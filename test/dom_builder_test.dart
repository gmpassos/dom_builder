import 'package:dom_builder/dom_builder.dart';
import 'package:test/test.dart';

void main() {
  group('dom_builder', () {
    setUp(() {});

    test('Basic div', () {
      var div =
          $div(id: 'd1', classes: 'container', style: 'background-color: blue');

      expect(div, isNotNull);
      expect(
          div.buildHTML(),
          equals(
              '<div id="d1" class="container" style="background-color: blue"></div>'));
    });

    test('Basic generic tag', () {
      var div = $tag('foo', classes: 'bar');

      expect(div, isNotNull);
      expect(div.buildHTML(), equals('<foo class="bar"></foo>'));
    });

    test('div content 1', () {
      var div = $div(
          classes: 'container',
          content: ['Simple Text', $span(content: 'Sub text')]);

      expect(div, isNotNull);
      expect(
          div.buildHTML(),
          equals(
              '<div class="container">Simple Text<span>Sub text</span></div>'));
    });

    test('div content 2', () {
      var div = $div(
          classes: 'container',
          content: ['Simple &nbsp; Text', $span(content: 'Sub text')]);

      expect(div, isNotNull);
      expect(
          div.buildHTML(),
          equals(
              '<div class="container"><span>Simple &nbsp; Text</span><span>Sub text</span></div>'));
    });

    test('div content 3', () {
      var div = $div(classes: 'container', content: [
        '<b>Simple &nbsp; Text</b>',
        $span(content: ['Sub', $br, 'text'])
      ]);

      expect(div, isNotNull);
      expect(
          div.buildHTML(),
          equals(
              '<div class="container"><b>Simple &nbsp; Text</b><span>Sub<br>text</span></div>'));
    });

    test('div content 4', () {
      var div = $div(classes: 'container', content: [
        '<b>Simple &nbsp; Text</b>',
        $span(content: (parent) => TestText('ok1'))
      ]);

      expect(div, isNotNull);
      expect(
          div.buildHTML(),
          equals(
              '<div class="container"><b>Simple &nbsp; Text</b><span>ok1</span></div>'));
    });

    test('div content 4', () {
      var div = $div(classes: 'container', content: [
        '<b>Simple &nbsp; Text</b>',
        $span(content: () => TestText('ok2'))
      ]);

      expect(div, isNotNull);
      expect(
          div.buildHTML(),
          equals(
              '<div class="container"><b>Simple &nbsp; Text</b><span>ok2</span></div>'));
    });

    test('div content and apply', () {
      var div = $div(classes: 'container')
          .add('Simple Text')
          .add($span(content: 'Sub text'));

      expect(div, isNotNull);
      expect(
          div.buildHTML(),
          equals(
              '<div class="container">Simple Text<span>Sub text</span></div>'));

      div.applyWhere((e) => e is DOMElement && e.tag == 'span',
          style: 'color: green');

      expect(
          div.buildHTML(),
          equals(
              '<div class="container">Simple Text<span style="color: green">Sub text</span></div>'));
    });

    test('Basic html', () {
      var div = $tagHTML(
          '<DIV class="container">Simple Text<SPAN>Sub text</SPAN></DIV>');

      expect(div, isNotNull);
      expect(
          div.buildHTML(),
          equals(
              '<div class="container">Simple Text<span>Sub text</span></div>'));
    });

    test('build HTML', () {
      var div = $tagHTML(
          '<div class="container"><span class="s1">Span Text<div class="d2">more text</div></span><span>Final Text</span></div>');

      expect(
          div.buildHTML(),
          equals(
              '<div class="container"><span class="s1">Span Text<div class="d2">more text</div></span><span>Final Text</span></div>'));
      expect(
          div.buildHTML(withIdent: true),
          equals(
              '<div class="container">\n  <span class="s1">Span Text<div class="d2">more text</div></span>\n  <span>Final Text</span>\n</div>'));
    });

    test('html add span', () {
      var div = $divHTML(
          '<DIV class="container">Simple Text<SPAN>Sub text</SPAN></DIV>');

      div.add($span(content: 'Final text'));

      expect(div, isNotNull);
      expect(
          div.buildHTML(),
          equals(
              '<div class="container">Simple Text<span>Sub text</span><span>Final text</span></div>'));

      div.applyWhere((e) => e is DOMElement && e.tag == 'span',
          style: 'color: black');

      expect(
          div.buildHTML(),
          equals(
              '<div class="container">Simple Text<span style="color: black">Sub text</span><span style="color: black">Final text</span></div>'));
    });

    test('html insert span', () {
      var div = $divHTML(
          '  <DIV class="container">Simple Text<SPAN>Sub text</SPAN></DIV>  ');

      div.insertAt(1, $span(id: 's1', content: 'Initial text'));

      expect(div, isNotNull);
      expect(
          div.buildHTML(),
          equals(
              '<div class="container">Simple Text<span id="s1">Initial text</span><span>Sub text</span></div>'));

      expect(div.nodeByID('s1').buildHTML(),
          equals('<span id="s1">Initial text</span>'));
      expect(div.node('#s1').buildHTML(),
          equals('<span id="s1">Initial text</span>'));

      expect(div.selectByID('#s1').buildHTML(),
          equals('<span id="s1">Initial text</span>'));
      expect(div.select('#s1').buildHTML(),
          equals('<span id="s1">Initial text</span>'));

      div.insertAt('#s1', $span(id: 's0', content: 'Text 0'));

      expect(
          div.buildHTML(),
          equals(
              '<div class="container">Simple Text<span id="s0">Text 0</span><span id="s1">Initial text</span><span>Sub text</span></div>'));

      div.insertAfter('#s1', $span(id: 's2', content: 'Text 2'));

      expect(
          div.buildHTML(),
          equals(
              '<div class="container">Simple Text<span id="s0">Text 0</span><span id="s1">Initial text</span><span id="s2">Text 2</span><span>Sub text</span></div>'));
    });

    test('generator', () {
      var generator = TestGenerator();

      var div = $tagHTML(
          '<div class="container"><span class="s1">Span Text<div class="d2">More text</div></span></div>');

      var genDiv = div.buildDOM(generator) as TestElem;

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
          '<div class="container"><span class="s1">Span Text<div class="d2">More text</div></span></div>');

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

      var genText = treeMap.generate(generator, text);

      expect(text, isNotNull);
      expect(treeMap.getMappedDOMNode(genText), equals(text));

      expect(genText.text, equals('txt!'));
    });

    test('generator mapped: operations', () {
      var generator = TestGenerator();

      var div = $tagHTML('<div><b>BBB</b><i>III</i><u>UUU</u></div>');
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

      var copyB = treeMap.duplicateByDOMNode(bNode);

      expect(copyB, isNotNull);
      expect(copyB.domNode.text, equals('BBB'));
      expect(copyB.node.text, equals('BBB'));

      expect(div.buildHTML(),
          equals('<div><u>UUU</u><b>BBB</b><b>BBB</b><i>III</i></div>'));
      expect(genDiv.text, equals('UUUBBBBBBIII'));

      var removed = treeMap.removeByDOMNode(bNode);
      expect(removed.domNode, equals(bNode));
      expect(
          div.buildHTML(), equals('<div><u>UUU</u><b>BBB</b><i>III</i></div>'));
      expect(genDiv.text, equals('UUUBBBIII'));

      var copyU = treeMap.duplicateByDOMNode(uNode);

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

      var copyU2 = treeMap.duplicateByDOMNode(copyU.domNode);
      expect(copyU2, isNotNull);
      expect(copyU2.domNode.parent, isNotNull);
      expect(copyU2.node.parent, isNotNull);
      treeMap.matchesMapping(copyU2.domNode, copyU.node);
      expect(copyU2.domNode.text, equals('UUUX'));
      expect(copyU2.node.text, equals('UUUX'));

      expect(div.buildHTML(),
          equals('<div><u>UUU</u><u>UUUX</u><u>UUUX</u><b>BBB</b><i>III</i></div>'));
      expect(genDiv.text, equals('UUUUUUXUUUXBBBIII'));

      var mergeU = treeMap.mergeNearStringNodes(uNode, copyU.domNode);

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
      expect(mergeU.domNode.nodes.where((e) => e.parent == null).isEmpty , isTrue);
      expect(mergeU.nodeCast<TestElem>().nodes.where((e) => e.parent == null).isEmpty , isFalse);
      expect(mergeU.domNode, equals(uNode));

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

      var div = $tagHTML('<div class="container"></div>');

      var span = TestElem('span')..add(TestText('span element'));
      div.add(span);

      var text = TestText('text element');
      div.add(text);

      var genDiv = div.buildDOM(generator) as TestElem;

      expect(genDiv, isNotNull);

      expect(genDiv.attributes['class'], equals('container'));
      expect(genDiv.nodesLength, equals(2));

      var genSpan = genDiv.get(0);

      expect(genSpan, equals(span));

      var genText = genDiv.get(1);

      expect(genText, equals(text.asTestElem));
    });

    test('table element', () {
      var table = $table(
          classes: 'ui-table',
          head: ['ha', 'hb', 'hc'],
          body: ['a', 'b', 'c'],
          foot: ['fa', 'fb', 'fc']);

      expect(
          table.buildHTML(),
          equals(
              '<table class="ui-table"><thead><tr><th>ha</th><th>hb</th><th>hc</th></tr></thead><tbody><tr><td>a</td><td>b</td><td>c</td></tr></tbody><tfoot><tr><td>fa</td><td>fb</td><td>fc</td></tr></tfoot></table>'));
    });

    test('table parse', () {
      var div = $div(classes: 'container', content: [
        $span(id: 's1', content: 'The '),
        $span(id: 's2', style: 'font-weight: bold', content: 'DOM '),
        $span(content: 'Builder'),
        $table(head: [
          'Name',
          'Age'
        ], body: [
          ['Joe', 21],
          ['Smith', 30]
        ])
      ]);

      // Equivalent:

      var div2 = $divHTML('<div class="container"><span>Builder</span></div>')
          .insertAt(0, $span(id: 's1', content: 'The '))
          .insertAfter('#s1',
              $span(id: 's2', style: 'font-weight: bold', content: 'DOM '))
          .add($tagHTML('''
        <table>
          <thead>
            <tr><th>Name</th><th>Age</th></tr>
          </thead>
          <tbody>
            <tr><td>Joe</td><td>21</td></tr>
            <tr><td>Smith</td><td>30</td></tr>
          </tbody>
        </table>
      '''));

      expect(div.buildHTML(withIdent: true),
          equals(div2.buildHTML(withIdent: true)));
    });

    test('Basic input', () {
      var div = $div(content: [
        $label(content: 'Some Label'),
        $input(type: 'text', value: 'Some Text'),
        $br(),
        $textarea(content: 'Title:\nText block.')
      ]);

      expect(div, isNotNull);
      expect(
          div.buildHTML(),
          equals(
              '<div><label>Some Label</label><input type="text" value="Some Text"><br><textarea>Title:\nText block.</textarea></div>'));
      expect(
          div.buildHTML(withIdent: true),
          equals(
              '<div>\n  <label>Some Label</label>\n  <input type="text" value="Some Text">\n  <br>\n  <textarea>Title:\nText block.</textarea>\n</div>'));
    });

    test('Basic hr p', () {
      var div = $div(content: ['AAA', $hr(), 'BBB', $p(), 'CCC']);

      expect(div, isNotNull);
      expect(div.buildHTML(), equals('<div>AAA<hr>BBB<p>CCC</div>'));
      expect(div.buildHTML(withIdent: true),
          equals('<div>AAA<hr>BBB<p>CCC</div>'));
    });

    test('\$br', () {
      expect($br().buildHTML(), equals('<br>'));
      expect($br(amount: 0), isNull);
      expect($br(amount: 1).buildHTML(), equals('<br>'));
      expect($br(amount: 2).buildHTML(), equals('<span><br><br></span>'));
      expect($br(amount: 3).buildHTML(), equals('<span><br><br><br></span>'));
    });

    test('&nbsp;', () {
      expect($nbsp(), equals('&nbsp;'));
      expect($nbsp(0), equals(''));
      expect($nbsp(1), equals('&nbsp;'));
      expect($nbsp(2), equals('&nbsp;&nbsp;'));
      expect($nbsp(3), equals('&nbsp;&nbsp;&nbsp;'));
    });

    test('Attribute class', () {
      var div = $div(classes: 'a b');
      expect(div.classesList, equals(['a', 'b']));
      expect(div.classes, equals('a b'));
      div.addClass('c');
      expect(div.classesList, equals(['a', 'b', 'c']));
      expect(div.classes, equals('a b c'));
      div.addClass('c');
      expect(div.classesList, equals(['a', 'b', 'c']));
      expect(div.classes, equals('a b c'));

      var div2 = $div(classes: 'a b b c d');
      expect(div2.classesList, equals(['a', 'b', 'c', 'd']));
      expect(div2.classes, equals('a b c d'));
    });

    test('Attribute class', () {
      var div = $div(classes: 'a b');
      expect(div.classesList, equals(['a', 'b']));
      expect(div.classes, equals('a b'));
      div.addClass('c');
      expect(div.classesList, equals(['a', 'b', 'c']));
      expect(div.classes, equals('a b c'));
      div.addClass('c');
      expect(div.classesList, equals(['a', 'b', 'c']));
      expect(div.classes, equals('a b c'));

      var div2 = $div(classes: 'a b b c d');
      expect(div2.classesList, equals(['a', 'b', 'c', 'd']));
      expect(div2.classes, equals('a b c d'));
    });

    test('Attribute class 2', () {
      var div = $div(
        classes: 'c1 c2 c2',
      );
      expect(div.buildHTML(), equals('<div class="c1 c2"></div>'));

      var attributeClass = div.getAttribute('class');
      expect(attributeClass.value, equals('c1 c2'));
      expect(attributeClass.values, equals(['c1', 'c2']));
      expect(attributeClass.containsValue('c2'), isTrue);
      expect(attributeClass.containsValue('Z'), isFalse);
      expect(attributeClass.isBoolean, isFalse);
      expect(attributeClass.isListValue, isTrue);
      expect(attributeClass.isSet, isTrue);
      attributeClass.setValue('c3 c4');
      expect(attributeClass.value, equals('c3 c4'));
      expect(attributeClass.values, equals(['c3', 'c4']));
      attributeClass.appendValue('c5');
      expect(attributeClass.value, equals('c3 c4 c5'));
      expect(attributeClass.values, equals(['c3', 'c4', 'c5']));
      attributeClass.setValue('c6');
      expect(attributeClass.value, equals('c6'));
      expect(attributeClass.values, equals(['c6']));
      attributeClass.setValue('c7');
      expect(attributeClass.value, equals('c7'));
      expect(attributeClass.values, equals(['c7']));

      attributeClass.setValue('');
      expect(attributeClass.value, isNull);
      expect(attributeClass.values, isNull);
    });

    test('Attribute foo', () {
      var div = $div(attributes: {'foo': 'aaa'});
      expect(div.buildHTML(), equals('<div foo="aaa"></div>'));

      var attributeFoo = div.getAttribute('foo');
      expect(attributeFoo.value, equals('aaa'));
      attributeFoo.setValue('bbb');
      expect(attributeFoo.value, equals('bbb'));
      attributeFoo.appendValue('ccc');
      expect(attributeFoo.value, equals('ccc'));
    });

    test('Attribute hidden', () {
      var div = $div(
          id: 'x1',
          classes: 'c1 c2 c2',
          attributes: {'foo': '111', 'bar': '2', 'hidden': 'true'},
          content: $span(attributes: {'bar': '222'}, content: 'sub'));
      expect(
          div.buildHTML(),
          equals(
              '<div id="x1" class="c1 c2" foo="111" bar="2" hidden><span bar="222">sub</span></div>'));

      expect(div.getAttributeValue('foo'), equals('111'));
      expect(div.getAttributeValue('hidden'), equals('true'));

      var attributeClass = div.getAttribute('class');
      expect(attributeClass.value, equals('c1 c2'));
      expect(attributeClass.values, equals(['c1', 'c2']));
      expect(attributeClass.containsValue('c2'), isTrue);
      expect(attributeClass.containsValue('Z'), isFalse);
      expect(attributeClass.isBoolean, isFalse);
      expect(attributeClass.isListValue, isTrue);
      expect(attributeClass.isSet, isTrue);

      var attributeFoo = div.getAttribute('foo');
      expect(attributeFoo.value, equals('111'));
      expect(attributeFoo.values, equals(['111']));
      expect(attributeFoo.containsValue('111'), isTrue);
      expect(attributeFoo.containsValue('Z'), isFalse);
      expect(attributeFoo.isBoolean, isFalse);
      expect(attributeFoo.isListValue, isFalse);
      expect(attributeFoo.isSet, isFalse);

      var attributeBar = div.getAttribute('bar');
      expect(attributeBar.value, equals('2'));
      expect(attributeBar.values, equals(['2']));
      expect(attributeBar.containsValue('2'), isTrue);
      expect(attributeBar.containsValue('Z'), isFalse);
      expect(attributeBar.isBoolean, isFalse);
      expect(attributeBar.isListValue, isFalse);
      expect(attributeBar.isSet, isFalse);

      var attributeBaz = div.getAttribute('baz');
      expect(attributeBaz, isNull);

      var attributeHidden = div.getAttribute('hidden');
      expect(attributeHidden.value, equals('true'));
      expect(attributeHidden.values, equals(['true']));
      expect(attributeHidden.containsValue('true'), isTrue);
      expect(attributeHidden.containsValue('Z'), isFalse);
      expect(attributeHidden.isBoolean, isTrue);
      expect(attributeHidden.isListValue, isFalse);
      expect(attributeHidden.isSet, isFalse);

      div.setAttribute('hidden', 'true');
      expect(
          div.buildHTML(),
          equals(
              '<div id="x1" class="c1 c2" foo="111" bar="2" hidden><span bar="222">sub</span></div>'));

      div.setAttribute('hidden', false);
      expect(
          div.buildHTML(),
          equals(
              '<div id="x1" class="c1 c2" foo="111" bar="2"><span bar="222">sub</span></div>'));

      expect(div.removeAttribute('foo'), isTrue);
      expect(
          div.buildHTML(),
          equals(
              '<div id="x1" class="c1 c2" bar="2"><span bar="222">sub</span></div>'));

      expect(div.removeAttributeDeeply('bar'), isTrue);
      expect(div.buildHTML(),
          equals('<div id="x1" class="c1 c2"><span>sub</span></div>'));
    });


    test('Helper \$tag', () {
      var div = $tag('div', attributes: {'foo': 'aaa'}, content: ['wow']);

      expect(div.runtimeType, equals( DIVElement ));
      expect(div.buildHTML(), equals('<div foo="aaa">wow</div>'));
    });

    test('Helper \$htmlRoot: div', () {
      var div = $htmlRoot('''<div foo="aaa">WOW</div>''');

      expect(div.runtimeType, equals( DIVElement ));
      expect(div.buildHTML(), equals('<div foo="aaa">WOW</div>'));
    });

    test('Helper \$htmlRoot: text 1', () {
      var node = $htmlRoot('''WoW''');
      expect(node.buildHTML(), equals('<span>WoW</span>'));
    });

    test('Helper \$htmlRoot: text 2', () {
      var node = $htmlRoot('''WoW<br>!''');
      expect(node.buildHTML(), equals('<span>WoW<br>!</span>'));
    });

    test('Helper \$htmlRoot: b+i', () {
      var node = $htmlRoot('''<b>BB</b><i>II</i>''');
      expect(node.buildHTML(), equals('<span><b>BB</b><i>II</i></span>'));
    });

    test('Helper \$tags', () {
      var node = $tags('b', ['aa','bb']) ;
      expect(node.map((e) => e.buildHTML()), equals(['<b>aa</b>','<b>bb</b>']));
    });

    test('Helper \$tags +generator', () {
      var node = $tags<String>('b', ['aa','bb'], (e) => e.toUpperCase()) ;
      expect(node.map((e) => e.buildHTML()), equals(['<b>AA</b>','<b>BB</b>']));
    });

  });
}

abstract class TestNode {
  TestNode parent;

  String get text;

  TestNode copy();
}

class TestText implements TestNode {
  @override
  TestNode parent;

  String _text;

  @override
  String get text => _text;

  set text(String value) {
    _text = value ?? '';
  }

  TestText(String text) : _text = text ?? '';

  TestElem get asTestElem => TestElem('span')..add(TestText(text));

  @override
  String toString() {
    return _text;
  }

  @override
  TestText copy() => TestText(_text);
}

class TestElem implements TestNode {
  @override
  TestNode parent;
  final String tag;

  TestElem(this.tag);

  @override
  TestElem copy() {
    var copy = TestElem(tag);

    nodes.map((e) => e.copy()).forEach((e) {
      copy.add(e);
    });

    return copy;
  }

  final List<TestNode> _nodes = [];

  List<TestNode> get nodes => List.unmodifiable(_nodes);

  int get nodesLength => _nodes.length;

  @override
  String get text {
    if (_nodes.isEmpty) return '';
    return _nodes.map((e) => e.text).join('');
  }

  TestNode get(int index) => _nodes[index];

  void addAll(Iterable<TestNode> nodes) {
    _nodes.addAll(nodes);
  }

  void add(TestNode node) {
    _nodes.add(node);
    _setParent(node, this);
  }

  bool remove(TestNode node) {
    if (_nodes.remove(node)) {
      _setParentNull(node);
      return true;
    }
    return false;
  }

  void _setParent(TestNode node, TestElem parent) {
    node.parent = parent;
  }

  void _setParentNull(TestNode node) {
    node.parent = null;
  }

  TestNode removeAt(int index) {
    var node = _nodes.removeAt(index);
    _setParentNull(node);
    return node;
  }

  void insertAt(int index, TestNode node) {
    _nodes.insert(index, node);
    _setParent(node, this);
  }

  int indexOf(TestNode node) {
    return _nodes.indexOf(node);
  }

  void clear() {
    _nodes.forEach(_setParentNull);
    _nodes.clear();
  }

  final Map<String, String> attributes = {};

  String get asHTML {
    // BAD HTML:
    return '<$tag $attributes>$_nodes</$tag>';
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is TestElem &&
          runtimeType == other.runtimeType &&
          tag == other.tag &&
          text == other.text;

  @override
  int get hashCode => tag.hashCode ^ text.hashCode;

  @override
  String toString() {
    return 'TestElem{tag: $tag, nodes: $nodes, text: $text, attributes: $attributes}';
  }
}

class TestGenerator extends DOMGenerator<TestNode> {
  @override
  TestNode getNodeParent(TestNode node) {
    return node.parent;
  }

  @override
  List<TestNode> getElementNodes(TestNode element) {
    if (element is TestElem) {
      return List.from(element.nodes);
    }
    return [];
  }

  @override
  void addChildToElement(TestNode element, TestNode child) {
    if (element is TestElem) {
      element.add(child);
    }
  }

  @override
  bool canHandleExternalElement(externalElement) {
    return externalElement is TestElem || externalElement is TestText;
  }

  @override
  List<TestNode> addExternalElementToElement(
      TestNode element, dynamic externalElement) {
    if (element is TestElem) {
      if (externalElement is TestElem) {
        element.add(externalElement);
        return [externalElement];
      } else if (externalElement is TestText) {
        var testElem = externalElement.asTestElem;
        element.add(testElem);
        return [testElem];
      }
    }
    return null;
  }

  @override
  TestNode appendElementText(TestNode element, String text) {
    if (element is TestElem) {
      var textElem = TestText(text);
      element.add(textElem);
      return textElem;
    }
    return null;
  }

  @override
  TestNode createTextNode(String text) {
    return TestText(text);
  }

  @override
  bool isTextNode(TestNode node) => node is TestText;

  @override
  TestElem createElement(String tag) {
    return TestElem(tag);
  }

  @override
  String getNodeText(TestNode node) {
    return node.text;
  }

  @override
  void setAttribute(TestNode element, String attrName, String attrVal) {
    if (element is TestElem) {
      element.attributes[attrName] = attrVal;
    }
  }

  @override
  String buildElementHTML(TestNode element) {
    if (element is TestElem) {
      return element.asHTML;
    }
    return '';
  }

  @override
  DOMNodeRuntime<TestNode> createDOMNodeRuntime(
      DOMTreeMap<TestNode> treeMap, DOMNode domNode, TestNode node) {
    return TestNodeRuntime(treeMap, domNode, node);
  }
}

class TestNodeRuntime extends DOMNodeRuntime<TestNode> {
  TestNodeRuntime(DOMTreeMap<TestNode> treeMap, DOMNode domNode, TestElem node)
      : super(treeMap, domNode, node);

  @override
  String get tagName {
    if (node is TestElem) {
      TestElem element = node;
      return element.tag;
    }
    return null;
  }

  @override
  String get text {
    return node.text;
  }

  @override
  set text(String value) {
    if (node is TestElem) {
      TestElem element = node;
      element.add(TestText(value));
    } else if (node is TestText) {
      TestText textElem = node;
      textElem.text = value ?? '';
    }
  }

  @override
  String get value => text;

  @override
  set value(String value) {
    text = value;
  }

  @override
  String getAttribute(String name) {
    if (node is TestElem) {
      TestElem element = node;
      return element.attributes[name];
    }
    return null;
  }

  @override
  void setAttribute(String name, String value) {
    if (node is TestElem) {
      TestElem element = node;
      element.attributes[name] = value;
    }
  }

  @override
  void removeAttribute(String name) {
    if (node is TestElem) {
      TestElem element = node;
      element.attributes.remove(name);
    }
  }

  @override
  List<TestNode> get children {
    if (node is TestElem) {
      TestElem element = node;
      return List.from(element.nodes);
    }
    return [];
  }

  @override
  int get nodesLength {
    if (node is TestElem) {
      TestElem element = node;
      return element.nodes.length;
    }
    return 0;
  }

  @override
  TestNode getNodeAt(int index) {
    if (node is TestElem) {
      TestElem element = node;
      return element.nodes[index];
    }
    return null;
  }

  @override
  void add(TestNode child) {
    if (node is TestElem) {
      TestElem element = node;
      element.add(child);
    }
  }

  @override
  void clear() {
    if (node is TestElem) {
      TestElem element = node;
      element.clear();
    }
  }

  @override
  int indexOf(TestNode child) {
    if (node is TestElem) {
      TestElem element = node;
      return element.indexOf(child);
    }
    return -1;
  }

  @override
  void insertAt(int index, TestNode child) {
    if (node is TestElem) {
      TestElem element = node;
      element.insertAt(index, child);
    }
  }

  @override
  bool removeNode(TestNode child) {
    if (node is TestElem) {
      TestElem element = node;
      return element.remove(child);
    }
    return false;
  }

  @override
  TestElem removeAt(int index) {
    if (node is TestElem) {
      TestElem element = node;
      return element.removeAt(index);
    }
    return null;
  }

  @override
  void addClass(String className) {}

  @override
  List<String> get classes => [];

  @override
  void clearClasses() {}

  @override
  bool removeClass(String className) => false;

  @override
  TestNode copy() {
    return node.copy();
  }

  @override
  bool absorbNode(TestNode other) {
    if (node is TestText) {
      if (other is TestText) {
        var textNode = node as TestText;
        textNode.text += other.text;
        other.text = '';
        return true;
      }
    } else if (node is TestElem) {
      var elemNode = node as TestElem;

      if (other is TestElem) {
        elemNode.addAll(other.nodes);
        other.clear();
        return true;
      }
    }

    throw UnimplementedError('$node > $other');
  }

  @override
  int get indexInParent {
    if (hasParent) {
      return parentRuntime.indexOf(node);
    }
    return -1;
  }

  @override
  bool get isStringElement {
    if (node is TestText) {
      return true;
    } else if (node is TestElem) {
      var elem = node as TestElem;
      return DOMElement.isStringTagName(elem.tag);
    }
    return false;
  }
}
