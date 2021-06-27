# dom_builder

[![pub package](https://img.shields.io/pub/v/dom_builder.svg?logo=dart&logoColor=00b9fc)](https://pub.dartlang.org/packages/dom_builder)
[![Null Safety](https://img.shields.io/badge/null-safety-brightgreen)](https://dart.dev/null-safety)
[![CI](https://img.shields.io/github/workflow/status/gmpassos/dom_builder/Dart%20CI/master?logo=github-actions&logoColor=white)](https://github.com/gmpassos/dom_builder/actions)
[![GitHub Tag](https://img.shields.io/github/v/tag/gmpassos/dom_builder?logo=git&logoColor=white)](https://github.com/gmpassos/dom_builder/releases)
[![New Commits](https://img.shields.io/github/commits-since/gmpassos/dom_builder/latest?logo=git&logoColor=white)](https://github.com/gmpassos/dom_builder/network)
[![Last Commits](https://img.shields.io/github/last-commit/gmpassos/dom_builder?logo=git&logoColor=white)](https://github.com/gmpassos/dom_builder/commits/master)
[![Pull Requests](https://img.shields.io/github/issues-pr/gmpassos/dom_builder?logo=github&logoColor=white)](https://github.com/gmpassos/dom_builder/pulls)
[![Code size](https://img.shields.io/github/languages/code-size/gmpassos/dom_builder?logo=github&logoColor=white)](https://github.com/gmpassos/dom_builder)
[![License](https://img.shields.io/github/license/gmpassos/dom_builder?logo=open-source-initiative&logoColor=green)](https://github.com/gmpassos/dom_builder/blob/master/LICENSE)

Generate and manipulate DOM elements (virtual or real), DSX (like JSX) and HTML declarations (Web and Native support).

## Usage

You can generate a DOM tree using HTML, Object Orientation or manipulating an already instantiated DOM tree.

Here's a simple usage example, that can work in any platform (Web or Native):

```dart
import 'package:dom_builder/dom_builder.dart';

void main() {

  var div = $divHTML('<div class="container"><span>Builder</span></div>')
      .insertAt( 0, $span( id: 's1', content: 'The ' ) )
      .insertAfter( '#s1' , $span( id: 's2', content: 'DOM ', style: 'font-weight: bold' ) )
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


  div.select('#s1').remove() ;
  print( div.buildHTML( withIdent: true ) ) ;

  ////////////
  // Output //
  ////////////
  // <div class="container">
  //   <span id="s2" style="font-weight: bold">DOM </span>
  //   <span>Builder</span>
  // </div>

}

```

## Generating a real DOM Element (`dart:html`):

As example, let's create a Bootstrap `navbar-toggler`:

```dart
import 'dart:html' ;
import 'package:dom_builder/dom_builder.dart';

class BootstrapNavbarToggler {

  static DOMGenerator domGenerator = DOMGenerator.dartHTML() ;

  Element render() {
    var button = $button( type: 'button', classes: 'navbar-toggler', attributes: {'data-toggle': "collapse", 'data-target': "#navbarCollapse", 'aria-controls': "navbarCollapse", 'aria-expanded':"false", 'aria-label':"Toggle navigation"} ,
        content: $span( classes: 'navbar-toggler-icon')
    );

    return button.buildDOM(domGenerator) ;
  }

}

```

## Mixing real DOM Element (`dart:html`) with virtual `DOMElement`:

```dart
import 'dart:html' ;
import 'package:dom_builder/dom_builder_html.dart';

class TitleComponent {

  static DOMGenerator domGenerator = DOMGenerator.dartHTML() ;

  Element render() {
    var div = $divHTML('<div class="container"><span>The </span></div>') ;

    div.add( SpanElement()..text = 'DOM Builder' ) ;

    return div.buildDOM(domGenerator) ;
  }

}

```

## DSX

Similar to [JSX][jsx], DSX (Dart Syntax Extension) allows the declaration and construction of
a `DOM` tree using plain `HTML`.

```dart
import 'dart:html' ;
import 'package:dom_builder/dom_builder_html.dart';

void main() {

  var button = $dsx('''
    <button onclick="${_btnClick.dsx()}">CLICK ME!</button>
  ''');
  
}

void _btnClick() {
  print('Button Clicked!');
}
```

[jsx]: https://reactjs.org/docs/introducing-jsx.html

## Example of Bootstrap Cards and Table:

```dart
import 'dart:html' ;
import 'package:dom_builder/dom_builder_html.dart';

Element generateBSCards() {
  // ...

  var tableHeads = ['User', 'E-Mail'];
  var usersEntries = [ ['Joe', 'joe@mail.com'], ['Smith', 'smith@mail.com']];

  var content = $div(content: [
    $div(classes: 'card', content: [
      $div(classes: 'card-header', content: 'Activity Timeline:'),
      $div(id: 'timeline-chart')
    ]),

    $hr(),

    $div(classes: 'card', content: [
      $div(classes: 'card-header', content: "Users:"),
      $div(classes: 'card-body', content:
      $table(classes: 'table text-truncate', head: tableHeads, body: usersEntries)
        ..applyWhere('td , th', classes: 'd-inline text-truncate', style: 'max-width: 50vw')
      )
    ]),

  ]);

  // ...

  if (timelineChartSeries != null) {
    content.select('#timeline-chart').add(
            (parent) {
          // render Chart inside element parent...
        }
    );
  }
  else {
    content.select('#timeline-chart').add('No Timeline Data.');
  }

  // ...

  var domGenerator = DOMGenerator.dartHTML();
  return content.buildDOM(domGenerator);
}
```

## See Also

See some related projects:

- [Bones_UI][bones_ui]: A simple and easy Web User Interface framework for Dart.
- [Bones_UI_Bootstrap][bones_ui_bootstrap]: Adds Bootstrap [Bones_UI][bones_ui].
- [Bootstrap][bootstrap]: Build fast and responsive sites. 

[bones_ui]: https://github.com/Colossus-Services/bones_ui
[bones_ui_bootstrap]: https://github.com/Colossus-Services/bones_ui_bootstrap
[bootstrap]: https://getbootstrap.com/

## Features and bugs

Please file feature requests and bugs at the [issue tracker][tracker].

[tracker]: https://github.com/gmpassos/dom_builder/issues

## Author

Graciliano M. Passos: [gmpassos@GitHub][github].

[github]: https://github.com/gmpassos

## License

Dart free & open-source [license](https://github.com/dart-lang/stagehand/blob/master/LICENSE).
