/// Associates values with objects without keeping the objects alive.
///
/// Generic implementation, backed by an [Expando] (keys by identity).
class DOMWeakStore<V extends Object> {
  final Expando<V> _expando;

  DOMWeakStore([String? name]) : _expando = Expando(name);

  /// Returns the value associated with [key], or `null`.
  V? operator [](Object key) => _expando[key];

  /// Associates [value] with [key]; a `null` [value] removes the association.
  void operator []=(Object key, V? value) => _expando[key] = value;
}
