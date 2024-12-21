import 'package:swiss_knife/swiss_knife.dart';

import 'dom_builder_base.dart';
import 'dom_builder_context.dart';
import 'dom_builder_dsx.dart';

final RegExpDialect _templateDialect = RegExpDialect({
  'o': r'\{\{\s*',
  'c': r'\s*\}\}',
  'key': r'\w[\w-]*',
  'quote': r'''(?:"[^"]*"|'[^']*')''',
  'var': r'$key(?:\.$key)*',
  'cmp': r'(?:==|!=)',
  'tag':
      r'$o([\:\!\?\/\#\.]|[\?\*][:!]|\.|intl?:)?($var)?(?:($cmp)(?:($quote)|($var)))?$c',
}, multiLine: false, caseSensitive: false);

final int _templateMinimalLength = '{{x}}'.length;

abstract class DOMTemplate {
  static DOMTemplate? from(Object? value) {
    if (value == null) return null;
    if (value is DOMTemplate) return value;
    if (value is String) return DOMTemplate.parse(value);
    return null;
  }

  static String objectToString(dynamic o) {
    if (o == null) {
      return '';
    } else if (o is String) {
      return o;
    } else if (o is DOMNode) {
      return o.buildHTML(buildTemplates: false);
    } else if (o is Iterable) {
      return o.map(objectToString).join('');
    } else if (o is Map) {
      return o.entries
          .map((e) => '${objectToString(e.key)}: ${objectToString(e.value)}')
          .join('');
    } else if (o is Iterable) {
      return o.map(objectToString).join('');
    } else {
      return o.toString();
    }
  }

  DOMTemplate();

  /// Returns `true` if this node is empty.
  bool get isEmpty;

  /// Returns `true` if this node NOT is empty.
  bool get isNotEmpty => !isEmpty;

  /// Returns this node as an [DSX] instance if [isDSX] returns `true`.
  DSX? get asDSX => null;

  /// Returns `true` if this node is a `DSX` entry.
  bool get isDSX => false;

  /// Returns `true` if this node or any sub-node is a [DSX] entry.
  bool get hasDSX => false;

  /// Returns a copy if this instance.
  DOMTemplate copy({bool resolveDSX = false});

  /// Returns [true] if [s] can be a template code, has `{{` and `}}`.
  static bool possiblyATemplate(String s) {
    if (s.length < _templateMinimalLength) return false;
    var idx = s.indexOf('{{');
    if (idx < 0) return false;
    var idx2 = s.indexOf('}}', idx);
    return idx2 > 0;
  }

  static final RegExp regexpTag = _templateDialect.getPattern(r'$tag');

  /// Tries to parse [s].
  ///
  /// Returns [null] if [s] has no template or a not valid template code.
  static DOMTemplateNode? tryParse(String? s) {
    try {
      return _parse(s, true);
    } catch (e) {
      return null;
    }
  }

  /// Parses [s] and returns a DOMTemplateNode.
  ///
  /// Throws [StateError] if [s] is not a valid template.
  static DOMTemplateNode parse(String s) {
    return _parse(s, false)!;
  }

  static DOMTemplateNode? _parse(String? s, bool tryParsing) {
    if (s == null) {
      // Only `tryParse` can pass a `null` [s].
      assert(tryParsing);
      return null;
    }

    if (s.length < _templateMinimalLength) {
      if (tryParsing) return null;
      if (s == '{{}}') {
        return DOMTemplateNode([]);
      } else {
        return DOMTemplateNode([DOMTemplateContent(s)]);
      }
    }

    var matches = regexpTag.allMatches(s).toList(growable: false);
    if (matches.isEmpty) {
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
                if (key != null && cursor.variable!.keysFull != key) {
                  if (tryParsing) return null;
                  throw StateError(
                      'Error paring! Current block with different key: ${cursor.variable!.keysFull} != $key');
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
          case 'int:':
          case 'intl:':
            {
              var o = DOMTemplateIntlMessage(key);
              cursor.add(o);
              break;
            }
          case ':':
            {
              var variable = DOMTemplateVariable.parse(key);

              DOMTemplateBlockIf block;

              if (cmp != null) {
                Object? value;

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
              stack.add(cursor as DOMTemplateNode);
              cursor = block;
              break;
            }
          case '?:':
            {
              var condition = cursor as DOMTemplateBlockCondition;

              var variable = DOMTemplateVariable.parse(key);

              DOMTemplateBlockCondition block;

              if (cmp != null) {
                Object? value;

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
              stack.add(cursor as DOMTemplateNode);
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
              stack.add(cursor as DOMTemplateNode);
              cursor = o;
              break;
            }
          case '*:':
            {
              var variable = DOMTemplateVariable.parse(key);
              var o = DOMTemplateBlockIfCollection(variable);
              cursor.add(o);
              stack.add(cursor as DOMTemplateNode);
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
                if (cursor.variable!.keysFull != key) {
                  if (tryParsing) return null;
                  throw StateError(
                      'Error paring! Current block with different key: ${cursor.variable!.keysFull} != $key');
                }
              } else {
                if (tryParsing) return null;
                throw StateError(
                    'Error paring! No block open: $cursor > $stack <${s.length < 100 ? s : '${s.substring(0, 100)}...'}>');
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

  dynamic build(Object? context,
      {bool asElement = true,
      bool resolveDSX = true,
      QueryElementProvider? elementProvider,
      IntlMessageResolver? intlMessageResolver});

  bool add(DOMTemplate entry) {
    throw UnsupportedError("Type can't have content: $runtimeType");
  }

  @override
  String toString();
}

typedef QueryElementProvider = dynamic Function(String query);

class DOMTemplateNode extends DOMTemplate {
  List<DOMTemplate> nodes;

  DOMTemplateNode([List<DOMTemplate>? nodes])
      : nodes = nodes ?? <DOMTemplate>[];

  @override
  DSX? get asDSX {
    if (nodes.length == 1) {
      return nodes.first.asDSX;
    } else {
      return null;
    }
  }

  @override
  bool get isDSX {
    if (nodes.length == 1) {
      return nodes.first.isDSX;
    } else {
      return false;
    }
  }

  @override
  bool get hasDSX {
    for (var node in nodes) {
      if (node.hasDSX) {
        return true;
      }
    }
    return false;
  }

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
      if (node is! DOMTemplateContent) return false;
    }
    return true;
  }

  String buildAsString(Object? context,
      {bool resolveDSX = true,
      QueryElementProvider? elementProvider,
      IntlMessageResolver? intlMessageResolver}) {
    var built = build(context,
        asElement: false,
        resolveDSX: resolveDSX,
        elementProvider: elementProvider,
        intlMessageResolver: intlMessageResolver);

    var s = DOMTemplate.objectToString(built);
    return s;
  }

  @override
  dynamic build(Object? context,
      {bool asElement = true,
      bool resolveDSX = true,
      QueryElementProvider? elementProvider,
      IntlMessageResolver? intlMessageResolver}) {
    if (nodes.isEmpty) return null;

    var built = nodes
        .map((n) {
          var built = n.build(context,
              asElement: asElement,
              resolveDSX: resolveDSX,
              elementProvider: elementProvider,
              intlMessageResolver: intlMessageResolver);
          return built;
        })
        .where((e) => e != null)
        .expand((e) => e is List ? e : [e])
        .toList();

    return built;
  }

  @override
  bool add(DOMTemplate? entry) {
    if (entry == null) return false;
    nodes.add(entry);
    return true;
  }

  bool addAll(List<DOMTemplate> entries) {
    if (entries.isEmpty) return false;
    nodes.addAll(entries);
    return true;
  }

  void clear() {
    nodes.clear();
  }

  @override
  String toString() => _toStringNodes();

  String _toStringNodes() {
    return nodes.isNotEmpty ? nodes.join() : '';
  }

  @override
  DOMTemplate copy({bool resolveDSX = false}) {
    if (resolveDSX) {
      var dsx = asDSX;
      if (dsx != null) {
        var s = dsx.createResolver().resolveValueAsString();
        return DOMTemplateContent(s);
      }
    }

    var copy = DOMTemplateNode();
    copy.nodes.addAll(copyNodes(resolveDSX: resolveDSX));
    return copy;
  }

  List<DOMTemplate> copyNodes({bool resolveDSX = false}) {
    return nodes.map((e) => e.copy(resolveDSX: resolveDSX)).toList();
  }
}

class DOMTemplateVariable {
  final List<String> keys;

  DOMTemplateVariable(this.keys);

  static DOMTemplateVariable? parse(String s) {
    s = s.trim();
    if (s.isEmpty) return null;

    var keys = s.split('.');
    return DOMTemplateVariable(keys);
  }

  bool get isDSX => keys.length == 1 && keys.first.startsWith('__DSX__');

  DSX? get asDSX => isDSX ? DSX.resolveDSX(keys.first) : null;

  String get keysFull => keys.join('.');

  Object? get(Object? context) {
    if (isDSX) {
      var dsx = DSX.resolveDSX(keys.first);
      return dsx;
    }

    if (context == null || isEmptyObject(context)) return null;

    var length = keys.length;
    if (length == 0) return context;

    var value = _get(context, keys[0]);

    for (var i = 1; i < length; ++i) {
      var k = keys[i];
      value = _get(value, k);
    }

    return value;
  }

  Object? _get(Object? context, String key) {
    if (context == null || isEmptyObject(context) || isEmptyString(key)) {
      return null;
    }

    if (context is Iterable) {
      context = context.toList();
    }

    if (context is Map) {
      if (context.containsKey(key)) {
        return context[key];
      } else if (isInt(key)) {
        var n = parseInt(key);
        return context[n];
      }
    } else if (context is List) {
      int? idx;
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
    } else if (context is DOMContext) {
      var val = context.variables[key];
      return val;
    } else if (context is DSX) {
      var object = context.object;
      return object;
    } else if (context is Function) {
      var ret = context(key);
      return ret;
    }

    return null;
  }

  Object? getResolved(Object? context,
      {bool asElement = true,
      bool resolveDSX = true,
      QueryElementProvider? elementProvider,
      IntlMessageResolver? intlMessageResolver}) {
    var value = get(context);
    return evaluateObject(context, value,
        asElement: asElement,
        resolveDSX: resolveDSX,
        elementProvider: elementProvider,
        intlMessageResolver: intlMessageResolver);
  }

  String getResolvedAsString(Object? context,
      {bool resolveDSX = true,
      QueryElementProvider? elementProvider,
      IntlMessageResolver? intlMessageResolver}) {
    var value = getResolved(context,
        asElement: false,
        resolveDSX: resolveDSX,
        elementProvider: elementProvider,
        intlMessageResolver: intlMessageResolver);
    return DOMTemplateVariable.valueToString(value);
  }

  static String valueToString(Object? value) {
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

  static Object? evaluateObject(Object? context, Object? value,
      {bool asElement = true,
      bool resolveDSX = true,
      QueryElementProvider? elementProvider,
      IntlMessageResolver? intlMessageResolver}) {
    if (value == null) return null;

    if (value is String) {
      return value;
    } else if (value is bool) {
      return value;
    } else if (value is num) {
      return value;
    } else if (value is List) {
      return value
          .map((e) => evaluateObject(context, e,
              asElement: asElement,
              elementProvider: elementProvider,
              intlMessageResolver: intlMessageResolver))
          .toList();
    } else if (value is Map) {
      return Map.from(value.map((k, v) => MapEntry(
          evaluateObject(context, k,
              asElement: asElement,
              elementProvider: elementProvider,
              intlMessageResolver: intlMessageResolver),
          evaluateObject(context, v,
              asElement: asElement,
              elementProvider: elementProvider,
              intlMessageResolver: intlMessageResolver))));
    } else if (value is DSX) {
      if (resolveDSX) {
        var resolver = value.createResolver();
        var res = asElement
            ? resolver.resolveElement(
                elementProvider: elementProvider,
                intlMessageResolver: intlMessageResolver)
            : resolver.resolveValue(
                elementProvider: elementProvider,
                intlMessageResolver: intlMessageResolver);
        return evaluateObject(context, res,
            asElement: asElement,
            resolveDSX: resolveDSX,
            elementProvider: elementProvider,
            intlMessageResolver: intlMessageResolver);
      } else {
        return value.toString();
      }
    } else if (value is Function(Map? a)) {
      var res = value(context as Map<dynamic, dynamic>?);
      return evaluateObject(context, res,
          asElement: asElement,
          elementProvider: elementProvider,
          intlMessageResolver: intlMessageResolver);
    } else if (value is Function(Object? a)) {
      var res = value(context);
      return evaluateObject(context, res,
          asElement: asElement,
          elementProvider: elementProvider,
          intlMessageResolver: intlMessageResolver);
    } else if (value is Function()) {
      var res = value();
      return evaluateObject(context, res,
          asElement: asElement,
          elementProvider: elementProvider,
          intlMessageResolver: intlMessageResolver);
    } else {
      return value;
    }
  }

  bool evaluate(Object? context) {
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

class DOMTemplateIntlMessage extends DOMTemplateNode {
  final String key;

  DOMTemplateIntlMessage(this.key);

  static DOMTemplateIntlMessage? parse(String s) {
    s = s.trim();
    if (s.isEmpty) return null;
    return DOMTemplateIntlMessage(s);
  }

  @override
  DOMTemplateIntlMessage copy({bool resolveDSX = false}) {
    var copy = DOMTemplateIntlMessage(key);
    return copy;
  }

  @override
  bool get isEmpty => key.isEmpty;

  @override
  String? build(Object? context,
      {bool asElement = true,
      bool resolveDSX = true,
      QueryElementProvider? elementProvider,
      IntlMessageResolver? intlMessageResolver}) {
    if (intlMessageResolver == null) return '';

    Map<String, dynamic>? parameters;

    if (context is Map<String, dynamic>) {
      parameters = context;
    } else if (context is Map) {
      parameters =
          context.map((key, value) => MapEntry('$key', value as dynamic));
    } else if (context is DOMContext) {
      parameters = context.variables;
    }

    var s = intlMessageResolver(key, parameters);
    return s;
  }

  @override
  String toString() {
    return '{{intl:$key}}';
  }
}

class DOMTemplateContent extends DOMTemplate {
  final String? content;

  DOMTemplateContent(this.content);

  @override
  DOMTemplateContent copy({bool resolveDSX = false}) {
    var copy = DOMTemplateContent(content);
    return copy;
  }

  @override
  bool get isEmpty => isEmptyString(content);

  @override
  dynamic build(Object? context,
          {bool asElement = true,
          bool resolveDSX = true,
          QueryElementProvider? elementProvider,
          IntlMessageResolver? intlMessageResolver}) =>
      content;

  @override
  String toString() {
    return content ?? '';
  }
}

class DOMTemplateBlockVar extends DOMTemplateNode {
  final DOMTemplateVariable? variable;

  DOMTemplateBlockVar(this.variable);

  @override
  bool get isDSX => variable?.isDSX ?? false;

  @override
  bool get hasDSX => isDSX;

  @override
  DSX? get asDSX => variable?.asDSX;

  @override
  DOMTemplate copy({bool resolveDSX = false}) {
    if (resolveDSX) {
      var dsx = asDSX;
      if (dsx != null) {
        var s = dsx.createResolver().resolveValueAsString();
        return DOMTemplateContent(s);
      }
    }

    var copy = DOMTemplateBlockVar(variable);
    return copy;
  }

  factory DOMTemplateBlockVar.parse(String s) {
    return DOMTemplateBlockVar(DOMTemplateVariable.parse(s));
  }

  @override
  bool get isEmpty => variable == null;

  @override
  dynamic build(Object? context,
      {bool asElement = true,
      bool resolveDSX = true,
      QueryElementProvider? elementProvider,
      IntlMessageResolver? intlMessageResolver}) {
    return variable!.getResolved(context,
        asElement: asElement,
        resolveDSX: resolveDSX,
        elementProvider: elementProvider,
        intlMessageResolver: intlMessageResolver);
  }

  @override
  String toString() {
    return '{{${variable!.keys.isEmpty ? '.' : variable!.keysFull}}}';
  }
}

class DOMTemplateBlockQuery extends DOMTemplateNode {
  final String query;

  DOMTemplateBlockQuery(this.query);

  @override
  DOMTemplateBlockQuery copy({bool resolveDSX = false}) {
    var copy = DOMTemplateBlockQuery(query);
    copy.nodes.addAll(copyNodes(resolveDSX: resolveDSX));
    return copy;
  }

  @override
  bool get isEmpty => query.isEmpty;

  @override
  dynamic build(Object? context,
      {bool asElement = true,
      bool resolveDSX = true,
      QueryElementProvider? elementProvider,
      IntlMessageResolver? intlMessageResolver}) {
    if (elementProvider == null) return '';
    var element = elementProvider(query)!;

    if (element == null) {
      return null;
    } else if (element is String) {
      if (!asElement) {
        return element;
      }

      var template = DOMTemplate.parse(element);
      if (!template.hasOnlyContent) {
        return template.build(context,
            asElement: true,
            resolveDSX: resolveDSX,
            elementProvider: elementProvider,
            intlMessageResolver: intlMessageResolver);
      } else {
        return element;
      }
    } else {
      return asElement ? element : DOMTemplateVariable.valueToString(element);
    }
  }

  @override
  String toString() {
    return '{{$query}}';
  }
}

abstract class DOMTemplateBlock extends DOMTemplateNode {
  final DOMTemplateVariable? variable;

  DOMTemplateBlock(this.variable, [DOMTemplateNode? content]) {
    add(content);
  }

  @override
  bool get isEmpty => false;
}

abstract class DOMTemplateBlockCondition extends DOMTemplateBlock {
  DOMTemplateBlockCondition(super.variable, [super.content]);

  DOMTemplateBlockCondition? elseCondition;

  bool evaluate(Object? context);

  @override
  dynamic build(Object? context,
      {bool asElement = true,
      bool resolveDSX = true,
      QueryElementProvider? elementProvider,
      IntlMessageResolver? intlMessageResolver}) {
    if (evaluate(context)) {
      return buildContent(context,
          asElement: asElement,
          resolveDSX: resolveDSX,
          elementProvider: elementProvider);
    } else {
      var elseCondition = this.elseCondition;

      while (elseCondition != null) {
        if (elseCondition.evaluate(context)) {
          return elseCondition.build(context,
              asElement: asElement,
              resolveDSX: resolveDSX,
              elementProvider: elementProvider);
        }
        elseCondition = elseCondition.elseCondition;
      }

      return null;
    }
  }

  dynamic buildContent(Object? context,
      {bool asElement = true,
      bool resolveDSX = true,
      QueryElementProvider? elementProvider}) {
    if (nodes.isEmpty) return null;

    var built = nodes
        .map((n) {
          var built = n.build(context,
              asElement: asElement,
              resolveDSX: resolveDSX,
              elementProvider: elementProvider);
          return built;
        })
        .where((e) => e != null)
        .expand((e) => e is List ? e : [e])
        .toList();

    return built;
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
  DOMTemplateBlockIf(super.variable, [super.content]);

  @override
  DOMTemplateBlockIf copy({bool resolveDSX = false}) {
    var copy = DOMTemplateBlockIf(variable);
    copy.nodes.addAll(copyNodes(resolveDSX: resolveDSX));
    return copy;
  }

  @override
  bool evaluate(Object? context) {
    return variable!.evaluate(context);
  }

  @override
  String toString() {
    return '{{:${variable!.keysFull}}}${_toStringNodes()}${_toStringRest()}';
  }
}

enum DOMTemplateCmp { eq, notEq }

String getDOMTemplateCmpOperator(DOMTemplateCmp? cmp) {
  switch (cmp) {
    case DOMTemplateCmp.eq:
      return '==';
    case DOMTemplateCmp.notEq:
      return '!=';
    default:
      return '';
  }
}

DOMTemplateCmp? parseDOMTemplateCmp(Object? cmp) {
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

  final DOMTemplateCmp? cmp;
  final Object? value;

  DOMTemplateBlockIfCmp(
      this.elseIf, DOMTemplateVariable? variable, Object? cmp, this.value,
      [DOMTemplateNode? content])
      : cmp = parseDOMTemplateCmp(cmp),
        super(variable, content);

  @override
  DOMTemplateBlockIfCmp copy({bool resolveDSX = false}) {
    var copy = DOMTemplateBlockIfCmp(elseIf, variable, cmp, value);
    copy.nodes.addAll(copyNodes(resolveDSX: resolveDSX));
    return copy;
  }

  @override
  bool evaluate(Object? context) {
    switch (cmp) {
      case DOMTemplateCmp.eq:
        return matchesEq(context);
      case DOMTemplateCmp.notEq:
        return !matchesEq(context);
      default:
        throw StateError("Can't handle: $cmp");
    }
  }

  bool matchesEq(Object? context) {
    var varValueStr = variable!.getResolvedAsString(context);
    var valueStr = getValueAsString(context);
    return varValueStr == valueStr;
  }

  String? getValueAsString(Object? context) {
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
      var content = valueContent.content!;
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
    return '{{${elseIf ? '?' : ''}:${variable!.keysFull}${getDOMTemplateCmpOperator(cmp)}${toStringValue()}}}${_toStringNodes()}${_toStringRest()}';
  }
}

class DOMTemplateBlockNot extends DOMTemplateBlockCondition {
  DOMTemplateBlockNot(super.variable, [super.content]);

  @override
  DOMTemplateBlockNot copy({bool resolveDSX = false}) {
    var copy = DOMTemplateBlockNot(variable);
    copy.nodes.addAll(copyNodes(resolveDSX: resolveDSX));
    return copy;
  }

  @override
  bool evaluate(Object? context) {
    return !variable!.evaluate(context);
  }

  @override
  String toString() {
    return '{{!${variable!.keysFull}}}${_toStringNodes()}${_toStringRest()}';
  }
}

abstract class DOMTemplateBlockElseCondition extends DOMTemplateBlockCondition {
  DOMTemplateBlockElseCondition(super.variable, [super.content]);
}

class DOMTemplateBlockElse extends DOMTemplateBlockElseCondition {
  DOMTemplateBlockElse([DOMTemplateNode? content]) : super(null, content);

  @override
  DOMTemplateBlockElse copy({bool resolveDSX = false}) {
    var copy = DOMTemplateBlockElse();
    copy.nodes.addAll(copyNodes(resolveDSX: resolveDSX));
    return copy;
  }

  @override
  bool evaluate(Object? context) {
    return true;
  }

  @override
  String toString() {
    return '{{?}}${_toStringNodes()}${_toStringRest()}';
  }
}

class DOMTemplateBlockElseIf extends DOMTemplateBlockElseCondition {
  DOMTemplateBlockElseIf(super.variable, [super.content]);

  @override
  DOMTemplateBlockElseIf copy({bool resolveDSX = false}) {
    var copy = DOMTemplateBlockElseIf(variable);
    copy.nodes.addAll(copyNodes(resolveDSX: resolveDSX));
    return copy;
  }

  @override
  bool evaluate(Object? context) {
    return variable!.evaluate(context);
  }

  @override
  String toString() {
    return '{{?:${variable!.keysFull}}}${_toStringNodes()}${_toStringRest()}';
  }
}

class DOMTemplateBlockElseNot extends DOMTemplateBlockElseCondition {
  DOMTemplateBlockElseNot(super.variable, [super.content]);

  @override
  DOMTemplateBlockElseNot copy({bool resolveDSX = false}) {
    var copy = DOMTemplateBlockElseNot(variable);
    copy.nodes.addAll(copyNodes(resolveDSX: resolveDSX));
    return copy;
  }

  @override
  bool evaluate(Object? context) {
    return !variable!.evaluate(context);
  }

  @override
  String toString() {
    return '{{?!:${variable!.keysFull}}${_toStringRest()}';
  }
}

class DOMTemplateBlockVarElse extends DOMTemplateBlock {
  DOMTemplateBlockVarElse(super.variable, [super.contentElse]);

  @override
  DOMTemplateBlockVarElse copy({bool resolveDSX = false}) {
    var copy = DOMTemplateBlockVarElse(variable);
    copy.nodes.addAll(copyNodes(resolveDSX: resolveDSX));
    return copy;
  }

  @override
  dynamic build(Object? context,
      {bool asElement = true,
      bool resolveDSX = true,
      QueryElementProvider? elementProvider,
      IntlMessageResolver? intlMessageResolver}) {
    var value = variable!.getResolved(context);
    if (variable!.evaluateValue(value)) {
      return asElement ? value : DOMTemplateVariable.valueToString(value);
    } else {
      return super.build(context,
          asElement: asElement,
          resolveDSX: resolveDSX,
          elementProvider: elementProvider);
    }
  }

  @override
  String toString() {
    return '{{?${variable!.keysFull}}}${_toStringNodes()}{{/}}';
  }
}

class DOMTemplateBlockIfCollection extends DOMTemplateBlockCondition {
  DOMTemplateBlockIfCollection(super.variable, [super.content]);

  @override
  DOMTemplateBlockIfCollection copy({bool resolveDSX = false}) {
    var copy = DOMTemplateBlockIfCollection(variable);
    copy.nodes.addAll(copyNodes(resolveDSX: resolveDSX));
    return copy;
  }

  @override
  bool evaluate(Object? context) {
    return variable!.evaluate(context);
  }

  @override
  dynamic buildContent(Object? context,
      {bool asElement = true,
      bool resolveDSX = true,
      QueryElementProvider? elementProvider}) {
    var value = variable!.getResolved(context);

    if (value is Iterable) {
      var built = value
          .map((val) => super.buildContent(val,
              asElement: asElement,
              resolveDSX: resolveDSX,
              elementProvider: elementProvider))
          .expand((e) => e is List ? e : [e])
          .toList();
      return built;
    } else {
      return super.buildContent(value,
          asElement: asElement,
          resolveDSX: resolveDSX,
          elementProvider: elementProvider);
    }
  }

  @override
  String toString() {
    return '{{*:${variable!.keysFull}}}${_toStringNodes()}${_toStringRest()}';
  }
}
