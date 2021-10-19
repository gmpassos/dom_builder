import 'package:dom_builder/dom_builder.dart';
import 'package:swiss_knife/swiss_knife.dart';

import 'dom_builder_base.dart';
import 'dom_builder_generator.dart';
import 'dom_builder_treemap.dart';

/// Wraps the actual generated node [T] and allows some operations over it.
abstract class DOMNodeRuntime<T> {
  final DOMTreeMap<T>? treeMap;

  /// The [DOMGenerator] used to generate this [treeMap].
  DOMGenerator<T> get domGenerator => treeMap!.domGenerator;

  /// The [DOMNode] of this [node].
  final DOMNode? domNode;

  /// The runtime node (generated element/node).
  final T? node;

  DOMNodeRuntime(this.treeMap, this.domNode, this.node);

  /// The [DOMNodeRuntime] of [parent].
  DOMNodeRuntime<T>? get parentRuntime {
    var domNodeParent = domNode != null ? domNode!.parent : null;
    var nodeParent = domGenerator.getNodeParent(node);
    if (nodeParent == null) return null;
    return domGenerator.createDOMNodeRuntime(
        treeMap!, domNodeParent, nodeParent);
  }

  /// This [node] parent.
  T? get parent {
    var nodeParent = domGenerator.getNodeParent(node);
    return nodeParent;
  }

  /// Returns `true` if this [node] has a [parent].
  bool get hasParent {
    var nodeParent = domGenerator.getNodeParent(node);
    return nodeParent != null;
  }

  /// The tag name of this [node].
  String? get tagName;

  /// Returns `true` if this [node] is a String element (a Text node or [DOMElement.isStringTagName]).
  bool get isStringElement;

  /// Returns the classes of this [node].
  List<String> get classes;

  /// Adds a [className] to this [node] classes.
  void addClass(String? className);

  /// Removes [className] from this [node] classes.
  bool removeClass(String? className);

  /// Clears classes from this [node] classes.
  void clearClasses();

  /// Returns `true` if this [node] and [domNode] exists.
  bool get exists => domNode != null && node != null;

  /// Returns the text of this [node].
  String get text;

  /// Sets the text of this [node].
  set text(String value);

  String? get value;

  set value(String? value);

  String? operator [](String name) => getAttribute(name);

  void operator []=(String name, Object? value) =>
      setAttribute(name, (value ?? '').toString());

  /// Returns the value of the attribute of [name].
  String? getAttribute(String name);

  /// Sets the value of the attribute of [name].
  void setAttribute(String name, String value);

  /// Removes the attribute of [name].
  void removeAttribute(String name);

  /// Gets runtime `style` of [node] as [CSS].
  CSS get style {
    return CSS(getAttribute('style'));
  }

  /// Sets runtime `style` of [node] parsed as [CSS].
  set style(Object? cssText) {
    var css = CSS(cssText);
    setAttribute('style', css.style);
  }

  /// Gets a runtime [style] [CSSEntry] for [name] from [node].
  CSSEntry? getStyleEntry(String name) {
    var style = this.style;
    return style.getEntry(name);
  }

  /// Gets a runtime [style] property for [name] from [node].
  String? getStyleProperty(String name) {
    var entry = getStyleEntry(name);
    return entry?.valueAsString;
  }

  String? setStyleProperty(String name, String value) {
    var style = this.style;
    var prev = style.getAsString(name);
    style.put(name, value);
    this.style = style;
    return prev;
  }

  void setStyleProperties(Map<String, String> properties) {
    var style = this.style;
    style.putAllProperties(properties);
    this.style = style;
  }

  CSSEntry? removeStyleEntry(String name) {
    var style = this.style;
    var entry = style.removeEntry(name);
    this.style = style;
    return entry;
  }

  String? removeStyleProperty(String name) {
    var entry = removeStyleEntry(name);
    return entry?.valueAsString;
  }

  List<CSSEntry> removeStyleEntries(List<String> names) {
    if (names.isEmpty) return <CSSEntry>[];

    var style = this.style;

    var removed = <CSSEntry>[];

    for (var name in names) {
      var entry = style.removeEntry(name);
      if (entry != null) {
        removed.add(entry);
      }
    }

    this.style = style;
    return removed;
  }

  Map<String, String> removeStyleProperties(List<String> names) {
    var removed = removeStyleEntries(names);
    return Map.fromEntries(
        removed.map((e) => MapEntry(e.name, e.valueAsString)));
  }

  /// Returns the [List] of children nodes.
  List<T> get children;

  /// Returns the number of children nodes.
  int get nodesLength;

  /// Returns the node at [index].
  T? getNodeAt(int index);

  int get indexInParent;

  /// Returns `true` if [other] is in the same [parent] of this [node].
  bool isInSameParent(T other) {
    var nodeParent = domGenerator.getNodeParent(node);
    return nodeParent != null &&
        nodeParent == domGenerator.getNodeParent(other);
  }

  DOMNodeRuntime<T>? getSiblingRuntime(T? other) {
    if (other == null || treeMap == null || !isInSameParent(other)) return null;

    var otherDomNode = treeMap!.getMappedDOMNode(other);
    return domGenerator.createDOMNodeRuntime(treeMap!, otherDomNode, other);
  }

  bool isPreviousNode(T? other) {
    var otherRuntime = getSiblingRuntime(other);
    if (otherRuntime == null) return false;

    var idx = indexInParent;
    var otherIdx = otherRuntime.indexInParent;
    return otherIdx >= 0 && otherIdx + 1 == idx;
  }

  bool isNextNode(T? other) {
    var otherRuntime = getSiblingRuntime(other);
    if (otherRuntime == null) return false;

    var idx = indexInParent;
    var otherIdx = otherRuntime.indexInParent;
    return idx >= 0 && idx + 1 == otherIdx;
  }

  bool isConsecutiveNode(T other) {
    return isNextNode(other) || isPreviousNode(other);
  }

  /// Returns the index of [child].
  int indexOf(T child);

  /// Adds [child] node.
  void add(T child);

  /// Inserts [child] node at [index].
  void insertAt(int index, T? child);

  /// Removes [child] node.
  bool removeNode(T? child);

  /// Removes child node at [index].
  T? removeAt(int index);

  void clear();

  /// Removes this node.
  bool remove() {
    if (hasParent) {
      return parentRuntime!.removeNode(node);
    }
    return false;
  }

  /// Replaces this node with [elements].
  ///
  /// - [remap] If `true` will remap the new element at [treeMap] (only if [elements] represents 1 element).
  bool replaceBy(List? elements, {bool remap = false}) {
    if (elements == null) return false;
    var e = domGenerator.toElements(elements);
    var ok = domGenerator.replaceElement(node, e);

    var treeMap = this.treeMap;

    if (ok && treeMap != null && domNode != null) {
      treeMap.removeByDOMNode(domNode);

      if (remap && e != null && e.length == 1) {
        var node2 = e.first;
        var domNode2 = domGenerator.revert(treeMap, node2);
        if (domNode2 != null) {
          treeMap.mapTree(domNode2, node2);
        }
      }
    }

    return ok;
  }

  int _contentFromIndexBackwardWhere(
      int idx, int steps, bool Function(T? node) test) {
    for (var i = Math.min(idx, nodesLength - 1); i >= 0; i--) {
      var node = getNodeAt(i);
      if (test(node)) {
        if (steps <= 0) {
          return i;
        } else {
          --steps;
        }
      }
    }
    return -1;
  }

  int _contentFromIndexForwardWhere(
      int idx, int steps, bool Function(T? node) test) {
    for (var i = idx; i < nodesLength; i++) {
      var node = getNodeAt(i);
      if (test(node)) {
        if (steps <= 0) {
          return i;
        } else {
          --steps;
        }
      }
    }
    return -1;
  }

  /// Moves this node up in parent's children.
  bool moveUp() {
    if (!hasParent) return false;
    var parentRuntime = this.parentRuntime;

    var idx = indexInParent;
    if (idx < 0) return false;
    if (idx == 0) return true;

    remove();

    var idxUp = parentRuntime!._contentFromIndexBackwardWhere(
        idx - 1, 0, (node) => domGenerator.isElementNode(node));
    if (idxUp < 0) {
      idxUp = 0;
    }

    parentRuntime.insertAt(idxUp, node);
    return true;
  }

  /// Moves this node down in parent's children.
  bool moveDown() {
    if (!hasParent) return false;
    var parentRuntime = this.parentRuntime;

    var idx = indexInParent;
    if (idx < 0) return false;
    if (idx >= parentRuntime!.nodesLength - 1) return true;

    remove();

    var idxDown = parentRuntime._contentFromIndexForwardWhere(
        idx, 1, (node) => domGenerator.isElementNode(node));
    if (idxDown < 0) {
      idxDown = parentRuntime.nodesLength;
    }

    parentRuntime.insertAt(idxDown, node);
    return true;
  }

  /// Copies this node.
  T? copy();

  /// Duplicates this node, inserting it at parent.
  T? duplicate() {
    var parentRuntime = this.parentRuntime;
    var idx = indexInParent;
    if (idx < 0) return null;

    var copy = this.copy();
    parentRuntime!.insertAt(idx + 1, copy);

    return copy;
  }

  bool absorbNode(T? other);

  bool mergeNode(T? other, {bool onlyConsecutive = true}) {
    if (onlyConsecutive) {
      if (isPreviousNode(other)) {
        return getSiblingRuntime(other)!
            .mergeNode(node, onlyConsecutive: false);
      } else if (!isNextNode(other)) {
        return false;
      }
    }

    if (hasParent) {
      parentRuntime!.removeNode(other);
    }

    absorbNode(other);
    return true;
  }
}

class DOMNodeRuntimeDummy<T> extends DOMNodeRuntime<T> {
  DOMNodeRuntimeDummy(DOMTreeMap<T>? treeMap, DOMNode domNode, T node)
      : super(treeMap ?? DOMTreeMapDummy(DOMGeneratorDummy()), domNode, node);

  @override
  String? get tagName => null;

  @override
  void addClass(String? className) {}

  @override
  List<String> get classes => [];

  @override
  void clearClasses() {}

  @override
  bool removeClass(String? className) => false;

  @override
  String get text => '';

  @override
  set text(String value) {}

  @override
  String get value => '';

  @override
  set value(String? value) {}

  @override
  String? getAttribute(String name) {
    return null;
  }

  @override
  void setAttribute(String name, String value) {}

  @override
  void removeAttribute(String name) {}

  @override
  void add(T child) {}

  @override
  List<T> get children => [];

  @override
  int get nodesLength => 0;

  @override
  T? getNodeAt(int index) => null;

  @override
  void clear() {}

  @override
  int get indexInParent => -1;

  @override
  int indexOf(T child) => -1;

  @override
  void insertAt(int index, T? child) {}

  @override
  bool removeNode(T? child) => false;

  @override
  T? removeAt(int index) => null;

  @override
  T? copy() => null;

  @override
  bool absorbNode(T? other) => false;

  @override
  bool get isStringElement => false;
}
