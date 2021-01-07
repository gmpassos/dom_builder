import 'dart:collection';

import 'package:dom_builder/dom_builder.dart';
import 'package:swiss_knife/swiss_knife.dart';

class CSS {
  static final RegExp ENTRIES_DELIMITER = RegExp(r'\s*;\s*', multiLine: false);

  factory CSS([dynamic css]) {
    if (css == null) return CSS._();

    if (css is CSS) return css;

    if (css is String) {
      return CSS.parse(css) ?? CSS._();
    } else if (css is List) {
      return CSS.parseList(css) ?? CSS._();
    }

    throw StateError("Can't parse CSS: $css");
  }

  factory CSS.parse(String css) {
    var entries = _parseEntriesList(css);
    return CSS.parseList(entries);
  }

  factory CSS.parseList(List<String> entries) {
    if (entries == null || entries.isEmpty) return null;

    var cssEntries = <CSSEntry>[];

    var comment;

    for (var i = 0; i < entries.length; ++i) {
      var e = entries[i];
      if (e == null) continue;
      e = e.trim();
      if (e.isEmpty) continue;

      if (e.startsWith('/*') && e.endsWith('*/')) {
        comment = e;
      } else {
        var entry = CSSEntry.parse(e, comment);
        if (entry != null) {
          cssEntries.add(entry);
        }
        comment = null;
      }
    }

    var o = CSS._();
    o.putAll(cssEntries);
    return o;
  }

  static List<String> _parseEntriesList(String css) {
    var delimiter = RegExp('[;"\'\/]');

    var entries = <String>[];
    var cursor = 0;
    var entryStart = 0;
    int commentStart;
    String comment;

    while (cursor < css.length) {
      var idx = css.indexOf(delimiter, cursor);

      if (idx < 0) {
        var entryStr = css.substring(entryStart);
        if (entryStr.isNotEmpty) {
          if (comment != null) {
            entryStr =
                _cutString(entryStr, entryStart, commentStart, comment.length);
            entries.add(comment);
          }
          entries.add(entryStr.trim());
        }
        entryStart = css.length;
        break;
      }

      var c = css.substring(idx, idx + 1);

      if (c == ';') {
        var entryStr = css.substring(entryStart, idx);
        if (entryStr.isNotEmpty) {
          if (comment != null) {
            entryStr =
                _cutString(entryStr, entryStart, commentStart, comment.length);
            entries.add(comment);
          }
          entries.add(entryStr.trim());
        }
        entryStart = cursor = idx + 1;
        comment = null;
      } else if (c == '/') {
        var c2 = idx + 2 <= css.length ? css.substring(idx + 1, idx + 2) : '';

        if (c2 == '*') {
          var idx2 = css.indexOf('*/', idx + 2);

          if (idx2 > 0) {
            commentStart = idx;
            comment = css.substring(idx, idx2 + 2);
            cursor = idx2 + 2;
          } else {
            var entryStr = css.substring(entryStart, idx);
            if (entryStr.isNotEmpty) {
              if (comment != null) {
                entryStr = _cutString(
                    entryStr, entryStart, commentStart, comment.length);
                entries.add(comment);
              }
              entries.add(entryStr.trim());
            }
            entryStart = css.length;
            break;
          }
        } else {
          cursor = idx + 1;
        }
      } else {
        var idx2 = css.indexOf(c, idx + 1);

        if (idx2 < 0) {
          var entryStr = css.substring(entryStart);
          if (entryStr.isNotEmpty) {
            if (comment != null) {
              entryStr = _cutString(
                  entryStr, entryStart, commentStart, comment.length);
              entries.add(comment);
            }
            entries.add(entryStr.trim());
          }
          entryStart = css.length;
          break;
        }

        cursor = idx2 + 1;
      }
    }

    if (entryStart < css.length) {
      var entryStr = css.substring(entryStart);
      if (entryStr.isNotEmpty) {
        if (comment != null) {
          entryStr =
              _cutString(entryStr, entryStart, commentStart, comment.length);
          entries.add(comment);
        }
        entries.add(entryStr.trim());
      }
    }

    return entries;
  }

  static String _cutString(
      String entryStr, int entryStart, int commentStart, int length) {
    commentStart -= entryStart;
    var prefix = entryStr.substring(0, commentStart);
    var suffix = entryStr.substring(commentStart + length);
    return prefix + suffix;
  }

  CSS._();

  CSS copy() => CSS(style);

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CSS &&
          runtimeType == other.runtimeType &&
          isEqualsDeep(_entries, other._entries);

  @override
  int get hashCode => deepHashCode(_entries);

  bool get isEmpty => _entries.isEmpty;

  bool get isNoEmpty => !isEmpty;

  int get length => _entries.length;

  void putAllProperties(Map<String, dynamic> properties) {
    if (properties == null || properties.isEmpty) return;
    for (var entry in properties.entries) {
      put(entry.key, entry.value);
    }
  }

  void putAll(List<CSSEntry> entries) {
    if (entries == null || entries.isEmpty) return;
    for (var entry in entries) {
      putEntry(entry);
    }
  }

  void putEntry<V extends CSSValue>(CSSEntry<V> entry) {
    if (entry == null) return;
    _putImpl(entry.name, entry);
  }

  void put(String name, dynamic value) {
    _putImpl(name, value);
  }

  void _putImpl(String name, dynamic value) {
    name = CSSEntry.normalizeName(name);
    if (name == null) return;

    if (value == null) {
      removeEntry(name);
      return;
    }

    switch (name) {
      case 'color':
        {
          color = value;
          break;
        }
      case 'background-color':
        {
          backgroundColor = value;
          break;
        }
      case 'background':
        {
          background = value;
          break;
        }
      case 'width':
        {
          width = value;
          break;
        }
      case 'height':
        {
          height = value;
          break;
        }
      case 'border':
        {
          border = value;
          break;
        }
      case 'opacity':
        {
          opacity = value;
          break;
        }
      default:
        {
          CSSEntry cssEntry;

          if (value is CSSEntry) {
            cssEntry = value;
          } else {
            var cssValue = CSSGeneric.from(value);
            if (cssValue == null) {
              throw StateError(
                  "Can't parse CSS value with name '$name': $value");
            }
            cssEntry = CSSEntry<CSSGeneric>.from(name, cssValue);
          }

          _addEntry(name, cssEntry);
          break;
        }
    }
  }

  CSSEntry<V> removeEntry<V extends CSSValue>(String name) {
    var entry = _entries.remove(name);
    return entry;
  }

  bool containsEntry<V extends CSSValue>(CSSEntry<V> entry) {
    if (entry == null) return false;
    var name = entry.name;
    var entry2 = _getEntry(name);
    return entry2 != null && entry2 == entry;
  }

  CSSEntry<V> getEntry<V extends CSSValue>(String name) => _getEntry(name);

  V get<V extends CSSValue>(String name) {
    var entry = _getEntry(name);
    return entry != null ? entry.value : null;
  }

  String getAsString<V extends CSSValue>(String name) {
    var entry = _getEntry(name);
    return entry != null ? entry.valueAsString : null;
  }

  List<CSSEntry> getPossibleEntries() {
    var list = [
      _getEntry('color', sampleValue: CSSColor.parse('#000000')),
      _getEntry('background-color',
          sampleValue: CSSColor.parse('rgba(0,0,0, 0.50)')),
      _getEntry('width', sampleValue: CSSLength(1)),
      _getEntry('height', sampleValue: CSSLength(1)),
      _getEntry('border', sampleValue: CSSBorder.parse('1px solid #000000')),
      _getEntry('opacity', sampleValue: CSSNumber(1)),
    ];

    var map = LinkedHashMap<String, CSSEntry>.fromEntries(
        list.where((e) => e != null).map((e) => MapEntry(e.name, e)));

    for (var entry in _entries.values) {
      if (map.containsKey(entry.name)) {
        continue;
      }
      map[entry.name] = entry;
    }

    return map.values.toList();
  }

  final LinkedHashMap<String, CSSEntry> _entries = LinkedHashMap();

  CSSEntry<V> _getEntry<V extends CSSValue>(String name,
      {V defaultValue, V sampleValue}) {
    var entry = _entries[name];
    if (entry != null) return entry;

    if (defaultValue != null || sampleValue != null) {
      return CSSEntry(name, defaultValue, sampleValue);
    }

    return null;
  }

  void _addEntry<V extends CSSValue>(String name, CSSEntry<V> entry) {
    assert(name != null);
    if (entry == null || entry.value == null) {
      _entries.remove(name);
    } else {
      assert(name == entry.name, '$name != ${entry.name}');
      _entries[name] = entry;
    }
  }

  CSSEntry<CSSColor> get color => _getEntry<CSSColor>('color');

  set color(dynamic value) =>
      _addEntry('color', CSSEntry<CSSColor>.from('color', value));

  CSSEntry<CSSColor> get backgroundColor =>
      _getEntry<CSSColor>('background-color');

  set backgroundColor(dynamic value) => _addEntry(
      'background-color', CSSEntry<CSSColor>.from('background-color', value));

  CSSEntry<CSSBackground> get background =>
      _getEntry<CSSBackground>('background');

  set background(dynamic value) => _addEntry(
      'background', CSSEntry<CSSBackground>.from('background', value));

  CSSEntry<CSSLength> get width => _getEntry<CSSLength>('width');

  set width(dynamic value) =>
      _addEntry('width', CSSEntry<CSSLength>.from('width', value));

  CSSEntry<CSSLength> get height => _getEntry<CSSLength>('height');

  set height(dynamic value) =>
      _addEntry('height', CSSEntry<CSSLength>.from('height', value));

  CSSEntry<CSSBorder> get border => _getEntry<CSSBorder>('border');

  set border(dynamic value) =>
      _addEntry('border', CSSEntry<CSSBorder>.from('border', value));

  CSSEntry<CSSNumber> get opacity => _getEntry<CSSNumber>('opacity');

  set opacity(dynamic value) =>
      _addEntry('opacity', CSSEntry<CSSNumber>.from('opacity', value));

  String get style => toString();

  List<CSSEntry> get entries => List<CSSEntry>.from(_entries.values);

  List<String> get entriesAsString =>
      _entries.values.map((e) => e.toString(false)).toList();

  @override
  String toString([DOMContext domContext]) {
    var s = StringBuffer();

    var cssEntries = _entries.values;
    var length = cssEntries.length;
    var finalIndex = length - 1;

    for (var i = 0; i < length; i++) {
      var cssEntry = cssEntries.elementAt(i);
      var finalEntry = i == finalIndex;
      _append(s, cssEntry, !finalEntry, domContext);
    }

    return s.toString();
  }

  void _append(StringBuffer s, CSSEntry entry, bool withDelimiter,
      DOMContext domContext) {
    if (entry == null) return;
    if (s.isNotEmpty) {
      s.write(' ');
    }
    var style = entry.toString(withDelimiter, domContext);
    s.write(style);
  }

  CSSValue operator [](String key) => get(key);

  void operator []=(String key, value) => put(key, value);
}

class CSSEntry<V extends CSSValue> {
  static String normalizeName(String name) {
    if (name == null) return null;
    return name.trim().toLowerCase();
  }

  static final RegExp PAIR_DELIMITER = RegExp(r'\s*:\s*', multiLine: false);

  final String name;

  V _value;

  V _sampleValue;

  String _comment;

  CSSEntry(String name, V value, [V sampleValue, String comment])
      : this._(normalizeName(name), value, sampleValue, comment);

  CSSEntry._(this.name, this._value, [this._sampleValue, this._comment]);

  factory CSSEntry.from(String name, dynamic value, [String comment]) {
    if (value == null) return null;

    if (value is CSSEntry) {
      return CSSEntry(name, value.value, null, comment);
    } else if (value is CSSValue) {
      return CSSEntry(name, value as V, null, comment);
    } else if (value is String) {
      var cssValue = CSSValue.parseByName(value, name);
      return CSSEntry(name, cssValue as V, null, comment);
    }

    return null;
  }

  factory CSSEntry.parse(String entry, [String comment]) {
    if (entry == null) return null;

    var idx = entry.indexOf(PAIR_DELIMITER);
    if (idx < 0) return null;

    var name = normalizeName(entry.substring(0, idx));
    var value = entry.substring(idx + 1).trim();

    var cssValue = CSSValue.from(value, name) as V;

    if (comment != null && comment.contains('DOMContext-original-value:')) {
      var idx = comment.indexOf('DOMContext-original-value:');
      var originalValueStr = comment.substring(idx + 26).trim();
      if (originalValueStr.endsWith('*/')) {
        originalValueStr =
            originalValueStr.substring(0, originalValueStr.length - 2).trim();
      }

      if (originalValueStr.isNotEmpty) {
        var originalValue = CSSValue.from(originalValueStr, name) as V;
        if (originalValue != null) {
          cssValue = originalValue;
          comment = null;
        }
      }
    }

    return CSSEntry._(name, cssValue, null, comment);
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is CSSEntry && name == other.name && _value == other._value);

  @override
  int get hashCode => name.hashCode ^ _value.hashCode;

  V get value => _value;

  set value(V value) {
    _value = value;
  }

  String get valueAsString => _value != null ? _value.toString() : '';

  V get sampleValue => _sampleValue;

  set sampleValue(V value) {
    _sampleValue = value;
  }

  String get sampleValueAsString =>
      _sampleValue != null ? _sampleValue.toString() : '';

  @override
  String toString([bool withDelimiter, DOMContext domContext]) {
    var valueStr = value.toString(domContext);

    var commentStr = '';
    if (_comment != null && _comment.isNotEmpty) {
      commentStr = _comment;
      if (!commentStr.startsWith('/*')) {
        commentStr = '/*$commentStr';
      }
      if (!commentStr.endsWith('*/')) {
        commentStr = '$commentStr*/';
      }
    }

    String s;
    if (withDelimiter != null && withDelimiter) {
      s = '$name: $valueStr$commentStr;';
    } else {
      s = '$name: $valueStr$commentStr';
    }

    return s;
  }
}

abstract class CSSValue {
  factory CSSValue.from(dynamic value, [String name]) {
    if (name != null && name.isNotEmpty) {
      return CSSValue.parseByName(value, name);
    }

    CSSValue cssValue;

    cssValue = CSSNumber.from(value);
    if (cssValue != null) return cssValue;

    cssValue = CSSLength.from(value);
    if (cssValue != null) return cssValue;

    cssValue = CSSColor.from(value);
    if (cssValue != null) return cssValue;

    cssValue = CSSURL.from(value);
    if (cssValue != null) return cssValue;

    cssValue = CSSCalc.from(value);
    if (cssValue != null) return cssValue;

    return CSSGeneric.from(value);
  }

  factory CSSValue.parseByName(dynamic value, String name) {
    if (name == null) return null;

    switch (name) {
      case 'color':
        return CSSColor.from(value);
      case 'background-color':
        return CSSColor.from(value);
      case 'background':
        return CSSBackground.from(value);
      case 'width':
        return CSSLength.from(value);
      case 'height':
        return CSSLength.from(value);
      case 'border':
        return CSSBorder.from(value);
      case 'opacity':
        return CSSNumber.from(value);
      default:
        return CSSValue.from(value);
    }
  }

  CSSValue();

  CSSCalc _calc;

  CSSValue.fromCalc(this._calc);

  CSSCalc get calc => _calc;

  bool get isCalc => _calc != null;

  @override
  String toString([DOMContext domContext]) {
    return isCalc ? _calc.toString() : null;
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CSSValue &&
          runtimeType == other.runtimeType &&
          _calc == other._calc;

  @override
  int get hashCode => _calc != null ? _calc.hashCode : 0;
}

enum CalcOperation { SUM, SUBTRACT, MULTIPLY, DIVIDE }

CalcOperation getCalcOperation(String op) {
  if (op == null) return null;
  op = op.trim();
  if (op.isEmpty) return null;

  switch (op) {
    case '+':
      return CalcOperation.SUM;
    case '-':
      return CalcOperation.SUBTRACT;
    case '*':
      return CalcOperation.MULTIPLY;
    case '/':
      return CalcOperation.DIVIDE;
    default:
      return null;
  }
}

String getCalcOperationSymbol(CalcOperation op) {
  if (op == null) return null;

  switch (op) {
    case CalcOperation.SUM:
      return '+';
    case CalcOperation.SUBTRACT:
      return '-';
    case CalcOperation.MULTIPLY:
      return '*';
    case CalcOperation.DIVIDE:
      return '/';
    default:
      return null;
  }
}

class CSSCalc extends CSSValue {
  static final RegExp PATTERN =
      RegExp(r'^\s*calc\((.*?)\)\s*$', caseSensitive: false, multiLine: false);

  static final RegExp PATTERN_EXPRESSION_OPERATION = RegExp(
      r'^\s*(.*?)\s*([*/+-])\s*(.*?)\s*$',
      caseSensitive: false,
      multiLine: false);

  final String a;
  final CalcOperation operation;
  final String b;

  CSSCalc.simpleExpression(this.a)
      : operation = null,
        b = null,
        super();

  CSSCalc.withOperation(this.a, this.operation, this.b) : super();

  factory CSSCalc.from(dynamic calc) {
    if (calc == null) return null;

    if (calc is CSSCalc) {
      return calc;
    } else if (calc is String) {
      return CSSCalc.parse(calc);
    }

    return null;
  }

  factory CSSCalc.parse(String calc) {
    if (calc == null) return null;
    calc = calc.trim().toLowerCase();
    if (calc.isEmpty) return null;

    var match = PATTERN.firstMatch(calc);
    if (match == null) return null;

    var expression = match.group(1);

    var matchExpresionOp = PATTERN_EXPRESSION_OPERATION.firstMatch(expression);

    if (matchExpresionOp != null) {
      var a = matchExpresionOp.group(1);
      var op = getCalcOperation(matchExpresionOp.group(2));
      var b = matchExpresionOp.group(3);
      return CSSCalc.withOperation(a, op, b);
    } else {
      return CSSCalc.simpleExpression(expression.trim());
    }
  }

  bool get hasOperation => operation != null;

  String get operationSymbol => getCalcOperationSymbol(operation);

  @override
  String toString([DOMContext domContext]) {
    if (hasOperation) {
      return 'calc($a $operationSymbol $b)';
    } else {
      return 'calc($a)';
    }
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CSSCalc &&
          runtimeType == other.runtimeType &&
          a == other.a &&
          operation == other.operation &&
          b == other.b;

  @override
  int get hashCode => a.hashCode ^ operation.hashCode ^ b.hashCode;
}

class CSSGeneric extends CSSValue {
  String _value;

  CSSGeneric(this._value) {
    if (_value == null || _value.isEmpty) {
      throw ArgumentError('Invalid value: <$value>');
    }
  }

  factory CSSGeneric.from(dynamic value) {
    if (value == null) return null;

    if (value is CSSGeneric) return value;

    if (value is String) {
      return CSSGeneric.parse(value);
    }

    return null;
  }

  factory CSSGeneric.parse(String value) {
    if (value == null) return null;
    value = value.trim();
    if (value.isEmpty) return null;
    return CSSGeneric(value);
  }

  String get value => _value;

  set value(String value) {
    _value = value ?? '';
  }

  @override
  String toString([DOMContext domContext]) {
    return super.toString(domContext) ?? '$_value';
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) || (other is CSSGeneric && _value == other._value);

  @override
  int get hashCode => _value.hashCode;
}

enum CSSUnit {
  px,
  cm,
  mm,
  inches,
  pt,
  pc,
  em,
  ex,
  ch,
  rem,
  vw,
  vh,
  vmin,
  vmax,
  percent,
}

bool isCSSViewportUnit(CSSUnit unit) {
  return unit == CSSUnit.vw ||
      unit == CSSUnit.vh ||
      unit == CSSUnit.vmin ||
      unit == CSSUnit.vmax;
}

CSSUnit parseCSSUnit(String unit, [CSSUnit def]) {
  if (unit == null) return def;
  unit = unit.trim().toLowerCase();
  if (unit.isEmpty) return def;

  switch (unit) {
    case 'px':
      return CSSUnit.px;
    case 'cm':
      return CSSUnit.cm;
    case 'mm':
      return CSSUnit.mm;
    case 'inches':
      return CSSUnit.inches;
    case 'pt':
      return CSSUnit.pt;
    case 'pc':
      return CSSUnit.pc;
    case 'em':
      return CSSUnit.em;
    case 'ex':
      return CSSUnit.ex;
    case 'ch':
      return CSSUnit.ch;
    case 'rem':
      return CSSUnit.rem;
    case 'vw':
      return CSSUnit.vw;
    case 'vh':
      return CSSUnit.vh;
    case 'vmin':
      return CSSUnit.vmin;
    case 'vmax':
      return CSSUnit.vmax;
    case '%':
      return CSSUnit.percent;
    default:
      return def;
  }
}

String getCSSUnitName(CSSUnit unit, [CSSUnit def]) {
  unit ??= def;
  if (unit == null) return null;

  switch (unit) {
    case CSSUnit.px:
      return 'px';
    case CSSUnit.cm:
      return 'cm';
    case CSSUnit.mm:
      return 'mm';
    case CSSUnit.inches:
      return 'inches';
    case CSSUnit.pt:
      return 'pt';
    case CSSUnit.pc:
      return 'pc';
    case CSSUnit.em:
      return 'em';
    case CSSUnit.ex:
      return 'ex';
    case CSSUnit.ch:
      return 'ch';
    case CSSUnit.rem:
      return 'rem';
    case CSSUnit.vw:
      return 'vw';
    case CSSUnit.vh:
      return 'vh';
    case CSSUnit.vmin:
      return 'vmin';
    case CSSUnit.vmax:
      return 'vmax';
    case CSSUnit.percent:
      return '%';
    default:
      return null;
  }
}

class CSSLength extends CSSValue {
  static final RegExp PATTERN =
      RegExp(r'^\s*(-?\d+(?:\.\d+)?|-?\.\d+)(\%|\w+)?\s*$', multiLine: false);

  num _value;

  CSSUnit _unit;

  CSSLength(num value, [CSSUnit unit = CSSUnit.px])
      : _value = value ?? 0,
        _unit = unit ?? CSSUnit.px;

  CSSLength.fromCalc(CSSCalc calc) : super.fromCalc(calc);

  factory CSSLength.from(dynamic value) {
    if (value == null) return null;

    if (value is CSSLength) return value;

    if (value is String) {
      var calc = CSSCalc.parse(value);

      if (calc != null) {
        if (!calc.hasOperation) {
          var calcLength = CSSLength.parse(calc.a);
          if (calcLength.toString() == calc.a) {
            return calcLength;
          }
        }

        return CSSLength.fromCalc(calc);
      } else {
        return CSSLength.parse(value);
      }
    }

    return null;
  }

  factory CSSLength.parse(String value) {
    if (value == null) return null;

    var match = PATTERN.firstMatch(value);
    if (match == null) return null;

    var nStr = match.group(1);

    num n;
    if (isInt(nStr)) {
      n = parseInt(nStr);
    } else if (isDouble(nStr)) {
      n = parseDouble(nStr);
    } else {
      return null;
    }

    var unit = parseCSSUnit(match.group(2));

    return CSSLength(n, unit);
  }

  /// Returns [true] if [unit] is of type `px`.
  bool get isPx => _unit == CSSUnit.px;

  /// Returns [true] if [unit] is of type `%`.
  bool get isPercent => _unit == CSSUnit.percent;

  num get value => _value;

  set value(num value) {
    _value = value ?? 0;
  }

  CSSUnit get unit => _unit;

  set unit(CSSUnit value) {
    _unit = value ?? CSSUnit.px;
  }

  @override
  String toString([DOMContext domContext]) {
    return super.toString(domContext) ?? _resolveValue(domContext);
  }

  String _resolveValue(DOMContext domContext) {
    if (domContext != null &&
        domContext.resolveCSSViewportUnit &&
        isCSSViewportUnit(_unit) &&
        domContext.viewport != null) {
      return domContext.resolveCSSViewportUnitValue(_value, unit);
    } else {
      return '$_value${getCSSUnitName(_unit)}';
    }
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is CSSLength &&
          _value == other._value &&
          _unit == other._unit &&
          calc == other.calc);

  @override
  int get hashCode => isCalc ? super.hashCode : _value.hashCode ^ _unit.index;
}

class CSSNumber extends CSSValue {
  static final RegExp PATTERN =
      RegExp(r'^\s*(-?\d+(?:\.\d+)?|-?\.\d+)\s*$', multiLine: false);

  num _value;

  CSSNumber(num value) : _value = value ?? 0;

  CSSNumber.fromCalc(CSSCalc calc) : super.fromCalc(calc);

  factory CSSNumber.from(dynamic value) {
    if (value == null) return null;

    if (value is CSSNumber) return value;

    if (value is String) {
      var calc = CSSCalc.parse(value);

      if (calc != null) {
        if (!calc.hasOperation) {
          var calcNumber = CSSNumber.parse(calc.a);
          if (calcNumber.toString() == calc.a) {
            return calcNumber;
          }
        }

        return CSSNumber.fromCalc(calc);
      } else {
        return CSSNumber.parse(value);
      }
    }

    return null;
  }

  factory CSSNumber.parse(String value) {
    if (value == null) return null;

    var match = PATTERN.firstMatch(value);
    if (match == null) return null;

    var nStr = match.group(1);

    num n;
    if (isInt(nStr)) {
      n = parseInt(nStr);
    } else if (isDouble(nStr)) {
      n = parseDouble(nStr);
    } else {
      return null;
    }

    return CSSNumber(n);
  }

  num get value => _value;

  set value(num value) {
    _value = value ?? 0;
  }

  @override
  String toString([DOMContext domContext]) {
    return super.toString(domContext) ?? _resolveValue(domContext);
  }

  String _resolveValue(DOMContext domContext) {
    return '$_value';
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is CSSNumber && _value == other._value && calc == other.calc);

  @override
  int get hashCode => isCalc ? super.hashCode : _value.hashCode;
}

abstract class CSSColor extends CSSValue {
  CSSColor() : super();

  factory CSSColor.from(dynamic color) {
    if (color == null) return null;

    if (color is List) {
      if (color.length == 3) {
        return CSSColorRGB(
            parseInt(color[0]), parseInt(color[1]), parseInt(color[2]));
      } else if (color.length == 4) {
        return CSSColorRGBA(parseInt(color[0]), parseInt(color[1]),
            parseInt(color[2]), parseDouble(color[3]));
      } else {
        return null;
      }
    } else if (color is Map) {
      var r = findKeyValue(color, ['red', 'r'], true);
      var g = findKeyValue(color, ['green', 'g'], true);
      var b = findKeyValue(color, ['blue', 'b'], true);
      var a = findKeyValue(color, ['alpha', 'a'], true);

      if (r != null && g != null && b != null) {
        if (a != null) {
          return CSSColorRGBA(
              parseInt(r), parseInt(g), parseInt(b), parseDouble(a));
        } else {
          return CSSColorRGB(parseInt(r), parseInt(g), parseInt(b));
        }
      } else {
        return null;
      }
    }

    if (color is CSSColorRGB) {
      return color;
    } else if (color is CSSColorRGBA) {
      return color;
    } else if (color is CSSColorHEX) {
      return color;
    } else if (color is String) {
      return CSSColor.parse(color);
    }

    return null;
  }

  factory CSSColor.parse(String color) {
    if (color == null) return null;

    var cssColor = CSSColorHEX.parse(color);
    if (cssColor != null) return cssColor;

    var matchRGB = CSSColorRGB.PATTERN_RGB.firstMatch(color);
    if (matchRGB != null) {
      //var type = int.parse( match.group(1) ) ;
      var red = int.parse(matchRGB.group(2));
      var green = int.parse(matchRGB.group(3));
      var blue = int.parse(matchRGB.group(4));
      var alpha = parseDouble(matchRGB.group(5));

      if (alpha != null && alpha != 1) {
        return CSSColorRGBA(red, green, blue, alpha);
      } else {
        return CSSColorRGB(red, green, blue);
      }
    }

    return CSSColorName.parse(color);
  }

  bool get hasAlpha => false;

  CSSColor get inverse => asCSSColorRGB.inverse;

  String get args;

  String get argsNoAlpha;

  CSSColorRGB get asCSSColorRGB;

  CSSColorRGBA get asCSSColorRGBA;

  CSSColorHEX get asCSSColorHEX;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is CSSColor && hasAlpha == other.hasAlpha && args == other.args);

  @override
  int get hashCode => args.hashCode;
}

class CSSColorRGB extends CSSColor {
  static final RegExp PATTERN_RGB = RegExp(
      r'^\s*(rgba?)\(\s*(\d+)\s*,\s*(\d+)\s*,\s*(\d+)\s*(?:,\s*(\d+(?:\.\d+)?)\s*)?\)\s*$',
      multiLine: false);

  int _red;

  int _green;

  int _blue;

  CSSColorRGB(int red, int green, int blue)
      : _red = _clip(red, 0, 255, 0),
        _green = _clip(green, 0, 255, 0),
        _blue = _clip(blue, 0, 255, 0),
        super();

  factory CSSColorRGB.from(dynamic color) {
    if (color == null) return null;

    if (color is CSSColorRGB) {
      return color;
    } else if (color is CSSColorRGBA) {
      return color;
    } else if (color is String) {
      return CSSColorRGB.parse(color);
    }

    return null;
  }

  factory CSSColorRGB.parse(String color) {
    if (color == null) return null;
    var matchRGB = CSSColorRGB.PATTERN_RGB.firstMatch(color);
    if (matchRGB == null) return null;

    //var type = int.parse( match.group(1) ) ;
    var red = int.parse(matchRGB.group(2));
    var green = int.parse(matchRGB.group(3));
    var blue = int.parse(matchRGB.group(4));
    var alpha = parseDouble(matchRGB.group(5));

    if (alpha != null && alpha != 1) {
      return CSSColorRGBA(red, green, blue, alpha);
    } else {
      return CSSColorRGB(red, green, blue);
    }
  }

  int get red => _red;

  set red(int value) {
    _red = _clip(value, 0, 255, 0);
  }

  int get green => _green;

  set green(int value) {
    _green = _clip(value, 0, 255, 0);
  }

  int get blue => _blue;

  set blue(int value) {
    _blue = _clip(value, 0, 255, 0);
  }

  @override
  CSSColorRGB get inverse {
    var r = clipNumber(255 - red, 0, 255);
    var g = clipNumber(255 - green, 0, 255);
    var b = clipNumber(255 - blue, 0, 255);
    return CSSColorRGB(r, g, b);
  }

  @override
  String get args {
    return '$_red, $_green, $_blue';
  }

  @override
  String get argsNoAlpha {
    return '$_red, $_green, $_blue';
  }

  @override
  String toString([DOMContext domContext]) {
    return 'rgb($args)';
  }

  @override
  CSSColorRGB get asCSSColorRGB => this;

  @override
  CSSColorRGBA get asCSSColorRGBA => CSSColorRGBA(red, green, blue, 1);

  @override
  CSSColorHEX get asCSSColorHEX => CSSColorHEX.fromRGB(red, green, blue);
}

class CSSColorRGBA extends CSSColorRGB {
  double _alpha;

  CSSColorRGBA(int red, int green, int blue, double alpha)
      : _alpha = _normalizeDouble(_clip(alpha, 0, 1, 1)),
        super(red, green, blue);

  factory CSSColorRGBA.from(dynamic color) => CSSColorRGB.from(color);

  factory CSSColorRGBA.parse(String color) => CSSColorRGB.parse(color);

  double get alpha => _alpha;

  set alpha(double value) {
    _alpha = _normalizeDouble(_clip(value, 0, 1, 1));
  }

  @override
  bool get hasAlpha => _alpha != 1;

  @override
  String get args {
    var a = _doubleToStr(_alpha);
    return '${super.args}, $a';
  }

  @override
  String toString([DOMContext domContext]) {
    if (alpha == 1) return super.toString();
    return 'rgba($args)';
  }

  @override
  CSSColorRGBA get asCSSColorRGBA => this;
}

class CSSColorHEX extends CSSColorRGB {
  static final RegExp PATTERN_HEX = RegExp(
      r'(?:^([0-9a-f]{6-8})$|^\s*#([0-9a-f]{3,8})\s*$)',
      multiLine: false,
      caseSensitive: false);

  factory CSSColorHEX(String hexColor) => CSSColorHEX.parse(hexColor);

  factory CSSColorHEX.fromRGB(int red, int green, int blue) =>
      CSSColorHEX._(red, green, blue);

  CSSColorHEX._(int red, int green, int blue) : super(red, green, blue);

  factory CSSColorHEX.from(dynamic color) {
    if (color == null) return null;

    if (color is CSSColorHEX) {
      return color;
    } else if (color is CSSColorHEXAlpha) {
      return color;
    } else if (color is String) {
      return CSSColorHEX.parse(color);
    }

    return null;
  }

  factory CSSColorHEX.parse(String color) {
    if (color == null) return null;
    var match = PATTERN_HEX.firstMatch(color);
    if (match == null) return null;

    var hex = match.group(1);
    hex ??= match.group(2);

    if (hex.length == 3) {
      var r = hex.substring(0, 1);
      var g = hex.substring(1, 2);
      var b = hex.substring(2, 3);

      var nR = _parseHex('$r$r');
      var nG = _parseHex('$g$g');
      var nB = _parseHex('$b$b');

      return CSSColorHEX._(nR, nG, nB);
    } else if (hex.length == 6) {
      var r = hex.substring(0, 2);
      var g = hex.substring(2, 4);
      var b = hex.substring(4, 6);

      var nR = _parseHex(r);
      var nG = _parseHex(g);
      var nB = _parseHex(b);

      return CSSColorHEX._(nR, nG, nB);
    } else if (hex.length == 8) {
      var r = hex.substring(0, 2);
      var g = hex.substring(2, 4);
      var b = hex.substring(4, 6);
      var a = hex.substring(6, 8);

      var nR = _parseHex(r);
      var nG = _parseHex(g);
      var nB = _parseHex(b);
      var nA = _parseHex(a);

      var alpha = nA / 255;

      return CSSColorHEXAlpha._(nR, nG, nB, alpha);
    }

    return null;
  }

  @override
  CSSColorHEX get inverse {
    var r = clipNumber(255 - red, 0, 255);
    var g = clipNumber(255 - green, 0, 255);
    var b = clipNumber(255 - blue, 0, 255);
    return CSSColorHEX._(r, g, b);
  }

  @override
  String toString([DOMContext domContext]) {
    var r = _toHex(red);
    var g = _toHex(green);
    var b = _toHex(blue);

    return '#$r$g$b';
  }

  @override
  CSSColorRGB get asCSSColorRGB => CSSColorRGB(red, green, blue);

  @override
  CSSColorHEX get asCSSColorHEX => this;
}

class CSSColorHEXAlpha extends CSSColorHEX {
  double _alpha;

  factory CSSColorHEXAlpha(String hexColor) => CSSColorHEXAlpha.parse(hexColor);

  CSSColorHEXAlpha._(int red, int green, int blue, double alpha)
      : _alpha = _normalizeDouble(_clip(alpha, 0, 1, 1)),
        super._(red, green, blue);

  factory CSSColorHEXAlpha.from(dynamic color) => CSSColorHEX.from(color);

  factory CSSColorHEXAlpha.parse(String color) => CSSColorHEX.parse(color);

  double get alpha => _alpha;

  set alpha(double value) {
    _alpha = _normalizeDouble(_clip(value, 0, 1, 1));
  }

  @override
  bool get hasAlpha => _alpha != 1;

  @override
  String toString([DOMContext domContext]) {
    var colorHEX = super.toString();
    if (alpha != 1) {
      var nA = Math.round(alpha * 255).toInt();
      var a = _toHex(nA);
      return '$colorHEX$a';
    } else {
      return colorHEX;
    }
  }

  @override
  CSSColorRGB get asCSSColorRGB => CSSColorRGBA(red, green, blue, alpha);

  @override
  CSSColorRGBA get asCSSColorRGBA => CSSColorRGBA(red, green, blue, alpha);
}

class CSSColorName extends CSSColorRGB {
  static const Map<String, String> COLORS_NAMES = {
    'transparent': '#00000000',
    'aliceblue': '#f0f8ff',
    'antiquewhite': '#faebd7',
    'aqua': '#00ffff',
    'aquamarine': '#7fffd4',
    'azure': '#f0ffff',
    'beige': '#f5f5dc',
    'bisque': '#ffe4c4',
    'black': '#000000',
    'blanchedalmond': '#ffebcd',
    'blue': '#0000ff',
    'blueviolet': '#8a2be2',
    'brown': '#a52a2a',
    'burlywood': '#deb887',
    'cadetblue': '#5f9ea0',
    'chartreuse': '#7fff00',
    'chocolate': '#d2691e',
    'coral': '#ff7f50',
    'cornflowerblue': '#6495ed',
    'cornsilk': '#fff8dc',
    'crimson': '#dc143c',
    'cyan': '#00ffff',
    'darkblue': '#00008b',
    'darkcyan': '#008b8b',
    'darkgoldenrod': '#b8860b',
    'darkgray': '#a9a9a9',
    'darkgrey': '#a9a9a9',
    'darkgreen': '#006400',
    'darkkhaki': '#bdb76b',
    'darkmagenta': '#8b008b',
    'darkolivegreen': '#556b2f',
    'darkorange': '#ff8c00',
    'darkorchid': '#9932cc',
    'darkred': '#8b0000',
    'darksalmon': '#e9967a',
    'darkseagreen': '#8fbc8f',
    'darkslateblue': '#483d8b',
    'darkslategray': '#2f4f4f',
    'darkslategrey': '#2f4f4f',
    'darkturquoise': '#00ced1',
    'darkviolet': '#9400d3',
    'deeppink': '#ff1493',
    'deepskyblue': '#00bfff',
    'dimgray': '#696969',
    'dimgrey': '#696969',
    'dodgerblue': '#1e90ff',
    'firebrick': '#b22222',
    'floralwhite': '#fffaf0',
    'forestgreen': '#228b22',
    'fuchsia': '#ff00ff',
    'gainsboro': '#dcdcdc',
    'ghostwhite': '#f8f8ff',
    'gold': '#ffd700',
    'goldenrod': '#daa520',
    'gray': '#808080',
    'grey': '#808080',
    'green': '#008000',
    'greenyellow': '#adff2f',
    'honeydew': '#f0fff0',
    'hotpink': '#ff69b4',
    'indianred': '#cd5c5c',
    'indigo': '#4b0082',
    'ivory': '#fffff0',
    'khaki': '#f0e68c',
    'lavender': '#e6e6fa',
    'lavenderblush': '#fff0f5',
    'lawngreen': '#7cfc00',
    'lemonchiffon': '#fffacd',
    'lightblue': '#add8e6',
    'lightcoral': '#f08080',
    'lightcyan': '#e0ffff',
    'lightgoldenrodyellow': '#fafad2',
    'lightgray': '#d3d3d3',
    'lightgrey': '#d3d3d3',
    'lightgreen': '#90ee90',
    'lightpink': '#ffb6c1',
    'lightsalmon': '#ffa07a',
    'lightseagreen': '#20b2aa',
    'lightskyblue': '#87cefa',
    'lightslategray': '#778899',
    'lightslategrey': '#778899',
    'lightsteelblue': '#b0c4de',
    'lightyellow': '#ffffe0',
    'lime': '#00ff00',
    'limegreen': '#32cd32',
    'linen': '#faf0e6',
    'magenta': '#ff00ff',
    'maroon': '#800000',
    'mediumaquamarine': '#66cdaa',
    'mediumblue': '#0000cd',
    'mediumorchid': '#ba55d3',
    'mediumpurple': '#9370db',
    'mediumseagreen': '#3cb371',
    'mediumslateblue': '#7b68ee',
    'mediumspringgreen': '#00fa9a',
    'mediumturquoise': '#48d1cc',
    'mediumvioletred': '#c71585',
    'midnightblue': '#191970',
    'mintcream': '#f5fffa',
    'mistyrose': '#ffe4e1',
    'moccasin': '#ffe4b5',
    'navajowhite': '#ffdead',
    'navy': '#000080',
    'oldlace': '#fdf5e6',
    'olive': '#808000',
    'olivedrab': '#6b8e23',
    'orange': '#ffa500',
    'orangered': '#ff4500',
    'orchid': '#da70d6',
    'palegoldenrod': '#eee8aa',
    'palegreen': '#98fb98',
    'paleturquoise': '#afeeee',
    'palevioletred': '#db7093',
    'papayawhip': '#ffefd5',
    'peachpuff': '#ffdab9',
    'peru': '#cd853f',
    'pink': '#ffc0cb',
    'plum': '#dda0dd',
    'powderblue': '#b0e0e6',
    'purple': '#800080',
    'rebeccapurple': '#663399',
    'red': '#ff0000',
    'rosybrown': '#bc8f8f',
    'royalblue': '#4169e1',
    'saddlebrown': '#8b4513',
    'salmon': '#fa8072',
    'sandybrown': '#f4a460',
    'seagreen': '#2e8b57',
    'seashell': '#fff5ee',
    'sienna': '#a0522d',
    'silver': '#c0c0c0',
    'skyblue': '#87ceeb',
    'slateblue': '#6a5acd',
    'slategray': '#708090',
    'slategrey': '#708090',
    'snow': '#fffafa',
    'springgreen': '#00ff7f',
    'steelblue': '#4682b4',
    'tan': '#d2b48c',
    'teal': '#008080',
    'thistle': '#d8bfd8',
    'tomato': '#ff6347',
    'turquoise': '#40e0d0',
    'violet': '#ee82ee',
    'wheat': '#f5deb3',
    'white': '#ffffff',
    'whitesmoke': '#f5f5f5',
    'yellow': '#ffff00',
    'yellowgreen': '#9acd32',
  };

  final String name;

  double _alpha;

  factory CSSColorName(String hexColor) => CSSColorName.parse(hexColor);

  CSSColorName._(this.name, int red, int green, int blue, double alpha)
      : super(red, green, blue);

  factory CSSColorName.from(dynamic color) {
    if (color == null) return null;

    if (color is CSSColorName) {
      return color;
    } else if (color is String) {
      return CSSColorName.parse(color);
    }

    return null;
  }

  static final RegExp PATTERN_WORD = RegExp(r'[a-z]{2,}');

  factory CSSColorName.parse(String color) {
    if (color == null) return null;
    color = color.trim().toLowerCase();
    if (color.isEmpty) return null;

    var hex = COLORS_NAMES[color];
    if (hex == null) return null;

    var r = hex.substring(1, 3);
    var g = hex.substring(3, 5);
    var b = hex.substring(5, 7);
    var a = hex.length > 7 ? hex.substring(7, Math.min(9, hex.length)) : null;

    var nR = _parseHex(r);
    var nG = _parseHex(g);
    var nB = _parseHex(b);
    var nA = a != null ? _parseHex(a) / 255 : 1.0;

    return CSSColorName._(color, nR, nG, nB, nA);
  }

  double get alpha => _alpha;

  set alpha(double value) {
    _alpha = _normalizeDouble(_clip(value, 0, 1, 1));
  }

  @override
  bool get hasAlpha => _alpha != 1;

  @override
  String toString([DOMContext domContext]) {
    return '$name';
  }

  @override
  CSSColorRGBA get asCSSColorRGBA => CSSColorRGBA(red, green, blue, _alpha);
}

enum CSSBorderStyle {
  dotted,
  dashed,
  solid,
  double,
  groove,
  ridge,
  inset,
  outset,
  none,
  hidden
}

CSSBorderStyle parseCSSBorderStyle(String borderStyle) {
  if (borderStyle == null) return null;

  borderStyle = borderStyle.trim().toLowerCase();

  switch (borderStyle) {
    case 'dotted':
      return CSSBorderStyle.dotted;
    case 'dashed':
      return CSSBorderStyle.dashed;
    case 'solid':
      return CSSBorderStyle.solid;
    case 'double':
      return CSSBorderStyle.double;
    case 'groove':
      return CSSBorderStyle.groove;
    case 'ridge':
      return CSSBorderStyle.ridge;
    case 'inset':
      return CSSBorderStyle.inset;
    case 'outset':
      return CSSBorderStyle.outset;
    case 'none':
      return CSSBorderStyle.none;
    case 'hidden':
      return CSSBorderStyle.hidden;
    default:
      return null;
  }
}

String getCSSBorderStyleName(CSSBorderStyle borderStyle) {
  if (borderStyle == null) return null;

  switch (borderStyle) {
    case CSSBorderStyle.dotted:
      return 'dotted';
    case CSSBorderStyle.dashed:
      return 'dashed';
    case CSSBorderStyle.solid:
      return 'solid';
    case CSSBorderStyle.double:
      return 'double';
    case CSSBorderStyle.groove:
      return 'groove';
    case CSSBorderStyle.ridge:
      return 'ridge';
    case CSSBorderStyle.inset:
      return 'inset';
    case CSSBorderStyle.outset:
      return 'outset';
    case CSSBorderStyle.none:
      return 'none';
    case CSSBorderStyle.hidden:
      return 'hidden';
    default:
      return null;
  }
}

class CSSBorder extends CSSValue {
  static final RegExp PATTERN = RegExp(
      r'^\s*((?:-?\d+(?:\.\d+)?|-?\.\d+)(?:\%|\w+)?)?'
      r'\s*(dotted|dashed|solid|double|groove|ridge|inset|outset|none|hidden)'
      r'(?:\s+(rgba?\(.*?\)|\#[0-9a-f]{3,8}|\w{3,}))?\s*$',
      multiLine: false,
      caseSensitive: false);

  CSSLength _size;

  CSSBorderStyle _style;

  CSSColor _color;

  CSSBorder(this._size, CSSBorderStyle style, [this._color])
      : _style = style ?? CSSBorderStyle.none;

  factory CSSBorder.from(dynamic value) {
    if (value == null) return null;

    if (value is CSSBorder) return value;

    if (value is String) return CSSBorder.parse(value);

    return null;
  }

  factory CSSBorder.parse(String value) {
    if (value == null) return null;

    var match = PATTERN.firstMatch(value);
    if (match == null) return null;

    var sizeStr = match.group(1);
    var styleStr = match.group(2);
    var colorStr = match.group(3);

    var size = CSSLength.parse(sizeStr);
    var style = parseCSSBorderStyle(styleStr);
    var color = CSSColor.parse(colorStr);

    return CSSBorder(size, style, color);
  }

  CSSLength get size => _size;

  set size(CSSLength value) {
    _size = value;
  }

  CSSBorderStyle get style => _style;

  set style(CSSBorderStyle value) {
    _style = value ?? CSSBorderStyle.solid;
  }

  CSSColor get color => _color;

  set color(CSSColor value) {
    _color = value;
  }

  @override
  String toString([DOMContext domContext]) {
    return '${_size != null ? '$_size ' : ''}${getCSSBorderStyleName(_style)}${_color != null ? ' $color' : ''}';
  }
}

enum CSSBackgroundRepeat { repeat, repeatX, repeatY, noRepeat, space, round }

CSSBackgroundRepeat parseCSSBackgroundRepeat(String repeat) {
  if (repeat == null) return null;

  repeat = repeat.trim().toLowerCase();

  switch (repeat) {
    case 'repeat':
      return CSSBackgroundRepeat.repeat;
    case 'repeat-x':
      return CSSBackgroundRepeat.repeatX;
    case 'repeat-y':
      return CSSBackgroundRepeat.repeatY;
    case 'no-repeat':
      return CSSBackgroundRepeat.noRepeat;
    case 'space':
      return CSSBackgroundRepeat.space;
    case 'round':
      return CSSBackgroundRepeat.round;
    default:
      return null;
  }
}

String getCSSBackgroundRepeatName(CSSBackgroundRepeat repeat) {
  if (repeat == null) return null;

  switch (repeat) {
    case CSSBackgroundRepeat.repeat:
      return 'repeat';
    case CSSBackgroundRepeat.repeatX:
      return 'repeat-x';
    case CSSBackgroundRepeat.repeatY:
      return 'repeat-y';
    case CSSBackgroundRepeat.noRepeat:
      return 'no-repeat';
    case CSSBackgroundRepeat.space:
      return 'space';
    case CSSBackgroundRepeat.round:
      return 'round';
    default:
      return null;
  }
}

enum CSSBackgroundBox { borderBox, paddingBox, contentBox }

CSSBackgroundBox parseCSSBackgroundBox(String clip) {
  if (clip == null) return null;

  clip = clip.trim().toLowerCase();

  switch (clip) {
    case 'border-box':
      return CSSBackgroundBox.borderBox;
    case 'padding-box':
      return CSSBackgroundBox.paddingBox;
    case 'content-box':
      return CSSBackgroundBox.contentBox;
    default:
      return null;
  }
}

String getCSSBackgroundBoxName(CSSBackgroundBox clip) {
  if (clip == null) return null;

  switch (clip) {
    case CSSBackgroundBox.borderBox:
      return 'border-box';
    case CSSBackgroundBox.paddingBox:
      return 'padding-box';
    case CSSBackgroundBox.contentBox:
      return 'content-box';
    default:
      return null;
  }
}

enum CSSBackgroundAttachment { scroll, fixed, local }

CSSBackgroundAttachment parseCSSBackgroundAttachment(String attachment) {
  if (attachment == null) return null;

  attachment = attachment.trim().toLowerCase();

  switch (attachment) {
    case 'scroll':
      return CSSBackgroundAttachment.scroll;
    case 'fixed':
      return CSSBackgroundAttachment.fixed;
    case 'local':
      return CSSBackgroundAttachment.local;
    default:
      return null;
  }
}

String getCSSBackgroundAttachmentName(CSSBackgroundAttachment clip) {
  if (clip == null) return null;

  switch (clip) {
    case CSSBackgroundAttachment.scroll:
      return 'scroll';
    case CSSBackgroundAttachment.fixed:
      return 'fixed';
    case CSSBackgroundAttachment.local:
      return 'local';
    default:
      return null;
  }
}

RegExpDialect _REGEXP_BACKGROUND_DIALECT = RegExpDialect({
  'd': r'(?:-?\d+(?:\.\d+)?|-?\.\d+)',
  'pos': r'$d(?:\%|\w+)',
  'pos_pair': r'$pos(?:\s+$pos)?',
  'color_rgba': r'(?:rgba?\(\s*\d+\s*,\s*\d+\s*,\s*\d+\s*(?:,\s*$d\s*)?\))',
  'color_hex': r'#(?:[0-9a-f]{3}|[0-9a-f]{6}|[0-9a-f]{8})',
  'color': r'(?:$color_rgba|$color_hex)',
  'quote': r'''(?:"[^"]*"|'[^']*')''',
  'url': r'''(?:url\(\s*(?:$quote|[^\)]*?)\s*\))''',
  'gradient_type':
      r'(?:linear-gradient|radial-gradient|repeating-linear-gradient|repeating-radial-gradient)',
  'gradient': r'''(?:$gradient_type\(\s*(?:$color|[^\(\)]+?)+\s*\))''',
  'gradient_capture':
      r'''(?:($gradient_type)\(\s*((?:$color|[^\(\)]+?)+)\s*\))''',
  'attachment': r'(?:scroll|fixed|local)',
  'box': r'(?:border-box|padding-box|content-box)',
  'repeat': r'(?:repeat|repeat-x|repeat-y|no-repeat|space|round)',
  'position':
      r'(?:(?:left|right|center)(?:\s+(?:top|center|bottom))?|$pos_pair)',
  'size': r'(?:auto|cover|contain|$pos_pair)',
  'position_size': r'$position(?:\s*/\s*$size)?',
  'position_size_capture': r'($position)(?:\s*/\s*($size))?',
  'image_prop': r'(?:$repeat|$attachment|$box(?:\s+$box)?|$position_size)',
  'image_prop_capture':
      r'(?:($repeat)|($attachment)|($box)(?:\s+($box))?|$position_size_capture)',
  'image_src': r'(?:$gradient|$url)',
  'image': r'(?:$image_src(?:\s+$image_prop)*)',
  'image_layers': r'$image(?:\s*,\s*$image)*',
}, multiLine: false, caseSensitive: false);

class CSSBackgroundGradient {
  final String type;

  final List<String> parameters;

  CSSBackgroundGradient(this.type, this.parameters);

  @override
  String toString() {
    return '$type(${parameters.join(', ')})';
  }
}

class CSSBackgroundImage {
  static final RegExp PATTERN_URL = _REGEXP_BACKGROUND_DIALECT
      .getPattern(r'^\s*($url)((?:\s+$image_prop)+)?\s*$');
  static final RegExp PATTERN_GRADIENT = _REGEXP_BACKGROUND_DIALECT
      .getPattern(r'^\s*$gradient_capture((?:\s+$image_prop)+)?\s*$');

  static final RegExp PATTERN_PROPS_CAPTURE =
      _REGEXP_BACKGROUND_DIALECT.getPattern(r'(?:^\s*|\s+)$image_prop_capture');

  final CSSURL url;
  final CSSBackgroundGradient gradient;
  final CSSBackgroundBox origin;
  final CSSBackgroundBox clip;
  final CSSBackgroundAttachment attachment;
  final CSSBackgroundRepeat repeat;
  final String position;
  final String size;

  CSSBackgroundImage.url(this.url,
      {this.origin,
      this.clip,
      this.attachment,
      this.repeat,
      this.position,
      this.size})
      : gradient = null;

  CSSBackgroundImage.gradient(this.gradient,
      {this.origin,
      this.clip,
      this.attachment,
      this.repeat,
      this.position,
      this.size})
      : url = null;

  factory CSSBackgroundImage.from(dynamic value) {
    if (value == null) return null;

    if (value is CSSBackgroundImage) return value;

    if (value is String) return CSSBackgroundImage.parse(value);

    return null;
  }

  factory CSSBackgroundImage.parse(String value) {
    if (value == null) return null;

    CSSURL url;
    CSSBackgroundGradient gradient;

    CSSBackgroundRepeat repeat;
    CSSBackgroundAttachment attachment;
    CSSBackgroundBox origin;
    CSSBackgroundBox clip;
    String position;
    String size;

    String propsStr;

    var match = PATTERN_URL.firstMatch(value);
    if (match != null) {
      var urlStr = match.group(1);
      url = CSSURL.parse(urlStr);
      propsStr = match.group(2);
    } else {
      match = PATTERN_GRADIENT.firstMatch(value);
      if (match != null) {
        var gradientTypeStr = match.group(1);
        var gradientParamsStr = match.group(2);
        var parameters = parseListOfStrings(
            gradientParamsStr, ARGUMENT_LIST_DELIMITER, true);
        gradient = CSSBackgroundGradient(gradientTypeStr, parameters);
        propsStr = match.group(3);
      }
    }

    if (propsStr != null) {
      var propsMatches = PATTERN_PROPS_CAPTURE.allMatches(propsStr);

      for (var m in propsMatches) {
        var repeatStr = m.group(1);
        var attachmentStr = m.group(2);
        var box1Str = m.group(3);
        var box2Str = m.group(4);
        var positionStr = m.group(5);
        var sizeStr = m.group(6);

        if (repeatStr != null) {
          repeat = parseCSSBackgroundRepeat(repeatStr);
        }

        if (attachmentStr != null) {
          attachment = parseCSSBackgroundAttachment(attachmentStr);
        }

        if (box1Str != null) {
          origin = parseCSSBackgroundBox(box1Str);
        }

        if (box2Str != null) {
          clip = parseCSSBackgroundBox(box2Str);
        }

        if (positionStr != null) {
          position = positionStr;
        }

        if (sizeStr != null) {
          size = sizeStr;
        }
      }
    }

    if (url != null) {
      return CSSBackgroundImage.url(url,
          origin: origin,
          clip: clip,
          repeat: repeat,
          attachment: attachment,
          position: position,
          size: size);
    } else if (gradient != null) {
      return CSSBackgroundImage.gradient(gradient,
          origin: origin,
          clip: clip,
          repeat: repeat,
          attachment: attachment,
          position: position,
          size: size);
    }

    return null;
  }

  @override
  String toString([DOMContext domContext]) {
    var params = _toStringParameters(domContext);
    if (url != null) {
      var urlStr = url.toString(domContext);
      return '$urlStr$params';
    } else if (gradient != null) {
      var gradientStr = gradient.toString();
      return '$gradientStr$params';
    } else {
      return '';
    }
  }

  String _toStringParameters(DOMContext domContext) {
    var s = '';

    if (isNotEmptyString(position)) {
      s += ' ';
      s += position;
      if (isNotEmptyString(size)) {
        s += ' / ';
        s += size;
      }
    }

    if (repeat != null) {
      s += ' ';
      s += getCSSBackgroundRepeatName(repeat);
    }

    if (attachment != null) {
      s += ' ';
      s += getCSSBackgroundAttachmentName(attachment);
    }

    if (origin != null) {
      s += ' ';
      s += getCSSBackgroundBoxName(origin);

      if (clip != null) {
        s += ' ';
        s += getCSSBackgroundBoxName(clip);
      }
    }

    return s;
  }
}

class CSSBackground extends CSSValue {
  static final RegExp PATTERN_COLOR =
      _REGEXP_BACKGROUND_DIALECT.getPattern(r'^\s*($color)\s*$');
  static final RegExp PATTERN_IMAGE = _REGEXP_BACKGROUND_DIALECT
      .getPattern(r'^\s*($image)(?:\s+($color))?\s*$');
  static final RegExp PATTERN_COLOR_IMAGE =
      _REGEXP_BACKGROUND_DIALECT.getPattern(r'^\s*($color)\s+($image)\s*$');
  static final RegExp PATTERN_IMAGES = _REGEXP_BACKGROUND_DIALECT
      .getPattern(r'^\s*($image_layers)(?:\s+($color))?\s*$');

  static final RegExp PATTERN_IMAGE_CAPTURE =
      _REGEXP_BACKGROUND_DIALECT.getPattern(r'(?:^\s*|\s+)($image)');

  CSSColor _color;
  List<CSSBackgroundImage> _images;

  CSSBackground.color(CSSColor color) : _color = color;

  CSSBackground.image(CSSBackgroundImage image, [CSSColor color])
      : _color = color,
        _images = [image];

  CSSBackground.images(List<CSSBackgroundImage> images, [CSSColor color])
      : _color = color,
        _images = images;

  CSSBackground.url(CSSURL url,
      {CSSBackgroundBox origin,
      CSSBackgroundBox clip,
      CSSBackgroundAttachment attachment,
      CSSBackgroundRepeat repeat,
      String position,
      String size,
      CSSColor color})
      : _color = color,
        _images = [
          CSSBackgroundImage.url(url,
              origin: origin,
              clip: clip,
              attachment: attachment,
              repeat: repeat,
              position: position,
              size: size)
        ];

  CSSBackground.gradient(
    CSSBackgroundGradient gradient, {
    CSSBackgroundBox origin,
    CSSBackgroundBox clip,
    CSSBackgroundAttachment attachment,
    CSSBackgroundRepeat repeat,
    String position,
    String size,
    CSSColor color,
  })  : _color = color,
        _images = [
          CSSBackgroundImage.gradient(gradient,
              origin: origin,
              clip: clip,
              attachment: attachment,
              repeat: repeat,
              position: position,
              size: size)
        ];

  factory CSSBackground.from(dynamic value) {
    if (value == null) return null;

    if (value is CSSBackground) return value;

    if (value is String) return CSSBackground.parse(value);

    return null;
  }

  factory CSSBackground.parse(String value) {
    if (value == null) return null;

    var match = PATTERN_COLOR.firstMatch(value);
    if (match != null) {
      var colorStr = match.group(1);
      var color = CSSColor.parse(colorStr);
      return CSSBackground.color(color);
    }

    match = PATTERN_IMAGE.firstMatch(value);
    if (match != null) {
      var imageStr = match.group(1);
      var colorStr = match.group(2);
      var color = CSSColor.parse(colorStr);

      var bgImage = CSSBackgroundImage.parse(imageStr);
      return CSSBackground.image(bgImage, color);
    }

    match = PATTERN_COLOR_IMAGE.firstMatch(value);
    if (match != null) {
      var colorStr = match.group(1);
      var color = CSSColor.parse(colorStr);
      var imageStr = match.group(2);

      var bgImage = CSSBackgroundImage.parse(imageStr);
      return CSSBackground.image(bgImage, color);
    }

    match = PATTERN_IMAGES.firstMatch(value);
    if (match != null) {
      var imagesStr = match.group(1);
      var colorStr = match.group(2);
      var color = CSSColor.parse(colorStr);

      var matches = PATTERN_IMAGE_CAPTURE.allMatches(imagesStr);
      var images =
          matches.map((m) => CSSBackgroundImage.parse(m.group(1))).toList();

      return CSSBackground.images(images, color);
    }

    return null;
  }

  CSSColor get color => _color;

  set color(CSSColor value) {
    _color = value;
  }

  List<CSSBackgroundImage> get images => _images.toList();

  bool get hasImages => _images != null && _images.isNotEmpty;

  int get imagesLength => _images != null ? _images.length : 0;

  CSSBackgroundImage get firstImage => hasImages ? _images[0] : null;

  CSSBackgroundImage getImage(int idx) => hasImages ? _images[idx] : null;

  @override
  String toString([DOMContext domContext]) {
    var hasColor = _color != null;
    var hasImages = isNotEmptyObject(_images);

    if (hasImages) {
      var s = _images.map((e) => e.toString(domContext)).join(', ');
      if (hasColor) {
        s += ' ';
        s += _color.toString(domContext);
      }
      return s;
    } else if (hasColor) {
      return _color.toString(domContext);
    }

    return '';
  }
}

class CSSURL extends CSSValue {
  static final RegExp PATTERN = RegExp(
      r'''^\s*url\(\s*(?:"(.*?)"|'(.*?)'|(.*?))\s*\)\s*$''',
      caseSensitive: false, multiLine: false);

  final String url;

  CSSURL(this.url) : super();

  factory CSSURL.from(dynamic url) {
    if (url == null) return null;

    if (url is CSSURL) {
      return url;
    } else if (url is String) {
      return CSSURL.parse(url);
    }

    return null;
  }

  factory CSSURL.parse(String url) {
    if (url == null) return null;
    url = url.trim();
    if (url.isEmpty) return null;

    var match = PATTERN.firstMatch(url);
    if (match == null) return null;

    var uri = match.group(1) ?? match.group(2) ?? match.group(3);

    return CSSURL(uri);
  }

  @override
  String toString([DOMContext domContext]) {
    var url = _resolveValue(domContext);
    if (!url.contains('"')) {
      return 'url("$url")';
    } else if (!url.contains("'")) {
      return "url('$url')";
    } else {
      return 'url($url)';
    }
  }

  String _resolveValue(DOMContext domContext) {
    if (domContext != null && domContext.resolveCSSURL) {
      return domContext.resolveCSSURLValue(url);
    } else {
      return url;
    }
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CSSURL && runtimeType == other.runtimeType && url == other.url;

  @override
  int get hashCode => url.hashCode;
}

int _parseHex(String hex) => int.parse(hex, radix: 16);

String _toHex(int n) => n.toRadixString(16).padLeft(2, '0');

String _doubleToStr(double d, [int precision = 1000]) {
  return _normalizeDouble(d, precision).toString();
}

double _normalizeDouble(double d, [int precision = 1000]) {
  var n = (d * precision).toInt();
  var d2 = n / precision;
  return d2;
}

num _clip(num n, num min, num max, [num def]) {
  n ??= def;
  if (n < min) return min;
  if (n > max) return max;
  return n;
}
