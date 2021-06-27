import 'dart:async';

import 'package:dom_builder/dom_builder.dart';
import 'package:test/test.dart';

Completer? _clickCompleter;

void _onClicked([int arg = -1]) {
  _clickCompleter!.complete(arg);
}

void main() {
  group('DSX', () {
    setUp(() {});

    test('button', () {
      var button = $dsx('''
        <button>CLICK ME!</button>
      ''');

      print(button);

      expect(button.length, equals(1));

      expect(button[0] is DOMElement, isTrue);
    });

    test('button: onclick function.dsx()', () async {
      var clickCompleter = _clickCompleter = Completer<int>();

      var button = $dsx('''
        <button onclick="${_onClicked.dsx()}">CLICK ME!</button>
      ''');

      print(button);

      expect(button.length, equals(1));

      var btn = button[0] as DOMElement;
      expect(btn is DOMElement, isTrue);

      expect(btn.onClick.isUsed, isTrue);

      btn.onClick.add(DOMMouseEvent.synthetic());

      var clickValue = await clickCompleter.future;

      expect(clickValue, equals(-1));
    });

    test('button: onclick \$dsxCall(function)', () async {
      var clickCompleter = _clickCompleter = Completer<int>();

      var button = $dsx('''
        <button onclick="${$dsxCall(_onClicked)}">CLICK ME!</button>
      ''');

      print(button);

      expect(button.length, equals(1));

      var btn = button[0] as DOMElement;
      expect(btn is DOMElement, isTrue);

      expect(btn.onClick.isUsed, isTrue);

      btn.onClick.add(DOMMouseEvent.synthetic());

      var clickValue = await clickCompleter.future;

      expect(clickValue, equals(-1));
    });

    test('button: onclick function.dsx(111)', () async {
      var clickCompleter = _clickCompleter = Completer<int>();

      var button = $dsx('''
        <button onclick="${_onClicked.dsx(11)}">CLICK ME!</button>
      ''');

      print(button);

      expect(button.length, equals(1));

      var btn = button[0] as DOMElement;
      expect(btn is DOMElement, isTrue);

      expect(btn.onClick.isUsed, isTrue);

      btn.onClick.add(DOMMouseEvent.synthetic());

      var clickValue = await clickCompleter.future;

      expect(clickValue, equals(11));
    });

    test('button: onclick lambda.dsx()', () async {
      var clickCompleter = Completer<int>();

      var button = $dsx('''
        <button onclick="${(() => clickCompleter.complete(123)).dsx()}">CLICK ME!</button>
      ''');

      print(button);

      expect(button.length, equals(1));

      var btn = button[0] as DOMElement;
      expect(btn is DOMElement, isTrue);

      expect(btn.onClick.isUsed, isTrue);

      btn.onClick.add(DOMMouseEvent.synthetic());

      var clickValue = await clickCompleter.future;

      expect(clickValue, equals(123));
    });

    test('button: content lambda.dsx()', () async {
      var button = $dsx('''
        <button name="${((x) => 'abc$x').dsx(10)}">${(() => 123456).dsx()}  {{foo}}</button>
      ''');

      print(button);

      expect(button.length, equals(1));

      var btn = button[0] as DOMElement;
      expect(btn is DOMElement, isTrue);

      var html = btn.buildHTML();
      print(html);
      expect(
          html,
          equals(
              '<button name="{{__DSX__function_4}}">{{__DSX__function_5}}  {{foo}}</button>'));

      var htmlResolvedDSX = btn.buildHTML(resolveDSX: true);
      print(htmlResolvedDSX);
      expect(htmlResolvedDSX,
          equals('<button name="abc10">123456  {{foo}}</button>'));
    });
  });
}
