import 'dart:html' as dart_html;

import 'package:swiss_knife/swiss_knife.dart';

import 'dom_builder_base.dart';
import 'dom_builder_html.dart';

class DOMHtmlBrowser extends DOMHtml {
  DOMHtmlBrowser() : super.create();

  @override
  bool isHtmlNode(Object? o) {
    return o is dart_html.Node || o is dart_html.Text;
  }

  @override
  bool isHtmlTextNode(Object? node) {
    return node is dart_html.Text;
  }

  @override
  bool isHtmlElementNode(Object? node) {
    return node is dart_html.Element;
  }

  @override
  String getNodeText(Object? node) {
    if (node is dart_html.Text) {
      return node.text ?? '';
    } else if (node is dart_html.Node) {
      return node.text ?? '';
    } else {
      return '';
    }
  }

  @override
  bool isEmptyTextNode(Object? node) {
    if (node is dart_html.Text) {
      return node.text?.trim().isEmpty ?? true;
    } else {
      return false;
    }
  }

  @override
  String? getNodeTag(Object? node) {
    if (node is dart_html.Element) {
      return node.tagName.toLowerCase().trim();
    } else {
      return null;
    }
  }

  @override
  List getChildrenNodes(Object? node) {
    if (node is dart_html.Element) {
      return node.nodes.toList();
    } else if (node is dart_html.Document) {
      var doc = node.documentElement ?? node;
      if (doc is dart_html.Element) {
        var body = doc.querySelector('body');
        if (body != null) {
          return body.nodes.toList();
        }
      }
      return doc.nodes.toList();
    } else if (node is dart_html.DocumentFragment) {
      return node.nodes.toList();
    } else if (node is dart_html.Node) {
      return node.nodes.toList();
    } else {
      return [];
    }
  }

  @override
  String toHTML(Object? node) {
    if (node is dart_html.Element) {
      return node.outerHtml ?? '';
    } else if (node is dart_html.Text) {
      return node.text ?? '';
    } else if (node is dart_html.Document) {
      var html = node.nodes.map(toHTML).join();
      return html;
    } else if (node is dart_html.DocumentFragment) {
      var html = node.nodes.map(toHTML).join();
      return html;
    } else {
      return '';
    }
  }

  @override
  DOMNode? toTextNode(Object? node) {
    if (node is dart_html.Text) {
      var text = node.text ?? '';
      return TextNode.toTextNode(text);
    } else {
      return null;
    }
  }

  @override
  DOMElement? toDOMElement(Object? node) {
    if (node is dart_html.Element) {
      var name = node.tagName.toLowerCase().trim();

      var attributes = node.attributes.map((k, v) => MapEntry(k.toString(), v));

      if (node is dart_html.InputElementBase) {
        var value = node.value;
        if (value != null && !attributes.containsKey('value')) {
          attributes['value'] = value;
        }
      }

      if (node is dart_html.CheckboxInputElement) {
        var checked = node.checked;
        if (checked != null && checked && !attributes.containsKey('checked')) {
          attributes['checked'] = 'true';
        }
      }

      var nodes = node.nodes;
      var content = isNotEmptyObject(nodes) ? List.from(nodes) : null;

      return DOMElement(name, attributes: attributes, content: content);
    } else {
      return null;
    }
  }

  dart_html.DomParser? _domParserInstance;

  dart_html.DomParser get _domParser =>
      _domParserInstance ??= dart_html.DomParser();

  @override
  Object? parse(String html) {
    try {
      dart_html.Node parsed = _domParser.parseFromString(html, 'text/html');

      if (parsed is dart_html.Document) {
        parsed = parsed.querySelector('body') ?? parsed;
      }

      return parsed;
    } catch (e) {
      print(e);

      var div = dart_html.DivElement();
      // ignore: unsafe_html
      div.setInnerHtml(html, validator: _createStandardNodeValidator());
      return div;
    }
  }

  @override
  Object? querySelector(Object? node, String selector) {
    if (node is dart_html.Document) {
      return node.querySelector(selector);
    } else if (node is dart_html.DocumentFragment) {
      return node.querySelector(selector);
    } else if (node is dart_html.Element) {
      return node.querySelector(selector);
    } else {
      return null;
    }
  }
}

const _htmlBasicAttrs = [
  'style',
  'capture',
  'type',
  'src',
  'href',
  'target',
  'contenteditable',
  'xmlns'
];

const _htmlControlAttrs = [
  'data-toggle',
  'data-target',
  'data-dismiss',
  'data-source',
  'aria-controls',
  'aria-expanded',
  'aria-label',
  'aria-current',
  'aria-hidden',
  'role',
];

const _htmlExtendedAttrs = [
  'field',
  'field_value',
  'element_value',
  'src-original',
  'href-original',
  'navigate',
  'action',
  'uilayout',
  'oneventkeypress',
  'oneventclick'
];

const _htmlElementsAllowedAttrs = [
  ..._htmlBasicAttrs,
  ..._htmlControlAttrs,
  ..._htmlExtendedAttrs
];

final _anyUriPolicy = _AnyUriPolicy();

class _AnyUriPolicy implements dart_html.UriPolicy {
  @override
  bool allowsUri(String uri) {
    return true;
  }
}

class _FullSvgNodeValidator implements dart_html.NodeValidator {
  @override
  bool allowsElement(dart_html.Element element) {
    return true;
  }

  @override
  bool allowsAttribute(
      dart_html.Element element, String attributeName, String value) {
    if (attributeName == 'is' || attributeName.startsWith('on')) {
      return false;
    }
    return allowsElement(element);
  }
}

dart_html.NodeValidatorBuilder _createStandardNodeValidator(
    {bool svg = true, bool allowSvgForeignObject = false}) {
  var validator = dart_html.NodeValidatorBuilder()
    ..allowTextElements()
    ..allowHtml5()
    ..allowElement('a', attributes: _htmlElementsAllowedAttrs)
    ..allowElement('nav', attributes: _htmlElementsAllowedAttrs)
    ..allowElement('div', attributes: _htmlElementsAllowedAttrs)
    ..allowElement('li', attributes: _htmlElementsAllowedAttrs)
    ..allowElement('ul', attributes: _htmlElementsAllowedAttrs)
    ..allowElement('ol', attributes: _htmlElementsAllowedAttrs)
    ..allowElement('span', attributes: _htmlElementsAllowedAttrs)
    ..allowElement('img', attributes: _htmlElementsAllowedAttrs)
    ..allowElement('textarea', attributes: _htmlElementsAllowedAttrs)
    ..allowElement('input', attributes: _htmlElementsAllowedAttrs)
    ..allowElement('label', attributes: _htmlElementsAllowedAttrs)
    ..allowElement('button', attributes: _htmlElementsAllowedAttrs)
    ..allowElement('iframe', attributes: _htmlElementsAllowedAttrs)
    ..allowElement('svg', attributes: _htmlElementsAllowedAttrs)
    ..allowImages(_anyUriPolicy)
    ..allowNavigation(_anyUriPolicy)
    ..allowInlineStyles();

  if (svg) {
    if (allowSvgForeignObject) {
      validator.add(_FullSvgNodeValidator());
    } else {
      validator.allowSvg();
    }
  }

  return validator;
}

DOMHtml createDOMHtml() => DOMHtmlBrowser();
