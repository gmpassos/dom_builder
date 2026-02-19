import 'dart:async';

import 'package:dom_builder/dom_builder.dart';
import 'package:test/test.dart';

import 'dom_builder_domtest.dart';

void main() {
  group('DOMElement.hasAnyEventListener', () {
    test('false when no listeners', () {
      final el = $div();
      expect(el.hasAnyEventListener, isFalse);
    });

    test('true after adding click listener', () {
      final el = $div();
      el.onClick.listen((_) {});
      expect(el.hasAnyEventListener, isTrue);
    });

    test('true with multiple listeners', () {
      final el = $input();
      el.onChange.listen((_) {});
      el.onKeyDown.listen((_) {});
      expect(el.hasAnyEventListener, isTrue);
    });
  });

  group('DOMElement.closeAllEventListeners', () {
    test('returns 0 when none', () async {
      final el = $div();
      final closed = await el.closeAllEventListeners();
      expect(closed, 0);
      expect(el.hasAnyEventListener, isFalse);
    });

    test('closes single listener', () async {
      final el = $div();
      el.onClick.listen((_) {});
      expect(el.hasAnyEventListener, isTrue);

      final closed = await el.closeAllEventListeners();

      expect(closed, 1);
      expect(el.hasAnyEventListener, isFalse);
    });

    test('closes all listeners', () async {
      final el = $input();
      el.onClick.listen((_) {});
      el.onChange.listen((_) {});
      el.onKeyDown.listen((_) {});
      el.onKeyUp.listen((_) {});
      el.onKeyPress.listen((_) {});
      el.onMouseOver.listen((_) {});
      el.onMouseOut.listen((_) {});

      expect(el.hasAnyEventListener, isTrue);

      final closed = await el.closeAllEventListeners();

      expect(closed, greaterThanOrEqualTo(7));
      expect(el.hasAnyEventListener, isFalse);
    });
  });

  group('DOMTreeMap.domElementsWithEventListener', () {
    test('returns only elements with listeners', () {
      final generator = TestGenerator();
      final tree = DOMTreeMap<TestNode>(generator);

      final a = $div();
      final b = $div();
      final c = $div();

      a.onClick.listen((_) {});
      c.onMouseOver.listen((_) {});

      var aDiv = a.buildDOM(generator: generator)!;
      var bDiv = b.buildDOM(generator: generator)!;
      var cDiv = c.buildDOM(generator: generator)!;

      tree.map(a, aDiv);
      tree.map(b, bDiv);
      tree.map(c, cDiv);

      final list = tree.domElementsWithEventListener();

      expect(list, containsAll([a, c]));
      expect(list, isNot(contains(b)));
    });
  });

  group('DOMTreeMap.cancelAllSubscriptions flags', () {
    test('does not close listeners when disabled', () async {
      final generator = TestGenerator();
      final tree = DOMTreeMap<TestNode>(generator);

      final el = $div();

      el.onClick.listen((_) {});

      var elDiv = el.buildDOM(generator: generator)!;
      tree.map(el, elDiv);

      tree.cancelAllSubscriptions(
        elementsSubscriptions: true,
        domElementsEventListeners: false,
      );

      expect(el.hasAnyEventListener, isTrue);
    });

    test('closes listeners when enabled', () async {
      final generator = TestGenerator();
      final tree = DOMTreeMap<TestNode>(generator);

      final el = $div();

      el.onClick.listen((_) {});

      var elDiv = el.buildDOM(generator: generator)!;
      tree.map(el, elDiv);

      tree.cancelAllSubscriptions();

      // allow async close
      await Future.delayed(Duration(milliseconds: 1));

      expect(el.hasAnyEventListener, isFalse);
    });
  });

  group('DOMTreeMap element subscriptions unaffected', () {
    test('cancel only element subscriptions', () async {
      final generator = TestGenerator();
      final tree = DOMTreeMap<TestNode>(generator);
      final node = TestElem('div');

      final sub = StreamController().stream.listen((_) {});
      tree.mapSubscriptions(node, [sub]);

      tree.cancelAllSubscriptions(domElementsEventListeners: false);

      expect(tree.getSubscriptions(node), isEmpty);
    });
  });
}
