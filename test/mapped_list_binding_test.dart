import 'dart:math';
import 'package:test/test.dart';
import 'package:epoxy/epoxy.dart';
import 'package:epoxy/testing.dart';

void main() {
    test('Mapping BindableList produces valid results', () {
        final original = new BindableList([1, 2, 3, 4, 5]);
        final mapped = original.map((item) => pow(2, item));
        expect(mapped.length, bindableEquals(5));

        expect(mapped[0].value, equals(2));
        expect(mapped.value[0], equals(2));

        expect(mapped[4].value, equals(32));
        expect(mapped.value[4], equals(32));
    });

    test('Mapped lists expand with their basis list', () {
        final original = new BindableList([1, 2, 3, 4, 5]);
        final mapped = original.map((item) => pow(2, item));

        original.add(6);
        expect(mapped.length, bindableEquals(6));
        expect(mapped[5].value, equals(64));
        expect(mapped.value[5], equals(64));

        original.insert(0, 0);
        expect(mapped.length, bindableEquals(7));
        expect(mapped[0].value, equals(1));
        expect(mapped.value[0], equals(1));
    });

    test('Mapped lists contract with their basis list', () {
        final original = new BindableList([1, 2, 3, 4, 5]);
        final mapped = original.map((item) => pow(2, item));
        original.removeAt(0);

        expect(mapped.length, bindableEquals(4));
        expect(mapped[0].value, equals(4));
        expect(mapped.value[0], equals(4));
    });

    test('MappedList map functions can be changed at runtime', () {
        final original = new BindableList([1, 2, 3, 4, 5]);
        final mapped = original.map((item) => pow(2, item));
        final lastItem = mapped[4];
        expect(lastItem.value, equals(32));
        mapped.mapFunction = (item) => item * item;
        expect(lastItem.value, equals(25));
        expect(mapped.value, equals([1, 4, 9, 16, 25]));
    });

    test('Mapped lists cannot be directly modified', () {
        final original = new BindableList([1, 2, 3, 4, 5]);
        final mapped = original.map((item) => pow(2, item));
        bool threwError = false;
        try {
            mapped[0] = 3;
        } catch (e) {
            threwError = true;
        }
        expect(threwError, isTrue);
    });

    test('Mapped lists map value changes in their changeStream', () async {
        final original = new BindableList([1, 2, 3, 4, 5]);
        final mapped = original.map((item) => pow(2, item));
        expect(mapped[0].value, equals(2));

        final valueChangeFuture = mapped.changeStream.first;
        original[4] = 8;
        final valueChange = await valueChangeFuture;
        expect(valueChange is PropertyChangeRecord, isTrue);
        expect(valueChange.baseChange is ValueChangeRecord, isTrue);
        expect(valueChange.baseChange.newValue, equals(256));
    });

    test('Mapped lists collapse deep property changes', () async {
        final original = new BindableList([[1, 2, 3], ['A', 'B', 'C']]);
        final mapped = original.map((list) => list[0].toString());
        expect(mapped[0].value, equals('1'));

        final valueChangeFuture = mapped.changeStream.first;
        original[0].insert(0, 0);
        final valueChange = await valueChangeFuture;
        expect(valueChange is PropertyChangeRecord, isTrue);
        expect(valueChange.path, equals([0]));
        expect(mapped[0].value, equals('0'));
    });

    test('Mapped list property bindables change with values in the original list', () async {
        final original = new BindableList([1, 2, 3, 4, 5], pinProperties: false);
        final mapped = original.map((item) => pow(2, item));
        final firstValue = mapped[4];
        expect(mapped[0].value, equals(2));

        final valueChangeFuture = firstValue.changeStream.first;
        original[4] = 10;
        final valueChange = await valueChangeFuture;
        expect(valueChange is ValueChangeRecord, isTrue);
        expect(valueChange.newValue, equals(1024));
        expect(firstValue.value, equals(1024));
    });

    test('Mapped list properties can stay pinned', () async {
        final original = new BindableList([1, 2, 3, 4, 5], pinProperties: true);
        final mapped = original.map((item) => pow(2, item));
        final firstValue = mapped[0];
        expect(mapped[0].value, equals(2));

        original.insert(0, 0);
        expect(firstValue.value, equals(2));
    });

    test('Mapped list properties can shift when not pinned', () async {
        final original = new BindableList([1, 2, 3, 4, 5], pinProperties: false);
        final mapped = original.map((item) => pow(2, item));
        final firstValue = mapped[0];
        expect(mapped[0].value, equals(2));

        final valueChangeFuture = firstValue.changeStream.first;
        original.insert(0, 0);
        final valueChange = await valueChangeFuture;
        expect(valueChange is ValueChangeRecord, isTrue);
        expect(valueChange.newValue, equals(1));
        expect(firstValue.value, equals(1));
    });

    test('Mapped lists can be used with reduced values', () {
        final original = new BindableList([[1, 2, 3], [4, 5, 6], [7, 8, 9]]);
        final sums = original.map((list) => list.reduce((acc, val) => acc + val));
        expect(sums.value, equals([6, 15, 24]));

        original.add([10, 11, 12]);
        expect(sums.value, equals([6, 15, 24, 33]));

        original[0].removeAt(1);
        expect(sums.value, equals([4, 15, 24, 33]));
    });

    test('Bound maps are tied to other bindables', () {
        final multiplicand = new Bindable(5);
        final original = new BindableList([1, 2, 3, 4, 5]);
        final mapped = original.boundMap([multiplicand], (item, mult) => mult * item);
        expect(mapped.length, bindableEquals(5));

        expect(mapped[1].value, equals(10));
        expect(mapped.value[1], equals(10));

        multiplicand.value = 10;
        expect(mapped[1].value, equals(20));
        expect(mapped.value[1], equals(20));
    });
}
