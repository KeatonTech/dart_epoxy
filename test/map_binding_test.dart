import 'package:test/test.dart';
import 'package:epoxy/epoxy.dart';
import 'package:epoxy/testing.dart';

void main() {
    test('BindableMaps can be built from an existing map', () {
        final map = new BindableMap({'A': 'Alpha', 'B': 'Beta'});
        expect(map.length, bindableEquals(2));
        expect(map['A'], bindableEquals('Alpha'));
        expect(map['B'], bindableEquals('Beta'));
        expect(map['C'], bindableEquals(null));

        expect(map.value['A'], equals('Alpha'));
        expect(map.value['B'], equals('Beta'));
        expect(map.value['C'], equals(null));
    });

    test('BindableMaps maintain a bindable list of keys', () {
        final map = new BindableMap({'A': 'Alpha', 'B': 'Beta'});

        final keys = map.keys;
        expect(keys, bindableEquals(['A', 'B']));

        map['S'] = 'Sigma';
        expect(keys, bindableEquals(['A', 'B', 'S']));

        map.remove('B');
        expect(keys, bindableEquals(['A', 'S']));
    });

    test('BindableMaps maintain a bindable list of values', () {
        final map = new BindableMap({'A': 'Alpha', 'B': 'Beta'});

        final values = map.values;
        expect(values, bindableEquals(['Alpha', 'Beta']));

        map['G'] = 'Gamma';
        expect(values, bindableEquals(['Alpha', 'Beta', 'Gamma']));

        map['B'] = 'Delta';
        expect(values, bindableEquals(['Alpha', 'Delta', 'Gamma']));

        map.remove('B');
        expect(values, bindableEquals(['Alpha', 'Gamma']));
    });

    test('BindableMaps produce a stream of change records', () async {
        final map = new BindableMap({'A': 'Alpha', 'B': 'Beta'});

        var changeFuture = map.changeStream.first;
        map['O'] = 'Omega';
        var change = await changeFuture;
        expect(change is PropertyChangeRecord, isTrue);
        expect(change.path[0], equals('O'));
        expect(change.baseChange is ValueChangeRecord, isTrue);
        expect(change.baseChange.oldValue, equals(null));
        expect(change.baseChange.newValue, equals('Omega'));

        changeFuture = map.changeStream.first;
        map['B'] = 'Delta';
        change = await changeFuture;
        expect(change is PropertyChangeRecord, isTrue);
        expect(change.path[0], equals('B'));
        expect(change.baseChange is ValueChangeRecord, isTrue);
        expect(change.baseChange.oldValue, equals('Beta'));
        expect(change.baseChange.newValue, equals('Delta'));

        changeFuture = map.changeStream.first;
        map.remove('B');
        change = await changeFuture;
        expect(change is PropertyChangeRecord, isTrue);
        expect(change.path[0], equals('B'));
        expect(change.baseChange is ValueChangeRecord, isTrue);
        expect(change.baseChange.oldValue, equals('Delta'));
        expect(change.baseChange.newValue, equals(null));
    });

    test('BindableMaps send change records for subproperty changes', () async {
        final map = new BindableMap({'Letters': {1: 'A', 2: 'B', 3: 'C'}});

        var changeFuture = map.changeStream.first;
        map['Letters'][3] = 'D';
        var change = await changeFuture;
        expect(change is PropertyChangeRecord, isTrue);
        expect(change.path[0], equals('Letters'));
        expect(change.path[1], equals(3));
        expect(change.baseChange is ValueChangeRecord, isTrue);
        expect(change.baseChange.oldValue, equals('C'));
        expect(change.baseChange.newValue, equals('D'));
    });

    test('BindableMaps maintain a length bindable', () async {
        final map = new BindableMap({1: 'A', 2: 'B', 3: 'C'});
        final length = map.length;
        expect(length, bindableEquals(3));

        map[4] = 'D';
        map[1] = 'Z';
        expect(length, bindableEquals(4));

        map.remove(1);
        expect(length, bindableEquals(3));
    });
}
