import 'dart:async';
import 'package:meta/meta.dart';
import 'bindable.dart';
import 'bindable_list.dart';
import 'bindable_map.dart';
import 'change_record.dart';
import 'property_bindables.dart';

/// Represents a Bindable that contains multiple child bindables.
///
/// This is the base class of BindableList, BindableMap, and BindableClass -- and handles the
/// semantics of tracking property changes.
///
/// Types:
/// * T is the type of data structure this represents (for example List or Map).
/// * K is the type of keys / property names (for lists, this is int).
/// * V is the type of the properties that this collection contains.
abstract class BaseBindableCollection<T, K, V> extends Bindable<T> {

    /// PropertyBindables are not created from the input data until they are accessed, which
    /// makes the constructor much more efficient and prevents unnecessary work in situations
    /// where the collection is always used as a whole value.
    @protected
    Map<K, PropertyBindable<K, V>> propertyCache = {};

    /// Listeners that subscribe to changes in subproperties
    Map<K, StreamSubscription> _propertySubscriptions = {};

    BaseBindableCollection(value) : super(value);

    void destroy() {
        super.destroy();
        this._propertySubscriptions.values.forEach((sub) => sub.cancel());
    }

    /// BindableCollections in their most basic form are just Bindables whose value is a data
    /// structure instead of a primitive value, so setting that value replaces the entire
    /// data structure with a new list, and as such changes all of the property values. Doing
    /// this invalidates any previously accessed property bindables, as they are bound to a
    /// data structure instance that no longer exists.
    void set value(T newValue) {
        this.propertyCache.forEach((_, prop) => prop.destroy());
        this.propertyCache = {};
        super.value = newValue;
    }

    /// Allows subclasses to selectively disable change records getting sent out, which can
    /// be used as an optimization in some cases.
    @protected
    bool disableChangeTracking = false;

    /// Converts input values for the collection into an appropriate bindable value. For
    /// example, if the user creates a BindableList of Lists, this will automatically convert
    /// it into a BindableList of BindableLists.
    @protected
    dynamic processValueForInsert(dynamic value) {
        if (value is List) value = new BindableList(value);
        if (value is Map) value = new BindableMap(value);
        if (value is BaseWrappedValue && !(value is BaseBindable)) {
            return value.value;
        } else {
            return value;
        }
    }

    /// Attaches a PropertyBindable to a specific subproperty of this collection.
    @protected
    void attachPropertyBindable(PropertyBindable bindable) {
        final propertyName = bindable.propertyName;
        this.propertyCache[propertyName] = bindable;
        this._propertySubscriptions[propertyName] = bindable.changeStream.listen((change) {
            if (change is PropertyChangeRecord) {
                final newPath = change.path.toList();
                newPath.insert(0, bindable.propertyName);
                this.noteSubpropertyChange(newPath, change.baseChange);
            } else {
                this.noteSubpropertyChange([bindable.propertyName], change);
            }
        });
    }

    /// Tells the collection that one of its properties was deleted.
    void notePropertyDeleted(K property) {
        if (this.propertyCache.containsKey(property)) {
            this.propertyCache[property].destroy();
            this.propertyCache.remove(property);
            this._propertySubscriptions[property].cancel();
            this._propertySubscriptions.remove(property);
        }
    }

    /// Tells the collection that the value of one of its properties has changed. This is
    /// generally just used by the data binding system within Epoxy and should rarely or
    /// never be necessary for end users.
    void noteSubpropertyChange(List<dynamic> path, ChangeRecord baseChange) {
        if (path.length == 1 && baseChange is ValueChangeRecord) {
            final index = path[0];
            if (baseChange.newValue is BaseBindable) {
                final existingProperty = this[index];
                if (existingProperty is PropertyBindable) {
                    existingProperty.basis = baseChange.newValue;
                } else {
                    throw new Exception('Attempting to modify a non-property bindable');
                }
            } else {
                super.value[index] = baseChange.newValue;
            }
            if (baseChange.newValue is BaseWrappedValue) {
                super.value[index] = baseChange.newValue.value;
            }
        }
        if (!this.disableChangeTracking) {
            this.invalidationController.add(true);
            this.changeController.add(new PropertyChangeRecord(path, baseChange));
        }
    }
}

/// Represents a Bindable that contains multiple, arbitrarily named child bindables in a
/// backing data structure such as a List or Map.
///
/// This is the base class of BindableList and BindableMap, and handles a lot of the work of
/// tracking changes to child bindables and retrieving and setting property values.
///
/// Types:
/// * T is the type of data structure this represents (for example List or Map).
/// * K is the type of keys / property names (for lists, this is int).
/// * V is the type of the properties that this collection contains.
abstract class BindableDataStructure<T, K, V> extends BaseBindableCollection<T, K, V> {
    BindableDataStructure(value) : super(value);

    /// Returns a Bindable that contains the value of a given property in this collection.
    /// The Bindable will be tied (well, bound) to this collection such that if the property
    /// value is changed in the future, it will also change. Passing a Bindable into this
    /// operator as the index will create a demuxer of sorts, allowing the returned bindable
    /// to point to different properties as the index changes.
    ///
    ///     var selectedIndex = new Bindable(0);
    ///     var items = new BindableList(['A', 'B', 'C', 'D']);
    ///     var selection = items[selectedIndex];
    ///     assert(selection.value == 'A');
    ///     selectedIndex.value = 2;
    ///     assert(selection.value == 'B');
    ///
    BaseBindable<V> operator[] (dynamic index) {
        if (index is BaseBindable<K>) {
            return new PropertyDemuxerBindable(this, index);
        }

        if (index is K) {
            if (!this.propertyCache.containsKey(index)) {
                this.attachPropertyBindable(new PropertyBindable(
                    index, new Bindable(super.value[index])));
            }
            return this.propertyCache[index];
        }

        throw new Exception('Invalid index type: $index');
    }

    /// Sets the value of a property in this collection. Acceptible values are primitives,
    /// consts, Bindables and ComputedBindables. Wrapped values will be unpacked before
    /// getting added to the list, and bindings will be maintained separately.
    ///
    ///     var list = new BindableList([1, 2, 0]);
    ///     var bindableProperty = new Bindable(3);
    ///     list[2] = bindableProperty;
    ///     assert(list.value[2] == 3); // Note that it's just the primitive value 3.
    ///     bindableProperty.value = 4;
    ///     assert(list.value[2] == 4); // The value has transparently updated.
    ///
    /// If the value is set to a basic collection like a List, it will get automatically
    /// converted to a BindableList so that nested subproperties can be tracked.
    void operator[]= (K index, dynamic newValue) {

        // Allows subclasses to process this value accordingly.
        final processedValue = this.processValueForInsert(newValue);

        // If the referenced index has a subproperty binding, update it
        if (this.propertyCache.containsKey(index)) {
            final subproperty = this.propertyCache[index];
            if (newValue is BaseBindable<T>) {
                subproperty.basis = processedValue;
            } else {
                // Computed properties cannot be set, so they will have to be replaced with
                // a normal binding.
                try {
                    subproperty.value = processedValue;
                } catch (e) {
                    subproperty.basis = new Bindable(processedValue);
                }
            }

        // Otherwise, just update the value, creating a subproperty binding if the
        // input is a Bindable
        } else {
            final oldValue = super.value[index];
            this.noteSubpropertyChange(
                [index], new ValueChangeRecord(oldValue, processedValue));
        }
    }
}
