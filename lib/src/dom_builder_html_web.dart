import 'package:js_interop_utils/js_interop_utils.dart';
import 'package:web_utils/web_utils.dart' as web;

import 'dom_builder_base.dart';
import 'dom_builder_html.dart';
import 'dom_builder_treemap.dart';

class DOMHtmlBrowserWeb extends DOMHtml {
  DOMHtmlBrowserWeb() : super.create();

  @override
  bool isHtmlNode(Object? o) {
    var jsAny = o.asJSAny;
    if (jsAny == null) return false;
    return jsAny.isA<web.Node>() || jsAny.isA<web.Text>();
  }

  @override
  bool isHtmlTextNode(Object? node) {
    var jsAny = node.asJSAny;
    if (jsAny == null) return false;
    return jsAny.isA<web.Text>();
  }

  @override
  bool isHtmlElementNode(Object? node) {
    var jsAny = node.asJSAny;
    if (jsAny == null) return false;
    return jsAny.isA<web.Element>();
  }

  @override
  String getNodeText(Object? node) {
    var jsAny = node.asJSAny;
    if (jsAny == null) return '';

    if (jsAny.isA<web.Text>()) {
      return (jsAny as web.Text).textContent ?? '';
    } else if (jsAny.isA<web.Node>()) {
      return (jsAny as web.Node).textContent ?? '';
    } else {
      return '';
    }
  }

  @override
  bool isEmptyTextNode(Object? node) {
    var jsAny = node.asJSAny;
    if (jsAny == null) return false;

    if (jsAny.isA<web.Text>()) {
      return (jsAny as web.Text).textContent?.trim().isEmpty ?? true;
    } else {
      return false;
    }
  }

  @override
  String? getNodeTag(Object? node) {
    var jsAny = node.asJSAny;
    if (jsAny == null) return null;

    if (jsAny.isA<web.Element>()) {
      return (jsAny as web.Element).tagName.toLowerCase().trim();
    } else {
      return null;
    }
  }

  @override
  List getChildrenNodes(Object? node) {
    var jsAny = node.asJSAny;
    if (jsAny == null) return [];

    if (jsAny.isA<web.Element>()) {
      return (node as web.Element).childNodes.toList();
    } else if (jsAny.isA<web.Document>()) {
      var doc = (jsAny as web.Document).documentElement ?? jsAny;
      if (doc.isA<web.Element>()) {
        var body = (doc as web.Element).querySelector('body');
        if (body != null) {
          return body.childNodes.toList();
        }
      }
      return doc.childNodes.toList();
    } else if (jsAny.isA<web.DocumentFragment>()) {
      return (jsAny as web.DocumentFragment).childNodes.toList();
    } else if (jsAny.isA<web.Node>()) {
      return (jsAny as web.Node).childNodes.toList();
    } else {
      return [];
    }
  }

  @override
  String toHTML(Object? node) {
    var jsAny = node.asJSAny;
    if (jsAny == null) return '';

    if (jsAny.isA<web.Element>()) {
      return (jsAny as web.Element).outerHTML.dartify()?.toString() ?? '';
    } else if (jsAny.isA<web.Text>()) {
      return (jsAny as web.Text).textContent ?? '';
    } else if (jsAny.isA<web.Document>()) {
      var html =
          (jsAny as web.Document).childNodes.toIterable().map(toHTML).join();
      return html;
    } else if (jsAny.isA<web.DocumentFragment>()) {
      var html = (jsAny as web.DocumentFragment)
          .childNodes
          .toIterable()
          .map(toHTML)
          .join();
      return html;
    } else {
      return '';
    }
  }

  @override
  DOMNode? toTextNode(Object? node) {
    var jsAny = node.asJSAny;
    if (jsAny == null) return null;

    if (jsAny.isA<web.Text>()) {
      var text = (jsAny as web.Text).textContent ?? '';
      return TextNode.toTextNode(text);
    } else {
      return null;
    }
  }

  @override
  DOMElement? toDOMElement(Object? node) {
    var jsAny = node.asJSAny;
    if (jsAny == null) return null;

    if (jsAny.isA<web.Element>()) {
      var element = jsAny as web.Element;

      // Check if this `Element` was built from a `DOMNode`:
      var treeMap = DOMTreeMap.getElementDOMTreeMap<web.Node>(element);
      if (treeMap != null) {
        var domNode = treeMap.getMappedDOMNode(element);
        if (domNode is DOMElement) {
          return domNode;
        }
      }

      var name = element.tagName.toLowerCase().trim();

      var attributes = element.attributes.toMap();

      if (element.isA<web.HTMLInputElement>()) {
        final input = element as web.HTMLInputElement;

        switch (input.type.toLowerCase()) {
          case 'checkbox':
            {
              var checked = element.checked;
              if (checked && !attributes.containsKey('checked')) {
                attributes['checked'] = 'true';
              }
            }
          default:
            {
              var value = input.value;
              if (!attributes.containsKey('value')) {
                attributes['value'] = value;
              }
            }
        }
      }

      var nodes = element.childNodes.toList();
      var content = nodes.isNotEmpty ? List.from(nodes) : null;

      return DOMElement(name, attributes: attributes, content: content);
    } else {
      return null;
    }
  }

  web.DOMParser? _domParserInstance;

  web.DOMParser get _domParser => _domParserInstance ??= web.DOMParser();

  @override
  Object? parse(String html) {
    switch (html) {
      case '&nbsp;':
        {
          return TextNode('\u00A0', false);
        }
      case '&nbsp;&nbsp;':
        {
          return TextNode('\u00A0\u00A0', false);
        }
      case '&nbsp;&nbsp;&nbsp;':
        {
          return TextNode('\u00A0\u00A0\u00A0', false);
        }
      case '&nbsp;&nbsp;&nbsp;&nbsp;':
        {
          return TextNode('\u00A0\u00A0\u00A0\u00A0', false);
        }

      case '&emsp;':
        {
          return TextNode('\u2003', false);
        }
      case '&emsp;&emsp;':
        {
          return TextNode('\u2003\u2003', false);
        }
      case '&emsp;&emsp;&emsp;':
        {
          return TextNode('\u2003\u2003\u2003', false);
        }
      case '&emsp;&emsp;&emsp;&emsp;':
        {
          return TextNode('\u2003\u2003\u2003\u2003', false);
        }

      case '<br>':
        {
          return DOMElement('br');
        }
      case '<br><br>':
        {
          return <DOMNode>[
            DOMElement('br'),
            DOMElement('br'),
          ];
        }
      case '<br><br><br>':
        {
          return <DOMNode>[
            DOMElement('br'),
            DOMElement('br'),
            DOMElement('br'),
          ];
        }
      case '<br><br><br><br>':
        {
          return <DOMNode>[
            DOMElement('br'),
            DOMElement('br'),
            DOMElement('br'),
            DOMElement('br'),
          ];
        }

      default:
        {
          return _parseImpl(html);
        }
    }
  }

  Object? _parseImpl(String html) {
    try {
      web.Node parsed = _domParser.parseFromString(html.toJS, 'text/html');

      if (parsed.isA<web.Document>()) {
        parsed = (parsed as web.Document).querySelector('body') ?? parsed;
      }

      return parsed;
    } catch (e) {
      print(e);

      var div = web.HTMLDivElement();
      div.innerHTML = html.toJS;

      return div;
    }
  }

  @override
  Object? querySelector(Object? node, String selector) {
    var jsAny = node.asJSAny;
    if (jsAny == null) return null;

    if (jsAny.isA<web.Document>()) {
      return (jsAny as web.Document).querySelector(selector);
    } else if (jsAny.isA<web.DocumentFragment>()) {
      return (jsAny as web.DocumentFragment).querySelector(selector);
    } else if (jsAny.isA<web.Element>()) {
      return (jsAny as web.Element).querySelector(selector);
    } else {
      return null;
    }
  }
}

DOMHtml createDOMHtml() => DOMHtmlBrowserWeb();
