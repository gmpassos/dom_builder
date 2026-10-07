import 'dart:collection';

import 'package:swiss_knife/swiss_knife.dart';

import 'dom_builder_base.dart';
import 'dom_builder_context.dart';
import 'dom_builder_css.dart';
import 'dom_builder_dsx.dart';
import 'dom_builder_generator.dart';
import 'dom_builder_helpers.dart';
import 'dom_builder_template.dart';
import 'dom_builder_treemap.dart';

/// Represents a [DOMElement] attribute entry (`name` and [DOMAttributeValue]).
class DOMAttribute with WithValue {
  static final Set<String> _attributesValueAsBoolean = {
    'checked',
    'hidden',
    'disabled',
    'selected',
    'multiple',
    'inert',
    'autoplay',
    'controls',
    'muted',
  };
  static final Set<String> _attributesValueAsSet = {'class'};

  static final Map<String, String> _attributesValueAsListDelimiters = {
    'class': ' ',
    'style': '; ',
  };

  static bool isBooleanAttribute(String attrName) =>
      _attributesValueAsBoolean.contains(attrName);

  static String? getAttributeDelimiter(String name) =>
      _attributesValueAsListDelimiters[name];

  static final Map<String, RegExp> _attributesValueAsListDelimitersPatterns = {
    'class': RegExp(r'\s+'),
    'style': RegExp(r'\s*;\s*'),
  };

  static RegExp? getAttributeDelimiterPattern(String name) =>
      _attributesValueAsListDelimitersPatterns[name];

  static String? normalizeName(String? name) {
    if (name == null) return null;
    return name.trim().toLowerCase();
  }

  /// Keywords of boolean attributes that are a state of their own, kept as
  /// the attribute's value: `hidden="until-found"` (hidden, but found by
  /// find-in-page and fragment navigation).
  static const Map<String, Set<String>> _booleanAttributesKeywords = {
    'hidden': {'until-found'},
  };

  /// The keyword of the boolean attribute [attrName] in [value]
  /// (`hidden="until-found"` -> `'until-found'`), or `null` if [value] is a
  /// boolean value.
  ///
  /// ```dart
  /// booleanAttributeKeyword('hidden', 'until-found');  // 'until-found'
  /// booleanAttributeKeyword('hidden', 'Until-Found');  // 'until-found'
  /// booleanAttributeKeyword('hidden', 'true');         // null
  /// booleanAttributeKeyword('checked', 'until-found'); // null
  /// ```
  static String? booleanAttributeKeyword(String? attrName, Object? value) {
    if (attrName == null || value is! String) return null;
    var keywords = _booleanAttributesKeywords[attrName];
    if (keywords == null) return null;
    var keyword = value.trim().toLowerCase();
    return keywords.contains(keyword) ? keyword : null;
  }

  /// The value of a boolean attribute ([isBooleanAttribute]) [attrName]: the
  /// one rule for every way a value comes in (parsed HTML, a template, a
  /// `bool`, `setValue`, a generator's `setAttribute`).
  ///
  /// ```dart
  /// parseBooleanValue('checked', '');         // true: <input checked>
  /// parseBooleanValue('checked', 'checked');  // true: XHTML form
  /// parseBooleanValue('checked', 'true');     // true (also on, yes, 1)
  /// parseBooleanValue('checked', 'false');    // false (also off, no, 0)
  /// parseBooleanValue('checked', true);       // true
  /// parseBooleanValue('checked', null);       // false: no value
  /// ```
  static bool parseBooleanValue(String? attrName, Object? value) {
    if (value == null) return false;
    if (value is bool) return value;

    if (value is String) {
      var s = value.trim();
      if (s.isEmpty) return true;
      if (attrName != null && s.toLowerCase() == attrName) return true;
      return parseBool(s, false)!;
    }

    return parseBool(value, false)!;
  }

  static String append(
    String s,
    String delimiter,
    DOMAttribute? attribute, {
    DOMContext? domContext,
    DSXResolution dsxResolution = DSXResolution.skipDSX,
  }) {
    if (attribute == null) return s;
    var append = attribute.buildHTML(
      domContext: domContext,
      dsxResolution: dsxResolution,
    );
    if (append.isEmpty) return s;
    return s + delimiter + append;
  }

  static StringBuffer appendTo(
    StringBuffer s,
    String delimiter,
    DOMAttribute? attribute, {
    DOMContext? domContext,
    DSXResolution dsxResolution = DSXResolution.skipDSX,
  }) {
    if (attribute == null) return s;
    var append = attribute.buildHTML(
      domContext: domContext,
      dsxResolution: dsxResolution,
    );
    if (append.isEmpty) return s;
    s.write(delimiter);
    s.write(append);
    return s;
  }

  final String name;

  final DOMAttributeValue valueHandler;

  DOMAttribute(this.name, this.valueHandler);

  static DOMAttribute? from(String? name, Object? value) {
    name = normalizeName(name);
    if (name == null) return null;

    if (value is String && DOMTemplate.possiblyATemplate(value)) {
      var template = DOMTemplate.parse(value);
      if (!template.hasOnlyContent) {
        return DOMAttribute(name, DOMAttributeValueTemplate(value));
      }
    }

    if (name == 'style') {
      return DOMAttribute(name, DOMAttributeValueCSS(value));
    }

    var delimiter = _attributesValueAsListDelimiters[name];

    if (delimiter != null) {
      var delimiterPattern = _attributesValueAsListDelimitersPatterns[name]!;

      var attrSet = _attributesValueAsSet.contains(name);

      if (attrSet) {
        return DOMAttribute(
          name,
          DOMAttributeValueSet(value, delimiter, delimiterPattern),
        );
      } else {
        return DOMAttribute(
          name,
          DOMAttributeValueList(value, delimiter, delimiterPattern),
        );
      }
    } else {
      var attrBoolean = _attributesValueAsBoolean.contains(name);

      if (attrBoolean) {
        if (value != null) {
          // A keyword is kept as the value: `hidden="until-found"`.
          var keyword = booleanAttributeKeyword(name, value);
          if (keyword != null) {
            return DOMAttribute(name, DOMAttributeValueString(keyword));
          }

          // `<input checked="">` and `<input checked="checked">` are true:
          // see `parseBooleanValue`.
          return DOMAttribute(
            name,
            DOMAttributeValueBoolean(value, attrName: name),
          );
        }
        return null;
      } else {
        return DOMAttribute(name, DOMAttributeValueString(value));
      }
    }
  }

  bool get isBoolean => valueHandler is DOMAttributeValueBoolean;

  bool get isList => valueHandler is DOMAttributeValueList;

  bool get isSet => valueHandler is DOMAttributeValueSet;

  bool get isCollection => valueHandler is DOMAttributeValueCollection;

  @override
  bool get hasValue => valueHandler.hasAttributeValue;

  @override
  String? get value => valueHandler.asAttributeValue;

  List<String>? get values => valueHandler.asAttributeValues;

  String? getValue([DOMContext? domContext, DOMTreeMap? treeMap]) =>
      valueHandler.getAttributeValue(domContext);

  int get valueLength => valueHandler.length;

  bool containsValue(Object? value) =>
      valueHandler.containsAttributeValue(value);

  void setBoolean(Object? value) {
    if (!isBoolean) throw StateError('Not a boolean attribute');
    setValue(value);
  }

  void setValue(Object? value) => valueHandler.setAttributeValue(value);

  void appendValue(Object? value) {
    if (valueHandler is DOMAttributeValueCollection) {
      var valueCollection = valueHandler as DOMAttributeValueCollection;
      return valueCollection.appendAttributeValue(value);
    } else {
      valueHandler.setAttributeValue(value);
    }
  }

  String buildHTML({
    DOMContext? domContext,
    DSXResolution dsxResolution = DSXResolution.skipDSX,
  }) {
    var valueHandler = this.valueHandler;

    if (isBoolean) {
      return valueHandler.hasAttributeValue ? name : '';
    }

    String? htmlValue;
    if (dsxResolution.resolve && valueHandler is DOMAttributeValueTemplate) {
      var templateBuilt = valueHandler.template.build(
        domContext,
        asElement: false,
        dsxResolution: dsxResolution,
        intlMessageResolver: domContext?.intlMessageResolver,
      );

      if (templateBuilt is String && !possiblyWithHTML(templateBuilt)) {
        htmlValue = templateBuilt;
      } else {
        var nodes = DOMNode.parseNodes(templateBuilt);
        htmlValue = nodes.map((e) => e.text).join();
      }
    } else {
      htmlValue = valueHandler.getAttributeValue(domContext);
    }

    if (htmlValue != null) {
      var html = StringBuffer('$name=');

      if (htmlValue.contains('"')) {
        html.write("'");
        html.write(htmlValue);
        html.write("'");
      } else {
        html.write('"');
        html.write(htmlValue);
        html.write('"');
      }

      return html.toString();
    } else {
      return '';
    }
  }

  @override
  String toString() {
    return hasValue ? value! : '';
  }
}

/// Base class for [DOMAttribute] value.
abstract class DOMAttributeValue {
  String? get asAttributeValue;

  List<String>? get asAttributeValues;

  /// Returns the attribute value.
  ///
  /// [domContext] Optional context, used by [DOMGenerator].
  String? getAttributeValue([DOMContext? domContext, DOMTreeMap? treeMap]) =>
      asAttributeValue;

  /// Returns [true] if has a value.
  bool get hasAttributeValue;

  int get length;

  /// Parses [value] and returns [true] if is equals to this instance value.
  bool equalsAttributeValue(Object? value);

  /// Parses [value] and returns [true] if this instance contains it.
  bool containsAttributeValue(Object? value);

  /// Parses [value] and sets this instances value.
  void setAttributeValue(Object? value);

  @override
  String toString();
}

/// A boolean attribute's value, read by [DOMAttribute.parseBooleanValue]
/// (with [attrName], its own name is true: `checked="checked"`).
class DOMAttributeValueBoolean extends DOMAttributeValue {
  /// The attribute's name, for [DOMAttribute.parseBooleanValue].
  final String? attrName;

  bool _value;

  DOMAttributeValueBoolean(Object? value, {this.attrName})
    : _value = DOMAttribute.parseBooleanValue(attrName, value);

  @override
  bool get hasAttributeValue => _value;

  @override
  int get length => 1;

  @override
  String get asAttributeValue => _value.toString();

  @override
  List<String> get asAttributeValues => [asAttributeValue];

  @override
  bool equalsAttributeValue(Object? value) {
    return _value == DOMAttribute.parseBooleanValue(attrName, value);
  }

  @override
  bool containsAttributeValue(value) => equalsAttributeValue(value);

  @override
  void setAttributeValue(Object? value) {
    _value = DOMAttribute.parseBooleanValue(attrName, value);
  }

  @override
  String toString() {
    return 'DOMAttributeValueBoolean{_value: $_value}';
  }
}

/// A [DOMAttributeValue] of type [String].
///
/// An empty value is a value (`data-x=""` is present: `[data-x]`,
/// `dataset.x == ""`); only `null` is no value.
class DOMAttributeValueString extends DOMAttributeValue {
  String? _value;

  DOMAttributeValueString(Object? value) : _value = parseString(value);

  @override
  bool get hasAttributeValue {
    final value = _value;
    return value != null && value.isNotEmpty;
  }

  @override
  int get length {
    final value = _value;
    return value != null ? value.length : 0;
  }

  /// The value, `''` included (`null`: no value).
  @override
  String? get asAttributeValue => _value;

  @override
  List<String>? get asAttributeValues {
    final value = _value;
    return value != null ? [value] : null;
  }

  /// `''` equals `''` (a value), `null` equals only no value.
  @override
  bool equalsAttributeValue(Object? value) {
    if (value == null) return _value == null;
    return _value == parseString(value);
  }

  @override
  bool containsAttributeValue(value) {
    final v = _value;
    if (value == null || v == null) return false;
    return v.contains(value as Pattern);
  }

  @override
  void setAttributeValue(Object? value) {
    _value = parseString(value);
  }

  @override
  String toString() {
    return 'DOMAttributeValueString{_value: $_value}';
  }
}

/// Attribute value when has template syntax: {{...}}
class DOMAttributeValueTemplate extends DOMAttributeValueString {
  late DOMTemplate _template;

  DOMAttributeValueTemplate(Object? value) : super(value) {
    _template = DOMTemplate.from(value)!;
  }

  DOMTemplate get template => _template;

  @override
  String? getAttributeValue([DOMContext? domContext, DOMTreeMap? treeMap]) {
    if (domContext == null) {
      return super.getAttributeValue(domContext);
    } else {
      var dsxResolution = DSXResolution.lifecycleManager(treeMap);
      var build = template.build(
        domContext,
        dsxResolution: dsxResolution,
        elementProvider: (q) => treeMap?.queryElementAsHTML(
          q,
          domContext: domContext,
          buildTemplates: true,
          dsxResolution: dsxResolution,
        ),
        intlMessageResolver: domContext.intlMessageResolver,
      );

      if (build == null) {
        return super.getAttributeValue(domContext, treeMap);
      } else if (build is String) {
        return build;
      } else if (build is Iterable) {
        var list = build.map((e) => e?.toString()).toList();
        return list.join();
      } else {
        return '$build';
      }
    }
  }

  @override
  void setAttributeValue(Object? value) {
    super.setAttributeValue(value);
    _template = DOMTemplate.parse(value as String);
  }

  @override
  String toString() {
    return 'DOMAttributeValueTemplate{template: $_template}';
  }
}

/// Base [DOMAttributeValue] class for collections.
abstract class DOMAttributeValueCollection extends DOMAttributeValue {
  bool containsAttributeValueEntry(Object? value);

  String? getAttributeValueEntry(Object? name);

  void appendAttributeValue(Object? value);

  String? removeAttributeValueEntry(Object? name);

  void removeAttributeValueAllEntries(List entries) {
    if (!hasAttributeValue) return;

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

  DOMAttributeValueList(Object? values, this.delimiter, this.delimiterPattern)
    : _values = parseListOfStrings(values, delimiterPattern);

  @override
  bool get hasAttributeValue {
    if (_values.isNotEmpty) {
      if (_values.length == 1) {
        return _values[0].isNotEmpty;
      } else {
        return true;
      }
    }
    return false;
  }

  @override
  int get length => _values.length;

  @override
  String? get asAttributeValue => hasAttributeValue
      ? (_values.length == 1 ? _values[0] : _values.join(delimiter))
      : null;

  @override
  List<String>? get asAttributeValues => hasAttributeValue ? _values : null;

  @override
  void setAttributeValue(Object? value) {
    var valuesList = parseListOfStrings(value, delimiterPattern, true);

    if (valuesList.isEmpty) {
      _values = [];
    } else if (_values.length == 1 && valuesList.length == 1) {
      _values[0] = parseString(valuesList[0])!;
    } else {
      _values = valuesList;
    }
  }

  @override
  void appendAttributeValue(value) {
    var s = parseString(value);
    if (s != null) {
      _values.add(s);
    }
  }

  @override
  bool equalsAttributeValue(Object? value) {
    if (value == null) return !hasAttributeValue;
    if (!hasAttributeValue) return false;
    var valuesList = parseListOfStrings(value, delimiterPattern);
    return isEqualsList(_values, valuesList);
  }

  @override
  bool containsAttributeValue(Object? value) {
    if (value == null) return false;
    if (!hasAttributeValue) return false;
    var valuesList = parseListOfStrings(value, delimiterPattern);
    if (valuesList.isEmpty) return false;

    for (var entry in valuesList) {
      if (!_values.contains(entry)) {
        return false;
      }
    }

    return true;
  }

  @override
  bool containsAttributeValueEntry(Object? value) {
    if (value == null) return false;
    if (!hasAttributeValue) return false;
    var valueStr = parseString(value);
    return valueStr != null && _values.contains(valueStr);
  }

  @override
  String? getAttributeValueEntry(Object? name) {
    if (!hasAttributeValue || name == null) {
      return null;
    }
    var idx = _values.indexOf(name as String);
    return idx >= 0 ? _values[idx] : null;
  }

  @override
  String? removeAttributeValueEntry(Object? name) {
    if (!hasAttributeValue || name == null) {
      return null;
    }
    var idx = _values.indexOf(name as String);
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

  DOMAttributeValueSet(Object? values, this.delimiter, this.delimiterPattern)
    : _values = LinkedHashSet<String>.from(
        parseListOfStrings(values, delimiterPattern),
      );

  @override
  bool get hasAttributeValue {
    if (_values.isNotEmpty) {
      if (_values.length == 1) {
        return _values.first.isNotEmpty;
      } else {
        return true;
      }
    }
    return false;
  }

  @override
  int get length => _values.length;

  @override
  String? get asAttributeValue => hasAttributeValue
      ? (_values.length == 1 ? _values.first : _values.join(delimiter))
      : null;

  @override
  List<String>? get asAttributeValues =>
      hasAttributeValue ? _values.toList() : null;

  @override
  void setAttributeValue(Object? value) {
    var valuesList = parseListOfStrings(value, delimiterPattern, true);

    if (valuesList.isEmpty) {
      // ignore: prefer_collection_literals
      _values = LinkedHashSet<String>();
    } else {
      _values = Set<String>.from(valuesList) as LinkedHashSet<String>;
    }
  }

  @override
  void appendAttributeValue(value) {
    var s = parseString(value);
    if (s != null) {
      _values.add(s);
    }
  }

  @override
  bool equalsAttributeValue(Object? value) {
    if (value == null) return !hasAttributeValue;
    var valuesSet = Set.from(parseListOfStrings(value, delimiterPattern));
    return isEqualsSet(_values, valuesSet);
  }

  @override
  bool containsAttributeValue(Object? value) {
    if (!hasAttributeValue || value == null) {
      return false;
    }
    var valuesList = parseListOfStrings(value, delimiterPattern);
    return _values.containsAll(valuesList);
  }

  @override
  bool containsAttributeValueEntry(Object? value) {
    if (!hasAttributeValue || value == null) {
      return false;
    }
    var valueStr = parseString(value);
    return _values.contains(valueStr);
  }

  @override
  String? getAttributeValueEntry(Object? name) {
    if (!hasAttributeValue || name == null) {
      return null;
    }
    var entryStr = parseString(name);
    return _values.contains(entryStr) ? name as String? : null;
  }

  @override
  String? removeAttributeValueEntry(Object? name) {
    if (!hasAttributeValue || name == null) {
      return null;
    }
    var entryStr = parseString(name);
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

  DOMAttributeValueCSS(Object? values) : _css = CSS(values);

  CSS get css => _css;

  @override
  bool get hasAttributeValue => _css.isNoEmpty;

  @override
  int get length => _css.length;

  @override
  String? get asAttributeValue => hasAttributeValue ? _css.toString() : null;

  @override
  List<String> get asAttributeValues => _css.entriesAsString;

  @override
  String? getAttributeValue([DOMContext? domContext, DOMTreeMap? treeMap]) {
    if (hasAttributeValue) {
      return _css.toString(domContext);
    }
    return null;
  }

  @override
  void setAttributeValue(Object? value) {
    _css = CSS(value);
  }

  @override
  void appendAttributeValue(Object? value) {
    if (value == null) return;

    var entries = CSS(value).entries;
    if (entries.isEmpty) return;

    _css.putAll(entries);
  }

  @override
  bool equalsAttributeValue(Object? value) {
    if (value == null) !hasAttributeValue;
    var css = CSS(value);
    return this.css == css;
  }

  @override
  bool containsAttributeValue(Object? value) {
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
  bool containsAttributeValueEntry(Object? value) {
    if (!hasAttributeValue || value == null) {
      return false;
    }

    var cssEntry = CSSEntry.parse(value as String);
    if (cssEntry == null) {
      return false;
    }

    var cssEntry2 = _css.getEntry(cssEntry.name);
    return cssEntry == cssEntry2;
  }

  @override
  String? getAttributeValueEntry(Object? name) {
    if (!hasAttributeValue || name == null) {
      return null;
    }

    var cssEntry = CSSEntry.parse(name as String);
    var cssName = cssEntry != null ? cssEntry.name : name.toString().trim();

    var cssEntry2 = _css.getEntry(cssName);
    return cssEntry2.toString();
  }

  @override
  String? removeAttributeValueEntry(Object? name) {
    if (!hasAttributeValue || name == null) {
      return null;
    }

    var cssEntry = CSSEntry.parse(name as String);
    if (cssEntry == null) return null;

    var cssName = cssEntry.name;

    var cssEntry2 = _css.getEntry(cssName);

    if (cssEntry == cssEntry2) {
      return _css.removeEntry(cssName).toString();
    }
    return null;
  }

  @override
  String toString() {
    return 'DOMAttributeValueCSS{_css: $_css}';
  }
}
