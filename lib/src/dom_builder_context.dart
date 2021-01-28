import 'package:dom_builder/dom_builder.dart';
import 'package:swiss_knife/swiss_knife.dart';

/// Represents browser window Viewport.
class Viewport {
  /// The device width.
  int deviceWidth;

  /// The device height.
  int deviceHeight;

  /// The Viewport width.
  int width;

  /// The Viewport height.
  int height;

  Viewport(this.width, this.height, [int deviceWidth, int deviceHeight])
      : deviceWidth = deviceWidth ?? width,
        deviceHeight = deviceHeight ?? height {
    _check();
  }

  void _check() {
    _checkField('deviceWidth', deviceWidth, 1);
    _checkField('deviceHeight', deviceHeight, 1);
    _checkField('width', width, 1);
    _checkField('height', height, 1);

    if (width > deviceWidth) {
      throw ArgumentError('width > deviceWidth: $width > $deviceWidth');
    }

    if (height > deviceHeight) {
      throw ArgumentError('height > deviceHeight: $height > $deviceHeight');
    }
  }

  void _checkField(String name, int value, int minValue) {
    if (value == null) {
      throw ArgumentError.notNull(name);
    }
    if (value < minValue) {
      throw ArgumentError('$name < $minValue: $value < $minValue');
    }
  }

  /// The smallest side of the viewport: `Math.min(width, height)`
  int get vmin => Math.min(width, height);

  /// The biggest side of the viewport: `Math.max(width, height)`
  int get vmax => Math.max(width, height);

  /// Returns [width] as a px String.
  String get widthAsPx => '${width}px';

  /// Returns [height] as a px String.
  String get heightAsPx => '${height}px';

  /// Returns [vmin] as a px String.
  String get vminAsPx => '${vmin}px';

  /// Returns [vmax] as a px String.
  String get vmaxAsPx => '${vmax}px';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Viewport &&
          runtimeType == other.runtimeType &&
          deviceWidth == other.deviceWidth &&
          deviceHeight == other.deviceHeight &&
          width == other.width &&
          height == other.height;

  @override
  int get hashCode =>
      deviceWidth.hashCode ^
      deviceHeight.hashCode ^
      width.hashCode ^
      height.hashCode;

  @override
  String toString() {
    return 'Viewport{deviceWidth: $deviceWidth, deviceHeight: $deviceHeight, width: $width, height: $height}';
  }
}

typedef NamedElementGenerator<T> = T Function(
    String name,
    DOMGenerator<T> domGenerator,
    DOMTreeMap<T> treeMap,
    DOMElement domParent,
    dynamic parent,
    String tag,
    Map<String, DOMAttribute> attributes);

typedef IntlMessageResolver = String Function(String key,
    [Map<String, dynamic> parameters]);

/// Converts [resolver] to [IntlMessageResolver].
IntlMessageResolver toIntlMessageResolver(dynamic resolver) {
  if (resolver == null) {
    return null;
  } else if (resolver is IntlMessageResolver) {
    return resolver;
  } else if (resolver is String Function(String key)) {
    return (k, [p]) => resolver(k);
  } else if (resolver is dynamic Function(dynamic key)) {
    return (k, [p]) => parseString(resolver(k));
  } else if (resolver is String Function()) {
    return (k, [p]) => resolver();
  } else if (resolver is dynamic Function()) {
    return (k, [p]) => resolver();
  } else if (resolver is Map) {
    return (k, [p]) => resolver[k];
  } else {
    throw ArgumentError('Invalid resolver type: $resolver');
  }
}

/// Represents the context of this DOM tree.
///
/// Used by [DOMGenerator] to configure some behaviors,
/// like CSS unit conversion.
class DOMContext<T> {
  /// Creates a copy of this instance.
  DOMContext<T> copy() {
    var context = DOMContext(
        parent: parent,
        viewport: viewport,
        resolveCSSViewportUnit: resolveCSSViewportUnit);
    context.domGenerator = domGenerator;
    context.namedElementAttribute = namedElementAttribute;
    context.namedElementProvider = namedElementProvider;
    context.variables = Map.from(deepCopy(variables));
    context.intlMessageResolver = intlMessageResolver;
    return context;
  }

  DOMGenerator<T> _domGenerator;

  DOMGenerator<T> get domGenerator => _domGenerator;

  set domGenerator(DOMGenerator<T> generator) {
    if (generator == null) throw ArgumentError.notNull('generator');
    _domGenerator = generator;
  }

  IntlMessageResolver intlMessageResolver;

  String resolveIntlMessage(String key, [Map<String, dynamic> parameters]) {
    var msgResolver = intlMessageResolver;
    return msgResolver != null ? msgResolver(key, parameters) : null;
  }

  final DOMContext<T> parent;

  /// The [Viewport] of this context.
  Viewport viewport;

  /// If [true] will resolve any viewport [CSSUnit] to `px` when
  /// generating a DOM tree.
  bool _resolveCSSViewportUnit = false;

  /// If [true] will resolve any [CSSURL] when
  /// generating a DOM tree.
  bool _resolveCSSURL = false;

  DOMContext(
      {this.parent,
      this.viewport,
      bool resolveCSSViewportUnit,
      bool resolveCSSURL}) {
    this.resolveCSSViewportUnit = resolveCSSViewportUnit;
    this.resolveCSSURL = resolveCSSURL;
  }

  bool get resolveCSSViewportUnit => _resolveCSSViewportUnit;

  set resolveCSSViewportUnit(bool value) {
    _resolveCSSViewportUnit = value ?? false;
  }

  /// Resolves a Viewport [CSSUnit] (`vw`, `vh`, `vmin`, `vmax`) [value]
  /// to a `px` value as [String].
  String resolveCSSViewportUnitValue(num value, CSSUnit unit,
      {bool originalValueAsComment = true}) {
    if (viewport == null) {
      return resolveCSSUnitValue(value, unit);
    }

    var resolvedViewportValue =
        _resolveCSSViewportUnitValueImpl(value, unit, viewport);
    if (resolvedViewportValue == null) {
      return resolveCSSUnitValue(value, unit);
    }

    if (originalValueAsComment ?? true) {
      var originalValue = resolveCSSUnitValue(value, unit);
      resolvedViewportValue +=
          ' /* DOMContext-original-value: $originalValue */';
    }

    return resolvedViewportValue;
  }

  String _resolveCSSViewportUnitValueImpl(
      num value, CSSUnit unit, Viewport viewport) {
    var ratio = value / 100;

    switch (unit) {
      case CSSUnit.vw:
        return '${ratio * viewport.width}px';
      case CSSUnit.vh:
        return '${ratio * viewport.height}px';
      case CSSUnit.vmin:
        return '${ratio * viewport.vmin}px';
      case CSSUnit.vmax:
        return '${ratio * viewport.vmax}px';
      default:
        return null;
    }
  }

  /// Resolves a [CSSUnit] [value] to a [String]
  String resolveCSSUnitValue(num value, CSSUnit unit) {
    return '$value${getCSSUnitName(unit)}';
  }

  bool get resolveCSSURL => _resolveCSSURL;

  set resolveCSSURL(bool value) {
    _resolveCSSURL = value ?? false;
  }

  /// The resolver [Function] for [CSSURL].
  String Function(String url) cssURLResolver;

  /// Resolves a [CSSURL] [value]
  String resolveCSSURLValue(String url) {
    if (cssURLResolver != null) {
      return cssURLResolver(url);
    }
    return url;
  }

  static final String defaultNamedElementAttribute = 'name';

  String _namedElementAttribute = defaultNamedElementAttribute;

  String get namedElementAttribute => _namedElementAttribute;

  set namedElementAttribute(String value) {
    _namedElementAttribute = value ?? defaultNamedElementAttribute;
  }

  NamedElementGenerator namedElementProvider;

  bool hasNamedElementNameValue(DOMElement domElement) {
    var elementName = getNamedElementNameValue(domElement);
    return elementName != null && elementName.isNotEmpty;
  }

  String getNamedElementNameValue(DOMElement domElement) {
    if (namedElementProvider == null || domElement == null) return null;

    var elementName = domElement.getAttributeValue(_namedElementAttribute);
    if (elementName != null && elementName.isNotEmpty) {
      return elementName;
    } else {
      return null;
    }
  }

  T resolveNamedElement(DOMElement domParent, T parent, DOMElement domElement,
      DOMTreeMap<T> treeMap) {
    if (namedElementProvider == null) return null;

    var elementName = domElement.getAttributeValue(_namedElementAttribute);

    if (elementName != null && elementName.isNotEmpty) {
      var element = namedElementProvider(elementName, _domGenerator, treeMap,
          domParent, parent, domElement.tag, domElement.domAttributes);
      return element;
    } else {
      return null;
    }
  }

  Map<String, dynamic> _variables;

  Map<String, dynamic> get variables {
    var vars = parent != null ? parent.variables : <String, dynamic>{};

    if (_variables != null) {
      vars.addAll(_variables);
    }

    return vars;
  }

  set variables(Map<String, dynamic> value) => _variables = value;

  void putVariable(String key, dynamic value) {
    _variables ??= {};
    _variables[key] = value;
  }

  dynamic getVariable(String key, dynamic value) =>
      _variables != null ? _variables[key] : null;

  void Function(DOMTreeMap<T> treeMap, DOMNode domElement, T element,
      DOMContext<T> context) onPreElementCreated;

  void Function(DOMTreeMap<T> treeMap) preFinalizeGeneratedTree;

  String resolveSource(String url) {
    if (parent != null) {
      var resolvedURL = parent.resolveSource(url);
      if (resolvedURL != null) {
        return resolvedURL;
      }
    }

    if (_domGenerator != null) {
      return domGenerator.resolveSource(url);
    }
    return url;
  }

  @override
  String toString() {
    return 'DOMContext{viewport: $viewport, _resolveCSSViewportUnit: $_resolveCSSViewportUnit}';
  }
}
