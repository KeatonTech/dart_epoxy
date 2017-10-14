import 'dart:async';
import 'bindable.dart';
import 'change_record.dart';
import 'bindable_collection.dart';

/// A bindable that represents the value of a specific property in a larger collection.
///
/// This is implemented as a SwitchBindable because properties can be set to different
/// bindables at runtime. Setting the value of a property bindable will reflect the value
/// down to whichever Bindable is currently on that property. This is a proxy class that
/// delegates function calls (such as .add() or .clear()) down to its basis bindable.
class PropertyBindable<K, V> extends SwitchBindable<V> {
    final BaseBindableCollection _parent;
    K propertyName;

    PropertyBindable(this._parent, this.propertyName, basis) : super(basis);

    /// Notifies this class of a change event coming from the basis bindable. This overrides
    /// a simpler function on SwitchBindable to notify the parent bindable.
    void noteBasisChange(ChangeRecord change) {
        if (this.destroyed) return;
        if (change is PropertyChangeRecord) {
            final newPath = change.path.toList();
            newPath.insert(0, this.propertyName);
            this._parent.noteSubpropertyChange(newPath, change.baseChange);
        } else {
            this._parent.noteSubpropertyChange([this.propertyName], change);
        }
        this.changeController.add(change);
    }
}


/// A special kind of PropertyBindable whose property changes with a bindable, adding
/// Demuxer-like behavior. This effectively ends up being a SwitchBindable that switches
/// between other SwitchBindables.
///
///     var selectedIndex = new Bindable(0);
///     var items = new BindableList(['A', 'B', 'C', 'D']);
///     var selection = items[selectedIndex]; // Selection is a PropertyDemuxerBindable
///     assert(selection.value == 'A');
///     selectedIndex.value = 2;
///     assert(selection.value == 'B');
///
class PropertyDemuxerBindable<T> extends SwitchBindable<T> {
    StreamSubscription<ChangeRecord> _indexListener;

    PropertyDemuxerBindable(BaseBindableCollection parent, Bindable indexBindable) :
        super(parent[indexBindable.value]) {
        this._indexListener = indexBindable.changeStream.listen((change) {
            if (change is ValueChangeRecord) {
                this.basis = parent[change.newValue];
            } else {
                throw new Exception('Got a complex mutation change on the demuxer index');
            }
        });
    }

    void destroy() {
        this._indexListener.cancel();
        super.destroy();
    }
}
