## 2.1.6

- Fix `createTableCells`.

## 2.1.5

- `DOMAction`: implement `==` and `hashCode`.
- `DOMGenerator`:
  - `resolveActionAttribute`: ensure that `eventStream.listen` is singleton.
- swiss_knife: ^3.1.4

## 2.1.4

- `DOMHtmlBrowser`:
  - `toDOMElement`: resolve `input` `value` as attribute.
- `DOMElement` constructor:
  - Optimize tag resolution.

## 2.1.3

- `DOMNode`:
  - `buildHTML`: added parameter `buildTemplates = false`.
- `TemplateNode`:
  - `buildHTML`:
    - respect `buildTemplates` parameter.
    - pass `domContext` to `build` calls.
- html: ^0.15.2
- swiss_knife: ^3.1.3
- lints: ^2.0.1
- test: ^1.23.1
- coverage: ^1.6.3

## 2.1.2

- `$button`: Added `name` and `disabled`.
- `$input`, `$checkbox`, `$radiobutton`, `$select`, `$option`: Added `disabled`.
- `INPUTElement`, `TEXTAREAElement`, `SELECTElement`, `OPTIONElement`: Added `disabled`.
- collection: ^1.17.0

## 2.1.1

- Added element events for `onKeyPress`, `onKeyDown` and `onKeyUp`.

## 2.1.0

- Added helpers `$ul`, `$ol`, `$li`.
- Better handling of content as `Iterable` (auto converted to `List`, to avoid re-iteration).
- Updated list of self-closing tags:
  - `area`, `base`, `br`, `embed`, `hr`, `img`, `input`, `link`, `meta`, `param`, `source`, `track`, `wbr`.
- sdk: '>=2.15.0 <3.0.0'
- dependency_validator: ^3.2.2
- coverage: ^1.5.0

## 2.0.10

- `CSS`:
  - Added `putIfAbsent` and `putAllIfAbsent`.
  - Ensure that number values when converted to `String` won't end in unnecessary `.0`.
  - `CSSColorRGBA`: ensure that when alpha is `1.0` it will generate `rgb` (not `rgba`) with only 3 elements.
- `$table`:
  - Parameters `thsStyle`, `trsStyle` and `tdsStyle` won't override a CSS style already defined in the table elements.  
- GitHub CI:
  - Remove use of Dart container.
  - Fix coverage command for dart 2.17+
- swiss_knife: ^3.1.1
- collection: ^1.16.0
- lints: ^2.0.0

## 2.0.9

- Dart `2.16`:
  - Organize imports.
  - Fix new lints.
- sdk: '>=2.13.0 <3.0.0'
- Added helper `$radiobutton`.
- Tag `video`:
  - Allow boolean attributes: 'autoplay', 'controls' and 'muted'.

## 2.0.8

- `dom_builder_html_browser.dart`: reuse `DomParser` instance. 

## 2.0.7

- Added `DOMHtml`, a portable HTML handler and parser.
  - When compiling to the browser uses `dart:html`. 
- Fix `OPTIONElement.toOptions`:
- Migrated from package `pedantic` to `lints`.
- Using Dart `coverage`.
- lints: ^1.0.1
- coverage: ^1.0.3

## 2.0.6

- Allow built of `DOMTemplate` without resolve `DSX` entries.
- `DOMNodeRuntime`:
  - added `remap` parameter to `replaceBy`. 
  - Improved documentation.
- Improved test coverage.
- swiss_knife: ^3.0.8
- test: ^1.17.10

## 2.0.5

- Added `DOMTreeMap.queryElement`.
- Fix resolution of attributes with templates in some scenarios.
- Added code coverage.

## 2.0.4

- Templates now can also generate a `DOMNode` and not only texts/String.
- `DSX`:
  - Allow DOM elements.
  - Allow observation of mapped `DSX`.
- Fix `hidden` parameter, to not be defined when `null` (default was `false` now is `null`). 

## 2.0.3

- Implemented `DSX` support, similar to `JSX`.
  - Templates also accepts `DSX` references, including functions/lambdas.

## 2.0.2

- Null Safety adjustments.
- swiss_knife: ^3.0.6
  
## 2.0.1

- Null Safety adjustments.
- swiss_knife: ^3.0.5

## 2.0.0

- Dart 2.12.0:
  - Sound null safety compatibility.
  - Update CI dart commands.
  - sdk: '>=2.12.0 <3.0.0'
- html: ^0.15.0
- swiss_knife: ^3.0.1
- pedantic: ^1.11.0
- test: ^1.16.5

## 1.0.26

- Improved `boolean` attributes: 'selected', 'multiple', 'inert'.
- Help `$divCenteredContent`: added `style` and `class`.
- New helper: `$checkbox`.
- Ensure that all element classes and helpers
  have the global attribute `hidden`.
- swiss_knife: ^2.5.26

## 1.0.25

- `DOMElement`: added event handler `onLoad` and `onError`.
- `DOMTemplate`: added support to `{{intl:key}}`.
- swiss_knife: ^2.5.25

## 1.0.24

- Added support to content as `Future`.
  - When a `Future` is completed, the result will be inserted in the generated DOM tree.
- Added `DOMAsync` for async nodes.
  - With support for `loading` content, that will be replaced by result of async content.
- Added interfaces `AsDOMElement` and `AsDOMNode`.
- Added `$select` and `$option` helpers.

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
- `CSS`: now is capable to convert viewport units to pixel units, based into [DOMContext] and [Viewport].
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
