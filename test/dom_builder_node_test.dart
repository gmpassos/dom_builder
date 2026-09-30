// Not compiled with dart2wasm: instantiating `DOMNode` together with the
// `merge`/`absorbNode` calls of other tests crashes the dart2wasm 3.13.3
// compiler ("Null check operator used on a null value" in
// `AstCodeGenerator._setupLocalParameters`), which fails the whole file even
// for skipped tests. Standalone repro (with dom_builder 3.0.10 from pub.dev):
// `DOMNode(content: 'a')` plus `TextNode.merge`, `DOMElement.merge` and
// `DOMElement.absorbNode` calls in one program.
@TestOn('!dart2wasm')
library;

import 'package:dom_builder/dom_builder.dart';
import 'package:test/test.dart';

void main() {
  group('DOMNode', () {
    // Regression: `DOMNode(content: ...)` left `_commented` uninitialized, so
    // `isCommented`/`buildHTML`/`copy` threw a `LateInitializationError`.
    test('constructor', () {
      var node = DOMNode(
        content: [
          $p(content: 'a'),
          'b',
        ],
      );
      expect(node.isCommented, isFalse);
      expect(node.buildHTML(), equals('<p>a</p>b'));
      expect(node.copy().buildHTML(), equals('<p>a</p>b'));
      expect(node.content!.first.parent, same(node));
      expect(DOMNode().buildHTML(), isEmpty);
      expect(DOMNode().isCommented, isFalse);
    });

    test('commented DOMNode builds no HTML', () {
      var node = DOMNode(content: 'x')..commented = true;
      expect(node.buildHTML(), isEmpty);
    });

    test('content is not indented without an own tag', () {
      var node = DOMNode(
        content: [
          $p(content: 'a'),
          $p(content: 'b'),
        ],
      );
      expect(node.buildHTML(withIndent: true), equals('<p>a</p><p>b</p>'));
    });
  });
}
