import 'dart:async';
import 'bindable.dart';
import 'change_record.dart';

/// Internal struct for the epoxy controller that stores information about a queued change.
class _BatchedChange {
    BaseBindable bindable;
    ChangeRecord changeRecord;
    dynamic originalValue;
    _BatchedChange(this.bindable, this.changeRecord, this.originalValue) {}
}

/// Static class that controls the global behavior of bindables, allowing for change
/// operations to be batched to prevent unnecessary computations.
class Epoxy {

    /// Tracks whether or not change operations should be batched.
    static bool _isBatching = false;

    /// Tracks all of the Bindables that changed during a batch operation along with a struct
    /// that contains information about how they changed and how to process that change.
    static Map<int, _BatchedChange> _changeBatch = {};

    /// When true, all change operations should be queued into the queueBatchChange function
    /// instead of being processed immediately by the Bindable.
    static bool get isBatching => Epoxy._isBatching;

    /// Batches all of the changes within the callback function into one change operation
    /// that can be processed more efficiently.
    static void batchChanges(Function batchedZone) {
        Epoxy._isBatching = true;
        batchedZone();
        Epoxy._closeBatch();
    }

    /// Adds a new change to the current batch. This function is automatically called by
    /// Bindables when Epoxy.isBatching is true.
    /// @nodoc
    static void queueBatchChange(BaseBindable bindable, ChangeRecord changeRecord) {
        dynamic originalValue = null;
        if (Epoxy._changeBatch.containsKey(bindable.id)) {
            originalValue = Epoxy._changeBatch[bindable.id].originalValue;
        } else if (changeRecord is ValueChangeRecord) {
            originalValue = changeRecord.oldValue;
        }

        final change = new _BatchedChange(bindable, changeRecord, originalValue);
        Epoxy._changeBatch[bindable.id] = change;
    }

    /// Executes all of the changes in a batch, using a cache-flushing method to make sure
    /// ComputedBindables are only recomputed at most once each.
    static void _closeBatch() {
        while (Epoxy._changeBatch.length > 0) {
            final List<int> changeFrame = Epoxy._changeBatch.keys.toList();
            changeFrame.forEach((int key) {
                final _BatchedChange queuedChange = Epoxy._changeBatch[key];

                if (queuedChange.changeRecord is ValueChangeRecord) {
                    // Optimization: Suppress change events if they would not result in the
                    // value of the bindable changing.
                    if (queuedChange.changeRecord.newValue == queuedChange.originalValue &&
                        queuedChange.originalValue != null) {
                        Epoxy._changeBatch.remove(key);
                        return;
                    }
                    queuedChange.changeRecord.oldValue = queuedChange.originalValue;
                }


                queuedChange.bindable.sendChangeRecord(
                    queuedChange.changeRecord, avoidBatching: true, avoidInvalidation: true);
                Epoxy._changeBatch.remove(key);
            });
        }

        Epoxy._changeBatch = {};
        Epoxy._isBatching = false;
    }
}
