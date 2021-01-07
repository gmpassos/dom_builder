import 'package:swiss_knife/swiss_knife.dart';

final RegExpDialect _TEMPLATE_DIALECT = RegExpDialect({
  'o': r'\{\{\s*',
  'c': r'\s*\}\}',
  'key': r'\w[\w-]*',
  'quote': r'''(?:"[^"]*"|'[^']*')''',
  'var': r'$key(?:\.$key)*',
  'cmp': r'(?:==|!=)',
  'tag':
      r'$o([\:\!\?\/\#\.]|[\?\*][:!]|\.)?($var)?(?:($cmp)(?:($quote)|($var)))?$c',
}, multiLine: false, caseSensitive: false);

abstract class DOMTemplate {
  factory DOMTemplate.from(dynamic value) {
    if (value == null) return null;
    if (value is DOMTemplate) return value;
    if (value is String) return DOMTemplate.parse(value);
    return null;
  }

  DOMTemplate();

  bool get isEmpty;

  bool get isNotEmpty => !isEmpty;

  /// Returns [true] if [s] can be a templace code, has `{{` and `}}`.
  static bool possiblyATemplate(String s) {
    var idx = s.indexOf('{{');
    if (idx < 0) return false;
    var idx2 = s.indexOf('}}', idx);
    return idx2 > 0;
  }

  static final RegExp REGEXP_TAG = _TEMPLATE_DIALECT.getPattern(r'$tag');
  static final RegExp REGEXP_QUERY = _TEMPLATE_DIALECT.getPattern(r'$query');

  /// Tries to parse [s].
  ///
  /// Returns [null] if [s] has no template or a not valid template code.
  static DOMTemplateNode tryParse(String s) {
    return _parse(s, true);
  }

  /// Parses [s] and returns a DOMTemplateNode.
  ///
  /// Throws [StateError] if [s] is not a valid template.
  static DOMTemplateNode parse(String s) {
    return _parse(s, false);
  }

  static DOMTemplateNode _parse(String s, bool tryParsing) {
    var matches = REGEXP_TAG.allMatches(s);
    if (matches == null || matches.isEmpty) {
      if (tryParsing) return null;
      return DOMTemplateNode([DOMTemplateContent(s)]);
    }

    var root = DOMTemplateNode([]);
    var stack = <DOMTemplateNode>[];
    DOMTemplate cursor = root;
    var start = 0;

    for (var m in matches) {
      var prev = s.substring(start, m.start);
      start = m.end;

      if (prev.isNotEmpty) {
        cursor.add(DOMTemplateContent(prev));
      }

      var type = m.group(1);
      var key = m.group(2);
      var cmp = m.group(3);
      var valueQuote = m.group(4);
      var valueVar = m.group(5);

      if (type == null) {
        if (key != null) {
          var o = DOMTemplateBlockVar.parse(key);
          cursor.add(o);
        }
        continue;
      }

      if (key == null) {
        switch (type) {
          case '?':
            {
              var condition = cursor as DOMTemplateBlockCondition;
              var o = DOMTemplateBlockElse();
              condition.elseCondition = o;

              stack.add(cursor);
              cursor = o;
              break;
            }
          case '.':
            {
              var o = DOMTemplateBlockVar(DOMTemplateVariable([]));
              cursor.add(o);
              break;
            }
          case '/':
            {
              if (cursor is DOMTemplateBlock) {
                if (key != null && cursor.variable.keysFull != key) {
                  if (tryParsing) return null;
                  throw StateError(
                      'Error paring! Current block with different key: ${cursor.variable.keysFull} != $key');
                }
              } else {
                if (tryParsing) return null;
                throw StateError(
                    'Error paring! No block open: $cursor > $stack');
              }

              while ((cursor is DOMTemplateBlockElseCondition) ||
                  (cursor is DOMTemplateBlockIfCmp && cursor.elseIf)) {
                cursor = stack.removeLast();
              }

              cursor = stack.removeLast();

              break;
            }
          default:
            {
              if (tryParsing) return null;
              throw StateError(
                  'Error paring block type: $type > ${m.group(0)}');
            }
        }
      } else {
        switch (type) {
          case ':':
            {
              var variable = DOMTemplateVariable.parse(key);

              DOMTemplateBlockIf block;

              if (cmp != null) {
                dynamic value;

                if (valueQuote != null) {
                  value = DOMTemplateContent(
                      valueQuote.substring(1, valueQuote.length - 1));
                } else if (valueVar != null) {
                  value = DOMTemplateVariable.parse(valueVar);
                }

                block = DOMTemplateBlockIfCmp(false, variable, cmp, value);
              } else {
                block = DOMTemplateBlockIf(variable);
              }

              cursor.add(block);
              stack.add(cursor);
              cursor = block;
              break;
            }
          case '?:':
            {
              var condition = cursor as DOMTemplateBlockCondition;

              var variable = DOMTemplateVariable.parse(key);

              DOMTemplateBlockCondition block;

              if (cmp != null) {
                dynamic value;

                if (valueQuote != null) {
                  value = DOMTemplateContent(
                      valueQuote.substring(1, valueQuote.length - 1));
                } else if (valueVar != null) {
                  value = DOMTemplateVariable.parse(valueVar);
                }

                block = DOMTemplateBlockIfCmp(true, variable, cmp, value);
              } else {
                block = DOMTemplateBlockElseIf(variable);
              }

              condition.elseCondition = block;

              stack.add(cursor);
              cursor = block;
              break;
            }
          case '!':
            {
              var variable = DOMTemplateVariable.parse(key);
              var o = DOMTemplateBlockNot(variable);
              cursor.add(o);
              stack.add(cursor);
              cursor = o;
              break;
            }
          case '?!':
            {
              var condition = cursor as DOMTemplateBlockCondition;

              var variable = DOMTemplateVariable.parse(key);
              var o = DOMTemplateBlockElseNot(variable);

              condition.elseCondition = o;

              cursor.add(o);
              stack.add(cursor);
              cursor = o;
              break;
            }
          case '?':
            {
              var variable = DOMTemplateVariable.parse(key);
              var o = DOMTemplateBlockVarElse(variable);
              cursor.add(o);
              stack.add(cursor);
              cursor = o;
              break;
            }
          case '*:':
            {
              var variable = DOMTemplateVariable.parse(key);
              var o = DOMTemplateBlockIfCollection(variable);
              cursor.add(o);
              stack.add(cursor);
              cursor = o;
              break;
            }
          case '#':
          case '.':
            {
              var o = DOMTemplateBlockQuery('$type$key');
              cursor.add(o);
              break;
            }
          case '/':
            {
              if (cursor is DOMTemplateBlock) {
                if (key != null && cursor.variable.keysFull != key) {
                  if (tryParsing) return null;
                  throw StateError(
                      'Error paring! Current block with different key: ${cursor.variable.keysFull} != $key');
                }
              } else {
                if (tryParsing) return null;
                throw StateError(
                    'Error paring! No block open: $cursor > $stack <${s.length < 100 ? s : s.substring(0, 100) + '...'}>');
              }

              cursor = stack.removeLast();
              break;
            }
          default:
            {
              if (tryParsing) return null;
              throw StateError(
                  'Error paring block type: $type > ${m.group(0)}');
            }
        }
      }
    }

    if (start < s.length) {
      var prev = s.substring(start);
      if (prev.isNotEmpty) {
        root.add(DOMTemplateContent(prev));
      }
    }

    if (stack.isNotEmpty) {
      if (tryParsing) return null;
      throw StateError('Error parsing! Block still open: $stack');
    }

    if (tryParsing && root.isEmpty) return null;

    return root;
  }

  String build(dynamic context, {ElementHTMLProvider elementProvider});

  bool add(DOMTemplate entry) {
    throw UnsupportedError("Type can't have content: $runtimeType");
  }

  @override
  String toString();
}

typedef ElementHTMLProvider = String Function(String query);

class DOMTemplateNode extends DOMTemplate {
  List<DOMTemplate> nodes;

  DOMTemplateNode([List<DOMTemplate> nodes]) : nodes = nodes ?? <DOMTemplate>[];

  @override
  bool get isEmpty {
    if (nodes.isEmpty) return true;
    for (var node in nodes) {
      if (node.isNotEmpty) return false;
    }
    return true;
  }

  bool get hasOnlyContent {
    for (var node in nodes) {
      if (!(node is DOMTemplateContent)) return false;
    }
    return true;
  }

  @override
  String build(dynamic context, {ElementHTMLProvider elementProvider}) {
    if (nodes.isEmpty) return '';

    var s = StringBuffer();
    for (var n in nodes) {
      s.write(n.build(context, elementProvider: elementProvider));
    }
    return s.toString();
  }

  @override
  bool add(DOMTemplate entry) {
    if (entry == null) return false;
    nodes.add(entry);
    return true;
  }

  bool addAll(List<DOMTemplate> entries) {
    if (entries == null || entries.isEmpty) return false;
    nodes.addAll(entries);
    return true;
  }

  void clear() {
    nodes.clear();
  }

  @override
  String toString() => _toStringNodes();

  String _toStringNodes() {
    return nodes != null && nodes.isNotEmpty ? nodes.join() : '';
  }
}

class DOMTemplateVariable {
  final List<String> keys;

  DOMTemplateVariable(this.keys);

  factory DOMTemplateVariable.parse(String s) {
    if (s == null) return null;
    s = s.trim();
    if (s.isEmpty) return null;

    var keys = s.split('.');
    return DOMTemplateVariable(keys);
  }

  String get keysFull => keys.join('.');

  dynamic get(dynamic context) {
    if (context == null || isEmptyObject(context)) return null;

    var length = keys.length;
    if (length == 0) return context;

    dynamic value = _get(context, keys[0]);

    for (var i = 1; i < length; ++i) {
      var k = keys[i];
      value = _get(value, k);
    }

    return value;
  }

  dynamic _get(dynamic context, String key) {
    if (context == null || isEmptyObject(context) || isEmptyString(key)) {
      return null;
    }

    if (context is Iterable) {
      context = (context as Iterable).toList();
    }

    if (context is Map) {
      if (context.containsKey(key)) {
        return context[key];
      } else if (isInt(key)) {
        var n = parseInt(key);
        return context[n];
      }
    } else if (context is List) {
      int idx;
      if (isInt(key)) {
        idx = parseInt(key);
      } else {
        key = key.trim();
        if (isInt(key)) {
          idx = parseInt(key);
        }
      }
      if (idx != null) {
        return idx < context.length ? context[idx] : null;
      }
    } else if (context is Set) {
      if (context.contains(key)) {
        return true;
      } else if (isInt(key)) {
        var n = parseInt(key);
        return context.contains(n);
      }
    }

    return null;
  }

  dynamic getResolved(dynamic context) {
    var value = get(context);
    return evaluateObject(context, value);
  }

  String getResolvedAsString(dynamic context) {
    var value = getResolved(context);
    return DOMTemplateVariable.valueToString(value);
  }

  static String valueToString(dynamic value) {
    if (value == null) return '';

    if (value is String) {
      return value;
    } else if (value is List) {
      return value.map(valueToString).join(',');
    } else if (value is Map) {
      return value
          .map((key, value) =>
              MapEntry(key, '${valueToString(key)}: ${valueToString(value)}'))
          .values
          .join('; ');
    } else {
      return '$value';
    }
  }

  static dynamic evaluateObject(dynamic context, dynamic value) {
    if (value == null) return null;

    if (value is String) {
      return value;
    } else if (value is bool) {
      return value;
    } else if (value is num) {
      return value;
    } else if (value is List) {
      return value.map((e) => evaluateObject(context, e)).toList();
    } else if (value is Map) {
      return Map.from(value.map((k, v) =>
          MapEntry(evaluateObject(context, k), evaluateObject(context, v))));
    } else if (value is Function(Map a)) {
      var res = value(context);
      return evaluateObject(context, res);
    } else if (value is Function(dynamic a)) {
      var res = value(context);
      return evaluateObject(context, res);
    } else if (value is Function()) {
      var res = value();
      return evaluateObject(context, res);
    } else {
      return value.toString();
    }
  }

  bool evaluate(dynamic context) {
    var value = getResolved(context);
    return evaluateValue(value);
  }

  bool evaluateValue(value) {
    if (value == null) return false;

    if (value is String) {
      return value.isNotEmpty;
    } else if (value is bool) {
      return value;
    } else if (value is num) {
      return value != 0;
    } else if (value is List) {
      return value.isNotEmpty;
    } else if (value is Map) {
      return value.isNotEmpty;
    } else {
      throw StateError("Can't evaluate value of type: ${value.runtimeType}");
    }
  }
}

class DOMTemplateContent extends DOMTemplate {
  final String content;

  DOMTemplateContent(this.content);

  @override
  bool get isEmpty => isEmptyString(content);

  @override
  String build(dynamic context, {ElementHTMLProvider elementProvider}) =>
      content;

  @override
  String toString() {
    return content ?? '';
  }
}

class DOMTemplateBlockVar extends DOMTemplateNode {
  final DOMTemplateVariable variable;

  DOMTemplateBlockVar(this.variable);

  factory DOMTemplateBlockVar.parse(String s) {
    return DOMTemplateBlockVar(DOMTemplateVariable.parse(s));
  }

  @override
  String build(dynamic context, {ElementHTMLProvider elementProvider}) {
    return variable.getResolvedAsString(context);
  }

  @override
  String toString() {
    return '{{${variable.keys.isEmpty ? '.' : variable.keysFull}}}';
  }
}

class DOMTemplateBlockQuery extends DOMTemplateNode {
  final String query;

  DOMTemplateBlockQuery(this.query);

  @override
  String build(dynamic context, {ElementHTMLProvider elementProvider}) {
    if (elementProvider == null) return '';
    var element = elementProvider(query);

    var template = DOMTemplate.parse(element);
    if (template != null && !template.hasOnlyContent) {
      return template.build(context, elementProvider: elementProvider);
    } else {
      return element ?? '';
    }
  }

  @override
  String toString() {
    return '{{$query}}';
  }
}

abstract class DOMTemplateBlock extends DOMTemplateNode {
  final DOMTemplateVariable variable;

  DOMTemplateBlock(this.variable, [DOMTemplateNode content]) {
    add(content);
  }
}

abstract class DOMTemplateBlockCondition extends DOMTemplateBlock {
  DOMTemplateBlockCondition(DOMTemplateVariable variable,
      [DOMTemplateNode content])
      : super(variable, content);

  DOMTemplateBlockCondition elseCondition;

  bool evaluate(dynamic context);

  @override
  String build(dynamic context, {ElementHTMLProvider elementProvider}) {
    if (evaluate(context)) {
      return buildContent(context, elementProvider: elementProvider);
    } else {
      var elseCondition = this.elseCondition;

      while (elseCondition != null) {
        if (elseCondition.evaluate(context)) {
          return elseCondition.build(context, elementProvider: elementProvider);
        }
        elseCondition = elseCondition.elseCondition;
      }

      return '';
    }
  }

  String buildContent(dynamic context, {ElementHTMLProvider elementProvider}) {
    if (nodes.isEmpty) return '';

    var s = StringBuffer();
    for (var n in nodes) {
      s.write(n.build(context, elementProvider: elementProvider));
    }

    return s.toString();
  }

  String _toStringRest() {
    if (elseCondition != null) {
      return elseCondition.toString();
    } else {
      return '{{/}}';
    }
  }
}

class DOMTemplateBlockIf extends DOMTemplateBlockCondition {
  DOMTemplateBlockIf(DOMTemplateVariable variable, [DOMTemplateNode content])
      : super(variable, content);

  @override
  bool evaluate(dynamic context) {
    return variable.evaluate(context);
  }

  @override
  String toString() {
    return '{{:${variable.keysFull}}}' + _toStringNodes() + _toStringRest();
  }
}

enum DOMTemplateCmp { eq, notEq }

String getDOMTemplateCmp_operator(DOMTemplateCmp cmp) {
  switch (cmp) {
    case DOMTemplateCmp.eq:
      return '==';
    case DOMTemplateCmp.notEq:
      return '!=';
    default:
      return '';
  }
}

DOMTemplateCmp parseDOMTemplateCmp(dynamic cmp) {
  if (cmp == null) return null;

  if (cmp is DOMTemplateCmp) return cmp;

  var s = cmp.toString().trim().toLowerCase();

  switch (s) {
    case ':':
    case 'eq':
    case '=':
    case '==':
      return DOMTemplateCmp.eq;
    case 'neq':
    case 'noteq':
    case '!':
    case '!=':
      return DOMTemplateCmp.notEq;
    default:
      return null;
  }
}

class DOMTemplateBlockIfCmp extends DOMTemplateBlockIf {
  final bool elseIf;

  final DOMTemplateCmp cmp;
  final dynamic value;

  DOMTemplateBlockIfCmp(
      this.elseIf, DOMTemplateVariable variable, dynamic cmp, this.value,
      [DOMTemplateNode content])
      : cmp = parseDOMTemplateCmp(cmp),
        super(variable, content);

  @override
  bool evaluate(dynamic context) {
    switch (cmp) {
      case DOMTemplateCmp.eq:
        return matchesEq(context);
      case DOMTemplateCmp.notEq:
        return !matchesEq(context);
      default:
        throw StateError("Can't handle: $cmp");
    }
  }

  bool matchesEq(dynamic context) {
    var varValueStr = variable.getResolvedAsString(context);
    var valueStr = getValueAsString(context);
    return varValueStr == valueStr;
  }

  String getValueAsString(dynamic context) {
    if (value is DOMTemplateContent) {
      var valueContent = value as DOMTemplateContent;
      return valueContent.content;
    } else if (value is DOMTemplateVariable) {
      var valueVar = value as DOMTemplateVariable;
      return valueVar.getResolvedAsString(context);
    } else {
      return value.toString();
    }
  }

  String toStringValue() {
    if (value is DOMTemplateContent) {
      var valueContent = value as DOMTemplateContent;
      var content = valueContent.content;
      return content.contains('"') ? "'$content'" : '"$content"';
    } else if (value is DOMTemplateVariable) {
      var valueVar = value as DOMTemplateVariable;
      return valueVar.keysFull;
    } else {
      return value.toString();
    }
  }

  @override
  String toString() {
    return '{{${elseIf ? '?' : ''}:${variable.keysFull}${getDOMTemplateCmp_operator(cmp)}${toStringValue()}}}' +
        _toStringNodes() +
        _toStringRest();
  }
}

class DOMTemplateBlockNot extends DOMTemplateBlockCondition {
  DOMTemplateBlockNot(DOMTemplateVariable variable, [DOMTemplateNode content])
      : super(variable, content);

  @override
  bool evaluate(dynamic context) {
    return !variable.evaluate(context);
  }

  @override
  String toString() {
    return '{{!${variable.keysFull}}}' + _toStringNodes() + _toStringRest();
  }
}

abstract class DOMTemplateBlockElseCondition extends DOMTemplateBlockCondition {
  DOMTemplateBlockElseCondition(DOMTemplateVariable variable,
      [DOMTemplateNode content])
      : super(variable, content);
}

class DOMTemplateBlockElse extends DOMTemplateBlockElseCondition {
  DOMTemplateBlockElse([DOMTemplateNode content]) : super(null, content);

  @override
  bool evaluate(dynamic context) {
    return true;
  }

  @override
  String toString() {
    return '{{?}}' + _toStringNodes() + _toStringRest();
  }
}

class DOMTemplateBlockElseIf extends DOMTemplateBlockElseCondition {
  DOMTemplateBlockElseIf(DOMTemplateVariable variable,
      [DOMTemplateNode content])
      : super(variable, content);

  @override
  bool evaluate(dynamic context) {
    return variable.evaluate(context);
  }

  @override
  String toString() {
    return '{{?:${variable.keysFull}}}' + _toStringNodes() + _toStringRest();
  }
}

class DOMTemplateBlockElseNot extends DOMTemplateBlockElseCondition {
  DOMTemplateBlockElseNot(DOMTemplateVariable variable,
      [DOMTemplateNode content])
      : super(variable, content);

  @override
  bool evaluate(dynamic context) {
    return !variable.evaluate(context);
  }

  @override
  String toString() {
    return '{{?!:${variable.keysFull}}' + _toStringRest();
  }
}

class DOMTemplateBlockVarElse extends DOMTemplateBlock {
  DOMTemplateBlockVarElse(DOMTemplateVariable variable,
      [DOMTemplate contentElse])
      : super(variable, contentElse);

  @override
  String build(dynamic context, {ElementHTMLProvider elementProvider}) {
    var value = variable.getResolved(context);
    if (variable.evaluateValue(value)) {
      return DOMTemplateVariable.valueToString(value);
    } else {
      return super.build(context, elementProvider: elementProvider);
    }
  }

  @override
  String toString() {
    return '{{?${variable.keysFull}}}' + _toStringNodes() + '{{/}}';
  }
}

class DOMTemplateBlockIfCollection extends DOMTemplateBlockCondition {
  DOMTemplateBlockIfCollection(DOMTemplateVariable variable,
      [DOMTemplateNode content])
      : super(variable, content);

  @override
  bool evaluate(dynamic context) {
    return variable.evaluate(context);
  }

  @override
  String buildContent(dynamic context, {ElementHTMLProvider elementProvider}) {
    var value = variable.getResolved(context);

    if (value is List) {
      var s = StringBuffer();
      for (var val in value) {
        s.write(super.buildContent(val, elementProvider: elementProvider));
      }
      return s.toString();
    } else if (value is Map) {
      return super.buildContent(value, elementProvider: elementProvider);
    } else {
      return super.buildContent(value, elementProvider: elementProvider);
    }
  }

  @override
  String toString() {
    return '{{*:${variable.keysFull}}}' + _toStringNodes() + _toStringRest();
  }
}
