import 'dart:async';
import 'dart:collection';
import 'dart:math' as math;
import 'dart:math' show Point;

import 'package:collection/collection.dart' show IterableExtension;
import 'package:swiss_knife/swiss_knife.dart';

import 'dom_builder_attribute.dart';
import 'dom_builder_context.dart';
import 'dom_builder_css.dart';
import 'dom_builder_dsx.dart';
import 'dom_builder_generator.dart';
import 'dom_builder_helpers.dart';
import 'dom_builder_html.dart';
import 'dom_builder_runtime.dart';
import 'dom_builder_template.dart';
import 'dom_builder_treemap.dart';

void domBuilderLog(String message,
    {bool warning = false, Object? error, StackTrace? stackTrace}) {
  if (error != null) {
    print('dom_builder> [ERROR] $message > $error');
  } else if (warning) {
    print('dom_builder> [WARNING] $message');
  } else {
    print('dom_builder> $message');
  }

  if (stackTrace != null) {
    print(stackTrace);
  }
}

mixin WithValue {
  /// Returns `true` if has [value].
  bool get hasValue {
    final value = this.value;
    return value != null && value.isNotEmpty;
  }

  String? get value;

  /// Returns [value] as [bool].
  bool? get valueAsBool => parseBool(value);

  /// Returns [value] as [bool].
  int? get valueAsInt => parseInt(value);

  /// Returns [value] as [double].
  double? get valueAsDouble => parseDouble(value);

  /// Returns [value] as [num].
  num? get valueAsNum => parseNum(value);
}

//
// NodeSelector:
//

typedef NodeSelector = bool Function(DOMNode? node);

final RegExp _selectorDelimiter = RegExp(r'\s*,\s*');

NodeSelector? asNodeSelector(Object? selector) {
  if (selector == null) return null;

  if (selector is NodeSelector) {
    return selector;
  } else if (selector is String) {
    var str = selector.trim();
    if (str.isEmpty) return null;

    var selectors = str.split(_selectorDelimiter);
    if (selectors.any((s) => s.isEmpty)) {
      selectors = selectors.where((s) => s.isNotEmpty).toList();
    }

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
      return (n) => multiSelector.nonNulls.any((f) => f(n));
    }
  } else if (selector is DOMNode) {
    return (n) => n == selector;
  } else if (selector is List) {
    if (selector.isEmpty) return null;
    if (selector.length == 1) return asNodeSelector(selector[0]);

    var multiSelector = selector.map(asNodeSelector).toList();
    return (n) => multiSelector.nonNulls.any((f) => f(n));
  }

  throw ArgumentError(
      "Can't use NodeSelector of type: [ ${selector.runtimeType}");
}

final DOMHtml _domHTML = DOMHtml();

/// Represents a DOM Node.
class DOMNode implements AsDOMNode {
  /// Converts [nodes] to a text [String].
  static String toText(Object? nodes) {
    if (nodes == null) return '';

    if (nodes is String) {
      return nodes;
    } else if (nodes is DOMNode) {
      return nodes.text;
    } else if (_domHTML.isHtmlNode(nodes)) {
      return _domHTML.getNodeText(nodes);
    } else if (nodes is Iterable) {
      nodes = nodes.asList;
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
  static List<DOMNode> parseNodes(Object? entry) {
    if (entry == null) {
      return <DOMNode>[];
    } else if (entry is String) {
      return _parseStringNodes(entry);
    } else if (entry is Iterable) {
      return _parseListNodes(entry);
    }

    var domNode = _parseSingleNode(entry);
    if (domNode != null) return <DOMNode>[domNode];

    if (isDOMBuilderDirectHelper(entry)) {
      try {
        dynamic f = entry;
        var tag = f();
        return parseNodes(tag);
      } catch (e, s) {
        domBuilderLog('Error calling function: $entry',
            error: e, stackTrace: s);
        return <DOMNode>[];
      }
    } else if (entry is DOMElementGenerator ||
        entry is DOMElementGeneratorFunction) {
      return [ExternalElementNode(entry)];
    } else {
      return [ExternalElementNode(entry)];
    }
  }

  /// Same as [parseNodes], but returns a [DOMNode] or a [List<DOMNode>].
  static Object? _parseNode(Object? entry) {
    if (entry == null) {
      return null;
    } else if (entry is String) {
      return _parseStringNodes(entry);
    } else if (entry is Iterable) {
      return _parseListNodes(entry);
    }

    var domNode = _parseSingleNode(entry);
    if (domNode != null) return domNode;

    if (isDOMBuilderDirectHelper(entry)) {
      try {
        dynamic f = entry;
        var tag = f();
        return _parseNode(tag);
      } catch (e, s) {
        domBuilderLog('Error calling function: $entry',
            error: e, stackTrace: s);
        return null;
      }
    } else if (entry is DOMElementGenerator ||
        entry is DOMElementGeneratorFunction) {
      return ExternalElementNode(entry);
    } else {
      return ExternalElementNode(entry);
    }
  }

  static Object? parseString(String s) {
    if (hasHTMLEntity(s) || hasHTMLTag(s)) {
      return parseHTML(s);
    } else if (s.isNotEmpty) {
      return TextNode.toTextNode(s);
    } else {
      return null;
    }
  }

  static List<DOMNode>? parseStringNodes(String s) {
    if (hasHTMLEntity(s) || hasHTMLTag(s)) {
      return parseHTML(s);
    } else if (s.isNotEmpty) {
      return <DOMNode>[TextNode.toTextNode(s)];
    } else {
      return null;
    }
  }

  static List<DOMNode> _parseStringNodes(String s) {
    if (isHTMLElement(s)) {
      return parseHTML(s) ?? <DOMNode>[];
    } else if (hasHTMLEntity(s) || hasHTMLTag(s)) {
      return [DOMElement._('span', content: parseHTML(s))];
    } else {
      return <DOMNode>[TextNode.toTextNode(s)];
    }
  }

  static List<DOMNode> _parseListNodes(Iterable l) {
    if (l is List) {
      if (l is List<DOMNode>) {
        return l;
      } else if (l is List<DOMNode?>) {
        return l.nonNulls.toList();
      }

      final lng = l.length;
      if (lng == 0) {
        return <DOMNode>[];
      } else if (lng == 1) {
        return parseNodes(l.first);
      }
    }

    var nodes = <DOMNode>[];

    for (var e in l) {
      if (e == null) continue;

      var node = _parseNode(e);

      if (node is DOMNode) {
        nodes.add(node);
      } else {
        nodes.addAll(node as Iterable<DOMNode>);
      }
    }

    return nodes;
  }

  static DOMNode? _parseSingleNode(Object o) {
    if (o is DOMNode) {
      return o;
    } else if (o is AsDOMNode) {
      var node = o.asDOMNode;
      return node;
    } else if (o is AsDOMElement) {
      var element = o.asDOMElement;
      return element;
    } else if (_domHTML.isHtmlNode(o)) {
      var domNode = _domHTML.toDOMNode(o);
      return domNode;
    } else if (o is num || o is bool) {
      return TextNode(o.toString());
    } else {
      return null;
    }
  }

  /// Creates a [DOMNode] from dynamic parameter [entry].
  ///
  /// [entry] Can be a [DOMNode], a String with HTML, a Text,
  /// a [Function] or an external element.
  static DOMNode? from(Object? entry) {
    if (entry == null) {
      return null;
    } else if (entry is DOMNode) {
      return entry;
    } else if (_domHTML.isHtmlNode(entry)) {
      return _domHTML.toDOMNode(entry);
    } else if (entry is Iterable) {
      var l = entry.asList;
      if (l.isEmpty) return null;
      l = entry.nonNulls.toList();
      if (l.isEmpty) return null;
      return DOMNode.from(l.single);
    } else if (entry is String) {
      if (isHTMLElement(entry)) {
        return parseHTML(entry)!.single;
      } else if (hasHTMLEntity(entry) || hasHTMLTag(entry)) {
        return parseHTML('<span>$entry</span>')!.single;
      } else {
        return TextNode.toTextNode(entry);
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

  /// Returns the [parent] [DOMNode] of generated tree (by [DOMGenerator]).
  DOMNode? parent;

  /// Returns the [DOMTreeMap] of the last generated tree of elements.
  DOMTreeMap? treeMap;

  /// Returns a [DOMNodeRuntime] with the actual generated node
  /// associated with [treeMap] and [domGenerator].
  DOMNodeRuntime get runtime {
    final treeMap = this.treeMap;
    return treeMap != null
        ? treeMap.getRuntimeNode(this) ??
            (throw StateError(
                "This `DOMNode` is not associated with `treeMap`!"))
        : DOMNodeRuntimeDummy(treeMap, this, null);
  }

  /// Same as [runtime], but casted to [DOMNodeRuntime]<[T]>.
  DOMNodeRuntime<T> getRuntime<T extends Object>() {
    final treeMap = this.treeMap as DOMTreeMap<T>?;
    return treeMap != null
        ? treeMap.getRuntimeNode(this) ??
            (throw StateError(
                "This `DOMNode` is not associated with `treeMap`!"))
        : DOMNodeRuntimeDummy(treeMap, this, null);
  }

  /// Returns [runtime.node].
  dynamic get runtimeNode => treeMap?.getMappedElement(this);

  /// Same as [runtimeNode], but casts to [T].
  T? getRuntimeNode<T>() => runtimeNode as T?;

  /// Returns [true] if this node has a generated element by [domGenerator].
  bool get isGenerated => treeMap != null;

  /// Returns the [DOMGenerator] associated with [treeMap].
  DOMGenerator? get domGenerator => treeMap?.domGenerator;

  /// Indicates if this node accepts content.
  final bool allowContent;

  late bool _commented;

  DOMNode._(bool? allowContent, bool? commented)
      : allowContent = allowContent ?? true,
        _commented = commented ?? false;

  DOMNode({content}) : allowContent = true {
    if (content != null) {
      _content = DOMNode.parseNodes(content);
      _setChildrenParent();
    }
  }

  /// Returns `true` if this node has a [DOMTemplate].
  bool get hasTemplate => false;

  /// Returns `true` if this node has a text node with a unresolved [DOMTemplate].
  bool get hasUnresolvedTemplate => false;

  @override
  DOMNode get asDOMNode => this;

  /// Returns [true] if this node has a parent.
  bool get hasParent => parent != null;

  /// If [true] this node is commented (ignored).
  bool get isCommented => _commented;

  set commented(bool value) {
    _commented = value;
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
      DSXResolution dsxResolution = DSXResolution.skipDSX,
      bool buildTemplates = false,
      DOMNode? parentNode,
      DOMNode? previousNode,
      DOMContext? domContext}) {
    if (isCommented) return '';

    final content = _content;
    if (content == null || content.isEmpty) return '';

    var html = StringBuffer();

    DOMNode? prev;
    for (var node in content) {
      var subHtml = node.buildHTML(
          withIndent: withIndent,
          parentIndent: parentIndent + indent,
          indent: indent,
          disableIndent: disableIndent,
          xhtml: xhtml,
          dsxResolution: dsxResolution,
          buildTemplates: buildTemplates,
          parentNode: parentNode,
          previousNode: prev,
          domContext: domContext);
      html.write(subHtml);
      prev = node;
    }

    return html.toString();
  }

  /// Sets the default [DOMGenerator] to `dart:html` implementation.
  ///
  /// Note that `dom_builder_generator_dart_html.dart` should be imported
  /// to enable `dart:html`.
  @Deprecated(
      "Use `setDefaultDomGeneratorToWeb`. Package `dart:html` is deprecated.")
  static DOMGenerator setDefaultDomGeneratorToDartHTML() {
    return _defaultDomGenerator = DOMGenerator.dartHTML();
  }

  /// Sets the default [DOMGenerator] to `web` implementation.
  ///
  /// Note that `dom_builder_generator_web.dart` should be imported
  /// to enable package `web`.
  static DOMGenerator setDefaultDomGeneratorToWeb() {
    return _defaultDomGenerator = DOMGenerator.web();
  }

  static DOMGenerator? _defaultDomGenerator;

  /// Returns the default [DOMGenerator].
  static DOMGenerator get defaultDomGenerator {
    return _defaultDomGenerator ?? DOMGenerator.web();
  }

  static set defaultDomGenerator(DOMGenerator value) {
    _defaultDomGenerator = value;
  }

  /// Builds a DOM using [generator].
  ///
  /// Note that this instance is a virtual DOM and an implementation of
  /// [DOMGenerator] is responsible to actually generate a DOM tree.
  T? buildDOM<T extends Object>(
      {DOMGenerator<T>? generator,
      DOMTreeMap<T>? treeMap,
      T? parent,
      DOMContext<T>? context,
      bool setTreeMapRoot = true}) {
    if (isCommented) return null;

    generator ??= defaultDomGenerator as DOMGenerator<T>;
    return generator.generate(this,
        parent: parent,
        context: context,
        treeMap: treeMap,
        setTreeMapRoot: setTreeMapRoot);
  }

  EventStream<Object>? _onGenerate;

  /// Returns [true] if has any [onGenerate] listener registered.
  bool get hasOnGenerateListener => _onGenerate != null;

  /// Event handler for when this element is generated by [DOMGenerator].
  EventStream<Object> get onGenerate {
    final onGenerate = _onGenerate ??= EventStream();
    return onGenerate;
  }

  /// Dispatch a [onGenerate] event with [element].
  void notifyElementGenerated(Object element) {
    final onGenerate = _onGenerate;
    if (onGenerate != null) {
      try {
        onGenerate.add(element);
      } catch (e, s) {
        print(e);
        print(s);
      }
    }
  }

  /// Returns the content of this node as text.
  String get text {
    if (isEmptyContent) return '';
    if (_content!.length == 1) {
      return _content![0].text;
    } else {
      return _content!.map((e) => e.text).join('');
    }
  }

  List<DOMNode>? _content;

  /// Actual list of nodes that represents the content of this node.
  List<DOMNode>? get content => _content;

  /// Returns [true] if [node] is a child of this node.
  ///
  /// [deep] If true looks deeply for [node].
  bool containsNode(DOMNode node, {deep = true}) {
    if (_content == null || _content!.isEmpty) return false;

    for (var child in _content!) {
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
    return parent!.root;
  }

  int indexOfNodeIdenticalFirst(DOMNode node) {
    var idx = indexOfNodeIdentical(node);
    return idx >= 0 ? idx : indexOfNode(node);
  }

  int indexOfNodeIdentical(DOMNode node) {
    if (isEmptyContent) return -1;
    for (var i = 0; i < _content!.length; i++) {
      var child = _content![i];
      if (identical(node, child)) return i;
    }
    return -1;
  }

  int indexOfNodeWhere(bool Function(DOMNode node) test) {
    if (isEmptyContent) return -1;

    for (var i = 0; i < _content!.length; i++) {
      var child = _content![i];
      if (test(child)) return i;
    }

    return -1;
  }

  int _contentFromIndexBackwardWhere(
      int idx, int steps, bool Function(DOMNode node) test) {
    for (var i = math.min(idx, _content!.length - 1); i >= 0; i--) {
      var node = _content![i];
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
    for (var i = idx; i < _content!.length; i++) {
      var node = _content![i];
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
    if (isEmptyContent) return false;

    var idx = indexOfNodeIdenticalFirst(node);
    if (idx < 0) return false;
    if (idx == 0) return true;

    _content!.removeAt(idx);

    var idxUp = _contentFromIndexBackwardWhere(
        idx - 1, 0, (node) => node is DOMElement);
    if (idxUp < 0) {
      idxUp = 0;
    }

    _content!.insert(idxUp, node);
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
    if (isEmptyContent) return false;

    var idx = indexOfNodeIdenticalFirst(node);
    if (idx < 0) return false;
    if (idx >= _content!.length - 1) return true;

    _content!.removeAt(idx);

    var idxDown =
        _contentFromIndexForwardWhere(idx, 1, (node) => node is DOMElement);
    if (idxDown < 0) {
      idxDown = _content!.length;
    }

    _content!.insert(idxDown, node);
    node.parent = this;
    return true;
  }

  /// Duplicate this node and add it to the parent.
  DOMNode? duplicate() {
    var parent = this.parent;
    if (parent == null) return null;
    return parent.duplicateNode(this);
  }

  /// Duplicate [node] and add it to the children list.
  DOMNode? duplicateNode(DOMNode node) {
    if (isEmptyContent) return null;

    var idx = indexOfNodeIdenticalFirst(node);
    if (idx < 0) return null;

    var elem = _content![idx];
    var copy = elem.copy();
    _content!.insert(idx + 1, copy);

    copy.parent = this;

    return copy;
  }

  /// Clear the children list.
  void clearNodes() {
    if (isEmptyContent) return;

    for (var node in _content!) {
      node.parent = null;
    }

    _content!.clear();
  }

  /// Removes this node from parent.
  bool remove() {
    var parent = this.parent;
    if (parent == null) return false;
    return parent.removeNode(this);
  }

  /// Removes [node] from children list.
  bool removeNode(DOMNode node) {
    if (isEmptyContent) return false;

    var idx = indexOfNodeIdenticalFirst(node);
    if (idx < 0) {
      return false;
    }

    var removed = _content!.removeAt(idx);

    removed.parent = null;
    return true;
  }

  /// Returns the index position of this node in the parent.
  int get indexInParent {
    if (parent == null) return -1;
    return parent!.indexOfNode(this);
  }

  /// Returns [true] if [other] is in the same [parent] of this node.
  bool isInSameParent(DOMNode other) {
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

  static final RegExp regexpWhiteSpace = RegExp(r'^\s+$', multiLine: false);

  /// Returns [true] if this node only have white space content.
  bool get isWhiteSpaceContent => false;

  /// Returns a copy [List] of children nodes.
  List<DOMNode> get nodes => isNotEmptyContent ? List.from(_content!) : [];

  /// Same as [nodes] but returns an unmodifiable [List].
  List<DOMNode> get nodesView =>
      UnmodifiableListView(isNotEmptyContent ? _content! : []);

  /// Returns the total number of children nodes.
  int get length {
    if (!allowContent) return 0;
    return _content?.length ?? 0;
  }

  /// Returns [true] if this node content is empty (no children nodes).
  bool get isEmptyContent {
    if (!allowContent) return true;
    return _content?.isEmpty ?? true;
  }

  /// Returns [true] if this node content is NOT empty (has children nodes).
  /// See [isEmptyContent].
  bool get isNotEmptyContent {
    if (!allowContent) return false;
    return _content?.isNotEmpty ?? false;
  }

  /// Returns [true] if this node content is empty (no children nodes).
  //bool get isEmpty => isContentEmpty;

  /// Returns ![isEmpty].
  //bool get isNotEmpty => !isEmpty;

  /// Returns [true] if this node only have [DOMElement] nodes.
  bool get hasOnlyElementNodes {
    return _content?.every((n) => n is DOMElement) ?? false;
  }

  /// Returns [true] if this node only have [TextNode] nodes.
  bool get hasOnlyTextNodes {
    return _content?.every((n) => n is TextNode) ?? false;
  }

  void _addToContent(Object? entry) {
    if (entry == null) return;

    if (entry is Iterable) {
      _addListToContent(entry.whereType<DOMNode>().toList());
    } else if (entry is DOMNode) {
      _addNodeToContent(entry);
    }
  }

  // [list] should NOT be shared:
  void _addListToContent(List<DOMNode> list) {
    if (list.isEmpty) return;

    _checkAllowContent();

    var content = _content;
    if (content == null) {
      _content = content = list;
      for (var elem in content) {
        elem.parent = this;
      }
    } else {
      for (var elem in list) {
        content.add(elem);
        elem.parent = this;
      }
    }
  }

  void _addNodeToContent(DOMNode entry) {
    _checkAllowContent();

    var content = _content;
    if (content == null) {
      _content = [entry];
    } else {
      content.add(entry);
    }

    entry.parent = this;
  }

  void _insertToContent(int index, Object? entry) {
    if (entry is Iterable) {
      _insertListToContent(index, entry.whereType<DOMNode>().toList());
    } else if (entry is DOMNode) {
      _insertNodeToContent(index, entry);
    }
  }

  // [list] should NOT be shared:
  void _insertListToContent(int index, List<DOMNode> list) {
    if (list.isEmpty) return;

    _checkAllowContent();

    if (list.length == 1) {
      var elem = list.first;
      if (_content == null || index >= _content!.length) {
        _addNodeToContent(elem);
      } else {
        _content!.insert(index, elem);
      }
      return;
    }

    if (_content == null) {
      _content = list;
      _setChildrenParent();
    } else {
      if (index >= _content!.length) {
        _addListToContent(list);
      } else {
        _content!.insertAll(index, list);
        for (var elem in list) {
          elem.parent = this;
        }
      }
    }
  }

  void _insertNodeToContent(int index, DOMNode entry) {
    _checkAllowContent();

    if (_content == null) {
      _content = [entry];
      entry.parent = this;
    } else {
      if (index >= _content!.length) {
        _addNodeToContent(entry);
      } else {
        _content!.insert(index, entry);
        entry.parent = this;
      }
    }
  }

  void _setChildrenParent() {
    final content = _content;
    if (content != null && content.isNotEmpty) {
      for (var e in content) {
        e.parent = this;
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
    final content = _content;
    if (content != null && content.isNotEmpty) {
      for (var child in content) {
        if (child.parent == null) {
          throw StateError('parent null');
        }

        if (child is DOMElement) {
          child.checkNodes();
        }
      }
    }
  }

  /// Sets the content of this node.
  DOMNode setContent(Object? newContent) {
    var nodes = DOMNode.parseNodes(newContent);
    if (nodes.isEmpty) {
      _content = null;
    } else {
      _content = nodes;
      _setChildrenParent();
      normalizeContent();
    }
    return this;
  }

  /// Returns a child node by [index].
  T? nodeByIndex<T extends DOMNode>(int? index) {
    if (index == null || isEmptyContent) return null;
    return _content![index] as T?;
  }

  /// Returns a child node by [id].
  T? nodeByID<T extends DOMNode>(String? id) {
    if (id == null || id.isEmpty || isEmptyContent) return null;
    if (id.startsWith('#')) id = id.substring(1);
    return nodeWhere((n) => n is DOMElement && n.id == id);
  }

  /// Returns a node [T] that has attribute [id].
  T? selectByID<T extends DOMNode>(String? id) {
    if (id == null || id.isEmpty || isEmptyContent) return null;
    if (id.startsWith('#')) id = id.substring(1);
    return selectWhere((n) => n is DOMElement && n.id == id);
  }

  /// Returns a node [T] that has all [classes].
  T? selectWithAllClasses<T extends DOMNode>(List<String>? classes) {
    if (classes == null || classes.isEmpty || isEmptyContent) return null;

    classes = classes
        .whereType<String>()
        .map((c) => c.trim())
        .where((c) => c.isNotEmpty)
        .toList();

    if (classes.isEmpty) return null;

    return selectWhere((n) => n is DOMElement && n.containsAllClasses(classes));
  }

  /// Returns a node [T] that has any of [classes].
  T? selectWithAnyClass<T extends DOMNode>(List<String>? classes) {
    if (classes == null || classes.isEmpty || isEmptyContent) return null;

    classes = classes
        .whereType<String>()
        .map((c) => c.trim())
        .where((c) => c.isNotEmpty)
        .toList();

    if (classes.isEmpty) return null;

    return selectWhere((n) => n is DOMElement && n.containsAnyClass(classes));
  }

  /// Returns a node [T] that is one of [tags].
  T? selectByTag<T extends DOMNode>(List<String>? tags) {
    if (tags == null || tags.isEmpty || isEmptyContent) return null;

    tags = tags
        .whereType<String>()
        .map((c) => c.trim())
        .where((c) => c.isNotEmpty)
        .toList();

    if (tags.isEmpty) return null;

    return selectWhere((n) => n is DOMElement && tags!.contains(n.tag));
  }

  /// Returns a node [T] that is equals to [node].
  T? nodeEquals<T extends DOMNode>(DOMNode? node) {
    if (node == null || isEmptyContent) return null;
    return nodeWhere((n) => n == node);
  }

  T? selectEquals<T extends DOMNode>(DOMNode? node) {
    if (node == null || isEmptyContent) return null;
    return selectWhere((n) => n == node);
  }

  T? nodeWhere<T extends DOMNode>(Object? selector) {
    if (selector == null || isEmptyContent) return null;
    bool Function(DOMNode) nodeSelector = asNodeSelector(selector)!;
    return _content!.firstWhereOrNull(nodeSelector) as T?;
  }

  /// Returns a [List<T>] of children nodes that matches [selector].
  List<T> nodesWhere<T extends DOMNode>(Object? selector) {
    if (selector == null || isEmptyContent) return <T>[];
    bool Function(DOMNode) nodeSelector = asNodeSelector(selector)!;
    return _content!.where(nodeSelector).whereType<T>().toList();
  }

  void catchNodesWhere<T extends DOMNode>(Object? selector, List<T> destiny) {
    if (selector == null || isEmptyContent) return;
    var nodeSelector = asNodeSelector(selector)!;
    var nodes = _content!.where(nodeSelector).whereType<T>();
    destiny.addAll(nodes);
  }

  /// Returns a [T] child node that matches [selector].
  T? selectWhere<T extends DOMNode>(Object? selector) {
    if (selector == null || isEmptyContent) return null;
    bool Function(DOMNode)? nodeSelector = asNodeSelector(selector);

    var found = nodeWhere(nodeSelector);
    if (found != null) return found as T?;

    for (var n in _content!.whereType<DOMNode>()) {
      found = n.selectWhere(nodeSelector);
      if (found != null) return found as T?;
    }

    return null;
  }

  /// Returns a parent [T] that matches [selector].
  T? selectParentWhere<T extends DOMNode>(Object? selector) {
    if (selector == null) return null;
    bool Function(DOMNode)? nodeSelector = asNodeSelector(selector);
    if (nodeSelector == null) return null;

    DOMNode? node = this;

    while (node != null) {
      if (nodeSelector(node)) return node as T?;
      node = node.parent;
    }
    return null;
  }

  /// Returns a child node of type [T].
  T? selectByType<T extends DOMNode>() => selectWhere((n) => n is T);

  /// Returns a [List<T>] of children nodes that are of type [T].
  List<T> selectAllByType<T extends DOMNode>() =>
      selectAllWhere((n) => n is T).whereType<T>().toList();

  /// Returns a [List<T>] of children nodes that matches [selector].
  List<T> selectAllWhere<T extends DOMNode>(Object? selector) {
    if (selector == null || isEmptyContent) return <T>[];
    var nodeSelector = asNodeSelector(selector);

    var all = <T>[];
    _selectAllWhereImpl(nodeSelector, all);
    return all;
  }

  void _selectAllWhereImpl<T extends DOMNode>(
      NodeSelector? selector, List<T> all) {
    if (isEmptyContent) return;

    catchNodesWhere(selector, all);

    for (var n in _content!.whereType<DOMNode>()) {
      n._selectAllWhereImpl(selector, all);
    }
  }

  T? node<T extends DOMNode>(Object? selector) {
    if (selector is num) {
      return nodeByIndex(selector as int?);
    } else {
      return nodeWhere(selector);
    }
  }

  /// Returns a node [T] that matches [selector].
  ///
  /// [selector] can by a [num], used as a node index.
  T? select<T extends DOMNode>(Object? selector) {
    if (selector == null || isEmptyContent) return null;

    if (selector is num) {
      return nodeByIndex(selector as int?);
    } else {
      return selectWhere(selector);
    }
  }

  /// Returns the index of a child node that matches [selector].
  int indexOf(Object? selector) {
    if (selector == null || isEmptyContent) return -1;

    if (selector is num) {
      if (selector < 0) return -1;
      if (selector >= _content!.length) return _content!.length;
      return selector as int;
    } else {
      bool Function(DOMNode) nodeSelector = asNodeSelector(selector)!;
      return _content!.indexWhere(nodeSelector);
    }
  }

  /// Returns the index of [node].
  int indexOfNode(DOMNode node) {
    if (isEmptyContent) return -1;
    return _content!.indexOf(node);
  }

  /// Adds each entry of [iterable] to [content].
  ///
  /// [contentGenerator] Optional element generator, that is called for each entry of [iterable].
  DOMNode addEach<T>(Iterable<T> iterable,
      [ContentGenerator<T>? contentGenerator]) {
    if (contentGenerator != null) {
      for (var entry in iterable) {
        var content = contentGenerator(entry);
        _addImpl(content);
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
      [ContentGenerator<T>? contentGenerator]) {
    if (contentGenerator != null) {
      for (var entry in iterable) {
        var content = contentGenerator(entry);
        var tagElem = $tag(tag, content: content);
        _addImpl(tagElem);
      }
    } else {
      for (var entry in iterable) {
        var content = $tag(tag, content: entry);
        _addImpl(content);
      }
    }

    normalizeContent();
    return this;
  }

  DOMNode addAsTag<T>(String tag, T entry,
      [ContentGenerator<T>? contentGenerator]) {
    if (contentGenerator != null) {
      var content = contentGenerator(entry);
      var tagElem = $tag(tag, content: content);
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
    if (list.isNotEmpty) {
      _addToContent(list);
      normalizeContent();
    }
    return this;
  }

  DOMNode add(Object? entry) {
    if (entry != null) {
      _addNotNullImpl(entry);
      normalizeContent();
    }
    return this;
  }

  /// Adds all [entries] to children nodes.
  DOMNode addAll(Iterable? entries) {
    if (entries != null) {
      var added = false;
      for (var e in entries) {
        if (e != null) {
          _addNotNullImpl(e);
          added = true;
        }
      }
      if (added) {
        normalizeContent();
      }
    }
    return this;
  }

  void _addImpl(Object? entry) {
    if (entry != null) {
      var node = _parseNode(entry);
      _addToContent(node);
    }
  }

  void _addNotNullImpl(Object entry) {
    var node = _parseNode(entry);
    _addToContent(node);
  }

  /// Inserts [entry] at index of child node that matches [indexSelector].
  DOMNode insertAt(Object? indexSelector, Object? entry) {
    var idx = indexOf(indexSelector);

    if (idx >= 0) {
      var node = _parseNode(entry);
      if (idx >= length) {
        _addToContent(node);
      } else {
        _insertToContent(idx, node);
      }
    } else if (indexSelector is num && isEmptyContent) {
      var node = _parseNode(entry);
      _addImpl(node);
    }

    normalizeContent();

    return this;
  }

  /// Inserts [entry] after index of child node that matches [indexSelector].
  DOMNode insertAfter(Object? indexSelector, Object? entry) {
    var idx = indexOf(indexSelector);

    if (idx >= 0) {
      idx++;

      var node = _parseNode(entry);
      _insertToContent(idx, node);
    } else if (indexSelector is num && isEmptyContent) {
      var node = _parseNode(entry);
      _addImpl(node);
    }

    normalizeContent();

    return this;
  }

  /// Copies this node.
  DOMNode copy() {
    return DOMNode(content: copyContent());
  }

  /// Copies this node content.
  List<DOMNode> copyContent() {
    if (_content == null || _content!.isEmpty) return <DOMNode>[];
    var content2 = _content!.map((e) => e.copy()).toList();
    return content2;
  }
}

/// Represents a text node in DOM.
class TextNode extends DOMNode with WithValue {
  static DOMNode toTextNode(String? text) {
    if (text == null || text.isEmpty) {
      return TextNode('');
    }

    if (DOMTemplate.possiblyATemplate(text)) {
      var template = DOMTemplate.tryParse(text);
      return template != null ? TemplateNode(template) : TextNode(text, true);
    } else {
      return TextNode(text, false);
    }
  }

  String _text;
  bool _hasUnresolvedTemplate;

  TextNode(this._text, [bool? hasTemplateToResolve])
      : _hasUnresolvedTemplate =
            hasTemplateToResolve ?? DOMTemplate.possiblyATemplate(_text),
        super._(false, false);

  @override
  String get text => _text;

  set text(String value) {
    _text = value;
    _hasUnresolvedTemplate = DOMTemplate.possiblyATemplate(value);
  }

  @override
  bool get hasTemplate => false;

  @override
  bool get hasUnresolvedTemplate => _hasUnresolvedTemplate;

  bool get isTextEmpty => text.isEmpty;

  @override
  bool get hasValue => text.isNotEmpty;

  @override
  bool absorbNode(DOMNode other) {
    if (other is TextNode) {
      text += other.text;
      other.text = '';
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
  bool merge(DOMNode other, {bool onlyConsecutive = true}) {
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
        (other.isEmptyContent || other.hasOnlyTextNodes)) {
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
  bool get isWhiteSpaceContent => DOMNode.regexpWhiteSpace.hasMatch(text);

  @override
  String buildHTML(
      {bool withIndent = false,
      String parentIndent = '',
      String indent = '  ',
      bool disableIndent = false,
      bool xhtml = false,
      DSXResolution dsxResolution = DSXResolution.skipDSX,
      bool buildTemplates = false,
      DOMNode? parentNode,
      DOMNode? previousNode,
      DOMContext? domContext}) {
    var nbsp = xhtml ? '&#160;' : '&nbsp;';
    return text.replaceAll('\xa0', nbsp);
  }

  @override
  String get value => text;

  bool equals(Object other) =>
      identical(this, other) ||
      other is TextNode &&
          runtimeType == other.runtimeType &&
          text == other.text;

  @override
  TextNode copy() {
    return TextNode(_text, _hasUnresolvedTemplate);
  }

  @override
  List<DOMNode> copyContent() {
    return <DOMNode>[];
  }

  @override
  String toString() {
    return text;
  }
}

/// Represents a template node in DOM.
class TemplateNode extends DOMNode with WithValue {
  DOMTemplateNode template;

  TemplateNode(this.template) : super._(false, false);

  @override
  String get text => isNotEmptyTemplate ? template.toString() : '';

  set text(String value) {
    template = DOMTemplate.parse(value);
  }

  @override
  bool get hasTemplate => true;

  @override
  bool get hasUnresolvedTemplate => false;

  bool get isEmptyTemplate => template.isEmpty;

  bool get isNotEmptyTemplate => !isEmptyTemplate;

  @override
  bool get hasValue => template.isNotEmpty;

  @override
  bool absorbNode(DOMNode other) {
    if (other is TextNode) {
      text += other.text;
      other.text = '';
      return true;
    } else if (other is TemplateNode) {
      template.addAll(other.template.nodes);
      other.template.clear();
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
    template.clear();
    super.clearNodes();
  }

  @override
  bool merge(DOMNode other, {bool onlyConsecutive = true}) {
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
        (other.isEmptyContent || other.hasOnlyTextNodes)) {
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
  bool get isWhiteSpaceContent => DOMNode.regexpWhiteSpace.hasMatch(text);

  @override
  String buildHTML(
      {bool withIndent = false,
      String parentIndent = '',
      String indent = '  ',
      bool disableIndent = false,
      bool xhtml = false,
      DSXResolution dsxResolution = DSXResolution.skipDSX,
      bool buildTemplates = false,
      DOMNode? parentNode,
      DOMNode? previousNode,
      DOMContext? domContext}) {
    String? html;

    if (dsxResolution.resolve) {
      if (template.isDSX) {
        html = template.buildAsString(domContext,
            dsxResolution: dsxResolution,
            intlMessageResolver: domContext?.intlMessageResolver);
      } else if (template.hasDSX) {
        var template2 = template.copy(dsxResolution: dsxResolution);

        if (buildTemplates) {
          var built = template2.build(domContext,
              asElement: false,
              dsxResolution: dsxResolution,
              intlMessageResolver: domContext?.intlMessageResolver);
          html = DOMTemplate.objectToString(built);
        } else {
          html = template2.toString();
        }
      }
    }

    if (html == null) {
      if (buildTemplates) {
        html = template.buildAsString(domContext,
            dsxResolution: dsxResolution,
            intlMessageResolver: domContext?.intlMessageResolver);
      } else {
        html = text;
      }
    }

    var nbsp = xhtml ? '&#160;' : '&nbsp;';

    return html.replaceAll('\xa0', nbsp);
  }

  @override
  String get value => text;

  bool equals(Object other) =>
      identical(this, other) ||
      other is TemplateNode &&
          runtimeType == other.runtimeType &&
          template == other.template;

  @override
  TemplateNode copy() {
    return TemplateNode(DOMTemplate.parse(text));
  }

  @override
  List<DOMNode> copyContent() {
    return <DOMNode>[];
  }

  @override
  String toString() {
    return text;
  }
}

//
// ContentGenerator:
//

typedef ContentGenerator<T> = dynamic Function(T? entry);

void _checkTag(String expectedTag, DOMElement domElement) {
  if (domElement.tag != expectedTag) {
    throw StateError('Not a $expectedTag tag: $domElement');
  }
}

//
// DOMElement:
//

/// A node for HTML elements.
class DOMElement extends DOMNode with WithValue implements AsDOMElement {
  static final Set<String> _selfClosingTags = {
    'area',
    'base',
    'br',
    'embed',
    'hr',
    'img',
    'input',
    'link',
    'meta',
    'param',
    'source',
    'track',
    'wbr',
  };

  static final Set<String> _selfClosingTagsOptional = {'p'};

  static String _normalizeTag(String? tag) {
    if (tag == null) {
      throw ArgumentError("Null tag!");
    }

    tag = tag.toLowerCase().trim();
    if (tag.isEmpty) {
      throw ArgumentError("Empty tag!");
    }

    return tag;
  }

  /// Normalizes a tag name. Returns null for empty string.
  static String? normalizeTag(String? tag) {
    if (tag == null) return null;
    tag = tag.toLowerCase().trim();
    if (tag.isEmpty) return null;
    return tag;
  }

  /// The tag name in lower-case.
  final String tag;

  factory DOMElement(String? tag,
      {Map<String, dynamic>? attributes,
      Object? id,
      Object? classes,
      Object? style,
      Object? content,
      bool? hidden,
      bool commented = false}) {
    tag = _normalizeTag(tag);

    switch (tag) {
      case 'div':
        return DIVElement(
            attributes: attributes,
            id: id,
            classes: classes,
            style: style,
            content: content,
            hidden: hidden,
            commented: commented);

      case 'input':
        {
          var type = attributes?['type'];

          if (type == 'checkbox') {
            return CHECKBOXElement(
                attributes: attributes,
                id: id,
                classes: classes,
                style: style,
                value: content,
                hidden: hidden,
                commented: commented);
          }

          return INPUTElement(
              attributes: attributes,
              id: id,
              classes: classes,
              style: style,
              value: content,
              hidden: hidden,
              commented: commented);
        }

      case 'select':
        return SELECTElement(
            attributes: attributes,
            id: id,
            classes: classes,
            style: style,
            options: content,
            hidden: hidden,
            commented: commented);

      case 'option':
        return OPTIONElement(
          attributes: attributes,
          classes: classes,
          style: style,
          text: DOMNode.toText(content),
        );

      case 'textarea':
        return TEXTAREAElement(
            attributes: attributes,
            id: id,
            classes: classes,
            style: style,
            content: content,
            hidden: hidden,
            commented: commented);

      case 'table':
        return TABLEElement(
            attributes: attributes,
            id: id,
            classes: classes,
            style: style,
            content: content,
            hidden: hidden,
            commented: commented);

      case 'thead':
        return THEADElement(
            attributes: attributes,
            id: id,
            classes: classes,
            style: style,
            rows: content,
            hidden: hidden,
            commented: commented);

      case 'caption':
        return CAPTIONElement(
            attributes: attributes,
            id: id,
            classes: classes,
            style: style,
            content: content,
            hidden: hidden,
            commented: commented);

      case 'tbody':
        return TBODYElement(
            attributes: attributes,
            id: id,
            classes: classes,
            style: style,
            rows: content,
            hidden: hidden,
            commented: commented);

      case 'tfoot':
        return TFOOTElement(
            attributes: attributes,
            id: id,
            classes: classes,
            style: style,
            rows: content,
            hidden: hidden,
            commented: commented);

      case 'tr':
        return TRowElement(
            attributes: attributes,
            id: id,
            classes: classes,
            style: style,
            cells: content,
            hidden: hidden,
            commented: commented);

      case 'td':
        return TDElement(
            attributes: attributes,
            id: id,
            classes: classes,
            style: style,
            content: content,
            hidden: hidden,
            commented: commented);

      case 'th':
        return THElement(
            attributes: attributes,
            id: id,
            classes: classes,
            style: style,
            content: content,
            hidden: hidden,
            commented: commented);

      default:
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

  DOMElement._(this.tag,
      {Map<String, dynamic>? attributes,
      Object? id,
      Object? classes,
      Object? style,
      Object? content,
      bool? hidden,
      bool commented = false})
      : super._(true, commented) {
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
      if (hidden) {
        setAttributeIfAbsent('hidden', hidden);
      } else {
        removeAttribute('hidden');
      }
    }

    if (content != null) {
      setContent(content);
    }

    resolveDSX();
  }

  Map<String, DSX>? _resolvedDSXEventAttributes;

  Iterable<DSX> resolvedDSXs() => _resolvedDSXEventAttributes?.values ?? [];

  void resolveDSX() {
    var attributes = _attributes;
    if (attributes == null || attributes.isEmpty) return;

    Map<String, DSX>? dsxAttributes;

    for (var entry in attributes.entries) {
      var attrVal = entry.value;

      var valueHandler = attrVal.valueHandler;

      if (valueHandler is DOMAttributeValueTemplate) {
        var dsx = valueHandler.template.asDSX;
        if (dsx != null) {
          dsxAttributes ??= <String, DSX>{};
          dsxAttributes[entry.key] = dsx;
        }
      }
    }

    if (dsxAttributes != null) {
      for (var entry in dsxAttributes.entries) {
        var attrName = entry.key;
        var dsx = entry.value;

        if (dsx.isFunction) {
          if (_resolveDSXEventFunction(attrName, dsx)) {
            _resolvedDSXEventAttributes ??= <String, DSX>{};
            _resolvedDSXEventAttributes![attrName] = dsx;

            removeAttribute(attrName);
          }
        }
      }
    }
  }

  bool _resolveDSXEventFunction(String attrName, DSX<dynamic> dsx) {
    attrName = attrName.toLowerCase();

    if (attrName == 'onclick') {
      onClick.listen((_) => dsx.call());
      return true;
    } else if (attrName == 'onload') {
      onLoad.listen((_) => dsx.call());
      return true;
    } else if (attrName == 'onmouseover') {
      onMouseOver.listen((_) => dsx.call());
      return true;
    } else if (attrName == 'onmouseout') {
      onMouseOut.listen((_) => dsx.call());
      return true;
    } else if (attrName == 'onchange') {
      onChange.listen((_) => dsx.call());
      return true;
    } else if (attrName == 'onkeypress') {
      onKeyPress.listen((_) => dsx.call());
      return true;
    } else if (attrName == 'onkeyup') {
      onKeyUp.listen((_) => dsx.call());
      return true;
    } else if (attrName == 'onkeydown') {
      onKeyDown.listen((_) => dsx.call());
      return true;
    } else if (attrName == 'onerror') {
      onError.listen((_) => dsx.call());
      return true;
    }

    return false;
  }

  @override
  bool get hasTemplate {
    if (_content != null) {
      for (var node in _content!) {
        if (node.hasTemplate) {
          return true;
        }
      }
    }

    if (_attributes != null) {
      for (var attr in _attributes!.values) {
        if (attr.valueHandler is DOMAttributeValueTemplate) {
          return true;
        }
      }
    }

    return false;
  }

  @override
  bool get hasUnresolvedTemplate {
    if (_content != null) {
      for (var node in _content!) {
        if (node.hasUnresolvedTemplate) {
          return true;
        }
      }
    }

    return false;
  }

  @override
  DOMElement get asDOMElement => this;

  /// Returns [true] if [tag] is one of [tags].
  bool isTagOneOf(Iterable<String> tags) {
    if (tag.isEmpty) return false;

    for (var t in tags) {
      var t2 = normalizeTag(t);
      if (tag == t2) return true;
    }

    return false;
  }

  /// Returns the attribute `id`.
  String? get id => getAttributeValue('id');

  /// Returns the attribute `class`.
  String? get classes => getAttributeValue('class');

  set classes(Object? value) => setAttribute('class', value);

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
      attr = getAttribute('style')!;
    }

    var cssHandler = attr.valueHandler as DOMAttributeValueCSS;
    return cssHandler.css;
  }

  set style(Object? value) => setAttribute('style', value);

  String? get styleText {
    var attr = getAttribute('style');
    if (attr == null) return null;
    return attr.value;
  }

  set styleText(String? value) => setAttribute('style', value);

  /// Returns [true] if attribute `class` has the [className].
  bool containsClass(String className) {
    var attribute = getAttribute('class');
    if (attribute == null) return false;
    return attribute.containsValue(className);
  }

  /// Returns [true] if attribute `class` has all [classes].
  bool containsAllClasses(Iterable<String>? classes) {
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
  bool containsAnyClass(Iterable<String>? classes) {
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

  LinkedHashMap<String, DOMAttribute>? _attributes;

  Map<String, DOMAttribute> get domAttributes {
    final attributes = _attributes;
    return attributes != null ? Map.from(attributes) : <String, DOMAttribute>{};
  }

  Map<String, dynamic> get attributes =>
      _attributes?.map((key, value) => MapEntry<String, dynamic>(
          key, value.isCollection ? value.values : value.value)) ??
      <String, dynamic>{};

  Map<String, String> get attributesAsString =>
      _attributes?.map(
          ((key, value) => MapEntry<String, String>(key, value.value ?? ''))) ??
      <String, String>{};

  static const Set<String> possibleGlobalAttributes = {
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

    for (var attr in possibleGlobalAttributes) {
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

    if (tag == 'video') {
      attributes.putIfAbsent('autoplay', () => '');
      attributes.putIfAbsent('controls', () => '');
      attributes.putIfAbsent('muted', () => '');
    }

    return attributes;
  }

  /// Returns the attributes names with values.
  Iterable<String> get attributesNames {
    final attributes = _attributes;
    return attributes != null && attributes.isNotEmpty ? attributes.keys : [];
  }

  /// Returns the size of attributes Map.
  int get attributesLength => _attributes?.length ?? 0;

  /// Returns [true] if this element has NO attributes.
  bool get hasEmptyAttributes => _attributes?.isEmpty ?? true;

  /// Returns [true] if this element has attributes.
  bool get hasAttributes => _attributes?.isNotEmpty ?? false;

  String? operator [](String name) => getAttributeValue(name);

  void operator []=(String name, Object? value) => setAttribute(name, value);

  @override
  String? get value => text;

  /// Returns attribute value for [name].
  ///
  /// [domContext] Optional context used by [DOMGenerator].
  String? getAttributeValue(String name, [DOMContext? domContext]) {
    var attr = getAttribute(name);
    return attr?.getValue(domContext);
  }

  /// Calls [getAttributeValue] and returns parsed as [bool].
  bool getAttributeValueAsBool(String name, [DOMContext? domContext]) {
    return parseBool(getAttributeValue(name, domContext), false)!;
  }

  /// Calls [getAttributeValue] and returns parsed as [int].
  int? getAttributeValueAsInt(String name, [DOMContext? domContext]) {
    return parseInt(getAttributeValue(name, domContext));
  }

  /// Calls [getAttributeValue] and returns parsed as [double].
  double? getAttributeValueAsDouble(String name, [DOMContext? domContext]) {
    return parseDouble(getAttributeValue(name, domContext));
  }

  /// Returns [true] if attribute for [name] exists.
  ///
  /// [domContext] Optional context used by [DOMGenerator].
  bool hasAttributeValue(String name, [DOMContext? domContext]) {
    var attr = getAttribute(name);
    if (attr == null) return false;
    var value = attr.getValue(domContext);
    return value != null && value.isNotEmpty;
  }

  /// Returns [DOMAttribute] entry for [name].
  DOMAttribute? getAttribute(String name) {
    return _attributes?[name];
  }

  /// Sets attribute for [name], parsing [value].
  DOMElement setAttribute(String name, Object? value) {
    name = name.toLowerCase().trim();

    if (_attributes != null) {
      var prevAttribute = _attributes![name];
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

  DOMElement setAttributeIfAbsent(String name, Object? value) {
    name = name.toLowerCase().trim();

    final attributes = _attributes;
    if (attributes != null) {
      var prevAttribute = attributes[name];
      if (prevAttribute != null) {
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
  DOMElement appendToAttribute(String name, Object? value) {
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
  DOMElement addAllAttributes(Map<String, dynamic>? attributes) {
    if (attributes != null && attributes.isNotEmpty) {
      for (var entry in attributes.entries) {
        var name = entry.key;
        var value = entry.value;
        setAttribute(name, value);
      }
    }

    return this;
  }

  DOMElement putDOMAttribute(DOMAttribute attribute) {
    // ignore: prefer_collection_literals
    var attributes = _attributes ??= LinkedHashMap();
    attributes[attribute.name] = attribute;
    return this;
  }

  bool removeAttribute(String attributeName) {
    attributeName = attributeName.toLowerCase().trim();
    if (attributeName.isEmpty) return false;

    return _removeAttributeImp(attributeName);
  }

  bool _removeAttributeImp(String attributeName) {
    var attribute = _attributes?.remove(attributeName);
    return attribute != null;
  }

  bool removeAttributeDeeply(String attributeName) {
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

    return this as T;
  }

  /// Applies [id], [classes] and [style] to children nodes that matches [selector].
  T applyWhere<T extends DOMElement>(Object? selector, {id, classes, style}) {
    var all = selectAllWhere(selector);

    for (var elem in all) {
      if (elem is DOMElement) {
        elem.apply(id: id, classes: classes, style: style);
      }
    }

    return this as T;
  }

  @override
  DOMElement add(entry) {
    return super.add(entry) as DOMElement;
  }

  @override
  DOMElement addEach<T>(Iterable<T> iterable,
      [ContentGenerator<T>? contentGenerator]) {
    return super.addEach(iterable, contentGenerator) as DOMElement;
  }

  @override
  DOMElement addEachAsTag<T>(String tag, Iterable<T> iterable,
      [ContentGenerator<T>? contentGenerator]) {
    return super.addEachAsTag(tag, iterable, contentGenerator) as DOMElement;
  }

  @override
  DOMElement addHTML(String html) {
    return super.addHTML(html) as DOMElement;
  }

  @override
  DOMElement insertAfter(Object? indexSelector, Object? entry) {
    return super.insertAfter(indexSelector, entry) as DOMElement;
  }

  @override
  DOMElement insertAt(Object? indexSelector, Object? entry) {
    return super.insertAt(indexSelector, entry) as DOMElement;
  }

  @override
  DOMElement setContent(Object? newContent) =>
      super.setContent(newContent) as DOMElement;

  @override
  bool absorbNode(DOMNode other) {
    if (other is DOMElement) {
      if (other.isEmptyContent) return true;
      var otherContent = other._content;
      if (otherContent != null) {
        addAll(otherContent);
        otherContent.clear();
      }
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
    final attributes = _attributes;
    if (attributes == null || attributes.isEmpty) return '';
    var entries = attributes
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

  static bool isStringTagName(String? tag) {
    tag = normalizeTag(tag);
    if (tag == null || tag.isEmpty) return false;
    return _isStringTagName(tag);
  }

  static bool _isStringTagName(String? tag) {
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
      return DOMNode.regexpWhiteSpace.hasMatch(text);
    }
    return false;
  }

  String buildOpenTagHTML(
      {bool openCloseTag = false,
      DSXResolution dsxResolution = DSXResolution.skipDSX,
      DOMContext? domContext}) {
    var html = StringBuffer('<$tag');

    final attributes = _attributes;
    if (attributes != null && attributes.isNotEmpty) {
      var attributeId = attributes['id'];
      var attributeClass = attributes['class'];
      var attributeStyle = attributes['style'];

      DOMAttribute.appendTo(html, ' ', attributeId,
          domContext: domContext, dsxResolution: dsxResolution);
      DOMAttribute.appendTo(html, ' ', attributeClass,
          domContext: domContext, dsxResolution: dsxResolution);
      DOMAttribute.appendTo(html, ' ', attributeStyle,
          domContext: domContext, dsxResolution: dsxResolution);

      var attributesNormal = attributes.values
          .where((v) => v.hasValue && !_isPriorityAttribute(v) && !v.isBoolean);

      for (var attr in attributesNormal) {
        DOMAttribute.appendTo(html, ' ', attr,
            domContext: domContext, dsxResolution: dsxResolution);
      }

      var attributesBoolean = attributes.values
          .where((v) => v.hasValue && !_isPriorityAttribute(v) && v.isBoolean);

      for (var attr in attributesBoolean) {
        DOMAttribute.appendTo(html, ' ', attr,
            domContext: domContext, dsxResolution: dsxResolution);
      }
    }

    if (_resolvedDSXEventAttributes != null) {
      for (var entry in _resolvedDSXEventAttributes!.entries) {
        var name = entry.key;
        var value = entry.value.toString();

        html.write(' ');
        html.write(name);
        html.write('="');
        html.write(value);
        html.write('"');
      }
    }

    html.write(openCloseTag ? '/>' : '>');

    return html.toString();
  }

  bool _isPriorityAttribute(DOMAttribute attr) {
    return attr.name == 'id' || attr.name == 'class' || attr.name == 'style';
  }

  String buildCloseTagHTML() {
    return '</$tag>';
  }

  static bool _tagAllowsInnerIndent(String? tag) {
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
      DSXResolution dsxResolution = DSXResolution.skipDSX,
      bool buildTemplates = false,
      DOMNode? parentNode,
      DOMNode? previousNode,
      DOMContext? domContext}) {
    if (buildTemplates && hasUnresolvedTemplate) {
      var htmlUnresolvedTemplate = buildHTML(
        withIndent: true,
        buildTemplates: false,
        dsxResolution: DSXResolution.skipDSX,
      );

      var template = DOMTemplate.tryParse(htmlUnresolvedTemplate);

      if (template != null) {
        var templateNode = TemplateNode(template);

        var html = templateNode.buildHTML(
            withIndent: withIndent,
            parentIndent: parentIndent,
            indent: indent,
            disableIndent: disableIndent,
            xhtml: xhtml,
            dsxResolution: dsxResolution,
            buildTemplates: true,
            parentNode: parentNode,
            previousNode: previousNode,
            domContext: domContext);

        return html;
      }
    }

    if (!disableIndent && !_tagAllowsInnerIndent(tag)) {
      disableIndent = true;
    }

    var allowIndent = withIndent &&
        isNotEmptyContent &&
        hasOnlyElementNodes &&
        !disableIndent;

    var innerIndent = allowIndent ? parentIndent + indent : '';
    var innerBreakLine = allowIndent ? '\n' : '';

    if (parentIndent.isNotEmpty &&
        previousNode != null &&
        previousNode.isStringElement) {
      parentIndent = '';
    }

    final content = _content;
    var emptyContent = content == null || content.isEmpty;

    if (_selfClosingTags.contains(tag) ||
        (emptyContent && (xhtml || _selfClosingTagsOptional.contains(tag)))) {
      var html = parentIndent +
          buildOpenTagHTML(
              openCloseTag: xhtml,
              dsxResolution: dsxResolution,
              domContext: domContext);
      return html;
    }

    var html = StringBuffer();

    html.write(parentIndent);
    html.write(
        buildOpenTagHTML(dsxResolution: dsxResolution, domContext: domContext));
    html.write(innerBreakLine);

    if (!emptyContent) {
      buildHTMLContent(
        output: html,
        withIndent: withIndent,
        innerIndent: innerIndent,
        innerBreakLine: innerBreakLine,
        indent: indent,
        disableIndent: disableIndent,
        xhtml: xhtml,
        dsxResolution: dsxResolution,
        buildTemplates: buildTemplates,
        domContext: domContext,
      );
    }

    if (allowIndent) {
      html.write(parentIndent);
    }

    html.write(buildCloseTagHTML());

    return html.toString();
  }

  StringBuffer buildHTMLContent(
      {bool withIndent = false,
      String indent = '  ',
      bool disableIndent = false,
      bool xhtml = false,
      DSXResolution dsxResolution = DSXResolution.skipDSX,
      bool buildTemplates = false,
      String innerIndent = '',
      String innerBreakLine = '',
      DOMNode? parentNode,
      DOMNode? previousNode,
      DOMContext? domContext,
      StringBuffer? output}) {
    output ??= StringBuffer();

    final content = _content;
    if (content == null || content.isEmpty) {
      return output;
    }

    DOMNode? prev;
    for (var node in content) {
      var subElement = node.buildHTML(
          withIndent: withIndent,
          parentIndent: innerIndent,
          indent: indent,
          disableIndent: disableIndent,
          xhtml: xhtml,
          dsxResolution: dsxResolution,
          buildTemplates: buildTemplates,
          parentNode: this,
          previousNode: prev,
          domContext: domContext);
      output.write(subElement);
      output.write(innerBreakLine);
      prev = node;
    }

    return output;
  }

  /// Returns true if [other] is fully equals.
  bool equals(Object other) =>
      identical(this, other) ||
      other is DOMElement &&
          runtimeType == other.runtimeType &&
          tag == other.tag &&
          equalsAttributes(other) &&
          ((isEmptyContent && other.isEmptyContent) ||
              isEqualsDeep(_content, other._content));

  /// Returns true if [other] have the same attributes.
  bool equalsAttributes(DOMElement other) =>
      ((hasEmptyAttributes && other.hasEmptyAttributes) ||
          isEqualsDeep(_attributes, other._attributes));

  static int objectHashcode(Object? o) {
    if (isEmptyObject(o)) return 0;
    return deepHashCode(o);
  }

  @override
  String toString() {
    var attributesStr = hasAttributes ? ', attributes: $_attributes' : '';
    var contentStr = isNotEmptyContent ? ', content: ${_content!.length}' : '';
    return 'DOMElement{tag: $tag$attributesStr$contentStr}';
  }

  @override
  DOMElement copy() {
    return DOMElement(tag,
        attributes: attributes, commented: isCommented, content: copyContent());
  }

  EventStream<DOMMouseEvent>? _onClick;

  /// Returns [true] if has any [onClick] listener registered.
  bool get hasOnClickListener => _onClick != null;

  /// Event handler for `click` events.
  EventStream<DOMMouseEvent> get onClick {
    final onClick = _onClick ??= EventStream();
    return onClick;
  }

  EventStream<DOMEvent>? _onChange;

  /// Returns [true] if has any [onChange] listener registered.
  bool get hasOnChangeListener => _onChange != null;

  /// Event handler for `change` events.
  EventStream<DOMEvent> get onChange {
    final onChange = _onChange ??= EventStream();
    return onChange;
  }

  EventStream<DOMEvent>? _onKeyPress;

  /// Returns [true] if has any [onKeyPress] listener registered.
  bool get hasOnKeyPressListener => _onKeyPress != null;

  /// Event handler for `change` events.
  EventStream<DOMEvent> get onKeyPress {
    final onKeyPress = _onKeyPress ??= EventStream();
    return onKeyPress;
  }

  EventStream<DOMEvent>? _onKeyUp;

  /// Returns [true] if has any [onKeyUp] listener registered.
  bool get hasOnKeyUpListener => _onKeyUp != null;

  /// Event handler for `change` events.
  EventStream<DOMEvent> get onKeyUp {
    final onKeyUp = _onKeyUp ??= EventStream();
    return onKeyUp;
  }

  EventStream<DOMEvent>? _onKeyDown;

  /// Returns [true] if has any [onKeyDown] listener registered.
  bool get hasOnKeyDownListener => _onKeyDown != null;

  /// Event handler for `change` events.
  EventStream<DOMEvent> get onKeyDown {
    final onKeyDown = _onKeyDown ??= EventStream();
    return onKeyDown;
  }

  EventStream<DOMMouseEvent>? _onMouseOver;

  /// Returns [true] if has any [onMouseOver] listener registered.
  bool get hasOnMouseOverListener => _onMouseOver != null;

  /// Event handler for click `mouseOver` events.
  EventStream<DOMMouseEvent> get onMouseOver {
    final onMouseOver = _onMouseOver ??= EventStream();
    return onMouseOver;
  }

  EventStream<DOMMouseEvent>? _onMouseOut;

  /// Returns [true] if has any [onMouseOut] listener registered.
  bool get hasOnMouseOutListener => _onMouseOut != null;

  /// Event handler for click `mouseOut` events.
  EventStream<DOMMouseEvent> get onMouseOut {
    final onMouseOut = _onMouseOut ??= EventStream();
    return onMouseOut;
  }

  EventStream<DOMEvent>? _onLoad;

  /// Returns [true] if has any [onLoad] listener registered.
  bool get hasOnLoadListener => _onLoad != null;

  /// Event handler for `load` events.
  EventStream<DOMEvent> get onLoad {
    final onLoad = _onLoad ??= EventStream();
    return onLoad;
  }

  EventStream<DOMEvent>? _onError;

  /// Returns [true] if has any [onError] listener registered.
  bool get hasOnErrorListener => _onError != null;

  /// Event handler for `load` events.
  EventStream<DOMEvent> get onError {
    final onError = _onError ??= EventStream();
    return onError;
  }

  /// Sets the validator of this [DOMElement].
  StreamSubscription<DOMEvent> validator(Function validator,
      {String? errorClass, String? validClass}) {
    return onChange.listen((_) {
      Object? result;

      var rt = runtime;

      if (validator is Function(DOMElement)) {
        result = validator(this);
      } else if (validator is Function(String?)) {
        var value = rt.value;
        result = validator(value);
      } else if (validator is Function(String)) {
        var value = rt.value ?? '';
        result = validator(value);
      } else if (validator is Function(Object)) {
        var node = rt.node;
        result = node != null && validator(node);
      } else if (validator is Function(Object?)) {
        var node = rt.node;
        result = validator(node);
      }

      var valid = parseBool(result, false)!;

      if (valid) {
        if (errorClass != null) rt.removeClass(errorClass);
        if (validClass != null) rt.addClass(validClass);
      } else {
        if (validClass != null) rt.removeClass(validClass);
        if (errorClass != null) rt.addClass(errorClass);
      }
    });
  }
}

//
// Events:
//

/// Base class for [DOMElement] events.
class DOMEvent<T extends Object> {
  final DOMTreeMap<T> treeMap;
  final Object? event;
  final Object? eventTarget;
  final DOMNode? target;

  DOMEvent(this.treeMap, this.event, this.eventTarget, this.target);

  DOMGenerator<T> get domGenerator => treeMap.domGenerator;

  bool cancel({bool stopImmediatePropagation = false}) => domGenerator
      .cancelEvent(event, stopImmediatePropagation: stopImmediatePropagation);

  @override
  String toString() {
    return '$event';
  }
}

/// Represents a mouse event.
class DOMMouseEvent<T extends Object> extends DOMEvent<T> {
  final Point<num> client;

  final Point<num> offset;

  final Point<num> page;

  final Point<num> screen;

  final int button;

  final int? buttons;

  final bool altKey;

  final bool ctrlKey;

  final bool shiftKey;

  final bool metaKey;

  DOMMouseEvent(
      super.treeMap,
      super.event,
      super.eventTarget,
      super.target,
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
      : super();

  /// Creates an artificial event. Useful to generated events programmatically.
  factory DOMMouseEvent.synthetic({
    DOMTreeMap<T>? treeMap,
    Object? event,
    Object? eventTarget,
    DOMNode? target,
    Point<num>? client,
    Point<num>? offset,
    Point<num>? page,
    Point<num>? screen,
    int button = 0,
    int? buttons,
    bool altKey = false,
    bool ctrlKey = false,
    bool shiftKey = false,
    bool metaKey = false,
  }) {
    client ??= Point(0, 0);

    return DOMMouseEvent(
        treeMap ?? DOMTreeMapDummy(DOMGeneratorDummy()),
        event,
        eventTarget,
        target,
        client,
        offset ?? client,
        page ?? client,
        screen ?? client,
        button,
        buttons,
        altKey,
        ctrlKey,
        shiftKey,
        metaKey);
  }

  @override
  bool cancel({bool stopImmediatePropagation = false}) => domGenerator
      .cancelEvent(event, stopImmediatePropagation: stopImmediatePropagation);
}

//
// ExternalElementNode:
//

/// Class wrapper for a external element as a [DOMNode].
class ExternalElementNode extends DOMNode {
  final Object? externalElement;

  ExternalElementNode(this.externalElement, [bool? allowContent])
      : super._(allowContent, false);

  @override
  String buildHTML(
      {bool withIndent = false,
      String parentIndent = '',
      String indent = '  ',
      bool disableIndent = false,
      bool xhtml = false,
      DSXResolution dsxResolution = DSXResolution.skipDSX,
      bool buildTemplates = false,
      DOMNode? parentNode,
      DOMNode? previousNode,
      DOMContext? domContext}) {
    final externalElement = this.externalElement;
    if (externalElement == null) return '';

    if (externalElement is String) {
      return externalElement;
    } else if (externalElement is DOMElementGenerator) {
      var element = externalElement(parentNode);
      return element != null ? '$element' : '';
    } else if (externalElement is DOMElementGeneratorFunction) {
      var element = externalElement();
      return element != null ? '$element' : '';
    } else {
      return '$externalElement';
    }
  }

  @override
  ExternalElementNode copy() {
    return ExternalElementNode(externalElement, allowContent);
  }

  @override
  String toString() => 'ExternalElementNode@$externalElement';
}

//
// DIVElement:
//

/// Class for a `div` element.
class DIVElement extends DOMElement {
  static DIVElement? from(Object? entry) {
    if (entry == null) return null;
    if (_domHTML.isHtmlNode(entry)) {
      entry = _domHTML.toDOMNode(entry);
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
      {Map<String, dynamic>? attributes,
      Object? id,
      Object? classes,
      Object? style,
      Object? content,
      bool? hidden,
      bool commented = false})
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

class INPUTElement extends DOMElement with WithValue {
  static INPUTElement? from(Object? entry) {
    if (entry == null) return null;
    if (_domHTML.isHtmlNode(entry)) {
      entry = _domHTML.toDOMNode(entry);
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
      {Map<String, dynamic>? attributes,
      Object? id,
      Object? name,
      Object? type,
      Object? placeholder,
      Object? classes,
      Object? style,
      Object? value,
      bool? hidden,
      bool disabled = false,
      bool commented = false})
      : super._('input',
            id: id,
            classes: classes,
            style: style,
            attributes: {
              if (name != null) 'name': name,
              if (type != null) 'type': type,
              if (placeholder != null) 'placeholder': placeholder,
              if (value != null) 'value': value,
              if (disabled) 'disabled': disabled,
              ...?attributes
            },
            hidden: hidden,
            commented: commented);

  @override
  INPUTElement copy() {
    return INPUTElement(attributes: attributes, commented: isCommented);
  }

  @override
  bool get hasValue {
    var value = this.value;
    return value != null && value.isNotEmpty;
  }

  @override
  String? get value => getAttributeValue('value');
}

//
// CHECKBOXElement:
//

class CHECKBOXElement extends INPUTElement with WithValue {
  static CHECKBOXElement? from(Object? entry) {
    if (entry == null) return null;
    if (_domHTML.isHtmlNode(entry)) {
      entry = _domHTML.toDOMNode(entry);
    }

    if (entry is CHECKBOXElement) return entry;

    if (entry is DOMElement) {
      _checkTag('input', entry);
      return CHECKBOXElement(
          attributes: entry._attributes,
          value: entry.value,
          commented: entry.isCommented);
    }

    return null;
  }

  CHECKBOXElement(
      {Map<String, dynamic>? attributes,
      super.id,
      Object? name,
      Object? type,
      Object? placeholder,
      super.classes,
      super.style,
      Object? value,
      bool? checked,
      super.hidden,
      bool disabled = false,
      super.commented})
      : super(attributes: {
          if (name != null) 'name': name,
          'type': 'checkbox',
          if (placeholder != null) 'placeholder': placeholder,
          if (value != null) 'value': value,
          if (checked != null) 'checked': checked,
          if (disabled) 'disabled': disabled,
          ...?attributes
        });

  @override
  CHECKBOXElement copy() {
    return CHECKBOXElement(attributes: attributes, commented: isCommented);
  }

  @override
  bool get hasValue {
    var value = this.value;
    return value != null && value.isNotEmpty;
  }

  @override
  String? get value => getAttributeValue('value');

  /// Returns `true` if the checkbox is checked.
  bool? get checked => getAttributeValueAsBool('checked');
}

//
// SELECTElement:
//

class SELECTElement extends DOMElement {
  static SELECTElement? from(Object? entry) {
    if (entry == null) return null;
    if (_domHTML.isHtmlNode(entry)) {
      entry = _domHTML.toDOMNode(entry);
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
      {Map<String, dynamic>? attributes,
      Object? id,
      Object? name,
      Object? type,
      Object? classes,
      Object? style,
      Object? options,
      bool? multiple,
      bool? hidden,
      bool disabled = false,
      bool commented = false})
      : super._('select',
            id: id,
            classes: classes,
            style: style,
            attributes: {
              ...?attributes,
              if (name != null) 'name': name,
              if (type != null) 'type': type,
              if (multiple != null && multiple) 'multiple': true,
              if (disabled) 'disabled': disabled,
            },
            content: OPTIONElement.toOptions(options),
            hidden: hidden,
            commented: commented);

  @override
  SELECTElement copy() {
    return SELECTElement(
        attributes: attributes, options: content, commented: isCommented);
  }

  bool get hasOptions => isNotEmptyContent;

  List<OPTIONElement> get options =>
      content?.whereType<OPTIONElement>().toList() ?? [];

  void addOption(Object? option) => add(OPTIONElement.from(option));

  void addOptions(Object? options) => addAll(OPTIONElement.toOptions(options));

  OPTIONElement? getOption(Object? option) {
    if (option == null) return null;
    if (option is OPTIONElement) {
      return getOptionByValue(option.value);
    }
    return getOptionByValue(option.toString());
  }

  OPTIONElement? getOptionByValue(Object? value) {
    if (value == null) return null;
    return options.firstWhereOrNull((e) => e.value == value);
  }

  OPTIONElement? getOptionByIndex(int index) {
    return index < options.length ? options[index] : null;
  }

  OPTIONElement? get selectedOption =>
      content?.whereType<OPTIONElement>().firstWhereOrNull((e) => e.selected);

  String? get selectedValue => selectedOption?.value;

  bool get hasSelection => selectedOption != null;

  void unselectAllOptions() {
    for (var opt in options) {
      opt.selected = false;
    }
  }

  OPTIONElement? selectOption(Object? option, [bool selected = true]) {
    var elem = getOption(option);

    if (elem != null) {
      elem.selected = selected;
      return elem;
    }

    return null;
  }
}

//
// OPTIONElement:
//

class OPTIONElement extends DOMElement with WithValue {
  static List<OPTIONElement> toOptions(Object? options) {
    if (options == null) return [];
    if (options is OPTIONElement) return [options];

    if (options is Map) {
      return options.entries
          .map(OPTIONElement.from)
          .whereType<OPTIONElement>()
          .toList();
    } else if (options is Iterable) {
      return options
          .map(OPTIONElement.from)
          .whereType<OPTIONElement>()
          .toList();
    } else {
      return [
        OPTIONElement.from(options) ??
            (throw ArgumentError(
                "Can't instantiate `OPTIONElement` from: $options"))
      ];
    }
  }

  static OPTIONElement? from(Object? entry) {
    if (entry == null) return null;

    if (_domHTML.isHtmlNode(entry)) {
      entry = _domHTML.toDOMNode(entry);
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

    Object? value;
    Object? text;

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
      entry = entry.asList;
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

    if ((valueStr != null && valueStr.trim().isNotEmpty) ||
        (textStr != null && textStr.trim().isNotEmpty)) {
      return OPTIONElement(
        value: valueStr,
        text: textStr,
      );
    }

    return null;
  }

  OPTIONElement(
      {Map<String, dynamic>? attributes,
      Object? classes,
      Object? style,
      Object? value,
      String? label,
      bool? selected,
      bool disabled = false,
      String? text})
      : super._(
          'option',
          classes: classes,
          style: style,
          attributes: {
            ...?attributes,
            if (value != null) 'value': parseString(value),
            if (label != null) 'label': label,
            if (selected != null) 'selected': parseBool(selected),
            if (disabled) 'disabled': disabled,
          },
          content: TextNode.toTextNode(text),
        );

  @override
  OPTIONElement copy() {
    return OPTIONElement(
      attributes: attributes,
      text: text,
    );
  }

  @override
  bool get hasValue {
    var value = this.value;
    return value != null && value.isNotEmpty;
  }

  @override
  String? get value => getAttributeValue('value');

  set value(String? val) => setAttribute('value', val);

  String? get label => getAttributeValue('label');

  set label(String? label) => setAttribute('label', label);

  bool get selected => getAttributeValueAsBool('selected');

  set selected(bool sel) {
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

class TEXTAREAElement extends DOMElement with WithValue {
  static TEXTAREAElement? from(Object? entry) {
    if (entry == null) return null;
    if (_domHTML.isHtmlNode(entry)) {
      entry = _domHTML.toDOMNode(entry);
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
      {Map<String, dynamic>? attributes,
      Object? id,
      Object? name,
      Object? classes,
      Object? style,
      Object? cols,
      Object? rows,
      Object? content,
      bool? hidden,
      bool disabled = false,
      bool commented = false})
      : super._('textarea',
            id: id,
            classes: classes,
            style: style,
            attributes: {
              if (name != null) 'name': name,
              if (cols != null) 'cols': cols,
              if (rows != null) 'rows': rows,
              if (disabled) 'disabled': disabled,
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
  bool get hasValue {
    var value = this.value;
    return value != null && value.isNotEmpty;
  }

  @override
  String? get value => getAttributeValue('value');
}

//
// TABLEElement:
//

CAPTIONElement? createTableCaption(Object? caption) {
  var nodes = DOMNode.parseNodes(caption);
  if (nodes.isNotEmpty) {
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
    {bool? header, bool? footer}) {
  if (content == null) {
    return [
      createTableCaption(caption),
      createTableEntry(head, header: true),
      createTableEntry(body),
      createTableEntry(foot, footer: true)
    ];
  }

  if (content is Iterable) {
    content = content.asList;
  }

  if (content is List) {
    if (listMatchesAll(content, (dynamic e) => _domHTML.isHtmlNode(e))) {
      var caption = content.firstWhere(
          (e) => _domHTML.getNodeTag(e) == 'caption',
          orElse: () => null);
      var thread = content.firstWhere((e) => _domHTML.getNodeTag(e) == 'thead',
          orElse: () => null);
      var tfoot = content.firstWhere((e) => _domHTML.getNodeTag(e) == 'tfoot',
          orElse: () => null);
      var tbody = content.firstWhere((e) => _domHTML.getNodeTag(e) == 'tbody',
          orElse: () => null);

      var list = <DOMNode?>[
        DOMNode.from(caption),
        DOMNode.from(thread),
        DOMNode.from(tbody),
        DOMNode.from(tfoot)
      ].nonNulls.toList();

      return list;
    } else {
      return content.map((e) => createTableEntry(e)).toList();
    }
  } else {
    return [createTableEntry(body)];
  }
}

TABLENode? createTableEntry(Object? entry, {bool? header, bool? footer}) {
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
  } else if (_domHTML.isHtmlElementNode(entry)) {
    return _domHTML.toDOMElement(entry) as TABLENode?;
  } else if (_domHTML.isHtmlTextNode(entry)) {
    var domNode = _domHTML.toTextNode(entry);
    return domNode != null ? TDElement(content: domNode.text) : null;
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

List<TRowElement> createTableRows(Object? rows, bool header) {
  List<TRowElement> tableRows;

  if (rows is Iterable) {
    var rowsList = rows.toList();

    if (listMatchesAll(rowsList, (dynamic e) => e is TRowElement)) {
      return rowsList.whereType<TRowElement>().toList();
    } else if (listMatchesAll(
        rowsList, (dynamic e) => _domHTML.isHtmlNode(e))) {
      var trList = rowsList.where((e) => _domHTML.getNodeTag(e) == 'tr');
      var list =
          trList.map((e) => DOMNode.from(e)).whereType<TRowElement>().toList();
      return list;
    } else if (listMatchesAll(rowsList, (dynamic e) => e is MapEntry)) {
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

TRowElement createTableRow(Object? rowCells, [bool? header]) {
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

List<TABLENode> createTableCells(Object? rowCells, [bool header = false]) {
  if (rowCells is Iterable) {
    rowCells = rowCells.asList;
  }

  if (rowCells is List) {
    if (listMatchesAll(
        rowCells,
        (dynamic e) =>
            (!header && e is TDElement) || (header && e is THElement))) {
      return rowCells.whereType<TABLENode>().toList();
    } else if (listMatchesAll(
        rowCells, (dynamic e) => _domHTML.isHtmlNode(e))) {
      var tdList = rowCells.where((e) {
        var tag = _domHTML.getNodeTag(e);
        return (tag == 'td' || tag == 'th');
      });
      var list = tdList
          .map((e) => DOMNode.from(e))
          .nonNulls
          .whereType<TABLENode>()
          .toList();
      return list;
    }
  } else if (rowCells is TDElement || rowCells is THElement) {
    return [rowCells as TABLENode];
  }

  if (rowCells != null && rowCells is! Iterable) {
    rowCells = [rowCells];
  }

  List list;
  if (header) {
    list = $tags('th', rowCells as Iterable?);
  } else {
    list = $tags('td', rowCells as Iterable?);
  }

  return list.cast<TABLENode>().toList();
}

abstract class TABLENode extends DOMElement {
  TABLENode._(super.tag,
      {super.attributes,
      super.id,
      super.classes,
      super.style,
      super.content,
      super.hidden,
      super.commented})
      : super._();

  @override
  TABLENode copy() {
    return super.copy() as TABLENode;
  }
}

class TABLEElement extends DOMElement {
  static TABLEElement? from(Object? entry) {
    if (entry == null) return null;
    if (_domHTML.isHtmlNode(entry)) {
      entry = _domHTML.toDOMNode(entry);
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
      {Map<String, dynamic>? attributes,
      Object? id,
      Object? classes,
      Object? style,
      Object? caption,
      Object? head,
      Object? body,
      Object? foot,
      Object? content,
      bool? hidden,
      bool commented = false})
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
  static THEADElement? from(Object? entry) {
    if (entry == null) return null;
    if (_domHTML.isHtmlNode(entry)) {
      entry = _domHTML.toDOMNode(entry);
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
      {Map<String, dynamic>? attributes,
      Object? id,
      Object? classes,
      Object? style,
      Object? rows,
      bool? hidden,
      bool commented = false})
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
  static CAPTIONElement? from(Object? entry) {
    if (entry == null) return null;
    if (_domHTML.isHtmlNode(entry)) {
      entry = _domHTML.toDOMNode(entry);
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
      {Map<String, dynamic>? attributes,
      Object? id,
      Object? classes,
      Object? style,
      Object? content,
      bool? hidden,
      bool commented = false})
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
  static TBODYElement? from(Object? entry) {
    if (entry == null) return null;
    if (_domHTML.isHtmlNode(entry)) {
      entry = _domHTML.toDOMNode(entry);
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
      {Map<String, dynamic>? attributes,
      Object? id,
      Object? classes,
      Object? style,
      Object? rows,
      bool? hidden,
      bool commented = false})
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
  static TFOOTElement? from(Object? entry) {
    if (entry == null) return null;
    if (_domHTML.isHtmlNode(entry)) {
      entry = _domHTML.toDOMNode(entry);
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
      {Map<String, dynamic>? attributes,
      Object? id,
      Object? classes,
      Object? style,
      Object? rows,
      bool? hidden,
      bool commented = false})
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
  static TRowElement? from(Object? entry) {
    if (entry == null) return null;
    if (_domHTML.isHtmlNode(entry)) {
      entry = _domHTML.toDOMNode(entry);
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
      {Map<String, dynamic>? attributes,
      Object? id,
      Object? classes,
      Object? style,
      Object? cells,
      bool headerRow = false,
      bool? hidden,
      bool commented = false})
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
  static THElement? from(Object? entry) {
    if (entry == null) return null;
    if (_domHTML.isHtmlNode(entry)) {
      entry = _domHTML.toDOMNode(entry);
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
      {Map<String, dynamic>? attributes,
      Object? id,
      Object? classes,
      Object? style,
      Object? content,
      bool? hidden,
      bool commented = false})
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
  static TDElement? from(Object? entry) {
    if (entry == null) return null;
    if (_domHTML.isHtmlNode(entry)) {
      entry = _domHTML.toDOMNode(entry);
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
      {Map<String, dynamic>? attributes,
      Object? id,
      Object? classes,
      Object? style,
      Object? content,
      bool? hidden,
      bool commented = false})
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
  final Future? future;

  /// A [Function] that returns the [Future] that defines this node content.
  final Future Function()? function;

  /// Content to be showed while [future]/[function] is being executed.
  final Object? loading;

  DOMAsync({this.loading, this.future, this.function}) : super._(false, false);

  DOMAsync.future(Future future, [Object? loading])
      : this(future: future, loading: loading);

  DOMAsync.function(Future Function() function, [Object? loading])
      : this(function: function, loading: loading);

  Future? _resolvedFuture;

  /// Resolves the actual [Future] that will define this node content.
  Future? get resolveFuture {
    if (_resolvedFuture != null) return _resolvedFuture;

    final future = this.future;
    if (future != null) {
      _resolvedFuture = future;
    } else {
      final function = this.function;
      if (function != null) {
        _resolvedFuture = function();
      } else {
        throw StateError("Can't resolve Future: null `future` and `function`!");
      }
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

extension _IterableExtension<T> on Iterable<T> {
  List<T> get asList {
    var self = this;
    if (self is List<T>) {
      return self;
    } else {
      return toList();
    }
  }
}
