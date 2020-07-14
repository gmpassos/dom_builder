import 'dart:collection';
import 'dart:math';

import 'package:html/dom.dart' as html_dom;
import 'package:html/parser.dart' as html_parse;
import 'package:swiss_knife/swiss_knife.dart';

import 'dom_builder_attribute.dart';
import 'dom_builder_generator.dart';
import 'dom_builder_treemap.dart';
import 'dom_builder_runtime.dart';

final RegExp STRING_LIST_DELIMITER = RegExp(r'[,;\s]+');

final RegExp CSS_LIST_DELIMITER = RegExp(r'\s*;\s*');

/// Parses [s] as a flat [List<String>].
///
/// [s] If is a [String] uses [delimiter] to split strings. If [s] is a [List] iterator over it and flatten sub lists.
/// [delimiter] Pattern to split [s] to list.
/// [trim] If [true] trims all strings.
List<String> parseListOfStrings(dynamic s,
    [Pattern delimiter, bool trim = true]) {
  if (s == null) return null;

  List<String> list;

  if (s is List) {
    list = s.map(parseString).toList();
  } else {
    var str = parseString(s);
    if (trim) str = str.trim();
    list = str.split(delimiter);
  }

  if (trim) {
    list = list
        .where((e) => e != null)
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList();
  }

  return list;
}

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
        return (n) => n is DOMElement && n.containsClass(str.substring(1));
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
class DOMNode {
  /// Parses [entry] to a list of nodes.
  static List<DOMNode> parseNodes(entry) {
    if (entry == null) return null;

    if (entry is DOMNode) {
      return [entry];
    } else if (entry is html_dom.Node) {
      return [DOMNode.from(entry)];
    } else if (entry is List) {
      entry.removeWhere((e) => e == null);
      if (entry.isEmpty) return [] ;
      var list = entry.expand(parseNodes).toList();
      list.removeWhere((e) => e == null);
      return list;
    } else if (entry is String) {
      if (isHTMLElement(entry)) {
        return parseHTML(entry);
      } else if (hasHTMLEntity(entry) || hasHTMLTag(entry)) {
        return parseHTML('<span>$entry</span>');
      } else {
        return [TextNode(entry)];
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
    } else if (entry is DOMElementGenerator) {
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
      if (entry.isEmpty) return null ;
      var list = entry.expand(parseNodes).toList();
      list.removeWhere((e) => e == null);
      if (list.isEmpty) return null ;
      if (list.length == 1) return list.single ;
      return list;
    } else if (entry is String) {
      if (isHTMLElement(entry)) {
        return parseHTML(entry);
      } else if (hasHTMLEntity(entry) || hasHTMLTag(entry)) {
        return parseHTML('<span>$entry</span>');
      } else {
        return TextNode(entry);
      }
    } else if (entry is num || entry is bool) {
      return TextNode(entry.toString());
    } else if (entry is DOMElementGenerator) {
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
        return TextNode(entry);
      }
    } else if (entry is num || entry is bool) {
      return TextNode(entry.toString());
    } else if (entry is DOMElementGenerator) {
      return ExternalElementNode(entry);
    } else {
      return ExternalElementNode(entry);
    }
  }

  factory DOMNode._fromHtmlNode(html_dom.Node entry) {
    if (entry is html_dom.Text) {
      return TextNode(entry.text);
    } else if (entry is html_dom.Element) {
      return DOMNode._fromHtmlNodeElement(entry);
    }

    return null;
  }

  factory DOMNode._fromHtmlNodeElement(html_dom.Element entry) {
    var name = entry.localName;

    var attributes = entry.attributes.map((k, v) => MapEntry(k.toString(), v));

    var content = isNotEmptyObject(entry.nodes) ? List.from(entry.nodes) : null ;

    return DOMElement(name,
        attributes: attributes, content: content);
  }

  /// Parent of this node.
  DOMNode _parent;

  DOMTreeMap _treeMap;

  /// Returns the [DOMTreeMap] of the last generated tree of elements.
  DOMTreeMap get treeMap => _treeMap;
  set treeMap(DOMTreeMap value) => _treeMap = value;

  /// Returns a [DOMNodeRuntime] with the actual generated node
  /// associated with [treeMap] and [domGenerator].
  DOMNodeRuntime get runtime => _treeMap != null
      ? _treeMap.getRuntimeNode(this)
      : DOMNodeRuntimeDummy(null, this, null);

  /// Returns [true] if this node has a generated element by [domGenerator].
  bool get isGenerated => _treeMap != null;

  /// Returns the [DOMGenerator] associated with [treeMap].
  DOMGenerator get domGenerator =>
      _treeMap != null ? _treeMap.domGenerator : _treeMap;

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

  /// Returns the [parent] [DOMNode] of generated tree (by [DOMGenerator]).
  DOMNode get parent => _parent;
  set parent(DOMNode value) {
    _parent = value;
  }

  /// Returns [true] if this node has a parent.
  bool get hasParent => _parent != null ;

  /// If [true] this node is commented (ignored).
  bool get isCommented => _commented;

  set commented(bool value) {
    _commented = value ?? false;
  }

  /// Generates a HTML from this node tree.
  ///
  /// [withIdent] If [true] will generate a indented HTML.
  String buildHTML(
      {bool withIdent = false, String parentIdent = '', String ident = '  ', bool disableIdent = false, DOMNode previousNode}) {
    if (isCommented) return '';

    var html = '' ;

    if (isNotEmptyObject(_content)) {
      for (var node in _content) {
        var subHtml = node.buildHTML(
            withIdent: withIdent,
            parentIdent: parentIdent + ident,
            ident: ident,
            disableIdent: disableIdent);
        if (subHtml != null) {
          html += subHtml ;
        }
      }
    }

    return html ;
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
  T buildDOM<T>([DOMGenerator<T> generator]) {
    if (isCommented) return null;

    generator ??= defaultDomGenerator;
    return generator.generate(this);
  }

  /// Returns the content of this node as text.
  String get text {
    if ( isEmpty ) return '' ;
    return _content.map((e) => e.text).join('') ;
  }

  List<DOMNode> _content;

  /// Actual list of nodes that represents the content of this node.
  List<DOMNode> get content => _content;

  int indexOfNodeIdenticalFirst( DOMNode node ) {
    var idx = indexOfNodeIdentical(node) ;
    return idx >= 0 ? idx : indexOfNode(node) ;
  }

  int indexOfNodeIdentical( DOMNode node ) {
    if ( isEmpty ) return -1;
    for (var i = 0; i < _content.length ; i++) {
      var child = _content[i] ;
      if ( identical(node, child) ) return i ;
    }
    return -1 ;
  }

  int indexOfNodeWhere( bool Function(DOMNode node) test ) {
    if ( isEmpty ) return -1;

    for (var i = 0; i < _content.length ; i++) {
      var child = _content[i] ;
      if ( test(child) ) return i ;
    }

    return -1 ;
  }

  int _contentFromIndexBackwardWhere(int idx, int steps, bool Function(DOMNode node) test ) {
    for (var i = Math.min(idx, _content.length-1) ; i >= 0 ; i--) {
      var node = _content[i] ;
      if ( test(node) ) {
        if (steps <= 0) {
          return i ;
        }
        else {
          --steps;
        }
      }
    }
    return -1 ;
  }

  int _contentFromIndexForwardWhere(int idx, int steps, bool Function(DOMNode node) test ) {
    for (var i = idx ; i < _content.length ; i++) {
      var node = _content[i] ;
      if ( test(node) ) {
        if (steps <= 0) {
          return i ;
        }
        else {
          --steps;
        }
      }
    }
    return -1 ;
  }

  /// Moves this node up in the parent children list.
  bool moveUp() {
    var parent = this.parent ;
    if (parent == null) return false ;
    return parent.moveUpNode(this) ;
  }

  /// Moves [node] up in the children list.
  bool moveUpNode(DOMNode node) {
    if (node == null || isEmpty) return false ;

    var idx = indexOfNodeIdenticalFirst(node) ;
    if (idx < 0) return false ;
    if (idx == 0) return true ;

    _content.removeAt(idx) ;

    var idxUp = _contentFromIndexBackwardWhere(idx-1, 0, (node) => node is DOMElement) ;
    if (idxUp < 0) {
      idxUp = 0 ;
    }

    _content.insert(idxUp, node) ;
    node._parent = this ;
    return true ;
  }

  /// Moves this node down in the parent children list.
  bool moveDown() {
    var parent = this.parent ;
    if (parent == null) return false ;
    return parent.moveDownNode(this) ;
  }

  /// Moves [node] down in the children list.
  bool moveDownNode(DOMNode node) {
    if (node == null || isEmpty) return false ;

    var idx = indexOfNodeIdenticalFirst(node) ;
    if (idx < 0) return false ;
    if (idx >= _content.length-1) return true ;

    _content.removeAt(idx) ;

    var idxDown = _contentFromIndexForwardWhere(idx, 1, (node) => node is DOMElement) ;
    if (idxDown < 0) {
      idxDown = _content.length ;
    }

    _content.insert(idxDown, node) ;
    node._parent = this ;
    return true ;
  }

  /// Duplicate this node and add it to the parent.
  DOMNode duplicate() {
    var parent = this.parent ;
    if (parent == null) return null ;
    return parent.duplicateNode(this) ;
  }

  /// Duplicate [node] and add it to the children list.
  DOMNode duplicateNode(DOMNode node) {
    if (node == null || isEmpty) return null ;

    var idx = indexOfNodeIdenticalFirst(node) ;
    if (idx < 0) return null ;

    var elem = _content[idx] ;
    var copy = elem.copy() ;
    _content.insert(idx+1, copy) ;

    copy.parent = this ;

    return copy ;
  }

  /// Clear the children list.
  void clearNodes() {
    if ( isEmpty ) return ;

    for (var node in _content) {
      node._parent = null ;
    }

    _content.clear() ;
  }

  /// Removes this node from parent.
  bool remove() {
    var parent = this.parent ;
    if (parent == null) return false ;
    return parent.removeNode(this) ;
  }

  /// Removes [node] from children list.
  bool removeNode(DOMNode node) {
    if (node == null || isEmpty) return false ;

    var idx = indexOfNodeIdenticalFirst(node) ;
    if (idx < 0) {
      return false ;
    }

    var removed = _content.removeAt(idx) ;

    if (removed != null) {
      removed._parent = null ;
      return true;
    }
    else {
      return false ;
    }
  }

  /// Returns the index position of this node in the parent.
  int get indexInParent {
    if (parent == null) return -1 ;
    return parent.indexOfNode(this) ;
  }

  /// Returns [true] if [other] is in the same [parent] of this node.
  bool isInSameParent(DOMNode other) {
    if ( other == null ) return false ;
    var parent = this.parent ;
    return parent != null && parent == other.parent ;
  }

  /// Returns [true] if [other] is the previous sibling of this node [parent].
  bool isPreviousNode(DOMNode other) {
    if ( !isInSameParent(other) || identical(this, other)) return false ;
    var otherIdx = other.indexInParent;
    return otherIdx >= 0 && otherIdx+1 == indexInParent ;
  }

  /// Returns [true] if [other] is the next sibling of this node [parent].
  bool isNextNode(DOMNode other) {
    if ( !isInSameParent(other) || identical(this, other)) return false ;
    var idx = indexInParent ;
    return idx >= 0 && idx+1 == other.indexInParent ;
  }

  /// Returns [true] if [other] is the previous or next
  /// sibling of this node [parent].
  bool isConsecutiveNode(DOMNode other) {
    return isNextNode(other) || isPreviousNode(other) ;
  }

  /// Absorb the content of [other] and appends to this node.
  bool absorbNode(DOMNode other) => false ;

  /// Merges [other] node into this node.
  bool merge( DOMNode other, {bool onlyConsecutive = true} ) => false ;

  static DOMNode mergeNearNodes( DOMNode node1 , DOMNode node2 ) {
    if ( node1.isConsecutiveNode(node2) ) {
      if ( node1.merge(node2) ) {
        return node1 ;
      }
    }
    else if ( node1.isPreviousNode(node2) ) {
      if ( node2.merge(node1) ) {
        return node2 ;
      }
    }
    return null ;
  }

  /// Returns [true] if this element is a [TextNode] or a [DOMElement] of
  /// tag: sup, i, em, u, b, strong.
  bool get isStringElement => false ;

  static final RegExp REGEXP_WHITE_SPACE = RegExp(r'^(?:\s+)$' , multiLine: false);

  /// Returns [true] if this node only have white space content.
  bool get isWhiteSpaceContent => false ;

  /// Returns a copy [List] of children nodes.
  List<DOMNode> get nodes => isNotEmpty ? List.from(_content).cast() : [];

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
      _content = [entry];;
    } else {
      _content.add(entry);
    }

    entry.parent = this ;
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
    if ( isEmpty ) return ;
    _content.forEach((e) => e.parent = this) ;
  }

  void _insertNodeToContent(int index, DOMNode entry) {
    if (entry == null) return;

    _checkAllowContent();

    if (_content == null) {
      _content = [entry];
      entry.parent = this ;
    } else {
      if (index > _content.length) index = _content.length;
      if (index == _content.length) {
        _addNodeToContent(entry);
      } else {
        _content.insert(index, entry);
        entry.parent = this ;
      }
    }
  }

  void _checkAllowContent() {
    if (!allowContent) {
      throw UnsupportedError("$runtimeType: can't insert entry to content!");
    }
  }

  void normalizeContent() {

  }

  /// Checks children nodes integrity.
  void checkNodes() {
    if (isEmpty) return ;

    for (var child in _content) {
      if (child.parent == null) {
        throw StateError('parent null') ;
      }

      if ( child is DOMElement ) {
        child.checkNodes() ;
      }
    }
  }

  /// Sets the content of this node.
  DOMNode setContent(newContent) {
    var nodes = DOMNode.parseNodes(newContent);
    if ( nodes != null && nodes.isNotEmpty ) {
      _content = nodes;
      _setChildrenParent();
      normalizeContent();
    }
    else {
      _content = null ;
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


  T selectByID<T extends DOMNode>(String id) {
    if (id == null || isEmpty) return null;
    if (id.startsWith('#')) id = id.substring(1);
    return selectWhere((n) => n is DOMElement && n.id == id);
  }

  T nodeEquals<T extends DOMNode>(DOMNode node) {
    if (node == null || isEmpty) return null;
    return nodeWhere((n) => n == node);
  }

  T selectEquals<T extends DOMNode>(DOMNode node) {
    if (node == null || isEmpty) return null;
    return selectWhere((n) => n == node);
  }

  T nodeWhere<T extends DOMNode>(dynamic selector) {
    if (selector == null || isEmpty) return null;
    var nodeSelector = asNodeSelector(selector);

    return _content.firstWhere(nodeSelector, orElse: () => null);
  }

  List<T> nodesWhere<T extends DOMNode>(dynamic selector) {
    if (selector == null || isEmpty) return [];
    var nodeSelector = asNodeSelector(selector);

    return _content.where(nodeSelector).toList();
  }

  void catchNodesWhere<T extends DOMNode>(dynamic selector, List<T> destiny) {
    if (selector == null || isEmpty) return;
    var nodeSelector = asNodeSelector(selector);
    destiny.addAll(_content.where(nodeSelector).whereType<T>());
  }

  T selectWhere<T extends DOMNode>(dynamic selector) {
    if (selector == null || isEmpty) return null;
    var nodeSelector = asNodeSelector(selector);

    var found = nodeWhere(nodeSelector);
    if (found != null) return found;

    for (var n in _content.whereType<DOMNode>()) {
      found = n.selectWhere(selector);
      if (found != null) return found;
    }

    return null;
  }

  List<T> selectAllWhere<T extends DOMNode>(dynamic selector) {
    if (selector == null || isEmpty) return [];
    var nodeSelector = asNodeSelector(selector);

    var all = <T>[];
    _selectAllWhereImpl(nodeSelector, all);
    return all;
  }

  void _selectAllWhereImpl<T extends DOMNode>(
      NodeSelector selector, List<T> all) {
    if (isEmpty) return;

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
      var nodeSelector = asNodeSelector(selector);
      return nodeWhere(nodeSelector);
    }
  }

  T select<T extends DOMNode>(dynamic selector) {
    if (selector == null || isEmpty) return null;

    if (selector is num) {
      return nodeByIndex(selector);
    } else {
      var nodeSelector = asNodeSelector(selector);
      return selectWhere(nodeSelector);
    }
  }

  int indexOf(dynamic selector) {
    if (selector is num) {
      if ( selector < 0 ) return -1 ;
      if ( isEmpty ) return 0 ;
      if ( selector >= _content.length ) return _content.length ;
      return selector;
    }

    if (selector == null || isEmpty) return -1;

    var nodeSelector = asNodeSelector(selector);
    return _content.indexWhere(nodeSelector);
  }

  /// Returns the index of [node].
  int indexOfNode(DOMNode node) {
    if ( isEmpty ) return -1;
    return _content.indexOf(node);
  }

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
      entries.forEach(_addImpl) ;
      normalizeContent();
    }
    return this;
  }

  void _addImpl(entry) {
    var node = _parseNode(entry);
    _addToContent(node);
  }

  DOMNode insertAt(dynamic indexSelector, dynamic entry) {
    var idx = indexOf(indexSelector);

    if (idx >= 0) {
      var node = _parseNode(entry);
      _insertToContent(idx, node);
      normalizeContent();
    }
    else if ( indexSelector is num && isEmpty ) {
      var node = _parseNode(entry);
      add(node) ;
      normalizeContent();
    }

    return this;
  }

  DOMNode insertAfter(dynamic indexSelector, dynamic entry) {
    var idx = indexOf(indexSelector);

    if (idx >= 0) {
      idx++;

      var node = _parseNode(entry);
      _insertToContent(idx, node);

      normalizeContent();
    }
    else if ( indexSelector is num && isEmpty ) {
      var node = _parseNode(entry);
      add(node) ;
      normalizeContent();
    }

    return this;
  }

  /// Copies this node.
  DOMNode copy() {
    return DOMNode( content: copyContent() ) ;
  }

  /// Copies this node content.
  List<DOMNode> copyContent() {
    if (_content == null) return null ;
    if (_content.isEmpty) return [] ;
    var content2 = _content.map((e) => e.copy()).toList() ;
    return content2 ;
  }

}

/// Represents a text node in DOM.
class TextNode extends DOMNode implements WithValue {
  String _text ;

  TextNode(String text) :
    _text = text ?? '' ,
    super._(false, false)
  ;

  @override
  String get text => _text ;
  set text(String value) {
    _text = value ?? '' ;
  }

  bool get isTextEmpty => text.isEmpty ;

  @override
  bool get hasValue => isNotEmptyObject(_text);

  @override
  bool absorbNode(DOMNode other) {
    if ( other is TextNode ) {
      _text += other.text ;
      other.text = '';
      return true ;
    }
    else if ( other is DOMElement ) {
      _text += other.text ;
      other.clearNodes();
      return true ;
    }
    else {
      return false;
    }
  }

  @override
  bool merge(DOMNode other, {bool onlyConsecutive = true}) {
    onlyConsecutive ??= true ;

    if (onlyConsecutive) {
      if ( isPreviousNode(other) ) {
        return other.merge(this, onlyConsecutive: false) ;
      }
      else if ( !isNextNode(other) ) {
        return false ;
      }
    }

    if (other is TextNode) {
      other.remove() ;
      absorbNode(other) ;
      return true ;
    }
    else if (other is DOMElement && other.isStringElement && ( other.isEmpty || other.hasOnlyTextNodes ) ) {
      other.remove() ;
      absorbNode(other) ;
      return true ;
    }
    else {
      return false ;
    }
  }

  @override
  bool get isStringElement => true ;

  @override
  bool get hasOnlyTextNodes => true ;

  @override
  bool get hasOnlyElementNodes => false ;

  @override
  bool get isWhiteSpaceContent => DOMNode.REGEXP_WHITE_SPACE.hasMatch(text);

  @override
  String buildHTML(
      {bool withIdent = false, String parentIdent = '', String ident = '  ', bool disableIdent = false, DOMNode previousNode}) {
    return _text;
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
    return TextNode(_text) ;
  }

  @override
  List<DOMNode> copyContent() {
    return null ;
  }

  @override
  String toString() {
    return _text ?? '' ;
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

class DOMElement extends DOMNode {
  static final Set<String> _NO_CONTENT_TAG = {'p', 'hr', 'br', 'input'};

  /// Normalizes a tag name. Returns null for empty string.
  static String normalizeTag(String tag) {
    if (tag == null) return null ;
    tag = tag.toLowerCase().trim() ;
    return tag.isNotEmpty ? tag : null ;
  }

  final String tag;

  factory DOMElement(String tag,
      {Map<String, dynamic> attributes,
      id,
      classes,
      style,
      content,
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
          commented: commented);
    } else if (tag == 'input') {
      return INPUTElement(
          attributes: attributes,
          id: id,
          classes: classes,
          style: style,
          value: content,
          commented: commented);
    } else if (tag == 'textarea') {
      return TEXTAREAElement(
          attributes: attributes,
          id: id,
          classes: classes,
          style: style,
          content: content,
          commented: commented);
    } else if (tag == 'table') {
      return TABLEElement(
          attributes: attributes,
          id: id,
          classes: classes,
          style: style,
          content: content,
          commented: commented);
    } else if (tag == 'thead') {
      return THEADElement(
          attributes: attributes,
          id: id,
          classes: classes,
          style: style,
          rows: content,
          commented: commented);
    } else if (tag == 'tbody') {
      return TBODYElement(
          attributes: attributes,
          id: id,
          classes: classes,
          style: style,
          rows: content,
          commented: commented);
    } else if (tag == 'tfoot') {
      return TFOOTElement(
          attributes: attributes,
          id: id,
          classes: classes,
          style: style,
          rows: content,
          commented: commented);
    } else if (tag == 'tr') {
      return TRowElement(
          attributes: attributes,
          id: id,
          classes: classes,
          style: style,
          cells: content,
          commented: commented);
    } else if (tag == 'td') {
      return TDElement(
          attributes: attributes,
          id: id,
          classes: classes,
          style: style,
          content: content,
          commented: commented);
    } else if (tag == 'th') {
      return THElement(
          attributes: attributes,
          id: id,
          classes: classes,
          style: style,
          content: content,
          commented: commented);
    } else {
      return DOMElement._(tag,
          attributes: attributes,
          id: id,
          classes: classes,
          style: style,
          content: content);
    }
  }

  DOMElement._(String tag,
      {Map<String, dynamic> attributes,
      id,
      classes,
      style,
      content,
      bool commented})
      : tag = normalizeTag(tag),
        super._(true, commented) {

    if (tag == null) throw ArgumentError.notNull('tag') ;

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

    if (content != null) {
      setContent(content);
    }
  }

  /// Returns [true] if [tag] is one of [tags].
  bool isTagOneOf(Iterable<String> tags) {
    if (tag == null || tag.isEmpty) return false ;

    for (var t in tags) {
      t = normalizeTag(t) ;
      if ( tag == t ) return true ;
    }

    return false ;
  }

  /// Returns the attribute `id`.
  String get id => getAttributeValue('id');

  /// Returns the attribute `class`.
  String get classes => getAttributeValue('class');

  /// Returns the list of class names of the attribute `class`.
  List<String> get classesList {
    var attribute = getAttribute('class');
    if ( attribute == null ) return [] ;
    return attribute.values ?? [] ;
  }

  /// Adds a [className] to attribute `class`.
  void addClass(String className) {
    appendToAttribute('class', className) ;
  }

  /// Returns the attribute `style`.
  String get style => getAttributeValue('style');

  /// Returns [true] if attribute `class` has the [className].
  bool containsClass(String className) {
    var attribute = getAttribute('class');
    if (attribute == null) return false;
    return attribute.containsValue(className);
  }

  LinkedHashMap<String, DOMAttribute> _attributes;

  Map<String,DOMAttribute> get domAttributes => _attributes != null ? Map.from( _attributes ) : {} ;

  Map<String,dynamic> get attributes => hasEmptyAttributes ? {} : _attributes.map((key, value) => MapEntry(key, value.isListValue ? value.values : value.value)) ;

  /// Returns the attributes names with values.
  Iterable<String> get attributesNames =>
      hasAttributes ? _attributes.keys : [];

  /// Returns the size of attributes Map.
  int get attributesLength =>
      _attributes != null ? _attributes.length : 0;

  /// Returns [true] if this element has NO attributes.
  bool get hasEmptyAttributes =>
      _attributes != null ? _attributes.isEmpty : true ;

  /// Returns [true] if this element has attributes.
  bool get hasAttributes => !hasEmptyAttributes ;

  String operator [](String name) => getAttributeValue(name);

  void operator []=(String name, dynamic value) => setAttribute(name, value);

  String get value {
    return text ;
  }

  String getAttributeValue(String name) {
    var attr = getAttribute(name);
    return attr != null ? attr.value : null;
  }

  DOMAttribute getAttribute(String name) {
    if ( hasEmptyAttributes ) return null;
    return _attributes[name];
  }

  DOMElement setAttribute(String name, dynamic value) {
    if (name == null) return null;

    name = name.toLowerCase().trim();

    var attribute = DOMAttribute.from(name, value);

    if (attribute != null) {
      putDOMAttribute(attribute);
    }

    return this;
  }

  DOMElement appendToAttribute(String name, dynamic value) {
    // ignore: prefer_collection_literals
    _attributes ??= LinkedHashMap();

    var attr = getAttribute(name);

    if (attr == null) {
      return setAttribute(name, value);
    }

    if (attr.isListValue) {
      attr.appendValue(value);
    } else {
      attr.setValue(value);
    }

    return this;
  }

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
    if (attributeName == null) return false ;
    attributeName = attributeName.toLowerCase().trim() ;
    if (attributeName.isEmpty) return false ;

    return _removeAttributeImp(attributeName);
  }

  bool _removeAttributeImp(String attributeName) {
    if ( hasEmptyAttributes ) return false ;
    var attribute = _attributes.remove( attributeName );
    return attribute != null ;
  }

  bool removeAttributeDeeply(String attributeName) {
    if (attributeName == null) return false ;
    attributeName = attributeName.toLowerCase().trim() ;
    if (attributeName.isEmpty) return false ;

    return _removeAttributeDeeplyImp(attributeName);
  }

  bool _removeAttributeDeeplyImp(String attributeName) {
    var removedAny = _removeAttributeImp(attributeName) ;

    for (var subNode in nodes) {
      if (subNode is DOMElement) {
        var removed = subNode._removeAttributeDeeplyImp(attributeName);
        if (removed) removedAny = true ;
      }
    }

    return removedAny ;
  }

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

  T applyWhere<T extends DOMElement>(dynamic selector, {id, classes, style}) {
    var nodeSelector = asNodeSelector(selector);

    var all = selectAllWhere(nodeSelector);

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
    if ( other == null ) return false ;

    if ( other is DOMElement ) {
      addAll( other._content ) ;
      other.clearNodes() ;
      return true ;
    }
    else if ( other is TextNode ) {
      other.remove() ;
      add( other ) ;
      return true ;
    }
    else {
      return false ;
    }
  }

  @override
  bool merge(DOMNode other, {bool onlyConsecutive = true}) {
    onlyConsecutive ??= true ;

    if (onlyConsecutive) {
      if ( isPreviousNode(other) ) {
        return other.merge(this, onlyConsecutive: false) ;
      }
      else if ( !isNextNode(other) ) {
        return false ;
      }
    }

    if (other is DOMElement) {
      if ( tag != other.tag ) return false ;



      other.remove() ;
      absorbNode(other) ;
      return true ;
    }
    else if (other is TextNode) {
      other.remove() ;
      absorbNode(other) ;
      return true ;
    }
    else {
      return false ;
    }
  }

  @override
  bool get isStringElement {
    return isStringTagName(tag) ;
  }

  static bool isStringTagName(String tag) {
    tag = normalizeTag(tag) ;
    if (tag == null || tag.isEmpty) return false ;
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
    if ( hasOnlyTextNodes ) {
      return DOMNode.REGEXP_WHITE_SPACE.hasMatch(text);
    }
    return false ;
  }

  String buildOpenTagHTML() {
    var html = '<$tag';

    if (hasAttributes) {
      var attributesWithValue =
          _attributes.values.where((v) => v != null && v.hasValue);
      for (var attr in attributesWithValue) {
        html += ' ' + attr.buildHTML();
      }
    }

    html += '>';

    return html;
  }

  String buildCloseTagHTML() {
    return '</$tag>';
  }

  static bool _tagAllowsInnerIdent(String tag) {
    if ( _isStringTagName(tag) ) return false ;

    switch (tag) {
      case 'style':
      case 'script':
      case 'pre': return false ;
      default: return true ;
    }
  }

  @override
  String buildHTML(
      {bool withIdent = false, String parentIdent = '', String ident = '  ', bool disableIdent = false, DOMNode previousNode}) {

    disableIdent ??= false ;
    if ( !disableIdent && !_tagAllowsInnerIdent(tag) ) {
      disableIdent = true ;
    }

    var allowIdent = withIdent && isNotEmpty && hasOnlyElementNodes && !disableIdent ;

    var innerIdent = allowIdent ? parentIdent + ident : '';
    var innerBreakLine = allowIdent ? '\n' : '';

    if ( parentIdent.isNotEmpty && previousNode != null && previousNode.isStringElement ) {
      parentIdent = '' ;
    }

    if (_NO_CONTENT_TAG.contains(tag)) {
      var html = parentIdent + buildOpenTagHTML();
      return html;
    }

    var html = parentIdent + buildOpenTagHTML() + innerBreakLine;

    if (isNotEmptyObject(_content)) {
      DOMNode prev ;
      for (var node in _content) {
        var subElement = node.buildHTML(
            withIdent: withIdent, parentIdent: innerIdent, ident: ident, disableIdent: disableIdent, previousNode: prev);
        if (subElement != null) {
          html += subElement + innerBreakLine;
        }
        prev = node ;
      }
    }

    html += (allowIdent ? parentIdent : '') + buildCloseTagHTML();

    return html;
  }

  /// Returns true if [other] is fully equals.
  bool equals(Object other) =>
      identical(this, other) ||
      other is DOMElement &&
          runtimeType == other.runtimeType &&
          tag == other.tag &&
          equalsAttributes(other) &&
          ( (isEmpty && other.isEmpty) || isEqualsDeep(_content, other._content) ) ;

  /// Returns true if [other] have the same attributes.
  bool equalsAttributes(DOMElement other) => ( (hasEmptyAttributes && other.hasEmptyAttributes) || isEqualsDeep(_attributes, other._attributes) );

  static int objectHashcode(dynamic o) {
    if ( isEmptyObject(o) ) return 0 ;
    return deepHashCode(o) ;
  }

  @override
  String toString() {
    var attributesStr = hasAttributes ? ', attributes: $_attributes' : '' ;
    var contentStr = isNotEmpty ? ', content: ${ _content.length }' : '' ;

    return 'DOMElement{tag: $tag$attributesStr$contentStr}';
  }

  @override
  DOMElement copy() {
    return DOMElement(tag , attributes: attributes, commented: isCommented, content: copyContent() ) ;
  }

  EventStream<DOMMouseEvent> _onClick ;
  EventStream<DOMMouseEvent> get onClick {
    _onClick ??= EventStream();
    return _onClick;
  }

}

//
// Events:
//

class DOMEvent {

}

class DOMMouseEvent<T> extends DOMEvent {
  final DOMTreeMap<T> treeMap;

  DOMGenerator<T> get domGenerator => treeMap.domGenerator;

  final dynamic event;
  final dynamic eventTarget;

  final DOMNode target;

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
      this.treeMap,
      this.event,
      this.eventTarget,
      this.target,
      this.client,
      this.offset,
      this.page,
      this.screen,
      this.button,
      this.buttons,
      this.altKey,
      this.ctrlKey,
      this.shiftKey,
      this.metaKey);

  bool cancel({bool stopImmediatePropagation = false}) =>
      domGenerator.cancelEvent(event,
          stopImmediatePropagation: stopImmediatePropagation ?? false);
}

//
// ExternalElementNode:
//

class ExternalElementNode extends DOMNode {
  final dynamic externalElement;

  ExternalElementNode(this.externalElement, [bool allowContent])
      : super._(allowContent, false);

  @override
  String buildHTML(
      {bool withIdent = false, String parentIdent = '', String ident = '  ', bool disableIdent = false, DOMNode previousNode}) {
    if (externalElement == null) return null;

    if (externalElement is String) {
      return externalElement;
    } else {
      return '$externalElement';
    }
  }

  @override
  ExternalElementNode copy() {
    return ExternalElementNode( externalElement , allowContent ) ;
  }

}

//
// DIVElement:
//

class DIVElement extends DOMElement {
  factory DIVElement.from(dynamic entry) {
    if (entry == null) return null;
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
      bool commented})
      : super._('div',
            attributes: attributes,
            id: id,
            classes: classes,
            style: style,
            content: content,
            commented: commented);

  @override
  DIVElement copy() {
    return DIVElement( attributes: attributes, commented: isCommented, content: copyContent() ) ;
  }

}

//
// INPUTElement:
//

class INPUTElement extends DOMElement implements WithValue {
  factory INPUTElement.from(dynamic entry) {
    if (entry == null) return null;
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
        classes,
        style,
        value,
        bool commented})
      : super._('input',
      id: id,
      classes: classes,
      style: style,
      attributes: {
        if (name != null) 'name': name,
        if (type != null) 'type': type,
        if (value != null) 'value': value,
        ...?attributes
      },
      commented: commented);

  @override
  INPUTElement copy() {
    return INPUTElement( attributes: attributes, commented: isCommented ) ;
  }

  @override
  bool get hasValue => isNotEmptyObject(value);

  @override
  String get value => getAttributeValue('value') ;

}

//
// TEXTAREAElement:
//

class TEXTAREAElement extends DOMElement implements WithValue {
  factory TEXTAREAElement.from(dynamic entry) {
    if (entry == null) return null;
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
      commented: commented);

  @override
  TEXTAREAElement copy() {
    return TEXTAREAElement( attributes: attributes, content: content, commented: isCommented ) ;
  }

  @override
  bool get hasValue => isNotEmptyObject(value);

  @override
  String get value => getAttributeValue('value') ;

}

//
// TABLEElement:
//

List createTableContent(content, head, body, foot, {bool header, bool footer}) {
  if (content == null) {
    return [
      createTableEntry(head, header: true),
      createTableEntry(body),
      createTableEntry(foot, footer: true)
    ];
  } else if (content is List) {
    if (listMatchesAll(content, (e) => e is html_dom.Node)) {
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
    tr.addEachAsTag('th', iterable);
  } else {
    tr.addEachAsTag('td', iterable);
  }

  return tr;
}

List<TABLENode> createTableCells(dynamic rowCells, [bool header]) {
  header ??= false;

  if (rowCells is List && listMatchesAll(rowCells, (e) => ( !header && e is TDElement ) || ( header && e is THElement ) )) {
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
      bool commented})
      : super._(tag,
            attributes: attributes,
            id: id,
            classes: classes,
            style: style,
            content: content,
            commented: commented);

  @override
  TABLENode copy() {
    return super.copy();
  }
}

class TABLEElement extends DOMElement {
  factory TABLEElement.from(dynamic entry) {
    if (entry == null) return null;
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
      head,
      body,
      foot,
      content,
      bool commented})
      : super._('table',
            attributes: attributes,
            id: id,
            classes: classes,
            style: style,
            content: createTableContent(content, head, body, foot),
            commented: commented);

  @override
  TABLEElement copy() {
    return TABLEElement( attributes: attributes, commented: isCommented, content: copyContent() ) ;
  }
}

class THEADElement extends TABLENode {
  factory THEADElement.from(dynamic entry) {
    if (entry == null) return null;
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
      bool commented})
      : super._('thead',
            attributes: attributes,
            id: id,
            classes: classes,
            style: style,
            content: createTableRows(rows, true),
            commented: commented);

  @override
  THEADElement copy() {
    return THEADElement( attributes: attributes, commented: isCommented, rows: copyContent() ) ;
  }
}

class TBODYElement extends TABLENode {
  factory TBODYElement.from(dynamic entry) {
    if (entry == null) return null;
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
      bool commented})
      : super._('tbody',
            attributes: attributes,
            id: id,
            classes: classes,
            style: style,
            content: createTableRows(rows, false),
            commented: commented);

  @override
  TBODYElement copy() {
    return TBODYElement( attributes: attributes, commented: isCommented, rows: copyContent() ) ;
  }
}

class TFOOTElement extends TABLENode {
  factory TFOOTElement.from(dynamic entry) {
    if (entry == null) return null;
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
      bool commented})
      : super._('tfoot',
            attributes: attributes,
            id: id,
            classes: classes,
            style: style,
            content: createTableRows(rows, false),
            commented: commented);

  @override
  TFOOTElement copy() {
    return TFOOTElement( attributes: attributes, commented: isCommented, rows: copyContent() ) ;
  }
}

class TRowElement extends TABLENode {
  factory TRowElement.from(dynamic entry) {
    if (entry == null) return null;
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
      bool commented})
      : super._('tr',
            attributes: attributes,
            id: id,
            classes: classes,
            style: style,
            content: createTableCells(cells, headerRow),
            commented: commented);

  bool get isHeaderRow => parent != null ? parent is THEADElement : false ;
  bool get isFooterRow => parent != null ? parent is TFOOTElement : false ;

  @override
  TRowElement copy() {
    return TRowElement( attributes: attributes, commented: isCommented, cells: copyContent() , headerRow: isHeaderRow ) ;
  }
}

class THElement extends TABLENode {
  factory THElement.from(dynamic entry) {
    if (entry == null) return null;
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
      bool commented})
      : super._('th',
            attributes: attributes,
            id: id,
            classes: classes,
            style: style,
            content: content,
            commented: commented);

  @override
  THElement copy() {
    return THElement( attributes: attributes, commented: isCommented, content: copyContent() ) ;
  }
}

class TDElement extends TABLENode {
  factory TDElement.from(dynamic entry) {
    if (entry == null) return null;
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
      bool commented})
      : super._('td',
            attributes: attributes,
            id: id,
            classes: classes,
            style: style,
            content: content,
            commented: commented);

  @override
  TDElement copy() {
    return TDElement( attributes: attributes, commented: isCommented, content: copyContent() ) ;
  }
}

final RegExp _REGEXP_DEPENDENT_TAG = RegExp(r'^\s*<(tbody|thread|tfoot|tr|td|th)\W' , multiLine: false) ;

/// Parses a [html] to nodes.
List<DOMNode> parseHTML(String html) {
  if (html == null) return null;

  var dependentTagMatch = _REGEXP_DEPENDENT_TAG.firstMatch(html) ;

  if ( dependentTagMatch != null ) {
    var dependentTagName = dependentTagMatch.group(1).toLowerCase() ;

    html_dom.DocumentFragment parsed ;
    if ( dependentTagName == 'td' || dependentTagName == 'th' ) {
      parsed = html_parse.parseFragment('<table><tbody><tr></tr>\n$html\n</tbody></table>', container: 'div');
    }
    else if ( dependentTagName == 'tbody' || dependentTagName == 'thead' || dependentTagName == 'tfoot' ) {
      parsed = html_parse.parseFragment('<table>\n$html\n</table>', container: 'div');
    }

    var node = parsed.querySelector(dependentTagName) ;
    return [DOMNode.from(node)];
  }

  var parsed = html_parse.parseFragment(html, container: 'div');

  if (parsed.nodes.isEmpty) {
    return null;
  } else if (parsed.nodes.length == 1) {
    var node = parsed.nodes[0];
    return [DOMNode.from(node)];
  } else {
    return parsed.nodes.map((e) => DOMNode.from(e)).toList();
  }
}

/// Returns a list of nodes from [html].
List<DOMNode> $html<T extends DOMNode>(dynamic html) {
  if (html == null) return null;
  if (html is String) {
    return parseHTML(html);
  }
  throw ArgumentError("Ca't parse type: ${html.runtimeType}");
}

bool _isTextTag( String tag ) {
  tag = DOMElement.normalizeTag(tag) ;
  if (tag == null || tag.isEmpty) return false ;

  switch (tag) {
    case 'br':
    case 'wbr':
    case 'p':
    case 'b':
    case 'strong':
    case 'i':
    case 'em':
    case 'u':
    case 'span': return true ;
    default: return false;
  }
}

DOMElement $htmlRoot(dynamic html, {String defaultRootTag, bool defaultTagDisplayInlineBlock}) {
  var nodes = $html(html);
  if (nodes == null || nodes.isEmpty) return null;

  if (nodes.length > 1) {
    nodes.removeWhere((e) => e is TextNode && e.text.trim().isEmpty);
    if (nodes.length == 1) {
      return nodes[0];
    } else {
      Map<String,String> attributes ;
      if (defaultRootTag == null) {
        var onlyText = listMatchesAll(nodes,
            (e) => e is TextNode || (e is DOMElement && _isTextTag(e.tag)));
        defaultRootTag = onlyText ? 'span' : 'div';
      }

      if ( !_isTextTag( defaultRootTag ) && (defaultTagDisplayInlineBlock ?? true) ) {
        attributes = {'style': 'display: inline-block'};
      }

      return $tag(defaultRootTag, content: nodes, attributes: attributes);
    }
  } else {
    var node = nodes.single;
    if (node is DOMElement) {
      return node;
    } else {
      return $span(content: node);
    }
  }
}

typedef DOMNodeValidator = bool Function();

final RegExp _PATTERN_HTML_ELEMENT_INIT = RegExp(r'\s*<\w+', multiLine: false);
final RegExp _PATTERN_HTML_ELEMENT_END = RegExp(r'>\s*$', multiLine: false);

bool isHTMLElement(String s) {
  if (s == null) return false;
  return s.startsWith(_PATTERN_HTML_ELEMENT_INIT) &&
      _PATTERN_HTML_ELEMENT_END.hasMatch(s);
}

final RegExp _PATTERN_HTML_ELEMENT = RegExp(r'<\w+.*?>');

bool hasHTMLTag(String s) {
  if (s == null) return false;
  return _PATTERN_HTML_ELEMENT.hasMatch(s) ;
}

final RegExp _PATTERN_HTML_ENTITY = RegExp(r'&(?:\w+|#\d+);');

bool hasHTMLEntity(String s) {
  if (s == null) return false;
  return _PATTERN_HTML_ENTITY.hasMatch(s) ;
}

DOMNode $node({content}) {
  return DOMNode(content: content);
}

bool _isValid(DOMNodeValidator validate) {
  if (validate != null) {
    try {
      var valid = validate();
      if (valid != null && !valid) {
        return false;
      }
    } catch (e, s) {
      print(e);
      print(s);
    }
  }

  return true;
}

/// Creates a node with [tag].
DOMElement $tag(String tag,
    {DOMNodeValidator validate,
    id,
    classes,
    style,
    Map<String, String> attributes,
    content,
    bool commented}) {
  if (!_isValid(validate)) {
    return null;
  }

  return DOMElement(tag,
      id: id,
      classes: classes,
      style: style,
      attributes: attributes,
      content: content,
      commented: commented);
}

/// Creates a tag node from [html].
T $tagHTML<T extends DOMElement>(dynamic html) =>
    $html<DOMElement>(html).whereType<T>().first;

/// Creates a list of nodes of same [tag].
List<DOMElement> $tags<T>(String tag, Iterable<T> iterable,
    [ContentGenerator<T> elementGenerator]) {
  if (iterable == null) return null;

  var elements = <DOMElement>[];

  if (elementGenerator != null) {
    for (var entry in iterable) {
      var elem = elementGenerator(entry);
      var tagElem = $tag(tag, content: elem);
      elements.add(tagElem);
    }
  } else {
    for (var entry in iterable) {
      var tagElem = $tag(tag, content: entry);
      elements.add(tagElem);
    }
  }

  return elements;
}

/// Creates a `table` node.
TABLEElement $table(
    {DOMNodeValidator validate,
    id,
    classes,
    style,
    Map<String, String> attributes,
    head,
    body,
    foot,
    bool commented}) {
  if (!_isValid(validate)) {
    return null;
  }

  return TABLEElement(
      id: id,
      classes: classes,
      style: style,
      attributes: attributes,
      head: head,
      body: body,
      foot: foot,
      commented: commented);
}

/// Creates a `thread` node.
THEADElement $thead(
    {DOMNodeValidator validate,
    id,
    classes,
    style,
    Map<String, String> attributes,
    rows,
    bool commented}) {
  if (!_isValid(validate)) {
    return null;
  }

  return THEADElement(
      id: id,
      classes: classes,
      style: style,
      attributes: attributes,
      rows: rows,
      commented: commented);
}

/// Creates a `tbody` node.
TBODYElement $tbody(
    {DOMNodeValidator validate,
    id,
    classes,
    style,
    Map<String, String> attributes,
    rows,
    bool commented}) {
  if (!_isValid(validate)) {
    return null;
  }

  return TBODYElement(
      id: id,
      classes: classes,
      style: style,
      attributes: attributes,
      rows: rows,
      commented: commented);
}

/// Creates a `tfoot` node.
TFOOTElement $tfoot(
    {DOMNodeValidator validate,
    id,
    classes,
    style,
    Map<String, String> attributes,
    rows,
    bool commented}) {
  if (!_isValid(validate)) {
    return null;
  }

  return TFOOTElement(
      id: id,
      classes: classes,
      style: style,
      attributes: attributes,
      rows: rows,
      commented: commented);
}

/// Creates a `tr` node.
TRowElement $tr(
    {DOMNodeValidator validate,
    id,
    classes,
    style,
    Map<String, String> attributes,
    cells,
    bool commented}) {
  if (!_isValid(validate)) {
    return null;
  }

  return TRowElement(
      id: id,
      classes: classes,
      style: style,
      attributes: attributes,
      cells: cells,
      commented: commented);
}

/// Creates a `td` node.
DOMElement $td(
        {DOMNodeValidator validate,
        id,
        classes,
        style,
        Map<String, String> attributes,
        content,
        bool commented}) =>
    $tag('td',
        validate: validate,
        id: id,
        classes: classes,
        style: style,
        attributes: attributes,
        content: content,
        commented: commented);

/// Creates a `th` node.
DOMElement $th(
        {DOMNodeValidator validate,
        id,
        classes,
        style,
        Map<String, String> attributes,
        content,
        bool commented}) =>
    $tag('td',
        validate: validate,
        id: id,
        classes: classes,
        style: style,
        attributes: attributes,
        content: content,
        commented: commented);

/// Creates a `div` node.
DIVElement $div(
        {DOMNodeValidator validate,
        id,
        classes,
        style,
        Map<String, String> attributes,
        content,
        bool commented}) =>
    $tag('div',
        validate: validate,
        id: id,
        classes: classes,
        style: style,
        attributes: attributes,
        content: content,
        commented: commented);

/// Creates a `div` node with `display: inline-block`.
DIVElement $divInline(
        {DOMNodeValidator validate,
        id,
        classes,
        style,
        Map<String, String> attributes,
        content,
        bool commented}) =>
    $tag('div',
        validate: validate,
        id: id,
        classes: classes,
        style: toFlatListOfStrings(['display: inline-block', style],
            delimiter: CSS_LIST_DELIMITER),
        attributes: attributes,
        content: content,
        commented: commented);

/// Creates a `div` node from HTML.
DIVElement $divHTML(dynamic html) => $tagHTML(html);

/// Creates a `span` node.
DOMElement $span(
        {DOMNodeValidator validate,
        id,
        classes,
        style,
        Map<String, String> attributes,
        content,
        bool commented}) =>
    $tag('span',
        validate: validate,
        id: id,
        classes: classes,
        style: style,
        attributes: attributes,
        content: content,
        commented: commented);

/// Creates a `button` node.
DOMElement $button(
        {DOMNodeValidator validate,
        id,
        classes,
        style,
        type,
        Map<String, String> attributes,
        content,
        bool commented}) =>
    $tag('button',
        validate: validate,
        id: id,
        classes: classes,
        style: style,
        attributes: {
          if (type != null) 'type': type,
          ...?attributes
        },
        content: content,
        commented: commented);

/// Creates a `label` node.
DOMElement $label(
        {DOMNodeValidator validate,
        id,
        forID,
        classes,
        style,
        Map<String, String> attributes,
        content,
        bool commented}) =>
    $tag('label',
        validate: validate,
        id: id,
        classes: classes,
        style: style,
        attributes: {
          if (forID != null) 'for': forID,
          ...?attributes
        },
        content: content,
        commented: commented);

/// Creates a `textarea` node.
TEXTAREAElement $textarea(
    {DOMNodeValidator validate,
      id,
      name,
      classes,
      style,
      cols,
      rows,
      Map<String, String> attributes,
      content,
      bool commented}) {
  if (!_isValid(validate)) {
    return null;
  }
  return TEXTAREAElement(
      id: id,
      name: name,
      classes: classes,
      style: style,
      cols: cols,
      rows: rows,
      attributes: attributes,
      content: content,
      commented: commented);
}

/// Creates an `input` node.
INPUTElement $input(
        {DOMNodeValidator validate,
        id,
        name,
        classes,
        style,
        type,
        Map<String, String> attributes,
        value,
        bool commented}) {
  if (!_isValid(validate)) {
    return null;
  }
  return INPUTElement(
        id: id,
        name: name,
        type: type,
        classes: classes,
        style: style,
        attributes: attributes,
        value: value,
        commented: commented);
}

/// Creates an `a` node.
DOMElement $a(
    {DOMNodeValidator validate,
      id,
      classes,
      style,
      Map<String, String> attributes,
      String href,
      String target,
      content,
      bool commented}) =>
    $tag('a',
        validate: validate,
        id: id,
        classes: classes,
        style: style,
        attributes: {
          if (href != null) 'href': href,
          if (target != null) 'target': target,
          ...?attributes
        },
        content: content,
        commented: commented);

/// Creates a `p` node.
DOMElement $p(
        {DOMNodeValidator validate,
        id,
        classes,
        style,
        Map<String, String> attributes,
        bool commented}) =>
    $tag('p',
        validate: validate,
        id: id,
        classes: classes,
        style: style,
        attributes: attributes,
        commented: commented);

/// Creates a `br` node.
DOMElement $br({int amount, bool commented}) {
  if (amount != null && amount > 1) {
    var list = <DOMElement>[] ;
    while (list.length < amount) {
      list.add( $tag('br', commented: commented) ) ;
    }
    return $span( content: list , commented: commented) ;
  }
  else {
    return $tag('br', commented: commented);
  }
}

String $nbsp([int length = 1]) {
  length ??= 1 ;
  if (length < 1) return '' ;

  var s = StringBuffer('&nbsp;') ;
  for (var i = 1 ; i < length; i++) {
    s.write('&nbsp;') ;
  }

  return s.toString() ;
}

/// Creates a `hr` node.
DOMElement $hr(
        {DOMNodeValidator validate,
        id,
        classes,
        style,
        Map<String, String> attributes,
        bool commented}) =>
    $tag('hr',
        validate: validate,
        id: id,
        classes: classes,
        style: style,
        attributes: attributes,
        commented: commented);

/// Creates a `form` node.
DOMElement $form(
        {DOMNodeValidator validate,
        id,
        classes,
        style,
        Map<String, String> attributes,
        content,
        bool commented}) =>
    $tag('form',
        validate: validate,
        id: id,
        classes: classes,
        style: style,
        attributes: attributes,
        content: content,
        commented: commented);

/// Creates a `nav` node.
DOMElement $nav(
    {DOMNodeValidator validate,
      id,
      classes,
      style,
      Map<String, String> attributes,
      content,
      bool commented}) =>
    $tag('nav',
        validate: validate,
        id: id,
        classes: classes,
        style: style,
        attributes: attributes,
        content: content,
        commented: commented);

/// Creates a `header` node.
DOMElement $header(
        {DOMNodeValidator validate,
        id,
        classes,
        style,
        Map<String, String> attributes,
        content,
        bool commented}) =>
    $tag('header',
        validate: validate,
        id: id,
        classes: classes,
        style: style,
        attributes: attributes,
        content: content,
        commented: commented);

/// Creates a `footer` node.
DOMElement $footer(
        {DOMNodeValidator validate,
        id,
        classes,
        style,
        Map<String, String> attributes,
        content,
        bool commented}) =>
    $tag('footer',
        validate: validate,
        id: id,
        classes: classes,
        style: style,
        attributes: attributes,
        content: content,
        commented: commented);

/// Returns [true] if [f] is a DOM Builder helper, like `$div` and `$br`.
///
/// Note: A direct helper is only for tags that don't need parameters to be valid.
bool isDOMBuilderDirectHelper(dynamic f) {
  if (f == null || !(f is Function)) return false;

  return identical(f, $br) ||
      identical(f, $p) ||
      identical(f, $nbsp) ||
      identical(f, $div) ||
      identical(f, $divInline) ||
      identical(f, $hr) ||
      identical(f, $form) ||
      identical(f, $nav) ||
      identical(f, $header) ||
      identical(f, $footer) ||
      identical(f, $table) ||
      identical(f, $tbody) ||
      identical(f, $thead) ||
      identical(f, $tfoot) ||
      identical(f, $td) ||
      identical(f, $tr);
}
