import 'package:dom_builder/dom_builder.dart';
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

    test('CSS colors named', () {
      var color1 = CSSColor.from('red');
      var color2 = CSSColor.from('blue');
      var color3 = CSSColor.from('black');
      var color4 = CSSColor.from('white');

      expect(color1.asCSSColorHEX, equals(CSSColor.from('#ff0000')));
      expect(color2.asCSSColorHEX, equals(CSSColor.from('#0000ff')));
      expect(color3.asCSSColorHEX, equals(CSSColor.from('#000000')));
      expect(color4.asCSSColorHEX, equals(CSSColor.from('#ffffff')));
    });

    test('CSSLength', () {
      expect(CSSLength.parse('101px').toString(), equals('101px'));
      expect(CSSLength.parse('101px'), equals(CSSLength(101, CSSUnit.px)));

      expect(CSSLength.parse('102').toString(), equals('102px'));
      expect(CSSLength.parse('102'), equals(CSSLength(102, CSSUnit.px)));

      expect(CSSLength.parse('75%').toString(), equals('75%'));
      expect(CSSLength.parse('75%'), equals(CSSLength(75, CSSUnit.percent)));

      expect(CSSLength.parse('1.5em'), equals(CSSLength(1.5, CSSUnit.em)));
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

    test('CSS border 4', () {
      var css = CSS('border: 10px dashed red');
      expect(css.style, equals('border: 10px dashed red'));
    });

    test('CSS url 1', () {
      var css = CSS('foo-src:   url("http://host/foo.txt")  ');
      print(css);

      expect(css.style, equals('foo-src: url("http://host/foo.txt")'));

      var cssValue = css.get('foo-src');

      expect(cssValue, equals(CSSURL('http://host/foo.txt')));
    });

    test('CSS url 2', () {
      var css = CSS('foo-src: url("http://host/foo.txt") ; width: 20px');
      print(css);

      expect(css.style,
          equals('foo-src: url("http://host/foo.txt"); width: 20px'));

      expect(css.get('foo-src'), equals(CSSURL('http://host/foo.txt')));

      expect(css.getAsString('foo-src'), 'url("http://host/foo.txt")');
    });

    test('CSS background color', () {
      var css = CSS('background: #ff0000 ; width: 20px');
      print(css);

      expect(css.style, equals('background: #ff0000; width: 20px'));

      expect(css.get('background'),
          equals(CSSBackground.color(CSSColor.parse('#ff0000'))));

      expect(css.getAsString('background'), '#ff0000');
    });

    test('CSS background url', () {
      var css = CSS('background: url("assets/foo.png") ; width: 20px');
      print(css);

      expect(
          css.style, equals('background: url("assets/foo.png"); width: 20px'));

      expect(css.get('background'),
          equals(CSSBackground.url(CSSURL('assets/foo.png'))));

      expect(css.getAsString('background'), 'url("assets/foo.png")');
    });

    test('CSS background url props 1', () {
      var css = CSS('background: url("assets/foo.png") no-repeat; width: 20px');
      print(css);

      expect(css.style,
          equals('background: url("assets/foo.png") no-repeat; width: 20px'));

      var background = css.background.value;
      expect(background, equals(CSSBackground.url(CSSURL('assets/foo.png'))));

      expect(background.hasImages, isTrue);
      expect(background.imagesLength, equals(1));

      var image = background.firstImage;

      expect(image.url.toString(), equals('url("assets/foo.png")'));
      expect(image.repeat, equals(CSSBackgroundRepeat.noRepeat));

      expect(background.toString(), 'url("assets/foo.png") no-repeat');
    });

    test('CSS background url props 2', () {
      var css =
          CSS('background: url("assets/foo.png") no-repeat #f00; width: 20px');
      print(css);

      expect(
          css.style,
          equals(
              'background: url("assets/foo.png") no-repeat #ff0000; width: 20px'));

      var background = css.background.value;
      expect(background, equals(CSSBackground.url(CSSURL('assets/foo.png'))));

      expect(background.hasImages, isTrue);
      expect(background.imagesLength, equals(1));

      expect(background.color.toString(), equals('#ff0000'));

      var image = background.firstImage;

      expect(image.url.toString(), equals('url("assets/foo.png")'));
      expect(image.repeat, equals(CSSBackgroundRepeat.noRepeat));

      expect(background.toString(), 'url("assets/foo.png") no-repeat #ff0000');
    });

    test('CSS background url props 3', () {
      var css = CSS(
          'background: url("assets/foo.png") center no-repeat fixed #f00; width: 20px');
      print(css);

      expect(
          css.style,
          equals(
              'background: url("assets/foo.png") center no-repeat fixed #ff0000; width: 20px'));

      var background = css.background.value;
      expect(background, equals(CSSBackground.url(CSSURL('assets/foo.png'))));

      expect(background.hasImages, isTrue);
      expect(background.imagesLength, equals(1));

      expect(background.color.toString(), equals('#ff0000'));

      var image = background.firstImage;

      expect(image.url.toString(), equals('url("assets/foo.png")'));
      expect(image.repeat, equals(CSSBackgroundRepeat.noRepeat));
      expect(image.attachment, equals(CSSBackgroundAttachment.fixed));
      expect(image.position, equals('center'));

      expect(background.toString(),
          'url("assets/foo.png") center no-repeat fixed #ff0000');
    });

    test('CSS background urls 1', () {
      var css = CSS(
          'background: url("assets/foo1.png"), url("assets/foo2.png")  ;  width: 20px');
      print(css);

      expect(
          css.style,
          equals(
              'background: url("assets/foo1.png"), url("assets/foo2.png"); width: 20px'));

      var background = css.background.value;
      expect(
          background,
          equals(CSSBackground.images([
            CSSBackgroundImage.url(CSSURL('assets/foo.png')),
            CSSBackgroundImage.url(CSSURL('assets/foo.png'))
          ])));

      expect(background.hasImages, isTrue);
      expect(background.imagesLength, equals(2));

      var image1 = background.getImage(0);
      var image2 = background.getImage(1);

      expect(image1.url.toString(), equals('url("assets/foo1.png")'));
      expect(image2.url.toString(), equals('url("assets/foo2.png")'));

      expect(background.toString(),
          'url("assets/foo1.png"), url("assets/foo2.png")');
    });

    test('CSS background urls 2', () {
      var css = CSS(
          'background: url("assets/foo1.png"), url("assets/foo2.png") #00ff00 ;  width: 20px');
      print(css);

      expect(
          css.style,
          equals(
              'background: url("assets/foo1.png"), url("assets/foo2.png") #00ff00; width: 20px'));

      var background = css.background.value;
      expect(
          background,
          equals(CSSBackground.images([
            CSSBackgroundImage.url(CSSURL('assets/foo.png')),
            CSSBackgroundImage.url(CSSURL('assets/foo.png'))
          ], CSSColor.parse('#00ff00'))));

      expect(background.color, equals(CSSColor.parse('#00ff00')));

      expect(background.hasImages, isTrue);
      expect(background.imagesLength, equals(2));

      var image1 = background.getImage(0);
      var image2 = background.getImage(1);

      expect(image1.url.toString(), equals('url("assets/foo1.png")'));
      expect(image2.url.toString(), equals('url("assets/foo2.png")'));

      expect(background.toString(),
          'url("assets/foo1.png"), url("assets/foo2.png") #00ff00');
    });

    test('CSS background linear-gradient', () {
      var css = CSS(
          'background: linear-gradient(to left, #333, #333 50% , #eee 75% , #333 75%) ; width: 20px');
      print(css);

      expect(
          css.style,
          equals(
              'background: linear-gradient(to left, #333, #333 50%, #eee 75%, #333 75%); width: 20px'));

      expect(
          css.get('background'),
          equals(CSSBackground.image(CSSBackgroundImage.gradient(
              CSSBackgroundGradient('linear-gradient',
                  ['to left', '#333', '#333 50%', '#eee 75%', '#333 75%'])))));

      expect(css.getAsString('background'),
          'linear-gradient(to left, #333, #333 50%, #eee 75%, #333 75%)');
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

      var css3 = CSS('height: calc(100%-20px)');
      print(css3);
      expect(css3.style, equals('height: calc(100% - 20px)'));

      var css4 =
          CSS('min-height: 62p; width: calc(100% - 156px); margin-left: 10px;');
      print(css4);
      expect(
          css4.style,
          equals(
              'min-height: 62px; width: calc(100% - 156px); margin-left: 10px'));

      //
    });

    test('CSS multiple', () {
      var css = CSS(
          'background-color: #333; text-align: center; box-shadow: 2px 2px 4px #f00; scrollbar-color: #000 #666;');
      print(css);
      expect(
          css.style,
          equals(
              'background-color: #333333; text-align: center; box-shadow: 2px 2px 4px #f00; scrollbar-color: #000 #666'));

      expect(css.get('background-color'),
          equals(CSSValue.parseByName('#333333', 'background-color')));

      expect(css.get('text-align'),
          equals(CSSValue.parseByName('center', 'text-align')));

      expect(css.get('box-shadow'),
          equals(CSSValue.parseByName('2px 2px 4px #f00', 'box-shadow')));

      expect(css.get('scrollbar-color'),
          equals(CSSValue.parseByName('#000 #666', 'scrollbar-color')));
    });

    test('CSS multiple 2', () {
      var css = CSS(
          'background-color: transparent; float: right; font-size: 0.7rem; font-weight: 700; line-height: 1; color: #000; text-shadow: 0 1px 0 #fff; opacity: 0.5;');
      var css2 = CSS(
          'background-color: transparent; float: right; font-size: .7rem; font-weight: 700; line-height: 1; color: #000000; text-shadow: 0 1px 0 #fff; opacity: .5;');

      expect(
          css.style,
          equals(
              'background-color: transparent; float: right; font-size: 0.7rem; font-weight: 700; line-height: 1; color: #000000; text-shadow: 0 1px 0 #fff; opacity: 0.5'));

      expect(css2.style, equals(css.style));

      expect(css.get<CSSColor>('background-color').hasAlpha, isTrue);

      expect(css.get('font-size'), equals(CSSLength(0.7, CSSUnit.rem)));

      expect(css.get('opacity'), equals(CSSNumber(0.5)));
    });

    test('CSS comments', () {
      var css1 = CSS('max-width: 80vw /* foo */; width: 200px; height: 50vh;');

      expect(css1.toString(),
          equals('max-width: 80vw/* foo */; width: 200px; height: 50vh'));

      var css2 = CSS('max-width: 80vw /* foo */;');

      expect(css2.toString(), equals('max-width: 80vw/* foo */'));

      var css3 = CSS('width: 20px; max-width: 80vw /* foo */;');

      expect(css3.toString(), equals('width: 20px; max-width: 80vw/* foo */'));
    });

    test('CSS DOMContext 1', () {
      var domContext = DOMContext(
          resolveCSSViewportUnit: true, viewport: Viewport(800, 600, 810, 610));

      var css = CSS('width: 80vw;');

      expect(css.toString(), equals('width: 80vw'));

      expect(css.toString(domContext),
          equals('width: 640.0px /* DOMContext-original-value: 80vw */'));

      expect(CSS.parse(css.toString()).toString(), equals('width: 80vw'));

      print(css.toString(domContext));
      print(CSS.parse(css.toString(domContext)).toString());

      expect(CSS.parse(css.toString(domContext)).toString(),
          equals('width: 80vw'));
    });

    test('CSS DOMContext 2', () {
      var domContext = DOMContext(
          resolveCSSViewportUnit: true, viewport: Viewport(800, 600, 810, 610));

      var div = $div(style: 'width: 80vw;', content: 'x');

      expect(div.buildHTML(), equals('<div style="width: 80vw">x</div>'));

      expect(
          div.buildHTML(domContext: domContext),
          equals(
              '<div style="width: 640.0px /* DOMContext-original-value: 80vw */">x</div>'));
    });

    test('CSS DOMContext 3', () {
      var domContext = DOMContext(
          resolveCSSViewportUnit: true, viewport: Viewport(800, 600, 810, 610));

      var css = CSS('max-width: 80vw; width: 200px; height: 50vh;');

      expect(css.toString(),
          equals('max-width: 80vw; width: 200px; height: 50vh'));

      expect(
          css.toString(domContext),
          equals(
              'max-width: 640.0px /* DOMContext-original-value: 80vw */; width: 200px; height: 300.0px /* DOMContext-original-value: 50vh */'));

      expect(CSS.parse(css.toString()).toString(),
          equals('max-width: 80vw; width: 200px; height: 50vh'));

      print(css.toString(domContext));
      print(CSS.parse(css.toString(domContext)).toString());

      expect(CSS.parse(css.toString(domContext)).toString(),
          equals('max-width: 80vw; width: 200px; height: 50vh'));
    });
  });
}
