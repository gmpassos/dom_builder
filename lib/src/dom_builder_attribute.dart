import 'dart:collection';

import 'package:dom_builder/dom_builder.dart';
import 'package:swiss_knife/swiss_knife.dart';

import 'dom_builder_base.dart';
import 'dom_builder_css.dart';
import 'dom_builder_helpers.dart';

/// Represents a [DOMElement] attribute entry (`name` and [DOMAttributeValue]).
class DOMAttribute implements WithValue {
  static final Set<String> _ATTRIBUTES_VALUE_AS_BOOLEAN = {'checked', 'hidden'};
  static final Set<String> _ATTRIBUTES_VALUE_AS_SET = {'class'};

  static final Map<String, Pattern> _ATTRIBUTES_VALUE_AS_LIST_DELIMITERS = {
    'class': ' ',
    'style': '; '
  };

  static String getAttributeDelimiter(String name) =>
      _ATTRIBUTES_VALUE_AS_LIST_DELIMITERS[name];

  static final Map<String, Pattern>
      _ATTRIBUTES_VALUE_AS_LIST_DELIMITERS_PATTERNS = {
    'class': RegExp(r'\s+'),
    'style': RegExp(r'\s*;\s*')
  };

  static RegExp getAttributeDelimiterPattern(String name) =>
      _ATTRIBUTES_VALUE_AS_LIST_DELIMITERS_PATTERNS[name];

  static bool hasAttribute(DOMAttribute attribute) =>
      attribute != null && attribute.hasValue;

  static bool hasAttributes(Map<String, DOMAttribute> attributes) =>
      attributes != null && attributes.isNotEmpty;

  static String normalizeName(String name) {
    if (name == null) return null;
    return name.trim().toLowerCase();
  }

  static String append(String s, String delimiter, DOMAttribute attribute,
      [DOMContext domContext]) {
    if (attribute == null) return s;
    var append = attribute.buildHTML(domContext);
    if (append == null || append.isEmpty) return s;
    return s + delimiter + append;
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

  bool get isCollection => _valueHandler is DOMAttributeValueCollection;

  @override
  bool get hasValue => _valueHandler.hasAttributeValue;

  @override
  String get value => _valueHandler.asAttributeValue;

  List<String> get values => _valueHandler.asAttributeValues;

  String getValue([DOMContext domContext]) =>
      _valueHandler.getAttributeValue(domContext);

  int get valueLength => _valueHandler.length;

  bool containsValue(dynamic value) =>
      _valueHandler.containsAttributeValue(value);

  void setBoolean(dynamic value) {
    if (!isBoolean) throw StateError('Not a boolean attribute');
    setValue(value);
  }

  void setValue(dynamic value) => _valueHandler.setAttributeValue(value);

  void appendValue(dynamic value) {
    if (_valueHandler is DOMAttributeValueCollection) {
      var valueCollection = _valueHandler as DOMAttributeValueCollection;
      return valueCollection.appendAttributeValue(value);
    } else {
      _valueHandler.setAttributeValue(value);
    }
  }

  String buildHTML([DOMContext domContext]) {
    if (isBoolean) {
      return _valueHandler.hasAttributeValue ? name : '';
    }

    var htmlValue = _valueHandler.getAttributeValue(domContext);

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

/// Base class for [DOMAttribute] value.
abstract class DOMAttributeValue {
  String get asAttributeValue;

  List<String> get asAttributeValues;

  /// Returns the attribute value.
  ///
  /// [domContext] Optional context, used by [DOMGenerator].
  String getAttributeValue([DOMContext domContext]) => asAttributeValue;

  /// Returns [true] if has a value.
  bool get hasAttributeValue;

  int get length;

  /// Parses [value] and returns [true] if is equals to this instance value.
  bool equalsAttributeValue(dynamic value);

  /// Parses [value] and returns [true] if this instance contains it.
  bool containsAttributeValue(dynamic value);

  /// Parses [value] and sets this instances value.
  void setAttributeValue(dynamic value);

  @override
  String toString();
}

class DOMAttributeValueBoolean extends DOMAttributeValue {
  bool _value;

  DOMAttributeValueBoolean(dynamic value) : _value = parseBool(value, false);

  @override
  bool get hasAttributeValue => _value;

  @override
  int get length => _value != null ? 1 : 0;

  @override
  String get asAttributeValue => _value.toString();

  @override
  List<String> get asAttributeValues => [asAttributeValue];

  @override
  bool equalsAttributeValue(dynamic value) {
    return _value == parseBool(value, false);
  }

  @override
  bool containsAttributeValue(value) => equalsAttributeValue(value);

  @override
  void setAttributeValue(dynamic value) {
    _value = parseBool(value, false);
  }

  @override
  String toString() {
    return 'DOMAttributeValueBoolean{_value: $_value}';
  }
}

/// A [DOMAttributeValue] of type [String].
class DOMAttributeValueString extends DOMAttributeValue {
  String _value;

  DOMAttributeValueString(dynamic value) : _value = parseString(value, '');

  @override
  bool get hasAttributeValue => _value != null && _value.isNotEmpty;

  @override
  int get length => _value != null ? _value.length : 0;

  @override
  String get asAttributeValue => hasAttributeValue ? _value.toString() : null;

  @override
  List<String> get asAttributeValues =>
      hasAttributeValue ? [asAttributeValue] : null;

  @override
  bool equalsAttributeValue(dynamic value) {
    if (_value == null) return !hasAttributeValue;
    return hasAttributeValue && _value == parseString(value);
  }

  @override
  bool containsAttributeValue(value) {
    if (value == null) return false;
    return hasAttributeValue && _value.contains(value);
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

/// Base [DOMAttributeValue] class for collections.
abstract class DOMAttributeValueCollection extends DOMAttributeValue {
  bool containsAttributeValueEntry(dynamic value);

  String getAttributeValueEntry(dynamic name);

  void appendAttributeValue(dynamic value);

  String removeAttributeValueEntry(dynamic name);

  void removeAttributeValueAllEntries(List entries) {
    if (entries == null || !hasAttributeValue) return;

    for (var entry in entries) {
      removeAttributeValueEntry(entry);
    }
  }
}

/// A [DOMAttributeValue] of type [List].
class DOMAttributeValueList extends DOMAttributeValueCollection {
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
  int get length => _values != null ? _values.length : 0;

  @override
  String get asAttributeValue => hasAttributeValue
      ? (_values.length == 1 ? _values[0] : _values.join(delimiter))
      : null;

  @override
  List<String> get asAttributeValues => hasAttributeValue ? _values : null;

  @override
  void setAttributeValue(dynamic value) {
    var valuesList = parseListOfStrings(value, delimiterPattern, true);

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
  bool equalsAttributeValue(dynamic value) {
    if (value == null) return !hasAttributeValue;
    if (!hasAttributeValue) return false;
    var valuesList = parseListOfStrings(value, delimiterPattern);
    return isEqualsList(_values, valuesList);
  }

  @override
  bool containsAttributeValue(dynamic value) {
    if (value == null) return false;
    if (!hasAttributeValue) return false;
    var valuesList = parseListOfStrings(value, delimiterPattern);
    if (valuesList == null || valuesList.isEmpty) return false;

    for (var entry in valuesList) {
      if (!_values.contains(entry)) {
        return false;
      }
    }

    return true;
  }

  @override
  bool containsAttributeValueEntry(dynamic entry) {
    if (entry == null) return false;
    if (!hasAttributeValue) return false;
    var entryStr = parseString(entry);
    return entryStr != null && _values.contains(entryStr);
  }

  @override
  String getAttributeValueEntry(dynamic entry) {
    if (!hasAttributeValue || entry == null) {
      return null;
    }
    var idx = _values.indexOf(entry);
    return idx >= 0 ? _values[idx] : null;
  }

  @override
  String removeAttributeValueEntry(dynamic entry) {
    if (!hasAttributeValue || entry == null) {
      return null;
    }
    var idx = _values.indexOf(entry);
    return idx >= 0 ? _values.removeAt(idx) : null;
  }

  @override
  String toString() {
    return 'DOMAttributeValueList{_values: $_values, delimiter: $delimiter, delimiterPattern: $delimiterPattern}';
  }
}

/// A [DOMAttributeValue] of type [Set].
class DOMAttributeValueSet extends DOMAttributeValueCollection {
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
  int get length => _values != null ? _values.length : 0;

  @override
  String get asAttributeValue => hasAttributeValue
      ? (_values.length == 1 ? _values.first : _values.join(delimiter))
      : null;

  @override
  List<String> get asAttributeValues =>
      hasAttributeValue ? _values.toList() : null;

  @override
  void setAttributeValue(dynamic value) {
    var valuesList = parseListOfStrings(value, delimiterPattern, true);

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
  bool equalsAttributeValue(dynamic value) {
    if (value == null) return !hasAttributeValue;
    var valuesSet = Set.from(parseListOfStrings(value, delimiterPattern));
    return isEqualsSet(_values ?? {}, valuesSet);
  }

  @override
  bool containsAttributeValue(dynamic value) {
    if (!hasAttributeValue || value == null) {
      return null;
    }
    var valuesList = parseListOfStrings(value, delimiterPattern);
    return _values.containsAll(valuesList);
  }

  @override
  bool containsAttributeValueEntry(dynamic entry) {
    if (!hasAttributeValue || entry == null) {
      return null;
    }
    var entryStr = parseString(entry);
    return _values.contains(entryStr);
  }

  @override
  String getAttributeValueEntry(dynamic entry) {
    if (!hasAttributeValue || entry == null) {
      return null;
    }
    var entryStr = parseString(entry);
    return _values.contains(entryStr) ? entry : null;
  }

  @override
  String removeAttributeValueEntry(dynamic entry) {
    if (!hasAttributeValue || entry == null) {
      return null;
    }
    var entryStr = parseString(entry);
    return _values.remove(entryStr) ? entryStr : null;
  }

  @override
  String toString() {
    return 'DOMAttributeValueSet{_values: $_values, delimiter: $delimiter, delimiterPattern: $delimiterPattern}';
  }
}

/// A [DOMAttributeValue] of type [CSS].
class DOMAttributeValueCSS extends DOMAttributeValueCollection {
  CSS _css;

  DOMAttributeValueCSS(dynamic values) {
    _css = CSS(values);
  }

  CSS get css => _css;

  @override
  bool get hasAttributeValue => _css.isNoEmpty;

  @override
  int get length => _css.length;

  @override
  String get asAttributeValue => hasAttributeValue ? _css.toString() : null;

  @override
  List<String> get asAttributeValues => _css.entriesAsString;

  @override
  String getAttributeValue([DOMContext domContext]) {
    if (hasAttributeValue) {
      return _css.toString(domContext);
    }
    return null;
  }

  @override
  void setAttributeValue(dynamic value) {
    _css = CSS(value);
  }

  @override
  void appendAttributeValue(dynamic value) {
    if (value == null) return;

    var entries = CSS(value).entries;
    if (entries.isEmpty) return;

    _css.putAll(entries);
  }

  @override
  bool equalsAttributeValue(dynamic value) {
    if (value == null) !hasAttributeValue;
    var css = CSS(value);
    return this.css == css;
  }

  @override
  bool containsAttributeValue(dynamic value) {
    if (value == null) return false;
    var css = CSS(value);
    if (css.isEmpty) return false;
    if (!hasAttributeValue) return false;

    for (var entry in css.entries) {
      if (!_css.containsEntry(entry)) {
        return false;
      }
    }

    return true;
  }

  @override
  bool containsAttributeValueEntry(dynamic entry) {
    if (!hasAttributeValue || entry == null) {
      return null;
    }

    var cssEntry = CSSEntry.parse(entry);
    if (cssEntry == null) {
      return null;
    }

    var cssEntry2 = _css.getEntry(cssEntry.name);
    return cssEntry == cssEntry2;
  }

  @override
  String getAttributeValueEntry(dynamic entry) {
    if (!hasAttributeValue || entry == null) {
      return null;
    }

    var cssEntry = CSSEntry.parse(entry);
    var name = cssEntry != null ? cssEntry.name : entry.trim();

    var cssEntry2 = _css.getEntry(name);
    return cssEntry2.toString();
  }

  @override
  String removeAttributeValueEntry(dynamic entry) {
    if (!hasAttributeValue || entry == null) {
      return null;
    }

    var cssEntry = CSSEntry.parse(entry);
    if (cssEntry == null) return null;

    var name = cssEntry.name;

    var cssEntry2 = _css.getEntry(name);

    if (cssEntry == cssEntry2) {
      return _css.removeEntry(name).toString();
    }
    return null;
  }

  @override
  String toString() {
    return 'DOMAttributeValueCSS{_css: $_css}';
  }
}
