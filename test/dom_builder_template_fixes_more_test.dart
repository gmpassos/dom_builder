@TestOn('vm')
library;

import 'dart:collection';

import 'package:dom_builder/dom_builder.dart';
import 'package:test/test.dart';

enum _Tag { vip }

class _Key {
  final String name;

  _Key(this.name);

  @override
  String toString() => name;
}

String _build(String template, Object? context) =>
    DOMTemplate.parse(template).buildAsString(context);

Object? _get(List<String> keys, Object? context) =>
    DOMTemplateVariable(keys).get(context);

void main() {
  group('Set membership: element types', () {
    test('Set of Strings', () {
      var ctx = {
        's': {'vip', 'new'},
      };
      expect(_get(['s', 'vip'], ctx), isTrue);
      expect(_get(['s', 'new'], ctx), isTrue);
      expect(_get(['s', 'old'], ctx), isFalse);
      // Case sensitive:
      expect(_get(['s', 'VIP'], ctx), isFalse);
    });

    test('Set of ints', () {
      var ctx = {
        's': {1, 2, 30},
      };
      expect(_get(['s', '1'], ctx), isTrue);
      expect(_get(['s', '30'], ctx), isTrue);
      expect(_get(['s', '3'], ctx), isFalse);
      expect(_get(['s', '0'], ctx), isFalse);
      expect(_get(['s', 'x'], ctx), isFalse);
      expect(_build('{{s.1}}|{{s.3}}', ctx), equals('true|false'));
    });

    test('Set of mixed Strings and ints', () {
      var ctx = {
        's': <Object>{'a', 2, '3'},
      };
      expect(_get(['s', 'a'], ctx), isTrue);
      // int element, numeric key:
      expect(_get(['s', '2'], ctx), isTrue);
      // String element, numeric key:
      expect(_get(['s', '3'], ctx), isTrue);
      expect(_get(['s', '4'], ctx), isFalse);
    });

    test('numeric-String keys', () {
      // Leading zeros: the String does not match, the parsed int does.
      expect(
        _get(
          ['s', '01'],
          {
            's': {1},
          },
        ),
        isTrue,
      );
      expect(
        _get(
          ['s', '01'],
          {
            's': {'1'},
          },
        ),
        isFalse,
      );
      expect(
        _get(
          ['s', '01'],
          {
            's': {'01'},
          },
        ),
        isTrue,
      );
      // Negative ints (only reachable through `DOMTemplateVariable`):
      expect(
        _get(
          ['s', '-1'],
          {
            's': {-1},
          },
        ),
        isTrue,
      );
      // A decimal key is not an int:
      expect(
        _get(
          ['s', '1.5'],
          {
            's': {1.5},
          },
        ),
        isFalse,
      );
      expect(
        _get(
          ['s', '1.5'],
          {
            's': {'1.5'},
          },
        ),
        isTrue,
      );
    });

    test('Set of doubles with an int key (1 == 1.0 on the VM)', () {
      expect(
        _get(
          ['s', '1'],
          {
            's': {1.0},
          },
        ),
        isTrue,
      );
      expect(
        _get(
          ['s', '2'],
          {
            's': {1.0},
          },
        ),
        isFalse,
      );
    });

    test('Set of non-String/int objects is never a member', () {
      var ctx = {
        'enums': {_Tag.vip},
        'objs': {_Key('vip')},
        'bools': {true},
        'nulls': {null},
      };
      expect(_get(['enums', 'vip'], ctx), isFalse);
      expect(_get(['objs', 'vip'], ctx), isFalse);
      expect(_get(['bools', 'true'], ctx), isFalse);
      expect(_get(['nulls', 'null'], ctx), isFalse);
      expect(
        _build('{{enums.vip}}|{{objs.vip}}|{{bools.true}}', ctx),
        equals('false|false|false'),
      );
    });

    test('Set as the root context', () {
      expect(_get(['vip'], {'vip', 'new'}), isTrue);
      expect(_get(['old'], {'vip', 'new'}), isFalse);
      expect(_build('{{vip}}-{{old}}', {'vip'}), equals('true-false'));
      expect(_build('{{:vip}}V{{?}}N{{/}}', {'vip'}), equals('V'));
    });

    test('empty Set: no membership, printed empty (not "false")', () {
      var ctx = {'s': <String>{}};
      // An empty context short-circuits to `null` before the membership
      // check, so it prints as '' where a non-empty Set prints 'false':
      expect(_get(['s', 'vip'], ctx), isNull);
      expect(_build('[{{s.vip}}]', ctx), equals('[]'));
      expect(_build('{{:s.vip}}V{{?}}N{{/}}', ctx), equals('N'));
      expect(_build('{{!s.vip}}NOT{{/}}', ctx), equals('NOT'));
    });

    test('a key past the membership boolean resolves to null', () {
      var ctx = {
        's': {'vip'},
      };
      expect(_get(['s', 'vip', 'x'], ctx), isNull);
      expect(_build('[{{s.vip.x}}]', ctx), equals('[]'));
    });

    test('LinkedHashSet and SplayTreeSet are Sets: membership', () {
      // A Set literal is a `LinkedHashSet`:
      var linked = <String>{'b', 'a'};
      expect(linked, isA<LinkedHashSet<String>>());
      var ctx = {
        'l': linked,
        't': SplayTreeSet<int>.from([3, 1]),
        'u': UnmodifiableSetView({'x'}),
      };
      expect(_get(['l', 'a'], ctx), isTrue);
      // Not indexed: `0` is not an element.
      expect(_get(['l', '0'], ctx), isFalse);
      expect(_get(['t', '1'], ctx), isTrue);
      expect(_get(['t', '0'], ctx), isFalse);
      // SplayTreeSet<int> with a non-int key must not throw:
      expect(_get(['t', 'a'], ctx), isFalse);
      expect(_get(['u', 'x'], ctx), isTrue);
      expect(_get(['u', 'y'], ctx), isFalse);
    });
  });

  group('Set membership: nesting', () {
    test('Set at the end of a Map path', () {
      var ctx = {
        'a': {
          'b': {'tag'},
        },
      };
      expect(_get(['a', 'b', 'tag'], ctx), isTrue);
      expect(_build('{{:a.b.tag}}T{{?}}F{{/}}', ctx), equals('T'));
      expect(_build('{{:a.b.other}}T{{?}}F{{/}}', ctx), equals('F'));
      expect(_build('{{a.b.tag}}/{{a.b.other}}', ctx), equals('true/false'));
    });

    test('Set inside a Map inside a List', () {
      var ctx = {
        'list': [
          {
            'tags': {'vip'},
          },
          {
            'tags': {'new'},
          },
        ],
      };
      expect(_get(['list', '0', 'tags', 'vip'], ctx), isTrue);
      expect(_get(['list', '1', 'tags', 'vip'], ctx), isFalse);
      expect(
        _build('{{list.0.tags.vip}},{{list.1.tags.vip}}', ctx),
        equals('true,false'),
      );
      // Out of range index: null, not `false`.
      expect(_build('[{{list.5.tags.vip}}]', ctx), equals('[]'));
    });

    test('Set inside a DOMContext', () {
      var ctx = DOMContext(
        variables: {
          'tags': {'vip'},
        },
      );
      expect(_get(['tags', 'vip'], ctx), isTrue);
      expect(_build('{{:tags.vip}}V{{?}}N{{/}}', ctx), equals('V'));
    });

    test('Set returned by a Function context is not reached by keys', () {
      // `{{f.vip}}`: the function is called with the key, and its return is
      // the value (no further membership step).
      var ctx = {'f': (Object? k) => k == 'vip'};
      expect(_get(['f', 'vip'], ctx), isTrue);
      expect(_get(['f', 'x'], ctx), isFalse);
    });
  });

  group('Set membership in template blocks', () {
    var ctxVip = {
      'tags': {'vip', 'new'},
    };
    var ctxNew = {
      'tags': {'new'},
    };
    var ctxNone = {
      'tags': {'old'},
    };

    test('{{:...}} without else', () {
      expect(_build('a{{:tags.vip}}-VIP{{/}}b', ctxVip), equals('a-VIPb'));
      expect(_build('a{{:tags.vip}}-VIP{{/}}b', ctxNew), equals('ab'));
    });

    test('{{!...}} not', () {
      var t = '{{!tags.vip}}regular{{?}}vip{{/}}';
      expect(_build(t, ctxVip), equals('vip'));
      expect(_build(t, ctxNew), equals('regular'));
    });

    test('{{?:...}} else-if chain', () {
      var t = '{{:tags.vip}}VIP{{?:tags.new}}NEW{{?}}NONE{{/}}';
      expect(_build(t, ctxVip), equals('VIP'));
      expect(_build(t, ctxNew), equals('NEW'));
      expect(_build(t, ctxNone), equals('NONE'));
    });

    test('{{?!...}} else-not', () {
      var t = '{{:tags.vip}}VIP{{?!tags.new}}NOT-NEW{{?}}NEW{{/}}';
      expect(_build(t, ctxVip), equals('VIP'));
      expect(_build(t, ctxNew), equals('NEW'));
      expect(_build(t, ctxNone), equals('NOT-NEW'));
    });

    test('comparisons against "true"/"false"', () {
      expect(_build('{{:tags.vip=="true"}}Y{{?}}N{{/}}', ctxVip), equals('Y'));
      expect(_build('{{:tags.vip=="true"}}Y{{?}}N{{/}}', ctxNew), equals('N'));
      expect(_build('{{:tags.vip=="false"}}Y{{?}}N{{/}}', ctxNew), equals('Y'));
      expect(_build('{{:tags.vip!="true"}}Y{{?}}N{{/}}', ctxNew), equals('Y'));
      expect(_build('{{:tags.vip!="true"}}Y{{?}}N{{/}}', ctxVip), equals('N'));
    });

    test('comparison in an else-if', () {
      var t = '{{:tags.old}}OLD{{?:tags.vip=="true"}}VIP{{?}}-{{/}}';
      expect(_build(t, ctxVip), equals('VIP'));
      expect(_build(t, ctxNew), equals('-'));
      expect(_build(t, ctxNone), equals('OLD'));
    });

    test('comparison between two memberships', () {
      var t = '{{:a.x==b.y}}SAME{{?}}DIFF{{/}}';
      expect(
        _build(t, {
          'a': {'x'},
          'b': {'y'},
        }),
        equals('SAME'),
      );
      expect(
        _build(t, {
          'a': {'x'},
          'b': {'z'},
        }),
        equals('DIFF'),
      );
    });

    test('{{?...}} var-else prints "true" or the else content', () {
      var t = '{{?tags.vip}}default{{/}}';
      expect(_build(t, ctxVip), equals('true'));
      expect(_build(t, ctxNew), equals('default'));
    });

    test('printed directly', () {
      expect(_build('{{tags.vip}}/{{tags.old}}', ctxVip), equals('true/false'));
    });

    test('{{*:list}} loop over items holding Sets', () {
      var ctx = {
        'items': [
          {
            'name': 'A',
            'tags': {'vip'},
          },
          {
            'name': 'B',
            'tags': {'new'},
          },
          {'name': 'C', 'tags': <String>{}},
        ],
      };
      expect(
        _build('{{*:items}}[{{name}}:{{:tags.vip}}V{{?}}-{{/}}]{{/}}', ctx),
        equals('[A:V][B:-][C:-]'),
      );
      expect(
        _build('{{*:items}}{{name}}={{tags.vip}};{{/}}', ctx),
        equals('A=true;B=false;C=;'),
      );
    });

    test('{{*:list}} loop over a List of Sets', () {
      var ctx = {
        'sets': [
          {'vip'},
          {'x'},
        ],
      };
      expect(_build('{{*:sets}}{{vip}},{{/}}', ctx), equals('true,false,'));
    });

    // Regression: `evaluateValue` only handled Lists and Maps, and threw for
    // a Set (or any other Iterable) value.
    test('Set value as a condition / loop', () {
      expect(_build('{{:tags}}X{{?}}E{{/}}', ctxVip), equals('X'));
      expect(_build('{{:tags}}X{{?}}E{{/}}', {'tags': <String>{}}), 'E');
      expect(_build('{{*:tags}}<{{.}}>{{/}}', ctxNew), equals('<new>'));
    });

    test('other Iterable values as a condition', () {
      expect(
        _build('{{:it}}X{{?}}E{{/}}', {'it': Iterable.generate(2, (i) => i)}),
        equals('X'),
      );
      expect(
        _build('{{:it}}X{{?}}E{{/}}', {'it': Iterable.generate(0, (i) => i)}),
        equals('E'),
      );
    });
  });

  group('Other Iterables are indexed', () {
    test('Iterable.generate', () {
      var ctx = {'g': Iterable.generate(3, (i) => i * 10)};
      expect(_get(['g', '0'], ctx), equals(0));
      expect(_get(['g', '2'], ctx), equals(20));
      expect(_get(['g', '3'], ctx), isNull);
      expect(_get(['g', '-1'], ctx), isNull);
      // Not membership: `10` is an element, but index 10 is out of range.
      expect(_get(['g', '10'], ctx), isNull);
      expect(_build('{{g.1}}', ctx), equals('10'));
    });

    test('map(...) of a List and of a Set', () {
      var ctx = {
        'ml': ['a', 'b'].map((e) => e.toUpperCase()),
        'ms': {'x', 'y'}.map((e) => '$e!'),
        'w': [1, 2, 3, 4].where((e) => e.isEven),
      };
      expect(_build('{{ml.1}}|{{ms.0}}|{{w.1}}', ctx), equals('B|x!|4'));
      // A mapped Set is no longer a Set: no membership.
      expect(_get(['ms', 'x!'], ctx), isNull);
    });

    test('Queue', () {
      var ctx = {
        'q': Queue<String>.from(['first', 'second']),
        'lq': ListQueue<int>.from([7, 8]),
      };
      expect(_get(['q', '0'], ctx), equals('first'));
      expect(_get(['q', '1'], ctx), equals('second'));
      expect(_get(['q', 'first'], ctx), isNull);
      expect(_build('{{lq.1}}', ctx), equals('8'));
    });

    test('UnmodifiableListView is a List: indexing', () {
      var ctx = {
        'u': UnmodifiableListView(['a', 'b']),
      };
      expect(_get(['u', '1'], ctx), equals('b'));
      expect(_get(['u', 'a'], ctx), isNull);
      expect(_build('{{u.0}}', ctx), equals('a'));
    });

    test('empty Iterable resolves to null', () {
      var ctx = {'e': Iterable<int>.empty()};
      expect(_get(['e', '0'], ctx), isNull);
    });

    test('Iterable of Sets: index then membership', () {
      var ctx = {
        'it': Iterable.generate(2, (i) => {'k$i'}),
      };
      expect(_get(['it', '0', 'k0'], ctx), isTrue);
      expect(_get(['it', '1', 'k0'], ctx), isFalse);
      expect(_build('{{it.1.k1}}', ctx), equals('true'));
    });

    test('pre-existing: List indexing and Map lookup', () {
      var ctx = {
        'l': ['a', 'b'],
        'm': {'k': 'v', 1: 'one'},
      };
      expect(_build('{{l.0}}{{l.1}}[{{l.2}}]', ctx), equals('ab[]'));
      expect(_build('{{m.k}}|{{m.1}}|[{{m.z}}]', ctx), equals('v|one|[]'));
    });
  });

  group('Function values: argument types', () {
    test('Function(Object?) gets each kind of context', () {
      String f(Object? o) => switch (o) {
        null => 'null',
        Map() => 'map',
        List() => 'list',
        String() => 'string',
        DOMContext() => 'ctx',
        _ => 'other:${o.runtimeType}',
      };

      expect(DOMTemplateVariable.evaluateObject({}, f), equals('map'));
      expect(DOMTemplateVariable.evaluateObject([], f), equals('list'));
      expect(DOMTemplateVariable.evaluateObject('s', f), equals('string'));
      expect(DOMTemplateVariable.evaluateObject(null, f), equals('null'));
      expect(
        DOMTemplateVariable.evaluateObject(DOMContext(), f),
        equals('ctx'),
      );
      expect(DOMTemplateVariable.evaluateObject(42, f), equals('other:int'));

      expect(_build('{{f}}', {'f': f}), equals('map'));
      expect(_build('{{0}}', [f]), equals('list'));
      expect(_build('{{f}}', DOMContext(variables: {'f': f})), equals('ctx'));
    });

    test('Function(dynamic) is a Function(Object?)', () {
      String f(dynamic o) => 'dyn:${o.runtimeType}';
      expect(DOMTemplateVariable.evaluateObject('s', f), equals('dyn:String'));
      expect(DOMTemplateVariable.evaluateObject(null, f), equals('dyn:Null'));
      expect(_build('{{0}}', [f]), startsWith('dyn:List'));
    });

    test('Function(Map?) gets the Map, or null for any other context', () {
      String f(Map? m) => m == null ? 'null' : 'map:${m.length}';
      expect(DOMTemplateVariable.evaluateObject({'a': 1}, f), equals('map:1'));
      expect(DOMTemplateVariable.evaluateObject([1], f), equals('null'));
      expect(DOMTemplateVariable.evaluateObject('s', f), equals('null'));
      expect(DOMTemplateVariable.evaluateObject(null, f), equals('null'));
      // A DOMContext is not a Map: null (its variables are not passed).
      expect(
        DOMTemplateVariable.evaluateObject(DOMContext(variables: {'a': 1}), f),
        equals('null'),
      );
      expect(_build('{{f}}', DOMContext(variables: {'f': f})), equals('null'));
    });

    test('Function(Map) (non-nullable) is not called', () {
      // A `Function(Map)` is NOT a `Function(Map?)` (contravariance), so it
      // is returned as is, and printed as a closure.
      String f(Map m) => 'map:${m.length}';
      var r = DOMTemplateVariable.evaluateObject({'a': 1}, f);
      expect(r, same(f));
    });

    test('Function(Map<String, dynamic>?) is not called', () {
      // Not a `Function(Map?)`: a `Map?` is not assignable to its parameter,
      // so it falls through and is returned unchanged.
      String f(Map<String, dynamic>? m) => 'called';
      var r = DOMTemplateVariable.evaluateObject(<String, dynamic>{}, f);
      expect(r, same(f));
      expect(_build('{{f}}', {'f': f}), isNot(equals('called')));
    });

    test('Function(String) is not called as a value', () {
      String f(String s) => 'called';
      expect(DOMTemplateVariable.evaluateObject('s', f), same(f));
    });

    test('Function() ignores the context', () {
      String f() => 'zero';
      expect(DOMTemplateVariable.evaluateObject({}, f), equals('zero'));
      expect(DOMTemplateVariable.evaluateObject(null, f), equals('zero'));
      expect(DOMTemplateVariable.evaluateObject([], f), equals('zero'));
      expect(_build('{{0}}', [f]), equals('zero'));
    });

    test('Function with optional parameters', () {
      // `([Object? o])` is both a `Function()` and a `Function(Object?)`;
      // the latter wins, so it gets the context.
      String f([Object? o]) => o == null ? 'none' : 'got';
      expect(DOMTemplateVariable.evaluateObject({}, f), equals('got'));
    });

    test('Function inside loop items is evaluated with the ROOT context', () {
      // `{{*:items}}` resolves `items` first, and `evaluateObject` walks the
      // List/Map values eagerly with the context of that lookup (the root),
      // so the item's own fields are not visible to the function.
      var ctx = {
        'n': 'root',
        'items': [
          {'n': 1, 'f': (Object? o) => 'n=${(o as Map)['n']}'},
          {'n': 2, 'f': (Map? m) => 'n=${m!['n']}'},
        ],
      };
      expect(_build('{{*:items}}{{f}};{{/}}', ctx), equals('n=root;n=root;'));
    });

    test(
      'Function inside loop items gets the item as context',
      skip:
          'Bug (pre-existing): `DOMTemplateBlockIfCollection.buildContent` '
          '(lib/src/dom_builder_template.dart:1427) iterates the value from '
          '`getResolved`, whose `evaluateObject` (line 694) already called '
          'every Function nested in the items with the outer context.',
      () {
        var ctx = {
          'items': [
            {'n': 1, 'f': (Object? o) => 'n=${(o as Map)['n']}'},
            {'n': 2, 'f': (Map? m) => 'n=${m!['n']}'},
          ],
        };
        expect(_build('{{*:items}}{{f}};{{/}}', ctx), equals('n=1;n=2;'));
      },
    );

    test('Function in a List value gets the outer context', () {
      var ctx = {
        'id': 'X',
        'l': [
          () => 'a',
          (Object? o) => (o as Map)['id'],
          (Map? m) => m!.length,
        ],
      };
      expect(_build('{{l}}', ctx), equals('aX2'));
    });

    test('Function as a condition value', () {
      var t = '{{:f}}T{{?}}F{{/}}';
      expect(_build(t, {'f': (Object? o) => true}), equals('T'));
      expect(_build(t, {'f': (Object? o) => false}), equals('F'));
      expect(_build(t, {'f': (Map? m) => m != null}), equals('T'));
      expect(_build(t, {'f': () => ''}), equals('F'));
      expect(_build(t, {'f': () => null}), equals('F'));
      expect(_build('{{:f=="ok"}}Y{{?}}N{{/}}', {'f': () => 'ok'}), 'Y');
    });
  });

  group('Function values: return types', () {
    test('returning String, num, bool and null', () {
      var ctx = {
        's': (Object? o) => 'str',
        'i': (Object? o) => 7,
        'd': (Map? m) => 1.5,
        'b': () => false,
        'n': (Object? o) => null,
      };
      expect(
        _build('{{s}}|{{i}}|{{d}}|{{b}}|[{{n}}]', ctx),
        'str|7|1.5|false|[]',
      );
      expect(DOMTemplateVariable(['i']).getResolved(ctx), equals(7));
      expect(DOMTemplateVariable(['n']).getResolved(ctx), isNull);
    });

    test('returning a Map or a List (values evaluated)', () {
      var ctx = {
        'm': (Object? o) => {'a': () => 1},
        'l': (Map? m) => ['x', () => 'y', (Object? o) => (o as Map).length],
      };
      expect(DOMTemplateVariable(['m']).getResolved(ctx), equals({'a': 1}));
      expect(
        DOMTemplateVariable(['l']).getResolved(ctx),
        equals(['x', 'y', 2]),
      );
      expect(_build('{{m}}', ctx), equals('a: 1'));
      expect(_build('{{l}}', ctx), equals('xy2'));
    });

    test('returning another function (chained evaluation)', () {
      var ctx = {
        'id': 'Z',
        'f': () =>
            (Object? o) =>
                (Map? m) => 'deep:${m!['id']}',
      };
      expect(_build('{{f}}', ctx), equals('deep:Z'));
    });

    test('returning a DOM node', () {
      var ctx = {'f': (Object? o) => $div(content: 'hi')};
      var built = DOMTemplate.parse('{{f}}').build(ctx) as List;
      expect(built.length, equals(1));
      expect(built.first, isA<DOMElement>());
      expect((built.first as DOMElement).buildHTML(), equals('<div>hi</div>'));
      expect(_build('{{f}}', ctx), equals('<div>hi</div>'));
    });

    test('returning a Set (returned as is)', () {
      var ctx = {
        'f': (Object? o) => {'a'},
      };
      expect(DOMTemplateVariable(['f']).getResolved(ctx), equals({'a'}));
    });
  });

  group('Function contexts (pre-existing)', () {
    test('{{f.name}} calls the function with the key', () {
      expect(_build('{{f.name}}', {'f': (Object? k) => 'v-$k'}), 'v-name');
      expect(_build('{{f.name}}', {'f': (dynamic k) => '$k!'}), 'name!');
    });

    test('{{f.a.b}}: the return of the first call is the next context', () {
      var ctx = {
        'f': (String k) => {'b': 'k=$k'},
      };
      expect(_build('{{f.a.b}}', ctx), equals('k=a'));
    });

    test('{{f.vip}} where f returns a Set: membership on the next key', () {
      var ctx = {
        'f': (String k) => {'vip'},
      };
      expect(_get(['f', 'any', 'vip'], ctx), isTrue);
      expect(_get(['f', 'any', 'x'], ctx), isFalse);
    });

    test(
      '{{f.name}} with a Function() or Function(Map?) context',
      skip:
          'Bug (pre-existing): `DOMTemplateVariable._get` (lib/src/'
          'dom_builder_template.dart:603) calls any `Function` context '
          'dynamically with the String key, so a `Function()` throws '
          'NoSuchMethodError and a `Function(Map?)` throws a TypeError '
          'instead of resolving to null.',
      () {
        expect(_build('[{{f.name}}]', {'f': () => 'x'}), equals('[]'));
        expect(_build('[{{f.name}}]', {'f': (Map? m) => 'x'}), equals('[]'));
      },
    );
  });
}
