@TestOn('browser')
library;

import 'package:dom_builder/dom_builder_web.dart';
import 'package:test/test.dart';
import 'package:web_utils/web_utils.dart' hide EventType;

/// Regression tests for the `package:web` generator fixes in 3.0.10.

DOMGeneratorWeb<Node> get _gen => DOMGenerator.web<Node>();

/// A root `div` attached to `document.body`, removed after the test.
HTMLDivElement _root() {
  final root = HTMLDivElement();
  document.body!.appendChild(root);
  addTearDown(() => root.remove());
  return root;
}

/// Generates [domNode] into a new attached root, with a mapped [DOMTreeMap].
({Element element, DOMTreeMap<Node> treeMap}) _generate(DOMNode domNode) {
  final treeMap = _gen.createDOMTreeMap();
  final element = _gen.generate(domNode, treeMap: treeMap, parent: _root());
  return (element: element as Element, treeMap: treeMap);
}

void main() {
  group('DOMGeneratorWeb', () {
    // List elements are `dynamic`, and calling the `asJSAny` extension on
    // them threw `NoSuchMethodError`.
    test('addExternalElementToElement with a List of nodes', () {
      final element = _root();
      final added = _gen.addExternalElementToElement(element, [
        HTMLElement.article(),
        [HTMLSpanElement()],
        null,
      ]);

      expect(added!.length, equals(2));
      expect(element.querySelector('article'), isNotNull);
      expect(element.querySelector('span'), isNotNull);
    });
  });

  group('DOMNodeRuntime', () {
    // `clearClasses` removed the element's children instead of its classes.
    test('clearClasses only clears classes', () {
      final div = $div(classes: 'a b', content: 'keep');
      final (:element, treeMap: _) = _generate(div);

      div.runtime.clearClasses();

      expect(element.className, isEmpty);
      expect(element.textContent, equals('keep'));
    });
  });

  group('DOMActionExecutor', () {
    // 'removeclass' was dispatched to `callAddClass`.
    test("'removeclass' / 'removeclasses' remove classes", () {
      final executor = _gen.domActionExecutor!;
      final div = $div(classes: 'a b c');
      final (:element, :treeMap) = _generate(div);

      executor.call('removeclass', ['a'], null, element, treeMap, null);
      expect(element.classList.contains('a'), isFalse);
      expect(element.classList.contains('b'), isTrue);

      executor.call('removeclasses', ['b'], null, element, treeMap, null);
      expect(element.classList.contains('b'), isFalse);
      expect(element.classList.contains('c'), isTrue);

      expect(
        executor.call('removeclass', ['x'], null, null, treeMap, null),
        isNull,
      );
    });

    test("'removeclass' via the action attribute", () async {
      final button = $button(
        attributes: {'action': '#target.removeClass(x)'},
        content: 'go',
      );
      final target = $div(id: 'target', classes: 'x y');
      final (:element, treeMap: _) = _generate($div(content: [button, target]));

      button.getRuntimeNode<Element>()!.dispatchEvent(MouseEvent('click'));
      // Actions are executed asynchronously:
      await Future<void>.delayed(Duration.zero);

      final targetElement = element.querySelector('#target')!;
      expect(targetElement.classList.contains('x'), isFalse);
      expect(targetElement.classList.contains('y'), isTrue);
    });
  });
}
