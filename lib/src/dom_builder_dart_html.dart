import 'dart:html';

/// Creates an [Element] using [tag] name.
@override
Element createElement(String tag) {
  switch (tag) {
    case 'a':
      return Element.a();
    case 'article':
      return Element.article();
    case 'aside':
      return Element.aside();
    case 'audio':
      return Element.audio();
    case 'br':
      return Element.br();
    case 'canvas':
      return Element.canvas();
    case 'div':
      return Element.div();
    case 'footer':
      return Element.footer();
    case 'header':
      return Element.header();
    case 'hr':
      return Element.hr();
    case 'iframe':
      return Element.iframe();
    case 'img':
      return Element.img();
    case 'li':
      return Element.li();
    case 'nav':
      return Element.nav();
    case 'ol':
      return Element.ol();
    case 'option':
      return Element.option();
    case 'p':
      return Element.p();
    case 'pre':
      return Element.pre();
    case 'section':
      return Element.section();
    case 'select':
      return Element.select();
    case 'span':
      return Element.span();
    case 'svg':
      return Element.svg();
    case 'table':
      return Element.table();
    case 'td':
      return Element.td();
    case 'textarea':
      return Element.textarea();
    case 'th':
      return Element.th();
    case 'tr':
      return Element.tr();
    case 'ul':
      return Element.ul();
    case 'video':
      return Element.video();

    default:
      return Element.tag(tag);
  }
}
