import 'package:swiss_knife/swiss_knife.dart';

import 'dom_builder_base.dart';
import 'dom_builder_helpers.dart';

class DOMAttribute implements WithValue {
  static final Set<String> _ATTRIBUTES_VALUE_AS_BOOLEAN = {'checked', 'hidden'};
  static final Set<String> _ATTRIBUTES_VALUE_AS_SET = {'class'};

  static final Map<String, Pattern> _ATTRIBUTES_VALUE_AS_LIST_DELIMITERS = {
    'class': ' ',
    'style': ';'
  };

  static final Map<String, Pattern>
      _ATTRIBUTES_VALUE_AS_LIST_DELIMITERS_PATTERNS = {
    'class': RegExp(r'\s+'),
    'style': RegExp(r'\s*;\s*')
  };

  static bool hasAttribute(DOMAttribute attribute) =>
      attribute != null && attribute.hasValue;

  static bool hasAttributes(Map<String, DOMAttribute> attributes) =>
      attributes != null && attributes.isNotEmpty;

  final String name;

  String _value;
  List<String> _values;

  final String delimiter;
  final Pattern delimiterPattern;

  bool _valueBoolean;
  final bool _set;

  DOMAttribute(String name,
      {dynamic value,
      List values,
      this.delimiter,
      this.delimiterPattern,
      dynamic set,
      dynamic valueBoolean})
      : name = name.toLowerCase().trim(),
        _value = parseString(value),
        _values = parseListOfStrings(values),
        _set = parseBool(set, false),
        _valueBoolean = parseBool(valueBoolean) {
    if (_value != null && _values != null) {
      throw ArgumentError(
          'Attribute $name: Only value or values can be defined, not both.');
    }
    if (_valueBoolean != null && (_value != null || _values != null)) {
      throw ArgumentError(
          "Attribute $name: Boolean attribute doesn't have value.");
    }
    if (_values != null && delimiter == null) {
      throw ArgumentError(
          'Attribute $name: If values is defined, a delimiter is required.');
    }
    if (_value != null && delimiter != null) {
      throw ArgumentError(
          'Attribute $name: If value is defined, delimiter should be null.');
    }

    if (_set) {
      if (!isListValue) {
        throw ArgumentError(
            'Attribute $name: If is a set, it should be a list value.');
      }

      _uniquifyValues();
    }
  }

  factory DOMAttribute.from(String name, dynamic value) {
    var delimiter = _ATTRIBUTES_VALUE_AS_LIST_DELIMITERS[name];

    if (delimiter != null) {
      var delimiterPattern =
          _ATTRIBUTES_VALUE_AS_LIST_DELIMITERS_PATTERNS[name];
      assert(delimiterPattern != null);

      var attrSet = _ATTRIBUTES_VALUE_AS_SET.contains(name);

      return DOMAttribute(name,
          values: parseListOfStrings(value, delimiterPattern),
          delimiter: delimiter,
          delimiterPattern: delimiterPattern,
          set: attrSet);
    } else {
      var attrBoolean = _ATTRIBUTES_VALUE_AS_BOOLEAN.contains(name);

      if (attrBoolean) {
        if (value != null) {
          return DOMAttribute(name, valueBoolean: value);
        }
        return null;
      } else {
        return DOMAttribute(name, value: value);
      }
    }
  }

  bool get isBoolean => _valueBoolean != null;

  bool get isListValue => delimiter != null;

  bool get isSet => _set;

  @override
  bool get hasValue {
    if (isBoolean) return _valueBoolean;

    if (isListValue) {
      if (isNotEmptyObject(_values)) {
        if (_values.length == 1) {
          return _values[0].isNotEmpty;
        } else {
          return true;
        }
      }
      return false;
    } else {
      return isNotEmptyObject(_value);
    }
  }

  @override
  String get value {
    if (isBoolean) return _valueBoolean.toString();

    if (isListValue) {
      if (isNotEmptyObject(_values)) {
        if (_values.length == 1) {
          return _values[0];
        } else {
          return _values.join(delimiter);
        }
      }
    } else if (isNotEmptyObject(_value)) {
      return _value;
    }

    return null;
  }

  List<String> get values {
    if (isBoolean) return [_valueBoolean.toString()];

    if (isListValue) {
      if (isNotEmptyObject(_values)) {
        return _values;
      }
    } else {
      if (isNotEmptyObject(_value)) {
        return [_value];
      }
    }

    return null;
  }

  bool containsValue(String v) {
    if (isBoolean) {
      v ??= 'false';
      return _valueBoolean.toString() == v;
    }

    if (isListValue) {
      if (isNotEmptyObject(_values)) {
        return _values.contains(v);
      }
    } else {
      if (isNotEmptyObject(_value)) {
        return _value == v;
      }
    }

    return false;
  }

  void setBoolean(dynamic value) {
    _valueBoolean = parseBool(value, false);
  }

  void setValue(dynamic value) {
    if (isBoolean) {
      setBoolean(value);
      return;
    }

    if (isListValue) {
      var valuesList = parseListOfStrings(value, delimiterPattern);

      if (valuesList == null || valuesList.isEmpty) {
        _values = [];
      } else if (_values != null &&
          _values.length == 1 &&
          valuesList.length == 1) {
        _values[0] = parseString(valuesList[0]);
      } else {
        _values = valuesList;
      }
    } else {
      _value = parseString(value);
    }
  }

  void appendValue(value) {
    if (!isListValue) {
      setValue(value);
      return;
    }

    var s = parseString(value);
    if (s != null) {
      _values ??= [];
      _values.add(s);

      if (isSet) {
        _uniquifyValues();
      }
    }
  }

  void _uniquifyValues() {
    if (_values == null) return;

    for (var i = 0; i < _values.length;) {
      var val1 = _values[i];

      var duplicated = false;
      for (var j = i + 1; j < _values.length; j++) {
        var val2 = _values[j];
        if (val1 == val2) {
          duplicated = true;
          break;
        }
      }

      if (duplicated) {
        _values.removeAt(i);
      } else {
        i++;
      }
    }
  }

  String buildHTML() {
    if (isBoolean) {
      return _valueBoolean ? name : '';
    }

    var htmlValue = value;

    if (htmlValue != null) {
      var html = '$name=';
      html += htmlValue.contains('"') ? "'$htmlValue'" : '"$htmlValue"';
      return html;
    } else {
      return '';
    }
  }

  @override
  String toString() {
    return 'DOMAttribute{name: $name, _value: $_value, _values: $_values, delimiter: $delimiter, _valueBoolean: $_valueBoolean}';
  }
}
