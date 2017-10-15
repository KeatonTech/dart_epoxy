import 'dart:async';
import 'dart:mirrors';
import 'package:meta/meta.dart';
import 'bindable_collection.dart';
import 'bindable.dart';
import 'property_bindables.dart';

/// A base class for custom classes that need to work within a reactive model.
@proxy
abstract class BindableObject extends BaseBindableCollection<Map<String, Any>, String, Any> {

    /// Constructs a BindableObject by hooking the PropertyBindables from the current
    /// instance into a BindableCollection.
    BindableObject() : super({}) {
        InstanceMirror thisMirror = reflect(this);
        ClassMirror classMirror = thisMirror.type;

        final thisSymbol = new Symbol('BindableObject');
        while (classMirror != null && classMirror.simpleName != thisSymbol) {
            this._registerBindablesForClass(thisMirror, classMirror);
            classMirror = classMirror.superclass;
        }
    }

    /// Adds property getters and setters for all PropertyBindables on a class.
    _registerBindablesForClass(InstanceMirror thisMirror, ClassMirror classMirror) {
        classMirror.declarations.forEach((Symbol symbol, DeclarationMirror declaration) {
            if (!(declaration is VariableMirror)) return;

            final varValue = thisMirror.getField(symbol).reflectee;
            if (varValue is PropertyBindable) {
                if (!declaration.isFinal) {
                    throw new Exception('All bindable properties must be final.');
                }

                final fieldName = MirrorSystem.getName(symbol);
                if (fieldName == varValue.propertyName) {
                    throw new Exception(
                        'Property name must be different from it\'s field name');
                }
                this.attachPropertyBindable(varValue);

            } else if (varValue is BaseBindable && !declaration.isPrivate) {
                throw new Exception('Public bindables must be of type PropertyBindable.');
            }
        });
    }

    /// Allows property values to be accessed using dot notation.
    noSuchMethod(Invocation invocation) {
        final realName = MirrorSystem.getName(invocation.memberName);
        if (invocation.isGetter) {
            return this._mockGetter(realName);
        } else if (invocation.isSetter) {
            final setterProperty = realName.replaceFirst('=', '');
            final newValue = invocation.positionalArguments[0];
            return this._mockSetter(setterProperty, newValue);
        } else {
            throw new Exception('Invalid invocation on BindableObject');
        }
    }

    /// Returns the value of a published property, if one exists.
    _mockGetter(String propName) {
        if (!propertyCache.containsKey(propName)) {
            throw new Exception('Property ${propName} does not exist.');
        }
        return propertyCache[propName].value;
    }

    /// Sets the value of a published property, if one exists.
    _mockSetter(String propName, newValue) {
        if (!propertyCache.containsKey(propName)) {
            throw new Exception('Property ${propName} does not exist.');
        }

        final processedValue = super.processValueForInsert(newValue);
        final subproperty = this.propertyCache[propName];
        if (newValue is BaseBindable<T>) {
            subproperty.basis = processedValue;
        } else {
            // Computed properties cannot be set, so they will have to be replaced
            // with a normal binding.
            try {
                subproperty.value = processedValue;
            } catch (e) {
                subproperty.basis = new Bindable(processedValue);
            }
        }
    }

    /// Makes .value work like any other struct property.
    void get value { return this._mockGetter('value'); }
    void set value(newValue) { return this._mockSetter('value', newValue); }
}
