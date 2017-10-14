import 'bindable.dart';

/// Const is a class that wraps a primitive value and adds operator overloading so that it
/// can be used inside the data graph.
///
/// Essentially, it's like a Bindable that cannot be changed, meaning it doesn't have a
/// change stream. These are largely unnecessary if operator overloading is not used.
///
///     var valid = new Bindable(5) + 10; // This will work.
///     var invalid = 10 + new Bindable(5); // Primitive types cannot be overloaded.
///     var fixed = new Const(10) + new Bindable(5); // Works great!
///
/// They may also be useful in some other cases as they wrap primitive types in an object
/// that can be passed around with references instead of the raw value.
class Const<T> extends BaseWrappedValue<T> {
    T _value;
    Const(T value) {
        this._value = value;
    }
    get value => this._value;

    // Operator overloading allows ComputedBindables to be invisibly created.
    BaseWrappedValue<R> _graphOperator<R>(dynamic other, Function performOperation) {
        if (other is Bindable) {
            return new ComputedBindable([other], performOperation);
        } else {
            dynamic val = other is BaseWrappedValue ? other.value : other;
            return new Const(performOperation(val));
        }
    }

    operator +(dynamic other) => this._graphOperator<T>(other, (o) => this._value + o);
    operator -(dynamic other) => this._graphOperator<T>(other, (o) => this._value - o);
    operator *(dynamic other) => this._graphOperator<T>(other, (o) => this._value * o);
    operator /(dynamic other) => this._graphOperator<T>(other, (o) => this._value / o);
    operator ^(dynamic other) => this._graphOperator<T>(other, (o) => this._value ^ o);

    operator ~/(dynamic other) => this._graphOperator<int>(other, (o) => this._value ~/ o);
    operator %(dynamic other) => this._graphOperator<int>(other, (o) => this._value % o);

    operator >(dynamic other) => this._graphOperator<bool>(other, (o) => this._value > o);
    operator >=(dynamic other) => this._graphOperator<bool>(other, (o) => this._value >= o);
    operator <(dynamic other) => this._graphOperator<bool>(other, (o) => this._value < o);
    operator <=(dynamic other) => this._graphOperator<bool>(other, (o) => this._value <= o);
    operator ==(dynamic other) => this._graphOperator<bool>(other, (o) => this._value == o);
}
