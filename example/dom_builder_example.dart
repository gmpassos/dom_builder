
import 'package:dom_builder/dom_builder.dart';

void main() {

  var div = $divHTML('<div class="container"><span>Builder</span></div>')
      .insertAt( 0, $span( id: 's1', content: 'The ' ) )
      .insertAfter( 's1' , $span( id: 's2', content: 'DOM ', style: 'font-weight: bold' ) )
  ;

  print( div.buildHTML( withIdent: true ) ) ;

  ////////////
  // Output //
  ////////////
  // <div class="container">
  //   <span id="s1">The </span>
  //   <span id="s2" style="font-weight: bold">DOM </span>
  //   <span>Builder</span>
  // </div>

}
