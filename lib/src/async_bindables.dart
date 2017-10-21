import 'dart:async';
import 'bindable.dart';


/// A computed bindable whose compute function returns a future instead of a raw value. Its
/// value will update once the future resolves.
class AsyncComputedBindable<V> extends ComputedBindable<V> {
    Future<T> currentComputation;

    /// When true, if the inputs change while a future is currently being processed, the
    /// existing future will be cancelled and computation will start over. When false, every
    /// computation is processed.
    bool cancelInterruptedFutures;

    /// When true (and when cancelInterruptedFutures is false), the order of the async value
    /// updates is guaranteed to match the order of the input changes. This works by delaying
    /// execution of futures, so it should only be used when needed.
    bool maintainOrdering;

    AsyncComputedBindable(inputs, computeFunction, {
        bool this.cancelInterruptedFutures = true,
        bool this.maintainOrdering = false,
    }) : super(inputs, computeFunction) {
        this.initialValue = false;
    }

    /// The change stream of computed bindables updates whenever any of their inputs update.
    /// @nodoc
    @protected
    void recompute() {
        if (!this.alive) throw new Exception('ComputedBindable has been destroyed.');
        if (this.cacheValid) return this.cachedValue;

        Future<T> computationFuture;
        final inputValues = this.inputs.map((input) => input.value).toList();
        computationFuture = Function.apply(this.computeFunction, inputValues);

        Future<T> orderingFuture = new Future.value(null);
        if (!this.cancelInterruptedFutures && this.maintainOrdering &&
            this.currentComputation != null) {
            orderingFuture = this.currentComputation.then((val) => computationFuture);
            this.currentComputation = orderingFuture;
        } else {
            this.currentComputation = computationFuture;
            orderingFuture = computationFuture;
        }

        orderingFuture.then((newComputed) {
            if (this.cancelInterruptedFutures &&
                computationFuture != this.currentComputation) {
                    return;
                }
            this.updateCacheValue(newComputed);
        });
    }

    /// Returns the current computed value. Note that in some cases the value will not be
    /// computed at all until this getter is called, so it can potentially be a relatively
    /// inefficient operation.
    T get value {
        if (!this.alive) throw new Exception('ComputedBindable has been destroyed.');
        return this.cachedValue;
    }
}


/// A bindable whose value is a debounced version of another bindable's value, meaning it
/// ignores changes that happen in quick succession.
class DebouncerBindable<V> extends AsyncComputedBindable<V> {

    /// Duration of time to wait before accepting the current value.
    Duration debounceDelay;

    DebouncerBindable(BaseBindable bindable, this.debounceDelay) : super(
            [bindable], (value) => new Timer(this.debounceDelay, () => value),
            cancelInterruptedFutures: true);
}


/// Delays every value change from a another bindable by a constant amount of time.
class DelayBindable<V> extends AsyncComputedBindable<V> {

    /// Duration of time to wait before accepting the current value.
    Duration delay;

    DelayBindable(BaseBindable bindable, this.delay) : super(
            [bindable], (value) => new Timer(this.delay, () => value),
            cancelInterruptedFutures: false, maintainOrdering: false);
}


/// Delays value changes from another bindable so they occur at minimum a set amount of time
/// apart. This is helpful for things like giving animations enough time to complete.
class SpreadChangesBindable<V> extends AsyncComputedBindable<V> {

    /// Duration of time to wait before accepting the current value.
    Duration delay;

    SpreadChangesBindable(BaseBindable bindable, this.delay) : super(
            [bindable], (value) => new Timer(this.delay, () => value),
            cancelInterruptedFutures: false, maintainOrdering: true);
}
