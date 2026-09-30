@TestOn('browser')
library;

import 'dart:async';
import 'dart:math' show Point;

import 'package:dom_builder/dom_builder_web.dart';
import 'package:dom_builder/src/dom_builder_html.dart';
import 'package:test/test.dart';
import 'package:web_utils/web_utils.dart' hide EventType;

/// Integration tests: `dom_builder` driving the real browser DOM through the
/// `package:web` generator ([DOMGeneratorWeb]).

const _svgNS = 'http://www.w3.org/2000/svg';

class _Foo {}

/// Matches the same JS object as [expected] (JS `===`). With `dart2wasm`,
/// the same JS object can be wrapped by distinct Dart objects.
Matcher _sameJS(JSAny expected) => predicate<Object?>(
  (actual) => (actual as JSAny?).strictEquals(expected).toDart,
  'the same JS object as $expected',
);

DOMGeneratorWeb<Node> get _gen => DOMGenerator.web<Node>();

/// A root `div` attached to `document.body`, removed after the test.
HTMLDivElement _root() {
  final root = HTMLDivElement();
  document.body!.appendChild(root);
  addTearDown(() => root.remove());
  return root;
}

/// Generates [domNode] into a new attached root, with a mapped [DOMTreeMap].
({Element element, DOMTreeMap<Node> treeMap}) _generate(
  DOMNode domNode, {
  DOMContext<Node>? context,
}) {
  final treeMap = _gen.createDOMTreeMap();
  final root = _root();
  final element = _gen.generate(
    domNode,
    treeMap: treeMap,
    parent: root,
    context: context,
  );
  return (element: element as Element, treeMap: treeMap);
}

void main() {
  group('DOMHtmlBrowserWeb (isA-based checks)', () {
    final html = DOMHtml();

    test('isHtmlNode / isHtmlTextNode / isHtmlElementNode', () {
      final text = Text('t');
      final comment = Comment('c');
      final div = HTMLDivElement();
      final svg = document.createElementNS(_svgNS, 'svg');
      final fragment = DocumentFragment();

      for (final value in <Object?>[null, 1, 'div', _Foo(), <int>[], {}]) {
        expect(html.isHtmlNode(value), isFalse, reason: '$value');
        expect(html.isHtmlTextNode(value), isFalse, reason: '$value');
        expect(html.isHtmlElementNode(value), isFalse, reason: '$value');
      }

      for (final value in <JSAny>['div'.toJS, 1.toJS, true.toJS, JSObject()]) {
        expect(html.isHtmlNode(value), isFalse, reason: '$value');
        expect(html.isHtmlElementNode(value), isFalse, reason: '$value');
      }

      expect(html.isHtmlNode(text), isTrue);
      expect(html.isHtmlTextNode(text), isTrue);
      expect(html.isHtmlElementNode(text), isFalse);

      expect(html.isHtmlNode(comment), isTrue);
      expect(html.isHtmlTextNode(comment), isFalse);
      expect(html.isHtmlElementNode(comment), isFalse);

      for (final e in <Element>[div, svg]) {
        expect(html.isHtmlNode(e), isTrue);
        expect(html.isHtmlTextNode(e), isFalse);
        expect(html.isHtmlElementNode(e), isTrue);
      }

      expect(html.isHtmlNode(fragment), isTrue);
      expect(html.isHtmlElementNode(fragment), isFalse);
      expect(html.isHtmlNode(document), isTrue);
      expect(html.isHtmlElementNode(document), isFalse);
    });

    test('getNodeText / isEmptyTextNode / getNodeTag', () {
      final div = HTMLDivElement()..textContent = 'abc';
      expect(html.getNodeText(Text('x')), equals('x'));
      expect(html.getNodeText(div), equals('abc'));
      expect(html.getNodeText(null), isEmpty);
      expect(html.getNodeText(_Foo()), isEmpty);
      expect(html.getNodeText(JSObject()), isEmpty);

      expect(html.isEmptyTextNode(Text('  ')), isTrue);
      expect(html.isEmptyTextNode(Text('a')), isFalse);
      expect(html.isEmptyTextNode(div), isFalse);
      expect(html.isEmptyTextNode(null), isFalse);

      expect(html.getNodeTag(div), equals('div'));
      expect(html.getNodeTag(Text('x')), isNull);
      expect(html.getNodeTag(null), isNull);
    });

    test('getChildrenNodes / toHTML', () {
      final div = HTMLDivElement()..innerHTML = '<b>1</b>2'.toJS;
      expect(html.getChildrenNodes(div).length, equals(2));
      expect(html.getChildrenNodes(null), isEmpty);
      expect(html.getChildrenNodes(Text('x')), isEmpty);

      final fragment = DocumentFragment()
        ..appendChild(Text('a'))
        ..appendChild(HTMLSpanElement()..textContent = 'b');
      expect(html.getChildrenNodes(fragment).length, equals(2));
      expect(html.toHTML(fragment), equals('a<span>b</span>'));

      final doc = DOMParser().parseFromString(
        '<p>x</p><p>y</p>'.toJS,
        'text/html',
      );
      expect(html.getChildrenNodes(doc).length, equals(2));
      expect(html.toHTML(doc), contains('<p>x</p>'));

      expect(html.toHTML(div), equals('<div><b>1</b>2</div>'));
      expect(html.toHTML(Text('t')), equals('t'));
      expect(html.toHTML(null), isEmpty);
      expect(html.toHTML(Comment('c')), isEmpty);
    });

    test('toDOMNode / toTextNode / toDOMElement', () {
      final div = HTMLDivElement()
        ..id = 'd'
        ..innerHTML = '<span>s</span>t'.toJS;

      final domElement = html.toDOMNode(div) as DOMElement;
      expect(domElement.tag, equals('div'));
      expect(domElement.id, equals('d'));
      expect(
        domElement.buildHTML(),
        equals('<div id="d"><span>s</span>t</div>'),
      );

      final textNode = html.toDOMNode(Text('hi'));
      expect(textNode, isA<TextNode>());
      expect(textNode!.text, equals('hi'));

      expect(html.toDOMNode(Comment('c')), isNull);
      expect(html.toDOMNode(null), isNull);
      expect(html.toTextNode(div), isNull);
      expect(html.toDOMElement(Text('x')), isNull);
      expect(html.toDOMElement(null), isNull);
    });

    test('DOMNode.from accepts real DOM nodes', () {
      final div = HTMLDivElement()..innerHTML = '<i>x</i>'.toJS;
      final node = DOMNode.from(div);
      expect(node, isA<DOMElement>());
      expect(node!.buildHTML(), equals('<div><i>x</i></div>'));
    });
  });

  group('DOMGeneratorWeb (changed code)', () {
    test('createTextNode', () {
      final existing = Text('x');
      expect(_gen.createTextNode(existing), _sameJS(existing));
      expect(_gen.createTextNode(TextNode('t'))!.textContent, equals('t'));
      expect(_gen.createTextNode(12)!.textContent, equals('12'));
      expect(_gen.createTextNode(''), isNull);
      expect(_gen.createTextNode(null), isNull);
    });

    test('createDOMMouseEvent / createDOMEvent / cancelEvent', () {
      final button = $button(content: 'b');
      final (:element, :treeMap) = _generate(button);

      final mouse = MouseEvent(
        'click',
        MouseEventInit(
          clientX: 3,
          clientY: 4,
          screenX: 5,
          screenY: 6,
          button: 1,
          buttons: 2,
          altKey: true,
          ctrlKey: true,
          shiftKey: true,
          metaKey: true,
          cancelable: true,
        ),
      );
      element.dispatchEvent(mouse);

      final domMouse = _gen.createDOMMouseEvent(treeMap, mouse)!;
      expect(domMouse.eventTarget, _sameJS(element));
      expect(domMouse.target, same(button));
      expect(domMouse.client, equals(const Point(3, 4)));
      expect(domMouse.screen, equals(const Point(5, 6)));
      expect(domMouse.button, equals(1));
      expect(domMouse.buttons, equals(2));
      expect(domMouse.altKey && domMouse.ctrlKey, isTrue);
      expect(domMouse.shiftKey && domMouse.metaKey, isTrue);
      expect(domMouse.domGenerator, same(_gen));

      final other = HTMLSpanElement();
      final withTarget = _gen.createDOMMouseEvent(
        treeMap,
        mouse,
        target: other,
      )!;
      expect(withTarget.eventTarget, _sameJS(other));
      expect(withTarget.target, isNull, reason: 'unmapped target');

      final change = Event('change');
      element.dispatchEvent(change);
      final domEvent = _gen.createDOMEvent(treeMap, change)!;
      expect(domEvent.target, same(button));
      expect(domEvent.toString(), startsWith('DOMEvent@'));

      // Non-events:
      for (final value in <Object?>[null, 'click', _Foo(), JSObject()]) {
        expect(_gen.createDOMMouseEvent(treeMap, value), isNull);
        expect(_gen.createDOMEvent(treeMap, value), isNull);
        expect(_gen.cancelEvent(value), isFalse);
      }
      expect(_gen.createDOMMouseEvent(treeMap, change), isNull);

      // `cancelEvent` only cancels cancelable `UIEvent`s:
      expect(_gen.cancelEvent(change), isFalse);
      expect(_gen.cancelEvent(MouseEvent('click')), isFalse);

      final cancelable = MouseEvent('click', MouseEventInit(cancelable: true));
      expect(_gen.cancelEvent(cancelable), isTrue);
      expect(cancelable.defaultPrevented, isTrue);

      final cancelable2 = MouseEvent('click', MouseEventInit(cancelable: true));
      expect(domMouse.cancel(), isTrue);
      expect(
        _gen.cancelEvent(cancelable2, stopImmediatePropagation: true),
        isTrue,
      );
    });

    test('cancel from a DOM event listener prevents the default', () async {
      final button = $button(content: 'b');
      final canceled = <bool>[];
      button.onClick.listen((e) => canceled.add(e.cancel()));
      final (:element, treeMap: _) = _generate(button);

      final event = MouseEvent('click', MouseEventInit(cancelable: true));
      element.dispatchEvent(event);
      await Future<void>.delayed(Duration.zero);

      expect(canceled, equals([true]));
      expect(event.defaultPrevented, isTrue);
    });

    test('action selectByID falls back to the treeMap root element', () {
      final executor = _gen.domActionExecutor!;
      final div = $div(
        id: 'act-root',
        content: [$span(id: 'act-target', content: 'x')],
      );
      final (:element, :treeMap) = _generate(div);
      final target = element.querySelector('#act-target')!;

      // Via `self`:
      expect(
        executor.selectByID('act-target', null, element, null, null),
        _sameJS(target),
      );
      // Via `target`:
      expect(
        executor.selectByID('act-target', element, null, null, null),
        _sameJS(target),
      );
      // Via the treeMap root (`rootElement.isA<Element>()`):
      expect(treeMap.rootElement, _sameJS(element));
      expect(
        executor.selectByID('act-target', Text('x'), null, treeMap, null),
        _sameJS(target),
      );
      // Via `document`:
      expect(
        executor.selectByID('act-target', null, null, null, null),
        _sameJS(target),
      );
    });

    test('runtime clear() on Element and Text nodes', () {
      final div = $div(
        content: [
          $span(content: 'a'),
          'b',
        ],
      );
      final (:element, treeMap: _) = _generate(div);

      expect(element.childNodes.length, equals(2));
      div.runtime.clear();
      expect(element.childNodes.length, equals(0));

      final text = TextNode('t');
      final holder = $div(content: [text]);
      _generate(holder);
      text.runtime.clear(); // Text node: no children, must not throw
      expect(holder.runtime.text, equals('t'));
    });

    test('Node.clear() on a non-Element node (web_utils 1.1.0 fix)', () {
      final fragment = DocumentFragment()
        ..appendChild(Text('a'))
        ..appendChild(HTMLSpanElement());
      fragment.clear();
      expect(fragment.childNodes.length, equals(0));
    });

    test('typed event streams via dom_builder elements', () async {
      final input = $input(value: 'x');
      final events = <String>[];
      input.onKeyUp.listen((e) => events.add('keyup:${e.event.runtimeType}'));
      input.onKeyDown.listen((_) => events.add('keydown'));
      input.onKeyPress.listen((_) => events.add('keypress'));
      input.onChange.listen((_) => events.add('change'));
      input.onMouseOver.listen((e) => events.add('over:${e.client.x}'));
      input.onMouseOut.listen((_) => events.add('out'));

      final (:element, treeMap: _) = _generate(input);

      element.dispatchEvent(
        KeyboardEvent('keyup', KeyboardEventInit(key: 'a')),
      );
      element.dispatchEvent(KeyboardEvent('keydown'));
      element.dispatchEvent(KeyboardEvent('keypress'));
      element.dispatchEvent(Event('change'));
      element.dispatchEvent(
        MouseEvent('mouseover', MouseEventInit(clientX: 9)),
      );
      element.dispatchEvent(MouseEvent('mouseout'));
      await Future<void>.delayed(Duration.zero);

      expect(events.length, equals(6));
      expect(events.first, startsWith('keyup:'));
      expect(
        events.skip(1),
        equals(['keydown', 'keypress', 'change', 'over:9', 'out']),
      );
    });

    test('onLoad / onError streams', () async {
      final img = $img();
      final loads = <DOMEvent>[];
      final errors = <DOMEvent>[];
      img.onLoad.listen(loads.add);
      img.onError.listen(errors.add);
      final (:element, treeMap: _) = _generate(img);

      element.dispatchEvent(Event('load'));
      element.dispatchEvent(Event('error'));
      await Future<void>.delayed(Duration.zero);

      expect(loads.single.target, same(img));
      expect(errors.single.target, same(img));
    });
  });

  group('end-to-end generation', () {
    test('form with inputs, textarea, checkbox and select', () {
      final form = $form(
        id: 'f',
        content: [
          $input(
            id: 'name',
            name: 'name',
            type: 'text',
            placeholder: 'Name',
            value: 'Joe',
          ),
          $textarea(id: 'bio', name: 'bio', cols: 10, rows: 2, content: 'hi'),
          $checkbox(id: 'ok', name: 'ok', checked: true, value: 'y'),
          $select(
            id: 'sel',
            name: 'sel',
            options: [
              $option(value: 'a', text: 'A'),
              $option(value: 'b', text: 'B', selected: true),
            ],
          ),
          $input(id: 'dis', disabled: true),
        ],
      );

      final (:element, treeMap: _) = _generate(form);
      expect(element.tagName, equals('FORM'));

      final name = element.querySelector('#name') as HTMLInputElement;
      expect(name.type, equals('text'));
      expect(name.placeholder, equals('Name'));
      expect(name.value, equals('Joe'));
      expect(name.name, equals('name'));

      final bio = element.querySelector('#bio') as HTMLTextAreaElement;
      expect(bio.value, equals('hi'));
      expect(bio.getAttribute('cols'), equals('10'));

      final ok = element.querySelector('#ok') as HTMLInputElement;
      expect(ok.type, equals('checkbox'));
      expect(ok.checked, isTrue);

      final sel = element.querySelector('#sel') as HTMLSelectElement;
      expect(sel.options.length, equals(2));
      expect(sel.value, equals('b'));

      final dis = element.querySelector('#dis') as HTMLInputElement;
      expect(dis.disabled, isTrue);

      // Generator value accessors:
      expect(_gen.getElementValue(name), equals('Joe'));
      expect(_gen.getElementValue(bio), equals('hi'));
      expect(_gen.getElementValue(ok), equals('true'));
      expect(_gen.getElementValue(sel), equals('b'));
      expect(_gen.getElementValue(Text('t')), equals('t'));
      expect(_gen.getElementValue(null), isNull);
      expect(_gen.getElementValue(HTMLInputElement()..type = 'file'), isEmpty);
    });

    test('tables', () {
      final table = $table(
        caption: 'Cap',
        head: [
          ['H1', 'H2'],
        ],
        body: [
          ['a', 'b'],
          ['c', 'd'],
        ],
        foot: [
          ['f1', 'f2'],
        ],
      );
      final (:element, treeMap: _) = _generate(table);
      final t = element as HTMLTableElement;

      expect(t.caption!.textContent, equals('Cap'));
      expect(t.tHead!.rows.length, equals(1));
      expect(t.tBodies.length, equals(1));
      expect(t.tFoot!.textContent, equals('f1f2'));
      expect(
        t.querySelectorAll('tbody td').toList().map((e) => e.textContent),
        equals(['a', 'b', 'c', 'd']),
      );
      expect(t.querySelectorAll('thead th').length, equals(2));
    });

    test('attributes: special handling', () {
      final div = $div(
        id: 'x',
        classes: 'a b',
        style: 'color: red',
        attributes: {'hidden': 'true', 'inert': 'true', 'data-k': 'v'},
      );
      final (:element, treeMap: _) = _generate(div);
      final e = element as HTMLElement;

      expect(e.id, equals('x'));
      expect(e.className, equals('a b'));
      expect(e.style.color, equals('red'));
      expect(e.hidden.dartify(), isTrue);
      expect(e.inert, isTrue);
      expect(e.getAttribute('data-k'), equals('v'));

      _gen.setAttribute(e, 'id', null);
      _gen.setAttribute(e, 'class', null);
      _gen.setAttribute(e, 'style', null);
      _gen.setAttribute(e, 'data-k', null);
      _gen.setAttribute(e, 'hidden', 'false');
      expect(e.hasAttribute('id'), isFalse);
      expect(e.hasAttribute('class'), isFalse);
      expect(e.getAttribute('style') ?? '', isEmpty);
      expect(e.style.color, isEmpty);

      final styled = HTMLDivElement();
      _gen.setAttribute(styled, 'style', 'color: red');
      expect(styled.style.color, equals('red'));
      _gen.setAttribute(styled, 'style', null);
      expect(styled.style.color, isEmpty);
      expect(e.hasAttribute('data-k'), isFalse);
      expect(e.hidden.dartify(), isFalse);
      _gen.setAttribute(Text('t'), 'id', 'ignored');

      final select = HTMLSelectElement();
      _gen.setAttribute(select, 'multiple', 'true');
      expect(select.multiple, isTrue);
      final input = HTMLInputElement()..type = 'file';
      _gen.setAttribute(input, 'multiple', null);
      expect(input.multiple, isTrue);
      final divM = HTMLDivElement();
      _gen.setAttribute(divM, 'multiple', 'x');
      expect(divM.getAttribute('multiple'), equals('x'));

      final option = HTMLOptionElement();
      _gen.setAttribute(option, 'selected', 'true');
      expect(option.selected, isTrue);
      final divS = HTMLDivElement();
      _gen.setAttribute(divS, 'selected', 'y');
      expect(divS.getAttribute('selected'), equals('y'));

      expect(_gen.getAttribute(e, 'data-k'), isNull);
      expect(_gen.getAttribute(Text('t'), 'x'), isNull);
    });

    test('SVG elements', () {
      final svg = $tag(
        'svg',
        attributes: {'viewbox': '0 0 10 10', 'width': '10'},
        content: '<circle r="5"></circle>',
      );
      final (:element, treeMap: _) = _generate(svg);
      expect(element.namespaceURI, equals(_svgNS));
      expect(element.getAttribute('viewBox'), equals('0 0 10 10'));
      expect(element.querySelector('circle'), isNotNull);
    });

    test('generator helpers', () {
      final div = HTMLDivElement()..innerHTML = '<b>1</b>2'.toJS;
      final b = div.firstChild!;

      expect(_gen.getElementTag(div), equals('DIV'));
      expect(_gen.getElementTag(Text('x')), isNull);
      expect(_gen.getElementNodes(div).length, equals(2));
      expect(_gen.getElementNodes(div, asView: true).length, equals(2));
      expect(_gen.getElementNodes(Text('x')), isEmpty);
      expect(_gen.getElementOuterHTML(div), equals('<div><b>1</b>2</div>'));
      expect(_gen.getElementOuterHTML(Text('t')), equals('t'));
      expect(_gen.getElementOuterHTML(null), isNull);
      expect(_gen.getElementAttributes(Text('t')), isNull);
      expect(_gen.getNodeParent(b), _sameJS(div));
      expect(_gen.getNodeText(div), equals('12'));
      expect(_gen.getNodeText(null), isNull);
      expect(_gen.isTextNode(Text('x')), isTrue);
      expect(_gen.isTextNode(div), isFalse);
      expect(_gen.containsNode(div, b), isTrue);
      expect(_gen.containsNode(div, null), isFalse);
      expect(_gen.isChildOfElement(div, b), isTrue);
      expect(_gen.isChildOfElement(Text('x'), b), isFalse);
      expect(_gen.isChildOfElement(null, b), isFalse);
      expect(_gen.buildElementHTML(div), equals('<div><b>1</b>2</div>'));
      expect(_gen.buildElementHTML(Text('t')), equals('t'));
      expect(_gen.buildElementHTML(Comment('c')), isNull);

      final span = HTMLSpanElement();
      expect(_gen.addChildToElement(div, span), isTrue);
      expect(_gen.addChildToElement(div, span), isFalse, reason: 'already');
      expect(_gen.addChildToElement(Text('x'), span), isFalse);
      expect(_gen.addChildToElement(null, span), isFalse);
      expect(_gen.removeChildFromElement(div, span), isTrue);
      expect(_gen.removeChildFromElement(div, span), isFalse);
      expect(_gen.removeChildFromElement(div, null), isFalse);
      expect(_gen.removeChildFromElement(Text('x'), span), isFalse);

      final i1 = HTMLElement.article();
      final i2 = HTMLElement.aside();
      expect(_gen.replaceChildElement(div, b, [i1, i2]), isTrue);
      expect(
        div.innerHTML.dartify(),
        equals('<article></article><aside></aside>2'),
      );
      expect(_gen.replaceChildElement(div, b, [i1]), isFalse);
      expect(_gen.replaceChildElement(Text('x'), b, [i1]), isFalse);

      final wrapper = _gen.wrapElements([Text('a'), HTMLSpanElement()])!;
      expect((wrapper as HTMLElement).style.display, equals('contents'));
      expect(wrapper.childNodes.length, equals(2));
      expect(_gen.wrapElements([]), isNull);
      expect(_gen.wrapElements(null), isNull);

      expect(_gen.appendElementText(div, 'z')!.textContent, equals('z'));
      expect(_gen.appendElementText(div, ''), isNull);

      expect(_gen.canHandleExternalElement(div), isTrue);
      expect(_gen.canHandleExternalElement(null), isFalse);
      expect(_gen.canHandleExternalElement(_Foo()), isFalse);

      expect(_gen.isEquivalentNodeType(TextNode('a'), Text('a')), isTrue);
      expect(_gen.isEquivalentNodeType($div(), div), isTrue);
      expect(_gen.isEquivalentNodeType($span(), div), isFalse);
      expect(_gen.isEquivalentNodeType($div(), Comment('c')), isFalse);
      expect(
        _gen.isEquivalentNode($div(id: 'q'), HTMLDivElement()..id = 'q'),
        isTrue,
      );
      expect(
        _gen.isEquivalentNode($div(id: 'q'), HTMLDivElement()..id = 'r'),
        isFalse,
      );
      expect(_gen.isEquivalentNode($span(), div), isFalse);
    });

    test('external elements inside DOMElements', () {
      final real = HTMLSpanElement()..textContent = 'real';
      final real2 = HTMLElement.article()..textContent = 'art';
      final div = $div(content: [real]);
      final (:element, treeMap: _) = _generate(div);
      expect(element.querySelector('span')!.textContent, equals('real'));

      expect(
        _gen.addExternalElementToElement(element, real2)!.length,
        equals(1),
      );
      expect(element.querySelector('article'), isNotNull);
      expect(_gen.addExternalElementToElement(element, null), isNull);
      expect(_gen.addExternalElementToElement(Text('t'), real2), isNull);
    });

    // Regression: list elements are `dynamic`, and calling the `asJSAny`
    // extension on them threw `NoSuchMethodError`.
    test('external elements: a List of nodes', () {
      final element = _root();
      final added = _gen.addExternalElementToElement(element, [
        HTMLElement.article(),
        [HTMLSpanElement()],
        null,
      ]);
      expect(added!.length, equals(2));
      expect(element.querySelector('article'), isNotNull);
      expect(element.querySelector('span'), isNotNull);
    });

    test('generateFromHTML and generateNodes', () {
      final root = _root();
      final generated = _gen.generateFromHTML(
        '<p id="gp">para <b>bold</b></p>',
        parent: root,
      );
      expect(generated, isNotNull);
      expect(root.querySelector('#gp b')!.textContent, equals('bold'));

      final nodes = _gen.generateNodes([$span(content: 'a'), TextNode('b')]);
      expect(nodes.length, equals(2));
      expect(nodes.first.textContent, equals('a'));
    });
  });

  group('DOMTreeMap', () {
    test('maps both ways', () {
      final span = $span(content: 'x');
      final div = $div(content: [span]);
      final (:element, :treeMap) = _generate(div);
      final spanElement = element.firstChild!;

      expect(treeMap.getMappedElement(div), _sameJS(element));
      expect(treeMap.getMappedDOMNode(element), same(div));
      expect(treeMap.getMappedDOMNode(spanElement), same(span));
      expect(treeMap.isMappedDOMNode(span), isTrue);
      expect(treeMap.isMappedElement(spanElement), isTrue);
      expect(treeMap.isMappedElement(HTMLDivElement()), isFalse);
      expect(treeMap.matchesMapping(span, spanElement), isTrue);
      expect(treeMap.rootDOMNode, same(div));
      expect(span.isGenerated, isTrue);
      expect(span.runtimeNode, _sameJS(spanElement));

      // Unmapped child of a mapped element:
      final extra = HTMLElement.article();
      spanElement.appendChild(extra);
      expect(treeMap.getMappedDOMNode(extra), isNull);
      expect(treeMap.getMappedDOMNode(extra, checkParents: true), same(span));
      expect(treeMap.asMappedElement(extra), _sameJS(spanElement));

      expect(treeMap.unmap(span, spanElement), isTrue);
      expect(treeMap.unmap(span, spanElement), isFalse);
      expect(treeMap.getMappedDOMNode(spanElement), isNull);
    });

    // Regression (dart2wasm): the element -> DOMTreeMap association was an
    // `Expando` keyed by the Dart wrapper, and the same DOM node can have
    // distinct wrappers with dart2wasm.
    test('getElementDOMTreeMap from a re-wrapped JS element', () {
      final span = $span(content: 'x');
      final div = $div(content: [span]);
      final (:element, :treeMap) = _generate(div);
      // A new JS wrapper of the same DOM node:
      final spanElement = element.firstChild!;
      expect(DOMTreeMap.getElementDOMTreeMap(spanElement), same(treeMap));
      expect(DOMTreeMap.getElementDOMTreeMap(HTMLDivElement()), isNull);
      expect(DOMTreeMap.getElementDOMTreeMap<Object>(null), isNull);
    });

    test('generateMapped', () {
      final div = $div(content: 'x');
      final treeMap = _gen.generateMapped(div);
      expect(treeMap.rootElement, isNotNull);
      expect(treeMap.getMappedDOMNode(treeMap.rootElement), same(div));
    });
  });

  group('DOMNodeRuntime', () {
    test('attributes / classes / text / value', () {
      final div = $div(id: 'r', classes: 'a', content: 'text');
      final (:element, treeMap: _) = _generate(div);
      final rt = div.runtime;

      expect(rt.exists, isTrue);
      expect(rt.tagName, equals('div'));
      expect(rt.isStringElement, isFalse);
      expect(rt.hasParent, isTrue);

      expect(rt.classes, equals(['a']));
      rt.addClass(' b ');
      rt.addClass('');
      rt.addClass(null);
      expect(element.className, equals('a b'));
      expect(rt.removeClass('a'), isTrue);
      expect(rt.removeClass('a'), isFalse);
      expect(rt.removeClass(' '), isFalse);
      expect(rt.removeClass(null), isFalse);
      expect(rt.classes, equals(['b']));

      rt.setAttribute('data-x', '1');
      expect(rt.getAttribute('data-x'), equals('1'));
      expect(element.getAttribute('data-x'), equals('1'));
      rt.removeAttribute('data-x');
      expect(rt.getAttribute('data-x'), isNull);

      rt.style = 'color: blue';
      expect(rt.getStyleProperty('color'), equals('blue'));

      expect(rt.text, equals('text'));
      rt.text = 'new';
      expect(element.textContent, equals('new'));
      expect(rt.value, equals('new'));
      rt.value = 'v';
      expect(element.textContent, equals('v'));
    });

    // Regression: `clearClasses` used to remove the element's children.
    test('clearClasses only clears classes', () {
      final div = $div(classes: 'a b', content: 'keep');
      final (:element, treeMap: _) = _generate(div);
      div.runtime.clearClasses();
      expect(element.className, isEmpty);
      expect(element.textContent, equals('keep'));
    });

    test('values of form elements', () {
      final input = $input(value: 'a');
      final checkbox = $checkbox(checked: false);
      final textarea = $textarea(content: 'ta');
      final img = $img(src: 'about:blank');
      final a = $a(href: 'about:blank');
      final holder = $div(content: [input, checkbox, textarea, img, a]);
      _generate(holder);

      expect(input.runtime.value, equals('a'));
      input.runtime.value = 'b';
      expect(input.getRuntimeNode<HTMLInputElement>()!.value, equals('b'));

      expect(checkbox.runtime.value, equals('false'));
      checkbox.runtime.value = 'true';
      expect(checkbox.getRuntimeNode<HTMLInputElement>()!.checked, isTrue);

      expect(textarea.runtime.value, equals('ta'));
      textarea.runtime.value = 'tb';
      expect(
        textarea.getRuntimeNode<HTMLTextAreaElement>()!.value,
        equals('tb'),
      );

      expect(img.runtime.value, equals('about:blank'));
      img.runtime.value = 'about:blank#2';
      expect(
        img.getRuntimeNode<HTMLImageElement>()!.src,
        equals('about:blank#2'),
      );

      expect(a.runtime.value, equals('about:blank'));
      a.runtime.value = 'about:blank#3';
      expect(
        a.getRuntimeNode<HTMLAnchorElement>()!.href,
        equals('about:blank#3'),
      );
    });

    test('children manipulation', () {
      final a = $span(content: 'a');
      final b = $span(content: 'b');
      final c = $span(content: 'c');
      final div = $div(content: [a, b, c]);
      final (:element, treeMap: _) = _generate(div);
      final rt = div.runtime as DOMNodeRuntime<Node>;

      expect(rt.nodesLength, equals(3));
      expect(rt.children.length, equals(3));
      expect(rt.getNodeAt(1)!.textContent, equals('b'));
      expect(rt.indexOf(element.childNodes.item(2)!), equals(2));
      expect(b.runtime.indexInParent, equals(1));

      final bNode = b.getRuntimeNode<Node>()!;
      final cNode = c.getRuntimeNode<Node>()!;
      final aRt = a.runtime as DOMNodeRuntime<Node>;
      expect(aRt.isInSameParent(bNode), isTrue);
      expect(aRt.isNextNode(bNode), isTrue);
      expect(aRt.isConsecutiveNode(bNode), isTrue);
      expect(aRt.isPreviousNode(bNode), isFalse);

      final d = HTMLSpanElement()..textContent = 'd';
      rt.add(d);
      rt.insertAt(0, HTMLSpanElement()..textContent = 'z');
      rt.insertAt(0, null);
      expect(element.textContent, equals('zabcd'));

      expect(rt.removeNode(d), isTrue);
      expect(rt.removeNode(d), isFalse);
      expect(rt.removeNode(null), isFalse);
      expect(rt.removeAt(0)!.textContent, equals('z'));
      expect(element.textContent, equals('abc'));

      expect((c.runtime as DOMNodeRuntime<Node>).moveUp(), isTrue);
      expect(element.textContent, equals('acb'));
      expect((c.runtime as DOMNodeRuntime<Node>).moveDown(), isTrue);
      expect(element.textContent, equals('abc'));

      final copy = (b.runtime as DOMNodeRuntime<Node>).copy() as Element;
      expect(copy.textContent, equals('b'));
      expect(copy.isConnected, isFalse);

      final dup = (b.runtime as DOMNodeRuntime<Node>).duplicate();
      expect(dup, isNotNull);
      expect(element.textContent, equals('abbc'));

      expect(cNode.isConnected, isTrue);
      expect(c.runtime.remove(), isTrue);
      expect(cNode.isConnected, isFalse);
      expect(c.runtime.remove(), isFalse);
    });

    test('absorbNode / mergeNode', () {
      final t1 = TextNode('a');
      final t2 = TextNode('b');
      final s1 = $span(content: 'x');
      final s2 = $span(content: 'y');
      final s3 = $span();
      final div = $div(content: [s1, s2, s3]);
      final p = $p(content: [t1]);
      final holder = $div(content: [div, p]);
      _generate(holder);

      final s1Rt = s1.runtime as DOMNodeRuntime<Node>;
      expect(s1Rt.absorbNode(s2.getRuntimeNode<Node>()), isTrue);
      expect(s1Rt.text, equals('xy'));
      expect(s1Rt.absorbNode(s3.getRuntimeNode<Node>()), isTrue);
      expect(s1Rt.absorbNode(null), isFalse);
      final loose = Text('z');
      expect(s1Rt.absorbNode(loose), isTrue);
      expect(s1Rt.text, equals('xyz'));
      expect(s1Rt.absorbNode(Comment('c')), isFalse);

      final t1Rt = t1.runtime as DOMNodeRuntime<Node>;
      final pNode = p.getRuntimeNode<Element>()!;
      pNode.appendChild(Text('b'));
      expect(t1Rt.absorbNode(pNode.lastChild), isTrue);
      expect(t1Rt.text, equals('ab'));
      final spanOther = HTMLSpanElement()..textContent = 'c';
      expect(t1Rt.absorbNode(spanOther), isTrue);
      expect(t1Rt.text, equals('abc'));
      expect(spanOther.childNodes.length, equals(0));
      expect(t1Rt.absorbNode(Comment('x')), isFalse);
      expect(t1Rt.isStringElement, isTrue);

      final m1 = $span(content: '1');
      final m2 = $span(content: '2');
      final mHolder = $div(content: [m1, m2]);
      final (:element, treeMap: _) = _generate(mHolder);
      final m1Rt = m1.runtime as DOMNodeRuntime<Node>;
      expect(m1Rt.mergeNode(m2.getRuntimeNode<Node>()), isTrue);
      expect(element.textContent, equals('12'));
      expect(t2.text, equals('b'));
    });

    test('replaceBy', () {
      final a = $span(content: 'a');
      final div = $div(content: [a]);
      final (:element, treeMap: _) = _generate(div);
      final repl = HTMLElement.article()..textContent = 'R';
      final rt = a.runtime;
      expect(rt.replaceBy(null), isFalse);
      expect(rt.replaceBy([repl]), isTrue);
      expect(element.innerHTML.dartify(), equals('<article>R</article>'));
      // The replaced DOMNode is unmapped:
      expect(a.treeMap!.getMappedElement(a), isNull);
    });
  });

  group('DOMAsync', () {
    test('resolves a Future into the DOM', () async {
      final completer = Completer<Object>();
      final async = DOMAsync(loading: 'loading...', future: completer.future);
      final div = $div(content: [async]);
      final (:element, treeMap: _) = _generate(div);

      expect(element.textContent, contains('loading'));
      completer.complete($span(content: 'done'));
      await Future<void>.delayed(const Duration(milliseconds: 20));
      expect(element.querySelector('span')?.textContent, equals('done'));
    });

    test('resolves a Function into the DOM', () async {
      final async = $asyncContent(
        loading: $span(content: 'wait'),
        function: () async => 'resolved',
      );
      final div = $div(content: [async]);
      final (:element, treeMap: _) = _generate(div);

      await Future<void>.delayed(const Duration(milliseconds: 20));
      expect(element.textContent, contains('resolved'));
    });
  });

  group('templates / DSX / actions', () {
    test('template content rendered with context variables', () {
      final context = DOMContext<Node>()..putVariable('locale', 'fr');
      final div = $div(content: '{{:locale=="en"}}YES{{?}}OUI{{/}}');
      final (:element, treeMap: _) = _generate(div, context: context);
      expect(element.textContent, equals('OUI'));
    });

    test('DSX onclick handler called from a real click', () async {
      final clicks = Completer<int>();
      void onClicked([int arg = -1]) => clicks.complete(arg);

      final nodes = $dsx(
        '<button id="dsx-b" onclick="${onClicked.dsx()}">GO</button>',
      );
      final button = nodes.single as DOMElement;
      final (:element, treeMap: _) = _generate(button);

      element.dispatchEvent(MouseEvent('click'));
      expect(await clicks.future.timeout(const Duration(seconds: 2)), -1);
    });

    test(
      'action attribute: hide / show / addClass / setClass on click',
      () async {
        final target = $div(id: 'act-t', classes: 'x', content: 'T');
        final btnHide = $button(
          attributes: {'action': '#act-t.hide()'},
          content: 'hide',
        );
        final btnShow = $button(
          attributes: {'action': '#act-t.show()'},
          content: 'show',
        );
        final btnAdd = $button(
          attributes: {'action': '#act-t.addClass(y)'},
          content: 'add',
        );
        final btnSet = $button(
          attributes: {'action': '#act-t.setClass(k);#act-t.clearClass()'},
          content: 'set',
        );
        final holder = $div(
          content: [target, btnHide, btnShow, btnAdd, btnSet],
        );
        final (:element, treeMap: _) = _generate(holder);
        final t = element.querySelector('#act-t') as HTMLElement;

        Future<void> click(DOMElement b) async {
          b.getRuntimeNode<Element>()!.dispatchEvent(MouseEvent('click'));
          await Future<void>.delayed(Duration.zero);
        }

        await click(btnHide);
        expect(t.hidden.dartify(), isTrue);
        t.style.display = 'none';
        await click(btnShow);
        expect(t.hidden.dartify(), isFalse);
        expect(t.style.display, isEmpty);

        await click(btnAdd);
        expect(t.classList.toList(), equals(['x', 'y']));

        await click(btnSet);
        expect(t.classList.toList(), isEmpty);
      },
    );

    test('action attribute on inputs fires on change', () async {
      final target = $div(id: 'act-c', content: 'C');
      final input = $input(attributes: {'action': '#act-c.clear()'});
      final holder = $div(content: [target, input]);
      final (:element, treeMap: _) = _generate(holder);

      input.getRuntimeNode<Element>()!.dispatchEvent(Event('change'));
      await Future<void>.delayed(Duration.zero);
      expect(element.querySelector('#act-c')!.childNodes.length, equals(0));
    });

    test('action executor: remove / removeClass', () {
      final executor = _gen.domActionExecutor!;
      final div = $div(id: 'act-rm', classes: 'a b', content: 'R');
      final (:element, :treeMap) = _generate(div);

      executor.call('addclass', ['c'], null, element, treeMap, null);
      expect(element.classList.contains('c'), isTrue);
      executor.callRemoveClass(element, ['a']);
      expect(element.classList.contains('a'), isFalse);
      expect(
        executor.call('unknown', [], null, element, treeMap, null),
        isNull,
      );
      expect(executor.call(' ', [], null, element, treeMap, null), isNull);

      executor.call('remove', [], null, element, treeMap, null);
      expect(element.isConnected, isFalse);
    });

    // Regression: 'removeclass' was dispatched to `callAddClass`.
    test('action removeClass() removes classes', () {
      final executor = _gen.domActionExecutor!;
      final div = $div(classes: 'a b');
      final (:element, :treeMap) = _generate(div);
      executor.call('removeclass', ['a'], null, element, treeMap, null);
      expect(element.classList.contains('a'), isFalse);
      expect(element.classList.contains('b'), isTrue);
      executor.call('removeclasses', ['b'], null, element, treeMap, null);
      expect(element.classList.contains('b'), isFalse);
      expect(
        executor.call('removeclass', ['x'], null, null, treeMap, null),
        isNull,
      );
    });

    // Regression: actions with 2+ parameters threw in `parseParameters`.
    test('action attribute with several parameters', () async {
      final target = $div(id: 'act-multi', classes: 'x y z');
      final btnAdd = $button(
        attributes: {'action': '#act-multi.addClass(a, b)'},
        content: 'add',
      );
      final btnRemove = $button(
        attributes: {'action': '#act-multi.removeClass(x, z)'},
        content: 'remove',
      );
      final (:element, treeMap: _) = _generate(
        $div(content: [target, btnAdd, btnRemove]),
      );
      final t = element.querySelector('#act-multi')!;

      Future<void> click(DOMElement b) async {
        b.getRuntimeNode<Element>()!.dispatchEvent(MouseEvent('click'));
        await Future<void>.delayed(Duration.zero);
      }

      await click(btnAdd);
      expect(t.classList.contains('a'), isTrue);
      expect(t.classList.contains('b'), isTrue);

      await click(btnRemove);
      expect(t.classList.contains('x'), isFalse);
      expect(t.classList.contains('z'), isFalse);
      expect(t.classList.contains('y'), isTrue);
    });

    test('action locale() is dispatched to the executor', () {
      final executor = _gen.domActionExecutor!;
      final div = HTMLDivElement();
      final context = DOMContext<Node>()
        ..variables = {
          'event': {'value': 'fr'},
        };
      expect(
        executor.call('locale', ['x'], null, div, null, context),
        _sameJS(div),
      );
      expect(
        executor.callShow(Text('t')),
        isA<Text>(),
        reason: 'non-HTMLElement is returned untouched',
      );
      expect(executor.callHide(null), isNull);
      expect(executor.callClear(null), isNull);
      expect(executor.callAddClass(null, ['a']), isNull);
      expect(executor.callSetClass(null, ['a']), isNull);
      expect(executor.callClearClass(null), isNull);
    });

    test('DOMAction.parse chains and lists', () {
      final executor = _gen.domActionExecutor!;
      final action = executor.parse('#a.hide();#b.show()')!;
      expect(action, isA<DOMActionList>());
      expect(action.toString(), equals('#a.hide();#b.show()'));
      expect(executor.parse(''), isNull);
      expect(executor.parse(null), isNull);
    });
  });

  group('HTML parsing and querying', () {
    final html = DOMHtml();

    test('parse: entities, <br> shortcuts and HTML', () {
      expect((html.parse('&nbsp;') as TextNode).text, equals(' '));
      expect((html.parse('&nbsp;&nbsp;') as TextNode).text.length, equals(2));
      expect(
        (html.parse('&nbsp;&nbsp;&nbsp;') as TextNode).text.length,
        equals(3),
      );
      expect(
        (html.parse('&nbsp;&nbsp;&nbsp;&nbsp;') as TextNode).text.length,
        equals(4),
      );
      expect((html.parse('&emsp;') as TextNode).text, equals(' '));
      expect((html.parse('&emsp;&emsp;') as TextNode).text.length, equals(2));
      expect(
        (html.parse('&emsp;&emsp;&emsp;') as TextNode).text.length,
        equals(3),
      );
      expect(
        (html.parse('&emsp;&emsp;&emsp;&emsp;') as TextNode).text.length,
        equals(4),
      );
      expect((html.parse('<br>') as DOMElement).tag, equals('br'));
      expect((html.parse('<br><br>') as List).length, equals(2));
      expect((html.parse('<br><br><br>') as List).length, equals(3));
      expect((html.parse('<br><br><br><br>') as List).length, equals(4));

      final body = html.parse('<p>x</p>');
      expect(html.isHtmlElementNode(body), isTrue);
      expect(html.getNodeTag(body), equals('body'));
    });

    test('querySelector on Document / DocumentFragment / Element', () {
      final doc = DOMParser().parseFromString(
        '<p id="q">x</p>'.toJS,
        'text/html',
      );
      expect(html.querySelector(doc, '#q'), isNotNull);

      final fragment = DocumentFragment()
        ..appendChild(HTMLSpanElement()..id = 'fq');
      expect(html.querySelector(fragment, '#fq'), isNotNull);

      final div = HTMLDivElement()..innerHTML = '<i id="dq"></i>'.toJS;
      expect(html.querySelector(div, '#dq'), isNotNull);
      expect(html.querySelector(div, '#none'), isNull);
      expect(html.querySelector(Text('t'), 'x'), isNull);
      expect(html.querySelector(null, 'x'), isNull);
    });

    test('toDOMElement of unmapped inputs keeps live values', () {
      final checkbox = HTMLInputElement()
        ..type = 'checkbox'
        ..checked = true;
      final domCheckbox = html.toDOMElement(checkbox)!;
      expect(domCheckbox.getAttributeValue('checked'), equals('true'));

      final input = HTMLInputElement()..value = 'typed';
      final domInput = html.toDOMElement(input)!;
      expect(domInput.getAttributeValue('value'), equals('typed'));
    });

    test('toDOMElement of a generated element returns its DOMElement', () {
      final div = $div(
        id: 'mapped',
        content: [$span(id: 'child')],
      );
      final (:element, treeMap: _) = _generate(div);
      expect(html.toDOMElement(element), same(div));
      // A fresh JS wrapper of a generated node (distinct with dart2wasm):
      expect(html.toDOMElement(element.firstChild), same(div.content!.first));
    });
  });

  group('element creation by tag', () {
    test('createElement for every known tag', () {
      const tags = [
        'a',
        'article',
        'aside',
        'audio',
        'br',
        'canvas',
        'div',
        'footer',
        'header',
        'hr',
        'iframe',
        'img',
        'li',
        'nav',
        'ol',
        'option',
        'p',
        'pre',
        'section',
        'select',
        'span',
        'svg',
        'table',
        'td',
        'textarea',
        'th',
        'tr',
        'ul',
        'video',
        'input',
        'main',
      ];
      for (final tag in tags) {
        final e = createElement(tag);
        expect(e, isNotNull, reason: tag);
        expect(e!.tagName.toLowerCase(), equals(tag), reason: tag);
      }

      expect(createElement(' DIV ')!.tagName, equals('DIV'));
      expect(createInputElement('Email').type, equals('email'));
      expect(createInputElement().type, equals('text'));

      expect(isTagSupported('main'), isTrue);
      expect(isTagSupported('not-a-standard'), isTrue, reason: 'custom tag');
      expect(isTagSupported('unknowntag'), isFalse);
      expect(isTagSupported(null), isFalse);
      expect(createElement('unknowntag'), isNull);
    });

    test('generating an unknown tag fails', () {
      expect(() => _generate($tag('unknowntag')), throwsStateError);
    });

    test('generator.createElement', () {
      expect((_gen.createElement('div') as Element).tagName, equals('DIV'));
      final svg = _gen.createElement('svg', $tag('svg')) as Element;
      expect(svg.namespaceURI, equals(_svgNS));
    });
  });

  group('runtime values of media and link elements', () {
    test('src / href based values', () {
      const url = 'about:blank';
      final elements = <String, DOMElement>{
        'canvas': $tag('canvas'),
        'video': $tag('video', attributes: {'src': url}),
        'audio': $tag('audio', attributes: {'src': url}),
        'iframe': $tag('iframe', attributes: {'src': url}),
        'script': $tag('script', attributes: {'src': url}),
        'source': $tag('source', attributes: {'src': url}),
        'track': $tag('track', attributes: {'src': url}),
        'embed': $tag('embed', attributes: {'src': url}),
        'link': $tag('link', attributes: {'href': url}),
        'base': $tag('base', attributes: {'href': url}),
        'area': $tag('area', attributes: {'href': url}),
        'input-image': $input(type: 'image'),
      };
      final holder = $div(content: elements.values.toList());
      _generate(holder);

      for (final MapEntry(:key, value: domElement) in elements.entries) {
        final rt = domElement.runtime;
        if (key == 'canvas') {
          expect(rt.value, isNull, reason: key);
          rt.value = url; // no `src`: not set, no error
          continue;
        }
        if (key != 'input-image') {
          expect(rt.value, equals(url), reason: key);
        }
        rt.value = '$url#$key';
        expect(rt.value, equals('$url#$key'), reason: key);
        rt.value = null;
      }
    });

    test('generic elements use text as value', () {
      final span = $span(content: 'txt');
      _generate(span);
      expect(span.runtime.value, equals('txt'));
      span.runtime.value = null;
      expect(span.runtime.text, isEmpty);
    });
  });

  group('DOMTreeMap operations', () {
    test('duplicate / empty / move / remove / merge / query', () {
      final a = $span(id: 'ta', content: 'a');
      final b = $span(id: 'tb', content: 'b');
      final c = $span(id: 'tc', content: 'c');
      final div = $div(content: [a, b, c]);
      final (:element, :treeMap) = _generate(div);

      expect(treeMap.moveUpByDOMNode(c), isTrue);
      expect(element.textContent, equals('acb'));
      expect(treeMap.moveDownByDOMNode(c), isTrue);
      expect(element.textContent, equals('abc'));
      expect(treeMap.moveUpByDOMNode(null), isFalse);
      expect(treeMap.moveDownByDOMNode(null), isFalse);

      final dup = treeMap.duplicateByDOMNode(b)!;
      expect(dup.domNode, isNot(same(b)));
      expect(element.textContent, equals('abbc'));
      expect(treeMap.duplicateByDOMNode(null), isNull);

      expect(treeMap.emptyByDOMNode(dup.domNode), isTrue);
      expect(element.textContent, equals('abc'));
      expect(treeMap.emptyByDOMNode(null), isFalse);

      expect(treeMap.queryElement('#tb'), same(b));
      // Returns the matched element's content HTML:
      expect(treeMap.queryElementAsHTML('#tb'), equals('b'));

      final removed = treeMap.removeByDOMNode(c)!;
      expect(removed.domNode, same(c));
      expect(element.textContent, isNot(contains('c')));
      expect(treeMap.removeByDOMNode(null), isNull);
    });

    test('mergeNearNodes / mergeNearStringNodes', () {
      final x = $span(content: 'x');
      final y = $span(content: 'y');
      final z = $span(content: 'z');
      final div = $div(content: [x, y, z]);
      final (:element, :treeMap) = _generate(div);

      final merged = treeMap.mergeNearNodes(x, y);
      expect(merged, isNotNull);
      expect(merged!.domNode, same(x));
      expect(element.childNodes.length, equals(2));
      expect(element.textContent, equals('xyz'));

      // Elements aren't "string" nodes:
      expect(treeMap.mergeNearStringNodes(z, x), isNull);

      final t1 = TextNode('p');
      final t2 = TextNode('q');
      final p = $p(content: [t1, t2]);
      final (element: pElement, treeMap: pTreeMap) = _generate(p);
      expect(pElement.childNodes.length, equals(2));
      final merged2 = pTreeMap.mergeNearStringNodes(t2, t1);
      expect(merged2?.domNode, same(t1));
      expect(pElement.childNodes.length, equals(1));
      expect(pElement.textContent, equals('pq'));
    });

    test('generic (dummy) treeMap does not map', () {
      final dummy = _gen.createGenericDOMTreeMap();
      final div = $div();
      final node = HTMLDivElement();
      dummy.map(div, node);
      expect(dummy.isMappedDOMNode(div), isFalse);
      expect(dummy.isMappedElement(node), isFalse);
      expect(dummy.matchesMapping(div, node), isFalse);
      expect(dummy.unmap(div, node), isFalse);
      expect(dummy.getMappedDOMNode(node), isNull);
      expect(dummy.getMappedElement(div), isNull);
      expect(dummy.getRuntimeNode(div), isNull);
      expect(dummy.asMappedDOMNode(div), isNull);
      expect(dummy.asMappedElement(node), isNull);
      expect(dummy.duplicateByDOMNode(div), isNull);
      expect(dummy.duplicateByElement(node), isNull);
      expect(dummy.emptyByDOMNode(div), isFalse);
      expect(dummy.emptyByElement(node), isFalse);
      expect(dummy.removeByDOMNode(div), isNull);
      expect(dummy.removeByElement(node), isNull);
      expect(dummy.moveUpByDOMNode(div), isFalse);
      expect(dummy.moveUpByElement(node), isFalse);
      expect(dummy.moveDownByDOMNode(div), isFalse);
      expect(dummy.moveDownByElement(node), isFalse);
      expect(dummy.mergeNearNodes(div, div), isNull);
      expect(dummy.mergeNearStringNodes(div, div), isNull);
      expect(dummy.queryElement('#x'), isNull);
      expect(dummy.queryElementAsHTML('#x'), isNull);
      expect(dummy.elementsWithSubscriptions(), isEmpty);
      expect(dummy.getSubscriptions(node), isEmpty);
      expect(dummy.cancelSubscriptions(node), isEmpty);
      expect(dummy.domElementsWithEventListener(), isEmpty);
      expect(dummy.disposeManagedDSXs(), equals(0));
      dummy.cancelAllSubscriptions();
      dummy.closeDOMElementsEventHandlers();
      dummy.purge();
      dummy.dispose();
      dummy.setRoot(div, node);
      dummy.manageDOMElementDSXs(div);
      expect(dummy.toString(), startsWith('DOMTreeMapDummy'));
    });
  });

  group('DOMNodeRuntime (dummy / siblings)', () {
    test('runtime of a non-generated node is a dummy', () {
      final div = $div(content: 'x');
      final rt = div.runtime;
      expect(rt.exists, isFalse);
      expect(rt.tagName, isNull);
      expect(rt.classes, isEmpty);
      rt.addClass('a');
      expect(rt.removeClass('a'), isFalse);
      rt.clearClasses();
      expect(rt.text, isEmpty);
      rt.text = 'x';
      expect(rt.value, isEmpty);
      rt.value = 'x';
      expect(rt.getAttribute('id'), isNull);
      rt.setAttribute('id', 'x');
      rt.removeAttribute('id');
      expect(rt.children, isEmpty);
      expect(rt.nodesLength, equals(0));
      expect(rt.getNodeAt(0), isNull);
      rt.clear();
      expect(rt.indexInParent, equals(-1));
      expect(rt.removeAt(0), isNull);
      expect(rt.copy(), isNull);
      expect(rt.isStringElement, isFalse);
      expect(rt.hasParent, isFalse);
    });

    test('mergeNode with the previous node', () {
      final m1 = $span(content: '1');
      final m2 = $span(content: '2');
      final holder = $div(content: [m1, m2]);
      final (:element, treeMap: _) = _generate(holder);
      final m2Rt = m2.runtime as DOMNodeRuntime<Node>;
      expect(m2Rt.mergeNode(m1.getRuntimeNode<Node>()), isTrue);
      expect(element.textContent, equals('12'));
      expect(element.childNodes.length, equals(1));
    });

    test('siblings of nodes in different parents', () {
      final a = $span(content: 'a');
      final b = $span(content: 'b');
      final holder = $div(
        content: [
          $div(content: [a]),
          $div(content: [b]),
        ],
      );
      _generate(holder);
      final aRt = a.runtime as DOMNodeRuntime<Node>;
      expect(aRt.isInSameParent(b.getRuntimeNode<Node>()!), isFalse);
      expect(aRt.getSiblingRuntime(b.getRuntimeNode<Node>()), isNull);
      expect(aRt.isNextNode(b.getRuntimeNode<Node>()), isFalse);
      expect(aRt.isPreviousNode(null), isFalse);
      expect(aRt.mergeNode(b.getRuntimeNode<Node>()), isFalse);
    });
  });
}
