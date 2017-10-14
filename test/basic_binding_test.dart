import 'dart:async';
import 'package:test/test.dart';
import 'package:epoxy/base.dart';

void main() {
    test('Bindables can be set', () async {
        final bindable = new Bindable(4);
        expect(bindable.value, equals(4));

        final futureRead = bindable.changeStream.first;
        bindable.value = 5;
        expect(bindable.value, equals(5));

        final change = await futureRead;
        expect(change is ValueChangeRecord, isTrue);
        expect(change.oldValue, equals(4));
        expect(change.newValue, equals(5));
    });

    test('ComputedBindables update when their dependencies update', () async {
        final value1 = new Bindable(4);
        final value2 = new Bindable(10);
        final computed = new ComputedBindable([value1, value2], (one, two) => one * two);

        expect(computed.value, equals(40));
        var changeCount = 0;
        computed.changeStream.forEach((change){changeCount++;});

        final futureChange1 = computed.changeStream.first;
        value1.value = 2;
        final change1 = await futureChange1;
        expect(change1.newValue, equals(20));

        final futureChange2 = computed.changeStream.first;
        value2.value = 0;
        final change2 = await futureChange2;
        expect(change2.newValue, equals(0));
        expect(changeCount, equals(2));

        await new Future.delayed(new Duration(milliseconds: 10));
        expect(changeCount, equals(2));
    });

    test('ComputedBindables can be created by adding bindables', () {
        final computed1 = new Bindable(4) + 5;
        expect(computed1 is ComputedBindable, isTrue);
        expect(computed1.value, equals(9));

        final computed2 = new Bindable(1) + new Bindable(1);
        expect(computed2 is ComputedBindable, isTrue);
        expect(computed2.value, equals(2));

        final computed3 = new Const(44) + new Bindable(55);
        expect(computed3 is ComputedBindable, isTrue);
        expect(computed3.value, equals(99));

        final computed4 = new Const(-5) + new Const(5);
        expect(computed4 is Const, isTrue);
        expect(computed4.value, equals(0));
    });

    test('ComputedBindables can themselves be added', () async {
        final bindableA = new Bindable(4);
        final bindableB = new Bindable(6);
        final computed1 = bindableA + new Const(5);
        final computed2 = bindableB + new Const(1);
        final metaComputed = computed1 + computed2;

        expect(metaComputed is ComputedBindable, isTrue);
        expect(metaComputed.value, equals(16));

        final change1 = metaComputed.changeStream.first;
        bindableA.value = 8;
        await change1;

        expect(metaComputed.value, equals(20));
    });

    test('ComputedBindables can be created by comparing bindables', () {
        final bindableA = new Bindable(4);
        final computed1 = bindableA > new Bindable(5);
        expect(computed1 is ComputedBindable, isTrue);
        expect(computed1.value, isFalse);
        bindableA.value = 6;
        expect(computed1.value, isTrue);

        final computed2 = new Const(3) <= bindableA;
        expect(computed2 is ComputedBindable, isTrue);
        expect(computed2.value, isTrue);
        bindableA.value = 3;
        expect(computed2.value, isTrue);
        bindableA.value = 2;
        expect(computed2.value, isFalse);
    });

    test('ComputedBindables null out when one of their dependencies is destroyed', () {
        final dependency = new Bindable(4);
        final computed1 = dependency + 5;
        expect(computed1.value, equals(9));

        dependency.destroy();
        expect(computed1.value, equals(null));
    });

    test('Bindables print nicely', () async {
        final bindable = new Bindable(4);
        expect(bindable.toString(), equals('[Bindable with current value: 4]'));

        final computed = bindable * 2;
        expect(computed.toString(), equals('[ComputedBindable with current value: 8]'));
    });
 }
