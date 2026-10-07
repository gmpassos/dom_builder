@TestOn('vm')
library;

import 'package:dom_builder/dom_builder.dart';
import 'package:test/test.dart';

import 'dom_builder_domtest.dart';

/// The boolean attributes (`DOMAttribute.isBooleanAttribute`).
const _booleanAttributes = [
  'checked',
  'hidden',
  'disabled',
  'selected',
  'multiple',
  'inert',
  'autoplay',
  'controls',
  'muted',
];

DOMElement _parse(String html) => DOMNode.parseNodes(html).first as DOMElement;

/// Resolves [name] of [domElement] with a fresh [TestGenerator].
String? _resolve(
  DOMElement domElement,
  String name, {
  bool booleanDefault = false,
  String? valueDefault,
  bool preserveClass = false,
  bool preserveStyle = false,
  TestElem? element,
  TestGenerator? generator,
}) {
  generator ??= TestGenerator();
  return generator.resolveAttributeValue(
    domElement,
    element ?? TestElem(domElement.tag),
    name,
    generator.createDOMTreeMap(),
    booleanDefault: booleanDefault,
    valueDefault: valueDefault,
    preserveClass: preserveClass,
    preserveStyle: preserveStyle,
  );
}

void main() {
  group('boolean attributes: value forms', () {
    const onForms = [
      'TRUE',
      ' true ',
      'True',
      'On',
      'YES',
      '1',
      '',
      'checked-own-name',
    ];
    const offForms = ['FALSE', 'Off', 'off ', 'NO', '0', 'null', 'x', '2'];

    for (final name in _booleanAttributes) {
      test('$name: on forms', () {
        for (final form in onForms) {
          final v = form == 'checked-own-name' ? name : form;
          final attr = DOMAttribute.from(name, v)!;
          expect(attr.isBoolean, isTrue, reason: '$name="$v"');
          expect(attr.hasValue, isTrue, reason: '$name="$v"');
          expect(attr.value, equals('true'), reason: '$name="$v"');
          expect(attr.buildHTML(), equals(name), reason: '$name="$v"');

          final e = _parse('<div $name="$v">x</div>');
          expect(e.getAttributeValueAsBool(name), isTrue, reason: '$name="$v"');
          expect(e.buildHTML(), equals('<div $name>x</div>'));
        }
      });

      test('$name: off forms (left out of the HTML)', () {
        for (final v in offForms) {
          final attr = DOMAttribute.from(name, v)!;
          expect(attr.isBoolean, isTrue, reason: '$name="$v"');
          expect(attr.hasValue, isFalse, reason: '$name="$v"');
          expect(attr.value, equals('false'), reason: '$name="$v"');
          expect(attr.buildHTML(), isEmpty, reason: '$name="$v"');

          final e = _parse('<div $name="$v">x</div>');
          expect(e.getAttributeValueAsBool(name), isFalse);
          // The attribute is kept (as off), but not built:
          expect(e.attributesNames, contains(name));
          expect(e.buildHTML(), equals('<div>x</div>'), reason: '$name="$v"');
        }
      });

      test('$name: its own name, any case and blanks', () {
        for (final v in [
          name,
          name.toUpperCase(),
          ' $name ',
          '${name[0].toUpperCase()}${name.substring(1)}',
        ]) {
          expect(DOMAttribute.from(name, v)!.hasValue, isTrue, reason: v);
          expect(_resolve(_parse('<div $name="$v">x</div>'), name), 'true');
        }
      });
    }

    test("another boolean attribute's name is off", () {
      expect(DOMAttribute.from('checked', 'disabled')!.hasValue, isFalse);
      expect(DOMAttribute.from('hidden', 'checked')!.hasValue, isFalse);
      expect(_resolve(_parse('<input checked="muted">'), 'checked'), isNull);
    });

    // `parseBool` (swiss_knife) words: "selected", "enabled", "ok", "y"...
    test('parseBool words are on, for any boolean attribute', () {
      for (final v in ['selected', 'enabled', 'ok', 'active', 'y', 't', '+']) {
        expect(DOMAttribute.from('checked', v)!.hasValue, isTrue, reason: v);
      }
      // Even a contradictory one:
      expect(
        _parse('<button disabled="enabled">b</button>').buildHTML(),
        equals('<button disabled>b</button>'),
      );
    });

    test('an upper-case attribute name is normalized', () {
      final on = _parse('<input CHECKED="CHECKED" Disabled>');
      expect(on.attributesNames, unorderedEquals(['checked', 'disabled']));
      expect(on.buildHTML(), equals('<input checked disabled>'));

      final off = _parse('<input CHECKED="false">');
      expect(off.getAttributeValueAsBool('checked'), isFalse);
      expect(off.buildHTML(), equals('<input>'));

      expect(DOMAttribute.from(' Checked ', 'checked')!.name, 'checked');
      expect(DOMAttribute.from(' Checked ', 'checked')!.hasValue, isTrue);
    });

    test('Dart values: bool, int and null', () {
      for (final name in _booleanAttributes) {
        expect(DOMAttribute.from(name, true)!.hasValue, isTrue);
        expect(DOMAttribute.from(name, false)!.hasValue, isFalse);
        expect(DOMAttribute.from(name, 1)!.hasValue, isTrue);
        expect(DOMAttribute.from(name, 0)!.hasValue, isFalse);
        // `null`: no attribute at all.
        expect(DOMAttribute.from(name, null), isNull);
      }
    });

    test(r'$tag(attributes:) with Dart bools and null', () {
      final input = $tag(
        'input',
        attributes: {
          'type': 'checkbox',
          'checked': true,
          'disabled': false,
          'hidden': null,
          'multiple': 'multiple',
          'muted': '',
          'autoplay': 'off',
        },
      );

      expect(input.attributesNames, isNot(contains('hidden')));
      expect(input.attributesNames, contains('disabled'));
      expect(input.getAttributeValueAsBool('disabled'), isFalse);
      // The value attributes first, then the boolean ones (in order):
      expect(
        input.buildHTML(),
        equals('<input type="checkbox" checked multiple muted>'),
      );
    });

    test('the DOMElement hidden argument', () {
      expect($div(hidden: true).buildHTML(), equals('<div hidden></div>'));
      expect($div(hidden: false).buildHTML(), equals('<div></div>'));
      expect(
        DOMElement(
          'div',
          attributes: {'hidden': true},
          hidden: false,
        ).attributesNames,
        isNot(contains('hidden')),
      );
      // An already set `hidden` attribute is kept:
      expect(
        $div(attributes: {'hidden': 'hidden'}, hidden: true).buildHTML(),
        equals('<div hidden></div>'),
      );
    });

    test('setValue with Dart and String values', () {
      final attr = DOMAttribute.from('checked', true)!;
      for (final (v, on) in [
        (false, false),
        (true, true),
        (0, false),
        (1, true),
        ('off', false),
        ('on', true),
        (null, false),
        ('TRUE', true),
      ]) {
        attr.setValue(v);
        expect(attr.hasValue, equals(on), reason: '$v');
        expect(attr.buildHTML(), equals(on ? 'checked' : ''), reason: '$v');
      }
    });

    test('setValue/setAttribute: "" and the own name are on, as in from()', () {
      final attr = DOMAttribute.from('checked', false)!;
      attr.setValue('');
      expect(attr.hasValue, isTrue);
      attr.setValue(false);
      attr.setValue('checked');
      expect(attr.hasValue, isTrue);

      // `setAttribute` on an already present attribute calls `setValue`:
      final input = $input()..setAttribute('checked', 'checked');
      expect(input.buildHTML(), equals('<input checked>'));
      input.setAttribute('checked', 'checked');
      expect(input.buildHTML(), equals('<input checked>'));
    });

    test('equalsAttributeValue / containsValue of a boolean', () {
      final on = DOMAttribute.from('selected', 'selected')!;
      expect(on.valueHandler.equalsAttributeValue(true), isTrue);
      expect(on.valueHandler.equalsAttributeValue('yes'), isTrue);
      expect(on.valueHandler.equalsAttributeValue(false), isFalse);
      expect(on.containsValue('true'), isTrue);

      final off = DOMAttribute.from('selected', 'no')!;
      expect(off.valueHandler.equalsAttributeValue(false), isTrue);
      // `null` parses as false:
      expect(off.valueHandler.equalsAttributeValue(null), isTrue);
      expect(off.valueHandler.equalsAttributeValue('off'), isTrue);
    });
  });

  group('resolveAttributeDefaults: every combination', () {
    String? apply(String name, String? value, bool b, String? v) =>
        DOMGenerator.resolveAttributeDefaults(
          name,
          value,
          booleanDefault: b,
          valueDefault: v,
        );

    for (final b in [false, true]) {
      for (final v in [null, '', '-']) {
        test(
          'booleanDefault: $b, valueDefault: ${v == null ? null : '"$v"'}',
          () {
            for (final name in _booleanAttributes) {
              expect(apply(name, null, b, v), equals(b ? 'true' : null));
              // A value wins, even an empty or "false" one:
              expect(apply(name, 'true', b, v), equals('true'));
              expect(apply(name, 'false', b, v), equals('false'));
              expect(apply(name, '', b, v), equals(''));
            }
            for (final name in ['title', 'value', 'data-x', 'class', 'style']) {
              expect(apply(name, null, b, v), equals(v), reason: name);
              expect(apply(name, 'x', b, v), equals('x'), reason: name);
              expect(apply(name, '', b, v), equals(''), reason: name);
            }
          },
        );
      }
    }

    test('the attribute name is case sensitive', () {
      // Names are normalized (lower case) before; an upper-case name is not
      // a boolean one:
      expect(apply('CHECKED', null, true, '-'), equals('-'));
    });
  });

  group('resolveAttributeValue: every combination', () {
    for (final b in [false, true]) {
      for (final v in [null, '', '-']) {
        test(
          'booleanDefault: $b, valueDefault: ${v == null ? null : '"$v"'}',
          () {
            final e = _parse(
              '<input checked hidden="false" disabled="disabled" '
              'title="t" value="" data-x>',
            );
            String? r(String name) =>
                _resolve(e, name, booleanDefault: b, valueDefault: v);

            expect(r('checked'), equals('true'));
            expect(r('disabled'), equals('true'));
            // A false boolean is off, whatever the defaults:
            expect(r('hidden'), isNull);
            expect(r('title'), equals('t'));
            // An empty value is a value: no default.
            expect(r('value'), equals(''));
            expect(r('data-x'), equals(''));

            // A value attribute without a value: valueDefault.
            final noValue = $div(attributes: {'title': 'x'});
            noValue.getAttribute('title')!.setValue(null);
            expect(
              _resolve(noValue, 'title', booleanDefault: b, valueDefault: v),
              equals(v),
            );
          },
        );
      }
    }

    test('a template attribute is resolved with the generator context', () {
      final generator = TestGenerator()
        ..domContext = DOMContext(variables: {'t': 'Hi', 'e': ''});
      final e = _parse('<div title="{{t}}" data-e="{{e}}">x</div>');

      expect(_resolve(e, 'title', generator: generator), equals('Hi'));
      // A template building to '' is an empty value, not a missing one:
      expect(
        _resolve(e, 'data-e', generator: generator, valueDefault: '-'),
        equals(''),
      );
    });

    test('a boolean attribute from a template building "false" is off', () {
      final generator = TestGenerator()
        ..domContext = DOMContext(variables: {'d': false});
      final e = _parse('<input disabled="{{d}}">');
      expect(_resolve(e, 'disabled', generator: generator), isNull);
    });
  });

  group('resolveAttributeValue: preserveClass / preserveStyle', () {
    TestElem elem(String tag, {String? cls, String? style}) {
      final e = TestElem(tag);
      if (cls != null) e.attributes['class'] = cls;
      if (style != null) e.attributes['style'] = style;
      return e;
    }

    test('a preserved class is merged with the new one', () {
      expect(
        _resolve(
          _parse('<div class="b c">x</div>'),
          'class',
          preserveClass: true,
          element: elem('div', cls: 'a'),
        ),
        equals('a b c'),
      );
    });

    test('a preserved class wins over valueDefault', () {
      for (final b in [false, true]) {
        for (final v in [null, '', '-']) {
          expect(
            _resolve(
              _parse('<div class="">x</div>'),
              'class',
              preserveClass: true,
              booleanDefault: b,
              valueDefault: v,
              element: elem('div', cls: 'a'),
            ),
            equals('a'),
            reason: 'booleanDefault: $b, valueDefault: $v',
          );
        }
      }
    });

    test('no preserved class: valueDefault', () {
      for (final prev in [null, '']) {
        expect(
          _resolve(
            _parse('<div class="">x</div>'),
            'class',
            preserveClass: true,
            valueDefault: '-',
            element: elem('div', cls: prev),
          ),
          equals('-'),
          reason: 'prev: $prev',
        );
      }
      expect(
        _resolve(
          _parse('<div class="b">x</div>'),
          'class',
          preserveClass: true,
          element: elem('div', cls: ''),
        ),
        equals('b'),
      );
    });

    test('preserveClass: false replaces the class', () {
      expect(
        _resolve(
          _parse('<div class="b">x</div>'),
          'class',
          element: elem('div', cls: 'a'),
        ),
        equals('b'),
      );
      expect(
        _resolve(
          _parse('<div class="">x</div>'),
          'class',
          valueDefault: '-',
          element: elem('div', cls: 'a'),
        ),
        equals('-'),
      );
    });

    test('a preserved style is merged with the new one', () {
      for (final prev in ['color: red', 'color: red;']) {
        expect(
          _resolve(
            _parse('<div style="top: 0">x</div>'),
            'style',
            preserveStyle: true,
            element: elem('div', style: prev),
          ),
          equals(prev.endsWith(';') ? '$prev top: 0' : '$prev; top: 0'),
          reason: prev,
        );
      }
    });

    test('a preserved style wins over valueDefault', () {
      for (final b in [false, true]) {
        for (final v in [null, '', '-']) {
          expect(
            _resolve(
              _parse('<div style="">x</div>'),
              'style',
              preserveStyle: true,
              booleanDefault: b,
              valueDefault: v,
              element: elem('div', style: 'color: red'),
            ),
            equals('color: red'),
            reason: 'booleanDefault: $b, valueDefault: $v',
          );
        }
      }
      // No preserved style: valueDefault.
      expect(
        _resolve(
          _parse('<div style="">x</div>'),
          'style',
          preserveStyle: true,
          valueDefault: '-',
          element: elem('div'),
        ),
        equals('-'),
      );
    });

    test('preserveClass does not preserve the style (and vice versa)', () {
      final e = _parse('<div class="b" style="top: 0">x</div>');
      final prev = elem('div', cls: 'a', style: 'color: red');

      expect(
        _resolve(e, 'style', preserveClass: true, element: prev),
        equals('top: 0'),
      );
      expect(
        _resolve(e, 'class', preserveStyle: true, element: prev),
        equals('b'),
      );
    });
  });

  group('resolveAttributeValue: src / href with sourceResolver', () {
    test('without a sourceResolver the value is kept', () {
      final element = TestElem('img');
      expect(
        _resolve(_parse('<img src="a.png">'), 'src', element: element),
        equals('a.png'),
      );
      expect(element.attributes, isEmpty);
    });

    for (final (tag, name) in [('img', 'src'), ('a', 'href')]) {
      test('$name: resolved, the original kept in $name-original', () {
        final generator = TestGenerator()
          ..sourceResolver = (url) => 'https://cdn/$url';
        final element = TestElem(tag);

        expect(
          _resolve(
            _parse('<$tag $name="x/y">'),
            name,
            generator: generator,
            element: element,
          ),
          equals('https://cdn/x/y'),
        );
        expect(element.attributes, equals({'$name-original': 'x/y'}));
      });
    }

    test('an unchanged source sets no -original', () {
      final generator = TestGenerator()..sourceResolver = (url) => url;
      final element = TestElem('img');
      expect(
        _resolve(
          _parse('<img src="a.png">'),
          'src',
          generator: generator,
          element: element,
        ),
        equals('a.png'),
      );
      expect(element.attributes, isEmpty);
    });

    test('an empty or missing source is not resolved', () {
      final calls = <String>[];
      final generator = TestGenerator()
        ..sourceResolver = (url) {
          calls.add(url);
          return 'resolved';
        };

      expect(
        _resolve(_parse('<img src="">'), 'src', generator: generator),
        equals(''),
      );

      final img = $img(src: 'a.png');
      img.getAttribute('src')!.setValue(null);
      expect(
        _resolve(img, 'src', generator: generator, valueDefault: '-'),
        equals('-'),
      );
      expect(calls, isEmpty);
    });

    test('other URL-like attributes are not resolved', () {
      final generator = TestGenerator()..sourceResolver = (url) => 'resolved';
      final e = _parse('<img data-src="a.png" srcset="b.png">');
      expect(_resolve(e, 'data-src', generator: generator), equals('a.png'));
      expect(_resolve(e, 'srcset', generator: generator), equals('b.png'));
    });
  });

  group('setAttributes (buildDOM) with TestGenerator', () {
    test('mixed empty, false and value attributes', () {
      final generator = TestGenerator();
      final div = _parse(
        '<div id="" class="" style="" title="" data-x hidden="false">'
        '<input checked="checked" value="false" disabled="off" '
        'autocomplete="off" spellcheck="false">'
        '</div>',
      );

      final root = div.buildDOM(generator: generator) as TestElem;
      expect(root.attributes, equals({'id': '', 'title': '', 'data-x': ''}));

      final input = root.nodes.single as TestElem;
      expect(
        input.attributes,
        equals({
          'checked': 'true',
          'value': 'false',
          'autocomplete': 'off',
          'spellcheck': 'false',
        }),
      );
    });

    test('DOMGeneratorDelegate.setAttributes forwards preserveClass', () {
      final generator = TestGenerator();
      final delegate = DOMGeneratorDelegate<TestNode>(generator);
      final element = TestElem('div')..attributes['class'] = 'a';

      delegate.setAttributes(
        _parse('<div class="b" selected="no" title="">x</div>'),
        element,
        generator.createDOMTreeMap(),
        preserveClass: true,
      );

      expect(element.attributes, equals({'class': 'a b', 'title': ''}));
    });

    test(
      'DOMGeneratorDelegate.resolveAttributeValue forwards the defaults',
      () {
        final generator = TestGenerator();
        final delegate = DOMGeneratorDelegate<TestNode>(generator);
        final div = $div(attributes: {'title': 'x'});
        div.getAttribute('title')!.setValue(null);

        expect(
          delegate.resolveAttributeValue(
            div,
            TestElem('div'),
            'title',
            generator.createDOMTreeMap(),
            booleanDefault: true,
            valueDefault: '-',
          ),
          equals('-'),
        );
      },
    );

    test('DOMGeneratorDummy.resolveAttributeValue is always null', () {
      final dummy = DOMGeneratorDummy<TestNode>();
      final treeMap = TestGenerator().createDOMTreeMap();
      final e = _parse('<input checked title="t">');
      for (final name in ['checked', 'title']) {
        expect(
          dummy.resolveAttributeValue(
            e,
            TestElem('input'),
            name,
            treeMap,
            booleanDefault: true,
            valueDefault: '-',
          ),
          isNull,
        );
      }
    });
  });

  group('empty values', () {
    test('kept: data-x="", valueless data-x, value, title, id', () {
      final e = _parse(
        '<input id="" value="" title="" data-x="" data-y aria-label="">',
      );
      for (final name in ['id', 'value', 'title', 'data-x', 'data-y']) {
        expect(e.getAttributeValue(name), equals(''), reason: name);
        expect(e.getAttribute(name)!.hasValue, isFalse, reason: name);
        // `hasAttributeValue` is a non-empty value:
        expect(e.hasAttributeValue(name), isFalse, reason: name);
      }
      expect(
        e.buildHTML(),
        equals(
          '<input id="" value="" title="" data-x="" data-y="" aria-label="">',
        ),
      );
    });

    test('an empty class / style is left out', () {
      final e = _parse('<div class="" style="" title="">x</div>');
      expect(e.getAttributeValue('class'), isNull);
      expect(e.getAttributeValue('style'), isNull);
      expect(e.buildHTML(), equals('<div title="">x</div>'));

      final blank = _parse('<div class="   " style=" ; ">x</div>');
      expect(blank.buildHTML(), equals('<div>x</div>'));
    });

    test("setValue('') vs setValue(null)", () {
      final div = $div(attributes: {'title': 't', 'data-x': 'x'});

      div.getAttribute('title')!.setValue('');
      div.getAttribute('data-x')!.setValue(null);

      expect(div.getAttributeValue('title'), equals(''));
      expect(div.getAttributeValue('data-x'), isNull);
      // Both still listed, only the empty one is built:
      expect(div.attributesNames, equals(['title', 'data-x']));
      expect(div.buildHTML(), equals('<div title=""></div>'));
      expect(DOMAttribute.from('data-x', null)!.buildHTML(), isEmpty);
    });

    test("setAttribute('') keeps an empty value; null removes the value", () {
      final div = $div()..setAttribute('title', '');
      expect(div.buildHTML(), equals('<div title=""></div>'));
      div.setAttribute('title', null);
      expect(div.buildHTML(), equals('<div></div>'));
      div.setAttribute('title', 'x');
      expect(div.buildHTML(), equals('<div title="x"></div>'));
    });

    test('equalsAttributeValue: null vs a missing value', () {
      final none = DOMAttributeValueString(null);
      expect(none.equalsAttributeValue(null), isTrue);
      expect(none.equalsAttributeValue(''), isFalse);

      final empty = DOMAttributeValueString('');
      expect(empty.asAttributeValue, equals(''));
      expect(empty.asAttributeValues, equals(['']));
      expect(empty.length, equals(0));
      // '' is a value: not equal to null (no value).
      expect(empty.equalsAttributeValue(null), isFalse);
    });

    // Regression: '' didn't equal '' (it required a non-empty value).
    test("equalsAttributeValue('') of an empty value is true", () {
      expect(DOMAttributeValueString('').equalsAttributeValue(''), isTrue);
      expect(DOMAttributeValueString('').containsAttributeValue(''), isTrue);
    });

    test('class / style: empty equals null', () {
      final cls = DOMAttribute.from('class', '')!.valueHandler;
      expect(cls.equalsAttributeValue(null), isTrue);
      expect(cls.equalsAttributeValue(''), isTrue);
      expect(cls.equalsAttributeValue('a'), isFalse);

      final style = DOMAttribute.from('style', '')!.valueHandler;
      expect(style.equalsAttributeValue(null), isTrue);
      expect(style.equalsAttributeValue(''), isTrue);
      expect(
        DOMAttribute.from(
          'style',
          'color: red',
        )!.valueHandler.equalsAttributeValue(null),
        isFalse,
      );

      final list = DOMAttributeValueList('', ' ', RegExp(r'\s+'));
      expect(list.equalsAttributeValue(null), isTrue);
      expect(list.equalsAttributeValue(''), isFalse);
    });

    test('a template attribute building to an empty value', () {
      final attr = DOMAttribute.from('title', '{{t}}')!;
      final ctx = DOMContext(variables: {'t': ''});

      expect(attr.getValue(ctx), equals(''));
      expect(
        attr.buildHTML(
          domContext: ctx,
          dsxResolution: DSXResolution.lifecycleManager(null),
        ),
        equals('title=""'),
      );

      final e = _parse('<div data-x="{{t}}" id="i">x</div>');
      expect(
        e.buildHTML(
          domContext: ctx,
          dsxResolution: DSXResolution.lifecycleManager(null),
        ),
        equals('<div id="i" data-x="">x</div>'),
      );
    });

    test('attribute order: id, class, style, values, then booleans', () {
      final e = _parse(
        '<input checked data-a="" type="text" style="top: 0" disabled="false" '
        'value="" class="c" hidden id="" title="t">',
      );
      expect(
        e.buildHTML(),
        equals(
          '<input id="" class="c" style="top: 0" data-a="" type="text" '
          'value="" title="t" checked hidden>',
        ),
      );
    });

    test('quotes: a value with " is single-quoted, an empty one is ""', () {
      final e = $div(attributes: {'title': 'a "b"', 'data-x': ''});
      expect(e.buildHTML(), equals('<div title=\'a "b"\' data-x=""></div>'));
    });
  });

  group('boolean-looking values of non-boolean attributes', () {
    const cases = [
      ('contenteditable', 'false'),
      ('contenteditable', 'true'),
      ('draggable', 'false'),
      ('draggable', 'true'),
      ('aria-hidden', 'false'),
      ('aria-hidden', 'true'),
      ('aria-checked', 'false'),
      ('translate', 'no'),
      ('translate', 'yes'),
      ('autocomplete', 'off'),
      ('spellcheck', 'false'),
      ('value', 'false'),
      ('value', '0'),
      ('data-checked', 'false'),
      ('data-hidden', 'off'),
      ('data-x', 'no'),
      ('title', 'checked'),
    ];

    for (final (name, value) in cases) {
      test('$name="$value" is verbatim everywhere', () {
        expect(DOMAttribute.isBooleanAttribute(name), isFalse);

        final attr = DOMAttribute.from(name, value)!;
        expect(attr.isBoolean, isFalse);
        expect(attr.value, equals(value));
        expect(attr.buildHTML(), equals('$name="$value"'));

        final e = _parse('<div $name="$value">x</div>');
        expect(e.getAttributeValue(name), equals(value));
        expect(e.buildHTML(), equals('<div $name="$value">x</div>'));

        for (final b in [false, true]) {
          expect(
            _resolve(e, name, booleanDefault: b, valueDefault: '-'),
            equals(value),
          );
        }

        final built = e.buildDOM(generator: TestGenerator()) as TestElem;
        expect(built.attributes, equals({name: value}));

        final fromTag = $tag('div', attributes: {name: value});
        expect(fromTag.buildHTML(), equals('<div $name="$value"></div>'));
      });
    }

    test('Dart bools are kept as "true"/"false" strings', () {
      final e = $tag(
        'div',
        attributes: {
          'contenteditable': false,
          'draggable': true,
          'aria-hidden': false,
          'data-flag': false,
        },
      );
      expect(
        e.buildHTML(),
        equals(
          '<div contenteditable="false" draggable="true" '
          'aria-hidden="false" data-flag="false"></div>',
        ),
      );
    });

    test('valueless: an empty value, not "true"', () {
      final e = _parse('<div contenteditable draggable>x</div>');
      expect(e.getAttributeValue('contenteditable'), equals(''));
      expect(e.getAttributeValue('draggable'), equals(''));
      expect(
        e.buildHTML(),
        equals('<div contenteditable="" draggable="">x</div>'),
      );
    });
  });

  group('round trips: parse -> buildHTML -> parse', () {
    Map<String, String?> attrs(DOMElement e) => {
      for (final n in e.attributesNames) n: e.getAttributeValue(n),
    };

    const htmls = [
      '<input type="checkbox" checked="checked" value="" data-x '
          'autocomplete="off" spellcheck="false">',
      '<input type="checkbox" checked="false" disabled="no" hidden="0">',
      '<div id="" title="" data-a="" data-b="false" aria-hidden="false" '
          'contenteditable="false" translate="no">x</div>',
      '<select multiple="multiple"><option value="" selected="">-</option>'
          '<option value="a" selected="off">A</option></select>',
      '<video autoplay="AUTOPLAY" controls muted="false" '
          'src="v.mp4"></video>',
      '<div class="a  b" style="color: red;" inert="">x</div>',
      '<div title=\'say "hi"\' data-q="it\'s">x</div>',
    ];

    for (final html in htmls) {
      test(html, () {
        final first = _parse(html);
        final html1 = first.buildHTML();
        final second = _parse(html1);
        final html2 = second.buildHTML();

        expect(html2, equals(html1));

        // The built (true/non-false) attributes survive with their values;
        // false boolean attributes are dropped by the first build.
        final kept = Map.of(attrs(first))
          ..removeWhere(
            (n, v) => first.getAttribute(n)!.isBoolean && v == 'false',
          );
        expect(attrs(second), equals(kept));
      });
    }

    test('boolean values are normalized to bare names', () {
      final e = _parse(
        '<input checked="CHECKED" disabled="yes" hidden="1" '
        'inert="TRUE" selected="">',
      );
      expect(
        e.buildHTML(),
        equals('<input checked disabled hidden inert selected>'),
      );
    });

    test('a template-generated select survives the round trip', () {
      final template = DOMTemplate.tryParse(
        '<select>'
        '<option value="pt" selected="{{:l==\'pt\'}}selected{{?}}false{{/}}">'
        'PT</option>'
        '<option value="en" selected="{{:l==\'en\'}}selected{{?}}false{{/}}">'
        'EN</option>'
        '</select>',
      )!;

      final select = _parse(template.buildAsString({'l': 'en'}));
      expect(
        select.buildHTML(),
        equals(
          '<select><option value="pt">PT</option>'
          '<option value="en" selected>EN</option></select>',
        ),
      );
      final again = _parse(select.buildHTML());
      final options = again.nodes.whereType<DOMElement>().toList();
      expect(
        options.map((o) => o.getAttributeValueAsBool('selected')).toList(),
        equals([false, true]),
      );
    });
  });
}
