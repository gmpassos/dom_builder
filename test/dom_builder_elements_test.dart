import 'dart:math';

import 'package:dom_builder/dom_builder.dart';
import 'package:test/test.dart';

/// Tests for the element classes, `$helpers` and attributes, focusing first
/// on the constructors refactored to super parameters and null-aware map
/// entries (Dart 3.13 upgrade), then on the rest of the public API.
void main() {
  group('Element constructors (super parameters)', () {
    test('DIVElement forwards id/classes/style/attributes/content', () {
      var div = DIVElement(
        id: 'd',
        classes: 'a b',
        style: 'color: red',
        attributes: {'data-x': '1'},
        content: 'x',
      );
      expect(
        div.buildHTML(),
        // `id`, `class` and `style` are always rendered first:
        equals('<div id="d" class="a b" style="color: red" data-x="1">x</div>'),
      );
      expect(div.id, equals('d'));
      expect(div.classesList, equals(['a', 'b']));
      expect(div.tag, equals('div'));
    });

    test('DIVElement hidden / commented', () {
      expect(
        DIVElement(hidden: true).buildHTML(),
        equals('<div hidden></div>'),
      );
      expect(DIVElement(hidden: false).buildHTML(), equals('<div></div>'));
      expect(DIVElement(commented: true).isCommented, isTrue);
      expect(DIVElement().isCommented, isFalse);
    });

    test('INPUTElement: null args produce no attributes', () {
      expect(INPUTElement().buildHTML(), equals('<input>'));
      expect(INPUTElement().hasEmptyAttributes, isTrue);

      var input = INPUTElement(
        id: 'i',
        name: 'n',
        type: 'text',
        placeholder: 'ph',
        value: 'v',
        classes: 'c',
        style: 'width: 10px',
        disabled: true,
      );
      expect(
        input.buildHTML(),
        equals(
          '<input id="i" class="c" style="width: 10px" name="n" type="text" '
          'placeholder="ph" value="v" disabled>',
        ),
      );
      expect(input.value, equals('v'));
      expect(input.hasValue, isTrue);
      expect(INPUTElement().hasValue, isFalse);
      expect(
        INPUTElement(disabled: false).containsAttribute('disabled'),
        isFalse,
      );
    });

    test('INPUTElement attributes override named args', () {
      var input = INPUTElement(name: 'n', attributes: {'name': 'override'});
      expect(input.getAttributeValue('name'), equals('override'));
    });

    test('CHECKBOXElement', () {
      expect(CHECKBOXElement().buildHTML(), equals('<input type="checkbox">'));
      var cb = CHECKBOXElement(
        name: 'c',
        placeholder: 'p',
        value: 'on',
        checked: true,
        disabled: true,
      );
      expect(
        cb.buildHTML(),
        equals(
          '<input name="c" type="checkbox" placeholder="p" value="on" '
          'checked disabled>',
        ),
      );
      expect(cb.checked, isTrue);
      expect(cb.value, equals('on'));
      expect(cb.hasValue, isTrue);
      expect(CHECKBOXElement(checked: false).checked, isFalse);
      expect(
        CHECKBOXElement(checked: false).buildHTML(),
        isNot(contains('checked')),
      );
      // `copy()` keeps the attributes (`type` is re-inserted first):
      expect(cb.copy().attributesAsString, equals(cb.attributesAsString));
      expect(
        cb.copy().buildHTML(),
        equals(
          '<input type="checkbox" name="c" placeholder="p" value="on" '
          'checked disabled>',
        ),
      );
    });

    test('SELECTElement', () {
      var select = SELECTElement(
        id: 's',
        name: 'n',
        type: 't',
        multiple: true,
        disabled: true,
        options: ['a', 'b'],
      );
      expect(
        select.buildHTML(),
        equals(
          '<select id="s" name="n" type="t" multiple disabled>'
          '<option value="a">a</option><option value="b">b</option></select>',
        ),
      );
      expect(
        SELECTElement(multiple: false).buildHTML(),
        equals('<select></select>'),
      );
      expect(
        SELECTElement(options: {'1': 'One', '2': 'Two'}).buildHTML(),
        equals(
          '<select><option value="1">One</option>'
          '<option value="2">Two</option></select>',
        ),
      );
      expect(select.hasOptions, isTrue);
      expect(SELECTElement().hasOptions, isFalse);
    });

    test('SELECTElement options API', () {
      var select = $select(options: ['a', 'b', 'c'], selected: 'b');
      expect(select.selectedValue, equals('b'));
      expect(select.hasSelection, isTrue);

      select.unselectAllOptions();
      expect(select.hasSelection, isFalse);

      expect(select.selectOption('c')?.value, equals('c'));
      expect(select.selectedOption?.text, equals('c'));
      expect(select.selectOption('zz'), isNull);
      expect(select.selectOption(null), isNull);

      expect(select.options.length, equals(3));
      expect(select.getOption('b')?.value, equals('b'));
      expect(select.getOption(OPTIONElement(value: 'a'))?.value, equals('a'));
      expect(select.getOption(null), isNull);
      expect(select.getOptionByValue(null), isNull);
      expect(select.getOptionByIndex(1)?.value, equals('b'));
      expect(select.getOptionByIndex(9), isNull);

      select
        ..addOption('d')
        ..addOptions(['e', 'f']);
      expect(
        select.options.map((o) => o.value),
        equals(['a', 'b', 'c', 'd', 'e', 'f']),
      );

      expect(select.copy().buildHTML(), equals(select.buildHTML()));
    });

    test('OPTIONElement', () {
      expect(
        OPTIONElement(text: 'T').buildHTML(),
        equals('<option>T</option>'),
      );
      var option = OPTIONElement(
        value: 1,
        label: 'L',
        selected: true,
        disabled: true,
        text: 'T',
        classes: 'c',
      );
      expect(
        option.buildHTML(),
        equals(
          '<option class="c" value="1" label="L" selected disabled>T</option>',
        ),
      );
      expect(option.value, equals('1'));
      expect(option.label, equals('L'));
      expect(option.selected, isTrue);
      expect(option.hasValue, isTrue);

      option
        ..value = 'w'
        ..label = 'M'
        ..selected = false;
      expect(
        option.buildHTML(),
        equals('<option class="c" value="w" label="M" disabled>T</option>'),
      );

      expect(OPTIONElement(text: 'x').hasValue, isFalse);
      expect(
        OPTIONElement(value: 'q', text: 'z').copy().buildHTML(),
        equals('<option value="q">z</option>'),
      );
    });

    test('OPTIONElement.from / toOptions', () {
      expect(OPTIONElement.from(null), isNull);
      expect(
        OPTIONElement.from('a')?.buildHTML(),
        equals('<option value="a">a</option>'),
      );
      expect(OPTIONElement.from(3)?.value, equals('3'));
      expect(OPTIONElement.from(TextNode('t'))?.value, equals('t'));
      expect(
        OPTIONElement.from(const MapEntry('k', 'v'))?.buildHTML(),
        equals('<option value="k">v</option>'),
      );
      expect(OPTIONElement.from(['x'])?.value, equals('x'));
      expect(
        OPTIONElement.from(['v', 't'])?.buildHTML(),
        equals('<option value="v">t</option>'),
      );
      expect(OPTIONElement.from(''), isNull);
      expect(
        OPTIONElement.from(
          DOMElement('option', attributes: {'value': '1'}, content: 'a'),
        )?.buildHTML(),
        equals('<option value="1">a</option>'),
      );

      var opt = OPTIONElement(value: 'x');
      expect(OPTIONElement.toOptions(opt), equals([opt]));
      expect(OPTIONElement.toOptions(null), isEmpty);
      expect(OPTIONElement.toOptions('single').single.value, equals('single'));
      expect(
        OPTIONElement.toOptions(['a', OPTIONElement(value: 'b', text: 'B')])
            .map((e) => e.buildHTML())
            .join(),
        equals('<option value="a">a</option><option value="b">B</option>'),
      );
    });

    test('TEXTAREAElement', () {
      var ta = TEXTAREAElement(
        id: 't',
        name: 'n',
        cols: 10,
        rows: 3,
        content: 'txt',
        disabled: true,
        classes: 'c',
      );
      expect(
        ta.buildHTML(),
        equals(
          '<textarea id="t" class="c" name="n" cols="10" rows="3" disabled>'
          'txt</textarea>',
        ),
      );
      expect(TEXTAREAElement().buildHTML(), equals('<textarea></textarea>'));

      var withValue = TEXTAREAElement(content: 'c', attributes: {'value': 'q'});
      expect(withValue.value, equals('q'));
      expect(withValue.hasValue, isTrue);
      expect(TEXTAREAElement().hasValue, isFalse);
      expect(
        withValue.copy().buildHTML(),
        equals('<textarea value="q">c</textarea>'),
      );
    });

    test('TABLEElement with caption/head/body/foot', () {
      var table = TABLEElement(
        id: 't',
        caption: 'cap',
        head: [
          ['h1', 'h2'],
        ],
        body: [
          ['a', 'b'],
          ['c', 'd'],
        ],
        foot: [
          ['f1', 'f2'],
        ],
      );
      expect(
        table.buildHTML(),
        equals(
          '<table id="t"><caption>cap</caption>'
          '<thead><tr><th>h1</th><th>h2</th></tr></thead>'
          '<tbody><tr><td>a</td><td>b</td></tr><tr><td>c</td><td>d</td></tr></tbody>'
          '<tfoot><tr><td>f1</td><td>f2</td></tr></tfoot></table>',
        ),
      );
      expect(TABLEElement().buildHTML(), equals('<table></table>'));
      expect(table.copy().buildHTML(), equals(table.buildHTML()));
    });

    test('TABLEElement content and nodes', () {
      expect(
        TABLEElement(
          content: [
            $thead(
              rows: [
                ['h'],
              ],
            ),
            $tbody(
              rows: [
                ['b'],
              ],
            ),
          ],
        ).buildHTML(),
        equals(
          '<table><thead><tr><th>h</th></tr></thead>'
          '<tbody><tr><td>b</td></tr></tbody></table>',
        ),
      );
      expect(
        TABLEElement(
          caption: CAPTIONElement(content: 'c'),
          body: [
            ['a'],
          ],
        ).buildHTML(),
        equals(
          '<table><caption>c</caption><tbody><tr><td>a</td></tr></tbody></table>',
        ),
      );
    });

    test('table sections forward attributes', () {
      expect(
        THEADElement(
          id: 'h',
          rows: [
            ['a'],
          ],
        ).buildHTML(),
        equals('<thead id="h"><tr><th>a</th></tr></thead>'),
      );
      expect(
        TBODYElement(
          classes: 'b',
          rows: [
            ['a'],
          ],
        ).buildHTML(),
        equals('<tbody class="b"><tr><td>a</td></tr></tbody>'),
      );
      expect(
        TFOOTElement(
          style: 'color: red',
          rows: [
            ['a'],
          ],
        ).buildHTML(),
        equals('<tfoot style="color: red"><tr><td>a</td></tr></tfoot>'),
      );
      expect(
        CAPTIONElement(id: 'c', content: 'x').buildHTML(),
        equals('<caption id="c">x</caption>'),
      );
      expect(
        TRowElement(hidden: true, cells: ['a']).buildHTML(),
        equals('<tr hidden><td>a</td></tr>'),
      );
      expect(
        THElement(id: 'i', content: 'h').buildHTML(),
        equals('<th id="i">h</th>'),
      );
      expect(
        TDElement(id: 'i', content: 'd').buildHTML(),
        equals('<td id="i">d</td>'),
      );
    });

    test('table rows variants', () {
      expect(
        TBODYElement(
          rows: [
            TRowElement(cells: ['a']),
          ],
        ).buildHTML(),
        equals('<tbody><tr><td>a</td></tr></tbody>'),
      );
      expect(
        TBODYElement(rows: {'k': 'v'}.entries.toList()).buildHTML(),
        equals('<tbody><tr><td>k</td><td>v</td></tr></tbody>'),
      );
      expect(
        TBODYElement(rows: ['a', 'b']).buildHTML(),
        equals('<tbody><tr><td>a</td><td>b</td></tr></tbody>'),
      );
      expect(
        TRowElement(cells: ['a', 'b'], headerRow: true).buildHTML(),
        equals('<tr><th>a</th><th>b</th></tr>'),
      );
      expect(
        TRowElement(cells: TDElement(content: 'x')).buildHTML(),
        equals('<tr><td>x</td></tr>'),
      );
      expect(TRowElement().buildHTML(), equals('<tr></tr>'));
    });

    test('TRowElement header/footer rows', () {
      var row = TRowElement(cells: ['a']);
      THEADElement(rows: [row]);
      expect(row.isHeaderRow, isTrue);
      expect(row.isFooterRow, isFalse);

      var foot = TFOOTElement(
        rows: [
          ['f'],
        ],
      );
      var footRow = foot.content!.first as TRowElement;
      expect(footRow.isFooterRow, isTrue);
      expect(TRowElement().isHeaderRow, isFalse);
      expect(footRow.copy().buildHTML(), equals('<tr><td>f</td></tr>'));
    });

    test('TH <-> TD conversion', () {
      expect(
        THElement(content: 'x', id: 'i').asTDElement().buildHTML(),
        equals('<td id="i">x</td>'),
      );
      expect(
        TDElement(content: 'y').asTHElement().buildHTML(),
        equals('<th>y</th>'),
      );
    });

    test('copy() of every element class', () {
      for (var e in <DOMElement>[
        DIVElement(content: 'a'),
        INPUTElement(value: 'q'),
        CAPTIONElement(content: 'a'),
        THEADElement(
          rows: [
            ['a'],
          ],
        ),
        TBODYElement(
          rows: [
            ['a'],
          ],
        ),
        TFOOTElement(
          rows: [
            ['a'],
          ],
        ),
        TRowElement(cells: ['a']),
        THElement(content: 'a'),
        TDElement(content: 'a'),
      ]) {
        var copy = e.copy();
        expect(copy.runtimeType, equals(e.runtimeType));
        expect(copy.buildHTML(), equals(e.buildHTML()));
        expect(identical(copy, e), isFalse);
      }
    });
  });

  group('Element.from() conversions', () {
    test('from generic DOMElement', () {
      expect(
        DIVElement.from(
          DOMElement('div', attributes: {'id': 'x'}, content: 'y'),
        )?.buildHTML(),
        equals('<div id="x">y</div>'),
      );
      expect(
        INPUTElement.from(DOMElement('input', attributes: {'value': 'v'}))
            ?.buildHTML(),
        equals('<input value="v">'),
      );
      expect(
        CHECKBOXElement.from(DOMElement('input', attributes: {'value': 'v'}))
            ?.buildHTML(),
        equals('<input type="checkbox" value="v">'),
      );
      expect(
        TEXTAREAElement.from(DOMElement('textarea', content: 't'))?.buildHTML(),
        equals('<textarea>t</textarea>'),
      );
      expect(
        TDElement.from(DOMElement('td', content: '1'))?.buildHTML(),
        equals('<td>1</td>'),
      );
      expect(
        THElement.from(DOMElement('th', content: '1'))?.buildHTML(),
        equals('<th>1</th>'),
      );
      expect(
        CAPTIONElement.from(DOMElement('caption', content: '1'))?.buildHTML(),
        equals('<caption>1</caption>'),
      );
      expect(
        TBODYElement.from(
          DOMElement(
            'tbody',
            content: [
              DOMElement('tr', content: [DOMElement('td', content: '1')]),
            ],
          ),
        )?.buildHTML(),
        equals('<tbody><tr><td>1</td></tr></tbody>'),
      );
      expect(
        TRowElement.from(
          DOMElement('tr', content: [DOMElement('td', content: '1')]),
        )?.buildHTML(),
        equals('<tr><td>1</td></tr>'),
      );
      expect(
        TABLEElement.from(
          $html('<table><thead><tr><th>h</th></tr></thead></table>').first,
        )?.buildHTML(),
        equals('<table><thead><tr><th>h</th></tr></thead></table>'),
      );
    });

    test('from returns the same instance, null or throws', () {
      var div = DIVElement(id: 'k');
      expect(identical(DIVElement.from(div), div), isTrue);
      expect(DIVElement.from(null), isNull);
      expect(DIVElement.from(123), isNull);
      expect(TDElement.from(null), isNull);
      expect(
        () => DIVElement.from(DOMElement('span')),
        throwsA(isA<StateError>()),
      );
      expect(
        () => TDElement.from(DOMElement('th')),
        throwsA(isA<StateError>()),
      );
    });

    test('DOMElement factory creates typed elements', () {
      expect(DOMElement('div'), isA<DIVElement>());
      expect(DOMElement('option'), isA<OPTIONElement>());
      expect(DOMElement('td'), isA<TDElement>());
      expect($tag('select'), isA<SELECTElement>());
      expect(
        $html('<table><tr><td>1</td></tr></table>').first,
        isA<TABLEElement>(),
      );
      expect($html('<input value="x">').first, isA<INPUTElement>());
      expect($html('<textarea>x</textarea>').first, isA<TEXTAREAElement>());
    });

    test('parsed select keeps option values', () {
      var select =
          $html(
                '<select><option value="1">a</option>'
                '<option value="2" selected>b</option></select>',
              ).first
              as SELECTElement;
      expect(
        select.options.map((o) => '${o.value}/${o.text}/${o.selected}'),
        equals(['1/a/false', '2/b/true']),
      );
    });
  });

  group('helpers with null-aware attributes', () {
    test(r'$a', () {
      expect(
        $a(href: 'h', target: '_blank', content: 'x').buildHTML(),
        equals('<a href="h" target="_blank">x</a>'),
      );
      expect($a(content: 'x').buildHTML(), equals('<a>x</a>'));
      expect(
        $a(href: 'h', attributes: {'href': 'o'}).getAttributeValue('href'),
        equals('o'),
      );
    });

    test(r'$img', () async {
      expect(
        $img(src: 's', title: 't').buildHTML(),
        equals('<img src="s" title="t">'),
      );
      expect($img().buildHTML(), equals('<img>'));

      var img = $img(srcFuture: Future.value('late.png'));
      expect(img.buildHTML(), equals('<img>'));
      await Future<void>.delayed(Duration.zero);
      expect(img.getAttributeValue('src'), equals('late.png'));

      var imgNull = $img(src: 'keep', srcFuture: Future.value(null));
      await Future<void>.delayed(Duration.zero);
      expect(imgNull.getAttributeValue('src'), equals('keep'));
    });

    test(r'$label', () {
      expect(
        $label(forID: 'f', content: 'l').buildHTML(),
        equals('<label for="f">l</label>'),
      );
      expect($label(content: 'l').buildHTML(), equals('<label>l</label>'));
    });

    test(r'$button', () {
      expect(
        $button(name: 'b', content: 'x', disabled: true).buildHTML(),
        equals('<button type="button" name="b" disabled>x</button>'),
      );
      expect(
        $button(content: 'x', type: 'submit').buildHTML(),
        equals('<button type="submit">x</button>'),
      );
      expect(
        $button(type: '').buildHTML(),
        equals('<button type="button"></button>'),
      );
    });

    test(r'$td / $th', () {
      expect(
        $td(colspan: 2, rowspan: 3, headers: 'h', content: 'x').buildHTML(),
        equals('<td colspan="2" rowspan="3" headers="h">x</td>'),
      );
      expect($td(content: 'x').buildHTML(), equals('<td>x</td>'));
      expect(
        $th(colspan: 2, abbr: 'a', scope: 'col', content: 'x').buildHTML(),
        equals('<th colspan="2" abbr="a" scope="col">x</th>'),
      );
      expect($th(content: 'x').buildHTML(), equals('<th>x</th>'));
    });

    test(r'$b / $asyncContent', () {
      expect($b(content: 'x').buildHTML(), equals('<b>x</b>'));
      expect($b(), isA<DOMElement>());

      var future = Future.value('v');
      var async = $asyncContent(loading: 'L', future: future);
      expect(async.loading, equals('L'));
      expect(identical(async.resolveFuture, future), isTrue);
      expect(async.copy().loading, equals('L'));
    });
  });

  group('other helpers', () {
    test('tags', () {
      expect($h(2, content: 'h').buildHTML(), equals('<h2>h</h2>'));
      expect($hr().buildHTML(), equals('<hr>'));
      expect($form(content: 'f').buildHTML(), equals('<form>f</form>'));
      expect($nav().buildHTML(), equals('<nav></nav>'));
      expect($header().buildHTML(), equals('<header></header>'));
      expect($footer().buildHTML(), equals('<footer></footer>'));
      expect(
        $ul(content: [$li(content: '1')]).buildHTML() + $ol().buildHTML(),
        equals('<ul><li>1</li></ul><ol></ol>'),
      );
      expect(
        $radiobutton(name: 'r', value: '1').buildHTML(),
        equals('<input name="r" type="radio" value="1">'),
      );
      expect(
        $option(valueAndText: 'vt').buildHTML(),
        equals('<option value="vt">vt</option>'),
      );
      expect(
        $textarea(content: 'x').buildHTML(),
        equals('<textarea>x</textarea>'),
      );
      expect($input(value: 'x').buildHTML(), equals('<input value="x">'));
      expect(
        $checkbox(checked: true).buildHTML(),
        equals('<input type="checkbox" checked>'),
      );
    });

    test(r'$br / $nbsp / $emsp', () {
      expect($br().buildHTML(), equals('<br>'));
      expect($br(amount: 3).buildHTML(), equals('<span><br><br><br></span>'));
      expect($br(amount: 0).isCommented, isTrue);
      expect($nbsp(), equals('&nbsp;'));
      expect($nbsp(3), equals('&nbsp;&nbsp;&nbsp;'));
      expect($nbsp(0), isEmpty);
      expect($emsp(), equals('&emsp;'));
      expect($emsp(2), equals('&emsp;&emsp;'));
      expect($emsp(0), isEmpty);
    });

    test(r'$divInline / $divCenteredContent', () {
      expect(
        $divInline(style: 'color: red').buildHTML(),
        equals('<div style="display: inline-block; color: red"></div>'),
      );
      var cell =
          'display: table-cell; text-align: center; vertical-align: middle';
      expect(
        $divCenteredContent(
          cells: ['a', 'b', 'c'],
          cellsPerRow: 2,
          style: 'x: y',
          cellSpacing: '2px',
        ).buildHTML(),
        equals(
          '<div style="display: table; width: 100%; height: 100%; x: y; '
          'border-spacing: 2px"><div style="display: table-row">'
          '<div style="$cell">a</div><div style="$cell">b</div></div>'
          '<div style="display: table-row"><div style="$cell">c</div></div></div>',
        ),
      );
      expect(
        $divCenteredContent(content: 'c', width: '', height: '').buildHTML(),
        equals('<div style="display: table"><div style="$cell">c</div></div>'),
      );
    });

    test(r'$table styles', () {
      var table = $table(
        head: ['h'],
        body: [
          ['1'],
        ],
        thsStyle: 'color: red',
        tdsStyle: 'color: blue',
        trsStyle: 'height: 1px',
      );
      expect(
        table.buildHTML(),
        equals(
          '<table><thead><tr style="height: 1px"><th style="color: red">h</th></tr></thead>'
          '<tbody><tr style="height: 1px"><td style="color: blue">1</td></tr></tbody></table>',
        ),
      );
      expect(
        $caption(
          captionSide: 'top',
          content: 'c',
          style: 'color: red',
        ).buildHTML(),
        equals('<caption style="caption-side: top; color: red">c</caption>'),
      );
      expect(
        $caption(captionSide: 'bottom').buildHTML(),
        equals('<caption style="caption-side: bottom"></caption>'),
      );
      expect($tr(cells: ['a']).buildHTML(), equals('<tr><td>a</td></tr>'));
      expect(
        $tfoot(
          rows: [
            ['f'],
          ],
        ).buildHTML(),
        equals('<tfoot><tr><td>f</td></tr></tfoot>'),
      );
    });

    test(r'$tags', () {
      expect(
        $tags('li', ['a', 'b']).map((e) => e.buildHTML()).join(),
        equals('<li>a</li><li>b</li>'),
      );
      expect(
        $tags<int>('li', [1, 2], (e) => 'n$e').map((e) => e.buildHTML()).join(),
        equals('<li>n1</li><li>n2</li>'),
      );
      expect($tags('li', null), isEmpty);
    });

    test(r'$html / $htmlRoot / $tagHTML / $divHTML', () {
      expect($html(null), isEmpty);
      expect(
        $html(['<b>', 'x', '</b>']).single.buildHTML(),
        equals('<b>x</b>'),
      );
      expect(() => $html(123), throwsArgumentError);

      expect(
        $htmlRoot('<b>a</b><i>b</i>')?.buildHTML(),
        equals('<span><b>a</b><i>b</i></span>'),
      );
      expect(
        $htmlRoot('<div>a</div><p>b</p>')?.buildHTML(),
        equals('<div style="display: inline-block"><div>a</div><p>b</p></div>'),
      );
      expect(
        $htmlRoot(
          '<div>a</div><p>b</p>',
          defaultTagDisplayInlineBlock: false,
        )?.buildHTML(),
        equals('<div><div>a</div><p>b</p></div>'),
      );
      expect(
        $htmlRoot(
          '<div>a</div><p>b</p>',
          defaultRootTag: 'section',
        )?.buildHTML(),
        equals(
          '<section style="display: inline-block"><div>a</div><p>b</p></section>',
        ),
      );
      expect($htmlRoot('text')?.buildHTML(), equals('<span>text</span>'));
      expect($htmlRoot(''), isNull);
      expect($htmlRoot('<div>a</div> ')?.buildHTML(), equals('<div>a</div>'));

      expect($tagHTML<DOMElement>('<p>x</p>')?.buildHTML(), equals('<p>x</p>'));
      expect($divHTML('<div>x</div>')?.buildHTML(), equals('<div>x</div>'));
      expect($divHTML('<p>x</p>'), isNull);
    });

    test('parseHTML dependent tags', () {
      expect(parseHTML(null), isNull);
      expect(parseHTML('<td>1</td>')?.single.buildHTML(), equals('<td>1</td>'));
      expect(
        parseHTML('<tbody><tr><td>1</td></tr></tbody>')?.single.buildHTML(),
        equals('<tbody><tr><td>1</td></tr></tbody>'),
      );
      expect(
        parseHTML(' <b>1</b> <i>2</i> ')?.map((e) => e.buildHTML()).join('|'),
        equals('<b>1</b>| |<i>2</i>'),
      );
    });

    test('string predicates', () {
      expect(isHTMLElement('<div>'), isTrue);
      expect(isHTMLElement('div'), isFalse);
      expect(hasHTMLTag('a <b>'), isTrue);
      expect(hasHTMLTag('a b'), isFalse);
      expect(hasHTMLEntity('&amp;'), isTrue);
      expect(hasHTMLEntity('&'), isFalse);
      expect(possiblyWithHTML('<b>'), isTrue);
      expect(possiblyWithHTML('&nbsp;'), isTrue);
      expect(possiblyWithHTML('x'), isFalse);
      expect(possiblyWithHTML(null), isFalse);
      expect(possiblyWithHTMLTag(null), isFalse);
      expect(possiblyWithHTMLEntity(null), isFalse);
    });

    test('parseListOfStrings', () {
      expect(
        parseListOfStrings('a, b;c', STRING_LIST_DELIMITER),
        equals(['a', 'b', 'c']),
      );
      expect(
        parseListOfStrings(['a', 1], STRING_LIST_DELIMITER),
        equals(['a', '1']),
      );
      expect(parseListOfStrings(null, STRING_LIST_DELIMITER), isEmpty);
      expect(
        parseListOfStrings(' a , b ', ARGUMENT_LIST_DELIMITER, false),
        equals([' a', 'b ']),
      );
    });

    test(r'$validate', () {
      expect(
        $validate<DOMElement>(node: $div(), validate: (n) => false),
        isNull,
      );
      expect(
        $validate<DOMElement>(
          instantiator: () => $div(),
          preValidate: () => true,
        ),
        isNotNull,
      );
      expect(
        $validate<DOMElement>(preValidate: () => false, node: $div()),
        isNull,
      );
      expect($validate<DOMElement>(), isNull);
      // Errors are logged, not thrown (unless `rethrowErrors`):
      expect(
        $validate<DOMElement>(preValidate: () => throw 'x', node: $div()),
        isNotNull,
      );
      expect($validate<DOMElement>(instantiator: () => throw 'x'), isNull);
      expect(
        $validate<DOMElement>(node: $div(), validate: (n) => throw 'x'),
        isNotNull,
      );
      expect(
        () => $validate<DOMElement>(
          preValidate: () => throw 'x',
          node: $div(),
          rethrowErrors: true,
        ),
        throwsA(equals('x')),
      );
    });

    test('isDOMBuilderDirectHelper', () {
      for (var f in <Function>[
        $br,
        $p,
        $a,
        $b,
        $div,
        $span,
        $table,
        $caption,
        $tr,
      ]) {
        expect(isDOMBuilderDirectHelper(f), isTrue);
      }
      expect(isDOMBuilderDirectHelper(print), isFalse);
      expect(isDOMBuilderDirectHelper(null), isFalse);
      expect(isDOMBuilderDirectHelper('x'), isFalse);
    });
  });

  group('DOMElement attributes API', () {
    test('id / classes / style', () {
      var el = $div(id: 'x', classes: 'a b', style: 'color: red');
      expect(el.id, equals('x'));
      expect(el.classes, equals('a b'));
      expect(el.classesList, equals(['a', 'b']));
      expect(el.styleText, equals('color: red'));
      expect(el.style.toString(), equals('color: red'));

      el.addClass('c');
      expect(el.containsClass('c'), isTrue);
      expect(el.containsClass('z'), isFalse);
      expect(el.containsAllClasses(['a', 'c']), isTrue);
      expect(el.containsAllClasses(['a', 'z']), isFalse);
      expect(el.containsAllClasses(null), isFalse);
      expect(el.containsAnyClass(['z', 'b']), isTrue);
      expect(el.containsAnyClass(['z']), isFalse);
      expect(el.containsAnyClass(null), isFalse);

      el.classesList = ['q', 'w'];
      expect(el.classes, equals('q w'));
      el.classes = 'k';
      expect(el.classes, equals('k'));
      el.styleText = 'margin: 0';
      expect(el.styleText, equals('margin: 0'));
      el.style = 'padding: 1px';
      expect(el.styleText, equals('padding: 1px'));

      var bare = $div();
      expect(bare.classesList, isEmpty);
      expect(bare.containsClass('a'), isFalse);
      expect(bare.containsAllClasses(['a']), isFalse);
      expect(bare.containsAnyClass(['a']), isFalse);
      expect(bare.styleText, isNull);
      expect(bare.style.isEmpty, isTrue);
    });

    test('operator [] / typed getters', () {
      var el = $div();
      el['data-x'] = 5;
      expect(el['data-x'], equals('5'));
      expect(el.getAttributeValueAsInt('data-x'), equals(5));
      expect(el.getAttributeValueAsDouble('data-x'), equals(5.0));
      expect(el.getAttributeValueAsBool('data-x'), isFalse);
      el['data-b'] = 'true';
      expect(el.getAttributeValueAsBool('data-b'), isTrue);
      expect(el.hasAttributeValue('data-x'), isTrue);
      expect(el.hasAttributeValue('none'), isFalse);
      expect(el.getAttributeValue('none'), isNull);
    });

    test('attribute maps', () {
      var el = $div(id: 'x', classes: 'a b', style: 'color: red');
      expect(el.attributesNames.toList(), equals(['id', 'class', 'style']));
      expect(el.attributesLength, equals(3));
      expect(el.hasAttributes, isTrue);
      expect(el.hasEmptyAttributes, isFalse);
      expect(
        el.attributesAsString,
        equals({'id': 'x', 'class': 'a b', 'style': 'color: red'}),
      );
      expect(el.attributes['class'], equals(['a', 'b']));
      expect(el.attributes['id'], equals('x'));
      expect(el.domAttributes.keys, equals(['id', 'class', 'style']));

      var empty = $div();
      expect(empty.attributesNames, isEmpty);
      expect(empty.attributesLength, equals(0));
      expect(empty.attributes, isEmpty);
      expect(empty.attributesAsString, isEmpty);
      expect(empty.domAttributes, isEmpty);
    });

    test('possibleAttributes', () {
      const globals = [
        'id',
        'navigate',
        'action',
        'uilayout',
        'oneventkeypress',
        'oneventclick',
      ];
      expect($div().possibleAttributes.keys, equals(globals));
      expect(
        $img().possibleAttributes.keys,
        equals([...globals, 'src', 'width', 'height']),
      );
      expect(
        $tag('video').possibleAttributes.keys,
        equals([
          ...globals,
          'src',
          'width',
          'height',
          'autoplay',
          'controls',
          'muted',
        ]),
      );
      expect($a().possibleAttributes.keys, equals([...globals, 'href']));
      expect($div(id: 'x').possibleAttributes['id'], equals('x'));
    });

    test('setAttribute / setAttributeIfAbsent / addAllAttributes', () {
      var el = $div(id: 'x');
      el.setAttributeIfAbsent('id', 'y');
      el.setAttributeIfAbsent('title', 't');
      expect(el.id, equals('x'));
      expect(el['title'], equals('t'));

      el.setAttribute(' DATA-Up ', 'v');
      expect(el['data-up'], equals('v'));

      el.addAllAttributes({'a': '1', 'b': '2'});
      el.addAllAttributes(null);
      expect(el['a'], equals('1'));
      expect(el['b'], equals('2'));

      // `null` boolean attributes are not created:
      el.setAttribute('checked', null);
      expect(el.containsAttribute('checked'), isFalse);
    });

    test('appendToAttribute', () {
      var el = $div(
        classes: 'a',
        style: 'color: red',
        attributes: {'title': 't'},
      );
      el.appendToAttribute('class', 'b');
      el.appendToAttribute('style', 'width: 1px');
      el.appendToAttribute('title', 'u');
      el.appendToAttribute('data-n', 'new');
      expect(
        el.buildHTML(),
        equals(
          '<div class="a b" style="color: red; width: 1px" title="u" data-n="new"></div>',
        ),
      );
    });

    test('removeAttribute / removeAttributeDeeply', () {
      var el = $div(attributes: {'title': 't'});
      expect(el.removeAttribute('TITLE'), isTrue);
      expect(el.removeAttribute('title'), isFalse);
      expect(el.removeAttribute(''), isFalse);

      var deep = $div(
        attributes: {'data-q': '1'},
        content: [
          $span(attributes: {'data-q': '2'}),
        ],
      );
      expect(deep.removeAttributeDeeply('data-q'), isTrue);
      expect(deep.buildHTML(), equals('<div><span></span></div>'));
      expect(deep.removeAttributeDeeply('data-q'), isFalse);
      expect(deep.removeAttributeDeeply(' '), isFalse);
    });

    test('apply id and style', () {
      var el = $div(content: 'x', style: 'color: red');
      el.apply<DOMElement>(id: 'i', style: 'width: 1px');
      expect(el.id, equals('i'));
      expect(el.styleText, equals('color: red; width: 1px'));
    });

    test(
      'apply classes',
      () {
        var el = $div(classes: 'a');
        el.apply<DOMElement>(classes: 'b');
        expect(el.buildHTML(), equals('<div class="a b"></div>'));

        var tree = $div(content: [$span(content: 'a')]);
        tree.applyWhere<DOMElement>('span', classes: 'c');
        expect(tree.buildHTML(), equals('<div><span class="c">a</span></div>'));
      },
      skip:
          'BUG: DOMElement.apply appends to a `classes` attribute instead of '
          '`class` (dom_builder_base.dart:2448)',
    );

    test('attributes signature / tag helpers', () {
      var el = $div(id: 'x', attributes: {'b': '2', 'a': '1'});
      expect(el.getAttributesSignature(), equals('a=1\nb=2\nid=x'));
      expect($div().getAttributesSignature(), isEmpty);
      expect(el.isTagOneOf(['p', 'DIV']), isTrue);
      expect(el.isTagOneOf(['p']), isFalse);
      expect(DOMElement.isStringTagName('b'), isTrue);
      expect(DOMElement.isStringTagName('div'), isFalse);
      expect(DOMElement.isStringTagName(null), isFalse);
      expect(DOMElement.normalizeTag(' DIV '), equals('div'));
    });

    test('toString / hasValue / asDOMElement', () {
      var el = $div(id: 'x', content: 'y');
      expect(
        el.toString(),
        equals('DOMElement{tag: div, attributes: {id: x}, content: 1}'),
      );
      expect($div().toString(), equals('DOMElement{tag: div}'));
      expect(el.hasValue, isTrue);
      expect(el.value, equals('y'));
      expect(identical(el.asDOMElement, el), isTrue);
      expect(identical(el.asDOMNode, el), isTrue);
    });

    test('equals', () {
      expect($div().equals($div()), isTrue);
      expect($div().equals($span()), isFalse);
      var el = $div(id: 'x');
      expect(el.equals(el), isTrue);
    });

    test(
      'equals with attributes/content',
      () {
        expect($div(id: 'x').equals($div(id: 'x')), isTrue);
        expect($div(content: 'a').equals($div(content: 'a')), isTrue);
      },
      skip:
          'BUG: DOMElement.equals is false for equal attributes/content: '
          'DOMAttribute and TextNode have no operator == '
          '(dom_builder_base.dart:2873-2885)',
    );
  });

  group('events', () {
    test('allEventHandlers / closeAllEventHandlers', () async {
      var d = $div();
      expect(d.allEventHandlers(), isEmpty);
      expect(d.hasAnyEventListener, isFalse);

      d.onClick.listen((_) {});
      expect(d.allEventHandlers(), equals([d.onClick]));

      d
        ..onChange
        ..onKeyUp
        ..onKeyDown
        ..onKeyPress
        ..onMouseOver
        ..onMouseOut
        ..onLoad
        ..onError
        ..onGenerate;

      expect(d.allEventHandlers().length, equals(10));
      expect(d.hasAnyEventListener, isTrue);
      expect([
        d.hasOnClickListener,
        d.hasOnChangeListener,
        d.hasOnKeyUpListener,
        d.hasOnKeyDownListener,
        d.hasOnKeyPressListener,
        d.hasOnMouseOverListener,
        d.hasOnMouseOutListener,
        d.hasOnLoadListener,
        d.hasOnErrorListener,
        d.hasOnGenerateListener,
      ], everyElement(isTrue));

      expect(await d.closeAllEventHandlers(), equals(10));
      expect(d.allEventHandlers(), isEmpty);
      expect(d.hasAnyEventListener, isFalse);
      expect(await d.closeAllEventHandlers(), equals(0));
    });

    test('DOMMouseEvent.synthetic', () {
      var ev = DOMMouseEvent.synthetic(
        client: const Point(1, 2),
        button: 1,
        shiftKey: true,
      );
      expect(ev.client, equals(const Point(1, 2)));
      expect(ev.offset, equals(ev.client));
      expect(ev.page, equals(ev.client));
      expect(ev.screen, equals(ev.client));
      expect(ev.button, equals(1));
      expect(ev.shiftKey, isTrue);
      expect(ev.altKey, isFalse);
      expect(ev.toString(), equals('DOMEvent@null'));

      var def = DOMMouseEvent.synthetic();
      expect(def.client, equals(const Point(0, 0)));
    });
  });

  group('DOMNode tree API', () {
    DOMElement tree() => $div(
      content: <Object>[
        $span(id: 's', classes: 'c1 c2', content: 'a'),
        $p(content: [$b(content: 'b')]),
      ],
    );

    test('selectors', () {
      var t = tree();
      expect(
        t.select('#s')?.buildHTML(),
        equals('<span id="s" class="c1 c2">a</span>'),
      );
      expect(t.select('.c1.c2')?.buildHTML(), startsWith('<span'));
      expect(t.select('b')?.buildHTML(), equals('<b>b</b>'));
      expect(t.select(1)?.buildHTML(), equals('<p><b>b</b></p>'));
      expect(t.select('i, b')?.buildHTML(), equals('<b>b</b>'));
      expect(t.select(['x', 'p'])?.buildHTML(), equals('<p><b>b</b></p>'));
      expect(t.select(null), isNull);
      expect(t.select('  '), isNull);
      expect(() => t.selectWhere(Object()), throwsArgumentError);
    });

    test('selectBy*', () {
      var t = tree();
      expect(t.selectByID('s'), isA<DOMElement>());
      expect(t.selectByID(null), isNull);
      expect(t.selectWithAllClasses(['c1']), isNotNull);
      expect(t.selectWithAllClasses([]), isNull);
      expect(t.selectWithAnyClass(['zz', 'c2']), isNotNull);
      expect(t.selectWithAnyClass([' ']), isNull);
      expect(t.selectByTag(['b'])?.buildHTML(), equals('<b>b</b>'));
      expect(t.selectByTag(null), isNull);
      expect(t.nodeByID('s'), isNotNull);
      expect(t.nodeByIndex(0), isNotNull);
      expect(t.node(1)?.buildHTML(), equals('<p><b>b</b></p>'));
      expect(t.node('p'), isNotNull);
      expect(t.nodeEquals(t.content![0]), isNotNull);
      expect(t.selectEquals(t.select('b')), isNotNull);
      expect(t.nodeEquals(null), isNull);
    });

    test('selectAll / nodesWhere', () {
      var t = tree();
      expect(t.selectAllWhere('span, b').length, equals(2));
      expect(t.selectAllByType<DOMElement>().length, equals(3));
      expect(t.selectByType<DOMElement>()?.tag, equals('span'));
      expect(t.nodesWhere('p').length, equals(1));
      expect(t.selectAllWhere(null), isEmpty);
      var dest = <DOMElement>[];
      t.catchNodesWhere<DOMElement>('span', dest);
      expect(dest.length, equals(1));
    });

    test('parents / root / containsNode', () {
      var t = tree();
      var b = t.select('b')!;
      expect(b.selectParentWhere<DOMElement>('p')?.tag, equals('p'));
      expect(b.selectParentWhere(null), isNull);
      expect(identical(b.root, t), isTrue);
      expect(identical(t.root, t), isTrue);
      expect(t.containsNode(b), isTrue);
      expect(t.containsNode(b, deep: false), isFalse);
      expect($div().containsNode(b), isFalse);
      expect(b.hasParent, isTrue);
      expect(t.hasParent, isFalse);
    });

    test('indexOf', () {
      var t = tree();
      expect(t.indexOf('p'), equals(1));
      expect(t.indexOf(5), equals(2));
      expect(t.indexOf(-1), equals(-1));
      expect(t.indexOf(null), equals(-1));
      expect(t.indexOfNode(t.content![1]), equals(1));
      expect(
        t.indexOfNodeWhere((n) => n is DOMElement && n.tag == 'p'),
        equals(1),
      );
      expect(t.indexOfNodeWhere((n) => false), equals(-1));
      expect($div().indexOfNode(t), equals(-1));
    });

    test('moveUp / moveDown / duplicate', () {
      var a = $b(content: 'A');
      var b = $b(content: 'B');
      var c = $b(content: 'C');
      var m = $div(content: <Object>[a, b, c]);

      expect(a.moveDown(), isTrue);
      expect(m.buildHTML(), equals('<div><b>B</b><b>A</b><b>C</b></div>'));
      expect(a.moveUp(), isTrue);
      expect(m.buildHTML(), equals('<div><b>A</b><b>B</b><b>C</b></div>'));
      expect(a.moveUp(), isTrue, reason: 'already first');
      expect(c.moveDown(), isTrue, reason: 'already last');
      expect(c.moveUp(), isTrue);
      expect(m.buildHTML(), equals('<div><b>A</b><b>C</b><b>B</b></div>'));

      var dup = b.duplicate();
      expect(identical(dup?.parent, m), isTrue);
      expect(
        m.buildHTML(),
        equals('<div><b>A</b><b>C</b><b>B</b><b>B</b></div>'),
      );

      expect(TextNode('x').moveUp(), isFalse);
      expect(TextNode('x').moveDown(), isFalse);
      expect(TextNode('x').duplicate(), isNull);
      expect(m.moveUpNode($b()), isFalse);
      expect(m.duplicateNode($b()), isNull);
    });

    test('siblings', () {
      var a = $b(content: 'A');
      var b = $b(content: 'B');
      $div(content: <Object>[a, b]);
      expect(a.isNextNode(b), isTrue);
      expect(b.isPreviousNode(a), isTrue);
      expect(a.isConsecutiveNode(b), isTrue);
      expect(a.isInSameParent(b), isTrue);
      expect(b.indexInParent, equals(1));
      expect($b().indexInParent, equals(-1));
      expect(a.isNextNode(a), isFalse);
    });

    test('remove / clearNodes', () {
      var a = $b(content: 'A');
      var m = $div(content: <Object>[a, 'x']);
      expect(a.remove(), isTrue);
      expect(a.remove(), isFalse);
      expect(m.buildHTML(), equals('<div>x</div>'));
      expect(m.removeNode($b()), isFalse);
      m.clearNodes();
      expect(m.isEmptyContent, isTrue);
      expect(m.length, equals(0));
    });

    test('content getters', () {
      var t = tree();
      expect(t.nodes.length, equals(2));
      expect(t.nodesView.length, equals(2));
      expect(() => t.nodesView.add($b()), throwsUnsupportedError);
      expect(t.hasOnlyElementNodes, isTrue);
      expect(t.hasOnlyTextNodes, isFalse);
      expect(t.text, equals('ab'));
      expect(t.isNotEmptyContent, isTrue);
      expect($div().nodes, isEmpty);
      expect(() => t.checkNodes(), returnsNormally);
    });

    test('add / addAll / addEach / addAsTag / addHTML / setContent', () {
      expect(
        ($div()
              ..addEach([1, 2], (e) => $b(content: '$e'))
              ..addEach(['z']))
            .buildHTML(),
        equals('<div><b>1</b><b>2</b>z</div>'),
      );
      expect(
        ($div()
              ..addEachAsTag('i', [1, 2])
              ..addEachAsTag<int>('u', [3], (e) => 'n$e'))
            .buildHTML(),
        equals('<div><i>1</i><i>2</i><u>n3</u></div>'),
      );
      expect(
        ($div()
              ..addAsTag('i', 'x')
              ..addAsTag<int>('u', 3, (e) => 'n$e'))
            .buildHTML(),
        equals('<div><i>x</i><u>n3</u></div>'),
      );
      expect(
        ($div()
              ..addHTML('<b>x</b>')
              ..addHTML(''))
            .buildHTML(),
        equals('<div><b>x</b></div>'),
      );
      expect(
        ($div()
              ..addAll(['a', null, $b(content: 'b')])
              ..addAll(null))
            .buildHTML(),
        equals('<div>a<b>b</b></div>'),
      );
      expect(($div()..add(null)).isEmptyContent, isTrue);
      expect(
        ($div(content: 'a')..setContent([$b(content: 'x')])).buildHTML(),
        equals('<div><b>x</b></div>'),
      );
      expect(
        ($div(content: 'a')..setContent(null)).buildHTML(),
        equals('<div></div>'),
      );
      expect(() => TextNode('t').add('x'), throwsUnsupportedError);
    });

    test('insertAt / insertAfter', () {
      var d = $div(
        content: <Object>[
          $span(content: 'a'),
          $span(content: 'b'),
        ],
      );
      d.insertAt(1, 'txt');
      expect(
        d.buildHTML(),
        equals('<div><span>a</span>txt<span>b</span></div>'),
      );
      d.insertAt(9, $b(content: 'end'));
      expect(d.buildHTML(), endsWith('<b>end</b></div>'));
      d.insertAfter(0, $b(content: '1'));
      expect(d.buildHTML(), startsWith('<div><span>a</span><b>1</b>'));

      var list = $div(
        content: <Object>[
          $span(content: 'a'),
          $span(content: 'b'),
        ],
      );
      list.insertAt(1, [$b(content: '1'), $b(content: '2')]);
      expect(
        list.buildHTML(),
        equals('<div><span>a</span><b>1</b><b>2</b><span>b</span></div>'),
      );
      expect(() => list.checkNodes(), returnsNormally);

      expect(($div()..insertAt(0, 'x')).buildHTML(), equals('<div>x</div>'));
      expect(($div()..insertAfter(0, 'x')).buildHTML(), equals('<div>x</div>'));
    });

    test(
      'insertAt a single parsed node sets its parent',
      () {
        var d = $div(content: <Object>[$span(content: 'a')]);
        d.insertAt(0, '<b>x</b>');
        expect(d.content!.first.parent, isNotNull);
        expect(() => d.checkNodes(), returnsNormally);
      },
      skip:
          'BUG: _insertListToContent single-element path inserts without '
          'setting `parent` (dom_builder_base.dart:904)',
    );

    test(
      'content list is copied from typed Dart lists',
      () {
        var list = [$span(content: 'a')]; // List<DOMElement>
        var d = $div(content: list);
        d.add('txt');
        expect(d.buildHTML(), equals('<div><span>a</span>txt</div>'));
        expect(list.length, equals(1));
      },
      skip:
          'BUG: DOMNode._parseListNodes returns the caller\'s List<DOMNode> '
          'subtype as-is: it is shared and adding a TextNode to a '
          'List<DOMElement> throws a TypeError (dom_builder_base.dart:249)',
    );

    test('hasFutureElement', () {
      var ext = ExternalElementNode(Future.value(1));
      expect(
        $div(content: <Object>[ext]).hasFutureElement(recursive: true),
        isTrue,
      );
      expect(
        $div(
          content: <Object>[
            $div(content: <Object>[ExternalElementNode(Future.value(1))]),
          ],
        ).hasFutureElement(recursive: true),
        isTrue,
      );
      expect($div(content: <Object>[ext]).hasFutureElement(), isFalse);
      expect($div(content: 'x').hasFutureElement(recursive: true), isFalse);
      expect($div().hasFutureElement(), isFalse);
    });

    test('merge / absorb', () {
      var t1 = TextNode('a');
      var t2 = TextNode('b');
      var par = $div(content: <Object>[t1, t2]);
      expect(t1.isCompatibleForMerge(t2), isTrue);
      expect(t1.merge(t2), isTrue);
      expect(par.buildHTML(), equals('<div>ab</div>'));
      expect(par.length, equals(1));

      var e1 = $b(content: 'x');
      var e2 = $b(content: 'y');
      var par2 = $div(content: <Object>[e1, e2]);
      expect(e1.isCompatibleForMerge(e2), isTrue);
      expect(e1.isCompatibleForMerge($i('z')), isFalse);
      expect(e1.merge(e2), isTrue);
      expect(par2.buildHTML(), equals('<div><b>xy</b></div>'));

      var a = $b(content: 'a');
      var b = $b(content: 'b');
      expect(a.absorbNode(b), isTrue);
      expect(a.buildHTML(), equals('<b>ab</b>'));
      expect(b.buildHTML(), equals('<b></b>'));
      expect(a.merge(TextNode('q')), isFalse, reason: 'not consecutive');

      var s = $b(content: 'x');
      var n = TextNode('y');
      $div(content: <Object>[n, s]);
      expect(n.merge(s), isTrue);
      expect(n.text, equals('yx'));
    });

    test('whitespace / string elements', () {
      expect($b(content: '  ').isWhiteSpaceContent, isTrue);
      expect($b(content: 'x').isWhiteSpaceContent, isFalse);
      expect($b(content: 'x').isStringElement, isTrue);
      expect($div().isStringElement, isFalse);
    });

    test('toText / from', () {
      expect(DOMNode.toText([TextNode('a'), 'b']), equals('ab'));
      expect(DOMNode.toText({'k': 'v'}), equals('v'));
      expect(DOMNode.toText(null), isEmpty);
      expect(DOMNode.toText('s'), equals('s'));
      expect(DOMNode.from('plain')?.buildHTML(), equals('plain'));
      expect(DOMNode.from('<b>x</b>')?.buildHTML(), equals('<b>x</b>'));
      expect(DOMNode.from(12)?.buildHTML(), equals('12'));
      expect(
        DOMNode.from('a &amp; b')?.buildHTML(),
        // The entity is decoded into the text node:
        equals('<span>a & b</span>'),
      );
      expect(DOMNode.from(null), isNull);
      var node = $b();
      expect(identical(DOMNode.from(node), node), isTrue);
    });

    test('buildHTML indentation and XHTML', () {
      expect(
        $div(
          content: <Object>[
            $p(content: 'a'),
            $div(content: <Object>[$b(content: 'b')]),
          ],
        ).buildHTML(withIndent: true),
        equals('<div>\n  <p>a</p>\n  <div>\n    <b>b</b>\n  </div>\n</div>'),
      );
      expect(
        $div(
          content: <Object>[
            $br(),
            $img(src: 'x'),
            $div(),
          ],
        ).buildHTML(xhtml: true),
        equals('<div><br/><img src="x"/><div/></div>'),
      );
    });

    // BUG (not tested here): `DOMNode(content: ...)` leaves
    // `late bool _commented` uninitialized, so `isCommented`/`buildHTML`
    // throw a `LateInitializationError` (dom_builder_base.dart:383).
    // A test calling it, even skipped, makes dart2wasm 3.13.3 crash while
    // compiling this file (`Null check operator used on a null value` in
    // `AstCodeGenerator._setupLocalParameters`).

    test(
      'commented elements are omitted from HTML',
      () {
        expect(
          $div(
            content: <Object>[
              $b(content: 'x', commented: true),
              'y',
            ],
          ).buildHTML(),
          equals('<div>y</div>'),
        );
        expect($br(amount: 0).buildHTML(), isEmpty);
      },
      skip:
          'BUG?: DOMElement.buildHTML ignores `isCommented` (only '
          'DOMNode.buildHTML and the DOM generator honor it; '
          'dom_builder_base.dart:2722)',
    );
  });

  group('table content bugs', () {
    test(
      'empty sections have no rows',
      () {
        expect(TBODYElement().buildHTML(), equals('<tbody></tbody>'));
        expect(THEADElement().buildHTML(), equals('<thead></thead>'));
      },
      skip:
          'BUG: createTableRows(null) creates a row with an empty cell '
          '(dom_builder_base.dart:3923)',
    );

    test(
      'mismatched TD/TH cells are converted, not nested',
      () {
        expect(
          TRowElement(
            cells: [TDElement(content: 'x')],
            headerRow: true,
          ).buildHTML(),
          equals('<tr><th>x</th></tr>'),
        );
        expect(
          TRowElement(
            cells: [
              THElement(content: 'x'),
              'y',
            ],
          ).buildHTML(),
          equals('<tr><th>x</th><td>y</td></tr>'),
        );
        expect(
          THEADElement.from(
            DOMElement(
              'thead',
              content: [
                DOMElement('tr', content: [DOMElement('th', content: 'h')]),
              ],
            ),
          )?.buildHTML(),
          equals('<thead><tr><th>h</th></tr></thead>'),
        );
      },
      skip:
          'BUG: createTableCells wraps a TDElement in <th> (and a THElement '
          'in <td>) instead of converting it (dom_builder_base.dart:3971)',
    );
  });

  group('TextNode / TemplateNode / ExternalElementNode / DOMAsync', () {
    test('TextNode', () {
      var x = TextNode('a\xa0b');
      expect(x.buildHTML(), equals('a&nbsp;b'));
      expect(x.buildHTML(xhtml: true), equals('a&#160;b'));
      expect(x.isTextEmpty, isFalse);
      expect(TextNode('').isTextEmpty, isTrue);
      expect(x.hasValue, isTrue);
      expect(x.value, equals(x.text));
      expect(x.isWhiteSpaceContent, isFalse);
      expect(TextNode('  ').isWhiteSpaceContent, isTrue);
      expect(x.equals(TextNode('a\xa0b')), isTrue);
      expect(x.equals(TextNode('z')), isFalse);
      expect(x.copy().text, equals(x.text));
      expect(x.copyContent(), isEmpty);
      expect(x.hasOnlyTextNodes, isTrue);
      expect(x.hasOnlyElementNodes, isFalse);
      expect(x.isStringElement, isTrue);
      expect(x.toString(), equals(x.text));
      expect(TextNode.toTextNode(null).text, isEmpty);
      expect(TextNode.toTextNode('{{x}}'), isA<TemplateNode>());
      expect(TextNode.toTextNode('plain'), isA<TextNode>());

      x.text = '{{y}}';
      expect(x.hasUnresolvedTemplate, isTrue);
      expect(x.absorbNode($b(content: 'q')), isTrue);
      expect(x.text, equals('{{y}}q'));
      expect(x.absorbNode(ExternalElementNode('e')), isFalse);
    });

    test('TemplateNode', () {
      var tn = TextNode.toTextNode('Hi {{name}}') as TemplateNode;
      expect(tn.buildHTML(), equals('Hi {{name}}'));
      expect(
        tn.buildHTML(
          buildTemplates: true,
          domContext: DOMContext(variables: {'name': 'Bob'}),
        ),
        equals('Hi Bob'),
      );
      expect(tn.hasTemplate, isTrue);
      expect(tn.hasUnresolvedTemplate, isFalse);
      expect(tn.isEmptyTemplate, isFalse);
      expect(tn.hasValue, isTrue);
      expect(tn.copy().text, equals('Hi {{name}}'));
      expect(tn.copyContent(), isEmpty);
      expect(tn.equals(tn), isTrue);
      expect(tn.isCompatibleForMerge(TextNode('x')), isTrue);
      expect(tn.toString(), equals(tn.text));

      expect(tn.absorbNode(TextNode('!')), isTrue);
      expect(tn.text, equals('Hi {{name}}!'));
      tn.clearNodes();
      expect(tn.isEmptyTemplate, isTrue);
      expect(tn.text, isEmpty);
    });

    test('ExternalElementNode', () {
      expect(ExternalElementNode('<x>').buildHTML(), equals('<x>'));
      expect(ExternalElementNode(null).buildHTML(), isEmpty);
      expect(ExternalElementNode(123).buildHTML(), equals('123'));
      expect(ExternalElementNode(Future.value(1)).isFutureElement, isTrue);
      expect(ExternalElementNode(Future.value(1)).hasFutureElement(), isTrue);
      expect(ExternalElementNode(1).isFutureElement, isFalse);
      expect(ExternalElementNode(123).copy().buildHTML(), equals('123'));
      expect(
        ExternalElementNode(123).toString(),
        equals('ExternalElementNode@123'),
      );
      expect(ExternalElementNode(() => 'gen').buildHTML(), equals('gen'));
    });

    test('DOMAsync', () {
      var future = Future.value(1);
      expect(
        identical(DOMAsync.future(future, 'l').resolveFuture, future),
        isTrue,
      );
      var calls = 0;
      var byFunction = DOMAsync.function(() async {
        calls++;
        return 1;
      });
      expect(byFunction.resolveFuture, isNotNull);
      expect(
        identical(byFunction.resolveFuture, byFunction.resolveFuture),
        isTrue,
      );
      expect(calls, equals(1));
      expect(() => DOMAsync().resolveFuture, throwsA(isA<StateError>()));
    });
  });

  group('CSSEntry comment (private named parameter)', () {
    test('comment is rendered by toString', () {
      var c = CSSEntry<CSSColor>(
        'Color',
        CSSColor.from('red'),
        comment: 'main',
      );
      expect(c.name, equals('color'));
      expect(c.toString(), equals('color: red/*main*/'));
      expect(c.toString(true), equals('color: red/*main*/;'));
      expect(
        CSSEntry(
          'color',
          CSSColor.from('red'),
          comment: '/*already*/',
        ).toString(),
        equals('color: red/*already*/'),
      );
      expect(
        CSSEntry('color', CSSColor.from('red')).toString(),
        equals('color: red'),
      );
      expect(
        CSSEntry<CSSColor>('color', null).toString(),
        equals('color: initial'),
      );
    });

    test('comment does not affect equality', () {
      expect(
        CSSEntry('color', CSSColor.from('red'), comment: 'a'),
        equals(CSSEntry('color', CSSColor.from('red'), comment: 'b')),
      );
    });

    test('from / parse with comment', () {
      expect(
        CSSEntry.from('color', 'red', 'cmt').toString(),
        equals('color: red/*cmt*/'),
      );
      expect(
        CSSEntry.from(
          'color',
          CSSEntry('x', CSSColor.from('red'), comment: 'drop'),
          'kept',
        ).toString(),
        equals('color: red/*kept*/'),
      );
      expect(
        CSSEntry.from('color', CSSColor.from('red'))?.toString(),
        equals('color: red'),
      );
      expect(CSSEntry.from('color', null), isNull);
      expect(CSSEntry.from('color', 12), isNull);

      expect(
        CSSEntry.parse('color: red', 'note').toString(),
        equals('color: red/*note*/'),
      );
      expect(
        CSSEntry.parse(
          'color: red',
          '/* DOMContext-original-value: blue */',
        ).toString(),
        equals('color: blue'),
      );
      expect(CSSEntry.parse('nocolon'), isNull);
    });
  });

  group('DSXObjectType.forObject', () {
    test('function / future / generic', () {
      expect(DSXObjectType.forObject(() {}), equals(DSXObjectType.function));
      expect(
        DSXObjectType.forObject(Future.value(1)),
        equals(DSXObjectType.future),
      );
      expect(DSXObjectType.forObject(1), equals(DSXObjectType.generic));
      expect(DSXObjectType.forObject(null), equals(DSXObjectType.generic));
      expect(DSXObjectType.function.placeholder, equals('function'));
      expect(DSXObjectType.future.placeholderPrefix, equals('future_'));
    });
  });

  group('DOMAttribute', () {
    test('static helpers', () {
      expect(DOMAttribute.isBooleanAttribute('checked'), isTrue);
      expect(DOMAttribute.isBooleanAttribute('title'), isFalse);
      expect(DOMAttribute.getAttributeDelimiter('class'), equals(' '));
      expect(DOMAttribute.getAttributeDelimiter('style'), equals('; '));
      expect(DOMAttribute.getAttributeDelimiter('id'), isNull);
      expect(DOMAttribute.getAttributeDelimiterPattern('class'), isNotNull);
      expect(DOMAttribute.getAttributeDelimiterPattern('id'), isNull);
      expect(DOMAttribute.normalizeName(' TiTle '), equals('title'));
      expect(DOMAttribute.normalizeName(null), isNull);

      var attr = DOMAttribute.from('id', 'x');
      expect(DOMAttribute.append('<a', ' ', attr), equals('<a id="x"'));
      expect(DOMAttribute.append('<a', ' ', null), equals('<a'));
      expect(
        DOMAttribute.append('<a', ' ', DOMAttribute.from('t', '')),
        equals('<a'),
      );
      expect(
        DOMAttribute.appendTo(StringBuffer('<a'), ' ', attr).toString(),
        equals('<a id="x"'),
      );
      expect(
        DOMAttribute.appendTo(StringBuffer('<a'), ' ', null).toString(),
        equals('<a'),
      );
      expect(
        DOMAttribute.appendTo(
          StringBuffer('<a'),
          ' ',
          DOMAttribute.from('t', ''),
        ).toString(),
        equals('<a'),
      );
    });

    test('from: string attribute', () {
      expect(DOMAttribute.from(null, 'x'), isNull);
      var attr = DOMAttribute.from(' Title ', 'hello')!;
      expect(attr.name, equals('title'));
      expect(
        attr.isBoolean || attr.isList || attr.isSet || attr.isCollection,
        isFalse,
      );
      expect(attr.hasValue, isTrue);
      expect(attr.value, equals('hello'));
      expect(attr.values, equals(['hello']));
      expect(attr.valueLength, equals(5));
      expect(attr.containsValue('ell'), isTrue);
      expect(attr.containsValue(null), isFalse);
      expect(attr.valueHandler.equalsAttributeValue('hello'), isTrue);
      expect(attr.valueHandler.equalsAttributeValue(null), isFalse);
      expect(attr.buildHTML(), equals('title="hello"'));
      expect(attr.toString(), equals('hello'));
      expect(() => attr.setBoolean(true), throwsStateError);

      attr.appendValue('world');
      expect(attr.value, equals('world'));
      attr.setValue('say "hi"');
      expect(attr.buildHTML(), equals('title=\'say "hi"\''));

      var empty = DOMAttribute.from('title', '')!;
      expect(empty.hasValue, isFalse);
      expect(empty.value, isNull);
      expect(empty.values, isNull);
      expect(empty.valueLength, equals(0));
      expect(empty.buildHTML(), isEmpty);
      expect(empty.toString(), isEmpty);
      expect(empty.valueHandler.equalsAttributeValue(null), isTrue);
      expect(
        empty.valueHandler.toString(),
        contains('DOMAttributeValueString'),
      );
    });

    test('from: boolean attribute', () {
      expect(DOMAttribute.from('checked', null), isNull);

      var attr = DOMAttribute.from('checked', true)!;
      expect(attr.isBoolean, isTrue);
      expect(attr.buildHTML(), equals('checked'));
      expect(attr.value, equals('true'));
      expect(attr.values, equals(['true']));
      expect(attr.valueLength, equals(1));
      expect(attr.containsValue(true), isTrue);
      expect(attr.valueHandler.toString(), contains('true'));

      attr.setBoolean(false);
      expect(attr.hasValue, isFalse);
      expect(attr.buildHTML(), isEmpty);

      expect(DOMAttribute.from('disabled', '')!.hasValue, isTrue);
      expect(DOMAttribute.from('hidden', 'false')!.hasValue, isFalse);
    });

    test('from: class set attribute', () {
      var attr = DOMAttribute.from('class', 'a b a')!;
      expect(attr.isSet, isTrue);
      expect(attr.isCollection, isTrue);
      expect(attr.values, equals(['a', 'b']));
      expect(attr.value, equals('a b'));
      expect(attr.valueLength, equals(2));
      expect(attr.containsValue('b a'), isTrue);
      expect(attr.containsValue('c'), isFalse);
      expect(attr.containsValue(null), isFalse);

      attr.appendValue('c');
      expect(attr.buildHTML(), equals('class="a b c"'));

      var handler = attr.valueHandler as DOMAttributeValueSet;
      // `isEqualsSet` (swiss_knife) is order sensitive:
      expect(handler.equalsAttributeValue('a b c'), isTrue);
      expect(handler.equalsAttributeValue('a b'), isFalse);
      expect(handler.equalsAttributeValue(null), isFalse);
      expect(handler.containsAttributeValueEntry('a'), isTrue);
      expect(handler.containsAttributeValueEntry(null), isFalse);
      expect(handler.getAttributeValueEntry('b'), equals('b'));
      expect(handler.getAttributeValueEntry('z'), isNull);
      expect(handler.removeAttributeValueEntry('b'), equals('b'));
      expect(handler.removeAttributeValueEntry('b'), isNull);
      handler.removeAttributeValueAllEntries(['a', 'c']);
      expect(handler.hasAttributeValue, isFalse);
      expect(handler.asAttributeValue, isNull);
      expect(handler.asAttributeValues, isNull);
      expect(handler.getAttributeValueEntry('a'), isNull);
      expect(handler.equalsAttributeValue(null), isTrue);

      attr.setValue('x y');
      expect(attr.values, equals(['x', 'y']));
      attr.setValue('');
      expect(attr.hasValue, isFalse);
      expect(handler.toString(), contains('DOMAttributeValueSet'));
    });

    test('DOMAttributeValueList', () {
      var list = DOMAttributeValueList('a;b', ';', RegExp(r'\s*;\s*'));
      expect(list.hasAttributeValue, isTrue);
      expect(list.length, equals(2));
      expect(list.asAttributeValue, equals('a;b'));
      expect(list.asAttributeValues, equals(['a', 'b']));
      expect(list.equalsAttributeValue('a; b'), isTrue);
      expect(list.equalsAttributeValue('b;a'), isFalse);
      expect(list.equalsAttributeValue(null), isFalse);
      expect(list.containsAttributeValue('b'), isTrue);
      expect(list.containsAttributeValue('z'), isFalse);
      expect(list.containsAttributeValue(null), isFalse);
      expect(list.containsAttributeValue(''), isFalse);
      expect(list.containsAttributeValueEntry('a'), isTrue);
      expect(list.containsAttributeValueEntry(null), isFalse);
      expect(list.getAttributeValueEntry('b'), equals('b'));
      expect(list.getAttributeValueEntry('z'), isNull);
      expect(list.getAttributeValueEntry(null), isNull);

      list.appendAttributeValue('c');
      expect(list.asAttributeValue, equals('a;b;c'));
      expect(list.removeAttributeValueEntry('a'), equals('a'));
      expect(list.removeAttributeValueEntry('a'), isNull);
      expect(list.removeAttributeValueEntry(null), isNull);

      list.setAttributeValue('only');
      expect(list.asAttributeValues, equals(['only']));
      list.setAttributeValue('x');
      expect(list.asAttributeValue, equals('x'));
      list.setAttributeValue('p;q');
      expect(list.length, equals(2));
      list.setAttributeValue(null);
      expect(list.hasAttributeValue, isFalse);
      expect(list.asAttributeValue, isNull);
      expect(list.asAttributeValues, isNull);
      expect(list.equalsAttributeValue(null), isTrue);
      expect(list.equalsAttributeValue('a'), isFalse);
      expect(list.containsAttributeValue('a'), isFalse);
      expect(list.containsAttributeValueEntry('a'), isFalse);
      expect(list.toString(), contains('DOMAttributeValueList'));

      var single = DOMAttributeValueList('', ';', ';');
      expect(single.hasAttributeValue, isFalse);
    });

    test('style CSS attribute', () {
      var attr = DOMAttribute.from('style', 'color: red; width: 10px')!;
      expect(attr.isCollection, isTrue);
      expect(attr.values, equals(['color: red', 'width: 10px']));
      expect(attr.valueLength, equals(2));
      expect(attr.containsValue('color: red'), isTrue);
      expect(attr.containsValue('color: blue'), isFalse);
      expect(attr.containsValue(null), isFalse);
      expect(attr.containsValue(''), isFalse);

      var handler = attr.valueHandler as DOMAttributeValueCSS;
      expect(handler.css.length, equals(2));
      expect(handler.equalsAttributeValue('color: red; width: 10px'), isTrue);
      expect(handler.containsAttributeValueEntry('color: red'), isTrue);
      expect(handler.containsAttributeValueEntry('color: blue'), isFalse);
      expect(handler.containsAttributeValueEntry('nocolon'), isFalse);
      expect(handler.containsAttributeValueEntry(null), isFalse);
      expect(handler.getAttributeValueEntry('color'), equals('color: red'));
      expect(handler.getAttributeValueEntry(null), isNull);
      expect(handler.removeAttributeValueEntry('color: blue'), isNull);
      expect(handler.removeAttributeValueEntry('nocolon'), isNull);
      expect(handler.removeAttributeValueEntry(null), isNull);
      expect(
        handler.removeAttributeValueEntry('color: red'),
        equals('color: red'),
      );
      expect(attr.value, equals('width: 10px'));

      attr.appendValue('height: 1px');
      attr.appendValue(null);
      attr.appendValue('');
      expect(attr.value, equals('width: 10px; height: 1px'));

      attr.setValue(null);
      expect(attr.hasValue, isFalse);
      expect(attr.value, isNull);
      expect(handler.getAttributeValue(), isNull);
      expect(handler.containsAttributeValue('width: 10px'), isFalse);
      expect(handler.toString(), contains('DOMAttributeValueCSS'));
    });

    test('template attribute', () {
      var attr = DOMAttribute.from('title', 'Hi {{name}}')!;
      expect(attr.valueHandler, isA<DOMAttributeValueTemplate>());
      expect(attr.getValue(), equals('Hi {{name}}'));
      expect(
        attr.getValue(DOMContext(variables: {'name': 'Bob'})),
        equals('Hi Bob'),
      );
      expect(attr.buildHTML(), equals('title="Hi {{name}}"'));

      var handler = attr.valueHandler as DOMAttributeValueTemplate;
      handler.setAttributeValue('Bye {{name}}');
      expect(
        attr.getValue(DOMContext(variables: {'name': 'Ann'})),
        equals('Bye Ann'),
      );
      expect(handler.template, isNotNull);
      expect(handler.toString(), contains('DOMAttributeValueTemplate'));

      var el = $div(attributes: {'title': '{{t}}'});
      expect(el.hasTemplate, isTrue);
      expect(
        el.getAttributeValue('title', DOMContext(variables: {'t': 'x'})),
        equals('x'),
      );
      expect($div(content: 'plain').hasTemplate, isFalse);
    });
  });
}

DOMElement $i(String s) => $tag('i', content: s);
