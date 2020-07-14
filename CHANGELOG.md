## 1.0.8

- Added `DOMTreeMap`: can be used to map a [DOMNode] to a generated node.
- Added `DOMNodeRuntime` and `DOMNode.runtime` to manipulate and access the actual generated node from the virtual node.
- Added `onClick` and `DOMEvent`.
- Added `DOMNode.copy`.
- Added node operations: `moveUp`, `moveUpNode`, `moveDown`, `moveDownNode`, `duplicate`, `duplicateNode`, `clearNodes`, `delete`, `deleteNode`.
- Added: `absorbNode`, `merge`.
- Added: `isInSameParent`, `isPreviousNode`, `isNextNode`, `isConsecutiveNode`, `isConsecutiveNode`.
- Added: `isStringElement`, `isWhiteSpace`.
- refactor `DOMAttribute`: set values.
- Added: `DOMElement.addClass`.
- buildHTML: prioritize attributes: id, class and style. Also shows boolean attributes at end of tag.
- External element function: now accepts non argument version.
- char \xa0 is replaced to &nbsp;, to rollback conversion.
- optimize call to `asNodeSelector`.
- Added tests.
- swiss_knife: ^2.5.5

## 1.0.7

- Added helpers for `header` and `footer`.
- dartfmt

## 1.0.6

- dartfmt.

## 1.0.5

- Added API Documentation.
- dartfmt.
- swiss_knife: ^2.5.2

## 1.0.4

- Fix README example and new examples.
- Fix 'dartdoc' issues.

## 1.0.3

- Better handling of selectors formats: .class, #id, tag
- Table support.
- Fix build HTML with ident.
- Element helpers: $input, $textarea, $button, $label, $p, $br, $hr, $table, $thead, $tfoot, $tbody, $tr, $td, $th, $$divInline.

## 1.0.2

- Added support for external elements.

## 1.0.1

- Add generic DOMGenerator and support for dart:html.

## 1.0.0

- Initial version, created by Stagehand
