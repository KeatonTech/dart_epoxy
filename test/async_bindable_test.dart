import 'dart:async';
import 'package:test/test.dart';
import 'package:epoxy/epoxy.dart';

void main() {
    test('Async bindables wait for a future to resolve to change their value', () async {
        Completer<int> computeCompleter = new Completer();
        var inputBindable = new Bindable(0);
        var asyncComputed = new AsyncComputedBindable(
            [inputBindable], (input) => computeCompleter.future);
        expect(asyncComputed.value, equals(null));

        var onChange = asyncComputed.changeStream.first.then((change) {
            expect(change is ValueChangeRecord, isTrue);
            expect(change.newValue, equals(4));
        });

        inputBindable.value = 2;
        computeCompleter.complete(4);
        await onChange;
    });

    test('Async bindables can cancel futures when inputs change', () async {
        int completerIndex = 0;
        Completer<int> completer1 = new Completer();
        Completer<int> completer2 = new Completer();

        var inputBindable = new Bindable(0);
        var asyncComputed = new AsyncComputedBindable(
            [inputBindable], (input) {
                if (completerIndex == 0) {
                    completerIndex = 1;
                    return completer1.future;
                } else {
                    return completer2.future;
                }
            });

        var onChange = asyncComputed.changeStream.first.then((change) {
            expect(change is ValueChangeRecord, isTrue);
            expect(change.newValue, equals(8));
        });

        inputBindable.value = 2;
        inputBindable.value = 4;
        completer2.complete(8);
        completer1.complete(4);
        await onChange;
    });

    test('Async bindables can respond to future values as they come in', () async {
        int completerIndex = 0;
        Completer<int> completer1 = new Completer();
        Completer<int> completer2 = new Completer();

        var inputBindable = new Bindable(0);
        var asyncComputed = new AsyncComputedBindable(
            [inputBindable], (input) {
                if (completerIndex == 0) {
                    completerIndex = 1;
                    return completer1.future;
                } else {
                    return completer2.future;
                }
            }, cancelInterruptedFutures: false, maintainOrdering: false);

        var onChange = asyncComputed.changeStream.first.then((change) {
            expect(change is ValueChangeRecord, isTrue);
            expect(change.newValue, equals(8));
            return asyncComputed.changeStream.first;
        }).then((change) {
            expect(change is ValueChangeRecord, isTrue);
            expect(change.newValue, equals(4));
        });

        inputBindable.value = 2;
        inputBindable.value = 4;
        completer2.complete(8);
        completer1.complete(4);
        await onChange;
    });

    test('Async bindables can respond to future values in strict order', () async {
        int completerIndex = 0;
        Completer<int> completer1 = new Completer();
        Completer<int> completer2 = new Completer();

        var inputBindable = new Bindable(0);
        var asyncComputed = new AsyncComputedBindable(
            [inputBindable], (input) {
                if (completerIndex == 0) {
                    completerIndex = 1;
                    return completer1.future;
                } else {
                    return completer2.future;
                }
            }, cancelInterruptedFutures: false, maintainOrdering: true);

        var onChange = asyncComputed.changeStream.first.then((change) {
            expect(change is ValueChangeRecord, isTrue);
            expect(change.newValue, equals(4));
            return asyncComputed.changeStream.first;
        }).then((change) {
            expect(change is ValueChangeRecord, isTrue);
            expect(change.newValue, equals(8));
        });

        inputBindable.value = 2;
        inputBindable.value = 4;
        completer2.complete(8);
        completer1.complete(4);
        await onChange;
    });
}
