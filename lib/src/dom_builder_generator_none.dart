import 'dom_builder_base.dart';
import 'dom_builder_generator.dart';
import 'dom_builder_treemap.dart';
import 'dom_builder_runtime.dart';

/// Dummy [DOMGeneratorDartHTML] for platforms that doesn't supports `dart:html`.
///
/// Useful when [DOMGenerator.dartHTML] is called in the wrong platform.
class DOMGeneratorDartHTMLUnsupported<T> extends DOMGeneratorDartHTML<T> {
  void _noDartHTML() {
    throw UnsupportedError('DOMGeneratorDartHTML: dart:html not loaded');
  }

  @override
  void addChildToElement(T element, T child) {
    _noDartHTML();
  }

  @override
  T createElement(String tag) {
    _noDartHTML();
    return null;
  }


  @override
  bool isTextNode(T node) {
    _noDartHTML();
    return null;
  }


  @override
  void setAttributes(DOMElement domElement, T element) {
    _noDartHTML();
  }

  @override
  String getNodeText(TextNode domNode) {
    _noDartHTML();
    return null;
  }

  @override
  T appendElementText(T element, String text) {
    _noDartHTML();
    return null;
  }

  @override
  void setAttribute(T element, String attrName, String attrVal) {
    _noDartHTML();
  }

  @override
  List<T> addExternalElementToElement(T element, dynamic externalElement) {
    _noDartHTML();
    return null;
  }

  @override
  bool canHandleExternalElement(externalElement) {
    return false;
  }

  @override
  String buildElementHTML(T element) {
    _noDartHTML();
    return null;
  }

  @override
  DOMNodeRuntime<T> createDOMNodeRuntime(DOMTreeMap<T> treeMap, DOMNode domNode, T node) {
    _noDartHTML();
    return null;
  }

  @override
  T createTextNode(String text) {
    _noDartHTML();
    return null;
  }

}

DOMGeneratorDartHTML<T> createDOMGeneratorDartHTML<T>() {
  return DOMGeneratorDartHTMLUnsupported<T>();
}
