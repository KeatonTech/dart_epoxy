import 'bindable_collection.dart';
import 'bindable_list.dart';
import 'bindable.dart';
import 'change_record.dart';
import 'mapped_bindable_list.dart';
import 'property_bindables.dart';

/// The reactive equivalent to Dart's Map class.
class BindableMap<K, V> extends BindableDataStructure<Map<K, V>, K, V> {
    BindableMap(Map<K, V> value) : super({}) {
        this.disableChangeTracking = true;
        this.addAll(value);
        this.disableChangeTracking = false;
    }

    BindableList<K> _keys = null;
    void _initializeKeysList() => this._keys = new BindableList(this.value.keys.toList());
    FixedBindableList<K> get keys {
        if (this._keys == null) this._initializeKeysList();
        return this._keys.fixedBindable;
    }

    FixedBindableList<V> _mappedValues = null;
    FixedBindableList<V> get values {
        if (this._keys == null) this._initializeKeysList();
        if (this._mappedValues == null) {
            this._mappedValues = this._keys.boundMap([this], (index, map) => map[index]);
        }
        return this._mappedValues;
    }

    ComputedBindable<int> get length {
        if (this._keys == null) this._initializeKeysList();
        return this._keys.length;
    }

    void operator[]= (K index, dynamic newValue) {
        final isNewProperty = !this.value.containsKey(index);
        super[index] = newValue;
        if (isNewProperty && this._keys != null) this._keys.add(index);
    }


    // MAP FUNCTIONALITY

    /// Adds all key-value pairs from `other` to this map, overwriting any existing keys.
    void addAll(Map<K, V> other) {
        other.forEach((key, value) => this[key] = value);
    }

    /// Sets the property `key` to `value` iff no property named `key` already exists.
    ///
    /// Returns true if a new key was added, and false if it already existed.
    bool putIfAbsent(K key, V value) {
        if (!this.value.containsKey(key)) return false;
        this[key] = value;
        return true;
    }

    /// Removes a key from the map, which also removes it from the keys and values iterables.
    ///
    /// Returns false if the key was already not in the map.
    bool remove(K key) {
        if (!this.value.containsKey(key)) return false;
        final lastValue = this.value.remove(key);
        if (this._keys != null) this._keys.remove(key);
        this.invalidationController.add(true);
        this.changeController.add(
            new PropertyChangeRecord([key], new ValueChangeRecord(lastValue, null)));
        return true;
    }
}
