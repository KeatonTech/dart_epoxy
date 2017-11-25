import 'package:test/test.dart';
import 'package:dart_epoxy/dart_epoxy.dart';
import './util/util.dart';

void main() {
    test('BindableList can be built from a flat list of data', () {
        final bound = new BindableList([1, 2, 3, 4, 5]);
        expect(bound.value, equals([1, 2, 3, 4, 5]));
        expect(bound.length, bindableEquals(5));

        final valueInList = bound[1];
        expect(valueInList is PropertyBindable, isTrue);
        expect(valueInList.value, equals(2));
    });

    test('Can iterate through a BindableList', () {
        final bound = new BindableList([1, 2, 3, 4, 5]);
        var callCount = 0;
        for (var property in bound) {
            expect(property.value, equals(++callCount));
        }
        expect(callCount, equals(5));
    });

    test('BindableList tracks changes to its subproperties', () async {
        final bound = new BindableList([1, 2, 3, 4, 5]);
        final valueInList = bound[1];

        bound[1] = -1;
        expect(valueInList, bindableEquals(-1));

        final otherValueChange = bound.changeStream.first;
        bound[3] = -3;
        final changeRecord = await otherValueChange;
        expect(changeRecord is PropertyChangeRecord, isTrue);
        expect(bound[3], bindableEquals(-3));
    });

    test('BindableList supports Bindables as input values', () async {
        final valueBindable = new Bindable(2);
        final bound = new BindableList([1, valueBindable, 3]);

        final valueInList = bound[1];
        expect(valueInList, bindableEquals(2));

        final subpropertyChange = valueInList.changeStream.first;
        final propertyChange = bound.changeStream.first;

        valueBindable.value = -1;
        await subpropertyChange;
        final changeRecord = await propertyChange;
        expect(changeRecord is PropertyChangeRecord, isTrue);
        expect(valueBindable, bindableEquals(-1));
        expect(valueInList, bindableEquals(-1));
        expect(bound[1], bindableEquals(-1));
        expect(bound.value[1], equals(-1));

        bound[1] = 0;
        expect(valueBindable, bindableEquals(0));
        expect(valueInList, bindableEquals(0));
        expect(bound[1], bindableEquals(0));
        expect(bound.value[1], equals(0));

        valueInList.value = 1;
        expect(valueBindable, bindableEquals(1));
        expect(valueInList, bindableEquals(1));
        expect(bound[1], bindableEquals(1));
        expect(bound.value[1], equals(1));
    });

    test('Can set Bindable values to BindableList', () {
        final bound = new BindableList([1, 2, 3]);
        bound[2] = bound[0] + bound[1];
        expect(bound[2], bindableEquals(3));

        bound[1] = 1;
        expect(bound[2], bindableEquals(2));
        expect(bound.value[2], equals(2));
    });

    test('Property bindings update when the property is set to a new Bindable', () {
        final bound = new BindableList([1, 1, 3, 4]);
        bound[3] = bound[1] + bound[2];
        expect(bound[2], bindableEquals(3));
        expect(bound[3], bindableEquals(4));

        bound[2] = bound[0] + bound[1];
        expect(bound[2], bindableEquals(2));
        expect(bound[3], bindableEquals(3));

        bound[1] = 3;
        expect(bound[2], bindableEquals(4));
        expect(bound.value[2], equals(4));
        expect(bound[3], bindableEquals(7));
        expect(bound.value[3], equals(7));
    });

    test('Computed properties can be set to a new value', () {
        final bound = new BindableList([1, 1, 3, 4]);
        bound[3] = bound[1] + bound[2];

        bool caughtError = false;
        try {
            bound[3] = 1;
        } catch (e) {
            caughtError = true;
        } finally {
            expect(caughtError, isFalse);
            expect(bound[3], bindableEquals(1));
            expect(bound.value[3], equals(1));
        }
    });

    test('Computed properties can be set to a new binding', () {
        final bound = new BindableList([1, 1, 3, 4]);
        bound[3] = bound[1] + bound[2];

        bool caughtError = false;
        try {
            bound[3] = new Bindable(1);
        } catch (e) {
            caughtError = true;
        } finally {
            expect(caughtError, isFalse);
            expect(bound[3], bindableEquals(1));
            expect(bound.value[3], equals(1));
        }
    });

    test('Generate Reactive Fibonacci', () {
        final fibonacci = new BindableList([1, 1]);
        for (var i = 0; i < 10; i++) fibonacci.add(fibonacci[i] + fibonacci[i + 1]);
        expect(fibonacci.value, equals([1, 1, 2, 3, 5, 8, 13, 21, 34, 55, 89, 144]));

        fibonacci[0] = 2;
        fibonacci[1] = 2;
        expect(fibonacci.value, equals([2, 2, 4, 6, 10, 16, 26, 42, 68, 110, 178, 288]));
    });

    test('Passing a bindable into an index lookup creates a demuxer', () async {
        final letters = new BindableList(['A', 'B', 'C', 'D', 'E']);
        final selectedIndex = new Bindable(0);
        final selection = letters[selectedIndex];
        expect(selection, bindableEquals('A'));

        var selectionChangeFuture = selection.changeStream.first;
        selectedIndex.value = 2;
        var selectionChange = await selectionChangeFuture;
        expect(selectionChange.oldValue, equals('A'));
        expect(selectionChange.newValue, equals('C'));
        expect(selection, bindableEquals('C'));

        selectionChangeFuture = selection.changeStream.first;
        letters[0] = 'Alpha';
        letters[1] = 'Bravo';
        letters[2] = 'Charlie';
        selectionChange = await selectionChangeFuture;
        expect(selectionChange.oldValue, equals('C'));
        expect(selectionChange.newValue, equals('Charlie'));
        expect(selection, bindableEquals('Charlie'));
    });

    test('BindableList tracks insertion changes', () async {
        final bound = new BindableList([1, 2, 6]);

        final otherValueChange = bound.changeStream.first;
        bound.insertAll(2, [3, 4, 5]);
        final changeRecord = await otherValueChange;
        expect(changeRecord is SpliceChangeRecord, isTrue);
        expect(changeRecord.startIndex, equals(2));
        expect(changeRecord.insertedCount, equals(3));
        expect(changeRecord.deletedCount, equals(0));
        expect(bound.length, bindableEquals(6));
        expect(bound, bindableEquals([1, 2, 3, 4, 5, 6]));
    });

    test('BindableList tracks deletion changes', () async {
        final bound = new BindableList([1, 2, 3, 4, 5]);

        final otherValueChange = bound.changeStream.first;
        bound.removeRange(1, 3);
        final changeRecord = await otherValueChange;
        expect(changeRecord is SpliceChangeRecord, isTrue);
        expect(changeRecord.startIndex, equals(1));
        expect(changeRecord.insertedCount, equals(0));
        expect(changeRecord.deletedCount, equals(2));
        expect(bound.length, bindableEquals(3));
        expect(bound, bindableEquals([1, 4, 5]));
    });

    test('Property bindables can be pinned when items are inserted', () {
        final bound = new BindableList([1, 3]);
        final prop1 = bound[0];
        final prop2 = bound[1];
        bound.insert(1, 2);

        expect(prop1, bindableEquals(1));
        expect(prop1.propertyName, equals(0));
        expect((prop1 == bound[0]).value, isTrue);

        expect(prop2, bindableEquals(3));
        expect(prop2.propertyName, equals(2));
        expect((prop2 == bound[1]).value, isFalse);
    });

    test('Property bindables can be unpinned when items are inserted', () {
        final bound = new BindableList([1, 4], pinProperties: false);
        final prop1 = bound[0];
        final prop2 = bound[1];
        bound.insertAll(1, [2, 3]);

        expect(prop1, bindableEquals(1));
        expect(prop1.propertyName, equals(0));
        expect((prop1 == bound[0]).value, isTrue);

        expect(prop2, bindableEquals(2));
        expect(prop2.propertyName, equals(1));
        expect((prop2 == bound[1]).value, isTrue);
    });

    test('Property bindables can be pinned when items are deleted', () {
        final bound = new BindableList([1, 2, 3]);
        final prop1 = bound[0];
        final prop2 = bound[1];
        final prop3 = bound[2];
        bound.removeAt(1);

        expect(prop1.value, equals(1));
        expect(prop1.propertyName, equals(0));
        expect(prop1.destroyed, isFalse);
        expect((prop1 == bound[0]).value, isTrue);

        expect(prop2.value, equals(null));
        expect(prop2.destroyed, isTrue);

        expect(prop3.value, equals(3));
        expect(prop3.propertyName, equals(1));
        expect(prop3.destroyed, isFalse);
        expect((prop3 == bound[1]).value, isTrue);
    });

    test('Property bindables can be unpinned when items are deleted', () {
        final bound = new BindableList([1, 2, 3, 4], pinProperties: false);
        final prop1 = bound[0];
        final prop2 = bound[1];
        final prop3 = bound[2];
        final prop4 = bound[3];
        bound.removeRange(1, 3);

        expect(prop1.value, equals(1));
        expect(prop1.propertyName, equals(0));
        expect(prop1.destroyed, isFalse);
        expect((prop1 == bound[0]).value, isTrue);

        expect(prop2.value, equals(4));
        expect(prop2.propertyName, equals(1));
        expect(prop2.destroyed, isFalse);
        expect((prop2 == bound[1]).value, isTrue);

        expect(prop3.value, equals(null));
        expect(prop3.destroyed, isTrue);

        expect(prop4.value, equals(null));
        expect(prop4.destroyed, isTrue);
    });

    test('Computed property nulls out when one of its dependencies is deleted', () {
        final bound = new BindableList([1, 2, 3]);
        bound[2] = bound[0] + bound[1];
        bound.removeAt(0);
        expect(bound[0].value, equals(2));
        expect(bound[1].value, equals(null));
    });

    test('Computed property is unaffected by items getting inserted', () {
        final bound = new BindableList([1, 2, 3]);
        bound[2] = bound[0] + bound[1];
        bound.insert(0, 0);
        bound.insert(2, 1.5);
        bound[1].value = 4;
        expect(bound[4].value, equals(6));
    });

    test('Child lists are converted to BindableList instances', () {
        final nested = new BindableList([[1, 2, 3], ['A', 'B', 'C'], 'YAY']);
        expect(nested[0].basis is BindableList, isTrue);
        expect(nested[1].basis is BindableList, isTrue);
        expect(nested[2].basis is BindableList, isFalse);
    });

    test('Changes from child lists bubble up to the parent list', () async {
        final nested = new BindableList([[1, 2, 3], ['A', 'B', 'C']]);
        var parentChangeFuture = nested.changeStream.first;
        nested[0][2] = 4;
        var parentChange = await parentChangeFuture;
        expect(parentChange.path, equals([0, 2]));
        expect(parentChange.baseChange.oldValue, equals(3));
        expect(parentChange.baseChange.newValue, equals(4));
        expect(nested[0][2].value, equals(4));
        expect(nested[0].value[2], equals(4));
        expect(nested.value[0][2], equals(4));

        parentChangeFuture = nested.changeStream.first;
        nested[0].add(8);
        parentChange = await parentChangeFuture;
        expect(parentChange.path, equals([0]));
        expect(parentChange.baseChange.startIndex, equals(3));
        expect(parentChange.baseChange.insertedCount, equals(1));
        expect(nested[0].length, bindableEquals(4));
        expect(nested[0][3].value, equals(8));
        expect(nested[0].value[3], equals(8));
        expect(nested.value[0][3], equals(8));
    });

    test('Inserting or removing values does not interfere with child lists', () async {
        final nested = new BindableList([[1, 2, 3]]);
        final sublist = nested[0];
        nested.insert(1, 'AFTER');
        nested.insert(0, 'BEFORE2');
        nested.insert(0, 'BEFORE1');

        final sublistChangeFuture = sublist.changeStream.first;
        nested[2].add(4);
        final sublistChange = await sublistChangeFuture;
        expect(sublistChange.startIndex, equals(3));
        expect(sublistChange.insertedCount, equals(1));

        nested.removeAt(0);
        final nestedChangeFuture = nested.changeStream.first;
        nested[1].add(5);
        final nestedChange = await nestedChangeFuture;
        expect(nestedChange.path, equals([1]));
        expect(nestedChange.baseChange.startIndex, equals(4));
        expect(nestedChange.baseChange.insertedCount, equals(1));
    });

    test('Values can be reduced', () {
        final list = new BindableList([1, 2, 3, 4]);
        final sum = list.reduce((val1, val2) => val1 + val2);
        expect(sum.value, equals(10));

        list.add(5);
        expect(sum.value, equals(15));

        list[0] = 0;
        expect(sum.value, equals(14));
    });

    test('Values can be joined into a bindable string', () {
        final list = new BindableList([1, 2, 3, 4]);
        final sum = list.join(', ');
        expect(sum.value, equals('1, 2, 3, 4'));

        list.add(5);
        expect(sum.value, equals('1, 2, 3, 4, 5'));

        list[0] = 0;
        expect(sum.value, equals('0, 2, 3, 4, 5'));

        list.clear();
        expect(sum.value, equals(''));
    });

    test('FixedLengthBindableLists can be changed', () {
        final fll = new FixedLengthBindableList([1, 2, 3, 4]);
        fll[1] = 1;
        expect(fll[1].value, equals(1));
        expect(fll.value[1], equals(1));
    });

    test('FixedBindableLists can not be changed', () {
        final fl = new FixedBindableList([1, 2, 3, 4]);
        bool threwError = false;
        try {
            fl[1] = 1;
        } catch (e) {
            threwError = true;
        }
        expect(threwError, isTrue);
    });

    test('BindableList can return a fixed bindable copy that stays up to date', () async {
        final list = new BindableList([1, 2, 3, 4]);
        final fixedCopy = list.fixedBindable;

        final fixedChangeFuture = fixedCopy.changeStream.first;
        list.add(5);
        final fixedChange = await fixedChangeFuture;
        expect(fixedChange is SpliceChangeRecord, isTrue);
        expect(fixedChange.startIndex, equals(4));
        expect(fixedCopy, bindableEquals([1, 2, 3, 4, 5]));
    });
}
