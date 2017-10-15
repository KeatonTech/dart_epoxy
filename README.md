# Epoxy
### The reactive glue for Dart

> Epoxy is a small library that enables fully reactive programming in Dart using native syntax that blends in with the rest of the language. The goal of Epoxy is to help you build robust data models that are compact and intuitively understandable, which can then serve as the backbone of your entire app. With reactive programming, everything is built around the data itself, not events or callbacks or run loops.  

### What is reactive programming?
You can think of reactive programming like an Excel spreadsheet: Some cells contain raw data and others are calculated values that update automatically when any of their input cells change. For example, you can add in a list of all your monthly expenses and then set another cell to display the sum total of all of them, to help you budget. When you add, change, or remove an expense, the sum total automatically updates with it. Your spreadsheet, which is a simple data model of sorts, will always be internally consistent.

Put in programming terms: Reactive programming explicitly models not just raw values but also the relationships between them. This makes your code shorter and more declarative by eliminating glue code (e.g. ‘Add a new expense and then re-calculate the sum variable and then tell the UI to update’) and replacing it with a graph of dependencies (e.g. ‘The UI depends on the sum which depends on the expenses’). The graph can change dynamically such that each node has only the dependencies it actually needs at any given time, which means that not only will your reactive code be shorter and more robust, it will often also be faster!

### Why Epoxy?
Reactive programming is probably familiar to most frontend engineers. Facebook’s React framework is an obvious example of it — as are most other JavaScript UI frameworks, from Knockout to Polymer. These work great for the inner workings of the UI layer but still interface with the backend code through old-fashioned imperative glue code. This is the reason why things like Redux and Immutable.js were invented — to cut back on the tangled mess of buggy code that goes between the reactive data model in your view and the imperative data model in the rest of your app.

But, wait a minute, why do we have two different models in the first place? Why not write backend code that uses the same reactive data model as the frontend, and then just plug it in directly?

Epoxy is not a UI framework but rather a common standard on which many different frameworks can be built. An Epoxy-based database wrapper could output Epoxy objects that can be plugged directly into an Epoxy-based UI framework. Then, whenever the database updates, the view automatically updates with it, and vice versa! Epoxy is not a platform or a mindset or a specific way of building an app — it is simply the reactive glue (get it?) that binds all of the different components together. What those components are and how they work is up to you.

### Some Code Examples

Create a computed variable by adding bindables:
```dart
final bindableA = new Bindable(4);
final bindableB = bindableA + 10;
expect(bindableB.value, equals(14));

bindableA.value = 10;
expect(bindableB.value, equals(20));
```

Keep a running total of items in a list:
```dart
final expenses = new BindableList([1, 2, 3, 4]);
final sum = expenses.reduce((val1, val2) => val1 + val2);
expect(sum.value, equals(10));

expenses.add(5);
expect(sum.value, equals(15));

expenses[0] = 0;
expect(sum.value, equals(14));
```

Maintain a dynamic selection from a list:
```dart
final letters = new BindableList(['A', 'B', 'C', 'D', 'E']);
final selectedIndex = new Bindable(0);
final selection = letters[selectedIndex];
expect(selection, bindableEquals('A'));

selectedIndex.value = 2;
expect(selection, bindableEquals('C'));
```

Create a bindable version of a struct class:
```dart
class RoughLocation {
    int latitude;
    int longitude;
    LocationStruct(this.latitude, this.longitude);
}

final bindableLocation = new BindableStruct<RoughLocation>(-50, 45);
expect(bindableLocation.latitude, equals(-50));

// Prefixing property names with a '$' returns the bindable instance, which is helpful for
// making things like computed properties. Otherwise the properties of the BindableStruct
// class match those of the base struct.
bindableLocation.longitude = bindableLocation.$latitude * 2;
expect(bindableLocation.longitude, equals(-100));

bindableLocation.latitude = 15;
expect(bindableLocation.longitude, equals(30));
```

Similarly, you can create your own custom bindable classes with more functionality:
```dart
class BindableLocation extends BindableObject {
    // This bindable will be published as this.latitude, with getters and setters to track
    // changes. The $ prefix is a convention, not a rule. The only hard rule is that the
    // name of the bindable property must be different from its published name ('latitude').
    final $latitude = new PropertyBindable('latitude', 100);
    final $longitude = new PropertyBindable('longitude', 50);
}

final bindableLocation = new BindableLocation();
expect(bindableLocation.latitude, equals(100));
expect(bindableLocation.longitude, equals(50));
```

Generate a reactive version of the fibonacci sequence:
```dart
final fibonacci = new BindableList([1, 1]);
for (var i = 0; i < 10; i++) fibonacci.add(fibonacci[i] + fibonacci[i + 1]);
expect(fibonacci.value, equals([1, 1, 2, 3, 5, 8, 13, 21, 34, 55, 89, 144]));

fibonacci[0] = 2;
fibonacci[1] = 2;
expect(fibonacci.value, equals([2, 2, 4, 6, 10, 16, 26, 42, 68, 110, 178, 288]));
```

Automatically make everything awesome:
```dart
final stuffList = new BindableList(['Dart', 'Epoxy']);
final awesomeList = stuffList.map((item) => item + ' is awesome!');
expect(awesomeList[0].value, equals('Dart is awesome!'));

stuffList.add('Reactive Programming')
expect(awesomeList[2].value, equals('Reactive Programming is awesome!'));
```

### Testing

Unit tests can be run with `pub run test`
