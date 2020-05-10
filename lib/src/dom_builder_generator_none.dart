
import 'dom_builder_generator.dart';
import 'dom_builder_base.dart';


class DOMGeneratorDartHTMLNone<T> extends DOMGeneratorDartHTML<T> {

  void _noDartHTML() {
    throw UnsupportedError('DOMGeneratorDartHTML: dart:html not loaded') ;
  }

  @override
  void addToElement(T element, T child) {
    _noDartHTML();
  }

  @override
  T createElement(String tag) {
    _noDartHTML();
    return null ;;
  }

  @override
  void setAttributes( DOMElement domElement , T element ) {
    _noDartHTML();
  }

  @override
  String getNodeText(TextNode domNode) {
    _noDartHTML();
    return null;
  }

  @override
  void appendElementText(T element, String text) {
    _noDartHTML();
  }

}


DOMGeneratorDartHTML<T> createDOMGeneratorDartHTML<T>() {
  return DOMGeneratorDartHTMLNone<T>() ;
}

