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

/// A [TestGenerator] that records the values given to
/// [setResolvedAttribute] (by [setAttributes]).
class _RecordingGenerator extends TestGenerator {
  final List<(String, String?, bool, String?)> resolved = [];

  @override
  void setResolvedAttribute(
    TestNode element,
    String attrName,
    String? attrVal, {
    required bool booleanDefault,
    required String? valueDefault,
  }) {
    resolved.add((attrName, attrVal, booleanDefault, valueDefault));
    super.setResolvedAttribute(
      element,
      attrName,
      attrVal,
      booleanDefault: booleanDefault,
      valueDefault: valueDefault,
    );
  }
}

void main() {
  group('boolean attributes: DOMAttribute', () {
    for (final name in _booleanAttributes) {
      test('$name is boolean', () {
        expect(DOMAttribute.isBooleanAttribute(name), isTrue);

        final on = DOMAttribute.from(name, 'true')!;
        expect(on.isBoolean, isTrue);
        expect(on.value, equals('true'));
        expect(on.hasValue, isTrue);

        final off = DOMAttribute.from(name, 'false')!;
        expect(off.isBoolean, isTrue);
        expect(off.value, equals('false'));
        expect(off.hasValue, isFalse);
      });
    }

    test('other attributes are not boolean', () {
      for (final name in ['title', 'value', 'readonly-x', 'data-checked']) {
        expect(DOMAttribute.isBooleanAttribute(name), isFalse, reason: name);
      }
    });
  });

  group('boolean attributes: parsed HTML', () {
    for (final name in _booleanAttributes) {
      test('$name: "true", bare and "false"', () {
        DOMElement parse(String attr) =>
            DOMNode.parseNodes('<div $attr>x</div>').first as DOMElement;

        final on = parse('$name="true"');
        expect(on.getAttributeValueAsBool(name), isTrue);
        expect(on.buildHTML(), contains(' $name'));

        final bare = parse(name);
        expect(bare.getAttributeValueAsBool(name), isTrue);
        expect(bare.buildHTML(), contains(' $name'));

        final off = parse('$name="false"');
        expect(off.getAttributeValueAsBool(name), isFalse);
        // A false boolean attribute is left out of the HTML:
        expect(off.buildHTML(), isNot(contains(name)));
      });
    }

    test('a select with false and true options', () {
      final select =
          DOMNode.parseNodes(
                '<select>'
                '<option value="a" selected="false">A</option>'
                '<option value="b" selected="true">B</option>'
                '</select>',
              ).first
              as DOMElement;

      final options = select.nodes.whereType<DOMElement>().toList();
      expect(
        options.map((o) => o.getAttributeValueAsBool('selected')).toList(),
        equals([false, true]),
      );
      expect(
        select.buildHTML(),
        equals(
          '<select><option value="a">A</option>'
          '<option value="b" selected>B</option></select>',
        ),
      );
    });

    test('a template resolving a boolean attribute', () {
      final template = DOMTemplate.tryParse(
        '<option value="pt" selected="{{:lang==\'pt\'}}true{{?}}false{{/}}">'
        'PT</option>',
      )!;

      String build(String lang) => template.buildAsString({'lang': lang});

      expect(build('pt'), contains('selected="true"'));
      expect(build('en'), contains('selected="false"'));

      final on = DOMNode.parseNodes(build('pt')).first as DOMElement;
      final off = DOMNode.parseNodes(build('en')).first as DOMElement;
      expect(on.getAttributeValueAsBool('selected'), isTrue);
      expect(off.getAttributeValueAsBool('selected'), isFalse);
    });
  });

  group('boolean attributes: resolveAttributeValue', () {
    final generator = TestGenerator();
    final treeMap = generator.createDOMTreeMap();

    String? resolve(
      String html,
      String name, {
      bool booleanDefault = false,
      String? valueDefault,
    }) {
      final domElement = DOMNode.parseNodes(html).first as DOMElement;
      return generator.resolveAttributeValue(
        domElement,
        TestElem(domElement.tag),
        name,
        treeMap,
        booleanDefault: booleanDefault,
        valueDefault: valueDefault,
      );
    }

    String? resolveNode(
      DOMElement domElement,
      String name, {
      required bool booleanDefault,
      required String? valueDefault,
    }) => generator.resolveAttributeValue(
      domElement,
      TestElem(domElement.tag),
      name,
      treeMap,
      booleanDefault: booleanDefault,
      valueDefault: valueDefault,
    );

    for (final name in _booleanAttributes) {
      test('$name: "true" -> "true", "false" -> null', () {
        expect(resolve('<div $name="true">x</div>', name), equals('true'));
        expect(resolve('<div $name>x</div>', name), equals('true'));
        // `null`: no attribute.
        expect(resolve('<div $name="false">x</div>', name), isNull);
      });
    }

    test('other attributes keep their value', () {
      expect(resolve('<div title="false">x</div>', 'title'), equals('false'));
      expect(resolve('<div data-x="false">x</div>', 'data-x'), equals('false'));
    });

    test('a false boolean is off, whatever booleanDefault', () {
      for (final b in [false, true]) {
        expect(
          resolve('<div hidden="false">x</div>', 'hidden', booleanDefault: b),
          isNull,
          reason: 'booleanDefault: $b',
        );
      }
    });

    test('a value attribute without a value: valueDefault', () {
      final div = $div(attributes: {'title': 'x'});
      div.getAttribute('title')!.setValue(null);

      expect(
        resolveNode(div, 'title', booleanDefault: false, valueDefault: null),
        isNull,
      );
      expect(
        resolveNode(div, 'title', booleanDefault: false, valueDefault: '-'),
        equals('-'),
      );
      // A value is kept:
      expect(
        resolve('<div title="t">x</div>', 'title', valueDefault: '-'),
        equals('t'),
      );
    });
  });

  group('DOMGenerator.applyAttributeDefaults', () {
    String? apply(String name, String? value, bool b, String? v) =>
        DOMGenerator.applyAttributeDefaults(
          name,
          value,
          booleanDefault: b,
          valueDefault: v,
        );

    test('a value is kept', () {
      expect(apply('title', 'x', false, '-'), equals('x'));
      expect(apply('checked', 'true', false, null), equals('true'));
    });

    for (final name in _booleanAttributes) {
      test('$name: null is booleanDefault', () {
        expect(apply(name, null, true, null), equals('true'));
        expect(apply(name, null, false, null), isNull);
        // `valueDefault` is not for boolean attributes:
        expect(apply(name, null, false, 'x'), isNull);
      });
    }

    test('other attributes: null is valueDefault', () {
      expect(apply('title', null, false, null), isNull);
      expect(apply('title', null, true, null), isNull);
      expect(apply('title', null, false, '-'), equals('-'));
    });
  });

  group('boolean attributes: setAttributes -> setResolvedAttribute', () {
    test('every resolved value goes through setResolvedAttribute', () {
      final generator = _RecordingGenerator();

      final div =
          DOMNode.parseNodes(
                '<div hidden="false" title="t">'
                '<input type="checkbox" checked="true">'
                '<select multiple="false">'
                '<option value="a" selected="false">A</option>'
                '<option value="b" selected>B</option>'
                '</select>'
                '</div>',
              ).first
              as DOMElement;

      div.buildDOM(generator: generator);

      final byName = <String, List<String?>>{};
      for (final (name, value, booleanDefault, valueDefault)
          in generator.resolved) {
        // `setAttributes`' defaults: off, and no attribute.
        expect(booleanDefault, isFalse, reason: name);
        expect(valueDefault, isNull, reason: name);
        byName.putIfAbsent(name, () => []).add(value);
      }

      expect(byName['hidden'], equals([null]));
      expect(byName['title'], equals(['t']));
      expect(byName['checked'], equals(['true']));
      expect(byName['multiple'], equals([null]));
      expect(byName['selected'], equals([null, 'true']));
    });

    test('DOMGeneratorDelegate forwards it, with both defaults', () {
      final target = _RecordingGenerator();
      final delegate = DOMGeneratorDelegate<TestNode>(target);
      final elem = TestElem('option');

      void set(String name, String? value, bool b, String? v) =>
          delegate.setResolvedAttribute(
            elem,
            name,
            value,
            booleanDefault: b,
            valueDefault: v,
          );

      set('selected', null, false, null);
      set('selected', null, true, null);
      set('title', null, false, '-');

      expect(
        target.resolved,
        equals([
          ('selected', null, false, null),
          ('selected', null, true, null),
          ('title', null, false, '-'),
        ]),
      );
      expect(elem.attributes, equals({'selected': 'true', 'title': '-'}));
    });

    test('DOMGeneratorDummy ignores it', () {
      final dummy = DOMGeneratorDummy<TestNode>();
      final elem = TestElem('option');
      dummy.setResolvedAttribute(
        elem,
        'selected',
        'true',
        booleanDefault: true,
        valueDefault: '-',
      );
      expect(elem.attributes, isEmpty);
    });

    test('TestGenerator: null is the defaults', () {
      final generator = TestGenerator();
      final elem = TestElem('input')..attributes['title'] = 'old';

      void set(String name, String? value, bool b, String? v) =>
          generator.setResolvedAttribute(
            elem,
            name,
            value,
            booleanDefault: b,
            valueDefault: v,
          );

      set('checked', null, true, null);
      expect(elem.attributes['checked'], equals('true'));
      set('checked', null, false, null);
      expect(elem.attributes.containsKey('checked'), isFalse);

      set('title', null, false, '-');
      expect(elem.attributes['title'], equals('-'));
      set('title', null, false, null);
      expect(elem.attributes.containsKey('title'), isFalse);
    });
  });
}
