
import 'dart:html';

import 'dom_builder_generator.dart';
import 'dom_builder_base.dart';

import 'dom_builder_dart_html.dart' as dart_html ;

class DOMGeneratorDartHTMLImpl extends DOMGeneratorDartHTML<Element> {

  @override
  void appendElementText(Element element, String text) {
    element.appendText(text);
  }

  @override
  String getNodeText(TextNode domNode) {
    var text = domNode.text;
    return text;
  }

  @override
  void addChildToElement(Element element, Element child) {
    element.children.add( child ) ;
  }

  @override
  bool canHandleExternalElement(externalElement) {
    return externalElement is Node ;
  }

  @override
  Element addExternalElementToElement(Element element, dynamic externalElement) {
    if (externalElement is Node) {
      element.children.add( externalElement ) ;
      return externalElement ;
    }
    return null ;
  }

  @override
  void setAttribute(Element element, String attrName, String attrVal) {
    element.setAttribute(attrName, attrVal) ;
  }

  @override
  Element createElement(String tag) {
    return dart_html.createElement(tag) ;
  }

}

DOMGeneratorDartHTML<T> createDOMGeneratorDartHTML<T>() {
  return DOMGeneratorDartHTMLImpl() as DOMGeneratorDartHTML<T> ;
}

