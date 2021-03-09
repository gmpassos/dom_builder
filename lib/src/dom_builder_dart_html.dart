import 'dart:html';

import 'package:dom_builder/dom_builder.dart';

/// Creates an [Element] using [tag] name.
@override
Element/*?*/ createElement(String/*!*/ tag, [DOMElement/*?*/ domElement]) {
  switch (tag) {
    case 'a':
      return AnchorElement();
    case 'article':
      return Element.article();
    case 'aside':
      return Element.aside();
    case 'audio':
      return AudioElement();
    case 'br':
      return BRElement();
    case 'canvas':
      return CanvasElement();
    case 'div':
      return DivElement();
    case 'footer':
      return Element.footer();
    case 'header':
      return Element.header();
    case 'hr':
      return HRElement();
    case 'iframe':
      return IFrameElement();
    case 'img':
      return ImageElement();
    case 'li':
      return LIElement();
    case 'nav':
      return Element.nav();
    case 'ol':
      return Element.ol();
    case 'option':
      return OptionElement();
    case 'p':
      return ParagraphElement();
    case 'pre':
      return PreElement();
    case 'section':
      return Element.section();
    case 'select':
      return SelectElement();
    case 'span':
      return SpanElement();
    case 'svg':
      return Element.svg();
    case 'table':
      return TableElement();
    case 'td':
      return TableCellElement();
    case 'textarea':
      return TextAreaElement();
    case 'th':
      return Element.th();
    case 'tr':
      return TableRowElement();
    case 'ul':
      return UListElement();
    case 'video':
      return VideoElement();
    case 'input':
      return createInputElement(domElement?.getAttributeValue('type'));
    default:
      return Element.isTagSupported(tag) ? Element.tag(tag) : null;
  }
}

InputElementBase/*!*/ createInputElement([String/*?*/ type]) {
  type = type?.toLowerCase();

  switch (type) {
    case 'search':
      return SearchInputElement();
    case 'text':
      return TextInputElement();
    case 'url':
      return UrlInputElement();
    case 'tel':
      return TelephoneInputElement();
    case 'email':
      return EmailInputElement();
    case 'password':
      return PasswordInputElement();
    case 'date':
      return DateInputElement();
    case 'month':
      return MonthInputElement();
    case 'week':
      return WeekInputElement();
    case 'time':
      return TimeInputElement();
    case 'datetime-local':
      return LocalDateTimeInputElement();
    case 'number':
      return NumberInputElement();
    case 'range':
      return RangeInputElement();
    case 'checkbox':
      return CheckboxInputElement();
    case 'radio':
      return RadioButtonInputElement();
    case 'file':
      return FileUploadInputElement();
    case 'submit':
      return SubmitButtonInputElement();
    case 'reset':
      return ResetButtonInputElement();
    case 'image':
      return ImageButtonInputElement();
    default:
      return InputElement();
  }
}
