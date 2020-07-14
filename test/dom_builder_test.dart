import 'package:dom_builder/dom_builder.dart';
import 'package:test/test.dart';

void main() {
  group('A group of tests', () {
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

      var genDiv = div.buildDOM(generator) as TestElem ;

      expect(genDiv, isNotNull);

      expect(genDiv.attributes['class'], equals('container'));
      expect(genDiv.nodesLength, equals(1));

      var genSpan = genDiv.get(0)  as TestElem  ;

      expect(genSpan.attributes['class'], equals('s1'));
      expect(genSpan.text, equals('Span TextMore text'));

      var genDiv2 = genSpan.get(1) as TestElem ;

      expect(genDiv2.attributes['class'], equals('d2'));
      expect(genDiv2.text, equals('More text'));
    });

    test('external element', () {
      var generator = TestGenerator();

      var div = $tagHTML('<div class="container"></div>');

      var span = TestElem('span')..add( TestText('span element') );
      div.add(span);

      var text = TestText('text element');
      div.add(text);

      var genDiv = div.buildDOM(generator) as TestElem ;

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
  });
}

abstract class TestNode {

  String get text ;

}

class TestText implements TestNode {
  String _text;

  @override
  String get text => _text;

  set text(String value) {
    _text = value ?? '' ;
  }

  TestText(String text) :
        _text = text ?? ''
  ;

  TestElem get asTestElem => TestElem('span')..add( TestText(text) ) ;
}

class TestElem implements TestNode {

  TestElem parent ;

  final String tag;

  TestElem(this.tag);

  final List<TestNode> _nodes = [];

  List<TestNode> get nodes => List.unmodifiable(_nodes) ;

  int get nodesLength => _nodes.length ;

  @override
  String get text {
    if ( _nodes.isEmpty ) return '' ;
    return _nodes.map((e) => e.text).join('') ;
  }

  TestNode get(int index) => _nodes[index] ;

  void add(TestNode node) {
    _nodes.add(node) ;
  }

  bool remove(TestNode node) {
    return _nodes.remove(node) ;
  }

  TestNode removeAt(int index) {
    return _nodes.removeAt(index) ;
  }

  void insertAt(int index, TestNode node) {
    _nodes.insert(index, node) ;
  }

  int indexOf(TestNode node) {
    return _nodes.indexOf(node) ;
  }

  void clear() {
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
    if ( element is TestElem ) {
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
    return null ;
  }

  @override
  TestNode createTextNode(String text) {
    return TestText(text) ;
  }

  @override
  bool isTextNode(TestNode node) => node is TestText ;

  @override
  TestElem createElement(String tag) {
    return TestElem(tag);
  }

  @override
  String getNodeText(TextNode domNode) {
    return domNode.text;
  }

  @override
  void setAttribute(TestNode element, String attrName, String attrVal) {
    if ( element is TestElem ) {
      element.attributes[attrName] = attrVal;
    }
  }

  @override
  String buildElementHTML(TestNode element) {
    if ( element is TestElem ) {
      return element.asHTML;
    }
    return '';
  }

  @override
  DOMNodeRuntime<TestNode> createDOMNodeRuntime(DOMTreeMap<TestNode> treeMap, DOMNode domNode, TestNode node) {
    return TestNodeRuntime(treeMap, domNode, node) ;
  }

}

class TestNodeRuntime extends DOMNodeRuntime<TestNode> {

  TestNodeRuntime(DOMTreeMap<TestElem> treeMap, DOMNode domNode, TestElem node) : super(treeMap, domNode, node);

  @override
  DOMNodeRuntime<TestElem> get parentRuntime => throw UnimplementedError();

  @override
  String get tagName {
    if ( node is TestElem ) {
      TestElem element = node ;
      return element.tag ;
    }
    return null ;
  }

  @override
  String get text {
    return node.text ;
  }
  @override
  set text(String value) {
    if ( node is TestElem ) {
      TestElem element = node ;
      element.add( TestText(value) ) ;
    }
    else if ( node is TestText ) {
      TestText textElem = node ;
      textElem.text = value ?? '';
    }
  }

  @override
  String get value => text ;
  @override
  set value(String value) {
    text = value ;
  }

  @override
  String getAttribute(String name) {
    if (node is TestElem) {
      TestElem element = node ;
      return element.attributes[name];
    }
    return null ;
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
    return [] ;
  }

  @override
  int get nodesLength {
    if (node is TestElem) {
      TestElem element = node;
      return element.nodes.length ;
    }
    return 0 ;
  }

  @override
  TestNode getNodeAt(int index) {
    if (node is TestElem) {
      TestElem element = node;
      return element.nodes[index] ;
    }
    return null ;
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
    return -1 ;
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
    return false ;
  }

  @override
  TestElem removeAt(int index) {
    if (node is TestElem) {
      TestElem element = node;
      return element.removeAt(index);
    }
    return null ;
  }

  @override
  void addClass(String className) {
  }

  @override
  List<String> get classes => [] ;

  @override
  void clearClasses() {
  }

  @override
  bool removeClass(String className) => false ;

  @override
  TestElem copy() {
    throw UnimplementedError();
  }

  @override
  TestElem duplicate() {
    throw UnimplementedError();
  }

  @override
  bool absorbNode(TestNode other) {
    throw UnimplementedError();
  }

  @override
  int get indexInParent => throw UnimplementedError();

  @override
  bool isInSameParent(TestNode other) {
    throw UnimplementedError();
  }

  @override
  bool isPreviousNode(TestNode other) {
    throw UnimplementedError();
  }

  @override
  bool isNextNode(TestNode other) {
    throw UnimplementedError();
  }

  @override
  bool mergeNode(TestNode other, {bool onlyConsecutive = true}) {
    throw UnimplementedError();
  }

  @override
  bool get isStringElement => throw UnimplementedError();

  @override
  bool get hasParent => throw UnimplementedError();

}

