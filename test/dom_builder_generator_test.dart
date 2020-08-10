import 'package:dom_builder/dom_builder.dart';
import 'package:test/test.dart';

void main() {
  group('dom_builder', () {
    setUp(() {});

    test('generator', () {
      var generator = TestGenerator();

      var div = $tagHTML(
          '<div class="container"><span class="s1">Span Text<div class="d2">More text</div></span></div>');

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

      var genDiv = treeMap.generate(generator, div);

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
          (domGenerator, tag, parent, attributes, contentHolder) =>
              TestText(contentHolder.text.toUpperCase())));

      generator.registerElementGenerator(ElementGeneratorFunctions(
          'lc',
          (domGenerator, tag, parent, attributes, contentHolder) =>
              TestText(contentHolder.text.toLowerCase())));

      var treeMap = generator.createDOMTreeMap();

      var div = $div(content: [
        '<uc>BBbb</uc>',
        '<lc>BBbb</lc>',
      ]);

      var genDiv = treeMap.generate(generator, div);

      expect(genDiv, isNotNull);
      expect(genDiv.text, equals('BBBBbbbb'));
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

      expect(
          div.buildHTML(),
          equals(
              '<div><u>UUU</u><u>UUUX</u><u>UUUX</u><b>BBB</b><i>III</i></div>'));
      expect(genDiv.text, equals('UUUUUUXUUUXBBBIII'));

      var mergeU = treeMap.mergeNearStringNodes(uNode, copyU.domNode,
          onlyCompatibles: true);

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

      var div = $tagHTML('<div class="container"></div>');

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
          '<div class="container"><span class="s1">Span Text<div class="d2">More text</div></span><x-tag>XTAG</x-tag></div>');

      print(div);
      print(div.buildHTML());

      var genDiv = div.buildDOM(generator: generator) as TestElem;
      expect(genDiv, isNotNull);

      DOMElement div2 = generator.revert(genDiv);
      expect(div2, isNotNull);

      expect(div2.buildHTML(), equals(div.buildHTML()));
    });
  });
}

class TestNodeGenerator extends ElementGenerator<TestElem> {
  @override
  final String tag;
  final String classes;

  TestNodeGenerator(this.tag, this.classes);

  @override
  TestElem generate(DOMGenerator<dynamic> domGenerator, String tag, parent,
      Map<String, DOMAttribute> attributes, contentHolder) {
    var attributesAsString =
        attributes.map((key, value) => MapEntry(key, value.value));

    var elem = TestElem(tag)..attributes.addAll(attributesAsString);

    var prevClass = elem.attributes['class'] ?? '';

    elem.attributes['class'] = (classes + ' ' + prevClass).trim();

    elem.add(TestText(contentHolder.text));

    return elem;
  }

  @override
  DOMElement revert(DOMElement domParent, TestElem parent, TestElem node) {
    var tag = node.tag;
    var prevClass = node.attributes['class'];

    if (prevClass != null && prevClass.contains(tag)) {
      prevClass = prevClass.replaceFirst(tag, '').trim();
      node.attributes['class'] = prevClass;
    }

    return DOMElement(tag, attributes: node.attributes);
  }
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
  String getElementTag(TestNode element) {
    if (element is TestElem) {
      return element.tag;
    }
    return null;
  }

  @override
  Map<String, String> getElementAttributes(TestNode element) {
    if (element is TestElem) {
      return Map.fromEntries(element.attributes.entries);
    }
    return null;
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
  bool containsNode(TestNode parent, TestNode node) {
    if (parent == null || node == null) return false;

    if (parent is TestElem) {
      return parent.nodes.contains(node);
    }

    return false;
  }

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
