import 'dom_builder_actions.dart';
import 'dom_builder_base.dart';
import 'dom_builder_context.dart';
import 'dom_builder_generator.dart';
import 'dom_builder_runtime.dart';
import 'dom_builder_treemap.dart';

/// Dummy [DOMGeneratorUnsupported] for platforms that doesn't support a [DOMGenerator].
///
/// Useful when a [DOMGenerator] is used in the wrong platform.
class DOMGeneratorUnsupported<T extends Object> extends DOMGenerator<T> {
  final String unsupportedDOMGenerator;

  final String unsupportedPackage;

  DOMGeneratorUnsupported(
      this.unsupportedDOMGenerator, this.unsupportedPackage);

  Never _notSupported() {
    throw UnsupportedError(
        "Unsupported `$unsupportedDOMGenerator`: can't load package `$unsupportedPackage`!");
  }

  @override
  bool isChildOfElement(T? parent, T? child) {
    _notSupported();
  }

  @override
  bool addChildToElement(T? parent, T? child) {
    _notSupported();
  }

  @override
  bool removeChildFromElement(T parent, T? child) {
    _notSupported();
  }

  @override
  bool replaceChildElement(T parent, T? child1, List<T>? child2) {
    _notSupported();
  }

  @override
  T? createElement(String? tag, [DOMElement? domElement]) {
    _notSupported();
  }

  @override
  T? createSVGElement(DOMElement domElement) {
    _notSupported();
  }

  @override
  bool isTextNode(T? node) {
    _notSupported();
  }

  @override
  bool containsNode(T parent, T? node) => false;

  @override
  void setAttributes(DOMElement domElement, T element, DOMTreeMap<T> treeMap,
      {bool preserveClass = false, bool preserveStyle = false}) {
    _notSupported();
  }

  @override
  String? getNodeText(T? node) {
    _notSupported();
  }

  @override
  T? appendElementText(T element, String? text) {
    _notSupported();
  }

  @override
  void setAttribute(T element, String attrName, String? attrVal) {
    _notSupported();
  }

  @override
  String? getAttribute(T element, String attrName) {
    _notSupported();
  }

  @override
  List<T>? addExternalElementToElement(T element, Object? externalElement) {
    _notSupported();
  }

  @override
  bool canHandleExternalElement(externalElement) {
    return false;
  }

  @override
  String? buildElementHTML(T element) {
    _notSupported();
  }

  @override
  DOMNodeRuntime<T>? createDOMNodeRuntime(
      DOMTreeMap<T> treeMap, DOMNode? domNode, T node) {
    _notSupported();
  }

  @override
  T? createTextNode(Object? text) {
    _notSupported();
  }
}

class DOMActionExecutorDartHTMLUnsupported<T extends Object>
    extends DOMActionExecutor<T> {
  void _noDartHTML() {
    throw UnsupportedError('DOMActionExecutorDartHTML: dart:html not loaded');
  }

  @override
  T? execute(DOMAction action, T? target, T? self,
      {DOMTreeMap? treeMap, DOMContext? context}) {
    _noDartHTML();
    return null;
  }

  @override
  T? call(String name, List<String> parameters, T? target, T? self,
      DOMTreeMap? treeMap, DOMContext? context) {
    _noDartHTML();
    return null;
  }

  @override
  T? selectByID(
      String id, T? target, T? self, DOMTreeMap? treeMap, DOMContext? context) {
    _noDartHTML();
    return null;
  }
}

@Deprecated("Use `_DOMGeneratorWebUnsupported`")
class _DOMGeneratorDartHTMLUnsupported<T extends Object>
    extends DOMGeneratorUnsupported<T> implements DOMGeneratorDartHTML<T> {
  _DOMGeneratorDartHTMLUnsupported()
      : super('DOMGeneratorDartHTML', 'dart:html');
}

class _DOMGeneratorWebUnsupported<T extends Object>
    extends DOMGeneratorUnsupported<T> implements DOMGeneratorWeb<T> {
  _DOMGeneratorWebUnsupported() : super('DOMGeneratorWeb', 'web');
}

@Deprecated("Use `createDOMGeneratorWeb`")
DOMGeneratorDartHTML<T> createDOMGeneratorDartHTML<T extends Object>() {
  return _DOMGeneratorDartHTMLUnsupported<T>();
}

DOMGeneratorWeb<T> createDOMGeneratorWeb<T extends Object>() {
  return _DOMGeneratorWebUnsupported<T>();
}
