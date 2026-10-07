@TestOn('vm')
library;

import 'dart:async';

import 'package:dom_builder/dom_builder.dart';
import 'package:test/test.dart';

import 'dom_builder_domtest.dart';

/// A [TestGenerator] that considers [TestNode] lists as handled external
/// elements, so a resolved `Future` can deliver a `List` to
/// `attachFutureElement`.
class _ListHandlingGenerator extends TestGenerator {
  @override
  bool canHandleExternalElement(externalElement) =>
      super.canHandleExternalElement(externalElement) ||
      (externalElement is List && externalElement.every((e) => e is TestNode));
}

/// A marker object that is not a [TestNode].
class _Marker {
  final String label;

  _Marker(this.label);

  @override
  String toString() => label;
}

/// A [TestGenerator] that passes a resolved `Future` result through untouched
/// (not converted to [TestNode]) and knows how to add [_Marker] objects.
class _RawFutureGenerator extends TestGenerator {
  @override
  bool canHandleExternalElement(externalElement) =>
      externalElement is _Marker ||
      externalElement is List ||
      super.canHandleExternalElement(externalElement);

  @override
  Object? resolveElements(
    Object? elements, {
    DOMTreeMap<TestNode>? treeMap,
    DOMContext<TestNode>? context,
    bool setTreeMapRoot = true,
  }) {
    if (elements is _Marker || elements is List) return elements;
    return super.resolveElements(
      elements,
      treeMap: treeMap,
      context: context,
      setTreeMapRoot: setTreeMapRoot,
    );
  }

  @override
  List<TestNode>? addExternalElementToElement(
    TestNode element,
    Object? externalElement, {
    DOMTreeMap<TestNode>? treeMap,
    DOMContext<TestNode>? context,
  }) {
    if (externalElement is _Marker) {
      if (externalElement.label.isEmpty) return null;
      var b = TestElem('b')..add(TestText(externalElement.label));
      (element as TestElem).add(b);
      return [b];
    }
    return super.addExternalElementToElement(
      element,
      externalElement,
      treeMap: treeMap,
      context: context,
    );
  }
}

/// A [TestGenerator] that claims any [DOMElement] is type-equivalent.
class _LooseEquivalenceGenerator extends TestGenerator {
  @override
  bool isEquivalentNodeType(DOMNode domNode, TestNode node) => true;
}

/// A [TestGenerator] whose event subscription cancellation is asynchronous.
class _AsyncCancelGenerator extends TestGenerator {
  final List<Object> cancelled = [];

  @override
  FutureOr<bool> cancelEventSubscriptions(
    TestNode? element,
    List<Object> subscriptions,
  ) async {
    cancelled.addAll(subscriptions);
    return true;
  }
}

/// A [DOMNode] type unknown to [DOMGenerator.build].
class _UnknownNode extends DOMNode {
  _UnknownNode() : super();
}

void main() {
  group('DOMGenerator (platform factories)', () {
    test('web() on the VM is an unsupported generator', () {
      var web = DOMGenerator.web<TestNode>();
      expect(identical(web, DOMGenerator.web<TestNode>()), isTrue);
      expect(
        () => web.createElement('div'),
        throwsA(
          isA<UnsupportedError>().having(
            (e) => e.message,
            'message',
            contains('DOMGeneratorWeb'),
          ),
        ),
      );
    });

    test('dartHTML() on the VM is an unsupported generator', () {
      // ignore: deprecated_member_use_from_same_package
      var g = DOMGenerator.dartHTML<TestNode>();
      // ignore: deprecated_member_use_from_same_package
      expect(identical(g, DOMGenerator.dartHTML<TestNode>()), isTrue);
      expect(
        () => g.createElement('div'),
        throwsA(
          isA<UnsupportedError>().having(
            (e) => e.message,
            'message',
            contains('dart:html'),
          ),
        ),
      );
    });

    test('base node accessors throw when not overridden', () {
      var g = DOMGenerator.web<TestNode>();
      var e = TestElem('div');

      expect(() => g.getNodeParent(e), throwsUnsupportedError);
      expect(() => g.getElementNodes(e), throwsUnsupportedError);
      expect(() => g.getElementTag(e), throwsUnsupportedError);
      expect(() => g.getElementValue(e), throwsUnsupportedError);
      expect(() => g.getElementOuterHTML(e), throwsUnsupportedError);
      expect(() => g.getElementAttributes(e), throwsUnsupportedError);
    });
  });

  group('DOMGenerator.isEquivalentNode', () {
    test('TextNode equivalency compares the text', () {
      var g = TestGenerator();
      expect(g.isEquivalentNode(TextNode('a'), TestText('a')), isTrue);
      expect(g.isEquivalentNode(TextNode('a'), TestText('b')), isFalse);
    });

    test('a non-text type pair throws', () {
      var g = TestGenerator();
      expect(
        () => g.isEquivalentNode($div(), TestElem('div')),
        throwsUnsupportedError,
      );
    });

    test('a type-equivalent non-text pair throws', () {
      var g = _LooseEquivalenceGenerator();
      expect(
        () => g.isEquivalentNode($div(), TestElem('div')),
        throwsA(
          isA<UnsupportedError>().having(
            (e) => e.message,
            'message',
            contains("Can't determine node equivalency"),
          ),
        ),
      );
    });
  });

  group('DOMGenerator.build', () {
    test('unknown DOMNode type throws StateError', () {
      var g = TestGenerator();
      expect(() => g.generate(_UnknownNode()), throwsStateError);
    });

    test('svg element is created and attached to its parent', () {
      var g = TestGenerator();
      var treeMap = g.createDOMTreeMap();
      var svg = $tag('svg');
      var div = $div(content: [svg]);

      var root = g.generate(div, treeMap: treeMap) as TestElem;
      expect(root.nodesLength, equals(1));
      var svgElem = root.get(0) as TestElem;
      expect(svgElem.tag, equals('svg'));
      expect(svgElem.parent, same(root));
      expect(treeMap.getMappedElement(svg), same(svgElem));
      expect(treeMap.getMappedDOMNode(svgElem), same(svg));
    });
  });

  group('DOMGenerator.buildTemplate', () {
    TestElem genIn(
      TestGenerator g,
      DOMNode node,
      Map<String, dynamic> vars, {
      DOMTreeMap<TestNode>? treeMap,
    }) {
      var div = $div(content: [node]);
      return g.generate(
        div,
        treeMap: treeMap,
        context: DOMContext<TestNode>(variables: vars),
      ) as TestElem;
    }

    test('variable resolving to a DOMElement builds the element', () {
      var g = TestGenerator();
      var root = genIn(g, TemplateNode(DOMTemplate.parse('{{x}}')), {
        'x': $tag('b', content: 'bold'),
      });
      expect(root.nodesLength, equals(1));
      var b = root.get(0) as TestElem;
      expect(b.tag, equals('b'));
      expect(b.text, equals('bold'));
    });

    test('variable resolving to a TextNode builds text', () {
      var g = TestGenerator();
      var root = genIn(g, TemplateNode(DOMTemplate.parse('{{x}}')), {
        'x': TextNode('plain'),
      });
      expect(root.text, equals('plain'));
      expect(root.get(0), isA<TestText>());
    });

    test('several DOMNodes are wrapped in a span', () {
      var g = TestGenerator();
      var root = genIn(g, TemplateNode(DOMTemplate.parse('{{a}}{{b}}')), {
        'a': $tag('b', content: 'A'),
        'b': $tag('i', content: 'I'),
      });
      expect(root.nodesLength, equals(1));
      var span = root.get(0) as TestElem;
      expect(span.tag, equals('span'));
      expect(span.nodes.map((e) => (e as TestElem).tag), equals(['b', 'i']));
      expect(span.text, equals('AI'));
    });

    test('DOMNodes mixed with text are wrapped in a span', () {
      var g = TestGenerator();
      var root = genIn(g, TemplateNode(DOMTemplate.parse('pre {{a}}')), {
        'a': $tag('b', content: 'A'),
      });
      expect(root.nodesLength, equals(1));
      var span = root.get(0) as TestElem;
      expect(span.tag, equals('span'));
      expect(span.text, equals('pre A'));
      expect((span.nodes.last as TestElem).tag, equals('b'));
    });

    test('HTML that parses to a single text node is appended as text', () {
      var g = TestGenerator();
      var treeMap = g.createDOMTreeMap();
      var tpl = TemplateNode(DOMTemplate.parse('{{x}}'));
      var root = genIn(g, tpl, {'x': 'a &amp; b'}, treeMap: treeMap);
      expect(root.nodesLength, equals(1));
      var text = root.get(0) as TestText;
      expect(text.text, equals('a & b'));
      expect(treeMap.getMappedElement(tpl), same(text));
    });

    test('root template without parent creates a text node', () {
      var g = TestGenerator();
      var treeMap = g.createDOMTreeMap();
      var tpl = TemplateNode(DOMTemplate.parse('{{x}}'));
      var node = g.generate(
        tpl,
        treeMap: treeMap,
        context: DOMContext<TestNode>(variables: {'x': 'hello'}),
      );
      expect(node, isA<TestText>());
      expect(node!.text, equals('hello'));
      expect(treeMap.getMappedElement(tpl), same(node));
    });

    test('root template with a text-only HTML entity creates a text node', () {
      var g = TestGenerator();
      var tpl = TemplateNode(DOMTemplate.parse('{{x}}'));
      var node = g.generate(
        tpl,
        context: DOMContext<TestNode>(variables: {'x': 'x &lt; y'}),
      );
      expect(node, isA<TestText>());
      expect(node!.text, equals('x < y'));
    });
  });

  group('DOMGenerator external elements', () {
    test('a root external element of type T is mapped and returned', () {
      var g = TestGenerator();
      var treeMap = g.createDOMTreeMap();
      var p = TestElem('p')..add(TestText('ext'));
      var ext = ExternalElementNode(p);

      var node = g.generate(ext, treeMap: treeMap);
      expect(node, same(p));
      expect(p.parent, isNull);
      expect(treeMap.getMappedDOMNode(p), same(ext));
    });

    test('a List with one DOMNode returns that single element', () {
      var g = TestGenerator();
      var treeMap = g.createDOMTreeMap();
      var div = $div(
        content: [
          ExternalElementNode([
            [null, $tag('b', content: 'one')],
          ]),
        ],
      );
      var root = g.generate(div, treeMap: treeMap) as TestElem;
      expect(root.nodesLength, equals(1));
      expect((root.get(0) as TestElem).tag, equals('b'));
      expect(root.text, equals('one'));
    });

    test('a List with a commented DOMNode throws StateError', () {
      var g = TestGenerator();
      var commented = $tag('b', content: 'x')..commented = true;
      var div = $div(
        content: [
          ExternalElementNode([commented]),
        ],
      );
      expect(() => g.generate(div), throwsStateError);
    });

    test('a non-T object is generated from its HTML string', () {
      var g = TestGenerator();
      var div = $div(content: [ExternalElementNode(_Marker('<i>it</i>'))]);
      var root = g.generate(div) as TestElem;
      expect(root.nodesLength, equals(1));
      var i = root.get(0) as TestElem;
      expect(i.tag, equals('i'));
      expect(i.text, equals('it'));
    });

    test('a non-T object with blank string yields no element', () {
      var g = TestGenerator();
      var div = $div(content: [ExternalElementNode(_Marker('  '))]);
      var root = g.generate(div) as TestElem;
      expect(root.nodesLength, equals(0));
    });
  });

  group('DOMGenerator DOMAsync', () {
    test('DOMAsync without loading content inserts a template, then the '
        'resolved element', () async {
      var g = TestGenerator();
      var treeMap = g.createDOMTreeMap();
      var completer = Completer<Object?>();
      var async = DOMAsync(future: completer.future);
      var div = $div(content: [async]);

      var root = g.generate(div, treeMap: treeMap) as TestElem;
      expect(root.nodesLength, equals(1));
      expect((root.get(0) as TestElem).tag, equals('template'));

      completer.complete($tag('b', content: 'done'));
      await Future<void>.delayed(Duration.zero);

      // The template placeholder is replaced. (`TestGenerator` doesn't move
      // nodes like a real DOM, so the resolved node can appear twice.)
      expect(
        root.nodes.whereType<TestElem>().map((e) => e.tag),
        everyElement(equals('b')),
      );
      var b = root.get(0) as TestElem;
      expect(b.text, equals('done'));
      expect((treeMap.getMappedDOMNode(b) as DOMElement).tag, equals('b'));
    });

    test('DOMAsync loading with several nodes is wrapped in a div', () async {
      var g = TestGenerator();
      var completer = Completer<Object?>();
      var async = DOMAsync(
        loading: '<b>L1</b><i>L2</i>',
        future: completer.future,
      );
      var div = $div(content: [async]);

      var root = g.generate(div) as TestElem;
      expect(root.nodesLength, equals(1));
      var loading = root.get(0) as TestElem;
      expect(loading.tag, equals('div'));
      expect(loading.text, equals('L1L2'));

      completer.complete($tag('u', content: 'ok'));
      await Future<void>.delayed(Duration.zero);

      // The loading wrapper is replaced (see the note above about
      // `TestGenerator` not moving nodes).
      expect(root.nodes, isNot(contains(loading)));
      expect(
        root.nodes.whereType<TestElem>().map((e) => e.tag),
        everyElement(equals('u')),
      );
      expect(root.text, startsWith('ok'));
    });
  });

  group('DOMGenerator.attachFutureElement', () {
    test('a resolved List of elements replaces the template', () async {
      var g = _ListHandlingGenerator();
      var treeMap = g.createDOMTreeMap();
      var completer = Completer<Object?>();
      var ext = ExternalElementNode(completer.future);
      var div = $div(content: [ext]);

      var root = g.generate(div, treeMap: treeMap) as TestElem;
      expect(root.nodesLength, equals(1));
      expect((root.get(0) as TestElem).tag, equals('template'));

      var b = TestElem('b')..add(TestText('B'));
      var i = TestElem('i')..add(TestText('I'));
      completer.complete([b, i]);
      await Future<void>.delayed(Duration.zero);

      expect(root.nodes, equals([b, i]));
      expect(root.text, equals('BI'));

      // The DOMNode is mapped to a `display: contents` wrapper:
      var wrapper = treeMap.getMappedElement(ext) as TestElem;
      expect(wrapper.tag, equals('div'));
      expect(wrapper.attributes['style'], equals('display: contents'));
    });

    test('a raw resolved object is added through '
        'addExternalElementToElement', () async {
      var g = _RawFutureGenerator();
      var treeMap = g.createDOMTreeMap();
      var completer = Completer<Object?>();
      var ext = ExternalElementNode(completer.future);
      var div = $div(content: [ext]);

      var root = g.generate(div, treeMap: treeMap) as TestElem;
      expect((root.get(0) as TestElem).tag, equals('template'));

      completer.complete(_Marker('raw'));
      await Future<void>.delayed(Duration.zero);

      expect(root.nodesLength, equals(1));
      var b = root.get(0) as TestElem;
      expect(b.tag, equals('b'));
      expect(b.text, equals('raw'));
      expect(treeMap.getMappedElement(ext), same(b));
    });

    test('a raw nested List with one element replaces the template', () async {
      var g = _RawFutureGenerator();
      var treeMap = g.createDOMTreeMap();
      var completer = Completer<Object?>();
      var ext = ExternalElementNode(completer.future);
      var div = $div(content: [ext]);

      var root = g.generate(div, treeMap: treeMap) as TestElem;
      expect((root.get(0) as TestElem).tag, equals('template'));

      var b = TestElem('b')..add(TestText('one'));
      completer.complete([
        null,
        [null, b, 'not a node'],
      ]);
      await Future<void>.delayed(Duration.zero);

      expect(root.nodes, equals([b]));
      expect(treeMap.getMappedElement(ext), same(b));
    });

    test('a raw nested List without elements keeps the template', () async {
      var g = _RawFutureGenerator();
      var completer = Completer<Object?>();
      var div = $div(content: [ExternalElementNode(completer.future)]);

      var root = g.generate(div) as TestElem;
      var template = root.get(0) as TestElem;
      expect(template.tag, equals('template'));

      completer.complete([
        null,
        ['text only'],
      ]);
      await Future<void>.delayed(Duration.zero);

      expect(root.nodes, equals([template]));
    });

    test('a raw resolved object that adds nothing removes the '
        'template', () async {
      var g = _RawFutureGenerator();
      var completer = Completer<Object?>();
      var div = $div(content: [ExternalElementNode(completer.future)]);

      var root = g.generate(div) as TestElem;
      expect(root.nodesLength, equals(1));

      completer.complete(_Marker(''));
      await Future<void>.delayed(Duration.zero);

      expect(root.nodesLength, equals(0));
    });
  });

  group('DOMGenerator.toElements', () {
    test('null returns null', () {
      expect(TestGenerator().toElements(null), isNull);
    });

    test('commented DOMNode throws StateError', () {
      var node = $div()..commented = true;
      expect(() => TestGenerator().toElements(node), throwsStateError);
    });

    test('HTML String', () {
      var l = TestGenerator().toElements('<p>hi</p>')!;
      expect(l.length, equals(1));
      expect((l.first as TestElem).tag, equals('p'));
      expect(l.first.text, equals('hi'));
    });

    test('empty HTML String throws StateError', () {
      expect(() => TestGenerator().toElements(''), throwsStateError);
    });

    test('Function result is converted', () {
      var l = TestGenerator().toElements(() => '<b>fn</b>')!;
      expect(l.length, equals(1));
      expect((l.first as TestElem).tag, equals('b'));
      expect(l.first.text, equals('fn'));
    });

    test('Iterable skips null entries and flattens', () {
      var e = TestElem('em');
      var l = TestGenerator().toElements([
        null,
        e,
        [$tag('b', content: 'x')],
      ])!;
      expect(l.length, equals(2));
      expect(l.first, same(e));
      expect((l[1] as TestElem).tag, equals('b'));
    });

    test('other objects are converted through their HTML string', () {
      var l = TestGenerator().toElements(_Marker('<i>m</i>'))!;
      expect(l.length, equals(1));
      expect((l.first as TestElem).tag, equals('i'));
      expect(l.first.text, equals('m'));
    });

    test('other objects with a blank string return null', () {
      expect(TestGenerator().toElements(_Marker('   ')), isNull);
    });
  });

  group('DOMNodeRuntime', () {
    late TestGenerator g;
    late DOMTreeMap<TestNode> treeMap;
    late DOMElement div;
    late TestElem root;

    setUp(() {
      g = TestGenerator();
      div = $div(
        content: [
          $tag('b', content: 'B', style: 'color: red; width: 10px'),
          $tag('i', content: 'I'),
        ],
      );
      treeMap = g.generateMapped(div);
      root = treeMap.rootElement as TestElem;
    });

    DOMNodeRuntime<TestNode> rt(int index) =>
        (div.content![index] as DOMElement).getRuntime<TestNode>();

    test('parent, exists and attribute operators', () {
      var b = rt(0);
      expect(b.parent, same(root));
      expect(b.exists, isTrue);

      b['title'] = 'T';
      expect(b['title'], equals('T'));
      b['title'] = null;
      expect(b['title'], equals(''));
    });

    test('style accessors', () {
      var b = rt(0);
      expect(b.style.getAsString('color'), equals('red'));
      expect(b.getStyleEntry('width')!.valueAsString, equals('10px'));
      expect(b.getStyleProperty('color'), equals('red'));
      expect(b.getStyleProperty('height'), isNull);

      expect(b.setStyleProperty('color', 'blue'), equals('red'));
      expect(b.getStyleProperty('color'), equals('blue'));

      b.setStyleProperties({'height': '5px', 'margin': '1px'});
      expect(b.getStyleProperty('height'), equals('5px'));
      expect(b.getStyleProperty('margin'), equals('1px'));

      expect(b.removeStyleProperty('height'), equals('5px'));
      expect(b.getStyleProperty('height'), isNull);
      expect(b.removeStyleEntry('nope'), isNull);

      expect(b.removeStyleEntries([]), isEmpty);
      expect(
        b.removeStyleProperties(['margin', 'width', 'nope']),
        equals({'margin': '1px', 'width': '10px'}),
      );
      expect(b.getStyleProperty('width'), isNull);
      expect(b.getStyleProperty('color'), equals('blue'));

      b.style = 'color: green';
      expect(b.getStyleProperty('color'), equals('green'));
      expect(b.getStyleProperty('width'), isNull);
    });

    test('isConsecutiveNode', () {
      var b = rt(0);
      var i = rt(1);
      expect(b.isConsecutiveNode(i.node!), isTrue);
      expect(i.isConsecutiveNode(b.node!), isTrue);
      expect(b.isConsecutiveNode(TestElem('x')), isFalse);
    });

    test('mergeNode with the previous node merges into it', () {
      var b = rt(0);
      var i = rt(1);
      var bElem = b.node as TestElem;
      var iElem = i.node as TestElem;

      expect(i.mergeNode(bElem), isTrue);
      // `b` absorbed `i`'s contents and `i` was removed from the parent:
      expect(root.nodes, equals([bElem]));
      expect(bElem.text, equals('BI'));
      expect(iElem.nodesLength, equals(0));
    });

    test('moveUp over a leading text node', () {
      var g = TestGenerator();
      var parent = TestElem('div');
      var text = TestText('t');
      var b = TestElem('b');
      parent
        ..add(text)
        ..add(b);
      var r = TestNodeRuntime(g.createDOMTreeMap(), null, b);

      expect(r.moveUp(), isTrue);
      expect(parent.nodes, equals([b, text]));
    });

    test('moveDown over a trailing text node', () {
      var g = TestGenerator();
      var parent = TestElem('div');
      var b = TestElem('b');
      var text = TestText('t');
      parent
        ..add(b)
        ..add(text);
      var r = TestNodeRuntime(g.createDOMTreeMap(), null, b);

      expect(r.moveDown(), isTrue);
      expect(parent.nodes, equals([text, b]));
    });
  });

  group('DOMNodeRuntimeDummy', () {
    test('a node without treeMap has a no-op dummy runtime', () {
      var dom = $div(content: 'x');
      var r = dom.runtime;
      expect(r, isA<DOMNodeRuntimeDummy>());
      expect(r.domNode, same(dom));
      expect(r.node, isNull);
      expect(r.exists, isFalse);
      expect(r.treeMap, isA<DOMTreeMapDummy>());
      expect(r.domGenerator, isA<DOMGeneratorDummy>());

      expect(r.tagName, isNull);
      expect(r.classes, isEmpty);
      r.addClass('a');
      expect(r.removeClass('a'), isFalse);
      r.clearClasses();
      expect(r.classes, isEmpty);

      expect(r.text, equals(''));
      r.text = 'abc';
      expect(r.text, equals(''));
      expect(r.value, equals(''));
      r.value = 'v';
      expect(r.value, equals(''));

      r.setAttribute('id', 'x');
      expect(r.getAttribute('id'), isNull);
      r.removeAttribute('id');
      expect(r['id'], isNull);

      expect(r.children, isEmpty);
      expect(r.nodesLength, equals(0));
      expect(r.getNodeAt(0), isNull);
      r.add(Object());
      r.insertAt(0, Object());
      expect(r.nodesLength, equals(0));
      expect(r.indexOf(Object()), equals(-1));
      expect(r.indexInParent, equals(-1));
      expect(r.removeNode(Object()), isFalse);
      expect(r.removeAt(0), isNull);
      r.clear();
      expect(r.copy(), isNull);
      expect(r.absorbNode(Object()), isFalse);
      expect(r.isStringElement, isFalse);
    });
  });

  group('DOMTreeMap', () {
    test('getElementDOMTreeMap', () {
      var g = TestGenerator();
      expect(DOMTreeMap.getElementDOMTreeMap<TestNode>(null), isNull);

      var treeMap = g.generateMapped($div(content: [$tag('b')]));
      var root = treeMap.rootElement!;
      expect(DOMTreeMap.getElementDOMTreeMap<TestNode>(root), same(treeMap));
      expect(
        DOMTreeMap.getElementDOMTreeMap<TestNode>(TestElem('unmapped')),
        isNull,
      );
    });

    test('re-mapping the same pair reclaims the DOMNode treeMap', () {
      var g = TestGenerator();
      var a = g.createDOMTreeMap();
      var b = g.createDOMTreeMap();
      var dom = $div();
      var elem = TestElem('div');

      a.map(dom, elem);
      expect(dom.treeMap, same(a));
      b.map(dom, elem);
      expect(dom.treeMap, same(b));
      expect(DOMTreeMap.getElementDOMTreeMap<TestNode>(elem), same(b));

      a.map(dom, elem);
      expect(dom.treeMap, same(a));
      expect(DOMTreeMap.getElementDOMTreeMap<TestNode>(elem), same(a));
    });

    test('mapping an element to a different DOMNode keeps the first '
        'mapping', () {
      var g = TestGenerator();
      var treeMap = g.createDOMTreeMap();
      var dom1 = $div();
      var dom2 = $div();
      var elem = TestElem('div');

      treeMap.map(dom1, elem);
      treeMap.map(dom2, elem);

      expect(treeMap.getMappedDOMNode(elem), same(dom1));
      expect(dom2.treeMap, same(treeMap));
    });

    test('lookups with checkParents and asMapped*', () {
      var g = TestGenerator();
      var treeMap = g.createDOMTreeMap();

      var span = $span();
      var div = $div(content: [span]);
      var divElem = TestElem('div');
      var spanElem = TestElem('span');
      divElem.add(spanElem);

      treeMap.map(div, divElem);

      expect(treeMap.getMappedElement(span), isNull);
      expect(treeMap.getMappedElement(span, checkParents: true), same(divElem));
      expect(treeMap.getMappedElement($p(), checkParents: true), isNull);

      expect(treeMap.getMappedDOMNode(spanElem), isNull);
      expect(treeMap.getMappedDOMNode(spanElem, checkParents: true), same(div));

      expect(treeMap.asMappedDOMNode(null), isNull);
      expect(treeMap.asMappedDOMNode(div), same(div));
      expect(treeMap.asMappedDOMNode(span), same(div));
      expect(treeMap.asMappedDOMNode($p()), isNull);

      expect(treeMap.asMappedElement(null), isNull);
      expect(treeMap.asMappedElement(divElem), same(divElem));
      expect(treeMap.asMappedElement(spanElem), same(divElem));
      expect(treeMap.asMappedElement(TestElem('p')), isNull);
    });

    test('domElementsWithEventListener on an empty map', () {
      var treeMap = TestGenerator().createDOMTreeMap();
      expect(treeMap.domElementsWithEventListener(), isEmpty);
    });

    test('cancelSubscriptions with an async generator', () async {
      var g = _AsyncCancelGenerator();
      var treeMap = g.createDOMTreeMap();
      var elem = TestElem('div');
      treeMap.mapSubscriptions(elem, ['s1', 's2']);

      var r = treeMap.cancelSubscriptions(elem);
      expect(r, isA<Future>());
      expect(await r, equals(['s1', 's2']));
      expect(g.cancelled, equals(['s1', 's2']));
      expect(treeMap.getSubscriptions(elem), isEmpty);
    });

    test('mergeNearStringNodes with the nodes in reverse order', () {
      var g = TestGenerator();
      var u1 = $tag('u', content: 'A');
      var u2 = $tag('u', content: 'B');
      var div = $div(content: [u1, u2]);
      var treeMap = g.generateMapped(div);
      var root = treeMap.rootElement as TestElem;

      var merged = treeMap.mergeNearStringNodes(u2, u1)!;
      expect(merged.domNode, same(u1));
      expect(merged.node.text, equals('AB'));
      expect(merged.domGenerator, same(g));
      expect(div.buildHTML(), equals('<div><u>AB</u></div>'));
      expect(root.nodesLength, equals(1));
      expect(treeMap.isMappedDOMNode(u2), isFalse);
    });

    test('regexpTagRef matches tag references', () {
      var m = DOMTreeMap.regexpTagRef.firstMatch('x {{ div#main }} y')!;
      expect(m.group(1), equals('div'));
      expect(m.group(2), equals('main'));
      expect(DOMTreeMap.regexpTagRef.hasMatch('{{*#id-1}}'), isTrue);
      expect(DOMTreeMap.regexpTagRef.hasMatch('{{div}}'), isFalse);
    });

    test('DSX event attributes are managed and disposed', () async {
      var clicks = 0;
      var nodes = $dsx(
        '<button onclick="${(() => clicks++).dsx()}">B</button>',
      );
      var button = nodes.single as DOMElement;
      expect(button.resolvedDSXs(), isNotEmpty);
      var dsx = button.resolvedDSXs().first;

      var g = TestGenerator();
      var treeMap = g.generateMapped(button);
      expect(treeMap.isManagedDSX(dsx), isTrue);
      expect(treeMap.domElementsWithEventListener(), equals([button]));

      treeMap.dispose();
      expect(treeMap.isDisposed, isTrue);
      expect(treeMap.isManagedDSX(dsx), isFalse);
      expect(treeMap.rootDOMNode, isNull);
    });
  });
}
