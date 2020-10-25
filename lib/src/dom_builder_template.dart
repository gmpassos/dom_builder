import 'package:swiss_knife/swiss_knife.dart';

final RegExpDialect _TEMPLATE_DIALECT = RegExpDialect({
  'o': r'\{\{\s*',
  'c': r'\s*\}\}',
  'key': r'\w[\w-]*',
  'var': r'$key(?:\.$key)*',
  'tag': r'$o([\:\!\?\/\#\.]|[\?\*][:!])?($var)?$c',
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

  static final RegExp REGEXP_TAG = _TEMPLATE_DIALECT.getPattern(r'$tag');
  static final RegExp REGEXP_QUERY = _TEMPLATE_DIALECT.getPattern(r'$query');

  static DOMTemplateNode parse(String s) {
    var matches = REGEXP_TAG.allMatches(s);
    if (matches == null || matches.isEmpty) {
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
          case '/':
            {
              if (cursor is DOMTemplateBlock) {
                if (key != null && cursor.variable.keysFull != key) {
                  throw StateError(
                      'Error paring! Current block with different key: ${cursor.variable.keysFull} != $key');
                }
              } else {
                throw StateError(
                    'Error paring! No block open: $cursor > $stack');
              }

              while (cursor is DOMTemplateBlockElseCondition) {
                cursor = stack.removeLast();
              }

              cursor = stack.removeLast();

              break;
            }
          default:
            throw StateError('Error paring block type: $type > ${m.group(0)}');
        }
      } else {
        switch (type) {
          case ':':
            {
              var variable = DOMTemplateVariable.parse(key);
              var o = DOMTemplateBlockIf(variable);
              cursor.add(o);
              stack.add(cursor);
              cursor = o;
              break;
            }
          case '?:':
            {
              var condition = cursor as DOMTemplateBlockCondition;

              var variable = DOMTemplateVariable.parse(key);
              var o = DOMTemplateBlockElseIf(variable);
              condition.elseCondition = o;

              stack.add(cursor);
              cursor = o;
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
                  throw StateError(
                      'Error paring! Current block with different key: ${cursor.variable.keysFull} != $key');
                }
              } else {
                throw StateError(
                    'Error paring! No block open: $cursor > $stack');
              }

              cursor = stack.removeLast();
              break;
            }
          default:
            throw StateError('Error paring block type: $type > ${m.group(0)}');
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
      throw StateError('Error paring! Block still open: $stack');
    }

    return root;
  }

  String build(Map context, {ElementHTMLProvider elementProvider});

  bool add(DOMTemplate entry) {
    throw UnsupportedError("Type can't have content: $runtimeType");
  }
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
  String build(Map context, {ElementHTMLProvider elementProvider}) {
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

  dynamic get(Map context) {
    if (context == null || context.isEmpty) return null;

    var length = keys.length;
    if (length == 0) return null;

    var value = context[keys[0]];

    for (var i = 1; i < length; ++i) {
      var k = keys[i];
      value = value[k];
    }

    return value;
  }

  dynamic getResolved(Map context) {
    var value = get(context);
    return evaluateObject(context, value);
  }

  String getResolvedAsString(Map context) {
    var value = getResolved(context);
    return DOMTemplateVariable.valueToString(value);
  }

  static String valueToString(dynamic value) {
    return value != null ? value.toString() : '';
  }

  static dynamic evaluateObject(Map context, dynamic value) {
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

  bool evaluate(Map context) {
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
  String build(Map context, {ElementHTMLProvider elementProvider}) => content;
}

class DOMTemplateBlockVar extends DOMTemplateNode {
  final DOMTemplateVariable variable;

  DOMTemplateBlockVar(this.variable);

  factory DOMTemplateBlockVar.parse(String s) {
    return DOMTemplateBlockVar(DOMTemplateVariable.parse(s));
  }

  @override
  String build(Map context, {ElementHTMLProvider elementProvider}) {
    return variable.getResolvedAsString(context);
  }
}

class DOMTemplateBlockQuery extends DOMTemplateNode {
  final String query;

  DOMTemplateBlockQuery(this.query);

  @override
  String build(Map context, {ElementHTMLProvider elementProvider}) {
    if (elementProvider == null) return '';
    var element = elementProvider(query);

    var template = DOMTemplate.parse(element);
    if (template != null && !template.hasOnlyContent) {
      return template.build(context, elementProvider: elementProvider);
    } else {
      return element ?? '';
    }
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

  bool evaluate(Map context);

  @override
  String build(Map context, {ElementHTMLProvider elementProvider}) {
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

  String buildContent(Map context, {ElementHTMLProvider elementProvider}) {
    if (nodes.isEmpty) return '';

    var s = StringBuffer();
    for (var n in nodes) {
      s.write(n.build(context, elementProvider: elementProvider));
    }

    return s.toString();
  }
}

class DOMTemplateBlockIf extends DOMTemplateBlockCondition {
  DOMTemplateBlockIf(DOMTemplateVariable variable, [DOMTemplateNode content])
      : super(variable, content);

  @override
  bool evaluate(Map context) {
    return variable.evaluate(context);
  }
}

class DOMTemplateBlockNot extends DOMTemplateBlockCondition {
  DOMTemplateBlockNot(DOMTemplateVariable variable, [DOMTemplateNode content])
      : super(variable, content);

  @override
  bool evaluate(Map context) {
    return !variable.evaluate(context);
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
  bool evaluate(Map context) {
    return true;
  }
}

class DOMTemplateBlockElseIf extends DOMTemplateBlockElseCondition {
  DOMTemplateBlockElseIf(DOMTemplateVariable variable,
      [DOMTemplateNode content])
      : super(variable, content);

  @override
  bool evaluate(Map context) {
    return variable.evaluate(context);
  }
}

class DOMTemplateBlockElseNot extends DOMTemplateBlockElseCondition {
  DOMTemplateBlockElseNot(DOMTemplateVariable variable,
      [DOMTemplateNode content])
      : super(variable, content);

  @override
  bool evaluate(Map context) {
    return !variable.evaluate(context);
  }
}

class DOMTemplateBlockVarElse extends DOMTemplateBlock {
  DOMTemplateBlockVarElse(DOMTemplateVariable variable,
      [DOMTemplate contentElse])
      : super(variable, contentElse);

  @override
  String build(Map context, {ElementHTMLProvider elementProvider}) {
    var value = variable.getResolved(context);
    if (variable.evaluateValue(value)) {
      return DOMTemplateVariable.valueToString(value);
    } else {
      return super.build(context, elementProvider: elementProvider);
    }
  }
}

class DOMTemplateBlockIfCollection extends DOMTemplateBlockCondition {
  DOMTemplateBlockIfCollection(DOMTemplateVariable variable,
      [DOMTemplateNode content])
      : super(variable, content);

  @override
  bool evaluate(Map context) {
    return variable.evaluate(context);
  }

  @override
  String buildContent(Map context, {ElementHTMLProvider elementProvider}) {
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
}
