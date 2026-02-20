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
  String toString() => '_DSXKey{id: $id}';
}

enum DSXObjectType {
  function('function', 'function_'),
  future('future', 'future_'),
  generic('', '');

  final String placeholder;

  final String placeholderPrefix;

  const DSXObjectType(this.placeholder, this.placeholderPrefix);

  static forObject(Object? obj) {
    if (obj is Function) {
      return DSXObjectType.function;
    } else if (obj is Future) {
      return DSXObjectType.future;
    }
    return DSXObjectType.generic;
  }
}

/// A DSX object.
///
/// Can be a [Function]/lambda that will be inserted into DOM definitions
/// passed to [$dsx].
class DSX<T extends Object> {
  static final Expando<List<DSX>> _objectsToDSX = Expando();
  static final Expando<Object> _dsxToObjectSource = Expando();
  static final Expando<Object> _dsxToObject = Expando();

  static final Set<DSX> _notManagedDSXs = {};
  static final Map<_DSXKey, WeakReference<DSX>> _keyToDSK = {};

  static bool applyLifeCycleManager(
      DSX dsx, DSXLifecycleManager? lifecycleManager) {
    if (lifecycleManager == null) return false;

    if (!_notManagedDSXs.contains(dsx)) return false;

    if (!_validateDSKKey(dsx._key)) return false;

    var ok = lifecycleManager.manageDSX(dsx);
    if (ok) {
      _notManagedDSXs.remove(dsx);
    }

    return ok;
  }

  static bool _validateDSKKey(_DSXKey key) {
    var prev = _keyToDSK[key];
    if (prev == null) return false;
    if (prev.target == null) {
      _keyToDSK.remove(key);
      return false;
    }
    return true;
  }

  static void purge() {
    _keyToDSK.removeWhere((key, dsxRef) {
      var dsx = dsxRef.target;
      if (dsx == null) return true;
      var objSrc = _dsxToObjectSource[dsx];
      var obj = _dsxToObject[dsx];
      if (objSrc == null && obj == null) {
        _notManagedDSXs.remove(dsx);
        return true;
      }
      return false;
    });
  }

  static Object? objectFromDSX(DSX dsx) {
    var o = _dsxToObject[dsx];
    if (o == null) {
      if (!dsx.check()) return null;
    }
    return o;
  }

  static Object? objectSourceFromDSX(DSX dsx) {
    var o = _dsxToObjectSource[dsx];
    if (o == null) {
      if (!dsx.check()) return null;
    }
    return o;
  }

  static Object? _objectFromKey(_DSXKey key) {
    var dsx = _fromKey(key);
    return dsx != null ? objectFromDSX(dsx) : null;
  }

  static DSX? _fromKey(_DSXKey key) {
    var dsxRef = _keyToDSK[key];
    if (dsxRef == null) return null;

    var dsx = dsxRef.target;
    if (dsx == null) {
      _keyToDSK.remove(key);
      return null;
    }

    if (!dsx.check()) return null;

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
      var type = DSXObjectType.forObject(obj);
      var dsx = DSX<T>._(type, parameters);

      _dsxToObjectSource[dsx] = objSource;
      _dsxToObject[dsx] = obj;

      _validateDSKKey(dsx._key);
      _keyToDSK[dsx._key] ??= WeakReference(dsx);
      _notManagedDSXs.add(dsx);

      print('primitive> $dsx > $objSource ; $obj');

      return dsx;
    }

    var prevDSX = _objectsToDSX[objSource];
    prevDSX ??= _objectsToDSX[obj];

    if (prevDSX != null) {
      for (var e in prevDSX) {
        if (e.equalsParameters(parameters)) {
          var dsx = e as DSX<T>;
          if (identical(dsx.objectSource, objSource)) {
            return dsx;
          }
        }
      }

      var type = DSXObjectType.forObject(obj);
      var dsx = DSX<T>._(type, parameters);
      prevDSX.add(dsx);

      _objectsToDSX[objSource] = prevDSX;
      _objectsToDSX[obj] = prevDSX;
      _dsxToObjectSource[dsx] = objSource;
      _dsxToObject[dsx] = obj;

      _validateDSKKey(dsx._key);
      _keyToDSK[dsx._key] ??= WeakReference(dsx);
      _notManagedDSXs.add(dsx);

      return dsx;
    } else {
      var type = DSXObjectType.forObject(obj);
      var dsx = DSX<T>._(type, parameters);

      _objectsToDSX[objSource] = [dsx];
      _objectsToDSX[obj] = [dsx];
      _dsxToObjectSource[dsx] = objSource;
      _dsxToObject[dsx] = obj;

      _validateDSKKey(dsx._key);
      _keyToDSK[dsx._key] ??= WeakReference(dsx);
      _notManagedDSXs.add(dsx);

      return dsx;
    }
  }

  static int _idCount = 0;

  final int id = ++_idCount;

  final DSXObjectType type;

  List? _parameters;

  List? get parameters => _parameters;

  late final _DSXKey _key;

  DSX._(this.type, [List? parameters]) : _parameters = parameters {
    _key = _DSXKey(id);
  }

  int get keyID => _key.id;

  DSXResolver createResolver({DSXLifecycleManager? lifecycleManager}) =>
      DSXResolver(this, lifecycleManager: lifecycleManager);

  Object? get objectSource => _dsxToObjectSource[this];

  Object? get object => _dsxToObject[this];

  /// Check the referenced [object] that this [DSX] instance still exists.
  bool check() {
    var objSrc = _dsxToObjectSource[this];
    var obj = _dsxToObject[this];

    if (objSrc == null && obj == null) {
      dispose();
      return false;
    }

    return true;
  }

  void dispose() {
    _parameters = null;

    _dsxToObjectSource.remove(this);
    _dsxToObject.remove(this);
    _keyToDSK.remove(_key);
    _notManagedDSXs.remove(this);
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

  bool get isFunction => type == DSXObjectType.function;

  bool get isFuture => type == DSXObjectType.future;

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
    var placeholderPrefix = type.placeholderPrefix;
    return '{{__DSX__$placeholderPrefix$id}}';
  }
}

class DSXResolution {
  static const resolveDSX = DSXResolution.resolve(true);
  static const skipDSX = DSXResolution.resolve(false);

  final bool resolve;

  final DSXLifecycleManager? lifecycleManager;

  const DSXResolution.resolve(this.resolve) : lifecycleManager = null;

  DSXResolution._(this.resolve, this.lifecycleManager);

  DSXResolution.lifecycleManager(this.lifecycleManager, {this.resolve = true});

  DSXResolution copyWith(
      {bool? resolve,
      DSXLifecycleManager? lifecycleManager,
      bool nullLifecycleManager = false}) {
    lifecycleManager ??= this.lifecycleManager;

    if (nullLifecycleManager) {
      lifecycleManager = null;
    }

    return DSXResolution._(resolve ?? this.resolve, lifecycleManager);
  }

  DSXResolution noLifecycleManager() => DSXResolution._(resolve, null);

  @override
  String toString() =>
      'DSXResolution{resolve: $resolve, lifecycleManager: $lifecycleManager}';
}

abstract class DSXLifecycleManager {
  bool isManagedDSX(DSX<Object> dsx);

  bool manageDSX(DSX<Object> dsx);

  bool disposeDSX(DSX<Object> dsx);

  int disposeManagedDSXs();
}

class DSXResolver<T extends Object> {
  final DSX<T> dsx;

  final DSXLifecycleManager? lifecycleManager;

  DSXResolver(this.dsx, {this.lifecycleManager}) {
    DSX.applyLifeCycleManager(dsx, lifecycleManager);
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

    final object = this.object;

    if (isFunction) {
      var value = call();
      setResolvedValue(value);
      return value;
    } else if (isFuture) {
      assert(_future == null);

      var future = object as Future;
      future.then(setResolvedValue);
      _future = future;

      future.whenComplete(() {
        if (identical(future, _future)) {
          _future = null;
        }
      });

      setResolvedValue('...');
      return _resolvedValue;
    } else {
      var value = object;
      setResolvedValue(object);
      return value;
    }
  }

  DOMElement setResolvedValue(dynamic value) {
    _resolvedValue = value;

    var element = _valueAsElement(value);

    // Call `listenDSXValue` if type defines method:
    _resolvedValueListenerSubscription ??= _listenDSXValue(
      objectSource,
      (objSrc) {
        var value = _toDSXValue(objSrc, objSrc);
        setResolvedValue(value);
      },
    );

    // Remove previous `_resolvedElement`:
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
  DSXObjectType get type => dsx.type;

  @override
  String toString() =>
      'DSXResolver[$dsx]{lifecycleManager: $lifecycleManager, resolvedElement: $_resolvedElement, resolvedValue: $_resolvedValue}';
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
  return f.dsx(a1, a2, a3, a4, a5, a6, a7, a8, a9, a10)!;
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

abstract class DSXType<T extends Object> {
  DSX<T> toDSX();
}

/// DSX extensions for [FutureOr].
extension DSXFutureOrExtension<T extends Object> on FutureOr<T?> {
  DSX? dsx([
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
    final self = this;
    if (self == null) return null;

    var dsx = _toDSX(self as Object, self as Object, a1, a2, a3, a4, a5, a6, a7,
        a8, a9, a10);
    if (dsx != null) return dsx;

    var dsxValue = _toDSXValue(self);
    if (dsxValue != null) {
      dsx = _toDSX(
          self as Object, dsxValue, a1, a2, a3, a4, a5, a6, a7, a8, a9, a10);
    }

    dsx ??= DSX<T>(self as Object, self as T);

    return dsx;
  }

  static DSX? _toDSX<T extends Object>(
      Object oSrc, Object o, a1, a2, a3, a4, a5, a6, a7, a8, a9, a10) {
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

extension _ExpandoExtension<T extends Object> on Expando<T> {
  void remove(Object key) {
    this[key] = null;
  }
}
