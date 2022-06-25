import 'package:swiss_knife/swiss_knife.dart';

import 'dom_builder_context.dart';
import 'dom_builder_generator.dart';
import 'dom_builder_treemap.dart';

abstract class DOMActionExecutor<T> {
  DOMGenerator<T>? _domGenerator;

  DOMGenerator<T>? get domGenerator => _domGenerator;

  set domGenerator(DOMGenerator<T>? generator) {
    if (generator == null) throw ArgumentError.notNull('generator');
    _domGenerator = generator;
  }

  T? execute(DOMAction<T> action, T? target, T? self,
      {DOMTreeMap? treeMap, DOMContext? context}) {
    T? result;
    if (action is DOMActionSelect<T>) {
      result = selectByID(action.id, target, self, treeMap, context);
    } else if (action is DOMActionCall<T>) {
      result =
          call(action.name, action.parameters, target, self, treeMap, context);
    }
    return result;
  }

  T? selectByID(
      String id, T? target, T? self, DOMTreeMap? treeMap, DOMContext? context) {
    throw UnimplementedError();
  }

  T? call(String name, List<String> parameters, T? target, T? self,
      DOMTreeMap? treeMap, DOMContext? context) {
    name = name.trim().toLowerCase();
    if (name.isEmpty) return null;

    switch (name) {
      case 'show':
        return callShow(self);
      case 'hide':
        return callHide(self);
      case 'delete':
      case 'remove':
        return callRemove(self);
      case 'clear':
        return callClear(self);
      case 'addclass':
      case 'addclasses':
        return callAddClass(self, parameters);
      case 'removeclass':
      case 'removeclasses':
        return callAddClass(self, parameters);
      case 'setclass':
      case 'setclasses':
        return callSetClass(self, parameters);
      case 'clearclass':
      case 'clearclasses':
        return callClearClass(self);
      case 'locale':
        return callLocale(self, parameters, context);
      default:
        return null;
    }
  }

  T? callShow(T? target) {
    throw UnimplementedError();
  }

  T? callHide(T? target) {
    throw UnimplementedError();
  }

  T? callRemove(T? target) {
    throw UnimplementedError();
  }

  T? callClear(T? target) {
    throw UnimplementedError();
  }

  T? callAddClass(T? target, List<String> classes) {
    throw UnimplementedError();
  }

  T callRemoveClass(T target, List<String> classes) {
    throw UnimplementedError();
  }

  T? callSetClass(T? target, List<String> classes) {
    throw UnimplementedError();
  }

  T? callClearClass(T? target) {
    throw UnimplementedError();
  }

  T? callLocale(T? target, List<String> parameters, DOMContext? context) {
    throw UnimplementedError();
  }

  DOMAction<T>? parse(String? actionLine) {
    return DOMAction.parse(this, actionLine);
  }
}

final RegExpDialect _regexpActionsDialect = RegExpDialect({
  'd': r'(?:-?\d+(?:\.\d+)?|-?\.\d+)',
  'bool': r'(?:true|false|yes|no|y|n)',
  'pos': r'$d(?:\%|\w+)',
  'id': r'[\w-]+',
  'color_rgba': r'(?:rgba?\(\s*\d+\s*,\s*\d+\s*,\s*\d+\s*(?:,\s*$d\s*)?\))',
  'color_hex': r'#(?:[0-9a-f]{3}|[0-9a-f]{6}|[0-9a-f]{8})',
  'color': r'(?:$color_rgba|$color_hex)',
  'quote': r'''(?:"[^"]*"|'[^']*')''',
  'parameter': r'(?:$quote|$pos|$d|$bool|$color|[\w-]+)',
  'parameter_capture': r'($parameter)(?:\s*,\s*)?',
  'parameters': r'$parameter(?:\s*,\s*$parameter)*',
  'call': r'\w+\(\s*(?:$parameters)?\s*\)',
  'call_capture': r'(\w+)\(\s*($parameters)?\s*\)',
  'sel': r'\#$id',
  'sel_capture': r'\#($id)',
  'action': r'(?:$sel|$call)',
  'action_capture': r'(?:($sel)|($call))',
}, multiLine: false, caseSensitive: false);

abstract class DOMAction<T> {
  static final RegExp _regexpActionCapture =
      _regexpActionsDialect.getPattern(r'$action_capture\.?');

  static final RegExp _regexpSelCapture =
      _regexpActionsDialect.getPattern(r'$sel_capture\.?');

  static final RegExp _regexpCallCapture =
      _regexpActionsDialect.getPattern(r'$call_capture\.?');

  static DOMAction<T>? parse<T>(
      DOMActionExecutor<T> executor, String? actionLine) {
    if (actionLine == null) return null;
    actionLine = actionLine.trim();
    if (actionLine.isEmpty) return null;

    var matches = _regexpActionCapture.allMatches(actionLine);

    var actions = <DOMAction<T>>[];

    DOMAction<T>? rootAction;
    DOMAction<T>? lastAction;

    var endPos = 0;
    for (var match in matches) {
      var part = match.group(0)!;

      if (match.start > endPos) {
        var prevChar = actionLine.substring(endPos, match.start).trim();

        if (prevChar == ';') {
          actions.add(rootAction!);
          rootAction = null;
          lastAction = null;
        } else {
          throw ArgumentError("Can't parse DOMAction line: $actionLine");
        }
      }

      var sel = match.group(1);
      var call = match.group(2);

      DOMAction<T> action;

      if (sel != null) {
        var selMatch = _regexpSelCapture.firstMatch(part)!;
        var id = selMatch.group(1)!;
        action = DOMActionSelect<T>(executor, id);
      } else if (call != null) {
        var callMatch = _regexpCallCapture.firstMatch(part)!;
        var name = callMatch.group(1)!;
        var parametersLine = callMatch.group(2);
        var parameters = parseParameters(executor, parametersLine);
        action = DOMActionCall<T>(executor, name, parameters);
      } else {
        throw ArgumentError("Can't parse DOMAction line: $actionLine");
      }

      rootAction ??= action;

      if (lastAction != null) {
        lastAction.next = action;
      }

      lastAction = action;

      endPos = match.end;
    }

    if (actions.isNotEmpty) {
      actions.add(rootAction!);
      return DOMActionList(executor, actions);
    }

    return rootAction;
  }

  static final RegExp _regexpParameterCapture =
      _regexpActionsDialect.getPattern(r'$parameter_capture');

  static List<String>? parseParameters<T>(
      DOMActionExecutor executor, String? parametersLine) {
    if (parametersLine == null) return null;
    parametersLine = parametersLine.trim();
    if (parametersLine.isEmpty) return null;

    var matches = _regexpParameterCapture.allMatches(parametersLine);

    var parameters = <String>[];

    var endPos = 0;
    for (var match in matches) {
      if (match.start != endPos) {
        throw ArgumentError("Can't parse parameters line: $parametersLine");
      }

      var param = match.group(1)!.trim();
      parameters.add(param);
    }

    return parameters;
  }

  final DOMActionExecutor<T> executor;

  DOMAction<T>? next;

  DOMAction(this.executor);

  T? execute(T? target, {T? self, DOMTreeMap? treeMap, DOMContext? context}) {
    var result = executor.execute(this, target, self,
        treeMap: treeMap, context: context);

    if (next != null) {
      result = next!
          .execute(target, self: result, treeMap: treeMap, context: context);
    }

    return result;
  }

  String actionString();

  @override
  String toString() {
    var s = actionString();
    if (next != null) {
      s += '.$next';
    }
    return s;
  }
}

class DOMActionList<T> extends DOMAction<T> {
  final List<DOMAction<T>> actions;

  DOMActionList(DOMActionExecutor<T> executor, this.actions) : super(executor);

  @override
  T? execute(T? target, {T? self, DOMTreeMap? treeMap, DOMContext? context}) {
    T? result;

    for (var action in actions) {
      result = action.execute(target,
          self: self, treeMap: treeMap, context: context);
    }

    return result;
  }

  @override
  String actionString() {
    return actions.join(';');
  }
}

class DOMActionSelect<T> extends DOMAction<T> {
  final String id;

  DOMActionSelect(DOMActionExecutor<T> executor, this.id) : super(executor);

  @override
  String actionString() {
    return '#$id';
  }
}

class DOMActionCall<T> extends DOMAction<T> {
  final String name;

  final List<String> parameters;

  DOMActionCall(
      DOMActionExecutor<T> executor, this.name, List<String>? parameters)
      : parameters = parameters ?? <String>[],
        super(executor);

  @override
  String actionString() {
    var paramsLine = parameters.join(' , ');
    return '$name($paramsLine)';
  }
}
