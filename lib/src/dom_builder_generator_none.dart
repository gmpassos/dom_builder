import 'dom_builder_actions.dart';
import 'dom_builder_base.dart';
import 'dom_builder_context.dart';
import 'dom_builder_generator.dart';
import 'dom_builder_runtime.dart';
import 'dom_builder_treemap.dart';

/// Dummy [DOMGeneratorDartHTML] for platforms that doesn't supports `dart:html`.
///
/// Useful when [DOMGenerator.dartHTML] is called in the wrong platform.
class DOMGeneratorDartHTMLUnsupported<T> extends DOMGeneratorDartHTML<T/*!*/> {
  void _noDartHTML() {
    throw UnsupportedError('DOMGeneratorDartHTML: dart:html not loaded');
  }

  @override
  bool/*!*/ addChildToElement(T parent, T child) {
    _noDartHTML();
    return false;
  }

  @override
  bool/*!*/ removeChildFromElement(T parent, T child) {
    _noDartHTML();
    return false;
  }

  @override
  bool/*!*/ replaceChildElement(T parent, T child1, List<T/*!*/> child2) {
    _noDartHTML();
    return false;
  }

  @override
  T createElement(String tag, [DOMElement domElement]) {
    _noDartHTML();
    return null;
  }

  @override
  bool/*!*/ isTextNode(T node) {
    _noDartHTML();
    return null;
  }

  @override
  bool/*!*/ containsNode(T parent, T node) => false;

  @override
  void setAttributes(DOMElement domElement, T element,
      {bool preserveClass = false, bool preserveStyle = false}) {
    _noDartHTML();
  }

  @override
  String getNodeText(T node) {
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
  String getAttribute(T element, String attrName) {
    _noDartHTML();
    return null;
  }

  @override
  List<T> addExternalElementToElement(T element, Object/*?*/ externalElement) {
    _noDartHTML();
    return null;
  }

  @override
  bool/*!*/ canHandleExternalElement(externalElement) {
    return false;
  }

  @override
  String buildElementHTML(T element) {
    _noDartHTML();
    return null;
  }

  @override
  DOMNodeRuntime<T> createDOMNodeRuntime(
      DOMTreeMap<T/*!*/> treeMap, DOMNode domNode, T node) {
    _noDartHTML();
    return null;
  }

  @override
  T createTextNode(String text) {
    _noDartHTML();
    return null;
  }
}

class DOMActionExecutorDartHTMLUnsupported<T> extends DOMActionExecutor<T/*!*/> {
  void _noDartHTML() {
    throw UnsupportedError('DOMActionExecutorDartHTML: dart:html not loaded');
  }

  @override
  T execute(DOMAction action, T target, T self,
      {DOMTreeMap treeMap, DOMContext context}) {
    _noDartHTML();
    return null;
  }

  @override
  T call(String name, List<String> parameters, T target, T self,
      DOMTreeMap treeMap, DOMContext context) {
    _noDartHTML();
    return null;
  }

  @override
  T selectByID(
      String id, T target, T self, DOMTreeMap treeMap, DOMContext context) {
    _noDartHTML();
    return null;
  }
}

DOMGeneratorDartHTML<T/*!*/>/*!*/ createDOMGeneratorDartHTML<T>() {
  return DOMGeneratorDartHTMLUnsupported<T>();
}
