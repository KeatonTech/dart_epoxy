import 'dart:async';
import 'bindable_list.dart';
import 'bindable.dart';
import 'change_record.dart';

/// Helper class that associates indices in the original list with indices in the reindexed
/// list. This is essentially a bidirectional map with special names. Note that this is a
/// normal non-reactive internal data structure.
class _ReindexBiMap {
    Map<int, int> _ogToRemapped = {};
    Map<int, int> _remappedToOg = {};

    void associate(int originalIndex, int remappedIndex) {
        if (this._ogToRemapped.containsKey(originalIndex)) {
            this._remappedToOg.remove(this._ogToRemapped[originalIndex]);
        }
        if (this._remappedToOg.containsKey(remappedIndex)) {
            this._ogToRemapped.remove(this._remappedToOg[remappedIndex]);
        }
        this._ogToRemapped[originalIndex] = remappedIndex;
        this._remappedToOg[remappedIndex] = originalIndex;
    }

    void disassociateOriginalIndex(int originalIndex) {
        if (!this._ogToRemapped.containsKey(originalIndex)) return;
        this._remappedToOg.remove(this._ogToRemapped[originalIndex]);
        this._ogToRemapped.remove(originalIndex);
    }

    void disassociateRemappedIndex(int remappedIndex) {
        if (!this._remappedToOg.containsKey(remappedIndex)) return;
        this._ogToRemapped.remove(this._remappedToOg[remappedIndex]);
        this._remappedToOg.remove(remappedIndex);
    }

    int indexInRemapped(int originalIndex) => this._ogToRemapped[originalIndex];
    int indexInOriginal(int remappedIndex) => this._remappedToOg[remappedIndex];

    bool hasOriginalIndex(int originalIndex) {
        return this._ogToRemapped.containsKey(originalIndex);
    }
}

/// A list that mirrors another list, but with the items (or a subset of the items) in a
/// different order.
///
/// This kind of onject can be created by BindableList.filter() or BindableList.sort().
/// This list is fixed, meaning it can't be directly modified in any way. This is different
/// from being immutable, as the values can still change as bindings update.
abstract class ReindexedBindableList<T, O> extends FixedBindableList<T> {
    StreamSubscription<ChangeRecord> _inputChanges;
    final BaseBindableList<O> _input;
    _ReindexBiMap _reindexMap = new _ReindexBiMap();
    Bindable<Function> _reindexerBindable = new Bindable((l) => []);

    ReindexedBindableList(this._input, List<int> reindexFunction(List<T> values)) :
        super(reindexFunction(_input.value).map((index) => _input.value[index]).toList()) {
            this._reindexerBindable.value = reindexFunction;
            this._init();
        }

    ReindexedBindableList.withBindableReindexer(this._input, this._reindexerBindable) :
        super(_reindexerBindable.value(_input.value).map((i) => _input.value[i]).toList()) {
            this._init();
        }

    void _init() {
        this._currentIndices = reindexFunction(this._input.value);
        this._reindexerBindable.changeStream.listen((c) {
            this._updateIndices();
        });
        this._inputChanges = this._input.changeStream.listen(_onInputChange);
    }

    void destroy() => this._inputChanges.cancel();
    Stream<ChangeRecord> get changeStream => this._reindexedChangeStream;

    /// Recomputes the local value based on a new value from the input list.
    void _recomputeListValue() {
        super.replaceListValue(
            this._reindexerBindable.value(_input.value)
                .map((index) => _input.value[index])
                .toList());
    }

    /// Updates the _reindexMap based on the current value of _currentIndices.
    Map<int, int> _computeReindexMap() {
        Map<int, int> retMap = {};
        for (var i = 0; i < this._currentIndices.length; i++) {
            retMap[this._currentIndices[i]] = i;
        }
        return retMap;
    }

    /// Updates the state of the instance to reflect changes to the input list.
    void _onInputChange(ChangeRecord change) {
        if (change is ValueChangeRecord) {
            this._recomputeListValue();
            return;
        }

        var List<int> newIndices;
        if (change is PropertyChangeRecord) {
            newIndices = this._updateIndexOnPropertyChange(change, this._currentIndices);
        } else if (change is SpliceChangeRecord) {
            if (change.isDeletion) {
                this._updateIndexForDeletedIndices(
                    change.startIndex, change.startIndex + change.deletedCount,
                    this._currentIndices)
            } else {
                this._updateIndexWithNewValues(
                    this._input.value.sublist(
                        change.startIndex, change.startIndex + change.insertedCount),
                    this._currentIndices);
            }
        }
    }

    /// Updates the _currentIndices array based on a top-level property of the list changing.
    List<int> _updateIndexOnPropertyChange(PropertyChangeRecord change, List<int> indices) {
        throw new AbstractClassInstantiationError('ReindexableBindableList');
    }

    /// Updates the _currentIndices array based items getting added to the input list.
    List<int> _updateIndexWithNewValues(List<T> inserted, List<int> indices) {
        throw new AbstractClassInstantiationError('ReindexableBindableList');
    }

    /// Updates the _currentIndices array based rows getting removed from the input list.
    List<int> _updateIndexForDeletedIndices(int start, int end, List<int> indices) {
        return indices.where((index) => index < start || index >= end).toList();
    }
}
