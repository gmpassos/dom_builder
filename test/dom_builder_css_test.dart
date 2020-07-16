import 'package:dom_builder/src/dom_builder_css.dart';
import 'package:test/test.dart';

void main() {
  group('CSS', () {
    setUp(() {});

    test('CSS construct 1', () {
      var css = CSS();
      expect(css.style, equals(''));

      css.color = CSSColorRGB(255, 0, 0);
      expect(css.style, equals('color: rgb(255, 0, 0);'));

      css.backgroundColor = CSSColorRGB(0, 255, 0);
      expect(css.style,
          equals('color: rgb(255, 0, 0); background-color: rgb(0, 255, 0);'));

      css.width = CSSLength(10, CSSUnit.px);
      expect(
          css.style,
          equals(
              'color: rgb(255, 0, 0); background-color: rgb(0, 255, 0); width: 10px;'));
    });

    test('CSS parse 1', () {
      var css = CSS(
          'color: rgb(255, 0, 0); background-color: rgba(0, 255, 0, 0.50); width: 10vw; height: 20%;');
      expect(
          css.style,
          equals(
              'color: rgb(255, 0, 0); background-color: rgba(0, 255, 0, 0.5); width: 10vw; height: 20%;'));

      expect(css.color.name, equals('color'));
      var color = css.color.value as CSSColorRGB ;
      expect(color.red, equals(255));
      expect(color.green, equals(0));
      expect(color.blue, equals(0));
      expect(color.toString(), equals('rgb(255, 0, 0)'));

      expect(css.backgroundColor.name, equals('background-color'));
      var backgroundColor = css.backgroundColor.value as CSSColorRGBA ;
      expect(backgroundColor.red, equals(0));
      expect(backgroundColor.green, equals(255));
      expect(backgroundColor.blue, equals(0));
      expect(backgroundColor.alpha, equals(0.50));
      expect(backgroundColor.toString(), equals('rgba(0, 255, 0, 0.5)'));

      expect(css.width.name, equals('width'));
      var width = css.width.value ;
      expect(width.value, equals(10));
      expect(width.unit, equals(CSSUnit.vw));

      expect(css.height.name, equals('height'));
      var height = css.height.value ;
      expect(height.value, equals(20));
      expect(height.unit, equals(CSSUnit.percent));

      color.green = 128 ;
      color.blue = 200 ;

      width.unit = CSSUnit.percent;
      height.unit = CSSUnit.vh;

      expect(
          css.style,
          equals(
              'color: rgb(255, 128, 200); background-color: rgba(0, 255, 0, 0.5); width: 10%; height: 20vh;'));
    });

    test('CSS colors RGB', () {
      var css = CSS('color: rgb(255, 0, 0);');
      expect(
          css.style,
          equals('color: rgb(255, 0, 0);'));

      expect(css.color.name, equals('color'));
      var color = css.color.value as CSSColorRGB ;
      expect(color.red, equals(255));
      expect(color.green, equals(0));
      expect(color.blue, equals(0));
      expect(color.hasAlpha, isFalse);
      expect(color.toString(), equals('rgb(255, 0, 0)'));

      color.green = 128 ;
      color.blue = 200 ;

      expect(css.style, equals('color: rgb(255, 128, 200);'));
    });

    test('CSS colors RGBA', () {
      var css = CSS('color: rgb(255, 0, 0, 0.21);');
      expect(
          css.style,
          equals('color: rgba(255, 0, 0, 0.21);'));

      expect(css.color.name, equals('color'));
      var color = css.color.value as CSSColorRGBA ;
      expect(color.red, equals(255));
      expect(color.green, equals(0));
      expect(color.blue, equals(0));
      expect(color.hasAlpha, isTrue);
      expect(color.toString(), equals('rgba(255, 0, 0, 0.21)'));

      color.red = 0 ;
      color.green = 128 ;
      color.blue = 200 ;
      color.alpha = 0.75 ;

      expect(css.style, equals('color: rgba(0, 128, 200, 0.75);'));
    });

    test('CSS colors HEX 6', () {
      var css = CSS('color: #FF0000;');
      expect(
          css.style,
          equals('color: #ff0000;'));

      expect(css.color.name, equals('color'));
      var color = css.color.value as CSSColorHEX ;
      expect(color.red, equals(255));
      expect(color.green, equals(0));
      expect(color.blue, equals(0));
      expect(color.toString(), equals('#ff0000'));

      color.red = 0 ;
      color.green = 128 ;
      color.blue = 200 ;

      expect(css.style, equals('color: #0080c8;'));
    });

    test('CSS colors HEX 3', () {
      var css = CSS('color: #FFF;');
      expect(
          css.style,
          equals('color: #ffffff;'));

      expect(css.color.name, equals('color'));
      var color = css.color.value as CSSColorHEX ;
      expect(color.red, equals(255));
      expect(color.green, equals(255));
      expect(color.blue, equals(255));
      expect(color.hasAlpha, isFalse);
      expect(color.toString(), equals('#ffffff'));

      color.green = 128 ;

      expect(css.style, equals('color: #ff80ff;'));
    });

    test('CSS colors HEX 8', () {
      var css = CSS('color: #FF881180;');
      expect(
          css.style,
          equals('color: #ff881180;'));

      expect(css.color.name, equals('color'));
      var color = css.color.value as CSSColorHEXAlpha ;
      expect(color.red, equals(255));
      expect(color.green, equals(136));
      expect(color.blue, equals(17));
      expect(color.alpha, equals(0.501));
      expect(color.hasAlpha, isTrue);
      expect(color.toString(), equals('#ff881180'));

      color.green = 128 ;
      color.alpha = 1 ;

      expect(css.style, equals('color: #ff8011;'));
    });

  });
}
