import 'package:matcher/matcher.dart';
import 'package:epoxy/epoxy.dart';

/// A matcher that unpacks bindables.
///
/// Very simple syntactic sugar that checks to see that the input is a bindable and compares
/// its current value to an expected value.
class BindableMatcher extends Matcher {
    final Matcher _valueMatcher;

    BindableMatcher(this._valueMatcher);

    bool matches(item, matchState) {
        return item is BaseBindable &&
               this._valueMatcher.matches(item.value, matchState);
    }

    Description describe(Description description) =>
      description.add('A Bindable with value ').addDescriptionOf(_valueMatcher);
}

Matcher bindableEquals(expected) => new BindableMatcher(equals(expected));
