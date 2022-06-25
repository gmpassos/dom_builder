import 'dart:async';

import 'package:collection/collection.dart';

import 'dom_builder_base.dart';
import 'dom_builder_context.dart';
import 'dom_builder_helpers.dart';
import 'dom_builder_template.dart';

class _DSXKey {
  final int id;

  _DSXKey(this.id);

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is _DSXKey && runtimeType == other.runtimeType && id == other.id;

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() {
    return '_DSXKey{id: $id}';
  }
}

/// A DSX object.
///
/// Can be a [Function]/lambda that will be inserted into DOM definitions
/// passed to [$dsx].
class DSX<T> {
  static final Expando<List<DSX>> _objectsToDSX = Expando<List<DSX>>();
  static final Expando<Object> _dsxToObjectSource = Expando<Object>();
  static final Expando<Object> _dsxToObject = Expando<Object>();
  static final Map<_DSXKey, DSX> _keyToDSK = <_DSXKey, DSX>{};

  static Object? objectFromDSX(DSX dsx) {
    var o = _dsxToObject[dsx];
    if (o == null) {
      dsx.check();
    }
    return o;
  }

  static Object? objectSourceFromDSX(DSX dsx) {
    var o = _dsxToObjectSource[dsx];
    if (o == null) {
      dsx.check();
    }
    return o;
  }

  static Object? _objectFromKey(_DSXKey key) {
    var dsx = _fromKey(key);
    return dsx != null ? objectFromDSX(dsx) : null;
  }

  static DSX? _fromKey(_DSXKey key) {
    var dsx = _keyToDSK[key];
    dsx?.check();
    return dsx;
  }

  /// Resolve [o] to the related [DSX.object] of a [DSX] instance.
  static Object? resolveObject(dynamic o) {
    if (o == null) {
      return null;
    } else if (o is DSX) {
      return DSX.objectFromDSX(o);
    } else if (o is _DSXKey) {
      return DSX._objectFromKey(o);
    } else if (o is int) {
      var key = _DSXKey(o);
      return DSX._objectFromKey(key);
    } else if (o is String) {
      if (isDSXMark(o)) {
        var id = parseDSXMarkID(o)!;
        var key = _DSXKey(id);
        return DSX._objectFromKey(key);
      } else {
        var id = int.parse(o.trim());
        var key = _DSXKey(id);
        return DSX._objectFromKey(key);
      }
    }

    throw StateError("Can't resolve: $o");
  }

  /// Resolve [o] to a [DSX] object.
  static DSX? resolveDSX(dynamic o) {
    if (o == null) {
      return null;
    } else if (o is DSX) {
      return o;
    } else if (o is _DSXKey) {
      return DSX._fromKey(o);
    } else if (o is int) {
      return DSX._fromKey(_DSXKey(o));
    } else if (o is String) {
      if (isDSXMark(o)) {
        var id = parseDSXMarkID(o)!;
        return DSX._fromKey(_DSXKey(id));
      } else {
        var id = int.parse(o.trim());
        return DSX._fromKey(_DSXKey(id));
      }
    }

    throw StateError("Can't resolve: $o");
  }

  static final RegExp markRegExp = RegExp(r'^__DSX__(?:[a-z]+_)?(\d+)$');

  /// Returns `true` if [s] is a [DSX] reference mark. Example: `__DSX__function_3`
  static bool isDSXMark(String s) {
    if (s.length < 8 || !s.startsWith('__DSX__')) {
      return false;
    }

    var hasMatch = markRegExp.hasMatch(s);
    return hasMatch;
  }

  /// Parses [s] to a [DSX] reference mark ID.
  static int? parseDSXMarkID(String s) {
    var match = markRegExp.firstMatch(s);
    if (match == null) return null;
    var idStr = match.group(1);
    if (idStr == null) return null;
    var id = int.parse(idStr);
    return id;
  }

  factory DSX.varArgs(
    Object objSource,
    T obj, [
    dynamic a1,
    dynamic a2,
    dynamic a3,
    dynamic a4,
    dynamic a5,
    dynamic a6,
    dynamic a7,
    dynamic a8,
    dynamic a9,
    dynamic a10,
  ]) {
    if (a10 != null) {
      return DSX(objSource, obj,
          parameters: [a1, a2, a3, a4, a5, a6, a7, a8, a9, 10]);
    } else if (a9 != null) {
      return DSX(objSource, obj,
          parameters: [a1, a2, a3, a4, a5, a6, a7, a8, a9]);
    } else if (a8 != null) {
      return DSX(objSource, obj, parameters: [a1, a2, a3, a4, a5, a6, a7, a8]);
    } else if (a7 != null) {
      return DSX(objSource, obj, parameters: [a1, a2, a3, a4, a5, a6, a7]);
    } else if (a6 != null) {
      return DSX(objSource, obj, parameters: [a1, a2, a3, a4, a5, a6]);
    } else if (a5 != null) {
      return DSX(objSource, obj, parameters: [a1, a2, a3, a4, a5]);
    } else if (a4 != null) {
      return DSX(objSource, obj, parameters: [a1, a2, a3, a4]);
    } else if (a3 != null) {
      return DSX(objSource, obj, parameters: [a1, a2, a3]);
    } else if (a2 != null) {
      return DSX(objSource, obj, parameters: [a1, a2]);
    } else if (a1 != null) {
      return DSX(objSource, obj, parameters: [a1]);
    }

    return DSX(objSource, obj);
  }

  static bool _isPrimitive(dynamic o) {
    return o == null || o is String || o is num || o is bool;
  }

  /// Creates a DSX object that makes a reference to [object] with [parameters].
  factory DSX(Object objSource, T obj, {List? parameters}) {
    if (_isPrimitive(objSource) || _isPrimitive(obj)) {
      var dsx = DSX<T>._(parameters);

      _dsxToObjectSource[dsx] = objSource;
      _dsxToObject[dsx] = obj;
      _keyToDSK[dsx._key] ??= dsx;

      print('primitive> $dsx > $objSource ; $obj');

      return dsx;
    }

    var prevDSX = _objectsToDSX[objSource];
    prevDSX ??= _objectsToDSX[obj as Object];

    if (prevDSX != null) {
      for (var e in prevDSX) {
        if (e.equalsParameters(parameters)) {
          var dsx = e as DSX<T>;
          if (identical(dsx.objectSource, objSource)) {
            return dsx;
          }
        }
      }

      var dsx = DSX<T>._(parameters);
      prevDSX.add(dsx);

      _objectsToDSX[objSource] = prevDSX;
      _objectsToDSX[obj as Object] = prevDSX;
      _dsxToObjectSource[dsx] = objSource;
      _dsxToObject[dsx] = obj;
      _keyToDSK[dsx._key] ??= dsx;

      return dsx;
    } else {
      var dsx = DSX<T>._(parameters);

      _objectsToDSX[objSource] = [dsx];
      _objectsToDSX[obj as Object] = [dsx];
      _dsxToObjectSource[dsx] = objSource;
      _dsxToObject[dsx] = obj;
      _keyToDSK[dsx._key] ??= dsx;

      return dsx;
    }
  }

  static int _idCount = 0;

  final int id = ++_idCount;

  final List? parameters;

  late final _DSXKey _key;

  DSX._([this.parameters]) {
    _key = _DSXKey(id);
  }

  int get keyID => _key.id;

  DSXResolver createResolver() => DSXResolver(this);

  Object? get objectSource => _dsxToObjectSource[this];

  Object? get object => _dsxToObject[this];

  /// Check the referenced [object] that this [DSX] instance still exists.
  DSX<T> check() {
    var objSrc = _dsxToObjectSource[this];
    var obj = _dsxToObject[this];

    if (objSrc == null && obj == null) {
      _dsxToObjectSource[this] = null;
      _dsxToObject[this] = null;
      _keyToDSK.remove(_key);
    }

    return this;
  }

  static final DeepCollectionEquality _deepCollectionEquality =
      DeepCollectionEquality();

  /// Returns `true` if [parameters] are equals to `this.parameters`.
  bool equalsParameters(List? parameters) {
    var thisParameters = this.parameters;
    if (thisParameters == null) {
      return parameters == null;
    }

    if (parameters == null) {
      return false;
    }

    if (thisParameters.length != parameters.length) {
      return false;
    }

    var length = parameters.length;

    for (var i = 0; i < length; ++i) {
      var a = thisParameters[i];
      var b = parameters[i];

      if (identical(a, b)) continue;

      if (!_deepCollectionEquality.equals(a, b)) {
        return false;
      }
    }

    return true;
  }

  bool get isFunction => object is Function;

  bool get isFuture => object is Future;

  /// Returns the type of this DSX object as [String].
  String get type {
    var obj = object;
    if (obj is Function) {
      return 'function';
    } else if (obj is Future) {
      return 'future';
    }
    return '';
  }

  dynamic call() {
    var f = object as Function;

    var a = parameters;
    if (a == null || a.isEmpty) {
      return f();
    } else if (a.length == 1) {
      return f(a[0]);
    } else if (a.length == 2) {
      return f(a[0], a[1]);
    } else if (a.length == 3) {
      return f(a[0], a[1], a[2]);
    } else if (a.length == 4) {
      return f(a[0], a[1], a[2], a[3]);
    } else if (a.length == 5) {
      return f(a[0], a[1], a[2], a[3], a[4]);
    } else if (a.length == 6) {
      return f(a[0], a[1], a[2], a[3], a[4], a[5]);
    } else if (a.length == 7) {
      return f(a[0], a[1], a[2], a[3], a[4], a[5], a[6]);
    } else if (a.length == 8) {
      return f(a[0], a[1], a[2], a[3], a[4], a[5], a[6], a[7]);
    } else if (a.length == 9) {
      return f(a[0], a[1], a[2], a[3], a[4], a[5], a[6], a[7], a[8]);
    } else if (a.length == 10) {
      return f(a[0], a[1], a[2], a[3], a[4], a[5], a[6], a[7], a[8], a[9]);
    } else {
      return null;
    }
  }

  /// This DSX object referend mark as [String].
  @override
  String toString() {
    var type = this.type;
    if (type.isNotEmpty) {
      type += '_';
    }
    return '{{__DSX__$type$id}}';
  }
}

class DSXResolver<T> {
  final DSX<T> dsx;

  DSXResolver(this.dsx) {
    print('DSXResolver> $dsx > $type');
  }

  Object? get objectSource => dsx.objectSource;

  Object? get object => dsx.object;

  bool get isFunction => dsx.isFunction;

  bool get isFuture => dsx.isFuture;

  Future? _future;

  Object? _resolvedValue;

  Object? get resolvedValue => _resolvedValue;

  StreamSubscription? _resolvedValueListenerSubscription;

  DOMElement? _resolvedElement;

  DOMElement? get resolvedElement => _resolvedElement;

  void reset() {
    _resolvedValue = null;

    _resolvedElement?.getRuntime().remove();
    _resolvedElement = null;
  }

  /// Resolve this [DSX] object value.
  ///
  /// - If [isFunction], calls it with [parameters].
  Object? resolveValue(
      {QueryElementProvider? elementProvider,
      IntlMessageResolver? intlMessageResolver}) {
    if (_resolvedValue != null) {
      assert(_resolvedElement != null);
      return _resolvedValue;
    }

    if (isFunction) {
      var value = call();
      setResolvedValue(value);
      return value;
    } else if (isFuture) {
      assert(_future == null);
      var future = object as Future;
      future.then(setResolvedValue);
      _future = future;
      setResolvedValue('...');
      return _resolvedValue;
    } else {
      var value = object;
      setResolvedValue(value);
      return value;
    }
  }

  DOMElement setResolvedValue(dynamic value) {
    _resolvedValue = value;

    var element = _valueAsElement(value);

    if (_resolvedValueListenerSubscription == null) {
      var listenerSubscription = _listenDSXValue(objectSource, (objSrc) {
        var value = _toDSXValue(objSrc, objSrc);
        setResolvedValue(value);
      });
      _resolvedValueListenerSubscription = listenerSubscription;
    }

    if (_resolvedElement != null) {
      var runtime = _resolvedElement!.getRuntime();

      if (runtime.domGenerator.isNodeInDOM(runtime.node)) {
        runtime.replaceBy([element]);
      } else {
        runtime.remove();
        _resolvedValueListenerSubscription?.cancel();
        reset();
      }
    }

    _resolvedElement = element;

    return element;
  }

  DOMElement _valueAsElement(Object? value) {
    value = _toDSXValue(value, value);

    List<DOMNode> nodes;
    if (value == null) {
      nodes = <DOMNode>[];
    } else if (value is String && isHTMLElement(value)) {
      nodes = $html(value);
    } else {
      nodes = DOMNode.parseNodes(value);
    }

    if (nodes.isEmpty) {
      return $span();
    }

    if (nodes.length == 1) {
      var elem = nodes.first;
      return elem is DOMElement ? elem : $span(content: elem);
    } else {
      return $span(content: nodes);
    }
  }

  /// Calls [resolveValue] and returns the corresponding [DOMElement] for the value.
  Object? resolveElement(
      {QueryElementProvider? elementProvider,
      IntlMessageResolver? intlMessageResolver}) {
    resolveValue(
        elementProvider: elementProvider,
        intlMessageResolver: intlMessageResolver);
    return _resolvedElement!;
  }

  /// Calls [resolveValue] to a [String].
  String? resolveValueAsString(
      {QueryElementProvider? elementProvider,
      IntlMessageResolver? intlMessageResolver}) {
    return resolveValue(
            elementProvider: elementProvider,
            intlMessageResolver: intlMessageResolver)
        ?.toString();
  }

  /// Call this DSX object as a [Function], passing [parameters] if present.
  dynamic call() => dsx.call();

  /// Returns the type of this DSX object as [String].
  String get type => dsx.type;
}

/// Parses [o] to a [List<DOMNode>], resolving [DSX] objects.
List<DOMNode> $dsx(dynamic o) {
  return _dsxNodes(o);
}

/// Converts a call to [f] to a DSX object.
DSX $dsxCall(
  Function f, [
  dynamic a1,
  dynamic a2,
  dynamic a3,
  dynamic a4,
  dynamic a5,
  dynamic a6,
  dynamic a7,
  dynamic a8,
  dynamic a9,
  dynamic a10,
]) {
  return f.dsx(a1, a2, a3, a4, a5, a6, a7, a8, a9, a10);
}

List<DOMNode> _dsxNodes(dynamic o) {
  var list = _dsxToList(o);
  _dsxJoinStrings(list);

  var list2 = list.expand(_dsxToDOMNodeList).toList();

  var nodes = _dsxToDOMNodeList(list2);
  return nodes;
}

List<DOMNode> _dsxToDOMNodeList(dynamic o) {
  if (o is DOMNode) {
    return <DOMNode>[o];
  } else if (o is List<DOMNode>) {
    return o;
  } else if (o is List) {
    return o.expand((e) => _dsxToDOMNodeList(e)).toList();
  }

  return $html('$o');
}

List _dsxToList(dynamic o) {
  if (o == null) {
    return [];
  } else if (o is List<DOMNode>) {
    return o;
  } else if (o is List) {
    return o.expand(_dsxToList).toList();
  } else {
    return [o];
  }
}

void _dsxJoinStrings(List list) {
  for (var i = 1; i < list.length;) {
    var prev = list[i - 1];
    var elem = list[i];

    if (elem is String && prev is String) {
      var s = prev + elem;
      list[i - 1] = s;
      list.remove(i);
    } else {
      ++i;
    }
  }
}

abstract class DSXType<T> {
  DSX<T> toDSX();
}

/// DSX extensions for [FutureOr].
extension DSXFutureOrExtension<T> on FutureOr<T> {
  dynamic dsx([
    dynamic a1,
    dynamic a2,
    dynamic a3,
    dynamic a4,
    dynamic a5,
    dynamic a6,
    dynamic a7,
    dynamic a8,
    dynamic a9,
    dynamic a10,
  ]) {
    if (this == null) return null;

    var dsx = _toDSX(this, this, a1, a2, a3, a4, a5, a6, a7, a8, a9, a10);
    if (dsx != null) return dsx;

    var dsxValue = _toDSXValue(this);
    if (dsxValue != null) {
      dsx = _toDSX(this, dsxValue, a1, a2, a3, a4, a5, a6, a7, a8, a9, a10);
    }

    dsx ??= DSX(this as Object, this);

    return dsx;
  }

  static dynamic _toDSX<T>(
      dynamic oSrc, dynamic o, a1, a2, a3, a4, a5, a6, a7, a8, a9, a10) {
    if (o is DSX) {
      return o;
    } else if (o is Future<T>) {
      return DSX<Future<T>>(oSrc, o);
    } else if (o is Function) {
      return DSX<Function>.varArgs(
          oSrc, o, a1, a2, a3, a4, a5, a6, a7, a8, a9, a10);
    } else if (o is String) {
      return DSX<String>(oSrc, o);
    } else if (o is int) {
      return DSX<int>(oSrc, o);
    } else if (o is double) {
      return DSX<double>(oSrc, o);
    } else if (o is bool) {
      return DSX<bool>(oSrc, o);
    } else if (o is DSXType) {
      return o.toDSX();
    } else {
      return null;
    }
  }
}

final Set<Type> _typesWithoutToDSXValue = <Type>{};

Object? _toDSXValue(dynamic o, [dynamic def]) {
  if (o == null ||
      o is String ||
      o is num ||
      o is bool ||
      o is Function ||
      o is Future) {
    return o;
  }

  var type = o.runtimeType;

  if (_typesWithoutToDSXValue.contains(type)) {
    return def;
  }

  try {
    var value = o.toDSXValue();
    return value;
  } catch (e) {
    _typesWithoutToDSXValue.add(type);
    return def;
  }
}

final Set<Type> _typesWithoutListenDSXValue = <Type>{};

StreamSubscription? _listenDSXValue(
    dynamic o, void Function(dynamic event) listener) {
  if (o == null ||
      o is String ||
      o is num ||
      o is bool ||
      o is Function ||
      o is Future) {
    return null;
  }

  var type = o.runtimeType;

  if (_typesWithoutListenDSXValue.contains(type)) {
    return null;
  }

  try {
    var subscription = o.listenDSXValue(listener);
    return subscription;
  } catch (e) {
    _typesWithoutListenDSXValue.add(type);
    return null;
  }
}

/// DSX extensions for [Future].
extension DSXFutureExtension<T> on Future<T> {
  DSX<Future<T>> dsx() => DSX(this, this);
}
