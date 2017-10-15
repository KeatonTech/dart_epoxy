import 'dart:mirrors';
import 'package:test/test.dart';
import 'package:epoxy/epoxy.dart';
import 'package:epoxy/testing.dart';

class DefaultValueStruct {
    int latitude = 10;
    int longitude = 90;
}

class LocationStruct {
    int latitude;
    int longitude;
    LocationStruct(this.latitude, this.longitude);
}

class ValueStruct {
    String value = 'Hello';
}

void main() {
    test('BindableStructs can be build from structs with default values', () async {
        final bindableTestStruct = new BindableStruct<DefaultValueStruct>();
        expect(bindableTestStruct.latitude, equals(10));
        expect(bindableTestStruct.longitude, equals(90));

        final propertyChange = bindableTestStruct.changeStream.first;
        bindableTestStruct.latitude = -10;
        final changeRecord = await propertyChange;
        expect(changeRecord is PropertyChangeRecord, isTrue);
        expect(MirrorSystem.getName(changeRecord.path[0]), equals('latitude'));
        expect(changeRecord.baseChange is ValueChangeRecord, isTrue);
        expect(changeRecord.baseChange.oldValue, equals(10));
        expect(changeRecord.baseChange.newValue, equals(-10));
        expect(bindableTestStruct.latitude, equals(-10));
    });

    test('BindableStructs can pass arguments to the struct constructor', () async {
        final bindableTestStruct = new BindableStruct<LocationStruct>(100, -40);
        expect(bindableTestStruct.latitude, equals(100));
        expect(bindableTestStruct.longitude, equals(-40));
    });

    test('BindableStruct can return the raw bindable version of properties', () async {
        final bindableTestStruct = new BindableStruct<DefaultValueStruct>();
        expect(bindableTestStruct.$latitude is BaseBindable, isTrue);
    });

    test('BindableStruct properties can be set to computed bindables', () async {
        final bindableTestStruct = new BindableStruct<DefaultValueStruct>();

        final propertyChange = bindableTestStruct.changeStream.first;
        bindableTestStruct.longitude = bindableTestStruct.$latitude;
        final changeRecord = await propertyChange;
        expect(changeRecord is PropertyChangeRecord, isTrue);
        expect(MirrorSystem.getName(changeRecord.path[0]), equals('longitude'));
        expect(changeRecord.baseChange is ValueChangeRecord, isTrue);
        expect(changeRecord.baseChange.oldValue, equals(90));
        expect(changeRecord.baseChange.newValue, equals(10));
        expect(bindableTestStruct.latitude, equals(10));
        expect(bindableTestStruct.longitude, equals(10));

        bindableTestStruct.latitude = 99;
        expect(bindableTestStruct.latitude, equals(99));
        expect(bindableTestStruct.longitude, equals(99));
    });

    test('BindableStructs values can be accessed with bracket notation', () async {
        final bindableTestStruct = new BindableStruct<LocationStruct>(-90, -40);
        expect(bindableTestStruct[new Symbol('latitude')].value, equals(-90));
        bindableTestStruct[new Symbol('latitude')] = 40;
        expect(bindableTestStruct.latitude, equals(40));
    });

    test('BindableStructs do not allow setting unknown properties', () async {
        final bindableTestStruct = new BindableStruct<LocationStruct>(-90, -40);
        bool caught = false;
        try {
            bindableTestStruct.altitude = 1000;
        } catch (e) {
            caught = true;
        }
        expect(caught, isTrue);
    });

    test('BindableStructs do not allow setting unknown properties with brackets', () async {
        final bindableTestStruct = new BindableStruct<LocationStruct>(-90, -40);
        bool caught = false;
        try {
            bindableTestStruct[new Symbol('altitude')] = 1000;
        } catch (e) {
            caught = true;
        }
        expect(caught, isTrue);
    });

    test('BindableStructs can have properties named "value"', () async {
        final bindableTestStruct = new BindableStruct<ValueStruct>();
        expect(bindableTestStruct.value, equals('Hello'));

        final propertyChange = bindableTestStruct.changeStream.first;
        bindableTestStruct.value = 'Goodbye';
        final changeRecord = await propertyChange;
        expect(changeRecord is PropertyChangeRecord, isTrue);
        expect(MirrorSystem.getName(changeRecord.path[0]), equals('value'));
        expect(changeRecord.baseChange is ValueChangeRecord, isTrue);
        expect(changeRecord.baseChange.oldValue, equals('Hello'));
        expect(changeRecord.baseChange.newValue, equals('Goodbye'));
        expect(bindableTestStruct.value, equals('Goodbye'));
    });
}
