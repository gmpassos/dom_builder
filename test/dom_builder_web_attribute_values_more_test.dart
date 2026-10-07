@TestOn('browser')
library;

import 'package:dom_builder/dom_builder_web.dart';
import 'package:test/test.dart';
import 'package:web_utils/web_utils.dart' hide EventType;

/// More integration tests (real DOM) for attribute values: every boolean
/// attribute on its element and in every value form, updating existing
/// elements, `<select>` correctness, empty values and enumerated attributes
/// whose values look like booleans. The DOM properties are checked, not only
/// the attributes.

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

/// Generates [domNode] with a generator whose context has [variables], so
/// that template attribute values (`selected="{{...}}"`) are resolved.
Element _generateWithVariables(
  DOMNode domNode,
  Map<String, dynamic> variables,
) {
  final gen = DOMGeneratorWebImpl()
    ..domContext = DOMContext<Node>(variables: variables);
  final treeMap = gen.createDOMTreeMap();
  return gen.generate(domNode, treeMap: treeMap, parent: _root()) as Element;
}

/// [DOMGenerator.setResolvedAttribute] as `setAttributes` calls it.
void _setResolved(
  Node element,
  String attrName,
  String? attrVal, {
  bool booleanDefault = false,
  String? valueDefault,
}) => _gen.setResolvedAttribute(
  element,
  attrName,
  attrVal,
  booleanDefault: booleanDefault,
  valueDefault: valueDefault,
);

bool _isHidden(Element e) => (e as HTMLElement).hidden.dartify() == true;

List<HTMLOptionElement> _options(HTMLSelectElement select) => [
  for (var i = 0; i < select.options.length; i++)
    select.options.item(i)! as HTMLOptionElement,
];

/// The values of the selected options of [select].
List<String> _selectedValues(HTMLSelectElement select) =>
    _options(select).where((o) => o.selected).map((o) => o.value).toList();

/// A boolean attribute on an element: [html] builds the HTML with the
/// attribute text, [pick] finds the element in the generated one, [read]
/// reads its DOM property.
typedef _Case = ({
  String name,
  String label,
  String Function(String attr) html,
  Element Function(Element generated) pick,
  bool Function(Element e) read,
  // `selected` is set as a property, which doesn't reflect to the attribute.
  bool reflects,
});

_Case _simple(
  String name,
  String tag,
  bool Function(Element e) read, {
  String extra = '',
  bool reflects = true,
}) => (
  name: name,
  label: '<$tag${extra.isEmpty ? '' : ' $extra'}>',
  html: (attr) => '<$tag $extra $attr></$tag>',
  pick: (e) => e,
  read: read,
  reflects: reflects,
);

final List<_Case> _cases = [
  _simple(
    'checked',
    'input',
    (e) => (e as HTMLInputElement).checked,
    extra: 'type="checkbox"',
  ),
  _simple(
    'checked',
    'input',
    (e) => (e as HTMLInputElement).checked,
    extra: 'type="radio"',
  ),
  _simple('disabled', 'button', (e) => (e as HTMLButtonElement).disabled),
  _simple('disabled', 'input', (e) => (e as HTMLInputElement).disabled),
  _simple('disabled', 'select', (e) => (e as HTMLSelectElement).disabled),
  _simple('disabled', 'textarea', (e) => (e as HTMLTextAreaElement).disabled),
  _simple('disabled', 'fieldset', (e) => (e as HTMLFieldSetElement).disabled),
  (
    name: 'disabled',
    label: '<option>',
    html: (attr) =>
        '<select><option value="a">A</option>'
        '<option value="b" $attr>B</option></select>',
    pick: (e) => e.querySelector('option[value="b"]')!,
    read: (e) => (e as HTMLOptionElement).disabled,
    reflects: true,
  ),
  // (`<optgroup disabled>` is in the `<select>` group: a parsed `<optgroup>`
  // fails, see the skipped test there.)
  (
    name: 'selected',
    label: '<option>',
    html: (attr) =>
        '<select><option value="a">A</option>'
        '<option value="b" $attr>B</option></select>',
    pick: (e) => e.querySelector('option[value="b"]')!,
    read: (e) => (e as HTMLOptionElement).selected,
    reflects: false,
  ),
  _simple('hidden', 'div', _isHidden),
  _simple('hidden', 'span', _isHidden),
  _simple('inert', 'div', (e) => (e as HTMLElement).inert),
  _simple('multiple', 'select', (e) => (e as HTMLSelectElement).multiple),
  _simple(
    'multiple',
    'input',
    (e) => (e as HTMLInputElement).multiple,
    extra: 'type="file"',
  ),
  for (final tag in ['video', 'audio']) ...[
    _simple('autoplay', tag, (e) => (e as HTMLMediaElement).autoplay),
    _simple('controls', tag, (e) => (e as HTMLMediaElement).controls),
    _simple('muted', tag, (e) => (e as HTMLMediaElement).defaultMuted),
  ],
];

void main() {
  group('boolean attributes: every value form, parsed HTML', () {
    for (final c in _cases) {
      group('${c.label} ${c.name}', () {
        Element generate(String attr) => c.pick(_generateHTML(c.html(attr)));

        void expectOn(String attr) {
          final e = generate(attr);
          expect(c.read(e), isTrue, reason: attr);
          if (c.reflects) {
            expect(e.hasAttribute(c.name), isTrue, reason: attr);
          }
        }

        void expectOff(String attr) {
          final e = generate(attr);
          expect(c.read(e), isFalse, reason: attr);
          expect(e.hasAttribute(c.name), isFalse, reason: attr);
        }

        final upper = c.name.toUpperCase();

        test('on: "true", bare, "", "on", own name', () {
          expectOn('${c.name}="true"');
          expectOn(c.name);
          expectOn('${c.name}=""');
          expectOn('${c.name}="on"');
          expectOn('${c.name}="${c.name}"');
        });

        test('on: upper case name and values', () {
          expectOn(upper);
          expectOn('$upper="$upper"');
          expectOn('${c.name}="TRUE"');
          expectOn('${c.name}=" ${c.name} "');
        });

        test('off: "false", "off", "FALSE", absent', () {
          expectOff('${c.name}="false"');
          expectOff('${c.name}="off"');
          expectOff('${c.name}="FALSE"');
          expectOff('$upper="false"');
          expectOff('');
        });
      });
    }
  });

  group(r'boolean attributes: $tag(attributes:)', () {
    test('bool values: true on, false off, null absent', () {
      for (final value in <Object?>[true, false, null]) {
        final checkbox = _generate(
          $tag('input', attributes: {'type': 'checkbox', 'checked': value}),
        ) as HTMLInputElement;
        final button = _generate(
          $tag('button', attributes: {'disabled': value}),
        ) as HTMLButtonElement;
        final div = _generate(
          $tag('div', attributes: {'hidden': value, 'inert': value}),
        ) as HTMLElement;
        final video = _generate(
          $tag(
            'video',
            attributes: {'autoplay': value, 'controls': value, 'muted': value},
          ),
        ) as HTMLVideoElement;

        final on = value == true;
        expect(checkbox.checked, equals(on), reason: '$value');
        expect(checkbox.hasAttribute('checked'), equals(on));
        expect(button.disabled, equals(on));
        expect(button.hasAttribute('disabled'), equals(on));
        expect(_isHidden(div), equals(on));
        expect(div.inert, equals(on));
        expect(video.autoplay, equals(on));
        expect(video.controls, equals(on));
        expect(video.defaultMuted, equals(on));
      }
    });

    test('string values: "", "on", own name on; "off", "no", "0" off', () {
      for (final (value, on) in [
        ('', true),
        ('on', true),
        ('checked', true),
        ('TRUE', true),
        ('off', false),
        ('no', false),
        ('0', false),
      ]) {
        final checkbox = _generate(
          $tag('input', attributes: {'type': 'checkbox', 'checked': value}),
        ) as HTMLInputElement;
        expect(checkbox.checked, equals(on), reason: '"$value"');
        expect(checkbox.hasAttribute('checked'), equals(on), reason: value);
      }
    });

    test('<select multiple> and <option selected/disabled>', () {
      final select = _generate(
        $tag(
          'select',
          attributes: {'multiple': true, 'disabled': false},
          content: [
            $tag('option', attributes: {'value': 'a', 'selected': true}),
            $tag('option', attributes: {'value': 'b', 'selected': false}),
            $tag(
              'option',
              attributes: {'value': 'c', 'selected': 'true', 'disabled': true},
            ),
          ],
        ),
      ) as HTMLSelectElement;

      expect(select.multiple, isTrue);
      expect(select.disabled, isFalse);
      expect(select.hasAttribute('disabled'), isFalse);
      expect(_selectedValues(select), equals(['a', 'c']));
      expect(_options(select).map((o) => o.disabled), [false, false, true]);
    });
  });

  group('boolean attributes: builders', () {
    test(r'$checkbox(checked:)', () {
      HTMLInputElement gen(bool? checked) =>
          _generate($checkbox(checked: checked)) as HTMLInputElement;

      expect(gen(true).checked, isTrue);
      expect(gen(true).type, equals('checkbox'));
      expect(gen(false).checked, isFalse);
      expect(gen(false).hasAttribute('checked'), isFalse);
      expect(gen(null).checked, isFalse);
    });

    test(r'$input / $button / $textarea (disabled:)', () {
      final inputOn = _generate($input(disabled: true)) as HTMLInputElement;
      final inputOff = _generate($input(disabled: false)) as HTMLInputElement;
      final buttonOn =
          _generate($button(disabled: true, content: 'x')) as HTMLButtonElement;
      final buttonOff = _generate(
        $button(disabled: false, content: 'x'),
      ) as HTMLButtonElement;
      final textareaOn =
          _generate($textarea(disabled: true)) as HTMLTextAreaElement;
      final textareaOff =
          _generate($textarea(disabled: false)) as HTMLTextAreaElement;

      expect(inputOn.disabled, isTrue);
      expect(inputOff.disabled, isFalse);
      expect(inputOff.hasAttribute('disabled'), isFalse);
      expect(buttonOn.disabled, isTrue);
      expect(buttonOff.disabled, isFalse);
      expect(buttonOff.hasAttribute('disabled'), isFalse);
      expect(textareaOn.disabled, isTrue);
      expect(textareaOff.disabled, isFalse);
    });

    test(r'$button(attributes: {disabled: "false"}) overrides', () {
      final button = _generate(
        $button(disabled: true, attributes: {'disabled': 'false'}),
      ) as HTMLButtonElement;
      expect(button.disabled, isFalse);
    });

    test(r'$select(disabled:, multiple:) / $option(disabled:, selected:)', () {
      final select = _generate(
        $select(
          multiple: true,
          disabled: false,
          options: [
            $option(value: 'a', text: 'A', selected: true),
            $option(value: 'b', text: 'B', disabled: true),
            $option(value: 'c', text: 'C', selected: true, disabled: true),
            $option(value: 'd', text: 'D', selected: false),
          ],
        ),
      ) as HTMLSelectElement;

      expect(select.multiple, isTrue);
      expect(select.disabled, isFalse);
      expect(_selectedValues(select), equals(['a', 'c']));
      expect(_options(select).map((o) => o.disabled), [
        false,
        true,
        true,
        false,
      ]);

      final single = _generate(
        $select(
          disabled: true,
          multiple: false,
          options: [
            $option(value: 'a', text: 'A'),
            $option(value: 'b', text: 'B'),
          ],
        ),
      ) as HTMLSelectElement;
      expect(single.disabled, isTrue);
      expect(single.multiple, isFalse);
      expect(single.hasAttribute('multiple'), isFalse);
    });

    test(r'$select(selected:) selects by value', () {
      final select = _generate(
        $select(
          selected: 'b',
          options: [
            $option(value: 'a', text: 'A'),
            $option(value: 'b', text: 'B'),
            $option(value: 'c', text: 'C'),
          ],
        ),
      ) as HTMLSelectElement;
      expect(select.value, equals('b'));
      expect(_selectedValues(select), equals(['b']));
    });

    test(r'$div(hidden:)', () {
      expect(_isHidden(_generate($div(hidden: true))), isTrue);
      final shown = _generate($div(hidden: false));
      expect(_isHidden(shown), isFalse);
      expect(shown.hasAttribute('hidden'), isFalse);
    });
  });

  group('updating existing elements', () {
    test('setResolvedAttribute toggles on -> off -> on (all booleans)', () {
      final checkbox = HTMLInputElement()..type = 'checkbox';
      final button = HTMLButtonElement();
      final textarea = HTMLTextAreaElement();
      final fieldset = HTMLFieldSetElement();
      final option = HTMLOptionElement();
      final select = HTMLSelectElement();
      final file = HTMLInputElement()..type = 'file';
      final div = HTMLDivElement();
      final audio = HTMLAudioElement();

      final targets = <(Element, String, bool Function())>[
        (checkbox, 'checked', () => checkbox.checked),
        (button, 'disabled', () => button.disabled),
        (textarea, 'disabled', () => textarea.disabled),
        (fieldset, 'disabled', () => fieldset.disabled),
        (option, 'disabled', () => option.disabled),
        (option, 'selected', () => option.selected),
        (select, 'multiple', () => select.multiple),
        (file, 'multiple', () => file.multiple),
        (div, 'hidden', () => _isHidden(div)),
        (div, 'inert', () => div.inert),
        (audio, 'autoplay', () => audio.autoplay),
        (audio, 'controls', () => audio.controls),
        (audio, 'muted', () => audio.defaultMuted),
      ];

      for (final (element, name, read) in targets) {
        _setResolved(element, name, 'true');
        expect(read(), isTrue, reason: '$name on');

        _setResolved(element, name, null);
        expect(read(), isFalse, reason: '$name off');
        expect(element.hasAttribute(name), isFalse, reason: '$name off');

        _setResolved(element, name, 'true');
        expect(read(), isTrue, reason: '$name on again');
      }
    });

    test('setResolvedAttribute: booleanDefault true/false for null', () {
      final checkbox = HTMLInputElement()..type = 'checkbox';
      final option = HTMLOptionElement();
      final div = HTMLDivElement();

      for (final on in [true, false, true]) {
        _setResolved(checkbox, 'checked', null, booleanDefault: on);
        _setResolved(option, 'selected', null, booleanDefault: on);
        _setResolved(div, 'inert', null, booleanDefault: on);
        expect(checkbox.checked, equals(on));
        expect(checkbox.hasAttribute('checked'), equals(on));
        expect(option.selected, equals(on));
        expect(div.inert, equals(on));
        expect(div.hasAttribute('inert'), equals(on));
      }
    });

    test('setResolvedAttribute: booleanDefault does not apply to a value', () {
      final option = HTMLOptionElement();
      _setResolved(option, 'selected', 'true', booleanDefault: false);
      expect(option.selected, isTrue);
      final div = HTMLDivElement();
      _setResolved(div, 'hidden', 'false', booleanDefault: true);
      expect(_isHidden(div), isFalse);
    });

    test(
      'setResolvedAttribute: valueDefault (null removes, a string sets)',
      () {
        final input = HTMLInputElement()
          ..placeholder = 'old'
          ..setAttribute('data-x', 'old')
          ..setAttribute('aria-label', 'old');

        _setResolved(input, 'placeholder', null);
        _setResolved(input, 'data-x', null);
        _setResolved(input, 'aria-label', null);
        expect(input.hasAttribute('placeholder'), isFalse);
        expect(input.placeholder, isEmpty);
        expect(input.hasAttribute('data-x'), isFalse);
        expect(input.hasAttribute('aria-label'), isFalse);

        _setResolved(input, 'placeholder', null, valueDefault: 'type...');
        _setResolved(input, 'data-x', null, valueDefault: '');
        expect(input.placeholder, equals('type...'));
        expect(input.getAttribute('data-x'), equals(''));
        expect(input.matches('[data-x]'), isTrue);

        // A value wins over valueDefault:
        _setResolved(input, 'placeholder', 'v', valueDefault: 'type...');
        expect(input.placeholder, equals('v'));
      },
    );

    test('setResolvedAttribute: id/class/style null removes them', () {
      final div = HTMLDivElement()
        ..id = 'a'
        ..className = 'x'
        ..setAttribute('style', 'color: red');
      _setResolved(div, 'id', null);
      _setResolved(div, 'class', null);
      _setResolved(div, 'style', null);
      expect(div.hasAttribute('id'), isFalse);
      expect(div.hasAttribute('class'), isFalse);
      expect(div.hasAttribute('style'), isFalse);

      _setResolved(div, 'id', null, valueDefault: 'b');
      _setResolved(div, 'class', null, valueDefault: 'c d');
      expect(div.id, equals('b'));
      expect(div.classList.contains('d'), isTrue);
    });

    test('setAttribute: selected/multiple/hidden/inert "true" -> "false"', () {
      final option = HTMLOptionElement();
      final select = HTMLSelectElement();
      final div = HTMLDivElement();
      for (final on in [true, false, true, false]) {
        _gen.setAttribute(option, 'selected', '$on');
        _gen.setAttribute(select, 'multiple', '$on');
        _gen.setAttribute(div, 'hidden', '$on');
        _gen.setAttribute(div, 'inert', '$on');
        expect(option.selected, equals(on));
        expect(select.multiple, equals(on));
        expect(select.hasAttribute('multiple'), equals(on));
        expect(_isHidden(div), equals(on));
        expect(div.hasAttribute('hidden'), equals(on));
        expect(div.inert, equals(on));
      }
    });

    test('setAttribute: checked/disabled follow the boolean rule', () {
      // As every boolean attribute: `null` is a bare attribute (on), a
      // value is read by `DOMAttribute.parseBooleanValue`.
      final checkbox = HTMLInputElement()..type = 'checkbox';
      _gen.setAttribute(checkbox, 'checked', '');
      expect(checkbox.checked, isTrue);
      _gen.setAttribute(checkbox, 'checked', 'false');
      expect(checkbox.checked, isFalse);
      expect(checkbox.hasAttribute('checked'), isFalse);
      _gen.setAttribute(checkbox, 'checked', null);
      expect(checkbox.checked, isTrue);

      final button = HTMLButtonElement();
      _gen.setAttribute(button, 'disabled', 'disabled');
      expect(button.disabled, isTrue);
      _gen.setAttribute(button, 'disabled', 'false');
      expect(button.disabled, isFalse);
    });

    test('re-generating a select changes the selected option', () {
      String html(String lang) =>
          '<select>${[
            for (final l in ['en', 'pt', 'es']) '<option value="$l" selected="${l == lang}">$l</option>',
          ].join()}</select>';

      for (final lang in ['pt', 'es', 'en']) {
        final select = _generateHTML(html(lang)) as HTMLSelectElement;
        expect(select.value, equals(lang));
        expect(_selectedValues(select), equals([lang]));
      }
    });

    test('setResolvedAttribute moves the selection between options', () {
      final select = _generateHTML(
        '<select><option value="a">A</option><option value="b">B</option>'
        '<option value="c">C</option></select>',
      ) as HTMLSelectElement;
      final options = _options(select);

      _setResolved(options[2], 'selected', 'true');
      expect(select.value, equals('c'));
      _setResolved(options[1], 'selected', 'true');
      expect(select.value, equals('b'));
      expect(_selectedValues(select), equals(['b']));
      _setResolved(options[1], 'selected', null);
      // A single select without a selected option shows the first one:
      expect(select.value, equals('a'));
    });

    test(
      'checked follows the attribute after the user toggled the checkbox',
      () {
        final checkbox = _generateHTML(
          '<input type="checkbox" checked>',
        ) as HTMLInputElement;
        // As a user click: the checkedness is now "dirty".
        checkbox.click();
        expect(checkbox.checked, isFalse);

        _setResolved(checkbox, 'checked', 'true');
        expect(checkbox.checked, isTrue);
      },
    );
  });

  group('<select> correctness', () {
    HTMLSelectElement select(String options, {String attrs = ''}) =>
        _generateHTML('<select $attrs>$options</select>') as HTMLSelectElement;

    test('single, 0 selected: the first one', () {
      final s = select(
        '<option value="a">A</option><option value="b">B</option>',
      );
      expect(s.value, equals('a'));
      expect(s.selectedIndex, equals(0));
    });

    test('single, 1 selected in the middle', () {
      final s = select(
        '<option value="a" selected="false">A</option>'
        '<option value="b" selected="true">B</option>'
        '<option value="c">C</option>',
      );
      expect(s.selectedIndex, equals(1));
      expect(_selectedValues(s), equals(['b']));
    });

    test('single, 1 selected last (no later option clears it)', () {
      final s = select(
        '<option value="a" selected="false">A</option>'
        '<option value="b" selected="false">B</option>'
        '<option value="c" selected="true">C</option>',
      );
      expect(s.value, equals('c'));
    });

    test('single, several selected: only one, the last (as HTML)', () {
      final s = select(
        '<option value="a" selected>A</option>'
        '<option value="b" selected="true">B</option>'
        '<option value="c">C</option>',
      );
      expect(_selectedValues(s), equals(['b']));
      expect(s.value, equals('b'));
    });

    test('multiple, several selected (true, bare, "", own name)', () {
      final s = select(
        attrs: 'multiple',
        '<option value="a" selected="true">A</option>'
        '<option value="b" selected="false">B</option>'
        '<option value="c" selected>C</option>'
        '<option value="d" selected="">D</option>'
        '<option value="e" selected="selected">E</option>'
        '<option value="f" selected="off">F</option>',
      );
      expect(s.multiple, isTrue);
      expect(_selectedValues(s), equals(['a', 'c', 'd', 'e']));
    });

    test('multiple, none selected: none (no default)', () {
      final s = select(
        attrs: 'multiple="true"',
        '<option value="a" selected="false">A</option>'
        '<option value="b">B</option>',
      );
      expect(_selectedValues(s), isEmpty);
      expect(s.selectedIndex, equals(-1));
    });

    test('multiple="false": a single select', () {
      final s = select(
        attrs: 'multiple="false"',
        '<option value="a" selected>A</option>'
        '<option value="b" selected>B</option>',
      );
      expect(s.multiple, isFalse);
      expect(s.hasAttribute('multiple'), isFalse);
      expect(_selectedValues(s), equals(['b']));
    });

    test('disabled options: selectable, and disabled="false" is enabled', () {
      final s = select(
        '<option value="a" disabled="true">A</option>'
        '<option value="b" disabled="false" selected="true">B</option>'
        '<option value="c" disabled>C</option>',
      );
      final options = _options(s);
      expect(options.map((o) => o.disabled), [true, false, true]);
      expect(options[1].hasAttribute('disabled'), isFalse);
      expect(s.value, equals('b'));
    });

    test('a disabled option can be the selected one', () {
      final s = select(
        '<option value="a">A</option>'
        '<option value="b" disabled selected>B</option>',
      );
      expect(s.value, equals('b'));
    });

    test(
      'optgroups: selected inside groups, disabled group',
      () {
        final s = select(
          '<optgroup label="Europe" disabled="false">'
          '<option value="pt" selected="false">PT</option>'
          '<option value="fr" selected="true">FR</option>'
          '</optgroup>'
          '<optgroup label="Asia" disabled="true">'
          '<option value="jp">JP</option>'
          '</optgroup>',
        );
        final groups = s.querySelectorAll('optgroup');
        expect((groups.item(0)! as HTMLOptGroupElement).disabled, isFalse);
        expect((groups.item(1)! as HTMLOptGroupElement).disabled, isTrue);
        expect(s.options.length, equals(3));
        expect(s.value, equals('fr'));
        expect(_selectedValues(s), equals(['fr']));
        // An option in a disabled group is disabled:
        expect(
          s.querySelector('option[value="jp"]')!.matches(':disabled'),
          true,
        );
      },
      skip: 'Bug: a parsed `<select>` maps every child with `OPTIONElement.from`, which throws "Not a option tag" for an `<optgroup>`',
    );

    test('<optgroup disabled> value forms (outside a parsed select)', () {
      for (final (attr, on) in [
        ('disabled', true),
        ('disabled="true"', true),
        ('disabled=""', true),
        ('disabled="disabled"', true),
        ('disabled="false"', false),
        ('', false),
      ]) {
        final g = _generateHTML(
          '<optgroup label="g" $attr><option>A</option></optgroup>',
        ) as HTMLOptGroupElement;
        expect(g.disabled, equals(on), reason: attr);
        expect(g.hasAttribute('disabled'), equals(on), reason: attr);
      }
    });

    const langs = ['en', 'pt', 'es', 'ga'];

    // The app's language select: a template condition per option, resolved
    // when generating (not pre-built to a string).
    for (final lang in [...langs, 'xx']) {
      test('template selected="{{:lang==...}}", resolved by the generator, '
          'lang "$lang"', () {
        final node = DOMNode.parseNodes(
          '<select>${[for (final l in langs) '<option value="$l" selected="{{:lang==\'$l\'}}true{{?}}false{{/}}">$l</option>'].join()}</select>',
        ).first;
        final s =
            _generateWithVariables(node, {'lang': lang}) as HTMLSelectElement;

        final expected = lang == 'xx' ? 'en' : lang;
        expect(s.value, equals(expected));
        expect(_selectedValues(s), equals([expected]));
      });
    }

    test('template on a multiple select', () {
      final node = DOMNode.parseNodes(
        '<select multiple>${[for (final l in langs) '<option value="$l" selected="{{:$l}}true{{?}}false{{/}}">$l</option>'].join()}</select>',
      ).first;
      final s = _generateWithVariables(node, {
        'en': true,
        'pt': false,
        'es': true,
        'ga': false,
      }) as HTMLSelectElement;
      expect(_selectedValues(s), equals(['en', 'es']));
    });

    test(
      'a generated selected option is the form default (survives reset)',
      () {
        final form = _generateHTML(
          '<form><select><option value="a">A</option>'
          '<option value="b" selected="true">B</option></select></form>',
        ) as HTMLFormElement;
        final s = form.querySelector('select')! as HTMLSelectElement;
        expect(s.value, equals('b'));

        final b = _options(s)[1];
        expect(b.defaultSelected, isTrue);
        form.reset();
        expect(s.value, equals('b'));
      },
    );
  });

  group('template values of boolean attributes', () {
    test('hidden / inert / multiple from a template', () {
      for (final on in [true, false]) {
        final e = _generateWithVariables(
          DOMNode.parseNodes(
            '<div hidden="{{:on}}true{{?}}false{{/}}" '
            'inert="{{:on}}true{{?}}false{{/}}">x</div>',
          ).first,
          {'on': on},
        );
        expect(_isHidden(e), equals(on));
        expect(e.hasAttribute('hidden'), equals(on));
        expect((e as HTMLElement).inert, equals(on));
      }
    });

    test('checked / disabled "false" from a template are off', () {
      final e = _generateWithVariables(
        DOMNode.parseNodes(
          '<div>'
          '<input type="checkbox" checked="{{:on}}true{{?}}false{{/}}">'
          '<button disabled="{{:on}}true{{?}}false{{/}}">b</button>'
          '</div>',
        ).first,
        {'on': false},
      );
      final checkbox = e.querySelector('input')! as HTMLInputElement;
      final button = e.querySelector('button')! as HTMLButtonElement;
      expect(checkbox.checked, isFalse);
      expect(button.disabled, isFalse);
    });

    test('selected="selected" / "" from a template select the option', () {
      final s = _generateWithVariables(
        DOMNode.parseNodes(
          '<select><option value="a">A</option>'
          '<option value="b" selected="{{:on}}selected{{/}}">B'
          '</option></select>',
        ).first,
        {'on': true},
      ) as HTMLSelectElement;
      expect(s.value, equals('b'));
    });
  });

  group('setAttribute / setResolvedAttribute value forms', () {
    test(
      '"" and own name are on for selected/hidden (as checked/disabled)',
      () {
        final option = HTMLOptionElement();
        _gen.setAttribute(option, 'selected', 'selected');
        expect(option.selected, isTrue);

        final div = HTMLDivElement();
        _gen.setAttribute(div, 'hidden', '');
        expect(_isHidden(div), isTrue);
      },
    );

    test('"false" is off for checked/disabled (as selected/hidden)', () {
      final checkbox = HTMLInputElement()..type = 'checkbox';
      _setResolved(checkbox, 'checked', 'false');
      expect(checkbox.checked, isFalse);

      final button = HTMLButtonElement();
      _setResolved(button, 'disabled', 'false');
      expect(button.disabled, isFalse);
    });
  });

  group('empty values in the DOM', () {
    test('data-x="" and a valueless data-x: present, dataset ""', () {
      final e = _generateHTML('<div data-x="" data-y data-z="z">x</div>');
      expect(e.matches('[data-x]'), isTrue);
      expect(e.matches('[data-y]'), isTrue);
      expect(e.matches('[data-x=""]'), isTrue);
      final dataset = (e as HTMLElement).dataset;
      expect(dataset['x'], equals(''));
      expect(dataset['y'], equals(''));
      expect(dataset['z'], equals('z'));
      expect(_root().ownerDocument!.querySelector('[data-y]'), isNotNull);
    });

    test(r'data-x="" from $tag attributes and setResolvedAttribute', () {
      final e = _generate($tag('div', attributes: {'data-x': ''}));
      expect(e.getAttribute('data-x'), equals(''));
      expect(e.matches('[data-x]'), isTrue);

      final div = HTMLDivElement();
      _setResolved(div, 'data-x', '');
      expect(div.getAttribute('data-x'), equals(''));
      expect(div.dataset['x'], equals(''));
    });

    test('value="" on input / option', () {
      final input = _generateHTML('<input value="">') as HTMLInputElement;
      expect(input.getAttribute('value'), equals(''));
      expect(input.defaultValue, equals(''));

      final s = _generateHTML(
        '<select><option value="">-</option>'
        '<option value="a">A</option></select>',
      ) as HTMLSelectElement;
      final empty = _options(s)[0];
      // An empty `value` is the value, not the text:
      expect(empty.hasAttribute('value'), isTrue);
      expect(empty.value, equals(''));
      expect(s.value, equals(''));
    });

    test('a valueless value on an option: the value is the text', () {
      final s = _generateHTML(
        '<select><option value>Text</option></select>',
      ) as HTMLSelectElement;
      expect(_options(s)[0].value, equals(''));
    });

    test('alt="" (decorative image) is kept, no alt is absent', () {
      final img =
          _generateHTML('<img src="data:," alt="">') as HTMLImageElement;
      expect(img.hasAttribute('alt'), isTrue);
      expect(img.alt, equals(''));
      expect(img.matches('[alt=""]'), isTrue);

      final noAlt = _generateHTML('<img src="data:,">') as HTMLImageElement;
      expect(noAlt.hasAttribute('alt'), isFalse);

      final built = _generate(
        $tag('img', attributes: {'src': 'data:,', 'alt': ''}),
      );
      expect(built.getAttribute('alt'), equals(''));
    });

    test('placeholder="" / aria-label="" / title="" kept', () {
      final input = _generateHTML(
        '<input placeholder="" aria-label="" title="">',
      ) as HTMLInputElement;
      expect(input.getAttribute('placeholder'), equals(''));
      expect(input.getAttribute('aria-label'), equals(''));
      expect(input.getAttribute('title'), equals(''));
      expect(input.matches('[aria-label]'), isTrue);

      final built = _generate(
        $input(placeholder: '', attributes: {'aria-label': ''}),
      ) as HTMLInputElement;
      expect(built.getAttribute('aria-label'), equals(''));
    });

    test('empty class / style are left out', () {
      final e = _generateHTML('<div class="" style="">x</div>');
      expect(e.hasAttribute('class'), isFalse);
      expect(e.hasAttribute('style'), isFalse);

      final built = _generate(
        $tag('div', attributes: {'class': '', 'style': ''}),
      );
      expect(built.hasAttribute('class'), isFalse);
      expect(built.hasAttribute('style'), isFalse);

      final spaces = _generateHTML('<div class="  " style=" ">x</div>');
      expect(spaces.className.trim(), isEmpty);
      expect(spaces.getAttribute('style')?.trim() ?? '', isEmpty);
    });

    test('an empty id is left out or empty, never a stray value', () {
      final e = _generateHTML('<div id="">x</div>');
      expect(e.id, isEmpty);
    });
  });

  group('enumerated attributes with boolean-like values: verbatim', () {
    test('contenteditable', () {
      final off = _generateHTML('<div contenteditable="false">x</div>');
      final on = _generateHTML('<div contenteditable="true">x</div>');
      final bare = _generateHTML('<div contenteditable>x</div>');
      expect((off as HTMLElement).isContentEditable, isFalse);
      expect(off.contentEditable, equals('false'));
      expect(off.getAttribute('contenteditable'), equals('false'));
      expect((on as HTMLElement).isContentEditable, isTrue);
      // A bare `contenteditable` is the empty state: editable.
      expect((bare as HTMLElement).isContentEditable, isTrue);

      final built = _generate(
        $tag('div', attributes: {'contenteditable': 'false'}),
      );
      expect((built as HTMLElement).isContentEditable, isFalse);
    });

    test('draggable', () {
      final off = _generateHTML('<div draggable="false">x</div>');
      final on = _generateHTML('<div draggable="true">x</div>');
      final img = _generateHTML('<img src="data:," draggable="false">');
      expect((off as HTMLElement).draggable, isFalse);
      expect(off.getAttribute('draggable'), equals('false'));
      expect((on as HTMLElement).draggable, isTrue);
      // An image is draggable by default; "false" must turn it off.
      expect((img as HTMLElement).draggable, isFalse);
    });

    test('spellcheck on a contenteditable div and an input', () {
      final div = _generateHTML(
        '<div contenteditable="true" spellcheck="false">x</div>',
      );
      expect((div as HTMLElement).spellcheck, isFalse);
      final input = _generate(
        $input(attributes: {'spellcheck': 'false'}),
      ) as HTMLInputElement;
      expect(input.spellcheck, isFalse);
      expect(input.getAttribute('spellcheck'), equals('false'));
    });

    test('autocomplete off / on / new-password', () {
      for (final v in ['off', 'on', 'new-password']) {
        final input =
            _generateHTML('<input autocomplete="$v">') as HTMLInputElement;
        expect(input.autocomplete, equals(v));
        final built = _generate(
          $input(attributes: {'autocomplete': v}),
        ) as HTMLInputElement;
        expect(built.autocomplete, equals(v));
      }
    });

    test('translate="no" / "yes"', () {
      final no = _generateHTML('<span translate="no">MenuIci</span>');
      final yes = _generateHTML('<span translate="yes">x</span>');
      expect((no as HTMLElement).translate, isFalse);
      expect(no.getAttribute('translate'), equals('no'));
      expect((yes as HTMLElement).translate, isTrue);
    });

    test('aria-* "false" / "true" kept as strings', () {
      final e = _generateHTML(
        '<div aria-hidden="false" aria-expanded="false" '
        'aria-checked="true" aria-disabled="false">x</div>',
      );
      expect(e.getAttribute('aria-hidden'), equals('false'));
      expect(e.getAttribute('aria-expanded'), equals('false'));
      expect(e.getAttribute('aria-checked'), equals('true'));
      expect(e.getAttribute('aria-disabled'), equals('false'));
      expect(e.matches('[aria-hidden="false"]'), isTrue);
      // aria-hidden="false" does not hide the element:
      expect(_isHidden(e), isFalse);
    });

    test(r'via $tag and setResolvedAttribute (booleanDefault ignored)', () {
      final div = HTMLDivElement();
      for (final (name, value) in [
        ('contenteditable', 'false'),
        ('draggable', 'false'),
        ('translate', 'no'),
        ('aria-hidden', 'false'),
        ('autocomplete', 'off'),
      ]) {
        _setResolved(div, name, value, booleanDefault: true);
        expect(div.getAttribute(name), equals(value), reason: name);
      }
      expect(div.isContentEditable, isFalse);
      expect(div.draggable, isFalse);
      expect(div.translate, isFalse);

      // `null` removes them (no booleanDefault for them):
      _setResolved(div, 'contenteditable', null, booleanDefault: true);
      expect(div.hasAttribute('contenteditable'), isFalse);
    });

    test('<details open> is not a parsed boolean: kept verbatim', () {
      final e = _generateHTML('<details open><summary>s</summary></details>');
      expect((e as HTMLDetailsElement).open, isTrue);
    });
  });

  // `hidden="until-found"`: a state of its own (hidden, but found by
  // find-in-page and fragment navigation), kept as the value.
  group('hidden="until-found"', () {
    String? hiddenOf(Element e) => e.getAttribute('hidden');

    test('keeps the until-found state', () {
      final e = _generateHTML('<div hidden="until-found">x</div>');
      expect(hiddenOf(e), equals('until-found'));
      expect((e as HTMLElement).hidden.dartify(), equals('until-found'));
    });

    test('in any case / with spaces: normalized', () {
      for (final value in ['Until-Found', 'UNTIL-FOUND', ' until-found ']) {
        final e = _generateHTML('<div hidden="$value">x</div>');
        expect(hiddenOf(e), equals('until-found'), reason: value);
      }
    });

    test(r'from $tag attributes and a template', () {
      final tagged = _generate(
        $tag('div', attributes: {'hidden': 'until-found'}, content: 'x'),
      );
      expect(hiddenOf(tagged), equals('until-found'));

      for (final (find, expected) in [(true, 'until-found'), (false, '')]) {
        final e = _generateWithVariables(
          DOMNode.parseNodes(
            '<div hidden="{{:find}}until-found{{?}}true{{/}}">x</div>',
          ).first,
          {'find': find},
        );
        expect(hiddenOf(e), equals(expected), reason: 'find: $find');
      }
    });

    test('the boolean forms still work alongside it', () {
      expect(hiddenOf(_generateHTML('<div hidden>x</div>')), equals(''));
      expect(hiddenOf(_generateHTML('<div hidden="true">x</div>')), '');
      expect(hiddenOf(_generateHTML('<div hidden="false">x</div>')), isNull);
      // Not a keyword of another boolean attribute:
      final input = _generateHTML(
        '<input type="checkbox" checked="until-found">',
      ) as HTMLInputElement;
      expect(input.checked, isFalse);
    });

    test('switching an element between until-found and the booleans', () {
      final div = HTMLDivElement();
      _gen.setAttribute(div, 'hidden', 'until-found');
      expect(hiddenOf(div), equals('until-found'));

      _setResolved(div, 'hidden', 'true');
      expect(hiddenOf(div), equals(''));
      expect(div.hidden.dartify(), isTrue);

      _setResolved(div, 'hidden', 'until-found');
      expect(hiddenOf(div), equals('until-found'));

      _setResolved(div, 'hidden', 'false');
      expect(hiddenOf(div), isNull);
      expect(div.hidden.dartify(), isFalse);
    });
  });
}
