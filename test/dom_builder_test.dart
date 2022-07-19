import 'package:dom_builder/dom_builder.dart';
import 'package:test/test.dart';

import 'dom_builder_domtest.dart';

void main() {
  group('dom_builder', () {
    setUp(() {});

    test('Basic div 1', () {
      var div = $divHTML(
              '<div class="container"><span class="text-x shadow-y">Builder</span></div>')!
          .insertAt(0, $span(id: 's1', content: 'The '))
          .insertAfter('#s1',
              $span(id: 's2', content: 'DOM ', style: 'font-weight: bold'));

      expect(div, isNotNull);
      expect(
          div.buildHTML(),
          equals(
              '<div class="container"><span id="s1">The </span><span id="s2" style="font-weight: bold">DOM </span><span class="text-x shadow-y">Builder</span></div>'));

      expect(div.selectWithAnyClass(['noo']), isNull);
      expect(div.selectWithAnyClass(['text-x'])!.buildHTML(),
          equals('<span class="text-x shadow-y">Builder</span>'));

      expect(div.selectWithAllClasses(['text-x', 'text-y']), isNull);
      expect(div.selectWithAllClasses(['text-x', 'shadow-y'])!.buildHTML(),
          equals('<span class="text-x shadow-y">Builder</span>'));

      expect(div.selectByTag(['span'])!.buildHTML(),
          equals('<span id="s1">The </span>'));

      expect(div.selectAllByType<DOMElement>().length, equals(3));

      var span2 = div.select('#s2') as DOMElement;
      expect(span2, isNotNull);

      expect(span2.style.isEmpty, isFalse);
      expect(span2.style.isNoEmpty, isTrue);
      expect(span2.style['font-weight'].toString(), equals('bold'));
      expect(span2.style.toString(), equals('font-weight: bold'));

      div.select('#s1')!.remove();

      expect(
          div.buildHTML(),
          equals(
              '<div class="container"><span id="s2" style="font-weight: bold">DOM </span><span class="text-x shadow-y">Builder</span></div>'));

      var span = div.select(['#s1', '#s2']) as DOMElement;

      expect(span, isNotNull);
      expect(span.tag, equals('span'));
    });

    test('Basic div 2', () {
      var div =
          $div(id: 'd1', classes: 'container', style: 'background-color: blue');

      expect(div, isNotNull);
      expect(
          div.buildHTML(),
          equals(
              '<div id="d1" class="container" style="background-color: blue"></div>'));

      div.add(['<b>BBB</b>', $br(), '<b>CCC</b>']);

      expect(
          div.buildHTML(),
          equals(
              '<div id="d1" class="container" style="background-color: blue"><b>BBB</b><br><b>CCC</b></div>'));

      div.add('<u>UUUUUU</u>');

      expect(
          div.buildHTML(),
          equals(
              '<div id="d1" class="container" style="background-color: blue"><b>BBB</b><br><b>CCC</b><u>UUUUUU</u></div>'));

      div.add('Some &nbsp; Text');

      expect(
          div.buildHTML(),
          equals(
              '<div id="d1" class="container" style="background-color: blue"><b>BBB</b><br><b>CCC</b><u>UUUUUU</u><span>Some &nbsp; Text</span></div>'));
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
          '<DIV class="container">Simple Text<SPAN>Sub text</SPAN></DIV>')!;

      expect(div, isNotNull);
      expect(
          div.buildHTML(),
          equals(
              '<div class="container">Simple Text<span>Sub text</span></div>'));
    });

    test('build HTML', () {
      var div = $tagHTML(
          '<div class="container"><span class="s1">Span Text<div class="d2">more text</div></span><span>Final Text</span></div>')!;

      expect(
          div.buildHTML(),
          equals(
              '<div class="container"><span class="s1">Span Text<div class="d2">more text</div></span><span>Final Text</span></div>'));
      expect(
          div.buildHTML(withIndent: true),
          equals(
              '<div class="container">\n  <span class="s1">Span Text<div class="d2">more text</div></span>\n  <span>Final Text</span>\n</div>'));
    });

    test('html add span', () {
      var div = $divHTML(
          '<DIV class="container">Simple Text<SPAN>Sub text</SPAN></DIV>')!;

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
          '  <DIV class="container">Simple Text<SPAN>Sub text</SPAN></DIV>  ')!;

      div.insertAt(1, $span(id: 's1', content: 'Initial text'));

      expect(div, isNotNull);
      expect(
          div.buildHTML(),
          equals(
              '<div class="container">Simple Text<span id="s1">Initial text</span><span>Sub text</span></div>'));

      expect(div.nodeByID('s1')!.buildHTML(),
          equals('<span id="s1">Initial text</span>'));
      expect(div.node('#s1')!.buildHTML(),
          equals('<span id="s1">Initial text</span>'));

      expect(div.selectByID('#s1')!.buildHTML(),
          equals('<span id="s1">Initial text</span>'));
      expect(div.select('#s1')!.buildHTML(),
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

      var div2 = $divHTML('<div class="container"><span>Builder</span></div>')!
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

      expect(div.buildHTML(withIndent: true),
          equals(div2.buildHTML(withIndent: true)));
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
          div.buildHTML(withIndent: true),
          equals(
              '<div>\n  <label>Some Label</label>\n  <input type="text" value="Some Text">\n  <br>\n  <textarea>Title:\nText block.</textarea>\n</div>'));
    });

    test('Basic hr p', () {
      var div = $div(content: ['AAA', $hr(), 'BBB', $p(), 'CCC']);

      expect(div, isNotNull);
      expect(div.buildHTML(), equals('<div>AAA<hr>BBB<p>CCC</div>'));
      expect(div.buildHTML(withIndent: true),
          equals('<div>AAA<hr>BBB<p>CCC</div>'));
    });

    test('\$br', () {
      expect($br().buildHTML(), equals('<br>'));
      expect($br(amount: 0).isCommented, isTrue);
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

      var attributeClass = div.getAttribute('class')!;
      expect(attributeClass.value, equals('c1 c2'));
      expect(attributeClass.values, equals(['c1', 'c2']));
      expect(attributeClass.containsValue('c2'), isTrue);
      expect(attributeClass.containsValue('Z'), isFalse);
      expect(attributeClass.isBoolean, isFalse);
      expect(attributeClass.isList, isFalse);
      expect(attributeClass.isSet, isTrue);
      expect(attributeClass.isCollection, isTrue);

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
      var div = $div(attributes: {'title': 'aaa'});
      expect(div.buildHTML(), equals('<div title="aaa"></div>'));

      var attributeFoo = div.getAttribute('title')!;
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
          attributes: {'title': '111', 'lang': 'en', 'hidden': 'true'},
          content: $span(attributes: {'lang': '222'}, content: 'sub'));
      expect(
          div.buildHTML(),
          equals(
              '<div id="x1" class="c1 c2" title="111" lang="en" hidden><span lang="222">sub</span></div>'));

      expect(div.getAttributeValue('title'), equals('111'));
      expect(div.getAttributeValue('hidden'), equals('true'));

      var attributeClass = div.getAttribute('class')!;
      expect(attributeClass.value, equals('c1 c2'));
      expect(attributeClass.values, equals(['c1', 'c2']));
      expect(attributeClass.containsValue('c2'), isTrue);
      expect(attributeClass.containsValue('Z'), isFalse);
      expect(attributeClass.isBoolean, isFalse);
      expect(attributeClass.isList, isFalse);
      expect(attributeClass.isSet, isTrue);
      expect(attributeClass.isCollection, isTrue);

      var attributeTitle = div.getAttribute('title')!;
      expect(attributeTitle.value, equals('111'));
      expect(attributeTitle.values, equals(['111']));
      expect(attributeTitle.containsValue('111'), isTrue);
      expect(attributeTitle.containsValue('Z'), isFalse);
      expect(attributeTitle.isBoolean, isFalse);
      expect(attributeTitle.isList, isFalse);
      expect(attributeTitle.isSet, isFalse);
      expect(attributeTitle.isCollection, isFalse);

      var attributeLang = div.getAttribute('lang')!;
      expect(attributeLang.value, equals('en'));
      expect(attributeLang.values, equals(['en']));
      expect(attributeLang.containsValue('en'), isTrue);
      expect(attributeLang.containsValue('fr'), isFalse);
      expect(attributeLang.isBoolean, isFalse);
      expect(attributeLang.isList, isFalse);
      expect(attributeLang.isSet, isFalse);
      expect(attributeLang.isCollection, isFalse);

      var attributeBaz = div.getAttribute('baz');
      expect(attributeBaz, isNull);

      var attributeHidden = div.getAttribute('hidden')!;
      expect(attributeHidden.value, equals('true'));
      expect(attributeHidden.values, equals(['true']));
      expect(attributeHidden.containsValue('true'), isTrue);
      expect(attributeHidden.containsValue('Z'), isFalse);
      expect(attributeHidden.isBoolean, isTrue);
      expect(attributeHidden.isList, isFalse);
      expect(attributeHidden.isSet, isFalse);
      expect(attributeHidden.isCollection, isFalse);

      div.setAttribute('hidden', 'true');
      expect(
          div.buildHTML(),
          equals(
              '<div id="x1" class="c1 c2" title="111" lang="en" hidden><span lang="222">sub</span></div>'));

      div.setAttribute('hidden', false);
      expect(
          div.buildHTML(),
          equals(
              '<div id="x1" class="c1 c2" title="111" lang="en"><span lang="222">sub</span></div>'));

      expect(div.removeAttribute('title'), isTrue);
      expect(
          div.buildHTML(),
          equals(
              '<div id="x1" class="c1 c2" lang="en"><span lang="222">sub</span></div>'));

      expect(div.removeAttributeDeeply('lang'), isTrue);
      expect(div.buildHTML(),
          equals('<div id="x1" class="c1 c2"><span>sub</span></div>'));

      var div2 = $div(hidden: true, content: 'foo');
      expect(div2.buildHTML(), equals('<div hidden>foo</div>'));

      var div3 = $div(hidden: false, content: 'foo');
      expect(div3.buildHTML(), equals('<div>foo</div>'));

      var div4 = $div(content: 'foo');
      expect(div4.buildHTML(), equals('<div>foo</div>'));
    });

    test('Helper \$ul', () {
      var props = {'a': 1, 'b': 2};

      var items = props.entries
          .map((e) => $li(content: [$label(content: e.key), e.value]));

      var ul = $ul(id: 'list1', attributes: {'lang': 'en'}, content: items);

      expect(ul.runtimeType, equals(DOMElement));
      expect(
          ul.buildHTML(),
          equals(
              '<ul id="list1" lang="en"><li><label>a</label>1</li><li><label>b</label>2</li></ul>'));

      var ol = $ol(id: 'list2', attributes: {'lang': 'en'}, content: items);

      expect(ol.runtimeType, equals(DOMElement));
      expect(
          ol.buildHTML(),
          equals(
              '<ol id="list2" lang="en"><li><label>a</label>1</li><li><label>b</label>2</li></ol>'));
    });

    test('Helper \$tag', () {
      var div = $tag('div', attributes: {'title': 'aaa'}, content: ['wow']);

      expect(div.runtimeType, equals(DIVElement));
      expect(div.buildHTML(), equals('<div title="aaa">wow</div>'));
    });

    test('Helper \$htmlRoot: div', () {
      var div = $htmlRoot('''<div title="aaa">WOW</div>''')!;

      expect(div.runtimeType, equals(DIVElement));
      expect(div.buildHTML(), equals('<div title="aaa">WOW</div>'));
    });

    test('Helper \$htmlRoot: text 1', () {
      var node = $htmlRoot('''WoW''')!;
      expect(node.buildHTML(), equals('<span>WoW</span>'));
    });

    test('Helper \$htmlRoot: text 2', () {
      var node = $htmlRoot('''WoW<br>!''')!;
      expect(node.buildHTML(), equals('<span>WoW<br>!</span>'));
    });

    test('Helper \$htmlRoot: b+i', () {
      var node = $htmlRoot('''<b>BB</b><i>II</i>''')!;
      expect(node.buildHTML(), equals('<span><b>BB</b><i>II</i></span>'));
    });

    test('Helper \$tags', () {
      var node = $tags('b', ['aa', 'bb']);
      expect(
          node.map((e) => e.buildHTML()), equals(['<b>aa</b>', '<b>bb</b>']));
    });

    test('Helper \$tags +generator', () {
      var node = $tags<String>('b', ['aa', 'bb'], (e) => e!.toUpperCase());
      expect(
          node.map((e) => e.buildHTML()), equals(['<b>AA</b>', '<b>BB</b>']));
    });

    test('Helper \$div', () {
      var node = $div(
          id: 'id1',
          classes: 'content',
          style: 'width: 100px ; height: 200px',
          attributes: {'lang': 'fr'},
          content: '<span>Foo</span>');

      expect(
          node.buildHTML(),
          equals(
              '<div id="id1" class="content" style="width: 100px; height: 200px" lang="fr"><span>Foo</span></div>'));
    });

    test('Helper \$divInline', () {
      var node = $divInline(
          id: 'id1',
          classes: 'content',
          style: 'width: 100px ; height: 200px',
          attributes: {'lang': 'pt'},
          content: '<span>Foo</span>');

      expect(
          node.buildHTML(),
          equals(
              '<div id="id1" class="content" style="display: inline-block; width: 100px; height: 200px" lang="pt"><span>Foo</span></div>'));
    });

    test('Select: options 1', () {
      var node = $div(
          content:
              '<select><option value="v1">Val 1</option><option value="v2">Val 2</option></select>');

      expect(
          node.buildHTML(),
          equals(
              '<div><select><option value="v1">Val 1</option><option value="v2">Val 2</option></select></div>'));
    });

    test('Select: options 2', () {
      var node = $div(
          content:
              '<select><option value="v1">Val 1</option><option value="v2" selected>Val 2</option></select>');

      expect(
          node.buildHTML(),
          equals(
              '<div><select><option value="v1">Val 1</option><option value="v2" selected>Val 2</option></select></div>'));
    });

    test(r'tag: video', () {
      var node = $div(
          content:
              '<video class="shadow" style="width: 80%; max-width: 90%; max-height: 70%" controls autoplay muted>'
              '<source src="https://managersystems.com.br/manager-30anos.mp4" type="video/mp4">'
              '</video>');

      expect(
          node.buildHTML(),
          equals(
              '<div><video class="shadow" style="width: 80%; max-width: 90%; max-height: 70%" controls autoplay muted>'
              '<source src="https://managersystems.com.br/manager-30anos.mp4" type="video/mp4">'
              '</video></div>'));
    });

    test(r'$checkbox', () {
      var chk1 = $checkbox(name: 'foo', value: 'a');
      var chk2 = $checkbox(name: 'bar', value: 'b');

      expect(chk1.buildHTML(),
          equals('<input name="foo" type="checkbox" value="a">'));
      expect(chk2.buildHTML(),
          equals('<input name="bar" type="checkbox" value="b">'));
    });

    test(r'$radiobutton', () {
      var rb1 = $radiobutton(name: 'foo', value: 'a');
      var rb2 = $radiobutton(name: 'foo', value: 'b');
      var rb3 = $radiobutton(name: 'foo', value: 'c');

      expect(
          rb1.buildHTML(), equals('<input name="foo" type="radio" value="a">'));
      expect(
          rb2.buildHTML(), equals('<input name="foo" type="radio" value="b">'));
      expect(
          rb3.buildHTML(), equals('<input name="foo" type="radio" value="c">'));
    });

    test('Content: template', () {
      var templateSource = '{{:locale=="en"}}YES{{?}}OUI{{/}}';
      var node = $div(content: templateSource);

      var context = DOMContext<TestNode>();

      expect(node.buildHTML(domContext: context),
          equals('<div>$templateSource</div>'));

      var generator = TestGenerator();

      context.putVariable('locale', 'en');

      var gen1 = generator.generate(node, context: context);
      expect(
          '$gen1',
          equals(
              'TestElem{tag: div, nodes: [YES], text: YES, attributes: {}}'));

      context.putVariable('locale', 'fr');

      var gen2 = generator.generate(node, context: context);
      expect(
          '$gen2',
          equals(
              'TestElem{tag: div, nodes: [OUI], text: OUI, attributes: {}}'));
    });
  });
}

class TestText {
  String text;

  TestText(this.text);

  @override
  String toString() {
    return text;
  }
}
