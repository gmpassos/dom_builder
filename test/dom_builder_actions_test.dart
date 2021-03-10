import 'package:dom_builder/dom_builder.dart';
import 'package:test/test.dart';

import 'dom_builder_domtest.dart';

class TestActionExecutorLog extends DOMActionExecutor<TestNode> {
  final List<String> log = [];

  void clearLog() {
    log.clear();
  }

  @override
  TestNode? execute(
      DOMAction<TestNode> action, TestNode? target, TestNode? self,
      {DOMTreeMap? treeMap, DOMContext? context}) {
    log.add(action.actionString());
    return null;
  }
}

void main() {
  var executor = TestActionExecutorLog();

  group('DOMAction', () {
    setUp(() {});

    test('parse: sel', () {
      var action = DOMAction.parse(executor, '#foo')!;

      var sel = action as DOMActionSelect;
      expect(sel.id, equals('foo'));

      executor.clearLog();
      action.execute(TestElem('div')..attributes['id'] = 'foo');
      expect(executor.log, equals(['#foo']));
    });

    test('parse: call', () {
      var action = DOMAction.parse(executor, 'show()')!;

      var call = action as DOMActionCall;

      expect(call.name, equals('show'));
      expect(call.parameters, equals([]));

      executor.clearLog();
      action.execute(TestElem('div'));
      expect(executor.log, equals(['show()']));
    });

    test('parse: sel -> call', () {
      var action = DOMAction.parse(executor, '#foo.show()')!;

      var sel = action as DOMActionSelect;
      expect(sel.id, equals('foo'));

      var call = sel.next as DOMActionCall;

      expect(call.name, equals('show'));
      expect(call.parameters, equals([]));

      executor.clearLog();
      action.execute(TestElem('div')..attributes['id'] = 'foo');
      expect(executor.log, equals(['#foo', 'show()']));
    });

    test('parse: call ; sel -> call', () {
      var action = DOMAction.parse(executor, 'location(en); #foo.hide()')!;

      var list = action as DOMActionList;
      expect(list.actions.length, equals(2));

      var location = list.actions[0] as DOMActionCall;
      expect(location.name, equals('location'));
      expect(location.parameters, equals(['en']));

      var sel = list.actions[1] as DOMActionSelect;
      expect(sel.id, equals('foo'));

      var call = sel.next as DOMActionCall;

      expect(call.name, equals('hide'));
      expect(call.parameters, equals([]));

      executor.clearLog();
      action.execute(TestElem('div')..attributes['id'] = 'foo');
      expect(executor.log, equals(['location(en)', '#foo', 'hide()']));
    });
  });
}
