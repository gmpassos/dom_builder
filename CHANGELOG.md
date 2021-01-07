## 1.0.23

- Table:
  - Added support to table caption.
  - Added `colspan` and `rowspan` to helpers.
  - Added `thsStyle` and `tdsStyle` to `$table` helper. 
- `DOMTemplate`:
  - Added `tryParse` and `possiblyATemplate`.
  - Now `TextNode` with a template code is mapped to `TemplateNode`.
  - `toString()` now re-builds the template text code.
  - Improved tests.

## 1.0.22

- `DOMTemplate`:
  - added `locale` call action.
  - Added multiple actions using `;` delimiter.
  - Added variable comparison.
- `DOMElement`: added `onChange` events.
- swiss_knife: ^2.5.18

## 1.0.21

- `DOMTemplate`:
  - Added support to `{{.}}` syntax.
  - Better resolution of variables.

## 1.0.20

- `DOMTemplate`: support to template syntax, using `{{...}}` blocks.
- Added `DOMAction` and `DOMActionExecutor`, that can perform operations over `DOMElement` based into a simple syntax.
- `DOMNode`:
  - Added `selectWithAllClass`, `selectWithAnyClass`, `selectByTag`.
  - Added `containsAllClasses` and `containsAnyClass`.
- `CSSColor`: added `inverse` getter.

## 1.0.19

- Added `CSSNumber`.
- Added `CSSBackground`.
- `CSS`:
  - Added support to parse comments.
  - Added support to CSS `background` and `opacity`.
- `CSSColorName`: support for name `transparent`.
- `CSSBorder`: improve parsing.
- `DOMNode`:
  - Added `onGenerate` event.
  - Added `containsNode`.
  - Added `root` getter.
- Added helper `$img`.
- Added helper `$divCenteredContent`: A div that centers vertically and horizontally content.
- Fix `DOMElement.buildHTML` for self-closing tags.
- Improved `DOMElement.possibleAttributes`.
- `DOMGenerator`: added `revertElementAttributes`.
- `DOMContext`: Added `resolveCSSURL` and `cssURLResolver`.

## 1.0.18

- Added option to generate XHTML.
- Added `resolveSource`, to translate any `src` or `href` attribute.
- Added `DOMGeneratorDelegate`.
- Fix `CSSLength`, to parse double.
- swiss_knife: ^2.5.14
- pedantic: ^1.9.2
- test: ^1.15.4
- test_coverage: ^0.4.3

## 1.0.17

- `DOMNodeRuntime`: Can manipulate CSS/style.
- Added `DOMContext` and `Viewport` for `DOMGenerator`.
- `CSS`: now is capable to convert viewport units to pixel units, based into [DOMContext] [Viewport].
- Better `CSSLength`, `CSSBorder`, `CSSColorRGB`, `CSSColorHEX` and `CSSURL` parsing. 
- swiss_knife: ^2.5.12

## 1.0.16

- Added `CSS.parseList`.
- Added new base class `DOMAttributeValueCollection`.
- Improved `DOMGenerator.revert`.
- Fix typo.

## 1.0.15

- `DOMGenerator`: New `revert` feature.
- `DOMGenerator`: `registerElementGenerator` now receives a class `ElementGenerator`, that implements `generate` and `revert`.
- `DOMGenerator`: Added `getElementTag` and `getElementAttributes`.
- DOMAttribute fix: Avoid adicional space to HTML tags when `DOMAttribute.buildHTML()` generates an empty string (usually false boolean attributes). 

## 1.0.14

- Many improvements into CSS support.
- Added `CSSURL`, `CSSColorName`, `CSSGeneric`, `CSSCalc`.
- Added abstract class DOMAttributeValue for: `DOMAttributeValueBoolean`, `DOMAttributeValueString`, `DOMAttributeValueList`, `DOMAttributeValueSet`, `DOMAttributeValueCSS`.
- `DOMNode.buildDOM` now accepts a `T parent` parameter.
- swiss_knife: ^2.5.8

## 1.0.13

- More `CSS` support: `CSSBorder`.
- Preserve CSS entries order.
- dartfmt.

## 1.0.12

- Added initial `CSS` support.

## 1.0.11

- `DOMElement`: fix `absorbNode`.
- Removed helper `$node`
- dartfmt.

## 1.0.10

- `DOMElement`: added `isCompatibleForMerge`.
- `DOMGenerator`: added `ignoreAttributeEquivalence`.
- `DOMTreeMap`: added: `matchesMapping`.
- `DOMTreeMap`: fixed `duplicateByDOMNode`, `mergeNearNodes`.
- `DOMNodeRuntime`: fixed `mergeNode`, `isPreviousNode`, `isNextNode`.
- Fix `$br` for `amount` = `0`.

## 1.0.9

- dartfmt.

## 1.0.8

- Added `DOMTreeMap`: can be used to map a `DOMNode` to a generated node.
- Added `DOMNodeRuntime` and `DOMNode.runtime` to manipulate and access the actual generated node from the virtual node.
- Added `onClick` and `DOMEvent`.
- Added `DOMNode.copy`.
- Added node operations: `moveUp`, `moveUpNode`, `moveDown`, `moveDownNode`, `duplicate`, `duplicateNode`, `clearNodes`, `delete`, `deleteNode`.
- Added: `absorbNode`, `merge`.
- Added: `isInSameParent`, `isPreviousNode`, `isNextNode`, `isConsecutiveNode`, `isConsecutiveNode`.
- Added: `isStringElement`, `isWhiteSpace`.
- refactor `DOMAttribute`: set values.
- Added: `DOMElement.addClass`.
- `buildHTML`: prioritize attributes: id, class and style. Also shows boolean attributes at end of tag.
- `buildHTML`: Char \xa0 is replaced to `&nbsp;` to rollback conversion.
- External element function: now accepts non argument version.
- Optimize call to `asNodeSelector`.
- Added tests.
- Added `test_coverage`.
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
