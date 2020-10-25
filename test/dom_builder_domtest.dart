import 'package:dom_builder/dom_builder.dart';

class TestNodeGenerator extends ElementGenerator<TestElem> {
  @override
  final String tag;
  final String classes;

  TestNodeGenerator(this.tag, this.classes);

  @override
  TestElem generate(
      DOMGenerator<dynamic> domGenerator,
      DOMTreeMap<dynamic> treeMap,
      String tag,
      DOMElement domParent,
      parent,
      Map<String, DOMAttribute> attributes,
      contentHolder,
      List<DOMNode> contentNodes) {
    var attributesAsString =
        attributes.map((key, value) => MapEntry(key, value.value));

    var elem = TestElem(tag)..attributes.addAll(attributesAsString);

    var prevClass = elem.attributes['class'] ?? '';

    elem.attributes['class'] = (classes + ' ' + prevClass).trim();

    elem.add(TestText(contentHolder.text));

    return elem;
  }

  @override
  DOMElement revert(
      DOMGenerator<dynamic> domGenerator,
      DOMTreeMap<dynamic> treeMap,
      DOMElement domParent,
      TestElem parent,
      TestElem node) {
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
  static int instanceIDCount = 0;

  final int instanceID = ++instanceIDCount;

  TestNode parent;

  String get text;

  TestNode copy();

  String outerHTML();
}

class TestText extends TestNode {
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
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is TestText &&
          runtimeType == other.runtimeType &&
          _text == other._text;

  @override
  int get hashCode => instanceID;

  @override
  String toString() {
    return _text;
  }

  @override
  TestText copy() => TestText(_text);

  @override
  String outerHTML() => _text;
}

class TestElem extends TestNode {
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

  bool contains(TestNode node) => _nodes.contains(node);

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

  String get asHTML => outerHTML();

  @override
  String outerHTML() {
    var attrs =
        attributes.entries.map((e) => '${e.key}="${e.value}"').join(' ');
    if (attrs.isNotEmpty) attrs = ' $attrs';

    var html = '<$tag$attrs>';

    for (var node in _nodes) {
      html += node.outerHTML();
    }

    html += '</$tag>';

    return html;
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is TestElem &&
          runtimeType == other.runtimeType &&
          tag == other.tag &&
          text == other.text;

  @override
  int get hashCode => tag.hashCode ^ instanceID;

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
  String getElementOuterHTML(TestNode element) {
    return element.outerHTML();
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
    if (element is TestElem && !element.contains(child)) {
      element.add(child);
    }
  }

  @override
  void removeChildFromElement(TestNode element, TestNode child) {
    if (element is TestElem) {
      element.remove(child);
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
  String getAttribute(TestNode element, String attrName) {
    if (element is TestElem) {
      return element.attributes[attrName];
    }
    return null;
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

class TestActionExecutor extends DOMActionExecutor<TestNode> {
  @override
  TestNode call(String name, List<String> parameters, TestNode target,
      TestNode self, DOMTreeMap treeMap, DOMContext context) {
    throw UnimplementedError();
  }

  @override
  TestNode selectByID(String id, TestNode target, TestNode self,
      DOMTreeMap treeMap, DOMContext context) {
    throw UnimplementedError();
  }
}
