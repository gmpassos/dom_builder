import 'package:swiss_knife/swiss_knife.dart';

class CSS {
  static final RegExp ENTRIES_DELIMITER = RegExp(r'\s*;\s*', multiLine: false);

  factory CSS([dynamic css]) {
    if (css == null) return CSS._();

    if (css is CSS) return css;

    if (css is String) {
      var entries = css
          .split(ENTRIES_DELIMITER)
          .map((e) => e.trim())
          .where((e) => e.isNotEmpty);

      if (entries.isEmpty) return null;

      var cssEntries = entries
          .map((e) => CSSEntry.parse(e))
          .where((e) => e != null)
          .toList();

      var o = CSS._();
      o.putAll(cssEntries);
      return o;
    }

    throw StateError("Can't parse CSS: $css");
  }

  CSS._();

  void putAll(List<CSSEntry> entries) {
    if (entries == null || entries.isEmpty) return;
    for (var entry in entries) {
      put(entry);
    }
  }

  void put<V>(CSSEntry<V> entry) {
    if (entry == null) return;

    switch (entry.name) {
      case 'color':
        {
          color = entry;
          break;
        }
      case 'background-color':
        {
          backgroundColor = entry;
          break;
        }
      case 'width':
        {
          width = entry;
          break;
        }
      case 'height':
        {
          height = entry;
          break;
        }
      default:
        throw StateError('Unknown CSS entry: $entry');
    }
  }

  CSSEntry<CSSColor> _color;

  CSSEntry<CSSColor> get color => _color;

  set color(dynamic value) {
    _color = CSSEntry.from('color', value);
  }

  CSSEntry<CSSColor> _backgroundColor;

  CSSEntry<CSSColor> get backgroundColor => _backgroundColor;

  set backgroundColor(dynamic value) {
    _backgroundColor = CSSEntry.from('background-color', value);
    ;
  }

  CSSEntry<CSSLength> _width;

  CSSEntry<CSSLength> get width => _width;

  set width(dynamic value) {
    _width = CSSEntry.from('width', value);
  }

  CSSEntry<CSSLength> _height;

  CSSEntry<CSSLength> get height => _height;

  set height(dynamic value) {
    _height = CSSEntry.from('height', value);
  }

  String get style => toString();

  void _append(StringBuffer s, CSSEntry entry) {
    if (entry == null) return;
    if (s.isNotEmpty) {
      s.write(' ');
    }
    s.write(entry);
  }

  @override
  String toString() {
    var s = StringBuffer();
    _append(s, _color);
    _append(s, _backgroundColor);
    _append(s, _width);
    _append(s, _height);
    return s.toString();
  }
}

class CSSEntry<V> {
  static String normalizeName(String name) {
    if (name == null) return null;
    return name.trim().toLowerCase();
  }

  static final RegExp PAIR_DELIMITER = RegExp(r'\s*:\s*', multiLine: false);

  final String name;

  V _value;

  CSSEntry(String name, V value) : this._(normalizeName(name), value);

  CSSEntry._(this.name, this._value);

  factory CSSEntry.from(String name, dynamic value) {
    if (value == null) return null;

    if (value is CSSEntry) {
      return CSSEntry(name, value.value);
    } else if (value is CSSValue) {
      return CSSEntry(name, value as V);
    }

    return null;
  }

  factory CSSEntry.parse(String entry) {
    if (entry == null) return null;

    var parts = entry.split(PAIR_DELIMITER);
    if (parts.length <= 1) return null;

    var name = normalizeName(parts[0]);
    var value = parts[1];

    var cssValue = CSSValue.from(value, name) as V;
    return CSSEntry._(name, cssValue);
  }

  V get value => _value;

  set value(V value) {
    _value = value;
  }

  @override
  String toString() {
    return '$name: $value;';
  }
}

abstract class CSSValue {
  factory CSSValue.from(dynamic value, [String name]) {
    if (name != null && name.isNotEmpty) {
      return CSSValue.parseByName(value, name);
    }

    CSSValue cssValue;

    cssValue = CSSLength.from(value);
    if (cssValue != null) return cssValue;

    cssValue = CSSColor.from(value);
    if (cssValue != null) return cssValue;

    return null;
  }

  factory CSSValue.parseByName(dynamic value, String name) {
    if (name == null) return null;

    switch (name) {
      case 'color':
        return CSSColor.from(value);
      case 'background-color':
        return CSSColor.from(value);
      case 'width':
        return CSSLength.from(value);
      case 'height':
        return CSSLength.from(value);
      default:
        throw StateError("Can't parse CSS value with name '$name': $value");
    }
  }

  CSSValue();

  @override
  String toString();
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
  static final RegExp PATTERN = RegExp(r'\s*(\d+)(\%|\w+)?\s*', multiLine: false);

  num _value;

  CSSUnit _unit;

  CSSLength(num value, [CSSUnit unit = CSSUnit.px])
      : _value = value ?? 0,
        _unit = unit ?? CSSUnit.px;

  factory CSSLength.from(dynamic value) {
    if (value == null) return null;

    if (value is CSSLength) return value;

    if (value is String) {
      return CSSLength.parse(value);
    }

    return null;
  }

  factory CSSLength.parse(String value) {
    if (value == null) return null;

    var match = PATTERN.firstMatch(value);
    if (match == null) return null;

    var n = int.parse(match.group(1));
    var unit = parseCSSUnit(match.group(2));

    return CSSLength(n, unit);
  }

  num get value => _value;

  set value(num value) {
    _value = value ?? 0;
  }

  CSSUnit get unit => _unit;

  set unit(CSSUnit value) {
    _unit = value ?? CSSUnit.px;
  }

  @override
  String toString() {
    return '$_value${getCSSUnitName(_unit)}';
  }
}

class CSSColor extends CSSValue {
  static final RegExp PATTERN_RGB = RegExp(
      r'\s*(rgba?)\(\s*(\d+)\s*,\s*(\d+)\s*,\s*(\d+)\s*(?:,\s*(\d+(?:\.\d+))\s*)?\)\s*',
      multiLine: false);

  CSSColor() : super();

  factory CSSColor.from(dynamic color) {
    if (color == null) return null;

    if (color is CSSColorRGB) {
      return color;
    } else if (color is CSSColorRGBA) {
      return color;
    } else if (color is String) {
      return CSSColor.parse(color);
    }

    return null;
  }

  factory CSSColor.parse(String color) {
    if (color == null) return null;

    var match = PATTERN_RGB.firstMatch(color);
    if (match == null) return null;

    //var type = int.parse( match.group(1) ) ;
    var red = int.parse(match.group(2));
    var green = int.parse(match.group(3));
    var blue = int.parse(match.group(4));
    var alpha = parseDouble(match.group(5));

    if (alpha != null && alpha != 1) {
      return CSSColorRGBA(red, green, blue, alpha);
    } else {
      return CSSColorRGB(red, green, blue);
    }
  }
}

class CSSColorRGB extends CSSColor {
  int _red;

  int _green;

  int _blue;

  CSSColorRGB(this._red, this._green, this._blue) : super();

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

  String get args {
    return '$_red, $_green, $_blue';
  }

  @override
  String toString() {
    return 'rgb($args)';
  }
}

class CSSColorRGBA extends CSSColorRGB {
  double _alpha;

  CSSColorRGBA(int red, int green, int blue, this._alpha)
      : super(red, green, blue);

  double get alpha => _alpha;

  set alpha(double value) {
    _alpha = _clip(value, 0, 1, 1);
  }

  @override
  String get args {
    return '${super.args}, $_alpha';
  }

  @override
  String toString() {
    return 'rgba($args)';
  }
}

num _clip(num n, num min, num max, [num def]) {
  n ??= def;
  if (n < min) return min;
  if (n > max) return max;
  return n;
}
