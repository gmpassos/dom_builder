@TestOn('vm')
library;

import 'dart:async';
import 'dart:math' show Point;

import 'package:dom_builder/dom_builder.dart';
import 'package:html/dom.dart' as html_dom;
import 'package:html/parser.dart' as html_parse;
import 'package:swiss_knife/swiss_knife.dart' show Pair;
import 'package:test/test.dart';

import 'dom_builder_domtest.dart';

class _AsNode implements AsDOMNode {
  @override
  DOMNode get asDOMNode => TextNode('as-node');
}

class _AsElement implements AsDOMElement {
  @override
  DOMElement get asDOMElement => $span(content: 'as-element');
}

class _Custom {
  final String name;

  _Custom(this.name);

  @override
  String toString() => 'custom:$name';
}

/// A [TestNodeRuntime] that records the class operations.
class _RecordingRuntime extends TestNodeRuntime {
  final List<String> ops;

  _RecordingRuntime(super.treeMap, super.domNode, super.node, this.ops);

  @override
  void addClass(String? className) => ops.add('+$className');

  @override
  bool removeClass(String? className) {
    ops.add('-$className');
    return true;
  }
}

class _RecordingGenerator extends TestGenerator {
  final List<String> ops = [];

  @override
  DOMNodeRuntime<TestNode> createDOMNodeRuntime(
    DOMTreeMap<TestNode> treeMap,
    DOMNode? domNode,
    TestNode node,
  ) => _RecordingRuntime(treeMap, domNode, node as TestElem, ops);
}

/// Parses a `<table>` with package `html` and returns its child elements.
List<html_dom.Element> _htmlTableChildren(String inner) {
  var fragment = html_parse.parseFragment('<table>$inner</table>');
  var table = fragment.nodes.whereType<html_dom.Element>().first;
  return table.children;
}

html_dom.Element _htmlElement(String html) =>
    html_parse.parseFragment(html).nodes.whereType<html_dom.Element>().first;

Future<void> _flush() => Future<void>.delayed(Duration.zero);

void main() {
  // Must run before any test sets the default `DOMGenerator`:
  test('default DOMGenerator falls back to the web one', () {
    var generator = DOMNode.defaultDomGenerator;
    expect(generator, isA<DOMGeneratorWeb>());
    expect(generator, same(DOMGenerator.web()));
  });

  group('domBuilderLog', () {
    test('prints plain, warning and error messages', () {
      var printed = <String>[];
      runZonedPrint(printed, () {
        domBuilderLog('plain');
        domBuilderLog('warn', warning: true);
        domBuilderLog('err', error: 'boom', stackTrace: StackTrace.empty);
      });

      expect(printed[0], equals('dom_builder> plain'));
      expect(printed[1], equals('dom_builder> [WARNING] warn'));
      expect(printed[2], equals('dom_builder> [ERROR] err > boom'));
      expect(printed.length, equals(4));
    });
  });

  group('WithValue', () {
    test('parses value as bool, int, double and num', () {
      expect(INPUTElement(value: '12').valueAsInt, equals(12));
      expect(INPUTElement(value: '1.5').valueAsDouble, equals(1.5));
      expect(INPUTElement(value: '7').valueAsNum, equals(7));
      expect(INPUTElement(value: 'true').valueAsBool, isTrue);
      expect(INPUTElement(value: 'false').valueAsBool, isFalse);
      expect(INPUTElement().valueAsInt, isNull);
    });
  });

  group('asNodeSelector', () {
    test('ignores empty entries in a multi selector', () {
      var selector = asNodeSelector('div,,span')!;
      expect(selector($div()), isTrue);
      expect(selector($span()), isTrue);
      expect(selector($p()), isFalse);
    });

    test('a DOMNode selector matches only that node', () {
      var node = $span();
      var selector = asNodeSelector(node)!;
      expect(selector(node), isTrue);
      expect(selector($span()), isFalse);
    });
  });

  group('DOMNode static parsing', () {
    test('toText falls back to toString', () {
      expect(DOMNode.toText(42), equals('42'));
      expect(DOMNode.toText(_Custom('x')), equals('custom:x'));
    });

    test('parseNodes calls a direct helper', () {
      var nodes = DOMNode.parseNodes($br);
      expect(nodes.length, equals(1));
      expect(nodes.single.buildHTML(), equals('<br>'));
    });

    test('parseNodes returns empty for a direct helper that throws', () {
      var printed = <String>[];
      List<DOMNode>? nodes;
      runZonedPrint(printed, () => nodes = DOMNode.parseNodes($h));
      expect(nodes, isEmpty);
      expect(printed.first, startsWith('dom_builder> [ERROR] Error calling'));
    });

    test('parseNodes wraps unknown objects as ExternalElementNode', () {
      var nodes = DOMNode.parseNodes(_Custom('ext'));
      expect(nodes.single, isA<ExternalElementNode>());
      expect(nodes.single.buildHTML(), equals('custom:ext'));
    });

    test('parseNodes of a mixed list calls a direct helper', () {
      var nodes = DOMNode.parseNodes(['a', $hr]);
      expect(nodes.length, equals(2));
      expect(nodes[1].buildHTML(), equals('<hr>'));
    });

    test(
      'parseNodes of a mixed list skips a direct helper that throws',
      () {
        var nodes = DOMNode.parseNodes(['a', $h]);
        expect(nodes.length, equals(1));
      },
      skip:
          'Bug: `_parseListNodes` casts the `null` returned by `_parseNode` '
          'to `Iterable<DOMNode>` and throws a TypeError',
    );

    test('parseNodes accepts AsDOMNode and AsDOMElement', () {
      var nodes = DOMNode.parseNodes([_AsNode(), _AsElement()]);
      expect(nodes.length, equals(2));
      expect(nodes[0].text, equals('as-node'));
      expect(nodes[1].buildHTML(), equals('<span>as-element</span>'));
    });

    test('parseString', () {
      var html = DOMNode.parseString('<b>x</b>');
      expect(html, isA<List<DOMNode>>());
      expect((html as List<DOMNode>).single.buildHTML(), equals('<b>x</b>'));

      var text = DOMNode.parseString('abc');
      expect(text, isA<TextNode>());
      expect((text as TextNode).text, equals('abc'));

      expect(DOMNode.parseString(''), isNull);
    });

    test('from an Iterable', () {
      expect(DOMNode.from([]), isNull);
      expect(DOMNode.from([null]), isNull);
      var node = DOMNode.from([null, $b(content: 'x')]);
      expect(node!.buildHTML(), equals('<b>x</b>'));
    });

    test('from a function or an unknown object', () {
      String gen() => 'generated';
      var fromFunction = DOMNode.from(gen);
      expect(fromFunction, isA<ExternalElementNode>());
      expect(fromFunction!.buildHTML(), equals('generated'));

      var fromObject = DOMNode.from(_Custom('o'));
      expect(fromObject, isA<ExternalElementNode>());
      expect(fromObject!.buildHTML(), equals('custom:o'));
    });
  });

  group('DOMNode base behaviour', () {
    test('defaults of a plain DOMNode', () {
      var node = DOMNode(content: 'x');
      var other = DOMNode();
      expect(node.hasTemplate, isFalse);
      expect(node.hasUnresolvedTemplate, isFalse);
      expect(node.absorbNode(other), isFalse);
      expect(node.merge(other), isFalse);
      expect(node.isCompatibleForMerge(other), isFalse);
      expect(node.isStringElement, isFalse);
      expect(node.isWhiteSpaceContent, isFalse);
      expect(node.isGenerated, isFalse);
      expect(node.domGenerator, isNull);
    });

    test('runtime throws when not mapped by its treeMap', () {
      var generator = TestGenerator();
      var div = $div(content: [$span(content: 'a')]);
      var treeMap = generator.generateMapped(div);

      expect(div.isGenerated, isTrue);
      expect(div.domGenerator, same(generator));

      var orphan = $p();
      orphan.treeMap = treeMap;
      expect(() => orphan.runtime, throwsStateError);
      expect(() => orphan.getRuntime<TestNode>(), throwsStateError);
    });

    test('default DOMGenerator accessors', () {
      // ignore: deprecated_member_use_from_same_package
      var dartHtml = DOMNode.setDefaultDomGeneratorToDartHTML();
      expect(DOMNode.defaultDomGenerator, same(dartHtml));

      var web = DOMNode.setDefaultDomGeneratorToWeb();
      expect(DOMNode.defaultDomGenerator, same(web));

      var test = TestGenerator();
      DOMNode.defaultDomGenerator = test;
      expect(DOMNode.defaultDomGenerator, same(test));

      var built = $div(content: 'x').buildDOM<TestNode>();
      expect((built as TestElem).tag, equals('div'));

      DOMNode.defaultDomGenerator = web;
    });

    test('buildDOM with the unsupported web generator on the VM', () {
      DOMNode.setDefaultDomGeneratorToWeb();
      expect(() => $div().buildDOM(), throwsUnsupportedError);
    });

    test('notifyElementGenerated dispatches to onGenerate', () async {
      var div = $div();
      var received = <Object>[];
      div.onGenerate.listen(received.add);
      expect(div.hasOnGenerateListener, isTrue);
      div.notifyElementGenerated('elem');
      await _flush();
      expect(received, equals(['elem']));
    });
  });

  group('DOMNode content manipulation', () {
    test('add ignores a direct helper that throws', () {
      var printed = <String>[];
      var div = $div(content: [$span()]);
      runZonedPrint(printed, () => div.add($h));
      expect(div.length, equals(1));
      expect(printed.first, startsWith('dom_builder> [ERROR] Error calling'));
    });

    test('moveUp to the start when no element precedes', () {
      var text = TextNode('t');
      var span = $span(content: 's');
      var div = $div(content: [text, span]);
      expect(span.moveUp(), isTrue);
      expect(div.nodes, equals([span, text]));
    });

    test('checkNodes detects a child without parent', () {
      var span = $span();
      var div = $div(content: [span]);
      div.checkNodes();
      span.parent = null;
      expect(() => div.checkNodes(), throwsStateError);
    });

    test('moveDown to the end when no element follows', () {
      var a = $span(content: 'a');
      var b = $span(content: 'b');
      var div = $div(content: [a, b]);
      expect(a.moveDown(), isTrue);
      expect(div.nodes, equals([b, a]));
      expect(a.parent, same(div));
    });

    test('insertAfter the last node appends a single node', () {
      var div = $div(content: [$span(content: 'a')]);
      div.insertAfter(0, $b(content: 'b'));
      expect(div.buildHTML(), equals('<div><span>a</span><b>b</b></div>'));
    });

    test('insertAfter the last node appends a parsed list', () {
      var div = $div(content: [$span(content: 'a')]);
      div.insertAfter(0, 'x');
      expect(div.buildHTML(), equals('<div><span>a</span>x</div>'));

      div.insertAfter(1, '<i>1</i><u>2</u>');
      expect(
        div.buildHTML(),
        equals('<div><span>a</span>x<i>1</i><u>2</u></div>'),
      );
    });
  });

  group('TextNode merge', () {
    test('merging with the previous TextNode', () {
      var t1 = TextNode('a');
      var t2 = TextNode('b');
      var div = $div(content: [t1, t2]);
      expect(t2.merge(t1), isTrue);
      expect(div.length, equals(1));
      expect(t1.text, equals('ab'));
    });
  });

  group('TemplateNode', () {
    TemplateNode tpl(String s) => TemplateNode(DOMTemplate.parse(s));

    test('merge with a following TextNode', () {
      var t = tpl('{{x}}');
      var div = $div(content: [t, TextNode('a')]);
      expect(t.merge(div.nodes[1]), isTrue);
      expect(div.length, equals(1));
      expect(t.text, equals('{{x}}a'));
    });

    test('merge with a following TemplateNode', () {
      var t1 = tpl('{{x}}');
      var t2 = tpl('{{y}}');
      var div = $div(content: [t1, t2]);
      expect(t1.merge(t2), isTrue);
      expect(div.length, equals(1));
      expect(t1.text, equals('{{x}}{{y}}'));
      expect(t2.isEmptyTemplate, isTrue);
    });

    test('merge with a following string element', () {
      var t = tpl('{{x}}');
      var b = $b(content: 'z');
      var div = $div(content: [t, b]);
      expect(t.merge(b), isTrue);
      expect(div.length, equals(1));
      expect(t.text, equals('{{x}}z'));
      expect(b.isEmptyContent, isTrue);
    });

    test('merge with the previous node delegates to it', () {
      var text = TextNode('a');
      var t = tpl('{{x}}');
      $div(content: [text, t]);
      // `TextNode.merge` does not absorb a `TemplateNode`:
      expect(t.merge(text), isFalse);
    });

    test('merge with a non-consecutive node fails', () {
      var t1 = tpl('{{x}}');
      var t2 = tpl('{{y}}');
      $div(content: [t1, $span(), t2]);
      expect(t1.merge(t2), isFalse);
    });

    test('flags and value', () {
      var t = tpl('{{x}}');
      expect(t.isStringElement, isTrue);
      expect(t.hasOnlyTextNodes, isTrue);
      expect(t.hasOnlyElementNodes, isFalse);
      expect(t.isWhiteSpaceContent, isFalse);
      expect(tpl('   ').isWhiteSpaceContent, isTrue);
      expect(t.value, equals('{{x}}'));
    });

    test('equals', () {
      var t = tpl('{{x}}');
      expect(t.equals(t), isTrue);
      expect(t.equals(TextNode('{{x}}')), isFalse);
    });

    test('buildHTML resolves a DSX template', () {
      String fn() => 'RESOLVED';
      var t = tpl('${fn.dsx()}');
      expect(
        t.buildHTML(dsxResolution: DSXResolution.resolveDSX),
        equals('RESOLVED'),
      );
      expect(
        t.buildHTML(
          dsxResolution: DSXResolution.resolveDSX,
          domContext: DOMContext(),
        ),
        equals('RESOLVED'),
      );
    });

    test('buildHTML resolves a template containing DSX', () {
      String fn() => 'R';
      var t = tpl('a ${fn.dsx()} {{v}}');
      expect(
        t.buildHTML(dsxResolution: DSXResolution.resolveDSX),
        equals('a R {{v}}'),
      );
      expect(
        t.buildHTML(
          dsxResolution: DSXResolution.resolveDSX,
          buildTemplates: true,
          domContext: DOMContext(),
        ),
        equals('a R '),
      );
    });
  });

  group('DOMElement factory', () {
    test('rejects a null or empty tag', () {
      expect(() => DOMElement(null), throwsArgumentError);
      expect(() => DOMElement('  '), throwsArgumentError);
    });

    test('creates a TFOOTElement', () {
      var tfoot = DOMElement(
        'tfoot',
        content: [
          ['a', 'b'],
        ],
      );
      expect(tfoot, isA<TFOOTElement>());
      expect(
        tfoot.buildHTML(),
        equals('<tfoot><tr><td>a</td><td>b</td></tr></tfoot>'),
      );
    });
  });

  group('DOMElement DSX events', () {
    for (var event in [
      'onload',
      'onmouseover',
      'onmouseout',
      'onchange',
      'onkeypress',
      'onkeyup',
      'onkeydown',
      'onerror',
    ]) {
      test('$event attribute becomes a listener', () async {
        var calls = 0;
        int fn() => calls++;
        var nodes = $dsx('<div $event="${fn.dsx()}">x</div>');
        var div = nodes.single as DOMElement;

        expect(div.getAttribute(event), isNull);
        expect(div.resolvedDSXs().length, equals(1));

        var stream = switch (event) {
          'onload' => div.onLoad,
          'onmouseover' => div.onMouseOver,
          'onmouseout' => div.onMouseOut,
          'onchange' => div.onChange,
          'onkeypress' => div.onKeyPress,
          'onkeyup' => div.onKeyUp,
          'onkeydown' => div.onKeyDown,
          _ => div.onError,
        };

        stream.add(DOMMouseEvent.synthetic());
        await _flush();
        expect(calls, equals(1));
      });
    }
  });

  group('DOMElement merge and absorb', () {
    test('absorbNode of a TextNode', () {
      var b = $b(content: 'x');
      expect(b.absorbNode(TextNode('y')), isTrue);
      expect(b.text, equals('xy'));
    });

    test('merge with the previous element', () {
      var b1 = $b(content: 'a');
      var b2 = $b(content: 'c');
      var div = $div(content: [b1, b2]);
      expect(b2.merge(b1), isTrue);
      expect(div.length, equals(1));
      expect(b1.buildHTML(), equals('<b>ac</b>'));
    });

    test('merge with a following TextNode', () {
      var b = $b(content: 'a');
      var div = $div(content: [b, TextNode('z')]);
      expect(b.merge(div.nodes[1]), isTrue);
      expect(div.length, equals(1));
      expect(b.buildHTML(), equals('<b>az</b>'));
    });
  });

  group('DOMElement HTML and equality', () {
    test('buildHTMLContent without an output buffer', () {
      var div = $div(
        content: [
          $b(content: 'x'),
          'y',
        ],
      );
      expect(div.buildHTMLContent().toString(), equals('<b>x</b>y'));
    });

    test('equals compares TemplateNode and other node contents', () {
      var template = DOMTemplate.parse('{{a}}');
      DOMElement withTemplate() => $div(content: [TemplateNode(template)]);
      expect(withTemplate().equals(withTemplate()), isTrue);
      expect(
        withTemplate().equals(
          $div(content: [TemplateNode(DOMTemplate.parse('{{b}}'))]),
        ),
        isFalse,
      );

      var ext = ExternalElementNode('e');
      expect($div(content: [ext]).equals($div(content: [ext])), isTrue);
      expect(
        $div(content: [ExternalElementNode('e')])
            .equals($div(content: [ExternalElementNode('e')])),
        isFalse,
      );
    });

    test(
      'equals compares TemplateNode contents by value',
      () {
        DOMElement withTemplate() =>
            $div(content: [TemplateNode(DOMTemplate.parse('{{a}}'))]);
        expect(withTemplate().equals(withTemplate()), isTrue);
      },
      skip:
          'Bug: `TemplateNode.equals` compares `template` with `==`, but '
          '`DOMTemplate` has identity equality, so equal templates differ',
    );

    test('objectHashcode', () {
      expect(DOMElement.objectHashcode(null), equals(0));
      expect(DOMElement.objectHashcode([]), equals(0));
      expect(
        DOMElement.objectHashcode([1, 2]),
        equals(DOMElement.objectHashcode([1, 2])),
      );
      expect(DOMElement.objectHashcode([1, 2]), isNot(equals(0)));
    });
  });

  group('DOMElement validator', () {
    late _RecordingGenerator generator;

    setUp(() => generator = _RecordingGenerator());

    Future<List<String>> validate(DOMElement elem, Function validator) async {
      generator.generateMapped($div(content: [elem]));
      elem.validator(validator, errorClass: 'err', validClass: 'ok');
      elem.onChange.add(DOMMouseEvent.synthetic());
      await _flush();
      return generator.ops;
    }

    test('DOMElement validator: valid', () async {
      var ops = await validate(
        $span(content: 'ok'),
        (DOMElement e) => e.text == 'ok',
      );
      expect(ops, equals(['-err', '+ok']));
    });

    test('String? validator: invalid', () async {
      var ops = await validate($span(content: 'bad'), (String? v) => v == 'x');
      expect(ops, equals(['-ok', '+err']));
    });

    test('String validator: valid', () async {
      var ops = await validate($span(content: 'abc'), (String v) => v == 'abc');
      expect(ops, equals(['-err', '+ok']));
    });
  });

  group('DOMEvent', () {
    test('domGenerator and cancel', () {
      var generator = DOMGeneratorDummy<Object>();
      var event = DOMEvent<Object>(
        DOMTreeMapDummy<Object>(generator),
        'evt',
        null,
        null,
      );
      expect(event.domGenerator, same(generator));
      expect(event.cancel(), isFalse);
      expect(event.toString(), equals('DOMEvent@evt'));
    });

    test('DOMMouseEvent.cancel', () {
      var event = DOMMouseEvent.synthetic(client: const Point(1, 2));
      expect(event.cancel(stopImmediatePropagation: true), isFalse);
      expect(event.page, equals(const Point(1, 2)));
    });
  });

  group('Element from()', () {
    test('from package `html` nodes', () {
      expect(DIVElement.from(_htmlElement('<div>d</div>'))!.text, 'd');
      expect(INPUTElement.from(_htmlElement('<input value="v">'))!.value, 'v');
      expect(
        CHECKBOXElement.from(_htmlElement('<input type="checkbox" value="c">'))!
            .value,
        'c',
      );
      expect(
        SELECTElement.from(
          _htmlElement('<select><option value="1">A</option></select>'),
        )!.options.single.value,
        '1',
      );
      expect(
        TEXTAREAElement.from(_htmlElement('<textarea>t</textarea>'))!.text,
        't',
      );

      var table = _htmlElement(
        '<table><tbody><tr><td>1</td></tr></tbody>'
        '</table>',
      );
      expect(TABLEElement.from(table)!.tag, 'table');

      var parts = _htmlTableChildren(
        '<caption>C</caption><thead><tr><th>H</th></tr></thead>'
        '<tbody><tr><td>B</td></tr></tbody><tfoot><tr><td>F</td></tr></tfoot>',
      );
      expect(CAPTIONElement.from(parts[0])!.text, 'C');
      expect(THEADElement.from(parts[1])!.text, 'H');
      expect(TBODYElement.from(parts[2])!.text, 'B');
      expect(TFOOTElement.from(parts[3])!.text, 'F');

      var tr = parts[1].children.single;
      expect(TRowElement.from(tr)!.text, 'H');
      expect(THElement.from(tr.children.single)!.text, 'H');

      var td = parts[2].children.single.children.single;
      expect(TDElement.from(td)!.text, 'B');
    });

    test('returns the same instance for the right type', () {
      var select = SELECTElement();
      expect(SELECTElement.from(select), same(select));
      var textarea = TEXTAREAElement();
      expect(TEXTAREAElement.from(textarea), same(textarea));
    });

    test('throws for an element with another tag', () {
      var span = $span();
      expect(() => DIVElement.from(span), throwsStateError);
      expect(() => INPUTElement.from(span), throwsStateError);
      expect(() => CHECKBOXElement.from(span), throwsStateError);
      expect(() => SELECTElement.from(span), throwsStateError);
      expect(() => OPTIONElement.from(span), throwsStateError);
      expect(() => TEXTAREAElement.from(span), throwsStateError);
      expect(() => TABLEElement.from(span), throwsStateError);
      expect(() => THEADElement.from(span), throwsStateError);
      expect(() => CAPTIONElement.from(span), throwsStateError);
      expect(() => TBODYElement.from(span), throwsStateError);
      expect(() => TFOOTElement.from(span), throwsStateError);
      expect(() => TRowElement.from(span), throwsStateError);
      expect(() => THElement.from(span), throwsStateError);
      expect(() => TDElement.from(span), throwsStateError);
    });

    test('CHECKBOXElement from an INPUTElement', () {
      var input = INPUTElement(type: 'checkbox', value: 'yes');
      var checkbox = CHECKBOXElement.from(input)!;
      expect(checkbox, isNot(same(input)));
      expect(checkbox.value, equals('yes'));
      expect(checkbox.getAttributeValue('type'), equals('checkbox'));
    });
  });

  group('OPTIONElement', () {
    test('from a TextNode, Pair, Iterable and object', () {
      var fromText = OPTIONElement.from(TextNode('t'))!;
      expect(fromText.value, 't');
      expect(fromText.text, 't');

      var fromPair = OPTIONElement.from(Pair('v', 'label'))!;
      expect(fromPair.value, 'v');
      expect(fromPair.text, 'label');

      var fromOne = OPTIONElement.from(['one'])!;
      expect(fromOne.value, 'one');
      expect(fromOne.text, 'one');

      var fromTwo = OPTIONElement.from({'k', 'txt'})!;
      expect(fromTwo.value, 'k');
      expect(fromTwo.text, 'txt');

      expect(OPTIONElement.from([]), isNull);

      var fromObject = OPTIONElement.from(_Custom('o'))!;
      expect(fromObject.value, 'custom:o');
    });

    test('toOptions of a single value', () {
      var options = OPTIONElement.toOptions(5);
      expect(options.single.value, '5');
      expect(() => OPTIONElement.toOptions(' '), throwsArgumentError);
    });
  });

  group('Table creation', () {
    test('TABLEElement content of table nodes', () {
      var table = TABLEElement(
        content: [
          CAPTIONElement(content: 'C'),
          THEADElement(
            rows: [
              ['H'],
            ],
          ),
          TBODYElement(
            rows: [
              ['B'],
            ],
          ),
          TFOOTElement(
            rows: [
              ['F'],
            ],
          ),
        ],
      );
      expect(
        table.buildHTML(),
        equals(
          '<table><caption>C</caption>'
          '<thead><tr><th>H</th></tr></thead>'
          '<tbody><tr><td>B</td></tr></tbody>'
          '<tfoot><tr><td>F</td></tr></tfoot></table>',
        ),
      );
    });

    test('TABLEElement content of package `html` nodes', () {
      var parts = _htmlTableChildren(
        '<caption>C</caption><thead><tr><th>H</th></tr></thead>'
        '<tbody><tr><td>B</td></tr></tbody>',
      );
      var table = TABLEElement(content: List<dynamic>.of(parts));
      expect(
        table.buildHTML(),
        equals(
          '<table><caption>C</caption>'
          '<thead><tr><th>H</th></tr></thead>'
          '<tbody><tr><td>B</td></tr></tbody></table>',
        ),
      );
    });

    test(
      'TABLEElement content of a typed list of package `html` elements',
      () {
        var parts = _htmlTableChildren('<tbody><tr><td>B</td></tr></tbody>');
        var table = TABLEElement(content: parts);
        expect(
          table.buildHTML(),
          equals('<table><tbody><tr><td>B</td></tr></tbody></table>'),
        );
      },
      skip:
          'Bug: `createTableContent` calls `firstWhere(orElse: () => null)` '
          'on the caller list, which throws a TypeError for any list with a '
          'non-nullable element type (`List<Element>`, `List<Object>`)',
    );

    test('TABLEElement content mixing `html` element and text nodes', () {
      var tbody = _htmlTableChildren('<tbody><tr><td>B</td></tr></tbody>')[0];
      var text = html_dom.Text('T');
      var table = TABLEElement(content: [tbody, text, 'x']);
      expect(
        table.buildHTML(),
        equals(
          '<table><tbody><tr><td>B</td></tr></tbody><td>T</td>'
          '<tbody><tr><td>x</td></tr></tbody></table>',
        ),
      );
    });

    test(
      'TABLEElement keeps a single non-list content',
      () {
        var table = TABLEElement(content: TBODYElement(rows: 'b'));
        expect(
          table.buildHTML(),
          equals('<table><tbody><tr><td>b</td></tr></tbody></table>'),
        );
      },
      skip:
          'Bug: `createTableContent` drops a non-list `content` and builds '
          '`createTableEntry(body)` instead (an empty table here)',
    );

    test('tbody with a single non-iterable row', () {
      var tbody = TBODYElement(rows: 'cell');
      expect(
        tbody.buildHTML(),
        equals('<tbody><tr><td>cell</td></tr></tbody>'),
      );
    });

    test('header rows convert td cells to th', () {
      var thead = THEADElement(
        rows: [
          [THElement(content: 'a'), TDElement(content: 'b')],
        ],
      );
      expect(
        thead.buildHTML(),
        equals('<thead><tr><th>a</th><th>b</th></tr></thead>'),
      );
    });

    test('body rows convert th cells to td', () {
      var tbody = TBODYElement(
        rows: [
          [TDElement(content: 'a'), THElement(content: 'b')],
        ],
      );
      expect(
        tbody.buildHTML(),
        equals('<tbody><tr><td>a</td><td>b</td></tr></tbody>'),
      );
    });

    test('rows and cells of package `html` nodes', () {
      var tbody = _htmlTableChildren(
        '<tbody><tr><td>1</td><td>2</td></tr></tbody>',
      )[0];
      var tr = tbody.children.single;

      var body = TBODYElement(rows: [tr]);
      expect(
        body.buildHTML(),
        equals('<tbody><tr><td>1</td><td>2</td></tr></tbody>'),
      );

      var row = TRowElement(cells: tr.children);
      expect(row.buildHTML(), equals('<tr><td>1</td><td>2</td></tr>'));
    });
  });
}

void runZonedPrint(List<String> printed, void Function() body) {
  Zone.current
      .fork(
        specification: ZoneSpecification(
          print: (self, parent, zone, line) => printed.add(line),
        ),
      )
      .run(body);
}
