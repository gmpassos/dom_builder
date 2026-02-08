import 'package:html/dom.dart' as html_dom;
import 'package:html/parser.dart' as html_parse;

import 'dom_builder_base.dart';
import 'dom_builder_html.dart';

class DOMHtmlGeneric extends DOMHtml {
  DOMHtmlGeneric() : super.create();

  @override
  bool isHtmlNode(Object? o) {
    return o is html_dom.Node;
  }

  @override
  bool isHtmlTextNode(Object? node) {
    return node is html_dom.Text;
  }

  @override
  bool isHtmlElementNode(Object? node) {
    return node is html_dom.Element;
  }

  @override
  String getNodeText(Object? node) {
    if (node is html_dom.Node) {
      return node.text ?? '';
    } else {
      return '';
    }
  }

  @override
  bool isEmptyTextNode(Object? node) {
    if (node is html_dom.Text) {
      return node.text.trim().isEmpty;
    } else {
      return false;
    }
  }

  @override
  String? getNodeTag(Object? node) {
    if (node is html_dom.Element) {
      return _getElementTagName(node);
    } else {
      return null;
    }
  }

  String _getElementTagName(html_dom.Element node) {
    var tagName = node.localName ?? '';
    return tagName.toLowerCase().trim();
  }

  @override
  List getChildrenNodes(Object? node) {
    if (node is html_dom.Element) {
      return node.nodes.toList();
    } else if (node is html_dom.Node) {
      return node.nodes.toList();
    } else {
      return [];
    }
  }

  @override
  DOMNode? toTextNode(Object? node) {
    if (node is html_dom.Text) {
      var text = node.text;
      return TextNode.toTextNode(text);
    } else {
      return null;
    }
  }

  @override
  String toHTML(Object? node) {
    if (node is html_dom.Element) {
      return node.outerHtml;
    } else if (node is html_dom.Text) {
      return node.text;
    } else if (node is html_dom.Node) {
      return '$node';
    } else {
      return '';
    }
  }

  @override
  DOMElement? toDOMElement(Object? node) {
    if (node is html_dom.Element) {
      var name = _getElementTagName(node);

      var attributes = node.attributes.map((k, v) => MapEntry(k.toString(), v));

      var nodes = node.nodes;
      var content = nodes.isNotEmpty ? List.from(nodes) : null;

      return DOMElement(name, attributes: attributes, content: content);
    } else {
      return null;
    }
  }

  @override
  Object? parse(String html) {
    return html_parse.parseFragment(html);
  }

  @override
  Object? querySelector(Object? node, String selector) {
    if (node is html_dom.DocumentFragment) {
      return node.querySelector(selector);
    } else if (node is html_dom.Element) {
      return node.querySelector(selector);
    } else {
      return null;
    }
  }
}

DOMHtml createDOMHtml() => DOMHtmlGeneric();
