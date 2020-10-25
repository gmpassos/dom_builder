import 'package:dom_builder/dom_builder.dart';
import 'package:swiss_knife/swiss_knife.dart';

import 'dom_builder_attribute.dart';
import 'dom_builder_base.dart';
import 'dom_builder_context.dart';
import 'dom_builder_generator_none.dart'
    if (dart.library.html) 'dom_builder_generator_dart_html.dart';
import 'dom_builder_runtime.dart';
import 'dom_builder_treemap.dart';

typedef DOMElementGenerator<T> = T Function(dynamic parent);
typedef DOMElementGeneratorFunction<T> = T Function();

/// Basic class for DOM elements generators.
abstract class DOMGenerator<T> {
  static DOMGeneratorDartHTML _dartHTML;

  static DOMGeneratorDartHTML<T> dartHTML<T>() {
    _dartHTML ??= createDOMGeneratorDartHTML();
    return _dartHTML as DOMGeneratorDartHTML<T>;
  }

  DOMActionExecutor<T> _domActionExecutor;

  DOMActionExecutor<T> get domActionExecutor => _domActionExecutor;

  set domActionExecutor(DOMActionExecutor<T> value) {
    _domActionExecutor = value;
    if (_domActionExecutor != null) {
      _domActionExecutor.domGenerator = this;
    }
  }

  DOMContext<T> _domContext;

  DOMContext<T> get domContext => _domContext;

  set domContext(DOMContext<T> value) {
    _domContext = value;
    if (_domContext != null) {
      _domContext.domGenerator = this;
    }
  }

  Viewport get viewport => _domContext?.viewport;

  bool isEquivalentNode(DOMNode domNode, T node) {
    if (!isEquivalentNodeType(domNode, node)) {
      return false;
    }

    if (domNode is TextNode) {
      return domNode.text == getNodeText(node);
    }

    throw UnsupportedError(
        "Can't determine node equivalency: $domNode == $node");
  }

  bool isEquivalentNodeType(DOMNode domNode, T node) {
    if (domNode is TextNode && isTextNode(node)) {
      return true;
    } else {
      throw UnsupportedError(
          "Can't determine type equivalency: $domNode == $node");
    }
  }

  final Set<String> _ignoreAttributeEquivalence = {};

  bool isIgnoreAttributeEquivalence(String attributeName) {
    return _ignoreAttributeEquivalence.contains(attributeName);
  }

  void ignoreAttributeEquivalence(String attributeName) {
    _ignoreAttributeEquivalence.add(attributeName);
  }

  List<String> getIgnoredAttributesEquivalence() =>
      List.from(_ignoreAttributeEquivalence);

  void clearIgnoredAttributesEquivalence() =>
      _ignoreAttributeEquivalence.clear();

  bool removeIgnoredAttributeEquivalence(String attributeName) {
    return _ignoreAttributeEquivalence.remove(attributeName);
  }

  T getNodeParent(T node) {
    throw UnsupportedError("Can't get element parent: $node");
  }

  List<T> getElementNodes(T element) {
    throw UnsupportedError("Can't get element nodes: $element");
  }

  String getElementTag(T element) {
    throw UnsupportedError("Can't get element tag: $element");
  }

  String getElementOuterHTML(T element) {
    throw UnsupportedError("Can't get element outerHTML: $element");
  }

  Map<String, String> getElementAttributes(T element) {
    throw UnsupportedError("Can't get element attributes: $element");
  }

  Map<String, String> revertElementAttributes(
      T element, Map<String, String> attributes) {
    return attributes;
  }

  /// Generates an element [T] using [root].
  ///
  /// [treeMap] Tree to populate. If [null] calls [createGenericDOMTreeMap] to define [DOMTreeMap] instance.
  /// [context] Optional context for this generated tree.
  /// [parent] Optional parent to add the generated element.
  /// [finalizeTree] Default [true]: calls [finalizeGeneratedTree].
  T generate(DOMNode root,
      {DOMTreeMap<T> treeMap,
      T parent,
      DOMContext<T> context,
      bool finalizeTree = true,
      bool setTreeMapRoot = true}) {
    treeMap ??= createGenericDOMTreeMap();
    context ??= _domContext;
    setTreeMapRoot ??= true;

    if (setTreeMapRoot) {
      treeMap.setRoot(root, null);
    }

    var rootElement = build(null, parent, root, treeMap, context);

    if (setTreeMapRoot) {
      treeMap.setRoot(root, rootElement);
    }

    _callFinalizeGeneratedTree(treeMap, context, finalizeTree);

    return rootElement;
  }

  /// Same as [generate], but generates [nodes] inside a preexistent [rootElement].
  T generateWithRoot(DOMElement domRoot, T rootElement, List<DOMNode> nodes,
      {DOMTreeMap<T> treeMap,
      T rootParent,
      DOMContext<T> context,
      bool finalizeTree = true,
      bool setTreeMapRoot = true}) {
    treeMap ??= createGenericDOMTreeMap();
    context ??= _domContext;
    setTreeMapRoot ??= true;

    if (rootElement == null && domRoot != null) {
      rootElement = treeMap.getMappedElement(domRoot);
      rootElement ??= build(null, null, domRoot, treeMap, context);
    }

    domRoot ??= treeMap.getMappedDOMNode(rootElement);

    if (rootParent != null) {
      addChildToElement(rootParent, rootElement);
    }

    for (var node in nodes) {
      build(domRoot, rootElement, node, treeMap, context);
    }

    if (domRoot != null && setTreeMapRoot) {
      treeMap.setRoot(domRoot, rootElement);
    }

    _callFinalizeGeneratedTree(treeMap, context, finalizeTree);

    return rootElement;
  }

  /// Same as [generate], but parses [htmlRoot] first.
  T generateFromHTML(String htmlRoot,
      {DOMTreeMap<T> treeMap,
      DOMElement domParent,
      T parent,
      DOMContext<T> context,
      bool finalizeTree = true}) {
    var root = $htmlRoot(htmlRoot,
        defaultTagDisplayInlineBlock: false,
        defaultRootTag: parent != null ? 'dom-builder-html-root' : null);

    if (root.tag == 'dom-builder-html-root') {
      var rootParent = parent != null ? getNodeParent(parent) : null;

      return generateWithRoot(domParent, parent, root.content,
          treeMap: treeMap,
          rootParent: rootParent,
          context: context,
          finalizeTree: finalizeTree);
    } else {
      return generate(root,
          treeMap: treeMap,
          parent: parent,
          context: context,
          finalizeTree: finalizeTree);
    }
  }

  DOMTreeMap<T> createDOMTreeMap() => DOMTreeMap<T>(this);

  DOMTreeMap<T> createGenericDOMTreeMap() => DOMTreeMapDummy<T>(this);

  /// Same as [generate], but returns a [DOMTreeMap], that contains all
  /// mapping table fo generated elements.
  DOMTreeMap<T> generateMapped(DOMElement root,
      {T parent, DOMContext<T> context}) {
    var treeMap = createDOMTreeMap();
    treeMap.generate(this, root, parent: parent, context: context);
    return treeMap;
  }

  List<T> generateNodes(List<DOMNode> nodes, {DOMContext<T> context}) {
    context ??= _domContext;
    return buildNodes(null, null, nodes, createGenericDOMTreeMap(), context);
  }

  List<T> buildNodes(DOMElement domParent, T parent, List<DOMNode> domNodes,
      DOMTreeMap<T> treeMap, DOMContext<T> context) {
    if (domNodes == null || domNodes.isEmpty) return [];

    var elements = <T>[];

    for (var node in domNodes) {
      var element = build(domParent, parent, node, treeMap, context);
      if (element != null) {
        elements.add(element);
      }
    }

    return elements;
  }

  String buildElementHTML(T element);

  T build(DOMElement domParent, T parent, DOMNode domNode,
      DOMTreeMap<T> treeMap, DOMContext<T> context) {
    if (domParent != null) {
      domNode.parent = domParent;
    }

    if (domNode.isCommented) return null;

    if (domNode is DOMElement) {
      return buildElement(domParent, parent, domNode, treeMap, context);
    } else if (domNode is TextNode) {
      return buildText(domParent, parent, domNode, treeMap);
    } else if (domNode is ExternalElementNode) {
      return buildExternalElement(domParent, parent, domNode, treeMap, context);
    } else {
      throw StateError("Can't build node of type: ${domNode.runtimeType}");
    }
  }

  T buildText(
      DOMElement domParent, T parent, TextNode domNode, DOMTreeMap<T> treeMap) {
    if (domParent != null) {
      domNode.parent = domParent;
    }

    var text = getDOMNodeText(domNode);

    T textNode;
    if (parent != null) {
      textNode = appendElementText(parent, text);
    } else {
      textNode = createTextNode(text);
    }

    if (textNode != null) {
      treeMap.map(domNode, textNode);
    }

    return textNode;
  }

  String getDOMNodeText(TextNode domNode) {
    return domNode.text;
  }

  String getNodeText(T node);

  T appendElementText(T element, String text);

  T buildElement(DOMElement domParent, T parent, DOMElement domElement,
      DOMTreeMap<T> treeMap, DOMContext<T> context) {
    if (domParent != null) {
      domElement.parent = domParent;
    }

    var element = createWithRegisteredElementGenerator(
        domParent, parent, domElement, treeMap, context);

    if (element == null) {
      if (_domContext != null) {
        element = _domContext.resolveNamedElement(
            domParent, parent, domElement, treeMap);
        element ??= createElement(domElement.tag);
      } else {
        element = createElement(domElement.tag);
      }

      if (element == null) {
        throw StateError("Can't create element for tag: ${domElement.tag}");
      }

      if (parent != null) {
        addChildToElement(parent, element);
      }

      treeMap.map(domElement, element);
      _callOnElementCreated(treeMap, domElement, element, context);

      setAttributes(domElement, element,
          preserveClass: true, preserveStyle: true);

      var length = domElement.length;

      for (var i = 0; i < length; i++) {
        var node = domElement.nodeByIndex(i);
        build(domElement, element, node, treeMap, context);
      }
    } else if (parent != null) {
      addChildToElement(parent, element);
    }

    domElement.notifyElementGenerated(element);

    return element;
  }

  void _callOnElementCreated(DOMTreeMap<T> treeMap, DOMNode domElement,
      T element, DOMContext<T> context) {
    if (context != null && context.onPreElementCreated != null) {
      context.onPreElementCreated(treeMap, domElement, element, context);
    }

    onElementCreated(treeMap, domElement, element, context);
  }

  void onElementCreated(DOMTreeMap<T> treeMap, DOMNode domElement, T element,
      DOMContext<T> context) {}

  T buildExternalElement(
      DOMElement domParent,
      T parent,
      ExternalElementNode domElement,
      DOMTreeMap<T> treeMap,
      DOMContext<T> context) {
    if (domParent != null) {
      domElement.parent = domParent;
    }

    var externalElement = domElement.externalElement;

    if (!canHandleExternalElement(externalElement)) {
      var parsedElement = _parseExternalElement(
          domParent, parent, domElement, externalElement, treeMap, context);
      if (parsedElement != null) {
        if (parent != null && !containsNode(parent, parsedElement)) {
          addChildToElement(parent, parsedElement);
        }

        domElement.notifyElementGenerated(parsedElement);

        return parsedElement;
      }
    }

    if (parent != null) {
      var children = addExternalElementToElement(parent, externalElement);
      if (isEmptyObject(children)) return null;
      var node = children.first;
      treeMap.map(domElement, node);

      domElement.notifyElementGenerated(node);

      return node;
    } else if (externalElement is T) {
      treeMap.map(domElement, externalElement);
      addChildToElement(parent, externalElement);

      domElement.notifyElementGenerated(externalElement);

      return externalElement;
    }

    return null;
  }

  T _parseExternalElement(
      DOMElement domParent,
      T parent,
      ExternalElementNode domElement,
      dynamic externalElement,
      DOMTreeMap<T> treeMap,
      DOMContext<T> context) {
    if (externalElement == null) return null;

    if (externalElement is T) {
      treeMap.map(domElement, externalElement);
      addChildToElement(parent, externalElement);
      return externalElement;
    } else if (externalElement is List &&
        listMatchesAll(externalElement, (e) => e is DOMNode)) {
      List<DOMNode> listNodes = externalElement;
      var elements = <T>[];
      for (var node in listNodes) {
        var element = build(domParent, parent, node, treeMap, context);
        elements.add(element);
        treeMap.map(node, element);
      }
      return elements.isEmpty ? null : elements.first;
    } else if (externalElement is DOMNode) {
      return build(domParent, parent, externalElement, treeMap, context);
    } else if (externalElement is DOMElementGenerator) {
      var element = externalElement(parent);
      return _parseExternalElement(
          domParent, parent, domElement, element, treeMap, context);
    } else if (externalElement is DOMElementGeneratorFunction) {
      var element = externalElement();
      return _parseExternalElement(
          domParent, parent, domElement, element, treeMap, context);
    } else if (externalElement is String) {
      var list = DOMNode.parseNodes(externalElement);

      if (list != null) {
        var elements = <T>[];
        for (var node in list) {
          var element = build(domParent, parent, node, treeMap, context);
          elements.add(element);
          treeMap.map(node, element);
        }
        return elements.isEmpty ? null : elements.first;
      }
    }

    return null;
  }

  void addChildToElement(T element, T child);

  void removeChildFromElement(T element, T child);

  bool canHandleExternalElement(dynamic externalElement);

  List<T> addExternalElementToElement(T element, dynamic externalElement);

  T createElement(String tag);

  T createTextNode(String text);

  bool isTextNode(T node);

  bool isElementNode(T node) => node != null && !isTextNode(node);

  bool containsNode(T parent, T node);

  void setAttributes(DOMElement domElement, T element,
      {bool preserveClass = false, bool preserveStyle = false}) {
    for (var attrName in domElement.attributesNames) {
      var attrVal = domElement.getAttributeValue(attrName, _domContext);

      if (preserveClass && attrName == 'class') {
        var prev = getAttribute(element, attrName);
        if (prev != null && prev.isNotEmpty) {
          attrVal =
              attrVal != null && attrVal.isNotEmpty ? '$prev $attrVal' : prev;
        }
      } else if (preserveStyle && attrName == 'style') {
        var prev = getAttribute(element, attrName);
        if (prev != null && prev.isNotEmpty) {
          if (!prev.endsWith(';')) prev += ';';
          attrVal =
              attrVal != null && attrVal.isNotEmpty ? '$prev $attrVal' : prev;
        }
      } else if ((attrName == 'src' || attrName == 'href') &&
          attrVal != null &&
          attrVal.isNotEmpty) {
        var attrVal2 = resolveSource(attrVal);

        if (attrVal2 != null && attrVal != attrVal2) {
          setAttribute(element, '$attrName-original', attrVal);
          attrVal = attrVal2;
        }
      }

      setAttribute(element, attrName, attrVal);
    }
  }

  /// [Function] used by [resolveSource].
  String Function(String url) sourceResolver;

  /// Resolves any source attribute.
  String resolveSource(String url) {
    if (sourceResolver != null) {
      var urlResolved = sourceResolver(url);
      if (urlResolved != null) {
        return urlResolved;
      }
    }
    return url;
  }

  void setAttribute(T element, String attrName, String attrVal);

  String getAttribute(T element, String attrName);

  final Map<String, ElementGenerator<T>> _elementsGenerators = {};

  bool isElementGeneratorTag(String tag) {
    tag = normalizeTag(tag);
    if (tag == null) return false;
    return _elementsGenerators.containsKey(tag);
  }

  Map<String, ElementGenerator<T>> get registeredElementsGenerators =>
      Map.from(_elementsGenerators);

  int get registeredElementsGeneratorsLength => _elementsGenerators.length;

  T createWithRegisteredElementGenerator(DOMElement domParent, T parent,
      DOMElement domElement, DOMTreeMap<T> treeMap, DOMContext<T> context) {
    var tag = domElement.tag;
    var generator = _elementsGenerators[tag];
    if (generator == null) return null;

    T contentHolder;
    if (generator.usesContentHolder) {
      contentHolder = createElement('div');

      if (parent != null) {
        addChildToElement(parent, contentHolder);
      }

      buildNodes(
          domElement, contentHolder, domElement.content, treeMap, context);

      if (parent != null) {
        removeChildFromElement(parent, contentHolder);
      }
    }

    var element = generator.generate(this, treeMap, tag, domParent, parent,
        domElement.domAttributes, contentHolder, domElement.content);

    treeMap.mapTree(domElement, element);

    _callOnElementCreated(treeMap, domElement, element, context);

    return element;
  }

  bool registerElementGenerator(ElementGenerator<T> elementGenerator) {
    if (elementGenerator == null) return false;
    var tag = elementGenerator.tag;
    tag = normalizeTag(tag);
    if (tag == null) return false;
    _elementsGenerators[tag] = elementGenerator;
    return true;
  }

  static String normalizeTag(String tag) {
    if (tag == null) return null;
    tag = tag.toLowerCase().trim();
    return tag.isNotEmpty ? tag : null;
  }

  bool registerElementGeneratorFrom(DOMGenerator<T> otherGenerator) {
    if (otherGenerator == null) return false;
    if (otherGenerator.registeredElementsGeneratorsLength == 0) return false;
    _elementsGenerators.addAll(otherGenerator._elementsGenerators);
    return true;
  }

  void resolveActionAttribute(DOMTreeMap<T> treeMap, DOMElement domElement,
      T element, DOMContext<T> context) {
    if (_domActionExecutor == null || domElement.tag == 'form') return;

    var actionValue = domElement.getAttributeValue('action', domContext);
    if (isEmptyString(actionValue)) return;

    var domAction = _domActionExecutor.parse(actionValue);

    if (domAction != null) {
      domElement.onClick.listen((event) {
        var target = domElement.getRuntimeNode();
        domAction.execute(target, treeMap: treeMap, context: context);
      });
    }
  }

  void registerEventListeners(DOMTreeMap<T> treeMap, DOMElement domElement,
      T element, DOMContext<T> context) {}

  DOMMouseEvent createDOMMouseEvent(DOMTreeMap<T> treeMap, dynamic event) =>
      null;

  bool cancelEvent(dynamic event, {bool stopImmediatePropagation = false}) =>
      false;

  DOMNodeRuntime<T> createDOMNodeRuntime(
      DOMTreeMap<T> treeMap, DOMNode domNode, T node);

  /// Reverts [node] to a [DOMNode].
  DOMNode revert(DOMTreeMap<T> treeMap, T node) {
    return _revertImp(treeMap, null, null, node);
  }

  DOMNode _revertImp(
      DOMTreeMap<T> treeMap, DOMElement domParent, T parent, T node) {
    if (isTextNode(node)) {
      return _revert_TextNode(domParent, parent, node);
    } else if (isElementNode(node)) {
      return _revert_DOMElement(treeMap, domParent, parent, node);
    } else {
      return null;
    }
  }

  TextNode _revert_TextNode(DOMElement domParent, T parent, T node) {
    var domNode = TextNode(getNodeText(node));
    domParent.add(domNode);
    return domNode;
  }

  DOMElement _revert_DOMElement(
      DOMTreeMap<T> treeMap, DOMElement domParent, T parent, T node) {
    var tag = getElementTag(node);
    tag = normalizeTag(tag);
    if (tag == null) return null;

    DOMElement domNode;

    var generator = _elementsGenerators[tag] ??
        _elementsGenerators.values
            .firstWhere((g) => g.isGeneratedElement(node), orElse: () => null);

    var hasChildrenElements = true;

    if (generator != null) {
      domNode = generator.revert(this, treeMap, domParent, parent, node);
      hasChildrenElements = generator.hasChildrenElements;
    } else {
      var attributes = getElementAttributes(node);
      attributes = revertElementAttributes(node, attributes);
      domNode = DOMElement(tag, attributes: attributes);
    }

    if (domParent != null) {
      domParent.add(domNode);
    }

    if (hasChildrenElements) {
      var children = getElementNodes(node);

      if (children != null && children.isNotEmpty) {
        for (var child in children) {
          if (child != null) {
            _revertImp(treeMap, domNode, node, child);
          }
        }
      }
    }

    return domNode;
  }

  /// Resets instances and generated tree.
  void reset() {
    _generatedHTMLTrees.clear();
  }

  bool populateGeneratedHTMLTrees = false;

  final List<String> _generatedHTMLTrees = [];

  List<String> get generatedHTMLTrees => List.from(_generatedHTMLTrees);

  void _callFinalizeGeneratedTree(
      DOMTreeMap<T> treeMap, DOMContext<T> context, bool finalizeTree) {
    if (finalizeTree ?? true) {
      var rootElement = treeMap.rootElement;

      if (rootElement != null && (populateGeneratedHTMLTrees ?? false)) {
        var html = getElementOuterHTML(rootElement);
        _generatedHTMLTrees.add(html);
      }

      if (context != null && context.preFinalizeGeneratedTree != null) {
        context.preFinalizeGeneratedTree(treeMap);
      }

      finalizeGeneratedTree(treeMap);
    }
  }

  void finalizeGeneratedTree(DOMTreeMap<T> treeMap) {}
}

abstract class ElementGenerator<T> {
  String get tag;

  /// If [true] indicated that this generated element has children nodes.
  bool get hasChildrenElements => true;

  /// If [true] will use a `div` as a content holder, with already
  /// generated content to be passed to [generate] call.
  bool get usesContentHolder => true;

  T generate(
      DOMGenerator<T> domGenerator,
      DOMTreeMap<T> treeMap,
      String tag,
      DOMElement domParent,
      T parent,
      Map<String, DOMAttribute> attributes,
      T contentHolder,
      List<DOMNode> contentNodes);

  DOMElement revert(DOMGenerator<T> domGenerator, DOMTreeMap<T> treeMap,
      DOMElement domParent, T parent, T node);

  bool isGeneratedElement(T element) => false;
}

typedef ElementGeneratorFunction<T> = T Function(
    DOMGenerator<T> domGenerator,
    String tag,
    T parent,
    Map<String, DOMAttribute> attributes,
    T contentHolder,
    List<DOMNode> contentNodes);

typedef ElementRevertFunction<T> = DOMElement Function(
    DOMGenerator<T> domGenerator,
    DOMTreeMap<T> treeMap,
    DOMElement domParent,
    T parent,
    T node);

typedef ElementGeneratedMatchingFunction<T> = bool Function(T element);

class ElementGeneratorFunctions<T> extends ElementGenerator<T> {
  @override
  final String tag;
  final ElementGeneratorFunction<T> generator;
  final ElementRevertFunction<T> reverter;
  final ElementGeneratedMatchingFunction elementMatcher;

  @override
  final bool hasChildrenElements;

  @override
  final bool usesContentHolder;

  ElementGeneratorFunctions(this.tag, this.generator,
      {this.reverter,
      this.elementMatcher,
      bool hasChildrenElements,
      bool usesContentHolder})
      : hasChildrenElements = hasChildrenElements ?? true,
        usesContentHolder = usesContentHolder ?? true;

  @override
  T generate(
      DOMGenerator<T> domGenerator,
      DOMTreeMap<T> treeMap,
      String tag,
      DOMElement domParent,
      T parent,
      Map<String, DOMAttribute> attributes,
      T contentHolder,
      List<DOMNode> contentNodes) {
    return generator(
        domGenerator, tag, parent, attributes, contentHolder, contentNodes);
  }

  @override
  DOMElement revert(DOMGenerator<T> domGenerator, DOMTreeMap<T> treeMap,
      DOMElement domParent, T parent, T node) {
    return reverter(domGenerator, treeMap, domParent, parent, node);
  }
}

abstract class DOMGeneratorDartHTML<T> extends DOMGenerator<T> {}

/// Delegates operations to another [DOMGenerator].
class DOMGeneratorDelegate<T> implements DOMGenerator<T> {
  final DOMGenerator<T> domGenerator;

  DOMGeneratorDelegate(this.domGenerator);

  @override
  void reset() => domGenerator.reset();

  @override
  void addChildToElement(T element, T child) =>
      domGenerator.addChildToElement(element, child);

  @override
  List<T> addExternalElementToElement(T element, externalElement) =>
      domGenerator.addExternalElementToElement(element, externalElement);

  @override
  T appendElementText(T element, String text) =>
      domGenerator.appendElementText(element, text);

  @override
  String buildElementHTML(T element) => domGenerator.buildElementHTML(element);

  @override
  bool canHandleExternalElement(externalElement) =>
      domGenerator.canHandleExternalElement(externalElement);

  @override
  bool containsNode(T parent, T node) =>
      domGenerator.containsNode(parent, node);

  @override
  DOMNodeRuntime<T> createDOMNodeRuntime(
          DOMTreeMap<T> treeMap, DOMNode domNode, T node) =>
      domGenerator.createDOMNodeRuntime(treeMap, domNode, node);

  @override
  T createElement(String tag) => domGenerator.createElement(tag);

  @override
  T createTextNode(String text) => domGenerator.createTextNode(text);

  @override
  String getAttribute(T element, String attrName) =>
      domGenerator.getAttribute(element, attrName);

  @override
  String getNodeText(T node) => domGenerator.getNodeText(node);

  @override
  bool isTextNode(T node) => domGenerator.isTextNode(node);

  @override
  void removeChildFromElement(T element, T child) =>
      domGenerator.removeChildFromElement(element, child);

  @override
  void setAttribute(T element, String attrName, String attrVal) =>
      domGenerator.setAttribute(element, attrName, attrVal);

  @override
  void onElementCreated(DOMTreeMap<T> treeMap, DOMNode domElement, T element,
          DOMContext<T> context) =>
      domGenerator.onElementCreated(treeMap, domElement, element, context);

  @override
  void resolveActionAttribute(DOMTreeMap<T> treeMap, DOMElement domElement,
      T element, DOMContext<T> context) {
    domGenerator.resolveActionAttribute(treeMap, domElement, element, context);
  }

  @override
  void registerEventListeners(DOMTreeMap<T> treeMap, DOMElement domElement,
          T element, DOMContext<T> context) =>
      domGenerator.registerEventListeners(
          treeMap, domElement, element, context);

  @override
  DOMMouseEvent createDOMMouseEvent(DOMTreeMap<T> treeMap, dynamic event) =>
      domGenerator.createDOMMouseEvent(treeMap, event);

  @override
  bool cancelEvent(dynamic event, {bool stopImmediatePropagation = false}) =>
      domGenerator.cancelEvent(event,
          stopImmediatePropagation: stopImmediatePropagation);

  @override
  void finalizeGeneratedTree(DOMTreeMap<T> treeMap) =>
      domGenerator.finalizeGeneratedTree(treeMap);

  @override
  Viewport get viewport => domGenerator.viewport;

  @override
  Map<String, ElementGenerator<T>> get registeredElementsGenerators =>
      domGenerator.registeredElementsGenerators;

  @override
  int get registeredElementsGeneratorsLength =>
      domGenerator.registeredElementsGeneratorsLength;

  @override
  DOMContext<T> get domContext => domGenerator.domContext;

  @override
  set domContext(DOMContext<T> value) => domGenerator.domContext = value;

  @override
  T buildElement(DOMElement domParent, T parent, DOMElement domElement,
          DOMTreeMap<T> treeMap, DOMContext<T> context) =>
      domGenerator.buildElement(
          domParent, parent, domElement, treeMap, context);

  @override
  List<T> buildNodes(DOMElement domParent, T parent, List<DOMNode> domNodes,
          DOMTreeMap<T> treeMap, DOMContext<T> context) =>
      domGenerator.buildNodes(domParent, parent, domNodes, treeMap, context);

  @override
  void _callFinalizeGeneratedTree(
          DOMTreeMap<T> treeMap, DOMContext<T> context, bool finalizeTree) =>
      domGenerator._callFinalizeGeneratedTree(treeMap, context, finalizeTree);

  @override
  void _callOnElementCreated(DOMTreeMap<T> treeMap, DOMNode domElement,
          T element, DOMContext<T> context) =>
      domGenerator._callOnElementCreated(treeMap, domElement, element, context);

  @override
  Map<String, ElementGenerator<T>> get _elementsGenerators =>
      domGenerator._elementsGenerators;

  @override
  Set<String> get _ignoreAttributeEquivalence =>
      domGenerator._ignoreAttributeEquivalence;

  @override
  T _parseExternalElement(
          DOMElement domParent,
          T parent,
          ExternalElementNode domElement,
          externalElement,
          DOMTreeMap<T> treeMap,
          DOMContext<T> context) =>
      domGenerator._parseExternalElement(
          domParent, parent, domElement, externalElement, treeMap, context);

  @override
  DOMNode _revertImp(
          DOMTreeMap<T> treeMap, DOMElement domParent, T parent, T node) =>
      domGenerator._revertImp(treeMap, domParent, parent, node);

  @override
  DOMElement _revert_DOMElement(
          DOMTreeMap<T> treeMap, DOMElement domParent, T parent, T node) =>
      domGenerator._revert_DOMElement(treeMap, domParent, parent, node);

  @override
  TextNode _revert_TextNode(DOMElement domParent, T parent, T node) =>
      domGenerator._revert_TextNode(domParent, parent, node);

  @override
  T build(DOMElement domParent, T parent, DOMNode domNode,
          DOMTreeMap<T> treeMap, DOMContext<T> context) =>
      domGenerator.build(domParent, parent, domNode, treeMap, context);

  @override
  T buildExternalElement(
          DOMElement domParent,
          T parent,
          ExternalElementNode domElement,
          DOMTreeMap<T> treeMap,
          DOMContext<T> context) =>
      domGenerator.buildExternalElement(
          domParent, parent, domElement, treeMap, context);

  @override
  T buildText(DOMElement domParent, T parent, TextNode domNode,
          DOMTreeMap<T> treeMap) =>
      domGenerator.buildText(domParent, parent, domNode, treeMap);

  @override
  void clearIgnoredAttributesEquivalence() =>
      domGenerator.clearIgnoredAttributesEquivalence();

  @override
  DOMTreeMap<T> createDOMTreeMap() => domGenerator.createDOMTreeMap();

  @override
  DOMTreeMap<T> createGenericDOMTreeMap() =>
      domGenerator.createGenericDOMTreeMap();

  @override
  T createWithRegisteredElementGenerator(
          DOMElement domParent,
          T parent,
          DOMElement domElement,
          DOMTreeMap<T> treeMap,
          DOMContext<T> context) =>
      domGenerator.createWithRegisteredElementGenerator(
          domParent, parent, domElement, treeMap, context);

  @override
  T generate(DOMNode root,
          {DOMTreeMap<T> treeMap,
          T parent,
          DOMContext<T> context,
          bool finalizeTree = true,
          bool setTreeMapRoot = true}) =>
      domGenerator.generate(root,
          treeMap: treeMap,
          parent: parent,
          context: context,
          finalizeTree: finalizeTree,
          setTreeMapRoot: setTreeMapRoot);

  @override
  T generateFromHTML(String htmlRoot,
          {DOMTreeMap<T> treeMap,
          DOMElement domParent,
          T parent,
          DOMContext<T> context,
          bool finalizeTree = true}) =>
      domGenerator.generateFromHTML(htmlRoot,
          treeMap: treeMap,
          domParent: domParent,
          parent: parent,
          context: context,
          finalizeTree: finalizeTree);

  @override
  DOMTreeMap<T> generateMapped(DOMElement root,
          {T parent, DOMContext<T> context}) =>
      domGenerator.generateMapped(root, parent: parent, context: context);

  @override
  List<T> generateNodes(List<DOMNode> nodes, {DOMContext<T> context}) =>
      domGenerator.generateNodes(nodes, context: context);

  @override
  T generateWithRoot(DOMElement domRoot, T rootElement, List<DOMNode> nodes,
          {DOMTreeMap<T> treeMap,
          T rootParent,
          DOMContext<T> context,
          bool finalizeTree = true,
          bool setTreeMapRoot = true}) =>
      domGenerator.generateWithRoot(domRoot, rootElement, nodes,
          treeMap: treeMap,
          rootParent: rootParent,
          context: context,
          finalizeTree: finalizeTree,
          setTreeMapRoot: setTreeMapRoot);

  @override
  String getDOMNodeText(TextNode domNode) =>
      domGenerator.getDOMNodeText(domNode);

  @override
  Map<String, String> getElementAttributes(T element) =>
      domGenerator.getElementAttributes(element);

  @override
  Map<String, String> revertElementAttributes(
          T element, Map<String, String> attributes) =>
      domGenerator.revertElementAttributes(element, attributes);

  @override
  List<T> getElementNodes(T element) => domGenerator.getElementNodes(element);

  @override
  String getElementTag(T element) => domGenerator.getElementTag(element);

  @override
  String getElementOuterHTML(T element) =>
      domGenerator.getElementOuterHTML(element);

  @override
  List<String> getIgnoredAttributesEquivalence() =>
      domGenerator.getIgnoredAttributesEquivalence();

  @override
  T getNodeParent(T node) => domGenerator.getNodeParent(node);

  @override
  void ignoreAttributeEquivalence(String attributeName) =>
      domGenerator.ignoreAttributeEquivalence(attributeName);

  @override
  bool isElementGeneratorTag(String tag) =>
      domGenerator.isElementGeneratorTag(tag);

  @override
  bool isElementNode(T node) => domGenerator.isElementNode(node);

  @override
  bool isEquivalentNode(DOMNode domNode, T node) =>
      domGenerator.isEquivalentNode(domNode, node);

  @override
  bool isEquivalentNodeType(DOMNode domNode, T node) =>
      domGenerator.isEquivalentNodeType(domNode, node);

  @override
  bool isIgnoreAttributeEquivalence(String attributeName) =>
      domGenerator.isIgnoreAttributeEquivalence(attributeName);

  @override
  bool registerElementGenerator(ElementGenerator<T> elementGenerator) =>
      domGenerator.registerElementGenerator(elementGenerator);

  @override
  bool registerElementGeneratorFrom(DOMGenerator<T> otherGenerator) =>
      domGenerator.registerElementGeneratorFrom(otherGenerator);

  @override
  bool removeIgnoredAttributeEquivalence(String attributeName) =>
      domGenerator.removeIgnoredAttributeEquivalence(attributeName);

  @override
  DOMNode revert(DOMTreeMap<T> treeMap, T node) =>
      domGenerator.revert(treeMap, node);

  @override
  void setAttributes(DOMElement domElement, T element,
          {bool preserveClass = false, bool preserveStyle = false}) =>
      domGenerator.setAttributes(domElement, element,
          preserveClass: preserveClass, preserveStyle: preserveStyle);

  @override
  DOMContext<T> get _domContext => domGenerator._domContext;

  @override
  set _domContext(DOMContext<T> domContext) =>
      domGenerator._domContext = domContext;

  @override
  List<String> get _generatedHTMLTrees => domGenerator._generatedHTMLTrees;

  @override
  List<String> get generatedHTMLTrees => domGenerator.generatedHTMLTrees;

  @override
  bool get populateGeneratedHTMLTrees =>
      domGenerator.populateGeneratedHTMLTrees;

  @override
  set populateGeneratedHTMLTrees(bool populate) =>
      domGenerator.populateGeneratedHTMLTrees = populate;

  @override
  String Function(String url) get sourceResolver => domGenerator.sourceResolver;

  @override
  set sourceResolver(String Function(String url) sourceResolver) =>
      domGenerator.sourceResolver = sourceResolver;

  @override
  String resolveSource(String url) => domGenerator.resolveSource(url);

  @override
  DOMActionExecutor<T> get domActionExecutor => domGenerator.domActionExecutor;

  @override
  set domActionExecutor(DOMActionExecutor<T> value) =>
      domGenerator.domActionExecutor = value;

  @override
  DOMActionExecutor<T> get _domActionExecutor =>
      domGenerator._domActionExecutor;

  @override
  set _domActionExecutor(DOMActionExecutor<T> value) =>
      domGenerator._domActionExecutor = value;
}
