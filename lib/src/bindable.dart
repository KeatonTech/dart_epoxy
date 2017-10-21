import 'dart:async';
import 'dart:mirrors';
import 'package:meta/meta.dart';
import 'change_record.dart';
import 'epoxy_controller.dart';


/// Represents a single value that can be used in the data graph.
///
/// All bindables and consts follow this interface and inherit from this class.
abstract class BaseWrappedValue<T> {

    /// The current value of the node as a static (non-reactive) type that can be consumed
    /// directly by non-reactive code.
    T get value => throw new AbstractClassInstantiationError('BaseBindable');

    /// Aids in debugging by generating useful descriptions of wrapped values. It is one of
    /// the only functions that will always return a non-reactive value.
    /// Detects minification and indicates that the exact type information is unknown.
    String toString() {
        var typeName = reflect(this).type.reflectedType.toString();
        if (typeName.length < 8) typeName = 'WrappedValue (unknown type)';
        return '[$typeName with current value: ${this.value}]';
    }
}


/// Represents a value that can change over time (in other words, not a constant) by modeling
/// a stream of change events.
///
/// This abstract class is the basis for both Bindables and ComputedBindables and as such
/// does not have any way of tracking its current value.
abstract class BaseBindable<T> extends BaseWrappedValue<T> {

    /// The changeController is used to broadcast new ChangeRecords to the changeStream.
    /// It is only accessible by this class and its subclasses.
    final StreamController<ChangeRecord> _changeController =
        new StreamController<ChangeRecord>.broadcast(sync: true);

    /// Returns a stream of ChangeRecord events, which contain information about how the
    /// value of this bindable changes at runtime. Events are dispatched synchonously to
    /// allow the data model to stay consistently up to date.
    Stream<ChangeRecord> get changeStream => this._changeController.stream;

    /// The invalidateController is used to clear the cache of derived bindables before the
    /// a ChangeRecord is sent out. This is used to prevent timing-related glitches that can
    /// occur in reactive graphs.
    ///@nodoc
    @protected
    final StreamController invalidationController =
        new StreamController.broadcast(sync: true);

    /// Returns a stream of empty events that are used by derived bindables to invalidate
    /// their local caches before the bound value is changed.
    Stream get invalidationStream => this.invalidationController.stream;

    /// All bindables have a unique Id that can be used to cache them and their derived or
    /// computed properties more efficiently. Ids are sequential integers.
    int id;
    static int _lastId = 0;

    // When false, this bindable has been destroyed and can no longer be accessed.
    ///@nodoc
    @protected
    bool alive = true;

    BaseBindable() {
        this.id = BaseBindable._lastId++;
    }

    /// Destroys the Bindable by removing any local stream listeners or other persistent
    /// properties that could block garbage collection.
    void destroy() {
        this.alive = false;
        this.invalidationController.add(true);
    }

    /// Internal function that sends a ChangeRecord to the dependants of this Bindable, or
    /// queues it in the EpoxyController if a batching operation is active. This should be
    /// overridden by subclasses as necessary.
    /// @nodoc
    void sendChangeRecord(ChangeRecord changeRecord, {
            bool avoidBatching = false,
            bool avoidInvalidation = false,
        }) {

        if (!avoidInvalidation) this.invalidationController.add(true);
        if (Epoxy.isBatching && !avoidBatching) {
            Epoxy.queueBatchChange(this, changeRecord);
            return;
        }

        this._changeController.add(changeRecord);
    }

    BaseWrappedValue<R> _graphOperator<R>(dynamic other, Function performOperation) {
        Function nullableOperation = (a, b) {
            if (a == null || b == null) return null;
            return performOperation(a, b);
        };
        if (other is BaseBindable) {
            return new ComputedBindable([this, other], nullableOperation);
        } else {
            dynamic val = other is BaseWrappedValue ? other.value : other;
            return new ComputedBindable([this], (a) => nullableOperation(a, val));
        }
    }

    operator +(dynamic other) => this._graphOperator<T>(other, (a, o) => a + o);
    operator -(dynamic other) => this._graphOperator<T>(other, (a, o) => a - o);
    operator *(dynamic other) => this._graphOperator<T>(other, (a, o) => a * o);
    operator /(dynamic other) => this._graphOperator<T>(other, (a, o) => a / o);
    operator ^(dynamic other) => this._graphOperator<T>(other, (a, o) => a ^ o);

    operator ~/(dynamic other) => this._graphOperator<int>(other, (a, o) => a ~/ o);
    operator %(dynamic other) => this._graphOperator<int>(other, (a, o) => a % o);

    operator >(dynamic other) => this._graphOperator<bool>(other, (a, o) => a > o);
    operator >=(dynamic other) => this._graphOperator<bool>(other, (a, o) => a >= o);
    operator <(dynamic other) => this._graphOperator<bool>(other, (a, o) => a < o);
    operator <=(dynamic other) => this._graphOperator<bool>(other, (a, o) => a <= o);
    operator ==(dynamic other) => this._graphOperator<bool>(other, (a, o) => a == o);

    operator [](dynamic index) {
        throw new Exception('Cannot get property from non-collection Bindable.');
    }
    operator []=(dynamic index, dynamic value) {
        throw new Exception('Cannot set property in non-collection Bindable.');
    }
}


/// Bindable is the root class of all variables in the UI framework. It represents a value
/// that can be set or retrieved, along with a Stream that updates whenever the value is
/// changed or mutated in any way.
///
/// This class is roughly analogous to the Observable type in other reactive frameworks,
/// although its inheritance from BaseBindable gives it some syntactic sugar like operator
/// overloading to create ComputedBindables.
///
/// The reason this is called Bindable and not Observable is that the 'observation' part is
/// meant to be largely transparent to the end-user of the library. The point of bindables
/// is that they can be combined and processed to create a reactive data model, and can be
/// plugged into other frameworks (such as UI rendering libraries) that use them to control
/// things like layout and element properties.
class Bindable<T> extends BaseBindable<T> {
    T _value;

    Bindable(this._value);

    void destroy() {
        super.destroy();
        this.sendChangeRecord(new ValueChangeRecord(this._value, null));
    }

    T get value {
        if (!this.alive) throw new Exception('Bindable has been destroyed.');
        return this._value;
    }

    /// Sets this Bindable to a new value, noting the change in the changeStream. This will
    /// cause any ComputedBindables that depend on this one to update as well.
    void set value(T newValue) {
        if (!this.alive) throw new Exception('Bindable has been destroyed.');
        final changeRecord = new ValueChangeRecord(this._value, newValue);
        this._value = newValue;
        this.sendChangeRecord(changeRecord);
    }
}


/// ComputedBindables represent a value that is derived from one or more input Bindables
/// (which can be seen as 'value dependencies') processed with a compute function.
///
/// As such, their value property cannot be explicitly set, only read. In every other way,
/// they work just like a normal Bindable and can be used in any situation where a Bindable
/// can be used (so yes, you can use ComputedBindables as inputs to other ComputedBindables).
/// ComputedBindables use a 'pull' approach, lazily computing their values when they are
/// accessed.
class ComputedBindable<T> extends BaseBindable<T> {
    Function _computeFunction;
    List<Bindable> inputs = [];
    List<StreamSubscription> _listeners = [];
    List<StreamSubscription> _invalidationListeners = [];

    /// @nodoc
    @protected
    T cachedValue = null;

    /// @nodoc
    @protected
    bool cacheValid = false;
    bool _initialValue = true;

    ComputedBindable(this.inputs, this._computeFunction) {
        this._listeners = inputs.map((input) =>
            input.changeStream.listen((c) => this.recompute())).toList();
        this._invalidationListeners = inputs.map((input) =>
            input.invalidationStream.listen((c) => this.invalidate())).toList();
    }

    /// Allows this instance to be cleanly removed by the garbage collector by unhooking all
    /// of its listeners and nulling out its value.
    void destroy() {
        super.destroy();
        this.alive = false;
        this.cacheValid = false;
        this.sendChangeRecord(new ValueChangeRecord(this.cachedValue , null));
        this.cachedValue = null;
        this._listeners.map((listener) => listener.cancel());
        this._invalidationListeners.map((listener) => listener.cancel());
    }

    /// Invalidates the cache so that the next time the value is read it must be recomputed.
    /// @nodoc
    @protected
    void invalidate() {
        this.cacheValid = false;
        this._initialValue = false;
    }

    /// The change stream of computed bindables updates whenever any of their inputs update.
    /// @nodoc
    @protected
    T recompute() {
        if (!this.alive) throw new Exception('ComputedBindable has been destroyed.');
        if (this.cacheValid) return this.cachedValue;

        T newComputed;
        try {
            final inputValues = this.inputs.map((input) => input.value).toList();
            newComputed = Function.apply(this._computeFunction, inputValues);
        } catch (e) {
            newComputed = null;
        }

        final oldValue = this.cachedValue;
        this.cachedValue = newComputed;
        this.cacheValid = true;
        if (!this._initialValue && oldValue != newComputed) {
            this.invalidationController.add(true);
            this.sendChangeRecord(new ValueChangeRecord(oldValue, newComputed));
        }
        this._initialValue = false;
        return newComputed;
    }

    /// Returns the current computed value. Note that in some cases the value will not be
    /// computed at all until this getter is called, so it can potentially be a relatively
    /// inefficient operation.
    T get value {
        if (!this.alive) throw new Exception('ComputedBindable has been destroyed.');
        if (this.cacheValid) return this.cachedValue;
        return this.recompute();
    }

    /// It is not possible to explicitly set the value of ComputedBindables because the
    /// compute function is not reversible -- there is no way to know how to update the input
    /// bindables to produce the desired value in this property.
    void set value(T newValue) {
        throw new Exception('Cannot set the value of computed bindables.');
    }
}


/// Represents a Bindable whose value is tied to the value of another Bindable (the 'basis'),
/// which can be swapped out at any time without interrupting the change stream.
///
/// Basically, it acts as one consistent bindable value (which, like ComputedBindable, can be
/// used in all the same places as a normal Bindable), but whose content can be switched
/// between different inputs at runtime.
/// This class proxies function calls to its basis bindable, so if it happens to represent
/// a BindableList, `SwitchBindable.insertAll(0, ['A', 'B', 'C'])` will work just fine.
@proxy
class SwitchBindable<T> extends BaseBindable<T> {
    BaseBindable<T> _basis;
    StreamSubscription<ChangeRecord> _basisListener;
    StreamSubscription<ChangeRecord> _basisInvalidationListener;

    SwitchBindable(basis) {
        if (basis is BaseBindable) {
            this.basis = basis;
        } else if (basis is T) {
            this.basis = new Bindable(basis);
        } else {
            throw new Exception('Initial value for SwitchBindable had an invalid type.');
        }
    }

    /// The Bindable whose value this switch is currently pulling from.
    BaseBindable<T> get basis => this._basis;

    /// Switches this instance to point to a new 'basis' Bindable.
    void set basis(BaseBindable<T> newBasis) {
        final bool shouldNotify = this._basis != null;
        final oldValue = this.value;
        if (this._basisListener != null) this.destroy();

        this._basisListener = newBasis.changeStream.listen(this.noteBasisChange);
        this._basisInvalidationListener = newBasis.invalidationStream.listen((c) =>
            this.invalidationController.add(true));
        this._basis = newBasis;

        final newValue = this.value;
        if (newValue != oldValue && shouldNotify) {
            this.sendChangeRecord(new ValueChangeRecord(oldValue, newValue));
        }
    }

    /// Overridden by subclasses in order to perform more complex logic when the basis
    /// bindable is changed in such a way that causes the output value of this bindable
    /// to change.
    @protected
    ///@nodoc
    void noteBasisChange(ChangeRecord change) {
        this._changeController.add(change);
    }

    void destroy() {
        super.destroy();
        this._basisListener.cancel();
        this._basisInvalidationListener.cancel();
        this._basis = null;
    }

    /// Whether this instance has been destroyed. After an instance is destroyed, it should
    /// no longer be accessed in any way.
    bool get destroyed => this._basis == null;

    T get value => this._basis?.value;

    /// Sets the current value of the basis bindable, where possible. If this switch is
    /// currently pointing to a ComputedBindable, this function will throw an error.
    void set value(T newValue) {
        if (this._basis is Bindable) {
            this._basis.value = newValue;
        } else {
            throw new Exception('Cannot set value on basis bindable.');
        }
    }

    noSuchMethod(Invocation invocation) {
        return reflect(this.basis).delegate(invocation);
    }
    operator [](dynamic index) => this.basis[index];
    operator []=(dynamic index, dynamic value) => this.basis[index] = value;
}
