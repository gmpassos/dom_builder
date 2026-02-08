import 'dart:async';

import 'package:swiss_knife/swiss_knife.dart';
import 'package:web_utils/web_utils.dart';

import 'dom_builder_actions.dart';
import 'dom_builder_base.dart';
import 'dom_builder_context.dart';
import 'dom_builder_generator.dart';
import 'dom_builder_runtime.dart';
import 'dom_builder_treemap.dart';
import 'dom_builder_web.dart' as web;

/// [DOMGenerator] based in `dart:html`.

class DOMGeneratorWebImpl extends DOMGeneratorWeb<Node> {
  DOMGeneratorWebImpl() {
    domActionExecutor = DOMActionExecutorWebHTML();
  }

  @override
  List<Node> getElementNodes(Node? element, {bool asView = false}) {
    final element2 = element.asElementChecked;
    if (element2 == null) return [];

    var childNodes = element2.asElement.childNodes;
    return asView ? childNodes.asListViewFixed : childNodes.toList();
  }

  @override
  String? getElementTag(Node? element) {
    final element2 = element.asElementChecked;
    return element2?.asElement.tagName;
  }

  @override
  String? getElementValue(Node? element) {
    if (element == null) return null;

    if (element.isA<HTMLInputElement>()) {
      var inputElement = element as HTMLInputElement;

      var type = inputElement.type.toLowerCase();

      switch (type) {
        case 'checkbox':
          {
            return '${element.checked}';
          }
        case 'file':
          {
            var files = element.files?.toList() ?? [];
            return files.isNotEmpty ? files.join(',') : '';
          }
      }

      return element.value;
    } else if (element.isA<HTMLTextAreaElement>()) {
      var textArea = element as HTMLTextAreaElement;
      return textArea.value;
    } else if (element.isA<HTMLSelectElement>()) {
      var select = element as HTMLSelectElement;
      return select.value;
    }

    return element.textContent;
  }

  @override
  String? getElementOuterHTML(Node? element) {
    if (element == null) return null;

    if (element.isA<Element>()) {
      return element.asElement.outerHTML.dartify()?.toString();
    } else {
      return element.textContent;
    }
  }

  @override
  Map<String, String>? getElementAttributes(Node? element) {
    if (element.isA<Element>()) {
      var attributes = (element as Element)
          .attributes
          .toMap()
          .map((k, v) => MapEntry(k, 'v'));
      return attributes;
    }
    return null;
  }

  @override
  Node? getNodeParent(Node? node) {
    return node!.parentNode;
  }

  @override
  bool isEquivalentNodeType(DOMNode domNode, Node node) {
    if (node.isA<Text>()) {
      return domNode is TextNode;
    } else if (node.isA<Element>()) {
      return domNode is DOMElement &&
          domNode.tag == (node as Element).tagName.toLowerCase();
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
    } else if (domNode is DOMElement && node.isA<Element>()) {
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
    element.appendChild(textNode);
    return textNode;
  }

  @override
  Text? createTextNode(Object? text) {
    if (text == null) return null;

    if (text.asJSAny.isA<Text>()) {
      return text as Text;
    } else if (text is TextNode) {
      return Text(text.text);
    }

    var s = text.toString();
    if (s.isEmpty) return null;
    return Text(s);
  }

  @override
  bool isTextNode(Node? node) => node.isA<Text>();

  @override
  bool containsNode(Node parent, Node? node) {
    if (node == null) return false;
    return parent.contains(node);
  }

  @override
  String? getNodeText(Node? node) {
    if (node == null) return null;
    return node.textContent;
  }

  @override
  bool isChildOfElement(Node? parent, Node? child) {
    if (parent == null || child == null) return false;

    if (parent.isA<Element>()) {
      return _isChildOfElementImpl(parent as Element, child);
    }

    return false;
  }

  bool _isChildOfElementImpl(Element parent, Node child) {
    return child.parentNode == parent;
  }

  @override
  bool addChildToElement(Node? parent, Node? child) {
    if (parent == null || child == null) return false;

    if (parent.isA<Element>()) {
      if (!_isChildOfElementImpl(parent as Element, child)) {
        parent.append(child);
        return true;
      }
    }

    return false;
  }

  @override
  bool removeChildFromElement(Node parent, Node? child) {
    if (child == null) return false;

    if (parent.isA<Element>()) {
      if (_isChildOfElementImpl(parent as Element, child)) {
        try {
          parent.removeChild(child);
          return true;
        } catch (_) {
          return false;
        }
      }
    }

    return false;
  }

  @override
  bool replaceChildElement(Node parent, Node? child1, List<Node>? child2) {
    if (parent.isA<Element>()) {
      var idx = parent.childNodes.indexOf(child1!);
      if (idx >= 0) {
        parent.removeNodeAt(idx);

        for (var i = 0; i < child2!.length; ++i) {
          var e = child2[i];
          parent.insertNode(idx + i, e);
        }
        return true;
      }
    }
    return false;
  }

  @override
  Node? wrapElements(List<Node>? elements) {
    if (elements == null || elements.isEmpty) return null;

    var div = HTMLDivElement()..style.display = 'contents';

    for (var child in elements) {
      div.appendChild(child);
    }

    return div;
  }

  @override
  bool canHandleExternalElement(Object? externalElement) {
    if (externalElement == null) return false;

    var jsAny = externalElement.asJSAny;
    return jsAny?.isA<Node>() ?? false;
  }

  @override
  List<Node>? addExternalElementToElement(Node element, Object? externalElement,
      {DOMTreeMap<Node>? treeMap, DOMContext<Node>? context}) {
    if (externalElement == null) return null;
    if (!element.isA<Element>()) return null;

    externalElement = resolveElements(externalElement,
        treeMap: treeMap, context: context, setTreeMapRoot: false);

    if (externalElement is List) {
      var added = <Node>[];
      for (var e in externalElement) {
        if (e == null) continue;

        if (e is List) {
          var l = addExternalElementToElement(element, e,
              treeMap: treeMap, context: context);
          if (l != null) {
            added.addAll(l);
          }
        } else {
          var jsAny = externalElement.asJSAny;
          if (jsAny.isA<Node>()) {
            var node = jsAny as Node;
            element.appendChild(node);
            added.add(node);
          }
        }
      }
      return added;
    } else {
      var jsAny = externalElement.asJSAny;
      if (jsAny.isA<Node>()) {
        var node = jsAny as Node;
        element.appendChild(node);
        return [node];
      }
    }

    return null;
  }

  @override
  void setAttribute(Node element, String attrName, String? attrVal) {
    if (!element.isA<Element>()) return;

    var element2 = element as Element;

    switch (attrName) {
      case 'selected':
        {
          if (element2.isA<HTMLOptionElement>()) {
            (element2 as HTMLOptionElement).selected =
                _parseAttributeBoolValue(attrVal);
          } else {
            element2.setAttribute(attrName, attrVal!);
          }
          break;
        }
      case 'multiple':
        {
          if (element2.isA<HTMLSelectElement>()) {
            (element2 as HTMLSelectElement).multiple =
                _parseAttributeBoolValue(attrVal);
          } else if (element2.isA<HTMLInputElement>()) {
            (element2 as HTMLInputElement).multiple =
                _parseAttributeBoolValue(attrVal);
          } else {
            element2.setAttribute(attrName, attrVal!);
          }
          break;
        }
      case 'hidden':
        {
          if (element2.isA<HTMLElement>()) {
            (element2 as HTMLElement).hidden =
                _parseAttributeBoolValue(attrVal).toJS;
          }
          break;
        }
      case 'inert':
        {
          if (element2.isA<HTMLElement>()) {
            (element2 as HTMLElement).inert = _parseAttributeBoolValue(attrVal);
          }
          break;
        }
      default:
        {
          if (attrVal == null) {
            element2.removeAttribute(attrName);
          } else {
            switch (attrName) {
              case 'id':
                {
                  element2.id = attrVal;
                  break;
                }
              case 'class':
                {
                  element2.className = attrVal;
                  break;
                }
              case 'style':
                {
                  element2.style?.cssText = attrVal;
                  break;
                }
              default:
                {
                  element2.setAttribute(attrName, attrVal);
                  break;
                }
            }
          }
          break;
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
    final element2 = element.asElementChecked;
    return element2?.getAttribute(attrName);
  }

  @override
  Element? createElement(String? tag, [DOMElement? domElement]) {
    if (domElement != null && tag == 'svg') {
      return createSVGElement(domElement);
    } else {
      return web.createElement(tag!, domElement);
    }
  }

  static const _svgNS = "http://www.w3.org/2000/svg";

  @override
  Element createSVGElement(DOMElement domElement) {
    var element = document.createElementNS(_svgNS, 'svg');

    for (var attrName in domElement.attributesNames) {
      var attr = domElement.getAttribute(attrName)!;
      var attrVal = attr.getValue();
      if (attrVal != null) {
        if (attrName == 'viewbox') {
          attrName = 'viewBox';
        }
        element.setAttributeNS(null, attrName, attrVal);
      }
    }

    var svgContent = domElement.buildHTMLContent().toString();
    element.innerHTML = svgContent.toJS;

    return element;
  }

  @override
  String? buildElementHTML(Node element) {
    if (element.isA<Element>()) {
      var html = element.asElement.outerHTML.dartify()?.toString();
      return html;
    } else if (element.isA<Text>()) {
      return (element as Text).textContent;
    }
    return null;
  }

  @override
  void registerEventListeners(DOMTreeMap<Node> treeMap, DOMElement domElement,
      Node element, DOMContext<Node>? context) {
    final element2 = element.asElementChecked;
    if (element2 == null) return;

    var subscriptions = <Object>[];

    if (domElement.hasOnClickListener) {
      var subscription = element2.onClick.listen((event) {
        var domEvent = createDOMMouseEvent(treeMap, event)!;
        domElement.onClick.add(domEvent);
      });
      subscriptions.add(subscription);
    }

    if (domElement.hasOnChangeListener) {
      var subscription = element2.onChange.listen((event) {
        var domEvent = createDOMEvent(treeMap, event)!;
        domElement.onChange.add(domEvent);
      });
      subscriptions.add(subscription);
    }

    if (domElement.hasOnKeyPressListener) {
      var subscription = element2.onKeyPress.listen((event) {
        var domEvent = createDOMEvent(treeMap, event)!;
        domElement.onKeyPress.add(domEvent);
      });
      subscriptions.add(subscription);
    }

    if (domElement.hasOnKeyUpListener) {
      var subscription = element2.onKeyUp.listen((event) {
        var domEvent = createDOMEvent(treeMap, event)!;
        domElement.onKeyUp.add(domEvent);
      });
      subscriptions.add(subscription);
    }

    if (domElement.hasOnKeyDownListener) {
      var subscription = element2.onKeyDown.listen((event) {
        var domEvent = createDOMEvent(treeMap, event)!;
        domElement.onKeyDown.add(domEvent);
      });
      subscriptions.add(subscription);
    }

    if (domElement.hasOnMouseOverListener) {
      var subscription = element2.onMouseOver.listen((event) {
        var domEvent = createDOMMouseEvent(treeMap, event)!;
        domElement.onMouseOver.add(domEvent);
      });
      subscriptions.add(subscription);
    }

    if (domElement.hasOnMouseOutListener) {
      var subscription = element2.onMouseOut.listen((event) {
        var domEvent = createDOMMouseEvent(treeMap, event)!;
        domElement.onMouseOut.add(domEvent);
      });
      subscriptions.add(subscription);
    }

    if (domElement.hasOnLoadListener) {
      var subscription = element2.onLoad.listen((event) {
        var domEvent = createDOMEvent(treeMap, event)!;
        domElement.onLoad.add(domEvent);
      });
      subscriptions.add(subscription);
    }

    if (domElement.hasOnErrorListener) {
      var subscription = element2.onError.listen((event) {
        var domEvent = createDOMEvent(treeMap, event)!;
        domElement.onError.add(domEvent);
      });
      subscriptions.add(subscription);
    }

    treeMap.mapSubscriptions(element, subscriptions);
  }

  @override
  FutureOr<bool> cancelEventSubscriptions(
      Node? element, List<Object> subscriptions) {
    if (subscriptions.isEmpty) return false;

    var cancelFutures = <Future>[];

    for (var subscription in subscriptions) {
      if (subscription is StreamSubscription<MouseEvent>) {
        var f = subscription.cancel();
        cancelFutures.add(f);
      }
    }

    if (cancelFutures.isEmpty) return false;

    return Future.wait(cancelFutures).then((_) => true);
  }

  @override
  DOMMouseEvent? createDOMMouseEvent(DOMTreeMap<Node> treeMap, Object? event) {
    if (event.asJSAny.isA<MouseEvent>()) {
      var eventTarget = (event as MouseEvent).target as Node?;
      var domTarget = treeMap.getMappedDOMNode(eventTarget);

      return DOMMouseEvent(
          treeMap,
          event,
          eventTarget,
          domTarget,
          event.clientPoint,
          event.offsetPoint,
          event.pagePoint,
          event.screenPoint,
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
  DOMEvent? createDOMEvent(DOMTreeMap<Node> treeMap, Object? event) {
    if (event.asJSAny.isA<Event>()) {
      var eventTarget = (event as Event).target as Node?;
      var domTarget = treeMap.getMappedDOMNode(eventTarget);

      return DOMEvent(treeMap, event, eventTarget, domTarget as DOMElement?);
    }

    return null;
  }

  @override
  bool cancelEvent(Object? event, {bool stopImmediatePropagation = false}) {
    if (event.asJSAny.isA<UIEvent>()) {
      final uiEvent = event as UIEvent;
      if (uiEvent.cancelable) {
        uiEvent.preventDefault();

        if (stopImmediatePropagation) {
          uiEvent.stopImmediatePropagation();
        }

        return true;
      }
    }

    return false;
  }

  @override
  DOMNodeRuntime<Node> createDOMNodeRuntime(
      DOMTreeMap<Node> treeMap, DOMNode? domNode, Node node) {
    return DOMNodeRuntimeWebImpl(treeMap, domNode, node);
  }
}

class DOMNodeRuntimeWebImpl extends DOMNodeRuntime<Node> {
  DOMNodeRuntimeWebImpl(super.treeMap, super.domNode, super.node) : super();

  bool get isNodeElement => node.isA<Element>();

  Element? get nodeAsElement => node?.asElementChecked;

  @override
  String? get tagName {
    var element = nodeAsElement;
    if (element != null) {
      return DOMElement.normalizeTag(element.tagName);
    }
    return null;
  }

  @override
  void addClass(String? className) {
    if (className == null || className.isEmpty) return;
    className = className.trim();
    if (className.isEmpty) return;

    final element = nodeAsElement;
    element?.classList.add(className);
  }

  @override
  List<String> get classes {
    final element = nodeAsElement;
    return element?.classList.toList() ?? [];
  }

  @override
  void clearClasses() {
    final element = nodeAsElement;
    element?.clear();
  }

  @override
  bool removeClass(String? className) {
    if (className == null) return false;

    final element = nodeAsElement;
    if (element != null) {
      className = className.trim();
      if (className.isEmpty) return false;

      return element.classList.removeAndDetectChange(className);
    }

    return false;
  }

  @override
  String get text {
    return node?.textContent ?? '';
  }

  @override
  set text(String value) {
    node?.textContent = value;
  }

  @override
  String? get value => _getElementValue(nodeAsElement);

  @override
  set value(String? value) => _setElementValue(nodeAsElement, value);

  @override
  bool get isStringElement {
    final node = this.node;
    if (node.isA<Text>()) {
      return true;
    } else if (node.isA<Element>()) {
      return DOMElement.isStringTagName(tagName);
    }
    return false;
  }

  @override
  bool remove() {
    final node = this.node;
    if (node == null) return false;

    if (hasParent) {
      if (node.isA<Element>()) {
        (node as Element).remove();
      } else {
        var parentNode = node.parentNode;
        parentNode?.removeChild(node);
      }
      return true;
    }

    return false;
  }

  @override
  String? getAttribute(String name) {
    final element = nodeAsElement;
    if (element != null) {
      return element.attributes.getAttributeValue(name);
    }
    return null;
  }

  @override
  void setAttribute(String name, String value) {
    final element = nodeAsElement;
    element?.attributes.put(name, value);
  }

  @override
  void removeAttribute(String name) {
    final element = nodeAsElement;
    element?.removeAttribute(name);
  }

  @override
  List<Node> get children => node?.childNodes.toList() ?? [];

  @override
  int get nodesLength {
    final element = nodeAsElement;
    return element?.childNodes.length ?? 0;
  }

  @override
  Node? getNodeAt(int index) {
    final element = nodeAsElement;
    return element?.childNodes.item(index);
  }

  @override
  void add(Node child) {
    final element = nodeAsElement;
    element?.append(child);
  }

  @override
  void clear() {
    node?.clear();
  }

  @override
  int get indexInParent {
    final node = this.node;
    if (node == null) return -1;

    var parent = node.parentNode;
    if (parent == null) return -1;

    return parent.childNodes.indexOf(node);
  }

  @override
  bool isInSameParent(Node other) {
    final node = this.node;
    if (node == null) return false;

    var parent = node.parentNode;
    return parent != null && parent == other.parentNode;
  }

  @override
  int indexOf(Node child) {
    final element = nodeAsElement;
    if (element != null) {
      return element.childNodes.indexOf(child);
    }
    return -1;
  }

  @override
  void insertAt(int index, Node? child) {
    if (child == null) return;
    final element = nodeAsElement;
    if (element != null) {
      element.insertNode(index, child);
    }
  }

  @override
  bool removeNode(Node? child) {
    if (child == null) return false;

    final element = nodeAsElement;
    if (element != null) {
      if (element.contains(child)) {
        element.removeChild(child);
        return true;
      }
    }
    return false;
  }

  @override
  Node? removeAt(int index) {
    final element = nodeAsElement;
    return element?.removeNodeAt(index);
  }

  @override
  Element copy() {
    final element =
        nodeAsElement ?? (throw StateError("Node not an `Element`"));
    return element.cloneNode(true) as Element;
  }

  @override
  bool absorbNode(Node? other) {
    if (other == null) return false;
    final node = this.node;
    if (node == null) return false;

    if (node.isA<Text>()) {
      if (other.isA<Text>()) {
        node.textContent =
            ((node as Text).textContent ?? '') + (other.textContent ?? '');
        other.textContent = '';
        return true;
      } else if (other.isA<Element>()) {
        node.textContent = ((node as Text).textContent ?? '') +
            ((other as Element).textContent ?? '');
        other.clear();
        return true;
      }
    } else if (node.isA<Element>()) {
      final element = node as Element;
      if (other.isA<Element>()) {
        final otherElement = other as Element;
        if (otherElement.childNodes.isEmpty) {
          return true;
        }
        element.appendNodes(otherElement.childNodes.toList());
        otherElement.clear();
        return true;
      } else if (other.isA<Text>()) {
        other.remove();
        element.appendChild(other);
        return true;
      }
    }

    return false;
  }
}

String? _getElementValue(Element? element, [String? def]) {
  if (element == null) return def;

  String? value;

  if (element.isA<HTMLInputElement>()) {
    final input = element as HTMLInputElement;
    switch (input.type) {
      case 'checkbox':
        {
          value = element.checked ? 'true' : 'false';
        }
      default:
        {
          value = element.value;
        }
    }
  } else if (element.isCanvasImageSource) {
    value = _getElementSRC(element);
  } else if (element.isA<HTMLTextAreaElement>()) {
    value = (element as HTMLTextAreaElement).value;
  } else if (_isElementWithSRC(element)) {
    value = _getElementSRC(element);
  } else if (_isElementWithHREF(element)) {
    value = _getElementHREF(element);
  } else {
    value = element.text;
  }

  return def != null && (value == null || value.isEmpty) ? def : value;
}

bool _setElementValue(Element? element, String? value) {
  if (element == null) return false;

  if (element.isA<HTMLInputElement>()) {
    final input = element as HTMLInputElement;
    switch (input.type) {
      case 'checkbox':
        {
          input.checked = parseBool(value) ?? false;
        }
      default:
        {
          input.value = value ?? '';
        }
    }

    return true;
  } else if (element.isCanvasImageSource) {
    return _setElementSRC(element, value);
  } else if (element.isA<HTMLTextAreaElement>()) {
    (element as HTMLTextAreaElement).value = value ?? '';
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
  if (element.isA<HTMLLinkElement>()) {
    return (element as HTMLLinkElement).href;
  } else if (element.isA<HTMLAnchorElement>()) {
    return (element as HTMLAnchorElement).href;
  } else if (element.isA<HTMLBaseElement>()) {
    return (element as HTMLBaseElement).href;
  } else if (element.isA<HTMLAreaElement>()) {
    return (element as HTMLAreaElement).href;
  }

  return null;
}

bool _setElementHREF(Element element, String? href) {
  href ??= '';

  if (element.isA<HTMLLinkElement>()) {
    (element as HTMLLinkElement).href = href;
    return true;
  } else if (element.isA<HTMLAnchorElement>()) {
    (element as HTMLAnchorElement).href = href;
    return true;
  } else if (element.isA<HTMLBaseElement>()) {
    (element as HTMLBaseElement).href = href;
    return true;
  } else if (element.isA<HTMLAreaElement>()) {
    (element as HTMLAreaElement).href = href;
    return true;
  }

  return false;
}

bool _isElementWithHREF(Element element) {
  if (element.isA<HTMLLinkElement>()) return true;
  if (element.isA<HTMLAnchorElement>()) return true;
  if (element.isA<HTMLBaseElement>()) return true;
  if (element.isA<HTMLAreaElement>()) return true;

  return false;
}

String? _getElementSRC(Element element) {
  if (element.isA<HTMLImageElement>()) {
    return (element as HTMLImageElement).src;
  } else if (element.isA<HTMLScriptElement>()) {
    return (element as HTMLScriptElement).src;
  } else if (element.isA<HTMLInputElement>()) {
    return (element as HTMLInputElement).src;
  } else if (element.isA<HTMLMediaElement>()) {
    return (element as HTMLMediaElement).src;
  } else if (element.isA<HTMLEmbedElement>()) {
    return (element as HTMLEmbedElement).src;
  } else if (element.isA<HTMLIFrameElement>()) {
    return (element as HTMLIFrameElement).src;
  } else if (element.isA<HTMLSourceElement>()) {
    return (element as HTMLSourceElement).src;
  } else if (element.isA<HTMLTrackElement>()) {
    return (element as HTMLTrackElement).src;
  }

  return null;
}

bool _setElementSRC(Element element, String? src) {
  src ??= '';

  if (element.isA<HTMLImageElement>()) {
    (element as HTMLImageElement).src = src;
    return true;
  } else if (element.isA<HTMLScriptElement>()) {
    (element as HTMLScriptElement).src = src;
    return true;
  } else if (element.isA<HTMLInputElement>()) {
    (element as HTMLInputElement).src = src;
    return true;
  } else if (element.isA<HTMLMediaElement>()) {
    (element as HTMLMediaElement).src = src;
    return true;
  } else if (element.isA<HTMLEmbedElement>()) {
    (element as HTMLEmbedElement).src = src;
    return true;
  } else if (element.isA<HTMLIFrameElement>()) {
    (element as HTMLIFrameElement).src = src;
    return true;
  } else if (element.isA<HTMLSourceElement>()) {
    (element as HTMLSourceElement).src = src;
    return true;
  } else if (element.isA<HTMLTrackElement>()) {
    (element as HTMLTrackElement).src = src;
    return true;
  } else {
    return false;
  }
}

bool _isElementWithSRC(Element element) {
  return element.isA<HTMLImageElement>() ||
      element.isA<HTMLScriptElement>() ||
      element.isA<HTMLInputElement>() ||
      element.isA<HTMLMediaElement>() ||
      element.isA<HTMLEmbedElement>() ||
      element.isA<HTMLIFrameElement>() ||
      element.isA<HTMLSourceElement>() ||
      element.isA<HTMLTrackElement>();
}

class DOMActionExecutorWebHTML extends DOMActionExecutor<Node> {
  @override
  Node selectByID(String id, Node? target, Node? self, DOMTreeMap? treeMap,
      DOMContext? context) {
    final selfElement = self?.asElementChecked;

    if (selfElement != null) {
      var sel = _selectByID(selfElement, id);
      if (sel != null) return sel;
    }

    final targetElement = target?.asElementChecked;

    if (targetElement != null) {
      var sel = _selectByID(targetElement, id);
      if (sel != null) return sel;
    }

    if (treeMap != null) {
      Object? rootElement = treeMap.rootElement;
      if (rootElement.asJSAny.isA<Element>()) {
        var element = rootElement as Element;
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
    var element = target.asHTMLElementChecked;
    if (element != null) {
      element.hidden = false.toJS;

      if (element.style.display == 'none') {
        element.style.display = '';
      }

      if (element.style.visibility == 'hidden') {
        element.style.visibility = '';
      }
    }
    return target;
  }

  @override
  Node? callHide(Node? target) {
    var element = target.asHTMLElementChecked;
    if (element != null) {
      element.hidden = true.toJS;
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
    var element = target.asHTMLElementChecked;
    if (element != null) {
      element.clear();
    }
    return target;
  }

  @override
  Node? callAddClass(Node? target, List<String> classes) {
    var element = target.asHTMLElementChecked;
    if (element != null) {
      element.classList.addAll(classes);
    }
    return target;
  }

  @override
  Node callRemoveClass(Node target, List<String> classes) {
    var element = target.asHTMLElementChecked;
    if (element != null) {
      element.classList.removeAll(classes);
    }
    return target;
  }

  @override
  Node? callSetClass(Node? target, List<String> classes) {
    var element = target.asHTMLElementChecked;
    if (element != null) {
      element.classList.clear();
      element.classList.addAll(classes);
    }
    return target;
  }

  @override
  Node? callClearClass(Node? target) {
    var element = target.asHTMLElementChecked;
    if (element != null) {
      element.classList.clear();
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

DOMGeneratorWeb<T> createDOMGeneratorWeb<T extends Object>() {
  return DOMGeneratorWebImpl() as DOMGeneratorWeb<T>;
}

@Deprecated("Use `createDOMGeneratorWeb`")
DOMGeneratorDartHTML<T> createDOMGeneratorDartHTML<T extends Object>() {
  throw UnsupportedError("`DOMGeneratorDartHTML` not loaded!");
}
