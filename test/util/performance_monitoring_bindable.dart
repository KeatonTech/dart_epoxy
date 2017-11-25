import 'package:epoxy/epoxy.dart';

/// PerformanceMonitoringBindables are a type of ComputedBindable that keep track of how
/// often they are recomputed and how long each computation takes.
class PerformanceMonitoringBindable<T> extends ComputedBindable<T> {
    List<int> computationTimes = [];
    int invalidationCount = 0;

    PerformanceMonitoringBindable(inputs, computeFunction) : super(inputs, computeFunction);

    // Invalidates the cache so that the next time the value is read it must be recomputed.
    void invalidate() {
        invalidationCount++;
        super.invalidate();
    }

    // The change stream of computed bindables updates whenever any of their inputs update.
    T recompute() {
        if (this.cacheValid) return this.cachedValue;
        DateTime start = new DateTime.now();
        T result = super.recompute();
        DateTime end = new DateTime.now();
        int durationUs = end.difference(start).inMicroseconds;
        computationTimes.add(durationUs);
        return result;
    }

    /// Resets the internal performance monitor, to prevent things outside of the current
    /// test from influencing the results.
    void resetMonitoring() {
        this.computationTimes = [];
        this.invalidationCount = 0;
    }

    /// Returns the number of computations performed.
    int get computationCount { return this.computationTimes.length; }

    /// Returns the average duration of computation
    int get averageTimeUs {
        return this.computationTimes.reduce((a, i) => a + i) / this.computationTimes.length;
    }
}
