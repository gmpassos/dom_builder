import 'package:swiss_knife/swiss_knife.dart';

import 'dom_builder_base.dart';
import 'dom_builder_context.dart';
import 'dom_builder_generator.dart';
import 'dom_builder_runtime.dart';

/// Represents a mapping tree. Can be used to map a [DOMNode] to a generated
/// node [T], or a node [T] to a [DOMNode].
class DOMTreeMap<T> {
  final DOMGenerator<T> domGenerator;

  DOMTreeMap(this.domGenerator);

  T generate(DOMGenerator<T> domGenerator, DOMNode root,
          {T parent, DOMContext<T> context}) =>
      domGenerator.generate(root,
          parent: parent, treeMap: this, context: context);

  DOMNode _rootDOMNode;

  T _rootElement;

  void setRoot(DOMNode rootDOMNode, T rootElement) {
    _rootDOMNode = rootDOMNode;
    _rootElement = rootElement;
  }

  /// The root [DOMNode] of this tree.
  DOMNode get rootDOMNode => _rootDOMNode;

  /// The root element [T] of this tree.
  T get rootElement => _rootElement;

  final Map<DOMNode, T> _domNodeToElementMap = {};

  final Map<T, DOMNode> _elementToDOMNodeMap = {};

  Iterable<T> get mappedElements => _domNodeToElementMap.values;

  Iterable<DOMNode> get mappedDOMNodes => _elementToDOMNodeMap.values;

  /// Maps in this instance the pair [domNode] and [element].
  void map(DOMNode domNode, T element) {
    if (domNode == null || element == null) return;

    _domNodeToElementMap[domNode] = element;
    _elementToDOMNodeMap[element] = domNode;

    domNode.treeMap = this;

    if (domNode is DOMElement) {
      domGenerator.registerEventListeners(this, domNode, element);
    }
  }

  /// Unmap from this instance the pair [domNode] and [element].
  bool unmap(DOMNode domNode, T element) {
    if (domNode == null || element == null) return false;

    var prev = _domNodeToElementMap[domNode];

    if (prev == element) {
      _domNodeToElementMap.remove(domNode);
      _elementToDOMNodeMap.remove(prev);
      return true;
    }

    return false;
  }

  /// Returns the mapped element [T] associated with [domNode].
  ///
  /// [checkParents] If true, also checks for mapped [domNode.parent].
  T getMappedElement(DOMNode domNode, {bool checkParents}) {
    if (domNode == null) return null;
    var element = _domNodeToElementMap[domNode];
    if (element != null) return element;

    checkParents ??= false;
    if (!checkParents) return null;

    var parent = domNode.parent;
    return getMappedElement(parent, checkParents: true);
  }

  /// Returns the mapped [DOMNode] associated with [element].
  ///
  /// [checkParents] If true, also checks for mapped [element.parent].
  DOMNode getMappedDOMNode(T element, {bool checkParents}) {
    if (element == null) return null;
    var domNode = _elementToDOMNodeMap[element];
    if (domNode != null) return domNode;

    checkParents ??= false;
    if (!checkParents) return null;

    var parent = domGenerator.getNodeParent(element);
    return getMappedDOMNode(parent, checkParents: true);
  }

  /// Returns [true] if [domNode] is mapped by this instance.
  bool isMappedDOMNode(DOMNode domNode) {
    if (domNode == null) return false;
    return _domNodeToElementMap.containsKey(domNode);
  }

  /// Returns [true] if [element] is mapped by this instance.
  bool isMappedElement(T element) {
    if (element == null) return false;
    return _elementToDOMNodeMap.containsKey(element);
  }

  /// Returns [domNode] or recursively a [domNode.parent] that is mapped.
  ///
  /// If [domNode] hierarchy doesn't have a mapped node, will return null.
  DOMNode asMappedDOMNode(DOMNode domNode) {
    if (domNode == null) return null;
    if (isMappedDOMNode(domNode)) {
      return domNode;
    }
    var parent = domNode.parent;
    if (parent == null) return null;
    return asMappedDOMNode(parent);
  }

  /// Returns [element] or recursively a [element.parent] that is mapped.
  ///
  /// If [element] hierarchy doesn't have a mapped node, will return null.
  T asMappedElement(T element) {
    if (element == null) return null;
    if (isMappedElement(element)) {
      return element;
    }
    var parent = domGenerator.getNodeParent(element);
    if (parent == null) return null;
    return asMappedElement(parent);
  }

  /// Returns [true] if the mapping for [domNode] matches [node].
  bool matchesMapping(DOMNode domNode, T node) {
    return identical(_elementToDOMNodeMap[domNode], node);
  }

  bool mapTree(DOMNode domRoot, T root) {
    if (domRoot == null || root == null) return false;
    map(domRoot, root);

    if (domRoot is TextNode) return false;

    var domNodes = domRoot.nodes.toList();
    var nodes = domGenerator.getElementNodes(root) ?? [];

    var limit = Math.min(domNodes.length, nodes.length);

    for (var i = 0; i < limit; i++) {
      var domNode = domNodes[i];
      var node = nodes[i];

      if (domGenerator.isEquivalentNode(domNode, node)) {
        map(domNode, node);
        mapTree(domNode, node);
      }
    }

    return true;
  }

  /// Returns a [DOMNodeRuntime] of [domNode].
  DOMNodeRuntime<T> getRuntimeNode(DOMNode domNode) {
    var node = getMappedElement(domNode);
    if (node == null) return null;
    return domGenerator.createDOMNodeRuntime(this, domNode, node);
  }

  /// Moves [element] up in the parent children list. Also performs on mapped [DOMNode].
  bool moveUpByElement(T element) => moveUpByDOMNode(getMappedDOMNode(element));

  /// Moves [domNode] up in the parent children list. Also performs on mapped element.
  bool moveUpByDOMNode(DOMNode domNode) {
    if (domNode == null || !domNode.hasParent) return false;

    var nodeRuntime = domNode.runtime;
    if (nodeRuntime == null) return false;

    var ok1 = domNode.moveUp();
    var ok2 = nodeRuntime.moveUp();

    if (ok1 != ok2) return null;

    return ok1 && ok2;
  }

  /// Moves [element] down in the parent children list. Also performs on mapped [DOMNode].
  bool moveDownByElement(T element) =>
      moveDownByDOMNode(getMappedDOMNode(element));

  /// Moves [domNode] down in the parent children list. Also performs on mapped element.
  bool moveDownByDOMNode(DOMNode domNode) {
    if (domNode == null || !domNode.hasParent) return false;

    var nodeRuntime = domNode.runtime;
    if (nodeRuntime == null) return false;

    var ok1 = domNode.moveDown();
    var ok2 = nodeRuntime.moveDown();

    if (ok1 != ok2) return null;

    return ok1 && ok2;
  }

  /// Duplicates [element] in the parent children list. Also performs on mapped [DOMNode].
  DOMNodeMapping<T> duplicateByElement(T element) =>
      duplicateByDOMNode(getMappedDOMNode(element));

  /// Duplicates [domNode] in the parent children list. Also performs on mapped element.
  DOMNodeMapping<T> duplicateByDOMNode(DOMNode domNode) {
    if (domNode == null || !domNode.hasParent) return null;

    var nodeRuntime = domNode.runtime;
    if (nodeRuntime == null) return null;

    var domCopy = domNode.duplicate();
    var copy = nodeRuntime.duplicate();

    if (domCopy == null && copy == null) return null;

    if (domCopy != null && copy != null) {
      mapTree(domCopy, copy);
    }

    return DOMNodeMapping(this, domCopy, copy);
  }

  /// Empties [element] children nodes. Also performs on mapped [DOMNode].
  bool emptyByElement(T element) => emptyByDOMNode(getMappedDOMNode(element));

  /// Empties [domNode] children nodes. Also performs on mapped element.
  bool emptyByDOMNode(DOMNode domNode) {
    if (domNode == null) return false;

    var nodeRuntime = domNode.runtime;
    if (nodeRuntime == null) return false;

    domNode.clearNodes();
    nodeRuntime.clear();

    return true;
  }

  /// Removes [element] from parent. Also performs on mapped [DOMNode].
  DOMNodeMapping<T> removeByElement(T element) =>
      removeByDOMNode(getMappedDOMNode(element));

  /// Removes [domNode] from parent. Also performs on mapped element.
  DOMNodeMapping<T> removeByDOMNode(DOMNode domNode) {
    if (domNode == null || !domNode.hasParent) return null;

    var nodeRuntime = domNode.runtime;
    if (nodeRuntime == null) return null;

    nodeRuntime.remove();
    domNode.remove();

    unmap(domNode, nodeRuntime.node);

    return DOMNodeMapping(this, domNode, nodeRuntime.node);
  }

  DOMNodeMapping<T> mergeNearNodes(DOMNode domNode1, DOMNode domNode2,
      {bool onlyCompatibles = false}) {
    onlyCompatibles ??= false;

    if (domNode1 == null || domNode2 == null) {
      return null;
    }

    if (onlyCompatibles && !domNode1.isCompatibleForMerge(domNode2)) {
      return null;
    }

    var nodeRuntime1 = domNode1.runtime;
    var nodeRuntime2 = domNode2.runtime;

    if (nodeRuntime1 == null || nodeRuntime2 == null) {
      return null;
    }

    if (domNode1.isNextNode(domNode2)) {
      if (domNode1.merge(domNode2) &&
          nodeRuntime1.mergeNode(nodeRuntime2.node)) {
        unmap(domNode2, nodeRuntime2.node);
        return DOMNodeMapping(this, domNode1, nodeRuntime1.node);
      }
    } else if (domNode1.isPreviousNode(domNode2)) {
      if (domNode2.merge(domNode1) &&
          nodeRuntime2.mergeNode(nodeRuntime1.node)) {
        unmap(domNode1, nodeRuntime1.node);
        return DOMNodeMapping(this, domNode2, nodeRuntime2.node);
      }
    }

    return null;
  }

  DOMNodeMapping<T> mergeNearStringNodes(DOMNode domNode1, DOMNode domNode2,
      {bool onlyCompatibles = false}) {
    if (domNode1 == null || domNode2 == null) {
      return null;
    }

    if (domNode1.isStringElement && domNode2.isStringElement) {
      return mergeNearNodes(domNode1, domNode2,
          onlyCompatibles: onlyCompatibles);
    }

    return null;
  }
}

/// A wrapper for a mapped pair of a [DOMTreeMap].
class DOMNodeMapping<T> {
  /// The [DOMTreeMap] of this pair.
  final DOMTreeMap<T> treeMap;

  DOMGenerator<T> get domGenerator => treeMap.domGenerator;

  /// The [DOMNode] of this mapped pair.
  final DOMNode domNode;

  /// The element [T] of this mapped pair.
  final T node;

  E nodeCast<E>() => node as E;

  DOMNodeMapping(this.treeMap, this.domNode, this.node);
}

/// A Dummy DOMTreeMap, that won't map anything.
class DOMTreeMapDummy<T> extends DOMTreeMap<T> {
  DOMTreeMapDummy(DOMGenerator<T> domGenerator) : super(domGenerator);

  @override
  void map(DOMNode domNode, T element) {}
}
