@TestOn('vm')
library;

import 'package:dom_builder/dom_builder.dart';
import 'package:test/test.dart';

import 'dom_builder_domtest.dart';

void main() {
  group('helpers: parsing', () {
    test('parseListOfStrings', () {
      expect(parseListOfStrings(null, ','), isEmpty);
      expect(
        parseListOfStrings([' a ', null, 'b', ''], ','),
        equals(['a', 'b']),
      );
      expect(parseListOfStrings(' a, b ,,c ', ','), equals(['a', 'b', 'c']));
      expect(parseListOfStrings(' a, b ', ',', false), equals([' a', ' b ']));
    });

    test('parseHTML: null, empty and plain text', () {
      expect(parseHTML(null), isNull);
      expect(parseHTML(''), isNull);

      var text = parseHTML('hello')!;
      expect(text.length, equals(1));
      expect(text.single, isA<TextNode>());
      expect(text.single.text, equals('hello'));
    });

    test('parseHTML: single element', () {
      var nodes = parseHTML('<div>x</div>')!;
      expect(nodes.map((e) => e.buildHTML()), equals(['<div>x</div>']));
    });

    test('parseHTML: several nodes, surrounding blanks trimmed', () {
      var nodes = parseHTML('  <b>x</b> <i>y</i>  ')!;
      expect(nodes.length, equals(3));
      expect(nodes.first.buildHTML(), equals('<b>x</b>'));
      expect(nodes.last.buildHTML(), equals('<i>y</i>'));
    });

    test('parseHTML: table-dependent tags (td, th, tbody, tfoot)', () {
      expect(parseHTML('<td>x</td>')!.single.buildHTML(), equals('<td>x</td>'));
      expect(parseHTML('<th>x</th>')!.single.buildHTML(), equals('<th>x</th>'));
      expect(
        parseHTML('<tbody><tr><td>x</td></tr></tbody>')!.single.buildHTML(),
        equals('<tbody><tr><td>x</td></tr></tbody>'),
      );
      expect(
        parseHTML('<tfoot><tr><td>x</td></tr></tfoot>')!.single.buildHTML(),
        equals('<tfoot><tr><td>x</td></tr></tfoot>'),
      );
    });

    test(
      'parseHTML: thead is kept',
      () {
        expect(
          parseHTML('<thead><tr><td>x</td></tr></thead>')!.single.buildHTML(),
          equals('<thead><tr><td>x</td></tr></thead>'),
        );
      },
      skip:
          'Bug: the dependent-tag RegExp says `thread` instead of `thead`, '
          'so `<thead>` is parsed outside a table and reduced to its text.',
    );

    test(
      'parseHTML: a lone tr is parsed',
      () {
        expect(
          parseHTML('<tr><td>x</td></tr>')!.single.buildHTML(),
          equals('<tr><td>x</td></tr>'),
        );
      },
      skip:
          'Bug: `tr` matches the dependent-tag RegExp but no branch assigns '
          '`parsed`, throwing LateInitializationError.',
    );

    test('\$htmlRoot', () {
      expect($htmlRoot(null), isNull);
      expect(
        $htmlRoot('  <div>a</div>  ')!.buildHTML(),
        equals('<div>a</div>'),
      );
      expect(
        $htmlRoot('<b>a</b><i>b</i>')!.buildHTML(),
        equals('<span><b>a</b><i>b</i></span>'),
      );
      expect(
        $htmlRoot('<div>a</div><div>b</div>')!.buildHTML(),
        equals(
          '<div style="display: inline-block"><div>a</div><div>b</div></div>',
        ),
      );
      expect(
        $htmlRoot(
          '<div>a</div><div>b</div>',
          defaultRootTag: 'section',
          defaultTagDisplayInlineBlock: false,
        )!.buildHTML(),
        equals('<section><div>a</div><div>b</div></section>'),
      );
      expect($htmlRoot('text')!.buildHTML(), equals('<span>text</span>'));
      expect(
        $htmlRoot(['<div>a</div>', '\n '])!.buildHTML(),
        equals('<div>a</div>'),
      );
    });

    test('isHTMLElement / hasHTMLTag / hasHTMLEntity', () {
      expect(isHTMLElement('<div>x</div>'), isTrue);
      expect(isHTMLElement(' <div>x</div> '), isTrue);
      expect(isHTMLElement('x <b>'), isFalse);
      expect(isHTMLElement('<div>x'), isFalse);
      expect(hasHTMLTag('a <b>x</b>'), isTrue);
      expect(hasHTMLTag('a < b'), isFalse);
      expect(hasHTMLEntity('a &amp; b'), isTrue);
      expect(hasHTMLEntity('a &#160; b'), isTrue);
      expect(hasHTMLEntity('a & b'), isFalse);
    });
  });

  group('helpers: table builders', () {
    test('\$table with all parameters', () {
      var table = $table(
        id: 't',
        classes: 'c',
        style: 'color: red',
        attributes: {'border': '1'},
        caption: 'Cap',
        head: ['H1', 'H2'],
        body: [
          ['a', 'b'],
        ],
        foot: [
          ['f1', 'f2'],
        ],
        thsStyle: 'color: blue',
        tdsStyle: 'padding: 1px',
        trsStyle: 'height: 2px',
        hidden: false,
      );

      expect(
        table.buildHTML(),
        equals(
          '<table id="t" class="c" style="color: red" border="1">'
          '<caption>Cap</caption>'
          '<thead><tr style="height: 2px">'
          '<th style="color: blue">H1</th><th style="color: blue">H2</th>'
          '</tr></thead>'
          '<tbody><tr style="height: 2px">'
          '<td style="padding: 1px">a</td><td style="padding: 1px">b</td>'
          '</tr></tbody>'
          '<tfoot><tr style="height: 2px">'
          '<td style="padding: 1px">f1</td><td style="padding: 1px">f2</td>'
          '</tr></tfoot>'
          '</table>',
        ),
      );
    });

    test('\$table: per-cell style wins over thsStyle/tdsStyle', () {
      var table = $table(
        body: [
          [$td(style: 'padding: 9px', content: 'a')],
        ],
        tdsStyle: 'padding: 1px; color: green',
      );
      expect(
        table.buildHTML(),
        equals(
          '<table><tbody><tr>'
          '<td style="padding: 9px; color: green">a</td>'
          '</tr></tbody></table>',
        ),
      );
    });

    test('\$table commented builds nothing', () {
      expect($table(body: 'x', commented: true).buildHTML(), isEmpty);
    });

    test('\$thead / \$tbody / \$tfoot', () {
      expect(
        $thead(
          id: 'h',
          classes: 'c',
          style: 'color: red',
          attributes: {'x': '1'},
          rows: [
            ['a'],
          ],
          hidden: true,
        ).buildHTML(),
        equals(
          '<thead id="h" class="c" style="color: red" x="1" hidden>'
          '<tr><th>a</th></tr></thead>',
        ),
      );

      var tbody = $tbody(
        id: 'b',
        classes: 'c',
        style: 'color: red',
        attributes: {'x': '1'},
        rows: [
          ['a', 'b'],
        ],
      );
      expect(tbody, isA<TBODYElement>());
      expect(
        tbody.buildHTML(),
        equals(
          '<tbody id="b" class="c" style="color: red" x="1">'
          '<tr><td>a</td><td>b</td></tr></tbody>',
        ),
      );

      var tfoot = $tfoot(
        id: 'f',
        classes: 'c',
        style: 'color: red',
        attributes: {'x': '1'},
        rows: [
          ['z'],
        ],
      );
      expect(tfoot, isA<TFOOTElement>());
      expect(
        tfoot.buildHTML(),
        equals(
          '<tfoot id="f" class="c" style="color: red" x="1">'
          '<tr><td>z</td></tr></tfoot>',
        ),
      );

      expect($tbody(rows: [], commented: true).buildHTML(), isEmpty);
    });

    test('\$caption with captionSide', () {
      expect(
        $caption(
          captionSide: 'bottom',
          style: 'color: red',
          content: 'C',
        ).buildHTML(),
        equals('<caption style="caption-side: bottom; color: red">C</caption>'),
      );
      expect(
        $caption(
          id: 'i',
          classes: 'k',
          captionSide: 'top',
          attributes: {'x': 'y'},
          content: 'C',
        ).buildHTML(),
        equals(
          '<caption id="i" class="k" style="caption-side: top" x="y">C</caption>',
        ),
      );
      expect(
        $caption(
          captionSide: '',
          style: 'color: red',
          content: 'C',
        ).buildHTML(),
        equals('<caption style="color: red">C</caption>'),
      );
    });

    test('\$tr', () {
      var tr = $tr(
        id: 'r',
        classes: 'c',
        style: 'color: red',
        attributes: {'x': '1'},
        cells: ['a', 'b'],
      );
      expect(tr, isA<TRowElement>());
      expect(
        tr.buildHTML(),
        equals(
          '<tr id="r" class="c" style="color: red" x="1"><td>a</td><td>b</td></tr>',
        ),
      );
    });

    test('\$td / \$th attributes', () {
      expect(
        $td(
          colspan: 2,
          rowspan: 3,
          headers: 'h1',
          content: 'x',
          attributes: {'a': 'b'},
        ).buildHTML(),
        equals('<td colspan="2" rowspan="3" headers="h1" a="b">x</td>'),
      );
      expect(
        $th(
          id: 'h',
          colspan: 2,
          rowspan: 3,
          abbr: 'ab',
          scope: 'col',
          attributes: {'a': 'b'},
          content: 'x',
        ).buildHTML(),
        equals(
          '<th id="h" colspan="2" rowspan="3" abbr="ab" scope="col" a="b">x</th>',
        ),
      );
      expect(
        $th(content: 'x', hidden: true).buildHTML(),
        equals('<th hidden>x</th>'),
      );
    });
  });

  group('helpers: element builders', () {
    test('\$div / \$divInline / \$divHTML', () {
      expect(
        $div(
          id: 'd',
          classes: 'c',
          style: 'color: red',
          attributes: {'a': 'b'},
          content: 'x',
          hidden: true,
        ).buildHTML(),
        equals('<div id="d" class="c" style="color: red" a="b" hidden>x</div>'),
      );
      expect(
        $divInline(
          id: 'd',
          classes: 'c',
          style: 'color: red',
          attributes: {'a': 'b'},
          content: 'x',
        ).buildHTML(),
        equals(
          '<div id="d" class="c" style="display: inline-block; color: red" a="b">x</div>',
        ),
      );
      expect($divInline(content: 'x', commented: true).buildHTML(), isEmpty);

      var div = $divHTML('<div class="k">y</div>')!;
      expect(div, isA<DIVElement>());
      expect(div.buildHTML(), equals('<div class="k">y</div>'));
    });

    test('\$divCenteredContent', () {
      const cell =
          'display: table-cell; text-align: center; vertical-align: middle';

      expect(
        $divCenteredContent(
          classes: 'k',
          style: 'color: red',
          cellSpacing: '2px',
          cells: ['a', 'b'],
        ).buildHTML(),
        equals(
          '<div class="k" style="display: table; width: 100%; height: 100%; '
          'color: red; border-spacing: 2px">'
          '<div style="display: table-row">'
          '<div style="$cell">a</div><div style="$cell">b</div>'
          '</div></div>',
        ),
      );

      var perRow = $divCenteredContent(
        width: '',
        height: '',
        cellsPerRow: 2,
        cells: ['a', 'b', 'c'],
        content: 'z',
      );
      var rows = perRow.content!.whereType<DIVElement>().toList();
      expect(rows.length, equals(3));
      expect(rows[0].text, equals('ab'));
      expect(rows[1].text, equals('c'));
      expect(rows[2].text, equals('z'));
      expect(perRow.getAttributeValue('style'), equals('display: table'));
    });

    test('\$span', () {
      expect(
        $span(
          id: 's',
          classes: 'c',
          style: 'color: red',
          attributes: {'a': 'b'},
          content: 'x',
        ).buildHTML(),
        equals('<span id="s" class="c" style="color: red" a="b">x</span>'),
      );
      expect($span(content: 'x', commented: true).buildHTML(), isEmpty);
    });

    test('\$button', () {
      expect(
        $button(
          id: 'b',
          name: 'n',
          classes: 'c',
          style: 'color: red',
          attributes: {'a': 'b'},
          content: 'B',
          disabled: true,
          hidden: true,
        ).buildHTML(),
        equals(
          '<button id="b" class="c" style="color: red" type="button" name="n" '
          'a="b" disabled hidden>B</button>',
        ),
      );
      expect(
        $button(type: 'submit', content: 'S').buildHTML(),
        equals('<button type="submit">S</button>'),
      );
    });

    test('\$label', () {
      expect(
        $label(
          id: 'l',
          forID: 'f',
          classes: 'c',
          style: 'color: red',
          attributes: {'a': 'b'},
          content: 'L',
        ).buildHTML(),
        equals(
          '<label id="l" class="c" style="color: red" for="f" a="b">L</label>',
        ),
      );
    });

    test('\$textarea', () {
      var textarea = $textarea(
        id: 't',
        name: 'n',
        classes: 'c',
        style: 'color: red',
        cols: 10,
        rows: 3,
        attributes: {'a': 'b'},
        content: 'txt',
        disabled: true,
      );
      expect(textarea, isA<TEXTAREAElement>());
      expect(
        textarea.buildHTML(),
        equals(
          '<textarea id="t" class="c" style="color: red" name="n" cols="10" '
          'rows="3" a="b" disabled>txt</textarea>',
        ),
      );
    });

    test('\$input', () {
      var input = $input(
        id: 'i',
        name: 'n',
        classes: 'c',
        style: 'color: red',
        type: 'text',
        placeholder: 'ph',
        attributes: {'a': 'b'},
        value: 'v',
        disabled: true,
      );
      expect(input.value, equals('v'));
      expect(
        input.buildHTML(),
        equals(
          '<input id="i" class="c" style="color: red" name="n" type="text" '
          'placeholder="ph" value="v" a="b" disabled>',
        ),
      );
      expect($input(hidden: true, commented: true).buildHTML(), isEmpty);
    });

    test('\$select / \$option', () {
      var select = $select(
        id: 's',
        name: 'n',
        classes: 'c',
        style: 'color: red',
        attributes: {'a': 'b'},
        options: {'1': 'One', '2': 'Two'},
        selected: '2',
        multiple: true,
        disabled: true,
      );
      expect(select.selectedValue, equals('2'));
      expect(select.options.length, equals(2));
      expect(
        select.buildHTML(),
        equals(
          '<select id="s" class="c" style="color: red" a="b" name="n" multiple disabled>'
          '<option value="1">One</option><option value="2" selected>Two</option>'
          '</select>',
        ),
      );

      var noSelection = $select(options: ['a', 'b'], selected: 'zz');
      expect(noSelection.hasSelection, isFalse);

      expect(
        $option(
          classes: 'c',
          style: 'color: red',
          attributes: {'a': 'b'},
          valueAndText: 'X',
          label: 'lab',
          selected: true,
          disabled: true,
        ).buildHTML(),
        equals(
          '<option class="c" style="color: red" a="b" value="X" label="lab" '
          'selected disabled>X</option>',
        ),
      );
      expect(
        $option(value: 'v', text: 'T').buildHTML(),
        equals('<option value="v">T</option>'),
      );
    });

    test('\$img', () async {
      expect(
        $img(
          id: 'i',
          classes: 'c',
          style: 'color: red',
          src: 's.png',
          title: 't',
          attributes: {'alt': 'a'},
        ).buildHTML(),
        equals(
          '<img id="i" class="c" style="color: red" src="s.png" title="t" alt="a">',
        ),
      );

      var img = $img(srcFuture: Future.value('late.png'));
      expect(img.getAttributeValue('src'), isNull);
      await Future<void>.delayed(Duration.zero);
      expect(img.getAttributeValue('src'), equals('late.png'));

      var img2 = $img(src: 'keep.png', srcFuture: Future.value(null));
      await Future<void>.delayed(Duration.zero);
      expect(img2.getAttributeValue('src'), equals('keep.png'));
    });

    test('\$a', () {
      expect(
        $a(
          id: 'a',
          classes: 'c',
          style: 'color: red',
          href: 'h',
          target: '_blank',
          attributes: {'rel': 'x'},
          content: 'A',
        ).buildHTML(),
        equals(
          '<a id="a" class="c" style="color: red" href="h" target="_blank" rel="x">A</a>',
        ),
      );
    });

    test('\$h / \$hr', () {
      expect(
        $h(
          2,
          id: 'h',
          classes: 'c',
          style: 'color: red',
          attributes: {'a': 'b'},
          content: 'H',
        ).buildHTML(),
        equals('<h2 id="h" class="c" style="color: red" a="b">H</h2>'),
      );
      expect(
        $hr(
          id: 'h',
          classes: 'c',
          style: 'color: red',
          attributes: {'a': 'b'},
        ).buildHTML(),
        equals('<hr id="h" class="c" style="color: red" a="b">'),
      );
    });

    test('\$form / \$nav / \$header / \$footer', () {
      for (var e in [
        ('form', $form),
        ('nav', $nav),
        ('header', $header),
        ('footer', $footer),
      ]) {
        var (tag, f) = e;
        DOMElement el = Function.apply(f, [], {
          #id: 'x',
          #classes: 'c',
          #style: 'color: red',
          #attributes: {'a': 'b'},
          #content: 'y',
        });
        expect(
          el.buildHTML(),
          equals('<$tag id="x" class="c" style="color: red" a="b">y</$tag>'),
        );
        DOMElement commented = Function.apply(f, [], {#commented: true});
        expect(commented.buildHTML(), isEmpty);
      }
    });

    test('\$br', () {
      expect($br().buildHTML(), equals('<br>'));
      expect($br(amount: 0).buildHTML(), isEmpty);
      expect($br(amount: 0).isCommented, isTrue);
      expect($br(amount: 3).buildHTML(), equals('<span><br><br><br></span>'));
    });

    test('\$nbsp / \$emsp', () {
      expect($nbsp(), equals('&nbsp;'));
      expect($nbsp(0), isEmpty);
      expect($nbsp(3), equals('&nbsp;&nbsp;&nbsp;'));
      expect($emsp(), equals('&emsp;'));
      expect($emsp(0), isEmpty);
      expect($emsp(2), equals('&emsp;&emsp;'));
      expect($emsp(4), equals('&emsp;&emsp;&emsp;&emsp;'));
    });

    test('isDOMBuilderDirectHelper', () {
      expect(isDOMBuilderDirectHelper(null), isFalse);
      expect(isDOMBuilderDirectHelper('x'), isFalse);
      expect(isDOMBuilderDirectHelper(print), isFalse);
      for (var f in <Function>[
        $br,
        $p,
        $a,
        $b,
        $h,
        $nbsp,
        $div,
        $divInline,
        $img,
        $hr,
        $form,
        $nav,
        $header,
        $footer,
        $span,
        $button,
        $label,
        $textarea,
        $input,
        $select,
        $option,
        $table,
        $tbody,
        $thead,
        $tfoot,
        $td,
        $th,
        $tr,
        $caption,
      ]) {
        expect(isDOMBuilderDirectHelper(f), isTrue, reason: '$f');
      }
    });
  });

  group('DOMAttribute', () {
    test('normalizeName', () {
      expect(DOMAttribute.normalizeName(null), isNull);
      expect(DOMAttribute.normalizeName('  Title '), equals('title'));
    });

    test('append / appendTo', () {
      var attr = DOMAttribute.from('title', 'T');
      var empty = DOMAttribute.from('title', '');

      expect(DOMAttribute.append('<x', ' ', null), equals('<x'));
      expect(DOMAttribute.append('<x', ' ', empty), equals('<x'));
      expect(DOMAttribute.append('<x', ' ', attr), equals('<x title="T"'));

      var sb = StringBuffer('<x');
      DOMAttribute.appendTo(sb, ' ', null);
      DOMAttribute.appendTo(sb, ' ', empty);
      expect(sb.toString(), equals('<x'));
      DOMAttribute.appendTo(sb, ' ', attr);
      expect(sb.toString(), equals('<x title="T"'));
    });

    test('from: name and value handler selection', () {
      expect(DOMAttribute.from(null, 'x'), isNull);
      expect(DOMAttribute.from('checked', null), isNull);

      var cls = DOMAttribute.from('class', 'a b a')!;
      expect(cls.isSet, isTrue);
      expect(cls.isCollection, isTrue);
      expect(cls.isList, isFalse);
      expect(cls.values, equals(['a', 'b']));
      expect(cls.valueLength, equals(2));

      var style = DOMAttribute.from('Style', 'color: red')!;
      expect(style.name, equals('style'));
      expect(style.valueHandler, isA<DOMAttributeValueCSS>());
      expect(style.isCollection, isTrue);
      expect(style.buildHTML(), equals('style="color: red"'));

      var str = DOMAttribute.from('title', 'x')!;
      expect(str.valueHandler, isA<DOMAttributeValueString>());
      expect(str.isCollection, isFalse);

      var checkedEmpty = DOMAttribute.from('checked', '')!;
      expect(checkedEmpty.isBoolean, isTrue);
      expect(checkedEmpty.hasValue, isTrue);

      var onlyContent = DOMAttribute.from('title', '{{')!;
      expect(onlyContent.valueHandler, isNot(isA<DOMAttributeValueTemplate>()));
    });

    test('buildHTML quoting and empty value', () {
      expect(
        DOMAttribute.from('title', 'say "hi"')!.buildHTML(),
        equals("title='say \"hi\"'"),
      );
      expect(DOMAttribute.from('title', 'x')!.buildHTML(), equals('title="x"'));
      expect(DOMAttribute.from('title', '')!.buildHTML(), isEmpty);
      expect(DOMAttribute.from('checked', false)!.buildHTML(), isEmpty);
      expect(
        DOMAttribute.from('checked', true)!.buildHTML(),
        equals('checked'),
      );
    });

    test('value accessors, containsValue and toString', () {
      var attr = DOMAttribute.from('title', 'hello world')!;
      expect(attr.value, equals('hello world'));
      expect(attr.getValue(), equals('hello world'));
      expect(attr.valueLength, equals(11));
      expect(attr.containsValue('world'), isTrue);
      expect(attr.containsValue('xyz'), isFalse);
      expect(attr.toString(), equals('hello world'));
      expect(DOMAttribute.from('title', '')!.toString(), isEmpty);
    });

    test('setBoolean / setValue / appendValue', () {
      var checked = DOMAttribute.from('checked', true)!;
      checked.setBoolean(false);
      expect(checked.hasValue, isFalse);
      checked.setBoolean('true');
      expect(checked.hasValue, isTrue);

      var title = DOMAttribute.from('title', 'a')!;
      expect(() => title.setBoolean(true), throwsStateError);
      title.setValue('b');
      expect(title.value, equals('b'));
      title.appendValue('c');
      expect(title.value, equals('c'));

      var cls = DOMAttribute.from('class', 'a')!;
      cls.appendValue('b');
      expect(cls.value, equals('a b'));
      expect(cls.buildHTML(), equals('class="a b"'));
    });

    test('template attribute', () {
      var attr = DOMAttribute.from('title', 'Hi {{name}}')!;
      expect(attr.valueHandler, isA<DOMAttributeValueTemplate>());

      var ctx = DOMContext(variables: {'name': 'Joe'});
      expect(attr.getValue(ctx), equals('Hi Joe'));
      expect(attr.buildHTML(), equals('title="Hi {{name}}"'));
      expect(
        attr.buildHTML(
          domContext: ctx,
          dsxResolution: DSXResolution.lifecycleManager(null),
        ),
        equals('title="Hi Joe"'),
      );

      // A template resolving to HTML only keeps the text:
      var html = DOMAttribute.from('title', '{{v}}')!;
      var ctxHtml = DOMContext(variables: {'v': '<b>bold</b> text'});
      expect(
        html.buildHTML(
          domContext: ctxHtml,
          dsxResolution: DSXResolution.lifecycleManager(null),
        ),
        equals('title="bold text"'),
      );
    });
  });

  group('DOMAttributeValueBoolean', () {
    test('value API', () {
      var v = DOMAttributeValueBoolean('yes');
      expect(v.hasAttributeValue, isTrue);
      expect(v.length, equals(1));
      expect(v.asAttributeValue, equals('true'));
      expect(v.asAttributeValues, equals(['true']));
      expect(v.equalsAttributeValue(true), isTrue);
      expect(v.containsAttributeValue('true'), isTrue);
      expect(v.containsAttributeValue(false), isFalse);
      v.setAttributeValue(null);
      expect(v.hasAttributeValue, isFalse);
      expect(v.toString(), equals('DOMAttributeValueBoolean{_value: false}'));
    });
  });

  group('DOMAttributeValueString', () {
    test('value API', () {
      var v = DOMAttributeValueString('abc');
      expect(v.length, equals(3));
      expect(v.asAttributeValues, equals(['abc']));
      expect(v.equalsAttributeValue('abc'), isTrue);
      expect(v.equalsAttributeValue(null), isFalse);
      expect(v.containsAttributeValue('b'), isTrue);
      expect(v.containsAttributeValue(RegExp(r'^a')), isTrue);
      expect(v.containsAttributeValue(null), isFalse);
      expect(v.toString(), equals('DOMAttributeValueString{_value: abc}'));

      v.setAttributeValue(null);
      expect(v.hasAttributeValue, isFalse);
      expect(v.length, equals(0));
      expect(v.asAttributeValue, isNull);
      expect(v.asAttributeValues, isNull);
      expect(v.equalsAttributeValue(null), isTrue);
      expect(v.containsAttributeValue('a'), isFalse);
    });
  });

  group('DOMAttributeValueTemplate', () {
    test('getAttributeValue with and without context', () {
      var v = DOMAttributeValueTemplate('{{a}}-{{b}}');
      expect(v.getAttributeValue(), equals('{{a}}-{{b}}'));
      expect(
        v.getAttributeValue(DOMContext(variables: {'a': 1, 'b': 2})),
        equals('1-2'),
      );
    });

    test('an emptied template has no value and builds empty', () {
      var v = DOMAttributeValueTemplate('{{a}}');
      v.setAttributeValue('');
      expect(v.asAttributeValue, isNull);
      expect(v.getAttributeValue(DOMContext(variables: {'a': 1})), isEmpty);
    });

    test('a query block is resolved through the tree map', () {
      var root = $div(
        content: [$span(id: 'foo', content: 'FOO')],
      );
      var treeMap = TestGenerator().generateMapped(root);

      var v = DOMAttributeValueTemplate('x-{{#foo}}');
      expect(v.getAttributeValue(DOMContext(), treeMap), equals('x-FOO'));
    });

    test(
      'a query block without a tree map resolves to nothing',
      () {
        var v = DOMAttributeValueTemplate('x-{{#foo}}');
        expect(v.getAttributeValue(DOMContext()), equals('x-'));
      },
      skip:
          'Bug: without a treeMap the elementProvider returns null and '
          'DOMTemplateBlockQuery.build applies `!` to it (TypeError).',
    );

    test('setAttributeValue re-parses the template', () {
      var v = DOMAttributeValueTemplate('{{a}}');
      v.setAttributeValue('x{{b}}');
      expect(v.asAttributeValue, equals('x{{b}}'));
      expect(
        v.getAttributeValue(DOMContext(variables: {'b': 'Y'})),
        equals('xY'),
      );
      expect(v.toString(), startsWith('DOMAttributeValueTemplate{template: '));
    });
  });

  group('DOMAttributeValueList', () {
    DOMAttributeValueList list(Object? v) =>
        DOMAttributeValueList(v, '; ', RegExp(r'\s*;\s*'));

    test('hasAttributeValue / asAttributeValue', () {
      expect(list(null).hasAttributeValue, isFalse);
      expect(list(null).asAttributeValue, isNull);
      expect(list(null).asAttributeValues, isNull);
      expect(list('a').asAttributeValue, equals('a'));
      expect(list('a;b').hasAttributeValue, isTrue);
      expect(list('a;b').asAttributeValue, equals('a; b'));
      expect(list('a;b').asAttributeValues, equals(['a', 'b']));
      expect(list('a;b').length, equals(2));
    });

    test('setAttributeValue / appendAttributeValue', () {
      var v = list('a');
      v.setAttributeValue('z');
      expect(v.asAttributeValues, equals(['z']));
      v.setAttributeValue('x;y');
      expect(v.asAttributeValues, equals(['x', 'y']));
      v.appendAttributeValue('w');
      v.appendAttributeValue(null);
      expect(v.asAttributeValue, equals('x; y; w'));
      v.setAttributeValue('');
      expect(v.hasAttributeValue, isFalse);
    });

    test('equals / contains', () {
      var v = list('a;b');
      expect(v.equalsAttributeValue('a; b'), isTrue);
      expect(v.equalsAttributeValue('b; a'), isFalse);
      expect(v.equalsAttributeValue(null), isFalse);
      expect(list(null).equalsAttributeValue(null), isTrue);
      expect(list(null).equalsAttributeValue('a'), isFalse);

      expect(v.containsAttributeValue('b'), isTrue);
      expect(v.containsAttributeValue('a;b'), isTrue);
      expect(v.containsAttributeValue('a;c'), isFalse);
      expect(v.containsAttributeValue(''), isFalse);
      expect(v.containsAttributeValue(null), isFalse);
      expect(list(null).containsAttributeValue('a'), isFalse);

      expect(v.containsAttributeValueEntry('a'), isTrue);
      expect(v.containsAttributeValueEntry('c'), isFalse);
      expect(v.containsAttributeValueEntry(null), isFalse);
      expect(list(null).containsAttributeValueEntry('a'), isFalse);
    });

    test('get / remove entries', () {
      var v = list('a;b;c');
      expect(v.getAttributeValueEntry('b'), equals('b'));
      expect(v.getAttributeValueEntry('z'), isNull);
      expect(v.getAttributeValueEntry(null), isNull);

      expect(v.removeAttributeValueEntry('b'), equals('b'));
      expect(v.removeAttributeValueEntry('z'), isNull);
      expect(v.removeAttributeValueEntry(null), isNull);
      expect(v.asAttributeValues, equals(['a', 'c']));

      v.removeAttributeValueAllEntries(['a', 'c']);
      expect(v.hasAttributeValue, isFalse);
      v.removeAttributeValueAllEntries(['a']);
      expect(v.length, equals(0));
    });

    test('toString', () {
      expect(
        list('a').toString(),
        startsWith('DOMAttributeValueList{_values: [a], delimiter: ; '),
      );
    });
  });

  group('DOMAttributeValueSet', () {
    DOMAttributeValueSet set(Object? v) =>
        DOMAttributeValueSet(v, ' ', RegExp(r'\s+'));

    test('value API', () {
      expect(set(null).hasAttributeValue, isFalse);
      expect(set(null).asAttributeValue, isNull);
      expect(set(null).asAttributeValues, isNull);
      var v = set('a b a');
      expect(v.length, equals(2));
      expect(v.asAttributeValue, equals('a b'));
      expect(v.asAttributeValues, equals(['a', 'b']));

      v.setAttributeValue('x y x');
      expect(v.asAttributeValues, equals(['x', 'y']));
      v.appendAttributeValue('z');
      v.appendAttributeValue(null);
      expect(v.asAttributeValue, equals('x y z'));
      v.setAttributeValue(null);
      expect(v.hasAttributeValue, isFalse);
    });

    test('equals / contains / entries', () {
      var v = set('a b c');
      expect(v.equalsAttributeValue('a  b c'), isTrue);
      expect(v.equalsAttributeValue('a b'), isFalse);
      expect(v.equalsAttributeValue(null), isFalse);
      expect(set(null).equalsAttributeValue(null), isTrue);

      expect(v.containsAttributeValue('a c'), isTrue);
      expect(v.containsAttributeValue('a z'), isFalse);
      expect(v.containsAttributeValue(null), isFalse);

      expect(v.containsAttributeValueEntry('b'), isTrue);
      expect(v.containsAttributeValueEntry(null), isFalse);
      expect(v.getAttributeValueEntry('b'), equals('b'));
      expect(v.getAttributeValueEntry('z'), isNull);
      expect(v.getAttributeValueEntry(null), isNull);

      expect(v.removeAttributeValueEntry('b'), equals('b'));
      expect(v.removeAttributeValueEntry('b'), isNull);
      expect(v.removeAttributeValueEntry(null), isNull);
      expect(v.asAttributeValue, equals('a c'));
    });

    test(
      'equalsAttributeValue ignores order',
      () {
        expect(set('a b c').equalsAttributeValue('c b a'), isTrue);
      },
      skip:
          'Bug: `isEqualsSet` (swiss_knife) compares iteration order, so a '
          'set-valued attribute (`class`) is order-sensitive.',
    );

    test('toString', () {
      expect(
        set('a').toString(),
        startsWith('DOMAttributeValueSet{_values: {a}, delimiter:  '),
      );
    });
  });

  group('DOMAttributeValueCSS', () {
    test('value API', () {
      var v = DOMAttributeValueCSS('color: red');
      expect(v.length, equals(1));
      expect(v.asAttributeValue, equals('color: red'));
      expect(v.asAttributeValues, equals(['color: red']));
      expect(v.getAttributeValue(), equals('color: red'));
      expect(v.toString(), equals('DOMAttributeValueCSS{_css: color: red}'));

      var empty = DOMAttributeValueCSS(null);
      expect(empty.hasAttributeValue, isFalse);
      expect(empty.asAttributeValue, isNull);
      expect(empty.getAttributeValue(), isNull);
    });

    test('set / append', () {
      var v = DOMAttributeValueCSS('color: red');
      v.setAttributeValue('width: 10px');
      expect(v.asAttributeValue, equals('width: 10px'));
      v.appendAttributeValue(null);
      v.appendAttributeValue('');
      expect(v.length, equals(1));
      v.appendAttributeValue('height: 5px');
      expect(v.asAttributeValue, equals('width: 10px; height: 5px'));
    });

    test('equals / contains', () {
      var v = DOMAttributeValueCSS('color: red; width: 10px');
      expect(v.equalsAttributeValue('color: red; width: 10px'), isTrue);
      expect(v.equalsAttributeValue('color: blue'), isFalse);
      expect(v.equalsAttributeValue(null), isFalse);
      expect(DOMAttributeValueCSS(null).equalsAttributeValue(null), isTrue);

      expect(v.containsAttributeValue('color: red'), isTrue);
      expect(v.containsAttributeValue('color: blue'), isFalse);
      expect(v.containsAttributeValue(''), isFalse);
      expect(v.containsAttributeValue(null), isFalse);
      expect(
        DOMAttributeValueCSS(null).containsAttributeValue('color: red'),
        isFalse,
      );
    });

    test('entries', () {
      var v = DOMAttributeValueCSS('color: red; width: 10px');
      expect(v.containsAttributeValueEntry('color: red'), isTrue);
      expect(v.containsAttributeValueEntry('color: blue'), isFalse);
      expect(v.containsAttributeValueEntry(null), isFalse);
      expect(v.getAttributeValueEntry('color'), equals('color: red'));
      expect(v.getAttributeValueEntry(null), isNull);
      expect(v.removeAttributeValueEntry('color: blue'), isNull);
      expect(v.removeAttributeValueEntry(null), isNull);
      expect(v.removeAttributeValueEntry('color: red'), equals('color: red'));
      expect(v.asAttributeValue, equals('width: 10px'));
    });
  });
}
