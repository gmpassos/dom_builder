import 'package:swiss_knife/swiss_knife.dart';

import 'dom_builder_attribute.dart';
import 'dom_builder_base.dart';
import 'dom_builder_generator_none.dart'
    if (dart.library.html) "dom_builder_generator_dart_html.dart";
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

  T generate(DOMElement root, {DOMTreeMap<T> treeMap}) {
    treeMap ??= createGenericDOMTreeMap();
    return build(null, null, root, treeMap);
  }

  DOMTreeMap<T> createDOMTreeMap() => DOMTreeMap<T>(this);

  DOMTreeMap<T> createGenericDOMTreeMap() => DOMTreeMapDummy<T>(this);

  DOMTreeMap<T> generateMapped(DOMElement root) {
    var treeMap = createDOMTreeMap();
    treeMap.generate(this, root);
    return treeMap;
  }

  List<T> generateNodes(List<DOMNode> nodes) {
    return buildNodes(null, null, nodes, createGenericDOMTreeMap());
  }

  List<T> buildNodes(DOMElement domParent, T parent, List<DOMNode> domNodes,
      DOMTreeMap<T> treeMap) {
    if (domNodes == null || domNodes.isEmpty) return [];

    var elements = <T>[];

    for (var node in domNodes) {
      var element = build(domParent, parent, node, treeMap);
      if (element != null) {
        elements.add(element);
      }
    }

    return elements;
  }

  String buildElementHTML(T element);

  T build(
      DOMElement domParent, T parent, DOMNode domNode, DOMTreeMap<T> treeMap) {
    if (domParent != null) {
      domNode.parent = domParent;
    }

    if (domNode.isCommented) return null;

    if (domNode is DOMElement) {
      return buildElement(domParent, parent, domNode, treeMap);
    } else if (domNode is TextNode) {
      return buildText(domParent, parent, domNode, treeMap);
    } else if (domNode is ExternalElementNode) {
      return buildExternalElement(domParent, parent, domNode, treeMap);
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
      DOMTreeMap<T> treeMap) {
    if (domParent != null) {
      domElement.parent = domParent;
    }

    var element = createWithRegisteredElementGenerator(
        domParent, parent, domElement, treeMap);

    if (element == null) {
      element = createElement(domElement.tag);
      treeMap.map(domElement, element);
      onElementCreated(element);

      if (element == null) {
        throw StateError("Can't create element for tag: ${domElement.tag}");
      }

      setAttributes(domElement, element);

      var length = domElement.length;

      for (var i = 0; i < length; i++) {
        var node = domElement.nodeByIndex(i);
        build(domElement, element, node, treeMap);
      }
    }

    if (parent != null) {
      addChildToElement(parent, element);
    }

    return element;
  }

  void onElementCreated(T element) {}

  T buildExternalElement(DOMElement domParent, T parent,
      ExternalElementNode domElement, DOMTreeMap<T> treeMap) {
    if (domParent != null) {
      domElement.parent = domParent;
    }

    var externalElement = domElement.externalElement;

    if (!canHandleExternalElement(externalElement)) {
      var parsedElement = _parseExternalElement(
          domParent, parent, domElement, externalElement, treeMap);
      if (parsedElement != null) {
        return parsedElement;
      }
    }

    if (parent != null) {
      var children = addExternalElementToElement(parent, externalElement);
      if (isEmptyObject(children)) return null;
      var node = children.first;
      treeMap.map(domElement, node);
      return node;
    } else if (externalElement is T) {
      treeMap.map(domElement, externalElement);
      addChildToElement(parent, externalElement);
      return externalElement;
    }

    return null;
  }

  T _parseExternalElement(
      DOMElement domParent,
      T parent,
      ExternalElementNode domElement,
      dynamic externalElement,
      DOMTreeMap<T> treeMap) {
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
        var element = build(domParent, parent, node, treeMap);
        elements.add(element);
        treeMap.map(node, element);
      }
      return elements.isEmpty ? null : elements.first;
    } else if (externalElement is DOMNode) {
      return build(domParent, parent, externalElement, treeMap);
    } else if (externalElement is DOMElementGenerator) {
      var element = externalElement(parent);
      return _parseExternalElement(
          domParent, parent, domElement, element, treeMap);
    } else if (externalElement is DOMElementGeneratorFunction) {
      var element = externalElement();
      return _parseExternalElement(
          domParent, parent, domElement, element, treeMap);
    } else if (externalElement is String) {
      var list = DOMNode.parseNodes(externalElement);

      if (list != null) {
        var elements = <T>[];
        for (var node in list) {
          var element = build(domParent, parent, node, treeMap);
          elements.add(element);
          treeMap.map(node, element);
        }
        return elements.isEmpty ? null : elements.first;
      }
    }

    return null;
  }

  void addChildToElement(T element, T child);

  bool canHandleExternalElement(dynamic externalElement);

  List<T> addExternalElementToElement(T element, dynamic externalElement);

  T createElement(String tag);

  T createTextNode(String text);

  bool isTextNode(T node);

  bool isElementNode(T node) => node != null && !isTextNode(node);

  void setAttributes(DOMElement domElement, T element) {
    for (var attrName in domElement.attributesNames) {
      var attrVal = domElement[attrName];
      setAttribute(element, attrName, attrVal);
    }
  }

  void setAttribute(T element, String attrName, String attrVal);

  final Map<String, ElementGenerator<T>> _elementsGenerators = {};

  Map<String, ElementGenerator<T>> get registeredElementsGenerators =>
      Map.from(_elementsGenerators);

  int get registeredElementsGeneratorsLength => _elementsGenerators.length;

  T createWithRegisteredElementGenerator(DOMElement domParent, T parent,
      DOMElement domElement, DOMTreeMap<T> treeMap) {
    var tag = domElement.tag;
    var generator = _elementsGenerators[tag];
    if (generator == null) return null;

    var contentHolder = createElement('div');

    buildNodes(domElement, contentHolder, domElement.content, treeMap);

    var element =
        generator(this, tag, parent, domElement.domAttributes, contentHolder);

    treeMap.mapTree(domElement, element);

    onElementCreated(element);

    return element;
  }

  bool registerElementGenerator(
      String tag, ElementGenerator<T> elementGenerator) {
    if (tag == null || elementGenerator == null) return false;
    tag = tag.toLowerCase().trim();
    if (tag.isEmpty) return false;
    _elementsGenerators[tag] = elementGenerator;
    return true;
  }

  bool registerElementGeneratorFrom(DOMGenerator<T> otherGenerator) {
    if (otherGenerator == null) return false;
    if (otherGenerator.registeredElementsGeneratorsLength == 0) return false;
    _elementsGenerators.addAll(otherGenerator._elementsGenerators);
    return true;
  }

  void registerEventListeners(
      DOMTreeMap<T> treeMap, DOMElement domElement, T element) {}

  DOMMouseEvent createDOMMouseEvent(DOMTreeMap<T> treeMap, dynamic event) =>
      null;

  bool cancelEvent(dynamic event, {bool stopImmediatePropagation = false}) =>
      false;

  DOMNodeRuntime<T> createDOMNodeRuntime(
      DOMTreeMap<T> treeMap, DOMNode domNode, T node);
}

typedef ElementGenerator<T> = T Function(
    DOMGenerator<T> domGenerator,
    String tag,
    T parent,
    Map<String, DOMAttribute> attributes,
    T contentHolder);

abstract class DOMGeneratorDartHTML<T> extends DOMGenerator<T> {}
