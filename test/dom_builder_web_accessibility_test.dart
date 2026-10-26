@TestOn('browser')
library;

import 'package:dom_builder/dom_builder_web.dart';
import 'package:test/test.dart';
import 'package:web_utils/web_utils.dart' hide EventType;

/// Integration tests (real DOM) for the accessibility attributes
/// (`DOMElement.setAccessibility`): generated as plain attributes, `aria-*`
/// values as strings.

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

void main() {
  group('accessibility attributes (web)', () {
    test('a clickable div as a button', () {
      final e = _generate(
        $div(
          content: 'Refresh',
          role: 'button',
          ariaLabel: 'Refresh the list',
          aria: {'pressed': false, 'controls': 'list'},
          tabIndex: 0,
        ),
      );

      expect(e.getAttribute('role'), 'button');
      expect(e.getAttribute('aria-label'), 'Refresh the list');
      expect(e.getAttribute('aria-pressed'), 'false');
      expect(e.getAttribute('aria-controls'), 'list');
      expect(e.getAttribute('tabindex'), '0');
      expect((e as HTMLElement).tabIndex, 0);
    });

    test('aria-hidden true and false are strings', () {
      final shown = _generate($span(aria: {'hidden': false}));
      final hidden = _generate($span(aria: {'hidden': true}));

      expect(shown.getAttribute('aria-hidden'), 'false');
      expect(hidden.getAttribute('aria-hidden'), 'true');
    });

    test('set after generating: the real element is updated', () {
      final node = $div(
        role: 'button',
        aria: {'expanded': false, 'controls': 'menu'},
      );
      final e = _generate(node);
      expect(e.getAttribute('aria-expanded'), 'false');

      node.setAccessibility(
        ariaLabel: 'Menu',
        aria: {'expanded': true, 'controls': null},
        tabIndex: 0,
      );

      expect(e.getAttribute('aria-expanded'), 'true');
      expect(e.getAttribute('aria-label'), 'Menu');
      expect(e.getAttribute('tabindex'), '0');
      expect(e.hasAttribute('aria-controls'), isFalse);
      expect(node.getAttributeValue('aria-expanded'), 'true');
    });

    test('set after building, before generating', () {
      final node = $button(content: 'x')
        ..setAccessibility(ariaLabel: 'Close', aria: {'expanded': true});
      final e = _generate(node);

      expect(e.getAttribute('aria-label'), 'Close');
      expect(e.getAttribute('aria-expanded'), 'true');
      expect(e.getAttribute('type'), 'button');
    });
  });
}
