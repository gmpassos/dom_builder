# dom_builder

Helpers to generate DOM elements or HTML.

## Usage

You can generate a DOM tree using HTML, Object Orientation or manipulating an already instantiated DOM tree.

A simple usage example:

```dart
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

```

## Generating a real DOM Element (`dart:html`):

As example let's create a Bootstrap Navbar toggler:

```dart
import 'dart:html' ;
import 'package:dom_builder/dom_builder.dart';

class BootstrapNavbarToggler {

  static DOMGenerator domGenerator = DOMGenerator.dartHTML() ;

  Element render() {
    var button = $button( classes: 'navbar-toggler', type: 'button', attributes: {'data-toggle': "collapse", 'data-target': "#navbarCollapse", 'aria-controls': "navbarCollapse", 'aria-expanded':"false", 'aria-label':"Toggle navigation"} ,
        content: $span( classes: 'navbar-toggler-icon')
    );

    return button.buildDOM(domGenerator) ;
  }

}

```

## Mixing real DOM Elements with Builder (`dart:html`):

```dart
import 'dart:html' ;
import 'package:dom_builder/dom_builder.dart';

class TitleComponent {

  static DOMGenerator domGenerator = DOMGenerator.dartHTML() ;

  Element render() {
    var div = $divHTML('<div class="container"><span>The </span></div>') ;

    div.add( SpanElement()..text = 'DOM Builder' ) ;

    return div.buildDOM(domGenerator) ;
  }

}

```

## Example of Bootstrap Cards and Table:

```dart

      // ...

      var tableHeads = ['User', 'E-Mail'] ;
      var usersEntries = [ ['Joe' , 'joe@mail.com'] , ['Smith' , 'smith@mail.com'] ] ;

      var content = $div( content: [
        $div( classes: 'card' , content: [
          $div( classes: 'card-header' , content: 'Activity Timeline:') ,
          $div( id: 'timeline-chart' )
        ]) ,

        $hr(),

        $div( classes: 'card' , content: [
          $div( classes: 'card-header' , content: "Users:"),
          $div( classes: 'card-body' , content:
            $table( classes: 'table text-truncate', head: tableHeads, body: usersEntries)
            ..applyWhere( 'td , th' , classes: 'd-inline text-truncate' , style: 'max-width: 50vw')
          )
        ]) ,

      ] );

      // ...

      if (timelineChartSeries != null) {
        content.select( '#timeline-chart' ).add(
            ( parent ) {
              // render Chart inside element parent...
            }
        ) ;
      }
      else {
        content.select( '#timeline-chart' ).add( 'No Timeline Data.' ) ;
      }

      // ...

      return content.buildDOM(domGenerator) ;
```


## Features and bugs

Please file feature requests and bugs at the [issue tracker][tracker].

[tracker]: https://github.com/gmpassos/dom_builder/issues

## Author

Graciliano M. Passos: [gmpassos@GitHub][github].

[github]: https://github.com/gmpassos

## License

Dart free & open-source [license](https://github.com/dart-lang/stagehand/blob/master/LICENSE).
