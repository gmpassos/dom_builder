@TestOn('browser')
library;

import 'package:dom_builder/dom_builder_web.dart';
import 'package:test/test.dart';
import 'package:web_utils/web_utils.dart' hide EventType;

/// Integration tests (real DOM) for the boolean attributes: a `"true"` or bare
/// one is on, a `"false"` one is off, from every source (parsed HTML, `$tag`
/// attributes, templates, `setAttribute` and `setResolvedAttribute`).

DOMGeneratorWeb<Node> get _gen => DOMGenerator.web<Node>();

/// A root `div` attached to `document.body`, removed after the test.
HTMLDivElement _root() {
  final root = HTMLDivElement();
  document.body!.appendChild(root);
  addTearDown(() => root.remove());
  return root;
}

/// Generates [domNode] into a new attached root.
Element _generate(DOMNode domNode) {
  final treeMap = _gen.createDOMTreeMap();
  return _gen.generate(domNode, treeMap: treeMap, parent: _root()) as Element;
}

/// Generates [html] (one element) into a new attached root.
Element _generateHTML(String html) => _generate(DOMNode.parseNodes(html).first);

/// A boolean attribute, the element it applies to, and how to read it.
typedef _Case = ({
  String name,
  String tag,
  String extra,
  bool Function(Element e) read,
});

final List<_Case> _cases = [
  (
    name: 'checked',
    tag: 'input',
    extra: 'type="checkbox"',
    read: (e) => (e as HTMLInputElement).checked,
  ),
  (
    name: 'disabled',
    tag: 'button',
    extra: '',
    read: (e) => (e as HTMLButtonElement).disabled,
  ),
  (
    name: 'hidden',
    tag: 'div',
    extra: '',
    read: (e) => (e as HTMLElement).hidden.dartify() == true,
  ),
  (name: 'inert', tag: 'div', extra: '', read: (e) => (e as HTMLElement).inert),
  (
    name: 'multiple',
    tag: 'select',
    extra: '',
    read: (e) => (e as HTMLSelectElement).multiple,
  ),
  (
    name: 'multiple',
    tag: 'input',
    extra: 'type="file"',
    read: (e) => (e as HTMLInputElement).multiple,
  ),
  (
    name: 'autoplay',
    tag: 'video',
    extra: '',
    read: (e) => (e as HTMLMediaElement).autoplay,
  ),
  (
    name: 'controls',
    tag: 'video',
    extra: '',
    read: (e) => (e as HTMLMediaElement).controls,
  ),
  (
    name: 'muted',
    tag: 'video',
    extra: '',
    read: (e) => (e as HTMLMediaElement).defaultMuted,
  ),
];

/// [DOMGenerator.setResolvedAttribute] as `setAttributes` calls it: a `null`
/// boolean is off, any other `null` is removed (`booleanDefault: false`,
/// `valueDefault: null`).
void _setResolved(Node element, String attrName, String? attrVal) =>
    _gen.setResolvedAttribute(
      element,
      attrName,
      attrVal,
      booleanDefault: false,
      valueDefault: null,
    );

/// The value of the `selected` options of [select].
List<String> _selectedValues(HTMLSelectElement select) => [
  for (var i = 0; i < select.options.length; i++)
    if ((select.options.item(i)! as HTMLOptionElement).selected)
      (select.options.item(i)! as HTMLOptionElement).value,
];

void main() {
  group('boolean attributes from parsed HTML', () {
    for (final c in _cases) {
      group('<${c.tag}> ${c.name}', () {
        Element generate(String attr) =>
            _generateHTML('<${c.tag} ${c.extra} $attr></${c.tag}>');

        test('"true" is on', () {
          expect(c.read(generate('${c.name}="true"')), isTrue);
        });

        test('bare is on', () {
          expect(c.read(generate(c.name)), isTrue);
        });

        test('"false" is off, without the attribute', () {
          final e = generate('${c.name}="false"');
          expect(c.read(e), isFalse);
          expect(e.hasAttribute(c.name), isFalse);
        });

        test('absent is off', () {
          expect(c.read(generate('')), isFalse);
        });
      });
    }
  });

  group(r'boolean attributes from $tag attributes', () {
    for (final c in _cases) {
      test('<${c.tag}> ${c.name}: "true" on, "false" off', () {
        Map<String, String> extra() => {
          for (final m in RegExp(r'(\w+)="([^"]*)"').allMatches(c.extra))
            m.group(1)!: m.group(2)!,
        };

        final on = _generate(
          $tag(c.tag, attributes: {...extra(), c.name: 'true'}),
        );
        final off = _generate(
          $tag(c.tag, attributes: {...extra(), c.name: 'false'}),
        );

        expect(c.read(on), isTrue);
        expect(c.read(off), isFalse);
      });
    }
  });

  group('selected options', () {
    test('only the "true" one, from parsed HTML', () {
      final select = _generateHTML(
        '<select>'
        '<option value="a" selected="false">A</option>'
        '<option value="b" selected="true">B</option>'
        '<option value="c" selected="false">C</option>'
        '</select>',
      ) as HTMLSelectElement;

      expect(select.value, equals('b'));
      expect(_selectedValues(select), equals(['b']));
    });

    test('a bare one', () {
      final select = _generateHTML(
        '<select>'
        '<option value="a">A</option>'
        '<option value="b" selected>B</option>'
        '<option value="c">C</option>'
        '</select>',
      ) as HTMLSelectElement;

      expect(select.value, equals('b'));
    });

    test('none: the first one shows', () {
      final select = _generateHTML(
        '<select>'
        '<option value="a" selected="false">A</option>'
        '<option value="b" selected="false">B</option>'
        '</select>',
      ) as HTMLSelectElement;

      expect(select.value, equals('a'));
    });

    test(r'from $select / $option', () {
      final select = _generate(
        $select(
          options: [
            $option(value: 'a', text: 'A', selected: false),
            $option(value: 'b', text: 'B', selected: true),
            $option(value: 'c', text: 'C', selected: false),
          ],
        ),
      ) as HTMLSelectElement;

      expect(select.value, equals('b'));
      expect(_selectedValues(select), equals(['b']));
    });

    test('a multiple select with several', () {
      final select = _generateHTML(
        '<select multiple="true">'
        '<option value="a" selected="true">A</option>'
        '<option value="b" selected="false">B</option>'
        '<option value="c" selected>C</option>'
        '</select>',
      ) as HTMLSelectElement;

      expect(select.multiple, isTrue);
      expect(_selectedValues(select), equals(['a', 'c']));
    });

    // The case that found the bug: a language select whose options are
    // marked by a template condition (`selected="{{:lang=='pt'}}true...`).
    for (final lang in ['en', 'pt', 'ga']) {
      test('from a template, current "$lang"', () {
        final template = DOMTemplate.tryParse(
          '<select>'
          '${[
            for (final l in ['en', 'pt', 'es', 'ga']) '<option value="$l" selected="{{:lang==\'$l\'}}true{{?}}false{{/}}">$l</option>',
          ].join()}'
          '</select>',
        )!;
        final select = _generateHTML(
          template.buildAsString({'lang': lang}),
        ) as HTMLSelectElement;

        expect(select.value, equals(lang));
        expect(_selectedValues(select), equals([lang]));
      });
    }
  });

  group('setAttribute: `null` is a bare attribute', () {
    test('selected, multiple, hidden, inert', () {
      final option = HTMLOptionElement();
      _gen.setAttribute(option, 'selected', null);
      expect(option.selected, isTrue);

      final select = HTMLSelectElement();
      _gen.setAttribute(select, 'multiple', null);
      expect(select.multiple, isTrue);

      final div = HTMLDivElement();
      _gen.setAttribute(div, 'hidden', null);
      expect(div.hidden.dartify(), isTrue);
      _gen.setAttribute(div, 'inert', null);
      expect(div.inert, isTrue);
    });

    test('"true" / "false" values', () {
      final option = HTMLOptionElement();
      _gen.setAttribute(option, 'selected', 'true');
      expect(option.selected, isTrue);
      _gen.setAttribute(option, 'selected', 'false');
      expect(option.selected, isFalse);

      final div = HTMLDivElement();
      _gen.setAttribute(div, 'hidden', 'true');
      expect(div.hidden.dartify(), isTrue);
      _gen.setAttribute(div, 'hidden', 'false');
      expect(div.hidden.dartify(), isNot(isTrue));
    });

    test('a null `selected`/`multiple` without the property removes it', () {
      final div = HTMLDivElement()
        ..setAttribute('selected', 'x')
        ..setAttribute('multiple', 'x');
      _setResolved(div, 'selected', null);
      _setResolved(div, 'multiple', null);
      expect(div.hasAttribute('selected'), isFalse);
      expect(div.hasAttribute('multiple'), isFalse);
    });
  });

  group('setResolvedAttribute: `null` is the booleanDefault', () {
    test('turns on and off an existing element', () {
      final option = HTMLOptionElement();
      final select = HTMLSelectElement();
      final div = HTMLDivElement();

      _setResolved(option, 'selected', 'true');
      _setResolved(select, 'multiple', 'true');
      _setResolved(div, 'hidden', 'true');
      _setResolved(div, 'inert', 'true');
      expect(option.selected, isTrue);
      expect(select.multiple, isTrue);
      expect(div.hidden.dartify(), isTrue);
      expect(div.inert, isTrue);

      _setResolved(option, 'selected', null);
      _setResolved(select, 'multiple', null);
      _setResolved(div, 'hidden', null);
      _setResolved(div, 'inert', null);
      expect(option.selected, isFalse);
      expect(select.multiple, isFalse);
      expect(div.hidden.dartify(), isNot(isTrue));
      expect(div.inert, isFalse);
    });

    test('booleanDefault: true turns every boolean on', () {
      void setOn(Node element, String attrName) => _gen.setResolvedAttribute(
        element,
        attrName,
        null,
        booleanDefault: true,
        valueDefault: null,
      );

      final option = HTMLOptionElement();
      final div = HTMLDivElement();
      final checkbox = HTMLInputElement()..type = 'checkbox';
      final button = HTMLButtonElement();

      setOn(option, 'selected');
      setOn(div, 'hidden');
      // Booleans that are not set as properties too:
      setOn(checkbox, 'checked');
      setOn(button, 'disabled');

      expect(option.selected, isTrue);
      expect(div.hidden.dartify(), isTrue);
      expect(checkbox.checked, isTrue);
      expect(button.disabled, isTrue);
    });

    test('valueDefault for a value attribute without a value', () {
      final div = HTMLDivElement()..title = 'old';

      _gen.setResolvedAttribute(
        div,
        'title',
        null,
        booleanDefault: false,
        valueDefault: '-',
      );
      expect(div.title, equals('-'));

      // `valueDefault` is not for boolean attributes:
      final checkbox = HTMLInputElement()..type = 'checkbox';
      _gen.setResolvedAttribute(
        checkbox,
        'checked',
        null,
        booleanDefault: false,
        valueDefault: '-',
      );
      expect(checkbox.checked, isFalse);
      expect(checkbox.hasAttribute('checked'), isFalse);
    });

    test('other attributes: `null` removes them', () {
      final input = HTMLInputElement()..setAttribute('checked', '');
      _setResolved(input, 'checked', null);
      expect(input.hasAttribute('checked'), isFalse);

      final div = HTMLDivElement();
      _setResolved(div, 'title', 't');
      expect(div.title, equals('t'));
      _setResolved(div, 'title', null);
      expect(div.hasAttribute('title'), isFalse);
    });

    test('setElementAttribute: `null` is a bare attribute by default', () {
      final gen = DOMGeneratorWebImpl();
      final option = HTMLOptionElement();
      gen.setElementAttribute(option, 'selected', null);
      expect(option.selected, isTrue);

      gen.setElementAttribute(option, 'selected', null, booleanDefault: false);
      expect(option.selected, isFalse);
    });
  });

  group('checked: the value forms', () {
    bool checkedOf(String attr) => (_generateHTML(
      '<input type="checkbox" $attr>',
    ) as HTMLInputElement).checked;

    for (final attr in [
      'checked',
      'checked=""',
      'checked="true"',
      'checked="on"',
      'checked="yes"',
      'checked="1"',
    ]) {
      test('$attr: checked', () => expect(checkedOf(attr), isTrue));
    }

    for (final attr in [
      'checked="false"',
      'checked="off"',
      'checked="no"',
      'checked="0"',
      '',
    ]) {
      test('${attr.isEmpty ? 'absent' : attr}: not checked', () {
        expect(checkedOf(attr), isFalse);
      });
    }

    test('checked="checked": checked (XHTML form)', () {
      expect(checkedOf('checked="checked"'), isTrue);

      final option = _generateHTML(
        '<select><option value="a">A</option>'
        '<option value="b" selected="selected">B</option></select>',
      ) as HTMLSelectElement;
      expect(option.value, equals('b'));

      final button = _generateHTML(
        '<button disabled="disabled">x</button>',
      ) as HTMLButtonElement;
      expect(button.disabled, isTrue);
    });
  });

  // "off"/"false" are values of these attributes, kept verbatim: dropping
  // `spellcheck="false"` would turn spellcheck back on, dropping
  // `autocomplete="off"` would turn autofill back on.
  group('on/off and true/false values of non-boolean attributes', () {
    test('autocomplete', () {
      final off =
          _generateHTML('<input autocomplete="off">') as HTMLInputElement;
      final on = _generateHTML('<input autocomplete="on">') as HTMLInputElement;
      expect(off.autocomplete, equals('off'));
      expect(off.getAttribute('autocomplete'), equals('off'));
      expect(on.autocomplete, equals('on'));

      final form = _generateHTML('<form autocomplete="off"></form>');
      expect(form.getAttribute('autocomplete'), equals('off'));
    });

    test('spellcheck', () {
      final off = _generateHTML(
        '<textarea spellcheck="false"></textarea>',
      ) as HTMLTextAreaElement;
      final on = _generateHTML(
        '<textarea spellcheck="true"></textarea>',
      ) as HTMLTextAreaElement;
      expect(off.spellcheck, isFalse);
      expect(off.getAttribute('spellcheck'), equals('false'));
      expect(on.spellcheck, isTrue);
    });

    test('value', () {
      final input = _generateHTML('<input value="off">') as HTMLInputElement;
      expect(input.value, equals('off'));

      final select = _generateHTML(
        '<select><option value="on">On</option>'
        '<option value="false" selected>No</option></select>',
      ) as HTMLSelectElement;
      expect(select.value, equals('false'));

      final built = _generate($input(value: 'off')) as HTMLInputElement;
      expect(built.value, equals('off'));
    });

    test('data-*', () {
      final e = _generateHTML(
        '<div data-x="off" data-flag="false" data-on="true">x</div>',
      );
      expect(e.getAttribute('data-x'), equals('off'));
      expect(e.getAttribute('data-flag'), equals('false'));
      expect(e.getAttribute('data-on'), equals('true'));
      expect(e.matches('[data-flag="false"]'), isTrue);
    });

    test(r'from $tag attributes', () {
      final input = _generate(
        $tag(
          'input',
          attributes: {
            'autocomplete': 'off',
            'spellcheck': 'false',
            'value': 'off',
            'data-flag': 'false',
          },
        ),
      ) as HTMLInputElement;

      expect(input.autocomplete, equals('off'));
      expect(input.spellcheck, isFalse);
      expect(input.value, equals('off'));
      expect(input.getAttribute('data-flag'), equals('false'));
    });

    test('setResolvedAttribute keeps them; null is valueDefault', () {
      final input = HTMLInputElement();
      void set(String name, String? value, {String? valueDefault}) =>
          _gen.setResolvedAttribute(
            input,
            name,
            value,
            booleanDefault: true,
            valueDefault: valueDefault,
          );

      set('autocomplete', 'off');
      set('spellcheck', 'false');
      expect(input.autocomplete, equals('off'));
      expect(input.spellcheck, isFalse);

      // `booleanDefault` doesn't apply to them:
      set('data-x', null);
      expect(input.hasAttribute('data-x'), isFalse);
      set('data-x', null, valueDefault: 'off');
      expect(input.getAttribute('data-x'), equals('off'));
    });

    test('an empty value is kept (`data-x=""`, `value=""`)', () {
      final e = _generateHTML('<div data-x="" data-y>x</div>');
      expect(e.getAttribute('data-x'), equals(''));
      expect(e.matches('[data-x]'), isTrue);
      expect(e.getAttribute('data-y'), equals(''));

      final input =
          _generateHTML('<input value="" placeholder="">') as HTMLInputElement;
      expect(input.hasAttribute('value'), isTrue);
      expect(input.value, isEmpty);
      expect(input.getAttribute('placeholder'), equals(''));
    });
  });
}
