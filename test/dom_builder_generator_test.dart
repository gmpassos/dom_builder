import 'package:dom_builder/dom_builder.dart';
import 'package:test/test.dart';

import 'dom_builder_domtest.dart';

void main() {
  group('dom_builder', () {
    setUp(() {});

    test('generator', () {
      var generator = TestGenerator();

      var div = $tagHTML(
          '<div class="container"><span class="s1">Span Text<div class="d2">More text</div></span></div>')!;

      var genDiv = div.buildDOM(generator: generator) as TestElem;

      expect(genDiv, isNotNull);

      expect(genDiv.attributes['class'], equals('container'));
      expect(genDiv.nodesLength, equals(1));

      var genSpan = genDiv.get(0) as TestElem;

      expect(genSpan.attributes['class'], equals('s1'));
      expect(genSpan.text, equals('Span TextMore text'));

      var genDiv2 = genSpan.get(1) as TestElem;

      expect(genDiv2.attributes['class'], equals('d2'));
      expect(genDiv2.text, equals('More text'));
    });

    test('generator treeMap 1', () {
      var generator = TestGenerator();

      var div = $tagHTML(
          '<div class="container"><span class="s1">Span Text<div class="d2">More text</div></span></div>')!;

      var treeMap = generator.generateMapped(div);

      var genDiv = treeMap.rootElement as TestElem;

      expect(genDiv, isNotNull);
      expect(treeMap.getMappedDOMNode(genDiv), equals(div));

      expect(genDiv.attributes['class'], equals('container'));
      expect(genDiv.nodesLength, equals(1));

      var genSpan = genDiv.get(0) as TestElem;

      expect(genSpan.attributes['class'], equals('s1'));
      expect(genSpan.text, equals('Span TextMore text'));

      var genDiv2 = genSpan.get(1) as TestElem;

      expect(genDiv2.attributes['class'], equals('d2'));
      expect(genDiv2.text, equals('More text'));
    });

    test('generator treeMap: text only', () {
      var generator = TestGenerator();

      var treeMap = generator.createDOMTreeMap();

      var text = TextNode('txt!');

      var genText = treeMap.generate(generator, text)!;

      expect(text, isNotNull);
      expect(treeMap.getMappedDOMNode(genText), equals(text));

      expect(genText.text, equals('txt!'));
    });

    test('generator treeMap: external element', () {
      var generator = TestGenerator();

      var treeMap = generator.createDOMTreeMap();

      var div = $div(id: 'd1', classes: 'container', content: [
        '<b>BBB</b>',
        (parent) {
          return TestElem('x-tag')..add(TestText('X'));
        },
        '<b>CCC</b>',
        () {
          return TestElem('z-tag')..add(TestText('Z'));
        },
        () {
          return '<i>III<i>';
        },
      ]);

      var genDiv = treeMap.generate(generator, div)!;

      expect(genDiv, isNotNull);
      expect(genDiv.text, equals('BBBXCCCZIII'));

      var subNodes = (genDiv as TestElem).nodes;
      expect(subNodes[0].text, equals('BBB'));
      expect(subNodes[1].text, equals('X'));
      expect(subNodes[2].text, equals('CCC'));
      expect(subNodes[3].text, equals('Z'));
      expect(subNodes[4].text, equals('III'));

      expect(subNodes.where((e) => e.parent == null).isEmpty, isTrue);
    });

    test('generator treeMap: registered generator', () {
      var generator = TestGenerator();

      generator.registerElementGenerator(ElementGeneratorFunctions(
        'uc',
        (domGenerator, tag, parent, attributes, contentHolder, contentNodes,
                domContext) =>
            TestText(contentHolder!.text.toUpperCase()),
      ));

      generator.registerElementGenerator(ElementGeneratorFunctions(
        'lc',
        (domGenerator, tag, parent, attributes, contentHolder, contentNodes,
                domContext) =>
            TestText(contentHolder!.text.toLowerCase()),
      ));

      var treeMap = generator.createDOMTreeMap();

      var div = $div(content: [
        '<uc>BBbb</uc>',
        '<lc>BBbb</lc>',
      ]);

      var genDiv = treeMap.generate(generator, div)!;

      expect(genDiv, isNotNull);
      expect(genDiv.text, equals('BBBBbbbb'));
    });

    test('generator mapped: operations', () {
      var generator = TestGenerator();

      var div = $tagHTML('<div><b>BBB</b><i>III</i><u>UUU</u></div>')!;
      expect(div, isNotNull);

      var bNode = div.node('b') as DOMElement;
      expect(bNode, isNotNull);
      expect(bNode.tag, equals('b'));

      var iNode = div.node('i') as DOMElement;
      expect(iNode, isNotNull);
      expect(iNode.tag, equals('i'));

      var uNode = div.node('u') as DOMElement;
      expect(uNode, isNotNull);
      expect(uNode.tag, equals('u'));

      var treeMap = generator.generateMapped(div);

      var genDiv = treeMap.rootElement as TestElem;
      expect(genDiv.text, equals(div.text));

      expect(genDiv.text, equals('BBBIIIUUU'));

      expect(bNode.indexInParent, equals(0));

      expect(bNode.isInSameParent(iNode), isTrue);
      expect(bNode.isInSameParent(div), isFalse);

      expect(bNode.isNextNode(iNode), isTrue);
      expect(iNode.isPreviousNode(bNode), isTrue);
      expect(bNode.isConsecutiveNode(iNode), isTrue);
      expect(iNode.isConsecutiveNode(bNode), isTrue);

      expect(treeMap.moveDownByDOMNode(bNode), isTrue);
      expect(
          div.buildHTML(), equals('<div><i>III</i><b>BBB</b><u>UUU</u></div>'));
      expect(genDiv.text, equals('IIIBBBUUU'));
      expect(bNode.indexInParent, equals(1));

      expect(treeMap.moveUpByDOMNode(bNode), isTrue);
      expect(
          div.buildHTML(), equals('<div><b>BBB</b><i>III</i><u>UUU</u></div>'));
      expect(genDiv.text, equals('BBBIIIUUU'));
      expect(bNode.indexInParent, equals(0));

      expect(treeMap.moveUpByDOMNode(uNode), isTrue);
      expect(
          div.buildHTML(), equals('<div><b>BBB</b><u>UUU</u><i>III</i></div>'));
      expect(genDiv.text, equals('BBBUUUIII'));
      expect(uNode.indexInParent, equals(1));

      expect(treeMap.moveUpByDOMNode(uNode), isTrue);
      expect(
          div.buildHTML(), equals('<div><u>UUU</u><b>BBB</b><i>III</i></div>'));
      expect(genDiv.text, equals('UUUBBBIII'));
      expect(uNode.indexInParent, equals(0));

      var copyB = treeMap.duplicateByDOMNode(bNode)!;

      expect(copyB, isNotNull);
      expect(copyB.domNode.text, equals('BBB'));
      expect(copyB.node.text, equals('BBB'));

      expect(div.buildHTML(),
          equals('<div><u>UUU</u><b>BBB</b><b>BBB</b><i>III</i></div>'));
      expect(genDiv.text, equals('UUUBBBBBBIII'));

      var removed = treeMap.removeByDOMNode(bNode)!;
      expect(removed.domNode, equals(bNode));
      expect(
          div.buildHTML(), equals('<div><u>UUU</u><b>BBB</b><i>III</i></div>'));
      expect(genDiv.text, equals('UUUBBBIII'));

      var copyU = treeMap.duplicateByDOMNode(uNode)!;

      expect(copyU, isNotNull);
      expect(copyU.domNode.parent, isNotNull);
      expect(copyU.node.parent, isNotNull);
      treeMap.matchesMapping(copyU.domNode, copyU.node);
      expect(copyU.domNode.text, equals('UUU'));
      expect(copyU.node.text, equals('UUU'));

      copyU.domNode.add(TextNode('X'));
      (copyU.node as TestElem).add(TestText('X'));
      expect(copyU.domNode.text, equals('UUUX'));
      expect(copyU.node.text, equals('UUUX'));

      var copyU2 = treeMap.duplicateByDOMNode(copyU.domNode)!;
      expect(copyU2, isNotNull);
      expect(copyU2.domNode.parent, isNotNull);
      expect(copyU2.node.parent, isNotNull);
      treeMap.matchesMapping(copyU2.domNode, copyU.node);
      expect(copyU2.domNode.text, equals('UUUX'));
      expect(copyU2.node.text, equals('UUUX'));

      expect(
          div.buildHTML(),
          equals(
              '<div><u>UUU</u><u>UUUX</u><u>UUUX</u><b>BBB</b><i>III</i></div>'));
      expect(genDiv.text, equals('UUUUUUXUUUXBBBIII'));

      var mergeU = treeMap.mergeNearStringNodes(uNode, copyU.domNode,
          onlyCompatibles: true)!;

      expect(mergeU, isNotNull);

      expect(copyU.domNode.parent, isNull);
      expect(copyU.nodeCast<TestElem>().parent, isNull);
      expect(copyU.domNode.nodes.length, equals(0));
      expect(copyU.nodeCast<TestElem>().nodes.length, equals(0));

      expect(div.buildHTML(),
          equals('<div><u>UUUUUUX</u><u>UUUX</u><b>BBB</b><i>III</i></div>'));
      expect(mergeU.domNode.text, equals('UUUUUUX'));
      expect(mergeU.node.text, equals('UUUUUUX'));
      expect(mergeU.domNode.parent, isNotNull);
      expect(mergeU.node.parent, isNotNull);
      expect(
          mergeU.domNode.nodes.where((e) => e.parent == null).isEmpty, isTrue);
      expect(
          mergeU
              .nodeCast<TestElem>()
              .nodes
              .where((e) => e.parent == null)
              .isEmpty,
          isFalse);
      expect(mergeU.domNode, equals(uNode));

      expect(mergeU.domNode.hasOnlyTextNodes, isTrue);
      expect(mergeU.domNode.hasOnlyElementNodes, isFalse);
      expect(div.hasOnlyTextNodes, isFalse);
      expect(div.hasOnlyElementNodes, isTrue);

      var mergeU2 = treeMap.mergeNearStringNodes(uNode, copyU2.domNode);
      expect(mergeU2, isNotNull);
      expect(div.buildHTML(),
          equals('<div><u>UUUUUUXUUUX</u><b>BBB</b><i>III</i></div>'));

      expect(treeMap.emptyByDOMNode(div), isTrue);
      expect(div.buildHTML(), equals('<div></div>'));
      expect(genDiv.text, equals(''));
    });

    test('external element', () {
      var generator = TestGenerator();

      var div = $tagHTML('<div class="container"></div>')!;

      var span = TestElem('span')..add(TestText('span element'));
      div.add(span);

      var text = TestText('text element');
      div.add(text);

      var genDiv = div.buildDOM(generator: generator) as TestElem;

      expect(genDiv, isNotNull);

      expect(genDiv.attributes['class'], equals('container'));
      expect(genDiv.nodesLength, equals(2));

      var genSpan = genDiv.get(0);

      expect(genSpan, equals(span));

      var genText = genDiv.get(1);

      expect(genText, equals(text.asTestElem));
    });

    test('test revert', () {
      var generator = TestGenerator();

      generator.registerElementGenerator(TestNodeGenerator('x-tag', 'x-tag'));

      var div = $tagHTML(
          '<div class="container"><span class="s1">Span Text<div class="d2">More text</div></span><x-tag>XTAG</x-tag></div>')!;

      print(div);
      print(div.buildHTML());

      var genDiv = div.buildDOM(generator: generator) as TestElem?;
      expect(genDiv, isNotNull);

      var div2 =
          generator.revert(div.treeMap as DOMTreeMap<TestNode>?, genDiv)!;
      expect(div2, isNotNull);

      expect(div2.buildHTML(), equals(div.buildHTML()));
    });

    test('domActionExecutor', () {
      var generator = TestGenerator();

      generator.domActionExecutor = TestActionExecutor();

      var div = $tagHTML<DIVElement>(
          '<div class="container"><span id="hi">Hi!</span> <button action="#hi.show()">Click</button></div>')!;

      var spanHi = div.selectByID('hi') as DOMElement;
      expect(spanHi, isNotNull);

      var clicks = <int>[];
      spanHi.onClick.listen((event) => clicks.add(clicks.length));

      var treeMap = generator.generateMapped(div);

      var genDiv = treeMap.rootElement as TestElem;
      expect(genDiv, isNotNull);
    });

    test('delegate', () {
      var generator0 = TestGenerator();

      var generator = DOMGeneratorDelegate(generator0);

      generator.domActionExecutor = TestActionExecutor();

      var div = $tagHTML<DIVElement>(
          '<div class="container"><span id="hi">Hi!</span> <button action="#hi.show()">Click</button></div>')!;

      div.add((parent) {
        return TestElem('x-tag')..add(TestText('X'));
      });

      var spanHi = div.selectByID('hi') as DOMElement;
      expect(spanHi, isNotNull);

      var treeMap = generator.generateMapped(div);

      var genDiv = treeMap.rootElement as TestElem;

      expect(genDiv, isNotNull);

      expect(generator.isNodeInDOM(genDiv), isFalse);

      var body = TestElem('body');
      body.add(genDiv);

      expect(generator.isNodeInDOM(genDiv), isTrue);

      var spanHiRuntime = spanHi.runtime;
      var spanHiNode = spanHiRuntime.node as TestElem;

      expect(spanHiNode.tag, equals('span'));
      expect(spanHiNode.attributes['id'], equals('hi'));

      expect(
          spanHiRuntime.replaceBy([
            TestElem('button')..attributes['id'] = 'hi',
          ], remap: true),
          isTrue);

      expect(spanHiRuntime.remove(), isFalse);

      var button = genDiv.nodes
          .whereType<TestElem>()
          .where((e) => e.tag == 'button')
          .first;
      expect(button.attributes['id'], equals('hi'));

      var domButton = treeMap.getMappedDOMNode(button) as DOMElement;
      expect(domButton['id'], equals('hi'));
    });
  });
}
