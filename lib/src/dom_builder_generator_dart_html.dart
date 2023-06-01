import 'dart:html';

import 'package:swiss_knife/swiss_knife.dart';

import 'dom_builder_actions.dart';
import 'dom_builder_base.dart';
import 'dom_builder_context.dart';
import 'dom_builder_dart_html.dart' as dart_html;
import 'dom_builder_generator.dart';
import 'dom_builder_runtime.dart';
import 'dom_builder_treemap.dart';

/// [DOMGenerator] based in `dart:html`.
class DOMGeneratorDartHTMLImpl extends DOMGeneratorDartHTML<Node> {
  DOMGeneratorDartHTMLImpl() {
    domActionExecutor = DOMActionExecutorDartHTML();
  }

  @override
  List<Node> getElementNodes(Node? element) {
    if (element is Element) {
      return List.from(element.nodes);
    }
    return <Node>[];
  }

  @override
  String? getElementTag(Node? element) {
    if (element is Element) {
      return element.tagName;
    }
    return null;
  }

  @override
  String? getElementValue(Node? element) {
    if (element == null) return null;

    if (element is InputElement) {
      return element.value;
    } else if (element is TextAreaElement) {
      return element.value;
    } else if (element is SelectElement) {
      return element.value;
    } else if (element is CheckboxInputElement) {
      return '${element.checked ?? false}';
    } else if (element is FileUploadInputElement) {
      var files = element.files ?? [];
      return files.isNotEmpty ? files.join(',') : '';
    }

    return element.text;
  }

  @override
  String? getElementOuterHTML(Node? element) {
    if (element is Element) {
      return element.outerHtml;
    } else {
      return element!.text;
    }
  }

  @override
  Map<String, String>? getElementAttributes(Node? element) {
    if (element is Element) {
      var attributes = Map.fromEntries(element.attributes.entries);
      return attributes;
    }
    return null;
  }

  @override
  Node? getNodeParent(Node? node) {
    return node!.parent;
  }

  @override
  bool isEquivalentNodeType(DOMNode domNode, Node node) {
    if (node is Text) {
      return domNode is TextNode;
    } else if (node is Element) {
      return domNode is DOMElement && domNode.tag == node.tagName.toLowerCase();
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
      var domAttributesSign =
          _toAttributesSignature(domNode.attributesAsString);
      var attributesSign = _toAttributesSignature(getElementAttributes(node)!);
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

  @override
  Text? appendElementText(Node element, String? text) {
    if (text == null || text.isEmpty) return null;
    var textNode = Text(text);
    element.append(textNode);
    return textNode;
  }

  @override
  Text? createTextNode(String? text) {
    if (text == null || text.isEmpty) return null;
    return Text(text);
  }

  @override
  bool isTextNode(Node? node) => node is Text;

  @override
  bool containsNode(Node parent, Node? node) {
    if (node == null) return false;
    return parent.contains(node);
  }

  @override
  String? getNodeText(Node? node) {
    if (node == null) return null;
    return node.text;
  }

  @override
  bool addChildToElement(Node? parent, Node? child) {
    if (parent is Element && !parent.nodes.contains(child)) {
      parent.append(child!);
      return true;
    }
    return false;
  }

  @override
  bool removeChildFromElement(Node parent, Node? child) {
    if (parent is Element) {
      return parent.children.remove(child);
    }
    return false;
  }

  @override
  bool replaceChildElement(Node parent, Node? child1, List<Node>? child2) {
    if (parent is Element) {
      var idx = parent.nodes.indexOf(child1!);
      if (idx >= 0) {
        parent.nodes.removeAt(idx);
        for (var i = 0; i < child2!.length; ++i) {
          var e = child2[i];
          parent.nodes.insert(idx + i, e);
        }
        return true;
      }
    }
    return false;
  }

  @override
  bool canHandleExternalElement(externalElement) {
    return externalElement is Node;
  }

  @override
  List<Node>? addExternalElementToElement(
      Node element, Object? externalElement) {
    if (element is Element && externalElement is Node) {
      element.children.add(externalElement as Element);
      return [externalElement];
    }
    return null;
  }

  @override
  void setAttribute(Node element, String attrName, String? attrVal) {
    if (element is Element) {
      switch (attrName) {
        case 'selected':
          {
            if (element is OptionElement) {
              element.selected = _parseAttributeBoolValue(attrVal);
            } else {
              element.setAttribute(attrName, attrVal!);
            }
            break;
          }
        case 'multiple':
          {
            if (element is SelectElement) {
              element.multiple = _parseAttributeBoolValue(attrVal);
            } else if (element is InputElement) {
              element.multiple = _parseAttributeBoolValue(attrVal);
            } else {
              element.setAttribute(attrName, attrVal!);
            }
            break;
          }
        case 'hidden':
          {
            element.hidden = _parseAttributeBoolValue(attrVal);
            break;
          }
        case 'inert':
          {
            element.inert = _parseAttributeBoolValue(attrVal);
            break;
          }
        default:
          {
            if (attrVal == null) {
              element.removeAttribute(attrName);
            } else {
              element.setAttribute(attrName, attrVal);
            }
            break;
          }
      }
    }
  }

  bool _parseAttributeBoolValue(String? attrVal) {
    if (attrVal == null) {
      return true;
    } else {
      return attrVal.toLowerCase() == 'true';
    }
  }

  @override
  String? getAttribute(Node element, String attrName) {
    if (element is Element) {
      return element.getAttribute(attrName);
    }
    return null;
  }

  @override
  Element? createElement(String? tag, [DOMElement? domElement]) {
    return dart_html.createElement(tag!, domElement);
  }

  @override
  String? buildElementHTML(Node element) {
    if (element is Element) {
      var html = element.outerHtml;
      return html;
    } else if (element is Text) {
      return element.text;
    }
    return null;
  }

  @override
  void registerEventListeners(DOMTreeMap<Node> treeMap, DOMElement domElement,
      Node element, DOMContext<Node>? context) {
    if (element is Element) {
      if (domElement.hasOnClickListener) {
        element.onClick.listen((event) {
          var domEvent = createDOMMouseEvent(treeMap, event)!;
          domElement.onClick.add(domEvent);
        });
      }

      if (domElement.hasOnChangeListener) {
        element.onChange.listen((event) {
          var domEvent = createDOMEvent(treeMap, event)!;
          domElement.onChange.add(domEvent);
        });
      }

      if (domElement.hasOnKeyPressListener) {
        element.onKeyPress.listen((event) {
          var domEvent = createDOMEvent(treeMap, event)!;
          domElement.onKeyPress.add(domEvent);
        });
      }

      if (domElement.hasOnKeyUpListener) {
        element.onKeyUp.listen((event) {
          var domEvent = createDOMEvent(treeMap, event)!;
          domElement.onKeyUp.add(domEvent);
        });
      }

      if (domElement.hasOnKeyDownListener) {
        element.onKeyDown.listen((event) {
          var domEvent = createDOMEvent(treeMap, event)!;
          domElement.onKeyDown.add(domEvent);
        });
      }

      if (domElement.hasOnMouseOverListener) {
        element.onMouseOver.listen((event) {
          var domEvent = createDOMMouseEvent(treeMap, event)!;
          domElement.onMouseOver.add(domEvent);
        });
      }

      if (domElement.hasOnMouseOutListener) {
        element.onMouseOut.listen((event) {
          var domEvent = createDOMMouseEvent(treeMap, event)!;
          domElement.onMouseOut.add(domEvent);
        });
      }

      if (domElement.hasOnLoadListener) {
        element.onLoad.listen((event) {
          var domEvent = createDOMEvent(treeMap, event)!;
          domElement.onLoad.add(domEvent);
        });
      }

      if (domElement.hasOnErrorListener) {
        element.onError.listen((event) {
          var domEvent = createDOMEvent(treeMap, event)!;
          domElement.onError.add(domEvent);
        });
      }
    }
  }

  @override
  DOMMouseEvent? createDOMMouseEvent(DOMTreeMap<Node> treeMap, event) {
    if (event is MouseEvent) {
      var eventTarget = event.target as Node?;
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
  DOMEvent? createDOMEvent(DOMTreeMap<Node> treeMap, event) {
    if (event is Event) {
      var eventTarget = event.target as Node?;
      var domTarget = treeMap.getMappedDOMNode(eventTarget);

      return DOMEvent(treeMap, event, eventTarget, domTarget as DOMElement?);
    }

    return null;
  }

  @override
  bool cancelEvent(Object? event, {bool stopImmediatePropagation = false}) {
    if (event is UIEvent) {
      if (event.cancelable!) {
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
      DOMTreeMap<Node> treeMap, DOMNode? domNode, Node node) {
    return DOMNodeRuntimeDartHTMLImpl(treeMap, domNode, node);
  }
}

class DOMNodeRuntimeDartHTMLImpl extends DOMNodeRuntime<Node> {
  DOMNodeRuntimeDartHTMLImpl(
      DOMTreeMap<Node> treeMap, DOMNode? domNode, Node node)
      : super(treeMap, domNode, node);

  bool get isNodeElement => node is Element;

  Element? get nodeAsElement => node as Element?;

  @override
  String? get tagName {
    if (node is Element) {
      var element = nodeAsElement!;
      return DOMElement.normalizeTag(element.tagName);
    }
    return null;
  }

  @override
  void addClass(String? className) {
    if (isEmptyObject(className)) return;
    className = className!.trim();
    if (className.isEmpty) return;

    if (node is Element) {
      var element = nodeAsElement!;
      element.classes.add(className);
    }
  }

  @override
  List<String> get classes =>
      isNodeElement ? List.from(nodeAsElement!.classes) : [];

  @override
  void clearClasses() {
    if (isNodeElement) {
      nodeAsElement!.nodes.clear();
    }
  }

  @override
  bool removeClass(String? className) {
    if (isEmptyObject(className)) return false;
    if (isNodeElement) {
      return nodeAsElement!.classes.remove(className);
    }
    return false;
  }

  @override
  String get text {
    return node!.text!;
  }

  @override
  set text(String value) {
    node!.text = value;
  }

  @override
  String? get value => _getElementValue(node as Element?);

  @override
  set value(String? value) => _setElementValue(node as Element?, value);

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
      node!.remove();
      return true;
    }
    return false;
  }

  @override
  String? getAttribute(String name) {
    if (isNodeElement) {
      return nodeAsElement!.attributes[name];
    }
    return null;
  }

  @override
  void setAttribute(String name, String value) {
    if (isNodeElement) {
      nodeAsElement!.attributes[name] = value;
    }
  }

  @override
  void removeAttribute(String name) {
    if (isNodeElement) {
      nodeAsElement!.removeAttribute(name);
    }
  }

  @override
  List<Node> get children => List.from(node!.nodes);

  @override
  int get nodesLength {
    if (isNodeElement) {
      return nodeAsElement!.nodes.length;
    }
    return 0;
  }

  @override
  Node? getNodeAt(int index) {
    if (isNodeElement) {
      return nodeAsElement!.nodes[index];
    }
    return null;
  }

  @override
  void add(Node child) {
    if (isNodeElement) {
      nodeAsElement!.append(child);
    }
  }

  @override
  void clear() {
    node!.nodes.clear();
  }

  @override
  int get indexInParent {
    var parent = node!.parent;
    if (parent == null) return -1;
    return parent.nodes.indexOf(node!);
  }

  @override
  bool isInSameParent(Node other) {
    var parent = node!.parent;
    return parent != null && parent == other.parent;
  }

  @override
  int indexOf(Node child) {
    if (isNodeElement) {
      return nodeAsElement!.nodes.indexOf(child);
    }
    return -1;
  }

  @override
  void insertAt(int index, Node? child) {
    if (isNodeElement) {
      nodeAsElement!.nodes.insert(index, child!);
    }
  }

  @override
  bool removeNode(Node? child) {
    if (isNodeElement) {
      return nodeAsElement!.nodes.remove(child);
    }
    return false;
  }

  @override
  Node? removeAt(int index) {
    if (isNodeElement) {
      return nodeAsElement!.nodes.removeAt(index);
    }
    return null;
  }

  @override
  Element copy() {
    return node!.clone(true) as Element;
  }

  @override
  bool absorbNode(Node? other) {
    if (other == null) return false;

    if (node is Text) {
      if (other is Text) {
        node!.text = (node!.text ?? '') + other.text!;
        other.text = '';
        return true;
      } else if (other is Element) {
        node!.text = (node!.text ?? '') + other.text!;
        other.nodes.clear();
        return true;
      }
    } else if (node is Element) {
      if (other is Element) {
        if (other.nodes.isEmpty) {
          return true;
        }
        nodeAsElement!.nodes.addAll(other.nodes);
        other.nodes.clear();
        return true;
      } else if (other is Text) {
        other.remove();
        nodeAsElement!.append(other);
        return true;
      }
    }

    return false;
  }
}

String? _getElementValue(Element? element, [String? def]) {
  if (element == null) return def;

  String? value;

  if (element is InputElement) {
    value = element.value;
  } else if (element is CanvasImageSource) {
    value = _getElementSRC(element);
  } else if (element is CheckboxInputElement) {
    value = element.checked! ? 'true' : 'false';
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

bool _setElementValue(Element? element, String? value) {
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

String? _getElementHREF(Element element) {
  if (element is LinkElement) return element.href;
  if (element is AnchorElement) return element.href;
  if (element is BaseElement) return element.href;
  if (element is AreaElement) return element.href;

  return null;
}

bool _setElementHREF(Element element, String? href) {
  if (element is LinkElement) {
    element.href = href!;
    return true;
  } else if (element is AnchorElement) {
    // ignore: unsafe_html
    element.href = href;
    return true;
  } else if (element is BaseElement) {
    element.href = href!;
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

String? _getElementSRC(Element element) {
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

bool _setElementSRC(Element element, String? src) {
  if (element is ImageElement) {
    // ignore: unsafe_html
    element.src = src;
    return true;
  } else if (element is ScriptElement) {
    // ignore: unsafe_html
    element.src = src!;
    return true;
  } else if (element is InputElement) {
    element.src = src;
    return true;
  } else if (element is MediaElement) {
    element.src = src!;
    return true;
  } else if (element is EmbedElement) {
    // ignore: unsafe_html
    element.src = src!;
    return true;
  } else if (element is IFrameElement) {
    // ignore: unsafe_html
    element.src = src;
    return true;
  } else if (element is SourceElement) {
    element.src = src!;
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

class DOMActionExecutorDartHTML extends DOMActionExecutor<Node> {
  @override
  Node selectByID(String id, Node? target, Node? self, DOMTreeMap? treeMap,
      DOMContext? context) {
    if (self is Element) {
      var sel = _selectByID(self, id);
      if (sel != null) return sel;
    }

    if (target is Element) {
      var sel = _selectByID(target, id);
      if (sel != null) return sel;
    }

    if (treeMap != null) {
      var element = treeMap.rootElement;
      if (element is Element) {
        var sel = _selectByID(element, id);
        if (sel != null) return sel;
      }
    }

    var sel = document.querySelector('#$id');
    sel ??= _selectByID(document.documentElement!, id);

    return sel!;
  }

  Element? _selectByID(Element element, String id) =>
      element.querySelector('#$id');

  @override
  Node? callShow(Node? target) {
    if (target is Element) {
      target.hidden = false;

      if (target.style.display == 'none') {
        target.style.display = '';
      }

      if (target.style.visibility == 'hidden') {
        target.style.visibility = '';
      }
    }
    return target;
  }

  @override
  Node? callHide(Node? target) {
    if (target is Element) {
      target.hidden = true;
    }
    return target;
  }

  @override
  Node? callRemove(Node? target) {
    target!.remove();
    return target;
  }

  @override
  Node? callClear(Node? target) {
    if (target is Element) {
      target.nodes.clear();
    }
    return target;
  }

  @override
  Node? callAddClass(Node? target, List<String> classes) {
    if (target is Element) {
      target.classes.addAll(classes);
    }
    return target;
  }

  @override
  Node callRemoveClass(Node target, List<String> classes) {
    if (target is Element) {
      target.classes.removeAll(classes);
    }
    return target;
  }

  @override
  Node? callSetClass(Node? target, List<String> classes) {
    if (target is Element) {
      target.classes.clear();
      target.classes.addAll(classes);
    }
    return target;
  }

  @override
  Node? callClearClass(Node? target) {
    if (target is Element) {
      target.classes.clear();
    }
    return target;
  }

  @override
  Node? callLocale(Node? target, List<String> parameters, DOMContext? context) {
    var variables = context?.variables ?? {};
    var event = variables['event'] ?? {};
    var locale = event['value'] ?? '';

    print(
        '>>>>>>>>>>>>>>>>>> LOCALE: $locale >> $parameters > $context > vars: $variables');

    return target;
  }
}

DOMGeneratorDartHTML<T> createDOMGeneratorDartHTML<T>() {
  return DOMGeneratorDartHTMLImpl() as DOMGeneratorDartHTML<T>;
}
