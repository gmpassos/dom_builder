import 'package:swiss_knife/swiss_knife.dart';

import 'dom_builder_base.dart';
import 'dom_builder_generator.dart';
import 'dom_builder_runtime.dart';

/// Represents a mapping tree. Can be used to map a [DOMNode] to a generated
/// node [T], or a node [T] to a [DOMNode].
class DOMTreeMap<T> {
  final DOMGenerator<T> domGenerator;

  DOMTreeMap(this.domGenerator);

  T generate(DOMGenerator<T> domGenerator, DOMNode root) {
    var rootElement = domGenerator.build(null, null, root, this);
    _rootDOMNode = root;
    _rootElement = rootElement;
    map(root, rootElement);
    return rootElement;
  }

  DOMNode _rootDOMNode;

  T _rootElement;

  DOMNode get rootDOMNode => _rootDOMNode;

  T get rootElement => _rootElement;

  final Map<DOMNode, T> _domNodeToElementMap = {};

  final Map<T, DOMNode> _elementToDOMNodeMap = {};

  void map(DOMNode domNode, T element) {
    if (domNode == null || element == null) return;

    _domNodeToElementMap[domNode] = element;
    _elementToDOMNodeMap[element] = domNode;

    domNode.treeMap = this;

    if (domNode is DOMElement) {
      domGenerator.registerEventListeners(this, domNode, element);
    }
  }

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

  T getMappedElement(DOMNode domNode) {
    if (domNode == null) return null;
    return _domNodeToElementMap[domNode];
  }

  DOMNode getMappedDOMNode(T element) {
    if (element == null) return null;
    return _elementToDOMNodeMap[element];
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

  DOMNodeRuntime<T> getRuntimeNode(DOMNode domNode) {
    var node = getMappedElement(domNode);
    if (node == null) return null;
    return domGenerator.createDOMNodeRuntime(this, domNode, node);
  }

  bool moveUpByElement(T element) => moveUpByDOMNode(getMappedDOMNode(element));

  bool moveUpByDOMNode(DOMNode domNode) {
    if (domNode == null || !domNode.hasParent) return false;

    var nodeRuntime = domNode.runtime;
    if (nodeRuntime == null) return false;

    var ok1 = domNode.moveUp();
    var ok2 = nodeRuntime.moveUp();

    if (ok1 != ok2) return null;

    return ok1 && ok2;
  }

  bool moveDownByElement(T element) =>
      moveDownByDOMNode(getMappedDOMNode(element));

  bool moveDownByDOMNode(DOMNode domNode) {
    if (domNode == null || !domNode.hasParent) return false;

    var nodeRuntime = domNode.runtime;
    if (nodeRuntime == null) return false;

    var ok1 = domNode.moveDown();
    var ok2 = nodeRuntime.moveDown();

    if (ok1 != ok2) return null;

    return ok1 && ok2;
  }

  DOMNodeMapping<T> duplicateByElement(T element) =>
      duplicateByDOMNode(getMappedDOMNode(element));

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

  bool emptyByElement(T element) => emptyByDOMNode(getMappedDOMNode(element));

  bool emptyByDOMNode(DOMNode domNode) {
    if (domNode == null) return false;

    var nodeRuntime = domNode.runtime;
    if (nodeRuntime == null) return false;

    domNode.clearNodes();
    nodeRuntime.clear();

    return true;
  }

  DOMNodeMapping<T> removeByElement(T element) =>
      removeByDOMNode(getMappedDOMNode(element));

  DOMNodeMapping<T> removeByDOMNode(DOMNode domNode) {
    if (domNode == null || !domNode.hasParent) return null;

    var nodeRuntime = domNode.runtime;
    if (nodeRuntime == null) return null;

    nodeRuntime.remove();
    domNode.remove();

    unmap(domNode, nodeRuntime.node);

    return DOMNodeMapping(this, domNode, nodeRuntime.node);
  }

  DOMNodeMapping<T> mergeNearNodes(DOMNode domNode1, DOMNode domNode2) {
    var nodeRuntime1 = domNode1.runtime;
    var nodeRuntime2 = domNode2.runtime;

    if (nodeRuntime1 == null || nodeRuntime2 == null) {
      return null;
    }

    if (domNode1.isConsecutiveNode(domNode2)) {
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

  DOMNodeMapping<T> mergeNearStringNodes(DOMNode domNode1, DOMNode domNode2) {
    if (domNode1.isStringElement && domNode2.isStringElement) {
      return mergeNearNodes(domNode1, domNode2);
    }

    return null;
  }
}

class DOMNodeMapping<T> {
  final DOMTreeMap<T> treeMap;

  DOMGenerator<T> get domGenerator => treeMap.domGenerator;

  final DOMNode domNode;

  final T node;

  DOMNodeMapping(this.treeMap, this.domNode, this.node);
}

class DOMTreeMapDummy<T> extends DOMTreeMap<T> {
  DOMTreeMapDummy(DOMGenerator<T> domGenerator) : super(domGenerator);

  @override
  void map(DOMNode domNode, T element) {}
}
