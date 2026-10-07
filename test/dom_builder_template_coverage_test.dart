@TestOn('vm')
library;

import 'package:dom_builder/dom_builder.dart';
import 'package:test/test.dart';

String _hello() => 'hello';

void main() {
  group('DOMTemplate base getters', () {
    test('DOMTemplateContent is not DSX', () {
      var content = DOMTemplateContent('abc');
      expect(content.isDSX, isFalse);
      expect(content.hasDSX, isFalse);
      expect(content.asDSX, isNull);
      expect(content.isNotEmpty, isTrue);
      expect(DOMTemplateContent(null).isEmpty, isTrue);
      expect(DOMTemplateContent(null).toString(), equals(''));
    });

    test('DOMTemplateContent.add is unsupported', () {
      var content = DOMTemplateContent('abc');
      expect(
        () => content.add(DOMTemplateContent('x')),
        throwsA(isA<UnsupportedError>()),
      );
    });

    test('DOMTemplateNode.isDSX with a single non-DSX node', () {
      var node = DOMTemplateNode([DOMTemplateContent('a')]);
      expect(node.isDSX, isFalse);
      expect(node.asDSX, isNull);
    });

    test('DOMTemplateNode.addAll', () {
      var node = DOMTemplateNode();
      expect(node.addAll([]), isFalse);
      expect(node.isEmpty, isTrue);
      expect(
        node.addAll([DOMTemplateContent('a'), DOMTemplateContent('b')]),
        isTrue,
      );
      expect(node.nodes.length, equals(2));
      expect(node.toString(), equals('ab'));
      expect(node.buildAsString(null), equals('ab'));
    });

    test('objectToString', () {
      expect(DOMTemplate.objectToString(null), equals(''));
      expect(DOMTemplate.objectToString(['a', 1, null]), equals('a1'));
      expect(DOMTemplate.objectToString({'k': 'v'}), equals('k: v'));
      expect(DOMTemplate.objectToString(12), equals('12'));
    });
  });

  group('DOMTemplate parse errors', () {
    test('close without open block', () {
      expect(() => DOMTemplate.parse('a {{/}} b'), throwsStateError);
      expect(DOMTemplate.tryParse('a {{/}} b'), isNull);
    });

    test('close with key without open block', () {
      expect(() => DOMTemplate.parse('a {{/x}} b'), throwsStateError);
      expect(DOMTemplate.tryParse('a {{/x}} b'), isNull);
    });

    test('close with a different key', () {
      expect(() => DOMTemplate.parse('{{:a}}x{{/b}}'), throwsStateError);
      expect(DOMTemplate.tryParse('{{:a}}x{{/b}}'), isNull);

      // Same key is fine:
      var t = DOMTemplate.parse('{{:a}}x{{/a}}');
      expect(t.buildAsString({'a': true}), equals('x'));
      expect(t.buildAsString({'a': false}), equals(''));
    });

    test('block type without key', () {
      expect(() => DOMTemplate.parse('{{#}}'), throwsStateError);
      expect(DOMTemplate.tryParse('{{#}}'), isNull);
      expect(() => DOMTemplate.parse('{{:}}'), throwsStateError);
    });

    test('unsupported block type with key', () {
      expect(() => DOMTemplate.parse('{{*!list}}x{{/}}'), throwsStateError);
      expect(DOMTemplate.tryParse('{{*!list}}x{{/}}'), isNull);
    });

    test('block still open', () {
      expect(() => DOMTemplate.parse('{{:a}}x'), throwsStateError);
      expect(DOMTemplate.tryParse('{{:a}}x'), isNull);
    });
  });

  group('DOMTemplate else-if with variable comparison', () {
    test('{{?:a==b}}', () {
      var source = '{{:a=="x"}}X{{?:a==b}}EQ-B{{?}}OTHER{{/}}';
      var t = DOMTemplate.parse(source);
      expect(t.toString(), equals(source));

      expect(t.buildAsString({'a': 'x', 'b': 'y'}), equals('X'));
      expect(t.buildAsString({'a': 'y', 'b': 'y'}), equals('EQ-B'));
      expect(t.buildAsString({'a': 'z', 'b': 'y'}), equals('OTHER'));
    });

    test('quoted value containing double quotes uses single quotes', () {
      var t = DOMTemplate.parse('''{{:a=='say "hi"'}}yes{{/}}''');
      expect(t.toString(), equals('''{{:a=='say "hi"'}}yes{{/}}'''));
      expect(t.buildAsString({'a': 'say "hi"'}), equals('yes'));
    });
  });

  group('DOMTemplateVariable.get', () {
    test('Map with int keys', () {
      var t = DOMTemplate.parse('{{m.1}}');
      expect(
        t.buildAsString({
          'm': {1: 'one', 2: 'two'},
        }),
        equals('one'),
      );
    });

    test('List with non-int key', () {
      var t = DOMTemplate.parse('[{{l.x}}][{{l.1}}][{{l.9}}]');
      expect(
        t.buildAsString({
          'l': ['a', 'b'],
        }),
        equals('[][b][]'),
      );
    });

    test('List with an int key with surrounding spaces', () {
      var v = DOMTemplateVariable(['l', ' 1 ']);
      expect(
        v.get({
          'l': ['a', 'b'],
        }),
        equals('b'),
      );
    });

    test('Iterable is converted to List', () {
      var t = DOMTemplate.parse('{{l.0}}');
      expect(
        t.buildAsString({
          'l': {'a', 'b'}.map((e) => e.toUpperCase()),
        }),
        equals('A'),
      );
    });

    // Regression: every `Iterable`, a `Set` too, was converted to a `List`
    // first, so a `Set` was indexed instead of checked for membership.
    test('Set context membership', () {
      var ctx = {
        's': <Object>{'a', 1},
      };
      expect(DOMTemplateVariable(['s', 'a']).get(ctx), isTrue);
      expect(DOMTemplateVariable(['s', '1']).get(ctx), isTrue);
      expect(DOMTemplateVariable(['s', '2']).get(ctx), isFalse);
      expect(DOMTemplateVariable(['s', 'b']).get(ctx), isFalse);
    });

    test('Set membership in a condition', () {
      var t = DOMTemplate.parse('{{:tags.vip}}VIP{{?}}-{{/}}');
      expect(
        t.buildAsString({
          'tags': {'vip', 'new'},
        }),
        equals('VIP'),
      );
      expect(
        t.buildAsString({
          'tags': {'new'},
        }),
        equals('-'),
      );
    });

    test('other Iterables are indexed as a List', () {
      var ctx = {'it': Iterable.generate(3, (i) => 'v$i')};
      expect(DOMTemplateVariable(['it', '1']).get(ctx), equals('v1'));
      expect(DOMTemplateVariable(['it', '5']).get(ctx), isNull);
    });

    test('Function context', () {
      var t = DOMTemplate.parse('{{f.name}}');
      expect(t.buildAsString({'f': (String k) => 'v-$k'}), equals('v-name'));
    });

    test('DSX context returns the DSX object', () {
      var dsx = DSX<Function>(_hello, _hello);
      var v = DOMTemplateVariable(['d', 'anything']);
      var o = v.get({'d': dsx});
      expect(identical(o, _hello), isTrue);

      var t = DOMTemplate.parse('{{d.x}}');
      expect(t.buildAsString({'d': dsx}), equals('hello'));
    });

    test('empty keys returns the context', () {
      var v = DOMTemplateVariable([]);
      expect(v.get({'a': 1}), equals({'a': 1}));
      expect(v.keysFull, equals(''));
      expect(DOMTemplateVariable.parse('  '), isNull);
    });
  });

  group('DOMTemplateVariable.valueToString', () {
    test('List and Map', () {
      expect(DOMTemplateVariable.valueToString(null), equals(''));
      expect(DOMTemplateVariable.valueToString(['a', 1]), equals('a,1'));
      expect(
        DOMTemplateVariable.valueToString({'a': 1, 'b': 'x'}),
        equals('a: 1; b: x'),
      );
      expect(DOMTemplateVariable.valueToString(1.5), equals('1.5'));
    });

    test('comparison against List and Map values', () {
      var t1 = DOMTemplate.parse('{{:l=="a,b"}}LIST{{/}}');
      expect(
        t1.buildAsString({
          'l': ['a', 'b'],
        }),
        equals('LIST'),
      );

      var t2 = DOMTemplate.parse('{{:m=="k: v"}}MAP{{/}}');
      expect(
        t2.buildAsString({
          'm': {'k': 'v'},
        }),
        equals('MAP'),
      );
      expect(
        t2.buildAsString({
          'm': {'k': 'w'},
        }),
        equals(''),
      );
    });
  });

  group('DOMTemplateVariable.evaluateObject', () {
    test('Function(Map?) receives the context', () {
      var t = DOMTemplate.parse('{{f}}');
      expect(
        t.buildAsString({'f': (Map? m) => 'size:${m!.length}', 'x': 1}),
        equals('size:2'),
      );
    });

    test('Function() is called', () {
      var t = DOMTemplate.parse('[{{f}}]');
      expect(t.buildAsString({'f': () => 'called'}), equals('[called]'));
    });

    // Regression: a `Function(Object?)` is also a `Function(Map?)`, checked
    // first, so a non-`Map` context was cast to `Map?` and threw.
    test('Function(Object?) with a non-Map context', () {
      var t = DOMTemplate.parse('{{0}}');
      expect(
        t.buildAsString([(Object? o) => 'ok:${o.runtimeType}']),
        startsWith('ok:List'),
      );
    });

    test('Function(Object?) with a Map context', () {
      var t = DOMTemplate.parse('{{f}}');
      expect(
        t.buildAsString({'f': (Object? o) => o is Map ? 'map' : 'other'}),
        equals('map'),
      );
    });

    test('Function(Map?) with a non-Map context gets null', () {
      var t = DOMTemplate.parse('{{0}}');
      expect(
        t.buildAsString([(Map? m) => m == null ? 'null' : 'map']),
        equals('null'),
      );
    });

    test('Map values are evaluated', () {
      var r = DOMTemplateVariable.evaluateObject({}, {
        'a': () => 1,
        'b': ['x', () => 'y'],
      });
      expect(
        r,
        equals({
          'a': 1,
          'b': ['x', 'y'],
        }),
      );
    });

    test('unknown objects are returned as is', () {
      var d = DateTime.utc(2020, 1, 2);
      expect(DOMTemplateVariable.evaluateObject({}, d), same(d));
    });

    test('DSX with skipDSX returns its mark', () {
      var dsx = DSX<Function>(_hello, _hello);
      var r = DOMTemplateVariable.evaluateObject(
        {},
        dsx,
        dsxResolution: DSXResolution.skipDSX,
      );
      expect(r, equals(dsx.toString()));
    });

    test('DSX resolved as element', () {
      var dsx = DSX<Function>(_hello, _hello);
      var t = DOMTemplate.parse('{{d}}');
      var built = t.build({'d': dsx}) as List;
      expect(built.length, equals(1));
      var elem = built.first as DOMElement;
      expect(elem.buildHTML(), equals('<span>hello</span>'));

      expect(t.buildAsString({'d': dsx}), equals('hello'));
    });
  });

  group('DOMTemplateVariable.evaluateValue', () {
    test('num, Map and unsupported types', () {
      var t = DOMTemplate.parse('{{:v}}T{{?}}F{{/}}');
      expect(t.buildAsString({'v': 0}), equals('F'));
      expect(t.buildAsString({'v': 2}), equals('T'));
      expect(t.buildAsString({'v': <String, int>{}}), equals('F'));
      expect(
        t.buildAsString({
          'v': {'a': 1},
        }),
        equals('T'),
      );
      expect(t.buildAsString({'v': []}), equals('F'));
      expect(
        () => t.buildAsString({'v': DateTime.utc(2020)}),
        throwsStateError,
      );
    });
  });

  group('DOMTemplateIntlMessage', () {
    test('parse', () {
      expect(DOMTemplateIntlMessage.parse('  '), isNull);
      var m = DOMTemplateIntlMessage.parse(' hello ')!;
      expect(m.key, equals('hello'));
      expect(m.toString(), equals('{{intl:hello}}'));
      expect(m.isEmpty, isFalse);
      expect(m.copy().toString(), equals('{{intl:hello}}'));
    });

    test('non-String keyed Map context', () {
      var t = DOMTemplate.parse('{{intl:msg}}');
      Map<String, dynamic>? received;
      var s = t.buildAsString(
        <Object, Object>{1: 'one', 'n': 'x'},
        intlMessageResolver: (key, [params]) {
          received = params;
          return '$key:${params!['1']}:${params['n']}';
        },
      );
      expect(s, equals('msg:one:x'));
      expect(received, equals({'1': 'one', 'n': 'x'}));
    });

    test('no resolver builds empty', () {
      var t = DOMTemplate.parse('[{{intl:msg}}]');
      expect(t.buildAsString({}), equals('[]'));
    });
  });

  group('DOMTemplateBlockQuery', () {
    test('isEmpty and copy', () {
      var q = DOMTemplateBlockQuery('#id');
      expect(q.isEmpty, isFalse);
      expect(DOMTemplateBlockQuery('').isEmpty, isTrue);
      var c = q.copy();
      expect(c.query, equals('#id'));
      expect(c.toString(), equals('{{#id}}'));
    });

    test('provider returns a template String', () {
      var t = DOMTemplate.parse('<{{#tpl}}>');
      var built = t.build({
        'name': 'Joe',
      }, elementProvider: (q) => q == '#tpl' ? 'Hi {{name}}!' : null);
      expect(DOMTemplate.objectToString(built), equals('<Hi Joe!>'));
    });

    test('provider returns a plain String', () {
      var t = DOMTemplate.parse('<{{#tpl}}>');
      var built = t.build({}, elementProvider: (q) => 'plain');
      expect(built, equals(['<', 'plain', '>']));
    });

    test('provider returns a non-String', () {
      var t = DOMTemplate.parse('{{.cls}}');
      expect(
        t.buildAsString({}, elementProvider: (q) => ['a', 'b']),
        equals('a,b'),
      );
      var built = t.build({}, elementProvider: (q) => 42);
      expect(built, equals([42]));
    });

    test('no provider builds empty', () {
      var t = DOMTemplate.parse('[{{#x}}]');
      expect(t.buildAsString({}), equals('[]'));
    });
  });

  group('DOMTemplateBlockIfCmp', () {
    test('unknown comparator throws on evaluate', () {
      var b = DOMTemplateBlockIfCmp(
        false,
        DOMTemplateVariable(['a']),
        'xx',
        DOMTemplateContent('1'),
      );
      expect(b.cmp, isNull);
      expect(() => b.evaluate({'a': '1'}), throwsStateError);
    });

    test('non-template value', () {
      var b = DOMTemplateBlockIfCmp(
        false,
        DOMTemplateVariable(['a']),
        'eq',
        123,
        DOMTemplateNode([DOMTemplateContent('yes')]),
      );
      expect(b.toString(), equals('{{:a==123}}yes{{/}}'));
      expect(b.getValueAsString({}), equals('123'));
      expect(b.evaluate({'a': 123}), isTrue);
      expect(b.evaluate({'a': 124}), isFalse);
      expect(DOMTemplate.objectToString(b.build({'a': 123})), equals('yes'));

      var copy = b.copy();
      expect(copy.toString(), equals(b.toString()));
    });

    test('parseDOMTemplateCmp and operator', () {
      expect(parseDOMTemplateCmp(null), isNull);
      expect(parseDOMTemplateCmp(DOMTemplateCmp.eq), DOMTemplateCmp.eq);
      expect(parseDOMTemplateCmp(' EQ '), DOMTemplateCmp.eq);
      expect(parseDOMTemplateCmp('noteq'), DOMTemplateCmp.notEq);
      expect(parseDOMTemplateCmp('?'), isNull);
      expect(getDOMTemplateCmpOperator(null), equals(''));
      expect(getDOMTemplateCmpOperator(DOMTemplateCmp.notEq), equals('!='));
    });
  });

  group('DOMTemplateBlockIfCollection', () {
    test('non-Iterable value is used as the content context', () {
      var source = '{{*:m}}[{{k}}]{{/}}';
      var t = DOMTemplate.parse(source);
      expect(t.toString(), equals(source));
      expect(
        t.buildAsString({
          'm': {'k': 'v'},
        }),
        equals('[v]'),
      );
    });
  });

  group('DSX templates', () {
    test('DOMTemplateNode.copy resolves a single DSX', () {
      var dsx = DSX<Function>(_hello, _hello);
      var t = DOMTemplate.parse(dsx.toString());
      expect(t.isDSX, isTrue);
      expect(t.hasDSX, isTrue);
      expect(t.asDSX, same(dsx));

      var resolved = t.copy(dsxResolution: DSXResolution.resolveDSX);
      expect(resolved, isA<DOMTemplateContent>());
      expect(resolved.toString(), equals('hello'));

      var skipped = t.copy();
      expect(skipped, isA<DOMTemplateNode>());
      expect(skipped.toString(), equals(dsx.toString()));
    });
  });
}
