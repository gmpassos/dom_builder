import 'package:collection/collection.dart' show IterableExtension;
import 'package:dom_builder/dom_builder.dart';
import 'package:swiss_knife/swiss_knife.dart';

import 'dom_builder_base.dart';
import 'dom_builder_css.dart';
import 'dom_builder_html.dart';

// ignore: non_constant_identifier_names
final RegExp STRING_LIST_DELIMITER = RegExp(r'[,;\s]+');

// ignore: non_constant_identifier_names
final RegExp ARGUMENT_LIST_DELIMITER = RegExp(r'\s*,\s*');

// ignore: non_constant_identifier_names
final RegExp CSS_LIST_DELIMITER = RegExp(r'\s*;\s*');

final DOMHtml _domHTML = DOMHtml();

/// Parses [s] as a flat [List<String>].
///
/// [s] If is a [String] uses [delimiter] to split strings. If [s] is a [List] iterator over it and flatten sub lists.
/// [delimiter] Pattern to split [s] to list.
/// [trim] If [true] trims all strings.
List<String> parseListOfStrings(Object? s, Pattern delimiter,
    [bool trim = true]) {
  if (s == null) return <String>[];

  List<String> list;

  if (s is List) {
    list = s.map(parseString).whereType<String>().toList();
  } else {
    var str = parseString(s, '')!;
    if (trim) str = str.trim();
    list = str.split(delimiter);
  }

  if (trim) {
    list = list.map((e) => e.trim()).where((e) => e.isNotEmpty).toList();
  }

  return list;
}

final RegExp _regexpHtmlTag = RegExp(r'<\w+(?:>|\s)');

bool possiblyWithHTML(String? s) =>
    s != null && s.contains('<') && s.contains(_regexpHtmlTag);

final RegExp _regexpDependentTag =
    RegExp(r'^\s*<(tbody|thread|tfoot|tr|td|th)\W', multiLine: false);

/// Parses a [html] to nodes.
List<DOMNode>? parseHTML(String? html) {
  if (html == null) return null;

  var dependentTagMatch = _regexpDependentTag.firstMatch(html);

  if (dependentTagMatch != null) {
    var dependentTagName = dependentTagMatch.group(1)!.toLowerCase();

    late Object parsed;
    if (dependentTagName == 'td' || dependentTagName == 'th') {
      parsed =
          _domHTML.parse('<table><tbody><tr></tr>\n$html\n</tbody></table>')!;
    } else if (dependentTagName == 'tbody' ||
        dependentTagName == 'thead' ||
        dependentTagName == 'tfoot') {
      parsed = _domHTML.parse('<table>\n$html\n</table>')!;
    }

    var node = _domHTML.querySelector(parsed, dependentTagName);
    return [DOMNode.from(node)!];
  }

  var parsed = _domHTML.parse(html);

  var parsedNodes = _domHTML.getChildrenNodes(parsed);

  if (parsedNodes.isEmpty) {
    return null;
  } else if (parsedNodes.length == 1) {
    var node = parsedNodes[0];
    return [DOMNode.from(node)!];
  } else {
    while (parsedNodes.isNotEmpty) {
      var o = parsedNodes[0];
      if (_domHTML.isEmptyTextNode(o)) {
        parsedNodes.removeAt(0);
      } else {
        break;
      }
    }

    while (parsedNodes.isNotEmpty) {
      var i = parsedNodes.length - 1;
      var o = parsedNodes[i];
      if (_domHTML.isEmptyTextNode(o)) {
        parsedNodes.removeAt(i);
      } else {
        break;
      }
    }

    var domList =
        parsedNodes.map((e) => DOMNode.from(e)).whereType<DOMNode>().toList();

    return domList;
  }
}

/// Returns a list of nodes from [html].
List<DOMNode> $html<T extends DOMNode>(Object? html) {
  if (html == null) return <DOMNode>[];
  if (html is String) {
    return parseHTML(html) ?? <DOMNode>[];
  } else if (html is List) {
    return parseHTML(html.join('')) ?? <DOMNode>[];
  }

  throw ArgumentError("Can't parse type: ${html.runtimeType}");
}

bool _isTextTag(String? tag) {
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

/// Validates a [DOMNode] before return it.
///
/// - [node]: the [DOMNode] instance.
/// - [instantiator]: the node instantiator, in case of [node] is null.
/// - [preValidate]: validates the node before the instance is defined/created.
/// - [validate]: validates a node after the instance is defined/created
T? $validate<T extends DOMNode>(
    {bool Function()? preValidate,
    DOMNodeValidator<T>? validate,
    T? node,
    DOMNodeInstantiator<T>? instantiator,
    bool rethrowErrors = false}) {
  if (preValidate != null) {
    try {
      var preValid = preValidate();
      if (!preValid) return null;
    } catch (e, s) {
      if (rethrowErrors) {
        rethrow;
      } else {
        domBuilderLog("Error calling 'preValidate' function: $preValidate",
            error: e, stackTrace: s);
      }
    }
  }

  var theNode = node;
  if (theNode == null && instantiator != null) {
    try {
      theNode = instantiator();
    } catch (e, s) {
      domBuilderLog("Error calling 'instantiator' function: $instantiator",
          error: e, stackTrace: s);
    }
  }

  if (theNode == null) return null;

  if (validate != null) {
    try {
      var valid = validate(theNode);
      if (!valid) return null;
    } catch (e, s) {
      domBuilderLog("Error calling 'validate' function: $validate",
          error: e, stackTrace: s);
    }
  }

  return theNode;
}

DOMElement? $htmlRoot(Object? html,
    {String? defaultRootTag, bool? defaultTagDisplayInlineBlock}) {
  var nodes = $html(html);
  if (nodes.isEmpty) return null;

  if (nodes.length > 1) {
    nodes.removeWhere((e) => e is TextNode && e.text.trim().isEmpty);
    if (nodes.length == 1) {
      return nodes[0] as DOMElement;
    } else {
      Map<String, String>? attributes;
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

typedef DOMNodeInstantiator<T extends DOMNode> = T? Function();

typedef DOMNodeValidator<T extends DOMNode> = bool Function(T? node);

final RegExp _patternHtmlElementInit = RegExp(r'\s*<\w+', multiLine: false);
final RegExp _patternHtmlElementEnd = RegExp(r'>\s*$', multiLine: false);

bool isHTMLElement(String s) {
  return s.startsWith(_patternHtmlElementInit) &&
      _patternHtmlElementEnd.hasMatch(s);
}

final RegExp _patternHtmlElement = RegExp(r'<\w+.*>');

bool hasHTMLTag(String s) {
  return _patternHtmlElement.hasMatch(s);
}

final RegExp _patternHtmlEntity = RegExp(r'&(?:\w+|#\d+);');

bool hasHTMLEntity(String s) {
  return _patternHtmlEntity.hasMatch(s);
}

/// Creates a node with [tag].
DOMElement $tag(String tag,
    {Object? id,
    Object? classes,
    Object? style,
    Map<String, String>? attributes,
    Object? content,
    bool? hidden,
    bool commented = false}) {
  return DOMElement(tag,
      id: id,
      classes: classes,
      style: style,
      attributes: attributes,
      content: content,
      hidden: hidden,
      commented: commented);
}

/// Creates a tag node from [html].
T? $tagHTML<T extends DOMElement>(Object? html) =>
    $html<DOMElement>(html).firstWhereOrNull((e) => e is T) as T?;

/// Creates a list of nodes of same [tag].
List<DOMElement> $tags<T>(String tag, Iterable<T>? iterable,
    [ContentGenerator<T>? elementGenerator]) {
  var elements = <DOMElement>[];
  if (iterable == null) return elements;

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
    {Object? id,
    Object? classes,
    Object? style,
    Object? thsStyle,
    Object? tdsStyle,
    Object? trsStyle,
    Map<String, String>? attributes,
    Object? caption,
    Object? head,
    Object? body,
    Object? foot,
    bool? hidden,
    bool commented = false}) {
  var tableElement = TABLEElement(
      id: id,
      classes: classes,
      style: style,
      attributes: attributes,
      caption: caption,
      head: head,
      body: body,
      foot: foot,
      hidden: hidden,
      commented: commented);

  if (thsStyle != null) {
    var css = CSS(thsStyle);
    tableElement
        .selectAllByType<THElement>()
        .forEach((e) => e.style.putAll(css.entries));
  }

  if (tdsStyle != null) {
    var css = CSS(tdsStyle);
    tableElement
        .selectAllByType<TDElement>()
        .forEach((e) => e.style.putAll(css.entries));
  }

  if (trsStyle != null) {
    var css = CSS(trsStyle);
    tableElement
        .selectAllByType<TRowElement>()
        .forEach((e) => e.style.putAll(css.entries));
  }

  return tableElement;
}

/// Creates a `thread` node.
THEADElement $thead(
    {Object? id,
    Object? classes,
    Object? style,
    Map<String, String>? attributes,
    Object? rows,
    bool? hidden,
    bool commented = false}) {
  return THEADElement(
      id: id,
      classes: classes,
      style: style,
      attributes: attributes,
      rows: rows,
      hidden: hidden,
      commented: commented);
}

/// Creates a `caption` node.
CAPTIONElement $caption(
    {Object? id,
    Object? classes,
    Object? style,
    String? captionSide,
    Map<String, String>? attributes,
    Object? content,
    bool? hidden,
    bool commented = false}) {
  return CAPTIONElement(
      id: id,
      classes: classes,
      style: isNotEmptyString(captionSide)
          ? (style != null
              ? 'caption-side: $captionSide; ${CSS(style).style}'
              : 'caption-side: $captionSide;')
          : style,
      attributes: attributes,
      content: content,
      hidden: hidden,
      commented: commented);
}

/// Creates a `tbody` node.
TBODYElement $tbody(
    {Object? id,
    Object? classes,
    Object? style,
    Map<String, String>? attributes,
    Object? rows,
    bool? hidden,
    bool commented = false}) {
  return TBODYElement(
      id: id,
      classes: classes,
      style: style,
      attributes: attributes,
      rows: rows,
      hidden: hidden,
      commented: commented);
}

/// Creates a `tfoot` node.
TFOOTElement $tfoot(
    {Object? id,
    Object? classes,
    Object? style,
    Map<String, String>? attributes,
    Object? rows,
    bool? hidden,
    bool commented = false}) {
  return TFOOTElement(
      id: id,
      classes: classes,
      style: style,
      attributes: attributes,
      rows: rows,
      hidden: hidden,
      commented: commented);
}

/// Creates a `tr` node.
TRowElement $tr(
    {Object? id,
    Object? classes,
    Object? style,
    Map<String, String>? attributes,
    Object? cells,
    bool? hidden,
    bool commented = false}) {
  return TRowElement(
      id: id,
      classes: classes,
      style: style,
      attributes: attributes,
      cells: cells,
      hidden: hidden,
      commented: commented);
}

/// Creates a `td` node.
DOMElement $td(
        {Object? id,
        Object? classes,
        Object? style,
        Map<String, String>? attributes,
        int? colspan,
        int? rowspan,
        String? headers,
        Object? content,
        bool? hidden,
        bool commented = false}) =>
    $tag('td',
        id: id,
        classes: classes,
        style: style,
        attributes: {
          if (colspan != null) 'colspan': '$colspan',
          if (rowspan != null) 'rowspan': '$rowspan',
          if (headers != null) 'headers': headers,
          ...?attributes,
        },
        content: content,
        hidden: hidden,
        commented: commented);

/// Creates a `th` node.
DOMElement $th(
        {Object? id,
        Object? classes,
        Object? style,
        Map<String, String>? attributes,
        int? colspan,
        int? rowspan,
        String? abbr,
        String? scope,
        Object? content,
        bool? hidden,
        bool commented = false}) =>
    $tag('td',
        id: id,
        classes: classes,
        style: style,
        attributes: {
          if (colspan != null) 'colspan': '$colspan',
          if (rowspan != null) 'rowspan': '$rowspan',
          if (abbr != null) 'abbr': abbr,
          if (scope != null) 'scope': scope,
          ...?attributes,
        },
        content: content,
        hidden: hidden,
        commented: commented);

/// Creates a `div` node.
DIVElement $div(
        {Object? id,
        Object? classes,
        Object? style,
        Map<String, String>? attributes,
        Object? content,
        bool? hidden,
        bool commented = false}) =>
    $tag('div',
        id: id,
        classes: classes,
        style: style,
        attributes: attributes,
        content: content,
        hidden: hidden,
        commented: commented) as DIVElement;

/// Creates a `div` node with `display: inline-block`.
DIVElement $divInline(
        {Object? id,
        Object? classes,
        Object? style,
        Map<String, String>? attributes,
        Object? content,
        bool? hidden,
        bool commented = false}) =>
    $tag('div',
        id: id,
        classes: classes,
        style: toFlatListOfStrings(['display: inline-block', style],
            delimiter: CSS_LIST_DELIMITER),
        attributes: attributes,
        content: content,
        hidden: hidden,
        commented: commented) as DIVElement;

/// Creates a `div` node from HTML.
DIVElement? $divHTML(Object? html) => $tagHTML(html);

/// Creates a `div` that centers vertically and horizontally using `display` `table` and `table-cell`.
DIVElement $divCenteredContent({
  Object? classes,
  String? style,
  String width = '100%',
  String height = '100%',
  String? cellsClasses,
  String? cellsStyle,
  String? cellSpacing,
  int? cellsPerRow,
  List? cells,
  List? rows,
  Object? content,
}) {
  var cssDimension = '';
  if (isNotEmptyString(width)) cssDimension += 'width: $width;';
  if (isNotEmptyString(height)) cssDimension += 'height: $height;';

  var divStyle = 'display: table;$cssDimension';

  if (isNotEmptyString(style, trim: true)) {
    style = style!.trim();
    if (!style.endsWith(';')) style += ';';
    divStyle += ' ; $style';
  }

  if (isNotEmptyString(cellSpacing, trim: true)) {
    divStyle += ' ; border-spacing: $cellSpacing ;';
  }

  cellsStyle ??= '';
  cellsStyle = cellsStyle.trim();

  cellsClasses ??= '';
  cellsClasses = cellsClasses.trim();

  rows ??= [];

  if (cells != null) {
    if (cellsPerRow == null || cellsPerRow <= 0) {
      rows.add(cells);
    } else {
      var row = [];
      for (var i = 0; i < cells.length; ++i) {
        var cell = cells[i];
        row.add(cell);
        if (row.length == cellsPerRow) {
          rows.add(row);
          row = [];
        }
      }
      if (row.isNotEmpty) {
        rows.add(row);
      }
    }
  }

  var list = [];

  for (var row in rows) {
    var rowList = row is List ? row : [row];

    var rowCells = rowList
        .map((e) => $div(
              classes: cellsClasses,
              style:
                  'display: table-cell; text-align: center; vertical-align: middle; $cellsStyle',
              content: e,
            ))
        .toList();

    var rowDiv = $div(
      style: 'display: table-row;',
      content: rowCells,
    );

    list.add(rowDiv);
  }

  if (content != null) {
    list.add($div(
      classes: cellsClasses,
      style:
          'display: table-cell; text-align: center; vertical-align: middle; $cellsStyle',
      content: content,
    ));
  }

  return $div(classes: classes, style: divStyle, content: list);
}

/// Creates a `div` node with `display: inline-block`.
DOMAsync $asyncContent({
  final Object? loading,
  Future? future,
  final Future Function()? function,
}) {
  return DOMAsync(loading: loading, future: future, function: function);
}

/// Creates a `span` node.
DOMElement $span(
        {Object? id,
        Object? classes,
        Object? style,
        Map<String, String>? attributes,
        Object? content,
        bool? hidden,
        bool commented = false}) =>
    $tag('span',
        id: id,
        classes: classes,
        style: style,
        attributes: attributes,
        content: content,
        hidden: hidden,
        commented: commented);

/// Creates a `button` node.
DOMElement $button(
        {Object? id,
        Object? classes,
        Object? style,
        String? type,
        Map<String, String>? attributes,
        Object? content,
        bool? hidden,
        bool commented = false}) =>
    $tag('button',
        id: id,
        classes: classes,
        style: style,
        attributes: {
          'type': isNotEmptyString(type) ? type! : 'button',
          ...?attributes
        },
        content: content,
        hidden: hidden,
        commented: commented);

/// Creates a `label` node.
DOMElement $label(
        {Object? id,
        String? forID,
        Object? classes,
        Object? style,
        Map<String, String>? attributes,
        Object? content,
        bool? hidden,
        bool commented = false}) =>
    $tag('label',
        id: id,
        classes: classes,
        style: style,
        attributes: {if (forID != null) 'for': forID, ...?attributes},
        content: content,
        hidden: hidden,
        commented: commented);

/// Creates a `textarea` node.
TEXTAREAElement $textarea(
    {Object? id,
    Object? name,
    Object? classes,
    Object? style,
    Object? cols,
    Object? rows,
    Map<String, String>? attributes,
    Object? content,
    bool? hidden,
    bool commented = false}) {
  return TEXTAREAElement(
      id: id,
      name: name,
      classes: classes,
      style: style,
      cols: cols,
      rows: rows,
      attributes: attributes,
      content: content,
      hidden: hidden,
      commented: commented);
}

/// Creates an `input` node.
INPUTElement $input(
    {Object? id,
    Object? name,
    Object? classes,
    Object? style,
    Object? type,
    Object? placeholder,
    Map<String, String>? attributes,
    Object? value,
    bool? hidden,
    bool commented = false}) {
  return INPUTElement(
      id: id,
      name: name,
      type: type,
      placeholder: placeholder,
      classes: classes,
      style: style,
      attributes: attributes,
      value: value,
      hidden: hidden,
      commented: commented);
}

/// Creates an `input` node of type `checkbox`.
INPUTElement $checkbox(
    {Object? id,
    Object? name,
    Object? classes,
    Object? style,
    Object? placeholder,
    Map<String, String>? attributes,
    Object? value,
    bool? hidden,
    bool commented = false}) {
  return INPUTElement(
      id: id,
      name: name,
      type: 'checkbox',
      placeholder: placeholder,
      classes: classes,
      style: style,
      attributes: attributes,
      value: value,
      hidden: hidden,
      commented: commented);
}

/// Creates an `select` node.
SELECTElement $select(
    {Object? id,
    Object? name,
    Object? classes,
    Object? style,
    Map<String, String>? attributes,
    Object? options,
    Object? selected,
    bool? multiple,
    bool? hidden,
    bool commented = false}) {
  var selectElement = SELECTElement(
      id: id,
      name: name,
      classes: classes,
      style: style,
      attributes: attributes,
      options: options,
      multiple: multiple,
      hidden: hidden,
      commented: commented);

  selectElement.selectOption(selected);

  return selectElement;
}

/// Creates an `option` node.
OPTIONElement $option(
    {Object? classes,
    Object? style,
    Map<String, String>? attributes,
    Object? value,
    String? label,
    bool? selected,
    Object? text,
    Object? valueAndText}) {
  return OPTIONElement(
      classes: classes,
      style: style,
      attributes: attributes,
      value: value ?? valueAndText,
      label: label,
      selected: selected,
      text: DOMNode.toText(text ?? valueAndText));
}

/// Creates an `img` node.
DOMElement $img(
    {Object? id,
    Object? classes,
    Object? style,
    Map<String, String>? attributes,
    String? src,
    Future<String?>? srcFuture,
    String? title,
    Object? content,
    bool? hidden,
    bool commented = false}) {
  var img = $tag('img',
      id: id,
      classes: classes,
      style: style,
      attributes: {
        if (src != null) 'src': src,
        if (title != null) 'title': title,
        ...?attributes
      },
      content: content,
      hidden: hidden,
      commented: commented);

  if (srcFuture != null) {
    srcFuture.then((src) {
      if (src != null) {
        img.setAttribute('src', src);
        img.runtime.setAttribute('src', src);
      }
      return src;
    });
  }

  return img;
}

/// Creates an `a` node.
DOMElement $a(
        {Object? id,
        Object? classes,
        Object? style,
        Map<String, String>? attributes,
        String? href,
        String? target,
        Object? content,
        bool? hidden,
        bool commented = false}) =>
    $tag('a',
        id: id,
        classes: classes,
        style: style,
        attributes: {
          if (href != null) 'href': href,
          if (target != null) 'target': target,
          ...?attributes
        },
        content: content,
        hidden: hidden,
        commented: commented);

/// Creates a `p` node.
DOMElement $p(
        {Object? id,
        Object? classes,
        Object? style,
        Map<String, String>? attributes,
        bool? hidden,
        bool commented = false}) =>
    $tag('p',
        id: id,
        classes: classes,
        style: style,
        attributes: attributes,
        hidden: hidden,
        commented: commented);

/// Creates a `br` node.
DOMElement $br({int amount = 1, bool commented = false}) {
  if (amount <= 0) {
    return $tag('br', commented: true);
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
  if (length < 1) return '';

  var s = StringBuffer('&nbsp;');
  for (var i = 1; i < length; i++) {
    s.write('&nbsp;');
  }

  return s.toString();
}

/// Creates a `hr` node.
DOMElement $hr(
        {Object? id,
        Object? classes,
        Object? style,
        Map<String, String>? attributes,
        bool? hidden,
        bool commented = false}) =>
    $tag('hr',
        id: id,
        classes: classes,
        style: style,
        attributes: attributes,
        hidden: hidden,
        commented: commented);

/// Creates a `form` node.
DOMElement $form(
        {Object? id,
        Object? classes,
        Object? style,
        Map<String, String>? attributes,
        Object? content,
        bool? hidden,
        bool commented = false}) =>
    $tag('form',
        id: id,
        classes: classes,
        style: style,
        attributes: attributes,
        content: content,
        hidden: hidden,
        commented: commented);

/// Creates a `nav` node.
DOMElement $nav(
        {Object? id,
        Object? classes,
        Object? style,
        Map<String, String>? attributes,
        Object? content,
        bool? hidden,
        bool commented = false}) =>
    $tag('nav',
        id: id,
        classes: classes,
        style: style,
        attributes: attributes,
        content: content,
        hidden: hidden,
        commented: commented);

/// Creates a `header` node.
DOMElement $header(
        {Object? id,
        Object? classes,
        Object? style,
        Map<String, String>? attributes,
        Object? content,
        bool? hidden,
        bool commented = false}) =>
    $tag('header',
        id: id,
        classes: classes,
        style: style,
        attributes: attributes,
        content: content,
        hidden: hidden,
        commented: commented);

/// Creates a `footer` node.
DOMElement $footer(
        {Object? id,
        Object? classes,
        Object? style,
        Map<String, String>? attributes,
        Object? content,
        bool? hidden,
        bool commented = false}) =>
    $tag('footer',
        id: id,
        classes: classes,
        style: style,
        attributes: attributes,
        content: content,
        hidden: hidden,
        commented: commented);

/// Returns [true] if [f] is a DOM Builder helper, like `$div` and `$br`.
///
/// Note: A direct helper is only for tags that don't need parameters to be valid.
bool isDOMBuilderDirectHelper(Object? f) {
  if (f == null || f is! Function) return false;

  return identical(f, $br) ||
      identical(f, $p) ||
      identical(f, $a) ||
      identical(f, $nbsp) ||
      identical(f, $div) ||
      identical(f, $divInline) ||
      identical(f, $img) ||
      identical(f, $hr) ||
      identical(f, $form) ||
      identical(f, $nav) ||
      identical(f, $header) ||
      identical(f, $footer) ||
      identical(f, $span) ||
      identical(f, $button) ||
      identical(f, $label) ||
      identical(f, $textarea) ||
      identical(f, $input) ||
      identical(f, $select) ||
      identical(f, $option) ||
      identical(f, $table) ||
      identical(f, $tbody) ||
      identical(f, $thead) ||
      identical(f, $tfoot) ||
      identical(f, $td) ||
      identical(f, $th) ||
      identical(f, $tr) ||
      identical(f, $caption);
}
