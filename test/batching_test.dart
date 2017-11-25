import 'dart:async';
import 'package:test/test.dart';
import 'package:epoxy/epoxy.dart';
import './util/util.dart';

void main() {
    test('Batching collapses repeated changes on one bindable', () async {
        var bindable = new Bindable(5);

        int changeCount = 0;
        bindable.changeStream.listen((change) => changeCount++);

        Epoxy.batchChanges(() {
            bindable.value = -10;
            bindable.value = 10;
        });
        expect(changeCount, equals(1));
    });

    test('Batching sends no changes if the value reverts to the original value', () async {
        var bindable = new Bindable(5);

        int changeCount = 0;
        bindable.changeStream.listen((change) => changeCount++);

        Epoxy.batchChanges(() {
            bindable.value = -10;
            bindable.value = 5;
        });
        expect(changeCount, equals(0));
    });

    test('ValueChangeRecords from batching have the correct OldValue set', () async {
        var bindable = new Bindable(5);

        int changeCount = 0;
        bindable.changeStream.listen((change) {
            changeCount++;
            expect(change.newValue, equals(10));
            expect(change.oldValue, equals(5));
        });

        Epoxy.batchChanges(() {
            bindable.value = -10;
            bindable.value = 10;
        });
        expect(changeCount, equals(1));
    });

    test('Batching reduces re-computations on ComputedBindables', () async {
        var valueOne = new Bindable(5);
        var valueTwo = new Bindable(10);
        var computed = new PerformanceMonitoringBindable([valueOne, valueTwo], (a, b) {
            return a + b;
        });
        expect(computed.value, equals(15));

        computed.resetMonitoring();
        valueOne.value = 1;
        valueTwo.value = 11;
        expect(computed.value, equals(12));
        expect(computed.computationCount, equals(2));

        computed.resetMonitoring();
        Epoxy.batchChanges(() {
            valueOne.value = -10;
            valueTwo.value = 10;
        });
        expect(computed.value, equals(0));
        expect(computed.computationCount, equals(1));
    });

    test('Batching reduces re-computations on deeply nested ComputedBindables', () async {
        final fibonacci = new BindableList([1, 1]);
        for (var i = 0; i < 10; i++) fibonacci.add(
            new PerformanceMonitoringBindable(
                [fibonacci[i], fibonacci[i + 1]], (o, t) => o + t));

        fibonacci[10].resetMonitoring();
        fibonacci[11].resetMonitoring();
        Epoxy.batchChanges(() {
            fibonacci[0] = 1;
            fibonacci[1] = 2;
        });
        expect(fibonacci[10].value, equals(144));
        expect(fibonacci[10].computationCount, equals(1));
        expect(fibonacci[11].value, equals(233));
        expect(fibonacci[11].computationCount, equals(2));
    });
}
