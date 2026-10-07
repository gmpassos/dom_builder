@TestOn('vm')
library;

import 'package:dom_builder/dom_builder.dart';
import 'package:test/test.dart';

/// A minimal [CSSValue] that does not override `toString`/`==`, used to
/// exercise the base-class behaviour.
class _PlainValue extends CSSValue {
  _PlainValue() : super();

  _PlainValue.fn(CSSFunction super.f) : super.fromFunction();
}

/// A minimal [CSSColor] that is not a [CSSColorRGB], used to exercise the
/// base-class `inverse`/`hasAlpha`.
class _FakeColor extends CSSColor {
  @override
  String get args => '1, 2, 3';

  @override
  String get argsNoAlpha => '1, 2, 3';

  @override
  CSSColorRGB get asCSSColorRGB => CSSColorRGB(1, 2, 3);

  @override
  CSSColorRGBA get asCSSColorRGBA => CSSColorRGBA(1, 2, 3, 1.0);

  @override
  CSSColorHEX get asCSSColorHEX => CSSColorHEX.fromRGB(1, 2, 3);
}

DOMContext _viewportContext() => DOMContext(
  resolveCSSViewportUnit: true,
  viewport: Viewport(800, 600, 810, 610),
);

void main() {
  group('CSS construction', () {
    test('factory accepts null, CSS, String and List', () {
      expect(CSS().isEmpty, isTrue);
      expect(CSS(null).length, equals(0));

      var css = CSS('color: red');
      expect(identical(CSS(css), css), isTrue);

      expect(CSS('').isEmpty, isTrue);

      var fromList = CSS(['color: red', 'width: 10px']);
      expect(fromList.toString(), equals('color: red; width: 10px'));
      expect(CSS(<String>[]).isEmpty, isTrue);
    });

    test('factory rejects unsupported types', () {
      expect(() => CSS(123), throwsStateError);
    });

    test('parse skips entries without a name/value delimiter', () {
      var css = CSS.parse('color red; width: 1px')!;
      expect(css.length, equals(1));
      expect(css.toString(), equals('width: 1px'));
    });

    test('static delimiters', () {
      expect('a ; b;c'.split(CSS.entriesDelimiter), equals(['a', 'b', 'c']));
      expect('a : b'.split(CSSEntry.pairDelimiter), equals(['a', 'b']));
    });
  });

  group('CSS parsing of comments, quotes and slashes', () {
    test('leading comment attached to the following entry', () {
      var css = CSS('/* c */ color: red; width: 10px');
      expect(css.toString(), equals('color: red/* c */; width: 10px'));
    });

    test('trailing comment with no final semicolon', () {
      var css = CSS('color: red /* c */');
      expect(css.toString(), equals('color: red/* c */'));
    });

    test('unclosed comment after a closed comment', () {
      var css = CSS('width: 10px /* a */ /* unclosed');
      expect(css.toString(), equals('width: 10px/* a */'));
    });

    test('unclosed comment without previous comment', () {
      var css = CSS('color: red; width: 1px /* unclosed');
      expect(css.toString(), equals('color: red; width: 1px'));
    });

    test('a slash that is not a comment', () {
      var css = CSS('background: url(a/b.png)');
      expect(css.toString(), equals('background: url("a/b.png")'));
    });

    test('unclosed quote with a preceding comment', () {
      var css = CSS('/* c */ content: "abc');
      expect(css.toString(), equals('content: "abc/* c */'));
    });

    test('quoted semicolon is kept inside the value', () {
      var css = CSS('content: "a;b"');
      expect(css.length, equals(1));
      expect(css.toString(), equals('content: "a;b"'));

      expect(CSS("content: 'x;y'").toString(), equals("content: 'x;y'"));
    });

    test('closed quote at the end with a preceding comment', () {
      var css = CSS('/* c */ content: "x"');
      expect(css.toString(), equals('content: "x"/* c */'));
    });

    test('dangling comment at the end is dropped', () {
      var css = CSS('color: red; /* trailing */');
      expect(css.toString(), equals('color: red'));
    });
  });

  group('CSS entries manipulation', () {
    test('equality, hashCode and copy', () {
      var a = CSS('color: red; width: 10px');
      var b = CSS('color: red; width: 10px');
      var c = CSS('color: blue; width: 10px');

      expect(a == b, isTrue);
      expect(a.hashCode, equals(b.hashCode));
      expect(a == c, isFalse);

      var copy = a.copy();
      expect(identical(copy, a), isFalse);
      expect(copy, equals(a));
      expect(copy.style, equals('color: red; width: 10px'));
    });

    test('isEmpty / isNoEmpty / length', () {
      var css = CSS();
      expect(css.isEmpty, isTrue);
      expect(css.isNoEmpty, isFalse);

      css.put('width', '1px');
      expect(css.isEmpty, isFalse);
      expect(css.isNoEmpty, isTrue);
      expect(css.length, equals(1));
    });

    test('put dispatches known properties to typed values', () {
      var css = CSS();
      css.put('Color ', 'red');
      css.put('background-color', '#fff');
      css.put('background', 'url(a.png)');
      css.put('width', '10px');
      css.put('height', '20%');
      css.put('border', '1px solid red');
      css.put('opacity', '0.5');
      css.put('display', 'none');
      css.put('margin', '4px');

      expect(css.color!.value, isA<CSSColorName>());
      expect(css.backgroundColor!.value, isA<CSSColorHEX>());
      expect(css.background!.value, isA<CSSBackground>());
      expect(css.width!.value, equals(CSSLength(10)));
      expect(css.height!.value, equals(CSSLength(20, CSSUnit.percent)));
      expect(css.border!.value, isA<CSSBorder>());
      expect(css.opacity!.value, equals(CSSNumber(0.5)));
      expect(css.display!.value, equals(CSSGeneric('none')));
      expect(css.get<CSSGeneric>('margin'), equals(CSSGeneric('4px')));

      expect(
        css.toString(),
        equals(
          'color: red; background-color: #ffffff; '
          'background: url("a.png"); width: 10px; height: 20%; '
          'border: 1px solid red; opacity: 0.5; display: none; margin: 4px',
        ),
      );

      expect(
        css.entriesAsString,
        equals([
          'color: red',
          'background-color: #ffffff',
          'background: url("a.png")',
          'width: 10px',
          'height: 20%',
          'border: 1px solid red',
          'opacity: 0.5',
          'display: none',
          'margin: 4px',
        ]),
      );
      expect(css.entries.length, equals(9));
    });

    test('put with a CSSEntry for a generic property', () {
      var css = CSS();
      css.put('padding', CSSEntry('padding', CSSGeneric('2px 3px')));
      expect(css.getAsString('padding'), equals('2px 3px'));
    });

    test('put with an unparseable generic value throws', () {
      var css = CSS();
      expect(() => css.put('margin', 123), throwsStateError);
    });

    test(
      'put with an unparseable typed value does not throw a TypeError',
      () {
        var css = CSS();
        css.put('color', 'not-a-color');
        expect(css.color, isNull);
      },
      skip:
          'Bug: CSSEntry.from casts the null parse result with `as V` '
          '(non-nullable), throwing a TypeError',
    );

    test('put null removes the entry', () {
      var css = CSS('color: red; margin: 1px');
      css.put('margin', null);
      expect(css.toString(), equals('color: red'));
      css['color'] = null;
      expect(css.isEmpty, isTrue);
    });

    test('putIfAbsent / putEntryIfAbsent keep existing values', () {
      var css = CSS('margin: 1px');
      css.putIfAbsent('margin', '2px');
      css.putIfAbsent('padding', '3px');
      expect(css.toString(), equals('margin: 1px; padding: 3px'));

      css.putAllIfAbsent([
        CSSEntry('margin', CSSGeneric('9px')),
        CSSEntry('top', CSSGeneric('0')),
      ]);
      css.putAllIfAbsent([]);
      expect(css.toString(), equals('margin: 1px; padding: 3px; top: 0'));
    });

    test('putAll / putAllProperties', () {
      var css = CSS();
      css.putAll([]);
      css.putAllProperties({});
      expect(css.isEmpty, isTrue);

      css.putAll([CSSEntry('top', CSSGeneric('1px'))]);
      css.putAllProperties({'left': '2px', 'color': 'blue'});
      expect(css.toString(), equals('top: 1px; left: 2px; color: blue'));
    });

    test('operator [] and []=', () {
      var css = CSS();
      css['width'] = '5px';
      expect(css['width'], equals(CSSLength(5)));
      expect(css['missing'], isNull);
    });

    test('removeEntry / containsEntry / getEntry / get', () {
      var css = CSS('width: 5px; margin: 1px');

      expect(css.containsEntry(CSSEntry('width', CSSLength(5))), isTrue);
      expect(css.containsEntry(CSSEntry('width', CSSLength(6))), isFalse);
      expect(css.containsEntry(CSSEntry('height', CSSLength(5))), isFalse);

      expect(css.getEntry('margin')!.valueAsString, equals('1px'));
      expect(css.get('nope'), isNull);
      expect(css.getAsString('nope'), isNull);

      var removed = css.removeEntry('margin');
      expect(removed!.name, equals('margin'));
      expect(css.removeEntry('margin'), isNull);
      expect(css.toString(), equals('width: 5px'));
    });

    test('typed setters remove the entry for unsupported values', () {
      var css = CSS('color: red; width: 1px');
      css.color = 123;
      expect(css.color, isNull);

      css.width = CSSEntry<CSSLength>('width', null);
      expect(css.width, isNull);
      expect(css.isEmpty, isTrue);
    });

    test('getPossibleEntries', () {
      var css = CSS('color: red; margin: 1px');
      var possible = css.getPossibleEntries();

      expect(
        possible.map((e) => e.name).toList(),
        equals([
          'color',
          'background-color',
          'width',
          'height',
          'border',
          'opacity',
          'display',
          'margin',
        ]),
      );

      var color = possible.first;
      expect(color.valueAsString, equals('red'));
      expect(color.sampleValueAsString, equals('#000000'));

      var width = possible[2];
      expect(width.valueAsString, equals('auto'));
      expect(width.sampleValueAsString, equals('1px'));

      var margin = possible.last;
      expect(margin.valueAsString, equals('1px'));
      expect(margin.sampleValueAsString, equals(''));
    });

    test('toString with a DOMContext resolving URLs', () {
      var ctx = DOMContext<Object>(resolveCSSURL: true)
        ..cssURLResolver = (u) => 'https://cdn.example/$u';
      var css = CSS('background: url(a.png)');
      expect(
        css.toString(ctx),
        equals('background: url("https://cdn.example/a.png")'),
      );
    });
  });

  group('CSSEntry', () {
    test('name is normalized', () {
      var e = CSSEntry(' Margin ', CSSGeneric('1px'));
      expect(e.name, equals('margin'));
      expect(CSSEntry.normalizeName(null), isNull);
    });

    test('toString with delimiter and comments', () {
      var e = CSSEntry('margin', CSSGeneric('1px'), comment: 'note');
      expect(e.toString(), equals('margin: 1px/*note*/'));
      expect(e.toString(true), equals('margin: 1px/*note*/;'));

      var e2 = CSSEntry('margin', CSSGeneric('1px'), comment: '/* ok */');
      expect(e2.toString(), equals('margin: 1px/* ok */'));
    });

    test('null value renders as initial', () {
      var e = CSSEntry<CSSGeneric>('margin', null);
      expect(e.toString(), equals('margin: initial'));
      expect(e.valueAsString, equals(''));
      expect(e.sampleValueAsString, equals(''));
    });

    test('equality and hashCode', () {
      var a = CSSEntry('margin', CSSGeneric('1px'));
      var b = CSSEntry('margin', CSSGeneric('1px'));
      var c = CSSEntry('padding', CSSGeneric('1px'));
      expect(a, equals(b));
      expect(a.hashCode, equals(b.hashCode));
      expect(a == c, isFalse);
    });

    test('from', () {
      expect(CSSEntry.from('margin', null), isNull);
      expect(CSSEntry.from('margin', 42), isNull);

      var src = CSSEntry('margin', CSSGeneric('1px'), comment: 'c');
      var copy = CSSEntry.from<CSSGeneric>('padding', src)!;
      expect(copy.toString(), equals('padding: 1px/*c*/'));

      var copy2 = CSSEntry.from<CSSGeneric>('padding', src, 'other')!;
      expect(copy2.toString(), equals('padding: 1px/*other*/'));

      var fromValue = CSSEntry.from<CSSLength>('width', CSSLength(3));
      expect(fromValue.toString(), equals('width: 3px'));
    });

    test('parse', () {
      expect(CSSEntry.parse('no-delimiter'), isNull);

      var e = CSSEntry.parse('Width:10px')!;
      expect(e.name, equals('width'));
      expect(e.value, equals(CSSLength(10)));

      var orig = CSSEntry.parse(
        'width: 640px',
        '/* DOMContext-original-value: 80vw */',
      )!;
      expect(orig.value, equals(CSSLength(80, CSSUnit.vw)));
      expect(orig.toString(), equals('width: 80vw'));

      var noEnd = CSSEntry.parse(
        'height: 300px',
        'DOMContext-original-value: 50vh',
      )!;
      expect(noEnd.toString(), equals('height: 50vh'));

      var empty = CSSEntry.parse(
        'height: 300px',
        '/* DOMContext-original-value: */',
      )!;
      expect(
        empty.toString(),
        equals('height: 300px/* DOMContext-original-value: */'),
      );
    });

    test(
      'whitespace before the colon is ignored',
      () {
        var e = CSSEntry.parse('width : 10px')!;
        expect(e.value, equals(CSSLength(10)));
        expect(CSS('width : 10px').toString(), equals('width: 10px'));
      },
      skip:
          'Bug: CSSEntry.parse takes the value from `idx + 1`, assuming the '
          'delimiter match is one char; with a space before ":" the value '
          'becomes ": 10px" and parses to null (`width: initial`)',
    );
  });

  group('CSSValue', () {
    test('from without a name tries each type in order', () {
      expect(CSSValue.from('5'), equals(CSSNumber(5)));
      expect(CSSValue.from('5px'), equals(CSSLength(5)));
      expect(CSSValue.from('red'), isA<CSSColorName>());
      expect(CSSValue.from('url(a.png)'), equals(CSSURL('a.png')));
      expect(CSSValue.from('auto'), equals(CSSGeneric('auto')));

      var calc = CSSCalc.parse('calc(1px + 2px)')!;
      expect(identical(CSSValue.from(calc), calc), isTrue);

      expect(CSSValue.from(5), isNull);
    });

    test('from with an empty name behaves like no name', () {
      expect(CSSValue.from('5', ''), equals(CSSNumber(5)));
    });

    test('parseByName', () {
      expect(CSSValue.parseByName('red', 'color'), isA<CSSColor>());
      expect(
        CSSValue.parseByName('#000', 'background-color').toString(),
        equals('#000000'),
      );
      expect(CSSValue.parseByName('#000', 'background'), isA<CSSBackground>());
      expect(CSSValue.parseByName('1px', 'width'), equals(CSSLength(1)));
      expect(
        CSSValue.parseByName('2em', 'height'),
        equals(CSSLength(2, CSSUnit.em)),
      );
      expect(
        CSSValue.parseByName('1px solid red', 'border').toString(),
        equals('1px solid red'),
      );
      expect(CSSValue.parseByName('0.3', 'opacity'), equals(CSSNumber(0.3)));
      expect(
        CSSValue.parseByName('block', 'display'),
        equals(CSSGeneric('block')),
      );
      expect(CSSValue.parseByName('4px', 'margin'), equals(CSSLength(4)));
    });

    test('base toString / equality / hashCode / calc getters', () {
      var plain = _PlainValue();
      expect(plain.toString(), equals(''));
      expect(plain.toStringCalc(), isNull);
      expect(plain.isFunction, isFalse);
      expect(plain.isCalc, isFalse);
      expect(plain.calc, isNull);
      expect(plain.function, isNull);
      expect(plain.hashCode, equals(0));
      expect(plain == _PlainValue(), isTrue);

      var calc = CSSCalc.parse('calc(1px + 2px)')!;
      var withCalc = _PlainValue.fn(calc);
      expect(withCalc.toString(), equals('calc(1px + 2px)'));
      expect(withCalc.isFunction, isTrue);
      expect(withCalc.isCalc, isTrue);
      expect(withCalc.calc, same(calc));
      expect(withCalc.hashCode, equals(calc.hashCode));
      expect(
        withCalc == _PlainValue.fn(CSSCalc.parse('calc(1px + 2px)')!),
        isTrue,
      );
      expect(withCalc == plain, isFalse);

      var withMax = _PlainValue.fn(CSSMax(['1px', '2px']));
      expect(withMax.isFunction, isTrue);
      expect(withMax.isCalc, isFalse);
      expect(withMax.calc, isNull);
      expect(withMax.toString(), equals('max(1px, 2px)'));
    });
  });

  group('calc operations', () {
    test('getCalcOperation', () {
      expect(getCalcOperation(null), isNull);
      expect(getCalcOperation('  '), isNull);
      expect(getCalcOperation(' + '), equals(CalcOperation.sum));
      expect(getCalcOperation('-'), equals(CalcOperation.subtract));
      expect(getCalcOperation('*'), equals(CalcOperation.multiply));
      expect(getCalcOperation('/'), equals(CalcOperation.divide));
      expect(getCalcOperation('%'), isNull);
    });

    test('getCalcOperationSymbol', () {
      expect(getCalcOperationSymbol(null), isNull);
      for (var op in CalcOperation.values) {
        expect(getCalcOperation(getCalcOperationSymbol(op)), equals(op));
      }
    });

    test('computeCalcOperationSymbol', () {
      expect(computeCalcOperationSymbol(CalcOperation.sum, 6, 3), equals(9));
      expect(
        computeCalcOperationSymbol(CalcOperation.subtract, 6, 3),
        equals(3),
      );
      expect(
        computeCalcOperationSymbol(CalcOperation.multiply, 6, 3),
        equals(18),
      );
      expect(computeCalcOperationSymbol(CalcOperation.divide, 6, 3), equals(2));
    });
  });

  group('CSSFunction', () {
    test('from', () {
      expect(CSSFunction.from(null), isNull);
      expect(CSSFunction.from(42), isNull);

      var calc = CSSCalc.parse('calc(1px)')!;
      var max = CSSMax(['1px']);
      var min = CSSMin(['1px']);
      expect(CSSFunction.from(calc), same(calc));
      expect(CSSFunction.from(max), same(max));
      expect(CSSFunction.from(min), same(min));

      expect(CSSFunction.from('max(1px, 2px)'), isA<CSSMax>());
      expect(CSSFunction.from('min(1px, 2px)'), isA<CSSMin>());
      expect(CSSFunction.from('calc(1px)'), isA<CSSCalc>());
      expect(CSSFunction.parse('clamp(1px, 2px, 3px)'), isNull);
    });

    test('computeValue', () {
      var calc = CSSCalc.parse('calc(1px + 2px)')!;
      expect(CSSFunction.computeValue(calc), equals(CSSLength(3)));

      var lenFn = CSSLength.fromFunction(CSSMax(['1px', '5px']));
      expect(CSSFunction.computeValue(lenFn), equals(CSSLength(5)));

      expect(CSSFunction.computeValue(CSSNumber(7)), equals(CSSNumber(7)));
      expect(
        CSSFunction.computeValue(CSSLength(2, CSSUnit.em)),
        equals(CSSLength(2, CSSUnit.em)),
      );
      expect(CSSFunction.computeValue(CSSGeneric('auto')), isNull);

      var resolved = CSSFunction.computeValue(
        CSSLength(50, CSSUnit.vw),
        _viewportContext(),
      );
      expect(resolved.toString(), equals('400px'));
    });
  });

  group('CSSCalc', () {
    test('from / parse', () {
      var calc = CSSCalc.parse('calc(1px)')!;
      expect(CSSCalc.from(null), isNull);
      expect(CSSCalc.from(calc), same(calc));
      expect(CSSCalc.from('calc(2px)')!.a, equals('2px'));
      expect(CSSCalc.from(1), isNull);

      expect(CSSCalc.parse(null), isNull);
      expect(CSSCalc.parse('   '), isNull);
      expect(CSSCalc.parse('foo(1px)'), isNull);

      var op = CSSCalc.parse('CALC(10PX + 5PX)')!;
      expect(op.a, equals('10px'));
      expect(op.operation, equals(CalcOperation.sum));
      expect(op.b, equals('5px'));
      expect(op.hasOperation, isTrue);
      expect(op.operationSymbol, equals('+'));
      expect(op.toString(), equals('calc(10px + 5px)'));

      var simple = CSSCalc.parse(' calc( 10px ) ')!;
      expect(simple.hasOperation, isFalse);
      expect(simple.operationSymbol, isNull);
      expect(simple.toString(), equals('calc(10px)'));
    });

    test('compute and computeUnit', () {
      CSSCalc c(String s) => CSSCalc.parse(s)!;

      expect(c('calc(10px + 5px)').compute(), equals(CSSLength(15)));
      expect(c('calc(10px + 5px)').computeUnit(), equals(CSSUnit.px));

      expect(c('calc(10px + 5%)').compute(), isNull);
      expect(c('calc(10px + 5%)').computeUnit(), isNull);

      expect(c('calc(2 * 3)').compute(), equals(CSSNumber(6)));
      expect(c('calc(10 / 4)').compute(), equals(CSSNumber(2.5)));
      expect(c('calc(2 * 3)').computeUnit(), isNull);

      expect(c('calc(10em)').compute(), equals(CSSLength(10, CSSUnit.em)));
      expect(c('calc(10em)').computeUnit(), equals(CSSUnit.em));
      expect(c('calc(10)').computeUnit(), isNull);

      expect(c('calc(auto)').compute(), isNull);
      expect(c('calc(auto)').computeUnit(), isNull);
      expect(c('calc(10px * auto)').compute(), isNull);
      expect(c('calc(10px * auto)').computeUnit(), isNull);
      expect(c('calc(10px + 2)').compute(), isNull);
    });

    test('equality and hashCode', () {
      var a = CSSCalc.parse('calc(1px + 2px)')!;
      var b = CSSCalc.withOperation('1px', CalcOperation.sum, '2px');
      var c = CSSCalc.simpleExpression('1px');
      expect(a, equals(b));
      expect(a.hashCode, equals(b.hashCode));
      expect(a == c, isFalse);
    });

    test(
      'leading negative number is not split as subtraction',
      () {
        var calc = CSSCalc.parse('calc(-10px)')!;
        expect(calc.hasOperation, isFalse);
        expect(calc.toString(), equals('calc(-10px)'));
      },
      skip:
          'Bug: patternExpressionOperation splits on the leading "-", '
          'producing `calc( - 10px)`',
    );

    test(
      'hyphenated identifiers are not split as subtraction',
      () {
        var calc = CSSCalc.parse('calc(var(--gap) * 2)')!;
        expect(calc.toString(), equals('calc(var(--gap) * 2)'));
      },
      skip:
          'Bug: patternExpressionOperation splits on the first "-" inside '
          '`var(--gap)`, producing `calc(var( - -gap) * 2)`',
    );
  });

  group('CSSMax / CSSMin', () {
    test('CSSMax from / parse / toString', () {
      expect(CSSMax(['a', ' ', ' b ']).args, equals(['a', 'b']));

      var max = CSSMax(['1px']);
      expect(CSSMax.from(null), isNull);
      expect(CSSMax.from(max), same(max));
      expect(CSSMax.from(1), isNull);
      expect(CSSMax.from('MAX(1px , 2px)')!.args, equals(['1px', '2px']));

      expect(CSSMax.parse(null), isNull);
      expect(CSSMax.parse(' '), isNull);
      expect(CSSMax.parse('min(1px)'), isNull);
      expect(CSSMax.parse('max()'), isNull);
      expect(CSSMax.parse('max(1px,2px)').toString(), equals('max(1px, 2px)'));
    });

    test('CSSMax compute / computeUnit', () {
      CSSMax m(String s) => CSSMax.parse(s)!;

      expect(m('max(1px, 3px, 2px)').compute(), equals(CSSLength(3)));
      expect(m('max(1px, 3px)').computeUnit(), equals(CSSUnit.px));
      expect(m('max(1, 3, 2)').compute(), equals(CSSNumber(3)));
      expect(m('max(1, 3)').computeUnit(), isNull);
      expect(m('max(1px, 2em)').compute(), isNull);
      expect(m('max(1px, 2em)').computeUnit(), isNull);
      expect(m('max(1px, auto)').compute(), isNull);
      expect(m('max(1px, auto)').computeUnit(), isNull);
      expect(m('max(calc(1px + 9px), 3px)').compute(), equals(CSSLength(10)));
    });

    test('CSSMax equality and hashCode', () {
      var a = CSSMax(['1px', '2px']);
      var b = CSSMax.parse('max(1px, 2px)')!;
      expect(a, equals(b));
      expect(a.hashCode, equals(b.hashCode));
      expect(a == CSSMax(['2px', '1px']), isFalse);
    });

    test('CSSMin from / parse / toString', () {
      expect(CSSMin(['a', ' ', ' b ']).args, equals(['a', 'b']));

      var min = CSSMin(['1px']);
      expect(CSSMin.from(null), isNull);
      expect(CSSMin.from(min), same(min));
      expect(CSSMin.from(1), isNull);
      expect(CSSMin.from('MIN(1px , 2px)')!.args, equals(['1px', '2px']));

      expect(CSSMin.parse(null), isNull);
      expect(CSSMin.parse(' '), isNull);
      expect(CSSMin.parse('max(1px)'), isNull);
      expect(CSSMin.parse('min()'), isNull);
      expect(CSSMin.parse('min(1px,2px)').toString(), equals('min(1px, 2px)'));
    });

    test('CSSMin compute / computeUnit', () {
      CSSMin m(String s) => CSSMin.parse(s)!;

      expect(m('min(3px, 1px, 2px)').compute(), equals(CSSLength(1)));
      expect(m('min(1px, 3px)').computeUnit(), equals(CSSUnit.px));
      expect(m('min(4, 3, 5)').compute(), equals(CSSNumber(3)));
      expect(m('min(1, 3)').computeUnit(), isNull);
      expect(m('min(1px, 2em)').compute(), isNull);
      expect(m('min(1px, 2em)').computeUnit(), isNull);
      expect(m('min(1px, auto)').compute(), isNull);
      expect(m('min(1px, auto)').computeUnit(), isNull);
    });

    test('CSSMin equality and hashCode', () {
      var a = CSSMin(['1px', '2px']);
      var b = CSSMin.parse('min(1px, 2px)')!;
      expect(a, equals(b));
      expect(a.hashCode, equals(b.hashCode));
      expect(a == CSSMin(['2px', '1px']), isFalse);
    });
  });

  group('CSSGeneric', () {
    test('from / parse / toString / equality', () {
      var g = CSSGeneric('auto');
      expect(CSSGeneric.from(null), isNull);
      expect(CSSGeneric.from(g), same(g));
      expect(CSSGeneric.from(1), isNull);
      expect(CSSGeneric.from(' inherit ')!.value, equals('inherit'));

      expect(CSSGeneric.parse(null), isNull);
      expect(CSSGeneric.parse('   '), isNull);

      expect(g.toString(), equals('auto'));
      expect(g, equals(CSSGeneric('auto')));
      expect(g.hashCode, equals(CSSGeneric('auto').hashCode));
      expect(g == CSSGeneric('none'), isFalse);
    });
  });

  group('CSSUnit', () {
    test('parseCSSUnit / getCSSUnitName round-trip', () {
      for (var unit in CSSUnit.values) {
        var name = getCSSUnitName(unit)!;
        expect(parseCSSUnit(name), equals(unit), reason: name);
        expect(parseCSSUnit(' ${name.toUpperCase()} '), equals(unit));
      }
      expect(getCSSUnitName(CSSUnit.percent), equals('%'));
      expect(getCSSUnitName(CSSUnit.inches), equals('inches'));
    });

    test('defaults', () {
      expect(parseCSSUnit(null), isNull);
      expect(parseCSSUnit(null, CSSUnit.em), equals(CSSUnit.em));
      expect(parseCSSUnit('  ', CSSUnit.pt), equals(CSSUnit.pt));
      expect(parseCSSUnit('furlong', CSSUnit.cm), equals(CSSUnit.cm));
      expect(parseCSSUnit('furlong'), isNull);

      expect(getCSSUnitName(null), isNull);
      expect(getCSSUnitName(null, CSSUnit.rem), equals('rem'));
    });

    test('isCSSViewportUnit', () {
      var viewport = CSSUnit.values.where(isCSSViewportUnit).toSet();
      expect(
        viewport,
        equals({CSSUnit.vw, CSSUnit.vh, CSSUnit.vmin, CSSUnit.vmax}),
      );
    });
  });

  group('CSSLength', () {
    test('from / parse', () {
      var l = CSSLength(1);
      expect(CSSLength.from(null), isNull);
      expect(CSSLength.from(l), same(l));
      expect(CSSLength.from(5), isNull);
      expect(CSSLength.from('12em'), equals(CSSLength(12, CSSUnit.em)));

      expect(CSSLength.parse(null), isNull);
      expect(CSSLength.parse('abc'), isNull);
      expect(CSSLength.parse('-.5em').toString(), equals('-0.5em'));
      expect(CSSLength.parse('1.5'), equals(CSSLength(1.5)));
    });

    test('from calc without operation unwraps a plain length', () {
      var l = CSSLength.from('calc(10px)')!;
      expect(l.isFunction, isFalse);
      expect(l, equals(CSSLength(10)));

      var l2 = CSSLength.from('calc(10.50px)')!;
      expect(l2.isFunction, isTrue);
      expect(l2.isCalc, isTrue);
      expect(l2.toString(), equals('10.5px'));
    });

    test('function-backed toString', () {
      expect(CSSLength.from('calc(2 * 3)').toString(), equals('6'));
      expect(
        CSSLength.from('calc(1px + 1em)').toString(),
        equals('calc(1px + 1em)'),
      );

      var fromCalc = CSSLength.fromCalc(CSSCalc.parse('calc(1px + 2px)')!);
      expect(fromCalc.isCalc, isTrue);
      expect(fromCalc.toString(), equals('3px'));
      expect(
        fromCalc.hashCode,
        equals(CSSCalc.parse('calc(1px + 2px)').hashCode),
      );

      var vw = CSSLength.fromCalc(CSSCalc.parse('calc(10vw + 10vw)')!);
      expect(
        vw.toString(_viewportContext()),
        equals('160px /* DOMContext-original-value: 20vw */'),
      );
    });

    test('isPx / isPercent', () {
      expect(CSSLength(1).isPx, isTrue);
      expect(CSSLength(1).isPercent, isFalse);
      expect(CSSLength(1, CSSUnit.percent).isPercent, isTrue);
    });

    test('valueToString / resolveValueAsString / resolveValue', () {
      expect(CSSLength.valueToString(2.0, CSSUnit.px), equals('2px'));
      expect(CSSLength.valueToString(2.5, CSSUnit.em), equals('2.5em'));
      expect(CSSLength.valueToString(3, CSSUnit.percent), equals('3%'));

      expect(
        CSSLength.resolveValueAsString(null, 10, CSSUnit.vw),
        equals('10vw'),
      );
      expect(
        CSSLength.resolveValueAsString(
          _viewportContext(),
          10,
          CSSUnit.vw,
          originalValueAsComment: false,
        ),
        equals('80px'),
      );

      expect(
        CSSLength.resolveValue(null, 10, CSSUnit.vh),
        equals(CSSLength(10, CSSUnit.vh)),
      );
      expect(
        CSSLength.resolveValue(_viewportContext(), 10, CSSUnit.vh).toString(),
        equals('60px'),
      );
      expect(
        CSSLength.resolveValue(_viewportContext(), 10, CSSUnit.em),
        equals(CSSLength(10, CSSUnit.em)),
      );
    });

    test('equality and hashCode', () {
      expect(CSSLength(1), equals(CSSLength(1, CSSUnit.px)));
      expect(CSSLength(1).hashCode, equals(CSSLength(1).hashCode));
      expect(CSSLength(1) == CSSLength(1, CSSUnit.em), isFalse);
      expect(CSSLength(1) == CSSLength(2), isFalse);
    });

    test(
      'lengths backed by different non-calc functions are not equal',
      () {
        var a = CSSLength.fromFunction(CSSMax(['1px', '2px']));
        var b = CSSLength.fromFunction(CSSMax(['3px', '4px']));
        expect(a == b, isFalse);
      },
      skip:
          'Bug: CSSLength.== compares `calc` (null for max/min) instead of '
          '`function`, so any two max()/min() lengths are equal',
    );
  });

  group('CSSNumber', () {
    test('constructors and value setter', () {
      expect(CSSNumber(null).value, equals(0));
      var n = CSSNumber(3);
      n.value = null;
      expect(n.value, equals(0));
      n.value = 4.5;
      expect(n.toString(), equals('4.5'));
      expect(CSSNumber(2.0).toString(), equals('2'));
    });

    test('from / parse', () {
      var n = CSSNumber(1);
      expect(CSSNumber.from(null), isNull);
      expect(CSSNumber.from(n), same(n));
      expect(CSSNumber.from(5), isNull);

      var unwrapped = CSSNumber.from('calc(5)')!;
      expect(unwrapped.isFunction, isFalse);
      expect(unwrapped, equals(CSSNumber(5)));

      var wrapped = CSSNumber.from('calc(5.50)')!;
      expect(wrapped.isFunction, isTrue);
      expect(wrapped.toString(), equals('calc(5.50)'));

      expect(CSSNumber.parse(null), isNull);
      expect(CSSNumber.parse('x'), isNull);
      expect(CSSNumber.parse('2.50'), equals(CSSNumber(2.5)));
      expect(CSSNumber.parse('-.25'), equals(CSSNumber(-0.25)));
    });

    test('fromCalc / fromFunction', () {
      var calc = CSSCalc.parse('calc(2 * 3)')!;
      var n = CSSNumber.fromCalc(calc);
      expect(n.isCalc, isTrue);
      expect(n.toString(), equals('calc(2 * 3)'));
      expect(n.hashCode, equals(calc.hashCode));
      expect(CSSFunction.computeValue(n), equals(CSSNumber(6)));

      var f = CSSNumber.fromFunction(CSSMin(['1', '2']));
      expect(f.toString(), equals('min(1, 2)'));
    });

    test('equality and hashCode', () {
      expect(CSSNumber(1), equals(CSSNumber(1)));
      expect(CSSNumber(1).hashCode, equals(CSSNumber(1).hashCode));
      expect(CSSNumber(1) == CSSNumber(2), isFalse);
    });

    test(
      'numbers backed by different non-calc functions are not equal',
      () {
        var a = CSSNumber.fromFunction(CSSMax(['1', '2']));
        var b = CSSNumber.fromFunction(CSSMin(['3', '4']));
        expect(a == b, isFalse);
      },
      skip:
          'Bug: CSSNumber.== compares `calc` (null for max/min) instead of '
          '`function`, so any two max()/min() numbers are equal',
    );
  });

  group('CSSColor', () {
    test('from list', () {
      expect(CSSColor.from([1, 2, 3]).toString(), equals('rgb(1, 2, 3)'));
      expect(
        CSSColor.from([1, 2, 3, 0.5]).toString(),
        equals('rgba(1, 2, 3, 0.5)'),
      );
      expect(CSSColor.from([1, 2]), isNull);
    });

    test('from map', () {
      expect(
        CSSColor.from({'r': 1, 'g': 2, 'b': 3}).toString(),
        equals('rgb(1, 2, 3)'),
      );
      expect(
        CSSColor.from({'Red': 10, 'Green': 20, 'Blue': 30}).toString(),
        equals('rgb(10, 20, 30)'),
      );
      expect(
        CSSColor.from({'r': 1, 'g': 2, 'b': 3, 'alpha': 0.25}).toString(),
        equals('rgba(1, 2, 3, 0.25)'),
      );
      expect(CSSColor.from({'r': 1}), isNull);
    });

    test('from instances and other types', () {
      var hex = CSSColorHEX('#123456');
      var rgb = CSSColorRGB(1, 2, 3);
      expect(CSSColor.from(null), isNull);
      expect(CSSColor.from(hex), same(hex));
      expect(CSSColor.from(rgb), same(rgb));
      expect(CSSColor.from(42), isNull);
      expect(CSSColor.parse(null), isNull);
    });

    test('rgba with alpha 1 parses as plain RGB', () {
      var c = CSSColor.parse('rgba(1, 2, 3, 1)')!;
      expect(c, isNot(isA<CSSColorRGBA>()));
      expect(c.toString(), equals('rgb(1, 2, 3)'));
    });

    test('base inverse / hasAlpha', () {
      var fake = _FakeColor();
      expect(fake.hasAlpha, isFalse);
      expect(fake.inverse.toString(), equals('rgb(254, 253, 252)'));
    });

    test('equality across representations', () {
      var name = CSSColorName('red');
      var rgb = CSSColorRGB(255, 0, 0);
      var hex = CSSColorHEX('#f00');
      expect(name == rgb, isTrue);
      expect(hex == rgb, isTrue);
      expect(name.hashCode, equals(hex.hashCode));
      expect(rgb == CSSColorRGBA(255, 0, 0, 0.5), isFalse);
    });
  });

  group('CSSColorRGB / CSSColorRGBA', () {
    test('RGB from / parse', () {
      var rgb = CSSColorRGB(1, 2, 3);
      expect(CSSColorRGB.from(null), isNull);
      expect(CSSColorRGB.from(rgb), same(rgb));
      expect(CSSColorRGB.from(1), isNull);
      expect(CSSColorRGB.from('rgb(4,5,6)').toString(), equals('rgb(4, 5, 6)'));
      expect(CSSColorRGB.parse('nope'), isNull);
      expect(CSSColorRGB.parse('rgba(1,2,3,0.5)'), isA<CSSColorRGBA>());
      expect(CSSColorRGB.parse('rgba(1,2,3,1)'), isNot(isA<CSSColorRGBA>()));
    });

    test('RGB components are clipped', () {
      var rgb = CSSColorRGB(300, -5, null);
      expect([rgb.red, rgb.green, rgb.blue], equals([255, 0, 0]));

      rgb.red = 10;
      rgb.green = 999;
      rgb.blue = -1;
      expect(rgb.toString(), equals('rgb(10, 255, 0)'));
    });

    test('RGB conversions', () {
      var rgb = CSSColorRGB(1, 2, 3);
      expect(rgb.inverse.toString(), equals('rgb(254, 253, 252)'));
      expect(rgb.args, equals('1, 2, 3'));
      expect(rgb.argsNoAlpha, equals('1, 2, 3'));
      expect(rgb.asCSSColorRGB, same(rgb));
      expect(rgb.asCSSColorRGBA.toString(), equals('rgb(1, 2, 3)'));
      expect(rgb.asCSSColorRGBA.alpha, equals(1));
      expect(rgb.asCSSColorHEX.toString(), equals('#010203'));
    });

    test('RGBA from / parse / alpha', () {
      var rgba = CSSColorRGBA.parse('rgba(1,2,3,0.5)')!;
      expect(rgba.alpha, equals(0.5));
      expect(CSSColorRGBA.from('rgba(1,2,3,0.25)')!.alpha, equals(0.25));

      expect(rgba.hasAlpha, isTrue);
      expect(rgba.args, equals('1, 2, 3, 0.5'));
      expect(rgba.argsWithoutAlpha, equals('1, 2, 3'));
      expect(rgba.argsNoAlpha, equals('1, 2, 3'));
      expect(rgba.asCSSColorRGBA, same(rgba));

      rgba.alpha = 0.12345;
      expect(rgba.alpha, equals(0.123));
      expect(rgba.toString(), equals('rgba(1, 2, 3, 0.123)'));

      rgba.alpha = 1.0;
      expect(rgba.hasAlpha, isFalse);
      expect(rgba.toString(), equals('rgb(1, 2, 3)'));
    });

    test(
      'RGBA alpha is clipped to [0, 1] and defaults to 1',
      () {
        expect(CSSColorRGBA(1, 2, 3, null).alpha, equals(1));
        expect(CSSColorRGBA(1, 2, 3, 2.0).alpha, equals(1));
        expect(CSSColorRGBA(1, 2, 3, -1.0).alpha, equals(0));
      },
      skip:
          'Bug: `_clip(alpha, 0, 1, 1) as double` returns the int bound/'
          'default on the VM, so the cast throws a TypeError',
    );
  });

  group('CSSColorHEX / CSSColorHEXAlpha', () {
    test('HEX construct / from / parse', () {
      expect(CSSColorHEX('#abc').toString(), equals('#aabbcc'));
      expect(CSSColorHEX.fromRGB(255, 0, 16).toString(), equals('#ff0010'));

      var hex = CSSColorHEX('#123456');
      expect(CSSColorHEX.from(null), isNull);
      expect(CSSColorHEX.from(hex), same(hex));
      expect(CSSColorHEX.from(1), isNull);
      expect(CSSColorHEX.from('#FFF').toString(), equals('#ffffff'));

      expect(CSSColorHEX.parse('#abcd'), isNull);
      expect(CSSColorHEX.parse('#abcde'), isNull);
      expect(CSSColorHEX.parse('red'), isNull);
      expect(CSSColor.parse('#abcd'), isNull);
    });

    test('HEX conversions', () {
      var hex = CSSColorHEX('#aabbcc');
      var inv = hex.inverse;
      expect(inv, isA<CSSColorHEX>());
      expect(inv.toString(), equals('#554433'));

      var rgb = hex.asCSSColorRGB;
      expect(rgb, isNot(isA<CSSColorHEX>()));
      expect(rgb.toString(), equals('rgb(170, 187, 204)'));
      expect(hex.asCSSColorHEX, same(hex));
    });

    test('HEXAlpha parse / toString / alpha', () {
      var c = CSSColorHEXAlpha('#ff000080');
      expect(c.alpha, equals(0.501));
      expect(c.hasAlpha, isTrue);
      expect(c.toString(), equals('#ff000080'));

      expect(
        CSSColorHEXAlpha.parse('#00ff0040')!.toString(),
        equals('#00ff0040'),
      );
      expect(CSSColorHEXAlpha.from('#0000ff80')!.blue, equals(255));

      var rgb = c.asCSSColorRGB;
      expect(rgb, isA<CSSColorRGBA>());
      expect(rgb.toString(), equals('rgba(255, 0, 0, 0.501)'));
      expect(c.asCSSColorRGBA.toString(), equals('rgba(255, 0, 0, 0.501)'));

      c.alpha = 1.0;
      expect(c.hasAlpha, isFalse);
      expect(c.toString(), equals('#ff0000'));
    });

    test('8-digit hex with full alpha prints as 6 digits', () {
      var c = CSSColor.parse('#112233ff')!;
      expect(c, isA<CSSColorHEXAlpha>());
      expect(c.hasAlpha, isFalse);
      expect(c.toString(), equals('#112233'));
    });
  });

  group('CSSColorName', () {
    test('construct / from / parse', () {
      var navy = CSSColorName('Navy');
      expect(navy.name, equals('navy'));
      expect(navy.toString(), equals('navy'));
      expect([navy.red, navy.green, navy.blue], equals([0, 0, 128]));
      expect(navy.hasAlpha, isFalse);

      expect(CSSColorName.from(null), isNull);
      expect(CSSColorName.from(navy), same(navy));
      expect(CSSColorName.from(1), isNull);
      expect(CSSColorName.from('red')!.name, equals('red'));
      expect(CSSColorName.parse('   '), isNull);
      expect(CSSColorName.parse('notacolor'), isNull);

      expect(CSSColorName.patternWord.hasMatch('ab'), isTrue);
      expect(CSSColorName.patternWord.hasMatch('a1'), isFalse);
    });

    test('transparent has zero alpha', () {
      var t = CSSColorName('transparent');
      expect(t.alpha, equals(0));
      expect(t.hasAlpha, isTrue);
      expect(t.asCSSColorRGBA.toString(), equals('rgba(0, 0, 0, 0.0)'));
    });

    test('alpha setter clips and defaults', () {
      var c = CSSColorName('red');
      expect(c.asCSSColorRGBA.toString(), equals('rgb(255, 0, 0)'));
      c.alpha = 0.5;
      expect(c.asCSSColorRGBA.toString(), equals('rgba(255, 0, 0, 0.5)'));
      c.alpha = null;
      expect(c.alpha, equals(1.0));
      c.alpha = 5.0;
      expect(c.alpha, equals(1.0));
      c.alpha = -5.0;
      expect(c.alpha, equals(0.0));
    });
  });

  group('CSSBorder', () {
    test('border style parse / name round-trip', () {
      for (var style in CSSBorderStyle.values) {
        var name = getCSSBorderStyleName(style)!;
        expect(parseCSSBorderStyle(' ${name.toUpperCase()} '), equals(style));
      }
      expect(parseCSSBorderStyle(null), isNull);
      expect(parseCSSBorderStyle('wavy'), isNull);
    });

    test('construct / from / parse / toString', () {
      expect(CSSBorder().style, equals(CSSBorderStyle.none));
      expect(CSSBorder().toString(), equals('none'));
      expect(
        CSSBorder(null, CSSBorderStyle.dashed, CSSColorName('red')).toString(),
        equals('dashed red'),
      );

      var b = CSSBorder(CSSLength(1));
      expect(CSSBorder.from(null), isNull);
      expect(CSSBorder.from(b), same(b));
      expect(CSSBorder.from(1), isNull);

      var parsed = CSSBorder.from('2px dotted #fff')!;
      expect(parsed.size, equals(CSSLength(2)));
      expect(parsed.style, equals(CSSBorderStyle.dotted));
      expect(parsed.color.toString(), equals('#ffffff'));

      expect(CSSBorder.parse(null), isNull);
      expect(CSSBorder.parse('thick wavy'), isNull);
      expect(CSSBorder.parse('solid').toString(), equals('solid'));
    });

    test(
      'borders with different values are not equal',
      () {
        expect(
          CSSBorder.parse('1px solid red') ==
              CSSBorder.parse('2px dotted blue'),
          isFalse,
        );
      },
      skip:
          'Bug: CSSBorder does not override ==, so CSSValue.== treats every '
          'CSSBorder as equal',
    );
  });

  group('CSSBackground enums', () {
    test('repeat parse / name round-trip', () {
      for (var r in CSSBackgroundRepeat.values) {
        var name = getCSSBackgroundRepeatName(r)!;
        expect(parseCSSBackgroundRepeat(' ${name.toUpperCase()} '), equals(r));
      }
      expect(parseCSSBackgroundRepeat('x'), isNull);
      expect(getCSSBackgroundRepeatName(null), isNull);
      expect(
        getCSSBackgroundRepeatName(CSSBackgroundRepeat.noRepeat),
        equals('no-repeat'),
      );
    });

    test('box parse / name round-trip', () {
      for (var b in CSSBackgroundBox.values) {
        var name = getCSSBackgroundBoxName(b)!;
        expect(parseCSSBackgroundBox(' ${name.toUpperCase()} '), equals(b));
      }
      expect(parseCSSBackgroundBox('x'), isNull);
      expect(getCSSBackgroundBoxName(null), isNull);
    });

    test('attachment parse / name round-trip', () {
      for (var a in CSSBackgroundAttachment.values) {
        var name = getCSSBackgroundAttachmentName(a)!;
        expect(
          parseCSSBackgroundAttachment(' ${name.toUpperCase()} '),
          equals(a),
        );
      }
      expect(parseCSSBackgroundAttachment('x'), isNull);
      expect(getCSSBackgroundAttachmentName(null), isNull);
    });
  });

  group('CSSBackgroundImage', () {
    test('gradient toString', () {
      var g = CSSBackgroundGradient('radial-gradient', ['red', 'blue']);
      expect(g.toString(), equals('radial-gradient(red, blue)'));
    });

    test('url with all properties', () {
      var img = CSSBackgroundImage.parse(
        'url(a.png) left top / cover no-repeat fixed padding-box content-box',
      )!;
      expect(img.url, equals(CSSURL('a.png')));
      expect(img.gradient, isNull);
      expect(img.position, equals('left top'));
      expect(img.size, equals('cover'));
      expect(img.repeat, equals(CSSBackgroundRepeat.noRepeat));
      expect(img.attachment, equals(CSSBackgroundAttachment.fixed));
      expect(img.origin, equals(CSSBackgroundBox.paddingBox));
      expect(img.clip, equals(CSSBackgroundBox.contentBox));
      expect(
        img.toString(),
        equals(
          'url("a.png") left top / cover no-repeat fixed '
          'padding-box content-box',
        ),
      );
    });

    test('gradient with properties', () {
      var img = CSSBackgroundImage.parse(
        'linear-gradient(red, blue) repeat-x local',
      )!;
      expect(img.url, isNull);
      expect(img.gradient!.type, equals('linear-gradient'));
      expect(img.gradient!.parameters, equals(['red', 'blue']));
      expect(img.repeat, equals(CSSBackgroundRepeat.repeatX));
      expect(img.attachment, equals(CSSBackgroundAttachment.local));
      expect(
        img.toString(),
        equals('linear-gradient(red, blue) repeat-x local'),
      );
    });

    test('from / parse failures / empty image', () {
      var img = CSSBackgroundImage.url(CSSURL('a.png'));
      expect(CSSBackgroundImage.from(null), isNull);
      expect(CSSBackgroundImage.from(img), same(img));
      expect(CSSBackgroundImage.from(1), isNull);
      expect(
        CSSBackgroundImage.from('url(b.png)')!.url,
        equals(CSSURL('b.png')),
      );

      expect(CSSBackgroundImage.parse(null), isNull);
      expect(CSSBackgroundImage.parse('nothing'), isNull);

      expect(CSSBackgroundImage.url(null).toString(), equals(''));
    });

    test('position without size, origin without clip', () {
      var img = CSSBackgroundImage.url(
        CSSURL('a.png'),
        position: 'center',
        size: '',
        origin: CSSBackgroundBox.borderBox,
      );
      expect(img.toString(), equals('url("a.png") center border-box'));
    });
  });

  group('CSSBackground', () {
    test('url / gradient constructors', () {
      var bg = CSSBackground.url(
        CSSURL('a.png'),
        repeat: CSSBackgroundRepeat.round,
        attachment: CSSBackgroundAttachment.scroll,
        position: '10px 20px',
        size: 'contain',
        origin: CSSBackgroundBox.contentBox,
        clip: CSSBackgroundBox.borderBox,
        color: CSSColorHEX('#000'),
      );
      expect(
        bg.toString(),
        equals(
          'url("a.png") 10px 20px / contain round scroll '
          'content-box border-box #000000',
        ),
      );

      var g = CSSBackground.gradient(
        CSSBackgroundGradient('linear-gradient', ['red', 'blue']),
        repeat: CSSBackgroundRepeat.space,
      );
      expect(g.toString(), equals('linear-gradient(red, blue) space'));
      expect(g.color, isNull);
    });

    test('from / parse', () {
      var bg = CSSBackground.color(CSSColorHEX('#fff'));
      expect(CSSBackground.from(null), isNull);
      expect(CSSBackground.from(bg), same(bg));
      expect(CSSBackground.from(1), isNull);
      expect(CSSBackground.from('#fff').toString(), equals('#ffffff'));

      var colorImage = CSSBackground.parse('#fff url(a.png)')!;
      expect(colorImage.color.toString(), equals('#ffffff'));
      expect(colorImage.firstImage!.url, equals(CSSURL('a.png')));
      expect(colorImage.toString(), equals('url("a.png") #ffffff'));

      var images = CSSBackground.parse('url(a.png), url(b.png) #000')!;
      expect(images.imagesLength, equals(2));
      expect(images.toString(), equals('url("a.png"), url("b.png") #000000'));

      expect(CSSBackground.parse('???'), isNull);
    });

    test('image accessors', () {
      var bg = CSSBackground.images([
        CSSBackgroundImage.url(CSSURL('a.png')),
        CSSBackgroundImage.url(CSSURL('b.png')),
      ]);
      expect(bg.hasImages, isTrue);
      expect(bg.imagesLength, equals(2));
      expect(bg.images.length, equals(2));
      expect(bg.firstImage!.url, equals(CSSURL('a.png')));
      expect(bg.getImage(1)!.url, equals(CSSURL('b.png')));

      var single = CSSBackground.image(CSSBackgroundImage.url(CSSURL('c')));
      expect(single.toString(), equals('url("c")'));

      var color = CSSBackground.color(CSSColorRGB(1, 2, 3));
      expect(color.hasImages, isFalse);
      expect(color.imagesLength, equals(0));
      expect(color.firstImage, isNull);
      expect(color.getImage(0), isNull);
      expect(color.toString(), equals('rgb(1, 2, 3)'));

      expect(CSSBackground.color(null).toString(), equals(''));
    });

    test(
      'named colors are accepted in the background shorthand',
      () {
        var css = CSS('background: red');
        expect(css.toString(), equals('background: red'));
      },
      skip:
          'Bug: the background dialect only knows rgb()/hex colors, so '
          '`background: red` parses to a null value and the entry is '
          'silently dropped (CSS renders as an empty string)',
    );
  });

  group('CSSURL', () {
    test('from / parse', () {
      var u = CSSURL('a.png');
      expect(CSSURL.from(null), isNull);
      expect(CSSURL.from(u), same(u));
      expect(CSSURL.from(1), isNull);
      expect(CSSURL.from("url('b.png')")!.url, equals('b.png'));
      expect(CSSURL.parse('url("c.png")')!.url, equals('c.png'));

      expect(CSSURL.parse(null), isNull);
      expect(CSSURL.parse('  '), isNull);
      expect(CSSURL.parse('a.png'), isNull);
    });

    test('toString picks a safe quote', () {
      expect(CSSURL('a.png').toString(), equals('url("a.png")'));
      expect(CSSURL('a"b').toString(), equals("url('a\"b')"));
      expect(CSSURL('a"b\'c').toString(), equals('url(a"b\'c)'));
    });

    test('toString resolves through the DOMContext', () {
      var ctx = DOMContext<Object>(resolveCSSURL: true)
        ..cssURLResolver = (u) => '/static/$u';
      expect(CSSURL('a.png').toString(ctx), equals('url("/static/a.png")'));

      var noResolver = DOMContext<Object>(resolveCSSURL: true);
      expect(CSSURL('a.png').toString(noResolver), equals('url("a.png")'));

      var disabled = DOMContext<Object>()..cssURLResolver = (u) => 'x';
      expect(CSSURL('a.png').toString(disabled), equals('url("a.png")'));
    });

    test('equality and hashCode', () {
      expect(CSSURL('a'), equals(CSSURL('a')));
      expect(CSSURL('a').hashCode, equals(CSSURL('a').hashCode));
      expect(CSSURL('a') == CSSURL('b'), isFalse);
    });
  });
}
