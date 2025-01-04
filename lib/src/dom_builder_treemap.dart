import 'package:swiss_knife/swiss_knife.dart';

import 'dom_builder_base.dart';
import 'dom_builder_context.dart';
import 'dom_builder_generator.dart';
import 'dom_builder_runtime.dart';

/// Represents a mapping tree. Can be used to map a [DOMNode] to a generated
/// node [T], or a node [T] to a [DOMNode].
class DOMTreeMap<T extends Object> {
  final DOMGenerator<T> domGenerator;

  DOMTreeMap(this.domGenerator);

  T? generate(DOMGenerator<T> domGenerator, DOMNode root,
          {T? parent, DOMContext<T>? context}) =>
      domGenerator.generate(root,
          parent: parent, treeMap: this, context: context);

  DOMNode? _rootDOMNode;

  T? _rootElement;

  void setRoot(DOMNode rootDOMNode, T? rootElement) {
    _rootDOMNode = rootDOMNode;
    _rootElement = rootElement;
  }

  /// The root [DOMNode] of this tree.
  DOMNode? get rootDOMNode => _rootDOMNode;

  /// The root element [T] of this tree.
  T? get rootElement => _rootElement;

  final Map<DOMNode, T> _domNodeToElementMap = {};

  final Map<T, DOMNode> _elementToDOMNodeMap = {};

  Iterable<T> get mappedElements => _domNodeToElementMap.values;

  Iterable<DOMNode> get mappedDOMNodes => _elementToDOMNodeMap.values;

  static final Expando _elementsDOMTreeMap =
      Expando<DOMTreeMap>('Elements->DOMTreeMap');

  /// Returns the [DOMTreeMap] of the [element],
  /// if it's associated with some [DOMElement].
  static DOMTreeMap<T>? getElementDOMTreeMap<T extends Object>(T? element) {
    if (element == null) return null;
    return _elementsDOMTreeMap[element] as DOMTreeMap<T>?;
  }

  /// Maps in this instance the pair [domNode] and [element].
  void map(DOMNode domNode, T element,
      {DOMContext<T>? context, bool allowOverwrite = false}) {
    var prevElement = _domNodeToElementMap[domNode];
    var prevDomNode = _elementToDOMNodeMap[element];

    if (prevElement != null || prevDomNode != null) {
      var samePrevElement = identical(prevElement, element);
      var samePrevDomNode = identical(prevDomNode, domNode);
      if (samePrevElement && samePrevDomNode) {
        return;
      } else {
        if (!allowOverwrite) {
          print(
              'WARNING> Mapping to different instances: $prevElement ; $prevDomNode');
        }
      }
    }

    _domNodeToElementMap[domNode] = element;
    _elementToDOMNodeMap[element] = domNode;

    domNode.treeMap = this;
    _elementsDOMTreeMap[element] = this;

    if (domNode is DOMElement) {
      domGenerator.resolveActionAttribute(this, domNode, element, context);
      domGenerator.registerEventListeners(this, domNode, element, context);
    }
  }

  /// Unmap from this instance the pair [domNode] and [element].
  bool unmap(DOMNode domNode, T element) {
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
  T? getMappedElement(DOMNode? domNode, {bool checkParents = false}) {
    if (domNode == null) return null;
    var element = _domNodeToElementMap[domNode];
    if (element != null) return element;

    if (!checkParents) return null;

    var parent = domNode.parent;
    return getMappedElement(parent, checkParents: true);
  }

  /// Returns the mapped [DOMNode] associated with [element].
  ///
  /// [checkParents] If true, also checks for mapped [element.parent].
  DOMNode? getMappedDOMNode(T? element, {bool checkParents = false}) {
    if (element == null) return null;
    var domNode = _elementToDOMNodeMap[element];
    if (domNode != null) return domNode;

    if (!checkParents) return null;

    var parent = domGenerator.getNodeParent(element);
    return getMappedDOMNode(parent, checkParents: true);
  }

  /// Returns [true] if [domNode] is mapped by this instance.
  bool isMappedDOMNode(DOMNode? domNode) {
    if (domNode == null) return false;
    return _domNodeToElementMap.containsKey(domNode);
  }

  /// Returns [true] if [element] is mapped by this instance.
  bool isMappedElement(T? element) {
    if (element == null) return false;
    return _elementToDOMNodeMap.containsKey(element);
  }

  /// Returns [domNode] or recursively a [domNode.parent] that is mapped.
  ///
  /// If [domNode] hierarchy doesn't have a mapped node, will return null.
  DOMNode? asMappedDOMNode(DOMNode? domNode) {
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
  T? asMappedElement(T? element) {
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
    map(domRoot, root);

    if (domRoot is TextNode) return false;

    var domNodes = domRoot.nodes.toList();
    var nodes = domGenerator.getElementNodes(root);

    var limit = Math.min(domNodes.length, nodes.length);

    for (var i = 0; i < limit; i++) {
      var domNode = domNodes[i];
      var node = nodes[i];

      if (domGenerator.isEquivalentNode(domNode, node)) {
        mapTree(domNode, node);
      }
    }

    return true;
  }

  /// Returns a [DOMNodeRuntime] of [domNode].
  DOMNodeRuntime<T>? getRuntimeNode(DOMNode? domNode) {
    var node = getMappedElement(domNode);
    if (node == null) return null;
    return domGenerator.createDOMNodeRuntime(this, domNode, node);
  }

  /// Moves [element] up in the parent children list. Also performs on mapped [DOMNode].
  bool moveUpByElement(T? element) =>
      moveUpByDOMNode(getMappedDOMNode(element));

  /// Moves [domNode] up in the parent children list. Also performs on mapped element.
  bool moveUpByDOMNode(DOMNode? domNode) {
    if (domNode == null || !domNode.hasParent) return false;

    var nodeRuntime = domNode.runtime;

    var ok1 = domNode.moveUp();
    var ok2 = nodeRuntime.moveUp();

    if (ok1 != ok2) return false;

    return ok1 && ok2;
  }

  /// Moves [element] down in the parent children list. Also performs on mapped [DOMNode].
  bool moveDownByElement(T? element) =>
      moveDownByDOMNode(getMappedDOMNode(element));

  /// Moves [domNode] down in the parent children list. Also performs on mapped element.
  bool moveDownByDOMNode(DOMNode? domNode) {
    if (domNode == null || !domNode.hasParent) return false;

    var nodeRuntime = domNode.runtime;

    var ok1 = domNode.moveDown();
    var ok2 = nodeRuntime.moveDown();

    if (ok1 != ok2) return false;

    return ok1 && ok2;
  }

  /// Duplicates [element] in the parent children list. Also performs on mapped [DOMNode].
  DOMNodeMapping<T>? duplicateByElement(T? element) =>
      duplicateByDOMNode(getMappedDOMNode(element));

  /// Duplicates [domNode] in the parent children list. Also performs on mapped element.
  DOMNodeMapping<T>? duplicateByDOMNode(DOMNode? domNode) {
    if (domNode == null || !domNode.hasParent) return null;

    var nodeRuntime = domNode.getRuntime<T>();

    var domCopy = domNode.duplicate();
    var copy = nodeRuntime.duplicate();

    if (domCopy == null || copy == null) return null;

    mapTree(domCopy, copy);
    return DOMNodeMapping(this, domCopy, copy);
  }

  /// Empties [element] children nodes. Also performs on mapped [DOMNode].
  bool emptyByElement(T? element) => emptyByDOMNode(getMappedDOMNode(element));

  /// Empties [domNode] children nodes. Also performs on mapped element.
  bool emptyByDOMNode(DOMNode? domNode) {
    if (domNode == null) return false;

    var nodeRuntime = domNode.runtime;

    domNode.clearNodes();
    nodeRuntime.clear();

    return true;
  }

  /// Removes [element] from parent. Also performs on mapped [DOMNode].
  DOMNodeMapping<T>? removeByElement(T? element) =>
      removeByDOMNode(getMappedDOMNode(element));

  /// Removes [domNode] from parent. Also performs on mapped element.
  DOMNodeMapping<T>? removeByDOMNode(DOMNode? domNode) {
    if (domNode == null || !domNode.hasParent) return null;

    var nodeRuntime = domNode.getRuntime<T>();

    nodeRuntime.remove();
    domNode.remove();

    var node = nodeRuntime.node;
    if (node == null) return null;

    unmap(domNode, node);
    return DOMNodeMapping(this, domNode, node);
  }

  DOMNodeMapping<T>? mergeNearNodes(DOMNode domNode1, DOMNode domNode2,
      {bool onlyCompatibles = false}) {
    if (onlyCompatibles && !domNode1.isCompatibleForMerge(domNode2)) {
      return null;
    }

    var nodeRuntime1 = domNode1.getRuntime<T>();
    var nodeRuntime2 = domNode2.getRuntime<T>();

    var node1 = nodeRuntime1.node;
    var node2 = nodeRuntime2.node;

    if (domNode1.isNextNode(domNode2)) {
      if (domNode1.merge(domNode2) && nodeRuntime1.mergeNode(node2)) {
        if (node1 == null || node2 == null) return null;
        unmap(domNode2, node2);
        return DOMNodeMapping(this, domNode1, node1);
      }
    } else if (domNode1.isPreviousNode(domNode2)) {
      if (domNode2.merge(domNode1) && nodeRuntime2.mergeNode(node1)) {
        if (node1 == null || node2 == null) return null;
        unmap(domNode1, node1);
        return DOMNodeMapping(this, domNode2, node2);
      }
    }

    return null;
  }

  DOMNodeMapping<T>? mergeNearStringNodes(DOMNode domNode1, DOMNode domNode2,
      {bool onlyCompatibles = false}) {
    if (domNode1.isStringElement && domNode2.isStringElement) {
      return mergeNearNodes(domNode1, domNode2,
          onlyCompatibles: onlyCompatibles);
    }

    return null;
  }

  static final RegExp regexpTagRef =
      RegExp(r'\{\{\s*([\w-]+|\*)#([\w-]+)\s*\}\}');
  static final RegExp regexpTagOpen =
      RegExp(r'''^\s*<[\w-]+\s(?:".*?"|'.*?'|\s+|[^>\s]+)*>''');
  static final RegExp regexpTagClose = RegExp(r'''<\/[\w-]+\s*>\s*$''');

  String? queryElement(String query,
      {DOMContext? domContext, bool buildTemplates = false}) {
    if (isEmptyString(query)) return null;

    var rootDOMNode = this.rootDOMNode as DOMElement;

    var node = rootDOMNode.select(query)!;

    var html =
        node.buildHTML(domContext: domContext, buildTemplates: buildTemplates);

    html = html.replaceFirst(regexpTagOpen, '');
    html = html.replaceFirst(regexpTagClose, '');

    return html;
  }
}

/// A wrapper for a mapped pair of a [DOMTreeMap].
class DOMNodeMapping<T extends Object> {
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
class DOMTreeMapDummy<T extends Object> extends DOMTreeMap<T> {
  DOMTreeMapDummy(super.domGenerator) : super();

  @override
  void map(DOMNode domNode, T element,
      {DOMContext<T>? context, bool allowOverwrite = false}) {}

  @override
  bool unmap(DOMNode domNode, T element) => false;

  @override
  DOMNodeMapping<T>? duplicateByDOMNode(DOMNode? domNode) => null;

  @override
  DOMNodeMapping<T>? duplicateByElement(T? element) => null;

  @override
  bool emptyByDOMNode(DOMNode? domNode) => false;

  @override
  bool emptyByElement(T? element) => false;

  @override
  bool isMappedDOMNode(DOMNode? domNode) => false;

  @override
  bool isMappedElement(T? element) => false;

  @override
  bool matchesMapping(DOMNode domNode, T node) => false;

  @override
  DOMNodeMapping<T>? mergeNearNodes(DOMNode domNode1, DOMNode domNode2,
          {bool onlyCompatibles = false}) =>
      null;

  @override
  DOMNodeMapping<T>? mergeNearStringNodes(DOMNode domNode1, DOMNode domNode2,
          {bool onlyCompatibles = false}) =>
      null;

  @override
  DOMNodeMapping<T>? removeByDOMNode(DOMNode? domNode) => null;

  @override
  DOMNodeMapping<T>? removeByElement(T? element) => null;

  @override
  bool moveDownByDOMNode(DOMNode? domNode) => false;

  @override
  bool moveDownByElement(T? element) => false;

  @override
  bool moveUpByDOMNode(DOMNode? domNode) => false;

  @override
  bool moveUpByElement(T? element) => false;

  @override
  void setRoot(DOMNode rootDOMNode, T? rootElement) {}
}
