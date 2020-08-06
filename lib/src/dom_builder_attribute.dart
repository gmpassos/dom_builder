import 'dart:collection';

import 'package:swiss_knife/swiss_knife.dart';

import 'dom_builder_base.dart';
import 'dom_builder_css.dart';
import 'dom_builder_helpers.dart';

class DOMAttribute implements WithValue {
  static final Set<String> _ATTRIBUTES_VALUE_AS_BOOLEAN = {'checked', 'hidden'};
  static final Set<String> _ATTRIBUTES_VALUE_AS_SET = {'class'};

  static final Map<String, Pattern> _ATTRIBUTES_VALUE_AS_LIST_DELIMITERS = {
    'class': ' ',
    'style': '; '
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

  static String normalizeName(String name) {
    if (name == null) return null;
    return name.trim().toLowerCase();
  }

  final String name;

  final DOMAttributeValue _valueHandler;

  DOMAttribute(this.name, this._valueHandler);

  factory DOMAttribute.from(String name, dynamic value) {
    name = normalizeName(name);
    if (name == null) return null;

    if (name == 'style') {
      return DOMAttribute(name, DOMAttributeValueCSS(value));
    }

    var delimiter = _ATTRIBUTES_VALUE_AS_LIST_DELIMITERS[name];

    if (delimiter != null) {
      var delimiterPattern =
          _ATTRIBUTES_VALUE_AS_LIST_DELIMITERS_PATTERNS[name];
      assert(delimiterPattern != null);

      var attrSet = _ATTRIBUTES_VALUE_AS_SET.contains(name);

      if (attrSet) {
        return DOMAttribute(
            name, DOMAttributeValueSet(value, delimiter, delimiterPattern));
      } else {
        return DOMAttribute(
            name, DOMAttributeValueList(value, delimiter, delimiterPattern));
      }
    } else {
      var attrBoolean = _ATTRIBUTES_VALUE_AS_BOOLEAN.contains(name);

      if (attrBoolean) {
        if (value != null) {
          return DOMAttribute(name, DOMAttributeValueBoolean(value));
        }
        return null;
      } else {
        return DOMAttribute(name, DOMAttributeValueString(value));
      }
    }
  }

  DOMAttributeValue get valueHandler => _valueHandler;

  bool get isBoolean => _valueHandler is DOMAttributeValueBoolean;

  bool get isList => _valueHandler is DOMAttributeValueList;

  bool get isSet => _valueHandler is DOMAttributeValueSet;

  bool get isCollection => isList || isSet;

  @override
  bool get hasValue => _valueHandler.hasAttributeValue;

  @override
  String get value => _valueHandler.asAttributeValue;

  List<String> get values => _valueHandler.asAttributeValues;

  bool containsValue(dynamic value) =>
      _valueHandler.containsAttributeValue(value);

  void setBoolean(dynamic value) {
    if (!isBoolean) throw StateError('Not a boolean attribute');
    setValue(value);
  }

  void setValue(dynamic value) => _valueHandler.setAttributeValue(value);

  void appendValue(dynamic value) => _valueHandler.appendAttributeValue(value);

  String buildHTML() {
    if (isBoolean) {
      return _valueHandler.hasAttributeValue ? name : '';
    }

    var htmlValue = _valueHandler.asAttributeValue;

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
    return 'DOMAttribute{name: $name, _value: $_valueHandler}';
  }
}

abstract class DOMAttributeValue {
  String get asAttributeValue;

  List<String> get asAttributeValues;

  bool get hasAttributeValue;

  bool containsAttributeValue(String value);

  void setAttributeValue(dynamic value);

  void appendAttributeValue(dynamic value) => setAttributeValue(value);

  @override
  String toString();
}

class DOMAttributeValueBoolean extends DOMAttributeValue {
  bool _value;

  DOMAttributeValueBoolean(dynamic value) : _value = parseBool(value, false);

  @override
  bool get hasAttributeValue => _value;

  @override
  String get asAttributeValue => _value.toString();

  @override
  List<String> get asAttributeValues => [asAttributeValue];

  @override
  bool containsAttributeValue(String value) {
    return _value == parseBool(value, false);
  }

  @override
  void setAttributeValue(dynamic value) {
    _value = parseBool(value, false);
  }

  @override
  String toString() {
    return 'DOMAttributeValueBoolean{_value: $_value}';
  }
}

class DOMAttributeValueString extends DOMAttributeValue {
  String _value;

  DOMAttributeValueString(dynamic value) : _value = parseString(value, '');

  @override
  bool get hasAttributeValue => _value != null && _value.isNotEmpty;

  @override
  String get asAttributeValue => hasAttributeValue ? _value.toString() : null;

  @override
  List<String> get asAttributeValues =>
      hasAttributeValue ? [asAttributeValue] : null;

  @override
  bool containsAttributeValue(String value) {
    return hasAttributeValue && _value == value;
  }

  @override
  void setAttributeValue(dynamic value) {
    _value = parseString(value);
  }

  @override
  String toString() {
    return 'DOMAttributeValueString{_value: $_value}';
  }
}

class DOMAttributeValueList extends DOMAttributeValue {
  List<String> _values;
  final String delimiter;
  final Pattern delimiterPattern;

  DOMAttributeValueList(dynamic values, this.delimiter, this.delimiterPattern) {
    if (delimiter == null) throw ArgumentError.notNull('delimiter');
    if (delimiterPattern == null) {
      throw ArgumentError.notNull('delimiterPattern');
    }
    _values = parseListOfStrings(values, delimiterPattern) ?? <String>[];
  }

  @override
  bool get hasAttributeValue {
    if (_values != null && _values.isNotEmpty) {
      if (_values.length == 1) {
        return _values[0].isNotEmpty;
      } else {
        return true;
      }
    }
    return false;
  }

  @override
  String get asAttributeValue => hasAttributeValue
      ? (_values.length == 1 ? _values[0] : _values.join(delimiter))
      : null;

  @override
  List<String> get asAttributeValues => hasAttributeValue ? _values : null;

  @override
  bool containsAttributeValue(String value) {
    return hasAttributeValue && _values.contains(value);
  }

  @override
  void setAttributeValue(dynamic value) {
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
  }

  @override
  void appendAttributeValue(value) {
    var s = parseString(value);
    if (s != null) {
      _values ??= [];
      _values.add(s);
    }
  }

  @override
  String toString() {
    return 'DOMAttributeValueList{_values: $_values, delimiter: $delimiter, delimiterPattern: $delimiterPattern}';
  }
}

class DOMAttributeValueSet extends DOMAttributeValue {
  LinkedHashSet<String> _values;
  final String delimiter;
  final Pattern delimiterPattern;

  DOMAttributeValueSet(dynamic values, this.delimiter, this.delimiterPattern) {
    if (delimiter == null) throw ArgumentError.notNull('delimiter');
    if (delimiterPattern == null) {
      throw ArgumentError.notNull('delimiterPattern');
    }
    _values = Set<String>.from(parseListOfStrings(values, delimiterPattern)) ??
        <String>{};
  }

  @override
  bool get hasAttributeValue {
    if (_values != null && _values.isNotEmpty) {
      if (_values.length == 1) {
        return _values.first.isNotEmpty;
      } else {
        return true;
      }
    }
    return false;
  }

  @override
  String get asAttributeValue => hasAttributeValue
      ? (_values.length == 1 ? _values.first : _values.join(delimiter))
      : null;

  @override
  List<String> get asAttributeValues =>
      hasAttributeValue ? _values.toList() : null;

  @override
  bool containsAttributeValue(String value) {
    return hasAttributeValue && _values.contains(value);
  }

  @override
  void setAttributeValue(dynamic value) {
    var valuesList = parseListOfStrings(value, delimiterPattern);

    if (valuesList == null || valuesList.isEmpty) {
      // ignore: prefer_collection_literals
      _values = LinkedHashSet();
    } else {
      _values = Set<String>.from(valuesList);
    }
  }

  @override
  void appendAttributeValue(value) {
    var s = parseString(value);
    if (s != null) {
      // ignore: prefer_collection_literals
      _values ??= LinkedHashSet();
      _values.add(s);
    }
  }

  @override
  String toString() {
    return 'DOMAttributeValueSet{_values: $_values, delimiter: $delimiter, delimiterPattern: $delimiterPattern}';
  }
}

class DOMAttributeValueCSS extends DOMAttributeValue {
  CSS _css;

  DOMAttributeValueCSS(dynamic values) {
    _css = CSS(values);
  }

  CSS get css => _css;

  @override
  bool get hasAttributeValue => _css.isNoEmpty;

  @override
  String get asAttributeValue => hasAttributeValue ? _css.toString() : null;

  @override
  List<String> get asAttributeValues => _css.entriesAsString;

  @override
  bool containsAttributeValue(String value) =>
      _css.entriesAsString.contains(value);

  @override
  void setAttributeValue(dynamic value) {
    _css = CSS(value);
  }

  @override
  void appendAttributeValue(value) {
    var entries = CSS(value).entries;
    if (entries.isEmpty) return;

    var entry = entries.first;
    _css.put(entry.name, entry);
  }

  @override
  String toString() {
    return 'DOMAttributeValueCSS{_css: $_css}';
  }
}
