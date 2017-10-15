import 'dart:async';
import 'bindable_list.dart';
import 'bindable.dart';
import 'change_record.dart';

/// A list that mirrors another list, but with a transformation function applied to all of
/// its values -- it is almost always created from a call to BaseBindableList.map().
///
/// This list is fixed, meaning it can't be directly modified in any way. This is different
/// from being immutable, as the values can still change as bindings update.
class MappedBindableList<T, O> extends FixedBindableList<T> {
    Stream<ChangeRecord> _mappedChangeStream;
    StreamSubscription<ChangeRecord> _inputChanges;
    StreamSubscription _basisInvalidationListener;
    final BaseBindableList<O> _input;
    Bindable<Function> _mapBindable = new Bindable((c) => null);

    /// Returns the function that maps values from the input list to values in this list.
    Function get mapFunction => this._mapBindable.value;

    /// Changes the function that maps values from the input list to values in this list.
    /// This will cause all of the values to be recalculated.
    void set mapFunction(Function newFunction) {
        this._mapBindable.value = newFunction;
    }

    /// Constructs a new MappedBindableList given an input list and a mapping function.
    MappedBindableList(this._input, T mapFunction(O item)) :
        super(_input.value.map(mapFunction).toList()) {
            this._mapBindable.value = mapFunction;
            this._mappedChangeStream = this._input.changeStream.map(_mapChangeRecord);
            this._inputChanges = this._mappedChangeStream.listen(_onInputChange);
            this._basisInvalidationListener = this._input.invalidationStream.listen((c) =>
                this.invalidationController.add(true));

            this._mapBindable.changeStream.listen((c) {
                this.listInstance.replaceRange(
                    0, super.value.length,
                    this._input.value.map(this._mapBindable.value).toList());
            });
        }

    void destroy() {
        super.destroy();
        this._inputChanges.cancel();
        this._basisInvalidationListener.cancel();
    }

    Stream<ChangeRecord> get changeStream => this._mappedChangeStream;

    ComputedBindable operator[] (int index) {
        return new ComputedBindable(
            [this._input[index], this._mapBindable],
            (value, map) => map(value));
    }

    /// Property preprocessing is not necessary for mapped lists, so this is a no-op.
    List<T> processValueList(List<dynamic> list, {int startIndex: 0}) => list;


    // HANDLING CHANGES

    /// Processes mapped changes from the input list and applies them to the local list.
    void _onInputChange(ChangeRecord listChange) {
        if (listChange is ValueChangeRecord) {
            super.value = listChange.newValue;
        } else if (listChange is PropertyChangeRecord) {
            ValueChangeRecord baseChange = listChange.baseChange;
            final int changedIndex = listChange.path[0];
            super.listInstance[changedIndex] = baseChange.newValue;
        } else if (listChange is SpliceChangeRecord) {
            if (listChange.isDeletion) {
                super.listInstance.removeRange(
                    listChange.startIndex, listChange.startIndex + listChange.deletedCount);
            }
            if (listChange.isInsertion) {
                final addedItems = this._input.listInstance.getRange(
                    listChange.startIndex, listChange.startIndex + listChange.insertedCount);
                final mappedAddedItems = addedItems.map(this._mapBindable.value).toList();
                super.listInstance.insertAll(listChange.startIndex, mappedAddedItems);
            }
        }
    }

    /// Applies the mapping function to ChangeRecords from the input list, so that the
    /// newValue and oldValue fields make sense.
    ChangeRecord _mapChangeRecord(ChangeRecord listChange) {
        final mappedChange = listChange.copy();
        if (mappedChange is ValueChangeRecord) {
            mappedChange.oldValue = this.value;
            mappedChange.newValue = mappedChange.newValue.map(this._mapBindable.value);
        } else if (mappedChange is PropertyChangeRecord) {
           mappedChange.path = [mappedChange.path[0]];
           mappedChange.baseChange = new ValueChangeRecord(
               this.listInstance[mappedChange.path[0]],
               this._mapBindable.value(this._input.listInstance[mappedChange.path[0]]));
        }
        return mappedChange;
    }
}

/// A special subclass of MappedBindableList whose mapping function can rely on the current
/// values of one or more Bindables. This is almost always generated from the boundMap()
/// function in BindableList.
class ComputedMappedBindableList<T, O> extends MappedBindableList<T, O> {
    List<StreamSubscription> _subscribers = [];
    List<StreamSubscription> _invalidationSubscribers = [];
    List<Bindable> _mapInputs = [];

    /// Arguments to the map function are [mapItem, input1, input2, ...]
    ComputedMappedBindableList(BaseBindableList<O> input, this._mapInputs, Function map) :
        super(input, (item) => item) {
            this._mapInputs.forEach((mapInput) {
                this._subscribers.add(mapInput.changeStream.listen((c) {
                    this._updateMapBindable(map);
                }));
                this._invalidationSubscribers.add(mapInput.invalidationStream.listen((c) =>
                    this.invalidationController.add(true)));
            });
            this._updateMapBindable(map);
        }

    /// Updates the map function of the superclass when any of the bindables change.
    void _updateMapBindable(Function map) {
        final mapInputValues =  this._mapInputs.map((input) => input.value).toList();
        this.mapFunction = (item) {
            return Function.apply(map, [item]..addAll(mapInputValues));
        };
    }

    void destroy() {
        super.destroy();
        this._subscribers.forEach((subscriber) => subscriber.cancel());
        this._invalidationSubscribers.forEach((subscriber) => subscriber.cancel());
    }
}
