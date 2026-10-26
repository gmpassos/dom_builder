@TestOn('vm')
library;

import 'package:dom_builder/dom_builder.dart';
import 'package:test/test.dart';

enum _Sort { ascending }

/// The accessibility attributes of the elements and helpers: `role`,
/// `aria-label`, any `aria-*` and `tabindex` ([DOMElement.setAccessibility]).
void main() {
  group('setAccessibility', () {
    test('sets role, aria-label, aria-* and tabindex', () {
      var e = $div()
        ..setAccessibility(
          role: 'button',
          ariaLabel: 'Refresh',
          aria: {'pressed': false, 'aria-controls': 'list'},
          tabIndex: 0,
        );

      expect(e.getAttributeValue('role'), 'button');
      expect(e.getAttributeValue('aria-label'), 'Refresh');
      expect(e.getAttributeValue('aria-pressed'), 'false');
      expect(e.getAttributeValue('aria-controls'), 'list');
      expect(e.getAttributeValue('tabindex'), '0');
    });

    test('an aria key with or without the prefix, any case', () {
      var e = $span(aria: {'Hidden': true, 'ARIA-LIVE': 'polite'});

      expect(e.getAttributeValue('aria-hidden'), 'true');
      expect(e.getAttributeValue('aria-live'), 'polite');
      expect(e.buildHTML(), isNot(contains('aria-aria-')));
    });

    test('a bool aria value is a string, not a bare boolean attribute', () {
      var html = $div(aria: {'expanded': true, 'hidden': false}).buildHTML();

      expect(html, contains('aria-expanded="true"'));
      expect(html, contains('aria-hidden="false"'));
    });

    test('a null aria value removes the attribute; null params keep', () {
      var e = $div(role: 'tab', ariaLabel: 'A', aria: {'selected': true});

      e.setAccessibility(aria: {'selected': null});

      expect(e.getAttribute('aria-selected'), isNull);
      expect(e.getAttributeValue('role'), 'tab');
      expect(e.getAttributeValue('aria-label'), 'A');
    });

    test('a list value is space-joined (an ID list)', () {
      var e = $input(
        aria: {
          'describedby': ['hint', 'error'],
          'controls': <Object?>['a', null, '', 'b'],
        },
      );

      expect(e.getAttributeValue('aria-describedby'), 'hint error');
      expect(e.getAttributeValue('aria-controls'), 'a b');
    });

    test('a key camelCase or snake_case is the same attribute', () {
      var e = $div(
        aria: {'ariaHidden': true, 'aria_live': 'polite', 'AriaBusy': false},
      );

      expect(e.getAttributeValue('aria-hidden'), 'true');
      expect(e.getAttributeValue('aria-live'), 'polite');
      expect(e.getAttributeValue('aria-busy'), 'false');
      expect(e.buildHTML(), isNot(contains('aria-aria')));
    });

    test('an empty key throws', () {
      expect(() => $div(aria: {' ': true}), throwsArgumentError);
      expect(() => $div(aria: {'aria-': true}), throwsArgumentError);
    });

    test("an enum value is its name; a number, its text", () {
      var e = $div(aria: {'sort': _Sort.ascending, 'valuenow': 3});

      expect(e.getAttributeValue('aria-sort'), 'ascending');
      expect(e.getAttributeValue('aria-valuenow'), '3');
    });

    test('ariaLabel wins over an aria label entry', () {
      expect(
        $button(
          ariaLabel: 'Close',
          aria: {'label': 'X'},
        ).getAttributeValue('aria-label'),
        'Close',
      );

      var e = $div()
        ..setAccessibility(ariaLabel: 'Close', aria: {'label': null});
      expect(e.getAttributeValue('aria-label'), 'Close');
    });

    test('ariaAttributeName and ariaAttributeValue', () {
      expect(DOMElement.ariaAttributeName('Expanded'), 'aria-expanded');
      expect(DOMElement.ariaAttributeName('aria-expanded'), 'aria-expanded');
      expect(DOMElement.ariaAttributeValue(null), isNull);
      expect(DOMElement.ariaAttributeValue(['a', 'b']), 'a b');
    });

    test('returns the element (chainable)', () {
      var e = $div();
      expect(identical(e.setAccessibility(role: 'region'), e), isTrue);
    });

    test('the parameters win over the same attributes', () {
      var e = $div(
        attributes: {'role': 'presentation', 'aria-label': 'old'},
        role: 'button',
        ariaLabel: 'new',
      );

      expect(e.getAttributeValue('role'), 'button');
      expect(e.getAttributeValue('aria-label'), 'new');
    });

    test('nothing set: no attribute', () {
      var html = $div(content: 'x').buildHTML();
      expect(html, isNot(contains('role=')));
      expect(html, isNot(contains('aria-')));
      expect(html, isNot(contains('tabindex')));
    });
  });

  group('helpers', () {
    String a11y(DOMElement e) => [
      e.getAttributeValue('role'),
      e.getAttributeValue('aria-label'),
      e.getAttributeValue('aria-describedby'),
      e.getAttributeValue('tabindex'),
    ].join('|');

    const expected = 'button|Name|desc|0';
    const args = (
      role: 'button',
      ariaLabel: 'Name',
      aria: {'describedby': 'desc'},
      tabIndex: 0,
    );

    test('every element helper takes and sets them', () {
      var elements = <String, DOMElement>{
        r'$tag': $tag(
          'section',
          role: args.role,
          ariaLabel: args.ariaLabel,
          aria: args.aria,
          tabIndex: args.tabIndex,
        ),
        r'$div': $div(
          role: args.role,
          ariaLabel: args.ariaLabel,
          aria: args.aria,
          tabIndex: args.tabIndex,
        ),
        r'$divInline': $divInline(
          role: args.role,
          ariaLabel: args.ariaLabel,
          aria: args.aria,
          tabIndex: args.tabIndex,
        ),
        r'$span': $span(
          role: args.role,
          ariaLabel: args.ariaLabel,
          aria: args.aria,
          tabIndex: args.tabIndex,
        ),
        r'$button': $button(
          role: args.role,
          ariaLabel: args.ariaLabel,
          aria: args.aria,
          tabIndex: args.tabIndex,
        ),
        r'$label': $label(
          role: args.role,
          ariaLabel: args.ariaLabel,
          aria: args.aria,
          tabIndex: args.tabIndex,
        ),
        r'$a': $a(
          role: args.role,
          ariaLabel: args.ariaLabel,
          aria: args.aria,
          tabIndex: args.tabIndex,
        ),
        r'$img': $img(
          role: args.role,
          ariaLabel: args.ariaLabel,
          aria: args.aria,
          tabIndex: args.tabIndex,
        ),
        r'$p': $p(
          role: args.role,
          ariaLabel: args.ariaLabel,
          aria: args.aria,
          tabIndex: args.tabIndex,
        ),
        r'$b': $b(
          role: args.role,
          ariaLabel: args.ariaLabel,
          aria: args.aria,
          tabIndex: args.tabIndex,
        ),
        r'$ul': $ul(
          role: args.role,
          ariaLabel: args.ariaLabel,
          aria: args.aria,
          tabIndex: args.tabIndex,
        ),
        r'$li': $li(
          role: args.role,
          ariaLabel: args.ariaLabel,
          aria: args.aria,
          tabIndex: args.tabIndex,
        ),
        r'$nav': $nav(
          role: args.role,
          ariaLabel: args.ariaLabel,
          aria: args.aria,
          tabIndex: args.tabIndex,
        ),
        r'$input': $input(
          role: args.role,
          ariaLabel: args.ariaLabel,
          aria: args.aria,
          tabIndex: args.tabIndex,
        ),
        r'$checkbox': $checkbox(
          role: args.role,
          ariaLabel: args.ariaLabel,
          aria: args.aria,
          tabIndex: args.tabIndex,
        ),
        r'$select': $select(
          role: args.role,
          ariaLabel: args.ariaLabel,
          aria: args.aria,
          tabIndex: args.tabIndex,
        ),
        r'$textarea': $textarea(
          role: args.role,
          ariaLabel: args.ariaLabel,
          aria: args.aria,
          tabIndex: args.tabIndex,
        ),
        r'$table': $table(
          role: args.role,
          ariaLabel: args.ariaLabel,
          aria: args.aria,
          tabIndex: args.tabIndex,
        ),
        r'$td': $td(
          role: args.role,
          ariaLabel: args.ariaLabel,
          aria: args.aria,
          tabIndex: args.tabIndex,
        ),
        r'$th': $th(
          role: args.role,
          ariaLabel: args.ariaLabel,
          aria: args.aria,
          tabIndex: args.tabIndex,
        ),
        r'$tr': $tr(
          role: args.role,
          ariaLabel: args.ariaLabel,
          aria: args.aria,
          tabIndex: args.tabIndex,
        ),
        r'$thead': $thead(
          role: args.role,
          ariaLabel: args.ariaLabel,
          aria: args.aria,
          tabIndex: args.tabIndex,
        ),
        r'$tbody': $tbody(
          role: args.role,
          ariaLabel: args.ariaLabel,
          aria: args.aria,
          tabIndex: args.tabIndex,
        ),
        r'$tfoot': $tfoot(
          role: args.role,
          ariaLabel: args.ariaLabel,
          aria: args.aria,
          tabIndex: args.tabIndex,
        ),
        r'$caption': $caption(
          role: args.role,
          ariaLabel: args.ariaLabel,
          aria: args.aria,
          tabIndex: args.tabIndex,
        ),
        r'$h': $h(
          2,
          role: args.role,
          ariaLabel: args.ariaLabel,
          aria: args.aria,
          tabIndex: args.tabIndex,
        ),
        r'$ol': $ol(
          role: args.role,
          ariaLabel: args.ariaLabel,
          aria: args.aria,
          tabIndex: args.tabIndex,
        ),
        r'$form': $form(
          role: args.role,
          ariaLabel: args.ariaLabel,
          aria: args.aria,
          tabIndex: args.tabIndex,
        ),
        r'$header': $header(
          role: args.role,
          ariaLabel: args.ariaLabel,
          aria: args.aria,
          tabIndex: args.tabIndex,
        ),
        r'$footer': $footer(
          role: args.role,
          ariaLabel: args.ariaLabel,
          aria: args.aria,
          tabIndex: args.tabIndex,
        ),
        r'$hr': $hr(
          role: args.role,
          ariaLabel: args.ariaLabel,
          aria: args.aria,
          tabIndex: args.tabIndex,
        ),
        r'$option': $option(
          valueAndText: 'x',
          role: args.role,
          ariaLabel: args.ariaLabel,
          aria: args.aria,
          tabIndex: args.tabIndex,
        ),
        r'$radiobutton': $radiobutton(
          role: args.role,
          ariaLabel: args.ariaLabel,
          aria: args.aria,
          tabIndex: args.tabIndex,
        ),
      };

      for (var e in elements.entries) {
        expect(a11y(e.value), expected, reason: e.key);
      }
    });

    test(r'$button keeps its default type', () {
      var html = $button(role: 'switch', aria: {'checked': true}).buildHTML();
      expect(html, contains('type="button"'));
      expect(html, contains('role="switch"'));
      expect(html, contains('aria-checked="true"'));
    });
  });

  group('keeping them', () {
    test('copy() keeps them', () {
      var e = $div(role: 'button', ariaLabel: 'Go', tabIndex: 0);
      var copy = e.copy();

      expect(copy.getAttributeValue('role'), 'button');
      expect(copy.getAttributeValue('aria-label'), 'Go');
      expect(copy.getAttributeValue('tabindex'), '0');
    });

    test('the HTML, parsed back, has them', () {
      var html = $button(
        content: 'Go',
        role: 'link',
        ariaLabel: 'Go home',
        aria: {'current': 'page', 'disabled': false},
        tabIndex: -1,
      ).buildHTML();

      var parsed = $tagHTML<DOMElement>(html)!;
      expect(parsed.getAttributeValue('role'), 'link');
      expect(parsed.getAttributeValue('aria-label'), 'Go home');
      expect(parsed.getAttributeValue('aria-current'), 'page');
      expect(parsed.getAttributeValue('aria-disabled'), 'false');
      expect(parsed.getAttributeValue('tabindex'), '-1');
    });

    test('a name set later replaces the one of the constructor', () {
      var e = $div(ariaLabel: 'First')..setAccessibility(ariaLabel: 'Second');
      expect(e.getAttributeValue('aria-label'), 'Second');
    });

    test('a template value in the name stays a template ({{intl:...}})', () {
      var e = $div(ariaLabel: '{{intl:labelRefresh}}');
      expect(e.buildHTML(), contains('aria-label="{{intl:labelRefresh}}"'));
    });
  });

  group('DOMElement factory', () {
    test('its specialized classes get them too', () {
      for (var tag in ['div', 'input', 'select', 'textarea', 'table', 'td']) {
        var e = DOMElement(tag, role: 'group', ariaLabel: tag, tabIndex: -1);
        expect(e.getAttributeValue('role'), 'group', reason: tag);
        expect(e.getAttributeValue('aria-label'), tag, reason: tag);
        expect(e.getAttributeValue('tabindex'), '-1', reason: tag);
      }
    });

    test('the attributes parsed from HTML stay', () {
      var e = $tagHTML<DOMElement>(
        '<div role="dialog" aria-modal="true" tabindex="-1">x</div>',
      )!;
      expect(e.getAttributeValue('role'), 'dialog');
      expect(e.getAttributeValue('aria-modal'), 'true');
      expect(e.getAttributeValue('tabindex'), '-1');
    });
  });
}
