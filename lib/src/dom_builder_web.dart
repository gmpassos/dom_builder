import 'package:web_utils/web_utils.dart';

import 'dom_builder_base.dart';

/// Creates an [Element] using [tag] name.
Element? createElement(String tag, [DOMElement? domElement]) {
  tag = tag.trim().toLowerCase();

  switch (tag) {
    case 'a':
      return HTMLAnchorElement();
    case 'article':
      return HTMLElement.article();
    case 'aside':
      return HTMLElement.aside();
    case 'audio':
      return HTMLAudioElement();
    case 'br':
      return HTMLBRElement();
    case 'canvas':
      return HTMLCanvasElement();
    case 'div':
      return HTMLDivElement();
    case 'footer':
      return HTMLElement.footer();
    case 'header':
      return HTMLElement.header();
    case 'hr':
      return HTMLHRElement();
    case 'iframe':
      return HTMLIFrameElement();
    case 'img':
      return HTMLImageElement();
    case 'li':
      return HTMLLIElement();
    case 'nav':
      return HTMLElement.nav();
    case 'ol':
      return document.createElement('ol');
    case 'option':
      return HTMLOptionElement();
    case 'p':
      return HTMLParagraphElement();
    case 'pre':
      return document.createElement('pre');
    case 'section':
      return HTMLElement.section();
    case 'select':
      return HTMLSelectElement();
    case 'span':
      return HTMLSpanElement();
    case 'svg':
      return document.createElement('svg');
    case 'table':
      return HTMLTableElement();
    case 'td':
      return document.createElement('td');
    case 'textarea':
      return HTMLTextAreaElement();
    case 'th':
      return document.createElement('th');
    case 'tr':
      return HTMLTableRowElement();
    case 'ul':
      return HTMLUListElement();
    case 'video':
      return HTMLVideoElement();
    case 'input':
      return createInputElement(domElement?.getAttributeValue('type'));

    default:
      return isTagSupported(tag) ? document.createElement(tag) : null;
  }
}

HTMLInputElement createInputElement([String? type]) {
  type = type?.trim().toLowerCase() ?? '';
  return HTMLInputElement()..type = type;
}

final Map<String, bool> _supportedTags = {};

bool isTagSupported(String? tag) {
  if (tag == null) return false;
  return _supportedTags[tag] ??= _isTagSupportedImpl(tag);
}

bool _isTagSupportedImpl(String tag) {
  tag = tag.trim().toLowerCase();

  var o = document.createElement(tag);

  if (o.isA<HTMLUnknownElement>()) {
    return false;
  }

  return true;
}
