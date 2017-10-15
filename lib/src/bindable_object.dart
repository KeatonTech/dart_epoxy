import 'dart:async';
import 'dart:mirrors';
import 'package:meta/meta.dart';
import 'bindable_collection.dart';
import 'bindable.dart';
import 'property_bindables.dart';

/// A bindable with fixed properties -- the basis for both BindableObject and BindableStruct.
@proxy
abstract class BaseBindableStruct extends
        BaseBindableCollection<Map<String, dynamic>, String, dynamic> {

    BaseBindableStruct(value): super(value);

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
    dynamic _mockGetter(String propName) {
        if (!propertyCache.containsKey(propName)) {
            throw new Exception('Property ${propName} does not exist.');
        }
        return propertyCache[propName].value;
    }

    /// Sets the value of a published property, if one exists.
    void _mockSetter(String propName, newValue) {
        if (!propertyCache.containsKey(propName)) {
            throw new Exception('Property ${propName} does not exist.');
        }

        final processedValue = super.processValueForInsert(newValue);
        final subproperty = this.propertyCache[propName];
        if (newValue is BaseBindable) {
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
    get value { return this._mockGetter('value'); }
    void set value(newValue) { return this._mockSetter('value', newValue); }
}

/// The reactive equivalent of a Struct, which is like a map but with predefined properties.
@proxy
class BindableStruct<C> extends BaseBindableStruct {
    ClassMirror _mirrorType;

    /// Constructs a BindableStruct from a class definition.
    ///
    /// Forwards a maximum of 9 arguments to the constructor for the basis type (C). Why 9?
    /// I got bored after typing that many optional args. Dart doesn't have splats, which
    /// would make this code much less terrible-looking.
    BindableStruct([arg1, arg2, arg3, arg4, arg5, arg6, arg7, arg8, arg9]) : super({}) {
        _mirrorType = reflect(this).type.typeArguments[0];
        if (!(_mirrorType is ClassMirror)) {
            throw new Exception('Used an invalid type to construct a BindableStruct');
        }

        final args = [];
        if (arg1 != null) args.add(arg1);
        if (arg2 != null) args.add(arg2);
        if (arg3 != null) args.add(arg3);
        if (arg4 != null) args.add(arg4);
        if (arg5 != null) args.add(arg5);
        if (arg6 != null) args.add(arg6);
        if (arg7 != null) args.add(arg7);
        if (arg8 != null) args.add(arg8);
        if (arg9 != null) args.add(arg9);

        this.disableChangeTracking = true;
        final typeInstance = _mirrorType.newInstance(new Symbol(''), args);
        _mirrorType.declarations.forEach((symbol, declaration) {
            if (declaration is VariableMirror && !declaration.isPrivate) {
                final propertyName = MirrorSystem.getName(symbol);
                final value = typeInstance.getField(symbol).reflectee;
                this.attachPropertyBindable(new PropertyBindable(propertyName, value));
            }
        });
        this.disableChangeTracking = false;
    }

    /// Adds '$'-prefixed getters to get the actual Bindable object for a property.
    noSuchMethod(Invocation invocation) {
        final realName = MirrorSystem.getName(invocation.memberName);
        if (invocation.isGetter && realName[0] == '\$') {
            return this.propertyCache[realName.replaceFirst('\$', '')];
        } else {
            return super.noSuchMethod(invocation);
        }
    }
}

/// A base class for custom classes that need to work within a reactive model.
abstract class BindableObject extends BaseBindableStruct {

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
                if (!(declaration as VariableMirror).isFinal) {
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
}
