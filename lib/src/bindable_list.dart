import 'dart:async';
import 'package:meta/meta.dart';
import 'bindable_collection.dart';
import 'bindable.dart';
import 'change_record.dart';
import 'mapped_bindable_list.dart';
import 'property_bindables.dart';

/// Custom (very simple) iterator class for BindableList objects.
///
/// Note that this iterates over bindables and not over the raw values of the list.
class BindableListIterator<T> extends Iterator<SwitchBindable<T>> {
    BindableList<T> _parent;
    int _index = -1;
    SwitchBindable<T> get current => this._parent[this._index];
    BindableListIterator(this._parent);
    bool moveNext() {
        if (this._index == this._parent.length.value - 1) return false;
        this._index++;
        return true;
    }
}

/// Parent class of BindableList and FixedBindableList. This handles the semantics of being
/// a list and implements all of the functions that do not involve changing the list,
/// including functional programming constructs like Map and Reduce.
abstract class BaseBindableList<T> extends BindableDataStructure<List<T>, int, T> {
    BaseBindableList(list) : super(list) {
        this.processValueList(list);
    }

    void operator[]= (int index, dynamic newValue) {
        if (!this._hasIndex(index)) throw new RangeError('Index $index is out of range');
        super[index] = newValue;
    }

    bool _hasIndex(int index) => index >= 0 && index < super.value.length;

    /// The original list value, altered such that it cannot be modified directly to prevent
    /// situations where changes are unintentionally made outside of a bindable context.
    List<T> get value => new List.unmodifiable(super.value);

    /// A modifiable copy of the underlying list.
    List<T> toList() => super.value.toList();
    void set value(List<T> newValue) => this.replaceListValue(newValue);

    ///@nodoc
    @protected
    void replaceListValue(List<T> newValue) {
        super.value = newValue;
        this.processValueList(super.value);
    }

    /// A reference to the actual underlying list. This is dangerous as any changes  to that
    /// list will potentially mess up the internal caches of this class, and so it is a
    /// protected function that should only ever be used by subclasses of this class.
    ///@nodoc
    @protected
    List<T> get listInstance => super.value;

    /// Tracks the number of items in the list.
    ComputedBindable<int> get length => new ComputedBindable([this], (list) => list.length);

    /// An iterator that moves through all property bindables in this list. Note that this is
    /// a relatively inefficient operation because it involves creating bindables for every
    /// property, even ones that would not otherwise need binding enabled.
    Iterator get iterator => new BindableListIterator(this);


    // FUNCTIONAL OPERATIONS

    /// Reduces the list to a single Bindable by iteratively combining each item with an
    /// existing value using a compute function.
    ComputedBindable<F> fold<F>(F initial, F combine(F value, T element)) {
        return new ComputedBindable<F>([this], (arr) => arr.fold(initial, combine));
    }

    /// Reduces the list to a single Bindable by iteratively combining each item with a
    /// previous item using a compute function.
    ///
    ///     final list = new BindableList([1, 2, 3, 4]);
    ///     final sum = list.reduce((a, e) => a + e);
    ///     assert(sum == 10);
    ///     list.add(5);
    ///     assert(sum == 15);
    ///
    ComputedBindable<T> reduce(T combine(T value, T element)) {
        return new ComputedBindable<T>([this], (thisArray) => thisArray.reduce(combine));
    }

    /// Returns a bindable string that contains every item in this list joined by an optional
    /// separator. This only works for lists where all of the values implement a toString()
    /// function, otherwise it will throw an error.
    ComputedBindable<String> join([String separator = '']) {
        return this.fold('', (val, item) {
            if (val != '') val += separator;
            val += item.toString();
            return val;
        });
    }

    /// Returns a new BindableList where the values mirror the ones in this list, but with a
    /// mapping function applied to them. The returned list is fixed and cannot be modified,
    /// but it will stay in sync with this list. For example, if values are added to this
    /// list, their mapped values will also appear in the mapped list. The map function takes
    /// a single argument, which is a value of type T representing an item in the list.
    ///
    ///     final values = new BindableList(['Dart', 'Programming']);
    ///     final mapped = values.map((thing) => thing + ' is great!');
    ///     assert(mapped[0].value == 'Dart is great!');
    ///     assert(mapped.value.length == 2);
    ///     values.add('Binding');
    ///     assert(mapped[0].value == 'Binding is great!');
    ///     assert(mapped.value.length == 3);
    ///
    /// Map functions can only return primitive values and not bindables, for performance
    /// reasons. If you need a map function that depends on other Bindable values, use the
    /// boundMap() function.
    MappedBindableList<M, T> map<M>(M mapFunction(T item)) {
        return new MappedBindableList(this, mapFunction);
    }

    /// Returns a new BindableList where the values mirror the ones in this list, but with a
    /// mapping function based on one or more Bindables applied to them. The values of the
    /// returned list will update both when values of this list are changed and when the
    /// value of any of the dependency bindables change.
    ///
    ///     final multiplier = new Bindable(5);
    ///     final values = new BindableList([1, 1, 2, 3, 5]);
    ///     final multiplied = values.boundMap([value, multiplier], (v, m) => v * m);
    ///     assert(multiplied[2] == 10);
    ///     multiplier.value = 100;
    ///     assert(multiplied[2] == 200);
    ///     values[2] = 0.5;
    ///     assert(multiplied[2] == 50);
    ///
    /// The arguments to the mapFunction are [mapItem, inputValue1, inputValue2, ...], and
    /// it must return a primitive value of type M. Just like the map() function, returning
    /// Bindables is not supported for performance reasons.
    MappedBindableList<M, T> boundMap<M>(List<Bindable> mapInputs, Function mapFunction) {
        return new ComputedMappedBindableList<M, T>(this, mapInputs, mapFunction);
    }


    // INPUT PROCESSING

    /// Pulls Bindables and other wrapped values out of the list and puts them into the
    /// property cache, updating existing property bindings where necessary.
    /// @nodoc
    @protected
    List<T> processValueList(List<dynamic> list, {int startIndex: 0}) {
        for (var i = 0; i < list.length; i++) {
            list[i] = this.processValueForInsert(list[i]);
            if (list[i] is BaseBindable) {
                if (this.propertyCache.containsKey(i + startIndex)) {
                    this.propertyCache[i + startIndex].basis = list[i];
                } else {
                    this.attachPropertyBindable(new PropertyBindable(
                        i + startIndex, list[i]));
                }
            } else if (this.propertyCache.containsKey(i + startIndex)) {
                if (this.propertyCache[i + startIndex].basis is Bindable) {
                    this.propertyCache[i + startIndex].value = list[i];
                } else {
                    this.propertyCache[i + startIndex].basis = new Bindable(list[i]);
                }
            }
            if (list[i] is BindableList) {
                list[i] = list[i].listInstance;
            } else if (list[i] is BaseWrappedValue) {
                list[i] = list[i].value;
            }
        }
        return list;
    }
}

/// The reactive equivalent to Dart's List class.
///
/// BindableLists follow largely the same API as the native Dart list, but track changes in
/// the change stream so that they can be data-bound to other things. Lists track:
///
/// * Direct changes to themselves, eg `list.value = ['New', 'List'];`
/// * New values getting added / inserted, eg `list.insertAt(0, 'A');`
/// * Values getting removed, eg `list.removeAt(1);`
/// * Changes to their immediate properties, eg `list[0] = 'NewValue';`
/// * Changes to bindables bound to a property, eg `list[0] = bindable; bindable.value = 4;`
/// * Changes to properties in nested lists and collections, eg `list[0]['key'] = 'Value';`
///
/// All of these actions will result in a ChangeRecord (of some type) getting added to the
/// changeStream of this list instance.
///
/// Retrieving values from BindableLists doesn't return the primitive value of the item but
/// rather a Bindable that represents that value and can change over time.
///
///     final list = new BindableList([1, 2, 3, 4]);
///     final firstValue = list[0];
///     assert(firstValue.value == 1);
///     list[0] = -1;
///     assert(firstValue.value == -1);
///
/// This will continue to work even if values are set to bindables.
///
///     final list = new BindableList([1, 2, 0]);
///     final lastValue = list[2];
///     list[2] = list[0] + list[1]; // Creates a ComputedBindable with operator overloading.
///     assert(lastValue.value == 3);
///     list[0].value = 2;
///     assert(lastValue.value == 4);
///
/// One exception to this behavior is if items are inserted or deleted in the middle of the
/// list. Depending on the value of the [pinProperty] setting, existing bindables may or may
/// not update to their new position.
///
/// As demonstrated in the previous example, list items can be computed from previous values
/// in the list, which means it's possible to generate reactive number sequences.
///
///     final fibonacci = new BindableList([1, 1]);
///     for (var i = 0; i < 10; i++) fibonacci.add(fibonacci[i] + fibonacci[i + 1]);
///     expect(fibonacci.value, equals([1, 1, 2, 3, 5, 8, 13, 21, 34, 55, 89, 144]));
///
///     fibonacci[0] = 2;
///     fibonacci[1] = 2;
///     expect(fibonacci.value, equals([2, 2, 4, 6, 10, 16, 26, 42, 68, 110, 178, 288]));
///
class BindableList<T> extends BaseBindableList<T> {

    /// When pinProperties is true, Bindables returned from previous property accesses will
    /// stick with their original item when other rows are inserted or deleted, like so:
    ///
    ///     final list = new BindableList(['Existing Value'])
    ///     final prop = list[0];
    ///     list.insert(0, 'New Value');
    ///     expect(prop.value, equals('Existing Value'));
    ///     expect(prop.value == list[0].value, isFalse);
    ///     expect(prop.value == list[1].value, isTrue);
    ///
    /// Notice that the value of prop stayed the same, but its index changed. This is flipped
    /// around when pinProperties is set to false:
    ///
    ///     final list = new BindableList(['Existing Value'])
    ///     final prop = list[0];
    ///     list.insert(0, 'New Value');
    ///     expect(prop.value, equals('New Value'));
    ///     expect(prop.value == list[0].value, isTrue);
    ///
    /// Pinning properties is helpful for rendering UIs, especially ones with animation, as
    /// it lets the view layer render only newly added elements, instead of having to
    /// re-render everything whenever the indexing changes. It may be confusing in some cases
    /// though, so it can be toggled off at construction or at runtime.
    /// Note that this also affects the behavior of computed lists based on this one.
    bool pinProperties = true;

    BindableList(list, {this.pinProperties: true}) : super(list);

    // Tighten up the return type.
    SwitchBindable<T> operator[] (dynamic index) => super[index];

    /// Returns a FixedBindableList that stays up to date with this list but cannot be
    /// directly modified. Similar to 'immutableCopy' in other frameworks.
    FixedBindableListCopy<T> _fixedBindable;
    FixedBindableListCopy<T> get fixedBindable {
        if (this._fixedBindable == null) {
            this._fixedBindable = new FixedBindableListCopy(this);
        }
        return this._fixedBindable;
    }


    // INSERTION OPERATIONS

    /// Adds multiple values to the list at a given index. The first item in valuesToInsert
    /// will have the index of insertionIndex in the resulting list. The item currently
    /// occupying insertionIndex will get shifted backwards.
    void insertAll(int insertionIndex, Iterable<dynamic> valuesToInsert) {
        if (insertionIndex < 0 || insertionIndex > super.value.length) {
            throw new RangeError('Insertion index $insertionIndex is out of range');
        }

        final int insertCount = valuesToInsert.length;
        if (this.pinProperties) {
            // Shift existing properties to their new indices.
            for (var i = super.value.length - 1; i >= insertionIndex; i--) {
                if (this.propertyCache.containsKey(i)) {
                    final int newIndex = i + insertCount;
                    this.propertyCache[i].propertyName = newIndex;
                    this.propertyCache[newIndex] = this.propertyCache[i];
                    this.propertyCache.remove(i);
                }
            }
        }

        // Process the new values, including by adding any bindables to the cache.
        final valuesList = valuesToInsert.toList(growable: false);
        final rawInsert = this.processValueList(valuesList, startIndex: insertionIndex);
        super.listInstance.insertAll(insertionIndex, rawInsert);

        // Send a splice notification.
        this.invalidationController.add(true);
        this.changeController.add(
            new SpliceChangeRecord.fromInsert(insertionIndex, insertCount));
    }

    /// Adds a new value to the list at a given index. The new item will have the index of
    /// insertionIndex in the resulting list. The item currently occupying insertionIndex
    /// will get shifted backwards.
    void insert(int insertionIndex, dynamic insertValue) {
        this.insertAll(insertionIndex, [insertValue]);
    }

    /// Adds a new value to the end of the list.
    void add(dynamic addValue) {
        this.insertAll(super.value.length, [addValue]);
    }

    /// Adds multiple values to the end of the list.
    void addAll(Iterable<dynamic> addValues) {
        this.insertAll(super.value.length, addValues);
    }


    // DELETION OPERATIONS

    /// Removes items in the range (start, end] from the list (where start is inclusive and
    /// end is exclusive). Any properties bound to the deleted items will get invalidated.
    void removeRange(int start, int end) {
        if (start < 0 || start >= super.value.length) {
            throw new RangeError('Start index $start of deletion is out of range');
        }
        if (end < 0 || end > super.value.length) {
            throw new RangeError('End index $end of deletion is out of range');
        }
        final int deleteCount = end - start;
        if (deleteCount == 0) return;

        if (this.pinProperties) {
            // Delete any subproperties in the removal range.
            for (var i = start; i < end; i++) {
                this.notePropertyDeleted(i);
            }

            // Shift existing properties to their new indices.
            for (var i = end; i < super.value.length; i++) {
                if (this.propertyCache.containsKey(i)) {
                    final int newIndex = i - deleteCount;
                    this.propertyCache[i].propertyName = newIndex;
                    this.propertyCache[newIndex] = this.propertyCache[i];
                    this.propertyCache.remove(i);
                }
            }
        } else {
            // Shift existing properties to their new values.
            for (var i = start; i < super.value.length - deleteCount; i++) {
                if (this.propertyCache.containsKey(i)) {
                    final origIndex = i + deleteCount;
                    if (this.propertyCache.containsKey(origIndex)) {
                        this.propertyCache[i].basis = this.propertyCache[origIndex].basis;
                    } else {
                        this.propertyCache[i].basis = new Bindable(super.listInstance[i]);
                    }
                }
            }

            // Delete any subproperties whose indices no longer exist in the list.
            for (var i = super.value.length - deleteCount; i < super.value.length; i++) {
                this.notePropertyDeleted(i);
            }
        }

        // Splice the raw values array.
        super.listInstance.removeRange(start, end);

        // Send a splice notification.
        this.invalidationController.add(true);
        this.changeController.add(new SpliceChangeRecord.fromDelete(start, deleteCount));
    }

    /// Removes an item from the list. Any properties bound to the current index of that item
    /// will get invaliated.
    bool remove(dynamic value) {
        final index = value is PropertyBindable ? value.propertyName :
                                                  super.value.indexOf(value);
        if (index == null || index == -1) return false;
        this.removeRange(index, index + 1);
        return true;
    }

    /// Removes the item at a given index from the list. Any properties bound to the index
    /// will get invaliated.
    T removeAt(int index) {
        final originalValue = this[index];
        this.removeRange(index, index + 1);
        return originalValue;
    }

    /// Removes the last item from the list.
    T removeLast() => this.removeAt(super.value.length - 1);

    /// Removes all items from the list and invalidates all bound properties.
    void clear() => this.removeRange(0, super.value.length);
}


/// A type of BindableList where any operation that would change its length (add, insert,
/// remove, etc) is forbidden.
class FixedLengthBindableList<T> extends BaseBindableList<T> {
    FixedLengthBindableList(list): super(list);
}


/// A type of BindableList where values cannot be set, added, or removed directly.
///
/// This is different from being immutable, as the values can still be Bindables that change
/// over time -- this is more like a read-only window into a changing list.
class FixedBindableList<T> extends BaseBindableList<T> {
    FixedBindableList(list): super(list);

    /// Setting values is not supported in FixedBindableLists.
    void operator[]= (int index, dynamic newValue) {
        throw new Exception('Cannot set values on a fixed BindableList.');
    }

    /// Replacing the list is not supported in FixedBindableLists.
    void set value(List<T> newValue) {
        throw new Exception('Cannot set the list value on a fixed BindableList.');
    }
}

/// Represents a fixed copy of a BindableList that stays up to date with the original list
/// (including broadcasting changes), but does not allow any direct changes.
class FixedBindableListCopy<T> extends FixedBindableList<T> {
    StreamSubscription<ChangeRecord> _parentListener;

    FixedBindableListCopy(BindableList<T> copy): super(copy.listInstance) {
        this._parentListener = copy.changeStream.listen((change) {
            this.invalidationController.add(true);
            this.changeController.add(change);
        });
    }
    void destroy() {
        super.destroy();
        this._parentListener.cancel();
    }
}
