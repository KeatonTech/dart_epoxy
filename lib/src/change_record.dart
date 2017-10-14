/// Represents a single discreet change to a value.
///
/// For non-collections, this will always be an instance of ValueChangeRecord. Other
/// subclasses represent more complex changes such as  a subproperty changing or items being
/// added or removed from a collection.
abstract class ChangeRecord {

    /// Returns a deep copy of the change that can be modified. The return type should be the
    /// same as the instance type.
    ChangeRecord copy() {
        throw new AbstractClassInstantiationError('ChangeRecord');
    }
}

/// Represents a value changing to an entirely new value.
///
/// This is the only type of ChangeRecord that gets sent by primitive types like numbers and
/// strings. It can also be sent by collection types when the backing List/Map is changed to
/// a new instance.
class ValueChangeRecord<T> extends ChangeRecord {

    /// The value of the object before the change.
    T oldValue;

    /// The value of the object after the change (this one will be the current value at the
    /// time the change is broadcasted).
    T newValue;

    ValueChangeRecord(this.oldValue, this.newValue);

    copy() {
        return new ValueChangeRecord(this.oldValue, this.newValue);
    }
}

/// Represents a list changing in length when one or more items is inserted or deleted.
///
/// This class mirrors the arguments to the Javascript Array Splice function, hence the name.
class SpliceChangeRecord extends ChangeRecord {

    /// Inclusive start index of the splice operation. For insertions, the first inserted
    /// item will have this index in the resulting list (and the item that used to be at this
    /// index will be pushed back). For deletions, this is the index of the first item that
    /// will be deleted.
    int startIndex;

    /// Number of items that were inserted, starting at startIndex.
    int insertedCount = 0;

    /// Number of items that were deleted, starting at startIndex.
    int deletedCount = 0;

    /// Constructs an arbitrary SpliceChangeRecord.
    /// It is technically possible to create a splice operation that both inserts and deletes
    /// items. In that case, the deletion should be processed first. However, this can be
    /// confusing and lead to some tricky edge cases, so generally the other two constructors
    /// (fromInsert and fromDelete) are preferred.
    SpliceChangeRecord(this.startIndex, this.insertedCount, this.deletedCount);
    SpliceChangeRecord.fromInsert(this.startIndex, this.insertedCount);
    SpliceChangeRecord.fromDelete(this.startIndex, this.deletedCount);

    copy() {
        return new SpliceChangeRecord(
            this.startIndex, this.insertedCount, this.deletedCount);
    }

    /// Whether this splice involves deleting items.
    bool get isDeletion => this.deletedCount > 0;

    /// Whether this splice involves inserting items.
    bool get isInsertion => this.insertedCount > 0;
}

/// Represents the change to a collection when one of its properties changes.
///
/// This supports both top level properties and nested properties (when collections are
/// inside other collections).
class PropertyChangeRecord<T> extends ChangeRecord {

    /// Identifies the exact property that was changed. For top-level changes (a value set
    /// directly on the affected list) this will have a length of 1, where the value is the
    /// index or key of the item that changed. Values in this path are always ints for lists,
    /// but can be any type that is accepted as a key for maps.
    List<dynamic> path;

    /// The change that occured to the property, triggering this property change. This will
    /// never be a PropertyChangeRecord, as those simply extend 'path' as they bubble up.
    ChangeRecord baseChange;

    PropertyChangeRecord(this.path, this.baseChange);

    copy() {
        return new PropertyChangeRecord(this.path.toList(), this.baseChange.copy());
    }
}

/// Represents the change to a collection when a property with a given name is removed.
///
/// This is different from a splice change record because it does not imply that any other
/// properties need to shift in any way. It is used on Maps and other data structures where
/// there is no implied order to properties. This only supports top-level properties.
class PropertyRemovedRecord<K> extends ChangeRecord {
    K propertyName;
    PropertyRemovedRecord(this.propertyName);
    copy() => new PropertyRemovedRecord(this.propertyName);
}

/// Represents the change to a collection when a property with a given name is added.
///
/// This is different from a splice change record because it does not imply that any other
/// properties need to shift in any way. It is used on Maps and other data structures where
/// there is no implied order to properties. This only supports top-level properties.
class PropertyAddedRecord<K, V> extends ChangeRecord {
    K propertyName;
    V newValue;
    PropertyAddedRecord(this.propertyName, this.newValue);
    copy() => new PropertyAddedRecord(this.propertyName, this.newValue);
}
