import 'package:dom_builder/dom_builder.dart';

void main() {
  var div = $div(classes: 'container', content: [
    $span(id: 's1', content: 'The '),
    $span(id: 's2', style: 'font-weight: bold', content: 'DOM '),
    $span(content: 'Builder'),
    $table(head: [
      'Name',
      'Age'
    ], body: [
      ['Joe', 21],
      ['Smith', 30]
    ])
  ]);

  // Moves down Joe's row, placing it after Smith's row:
  div.select('tbody')!.select('tr')!.moveDown();

  print('===============');
  print(div.buildHTML(withIndent: true));
  print('===============');

  // Equivalent:

  var div2 = $divHTML('<div class="container"><span>Builder</span></div>')!
      .insertAt(0, $span(id: 's1', content: 'The '))
      .insertAfter(
          '#s1', $span(id: 's2', style: 'font-weight: bold', content: 'DOM '))
      .add($tagHTML('''
        <table>
          <thead>
            <tr><th>Name</th><th>Age</th></tr>
          </thead>
          <tbody>
            <tr><td>Smith</td><td>30</td></tr>
            <tr><td>Joe</td><td>21</td></tr>
          </tbody>
        </table>
      '''));

  var eq = div.buildHTML() == div2.buildHTML();

  print('eq: $eq');
}

/*///////////
// OUTPUT: //
/////////////
===============
<div class="container">
  <span id="s1">The </span>
  <span id="s2" style="font-weight: bold">DOM </span>
  <span>Builder</span>
  <table>
    <thead>
      <tr>
        <th>Name</th>
        <th>Age</th>
      </tr>
    </thead>
    <tbody>
      <tr>
        <td>Joe</td>
        <td>21</td>
      </tr>
      <tr>
        <td>Smith</td>
        <td>30</td>
      </tr>
    </tbody>
  </table>
</div>
===============
eq: true

 */
