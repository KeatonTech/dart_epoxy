import 'dart:async';
import 'dart:mirrors';
import 'bindable_object.dart';
import 'property_bindables.dart';

/// The reactive equivalent of a Struct, which is like a map but with predefined properties.
@proxy
class BindableStruct<C> extends BindableObject {
    ClassMirror _mirrorType;

    /// Constructs a BindableStruct from a class definition.
    ///
    /// Forwards a maximum of 9 arguments to the constructor for the basis type (C). Why 9?
    /// I got bored after typing that many optional args. Dart doesn't have splats, which
    /// would make this code much less terrible-looking.
    BindableStruct([arg1, arg2, arg3, arg4, arg5, arg6, arg7, arg8, arg9]) : super() {
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
