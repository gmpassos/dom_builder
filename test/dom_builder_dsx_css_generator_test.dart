import 'dart:async';

import 'package:dom_builder/dom_builder.dart';
import 'package:dom_builder/src/dom_builder_generator_none.dart';
import 'package:dom_builder/src/dom_builder_html_generic.dart';
import 'package:html/dom.dart' as html_dom;
import 'package:test/test.dart';

import 'dom_builder_domtest.dart';

/// Tests for the platform-agnostic core: [DOMGenerator] (generic, delegate,
/// dummy and unsupported), DSX, CSS, templates, [DOMContext], [DOMAction]s,
/// [DOMTreeMap] and the generic (`package:html`) [DOMHtml].

class _LogActionExecutor extends DOMActionExecutor<TestNode> {
  final List<String> log = [];

  @override
  TestNode? selectByID(
    String id,
    TestNode? target,
    TestNode? self,
    DOMTreeMap? treeMap,
    DOMContext? context,
  ) {
    log.add('select:$id');
    return TestElem('div')..attributes['id'] = id;
  }

  @override
  TestNode? callShow(TestNode? target) {
    log.add('show');
    return target;
  }

  @override
  TestNode? callHide(TestNode? target) {
    log.add('hide');
    return target;
  }

  @override
  TestNode? callRemove(TestNode? target) {
    log.add('remove');
    return target;
  }

  @override
  TestNode? callClear(TestNode? target) {
    log.add('clear');
    return target;
  }

  @override
  TestNode? callAddClass(TestNode? target, List<String> classes) {
    log.add('addClass:${classes.join(',')}');
    return target;
  }

  @override
  TestNode callRemoveClass(TestNode target, List<String> classes) {
    log.add('removeClass:${classes.join(',')}');
    return target;
  }

  @override
  TestNode? callSetClass(TestNode? target, List<String> classes) {
    log.add('setClass:${classes.join(',')}');
    return target;
  }

  @override
  TestNode? callClearClass(TestNode? target) {
    log.add('clearClass');
    return target;
  }

  @override
  TestNode? callLocale(
    TestNode? target,
    List<String> parameters,
    DOMContext? context,
  ) {
    log.add('locale:${parameters.join(',')}');
    return target;
  }
}

class _BareActionExecutor extends DOMActionExecutor<TestNode> {}

class _DSXValueHolder {
  final String value;

  _DSXValueHolder(this.value);

  String toDSXValue() => 'holder:$value';
}

class _DSXTypeObj extends DSXType<String> {
  @override
  DSX<String> toDSX() => DSX<String>('dsx-type', 'dsx-type-value');
}

class _Lifecycle implements DSXLifecycleManager {
  final Set<DSX> managed = {};

  @override
  bool isManagedDSX(DSX<Object> dsx) => managed.contains(dsx);

  @override
  bool manageDSX(DSX<Object> dsx) => managed.add(dsx);

  @override
  bool disposeDSX(DSX<Object> dsx) => managed.remove(dsx);

  @override
  int disposeManagedDSXs() {
    var n = managed.length;
    managed.clear();
    return n;
  }
}

int _sum(int a, int b) => a + b;

TestElem _elem(TestNode? node) => node as TestElem;

void main() {
  group('DOMGenerator (generic)', () {
    test('generate() with the default generic tree map', () {
      var generator = TestGenerator();
      var root = $div(
        classes: 'c',
        content: [
          $span(content: 'a'),
          'b',
        ],
      );

      var elem = _elem(generator.generate(root));
      expect(elem.tag, equals('div'));
      expect(elem.attributes['class'], equals('c'));
      expect(elem.text, equals('ab'));
      expect(elem.nodesLength, equals(2));

      // The generic tree map is a dummy (doesn't map):
      var dummy = generator.createGenericDOMTreeMap();
      expect(dummy, isA<DOMTreeMapDummy>());
      expect(identical(dummy, generator.createGenericDOMTreeMap()), isTrue);
      expect(dummy.getMappedElement(root), isNull);
    });

    test('generate() into a parent', () {
      var generator = TestGenerator();
      var parent = TestElem('section');

      var elem = generator.generate($p(content: 'x'), parent: parent);
      expect(parent.nodesLength, equals(1));
      expect(identical(parent.get(0), elem), isTrue);
      expect(generator.getNodeParent(elem), same(parent));
      expect(generator.getNodeParentsUntilRoot(elem), equals([parent]));
    });

    test('generateWithRoot()', () {
      var generator = TestGenerator();
      var treeMap = generator.createDOMTreeMap();

      var domRoot = $div(id: 'root');
      var rootElement = generator.generateWithRoot(domRoot, null, [
        $span(content: 'a'),
        TextNode('b'),
      ], treeMap: treeMap);

      var root = _elem(rootElement);
      expect(root.attributes['id'], equals('root'));
      expect(root.text, equals('ab'));
      expect(domRoot.content!.length, equals(2));
      expect(treeMap.rootDOMNode, same(domRoot));
      expect(treeMap.rootElement, same(root));

      // Existing root element + parent:
      var rootParent = TestElem('main');
      var root2 = TestElem('div');
      var dom2 = $div();
      treeMap.map(dom2, root2);
      generator.generateWithRoot(
        dom2,
        root2,
        [$b(content: 'x')],
        treeMap: treeMap,
        rootParent: rootParent,
        setTreeMapRoot: false,
      );
      expect(rootParent.nodesLength, equals(1));
      expect(root2.text, equals('x'));

      expect(
        () => generator.generateWithRoot(null, null, []),
        throwsStateError,
      );
    });

    test('generateFromHTML()', () {
      var generator = TestGenerator();

      var p = _elem(generator.generateFromHTML('<p class="x">Hello</p>'));
      expect(p.tag, equals('p'));
      expect(p.attributes['class'], equals('x'));
      expect(p.text, equals('Hello'));

      // Into a mapped parent:
      var domParent = $div();
      var treeMap = generator.generateMapped(domParent);
      var parent = _elem(treeMap.rootElement);
      TestElem('body').add(parent);

      generator.generateFromHTML(
        '<b>1</b><i>2</i>',
        treeMap: treeMap,
        domParent: domParent,
        parent: parent,
      );
      expect(parent.text, equals('12'));
      expect(parent.nodesLength, equals(2));
      expect(domParent.content!.length, equals(2));
    });

    // Regression: without a `domParent` or a mapped `parent`,
    // `generateWithRoot` crashed with a null-check on `domRoot`.
    test('generateFromHTML() into an unmapped parent', () {
      var generator = TestGenerator();
      var parent = TestElem('div');
      var root = generator.generateFromHTML('<b>1</b><i>2</i>', parent: parent);
      expect(root, same(parent));
      expect(parent.text, equals('12'));
      expect(parent.nodesLength, equals(2));
    });

    test('generateNodes()', () {
      var generator = TestGenerator();
      var nodes = generator.generateNodes([
        $span(content: 'a'),
        $b(content: 'b'),
      ]);
      expect(nodes.map((e) => (e as TestElem).tag), equals(['span', 'b']));
    });

    test('generateMapped() + revert()', () {
      var generator = TestGenerator();
      var root = $div(
        attributes: {'title': 't'},
        content: [$span(content: 'text')],
      );

      var treeMap = generator.generateMapped(root);
      var elem = _elem(treeMap.rootElement);
      expect(treeMap.getMappedDOMNode(elem), same(root));
      expect(treeMap.isMappedElement(elem), isTrue);
      expect(treeMap.isMappedDOMNode(root), isTrue);

      var reverted = generator.revert(treeMap, elem) as DOMElement;
      expect(reverted.tag, equals('div'));
      expect(reverted.getAttributeValue('title'), equals('t'));
      expect(reverted.buildHTML(), contains('text'));

      expect(generator.revert(treeMap, null), isNull);
    });

    test('element accessors', () {
      var generator = TestGenerator();
      var elem = _elem(
        generator.generate($input(attributes: {'value': 'v1'}, classes: 'k')),
      );

      expect(generator.getElementTag(elem), equals('input'));
      // `TestGenerator.getElementValue` returns the node text:
      expect(generator.getElementValue(elem), equals(''));
      expect(generator.getElementValue(null), isNull);
      expect(generator.getElementAttributes(elem)!['class'], equals('k'));
      expect(generator.getElementOuterHTML(elem), contains('<input'));
      expect(generator.isElementNode(elem), isTrue);
      expect(generator.isElementNode(null), isFalse);
      expect(generator.isTextNode(TestText('x')), isTrue);
      expect(generator.equalsNodes(elem, elem), isTrue);
      expect(generator.equalsNodes(elem, null), isFalse);
      expect(generator.equalsNodes(TestText('a'), TestText('b')), isFalse);
      expect(
        generator.revertElementAttributes(elem, {'a': 'b'}),
        equals({'a': 'b'}),
      );
    });

    test('equivalence and ignored attributes', () {
      var generator = TestGenerator();

      expect(generator.isEquivalentNode(TextNode('a'), TestText('a')), isTrue);
      expect(generator.isEquivalentNode(TextNode('a'), TestText('b')), isFalse);
      expect(
        generator.isEquivalentNodeType(TextNode('a'), TestText('z')),
        isTrue,
      );
      // The base implementation only knows how to compare text nodes:
      expect(
        () => generator.isEquivalentNodeType(TextNode('a'), TestElem('p')),
        throwsUnsupportedError,
      );
      expect(
        () => generator.isEquivalentNode($div(), TestElem('div')),
        throwsUnsupportedError,
      );

      expect(generator.isIgnoreAttributeEquivalence('data-x'), isFalse);
      generator.ignoreAttributeEquivalence('data-x');
      generator.ignoreAttributeEquivalence('data-y');
      expect(generator.isIgnoreAttributeEquivalence('data-x'), isTrue);
      expect(
        generator.getIgnoredAttributesEquivalence(),
        containsAll(['data-x', 'data-y']),
      );
      expect(generator.removeIgnoredAttributeEquivalence('data-x'), isTrue);
      expect(generator.removeIgnoredAttributeEquivalence('data-x'), isFalse);
      generator.clearIgnoredAttributesEquivalence();
      expect(generator.getIgnoredAttributesEquivalence(), isEmpty);
    });

    test('registered ElementGenerators', () {
      var generator = TestGenerator();
      expect(generator.isElementGeneratorTag('tag-x'), isFalse);
      expect(generator.isElementGeneratorTag(null), isFalse);
      expect(
        generator.registerElementGenerator(TestNodeGenerator(' ', 'c')),
        isFalse,
      );

      expect(
        generator.registerElementGenerator(TestNodeGenerator('Tag-X', 'gx')),
        isTrue,
      );
      expect(generator.isElementGeneratorTag('tag-x'), isTrue);
      expect(generator.isElementGeneratorTag(' TAG-X '), isTrue);
      expect(generator.registeredElementsGeneratorsLength, equals(1));
      expect(generator.registeredElementsGenerators.keys, equals(['tag-x']));

      var elem = _elem(
        generator.generate(
          DOMElement('tag-x', classes: 'user', content: 'inner'),
        ),
      );
      expect(elem.tag, equals('tag-x'));
      expect(elem.attributes['class'], equals('gx user'));
      expect(elem.text, equals('inner'));

      var other = TestGenerator();
      expect(other.registerElementGeneratorFrom(TestGenerator()), isFalse);
      expect(other.registerElementGeneratorFrom(generator), isTrue);
      expect(other.isElementGeneratorTag('tag-x'), isTrue);

      expect(DOMGenerator.normalizeTag(' DiV '), equals('div'));
      expect(DOMGenerator.normalizeTag('  '), isNull);
      expect(DOMGenerator.normalizeTag(null), isNull);
    });

    test('ElementGeneratorFunctions', () {
      var generator = TestGenerator();

      var reverted = <String>[];
      var functions = ElementGeneratorFunctions<TestNode>(
        'fn-tag',
        (
          domGenerator,
          tag,
          parent,
          attributes,
          contentHolder,
          contentNodes,
          context,
        ) {
          return TestElem('div')
            ..attributes['data-tag'] = tag ?? ''
            ..attributes['data-n'] = '${contentNodes?.length ?? 0}'
            ..add(TestText(contentHolder?.text));
        },
        reverter: (domGenerator, treeMap, domParent, parent, node) {
          reverted.add('reverted');
          return DOMElement('fn-tag');
        },
        usesContentHolder: true,
        hasChildrenElements: false,
      );

      expect(functions.tag, equals('fn-tag'));
      expect(functions.hasChildrenElements, isFalse);
      expect(functions.usesContentHolder, isTrue);
      expect(functions.isGeneratedElement(TestElem('div')), isFalse);

      generator.registerElementGenerator(functions);

      var elem = _elem(
        generator.generate(
          DOMElement(
            'fn-tag',
            content: [
              'a',
              $b(content: 'b'),
            ],
          ),
        ),
      );
      expect(elem.attributes['data-tag'], equals('fn-tag'));
      expect(elem.attributes['data-n'], equals('2'));
      expect(elem.text, equals('ab'));

      var dom = functions.revert(generator, null, null, null, elem);
      expect(dom.tag, equals('fn-tag'));
      expect(reverted, equals(['reverted']));
    });

    test('sourceResolver', () {
      var generator = TestGenerator();
      expect(generator.resolveSource('a.png'), equals('a.png'));
      generator.sourceResolver = (url) => 'https://cdn/$url';
      expect(generator.resolveSource('a.png'), equals('https://cdn/a.png'));
    });

    test('populateGeneratedHTMLTrees / reset', () {
      var generator = TestGenerator();
      var treeMap = generator.createDOMTreeMap();

      generator.populateGeneratedHTMLTrees = true;
      generator.generate($p(content: 'x'), treeMap: treeMap);
      expect(generator.generatedHTMLTrees.single, contains('<p>'));

      generator.reset();
      expect(generator.generatedHTMLTrees, isEmpty);
    });

    test('domContext / domActionExecutor setters link the generator', () {
      var generator = TestGenerator();
      expect(generator.viewport, isNull);

      var context = DOMContext<TestNode>(viewport: Viewport(100, 50));
      generator.domContext = context;
      expect(context.domGenerator, same(generator));
      expect(generator.viewport, equals(Viewport(100, 50)));

      var executor = _LogActionExecutor();
      generator.domActionExecutor = executor;
      expect(executor.domGenerator, same(generator));

      generator.domContext = null;
      generator.domActionExecutor = null;
      expect(generator.domContext, isNull);
      expect(generator.domActionExecutor, isNull);
    });

    test(
      'context callbacks: preFinalizeGeneratedTree / onPreElementCreated',
      () {
        var generator = TestGenerator();
        var created = <String>[];
        var finalized = 0;

        var context = DOMContext<TestNode>()
          ..onPreElementCreated = (treeMap, domElement, element, context) {
            if (domElement is DOMElement) created.add(domElement.tag);
          }
          ..preFinalizeGeneratedTree = (treeMap) => finalized++;

        generator.generate($div(content: [$span(), $b()]), context: context);

        expect(created, containsAll(['div', 'span', 'b']));
        expect(finalized, equals(1));

        generator.generate($div(), context: context, finalizeTree: false);
        expect(finalized, equals(1));
      },
    );

    test('DOMAsync with future and loading content', () async {
      var generator = TestGenerator();
      var completer = Completer<Object?>();

      var root = $div(
        content: [DOMAsync(loading: 'loading...', future: completer.future)],
      );

      var elem = _elem(generator.generate(root));
      expect(elem.text, equals('loading...'));

      completer.complete($span(content: 'done'));
      await Future<void>.delayed(Duration(milliseconds: 20));

      // The loading placeholder is replaced. (`TestGenerator` doesn't move
      // nodes like a real DOM, so the resolved node can appear twice.)
      expect(elem.text, isNot(contains('loading')));
      expect(elem.text, startsWith('done'));
    });

    test('DOMAsync with a function', () async {
      var generator = TestGenerator();

      var root = $div(
        content: [
          DOMAsync(
            loading: $span(content: 'wait'),
            function: () async => 'fn result',
          ),
        ],
      );

      var elem = _elem(generator.generate(root));
      expect(elem.text, equals('wait'));

      await Future<void>.delayed(Duration(milliseconds: 20));
      expect(elem.text, isNot(contains('wait')));
      expect(elem.text, startsWith('fn result'));
    });
  });

  group('DOMGenerator: external elements, templates, attributes', () {
    TestElem gen(TestGenerator generator, List<Object> content) =>
        _elem(generator.generate($div(content: content)));

    test('external elements of many kinds', () {
      var generator = TestGenerator();

      expect(
        gen(generator, [ExternalElementNode('<i>x</i>')]).text,
        equals('x'),
      );
      expect(
        gen(generator, [
          ExternalElementNode(<Object?>[
            $b(content: '1'),
            [$tag('i', content: '2')],
            null,
          ]),
        ]).text,
        // Wrapped in a `display: contents` div. (`TestGenerator` doesn't move
        // nodes like a real DOM, so the nodes also stay in the parent.)
        endsWith('12'),
      );
      expect(
        gen(generator, [ExternalElementNode(() => $span(content: 'fn'))]).text,
        equals('fn'),
      );
      expect(
        gen(generator, [
          ExternalElementNode((Object? parent) => $span(content: 'gen')),
        ]).text,
        equals('gen'),
      );
      expect(
        gen(generator, [
          ExternalElementNode(TestElem('p')..add(TestText('t'))),
        ]).text,
        equals('t'),
      );
      expect(
        gen(generator, [ExternalElementNode(TestText('tt'))]).text,
        equals('tt'),
      );
      expect(
        gen(generator, [ExternalElementNode($tag('u', content: 'dom'))]).text,
        equals('dom'),
      );
      expect(gen(generator, [ExternalElementNode('  ')]).nodesLength, 0);
      expect(gen(generator, [ExternalElementNode(<Object?>[])]).nodesLength, 0);
    });

    test('external Future element', () async {
      var generator = TestGenerator();
      var completer = Completer<Object?>();
      var elem = gen(generator, [ExternalElementNode(completer.future)]);
      expect(elem.nodesLength, equals(1));
      expect((elem.get(0) as TestElem).tag, equals('template'));

      completer.complete(TestElem('b')..add(TestText('late')));
      await Future<void>.delayed(Duration(milliseconds: 20));
      expect(elem.text, equals('late'));
    });

    test('resolveElements / toElements / wrapElements', () {
      var generator = TestGenerator();

      var single = generator.resolveElements($span(content: 's'));
      expect(single, isA<TestElem>());

      var list = generator.resolveElements([$b(), $tag('i')]);
      expect(list, isA<List>());
      expect((list as List).length, equals(2));

      expect(generator.resolveElements(null), isNull);
      expect(generator.resolveElements(<Object>[]), isNull);

      var wrap = _elem(generator.wrapElements([TestElem('a'), TestElem('b')]));
      expect(wrap.tag, equals('div'));
      expect(wrap.attributes['style'], equals('display: contents'));
      expect(wrap.nodesLength, equals(2));
      expect(generator.wrapElements([]), isNull);
      expect(generator.wrapElements(null), isNull);
    });

    test('replaceElement', () {
      var generator = TestGenerator();
      var parent = TestElem('div');
      var a = TestElem('a');
      parent.add(a);

      expect(
        generator.replaceElement(a, [TestElem('b'), TestElem('c')]),
        isTrue,
      );
      expect(parent.nodes.map((e) => (e as TestElem).tag), equals(['b', 'c']));
      expect(generator.replaceElement(null, []), isFalse);
      expect(generator.replaceElement(TestElem('x'), null), isFalse);
    });

    test('isNodeInDOM', () {
      var generator = TestGenerator();
      var body = TestElem('body');
      var div = TestElem('div');
      body.add(div);
      var text = TestText('t');
      div.add(text);

      expect(generator.isNodeInDOM(div), isTrue);
      expect(generator.isNodeInDOM(text), isTrue);
      expect(generator.isNodeInDOM(body), isFalse);

      var detached = TestElem('section')..add(TestElem('p'));
      expect(generator.isNodeInDOM(detached.get(0)), isFalse);
    });

    test('templates with context variables', () {
      var generator = TestGenerator();
      var context = DOMContext<TestNode>(
        variables: {'name': 'Joe', 'bold': true},
        intlMessageResolver: (k, [p]) => k == 'hi' ? 'Hello' : null,
      );

      TestElem genTemplate(String template) => _elem(
        generator.generate(
          $div(content: [TemplateNode(DOMTemplate.parse(template))]),
          context: context,
        ),
      );

      expect(genTemplate('Hi {{name}}!').text, equals('Hi Joe!'));
      expect(genTemplate('{{intl:hi}}, {{name}}').text, equals('Hello, Joe'));

      var bold = genTemplate('{{:bold}}<b>B</b>{{/}}');
      expect((bold.get(0) as TestElem).tag, equals('b'));
      expect(bold.text, equals('B'));

      var html = genTemplate('<i>{{name}}</i> and <u>x</u>');
      expect(html.text, equals('Joe and x'));

      var empty = genTemplate('{{:missing}}x{{/}}');
      expect(empty.text, equals(''));

      // Without a context:
      var noContext = _elem(
        generator.generate(
          $div(content: [TemplateNode(DOMTemplate.parse('[{{name}}]'))]),
        ),
      );
      expect(noContext.text, equals('[]'));
    });

    test('attributes: src/href resolution, class/style, booleans', () {
      var generator = TestGenerator()
        ..sourceResolver = (u) => u.startsWith('/') ? u : '/static/$u';

      var img = _elem(generator.generate($img(src: 'a.png')));
      expect(img.attributes['src'], equals('/static/a.png'));
      expect(img.attributes['src-original'], equals('a.png'));

      var link = _elem(generator.generate($a(href: '/abs')));
      expect(link.attributes['href'], equals('/abs'));
      expect(link.attributes.containsKey('href-original'), isFalse);

      var treeMap = generator.createDOMTreeMap();
      var element = TestElem('div')
        ..attributes['class'] = 'a'
        ..attributes['style'] = 'color: red';
      var domElement = $div(classes: 'b', style: 'width: 1px');

      expect(
        generator.resolveAttributeValue(
          domElement,
          element,
          'class',
          treeMap,
          preserveClass: true,
        ),
        equals('a b'),
      );
      expect(
        generator.resolveAttributeValue(
          domElement,
          element,
          'style',
          treeMap,
          preserveStyle: true,
        ),
        equals('color: red; width: 1px'),
      );
      element.attributes['style'] = 'color: red;';
      expect(
        generator.resolveAttributeValue(
          domElement,
          element,
          'style',
          treeMap,
          preserveStyle: true,
        ),
        equals('color: red; width: 1px'),
      );

      generator.setAttributes(
        domElement,
        element,
        treeMap,
        preserveClass: true,
        preserveStyle: true,
      );
      expect(element.attributes['class'], equals('a b'));
      expect(element.attributes['style'], contains('width: 1px'));

      // A `false` boolean attribute resolves to `null` (to be removed):
      var input = TestElem('input');
      expect(
        generator.resolveAttributeValue(
          INPUTElement(attributes: {'checked': false}),
          input,
          'checked',
          treeMap,
        ),
        isNull,
      );
      expect(
        generator.resolveAttributeValue(
          INPUTElement(attributes: {'checked': true}),
          input,
          'checked',
          treeMap,
        ),
        equals('true'),
      );
    });

    test('action attribute executes a DOMAction on click/change', () async {
      var generator = TestGenerator();
      var executor = _LogActionExecutor();
      generator.domActionExecutor = executor;

      var button = $button(attributes: {'action': 'show()'});
      var input = $input(attributes: {'action': 'hide()'});
      var form = DOMElement('form', attributes: {'action': '/submit'});
      var treeMap = generator.generateMapped(
        $div(content: [button, input, form]),
      );
      expect(treeMap.rootElement, isNotNull);

      button.onClick.add(DOMMouseEvent.synthetic());
      input.onChange.add(DOMEvent(treeMap, null, null, input));
      await Future<void>.delayed(Duration(milliseconds: 10));

      expect(executor.log, containsAll(['show', 'hide']));
    });
  });

  group('DOMGeneratorDelegate', () {
    test('delegates generation and queries', () {
      var inner = TestGenerator();
      var generator = DOMGeneratorDelegate<TestNode>(inner);

      expect(generator.domGenerator, same(inner));

      var elem = _elem(generator.generate($div(content: 'x')));
      expect(elem.text, equals('x'));

      var treeMap = generator.generateMapped($div(content: [$span()]));
      expect(treeMap.rootElement, isA<TestElem>());

      var p = _elem(generator.generateFromHTML('<p>hi</p>'));
      expect(p.text, equals('hi'));

      var nodes = generator.generateNodes([$b(), $tag('i')]);
      expect(nodes.length, equals(2));

      var withRoot = generator.generateWithRoot($div(), null, [
        $span(content: 'r'),
      ], treeMap: generator.createDOMTreeMap());
      expect(_elem(withRoot).text, equals('r'));

      expect(generator.createGenericDOMTreeMap(), isA<DOMTreeMapDummy>());
      expect(generator.isMappable($div()), isTrue);

      var e1 = TestElem('div');
      var t1 = TestText('t');
      expect(generator.addChildToElement(e1, t1), isTrue);
      expect(generator.isChildOfElement(e1, t1), isTrue);
      expect(generator.containsNode(e1, t1), isTrue);
      expect(generator.getElementNodes(e1), equals([t1]));
      expect(generator.getNodeParent(t1), same(e1));
      expect(generator.getNodeParentsUntilRoot(t1), equals([e1]));
      expect(generator.removeChildFromElement(e1, t1), isTrue);
      expect(generator.isChildOfElement(e1, t1), isFalse);

      expect(generator.equalsNodes(e1, e1), isTrue);
      expect(generator.isTextNode(t1), isTrue);
      expect(generator.isElementNode(e1), isTrue);
      expect(generator.getNodeText(t1), equals('t'));
      expect(generator.getElementTag(e1), equals('div'));
      expect(generator.createElement('p'), isA<TestElem>());
      expect(generator.createTextNode('z'), isA<TestText>());
      expect(generator.canHandleExternalElement(TestElem('a')), isTrue);
      expect(generator.castToNodes([e1]), equals([e1]));

      generator.setAttribute(e1, 'title', 'tt');
      expect(generator.getAttribute(e1, 'title'), equals('tt'));
      expect(generator.getElementAttributes(e1), containsPair('title', 'tt'));
      expect(generator.getElementOuterHTML(e1), contains('title="tt"'));
      expect(generator.buildElementHTML(e1), contains('<div'));
      expect(generator.getElementValue(e1), equals(''));
      expect(generator.appendElementText(e1, 'txt'), isA<TestText>());
      expect(e1.text, equals('txt'));

      expect(generator.isEquivalentNode(TextNode('t'), TestText('t')), isTrue);
      expect(
        generator.isEquivalentNodeType(TextNode('t'), TestText('t')),
        isTrue,
      );
      expect(generator.getDOMNodeText(TextNode('abc')), equals('abc'));
      expect(generator.revertElementAttributes(e1, {'x': 'y'}), {'x': 'y'});

      generator.ignoreAttributeEquivalence('data-z');
      expect(generator.isIgnoreAttributeEquivalence('data-z'), isTrue);
      expect(generator.getIgnoredAttributesEquivalence(), contains('data-z'));
      expect(generator.removeIgnoredAttributeEquivalence('data-z'), isTrue);
      generator.clearIgnoredAttributesEquivalence();

      expect(
        generator.registerElementGenerator(TestNodeGenerator('dg', 'c')),
        isTrue,
      );
      expect(generator.isElementGeneratorTag('dg'), isTrue);
      expect(generator.registeredElementsGeneratorsLength, equals(1));
      expect(generator.registeredElementsGenerators, contains('dg'));
      expect(TestGenerator().registerElementGeneratorFrom(generator), isTrue);
      expect(generator.registerElementGeneratorFrom(TestGenerator()), isFalse);

      generator.sourceResolver = (u) => '/r/$u';
      expect(generator.sourceResolver, isNotNull);
      expect(generator.resolveSource('x'), equals('/r/x'));
      expect(inner.resolveSource('x'), equals('/r/x'));

      generator.populateGeneratedHTMLTrees = true;
      expect(generator.populateGeneratedHTMLTrees, isTrue);
      generator.generate($p(), treeMap: generator.createDOMTreeMap());
      expect(generator.generatedHTMLTrees, isNotEmpty);
      generator.reset();
      expect(generator.generatedHTMLTrees, isEmpty);

      var context = DOMContext<TestNode>(viewport: Viewport(10, 10));
      generator.domContext = context;
      expect(generator.domContext, same(context));
      expect(generator.viewport, equals(Viewport(10, 10)));

      var executor = _LogActionExecutor();
      generator.domActionExecutor = executor;
      expect(generator.domActionExecutor, same(executor));

      var revertTreeMap = inner.generateMapped($div(content: 'rv'));
      var reverted = generator.revert(revertTreeMap, revertTreeMap.rootElement);
      expect(reverted, isA<DOMElement>());

      expect(generator.cancelEvent(null), isFalse);
      expect(generator.createDOMEvent(treeMap, null), isNull);
      expect(generator.createDOMMouseEvent(treeMap, null), isNull);
    });

    test('delegates building and lifecycle', () async {
      var inner = TestGenerator();
      var generator = DOMGeneratorDelegate<TestNode>(inner);
      var treeMap = generator.createDOMTreeMap();
      var parent = TestElem('div');
      var domParent = $div();

      var built = _elem(
        generator.build(domParent, parent, $span(content: 'b'), treeMap, null),
      );
      expect(built.tag, equals('span'));

      var element = generator.buildElement(
        domParent,
        parent,
        $p(content: 'p'),
        treeMap,
        null,
      );
      expect(_elem(element).tag, equals('p'));

      var nodes = generator.buildNodes(
        domParent,
        parent,
        [$b(), TextNode('t')],
        treeMap,
        null,
      );
      expect(nodes.length, equals(2));

      expect(
        generator.buildText(domParent, parent, TextNode('tx'), treeMap),
        isA<TestText>(),
      );
      expect(
        generator.buildTemplate(
          domParent,
          parent,
          TemplateNode(DOMTemplate.parse('<i>{{x}}</i>')),
          treeMap,
          DOMContext(variables: {'x': 'X'}),
        ),
        isA<TestElem>(),
      );
      expect(
        generator.buildExternalElement(
          domParent,
          parent,
          ExternalElementNode('<u>e</u>'),
          treeMap,
          null,
        ),
        isA<TestElem>(),
      );
      expect(
        generator.buildDOMAsyncElement(
          domParent,
          parent,
          DOMAsync(loading: 'l', future: Future.value('ok')),
          treeMap,
          null,
        ),
        isA<TestNode>(),
      );
      expect(
        generator.generateDOMAsyncElement(
          domParent,
          parent,
          DOMAsync(future: Future.value('ok')),
          treeMap,
          null,
        ),
        isA<TestElem>(),
      );
      expect(
        generator.generateFutureElement(
          domParent,
          parent,
          ExternalElementNode(null),
          Future.value(TestElem('q')),
          treeMap,
          null,
        ),
        isA<TestElem>(),
      );
      expect(
        generator.resolveFutureElement(
          domParent,
          parent,
          $div(),
          null,
          TestElem('r'),
          treeMap,
          null,
        ),
        isA<TestElem>(),
      );
      var template = TestElem('template');
      parent.add(template);
      generator.attachFutureElement(
        domParent,
        parent,
        $div(),
        template,
        TestElem('att'),
        treeMap,
        null,
      );
      expect(parent.contains(template), isFalse);

      generator.registerElementGenerator(TestNodeGenerator('reg-x', 'r'));
      expect(
        generator.createWithRegisteredElementGenerator(
          domParent,
          parent,
          DOMElement('reg-x'),
          treeMap,
          null,
        ),
        isA<TestElem>(),
      );

      var e = TestElem('div')..attributes['class'] = 'a';
      var dom = $div(classes: 'b');
      expect(
        generator.resolveAttributeValue(
          dom,
          e,
          'class',
          treeMap,
          preserveClass: true,
        ),
        equals('a b'),
      );
      generator.setAttributes(dom, e, treeMap);
      generator.onElementCreated(treeMap, dom, e, null);
      generator.resolveActionAttribute(treeMap, dom, e, null);
      generator.registerEventListeners(treeMap, dom, e, null);
      expect(await generator.cancelEventSubscriptions(e, []), isA<bool>());
      generator.finalizeGeneratedTree(treeMap);

      expect(generator.resolveElements($b()), isA<TestElem>());
      expect(generator.toElements($b()), hasLength(1));
      expect(generator.wrapElements([TestElem('a')]), isA<TestElem>());

      var p2 = TestElem('div');
      var c1 = TestElem('a');
      p2.add(c1);
      expect(generator.replaceChildElement(p2, c1, [TestElem('b')]), isTrue);
      var c2 = p2.get(0);
      expect(generator.replaceElement(c2, [TestElem('c')]), isTrue);
      expect(generator.isNodeInDOM(c2), isFalse);

      expect(
        generator.appendElementTextNode(p2, TextNode('tn')),
        isA<TestText>(),
      );
      expect(
        generator.addExternalElementToElement(p2, TestElem('x')),
        hasLength(1),
      );
      expect(generator.createSVGElement($div()), isA<TestElem>());
      expect(
        generator.createDOMNodeRuntime(treeMap, $div(), TestElem('d')),
        isNotNull,
      );
    });
  });

  group('DOMGeneratorDummy', () {
    test('every operation is a no-op', () {
      var g = DOMGeneratorDummy<TestNode>();
      var e = TestElem('div');
      var treeMap = g.createDOMTreeMap();

      expect(treeMap, isA<DOMTreeMapDummy>());
      expect(g.createGenericDOMTreeMap(), same(treeMap));
      expect(g.generateMapped($div()), isA<DOMTreeMapDummy>());
      expect(g.generate($div()), isNull);
      expect(g.generateFromHTML('<p></p>'), isNull);
      expect(g.generateNodes([$div()]), isEmpty);
      expect(g.generateWithRoot($div(), e, []), isNull);
      expect(g.isMappable($div()), isFalse);
      expect(g.equalsNodes(e, e), isFalse);
      expect(g.isChildOfElement(e, e), isFalse);
      expect(g.addChildToElement(e, e), isFalse);
      expect(g.addExternalElementToElement(e, 'x'), isNull);
      expect(g.appendElementText(e, 'x'), isNull);
      expect(g.appendElementTextNode(e, TextNode('x')), isNull);
      expect(g.buildElementHTML(e), isNull);
      expect(g.canHandleExternalElement(e), isFalse);
      expect(g.containsNode(e, e), isFalse);
      expect(g.createDOMNodeRuntime(treeMap, null, e), isNull);
      expect(g.castToNodes([e]), isEmpty);
      expect(g.createElement('div'), isNull);
      expect(g.createSVGElement($div()), isNull);
      expect(g.createTextNode('x'), isNull);
      expect(
        g.generateDOMAsyncElement(null, null, DOMAsync(), treeMap, null),
        isNull,
      );
      expect(
        g.generateFutureElement(
          null,
          null,
          $div(),
          Future.value(1),
          treeMap,
          null,
        ),
        isNull,
      );
      expect(
        g.resolveFutureElement(null, null, $div(), null, 1, treeMap, null),
        isNull,
      );
      expect(g.resolveElements([e]), isNull);
      expect(g.wrapElements([e]), isNull);
      g.attachFutureElement(null, null, $div(), null, 1, treeMap, null);
      expect(g.getAttribute(e, 'x'), isNull);
      expect(g.getNodeText(e), isNull);
      expect(g.isTextNode(e), isFalse);
      expect(g.removeChildFromElement(e, e), isFalse);
      expect(g.replaceChildElement(e, e, [e]), isFalse);
      expect(g.replaceElement(e, [e]), isFalse);
      expect(g.toElements([e]), isNull);
      g.setAttribute(e, 'a', 'b');
      expect(g.resolveAttributeValue($div(), e, 'a', treeMap), isNull);
      g.onElementCreated(treeMap, $div(), e, null);
      g.resolveActionAttribute(treeMap, $div(), e, null);
      g.registerEventListeners(treeMap, $div(), e, null);
      expect(g.cancelEventSubscriptions(e, []), isFalse);
      expect(g.createDOMMouseEvent(treeMap, null), isNull);
      expect(g.createDOMEvent(treeMap, null), isNull);
      expect(g.cancelEvent(null), isFalse);
      g.finalizeGeneratedTree(treeMap);
      expect(g.viewport, isNull);
      expect(g.registeredElementsGenerators, isEmpty);
      expect(g.registeredElementsGeneratorsLength, equals(0));
      expect(g.domContext, isNull);
      g.domContext = DOMContext();
      expect(g.domContext, isNull);
      expect(
        () => g.buildElement(null, null, $div(), treeMap, null),
        throwsUnsupportedError,
      );
      expect(g.buildNodes(null, null, [$div()], treeMap, null), isEmpty);
      expect(g.build(null, null, $div(), treeMap, null), isNull);
      expect(
        g.buildDOMAsyncElement(null, null, DOMAsync(), treeMap, null),
        isNull,
      );
      expect(
        g.buildExternalElement(
          null,
          null,
          ExternalElementNode('x'),
          treeMap,
          null,
        ),
        isNull,
      );
      expect(g.buildText(null, null, TextNode('x'), treeMap), isNull);
      expect(
        g.buildTemplate(
          null,
          null,
          TemplateNode(DOMTemplate.parse('{{x}}')),
          treeMap,
          null,
        ),
        isNull,
      );
      g.clearIgnoredAttributesEquivalence();
      expect(
        g.createWithRegisteredElementGenerator(
          null,
          null,
          $div(),
          treeMap,
          null,
        ),
        isNull,
      );
      expect(g.getDOMNodeText(TextNode('x')), equals(''));
      expect(g.getElementAttributes(e), isNull);
      expect(g.revertElementAttributes(e, {}), isNull);
      expect(g.getElementNodes(e), isEmpty);
      expect(g.getElementTag(e), isNull);
      expect(g.getElementValue(e), isNull);
      expect(g.getElementOuterHTML(e), isNull);
      expect(g.getIgnoredAttributesEquivalence(), isEmpty);
      expect(g.getNodeParent(e), isNull);
      expect(g.getNodeParentsUntilRoot(e), isEmpty);
      expect(g.isNodeInDOM(e), isFalse);
      g.ignoreAttributeEquivalence('x');
      expect(g.isElementGeneratorTag('div'), isFalse);
      expect(g.isElementNode(e), isFalse);
      expect(g.isEquivalentNode($div(), e), isFalse);
      expect(g.isEquivalentNodeType($div(), e), isFalse);
      expect(g.isIgnoreAttributeEquivalence('x'), isFalse);
      expect(g.registerElementGenerator(TestNodeGenerator('x', 'x')), isFalse);
      expect(g.registerElementGeneratorFrom(TestGenerator()), isFalse);
      expect(g.removeIgnoredAttributeEquivalence('x'), isFalse);
      expect(g.revert(treeMap, e), isNull);
      g.setAttributes($div(), e, treeMap);
      expect(g.generatedHTMLTrees, isEmpty);
      expect(g.populateGeneratedHTMLTrees, isFalse);
      g.populateGeneratedHTMLTrees = true;
      expect(g.populateGeneratedHTMLTrees, isFalse);
      expect(g.sourceResolver, isNull);
      g.sourceResolver = (u) => u;
      expect(g.resolveSource('x'), equals(''));
      expect(g.domActionExecutor, isNull);
      g.domActionExecutor = _LogActionExecutor();
      expect(g.domActionExecutor, isNull);
      g.reset();
    });
  });

  group('DOMGeneratorUnsupported', () {
    test('operations throw UnsupportedError', () {
      var g = DOMGeneratorUnsupported<TestNode>('MyGen', 'my_pkg');
      var e = TestElem('div');

      Matcher unsupported = throwsA(
        isA<UnsupportedError>().having(
          (e) => e.message,
          'message',
          allOf(contains('MyGen'), contains('my_pkg')),
        ),
      );

      expect(() => g.isChildOfElement(e, e), unsupported);
      expect(() => g.addChildToElement(e, e), unsupported);
      expect(() => g.removeChildFromElement(e, e), unsupported);
      expect(() => g.replaceChildElement(e, e, [e]), unsupported);
      expect(() => g.createElement('div'), unsupported);
      expect(() => g.createSVGElement($div()), unsupported);
      expect(() => g.isTextNode(e), unsupported);
      expect(() => g.getNodeText(e), unsupported);
      expect(() => g.appendElementText(e, 'x'), unsupported);
      expect(() => g.setAttribute(e, 'a', 'b'), unsupported);
      expect(() => g.getAttribute(e, 'a'), unsupported);
      expect(() => g.addExternalElementToElement(e, 'x'), unsupported);
      expect(() => g.buildElementHTML(e), unsupported);
      expect(
        () => g.setAttributes($div(), e, g.createDOMTreeMap()),
        unsupported,
      );
      expect(
        () => g.createDOMNodeRuntime(g.createDOMTreeMap(), null, e),
        unsupported,
      );
      expect(() => g.createTextNode('x'), unsupported);

      expect(g.containsNode(e, e), isFalse);
      expect(g.canHandleExternalElement(e), isFalse);
    });

    test('unsupported web generator and action executor', () {
      // Only this conditional-import fallback is exercised here; on browsers
      // `DOMGenerator.web()` resolves to the real implementation.
      var web = createDOMGeneratorWeb<TestNode>();
      expect(web, isA<DOMGeneratorWeb<TestNode>>());
      expect(web, isA<DOMGeneratorUnsupported<TestNode>>());
      expect(() => web.createElement('div'), throwsUnsupportedError);

      // ignore: deprecated_member_use_from_same_package
      var dartHTML = createDOMGeneratorDartHTML<TestNode>();
      expect(() => dartHTML.createElement('div'), throwsUnsupportedError);

      var executor = DOMActionExecutorDartHTMLUnsupported<TestNode>();
      var action = DOMAction.parse(executor, 'show()')!;
      expect(
        () => executor.execute(action, null, null),
        throwsUnsupportedError,
      );
      expect(
        () => executor.call('show', [], null, null, null, null),
        throwsUnsupportedError,
      );
      expect(
        () => executor.selectByID('x', null, null, null, null),
        throwsUnsupportedError,
      );
    });
  });

  group('DOMTreeMap', () {
    test('queryElement / queryElementAsHTML', () {
      var generator = TestGenerator();
      var root = $div(
        content: [
          $span(id: 's1', content: 'one'),
          $p(
            classes: 'para',
            content: [$b(content: 'two')],
          ),
        ],
      );

      var treeMap = generator.generateMapped(root);

      expect(treeMap.queryElement(''), isNull);
      expect((treeMap.queryElement('#s1') as DOMElement).text, equals('one'));
      expect(treeMap.queryElement('.para'), isA<DOMElement>());
      expect(treeMap.queryElementAsHTML('.para'), equals('<b>two</b>'));
      expect(treeMap.queryElementAsHTML('#none'), isNull);

      var runtime = treeMap.getRuntimeNode(root.content!.first);
      expect(runtime, isNotNull);
      expect(runtime!.text, equals('one'));
      expect(treeMap.getRuntimeNode($div()), isNull);
    });

    test('element operations by element', () {
      var generator = TestGenerator();
      var root = $div(
        content: [
          $b(content: '1'),
          $tag('i', content: '2'),
          $tag('u', content: '3'),
        ],
      );

      var treeMap = generator.generateMapped(root);
      var rootElem = _elem(treeMap.rootElement);

      var iElem = rootElem.get(1);
      expect(treeMap.moveUpByElement(iElem), isTrue);
      expect(rootElem.text, equals('213'));
      expect(root.text, equals('213'));

      expect(treeMap.moveDownByElement(iElem), isTrue);
      expect(rootElem.text, equals('123'));

      var dup = treeMap.duplicateByElement(iElem)!;
      expect(dup.domNode.text, equals('2'));
      expect(dup.nodeCast<TestElem>().text, equals('2'));
      expect(rootElem.text, equals('1223'));

      var removed = treeMap.removeByElement(dup.node)!;
      expect(removed.domNode.text, equals('2'));
      expect(rootElem.text, equals('123'));
      expect(root.text, equals('123'));

      expect(treeMap.emptyByElement(rootElem), isTrue);
      expect(rootElem.nodesLength, equals(0));
      expect(root.content, isEmpty);

      expect(treeMap.moveUpByDOMNode(null), isFalse);
      expect(treeMap.moveDownByDOMNode($div()), isFalse);
      expect(treeMap.duplicateByDOMNode(null), isNull);
      expect(treeMap.removeByDOMNode($div()), isNull);
      expect(treeMap.emptyByDOMNode(null), isFalse);
    });

    test('DSX lifecycle management and dispose', () {
      var generator = TestGenerator();
      var treeMap = generator.generateMapped($div(content: 'x'));

      var dsx = DSX<Function>(_sum, _sum, parameters: [1, 2]);
      expect(treeMap.isManagedDSX(dsx), isFalse);
      expect(treeMap.manageDSX(dsx), isTrue);
      expect(treeMap.isManagedDSX(dsx), isTrue);

      treeMap.purge();
      expect(treeMap.purgeCount, equals(1));
      expect(treeMap.isManagedDSX(dsx), isTrue);

      expect(treeMap.disposeDSX(dsx), isTrue);
      expect(treeMap.disposeDSX(dsx), isFalse);
      expect(dsx.parameters, isNull, reason: 'disposed');

      var dsx2 = DSX<Function>(_sum, _sum, parameters: [3, 4]);
      treeMap.manageDSX(dsx2);
      expect(treeMap.disposeManagedDSXs(), equals(1));
      expect(treeMap.disposeManagedDSXs(), equals(0));

      expect(treeMap.toString(), contains('purgeCount: 1'));
      expect(treeMap.isDisposed, isFalse);
      treeMap.closeDOMElementsEventHandlers();
      treeMap.dispose();
      expect(treeMap.isDisposed, isTrue);
      expect(treeMap.rootElement, isNull);
      expect(treeMap.rootDOMNode, isNull);
    });

    test('DOMTreeMapDummy', () {
      var generator = TestGenerator();
      var dummy = DOMTreeMapDummy<TestNode>(generator);
      var dom = $div();
      var e = TestElem('div');
      var dsx = DSX<Function>(_sum, _sum, parameters: [9, 9]);

      dummy.map(dom, e);
      dummy.setRoot(dom, e);
      expect(dummy.rootElement, isNull);
      expect(dummy.unmap(dom, e), isFalse);
      expect(dummy.duplicateByDOMNode(dom), isNull);
      expect(dummy.duplicateByElement(e), isNull);
      expect(dummy.emptyByDOMNode(dom), isFalse);
      expect(dummy.emptyByElement(e), isFalse);
      expect(dummy.isMappedDOMNode(dom), isFalse);
      expect(dummy.isMappedElement(e), isFalse);
      expect(dummy.matchesMapping(dom, e), isFalse);
      expect(dummy.mergeNearNodes(dom, dom), isNull);
      expect(dummy.mergeNearStringNodes(dom, dom), isNull);
      expect(dummy.removeByDOMNode(dom), isNull);
      expect(dummy.removeByElement(e), isNull);
      expect(dummy.moveDownByDOMNode(dom), isFalse);
      expect(dummy.moveDownByElement(e), isFalse);
      expect(dummy.moveUpByDOMNode(dom), isFalse);
      expect(dummy.moveUpByElement(e), isFalse);
      expect(dummy.mapTree(dom, e), isFalse);
      expect(dummy.asMappedDOMNode(dom), isNull);
      expect(dummy.asMappedElement(e), isNull);
      expect(dummy.getMappedDOMNode(e), isNull);
      expect(dummy.getMappedElement(dom), isNull);
      expect(dummy.getRuntimeNode(dom), isNull);
      expect(dummy.queryElement('div'), isNull);
      expect(dummy.queryElementAsHTML('div'), isNull);
      expect(dummy.manageDSX(dsx), isFalse);
      expect(dummy.disposeDSX(dsx), isFalse);
      expect(dummy.disposeManagedDSXs(), equals(0));
      expect(dummy.isManagedDSX(dsx), isFalse);
      dummy.manageDOMElementDSXs(dom);
      dummy.mapSubscriptions(e, []);
      expect(dummy.elementsWithSubscriptions(), isEmpty);
      expect(dummy.getSubscriptions(e), isEmpty);
      expect(dummy.cancelSubscriptions(e), isEmpty);
      dummy.cancelAllSubscriptions();
      expect(dummy.domElementsWithEventListener(), isEmpty);
      dummy.closeDOMElementsEventHandlers();
      dummy.purge();
      dummy.dispose();
      expect(dummy.toString(), startsWith('DOMTreeMapDummy{}@'));
    });
  });

  group('DOMAction', () {
    test('default call() dispatch', () {
      var executor = _LogActionExecutor();
      var target = TestElem('div');

      for (var line in [
        'show()',
        'hide()',
        'delete()',
        'remove()',
        'clear()',
        'addClass(a)',
        'addClasses(c)',
        'setClass(x)',
        'setClasses( y )',
        'clearClass()',
        'clearClasses()',
        'locale(pt)',
        'unknownCall()',
      ]) {
        DOMAction.parse(executor, line)!.execute(target, self: target);
      }

      expect(
        executor.log,
        equals([
          'show',
          'hide',
          'remove',
          'remove',
          'clear',
          'addClass:a',
          'addClass:c',
          'setClass:x',
          'setClass:y',
          'clearClass',
          'clearClass',
          'locale:pt',
        ]),
      );

      expect(executor.call('   ', [], target, target, null, null), isNull);
    });

    test('removeClass() dispatches to callRemoveClass', () {
      var executor = _LogActionExecutor();
      var target = TestElem('div');
      DOMAction.parse(
        executor,
        'removeClass(a)',
      )!.execute(target, self: target);
      DOMAction.parse(executor, 'removeClasses(b)')!.execute(target);
      expect(executor.log, equals(['removeClass:a']));
    });

    test('selection chain via default execute()', () {
      var executor = _LogActionExecutor();
      var action = DOMAction.parse(executor, '#foo.hide(); #bar.show()')!;

      expect(action, isA<DOMActionList<TestNode>>());
      expect(action.toString(), equals('#foo.hide();#bar.show()'));

      var result = action.execute(TestElem('div')) as TestElem;
      expect(result.attributes['id'], equals('bar'));
      expect(
        executor.log,
        equals(['select:foo', 'hide', 'select:bar', 'show']),
      );
    });

    test('equality, hashCode and parse()', () {
      var executor = _LogActionExecutor();
      var a1 = executor.parse('addClass(a)')!;
      var a2 = executor.parse(' addClass( a ) ')!;
      expect(a1, equals(a2));
      expect(a1.hashCode, equals(a2.hashCode));
      expect(a1.toString(), equals('addClass(a)'));
      expect(a1, isNot(equals(executor.parse('addClass(b)'))));
      expect(
        DOMActionCall<TestNode>(executor, 'f', ['a', 'b']).toString(),
        equals('f(a , b)'),
      );

      var s1 = executor.parse('#x')!;
      expect(s1, equals(DOMActionSelect<TestNode>(executor, 'x')));
      expect(s1.hashCode, equals('x'.hashCode));

      var l1 = executor.parse('show(); hide()')!;
      var l2 = executor.parse('show();hide()')!;
      expect(l1, equals(l2));
      expect(l1.hashCode, equals(l2.hashCode));

      expect(executor.parse(null), isNull);
      expect(executor.parse('   '), isNull);
      expect(() => executor.parse('show() x hide()'), throwsArgumentError);
      expect(DOMAction.parseParameters(executor, null), isNull);
      expect(DOMAction.parseParameters(executor, '  '), isNull);
      expect(DOMAction.parseParameters(executor, 'a'), equals(['a']));
    });

    // Regression: `parseParameters` never advanced `endPos`, so any call with
    // 2+ parameters threw `ArgumentError`.
    test('multiple call parameters', () {
      var executor = _LogActionExecutor();
      expect(DOMAction.parseParameters(executor, 'a, b'), equals(['a', 'b']));
      expect(
        DOMAction.parseParameters(executor, 'a,b ,  c'),
        equals(['a', 'b', 'c']),
      );
      DOMAction.parse(executor, 'addClass(a, b)')!.execute(null);
      expect(executor.log, equals(['addClass:a,b']));
    });

    test('unimplemented executor hooks', () {
      var executor = _BareActionExecutor();
      expect(() => executor.domGenerator = null, throwsArgumentError);
      expect(executor.domGenerator, isNull);
      executor.domGenerator = TestGenerator();
      expect(executor.domGenerator, isA<TestGenerator>());

      var e = TestElem('div');
      expect(() => executor.callShow(e), throwsUnimplementedError);
      expect(() => executor.callHide(e), throwsUnimplementedError);
      expect(() => executor.callRemove(e), throwsUnimplementedError);
      expect(() => executor.callClear(e), throwsUnimplementedError);
      expect(() => executor.callAddClass(e, []), throwsUnimplementedError);
      expect(() => executor.callRemoveClass(e, []), throwsUnimplementedError);
      expect(() => executor.callSetClass(e, []), throwsUnimplementedError);
      expect(() => executor.callClearClass(e), throwsUnimplementedError);
      expect(() => executor.callLocale(e, [], null), throwsUnimplementedError);
      expect(
        () => executor.selectByID('x', e, e, null, null),
        throwsUnimplementedError,
      );
    });
  });

  group('DOMContext / Viewport', () {
    test('Viewport', () {
      var v = Viewport(800, 600, 1024, 768);
      expect(v.vmin, equals(600));
      expect(v.vmax, equals(800));
      expect(v.widthAsPx, equals('800px'));
      expect(v.heightAsPx, equals('600px'));
      expect(v.vminAsPx, equals('600px'));
      expect(v.vmaxAsPx, equals('800px'));
      expect(v, equals(Viewport(800, 600, 1024, 768)));
      expect(v.hashCode, equals(Viewport(800, 600, 1024, 768).hashCode));
      expect(v, isNot(equals(Viewport(800, 600))));
      expect(v.toString(), contains('deviceWidth: 1024'));

      expect(() => Viewport(0, 10), throwsArgumentError);
      expect(() => Viewport(10, 10, 5, 10), throwsArgumentError);
      expect(() => Viewport(10, 10, 10, 5), throwsArgumentError);
    });

    test('toIntlMessageResolver', () {
      expect(toIntlMessageResolver(null), isNull);

      String? full(String k, [Map<String, dynamic>? p]) => '$k:${p?['n']}';
      expect(toIntlMessageResolver(full)!('a', {'n': 1}), equals('a:1'));

      expect(
        toIntlMessageResolver((String k) => k.toUpperCase())!('hi'),
        equals('HI'),
      );
      expect(toIntlMessageResolver((Object? k) => 123)!('k'), equals('123'));
      expect(toIntlMessageResolver(() => 'const')!('k'), equals('const'));
      Object? dyn() => 'dyn';
      expect(toIntlMessageResolver(dyn)!('k'), equals('dyn'));
      expect(toIntlMessageResolver({'a': 'A'})!('a'), equals('A'));
      expect(() => toIntlMessageResolver(42), throwsArgumentError);
    });

    // Regression: the `dynamic Function()` branch returned the raw value
    // (a TypeError for non-String values) instead of using `parseString`.
    test('toIntlMessageResolver with a non-String `dynamic Function()`', () {
      expect(toIntlMessageResolver(() => 7)!('k'), equals('7'));
      expect(toIntlMessageResolver(() => null)!('k'), isNull);
    });

    test('variables, intl, source and viewport units', () {
      var parent = DOMContext<TestNode>(variables: {'a': 1, 'b': 2});
      var context = DOMContext<TestNode>(
        parent: parent,
        viewport: Viewport(200, 100),
        resolveCSSViewportUnit: true,
        variables: {'b': 3},
        intlMessageResolver: (k, [p]) => 'msg:$k',
      );

      expect(context.variables, equals({'a': 1, 'b': 3}));
      context.putVariable('c', 4);
      expect(context.getVariable('c', null), equals(4));
      expect(context.variables['c'], equals(4));
      expect(DOMContext<TestNode>().getVariable('x', null), isNull);

      expect(context.resolveIntlMessage('hi'), equals('msg:hi'));
      expect(parent.resolveIntlMessage('hi'), isNull);

      expect(
        context.resolveCSSViewportUnitValue(50, CSSUnit.vw),
        equals('100px /* DOMContext-original-value: 50vw */'),
      );
      expect(
        context.resolveCSSViewportUnitValue(
          10,
          CSSUnit.vh,
          originalValueAsComment: false,
        ),
        equals('10px'),
      );
      expect(context.resolveViewportCSSLength(50, CSSUnit.vmin).value, 50);
      expect(context.resolveViewportCSSLength(50, CSSUnit.vmax).value, 100);
      expect(
        context.resolveViewportCSSLength(5, CSSUnit.em),
        equals(CSSLength(5, CSSUnit.em)),
      );
      expect(
        parent.resolveViewportCSSLength(5, CSSUnit.vw),
        equals(CSSLength(5, CSSUnit.vw)),
      );
      expect(context.resolveCSSUnitValue(3, CSSUnit.rem), equals('3rem'));

      expect(context.resolveCSSURLValue('a.png'), equals('a.png'));
      context.cssURLResolver = (u) => '/static/$u';
      expect(context.resolveCSSURLValue('a.png'), equals('/static/a.png'));

      expect(context.resolveSource('x'), equals('x'));
      var generator = TestGenerator()..sourceResolver = (u) => 'gen:$u';
      parent.domGenerator = generator;
      expect(context.resolveSource('x'), equals('gen:x'));
      expect(() => context.domGenerator = null, throwsArgumentError);

      var copy = context.copy();
      expect(copy.viewport, equals(context.viewport));
      expect(copy.variables, equals(context.variables));
      expect(copy.resolveIntlMessage('k'), equals('msg:k'));

      expect(context.toString(), contains('resolveCSSViewportUnit: true'));
    });

    test('named elements', () {
      var generator = TestGenerator();
      var treeMap = generator.createDOMTreeMap();
      var context = DOMContext<TestNode>();

      var named = $div(attributes: {'name': 'widget'});
      expect(context.hasNamedElementNameValue(named), isFalse);
      expect(context.getNamedElementNameValue(named), isNull);
      expect(context.resolveNamedElement(null, null, named, treeMap), isNull);

      context.namedElementProvider = (
        name,
        domGenerator,
        treeMap,
        domParent,
        parent,
        tag,
        attributes,
      ) => TestElem('named')..attributes['n'] = name;

      expect(context.hasNamedElementNameValue(named), isTrue);
      expect(context.getNamedElementNameValue(named), equals('widget'));
      expect(context.hasNamedElementNameValue($div()), isFalse);
      expect(context.resolveNamedElement(null, null, $div(), treeMap), isNull);

      var resolved = _elem(
        context.resolveNamedElement(null, null, named, treeMap),
      );
      expect(resolved.tag, equals('named'));
      expect(resolved.attributes['n'], equals('widget'));

      context.namedElementAttribute = 'data-w';
      expect(context.getNamedElementNameValue(named), isNull);

      // Through generation (the generator's own `domContext`):
      context.namedElementAttribute = DOMContext.defaultNamedElementAttribute;
      generator.domContext = context;
      var elem = _elem(generator.generate($div(content: [named])));
      expect((elem.get(0) as TestElem).tag, equals('named'));
    });

    // Regression: `buildElement` resolved named elements only with the
    // generator's own `domContext`, ignoring the `context` argument.
    test('named elements with the `context` passed to generate()', () {
      var generator = TestGenerator();
      var context = DOMContext<TestNode>()
        ..namedElementProvider = (
          name,
          domGenerator,
          treeMap,
          domParent,
          parent,
          tag,
          attrs,
        ) => TestElem('named');
      var elem = _elem(
        generator.generate(
          $div(
            content: [
              $div(attributes: {'name': 'w'}),
            ],
          ),
          context: context,
        ),
      );
      expect((elem.get(0) as TestElem).tag, equals('named'));
      expect(generator.domContext, isNull);
    });
  });

  group('DSX', () {
    test('DSXObjectType.forObject', () {
      expect(DSXObjectType.forObject(() {}), equals(DSXObjectType.function));
      expect(
        DSXObjectType.forObject(Future.value(1)),
        equals(DSXObjectType.future),
      );
      expect(DSXObjectType.forObject('x'), equals(DSXObjectType.generic));
      expect(DSXObjectType.forObject(null), equals(DSXObjectType.generic));
      expect(DSXObjectType.function.placeholderPrefix, equals('function_'));
    });

    test('marks: isDSXMark / parseDSXMarkID', () {
      expect(DSX.isDSXMark('__DSX__function_12'), isTrue);
      expect(DSX.isDSXMark('__DSX__7'), isTrue);
      expect(DSX.isDSXMark('__DSX__'), isFalse);
      expect(DSX.isDSXMark('DSX_function_1'), isFalse);
      expect(DSX.isDSXMark('__DSX__function_x'), isFalse);
      expect(DSX.parseDSXMarkID('__DSX__future_42'), equals(42));
      expect(DSX.parseDSXMarkID('nope'), isNull);
    });

    test('function DSX: call, parameters, resolve', () {
      var dsx = _sum.dsx(2, 3)!;
      expect(dsx.isFunction, isTrue);
      expect(dsx.isFuture, isFalse);
      expect(dsx.type, equals(DSXObjectType.function));
      expect(dsx.parameters, equals([2, 3]));
      expect(dsx.call(), equals(5));
      expect(dsx.toString(), equals('{{__DSX__function_${dsx.id}}}'));
      expect(dsx.keyID, equals(dsx.id));

      // Same function + same parameters => same DSX:
      expect(identical(_sum.dsx(2, 3), dsx), isTrue);
      expect(identical(_sum.dsx(3, 2), dsx), isFalse);

      expect(DSX.resolveDSX(dsx), same(dsx));
      expect(DSX.resolveDSX(dsx.id), same(dsx));
      expect(DSX.resolveDSX('${dsx.id}'), same(dsx));
      expect(DSX.resolveDSX('__DSX__function_${dsx.id}'), same(dsx));
      expect(DSX.resolveDSX(null), isNull);
      expect(() => DSX.resolveDSX(1.5), throwsStateError);

      expect(DSX.resolveObject(dsx), same(_sum));
      expect(DSX.resolveObject(dsx.id), same(_sum));
      expect(DSX.resolveObject('__DSX__function_${dsx.id}'), same(_sum));
      expect(DSX.resolveObject(' ${dsx.id} '), same(_sum));
      expect(DSX.resolveObject(null), isNull);
      expect(() => DSX.resolveObject(true), throwsStateError);
      expect(DSX.objectSourceFromDSX(dsx), same(_sum));

      expect(dsx.equalsParameters([2, 3]), isTrue);
      expect(dsx.equalsParameters([2]), isFalse);
      expect(dsx.equalsParameters(null), isFalse);
      expect(dsx.equalsParameters([2, 4]), isFalse);
    });

    test('call() arities', () {
      int f0() => 0;
      String f(a, [b, c, d, e, f, g, h, i, j]) =>
          [a, b, c, d, e, f, g, h, i, j].nonNulls.join();

      expect(DSX<Function>(f0, f0).call(), equals(0));
      for (var n = 1; n <= 10; n++) {
        var params = List.generate(n, (i) => i);
        var dsx = DSX<Function>(f, f, parameters: params);
        expect(dsx.call(), equals(params.join()), reason: '$n params');
      }
      var dsx11 = DSX<Function>(f, f, parameters: List.filled(11, 1));
      expect(dsx11.call(), isNull);
    });

    test('DSX.varArgs', () {
      String f(a, [b, c, d, e, f, g, h, i, j]) =>
          [a, b, c, d, e, f, g, h, i, j].nonNulls.join(',');

      for (var n = 0; n <= 9; n++) {
        var args = List<dynamic>.generate(10, (i) => i < n ? i + 1 : null);
        var dsx = DSX<Function>.varArgs(
          f,
          f,
          args[0],
          args[1],
          args[2],
          args[3],
          args[4],
          args[5],
          args[6],
          args[7],
          args[8],
        );
        if (n == 0) {
          expect(dsx.parameters, isNull);
        } else {
          expect(dsx.parameters, equals(args.take(n).toList()));
        }
      }
    });

    // Regression: `DSX.varArgs` passed the literal `10` instead of `a10`.
    test('DSX.varArgs with 10 arguments keeps the 10th argument', () {
      String f(a, [b, c, d, e, f, g, h, i, j]) => '';
      var dsx = DSX<Function>.varArgs(f, f, 1, 2, 3, 4, 5, 6, 7, 8, 9, 'x');
      expect(dsx.parameters, equals([1, 2, 3, 4, 5, 6, 7, 8, 9, 'x']));
    });

    test('primitive, typed and toDSXValue objects', () {
      var sDSX = 'text'.dsx()!;
      expect(sDSX.type, equals(DSXObjectType.generic));
      expect(sDSX.object, equals('text'));

      expect((5).dsx()!.object, equals(5));
      expect((1.5).dsx()!.object, equals(1.5));
      expect(true.dsx()!.object, equals(true));
      expect((null as String?).dsx(), isNull);

      var typed = _DSXTypeObj().dsx()!;
      expect(typed.object, equals('dsx-type-value'));

      var holder = _DSXValueHolder('v');
      var holderDSX = holder.dsx()!;
      expect(holderDSX.object, equals('holder:v'));
      expect(holderDSX.objectSource, same(holder));

      var dsxOfDSX = sDSX.dsx();
      expect(dsxOfDSX, same(sDSX));
    });

    test('future DSX', () async {
      var completer = Completer<String>();
      var dsx = completer.future.dsx();
      expect(dsx.isFuture, isTrue);
      expect(dsx.toString(), startsWith('{{__DSX__future_'));

      var resolver = dsx.createResolver();
      expect(resolver.isFuture, isTrue);
      expect(resolver.resolveValueAsString(), equals('...'));

      completer.complete('done');
      await Future<void>.delayed(Duration(milliseconds: 10));
      expect(
        (resolver.resolvedElement as DOMElement).buildHTML(),
        contains('done'),
      );
    });

    // Regression: `setResolvedValue` set the value, then `reset()` (when the
    // previous element isn't in the DOM) wiped it.
    test('future DSX keeps the resolved value', () async {
      var completer = Completer<String>();
      var resolver = completer.future.dsx().createResolver();
      expect(resolver.resolveValue(), equals('...'));
      expect(resolver.resolvedValue, equals('...'));
      completer.complete('done');
      await Future<void>.delayed(Duration(milliseconds: 10));
      expect(resolver.resolvedValue, equals('done'));
      expect(resolver.resolvedElement!.buildHTML(), contains('done'));
      // Resolving again returns the cached value:
      expect(resolver.resolveValue(), equals('done'));
    });

    test('DSXResolver', () {
      var lifecycle = _Lifecycle();
      int makeCount() => 3;
      var dsx = DSX<Function>(makeCount, makeCount);

      var resolver = dsx.createResolver(lifecycleManager: lifecycle);
      expect(lifecycle.isManagedDSX(dsx), isTrue);
      expect(resolver.lifecycleManager, same(lifecycle));
      expect(resolver.isFunction, isTrue);
      expect(resolver.object, same(makeCount));
      expect(resolver.objectSource, same(makeCount));
      expect(resolver.type, equals(DSXObjectType.function));

      var element = resolver.resolveElement() as DOMElement;
      expect(element.buildHTML(), equals('<span>3</span>'));
      expect(resolver.resolvedValue, equals(3));
      expect(resolver.call(), equals(3));
      expect(resolver.toString(), startsWith('DSXResolver['));

      // Cached:
      expect(resolver.resolveValue(), equals(3));

      // Generic values to elements:
      var r2 = DSX<String>('<b>bold</b>', '<b>bold</b>').createResolver();
      expect(
        (r2.resolveElement() as DOMElement).buildHTML(),
        equals('<b>bold</b>'),
      );

      var r3 = DSX<String>('src-a', 'a<b>b</b>').createResolver();
      expect(
        (r3.resolveElement() as DOMElement).buildHTML(),
        equals('<span>a<b>b</b></span>'),
      );

      String? empty() => null;
      var r4 = DSX<Function>(empty, empty).createResolver();
      expect(
        (r4.resolveElement() as DOMElement).buildHTML(),
        equals('<span></span>'),
      );

      r4.reset();
      expect(r4.resolvedValue, isNull);
      expect(r4.resolvedElement, isNull);
    });

    test('DSXResolution', () {
      expect(DSXResolution.resolveDSX.resolve, isTrue);
      expect(DSXResolution.skipDSX.resolve, isFalse);

      var lifecycle = _Lifecycle();
      var r = DSXResolution.lifecycleManager(lifecycle);
      expect(r.resolve, isTrue);
      expect(r.lifecycleManager, same(lifecycle));

      var c1 = r.copyWith(resolve: false);
      expect(c1.resolve, isFalse);
      expect(c1.lifecycleManager, same(lifecycle));

      var c2 = r.copyWith(nullLifecycleManager: true);
      expect(c2.lifecycleManager, isNull);

      expect(r.noLifecycleManager().lifecycleManager, isNull);
      expect(r.toString(), contains('resolve: true'));
    });

    test('DSX.applyLifeCycleManager / purge / dispose', () {
      int f() => 1;
      var dsx = DSX<Function>(f, f, parameters: ['apply']);
      expect(DSX.applyLifeCycleManager(dsx, null), isFalse);

      var lifecycle = _Lifecycle();
      expect(DSX.applyLifeCycleManager(dsx, lifecycle), isTrue);
      // Already managed:
      expect(DSX.applyLifeCycleManager(dsx, lifecycle), isFalse);

      expect(dsx.check(), isTrue);
      DSX.purge();
      expect(dsx.check(), isTrue);

      dsx.dispose();
      expect(dsx.object, isNull);
      expect(dsx.check(), isFalse);
      expect(DSX.objectFromDSX(dsx), isNull);
      expect(DSX.objectSourceFromDSX(dsx), isNull);
      expect(DSX.resolveDSX(dsx.id), isNull);
      expect(DSX.resolveObject(dsx.id), isNull);
    });

    test('\$dsx() parsing', () {
      var nodes = $dsx(['<div>', 'a', '<b>b</b>', '</div>']);
      expect(nodes.length, equals(1));
      expect(
        (nodes.single as DOMElement).buildHTML(),
        equals('<div>a<b>b</b></div>'),
      );

      expect($dsx(null), isEmpty);
      expect($dsx($span(content: 'x')).single, isA<DOMElement>());
      expect($dsx([$span(), $b()]).length, equals(2));
      expect(
        $dsx(<Object?>[
          ['<i>x</i>'],
          $b(),
        ]).length,
        equals(2),
      );

      var call = $dsxCall(_sum, 10, 20);
      expect(call.call(), equals(30));
    });
  });

  group('CSS', () {
    test('CSSEntry comment (private named parameter)', () {
      var entry = CSSEntry<CSSGeneric>(
        'Margin',
        CSSGeneric('0'),
        comment: 'reset',
      );
      expect(entry.name, equals('margin'));
      expect(entry.toString(), equals('margin: 0/*reset*/'));
      expect(entry.toString(true), equals('margin: 0/*reset*/;'));

      var entry2 = CSSEntry<CSSGeneric>(
        'x',
        CSSGeneric('1'),
        comment: '/* full */',
      );
      expect(entry2.toString(), equals('x: 1/* full */'));

      var from = CSSEntry.from<CSSLength>('width', '10px', 'w')!;
      expect(from.value, equals(CSSLength(10)));
      expect(from.toString(), equals('width: 10px/*w*/'));

      var fromValue = CSSEntry.from<CSSLength>('width', CSSLength(3), 'c')!;
      expect(fromValue.toString(), equals('width: 3px/*c*/'));

      var fromEntry = CSSEntry.from<CSSLength>('height', from, 'h')!;
      expect(fromEntry.name, equals('height'));
      expect(fromEntry.toString(), equals('height: 10px/*h*/'));

      expect(CSSEntry.from<CSSLength>('width', null), isNull);
      expect(CSSEntry.from<CSSLength>('width', 123), isNull);

      var noValue = CSSEntry<CSSGeneric>('display', null);
      expect(noValue.toString(), equals('display: initial'));
      expect(noValue.valueAsString, equals(''));
      expect(noValue.sampleValueAsString, equals(''));

      var sample = CSSEntry<CSSNumber>(
        'opacity',
        null,
        sampleValue: CSSNumber(1),
      );
      expect(sample.sampleValueAsString, equals('1'));
    });

    test('CSS parsing keeps comments', () {
      var css = CSS('margin: 1px /* spacing */; padding: 2px');
      expect(css.length, equals(2));
      expect(css.style, equals('margin: 1px/* spacing */; padding: 2px'));

      var parsed = CSSEntry.parse('margin: 2px', '/*note*/')!;
      expect(parsed.value, equals(CSSLength(2)));
      expect(parsed.toString(), equals('margin: 2px/*note*/'));

      var original = CSSEntry.parse<CSSLength>(
        'width: 100px',
        '/* DOMContext-original-value: 50vw */',
      )!;
      expect(original.value, equals(CSSLength(50, CSSUnit.vw)));
      expect(original.toString(), equals('width: 50vw'));

      expect(CSSEntry.parse('no-delimiter'), isNull);

      expect(
        CSS.parse('a: 1; /* c1 */ b: 2; c: "x;y"; d: \'z\'')!.entriesAsString,
        equals(['a: 1', 'b: 2/* c1 */', 'c: "x;y"', "d: 'z'"]),
      );
      expect(CSS.parse('a: "unterminated')!.length, equals(1));
      expect(CSS.parse('a: 1 /* open comment')!.length, equals(1));
      expect(
        CSS.parse('/* c */ a: 1')!.entriesAsString,
        equals(['a: 1/* c */']),
      );
      expect(CSS.parse(''), isNull);
    });

    // Regression: the typed-property setters rebuilt the entry with
    // `CSSEntry.from`, which dropped the comment of the source entry.
    test('CSS parsing keeps comments of typed properties', () {
      var css = CSS('color: red /* primary */; width: 1px /* w */');
      expect(css.style, equals('color: red/* primary */; width: 1px/* w */'));

      var css2 = CSS(
        'height: 2px /* h */; opacity: 0.5 /* o */; display: block /* d */; '
        'background-color: #000 /* bg */; border: 1px solid #000 /* b */',
      );
      expect(
        css2.entriesAsString.map((e) => e.substring(e.indexOf('/*'))),
        equals(['/* h */', '/* o */', '/* d */', '/* bg */', '/* b */']),
      );

      // An explicit comment still wins over the source entry's:
      var entry = CSSEntry.parse<CSSGeneric>('cursor: pointer', '/* src */')!;
      expect(
        CSSEntry.from<CSSGeneric>('cursor', entry, 'new').toString(),
        contains('/*new*/'),
      );
      expect(
        CSSEntry.from<CSSGeneric>('cursor', entry).toString(),
        contains('/* src */'),
      );
    });

    test('CSS API', () {
      var css = CSS(['color: #ff0000', 'width: 10px', null]);
      expect(css.length, equals(2));
      expect(css.isEmpty, isFalse);
      expect(css.isNoEmpty, isTrue);
      expect(CSS().isEmpty, isTrue);
      expect(identical(CSS(css), css), isTrue);
      expect(() => CSS(123), throwsStateError);

      css.putAllProperties({
        'height': '5em',
        'opacity': '0.5',
        'display': 'block',
        'border': '1px solid #000',
        'background-color': 'blue',
        'background': 'url("a.png") no-repeat',
        'margin': '0 auto',
      });
      expect(css.height!.value, equals(CSSLength(5, CSSUnit.em)));
      expect(css.opacity!.value, equals(CSSNumber(0.5)));
      expect(css.display!.value, equals(CSSGeneric('block')));
      expect(css.border!.value.toString(), equals('1px solid #000000'));
      expect(css.backgroundColor!.value.toString(), equals('blue'));
      expect(css.background!.value!.firstImage!.url!.url, equals('a.png'));
      expect(css.getAsString('margin'), equals('0 auto'));
      expect(css.get<CSSGeneric>('margin'), equals(CSSGeneric('0 auto')));
      expect(css['width'], equals(CSSLength(10)));

      css.putIfAbsent('width', '99px');
      expect(css['width'], equals(CSSLength(10)));
      css.putIfAbsent('padding', '2px');
      expect(css.getAsString('padding'), equals('2px'));

      css['padding'] = null;
      expect(css.getEntry('padding'), isNull);

      css.putEntryIfAbsent(CSSEntry('width', CSSLength(1)));
      expect(css['width'], equals(CSSLength(10)));
      css.putAllIfAbsent([CSSEntry('top', CSSGeneric('0'))]);
      expect(css.getAsString('top'), equals('0'));
      css.putAll([CSSEntry('top', CSSGeneric('1px'))]);
      expect(css.getAsString('top'), equals('1px'));
      css.putAll([]);
      css.putAllIfAbsent([]);
      css.putAllProperties({});

      expect(css.containsEntry(CSSEntry('top', CSSGeneric('1px'))), isTrue);
      expect(css.containsEntry(CSSEntry('top', CSSGeneric('2px'))), isFalse);
      expect(css.removeEntry('top')!.name, equals('top'));

      var copy = css.copy();
      expect(copy, equals(css));
      expect(copy.hashCode, equals(css.hashCode));
      expect(css.entries.length, equals(css.length));

      var possible = CSS('color: red').getPossibleEntries();
      expect(
        possible.map((e) => e.name),
        containsAll(['color', 'background-color', 'width', 'border']),
      );
      expect(
        possible.firstWhere((e) => e.name == 'width').valueAsString,
        equals('auto'),
      );

      expect(() => css.put('x', 123), throwsStateError);
      css.put('  ', 'ignored');
    });

    test('CSSValue.from / parseByName', () {
      expect(CSSValue.from('12'), isA<CSSNumber>());
      expect(CSSValue.from('12px'), isA<CSSLength>());
      expect(CSSValue.from('#fff'), isA<CSSColor>());
      expect(CSSValue.from('url(a.png)'), isA<CSSURL>());
      // Without a property name, functions are wrapped by the first
      // matching type (CSSNumber):
      var calc = CSSValue.from('calc(1px + 2px)')!;
      expect(calc.isFunction, isTrue);
      expect(calc.isCalc, isTrue);
      expect(calc.calc, isA<CSSCalc>());
      expect(calc.function, isA<CSSCalc>());
      expect(calc.toString(), equals('calc(1px + 2px)'));
      var max = CSSValue.from('max(1px, a)')!;
      expect(max.isCalc, isFalse);
      expect(max.calc, isNull);
      expect(max.function, isA<CSSMax>());
      expect(max.toString(), equals('max(1px, a)'));
      expect(calc, equals(CSSValue.from('calc(1px + 2px)')));
      expect(calc.hashCode, equals(CSSValue.from('calc(1px + 2px)').hashCode));
      expect(CSSValue.from('inherit'), isA<CSSGeneric>());
      expect(CSSValue.parseByName('red', 'color'), isA<CSSColor>());
      expect(CSSValue.parseByName('red', 'background-color'), isA<CSSColor>());
      expect(CSSValue.parseByName('1px solid', 'border'), isA<CSSBorder>());
      expect(CSSValue.parseByName('grid', 'display'), isA<CSSGeneric>());
      expect(CSSValue.parseByName('0.3', 'opacity'), isA<CSSNumber>());
      expect(CSSValue.parseByName('7px', 'height'), isA<CSSLength>());
    });

    test('calc()', () {
      expect(getCalcOperation('+'), equals(CalcOperation.sum));
      expect(getCalcOperation('-'), equals(CalcOperation.subtract));
      expect(getCalcOperation('*'), equals(CalcOperation.multiply));
      expect(getCalcOperation('/'), equals(CalcOperation.divide));
      expect(getCalcOperation('%'), isNull);
      expect(getCalcOperation(' '), isNull);
      expect(getCalcOperation(null), isNull);
      for (var op in CalcOperation.values) {
        expect(getCalcOperation(getCalcOperationSymbol(op)), equals(op));
      }
      expect(getCalcOperationSymbol(null), isNull);
      expect(computeCalcOperationSymbol(CalcOperation.divide, 9, 3), 3);
      expect(computeCalcOperationSymbol(CalcOperation.multiply, 2, 3), 6);
      expect(computeCalcOperationSymbol(CalcOperation.subtract, 2, 3), -1);

      var sum = CSSCalc.parse('calc(10px + 5px)')!;
      expect(sum.hasOperation, isTrue);
      expect(sum.operationSymbol, equals('+'));
      expect(sum.toString(), equals('calc(10px + 5px)'));
      expect(sum.compute(), equals(CSSLength(15)));
      expect(sum.computeUnit(), equals(CSSUnit.px));

      var mixed = CSSCalc.parse('calc(10px - 1em)')!;
      expect(mixed.compute(), isNull);
      expect(mixed.computeUnit(), isNull);

      var numbers = CSSCalc.parse('calc(6 / 2)')!;
      expect(numbers.compute(), equals(CSSNumber(3)));
      expect(numbers.computeUnit(), isNull);

      var simple = CSSCalc.parse('calc(4em)')!;
      expect(simple.hasOperation, isFalse);
      expect(simple.toString(), equals('calc(4em)'));
      expect(simple.compute(), equals(CSSLength(4, CSSUnit.em)));
      expect(simple.computeUnit(), equals(CSSUnit.em));

      expect(CSSCalc.parse('calc(a + b)')!.compute(), isNull);
      expect(CSSCalc.parse('nope'), isNull);
      expect(CSSCalc.parse(' '), isNull);
      expect(CSSCalc.from(sum), same(sum));
      expect(CSSCalc.from('calc(1px)'), isA<CSSCalc>());
      expect(CSSCalc.from(1), isNull);
      expect(sum, equals(CSSCalc.parse('CALC(10px + 5px)')));
      expect(sum.hashCode, equals(CSSCalc.parse('calc(10px + 5px)').hashCode));

      var length = CSSLength.from('calc(10px + 5px)')!;
      expect(length.isCalc, isTrue);
      expect(length.calc, equals(sum));
      expect(length.toString(), equals('15px'));

      expect(CSSLength.from('calc(3px)'), equals(CSSLength(3)));
      expect(CSSNumber.from('calc(3)'), equals(CSSNumber(3)));
      var numberCalc = CSSNumber.from('calc(1 + 2)')!;
      expect(numberCalc.toString(), equals('calc(1 + 2)'));
      expect(CSSNumber.fromCalc(sum).isCalc, isTrue);
      expect(CSSLength.fromCalc(sum).toString(), equals('15px'));
      expect(
        CSSLength.fromFunction(CSSCalc.parse('calc(a * 2)')!).toString(),
        equals('calc(a * 2)'),
      );
    });

    test('max() / min()', () {
      var max = CSSMax.parse('max(10px, 30px, 20px)')!;
      expect(max.args, equals(['10px', '30px', '20px']));
      expect(max.toString(), equals('max(10px, 30px, 20px)'));
      expect(max.compute(), equals(CSSLength(30)));
      expect(max.computeUnit(), equals(CSSUnit.px));
      expect(CSSMax.parse('max(1px, 1em)')!.compute(), isNull);
      expect(CSSMax.parse('max(1px, 1em)')!.computeUnit(), isNull);
      expect(CSSMax.parse('max(1px, zz)')!.compute(), isNull);
      expect(CSSMax(['  ']).compute(), isNull);
      expect(CSSMax(['  ']).computeUnit(), isNull);
      expect(CSSMax.parse('max( )'), isNull);
      expect(CSSMax.parse(null), isNull);
      expect(CSSMax.parse(''), isNull);
      expect(CSSMax.from(max), same(max));
      expect(CSSMax.from('max(1px)'), isA<CSSMax>());
      expect(CSSMax.from(1), isNull);
      expect(max, equals(CSSMax(['10px', ' 30px', '20px '])));
      expect(max.hashCode, equals(CSSMax(['10px', '30px', '20px']).hashCode));

      var min = CSSMin.parse('min(10px, 30px, 20px)')!;
      expect(min.toString(), equals('min(10px, 30px, 20px)'));
      expect(min.compute(), equals(CSSLength(10)));
      expect(min.computeUnit(), equals(CSSUnit.px));
      expect(CSSMin.parse('min(1px, 1em)')!.compute(), isNull);
      expect(CSSMin.parse('min(1px, 1em)')!.computeUnit(), isNull);
      expect(CSSMin.parse('min(1px, zz)')!.compute(), isNull);
      expect(CSSMin(['']).compute(), isNull);
      expect(CSSMin(['']).computeUnit(), isNull);
      expect(CSSMin.parse('min()'), isNull);
      expect(CSSMin.parse(null), isNull);
      expect(CSSMin.from(min), same(min));
      expect(CSSMin.from('min(1px)'), isA<CSSMin>());
      expect(CSSMin.from(1), isNull);
      expect(min, equals(CSSMin(['10px', '30px', '20px'])));
      expect(min.hashCode, equals(CSSMin(['10px', '30px', '20px']).hashCode));

      expect(CSSFunction.from(max), same(max));
      expect(CSSFunction.from(min), same(min));
      expect(CSSFunction.from(null), isNull);
      expect(CSSFunction.from(1), isNull);
      expect(CSSFunction.parse('min(1px)'), isA<CSSMin>());
      expect(CSSFunction.parse('foo(1px)'), isNull);

      expect(CSSLength.from('max(1px, 2px)').toString(), equals('2px'));
      expect(CSSFunction.computeValue(CSSNumber(2)), equals(CSSNumber(2)));
      expect(CSSFunction.computeValue(CSSGeneric('x')), isNull);
    });

    // Regression: `compute()` reduced the (empty) `computedCSSLength` instead
    // of `computedCSSNumber`, throwing `StateError`.
    test('max() / min() of plain numbers', () {
      expect(CSSMax.parse('max(1, 3, 2)')!.compute(), equals(CSSNumber(3)));
      expect(CSSMin.parse('min(4, 2, 3)')!.compute(), equals(CSSNumber(2)));
      expect(CSSMax.parse('max(1.5, -2)')!.compute(), equals(CSSNumber(1.5)));
      expect(CSSMin.parse('min(1.5, -2)')!.compute(), equals(CSSNumber(-2)));

      // Mixed lengths and numbers still can't be computed:
      expect(CSSMax.parse('max(1px, 2)')!.compute(), isNull);
    });

    test('units and lengths', () {
      for (var unit in CSSUnit.values) {
        expect(parseCSSUnit(getCSSUnitName(unit)), equals(unit));
      }
      expect(parseCSSUnit('xx', CSSUnit.em), equals(CSSUnit.em));
      expect(parseCSSUnit(' ', CSSUnit.px), equals(CSSUnit.px));
      expect(parseCSSUnit(null), isNull);
      expect(getCSSUnitName(null, CSSUnit.pt), equals('pt'));
      expect(getCSSUnitName(null), isNull);
      expect(isCSSViewportUnit(CSSUnit.vmax), isTrue);
      expect(isCSSViewportUnit(CSSUnit.px), isFalse);

      var l = CSSLength.parse('12.5%')!;
      expect(l.value, equals(12.5));
      expect(l.isPercent, isTrue);
      expect(l.isPx, isFalse);
      expect(l.toString(), equals('12.5%'));
      expect(CSSLength.parse('-.5em')!.value, equals(-0.5));
      expect(CSSLength.parse('10')!.unit, equals(CSSUnit.px));
      expect(CSSLength.parse('abc'), isNull);
      expect(CSSLength.parse(null), isNull);
      expect(CSSLength.from(l), same(l));
      expect(CSSLength.from(5), isNull);
      expect(CSSLength.from(null), isNull);
      expect(CSSLength.valueToString(2.0, CSSUnit.rem), equals('2rem'));
      expect(CSSLength(1, CSSUnit.cm).hashCode, isNot(CSSLength(1).hashCode));

      var context = DOMContext(
        viewport: Viewport(200, 100),
        resolveCSSViewportUnit: true,
      );
      expect(
        CSSLength(50, CSSUnit.vw).toString(context),
        equals('100px /* DOMContext-original-value: 50vw */'),
      );
      expect(
        CSSLength.resolveValue(context, 10, CSSUnit.vh),
        equals(CSSLength(10)),
      );
      expect(
        CSSLength.resolveValue(null, 10, CSSUnit.vh),
        equals(CSSLength(10, CSSUnit.vh)),
      );
      expect(
        CSSLength.resolveValueAsString(
          context,
          10,
          CSSUnit.vh,
          originalValueAsComment: false,
        ),
        equals('10px'),
      );
    });

    test('numbers', () {
      expect(CSSNumber.parse('1.50')!.toString(), equals('1.5'));
      expect(CSSNumber.parse('2.0')!.toString(), equals('2'));
      expect(CSSNumber.parse('-.25')!.value, equals(-0.25));
      expect(CSSNumber.parse('1px'), isNull);
      expect(CSSNumber.parse(null), isNull);
      expect(CSSNumber(null).value, equals(0));
      var n = CSSNumber(1)..value = null;
      expect(n.value, equals(0));
      expect(CSSNumber.from(n), same(n));
      expect(CSSNumber.from(1), isNull);
      expect(CSSNumber.from(null), isNull);
      expect(CSSNumber(3).hashCode, equals(CSSNumber(3).hashCode));
    });

    test('colors', () {
      var rgb = CSSColor.parse('rgb(10, 20, 30)') as CSSColorRGB;
      expect(rgb.args, equals('10, 20, 30'));
      expect(rgb.argsNoAlpha, equals('10, 20, 30'));
      expect(rgb.toString(), equals('rgb(10, 20, 30)'));
      expect(rgb.hasAlpha, isFalse);
      expect(rgb.inverse.toString(), equals('rgb(245, 235, 225)'));
      expect(rgb.asCSSColorHEX.toString(), equals('#0a141e'));
      expect(rgb.asCSSColorRGB, same(rgb));
      expect(rgb.asCSSColorRGBA.toString(), equals('rgb(10, 20, 30)'));
      rgb
        ..red = 300
        ..green = -5
        ..blue = 7;
      expect(rgb.args, equals('255, 0, 7'));

      var rgba = CSSColor.parse('rgba(1, 2, 3, 0.5)') as CSSColorRGBA;
      expect(rgba.hasAlpha, isTrue);
      expect(rgba.toString(), equals('rgba(1, 2, 3, 0.5)'));
      expect(rgba.argsWithoutAlpha, equals('1, 2, 3'));
      expect(rgba.asCSSColorRGBA, same(rgba));
      rgba.alpha = 1.0;
      expect(rgba.toString(), equals('rgb(1, 2, 3)'));
      expect(CSSColorRGBA.parse('rgba(1, 2, 3, 0.2)')!.alpha, equals(0.2));
      expect(CSSColorRGBA.from('rgba(1, 2, 3, 0.2)'), isA<CSSColorRGBA>());
      expect(CSSColor.parse('rgba(1, 2, 3, 1)'), isNot(isA<CSSColorRGBA>()));

      var hex3 = CSSColorHEX('#abc');
      expect(hex3.toString(), equals('#aabbcc'));
      expect(hex3.inverse.toString(), equals('#554433'));
      expect(hex3.asCSSColorHEX, same(hex3));
      expect(hex3.asCSSColorRGB.toString(), equals('rgb(170, 187, 204)'));
      expect(CSSColorHEX.parse('#abcd'), isNull);
      expect(CSSColorHEX.parse('red'), isNull);
      expect(CSSColorHEX.from(hex3), same(hex3));
      expect(CSSColorHEX.from('#000'), isA<CSSColorHEX>());
      expect(CSSColorHEX.from(1), isNull);
      expect(CSSColorHEX.from(null), isNull);
      expect(CSSColorHEX.fromRGB(255, 0, 0).toString(), equals('#ff0000'));

      var hexA = CSSColorHEXAlpha('#ff000080');
      expect(hexA.hasAlpha, isTrue);
      expect(hexA.alpha, closeTo(0.5, 0.01));
      expect(hexA.toString(), equals('#ff000080'));
      expect(
        hexA.asCSSColorRGBA.toString(),
        startsWith('rgba(255, 0, 0, 0.50'),
      );
      expect(hexA.asCSSColorRGB, isA<CSSColorRGBA>());
      hexA.alpha = 1.0;
      expect(hexA.toString(), equals('#ff0000'));
      expect(CSSColorHEXAlpha.parse('#00000000')!.alpha, equals(0));
      expect(CSSColorHEXAlpha.from('#11223344'), isA<CSSColorHEXAlpha>());

      var name = CSSColor.parse('Tomato') as CSSColorName;
      expect(name.name, equals('tomato'));
      expect(name.toString(), equals('tomato'));
      expect(name.args, equals('255, 99, 71'));
      expect(CSSColorName.from(name), same(name));
      expect(CSSColorName.from('white'), isA<CSSColorName>());
      expect(CSSColorName.from(1), isNull);
      expect(CSSColorName.parse('notacolor'), isNull);
      expect(CSSColorName.parse(' '), isNull);

      expect(CSSColor.from([1, 2, 3]).toString(), equals('rgb(1, 2, 3)'));
      expect(
        CSSColor.from([1, 2, 3, 0.4]).toString(),
        equals('rgba(1, 2, 3, 0.4)'),
      );
      expect(CSSColor.from([1, 2]), isNull);
      expect(
        CSSColor.from({'r': 1, 'green': 2, 'b': 3}).toString(),
        equals('rgb(1, 2, 3)'),
      );
      expect(
        CSSColor.from({'red': 1, 'g': 2, 'blue': 3, 'a': 0.1}).toString(),
        equals('rgba(1, 2, 3, 0.1)'),
      );
      expect(CSSColor.from({'r': 1}), isNull);
      expect(CSSColor.from(hex3), same(hex3));
      expect(CSSColor.from(rgba), same(rgba));
      expect(CSSColor.from(null), isNull);
      expect(CSSColor.from(1), isNull);
      expect(CSSColor.parse(null), isNull);
      expect(CSSColorRGB.from('rgb(1,2,3)'), isA<CSSColorRGB>());
      expect(CSSColorRGB.from(rgb), same(rgb));
      expect(CSSColorRGB.from(1), isNull);
      expect(CSSColorRGB.from(null), isNull);
      expect(CSSColorRGB.parse('nope'), isNull);

      expect(CSSColor.parse('#ffffff'), equals(CSSColor.parse('#fff')));
      expect(
        CSSColor.parse('#ffffff').hashCode,
        equals(CSSColor.parse('#fff').hashCode),
      );
      expect(CSSColor.parse('#000')!.inverse.toString(), equals('#ffffff'));
    });

    // Regression: `CSSColorName._` ignored its `alpha` argument, leaving
    // `_alpha` null (`hasAlpha` always true).
    test('CSSColorName keeps its alpha', () {
      expect(CSSColorName('black').alpha, equals(1.0));
      expect(CSSColorName('black').hasAlpha, isFalse);
      expect(CSSColorName('transparent').alpha, equals(0.0));
      expect(CSSColorName('transparent').hasAlpha, isTrue);

      var rgba = CSSColorName('red').asCSSColorRGBA;
      expect([rgba.red, rgba.green, rgba.blue], equals([255, 0, 0]));
      expect(rgba.alpha, equals(1.0));
      expect(CSSColorName('transparent').asCSSColorRGBA.alpha, equals(0.0));
    });

    test('borders', () {
      for (var style in CSSBorderStyle.values) {
        expect(
          parseCSSBorderStyle(getCSSBorderStyleName(style)),
          equals(style),
        );
      }
      expect(parseCSSBorderStyle('wavy'), isNull);
      expect(parseCSSBorderStyle(null), isNull);

      var b = CSSBorder.parse('2px dashed rgba(0, 0, 0, 0.5)')!;
      expect(b.size, equals(CSSLength(2)));
      expect(b.style, equals(CSSBorderStyle.dashed));
      expect(b.color, isA<CSSColorRGBA>());
      expect(b.toString(), equals('2px dashed rgba(0, 0, 0, 0.5)'));

      var noSize = CSSBorder.parse('solid red')!;
      expect(noSize.toString(), equals('solid red'));
      expect(CSSBorder().toString(), equals('none'));
      expect(CSSBorder.parse('bad'), isNull);
      expect(CSSBorder.parse(null), isNull);
      expect(CSSBorder.from(b), same(b));
      expect(CSSBorder.from('1px dotted'), isA<CSSBorder>());
      expect(CSSBorder.from(1), isNull);
      expect(CSSBorder.from(null), isNull);
    });

    test('backgrounds', () {
      for (var r in CSSBackgroundRepeat.values) {
        expect(
          parseCSSBackgroundRepeat(getCSSBackgroundRepeatName(r)!),
          equals(r),
        );
      }
      expect(parseCSSBackgroundRepeat('x'), isNull);
      expect(getCSSBackgroundRepeatName(null), isNull);

      for (var b in CSSBackgroundBox.values) {
        expect(parseCSSBackgroundBox(getCSSBackgroundBoxName(b)!), equals(b));
      }
      expect(parseCSSBackgroundBox('x'), isNull);
      expect(getCSSBackgroundBoxName(null), isNull);

      for (var a in CSSBackgroundAttachment.values) {
        expect(
          parseCSSBackgroundAttachment(getCSSBackgroundAttachmentName(a)!),
          equals(a),
        );
      }
      expect(parseCSSBackgroundAttachment('x'), isNull);
      expect(getCSSBackgroundAttachmentName(null), isNull);

      var color = CSSBackground.parse('#ff0000')!;
      expect(color.hasImages, isFalse);
      expect(color.imagesLength, equals(0));
      expect(color.firstImage, isNull);
      expect(color.getImage(0), isNull);
      expect(color.toString(), equals('#ff0000'));

      var img = CSSBackground.parse(
        'url("bg.png") center / cover no-repeat fixed padding-box content-box '
        '#000',
      )!;
      expect(img.imagesLength, equals(1));
      var first = img.firstImage!;
      expect(first.url!.url, equals('bg.png'));
      expect(first.position, equals('center'));
      expect(first.size, equals('cover'));
      expect(first.repeat, equals(CSSBackgroundRepeat.noRepeat));
      expect(first.attachment, equals(CSSBackgroundAttachment.fixed));
      expect(first.origin, equals(CSSBackgroundBox.paddingBox));
      expect(first.clip, equals(CSSBackgroundBox.contentBox));
      expect(
        img.toString(),
        equals(
          'url("bg.png") center / cover no-repeat fixed padding-box '
          'content-box #000000',
        ),
      );

      var colorFirst = CSSBackground.parse('#fff url(a.png)')!;
      expect(colorFirst.color.toString(), equals('#ffffff'));
      expect(colorFirst.firstImage!.url!.url, equals('a.png'));

      var gradient = CSSBackground.parse(
        'linear-gradient(red, blue) space local',
      )!;
      var g = gradient.firstImage!.gradient!;
      expect(g.type, equals('linear-gradient'));
      expect(g.parameters, equals(['red', 'blue']));
      expect(
        gradient.toString(),
        equals('linear-gradient(red, blue) space local'),
      );

      var layers = CSSBackground.parse(
        'url(a.png), url(b.png) no-repeat #111',
      )!;
      expect(layers.imagesLength, equals(2));
      expect(layers.images[1].url!.url, equals('b.png'));
      expect(layers.getImage(1)!.repeat, equals(CSSBackgroundRepeat.noRepeat));
      expect(layers.toString(), endsWith('#111111'));

      expect(CSSBackground.parse('not a background'), isNull);
      expect(CSSBackground.from(color), same(color));
      expect(CSSBackground.from('#000'), isA<CSSBackground>());
      expect(CSSBackground.from(1), isNull);
      expect(CSSBackground.from(null), isNull);

      var byURL = CSSBackground.url(
        CSSURL('u.png'),
        repeat: CSSBackgroundRepeat.round,
        attachment: CSSBackgroundAttachment.local,
        origin: CSSBackgroundBox.borderBox,
        position: '1px 2px',
        color: CSSColor.parse('#000'),
      );
      expect(
        byURL.toString(),
        equals('url("u.png") 1px 2px round local border-box #000000'),
      );

      var byGradient = CSSBackground.gradient(
        CSSBackgroundGradient('radial-gradient', ['red', 'blue']),
        size: 'auto',
        position: 'left',
      );
      expect(
        byGradient.toString(),
        equals('radial-gradient(red, blue) left / auto'),
      );

      expect(
        CSSBackground.images([CSSBackgroundImage.url(CSSURL('x.png'))])
            .toString(),
        equals('url("x.png")'),
      );
      expect(CSSBackground.color(null).toString(), equals(''));

      expect(CSSBackgroundImage.parse(null), isNull);
      expect(CSSBackgroundImage.parse('nope'), isNull);
      expect(CSSBackgroundImage.from('url(a.png)'), isA<CSSBackgroundImage>());
      var bi = CSSBackgroundImage.url(CSSURL('a'));
      expect(CSSBackgroundImage.from(bi), same(bi));
      expect(CSSBackgroundImage.from(1), isNull);
      expect(CSSBackgroundImage.from(null), isNull);
    });

    // Regression: the `repeat` regexp alternation matched `repeat` before
    // `repeat-x`/`repeat-y`, so both parsed as `repeat`.
    test('background repeat-x / repeat-y', () {
      final expected = {
        'repeat-x': CSSBackgroundRepeat.repeatX,
        'repeat-y': CSSBackgroundRepeat.repeatY,
        'no-repeat': CSSBackgroundRepeat.noRepeat,
        'repeat': CSSBackgroundRepeat.repeat,
        'space': CSSBackgroundRepeat.space,
        'round': CSSBackgroundRepeat.round,
      };
      for (final e in expected.entries) {
        final background = CSSBackground.parse('url(a.png) ${e.key}')!;
        expect(background.firstImage!.repeat, equals(e.value), reason: e.key);
        expect(background.toString(), contains(e.key), reason: e.key);
      }
    });

    test('url()', () {
      expect(CSSURL.parse('url("a b.png")')!.url, equals('a b.png'));
      expect(CSSURL.parse("url('q.png')")!.url, equals('q.png'));
      expect(CSSURL.parse('url(plain.png)')!.url, equals('plain.png'));
      expect(CSSURL.parse('nope'), isNull);
      expect(CSSURL.parse(' '), isNull);
      expect(CSSURL.parse(null), isNull);

      expect(CSSURL('a.png').toString(), equals('url("a.png")'));
      expect(CSSURL('a"b').toString(), equals("url('a\"b')"));
      expect(CSSURL('a"b\'c').toString(), equals('url(a"b\'c)'));

      var context = DOMContext(resolveCSSURL: true)
        ..cssURLResolver = (u) => '/cdn/$u';
      expect(CSSURL('a.png').toString(context), equals('url("/cdn/a.png")'));

      var u = CSSURL('x');
      expect(CSSURL.from(u), same(u));
      expect(CSSURL.from('url(x)'), equals(u));
      expect(CSSURL.from(1), isNull);
      expect(CSSURL.from(null), isNull);
      expect(u.hashCode, equals(CSSURL('x').hashCode));
    });

    test('generic values', () {
      expect(CSSGeneric.parse('  auto  ')!.value, equals('auto'));
      expect(CSSGeneric.parse(' '), isNull);
      expect(CSSGeneric.parse(null), isNull);
      var g = CSSGeneric('x');
      expect(CSSGeneric.from(g), same(g));
      expect(CSSGeneric.from(1), isNull);
      expect(CSSGeneric.from(null), isNull);
      expect(g.hashCode, equals(CSSGeneric('x').hashCode));
      expect(CSSGeneric('a') == CSSGeneric('b'), isFalse);
    });
  });

  group('DOMTemplate', () {
    test('helpers', () {
      expect(DOMTemplate.from(null), isNull);
      expect(DOMTemplate.from(1), isNull);
      var t = DOMTemplate.parse('Hi {{name}}');
      expect(DOMTemplate.from(t), same(t));
      expect(DOMTemplate.from('Hi {{name}}').toString(), equals('Hi {{name}}'));

      expect(DOMTemplate.possiblyATemplate('{{x}}'), isTrue);
      expect(DOMTemplate.possiblyATemplate('{x}}'), isFalse);
      expect(DOMTemplate.possiblyATemplate('{{x'), isFalse);
      expect(DOMTemplate.possiblyATemplate('ab'), isFalse);

      expect(DOMTemplate.objectToString(null), equals(''));
      expect(DOMTemplate.objectToString('s'), equals('s'));
      expect(DOMTemplate.objectToString($b(content: 'x')), equals('<b>x</b>'));
      expect(DOMTemplate.objectToString([1, 'a', null]), equals('1a'));
      expect(DOMTemplate.objectToString({'k': 'v'}), equals('k: v'));
      expect(DOMTemplate.objectToString(1.5), equals('1.5'));

      expect(DOMTemplate.parse('ab').toString(), equals('ab'));
      expect(DOMTemplate.parse('plain text').toString(), equals('plain text'));
      expect(DOMTemplate.tryParse(null), isNull);
      expect(DOMTemplate.tryParse('ab'), isNull);
      expect(DOMTemplate.tryParse('plain text'), isNull);
    });

    // Regression: `DOMTemplateBlockCondition` subclasses copied without their
    // `elseCondition`, dropping `{{?:x}}`/`{{?!x}}`/`{{?}}` branches.
    test('copy() keeps else branches', () {
      for (final source in [
        '{{:a}}x{{?:b}}y{{?}}z{{/}}',
        '{{!a}}x{{?!b}}y{{?}}z{{/}}',
        '{{:a=="1"}}x{{?:a=="2"}}y{{/}}',
        '{{*:list}}[{{.}}]{{?}}empty{{/}}',
      ]) {
        var t = DOMTemplate.parse(source);
        var copy = t.copy();
        expect(copy.toString(), equals(source), reason: source);

        for (final vars in <Map<String, Object?>>[
          {},
          {'a': true},
          {'b': true},
          {'a': '1'},
          {'a': '2'},
          {
            'list': [1, 2],
          },
        ]) {
          expect(
            (copy as DOMTemplateNode).buildAsString(vars),
            equals(t.buildAsString(vars)),
            reason: '$source $vars',
          );
        }
      }

      // The copy's else chain is independent of the original:
      var t = DOMTemplate.parse('{{:a}}x{{?}}z{{/}}');
      var copy = t.copy() as DOMTemplateNode;
      var copyIf = copy.nodes.single as DOMTemplateBlockCondition;
      var originalIf = t.nodes.single as DOMTemplateBlockCondition;
      expect(copyIf.elseCondition, isA<DOMTemplateBlockElse>());
      expect(
        identical(copyIf.elseCondition, originalIf.elseCondition),
        isFalse,
      );
    });

    test('copy() and isEmpty', () {
      var t = DOMTemplate.parse(
        'A{{:a}}x{{/}}{{!n}}not{{/}}{{?v}}none{{/}}{{*:list}}[{{.}}]{{/}}'
        '{{:c=="1"}}one{{/}}{{#q}}{{intl:k}}{{v}}',
      );
      var copy = t.copy();
      expect(copy.toString(), equals(t.toString()));
      expect(copy.isEmpty, isFalse);
      expect(copy.isNotEmpty, isTrue);
      expect(DOMTemplate.parse('{{}}').isEmpty, isTrue);

      var vars = {
        'a': true,
        'list': [1, 2],
      };
      expect(
        (copy as DOMTemplateNode).buildAsString(vars),
        equals(t.buildAsString(vars)),
      );
    });

    test('block query with element provider', () {
      var t = DOMTemplate.parse('[{{#box}}]');
      expect(
        t.buildAsString({}, elementProvider: (q) => '<i>$q</i>'),
        equals('[<i>#box</i>]'),
      );
      expect(t.toString(), equals('[{{#box}}]'));
    });

    test('else-not block', () {
      var t = DOMTemplate.parse('{{:a}}A{{?!b}}not-b{{/}}');
      expect(t.buildAsString({'a': false}), equals('not-b'));
      expect(t.buildAsString({'a': false, 'b': true}), equals(''));
    });

    // Regression: the `{{?!x}}` parser branch also added the else-not block as
    // a child of the if block, so it rendered inside the if content.
    test('else-not block is not rendered when the if-condition is true', () {
      var t = DOMTemplate.parse('{{:a}}A{{?!b}}not-b{{/}}');
      expect(t.buildAsString({'a': true}), equals('A'));
      expect(t.buildAsString({'a': true, 'b': true}), equals('A'));
      expect(t.buildAsString({'a': false}), equals('not-b'));
      expect(t.buildAsString({'a': false, 'b': true}), equals(''));

      var ifBlock = t.nodes.single as DOMTemplateBlockCondition;
      expect(ifBlock.nodes.whereType<DOMTemplateBlockElseNot>(), isEmpty);
      expect(ifBlock.elseCondition, isA<DOMTemplateBlockElseNot>());
    });

    // Regression: `DOMTemplateBlockElseNot.toString()` emitted `{{?!:b}`
    // without the closing brace and its nodes.
    test('else-not block toString() round-trip', () {
      for (final source in [
        '{{:a}}A{{?!b}}not-b{{/}}',
        '{{:a}}A{{?!b}}not-b{{?}}else{{/}}',
        'x{{!a}}A{{?!b.c}}B{{?:d}}D{{/}}y',
      ]) {
        var t = DOMTemplate.parse(source);
        expect(t.toString(), equals(source), reason: source);
        expect(
          DOMTemplate.parse(t.toString()).toString(),
          equals(source),
          reason: source,
        );
      }

      var t = DOMTemplate.parse('{{:a}}A{{?!b}}not-b{{?}}else{{/}}');
      expect(t.buildAsString({'a': true}), equals('A'));
      expect(t.buildAsString({}), equals('not-b'));
      expect(t.buildAsString({'b': true}), equals('else'));
    });

    test('intl messages through a context resolver', () {
      var t = DOMTemplate.parse('{{intl:hello}} {{intl:missing}}!');
      expect(
        t.buildAsString(
          {},
          intlMessageResolver: (k, [p]) => k == 'hello' ? 'Olá' : null,
        ),
        equals('Olá !'),
      );
    });
  });

  group('DOMHtmlGeneric (package:html)', () {
    test('parse and convert nodes', () {
      var html = DOMHtmlGeneric();
      var fragment = html.parse('<div id="a">x<b>y</b></div>tail');

      var div = html.querySelector(fragment, '#a');
      expect(div, isA<html_dom.Element>());
      expect(html.querySelector(div, 'b'), isA<html_dom.Element>());
      expect(html.querySelector('nope', 'b'), isNull);

      expect(html.getChildrenNodes(div).length, equals(2));
      expect(html.getChildrenNodes(fragment).length, equals(2));
      expect(html.getChildrenNodes('x'), isEmpty);

      var text = (div as html_dom.Element).nodes.first;
      expect(html.toTextNode(text)!.text, equals('x'));
      expect(html.toTextNode(div), isNull);

      expect(html.toHTML(div), equals('<div id="a">x<b>y</b></div>'));
      expect(html.toHTML(text), equals('x'));
      expect(html.toHTML(html_dom.Comment('c')), contains('c'));
      expect(html.toHTML(1), equals(''));

      var dom = html.toDOMElement(div)!;
      expect(dom.tag, equals('div'));
      expect(dom.getAttributeValue('id'), equals('a'));
      expect(html.toDOMElement(text), isNull);
    });

    test(
      'toDOMElement() content (package:html is the platform DOMHtml)',
      () {
        var html = DOMHtmlGeneric();
        var div = html.querySelector(
          html.parse('<div id="a">x<b>y</b></div>'),
          '#a',
        );
        expect(
          html.toDOMElement(div)!.buildHTML(),
          equals('<div id="a">x<b>y</b></div>'),
        );
      },
      // On browsers `DOMHtml()` is the web implementation, which doesn't
      // convert `package:html` nodes:
      testOn: 'vm',
    );
  });
}
