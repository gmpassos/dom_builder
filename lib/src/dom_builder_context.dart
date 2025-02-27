import 'package:swiss_knife/swiss_knife.dart';

import 'dom_builder_attribute.dart';
import 'dom_builder_base.dart';
import 'dom_builder_css.dart';
import 'dom_builder_generator.dart';
import 'dom_builder_treemap.dart';

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

  Viewport(this.width, this.height, [int? deviceWidth, int? deviceHeight])
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

typedef NamedElementGenerator<T extends Object> = T? Function(
    String name,
    DOMGenerator<T>? domGenerator,
    DOMTreeMap<T> treeMap,
    DOMElement? domParent,
    Object? parent,
    String? tag,
    Map<String, DOMAttribute> attributes);

typedef IntlMessageResolver = String? Function(String key,
    [Map<String, dynamic>? parameters]);

/// Converts [resolver] to [IntlMessageResolver].
IntlMessageResolver? toIntlMessageResolver(Object? resolver) {
  if (resolver == null) {
    return null;
  } else if (resolver is IntlMessageResolver) {
    return resolver;
  } else if (resolver is String Function(String key)) {
    return (k, [p]) => resolver(k);
  } else if (resolver is dynamic Function(Object? key)) {
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
class DOMContext<T extends Object> {
  /// Creates a copy of this instance.
  DOMContext<T> copy() {
    var context = DOMContext(
        parent: parent,
        viewport: viewport,
        resolveCSSViewportUnit: resolveCSSViewportUnit);
    context.domGenerator = domGenerator;
    context.namedElementAttribute = namedElementAttribute;
    context.namedElementProvider = namedElementProvider;
    context.variables = Map.from(deepCopy(variables)!);
    context.intlMessageResolver = intlMessageResolver;
    return context;
  }

  DOMGenerator<T>? _domGenerator;

  DOMGenerator<T>? get domGenerator => _domGenerator;

  set domGenerator(DOMGenerator<T>? generator) {
    if (generator == null) throw ArgumentError.notNull('generator');
    _domGenerator = generator;
  }

  IntlMessageResolver? intlMessageResolver;

  String? resolveIntlMessage(String key, [Map<String, dynamic>? parameters]) {
    var msgResolver = intlMessageResolver;
    return msgResolver != null ? msgResolver(key, parameters) : null;
  }

  final DOMContext<T>? parent;

  /// The [Viewport] of this context.
  Viewport? viewport;

  /// If [true] will resolve any viewport [CSSUnit] to `px` when
  /// generating a DOM tree.
  bool resolveCSSViewportUnit;

  /// If [true] will resolve any [CSSURL] when
  /// generating a DOM tree.
  bool resolveCSSURL;

  DOMContext(
      {this.parent,
      this.viewport,
      this.resolveCSSViewportUnit = false,
      this.resolveCSSURL = false,
      Map<String, dynamic>? variables,
      this.intlMessageResolver}) {
    if (variables != null) {
      this.variables = variables;
    }
  }

  /// Resolves a Viewport [CSSUnit] (`vw`, `vh`, `vmin`, `vmax`) [value]
  /// to a `px` value as [String].
  String resolveCSSViewportUnitValue(num value, CSSUnit unit,
      {bool originalValueAsComment = true}) {
    var resolved = resolveViewportCSSLength(value, unit);
    var resolvedStr = resolved.toString(this);

    if (originalValueAsComment) {
      var originalValue = resolveCSSUnitValue(value, unit);
      resolvedStr += ' /* DOMContext-original-value: $originalValue */';
    }

    return resolvedStr;
  }

  CSSLength resolveViewportCSSLength(num value, CSSUnit unit) {
    if (viewport == null) {
      return CSSLength(value, unit);
    }
    var resolvedViewportValue =
        _computeViewportCSSLength(value, unit, viewport);
    return resolvedViewportValue ?? CSSLength(value, unit);
  }

  CSSLength? _computeViewportCSSLength(
      num value, CSSUnit unit, Viewport? viewport) {
    var ratio = value / 100;

    switch (unit) {
      case CSSUnit.vw:
        return CSSLength(ratio * viewport!.width);
      case CSSUnit.vh:
        return CSSLength(ratio * viewport!.height);
      case CSSUnit.vmin:
        return CSSLength(ratio * viewport!.vmin);
      case CSSUnit.vmax:
        return CSSLength(ratio * viewport!.vmax);
      default:
        return null;
    }
  }

  /// Resolves a [CSSUnit] [value] to a [String]
  String resolveCSSUnitValue(num value, CSSUnit unit) {
    return '$value${getCSSUnitName(unit)}';
  }

  /// The resolver [Function] for [CSSURL].
  String Function(String? url)? cssURLResolver;

  /// Resolves a [CSSURL] [value]
  String? resolveCSSURLValue(String? url) {
    if (cssURLResolver != null) {
      return cssURLResolver!(url);
    }
    return url;
  }

  static final String defaultNamedElementAttribute = 'name';

  String namedElementAttribute = defaultNamedElementAttribute;

  NamedElementGenerator<T>? namedElementProvider;

  bool hasNamedElementNameValue(DOMElement domElement) {
    var elementName = getNamedElementNameValue(domElement);
    return elementName != null && elementName.isNotEmpty;
  }

  String? getNamedElementNameValue(DOMElement domElement) {
    if (namedElementProvider == null) return null;

    var elementName = domElement.getAttributeValue(namedElementAttribute);
    if (elementName != null && elementName.isNotEmpty) {
      return elementName;
    } else {
      return null;
    }
  }

  T? resolveNamedElement(DOMElement? domParent, T? parent,
      DOMElement domElement, DOMTreeMap<T> treeMap) {
    final namedElementProvider = this.namedElementProvider;
    if (namedElementProvider == null) return null;

    var elementName = domElement.getAttributeValue(namedElementAttribute);

    if (elementName != null && elementName.isNotEmpty) {
      var element = namedElementProvider(elementName, _domGenerator, treeMap,
          domParent, parent, domElement.tag, domElement.domAttributes);
      return element;
    } else {
      return null;
    }
  }

  Map<String, dynamic>? _variables;

  Map<String, dynamic> get variables {
    var vars = parent != null ? parent!.variables : <String, dynamic>{};

    if (_variables != null) {
      vars.addAll(_variables!);
    }

    return vars;
  }

  set variables(Map<String, dynamic> value) => _variables = value;

  void putVariable(String key, Object? value) {
    _variables ??= {};
    _variables![key] = value;
  }

  dynamic getVariable(String key, Object? value) =>
      _variables != null ? _variables![key] : null;

  void Function(DOMTreeMap<T> treeMap, DOMNode domElement, T element,
      DOMContext<T> context)? onPreElementCreated;

  void Function(DOMTreeMap<T> treeMap)? preFinalizeGeneratedTree;

  String resolveSource(String url) {
    if (parent != null) {
      var resolvedURL = parent!.resolveSource(url);
      return resolvedURL;
    }

    if (_domGenerator != null) {
      return domGenerator!.resolveSource(url);
    }
    return url;
  }

  @override
  String toString() {
    return 'DOMContext{viewport: $viewport, resolveCSSViewportUnit: $resolveCSSViewportUnit resolveCSSURL: $resolveCSSURL}';
  }
}
