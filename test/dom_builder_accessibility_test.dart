@TestOn('vm')
library;

import 'package:dom_builder/dom_builder.dart';
import 'package:test/test.dart';

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
