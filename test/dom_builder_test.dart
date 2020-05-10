import 'package:dom_builder/dom_builder.dart';
import 'package:test/test.dart';

void main() {
  group('A group of tests', () {

    setUp(() {});

    test('Basic div', () {

      var div = $div( id: 'd1', classes: 'container' , style: 'background-color: blue' );

      expect(div, isNotNull) ;
      expect(div.buildHTML(), equals('<div id="d1" class="container" style="background-color: blue"></div>')) ;

    });

    test('Basic generic tag', () {

      var div = $tag( 'foo', classes: 'bar' ) ;

      expect(div, isNotNull) ;
      expect(div.buildHTML(), equals('<foo class="bar"></foo>')) ;

    });

    test('div content 1', () {

      var div = $div( classes: 'container' , content: ['Simple Text' , $span( content: 'Sub text') ] ) ;

      expect(div, isNotNull) ;
      expect(div.buildHTML(), equals('<div class="container">Simple Text<span>Sub text</span></div>')) ;
    });

    test('div content 2', () {

      var div = $div( classes: 'container' )
          .add('Simple Text')
          .add( $span( content: 'Sub text') ) ;


      expect(div, isNotNull) ;
      expect(div.buildHTML(), equals('<div class="container">Simple Text<span>Sub text</span></div>')) ;
    });

    test('Basic html', () {

      var div = $tagHTML('<DIV class="container">Simple Text<SPAN>Sub text</SPAN></DIV>');

      expect(div, isNotNull) ;
      expect(div.buildHTML(), equals('<div class="container">Simple Text<span>Sub text</span></div>')) ;

    });

    test('html add span', () {

      var div = $divHTML('<DIV class="container">Simple Text<SPAN>Sub text</SPAN></DIV>') ;

      div.add( $span( content: 'Final text' ) ) ;

      expect(div, isNotNull) ;
      expect(div.buildHTML(), equals('<div class="container">Simple Text<span>Sub text</span><span>Final text</span></div>')) ;

    });

    test('html insert span', () {

      var div = $divHTML('<DIV class="container">Simple Text<SPAN>Sub text</SPAN></DIV>') ;

      div.insertAt( 1, $span( id: 's1', content: 'Initial text' ) ) ;

      expect(div, isNotNull) ;
      expect(div.buildHTML(), equals('<div class="container">Simple Text<span id="s1">Initial text</span><span>Sub text</span></div>')) ;

      expect( div.nodeByID('s1').buildHTML() , equals('<span id="s1">Initial text</span>')) ;
      expect( div.node('s1').buildHTML() , equals('<span id="s1">Initial text</span>')) ;

      expect( div.selectByID('s1').buildHTML() , equals('<span id="s1">Initial text</span>')) ;
      expect( div.select('s1').buildHTML() , equals('<span id="s1">Initial text</span>')) ;

      div.insertAt( 's1' , $span( id: 's0', content: 'Text 0' ) ) ;

      expect(div.buildHTML(), equals('<div class="container">Simple Text<span id="s0">Text 0</span><span id="s1">Initial text</span><span>Sub text</span></div>')) ;

      div.insertAfter( 's1' , $span( id: 's2', content: 'Text 2' ) ) ;

      expect(div.buildHTML(), equals('<div class="container">Simple Text<span id="s0">Text 0</span><span id="s1">Initial text</span><span id="s2">Text 2</span><span>Sub text</span></div>')) ;

    });

  });
}
