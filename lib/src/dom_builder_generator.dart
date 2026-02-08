import 'dart:async';

import 'package:collection/collection.dart' show IterableExtension;
import 'package:swiss_knife/swiss_knife.dart';

import 'dom_builder_actions.dart';
import 'dom_builder_attribute.dart';
import 'dom_builder_base.dart';
import 'dom_builder_context.dart';
import 'dom_builder_generator_none.dart'
    if (dart.library.js_interop) 'dom_builder_generator_web.dart'
    if (dart.library.html) 'dom_builder_generator_dart_html.dart';
import 'dom_builder_helpers.dart';
import 'dom_builder_runtime.dart';
import 'dom_builder_template.dart';
import 'dom_builder_treemap.dart';

typedef DOMElementGenerator<T> = T Function(Object? parent);
typedef DOMElementGeneratorFunction<T> = T Function();

/// Basic class for DOM elements generators.
abstract class DOMGenerator<T extends Object> {
  @Deprecated("Use `_web`")
  static DOMGeneratorDartHTML? _dartHTML;

  @Deprecated(
      "Use `DOMGenerator.web` with package `web`. Package `dart:html` is deprecated.")
  static DOMGeneratorDartHTML<T> dartHTML<T extends Object>() {
    _dartHTML ??= createDOMGeneratorDartHTML<T>();
    return _dartHTML as DOMGeneratorDartHTML<T>;
  }

  static DOMGeneratorWeb? _web;

  static DOMGeneratorWeb<T> web<T extends Object>() {
    _web ??= createDOMGeneratorWeb<T>();
    return _web as DOMGeneratorWeb<T>;
  }

  DOMActionExecutor<T>? _domActionExecutor;

  DOMActionExecutor<T>? get domActionExecutor => _domActionExecutor;

  set domActionExecutor(DOMActionExecutor<T>? value) {
    _domActionExecutor = value;
    if (_domActionExecutor != null) {
      _domActionExecutor!.domGenerator = this;
    }
  }

  DOMContext<T>? _domContext;

  DOMContext<T>? get domContext => _domContext;

  set domContext(DOMContext<T>? value) {
    _domContext = value;
    if (_domContext != null) {
      _domContext!.domGenerator = this;
    }
  }

  Viewport? get viewport => _domContext?.viewport;

  /// Returns `true` if [node1] and [node2] are the same instance.
  bool equalsNodes(T? node1, T? node2) {
    if (node1 == null || node2 == null) return false;

    if (identical(node1, node2)) return true;

    return node1 == node2;
  }

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

  T? getNodeParent(T? node) {
    throw UnsupportedError("Can't get element parent: $node");
  }

  List<T> getNodeParentsUntilRoot(T? node) {
    var list = <T>[];

    while (true) {
      var parent = getNodeParent(node);
      if (parent == null) break;
      list.add(parent);
      node = parent;
    }

    return list;
  }

  bool isNodeInDOM(T? node) {
    var parents = getNodeParentsUntilRoot(node);
    if (parents.isEmpty) return false;

    var root = parents.last;

    if (isTextNode(root)) return false;

    var rootTag = getElementTag(root) ?? '';
    rootTag = rootTag.toLowerCase().trim();

    return rootTag == 'html' || rootTag == 'body' || rootTag == 'head';
  }

  List<T> getElementNodes(T? element, {bool asView = false}) {
    throw UnsupportedError("Can't get element nodes: $element");
  }

  String? getElementTag(T? element) {
    throw UnsupportedError("Can't get element tag: $element");
  }

  String? getElementValue(T? element) {
    throw UnsupportedError("Can't get element value: $element");
  }

  String? getElementOuterHTML(T? element) {
    throw UnsupportedError("Can't get element outerHTML: $element");
  }

  Map<String, String>? getElementAttributes(T? element) {
    throw UnsupportedError("Can't get element attributes: $element");
  }

  Map<String, String>? revertElementAttributes(
      T? element, Map<String, String>? attributes) {
    return attributes;
  }

  /// Generates an element [T] using [root].
  ///
  /// [treeMap] Tree to populate. If [null] calls [createGenericDOMTreeMap] to define [DOMTreeMap] instance.
  /// [context] Optional context for this generated tree.
  /// [parent] Optional parent to add the generated element.
  /// [finalizeTree] Default [true]: calls [finalizeGeneratedTree].
  T? generate(DOMNode root,
      {DOMTreeMap<T>? treeMap,
      T? parent,
      DOMContext<T>? context,
      bool finalizeTree = true,
      bool setTreeMapRoot = true}) {
    treeMap ??= createGenericDOMTreeMap();
    context ??= _domContext;

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
  T? generateWithRoot(DOMElement? domRoot, T? rootElement, List<DOMNode> nodes,
      {DOMTreeMap<T>? treeMap,
      T? rootParent,
      DOMContext<T>? context,
      bool finalizeTree = true,
      bool setTreeMapRoot = true}) {
    treeMap ??= createGenericDOMTreeMap();
    context ??= _domContext;

    if (rootElement == null && domRoot != null) {
      rootElement = treeMap.getMappedElement(domRoot);
      rootElement ??= build(null, null, domRoot, treeMap, context);
    }

    if (rootElement == null) throw StateError("Null `rootElement`.");

    domRoot ??= treeMap.getMappedDOMNode(rootElement) as DOMElement?;

    if (rootParent != null) {
      addChildToElement(rootParent, rootElement);
    }

    treeMap.map(domRoot!, rootElement);

    for (var node in nodes) {
      if (!domRoot.containsNode(node)) {
        domRoot.add(node);
      }
      build(domRoot, rootElement, node, treeMap, context);
    }

    if (setTreeMapRoot) {
      treeMap.setRoot(domRoot, rootElement);
    }

    _callFinalizeGeneratedTree(treeMap, context, finalizeTree);

    return rootElement;
  }

  /// Same as [generate], but parses [htmlRoot] first.
  T? generateFromHTML(String htmlRoot,
      {DOMTreeMap<T>? treeMap,
      DOMElement? domParent,
      T? parent,
      DOMContext<T>? context,
      bool finalizeTree = true,
      bool setTreeMapRoot = true}) {
    var root = $htmlRoot(htmlRoot,
        defaultTagDisplayInlineBlock: false,
        defaultRootTag: parent != null ? 'dom-builder-html-root' : null);

    if (root == null) return null;

    if (root.tag == 'dom-builder-html-root') {
      var rootParent = parent != null ? getNodeParent(parent) : null;

      return generateWithRoot(domParent, parent, root.content!,
          treeMap: treeMap,
          rootParent: rootParent,
          context: context,
          finalizeTree: finalizeTree,
          setTreeMapRoot: setTreeMapRoot);
    } else {
      return generate(root,
          treeMap: treeMap,
          parent: parent,
          context: context,
          finalizeTree: finalizeTree,
          setTreeMapRoot: setTreeMapRoot);
    }
  }

  DOMTreeMap<T> createDOMTreeMap() => DOMTreeMap<T>(this);

  late final _genericDOMTreeMapDummy = DOMTreeMapDummy<T>(this);

  /// Returns a generic [DOMTreeMap]. Called when a [DOMTreeMap] is not passed
  /// while building/generating elements.
  ///
  /// Default implementation returns
  /// a cached [DOMTreeMapDummy] instance.
  DOMTreeMap<T> createGenericDOMTreeMap() => _genericDOMTreeMapDummy;

  /// Same as [generate], but returns a [DOMTreeMap], that contains all
  /// mapping table fo generated elements.
  DOMTreeMap<T> generateMapped(DOMElement root,
      {T? parent, DOMContext<T>? context}) {
    var treeMap = createDOMTreeMap();
    treeMap.generate(this, root, parent: parent, context: context);
    return treeMap;
  }

  List<T> generateNodes(List<DOMNode> nodes, {DOMContext<T>? context}) {
    context ??= _domContext;
    return buildNodes(null, null, nodes, createGenericDOMTreeMap(), context);
  }

  List<T> buildNodes(DOMElement? domParent, T? parent, List<DOMNode>? domNodes,
      DOMTreeMap<T> treeMap, DOMContext<T>? context) {
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

  String? buildElementHTML(T element);

  T? build(DOMElement? domParent, T? parent, DOMNode domNode,
      DOMTreeMap<T> treeMap, DOMContext<T>? context) {
    if (domParent != null) {
      domNode.parent = domParent;
    }

    if (domNode.isCommented) return null;

    if (domNode is DOMElement) {
      return buildElement(domParent, parent, domNode, treeMap, context);
    } else if (domNode is TextNode) {
      return buildText(domParent, parent, domNode, treeMap);
    } else if (domNode is TemplateNode) {
      return buildTemplate(domParent, parent, domNode, treeMap, context);
    } else if (domNode is ExternalElementNode) {
      return buildExternalElement(domParent, parent, domNode, treeMap, context);
    } else if (domNode is DOMAsync) {
      return buildDOMAsyncElement(domParent, parent, domNode, treeMap, context);
    } else {
      throw StateError("Can't build node of type: ${domNode.runtimeType}");
    }
  }

  T? buildText(DOMElement? domParent, T? parent, TextNode domNode,
      DOMTreeMap<T> treeMap) {
    if (domParent != null) {
      domNode.parent = domParent;
    }

    var text = getDOMNodeText(domNode);

    T? textNode;
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

  T? buildTemplate(DOMElement? domParent, T? parent, TemplateNode domNode,
      DOMTreeMap<T> treeMap, DOMContext<T>? context) {
    context ??= domContext;

    if (domParent != null) {
      domNode.parent = domParent;
    }

    var variables = context?.variables ?? <String, dynamic>{};
    var templateResolved = domNode.template
        .build(variables, intlMessageResolver: context?.intlMessageResolver);

    if (templateResolved is List) {
      if (templateResolved.isEmpty) {
        templateResolved = null;
      } else if (templateResolved.length == 1) {
        templateResolved = templateResolved.first;
      } else if (templateResolved.where((e) => e is! DOMNode).isEmpty) {
        templateResolved = $span(content: templateResolved);
      } else if (templateResolved.whereType<DOMNode>().isNotEmpty) {
        var nodes =
            templateResolved.expand((e) => DOMNode.parseNodes(e)).toList();
        templateResolved = $span(content: nodes);
      }
    }

    String str;
    if (templateResolved is DOMNode) {
      var node = templateResolved;
      if (node is! TextNode) {
        if (domParent != null) {
          node.parent = domParent;
        }
        return build(domParent, parent, node, treeMap, context);
      } else {
        str = templateResolved.text;
      }
    } else {
      str = DOMTemplate.objectToString(templateResolved);
    }

    if (possiblyWithHTML(str)) {
      var nodes = parseHTML(str);
      if (nodes != null && nodes.isNotEmpty) {
        DOMNode node;
        if (nodes.length == 1) {
          node = nodes[0];
        } else {
          node = $tag('span', content: nodes);
        }

        if (node is TextNode) {
          T? textNode;
          if (parent != null) {
            textNode = appendElementTextNode(parent, node);
          } else {
            textNode = createTextNode(node);
          }

          if (textNode != null) {
            treeMap.map(domNode, textNode);
          }

          return textNode;
        } else {
          if (domParent != null) {
            node.parent = domParent;
          }
          return build(domParent, parent, node, treeMap, context);
        }
      }
    }

    T? textNode;
    if (parent != null) {
      textNode = appendElementText(parent, str);
    } else {
      textNode = createTextNode(str);
    }

    if (textNode != null) {
      treeMap.map(domNode, textNode);
    }

    return textNode;
  }

  String getDOMNodeText(TextNode domNode) {
    return domNode.text;
  }

  String? getNodeText(T? node);

  T? appendElementText(T element, String? text);

  T? appendElementTextNode(T element, TextNode? textNode) =>
      appendElementText(element, textNode?.text);

  T buildElement(DOMElement? domParent, T? parent, DOMElement domElement,
      DOMTreeMap<T> treeMap, DOMContext<T>? context) {
    if (domParent != null) {
      domElement.parent = domParent;
    }

    var element = createWithRegisteredElementGenerator(
        domParent, parent, domElement, treeMap, context);

    if (element == null) {
      final domContext = _domContext;
      if (domContext != null) {
        element = domContext.resolveNamedElement(
            domParent, parent, domElement, treeMap);
      }

      final domTag = domElement.tag;
      if (domTag == 'svg') {
        element ??= createSVGElement(domElement);
        if (element == null) {
          throw StateError("Can't create SVG element!");
        }

        if (parent != null) {
          addChildToElement(parent, element);
        }

        treeMap.map(domElement, element);
        _callOnElementCreated(treeMap, domElement, element, context);
      } else {
        element ??= createElement(domTag, domElement);
        if (element == null) {
          throw StateError("Can't create element for tag: $domTag");
        }

        setAttributes(domElement, element, treeMap,
            preserveClass: true, preserveStyle: true);

        if (parent != null) {
          addChildToElement(parent, element);
        }

        treeMap.map(domElement, element);
        _callOnElementCreated(treeMap, domElement, element, context);

        final length = domElement.length;
        if (length > 0) {
          final domContent = domElement.content!;
          for (var i = 0; i < length; ++i) {
            var node = domContent[i];
            build(domElement, element, node, treeMap, context);
          }
        }
      }
    } else if (parent != null) {
      addChildToElement(parent, element);
    }

    domElement.notifyElementGenerated(element);

    return element;
  }

  void _callOnElementCreated(DOMTreeMap<T> treeMap, DOMNode domElement,
      T element, DOMContext<T>? context) {
    if (context != null && context.onPreElementCreated != null) {
      context.onPreElementCreated!(treeMap, domElement, element, context);
    }

    onElementCreated(treeMap, domElement, element, context);
  }

  void onElementCreated(DOMTreeMap<T> treeMap, DOMNode domElement, T element,
      DOMContext<T>? context) {}

  T? buildDOMAsyncElement(DOMElement? domParent, T? parent, DOMAsync domElement,
      DOMTreeMap<T> treeMap, DOMContext<T>? context) {
    if (domParent != null) {
      domElement.parent = domParent;
    }

    var parsedElement = _parseExternalElement(
        domParent, parent, domElement, domElement, treeMap, context);

    if (parsedElement != null) {
      if (parent != null && !containsNode(parent, parsedElement)) {
        addChildToElement(parent, parsedElement);
      }

      domElement.notifyElementGenerated(parsedElement);
    }

    return parsedElement;
  }

  T? buildExternalElement(
      DOMElement? domParent,
      T? parent,
      ExternalElementNode domElement,
      DOMTreeMap<T> treeMap,
      DOMContext<T>? context) {
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
      var children = addExternalElementToElement(parent, externalElement,
          treeMap: treeMap, context: context);
      if (children == null || children.isEmpty) return null;
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

  T? _parseExternalElement(DOMElement? domParent, T? parent, DOMNode domElement,
      Object? externalElement, DOMTreeMap<T> treeMap, DOMContext<T>? context) {
    if (externalElement == null) return null;

    if (externalElement is List) {
      var listNodes = _resolveListOfDOMNode(externalElement).toList();
      if (listNodes.isEmpty) return null;

      var elements = <T>[];
      for (var node in listNodes) {
        var elem = build(domParent, parent, node, treeMap, context);
        if (elem == null) {
          throw StateError(
              "Can't build element for `DOMNode` in `externalElement` List: $node");
        }
        elements.add(elem);
        treeMap.map(node, elem);
      }

      if (elements.isEmpty) {
        return null;
      } else if (elements.length == 1) {
        return elements.first;
      } else {
        return wrapElements(elements);
      }
    } else if (externalElement is DOMAsync) {
      return generateDOMAsyncElement(
          domParent, parent, externalElement, treeMap, context);
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
    } else if (externalElement is Future) {
      return generateFutureElement(domParent, parent,
          domElement as ExternalElementNode, externalElement, treeMap, context);
    } else if (externalElement is String) {
      externalElement = externalElement.trim();
      if (externalElement.isEmpty) return null;

      var list = DOMNode.parseNodes(externalElement);

      var elements = <T>[];
      for (var node in list) {
        var elem = build(domParent, parent, node, treeMap, context);
        if (elem == null) {
          throw StateError(
              "Can't build element for `DOMNode` in `externalElement` List: $node");
        }
        T element = elem;
        elements.add(element);
        treeMap.map(node, element);
      }

      return elements.isEmpty ? null : elements.first;
    } else if (externalElement is T) {
      treeMap.map(domElement, externalElement);
      addChildToElement(parent, externalElement as T?);
      return externalElement as T?;
    } else {
      var s = externalElement.toString();
      if (s.trim().isEmpty) return null;
      var e = generateFromHTML(s);
      return e;
    }
  }

  static Iterable<DOMNode> _resolveListOfDOMNode(List<Object?> list) {
    return list.nonNulls.expand(
      (e) => e is List
          ? _resolveListOfDOMNode(e)
          : (e is DOMNode ? <DOMNode>[e] : <DOMNode>[]),
    );
  }

  T? generateDOMAsyncElement(DOMElement? domParent, T? parent,
      DOMAsync domAsync, DOMTreeMap<T> treeMap, DOMContext<T>? context) {
    T? templateElement;
    if (domAsync.loading != null) {
      var nodes = DOMNode.parseNodes(domAsync.loading);

      if (nodes.isNotEmpty) {
        DOMNode rootNode;
        if (nodes.length == 1) {
          rootNode = nodes.first;
        } else {
          rootNode = $div(content: nodes);
        }

        templateElement = build(domParent, parent, rootNode, treeMap, context);
      }
    }

    templateElement ??= createElement('template');

    var future = domAsync.resolveFuture!;

    return _generateFutureElementImpl(
        domParent, parent, domAsync, templateElement, future, treeMap, context);
  }

  T? generateFutureElement(
      DOMElement? domParent,
      T? parent,
      ExternalElementNode domElement,
      Future future,
      DOMTreeMap<T> treeMap,
      DOMContext<T>? context) {
    var templateElement = createElement('template');
    return _generateFutureElementImpl(domParent, parent, domElement,
        templateElement, future, treeMap, context);
  }

  T? _generateFutureElementImpl(
      DOMElement? domParent,
      T? parent,
      DOMNode domElement,
      T? templateElement,
      Future future,
      DOMTreeMap<T> treeMap,
      DOMContext<T>? context) {
    future.then((futureResult) {
      var resolvedElement = resolveFutureElement(domParent, parent, domElement,
          templateElement, futureResult, treeMap, context);
      attachFutureElement(domParent, parent, domElement, templateElement,
          resolvedElement, treeMap, context);
    });
    return templateElement;
  }

  Object? resolveFutureElement(
      DOMElement? domParent,
      T? parent,
      DOMNode domElement,
      T? templateElement,
      Object? futureResult,
      DOMTreeMap<T> treeMap,
      DOMContext<T>? context) {
    if (!canHandleExternalElement(futureResult)) {
      return _parseExternalElement(
          domParent, parent, domElement, futureResult, treeMap, context);
    }
    return futureResult;
  }

  Object? resolveElements(Object? elements,
      {DOMTreeMap<T>? treeMap,
      DOMContext<T>? context,
      bool setTreeMapRoot = true}) {
    var elementsList = toElements(elements,
        treeMap: treeMap, context: context, setTreeMapRoot: setTreeMapRoot);
    if (elementsList == null || elementsList.isEmpty) return null;

    if (elementsList.length == 1) {
      return elementsList.first;
    }

    return elementsList;
  }

  T? wrapElements(List<T>? elements) {
    if (elements == null || elements.isEmpty) return null;

    var div = createElement('div');
    if (div == null) return null;

    setAttribute(div, 'style', 'display: contents');

    for (var child in elements) {
      addChildToElement(div, child);
    }

    return div;
  }

  void attachFutureElement(
      DOMElement? domParent,
      T? parent,
      DOMNode domElement,
      T? templateElement,
      Object? futureElementResolved,
      DOMTreeMap<T> treeMap,
      DOMContext<T>? context) {
    futureElementResolved = resolveElements(futureElementResolved,
        treeMap: treeMap, context: context, setTreeMapRoot: false);
    if (futureElementResolved == null) return;

    if (futureElementResolved is List<Object?>) {
      var futureElementResolvedListTyped = futureElementResolved
          .expand((e) => e.expandNonNullable())
          .whereType<T>()
          .toList();

      if (futureElementResolvedListTyped.isEmpty) return;

      if (futureElementResolvedListTyped.length == 1) {
        var futureElementResolved = futureElementResolvedListTyped.first;
        treeMap.map(domElement, futureElementResolved, allowOverwrite: true);
        if (parent != null) {
          replaceChildElement(parent, templateElement, [futureElementResolved]);
        }
      } else {
        var wrap = wrapElements(futureElementResolvedListTyped);
        if (wrap != null) {
          treeMap.map(domElement, wrap, allowOverwrite: true);
        }

        if (parent != null) {
          replaceChildElement(
              parent, templateElement, futureElementResolvedListTyped);
        }
      }
    } else if (futureElementResolved is T) {
      treeMap.map(domElement, futureElementResolved, allowOverwrite: true);
      if (parent != null) {
        replaceChildElement(parent, templateElement, [futureElementResolved]);
      }
    } else if (parent != null) {
      var children = addExternalElementToElement(parent, futureElementResolved,
          treeMap: treeMap, context: context);

      if (children == null || children.isEmpty) {
        removeChildFromElement(parent, templateElement);
      } else {
        var node = children.first;
        treeMap.map(domElement, node);

        for (var child in children) {
          removeChildFromElement(parent, child);
        }
        replaceChildElement(parent, templateElement, children);
      }
    }
  }

  bool isChildOfElement(T? parent, T? child);

  bool addChildToElement(T? parent, T? child);

  bool removeChildFromElement(T parent, T? child);

  bool replaceChildElement(T parent, T? child1, List<T>? child2);

  bool replaceElement(T? child1, List<T>? child2) {
    if (child1 == null || child2 == null) return false;
    var parent = getNodeParent(child1);
    if (parent == null) return false;
    return replaceChildElement(parent, child1, child2);
  }

  List<T>? toElements(Object? elements,
      {DOMTreeMap<T>? treeMap,
      DOMContext<T>? context,
      bool setTreeMapRoot = true}) {
    if (elements == null) {
      return null;
    } else if (elements is DOMNode) {
      var e = generate(elements,
          treeMap: treeMap, context: context, setTreeMapRoot: setTreeMapRoot);
      if (e == null) {
        throw StateError("Can't generate element for `DOMNode`: $elements");
      }
      return [e];
    } else if (elements is String) {
      var e = generateFromHTML(elements,
          treeMap: treeMap, context: context, setTreeMapRoot: setTreeMapRoot);
      if (e == null) {
        throw StateError("Can't generate element from `HTML`: $elements");
      }
      return [e];
    } else if (elements is Function) {
      var e = elements();
      return toElements(e,
          treeMap: treeMap, context: context, setTreeMapRoot: setTreeMapRoot);
    } else if (elements is Iterable) {
      return elements
          .expand((e) =>
              toElements(e,
                  treeMap: treeMap, context: context, setTreeMapRoot: false) ??
              <T>[])
          .toList();
    } else if (elements is T) {
      return [elements];
    } else {
      var s = elements.toString();
      if (s.trim().isEmpty) return null;
      var e = generateFromHTML(s,
          treeMap: treeMap, context: context, setTreeMapRoot: setTreeMapRoot);
      if (e == null) return null;
      return [e];
    }
  }

  bool canHandleExternalElement(Object? externalElement);

  List<T>? addExternalElementToElement(T element, Object? externalElement,
      {DOMTreeMap<T>? treeMap, DOMContext<T>? context});

  T? createElement(String? tag, [DOMElement? domElement]);

  T? createSVGElement(DOMElement domElement);

  T? createTextNode(Object? text);

  bool isTextNode(T? node);

  bool isElementNode(T? node) => node != null && !isTextNode(node);

  bool containsNode(T parent, T? node);

  void setAttributes(DOMElement domElement, T element, DOMTreeMap<T> treeMap,
      {bool preserveClass = false, bool preserveStyle = false}) {
    for (var attrName in domElement.attributesNames) {
      var attr = domElement.getAttribute(attrName)!;
      var attrVal = attr.getValue(_domContext, treeMap);

      if (preserveClass && attrName == 'class') {
        // print('[WASM ISSUE: not entering method] getAttribute: $attrName ... ($this)[${this.runtimeType}]');
        // print(StackTrace.current);
        var prev = getAttribute(element, attrName);
        if (prev != null && prev.isNotEmpty) {
          attrVal =
              attrVal != null && attrVal.isNotEmpty ? '$prev $attrVal' : prev;
        }
      } else if (preserveStyle && attrName == 'style') {
        var prev = getAttribute(element, attrName);
        if (prev != null && prev.isNotEmpty) {
          if (attrVal != null && attrVal.isNotEmpty) {
            attrVal =
                !prev.endsWith(';') ? '$prev; $attrVal' : '$prev $attrVal';
          } else {
            attrVal = prev;
          }
        }
      } else if ((attrName == 'src' || attrName == 'href') &&
          attrVal != null &&
          attrVal.isNotEmpty) {
        var attrVal2 = resolveSource(attrVal);

        if (attrVal != attrVal2) {
          setAttribute(element, '$attrName-original', attrVal);
          attrVal = attrVal2;
        }
      } else if (attr.isBoolean && DOMAttribute.isBooleanAttribute(attrName)) {
        if (attrVal != 'true') {
          continue;
        }
      }

      setAttribute(element, attrName, attrVal);
    }
  }

  /// [Function] used by [resolveSource].
  String Function(String url)? sourceResolver;

  /// Resolves any source attribute.
  String resolveSource(String url) {
    if (sourceResolver != null) {
      var urlResolved = sourceResolver!(url);
      return urlResolved;
    }
    return url;
  }

  void setAttribute(T element, String attrName, String? attrVal);

  String? getAttribute(T element, String attrName);

  final Map<String, ElementGenerator<T>> _elementsGenerators = {};

  bool isElementGeneratorTag(String? tag) {
    tag = normalizeTag(tag);
    if (tag == null) return false;
    return _elementsGenerators.containsKey(tag);
  }

  Map<String, ElementGenerator<T>> get registeredElementsGenerators =>
      Map.from(_elementsGenerators);

  int get registeredElementsGeneratorsLength => _elementsGenerators.length;

  T? createWithRegisteredElementGenerator(DOMElement? domParent, T? parent,
      DOMElement domElement, DOMTreeMap<T> treeMap, DOMContext<T>? context) {
    var tag = domElement.tag;
    var generator = _elementsGenerators[tag];
    if (generator == null) return null;

    T? contentHolder;
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

    var element = generator.generate(
        this,
        treeMap,
        tag,
        domParent,
        parent,
        domElement,
        domElement.domAttributes,
        contentHolder,
        domElement.content,
        context);

    treeMap.mapTree(domElement, element);

    _callOnElementCreated(treeMap, domElement, element, context);

    return element;
  }

  bool registerElementGenerator(ElementGenerator<T> elementGenerator) {
    String? tag = elementGenerator.tag;
    tag = normalizeTag(tag);
    if (tag == null) return false;
    _elementsGenerators[tag] = elementGenerator;
    return true;
  }

  static String? normalizeTag(String? tag) {
    if (tag == null) return null;
    tag = tag.toLowerCase().trim();
    if (tag.isEmpty) return null;
    return tag;
  }

  bool registerElementGeneratorFrom(DOMGenerator<T> otherGenerator) {
    if (otherGenerator.registeredElementsGeneratorsLength == 0) return false;
    _elementsGenerators.addAll(otherGenerator._elementsGenerators);
    return true;
  }

  void resolveActionAttribute(DOMTreeMap<T> treeMap, DOMElement domElement,
      T element, DOMContext<T>? context) {
    if (_domActionExecutor == null || domElement.tag == 'form') return;

    var actionValue = domElement.getAttributeValue('action', domContext);
    if (actionValue == null || actionValue.isEmpty) return;

    var domAction = _domActionExecutor!.parse(actionValue);

    if (domAction != null) {
      EventStream<DOMEvent> eventStream;

      var tag = domElement.tag;
      if (tag == 'select' || tag == 'input' || tag == 'textarea') {
        eventStream = domElement.onChange;
      } else {
        eventStream = domElement.onClick;
      }

      eventStream.listen(
        (event) {
          var target = domElement.getRuntimeNode();
          var elementValue = getElementValue(element);

          var context2 = context?.copy() ?? DOMContext();

          var variables = context2.variables;
          variables['event'] = {
            'target': domElement,
            'value': elementValue,
            'event': '$event'
          };

          context2.variables = variables;

          domAction.execute(target, treeMap: treeMap, context: context2);
        },
        singletonIdentifier: domAction,
        singletonIdentifyByInstance: false,
        overwriteSingletonSubscription: true,
      );
    }
  }

  void registerEventListeners(DOMTreeMap<T> treeMap, DOMElement domElement,
      T element, DOMContext<T>? context) {}

  FutureOr<bool> cancelEventSubscriptions(
          T? element, List<Object> subscriptions) =>
      false;

  DOMMouseEvent? createDOMMouseEvent(DOMTreeMap<T> treeMap, Object? event) =>
      null;

  DOMEvent? createDOMEvent(DOMTreeMap<T> treeMap, Object? event) => null;

  bool cancelEvent(Object? event, {bool stopImmediatePropagation = false}) =>
      false;

  DOMNodeRuntime<T>? createDOMNodeRuntime(
      DOMTreeMap<T> treeMap, DOMNode? domNode, T node);

  List<T> castToNodes(List list) {
    if (list is List<T>) return list;
    return list.cast<T>();
  }

  /// Reverts [node] to a [DOMNode].
  DOMNode? revert(DOMTreeMap<T>? treeMap, T? node) {
    return _revertImp(treeMap, null, null, node);
  }

  DOMNode? _revertImp(
      DOMTreeMap<T>? treeMap, DOMElement? domParent, T? parent, T? node) {
    if (isTextNode(node)) {
      return _revertTextNode(domParent!, parent, node);
    } else if (isElementNode(node)) {
      return _revertDOMElement(treeMap, domParent, parent, node);
    } else {
      return null;
    }
  }

  TextNode _revertTextNode(DOMElement domParent, T? parent, T? node) {
    var domNode = TextNode(getNodeText(node)!);
    domParent.add(domNode);
    return domNode;
  }

  DOMElement? _revertDOMElement(
      DOMTreeMap<T>? treeMap, DOMElement? domParent, T? parent, T? node) {
    var tag = getElementTag(node);
    tag = normalizeTag(tag);
    if (tag == null) return null;

    DOMElement? domNode;

    var generator = node == null
        ? null
        : _elementsGenerators[tag] ??
            _elementsGenerators.values
                .firstWhereOrNull((g) => g.isGeneratedElement(node));

    var hasChildrenElements = true;

    if (generator != null) {
      domNode = generator.revert(this, treeMap, domParent, parent, node);
      hasChildrenElements = generator.hasChildrenElements;
    } else {
      var attributes = getElementAttributes(node);
      attributes = revertElementAttributes(node, attributes);
      domNode = DOMElement(tag, attributes: attributes);
    }

    if (domNode == null) return null;

    if (domParent != null) {
      domParent.add(domNode);
    }

    if (hasChildrenElements) {
      var children = getElementNodes(node, asView: true);
      if (children.isNotEmpty) {
        for (var child in children) {
          _revertImp(treeMap, domNode, node, child);
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
      DOMTreeMap<T> treeMap, DOMContext<T>? context, bool finalizeTree) {
    if (finalizeTree) {
      var rootElement = treeMap.rootElement;

      if (rootElement != null && populateGeneratedHTMLTrees) {
        var html = getElementOuterHTML(rootElement)!;
        _generatedHTMLTrees.add(html);
      }

      if (context != null && context.preFinalizeGeneratedTree != null) {
        context.preFinalizeGeneratedTree!(treeMap);
      }

      finalizeGeneratedTree(treeMap);
    }
  }

  void finalizeGeneratedTree(DOMTreeMap<T> treeMap) {}
}

abstract class ElementGenerator<T extends Object> {
  String get tag;

  /// If [true] indicated that this generated element has children nodes.
  bool get hasChildrenElements => true;

  /// If [true] will use a `div` as a content holder, with already
  /// generated content to be passed to [generate] call.
  bool get usesContentHolder => true;

  T generate(
      DOMGenerator<T> domGenerator,
      DOMTreeMap<T> treeMap,
      String? tag,
      DOMElement? domParent,
      T? parent,
      DOMNode domNode,
      Map<String, DOMAttribute> attributes,
      T? contentHolder,
      List<DOMNode>? contentNodes,
      DOMContext<T>? context);

  DOMElement? revert(DOMGenerator<T> domGenerator, DOMTreeMap<T>? treeMap,
      DOMElement? domParent, T? parent, T? node);

  bool isGeneratedElement(T element) => false;
}

typedef ElementGeneratorFunction<T extends Object> = T Function(
    DOMGenerator<T> domGenerator,
    String? tag,
    T? parent,
    Map<String, DOMAttribute> attributes,
    T? contentHolder,
    List<DOMNode>? contentNodes,
    DOMContext<T>? context);

typedef ElementRevertFunction<T extends Object> = DOMElement Function(
    DOMGenerator<T> domGenerator,
    DOMTreeMap<T>? treeMap,
    DOMElement? domParent,
    T? parent,
    T? node);

typedef ElementGeneratedMatchingFunction<T extends Object> = bool Function(
    T element);

class ElementGeneratorFunctions<T extends Object> extends ElementGenerator<T> {
  @override
  final String tag;
  final ElementGeneratorFunction<T> generator;
  final ElementRevertFunction<T>? reverter;
  final ElementGeneratedMatchingFunction? elementMatcher;

  @override
  final bool hasChildrenElements;

  @override
  final bool usesContentHolder;

  ElementGeneratorFunctions(this.tag, this.generator,
      {this.reverter,
      this.elementMatcher,
      this.hasChildrenElements = true,
      this.usesContentHolder = true});

  @override
  T generate(
      DOMGenerator<T> domGenerator,
      DOMTreeMap<T> treeMap,
      String? tag,
      DOMElement? domParent,
      T? parent,
      DOMNode domNode,
      Map<String, DOMAttribute> attributes,
      T? contentHolder,
      List<DOMNode>? contentNodes,
      DOMContext<T>? context) {
    return generator(domGenerator, tag, parent, attributes, contentHolder,
        contentNodes, context);
  }

  @override
  DOMElement revert(DOMGenerator<T> domGenerator, DOMTreeMap<T>? treeMap,
      DOMElement? domParent, T? parent, T? node) {
    return reverter!(domGenerator, treeMap, domParent, parent, node);
  }
}

@Deprecated(
    "Use `DOMGeneratorWeb` with package `web`. Package `dart:html` is deprecated.")
abstract class DOMGeneratorDartHTML<T extends Object> extends DOMGenerator<T> {}

abstract class DOMGeneratorWeb<T extends Object> extends DOMGenerator<T> {}

/// Delegates operations to another [DOMGenerator].
class DOMGeneratorDelegate<T extends Object> implements DOMGenerator<T> {
  final DOMGenerator<T> domGenerator;

  DOMGeneratorDelegate(this.domGenerator);

  @override
  DOMTreeMapDummy<T> get _genericDOMTreeMapDummy =>
      domGenerator._genericDOMTreeMapDummy;

  @override
  void reset() => domGenerator.reset();

  @override
  bool equalsNodes(T? node1, T? node2) =>
      domGenerator.equalsNodes(node1, node2);

  @override
  bool isChildOfElement(T? parent, T? child) =>
      domGenerator.isChildOfElement(parent, child);

  @override
  bool addChildToElement(T? parent, T? child) =>
      domGenerator.addChildToElement(parent, child);

  @override
  List<T>? addExternalElementToElement(T element, externalElement,
          {DOMTreeMap<T>? treeMap, DOMContext<T>? context}) =>
      domGenerator.addExternalElementToElement(element, externalElement,
          treeMap: treeMap, context: context);

  @override
  T? appendElementText(T element, String? text) =>
      domGenerator.appendElementText(element, text);

  @override
  T? appendElementTextNode(T element, TextNode? textNode) =>
      domGenerator.appendElementTextNode(element, textNode);

  @override
  String? buildElementHTML(T element) => domGenerator.buildElementHTML(element);

  @override
  bool canHandleExternalElement(externalElement) =>
      domGenerator.canHandleExternalElement(externalElement);

  @override
  bool containsNode(T parent, T? node) =>
      domGenerator.containsNode(parent, node);

  @override
  DOMNodeRuntime<T>? createDOMNodeRuntime(
          DOMTreeMap<T> treeMap, DOMNode? domNode, T node) =>
      domGenerator.createDOMNodeRuntime(treeMap, domNode, node);

  @override
  List<T> castToNodes(List list) => domGenerator.castToNodes(list);

  @override
  T? createElement(String? tag, [DOMElement? domElement]) =>
      domGenerator.createElement(tag, domElement);

  @override
  T? createSVGElement(DOMElement domElement) =>
      domGenerator.createSVGElement(domElement);

  @override
  T? createTextNode(Object? text) => domGenerator.createTextNode(text);

  @override
  T? generateDOMAsyncElement(DOMElement? domParent, T? parent,
          DOMAsync domAsync, DOMTreeMap<T> treeMap, DOMContext<T>? context) =>
      domGenerator.generateDOMAsyncElement(
          domParent, parent, domAsync, treeMap, context);

  @override
  T? generateFutureElement(DOMElement? domParent, T? parent, DOMNode domElement,
          Future future, DOMTreeMap<T> treeMap, DOMContext<T>? context) =>
      domGenerator.generateFutureElement(domParent, parent,
          domElement as ExternalElementNode, future, treeMap, context);

  @override
  T? _generateFutureElementImpl(
          DOMElement? domParent,
          T? parent,
          DOMNode domElement,
          T? templateElement,
          Future future,
          DOMTreeMap<T> treeMap,
          DOMContext<T>? context) =>
      domGenerator._generateFutureElementImpl(domParent, parent, domElement,
          templateElement, future, treeMap, context);

  @override
  Object? resolveFutureElement(
          DOMElement? domParent,
          T? parent,
          DOMNode domElement,
          T? templateElement,
          futureResult,
          DOMTreeMap<T> treeMap,
          DOMContext<T>? context) =>
      domGenerator.resolveFutureElement(domParent, parent, domElement,
          templateElement, futureResult, treeMap, context);

  @override
  Object? resolveElements(Object? elements,
          {DOMTreeMap<T>? treeMap,
          DOMContext<T>? context,
          bool setTreeMapRoot = true}) =>
      domGenerator.resolveElements(elements,
          treeMap: treeMap, context: context, setTreeMapRoot: setTreeMapRoot);

  @override
  T? wrapElements(List<T>? elements) => domGenerator.wrapElements(elements);

  @override
  void attachFutureElement(
          DOMElement? domParent,
          T? parent,
          DOMNode domElement,
          T? templateElement,
          Object? futureElementResolved,
          DOMTreeMap<T> treeMap,
          DOMContext<T>? context) =>
      domGenerator.attachFutureElement(domParent, parent, domElement,
          templateElement, futureElementResolved, treeMap, context);

  @override
  String? getAttribute(T element, String attrName) =>
      domGenerator.getAttribute(element, attrName);

  @override
  String? getNodeText(T? node) => domGenerator.getNodeText(node);

  @override
  bool isTextNode(T? node) => domGenerator.isTextNode(node);

  @override
  bool removeChildFromElement(T element, T? child) =>
      domGenerator.removeChildFromElement(element, child);

  @override
  bool replaceChildElement(T element, T? child1, List<T>? child2) =>
      domGenerator.replaceChildElement(element, child1, child2);

  @override
  bool replaceElement(T? child1, List<T>? child2) =>
      domGenerator.replaceElement(child1, child2);

  @override
  List<T>? toElements(elements,
          {DOMTreeMap<T>? treeMap,
          DOMContext<T>? context,
          bool setTreeMapRoot = true}) =>
      domGenerator.toElements(elements,
          treeMap: treeMap, context: context, setTreeMapRoot: setTreeMapRoot);

  @override
  void setAttribute(T element, String attrName, String? attrVal) =>
      domGenerator.setAttribute(element, attrName, attrVal);

  @override
  void onElementCreated(DOMTreeMap<T> treeMap, DOMNode domElement, T element,
          DOMContext<T>? context) =>
      domGenerator.onElementCreated(treeMap, domElement, element, context);

  @override
  void resolveActionAttribute(DOMTreeMap<T> treeMap, DOMElement domElement,
      T element, DOMContext<T>? context) {
    domGenerator.resolveActionAttribute(treeMap, domElement, element, context);
  }

  @override
  void registerEventListeners(DOMTreeMap<T> treeMap, DOMElement domElement,
          T element, DOMContext<T>? context) =>
      domGenerator.registerEventListeners(
          treeMap, domElement, element, context);

  @override
  FutureOr<bool> cancelEventSubscriptions(
          T? element, List<Object> subscriptions) =>
      domGenerator.cancelEventSubscriptions(element, subscriptions);

  @override
  DOMMouseEvent? createDOMMouseEvent(DOMTreeMap<T> treeMap, Object? event) =>
      domGenerator.createDOMMouseEvent(treeMap, event);

  @override
  DOMEvent? createDOMEvent(DOMTreeMap<T> treeMap, event) =>
      domGenerator.createDOMEvent(treeMap, event);

  @override
  bool cancelEvent(Object? event, {bool stopImmediatePropagation = false}) =>
      domGenerator.cancelEvent(event,
          stopImmediatePropagation: stopImmediatePropagation);

  @override
  void finalizeGeneratedTree(DOMTreeMap<T> treeMap) =>
      domGenerator.finalizeGeneratedTree(treeMap);

  @override
  Viewport? get viewport => domGenerator.viewport;

  @override
  Map<String, ElementGenerator<T>> get registeredElementsGenerators =>
      domGenerator.registeredElementsGenerators;

  @override
  int get registeredElementsGeneratorsLength =>
      domGenerator.registeredElementsGeneratorsLength;

  @override
  DOMContext<T>? get domContext => domGenerator.domContext;

  @override
  set domContext(DOMContext<T>? value) => domGenerator.domContext = value;

  @override
  T buildElement(DOMElement? domParent, T? parent, DOMElement domElement,
          DOMTreeMap<T> treeMap, DOMContext<T>? context) =>
      domGenerator.buildElement(
          domParent, parent, domElement, treeMap, context);

  @override
  List<T> buildNodes(DOMElement? domParent, T? parent, List<DOMNode>? domNodes,
          DOMTreeMap<T> treeMap, DOMContext<T>? context) =>
      domGenerator.buildNodes(domParent, parent, domNodes, treeMap, context);

  @override
  void _callFinalizeGeneratedTree(
          DOMTreeMap<T> treeMap, DOMContext<T>? context, bool finalizeTree) =>
      domGenerator._callFinalizeGeneratedTree(treeMap, context, finalizeTree);

  @override
  void _callOnElementCreated(DOMTreeMap<T> treeMap, DOMNode domElement,
          T element, DOMContext<T>? context) =>
      domGenerator._callOnElementCreated(treeMap, domElement, element, context);

  @override
  Map<String, ElementGenerator<T>> get _elementsGenerators =>
      domGenerator._elementsGenerators;

  @override
  Set<String> get _ignoreAttributeEquivalence =>
      domGenerator._ignoreAttributeEquivalence;

  @override
  T? _parseExternalElement(DOMElement? domParent, T? parent, DOMNode domElement,
          externalElement, DOMTreeMap<T> treeMap, DOMContext<T>? context) =>
      domGenerator._parseExternalElement(
          domParent, parent, domElement, externalElement, treeMap, context);

  @override
  DOMNode? _revertImp(
          DOMTreeMap<T>? treeMap, DOMElement? domParent, T? parent, T? node) =>
      domGenerator._revertImp(treeMap, domParent, parent, node);

  @override
  DOMElement? _revertDOMElement(
          DOMTreeMap<T>? treeMap, DOMElement? domParent, T? parent, T? node) =>
      domGenerator._revertDOMElement(treeMap, domParent, parent, node);

  @override
  TextNode _revertTextNode(DOMElement domParent, T? parent, T? node) =>
      domGenerator._revertTextNode(domParent, parent, node);

  @override
  T? build(DOMElement? domParent, T? parent, DOMNode domNode,
          DOMTreeMap<T> treeMap, DOMContext<T>? context) =>
      domGenerator.build(domParent, parent, domNode, treeMap, context);

  @override
  T? buildDOMAsyncElement(DOMElement? domParent, T? parent, DOMAsync domElement,
          DOMTreeMap<T> treeMap, DOMContext<T>? context) =>
      domGenerator.buildDOMAsyncElement(
          domParent, parent, domElement, treeMap, context);

  @override
  T? buildExternalElement(
          DOMElement? domParent,
          T? parent,
          ExternalElementNode domElement,
          DOMTreeMap<T> treeMap,
          DOMContext<T>? context) =>
      domGenerator.buildExternalElement(
          domParent, parent, domElement, treeMap, context);

  @override
  T? buildText(DOMElement? domParent, T? parent, TextNode domNode,
          DOMTreeMap<T> treeMap) =>
      domGenerator.buildText(domParent, parent, domNode, treeMap);

  @override
  T? buildTemplate(DOMElement? domParent, T? parent, TemplateNode domNode,
          DOMTreeMap<T> treeMap, DOMContext<T>? context) =>
      domGenerator.buildTemplate(domParent, parent, domNode, treeMap, context);

  @override
  void clearIgnoredAttributesEquivalence() =>
      domGenerator.clearIgnoredAttributesEquivalence();

  @override
  DOMTreeMap<T> createDOMTreeMap() => domGenerator.createDOMTreeMap();

  @override
  DOMTreeMap<T> createGenericDOMTreeMap() =>
      domGenerator.createGenericDOMTreeMap();

  @override
  T? createWithRegisteredElementGenerator(
          DOMElement? domParent,
          T? parent,
          DOMElement domElement,
          DOMTreeMap<T> treeMap,
          DOMContext<T>? context) =>
      domGenerator.createWithRegisteredElementGenerator(
          domParent, parent, domElement, treeMap, context);

  @override
  T? generate(DOMNode root,
          {DOMTreeMap<T>? treeMap,
          T? parent,
          DOMContext<T>? context,
          bool finalizeTree = true,
          bool setTreeMapRoot = true}) =>
      domGenerator.generate(root,
          treeMap: treeMap,
          parent: parent,
          context: context,
          finalizeTree: finalizeTree,
          setTreeMapRoot: setTreeMapRoot);

  @override
  T? generateFromHTML(String htmlRoot,
          {DOMTreeMap<T>? treeMap,
          DOMElement? domParent,
          T? parent,
          DOMContext<T>? context,
          bool finalizeTree = true,
          bool setTreeMapRoot = true}) =>
      domGenerator.generateFromHTML(htmlRoot,
          treeMap: treeMap,
          domParent: domParent,
          parent: parent,
          context: context,
          finalizeTree: finalizeTree,
          setTreeMapRoot: setTreeMapRoot);

  @override
  DOMTreeMap<T> generateMapped(DOMElement root,
          {T? parent, DOMContext<T>? context}) =>
      domGenerator.generateMapped(root, parent: parent, context: context);

  @override
  List<T> generateNodes(List<DOMNode> nodes, {DOMContext<T>? context}) =>
      domGenerator.generateNodes(nodes, context: context);

  @override
  T? generateWithRoot(DOMElement? domRoot, T? rootElement, List<DOMNode> nodes,
          {DOMTreeMap<T>? treeMap,
          T? rootParent,
          DOMContext<T>? context,
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
  Map<String, String>? getElementAttributes(T? element) =>
      domGenerator.getElementAttributes(element);

  @override
  Map<String, String>? revertElementAttributes(
          T? element, Map<String, String>? attributes) =>
      domGenerator.revertElementAttributes(element, attributes);

  @override
  List<T> getElementNodes(T? element, {bool asView = false}) =>
      domGenerator.getElementNodes(element, asView: asView);

  @override
  String? getElementTag(T? element) => domGenerator.getElementTag(element);

  @override
  String? getElementValue(T? element) => domGenerator.getElementValue(element);

  @override
  String? getElementOuterHTML(T? element) =>
      domGenerator.getElementOuterHTML(element);

  @override
  List<String> getIgnoredAttributesEquivalence() =>
      domGenerator.getIgnoredAttributesEquivalence();

  @override
  T? getNodeParent(T? node) => domGenerator.getNodeParent(node);

  @override
  List<T> getNodeParentsUntilRoot(T? node) =>
      domGenerator.getNodeParentsUntilRoot(node);

  @override
  bool isNodeInDOM(T? node) => domGenerator.isNodeInDOM(node);

  @override
  void ignoreAttributeEquivalence(String attributeName) =>
      domGenerator.ignoreAttributeEquivalence(attributeName);

  @override
  bool isElementGeneratorTag(String? tag) =>
      domGenerator.isElementGeneratorTag(tag);

  @override
  bool isElementNode(T? node) => domGenerator.isElementNode(node);

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
  DOMNode? revert(DOMTreeMap<T>? treeMap, T? node) =>
      domGenerator.revert(treeMap, node);

  @override
  void setAttributes(DOMElement domElement, T element, DOMTreeMap<T> treeMap,
          {bool preserveClass = false, bool preserveStyle = false}) =>
      domGenerator.setAttributes(domElement, element, treeMap,
          preserveClass: preserveClass, preserveStyle: preserveStyle);

  @override
  DOMContext<T>? get _domContext => domGenerator._domContext;

  @override
  set _domContext(DOMContext<T>? domContext) =>
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
  String Function(String url)? get sourceResolver =>
      domGenerator.sourceResolver;

  @override
  set sourceResolver(String Function(String url)? sourceResolver) =>
      domGenerator.sourceResolver = sourceResolver;

  @override
  String resolveSource(String url) => domGenerator.resolveSource(url);

  @override
  DOMActionExecutor<T>? get domActionExecutor => domGenerator.domActionExecutor;

  @override
  set domActionExecutor(DOMActionExecutor<T>? value) =>
      domGenerator.domActionExecutor = value;

  @override
  DOMActionExecutor<T>? get _domActionExecutor =>
      domGenerator._domActionExecutor;

  @override
  set _domActionExecutor(DOMActionExecutor<T>? value) =>
      domGenerator._domActionExecutor = value;
}

/// A dummy [DOMGenerator] implementation.
class DOMGeneratorDummy<T extends Object> implements DOMGenerator<T> {
  DOMGeneratorDummy();

  @override
  DOMTreeMapDummy<T> get _genericDOMTreeMapDummy => throw UnimplementedError();

  @override
  void reset() {}

  @override
  bool equalsNodes(T? node1, T? node2) => false;

  @override
  bool isChildOfElement(T? parent, T? child) => false;

  @override
  bool addChildToElement(T? parent, T? child) => false;

  @override
  List<T>? addExternalElementToElement(T element, externalElement,
          {DOMTreeMap<T>? treeMap, DOMContext<T>? context}) =>
      null;

  @override
  T? appendElementText(T element, String? text) => null;

  @override
  T? appendElementTextNode(T element, TextNode? textNode) => null;

  @override
  String? buildElementHTML(T element) => null;

  @override
  bool canHandleExternalElement(externalElement) => false;

  @override
  bool containsNode(T parent, T? node) => false;

  @override
  DOMNodeRuntime<T>? createDOMNodeRuntime(
          DOMTreeMap<T> treeMap, DOMNode? domNode, T node) =>
      null;

  @override
  List<T> castToNodes(List list) => <T>[];

  @override
  T? createElement(String? tag, [DOMElement? domElement]) => null;

  @override
  T? createSVGElement(DOMElement domElement) => null;

  @override
  T? createTextNode(Object? text) => null;

  @override
  T? generateDOMAsyncElement(DOMElement? domParent, T? parent,
          DOMAsync domAsync, DOMTreeMap<T> treeMap, DOMContext<T>? context) =>
      null;

  @override
  T? generateFutureElement(DOMElement? domParent, T? parent, DOMNode domElement,
          Future future, DOMTreeMap<T> treeMap, DOMContext<T>? context) =>
      null;

  @override
  T? _generateFutureElementImpl(
          DOMElement? domParent,
          T? parent,
          DOMNode domElement,
          T? templateElement,
          Future future,
          DOMTreeMap<T> treeMap,
          DOMContext<T>? context) =>
      null;

  @override
  Object? resolveFutureElement(
          DOMElement? domParent,
          T? parent,
          DOMNode domElement,
          T? templateElement,
          futureResult,
          DOMTreeMap<T> treeMap,
          DOMContext<T>? context) =>
      null;

  @override
  Object? resolveElements(Object? elements,
          {DOMTreeMap<T>? treeMap,
          DOMContext<T>? context,
          bool setTreeMapRoot = true}) =>
      null;

  @override
  T? wrapElements(List<T>? elements) => null;

  @override
  void attachFutureElement(
      DOMElement? domParent,
      T? parent,
      DOMNode domElement,
      T? templateElement,
      Object? futureElementResolved,
      DOMTreeMap<T> treeMap,
      DOMContext<T>? context) {}

  @override
  String? getAttribute(T element, String attrName) => null;

  @override
  String? getNodeText(T? node) => null;

  @override
  bool isTextNode(T? node) => false;

  @override
  bool removeChildFromElement(T element, T? child) => false;

  @override
  bool replaceChildElement(T element, T? child1, List<T>? child2) => false;

  @override
  bool replaceElement(T? child1, List<T>? child2) => false;

  @override
  List<T>? toElements(elements,
          {DOMTreeMap<T>? treeMap,
          DOMContext<T>? context,
          bool setTreeMapRoot = true}) =>
      null;

  @override
  void setAttribute(T element, String attrName, String? attrVal) {}

  @override
  void onElementCreated(DOMTreeMap<T> treeMap, DOMNode domElement, T element,
      DOMContext<T>? context) {}

  @override
  void resolveActionAttribute(DOMTreeMap<T> treeMap, DOMElement domElement,
      T element, DOMContext<T>? context) {}

  @override
  void registerEventListeners(DOMTreeMap<T> treeMap, DOMElement domElement,
      T element, DOMContext<T>? context) {}

  @override
  bool cancelEventSubscriptions(T? element, List<Object> subscriptions) =>
      false;

  @override
  DOMMouseEvent? createDOMMouseEvent(DOMTreeMap<T> treeMap, Object? event) =>
      null;

  @override
  DOMEvent? createDOMEvent(DOMTreeMap<T> treeMap, event) => null;

  @override
  bool cancelEvent(Object? event, {bool stopImmediatePropagation = false}) =>
      false;

  @override
  void finalizeGeneratedTree(DOMTreeMap<T> treeMap) {}

  @override
  Viewport? get viewport => null;

  @override
  Map<String, ElementGenerator<T>> get registeredElementsGenerators =>
      <String, ElementGenerator<T>>{};

  @override
  int get registeredElementsGeneratorsLength => 0;

  @override
  DOMContext<T>? get domContext => null;

  @override
  set domContext(DOMContext<T>? value) {}

  @override
  T buildElement(DOMElement? domParent, T? parent, DOMElement domElement,
          DOMTreeMap<T> treeMap, DOMContext<T>? context) =>
      throw UnsupportedError(toString());

  @override
  List<T> buildNodes(DOMElement? domParent, T? parent, List<DOMNode>? domNodes,
          DOMTreeMap<T> treeMap, DOMContext<T>? context) =>
      <T>[];

  @override
  void _callFinalizeGeneratedTree(
      DOMTreeMap<T> treeMap, DOMContext<T>? context, bool finalizeTree) {}

  @override
  void _callOnElementCreated(DOMTreeMap<T> treeMap, DOMNode domElement,
      T element, DOMContext<T>? context) {}

  @override
  Map<String, ElementGenerator<T>> get _elementsGenerators =>
      <String, ElementGenerator<T>>{};

  @override
  Set<String> get _ignoreAttributeEquivalence => <String>{};

  @override
  T? _parseExternalElement(DOMElement? domParent, T? parent, DOMNode domElement,
          externalElement, DOMTreeMap<T> treeMap, DOMContext<T>? context) =>
      null;

  @override
  DOMNode? _revertImp(
          DOMTreeMap<T>? treeMap, DOMElement? domParent, T? parent, T? node) =>
      null;

  @override
  DOMElement? _revertDOMElement(
          DOMTreeMap<T>? treeMap, DOMElement? domParent, T? parent, T? node) =>
      null;

  @override
  TextNode _revertTextNode(DOMElement domParent, T? parent, T? node) =>
      TextNode('');

  @override
  T? build(DOMElement? domParent, T? parent, DOMNode domNode,
          DOMTreeMap<T> treeMap, DOMContext<T>? context) =>
      null;

  @override
  T? buildDOMAsyncElement(DOMElement? domParent, T? parent, DOMAsync domElement,
          DOMTreeMap<T> treeMap, DOMContext<T>? context) =>
      null;

  @override
  T? buildExternalElement(
          DOMElement? domParent,
          T? parent,
          ExternalElementNode domElement,
          DOMTreeMap<T> treeMap,
          DOMContext<T>? context) =>
      null;

  @override
  T? buildText(DOMElement? domParent, T? parent, TextNode domNode,
          DOMTreeMap<T> treeMap) =>
      null;

  @override
  T? buildTemplate(DOMElement? domParent, T? parent, TemplateNode domNode,
          DOMTreeMap<T> treeMap, DOMContext<T>? context) =>
      null;

  @override
  void clearIgnoredAttributesEquivalence() {}

  late final _domTreeMapDummy = DOMTreeMapDummy(this);

  @override
  DOMTreeMap<T> createDOMTreeMap() => _domTreeMapDummy;

  @override
  DOMTreeMap<T> createGenericDOMTreeMap() => _domTreeMapDummy;

  @override
  T? createWithRegisteredElementGenerator(
          DOMElement? domParent,
          T? parent,
          DOMElement domElement,
          DOMTreeMap<T> treeMap,
          DOMContext<T>? context) =>
      null;

  @override
  T? generate(DOMNode root,
          {DOMTreeMap<T>? treeMap,
          T? parent,
          DOMContext<T>? context,
          bool finalizeTree = true,
          bool setTreeMapRoot = true}) =>
      null;

  @override
  T? generateFromHTML(String htmlRoot,
          {DOMTreeMap<T>? treeMap,
          DOMElement? domParent,
          T? parent,
          DOMContext<T>? context,
          bool finalizeTree = true,
          bool setTreeMapRoot = true}) =>
      null;

  @override
  DOMTreeMap<T> generateMapped(DOMElement root,
          {T? parent, DOMContext<T>? context}) =>
      DOMTreeMapDummy(this);

  @override
  List<T> generateNodes(List<DOMNode> nodes, {DOMContext<T>? context}) => <T>[];

  @override
  T? generateWithRoot(DOMElement? domRoot, T? rootElement, List<DOMNode> nodes,
          {DOMTreeMap<T>? treeMap,
          T? rootParent,
          DOMContext<T>? context,
          bool finalizeTree = true,
          bool setTreeMapRoot = true}) =>
      null;

  @override
  String getDOMNodeText(TextNode domNode) => '';

  @override
  Map<String, String>? getElementAttributes(T? element) => null;

  @override
  Map<String, String>? revertElementAttributes(
          T? element, Map<String, String>? attributes) =>
      null;

  @override
  List<T> getElementNodes(T? element, {bool asView = false}) => <T>[];

  @override
  String? getElementTag(T? element) => null;

  @override
  String? getElementValue(T? element) => null;

  @override
  String? getElementOuterHTML(T? element) => null;

  @override
  List<String> getIgnoredAttributesEquivalence() => <String>[];

  @override
  T? getNodeParent(T? node) => null;

  @override
  List<T> getNodeParentsUntilRoot(T? node) => <T>[];

  @override
  bool isNodeInDOM(T? node) => false;

  @override
  void ignoreAttributeEquivalence(String attributeName) {}

  @override
  bool isElementGeneratorTag(String? tag) => false;

  @override
  bool isElementNode(T? node) => false;

  @override
  bool isEquivalentNode(DOMNode domNode, T node) => false;

  @override
  bool isEquivalentNodeType(DOMNode domNode, T node) => false;

  @override
  bool isIgnoreAttributeEquivalence(String attributeName) => false;

  @override
  bool registerElementGenerator(ElementGenerator<T> elementGenerator) => false;

  @override
  bool registerElementGeneratorFrom(DOMGenerator<T> otherGenerator) => false;

  @override
  bool removeIgnoredAttributeEquivalence(String attributeName) => false;

  @override
  DOMNode? revert(DOMTreeMap<T>? treeMap, T? node) => null;

  @override
  void setAttributes(DOMElement domElement, T element, DOMTreeMap<T> treeMap,
      {bool preserveClass = false, bool preserveStyle = false}) {}

  @override
  DOMContext<T>? get _domContext => null;

  @override
  set _domContext(DOMContext<T>? domContext) {}

  @override
  List<String> get _generatedHTMLTrees => <String>[];

  @override
  List<String> get generatedHTMLTrees => <String>[];

  @override
  bool get populateGeneratedHTMLTrees => false;

  @override
  set populateGeneratedHTMLTrees(bool populate) {}

  @override
  String Function(String url)? get sourceResolver => null;

  @override
  set sourceResolver(String Function(String url)? sourceResolver) {}

  @override
  String resolveSource(String url) => '';

  @override
  DOMActionExecutor<T>? get domActionExecutor => null;

  @override
  set domActionExecutor(DOMActionExecutor<T>? value) {}

  @override
  DOMActionExecutor<T>? get _domActionExecutor => null;

  @override
  set _domActionExecutor(DOMActionExecutor<T>? value) {}
}

extension on Object? {
  List<Object> expandNonNullable() {
    var self = this;
    if (self == null) return [];
    if (self is List<Object?>) {
      return self.expand((e) => e.expandNonNullable()).toList();
    }
    return [self];
  }
}
