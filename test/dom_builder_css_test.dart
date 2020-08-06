import 'package:dom_builder/src/dom_builder_css.dart';
import 'package:test/test.dart';

void main() {
  group('CSS', () {
    setUp(() {});

    test('CSS construct 1', () {
      var css = CSS();
      expect(css.style, equals(''));

      css.color = CSSColorRGB(255, 0, 0);
      expect(css.style, equals('color: rgb(255, 0, 0)'));

      css.backgroundColor = CSSColorRGB(0, 255, 0);
      expect(css.style,
          equals('color: rgb(255, 0, 0); background-color: rgb(0, 255, 0)'));

      css.width = CSSLength(10, CSSUnit.px);
      expect(
          css.style,
          equals(
              'color: rgb(255, 0, 0); background-color: rgb(0, 255, 0); width: 10px'));
    });

    test('CSS construct 2', () {
      var css1 = CSS()
        ..color = CSSColorRGBA(255, 0, 0, 0.4)
        ..backgroundColor = '#ff0000'
        ..width = '1px'
        ..height = CSSLength(11, CSSUnit.px);

      print(css1);

      expect(
          css1.style,
          equals(
              'color: rgba(255, 0, 0, 0.4); background-color: #ff0000; width: 1px; height: 11px'));

      var css2 = CSS()
        ..width = '1px'
        ..height = CSSLength(11, CSSUnit.px)
        ..color = CSSColorRGBA(255, 0, 0, 0.4)
        ..backgroundColor = '#ff0000';

      print(css2);

      expect(
          css2.style,
          equals(
              'width: 1px; height: 11px; color: rgba(255, 0, 0, 0.4); background-color: #ff0000'));

      var css3 = CSS()
        ..color = CSSColorRGBA(255, 0, 0, 1)
        ..backgroundColor = '#ff0000ff';

      print(css3);

      expect(css3.style,
          equals('color: rgb(255, 0, 0, 1.0); background-color: #ff0000'));

      var css4 = CSS()
        ..color = CSSColorRGBA(255, 0, 0, 0.50)
        ..backgroundColor = '#ff000080';

      print(css4);

      expect(css4.style,
          equals('color: rgba(255, 0, 0, 0.5); background-color: #ff000080'));

      var css5 = CSS()
        ..width = '101'
        ..height = '0';

      print(css5);

      expect(css5.style, equals('width: 101px; height: 0px'));

      var css6 = CSS()..border = '10px solid #00ff00';

      print(css6);

      expect(css6.style, equals('border: 10px solid #00ff00'));
    });

    test('CSS parse 1', () {
      var css = CSS(
          'width: 10vw; height: 20%; color: rgb(255, 0, 0); background-color: rgba(0, 255, 0, 0.50);');
      expect(
          css.style,
          equals(
              'width: 10vw; height: 20%; color: rgb(255, 0, 0); background-color: rgba(0, 255, 0, 0.5)'));

      expect(css.color.name, equals('color'));
      var color = css.color.value as CSSColorRGB;
      expect(color.red, equals(255));
      expect(color.green, equals(0));
      expect(color.blue, equals(0));
      expect(color.toString(), equals('rgb(255, 0, 0)'));

      expect(css.backgroundColor.name, equals('background-color'));
      var backgroundColor = css.backgroundColor.value as CSSColorRGBA;
      expect(backgroundColor.red, equals(0));
      expect(backgroundColor.green, equals(255));
      expect(backgroundColor.blue, equals(0));
      expect(backgroundColor.alpha, equals(0.50));
      expect(backgroundColor.toString(), equals('rgba(0, 255, 0, 0.5)'));

      expect(css.width.name, equals('width'));
      var width = css.width.value;
      expect(width.value, equals(10));
      expect(width.unit, equals(CSSUnit.vw));

      expect(css.height.name, equals('height'));
      var height = css.height.value;
      expect(height.value, equals(20));
      expect(height.unit, equals(CSSUnit.percent));

      color.green = 128;
      color.blue = 200;

      width.unit = CSSUnit.percent;
      height.unit = CSSUnit.vh;

      expect(
          css.style,
          equals(
              'width: 10%; height: 20vh; color: rgb(255, 128, 200); background-color: rgba(0, 255, 0, 0.5)'));
    });

    test('CSS colors RGB', () {
      var css = CSS('color: rgb(255, 0, 0);');
      expect(css.style, equals('color: rgb(255, 0, 0)'));

      expect(css.color.name, equals('color'));
      var color = css.color.value as CSSColorRGB;
      expect(color.red, equals(255));
      expect(color.green, equals(0));
      expect(color.blue, equals(0));
      expect(color.hasAlpha, isFalse);
      expect(color.toString(), equals('rgb(255, 0, 0)'));

      color.green = 128;
      color.blue = 200;

      expect(css.style, equals('color: rgb(255, 128, 200)'));
    });

    test('CSS colors RGBA', () {
      var css = CSS('color: rgb(255, 0, 0, 0.21);');
      expect(css.style, equals('color: rgba(255, 0, 0, 0.21)'));

      expect(css.color.name, equals('color'));
      var color = css.color.value as CSSColorRGBA;
      expect(color.red, equals(255));
      expect(color.green, equals(0));
      expect(color.blue, equals(0));
      expect(color.hasAlpha, isTrue);
      expect(color.toString(), equals('rgba(255, 0, 0, 0.21)'));

      color.red = 0;
      color.green = 128;
      color.blue = 200;
      color.alpha = 0.75;

      expect(css.style, equals('color: rgba(0, 128, 200, 0.75)'));
    });

    test('CSS colors HEX 6', () {
      var css = CSS('color: #FF0000;');
      expect(css.style, equals('color: #ff0000'));

      expect(css.color.name, equals('color'));
      var color = css.color.value as CSSColorHEX;
      expect(color.red, equals(255));
      expect(color.green, equals(0));
      expect(color.blue, equals(0));
      expect(color.toString(), equals('#ff0000'));

      color.red = 0;
      color.green = 128;
      color.blue = 200;

      expect(css.style, equals('color: #0080c8'));
    });

    test('CSS colors HEX 3', () {
      var css = CSS('color: #FFF;');
      expect(css.style, equals('color: #ffffff'));

      expect(css.color.name, equals('color'));
      var color = css.color.value as CSSColorHEX;
      expect(color.red, equals(255));
      expect(color.green, equals(255));
      expect(color.blue, equals(255));
      expect(color.hasAlpha, isFalse);
      expect(color.toString(), equals('#ffffff'));

      color.green = 128;

      expect(css.style, equals('color: #ff80ff'));
    });

    test('CSS colors HEX 8', () {
      var css = CSS('color: #FF881180;');
      expect(css.style, equals('color: #ff881180'));

      expect(css.color.name, equals('color'));
      var color = css.color.value as CSSColorHEXAlpha;
      expect(color.red, equals(255));
      expect(color.green, equals(136));
      expect(color.blue, equals(17));
      expect(color.alpha, equals(0.501));
      expect(color.hasAlpha, isTrue);
      expect(color.toString(), equals('#ff881180'));

      color.green = 128;
      color.alpha = 1;

      expect(css.style, equals('color: #ff8011'));
    });

    test('CSS colors equals', () {
      var color1 = CSSColor.from('#ff0000');
      var color2 = CSSColor.from('rgb(255,0,0)');
      var color3 = CSSColor.from('rgba(255,0,0, 1)');

      var color4 = CSSColor.from('rgb(0,255,0)');

      expect(color1 == color2, isTrue);
      expect(color1 == color3, isTrue);

      expect(color2 == color1, isTrue);
      expect(color2 == color3, isTrue);

      expect(color3 == color1, isTrue);
      expect(color3 == color2, isTrue);

      expect(color1 == color4, isFalse);
      expect(color2 == color4, isFalse);
      expect(color3 == color4, isFalse);

      expect(color4 == color1, isFalse);
      expect(color4 == color2, isFalse);
      expect(color4 == color3, isFalse);
    });

    test('CSS border 1', () {
      var css = CSS('border: 11px dotted #f00;');
      expect(css.style, equals('border: 11px dotted #ff0000'));
    });

    test('CSS border 2', () {
      var css = CSS('border: solid');
      expect(css.style, equals('border: solid'));
    });

    test('CSS border 3', () {
      var css = CSS('border: dashed rgb(255,0,0)');
      expect(css.style, equals('border: dashed rgb(255, 0, 0)'));
    });

    test('CSS url', () {
      var css = CSS('foo-src:   url("http://host/foo.txt")  ');
      print(css);

      expect(css.style, equals('foo-src: url("http://host/foo.txt")'));

      var cssValue = css.get('foo-src');

      expect(cssValue, equals(CSSURL('http://host/foo.txt')));
    });

    test('CSS generic', () {
      var css = CSS('foo: bar');
      print(css);

      expect(css.style, equals('foo: bar'));

      var cssValue = css.get('foo');

      expect(cssValue, equals(CSSGeneric('bar')));
    });

    test('CSS calc', () {
      var css = CSS('width: calc( 100% -20px  )');
      print(css);
      expect(css.style, equals('width: calc(100% - 20px)'));

      var cssValue = css.get('width');

      expect(
          cssValue,
          equals(CSSLength.fromCalc(
              CSSCalc.withOperation('100%', CalcOperation.SUBTRACT, '20px'))));

      var css2 = CSS('width: calc( 100% )');
      print(css2);
      expect(css2.style, equals('width: 100%'));
    });
  });
}
