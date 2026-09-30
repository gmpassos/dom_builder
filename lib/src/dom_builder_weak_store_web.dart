import 'dart:js_interop';

@JS('WeakMap')
extension type _JSWeakMap._(JSObject _) implements JSObject {
  external _JSWeakMap();

  external JSAny? get(JSObject key);

  external void set(JSObject key, JSAny? value);

  external bool delete(JSObject key);
}

/// Associates values with objects without keeping the objects alive.
///
/// Web implementation: JS objects (e.g. DOM nodes) are keyed by JS identity
/// in a JS `WeakMap`. An [Expando] keys by the Dart object, and with
/// `dart2wasm` the same JS object can be wrapped by distinct Dart objects
/// (e.g. `element.firstChild` returns a new wrapper), so an [Expando] would
/// miss it. Other keys use an [Expando].
class DOMWeakStore<V extends Object> {
  final Expando<V> _expando;

  final _JSWeakMap _weakMap = _JSWeakMap();

  DOMWeakStore([String? name]) : _expando = Expando(name);

  /// Returns the value associated with [key], or `null`.
  V? operator [](Object key) {
    if (key.isA<JSObject>()) {
      final boxed = _weakMap.get(key as JSObject);
      return boxed.isA<JSBoxedDartObject>()
          ? (boxed as JSBoxedDartObject).toDart as V
          : null;
    }
    return _expando[key];
  }

  /// Associates [value] with [key]; a `null` [value] removes the association.
  void operator []=(Object key, V? value) {
    if (key.isA<JSObject>()) {
      final jsKey = key as JSObject;
      if (value == null) {
        _weakMap.delete(jsKey);
      } else {
        _weakMap.set(jsKey, value.toJSBox);
      }
    } else {
      _expando[key] = value;
    }
  }
}
