import 'dart:html';

import 'package:swiss_knife/swiss_knife.dart';

import 'dom_builder_base.dart';
import 'dom_builder_dart_html.dart' as dart_html;
import 'dom_builder_generator.dart';
import 'dom_builder_runtime.dart';
import 'dom_builder_treemap.dart';

/// [DOMGenerator] based in `dart:html`.
class DOMGeneratorDartHTMLImpl extends DOMGeneratorDartHTML<Node> {
  @override
  List<Node> getElementNodes(Node node) {
    if (node is Element) {
      return List.from(node.nodes);
    }
    return <Node>[];
  }

  @override
  Node getNodeParent(Node node) {
    return node.parent;
  }

  @override
  bool isEquivalentNodeType(DOMNode domNode, Node node) {
    if (node is Text) {
      return domNode is TextNode;
    } else if (node is Element) {
      return domNode is DOMElement &&
          domNode.tag.toLowerCase() == node.tagName.toLowerCase();
    }
    return false;
  }

  @override
  bool isEquivalentNode(DOMNode domNode, Node node) {
    if (!isEquivalentNodeType(domNode, node)) {
      return false;
    }

    if (domNode is TextNode) {
      return domNode.text == node.toString();
    } else if (domNode is DOMElement && node is Element) {
      var domAttributesSign = _toAttributesSignature(domNode.attributes.map(
          (key, value) =>
              MapEntry(key, value is List ? value.join(' ') : value)));
      var attributesSign = _toAttributesSignature(getElementAttributes(node));
      return domAttributesSign == attributesSign;
    }

    return false;
  }

  String _toAttributesSignature(Map<String, String> attributes) {
    var entries = attributes
        .map((key, value) => MapEntry(key.toLowerCase(), value))
        .entries
        .where((e) => !isIgnoreAttributeEquivalence(e.key))
        .toList();
    entries.sort((a, b) => a.key.compareTo(b.key));
    var attributesSignature =
        entries.map((e) => '${e.key}=${e.value}').toList();
    return attributesSignature.join('\n');
  }

  static Map<String, String> getElementAttributes(Element element) {
    if (element == null) return null;

    var attributes = <String, String>{};

    for (var name in element.getAttributeNames()) {
      var value = element.getAttribute(name);
      attributes[name] = value;
    }

    return attributes;
  }

  @override
  Text appendElementText(Node node, String text) {
    if (text == null || text.isEmpty) return null;
    var textNode = Text(text);
    node.nodes.add(textNode);
    return textNode;
  }

  @override
  Text createTextNode(String text) {
    if (text == null || text.isEmpty) return null;
    return Text(text);
  }

  @override
  bool isTextNode(Node node) => node is Text;

  @override
  bool containsNode(Node parent, Node node) {
    if (parent == null || node == null) return false;

    if (parent is Node) {
      return parent.contains(node);
    }

    return false;
  }

  @override
  String getNodeText(Node node) {
    if (node == null) return null;
    return node.text;
  }

  @override
  void addChildToElement(Node node, Node child) {
    if (node is Element) {
      node.children.add(child);
    }
  }

  @override
  bool canHandleExternalElement(externalElement) {
    return externalElement is Node;
  }

  @override
  List<Node> addExternalElementToElement(Node node, dynamic externalElement) {
    if (node is Element && externalElement is Node) {
      node.children.add(externalElement);
      return [externalElement];
    }
    return null;
  }

  @override
  void setAttribute(Node node, String attrName, String attrVal) {
    if (node is Element) {
      if (attrVal == null) {
        node.removeAttribute(attrName);
      } else {
        node.setAttribute(attrName, attrVal);
      }
    }
  }

  @override
  Element createElement(String tag) {
    return dart_html.createElement(tag);
  }

  @override
  String buildElementHTML(Node node) {
    if (node == null) return null;
    if (node is Element) {
      var html = node.outerHtml;
      return html;
    } else if (node is Text) {
      return node.text;
    }
    return null;
  }

  @override
  void registerEventListeners(
      DOMTreeMap<Node> treeMap, DOMElement domElement, Node element) {
    if (element is Element) {
      element.onClick.listen((event) {
        var domEvent = createDOMMouseEvent(treeMap, event);
        domElement.onClick.add(domEvent);
      });
    }
  }

  @override
  DOMMouseEvent createDOMMouseEvent(DOMTreeMap<Node> treeMap, event) {
    if (event is MouseEvent) {
      Node eventTarget = event.target;
      var domTarget = treeMap.getMappedDOMNode(eventTarget);

      return DOMMouseEvent(
          treeMap,
          event,
          eventTarget,
          domTarget,
          event.client,
          event.offset,
          event.page,
          event.screen,
          event.button,
          event.buttons,
          event.altKey,
          event.ctrlKey,
          event.shiftKey,
          event.metaKey);
    }

    return null;
  }

  @override
  bool cancelEvent(dynamic event, {bool stopImmediatePropagation = false}) {
    if (event is UIEvent) {
      if (event.cancelable) {
        event.preventDefault();

        if (stopImmediatePropagation) {
          event.stopImmediatePropagation();
        }

        return true;
      }
    }

    return false;
  }

  @override
  DOMNodeRuntime<Node> createDOMNodeRuntime(
      DOMTreeMap<Node> treeMap, DOMNode domNode, Node node) {
    return DOMNodeRuntimeDartHTMLImpl(treeMap, domNode, node);
  }
}

class DOMNodeRuntimeDartHTMLImpl extends DOMNodeRuntime<Node> {
  DOMNodeRuntimeDartHTMLImpl(
      DOMTreeMap<Node> treeMap, DOMNode domNode, Node node)
      : super(treeMap, domNode, node);

  bool get isNodeElement => node is Element;

  Element get nodeAsElement => node as Element;

  @override
  String get tagName {
    if (node is Element) {
      var element = nodeAsElement;
      return DOMElement.normalizeTag(element.tagName);
    }
    return null;
  }

  @override
  void addClass(String className) {
    if (isEmptyObject(className)) return;
    className = className.trim();
    if (className.isEmpty) return;

    if (node is Element) {
      var element = nodeAsElement;
      element.classes.add(className);
    }
  }

  @override
  List<String> get classes =>
      isNodeElement ? List.from(nodeAsElement.classes) : [];

  @override
  void clearClasses() {
    if (isNodeElement) {
      nodeAsElement.nodes.clear();
    }
  }

  @override
  bool removeClass(String className) {
    if (isEmptyObject(className)) return false;
    if (isNodeElement) {
      return nodeAsElement.classes.remove(className);
    }
    return false;
  }

  @override
  String get text {
    return node.text;
  }

  @override
  set text(String value) {
    node.text = value ?? '';
  }

  @override
  String get value => _getElementValue(node);

  @override
  set value(String value) => _setElementValue(node, value);

  @override
  bool get isStringElement {
    if (node is Text) {
      return true;
    } else if (node is Element) {
      return DOMElement.isStringTagName(tagName);
    }
    return false;
  }

  @override
  bool remove() {
    if (hasParent) {
      node.remove();
      return true;
    }
    return false;
  }

  @override
  String getAttribute(String name) {
    if (isNodeElement) {
      return nodeAsElement.attributes[name];
    }
    return null;
  }

  @override
  void setAttribute(String name, String value) {
    if (isNodeElement) {
      nodeAsElement.attributes[name] = value;
    }
  }

  @override
  void removeAttribute(String name) {
    if (isNodeElement) {
      nodeAsElement.removeAttribute(name);
    }
  }

  @override
  List<Node> get children => List.from(node.nodes);

  @override
  int get nodesLength {
    if (isNodeElement) {
      return nodeAsElement.nodes.length;
    }
    return 0;
  }

  @override
  Node getNodeAt(int index) {
    if (isNodeElement) {
      return nodeAsElement.nodes[index];
    }
    return null;
  }

  @override
  void add(Node child) {
    if (isNodeElement) {
      nodeAsElement.append(child);
    }
  }

  @override
  void clear() {
    node.nodes.clear();
  }

  @override
  int get indexInParent {
    var parent = node.parent;
    if (parent == null) return -1;
    return parent.nodes.indexOf(node);
  }

  @override
  bool isInSameParent(Node other) {
    if (other == null) return false;
    var parent = node.parent;
    return parent != null && parent == other.parent;
  }

  @override
  int indexOf(Node child) {
    if (isNodeElement) {
      return nodeAsElement.nodes.indexOf(child);
    }
    return -1;
  }

  @override
  void insertAt(int index, Node child) {
    if (isNodeElement) {
      nodeAsElement.nodes.insert(index, child);
    }
  }

  @override
  bool removeNode(Node child) {
    if (isNodeElement) {
      return nodeAsElement.nodes.remove(child);
    }
    return false;
  }

  @override
  Node removeAt(int index) {
    if (isNodeElement) {
      return nodeAsElement.nodes.removeAt(index);
    }
    return null;
  }

  @override
  Element copy() {
    return node.clone(true);
  }

  @override
  bool absorbNode(Node other) {
    if (other == null) return false;

    if (node is Text) {
      if (other is Text) {
        node.text += other.text;
        other.text = '';
        return true;
      } else if (other is Element) {
        node.text += other.text;
        other.nodes.clear();
        return true;
      }
    } else if (node is Element) {
      if (other is Element) {
        if (other.nodes.isEmpty) {
          return true;
        }
        nodeAsElement.nodes.addAll(other.nodes);
        other.nodes.clear();
        return true;
      } else if (other is Text) {
        other.remove();
        nodeAsElement.nodes.add(other);
        return true;
      }
    }

    return false;
  }
}

String _getElementValue(Element element, [String def]) {
  if (element == null) return def;

  String value;

  if (element is InputElement) {
    value = element.value;
  } else if (element is CanvasImageSource) {
    value = _getElementSRC(element);
  } else if (element is CheckboxInputElement) {
    value = element.checked ? 'true' : 'false';
  } else if (element is TextAreaElement) {
    value = element.value;
  } else if (_isElementWithSRC(element)) {
    value = _getElementSRC(element);
  } else if (_isElementWithHREF(element)) {
    value = _getElementHREF(element);
  } else {
    value = element.text;
  }

  return def != null && isEmptyObject(value) ? def : value;
}

bool _setElementValue(Element element, String value) {
  if (element == null) return false;

  if (element is InputElement) {
    element.value = value;
    return true;
  } else if (element is CanvasImageSource) {
    return _setElementSRC(element, value);
  } else if (element is CheckboxInputElement) {
    element.checked = parseBool(value);
    return true;
  } else if (element is TextAreaElement) {
    element.value = value;
    return true;
  } else if (_isElementWithSRC(element)) {
    return _setElementSRC(element, value);
  } else if (_isElementWithHREF(element)) {
    return _setElementHREF(element, value);
  } else {
    element.text = value;
    return true;
  }
}

String _getElementHREF(Element element) {
  if (element is LinkElement) return element.href;
  if (element is AnchorElement) return element.href;
  if (element is BaseElement) return element.href;
  if (element is AreaElement) return element.href;

  return null;
}

bool _setElementHREF(Element element, String href) {
  if (element is LinkElement) {
    element.href = href;
    return true;
  } else if (element is AnchorElement) {
    element.href = href;
    return true;
  } else if (element is BaseElement) {
    element.href = href;
    return true;
  } else if (element is AreaElement) {
    element.href = href;
    return true;
  }

  return false;
}

bool _isElementWithHREF(Element element) {
  if (element is LinkElement) return true;
  if (element is AnchorElement) return true;
  if (element is BaseElement) return true;
  if (element is AreaElement) return true;

  return false;
}

String _getElementSRC(Element element) {
  if (element is ImageElement) return element.src;
  if (element is ScriptElement) return element.src;
  if (element is InputElement) return element.src;

  if (element is MediaElement) return element.src;
  if (element is EmbedElement) return element.src;

  if (element is IFrameElement) return element.src;
  if (element is SourceElement) return element.src;
  if (element is TrackElement) return element.src;

  if (element is ImageButtonInputElement) return element.src;

  return null;
}

bool _setElementSRC(Element element, String src) {
  if (element == null) return false;

  if (element is ImageElement) {
    element.src = src;
    return true;
  } else if (element is ScriptElement) {
    element.src = src;
    return true;
  } else if (element is InputElement) {
    element.src = src;
    return true;
  } else if (element is MediaElement) {
    element.src = src;
    return true;
  } else if (element is EmbedElement) {
    element.src = src;
    return true;
  } else if (element is IFrameElement) {
    element.src = src;
    return true;
  } else if (element is SourceElement) {
    element.src = src;
    return true;
  } else if (element is TrackElement) {
    element.src = src;
    return true;
  } else if (element is ImageButtonInputElement) {
    element.src = src;
    return true;
  } else {
    return false;
  }
}

bool _isElementWithSRC(Element element) {
  if (element is ImageElement) return true;
  if (element is ScriptElement) return true;
  if (element is InputElement) return true;

  if (element is MediaElement) return true;
  if (element is EmbedElement) return true;

  if (element is IFrameElement) return true;
  if (element is SourceElement) return true;
  if (element is TrackElement) return true;

  if (element is ImageButtonInputElement) return true;

  return false;
}

DOMGeneratorDartHTML<T> createDOMGeneratorDartHTML<T>() {
  return DOMGeneratorDartHTMLImpl() as DOMGeneratorDartHTML<T>;
}
