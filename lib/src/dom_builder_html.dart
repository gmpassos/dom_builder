import 'dom_builder_base.dart';
import 'dom_builder_html_generic.dart'
    if (dart.library.js_interop) 'dom_builder_html_web.dart'
    if (dart.library.html) 'dom_builder_html_browser.dart';

/// Class to parse HTML and handle HTML nodes.
///
/// It can have different implementations depending on the Dart platform.
/// When compiling to the browser uses `dart:html`.
abstract class DOMHtml {
  static final DOMHtml _instance = createDOMHtml();

  /// Singleton.
  factory DOMHtml() => _instance;

  DOMHtml.create();

  /// Returns `true` of [o] is a HTML node handled by this class.
  bool isHtmlNode(Object? o);

  /// Returns `true` of [node] is a HTML text node.
  bool isHtmlTextNode(Object? node);

  /// Returns `true` of [node] is a HTML element node.
  bool isHtmlElementNode(Object? node);

  /// Returns the [node] text.
  String getNodeText(Object? node);

  /// Returns `true` if [node] is a text node with an empty text.
  bool isEmptyTextNode(Object? node);

  /// Returns the [node] tag name.
  String? getNodeTag(Object? node);

  /// Returns the [node] children nodes.
  List getChildrenNodes(Object? node);

  /// Converts [node] to HTML.
  String toHTML(Object? node);

  /// Converts [node] to a [DOMNode].
  DOMNode? toDOMNode(Object? node) {
    if (isHtmlElementNode(node)) {
      return toDOMElement(node);
    } else if (isHtmlTextNode(node)) {
      return toTextNode(node);
    } else {
      return null;
    }
  }

  /// Converts [node] to a text [DOMNode].
  ///
  /// Should call [TextNode.toTextNode].
  DOMNode? toTextNode(Object? node);

  /// Converts [node] to a [DOMElement].
  DOMElement? toDOMElement(Object? node);

  /// Parses [html].
  /// This can return a [DOMNode] or a native `Node`.
  Object? parse(String html);

  /// Performs a [node] selection for [selector].
  Object? querySelector(Object? node, String selector);
}
