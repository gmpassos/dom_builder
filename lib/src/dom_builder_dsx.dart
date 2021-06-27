import 'package:collection/collection.dart';
import 'package:dom_builder/dom_builder.dart';

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
  static final Expando<Object> _dsxToObject = Expando<Object>();
  static final Map<_DSXKey, DSX> _keyToDSK = <_DSXKey, DSX>{};

  static Object? objectFromDSX(DSX dsx) {
    var o = _dsxToObject[dsx];
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

  /// Creates a DSX object that makes a reference to [object] with [parameters].
  factory DSX(T obj, [List? parameters]) {
    var prevDSX = _objectsToDSX[obj as Object];

    if (prevDSX != null) {
      for (var e in prevDSX) {
        if (e.equalsParameters(parameters)) {
          return e as DSX<T>;
        }
      }

      var dsx = DSX<T>._(parameters);
      prevDSX.add(dsx);

      _objectsToDSX[obj] = prevDSX;
      _dsxToObject[dsx] = obj;
      _keyToDSK[dsx.key] = dsx;

      return dsx;
    } else {
      var dsx = DSX<T>._(parameters);

      _objectsToDSX[obj] = [dsx];
      _dsxToObject[dsx] = obj;
      _keyToDSK[dsx.key] = dsx;

      return dsx;
    }
  }

  static int _idCount = 0;

  final int id = ++_idCount;

  final List? parameters;

  late final _DSXKey key;

  DSX._([this.parameters]) {
    key = _DSXKey(id);
  }

  Object? get object => _dsxToObject[this];

  /// Check the referenced [object] that this [DSX] instance still exists.
  DSX<T> check() {
    var obj = _dsxToObject[this];
    if (obj == null) {
      _dsxToObject[this] = null;
      _keyToDSK.remove(key);
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

  /// Resolve this [DSX] object.
  ///
  /// - If [isFunction] calls it with [parameters].
  Object? resolve() {
    if (isFunction) {
      var ret = call();
      return ret;
    } else {
      return object;
    }
  }

  /// calls [resolve] to a [String].
  String? resolveAsString() {
    return resolve()?.toString();
  }

  /// Call this DSX object as a [Function], passing [parameters] if present.
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

  /// Returns the type of this DSX object as [String].
  String get type {
    if (isFunction) {
      return 'function';
    }
    return '';
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

/// Parses [o] to a [List<DOMNode>], resolving [DSX] objects.
List<DOMNode> $dsx(dynamic o) {
  return _dsx_nodes(o);
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

List<DOMNode> _dsx_nodes(dynamic o) {
  var list = _dsx_toList(o);
  _dsx_joinStrings(list);

  var list2 = list.expand(_dsx_toDOMNodeList).toList();

  var nodes = _dsx_toDOMNodeList(list2);
  return nodes;
}

List<DOMNode> _dsx_toDOMNodeList(dynamic o) {
  if (o is DOMNode) {
    return <DOMNode>[o];
  } else if (o is List<DOMNode>) {
    return o;
  } else if (o is List) {
    return o.expand((e) => _dsx_toDOMNodeList(e)).toList();
  }

  return $html('$o');
}

List _dsx_toList(dynamic o) {
  if (o == null) {
    return [];
  } else if (o is List<DOMNode>) {
    return o;
  } else if (o is List) {
    return o.expand(_dsx_toList).toList();
  } else {
    return [o];
  }
}

void _dsx_joinStrings(List list) {
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

/// DSX extensions for [Function].
extension DSXFunctionExtension on Function {
  DSX dsx([
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
      return DSX(this, [a1, a2, a3, a4, a5, a6, a7, a8, a9, 10]);
    } else if (a9 != null) {
      return DSX(this, [a1, a2, a3, a4, a5, a6, a7, a8, a9]);
    } else if (a8 != null) {
      return DSX(this, [a1, a2, a3, a4, a5, a6, a7, a8]);
    } else if (a7 != null) {
      return DSX(this, [a1, a2, a3, a4, a5, a6, a7]);
    } else if (a6 != null) {
      return DSX(this, [a1, a2, a3, a4, a5, a6]);
    } else if (a5 != null) {
      return DSX(this, [a1, a2, a3, a4, a5]);
    } else if (a4 != null) {
      return DSX(this, [a1, a2, a3, a4]);
    } else if (a3 != null) {
      return DSX(this, [a1, a2, a3]);
    } else if (a2 != null) {
      return DSX(this, [a1, a2]);
    } else if (a1 != null) {
      return DSX(this, [a1]);
    }

    return DSX(this);
  }
}
