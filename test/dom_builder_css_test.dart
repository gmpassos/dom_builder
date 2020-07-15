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
  });
}
