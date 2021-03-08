import 'dart:collection';
import 'dart:math';

import 'package:dom_builder/dom_builder.dart';
import 'package:html/dom.dart' as html_dom;
import 'package:swiss_knife/swiss_knife.dart';

import 'dom_builder_attribute.dart';
import 'dom_builder_generator.dart';
import 'dom_builder_helpers.dart';
import 'dom_builder_runtime.dart';
import 'dom_builder_treemap.dart';

abstract class WithValue {
  bool get hasValue;

  String get value;
}

//
// NodeSelector:
//

typedef NodeSelector = bool Function(DOMNode node);

final RegExp _SELECTOR_DELIMITER = RegExp(r'\s*,\s*');

NodeSelector asNodeSelector(dynamic selector) {
  if (selector == null) return null;

  if (selector is NodeSelector) {
    return selector;
  } else if (selector is String) {
    var str = selector.trim();
    if (str.isEmpty) return null;

    var selectors = str.split(_SELECTOR_DELIMITER);
    selectors.removeWhere((s) => s.isEmpty);

    if (selectors.isEmpty) {
      return null;
    } else if (selectors.length == 1) {
      // id:
      if (str.startsWith('#')) {
        return (n) => n is DOMElement && n.id == str.substring(1);
      }
      // class
      else if (str.startsWith('.')) {
        var classes = str.substring(1).split('.');
        return (n) => n is DOMElement && n.containsAllClasses(classes);
      }
      // tag
      else {
        return (n) => n is DOMElement && n.tag == str;
      }
    } else {
      var multiSelector = selectors.map(asNodeSelector).toList();
      return (n) => multiSelector.any((f) => f(n));
    }
  } else if (selector is DOMNode) {
    return (n) => n == selector;
  } else if (selector is List) {
    if (selector.isEmpty) return null;
    if (selector.length == 1) return asNodeSelector(selector[0]);

    var multiSelector = selector.map(asNodeSelector).toList();

    return (n) => multiSelector.any((f) => f(n));
  }

  throw ArgumentError(
      "Can't use NodeSelector of type: [ ${selector.runtimeType}");
}

/// Represents a DOM Node.
class DOMNode implements AsDOMNode {
  /// Converts [nodes] to a text [String].
  static String toText(dynamic nodes) {
    if (nodes == null) return '';

    if (nodes is String) {
      return nodes;
    } else if (nodes is DOMNode) {
      return nodes.text;
    } else if (nodes is html_dom.Node) {
      return nodes.text;
    } else if (nodes is Iterable) {
      if (nodes.isEmpty) {
        return '';
      } else if (nodes.length == 1) {
        return toText(nodes.first);
      } else {
        return nodes.map(toText).join('');
      }
    } else if (nodes is Map) {
      return toText(nodes.values);
    } else {
      return nodes.toString();
    }
  }

  /// Parses [entry] to a list of nodes.
  static List<DOMNode> parseNodes(entry) {
    if (entry == null) return null;

    if (entry is AsDOMNode) {
      var node = entry.asDOMNode;
      return node != null ? [node] : null;
    } else if (entry is AsDOMElement) {
      var element = entry.asDOMElement;
      return element != null ? [element] : null;
    } else if (entry is DOMNode) {
      return [entry];
    } else if (entry is html_dom.Node) {
      return [DOMNode.from(entry)];
    } else if (entry is List) {
      entry.removeWhere((e) => e == null);
      if (entry.isEmpty) return [];
      var list = entry.expand(parseNodes).toList();
      list.removeWhere((e) => e == null);
      return list;
    } else if (entry is String) {
      if (isHTMLElement(entry)) {
        return parseHTML(entry);
      } else if (hasHTMLEntity(entry) || hasHTMLTag(entry)) {
        return parseHTML('<span>$entry</span>');
      } else {
        return [_toTextNode(entry)];
      }
    } else if (entry is num || entry is bool) {
      return [TextNode(entry.toString())];
    } else if (isDOMBuilderDirectHelper(entry)) {
      try {
        var tag = entry();
        return [tag];
      } catch (e, s) {
        print(e);
        print(s);
        return null;
      }
    } else if (entry is DOMElementGenerator ||
        entry is DOMElementGeneratorFunction) {
      return [ExternalElementNode(entry)];
    } else {
      return [ExternalElementNode(entry)];
    }
  }

  static dynamic _parseNode(entry) {
    if (entry == null) return null;

    if (entry is DOMNode) {
      return entry;
    } else if (entry is html_dom.Node) {
      return DOMNode.from(entry);
    } else if (entry is List) {
      entry.removeWhere((e) => e == null);
      if (entry.isEmpty) return null;
      var list = entry.expand(parseNodes).toList();
      list.removeWhere((e) => e == null);
      if (list.isEmpty) return null;
      if (list.length == 1) return list.single;
      return list;
    } else if (entry is String) {
      if (isHTMLElement(entry)) {
        return parseHTML(entry);
      } else if (hasHTMLEntity(entry) || hasHTMLTag(entry)) {
        return parseHTML('<span>$entry</span>');
      } else {
        return _toTextNode(entry);
      }
    } else if (entry is num || entry is bool) {
      return TextNode(entry.toString());
    } else if (entry is DOMElementGenerator ||
        entry is DOMElementGeneratorFunction) {
      return ExternalElementNode(entry);
    } else {
      return ExternalElementNode(entry);
    }
  }

  /// Creates a [DOMNode] from dynamic parameter [entry].
  ///
  /// [entry] Can be a [DOMNode], a String with HTML, a Text,
  /// a [Function] or an external element.
  factory DOMNode.from(entry) {
    if (entry == null) return null;

    if (entry is DOMNode) {
      return entry;
    } else if (entry is html_dom.Node) {
      return DOMNode._fromHtmlNode(entry);
    } else if (entry is List) {
      if (entry.isEmpty) return null;
      entry.removeWhere((e) => e == null);
      return DOMNode.from(entry.single);
    } else if (entry is String) {
      if (isHTMLElement(entry)) {
        return parseHTML(entry).single;
      } else if (hasHTMLEntity(entry) || hasHTMLTag(entry)) {
        return parseHTML('<span>$entry</span>').single;
      } else {
        return _toTextNode(entry);
      }
    } else if (entry is num || entry is bool) {
      return TextNode(entry.toString());
    } else if (entry is DOMElementGenerator ||
        entry is DOMElementGeneratorFunction) {
      return ExternalElementNode(entry);
    } else {
      return ExternalElementNode(entry);
    }
  }

  factory DOMNode._fromHtmlNode(html_dom.Node entry) {
    if (entry is html_dom.Text) {
      return _toTextNode(entry.text);
    } else if (entry is html_dom.Element) {
      return DOMNode._fromHtmlNodeElement(entry);
    }

    return null;
  }

  factory DOMNode._fromHtmlNodeElement(html_dom.Element entry) {
    var name = entry.localName;

    var attributes = entry.attributes.map((k, v) => MapEntry(k.toString(), v));

    var content = isNotEmptyObject(entry.nodes) ? List.from(entry.nodes) : null;

    return DOMElement(name, attributes: attributes, content: content);
  }

  /// Returns the [parent] [DOMNode] of generated tree (by [DOMGenerator]).
  DOMNode parent;

  /// Returns the [DOMTreeMap] of the last generated tree of elements.
  DOMTreeMap treeMap;

  /// Returns a [DOMNodeRuntime] with the actual generated node
  /// associated with [treeMap] and [domGenerator].
  DOMNodeRuntime get runtime => treeMap != null
      ? treeMap.getRuntimeNode(this)
      : DOMNodeRuntimeDummy(null, this, null);

  /// Same as [runtime], but casts to [DOMNodeRuntime<T>].
  DOMNodeRuntime<T> getRuntime<T>() => runtime as DOMNodeRuntime<T>;

  /// Returns [runtime.node].
  dynamic get runtimeNode =>
      treeMap != null ? treeMap.getMappedElement(this) : null;

  /// Same as [runtimeNode], but casts to [T].
  T getRuntimeNode<T>() => runtimeNode as T;

  /// Returns [true] if this node has a generated element by [domGenerator].
  bool get isGenerated => treeMap != null;

  /// Returns the [DOMGenerator] associated with [treeMap].
  DOMGenerator get domGenerator =>
      treeMap != null ? treeMap.domGenerator : treeMap;

  /// Indicates if this node accepts content.
  final bool allowContent;

  bool _commented;

  DOMNode._(bool allowContent, bool commented)
      : allowContent = allowContent ?? true,
        _commented = commented ?? false;

  DOMNode({content}) : allowContent = true {
    if (content != null) {
      _content = DOMNode.parseNodes(content);
      _setChildrenParent();
    }
  }

  @override
  DOMNode get asDOMNode => this;

  /// Returns [true] if this node has a parent.
  bool get hasParent => parent != null;

  /// If [true] this node is commented (ignored).
  bool get isCommented => _commented;

  set commented(bool value) {
    _commented = value ?? false;
  }

  /// Generates a HTML from this node tree.
  ///
  /// [withIndent] If [true] will generate a indented HTML.
  String buildHTML(
      {bool withIndent = false,
      String parentIndent = '',
      String indent = '  ',
      bool disableIndent = false,
      bool xhtml = false,
      DOMNode parentNode,
      DOMNode previousNode,
      DOMContext domContext}) {
    if (isCommented) return '';

    var html = '';

    if (isNotEmptyObject(_content)) {
      DOMNode prev;
      for (var node in _content) {
        var subHtml = node.buildHTML(
            withIndent: withIndent,
            parentIndent: parentIndent + indent,
            indent: indent,
            disableIndent: disableIndent,
            xhtml: xhtml,
            parentNode: parentNode,
            previousNode: prev,
            domContext: domContext);
        if (subHtml != null) {
          html += subHtml;
        }
        prev = node;
      }
    }

    return html;
  }

  /// Sets the default [DOMGenerator] to `dart:html` implementation.
  ///
  /// Note that `dom_builder_generator_dart_html.dart` should be imported
  /// to enable `dart:html`.
  static DOMGenerator setDefaultDomGeneratorToDartHTML() {
    return _defaultDomGenerator = DOMGenerator.dartHTML();
  }

  static DOMGenerator _defaultDomGenerator;

  /// Returns the default [DOMGenerator].
  static DOMGenerator get defaultDomGenerator {
    return _defaultDomGenerator ?? DOMGenerator.dartHTML();
  }

  static set defaultDomGenerator(DOMGenerator value) {
    _defaultDomGenerator = value ?? DOMGenerator.dartHTML();
  }

  /// Builds a DOM using [generator].
  ///
  /// Note that this instance is a virtual DOM and an implementation of
  /// [DOMGenerator] is responsible to actually generate a DOM tree.
  T buildDOM<T>({DOMGenerator<T> generator, T parent, DOMContext<T> context}) {
    if (isCommented) return null;

    generator ??= defaultDomGenerator;
    return generator.generate(this, parent: parent, context: context);
  }

  EventStream<dynamic> _onGenerate;

  /// Returns [true] if has any [onGenerate] listener registered.
  bool get hasOnGenerateListener => _onGenerate != null;

  /// Event handler for when this element is generated by [DOMGenerator].
  EventStream<dynamic> get onGenerate {
    _onGenerate ??= EventStream();
    return _onGenerate;
  }

  /// Dispatch a [onGenerate] event with [element].
  void notifyElementGenerated(dynamic element) {
    if (_onGenerate != null) {
      try {
        _onGenerate.add(element);
      } catch (e, s) {
        print(e);
        print(s);
      }
    }
  }

  /// Returns the content of this node as text.
  String get text {
    if (isEmpty || _content == null) return '';
    if (_content.length == 1) {
      return _content[0].text;
    } else {
      return _content.map((e) => e.text).join('');
    }
  }

  List<DOMNode> _content;

  /// Actual list of nodes that represents the content of this node.
  List<DOMNode> get content => _content;

  /// Returns [true] if [node] is a child of this node.
  ///
  /// [deep] If true looks deeply for [node].
  bool containsNode(DOMNode node, {deep = true}) {
    if (node == null || _content == null || _content.isEmpty) return false;

    for (var child in _content) {
      if (identical(child, node)) {
        return true;
      }

      if (deep && child.containsNode(node, deep: true)) {
        return true;
      }
    }

    return false;
  }

  /// Returns the root [DOMNode] of this element. If this node doesn't have
  /// a [parent], will return this instance as root.
  DOMNode get root {
    if (parent == null) {
      return this;
    }
    return parent.root;
  }

  int indexOfNodeIdenticalFirst(DOMNode node) {
    var idx = indexOfNodeIdentical(node);
    return idx >= 0 ? idx : indexOfNode(node);
  }

  int indexOfNodeIdentical(DOMNode node) {
    if (isEmpty) return -1;
    for (var i = 0; i < _content.length; i++) {
      var child = _content[i];
      if (identical(node, child)) return i;
    }
    return -1;
  }

  int indexOfNodeWhere(bool Function(DOMNode node) test) {
    if (isEmpty) return -1;

    for (var i = 0; i < _content.length; i++) {
      var child = _content[i];
      if (test(child)) return i;
    }

    return -1;
  }

  int _contentFromIndexBackwardWhere(
      int idx, int steps, bool Function(DOMNode node) test) {
    for (var i = Math.min(idx, _content.length - 1); i >= 0; i--) {
      var node = _content[i];
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
      int idx, int steps, bool Function(DOMNode node) test) {
    for (var i = idx; i < _content.length; i++) {
      var node = _content[i];
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

  /// Moves this node up in the parent children list.
  bool moveUp() {
    var parent = this.parent;
    if (parent == null) return false;
    return parent.moveUpNode(this);
  }

  /// Moves [node] up in the children list.
  bool moveUpNode(DOMNode node) {
    if (node == null || isEmpty) return false;

    var idx = indexOfNodeIdenticalFirst(node);
    if (idx < 0) return false;
    if (idx == 0) return true;

    _content.removeAt(idx);

    var idxUp = _contentFromIndexBackwardWhere(
        idx - 1, 0, (node) => node is DOMElement);
    if (idxUp < 0) {
      idxUp = 0;
    }

    _content.insert(idxUp, node);
    node.parent = this;
    return true;
  }

  /// Moves this node down in the parent children list.
  bool moveDown() {
    var parent = this.parent;
    if (parent == null) return false;
    return parent.moveDownNode(this);
  }

  /// Moves [node] down in the children list.
  bool moveDownNode(DOMNode node) {
    if (node == null || isEmpty) return false;

    var idx = indexOfNodeIdenticalFirst(node);
    if (idx < 0) return false;
    if (idx >= _content.length - 1) return true;

    _content.removeAt(idx);

    var idxDown =
        _contentFromIndexForwardWhere(idx, 1, (node) => node is DOMElement);
    if (idxDown < 0) {
      idxDown = _content.length;
    }

    _content.insert(idxDown, node);
    node.parent = this;
    return true;
  }

  /// Duplicate this node and add it to the parent.
  DOMNode duplicate() {
    var parent = this.parent;
    if (parent == null) return null;
    return parent.duplicateNode(this);
  }

  /// Duplicate [node] and add it to the children list.
  DOMNode duplicateNode(DOMNode node) {
    if (node == null || isEmpty) return null;

    var idx = indexOfNodeIdenticalFirst(node);
    if (idx < 0) return null;

    var elem = _content[idx];
    var copy = elem.copy();
    _content.insert(idx + 1, copy);

    copy.parent = this;

    return copy;
  }

  /// Clear the children list.
  void clearNodes() {
    if (isEmpty) return;

    for (var node in _content) {
      node.parent = null;
    }

    _content.clear();
  }

  /// Removes this node from parent.
  bool remove() {
    var parent = this.parent;
    if (parent == null) return false;
    return parent.removeNode(this);
  }

  /// Removes [node] from children list.
  bool removeNode(DOMNode node) {
    if (node == null || isEmpty) return false;

    var idx = indexOfNodeIdenticalFirst(node);
    if (idx < 0) {
      return false;
    }

    var removed = _content.removeAt(idx);

    if (removed != null) {
      removed.parent = null;
      return true;
    } else {
      return false;
    }
  }

  /// Returns the index position of this node in the parent.
  int get indexInParent {
    if (parent == null) return -1;
    return parent.indexOfNode(this);
  }

  /// Returns [true] if [other] is in the same [parent] of this node.
  bool isInSameParent(DOMNode other) {
    if (other == null) return false;
    var parent = this.parent;
    return parent != null && parent == other.parent;
  }

  /// Returns [true] if [other] is the previous sibling of this node [parent].
  bool isPreviousNode(DOMNode other) {
    if (!isInSameParent(other) || identical(this, other)) return false;
    var otherIdx = other.indexInParent;
    return otherIdx >= 0 && otherIdx + 1 == indexInParent;
  }

  /// Returns [true] if [other] is the next sibling of this node [parent].
  bool isNextNode(DOMNode other) {
    if (!isInSameParent(other) || identical(this, other)) return false;
    var idx = indexInParent;
    return idx >= 0 && idx + 1 == other.indexInParent;
  }

  /// Returns [true] if [other] is the previous or next
  /// sibling of this node [parent].
  bool isConsecutiveNode(DOMNode other) {
    return isNextNode(other) || isPreviousNode(other);
  }

  /// Absorb the content of [other] and appends to this node.
  bool absorbNode(DOMNode other) => false;

  /// Merges [other] node into this node.
  bool merge(DOMNode other, {bool onlyConsecutive = true}) => false;

  /// Returns [true] if [other] is compatible for merging.
  bool isCompatibleForMerge(DOMNode other) {
    return false;
  }

  /// Returns [true] if this element is a [TextNode] or a [DOMElement] of
  /// tag: sup, i, em, u, b, strong.
  bool get isStringElement => false;

  static final RegExp REGEXP_WHITE_SPACE =
      RegExp(r'^(?:\s+)$', multiLine: false);

  /// Returns [true] if this node only have white space content.
  bool get isWhiteSpaceContent => false;

  /// Returns a copy [List] of children nodes.
  List<DOMNode> get nodes =>
      isNotEmpty && _content != null ? List.from(_content).cast() : [];

  /// Returns the total number of children nodes.
  int get length => allowContent && _content != null ? _content.length : 0;

  /// Returns [true] if this node content is empty (no children nodes).
  bool get isEmpty =>
      allowContent && _content != null ? _content.isEmpty : true;

  /// Returns ![isEmpty].
  bool get isNotEmpty => !isEmpty;

  /// Returns [true] if this node only have [DOMElement] nodes.
  bool get hasOnlyElementNodes {
    if (isEmpty) return false;
    return _content.any((n) => !(n is DOMElement)) == false;
  }

  /// Returns [true] if this node only have [TextNode] nodes.
  bool get hasOnlyTextNodes {
    if (isEmpty) return false;
    return _content.any((n) => (n is DOMElement)) == false;
  }

  void _addToContent(dynamic entry) {
    if (entry is List) {
      _addListToContent(entry);
    } else {
      _addNodeToContent(entry);
    }
  }

  void _addListToContent(List<DOMNode> list) {
    if (list == null) return;
    list.removeWhere((e) => e == null);
    if (list.isEmpty) return;

    for (var elem in list) {
      _addNodeToContent(elem);
    }
  }

  void _addNodeToContent(DOMNode entry) {
    if (entry == null) return;

    _checkAllowContent();

    if (_content == null) {
      _content = [entry];
      ;
    } else {
      _content.add(entry);
    }

    entry.parent = this;
  }

  void _insertToContent(int index, dynamic entry) {
    if (entry is List) {
      _insertListToContent(index, entry);
    } else {
      _insertNodeToContent(index, entry);
    }
  }

  void _insertListToContent(int index, List<DOMNode> list) {
    if (list == null) return;
    list.removeWhere((e) => e == null);
    if (list.isEmpty) return;

    if (list.length == 1) {
      _addNodeToContent(list[0]);
      return;
    }

    _checkAllowContent();

    if (_content == null) {
      _content = List.from(list).cast();
      _setChildrenParent();
    } else {
      if (index > _content.length) index = _content.length;
      if (index == _content.length) {
        for (var entry in list) {
          _addNodeToContent(entry);
        }
      } else {
        _content.insertAll(index, list);
        _setChildrenParent();
      }
    }
  }

  void _setChildrenParent() {
    if (isEmpty) return;
    _content.forEach((e) => e.parent = this);
  }

  void _insertNodeToContent(int index, DOMNode entry) {
    if (entry == null) return;

    _checkAllowContent();

    if (_content == null) {
      _content = [entry];
      entry.parent = this;
    } else {
      if (index > _content.length) index = _content.length;
      if (index == _content.length) {
        _addNodeToContent(entry);
      } else {
        _content.insert(index, entry);
        entry.parent = this;
      }
    }
  }

  void _checkAllowContent() {
    if (!allowContent) {
      throw UnsupportedError("$runtimeType: can't insert entry to content!");
    }
  }

  void normalizeContent() {}

  /// Checks children nodes integrity.
  void checkNodes() {
    if (isEmpty) return;

    for (var child in _content) {
      if (child.parent == null) {
        throw StateError('parent null');
      }

      if (child is DOMElement) {
        child.checkNodes();
      }
    }
  }

  /// Sets the content of this node.
  DOMNode setContent(newContent) {
    var nodes = DOMNode.parseNodes(newContent);
    if (nodes != null && nodes.isNotEmpty) {
      _content = nodes;
      _setChildrenParent();
      normalizeContent();
    } else {
      _content = null;
    }
    return this;
  }

  /// Returns a child node by [index].
  T nodeByIndex<T extends DOMNode>(int index) {
    if (index == null || isEmpty) return null;
    return _content[index];
  }

  /// Returns a child node by [id].
  T nodeByID<T extends DOMNode>(String id) {
    if (id == null || isEmpty) return null;
    if (id.startsWith('#')) id = id.substring(1);
    return nodeWhere((n) => n is DOMElement && n.id == id);
  }

  /// Returns a node [T] that has attribute [id].
  T selectByID<T extends DOMNode>(String id) {
    if (id == null || isEmpty) return null;
    if (id.startsWith('#')) id = id.substring(1);
    return selectWhere((n) => n is DOMElement && n.id == id);
  }

  /// Returns a node [T] that has all [classes].
  T selectWithAllClass<T extends DOMNode>(List<String> classes) {
    if (isEmptyObject(classes) || isEmpty) return null;

    classes = classes
        .where((c) => c != null)
        .map((c) => c.trim())
        .where((c) => c.isNotEmpty)
        .toList();

    return selectWhere((n) => n is DOMElement && n.containsAllClasses(classes));
  }

  /// Returns a node [T] that has any of [classes].
  T selectWithAnyClass<T extends DOMNode>(List<String> classes) {
    if (isEmptyObject(classes) || isEmpty) return null;

    classes = classes
        .where((c) => c != null)
        .map((c) => c.trim())
        .where((c) => c.isNotEmpty)
        .toList();

    return selectWhere((n) => n is DOMElement && n.containsAnyClass(classes));
  }

  /// Returns a node [T] that is one of [tags].
  T selectByTag<T extends DOMNode>(List<String> tags) {
    if (isEmptyObject(tags) || isEmpty) return null;

    tags = tags
        .where((c) => c != null)
        .map((c) => c.trim())
        .where((c) => c.isNotEmpty)
        .toList();

    return selectWhere((n) => n is DOMElement && tags.contains(n.tag));
  }

  /// Returns a node [T] that is equals to [node].
  T nodeEquals<T extends DOMNode>(DOMNode node) {
    if (node == null || isEmpty) return null;
    return nodeWhere((n) => n == node);
  }

  T selectEquals<T extends DOMNode>(DOMNode node) {
    if (node == null || isEmpty) return null;
    return selectWhere((n) => n == node);
  }

  T nodeWhere<T extends DOMNode>(dynamic selector) {
    if (selector == null || isEmpty || _content == null) return null;
    var nodeSelector = asNodeSelector(selector);
    return _content.firstWhere(nodeSelector, orElse: () => null);
  }

  /// Returns a [List<T>] of children nodes that matches [selector].
  List<T> nodesWhere<T extends DOMNode>(dynamic selector) {
    if (selector == null || isEmpty || _content == null) return [];
    var nodeSelector = asNodeSelector(selector);
    return _content.where(nodeSelector).toList();
  }

  void catchNodesWhere<T extends DOMNode>(dynamic selector, List<T> destiny) {
    if (selector == null || isEmpty || _content == null) return;
    var nodeSelector = asNodeSelector(selector);
    destiny.addAll(_content.where(nodeSelector).whereType<T>());
  }

  /// Returns a [T] child node that matches [selector].
  T selectWhere<T extends DOMNode>(dynamic selector) {
    if (selector == null || isEmpty || _content == null) return null;
    var nodeSelector = asNodeSelector(selector);

    var found = nodeWhere(nodeSelector);
    if (found != null) return found;

    for (var n in _content.whereType<DOMNode>()) {
      found = n.selectWhere(nodeSelector);
      if (found != null) return found;
    }

    return null;
  }

  /// Returns a parent [T] that matches [selector].
  T selectParentWhere<T extends DOMNode>(dynamic selector) {
    if (selector == null) return null;
    var nodeSelector = asNodeSelector(selector);
    if (nodeSelector == null) return null;

    var node = this;

    while (node != null) {
      if (nodeSelector(node)) return node;
      node = node.parent;
    }
    return null;
  }

  /// Returns a child node of type [T].
  T selectByType<T extends DOMNode>() => selectWhere((n) => n is T);

  /// Returns a [List<T>] of children nodes that are of type [T].
  List<T> selectAllByType<T extends DOMNode>() =>
      selectAllWhere((n) => n is T).whereType<T>().toList();

  /// Returns a [List<T>] of children nodes that matches [selector].
  List<T> selectAllWhere<T extends DOMNode>(dynamic selector) {
    if (selector == null || isEmpty) return [];
    var nodeSelector = asNodeSelector(selector);

    var all = <T>[];
    _selectAllWhereImpl(nodeSelector, all);
    return all;
  }

  void _selectAllWhereImpl<T extends DOMNode>(
      NodeSelector selector, List<T> all) {
    if (isEmpty || _content == null) return;

    catchNodesWhere(selector, all);

    for (var n in _content.whereType<DOMNode>()) {
      n._selectAllWhereImpl(selector, all);
    }
  }

  T node<T extends DOMNode>(dynamic selector) {
    if (selector == null || isEmpty) return null;

    if (selector is num) {
      return nodeByIndex(selector);
    } else {
      return nodeWhere(selector);
    }
  }

  /// Returns a node [T] that matches [selector].
  ///
  /// [selector] can by a [num], used as a node index.
  T select<T extends DOMNode>(dynamic selector) {
    if (selector == null || isEmpty) return null;

    if (selector is num) {
      return nodeByIndex(selector);
    } else {
      return selectWhere(selector);
    }
  }

  /// Returns the index of a child node that matches [selector].
  int indexOf(dynamic selector) {
    if (selector is num) {
      if (selector < 0) return -1;
      if (isEmpty) return 0;
      if (selector >= _content.length) return _content.length;
      return selector;
    }

    if (selector == null || isEmpty) return -1;

    var nodeSelector = asNodeSelector(selector);
    return _content.indexWhere(nodeSelector);
  }

  /// Returns the index of [node].
  int indexOfNode(DOMNode node) {
    if (isEmpty) return -1;
    return _content.indexOf(node);
  }

  /// Adds each entry of [iterable] to [content].
  ///
  /// [elementGenerator] Optional element generator, that is called for each entry of [iterable].
  DOMNode addEach<T>(Iterable<T> iterable,
      [ContentGenerator<T> elementGenerator]) {
    if (elementGenerator != null) {
      for (var entry in iterable) {
        var elem = elementGenerator(entry);
        _addImpl(elem);
      }
    } else {
      for (var entry in iterable) {
        _addImpl(entry);
      }
    }

    normalizeContent();
    return this;
  }

  DOMNode addEachAsTag<T>(String tag, Iterable<T> iterable,
      [ContentGenerator<T> elementGenerator]) {
    if (elementGenerator != null) {
      for (var entry in iterable) {
        var elem = elementGenerator(entry);
        var tagElem = $tag(tag, content: elem);
        _addImpl(tagElem);
      }
    } else {
      for (var entry in iterable) {
        var tagElem = $tag(tag, content: entry);
        _addImpl(tagElem);
      }
    }

    normalizeContent();
    return this;
  }

  DOMNode addAsTag<T>(String tag, T entry,
      [ContentGenerator<T> elementGenerator]) {
    if (elementGenerator != null) {
      var elem = elementGenerator(entry);
      var tagElem = $tag(tag, content: elem);
      _addImpl(tagElem);
    } else {
      var tagElem = $tag(tag, content: entry);
      _addImpl(tagElem);
    }

    normalizeContent();
    return this;
  }

  /// Parses [html] and add it to [content].
  DOMNode addHTML(String html) {
    var list = $html(html);
    _addListToContent(list);
    normalizeContent();
    return this;
  }

  DOMNode add(dynamic entry) {
    _addImpl(entry);
    normalizeContent();
    return this;
  }

  /// Adds all [entries] to children nodes.
  DOMNode addAll(List entries) {
    if (entries != null && entries.isNotEmpty) {
      entries.forEach(_addImpl);
      normalizeContent();
    }
    return this;
  }

  void _addImpl(entry) {
    var node = _parseNode(entry);
    _addToContent(node);
  }

  /// Inserts [entry] at index of child node that matches [indexSelector].
  DOMNode insertAt(dynamic indexSelector, dynamic entry) {
    var idx = indexOf(indexSelector);

    if (idx >= 0) {
      var node = _parseNode(entry);
      _insertToContent(idx, node);
      normalizeContent();
    } else if (indexSelector is num && isEmpty) {
      var node = _parseNode(entry);
      add(node);
      normalizeContent();
    }

    return this;
  }

  /// Inserts [entry] after index of child node that matches [indexSelector].
  DOMNode insertAfter(dynamic indexSelector, dynamic entry) {
    var idx = indexOf(indexSelector);

    if (idx >= 0) {
      idx++;

      var node = _parseNode(entry);
      _insertToContent(idx, node);

      normalizeContent();
    } else if (indexSelector is num && isEmpty) {
      var node = _parseNode(entry);
      add(node);
      normalizeContent();
    }

    return this;
  }

  /// Copies this node.
  DOMNode copy() {
    return DOMNode(content: copyContent());
  }

  /// Copies this node content.
  List<DOMNode> copyContent() {
    if (_content == null) return null;
    if (_content.isEmpty) return [];
    var content2 = _content.map((e) => e.copy()).toList();
    return content2;
  }
}

DOMNode _toTextNode(String text) {
  if (text == null || text.isEmpty) {
    return TextNode('');
  }

  if (DOMTemplate.possiblyATemplate(text)) {
    var template = DOMTemplate.tryParse(text);
    return template != null ? TemplateNode(template) : TextNode(text);
  } else {
    return TextNode(text);
  }
}

/// Represents a text node in DOM.
class TextNode extends DOMNode implements WithValue {
  String _text;

  TextNode(String text)
      : _text = text ?? '',
        super._(false, false);

  @override
  String get text => _text;

  set text(String value) {
    _text = value ?? '';
  }

  bool get isTextEmpty => text.isEmpty;

  @override
  bool get hasValue => isNotEmptyObject(_text);

  @override
  bool absorbNode(DOMNode other) {
    if (other is TextNode) {
      _text += other.text;
      other.text = '';
      return true;
    } else if (other is DOMElement) {
      _text += other.text;
      other.clearNodes();
      return true;
    } else {
      return false;
    }
  }

  @override
  bool merge(DOMNode other, {bool onlyConsecutive = true}) {
    onlyConsecutive ??= true;

    if (onlyConsecutive) {
      if (isPreviousNode(other)) {
        return other.merge(this, onlyConsecutive: false);
      } else if (!isNextNode(other)) {
        return false;
      }
    }

    if (other is TextNode) {
      other.remove();
      absorbNode(other);
      return true;
    } else if (other is DOMElement &&
        other.isStringElement &&
        (other.isEmpty || other.hasOnlyTextNodes)) {
      other.remove();
      absorbNode(other);
      return true;
    } else {
      return false;
    }
  }

  @override
  bool isCompatibleForMerge(DOMNode other) {
    return other is TextNode;
  }

  @override
  bool get isStringElement => true;

  @override
  bool get hasOnlyTextNodes => true;

  @override
  bool get hasOnlyElementNodes => false;

  @override
  bool get isWhiteSpaceContent => DOMNode.REGEXP_WHITE_SPACE.hasMatch(text);

  @override
  String buildHTML(
      {bool withIndent = false,
      String parentIndent = '',
      String indent = '  ',
      bool disableIndent = false,
      bool xhtml = false,
      DOMNode parentNode,
      DOMNode previousNode,
      DOMContext domContext}) {
    var nbsp = xhtml ? '&#160;' : '&nbsp;';

    return _text.replaceAll('\xa0', nbsp);
  }

  @override
  String get value => _text;

  bool equals(Object other) =>
      identical(this, other) ||
      other is TextNode &&
          runtimeType == other.runtimeType &&
          _text == other._text;

  @override
  TextNode copy() {
    return TextNode(_text);
  }

  @override
  List<DOMNode> copyContent() {
    return null;
  }

  @override
  String toString() {
    return _text ?? '';
  }
}

/// Represents a template node in DOM.
class TemplateNode extends DOMNode implements WithValue {
  DOMTemplateNode _template;

  TemplateNode(DOMTemplateNode template)
      : _template = template ?? DOMTemplateNode([]),
        super._(false, false);

  @override
  String get text => isNotEmpty ? _template.toString() : '';

  set text(String value) {
    _template = DOMTemplate.parse(value ?? '');
  }

  DOMTemplate get template => _template;

  set template(DOMTemplate value) {
    _template = value;
  }

  @override
  bool get isEmpty => _template != null ? _template.isEmpty : true;

  @override
  bool get hasValue => _template != null && _template.isNotEmpty;

  @override
  bool absorbNode(DOMNode other) {
    if (other is TextNode) {
      text += other.text;
      other.text = '';
      return true;
    } else if (other is TemplateNode) {
      _template.addAll(other._template.nodes);
      other._template.clear();
      return true;
    } else if (other is DOMElement) {
      text += other.text;
      other.clearNodes();
      return true;
    } else {
      return false;
    }
  }

  @override
  void clearNodes() {
    _template.clear();
    super.clearNodes();
  }

  @override
  bool merge(DOMNode other, {bool onlyConsecutive = true}) {
    onlyConsecutive ??= true;

    if (onlyConsecutive) {
      if (isPreviousNode(other)) {
        return other.merge(this, onlyConsecutive: false);
      } else if (!isNextNode(other)) {
        return false;
      }
    }

    if (other is TextNode) {
      other.remove();
      absorbNode(other);
      return true;
    } else if (other is TemplateNode) {
      other.remove();
      absorbNode(other);
      return true;
    } else if (other is DOMElement &&
        other.isStringElement &&
        (other.isEmpty || other.hasOnlyTextNodes)) {
      other.remove();
      absorbNode(other);
      return true;
    } else {
      return false;
    }
  }

  @override
  bool isCompatibleForMerge(DOMNode other) {
    return other is TextNode || other is TemplateNode;
  }

  @override
  bool get isStringElement => true;

  @override
  bool get hasOnlyTextNodes => true;

  @override
  bool get hasOnlyElementNodes => false;

  @override
  bool get isWhiteSpaceContent => DOMNode.REGEXP_WHITE_SPACE.hasMatch(text);

  @override
  String buildHTML(
      {bool withIndent = false,
      String parentIndent = '',
      String indent = '  ',
      bool disableIndent = false,
      bool xhtml = false,
      DOMNode parentNode,
      DOMNode previousNode,
      DOMContext domContext}) {
    var nbsp = xhtml ? '&#160;' : '&nbsp;';

    return text.replaceAll('\xa0', nbsp);
  }

  @override
  String get value => text;

  bool equals(Object other) =>
      identical(this, other) ||
      other is TemplateNode &&
          runtimeType == other.runtimeType &&
          _template == other._template;

  @override
  TemplateNode copy() {
    return TemplateNode(DOMTemplate.parse(text));
  }

  @override
  List<DOMNode> copyContent() {
    return null;
  }

  @override
  String toString() {
    return text;
  }
}

//
// ContentGenerator:
//

typedef ContentGenerator<T> = dynamic Function(T entry);

void _checkTag(String expectedTag, DOMElement domElement) {
  if (domElement.tag != expectedTag) {
    throw StateError('Not a $expectedTag tag: $domElement');
  }
}

//
// DOMElement:
//

/// A node for HTML elements.
class DOMElement extends DOMNode implements AsDOMElement {
  static final Set<String> _SELF_CLOSING_TAGS = {
    'hr',
    'br',
    'input',
    'img',
    'meta'
  };
  static final Set<String> _SELF_CLOSING_TAGS_OPTIONAL = {'p'};

  /// Normalizes a tag name. Returns null for empty string.
  static String normalizeTag(String tag) {
    if (tag == null) return null;
    tag = tag.toLowerCase().trim();
    return tag.isNotEmpty ? tag : null;
  }

  final String tag;

  factory DOMElement(String tag,
      {Map<String, dynamic> attributes,
      id,
      classes,
      style,
      content,
      bool hidden,
      bool commented}) {
    if (tag == null) throw ArgumentError('Null tag');

    tag = tag.toLowerCase().trim();

    if (tag == 'div') {
      return DIVElement(
          attributes: attributes,
          id: id,
          classes: classes,
          style: style,
          content: content,
          hidden: hidden,
          commented: commented);
    } else if (tag == 'input') {
      return INPUTElement(
          attributes: attributes,
          id: id,
          classes: classes,
          style: style,
          value: content,
          hidden: hidden,
          commented: commented);
    } else if (tag == 'select') {
      return SELECTElement(
          attributes: attributes,
          id: id,
          classes: classes,
          style: style,
          options: content,
          hidden: hidden,
          commented: commented);
    } else if (tag == 'option') {
      return OPTIONElement(
        attributes: attributes,
        classes: classes,
        style: style,
        text: DOMNode.toText(content),
      );
    } else if (tag == 'textarea') {
      return TEXTAREAElement(
          attributes: attributes,
          id: id,
          classes: classes,
          style: style,
          content: content,
          hidden: hidden,
          commented: commented);
    } else if (tag == 'table') {
      return TABLEElement(
          attributes: attributes,
          id: id,
          classes: classes,
          style: style,
          content: content,
          hidden: hidden,
          commented: commented);
    } else if (tag == 'thead') {
      return THEADElement(
          attributes: attributes,
          id: id,
          classes: classes,
          style: style,
          rows: content,
          hidden: hidden,
          commented: commented);
    } else if (tag == 'caption') {
      return CAPTIONElement(
          attributes: attributes,
          id: id,
          classes: classes,
          style: style,
          content: content,
          hidden: hidden,
          commented: commented);
    } else if (tag == 'tbody') {
      return TBODYElement(
          attributes: attributes,
          id: id,
          classes: classes,
          style: style,
          rows: content,
          hidden: hidden,
          commented: commented);
    } else if (tag == 'tfoot') {
      return TFOOTElement(
          attributes: attributes,
          id: id,
          classes: classes,
          style: style,
          rows: content,
          hidden: hidden,
          commented: commented);
    } else if (tag == 'tr') {
      return TRowElement(
          attributes: attributes,
          id: id,
          classes: classes,
          style: style,
          cells: content,
          hidden: hidden,
          commented: commented);
    } else if (tag == 'td') {
      return TDElement(
          attributes: attributes,
          id: id,
          classes: classes,
          style: style,
          content: content,
          hidden: hidden,
          commented: commented);
    } else if (tag == 'th') {
      return THElement(
          attributes: attributes,
          id: id,
          classes: classes,
          style: style,
          content: content,
          hidden: hidden,
          commented: commented);
    } else {
      return DOMElement._(tag,
          attributes: attributes,
          id: id,
          classes: classes,
          style: style,
          content: content,
          hidden: hidden,
          commented: commented);
    }
  }

  DOMElement._(String tag,
      {Map<String, dynamic> attributes,
      id,
      classes,
      style,
      content,
      bool hidden,
      bool commented})
      : tag = normalizeTag(tag),
        super._(true, commented) {
    if (tag == null) throw ArgumentError.notNull('tag');

    addAllAttributes(attributes);

    if (id != null) {
      setAttribute('id', id);
    }

    if (classes != null) {
      appendToAttribute('class', classes);
    }

    if (style != null) {
      appendToAttribute('style', style);
    }

    if (hidden != null) {
      setAttribute('hidden', hidden);
    }

    if (content != null) {
      setContent(content);
    }
  }

  @override
  DOMElement get asDOMElement => this;

  /// Returns [true] if [tag] is one of [tags].
  bool isTagOneOf(Iterable<String> tags) {
    if (tag == null || tag.isEmpty) return false;

    for (var t in tags) {
      t = normalizeTag(t);
      if (tag == t) return true;
    }

    return false;
  }

  /// Returns the attribute `id`.
  String get id => getAttributeValue('id');

  /// Returns the attribute `class`.
  String get classes => getAttributeValue('class');

  set classes(dynamic value) => setAttribute('class', value);

  /// Returns the list of class names of the attribute `class`.
  List<String> get classesList {
    var attribute = getAttribute('class');
    if (attribute == null) return [];
    return attribute.values ?? [];
  }

  /// Sets the [List] of classes.
  set classesList(List value) => setAttribute('class', value);

  /// Adds a [className] to attribute `class`.
  void addClass(String className) {
    appendToAttribute('class', className);
  }

  /// Returns the attribute `style` as [CSS].
  CSS get style {
    var attr = getAttribute('style');
    if (attr == null) {
      var css = CSS();
      setAttribute('style', css);
      attr = getAttribute('style');
    }

    var cssHandler = attr.valueHandler as DOMAttributeValueCSS;
    return cssHandler.css;
  }

  set style(dynamic value) => setAttribute('style', value);

  String get styleText {
    var attr = getAttribute('style');
    if (attr == null) return null;
    return attr.value;
  }

  set styleText(String value) => setAttribute('style', value);

  /// Returns [true] if attribute `class` has the [className].
  bool containsClass(String className) {
    var attribute = getAttribute('class');
    if (attribute == null) return false;
    return attribute.containsValue(className);
  }

  /// Returns [true] if attribute `class` has all [classes].
  bool containsAllClasses(Iterable<String> classes) {
    var attribute = getAttribute('class');
    if (attribute == null) return false;

    if (classes == null || classes.isEmpty) return false;

    for (var c in classes) {
      if (!attribute.containsValue(c)) {
        return false;
      }
    }

    return true;
  }

  /// Returns [true] if attribute `class` has any of [classes].
  bool containsAnyClass(Iterable<String> classes) {
    var attribute = getAttribute('class');
    if (attribute == null) return false;

    if (classes == null || classes.isEmpty) return false;

    for (var c in classes) {
      if (attribute.containsValue(c)) {
        return true;
      }
    }

    return false;
  }

  LinkedHashMap<String, DOMAttribute> _attributes;

  Map<String, DOMAttribute> get domAttributes =>
      _attributes != null ? Map.from(_attributes) : {};

  Map<String, dynamic> get attributes => hasEmptyAttributes
      ? {}
      : _attributes.map((key, value) =>
          MapEntry(key, value.isCollection ? value.values : value.value));

  Map<String, String> get attributesAsString => hasEmptyAttributes
      ? {}
      : _attributes.map((key, value) => MapEntry(key, value.value));

  static const Set<String> POSSIBLE_GLOBAL_ATTRIBUTES = {
    'id',
    'navigate',
    'action',
    'uilayout',
    'oneventkeypress',
    'oneventclick'
  };

  /// Map of possible attributes for this element.
  Map<String, String> get possibleAttributes {
    var attributes = attributesAsString;

    for (var attr in POSSIBLE_GLOBAL_ATTRIBUTES) {
      attributes.putIfAbsent(attr, () => '');
    }

    if (tag == 'img' ||
        tag == 'audio' ||
        tag == 'video' ||
        tag == 'embed' ||
        tag == 'track' ||
        tag == 'source' ||
        tag == 'iframe' ||
        tag == 'script' ||
        tag == 'input') {
      attributes.putIfAbsent('src', () => '');
    } else if (tag == 'a' || tag == 'area' || tag == 'base' || tag == 'link') {
      attributes.putIfAbsent('href', () => '');
    }

    if (tag == 'img' ||
        tag == 'video' ||
        tag == 'embed' ||
        tag == 'canvas' ||
        tag == 'iframe') {
      attributes.putIfAbsent('width', () => '');
      attributes.putIfAbsent('height', () => '');
    }

    return attributes;
  }

  /// Returns the attributes names with values.
  Iterable<String> get attributesNames => hasAttributes ? _attributes.keys : [];

  /// Returns the size of attributes Map.
  int get attributesLength => _attributes != null ? _attributes.length : 0;

  /// Returns [true] if this element has NO attributes.
  bool get hasEmptyAttributes =>
      _attributes != null ? _attributes.isEmpty : true;

  /// Returns [true] if this element has attributes.
  bool get hasAttributes => !hasEmptyAttributes;

  String operator [](String name) => getAttributeValue(name);

  void operator []=(String name, dynamic value) => setAttribute(name, value);

  String get value {
    return text;
  }

  /// Returns attribute value for [name].
  ///
  /// [domContext] Optional context used by [DOMGenerator].
  String getAttributeValue(String name, [DOMContext domContext]) {
    var attr = getAttribute(name);
    return attr != null ? attr.getValue(domContext) : null;
  }

  /// Calls [getAttributeValue] and returns parsed as [bool].
  bool getAttributeValueAsBool(String name, [DOMContext domContext]) {
    return parseBool(getAttributeValue(name, domContext));
  }

  /// Calls [getAttributeValue] and returns parsed as [int].
  int getAttributeValueAsInt(String name, [DOMContext domContext]) {
    return parseInt(getAttributeValue(name, domContext));
  }

  /// Calls [getAttributeValue] and returns parsed as [double].
  double getAttributeValueAsDouble(String name, [DOMContext domContext]) {
    return parseDouble(getAttributeValue(name, domContext));
  }

  /// Returns [true] if attribute for [name] exists.
  ///
  /// [domContext] Optional context used by [DOMGenerator].
  bool hasAttributeValue(String name, [DOMContext domContext]) {
    var attr = getAttribute(name);
    if (attr == null) return false;
    var value = attr.getValue(domContext);
    return value != null && value.isNotEmpty;
  }

  /// Returns [DOMAttribute] entry for [name].
  DOMAttribute getAttribute(String name) {
    if (hasEmptyAttributes) return null;
    return _attributes[name];
  }

  /// Sets attribute for [name], parsing [value].
  DOMElement setAttribute(String name, dynamic value) {
    if (name == null) return null;

    name = name.toLowerCase().trim();

    if (_attributes != null) {
      var prevAttribute = _attributes[name];
      if (prevAttribute != null) {
        prevAttribute.setValue(value);
        return this;
      }
    }

    var attribute = DOMAttribute.from(name, value);

    if (attribute != null) {
      putDOMAttribute(attribute);
    }

    return this;
  }

  /// Appends [value] to attribute of [name].
  /// Useful for attributes like `class` and `style`.
  DOMElement appendToAttribute(String name, dynamic value) {
    // ignore: prefer_collection_literals
    _attributes ??= LinkedHashMap();

    var attr = getAttribute(name);

    if (attr == null) {
      return setAttribute(name, value);
    }

    if (attr.isCollection) {
      attr.appendValue(value);
    } else {
      attr.setValue(value);
    }

    return this;
  }

  /// Add [attributes] to this instance.
  DOMElement addAllAttributes(Map<String, dynamic> attributes) {
    if (isNotEmptyObject(attributes)) {
      for (var entry in attributes.entries) {
        var name = entry.key;
        var value = entry.value;
        setAttribute(name, value);
      }
    }

    return this;
  }

  DOMElement putDOMAttribute(DOMAttribute attribute) {
    if (attribute == null) return this;

    // ignore: prefer_collection_literals
    _attributes ??= LinkedHashMap();
    _attributes[attribute.name] = attribute;

    return this;
  }

  bool removeAttribute(String attributeName) {
    if (attributeName == null) return false;
    attributeName = attributeName.toLowerCase().trim();
    if (attributeName.isEmpty) return false;

    return _removeAttributeImp(attributeName);
  }

  bool _removeAttributeImp(String attributeName) {
    if (hasEmptyAttributes) return false;
    var attribute = _attributes.remove(attributeName);
    return attribute != null;
  }

  bool removeAttributeDeeply(String attributeName) {
    if (attributeName == null) return false;
    attributeName = attributeName.toLowerCase().trim();
    if (attributeName.isEmpty) return false;

    return _removeAttributeDeeplyImp(attributeName);
  }

  bool _removeAttributeDeeplyImp(String attributeName) {
    var removedAny = _removeAttributeImp(attributeName);

    for (var subNode in nodes) {
      if (subNode is DOMElement) {
        var removed = subNode._removeAttributeDeeplyImp(attributeName);
        if (removed) removedAny = true;
      }
    }

    return removedAny;
  }

  /// Applies [id], [classes] and [style] to this instance.
  T apply<T extends DOMElement>({id, classes, style}) {
    if (id != null) {
      setAttribute('id', id);
    }

    if (classes != null) {
      appendToAttribute('classes', classes);
    }

    if (style != null) {
      appendToAttribute('style', style);
    }

    return this;
  }

  /// Applies [id], [classes] and [style] to children nodes that matches [selector].
  T applyWhere<T extends DOMElement>(dynamic selector, {id, classes, style}) {
    var all = selectAllWhere(selector);

    for (var elem in all) {
      if (elem is DOMElement) {
        elem.apply(id: id, classes: classes, style: style);
      }
    }

    return this;
  }

  @override
  DOMElement add(entry) {
    return super.add(entry);
  }

  @override
  DOMElement addEach<T>(Iterable<T> iterable,
      [ContentGenerator<T> elementGenerator]) {
    return super.addEach(iterable, elementGenerator);
  }

  @override
  DOMElement addEachAsTag<T>(String tag, Iterable<T> iterable,
      [ContentGenerator<T> elementGenerator]) {
    return super.addEachAsTag(tag, iterable, elementGenerator);
  }

  @override
  DOMElement addHTML(String html) {
    return super.addHTML(html);
  }

  @override
  DOMElement insertAfter(indexSelector, entry) {
    return super.insertAfter(indexSelector, entry);
  }

  @override
  DOMElement insertAt(indexSelector, entry) {
    return super.insertAt(indexSelector, entry);
  }

  @override
  DOMElement setContent(elementContent) {
    return super.setContent(elementContent);
  }

  @override
  bool absorbNode(DOMNode other) {
    if (other == null) return false;

    if (other is DOMElement) {
      if (other.isEmpty) return true;
      addAll(other._content);
      other._content.clear();
      return true;
    } else if (other is TextNode) {
      other.remove();
      add(other);
      return true;
    } else {
      return false;
    }
  }

  /// Merges this node with [other]. Useful for consecutive text elements like
  /// `b`, `i` and `span`.
  @override
  bool merge(DOMNode other, {bool onlyConsecutive = true}) {
    onlyConsecutive ??= true;

    if (onlyConsecutive) {
      if (isPreviousNode(other)) {
        return other.merge(this, onlyConsecutive: false);
      } else if (!isNextNode(other)) {
        return false;
      }
    }

    if (other is DOMElement) {
      if (tag != other.tag) return false;

      other.remove();
      absorbNode(other);
      return true;
    } else if (other is TextNode) {
      other.remove();
      absorbNode(other);
      return true;
    } else {
      return false;
    }
  }

  /// Returns [true] if [other] is compatible to call [merge].
  @override
  bool isCompatibleForMerge(DOMNode other) {
    if (other is DOMElement) {
      if (tag == other.tag) {
        return getAttributesSignature() == other.getAttributesSignature();
      }
    }
    return false;
  }

  /// Returns a deterministic [String] of all attributes entries.
  String getAttributesSignature() {
    if (_attributes == null || _attributes.isEmpty) return '';
    var entries = _attributes
        .map((key, value) => MapEntry(key.toLowerCase(), value.value))
        .entries
        .toList();
    entries.sort((a, b) => a.key.compareTo(b.key));
    var attributesSignature =
        entries.map((e) => '${e.key}=${e.value}').toList();
    return attributesSignature.join('\n');
  }

  @override
  bool get isStringElement {
    return isStringTagName(tag);
  }

  static bool isStringTagName(String tag) {
    tag = normalizeTag(tag);
    if (tag == null || tag.isEmpty) return false;
    return _isStringTagName(tag);
  }

  static bool _isStringTagName(String tag) {
    switch (tag) {
      case 'sub':
      case 'sup':
      case 'i':
      case 'em':
      case 'u':
      case 'b':
      case 'strong':
        return true;
      default:
        return false;
    }
  }

  @override
  bool get isWhiteSpaceContent {
    if (hasOnlyTextNodes) {
      return DOMNode.REGEXP_WHITE_SPACE.hasMatch(text);
    }
    return false;
  }

  String buildOpenTagHTML({bool openCloseTag = false, DOMContext domContext}) {
    var html = '<$tag';

    if (hasAttributes) {
      var attributeId = _attributes['id'];
      var attributeClass = _attributes['class'];
      var attributeStyle = _attributes['style'];

      html = DOMAttribute.append(html, ' ', attributeId, domContext);
      html = DOMAttribute.append(html, ' ', attributeClass, domContext);
      html = DOMAttribute.append(html, ' ', attributeStyle, domContext);

      var attributesNormal = _attributes.values.where((v) =>
          v != null && v.hasValue && !_isPriorityAttribute(v) && !v.isBoolean);

      for (var attr in attributesNormal) {
        html = DOMAttribute.append(html, ' ', attr, domContext);
      }

      var attributesBoolean = _attributes.values.where((v) =>
          v != null && v.hasValue && !_isPriorityAttribute(v) && v.isBoolean);

      for (var attr in attributesBoolean) {
        html = DOMAttribute.append(html, ' ', attr, domContext);
      }
    }

    html += openCloseTag ? '/>' : '>';

    return html;
  }

  bool _isPriorityAttribute(DOMAttribute attr) {
    return attr.name == 'id' || attr.name == 'class' || attr.name == 'style';
  }

  String buildCloseTagHTML() {
    return '</$tag>';
  }

  static bool _tagAllowsInnerIndent(String tag) {
    if (_isStringTagName(tag)) return false;

    switch (tag) {
      case 'style':
      case 'script':
      case 'pre':
        return false;
      default:
        return true;
    }
  }

  @override
  String buildHTML(
      {bool withIndent = false,
      String parentIndent = '',
      String indent = '  ',
      bool disableIndent = false,
      bool xhtml = false,
      DOMNode parentNode,
      DOMNode previousNode,
      DOMContext domContext}) {
    disableIndent ??= false;
    if (!disableIndent && !_tagAllowsInnerIndent(tag)) {
      disableIndent = true;
    }

    var allowIndent =
        withIndent && isNotEmpty && hasOnlyElementNodes && !disableIndent;

    var innerIndent = allowIndent ? parentIndent + indent : '';
    var innerBreakLine = allowIndent ? '\n' : '';

    if (parentIndent.isNotEmpty &&
        previousNode != null &&
        previousNode.isStringElement) {
      parentIndent = '';
    }

    var emptyContent = isEmptyObject(_content);

    if (_SELF_CLOSING_TAGS.contains(tag) ||
        (emptyContent && _SELF_CLOSING_TAGS_OPTIONAL.contains(tag))) {
      var html = parentIndent +
          buildOpenTagHTML(openCloseTag: xhtml, domContext: domContext);
      return html;
    }

    var html = parentIndent +
        buildOpenTagHTML(domContext: domContext) +
        innerBreakLine;

    if (!emptyContent) {
      DOMNode prev;
      for (var node in _content) {
        var subElement = node.buildHTML(
            withIndent: withIndent,
            parentIndent: innerIndent,
            indent: indent,
            disableIndent: disableIndent,
            xhtml: xhtml,
            parentNode: this,
            previousNode: prev,
            domContext: domContext);
        if (subElement != null) {
          html += subElement + innerBreakLine;
        }
        prev = node;
      }
    }

    html += (allowIndent ? parentIndent : '') + buildCloseTagHTML();

    return html;
  }

  /// Returns true if [other] is fully equals.
  bool equals(Object other) =>
      identical(this, other) ||
      other is DOMElement &&
          runtimeType == other.runtimeType &&
          tag == other.tag &&
          equalsAttributes(other) &&
          ((isEmpty && other.isEmpty) ||
              isEqualsDeep(_content, other._content));

  /// Returns true if [other] have the same attributes.
  bool equalsAttributes(DOMElement other) =>
      ((hasEmptyAttributes && other.hasEmptyAttributes) ||
          isEqualsDeep(_attributes, other._attributes));

  static int objectHashcode(dynamic o) {
    if (isEmptyObject(o)) return 0;
    return deepHashCode(o);
  }

  @override
  String toString() {
    var attributesStr = hasAttributes ? ', attributes: $_attributes' : '';
    var contentStr = isNotEmpty ? ', content: ${_content.length}' : '';

    return 'DOMElement{tag: $tag$attributesStr$contentStr}';
  }

  @override
  DOMElement copy() {
    return DOMElement(tag,
        attributes: attributes, commented: isCommented, content: copyContent());
  }

  EventStream<DOMMouseEvent> _onClick;

  /// Returns [true] if has any [onClick] listener registered.
  bool get hasOnClickListener => _onClick != null;

  /// Event handler for `click` events.
  EventStream<DOMMouseEvent> get onClick {
    _onClick ??= EventStream();
    return _onClick;
  }

  EventStream<DOMEvent> _onChange;

  /// Returns [true] if has any [onChange] listener registered.
  bool get hasOnChangeListener => _onChange != null;

  /// Event handler for `change` events.
  EventStream<DOMEvent> get onChange {
    _onChange ??= EventStream();
    return _onChange;
  }

  EventStream<DOMMouseEvent> _onMouseOver;

  /// Returns [true] if has any [onMouseOver] listener registered.
  bool get hasOnMouseOverListener => _onMouseOver != null;

  /// Event handler for click `mouseOver` events.
  EventStream<DOMMouseEvent> get onMouseOver {
    _onMouseOver ??= EventStream();
    return _onMouseOver;
  }

  EventStream<DOMMouseEvent> _onMouseOut;

  /// Returns [true] if has any [onMouseOut] listener registered.
  bool get hasOnMouseOutListener => _onMouseOut != null;

  /// Event handler for click `mouseOut` events.
  EventStream<DOMMouseEvent> get onMouseOut {
    _onMouseOut ??= EventStream();
    return _onMouseOut;
  }

  EventStream<DOMEvent> _onLoad;

  /// Returns [true] if has any [onLoad] listener registered.
  bool get hasOnLoadListener => _onLoad != null;

  /// Event handler for `load` events.
  EventStream<DOMEvent> get onLoad {
    _onLoad ??= EventStream();
    return _onLoad;
  }

  EventStream<DOMEvent> _onError;

  /// Returns [true] if has any [onError] listener registered.
  bool get hasOnErrorListener => _onError != null;

  /// Event handler for `load` events.
  EventStream<DOMEvent> get onError {
    _onError ??= EventStream();
    return _onError;
  }
}

//
// Events:
//

/// Base class for [DOMElement] events.
class DOMEvent<T> {
  final DOMTreeMap<T> treeMap;
  final dynamic event;
  final dynamic eventTarget;
  final DOMElement target;

  DOMEvent(this.treeMap, this.event, this.eventTarget, this.target);

  DOMGenerator<T> get domGenerator => treeMap.domGenerator;

  bool cancel({bool stopImmediatePropagation = false}) =>
      domGenerator.cancelEvent(event,
          stopImmediatePropagation: stopImmediatePropagation ?? false);

  @override
  String toString() {
    return '$event';
  }
}

/// Represents a mouse event.
class DOMMouseEvent<T> extends DOMEvent<T> {
  final Point<num> client;

  final Point<num> offset;

  final Point<num> page;

  final Point<num> screen;

  final int button;

  final int buttons;

  final bool altKey;

  final bool ctrlKey;

  final bool shiftKey;

  final bool metaKey;

  DOMMouseEvent(
      DOMTreeMap treeMap,
      dynamic event,
      dynamic eventTarget,
      DOMNode target,
      this.client,
      this.offset,
      this.page,
      this.screen,
      this.button,
      this.buttons,
      this.altKey,
      this.ctrlKey,
      this.shiftKey,
      this.metaKey)
      : super(treeMap, event, eventTarget, target);

  @override
  bool cancel({bool stopImmediatePropagation = false}) =>
      domGenerator.cancelEvent(event,
          stopImmediatePropagation: stopImmediatePropagation ?? false);
}

//
// ExternalElementNode:
//

/// Class wrapper for a external element as a [DOMNode].
class ExternalElementNode extends DOMNode {
  final dynamic externalElement;

  ExternalElementNode(this.externalElement, [bool allowContent])
      : super._(allowContent, false);

  @override
  String buildHTML(
      {bool withIndent = false,
      String parentIndent = '',
      String indent = '  ',
      bool disableIndent = false,
      bool xhtml = false,
      DOMNode parentNode,
      DOMNode previousNode,
      DOMContext domContext}) {
    if (externalElement == null) return '';

    if (externalElement is String) {
      return externalElement;
    } else if (externalElement is DOMElementGenerator) {
      var function = externalElement as DOMElementGenerator;
      var element = function(parentNode);
      return element != null ? '$element' : '';
    } else if (externalElement is DOMElementGeneratorFunction) {
      var function = externalElement as DOMElementGeneratorFunction;
      var element = function();
      return element != null ? '$element' : '';
    } else {
      return '$externalElement';
    }
  }

  @override
  ExternalElementNode copy() {
    return ExternalElementNode(externalElement, allowContent);
  }
}

//
// DIVElement:
//

/// Class for a `div` element.
class DIVElement extends DOMElement {
  factory DIVElement.from(dynamic entry) {
    if (entry == null) return null;
    if (entry is html_dom.Node) {
      entry = DOMNode.from(entry);
    }

    if (entry is DIVElement) return entry;

    if (entry is DOMElement) {
      _checkTag('div', entry);
      return DIVElement(
          attributes: entry._attributes,
          content: entry._content,
          commented: entry.isCommented);
    }

    return null;
  }

  DIVElement(
      {Map<String, dynamic> attributes,
      id,
      classes,
      style,
      content,
      bool hidden,
      bool commented})
      : super._('div',
            attributes: attributes,
            id: id,
            classes: classes,
            style: style,
            content: content,
            hidden: hidden,
            commented: commented);

  @override
  DIVElement copy() {
    return DIVElement(
        attributes: attributes, commented: isCommented, content: copyContent());
  }
}

//
// INPUTElement:
//

class INPUTElement extends DOMElement implements WithValue {
  factory INPUTElement.from(dynamic entry) {
    if (entry == null) return null;
    if (entry is html_dom.Node) {
      entry = DOMNode.from(entry);
    }

    if (entry is INPUTElement) return entry;

    if (entry is DOMElement) {
      _checkTag('input', entry);
      return INPUTElement(
          attributes: entry._attributes,
          value: entry.value,
          commented: entry.isCommented);
    }

    return null;
  }

  INPUTElement(
      {Map<String, dynamic> attributes,
      id,
      name,
      type,
      placeholder,
      classes,
      style,
      value,
      bool hidden,
      bool commented})
      : super._('input',
            id: id,
            classes: classes,
            style: style,
            attributes: {
              if (name != null) 'name': name,
              if (type != null) 'type': type,
              if (placeholder != null) 'placeholder': placeholder,
              if (value != null) 'value': value,
              ...?attributes
            },
            hidden: hidden,
            commented: commented);

  @override
  INPUTElement copy() {
    return INPUTElement(attributes: attributes, commented: isCommented);
  }

  @override
  bool get hasValue => isNotEmptyObject(value);

  @override
  String get value => getAttributeValue('value');
}

//
// SELECTElement:
//

class SELECTElement extends DOMElement {
  factory SELECTElement.from(dynamic entry) {
    if (entry == null) return null;
    if (entry is html_dom.Node) {
      entry = DOMNode.from(entry);
    }

    if (entry is SELECTElement) return entry;

    if (entry is DOMElement) {
      _checkTag('select', entry);
      return SELECTElement(
          attributes: entry._attributes,
          options: OPTIONElement.toOptions(entry.content),
          commented: entry.isCommented);
    }

    return null;
  }

  SELECTElement(
      {Map<String, dynamic> attributes,
      id,
      name,
      type,
      classes,
      style,
      options,
      bool multiple,
      bool hidden,
      bool commented})
      : super._('select',
            id: id,
            classes: classes,
            style: style,
            attributes: {
              ...?attributes,
              if (name != null) 'name': name,
              if (type != null) 'type': type,
              if (multiple != null && multiple) 'multiple': true,
            },
            content: OPTIONElement.toOptions(options),
            hidden: hidden,
            commented: commented);

  @override
  SELECTElement copy() {
    return SELECTElement(
        attributes: attributes, options: content, commented: isCommented);
  }

  bool get hasOptions => isNotEmpty;

  List<OPTIONElement> get options =>
      content?.whereType<OPTIONElement>()?.toList() ?? [];

  void addOption(dynamic option) => add(OPTIONElement.from(option));

  void addOptions(dynamic options) => addAll(OPTIONElement.toOptions(options));

  OPTIONElement getOption(dynamic option) {
    if (option == null) return null;
    if (option is OPTIONElement) {
      return getOptionByValue(option.value);
    }
    return getOptionByValue(option.toString());
  }

  OPTIONElement getOptionByValue(dynamic value) {
    if (value == null) return null;
    return options.firstWhere((e) => e.value == value, orElse: () => null);
  }

  OPTIONElement getOptionByIndex(int index) {
    return index != null && index < options.length ? options[index] : null;
  }

  OPTIONElement get selectedOption => content
      ?.whereType<OPTIONElement>()
      ?.firstWhere((e) => e.selected, orElse: () => null);

  String get selectedValue => selectedOption?.value;

  bool get hasSelection => selectedOption != null;

  void unselectAllOptions() {
    for (var opt in options) {
      opt.selected = false;
    }
  }

  OPTIONElement selectOption(dynamic option, [bool selected = true]) {
    var elem = getOption(option);

    if (elem != null) {
      selected ??= true;
      elem.selected = selected;
      return elem;
    }

    return null;
  }
}

//
// OPTIONElement:
//

class OPTIONElement extends DOMElement implements WithValue {
  static List<OPTIONElement> toOptions(dynamic options) {
    if (options == null) return [];
    if (options is OPTIONElement) return [options];

    if (options is Iterable) {
      return options.map((e) => OPTIONElement.from(e)).toList();
    } else if (options is Map) {
      return options.values.map((e) => OPTIONElement.from(e)).toList();
    } else {
      return [OPTIONElement.from(options)];
    }
  }

  factory OPTIONElement.from(dynamic entry) {
    if (entry == null) return null;
    if (entry is html_dom.Node) {
      entry = DOMNode.from(entry);
    }

    if (entry is OPTIONElement) return entry;

    if (entry is DOMElement) {
      _checkTag('option', entry);
      return OPTIONElement(
        attributes: entry._attributes,
        value: entry.value,
        label: entry.getAttributeValue('label'),
        selected: entry.getAttributeValueAsBool('selected'),
        text: entry.text,
      );
    }

    dynamic value;
    dynamic text;

    if (entry is String || entry is num || entry is bool) {
      value = text = entry.toString();
    } else if (entry is TextNode) {
      value = text = entry.text;
    } else if (entry is MapEntry) {
      value = entry.key;
      text = entry.value;
    } else if (entry is Pair) {
      value = entry.a;
      text = entry.b;
    } else if (entry is Iterable) {
      if (entry.length == 1) {
        value = text = entry.first?.toString();
      } else if (entry.length >= 2) {
        var l = entry.toList();
        value = l[0];
        text = l[1];
      }
    } else {
      value = text = entry.toString();
    }

    var valueStr = parseString(value);
    var textStr = parseString(text);

    if (isNotEmptyString(valueStr, trim: true) ||
        isNotEmptyString(textStr, trim: true)) {
      return OPTIONElement(
        value: valueStr,
        text: textStr,
      );
    }

    return null;
  }

  OPTIONElement(
      {Map<String, dynamic> attributes,
      classes,
      style,
      dynamic value,
      String label,
      bool selected,
      String text})
      : super._(
          'option',
          classes: classes,
          style: style,
          attributes: {
            ...?attributes,
            if (value != null) 'value': parseString(value),
            if (label != null) 'label': label,
            if (selected != null) 'selected': parseBool(selected),
          },
          content: _toTextNode(text),
        );

  @override
  OPTIONElement copy() {
    return OPTIONElement(
      attributes: attributes,
      text: text,
    );
  }

  @override
  bool get hasValue => isNotEmptyObject(value);

  @override
  String get value => getAttributeValue('value');

  set value(String val) => setAttribute('value', val);

  String get label => getAttributeValue('label');

  set label(String label) => setAttribute('label', label);

  bool get selected => getAttributeValueAsBool('selected');

  set selected(bool sel) {
    sel ??= false;

    if (sel) {
      setAttribute('selected', sel);
    } else {
      removeAttribute('selected');
    }
  }
}

//
// TEXTAREAElement:
//

class TEXTAREAElement extends DOMElement implements WithValue {
  factory TEXTAREAElement.from(dynamic entry) {
    if (entry == null) return null;
    if (entry is html_dom.Node) {
      entry = DOMNode.from(entry);
    }

    if (entry is TEXTAREAElement) return entry;

    if (entry is DOMElement) {
      _checkTag('textarea', entry);
      return TEXTAREAElement(
          attributes: entry._attributes,
          content: entry.content,
          commented: entry.isCommented);
    }

    return null;
  }

  TEXTAREAElement(
      {Map<String, dynamic> attributes,
      id,
      name,
      classes,
      style,
      cols,
      rows,
      content,
      bool hidden,
      bool commented})
      : super._('textarea',
            id: id,
            classes: classes,
            style: style,
            attributes: {
              if (name != null) 'name': cols,
              if (cols != null) 'cols': cols,
              if (rows != null) 'rows': rows,
              ...?attributes
            },
            content: content,
            hidden: hidden,
            commented: commented);

  @override
  TEXTAREAElement copy() {
    return TEXTAREAElement(
        attributes: attributes, content: content, commented: isCommented);
  }

  @override
  bool get hasValue => isNotEmptyObject(value);

  @override
  String get value => getAttributeValue('value');
}

//
// TABLEElement:
//

CAPTIONElement createTableCaption(dynamic caption) {
  var nodes = DOMNode.parseNodes(caption);
  if (nodes != null && nodes.isNotEmpty) {
    if (nodes.length == 1) {
      var first = nodes.first;
      if (first is CAPTIONElement) {
        return first;
      }
    }

    return CAPTIONElement(content: nodes);
  }
  return null;
}

List createTableContent(content, caption, head, body, foot,
    {bool header, bool footer}) {
  if (content == null) {
    return [
      createTableCaption(caption),
      createTableEntry(head, header: true),
      createTableEntry(body),
      createTableEntry(foot, footer: true)
    ];
  } else if (content is List) {
    if (listMatchesAll(content, (e) => e is html_dom.Node)) {
      var caption = content.firstWhere(
          (e) => e is html_dom.Element && e.localName == 'caption',
          orElse: () => null);
      var thread = content.firstWhere(
          (e) => e is html_dom.Element && e.localName == 'thead',
          orElse: () => null);
      var tfoot = content.firstWhere(
          (e) => e is html_dom.Element && e.localName == 'tfoot',
          orElse: () => null);
      var tbody = content.firstWhere(
          (e) => e is html_dom.Element && e.localName == 'tbody',
          orElse: () => null);

      var list = [
        DOMNode.from(caption),
        DOMNode.from(thread),
        DOMNode.from(tbody),
        DOMNode.from(tfoot)
      ];
      list.removeWhere((e) => e == null);
      return list;
    } else {
      return content.map((e) => createTableEntry(e)).toList();
    }
  } else {
    return [createTableEntry(body)];
  }
}

TABLENode createTableEntry(dynamic entry, {bool header, bool footer}) {
  if (entry == null) return null;
  header ??= false;
  footer ??= false;

  if (entry is THEADElement) {
    return entry;
  } else if (entry is CAPTIONElement) {
    return entry;
  } else if (entry is TBODYElement) {
    return entry;
  } else if (entry is TFOOTElement) {
    return entry;
  } else if (entry is html_dom.Element) {
    return DOMNode.from(entry);
  } else if (entry is html_dom.Text) {
    return DOMNode.from(entry);
  } else {
    if (header) {
      return $thead(rows: entry);
    } else if (footer) {
      return $tfoot(rows: entry);
    } else {
      return $tbody(rows: entry);
    }
  }
}

List<TRowElement> createTableRows(dynamic rows, bool header) {
  List<TRowElement> tableRows;

  if (rows is Iterable) {
    var rowsList = List.from(rows);

    if (listMatchesAll(rowsList, (e) => e is TRowElement)) {
      return rowsList.cast();
    } else if (listMatchesAll(rowsList, (e) => e is html_dom.Node)) {
      var trList =
          rowsList.where((e) => e is html_dom.Element && e.localName == 'tr');
      var list = trList.map((e) => DOMNode.from(e)).toList();
      list.removeWhere((e) => e == null);
      return list.cast();
    } else if (listMatchesAll(rowsList, (e) => e is MapEntry)) {
      var mapEntries = rowsList.whereType<MapEntry>().toList();
      tableRows = mapEntries
          .map((e) => createTableRow([e.key, e.value], header))
          .toList();
    } else if (rowsList.any((e) => e is List)) {
      tableRows = [];
      for (var rowCells in rowsList) {
        var tr = createTableRow(rowCells, header);
        tableRows.add(tr);
      }
    } else {
      tableRows = [createTableRow(rowsList, header)];
    }
  } else {
    tableRows = [createTableRow(rows, header)];
  }

  return tableRows;
}

TRowElement createTableRow(dynamic rowCells, [bool header]) {
  header ??= false;

  if (rowCells is TRowElement) {
    return rowCells;
  }

  Iterable iterable;

  if (rowCells is Iterable) {
    iterable = List.from(rowCells);
  } else {
    iterable = [rowCells];
  }

  var tr = TRowElement();

  if (header) {
    for (var e in iterable) {
      if (e is THElement) {
        tr.add(e);
      } else if (e is TDElement) {
        tr.add(e.asTHElement());
      } else {
        tr.addAsTag('th', e);
      }
    }
  } else {
    for (var e in iterable) {
      if (e is TDElement) {
        tr.add(e);
      } else if (e is THElement) {
        tr.add(e.asTDElement());
      } else {
        tr.addAsTag('td', e);
      }
    }
  }

  return tr;
}

List<TABLENode> createTableCells(dynamic rowCells, [bool header]) {
  header ??= false;

  if (rowCells is List &&
      listMatchesAll(rowCells,
          (e) => (!header && e is TDElement) || (header && e is THElement))) {
    return rowCells.cast();
  } else if (rowCells is List &&
      listMatchesAll(rowCells, (e) => e is html_dom.Node)) {
    var tdList = rowCells.where((e) =>
        e is html_dom.Element && (e.localName == 'td' || e.localName == 'th'));
    var list = tdList.map((e) => DOMNode.from(e)).toList();
    list.removeWhere((e) => e == null);
    return list.cast();
  }

  List list;
  if (header) {
    list = $tags('th', rowCells);
  } else {
    list = $tags('td', rowCells);
  }

  return list != null ? list.cast() : null;
}

abstract class TABLENode extends DOMElement {
  TABLENode._(String tag,
      {Map<String, dynamic> attributes,
      id,
      classes,
      style,
      content,
      bool hidden,
      bool commented})
      : super._(tag,
            attributes: attributes,
            id: id,
            classes: classes,
            style: style,
            content: content,
            hidden: hidden,
            commented: commented);

  @override
  TABLENode copy() {
    return super.copy();
  }
}

class TABLEElement extends DOMElement {
  factory TABLEElement.from(dynamic entry) {
    if (entry == null) return null;
    if (entry is html_dom.Node) {
      entry = DOMNode.from(entry);
    }

    if (entry is TABLEElement) return entry;

    if (entry is DOMElement) {
      _checkTag('table', entry);
      return TABLEElement(
          attributes: entry._attributes,
          body: entry._content,
          commented: entry.isCommented);
    }

    return null;
  }

  TABLEElement(
      {Map<String, dynamic> attributes,
      id,
      classes,
      style,
      caption,
      head,
      body,
      foot,
      content,
      bool hidden,
      bool commented})
      : super._('table',
            attributes: attributes,
            id: id,
            classes: classes,
            style: style,
            content: createTableContent(content, caption, head, body, foot),
            hidden: hidden,
            commented: commented);

  @override
  TABLEElement copy() {
    return TABLEElement(
        attributes: attributes, commented: isCommented, content: copyContent());
  }
}

class THEADElement extends TABLENode {
  factory THEADElement.from(dynamic entry) {
    if (entry == null) return null;
    if (entry is html_dom.Node) {
      entry = DOMNode.from(entry);
    }

    if (entry is THEADElement) return entry;

    if (entry is DOMElement) {
      _checkTag('thead', entry);
      return THEADElement(
          attributes: entry._attributes,
          rows: entry._content,
          commented: entry.isCommented);
    }

    return null;
  }

  THEADElement(
      {Map<String, dynamic> attributes,
      id,
      classes,
      style,
      rows,
      bool hidden,
      bool commented})
      : super._('thead',
            attributes: attributes,
            id: id,
            classes: classes,
            style: style,
            content: createTableRows(rows, true),
            hidden: hidden,
            commented: commented);

  @override
  THEADElement copy() {
    return THEADElement(
        attributes: attributes, commented: isCommented, rows: copyContent());
  }
}

class CAPTIONElement extends TABLENode {
  factory CAPTIONElement.from(dynamic entry) {
    if (entry == null) return null;
    if (entry is html_dom.Node) {
      entry = DOMNode.from(entry);
    }

    if (entry is CAPTIONElement) return entry;

    if (entry is DOMElement) {
      _checkTag('caption', entry);
      return CAPTIONElement(
          attributes: entry._attributes,
          content: entry._content,
          commented: entry.isCommented);
    }

    return null;
  }

  CAPTIONElement(
      {Map<String, dynamic> attributes,
      id,
      classes,
      style,
      content,
      bool hidden,
      bool commented})
      : super._('caption',
            attributes: attributes,
            id: id,
            classes: classes,
            style: style,
            content: content,
            hidden: hidden,
            commented: commented);

  @override
  CAPTIONElement copy() {
    return CAPTIONElement(
        attributes: attributes, commented: isCommented, content: copyContent());
  }
}

class TBODYElement extends TABLENode {
  factory TBODYElement.from(dynamic entry) {
    if (entry == null) return null;
    if (entry is html_dom.Node) {
      entry = DOMNode.from(entry);
    }

    if (entry is TBODYElement) return entry;

    if (entry is DOMElement) {
      _checkTag('tbody', entry);
      return TBODYElement(
          attributes: entry._attributes,
          rows: entry._content,
          commented: entry.isCommented);
    }

    return null;
  }

  TBODYElement(
      {Map<String, dynamic> attributes,
      id,
      classes,
      style,
      rows,
      bool hidden,
      bool commented})
      : super._('tbody',
            attributes: attributes,
            id: id,
            classes: classes,
            style: style,
            content: createTableRows(rows, false),
            hidden: hidden,
            commented: commented);

  @override
  TBODYElement copy() {
    return TBODYElement(
        attributes: attributes, commented: isCommented, rows: copyContent());
  }
}

class TFOOTElement extends TABLENode {
  factory TFOOTElement.from(dynamic entry) {
    if (entry == null) return null;
    if (entry is html_dom.Node) {
      entry = DOMNode.from(entry);
    }

    if (entry is TFOOTElement) return entry;

    if (entry is DOMElement) {
      _checkTag('tfoot', entry);
      return TFOOTElement(
          attributes: entry._attributes,
          rows: entry._content,
          commented: entry.isCommented);
    }

    return null;
  }

  TFOOTElement(
      {Map<String, dynamic> attributes,
      id,
      classes,
      style,
      rows,
      bool hidden,
      bool commented})
      : super._('tfoot',
            attributes: attributes,
            id: id,
            classes: classes,
            style: style,
            content: createTableRows(rows, false),
            hidden: hidden,
            commented: commented);

  @override
  TFOOTElement copy() {
    return TFOOTElement(
        attributes: attributes, commented: isCommented, rows: copyContent());
  }
}

class TRowElement extends TABLENode {
  factory TRowElement.from(dynamic entry) {
    if (entry == null) return null;
    if (entry is html_dom.Node) {
      entry = DOMNode.from(entry);
    }

    if (entry is TRowElement) return entry;

    if (entry is DOMElement) {
      _checkTag('tr', entry);
      return TRowElement(
          attributes: entry._attributes,
          cells: entry._content,
          commented: entry.isCommented);
    }

    return null;
  }

  TRowElement(
      {Map<String, dynamic> attributes,
      id,
      classes,
      style,
      cells,
      bool headerRow,
      bool hidden,
      bool commented})
      : super._('tr',
            attributes: attributes,
            id: id,
            classes: classes,
            style: style,
            content: createTableCells(cells, headerRow),
            hidden: hidden,
            commented: commented);

  bool get isHeaderRow => parent != null ? parent is THEADElement : false;

  bool get isFooterRow => parent != null ? parent is TFOOTElement : false;

  @override
  TRowElement copy() {
    return TRowElement(
        attributes: attributes,
        commented: isCommented,
        cells: copyContent(),
        headerRow: isHeaderRow);
  }
}

class THElement extends TABLENode {
  factory THElement.from(dynamic entry) {
    if (entry == null) return null;
    if (entry is html_dom.Node) {
      entry = DOMNode.from(entry);
    }

    if (entry is THElement) return entry;

    if (entry is DOMElement) {
      _checkTag('th', entry);
      return THElement(
          attributes: entry._attributes,
          content: entry._content,
          commented: entry.isCommented);
    }

    return null;
  }

  THElement(
      {Map<String, dynamic> attributes,
      id,
      classes,
      style,
      content,
      bool hidden,
      bool commented})
      : super._('th',
            attributes: attributes,
            id: id,
            classes: classes,
            style: style,
            content: content,
            hidden: hidden,
            commented: commented);

  @override
  THElement copy() {
    return THElement(
        attributes: attributes, commented: isCommented, content: copyContent());
  }

  TDElement asTDElement() {
    return TDElement(
        attributes: attributes, commented: isCommented, content: copyContent());
  }
}

class TDElement extends TABLENode {
  factory TDElement.from(dynamic entry) {
    if (entry == null) return null;
    if (entry is html_dom.Node) {
      entry = DOMNode.from(entry);
    }

    if (entry is TDElement) return entry;

    if (entry is DOMElement) {
      _checkTag('td', entry);
      return TDElement(
          attributes: entry._attributes,
          content: entry._content,
          commented: entry.isCommented);
    }

    return null;
  }

  TDElement(
      {Map<String, dynamic> attributes,
      id,
      classes,
      style,
      content,
      bool hidden,
      bool commented})
      : super._('td',
            attributes: attributes,
            id: id,
            classes: classes,
            style: style,
            content: content,
            hidden: hidden,
            commented: commented);

  @override
  TDElement copy() {
    return TDElement(
        attributes: attributes, commented: isCommented, content: copyContent());
  }

  THElement asTHElement() {
    return THElement(
        attributes: attributes, commented: isCommented, content: copyContent());
  }
}

/// A [DOMNode] that will be defined in the future.
class DOMAsync extends DOMNode {
  /// A Future that returns the final node content.
  final Future future;

  /// A [Function] that returns the [Future] that defines this node content.
  final Future Function() function;

  /// Content to be showed while [future]/[function] is being executed.
  final dynamic loading;

  DOMAsync({this.loading, this.future, this.function}) : super._(false, false);

  DOMAsync.future(Future future, [dynamic loading])
      : this(future: future, loading: loading);

  DOMAsync.function(Future Function() function, [dynamic loading])
      : this(function: function, loading: loading);

  Future _resolvedFuture;

  /// Resolves the actual [Future] that will define this node content.
  Future get resolveFuture {
    if (_resolvedFuture != null) return _resolvedFuture;

    if (future != null) {
      _resolvedFuture = future;
    } else if (function != null) {
      _resolvedFuture = function();
    }

    if (_resolvedFuture == null) {
      throw StateError("Can't resolve Future!");
    }

    return _resolvedFuture;
  }

  @override
  DOMAsync copy() {
    return DOMAsync(loading: loading, future: future, function: function);
  }
}

/// Interface for objects that can be cast as [DOMNode].
abstract class AsDOMNode {
  DOMNode get asDOMNode;
}

/// Interface for objects that can be cast as [DOMElement].
abstract class AsDOMElement {
  DOMElement get asDOMElement;
}
