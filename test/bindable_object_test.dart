import 'dart:mirrors';
import 'package:test/test.dart';
import 'package:epoxy/epoxy.dart';
import 'package:epoxy/testing.dart';

class BindableLocation extends BindableObject {
    final $latitude = new PropertyBindable('latitude', 100);
    final $longitude = new PropertyBindable('longitude', 50);
}

class InvalidNonFinal extends BindableObject {
    var $property = new PropertyBindable('property');
}

class InvalidPublicBindable extends BindableObject {
    final publicBindable = new Bindable(100);
}

class ValidPrivateBindable extends BindableObject {
    final _privateBindable = new Bindable(100);
}

class BindableLocation3D extends BindableLocation {
    final $altitude = new PropertyBindable('altitude', 0);

    void goToSpace() {
        this.altitude = 10000;
    }
}

void main() {
    test('BindableObjects do not allow non-final bindable properties', () {
        bool errored = false;
        try {
            new InvalidNonFinal();
        } catch (e) {
            errored = true;
        }
        expect(errored, isTrue);
    });

    test('BindableObjects do not allow public non-property bindables', () {
        bool errored = false;
        try {
            new InvalidPublicBindable();
        } catch (e) {
            errored = true;
        }
        expect(errored, isTrue);
    });

    test('BindableObjects do allow private non-property bindables', () {
        new ValidPrivateBindable();
    });

    test('BindableObjects respond to changes in their properties', () async {
        final bindableLocation = new BindableLocation();
        expect(bindableLocation.latitude, equals(100));
        expect(bindableLocation.longitude, equals(50));

        final propertyChange = bindableLocation.changeStream.first;
        bindableLocation.latitude = -10;
        final changeRecord = await propertyChange;
        expect(changeRecord is PropertyChangeRecord, isTrue);
        expect(changeRecord.path[0], equals('latitude'));
        expect(changeRecord.baseChange is ValueChangeRecord, isTrue);
        expect(changeRecord.baseChange.oldValue, equals(100));
        expect(changeRecord.baseChange.newValue, equals(-10));
        expect(bindableLocation.latitude, equals(-10));
    });

    test('BindableObject properties are inherited', () async {
        final bindableLocation = new BindableLocation3D();
        expect(bindableLocation.altitude, equals(0));
        expect(bindableLocation.latitude, equals(100));
        expect(bindableLocation.longitude, equals(50));

        var propertyChange = bindableLocation.changeStream.first;
        bindableLocation.altitude += 10;
        var changeRecord = await propertyChange;
        expect(changeRecord is PropertyChangeRecord, isTrue);
        expect(changeRecord.path[0], equals('altitude'));
        expect(changeRecord.baseChange is ValueChangeRecord, isTrue);
        expect(changeRecord.baseChange.oldValue, equals(0));
        expect(changeRecord.baseChange.newValue, equals(10));
        expect(bindableLocation.altitude, equals(10));

        propertyChange = bindableLocation.changeStream.first;
        bindableLocation.latitude = -10;
        changeRecord = await propertyChange;
        expect(changeRecord is PropertyChangeRecord, isTrue);
        expect(changeRecord.path[0], equals('latitude'));
        expect(changeRecord.baseChange is ValueChangeRecord, isTrue);
        expect(changeRecord.baseChange.oldValue, equals(100));
        expect(changeRecord.baseChange.newValue, equals(-10));
        expect(bindableLocation.latitude, equals(-10));
    });

    test('BindableObject methods can access public bound properties', () async {
        final bindableLocation = new BindableLocation3D();
        var propertyChange = bindableLocation.changeStream.first;
        bindableLocation.goToSpace();
        var changeRecord = await propertyChange;
        expect(changeRecord is PropertyChangeRecord, isTrue);
        expect(changeRecord.path[0], equals('altitude'));
        expect(changeRecord.baseChange is ValueChangeRecord, isTrue);
        expect(changeRecord.baseChange.oldValue, equals(0));
        expect(changeRecord.baseChange.newValue, equals(10000));
        expect(bindableLocation.altitude, equals(10000));
    });

    test('BindableObjects can use computed properties', () async {
        final bindableLocation = new BindableLocation3D();
        var propertyChange = bindableLocation.changeStream.first;
        bindableLocation.altitude = bindableLocation.$latitude + bindableLocation.$longitude;
        var changeRecord = await propertyChange;
        expect(changeRecord is PropertyChangeRecord, isTrue);
        expect(changeRecord.path[0], equals('altitude'));
        expect(changeRecord.baseChange is ValueChangeRecord, isTrue);
        expect(changeRecord.baseChange.oldValue, equals(0));
        expect(changeRecord.baseChange.newValue, equals(150));
        expect(bindableLocation.altitude, equals(150));
        
        bindableLocation.latitude = 150;
        expect(bindableLocation.altitude, equals(200));
    });
}
