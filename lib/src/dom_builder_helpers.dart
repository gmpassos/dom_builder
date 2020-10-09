import 'package:html/dom.dart' as html_dom;
import 'package:html/parser.dart' as html_parse;
import 'package:swiss_knife/swiss_knife.dart';

import 'dom_builder_base.dart';

final RegExp STRING_LIST_DELIMITER = RegExp(r'[,;\s]+');

final RegExp ARGUMENT_LIST_DELIMITER = RegExp(r'\s*,\s*');

final RegExp CSS_LIST_DELIMITER = RegExp(r'\s*;\s*');

/// Parses [s] as a flat [List<String>].
///
/// [s] If is a [String] uses [delimiter] to split strings. If [s] is a [List] iterator over it and flatten sub lists.
/// [delimiter] Pattern to split [s] to list.
/// [trim] If [true] trims all strings.
List<String> parseListOfStrings(dynamic s,
    [Pattern delimiter, bool trim = true]) {
  if (s == null) return null;

  List<String> list;

  if (s is List) {
    list = s.map(parseString).toList();
  } else {
    var str = parseString(s);
    if (trim) str = str.trim();
    list = str.split(delimiter);
  }

  if (trim) {
    list = list
        .where((e) => e != null)
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList();
  }

  return list;
}

final RegExp _REGEXP_DEPENDENT_TAG =
    RegExp(r'^\s*<(tbody|thread|tfoot|tr|td|th)\W', multiLine: false);

/// Parses a [html] to nodes.
List<DOMNode> parseHTML(String html) {
  if (html == null) return null;

  var dependentTagMatch = _REGEXP_DEPENDENT_TAG.firstMatch(html);

  if (dependentTagMatch != null) {
    var dependentTagName = dependentTagMatch.group(1).toLowerCase();

    html_dom.DocumentFragment parsed;
    if (dependentTagName == 'td' || dependentTagName == 'th') {
      parsed = html_parse.parseFragment(
          '<table><tbody><tr></tr>\n$html\n</tbody></table>',
          container: 'div');
    } else if (dependentTagName == 'tbody' ||
        dependentTagName == 'thead' ||
        dependentTagName == 'tfoot') {
      parsed = html_parse.parseFragment('<table>\n$html\n</table>',
          container: 'div');
    }

    var node = parsed.querySelector(dependentTagName);
    return [DOMNode.from(node)];
  }

  var parsed = html_parse.parseFragment(html, container: 'div');

  if (parsed.nodes.isEmpty) {
    return null;
  } else if (parsed.nodes.length == 1) {
    var node = parsed.nodes[0];
    return [DOMNode.from(node)];
  } else {
    return parsed.nodes.map((e) => DOMNode.from(e)).toList();
  }
}

/// Returns a list of nodes from [html].
List<DOMNode> $html<T extends DOMNode>(dynamic html) {
  if (html == null) return null;
  if (html is String) {
    return parseHTML(html);
  }
  throw ArgumentError("Ca't parse type: ${html.runtimeType}");
}

bool _isTextTag(String tag) {
  tag = DOMElement.normalizeTag(tag);
  if (tag == null || tag.isEmpty) return false;

  switch (tag) {
    case 'br':
    case 'wbr':
    case 'p':
    case 'b':
    case 'strong':
    case 'i':
    case 'em':
    case 'u':
    case 'span':
      return true;
    default:
      return false;
  }
}

DOMElement $htmlRoot(dynamic html,
    {String defaultRootTag, bool defaultTagDisplayInlineBlock}) {
  var nodes = $html(html);
  if (nodes == null || nodes.isEmpty) return null;

  if (nodes.length > 1) {
    nodes.removeWhere((e) => e is TextNode && e.text.trim().isEmpty);
    if (nodes.length == 1) {
      return nodes[0];
    } else {
      Map<String, String> attributes;
      if (defaultRootTag == null) {
        var onlyText = listMatchesAll(nodes,
            (e) => e is TextNode || (e is DOMElement && _isTextTag(e.tag)));
        defaultRootTag = onlyText ? 'span' : 'div';
      }

      if (!_isTextTag(defaultRootTag) &&
          (defaultTagDisplayInlineBlock ?? true)) {
        attributes = {'style': 'display: inline-block'};
      }

      return $tag(defaultRootTag, content: nodes, attributes: attributes);
    }
  } else {
    var node = nodes.single;
    if (node is DOMElement) {
      return node;
    } else {
      return $span(content: node);
    }
  }
}

typedef DOMNodeValidator = bool Function();

final RegExp _PATTERN_HTML_ELEMENT_INIT = RegExp(r'\s*<\w+', multiLine: false);
final RegExp _PATTERN_HTML_ELEMENT_END = RegExp(r'>\s*$', multiLine: false);

bool isHTMLElement(String s) {
  if (s == null) return false;
  return s.startsWith(_PATTERN_HTML_ELEMENT_INIT) &&
      _PATTERN_HTML_ELEMENT_END.hasMatch(s);
}

final RegExp _PATTERN_HTML_ELEMENT = RegExp(r'<\w+.*?>');

bool hasHTMLTag(String s) {
  if (s == null) return false;
  return _PATTERN_HTML_ELEMENT.hasMatch(s);
}

final RegExp _PATTERN_HTML_ENTITY = RegExp(r'&(?:\w+|#\d+);');

bool hasHTMLEntity(String s) {
  if (s == null) return false;
  return _PATTERN_HTML_ENTITY.hasMatch(s);
}

bool _isValid(DOMNodeValidator validate) {
  if (validate != null) {
    try {
      var valid = validate();
      if (valid != null && !valid) {
        return false;
      }
    } catch (e, s) {
      print(e);
      print(s);
    }
  }

  return true;
}

/// Creates a node with [tag].
DOMElement $tag(String tag,
    {DOMNodeValidator validate,
    id,
    classes,
    style,
    Map<String, String> attributes,
    content,
    bool commented}) {
  if (!_isValid(validate)) {
    return null;
  }

  return DOMElement(tag,
      id: id,
      classes: classes,
      style: style,
      attributes: attributes,
      content: content,
      commented: commented);
}

/// Creates a tag node from [html].
T $tagHTML<T extends DOMElement>(dynamic html) =>
    $html<DOMElement>(html).whereType<T>().first;

/// Creates a list of nodes of same [tag].
List<DOMElement> $tags<T>(String tag, Iterable<T> iterable,
    [ContentGenerator<T> elementGenerator]) {
  if (iterable == null) return null;

  var elements = <DOMElement>[];

  if (elementGenerator != null) {
    for (var entry in iterable) {
      var elem = elementGenerator(entry);
      var tagElem = $tag(tag, content: elem);
      elements.add(tagElem);
    }
  } else {
    for (var entry in iterable) {
      var tagElem = $tag(tag, content: entry);
      elements.add(tagElem);
    }
  }

  return elements;
}

/// Creates a `table` node.
TABLEElement $table(
    {DOMNodeValidator validate,
    id,
    classes,
    style,
    Map<String, String> attributes,
    head,
    body,
    foot,
    bool commented}) {
  if (!_isValid(validate)) {
    return null;
  }

  return TABLEElement(
      id: id,
      classes: classes,
      style: style,
      attributes: attributes,
      head: head,
      body: body,
      foot: foot,
      commented: commented);
}

/// Creates a `thread` node.
THEADElement $thead(
    {DOMNodeValidator validate,
    id,
    classes,
    style,
    Map<String, String> attributes,
    rows,
    bool commented}) {
  if (!_isValid(validate)) {
    return null;
  }

  return THEADElement(
      id: id,
      classes: classes,
      style: style,
      attributes: attributes,
      rows: rows,
      commented: commented);
}

/// Creates a `tbody` node.
TBODYElement $tbody(
    {DOMNodeValidator validate,
    id,
    classes,
    style,
    Map<String, String> attributes,
    rows,
    bool commented}) {
  if (!_isValid(validate)) {
    return null;
  }

  return TBODYElement(
      id: id,
      classes: classes,
      style: style,
      attributes: attributes,
      rows: rows,
      commented: commented);
}

/// Creates a `tfoot` node.
TFOOTElement $tfoot(
    {DOMNodeValidator validate,
    id,
    classes,
    style,
    Map<String, String> attributes,
    rows,
    bool commented}) {
  if (!_isValid(validate)) {
    return null;
  }

  return TFOOTElement(
      id: id,
      classes: classes,
      style: style,
      attributes: attributes,
      rows: rows,
      commented: commented);
}

/// Creates a `tr` node.
TRowElement $tr(
    {DOMNodeValidator validate,
    id,
    classes,
    style,
    Map<String, String> attributes,
    cells,
    bool commented}) {
  if (!_isValid(validate)) {
    return null;
  }

  return TRowElement(
      id: id,
      classes: classes,
      style: style,
      attributes: attributes,
      cells: cells,
      commented: commented);
}

/// Creates a `td` node.
DOMElement $td(
        {DOMNodeValidator validate,
        id,
        classes,
        style,
        Map<String, String> attributes,
        content,
        bool commented}) =>
    $tag('td',
        validate: validate,
        id: id,
        classes: classes,
        style: style,
        attributes: attributes,
        content: content,
        commented: commented);

/// Creates a `th` node.
DOMElement $th(
        {DOMNodeValidator validate,
        id,
        classes,
        style,
        Map<String, String> attributes,
        content,
        bool commented}) =>
    $tag('td',
        validate: validate,
        id: id,
        classes: classes,
        style: style,
        attributes: attributes,
        content: content,
        commented: commented);

/// Creates a `div` node.
DIVElement $div(
        {DOMNodeValidator validate,
        id,
        classes,
        style,
        Map<String, String> attributes,
        content,
        bool commented}) =>
    $tag('div',
        validate: validate,
        id: id,
        classes: classes,
        style: style,
        attributes: attributes,
        content: content,
        commented: commented);

/// Creates a `div` node with `display: inline-block`.
DIVElement $divInline(
        {DOMNodeValidator validate,
        id,
        classes,
        style,
        Map<String, String> attributes,
        content,
        bool commented}) =>
    $tag('div',
        validate: validate,
        id: id,
        classes: classes,
        style: toFlatListOfStrings(['display: inline-block', style],
            delimiter: CSS_LIST_DELIMITER),
        attributes: attributes,
        content: content,
        commented: commented);

/// Creates a `div` node from HTML.
DIVElement $divHTML(dynamic html) => $tagHTML(html);

/// Creates a `div` that centers vertically and horizontally using `display` `table` and `table-cell`.
DIVElement $divCenteredContent(
    {String width = '100%', String height = '100%', dynamic content}) {
  var cssDimension = '';
  if (isNotEmptyString(width)) cssDimension += 'width: $width;';
  if (isNotEmptyString(height)) cssDimension += 'height: $height;';

  return $div(
      style: 'display: table;$cssDimension',
      content: $div(
          style:
              'display: table-cell; text-align: center; vertical-align: middle;',
          content: content));
}

/// Creates a `span` node.
DOMElement $span(
        {DOMNodeValidator validate,
        id,
        classes,
        style,
        Map<String, String> attributes,
        content,
        bool commented}) =>
    $tag('span',
        validate: validate,
        id: id,
        classes: classes,
        style: style,
        attributes: attributes,
        content: content,
        commented: commented);

/// Creates a `button` node.
DOMElement $button(
        {DOMNodeValidator validate,
        id,
        classes,
        style,
        type,
        Map<String, String> attributes,
        content,
        bool commented}) =>
    $tag('button',
        validate: validate,
        id: id,
        classes: classes,
        style: style,
        attributes: {
          'type': isNotEmptyString(type) ? type : 'button',
          ...?attributes
        },
        content: content,
        commented: commented);

/// Creates a `label` node.
DOMElement $label(
        {DOMNodeValidator validate,
        id,
        forID,
        classes,
        style,
        Map<String, String> attributes,
        content,
        bool commented}) =>
    $tag('label',
        validate: validate,
        id: id,
        classes: classes,
        style: style,
        attributes: {if (forID != null) 'for': forID, ...?attributes},
        content: content,
        commented: commented);

/// Creates a `textarea` node.
TEXTAREAElement $textarea(
    {DOMNodeValidator validate,
    id,
    name,
    classes,
    style,
    cols,
    rows,
    Map<String, String> attributes,
    content,
    bool commented}) {
  if (!_isValid(validate)) {
    return null;
  }
  return TEXTAREAElement(
      id: id,
      name: name,
      classes: classes,
      style: style,
      cols: cols,
      rows: rows,
      attributes: attributes,
      content: content,
      commented: commented);
}

/// Creates an `input` node.
INPUTElement $input(
    {DOMNodeValidator validate,
    id,
    name,
    classes,
    style,
    type,
    placeholder,
    Map<String, String> attributes,
    value,
    bool commented}) {
  if (!_isValid(validate)) {
    return null;
  }
  return INPUTElement(
      id: id,
      name: name,
      type: type,
      placeholder: placeholder,
      classes: classes,
      style: style,
      attributes: attributes,
      value: value,
      commented: commented);
}

/// Creates an `img` node.
DOMElement $img(
        {DOMNodeValidator validate,
        id,
        classes,
        style,
        Map<String, String> attributes,
        String src,
        String title,
        content,
        bool commented}) =>
    $tag('img',
        validate: validate,
        id: id,
        classes: classes,
        style: style,
        attributes: {
          if (src != null) 'src': src,
          if (title != null) 'title': title,
          ...?attributes
        },
        content: content,
        commented: commented);

/// Creates an `a` node.
DOMElement $a(
        {DOMNodeValidator validate,
        id,
        classes,
        style,
        Map<String, String> attributes,
        String href,
        String target,
        content,
        bool commented}) =>
    $tag('a',
        validate: validate,
        id: id,
        classes: classes,
        style: style,
        attributes: {
          if (href != null) 'href': href,
          if (target != null) 'target': target,
          ...?attributes
        },
        content: content,
        commented: commented);

/// Creates a `p` node.
DOMElement $p(
        {DOMNodeValidator validate,
        id,
        classes,
        style,
        Map<String, String> attributes,
        bool commented}) =>
    $tag('p',
        validate: validate,
        id: id,
        classes: classes,
        style: style,
        attributes: attributes,
        commented: commented);

/// Creates a `br` node.
DOMElement $br({int amount, bool commented}) {
  amount ??= 1;

  if (amount <= 0) {
    return null;
  } else if (amount == 1) {
    return $tag('br', commented: commented);
  } else {
    var list = <DOMElement>[];
    while (list.length < amount) {
      list.add($tag('br', commented: commented));
    }
    return $span(content: list, commented: commented);
  }
}

String $nbsp([int length = 1]) {
  length ??= 1;
  if (length < 1) return '';

  var s = StringBuffer('&nbsp;');
  for (var i = 1; i < length; i++) {
    s.write('&nbsp;');
  }

  return s.toString();
}

/// Creates a `hr` node.
DOMElement $hr(
        {DOMNodeValidator validate,
        id,
        classes,
        style,
        Map<String, String> attributes,
        bool commented}) =>
    $tag('hr',
        validate: validate,
        id: id,
        classes: classes,
        style: style,
        attributes: attributes,
        commented: commented);

/// Creates a `form` node.
DOMElement $form(
        {DOMNodeValidator validate,
        id,
        classes,
        style,
        Map<String, String> attributes,
        content,
        bool commented}) =>
    $tag('form',
        validate: validate,
        id: id,
        classes: classes,
        style: style,
        attributes: attributes,
        content: content,
        commented: commented);

/// Creates a `nav` node.
DOMElement $nav(
        {DOMNodeValidator validate,
        id,
        classes,
        style,
        Map<String, String> attributes,
        content,
        bool commented}) =>
    $tag('nav',
        validate: validate,
        id: id,
        classes: classes,
        style: style,
        attributes: attributes,
        content: content,
        commented: commented);

/// Creates a `header` node.
DOMElement $header(
        {DOMNodeValidator validate,
        id,
        classes,
        style,
        Map<String, String> attributes,
        content,
        bool commented}) =>
    $tag('header',
        validate: validate,
        id: id,
        classes: classes,
        style: style,
        attributes: attributes,
        content: content,
        commented: commented);

/// Creates a `footer` node.
DOMElement $footer(
        {DOMNodeValidator validate,
        id,
        classes,
        style,
        Map<String, String> attributes,
        content,
        bool commented}) =>
    $tag('footer',
        validate: validate,
        id: id,
        classes: classes,
        style: style,
        attributes: attributes,
        content: content,
        commented: commented);

/// Returns [true] if [f] is a DOM Builder helper, like `$div` and `$br`.
///
/// Note: A direct helper is only for tags that don't need parameters to be valid.
bool isDOMBuilderDirectHelper(dynamic f) {
  if (f == null || !(f is Function)) return false;

  return identical(f, $br) ||
      identical(f, $p) ||
      identical(f, $nbsp) ||
      identical(f, $div) ||
      identical(f, $divInline) ||
      identical(f, $hr) ||
      identical(f, $form) ||
      identical(f, $nav) ||
      identical(f, $header) ||
      identical(f, $footer) ||
      identical(f, $table) ||
      identical(f, $tbody) ||
      identical(f, $thead) ||
      identical(f, $tfoot) ||
      identical(f, $td) ||
      identical(f, $tr);
}
