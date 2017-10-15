import 'dart:async';
import 'dart:mirrors';
import 'package:meta/meta.dart';
import 'bindable_collection.dart';
import 'bindable.dart';

/// The reactive equivalent of a Struct, which is like a map but with predefined properties.
@proxy
class BindableStruct<C> extends BindableDataStructure<Map<Symbol, Any>, Symbol, Any> {
    ClassMirror _mirrorType;

    /// Constructs a BindableStruct from a class definition.
    ///
    /// Forwards a maximum of 5 arguments to the constructor for the basis type (C). Why 5?
    /// I got bored after typing that many optional args. Dart doesn't have splats, which
    /// would make this code much less terrible-looking.
    BindableStruct([arg1, arg2, arg3, arg4, arg5]) : super({}) {
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
        final typeInstance = _mirrorType.newInstance(new Symbol(''), args);

        this.disableChangeTracking = true;
        _mirrorType.declarations.forEach((symbol, declaration) {
            if (declaration is VariableMirror && !declaration.isPrivate) {
                super[symbol] = typeInstance.getField(symbol).reflectee;
            }
        });
        this.disableChangeTracking = false;
    }

    /// Allows property values to be accessed using dot notation.
    noSuchMethod(Invocation invocation) {
        final realName = MirrorSystem.getName(invocation.memberName);

        if (invocation.isGetter) {
            if (realName[0] == '\$') {
                final originalProperty = new Symbol(realName.replaceFirst('\$', ''));
                if (!super.value.containsKey(originalProperty)) {
                    throw new Exception('Property ${originalProperty} does not exist.');
                }
                return super[originalProperty];
            } else {
                if (!super.value.containsKey(invocation.memberName)) {
                    throw new Exception('Property ${invocation.memberName} does not exist.');
                }
                return super[invocation.memberName].value;
            }
        } else if (invocation.isSetter) {
            final setterProperty = new Symbol(
                realName.replaceFirst('=', '').replaceFirst('\$', ''));
            if (!super.value.containsKey(setterProperty)) {
                throw new Exception('Property ${setterProperty} does not exist.');
            }
            return super[setterProperty] = invocation.positionalArguments[0];
        } else {
            throw new Exception('Invalid invocation on BindableStruct');
        }
    }

    /// Prevents new properties from being added to this struct.
    void operator[]= (Symbol key, dynamic newValue) {
        if (!super.value.containsKey(key)) {
            throw new Exception('Cannot add arbitrary properties to a struct.');
        }
        super[key] = newValue;
    }

    /// Makes .value work like any other struct property.
    void get value { return super[new Symbol('value')].value; }
    void set value(newValue) { return super[new Symbol('value')] = newValue; }
}
