import 'package:dom_builder/dom_builder.dart';
import 'package:test/test.dart';

void main() {
  group('DOMAction', () {
    setUp(() {});

    test('parse: var 1', () {
      var source = 'My name is {{name}}!';

      var template = DOMTemplate.parse(source);
      expect(template.nodes.length, equals(3));
      expect(template.toString(), equals(source));

      var s1 = template.buildAsString({'name': 'Joe'});
      expect(s1, equals('My name is Joe!'));

      var s2 = template.buildAsString({});
      expect(s2, equals('My name is !'));
    });

    test('parse: var 2', () {
      var source = 'My name is {{name}}!!!';

      var template = DOMTemplate.parse(source);
      expect(template.nodes.length, equals(3));
      expect(template.toString(), equals(source));

      var s1 = template.buildAsString({'name': 'Joe'});
      expect(s1, equals('My name is Joe!!!'));

      var s2 = template.buildAsString({});
      expect(s2, equals('My name is !!!'));
    });

    test('parse: var 3', () {
      var source = 'My name is {{name}}';

      var template = DOMTemplate.parse(source);
      expect(template.nodes.length, equals(2));
      expect(template.toString(), equals(source));

      var s1 = template.buildAsString({'name': 'Joe'});
      expect(s1, equals('My name is Joe'));

      var s2 = template.buildAsString({});
      expect(s2, equals('My name is '));
    });

    test('parse: var 4', () {
      var source = 'My name is {{ name }}.';

      var template = DOMTemplate.parse(source);
      expect(template.nodes.length, equals(3));
      expect(template.toString(), equals('My name is {{name}}.'));

      var s1 = template.buildAsString({'name': 'Joe'});
      expect(s1, equals('My name is Joe.'));

      var s2 = template.buildAsString({});
      expect(s2, equals('My name is .'));
    });

    test('parse: var else', () {
      var source = 'name is {{?name}}unknown{{/}}!';

      var template = DOMTemplate.parse(source);
      expect(template.nodes.length, equals(3));
      expect(template.toString(), equals(source));

      var s1 = template.buildAsString({'name': 'Joe'});
      expect(s1, equals('name is Joe!'));

      var s2 = template.buildAsString({});
      expect(s2, equals('name is unknown!'));
    });

    test('parse: if 1', () {
      var source = 'name var {{:name}}present{{/}}!';

      var template = DOMTemplate.parse(source);
      expect(template.nodes.length, equals(3));
      expect(template.toString(), equals(source));

      var s1 = template.buildAsString({'name': 'Joe'});
      expect(s1, equals('name var present!'));

      var s2 = template.buildAsString({});
      expect(s2, equals('name var !'));
    });

    test('parse: if 2', () {
      var source = 'name var {{:name}}present{{/name}}!';

      var template = DOMTemplate.parse(source);
      expect(template.nodes.length, equals(3));
      expect(template.toString(), equals('name var {{:name}}present{{/}}!'));

      var s1 = template.buildAsString({'name': 'Joe'});
      expect(s1, equals('name var present!'));

      var s2 = template.buildAsString({});
      expect(s2, equals('name var !'));
    });

    test('parse: not 1', () {
      var source = 'Name is {{!name}}empty{{/}}!';

      var template = DOMTemplate.parse(source);
      expect(template.nodes.length, equals(3));
      expect(template.toString(), equals(source));

      var s1 = template.buildAsString({});
      expect(s1, equals('Name is empty!'));

      var s2 = template.buildAsString({'name': 'Joe'});
      expect(s2, equals('Name is !'));
    });

    test('parse: not 2', () {
      var source = 'Name is {{!name}}empty{{/name}}!';

      var template = DOMTemplate.parse(source);
      expect(template.nodes.length, equals(3));
      expect(template.toString(), equals('Name is {{!name}}empty{{/}}!'));

      var s1 = template.buildAsString({});
      expect(s1, equals('Name is empty!'));

      var s2 = template.buildAsString({'name': 'Joe'});
      expect(s2, equals('Name is !'));
    });

    test('parse: if_else 1', () {
      var source = 'My name is {{:name}}Foo{{?}}Bar{{/}}!';

      var template = DOMTemplate.parse(source);
      expect(template.nodes.length, equals(3));
      expect(template.toString(), equals(source));

      var s1 = template.buildAsString({'name': 'Joe'});
      expect(s1, equals('My name is Foo!'));

      var s2 = template.buildAsString({});
      expect(s2, equals('My name is Bar!'));
    });

    test('parse: if_elseif_else 1', () {
      var source = 'My name is {{:name}}Foo{{?:surname}}Fii{{?}}Bar{{/}}!';

      var template = DOMTemplate.parse(source);
      expect(template.nodes.length, equals(3));
      expect(template.toString(), equals(source));

      var s1 = template.buildAsString({'name': 'Joe'});
      expect(s1, equals('My name is Foo!'));

      var s2 = template.buildAsString({'surname': '2nd'});
      expect(s2, equals('My name is Fii!'));

      var s3 = template.buildAsString({});
      expect(s3, equals('My name is Bar!'));
    });

    test('parse: if_elseif_elseif_else 1', () {
      var source =
          'My name is {{:name}}Foo{{?:surname}}Fii{{?:nickname}}Fuu{{?}}Bar{{/}}!';

      var template = DOMTemplate.parse(source);
      expect(template.nodes.length, equals(3));
      expect(template.toString(), equals(source));

      var s1 = template.buildAsString({'name': 'Joe'});
      expect(s1, equals('My name is Foo!'));

      var s2 = template.buildAsString({'surname': '2nd'});
      expect(s2, equals('My name is Fii!'));

      var s3 = template.buildAsString({'nickname': 'J'});
      expect(s3, equals('My name is Fuu!'));

      var s4 = template.buildAsString({});
      expect(s4, equals('My name is Bar!'));
    });

    test('parse: if_elseif_elseif 1', () {
      var source = 'My name is {{:name}}Foo{{?:surname}}Fii{{/}}!';

      var template = DOMTemplate.parse(source);
      expect(template.nodes.length, equals(3));
      expect(template.toString(), equals(source));

      var s1 = template.buildAsString({'name': 'Joe'});
      expect(s1, equals('My name is Foo!'));

      var s2 = template.buildAsString({'surname': '2nd'});
      expect(s2, equals('My name is Fii!'));

      var s3 = template.buildAsString({});
      expect(s3, equals('My name is !'));
    });

    test('parse: not_else 1', () {
      var source = 'name is {{!name}}empty{{?}}present{{/}}!';

      var template = DOMTemplate.parse(source);
      expect(template.nodes.length, equals(3));
      expect(template.toString(), equals(source));

      var s1 = template.buildAsString({});
      expect(s1, equals('name is empty!'));

      var s2 = template.buildAsString({'name': 'Joe'});
      expect(s2, equals('name is present!'));
    });

    test('parse: if{ var } 1', () {
      var source = 'E-mail is {{:name}}"{{email}}"{{/}}!';

      var template = DOMTemplate.parse(source);
      expect(template.nodes.length, equals(3));
      expect(template.toString(), equals(source));

      var s1 = template.buildAsString({'email': 'a@b.c'});
      expect(s1, equals('E-mail is !'));

      var s2 = template.buildAsString({'name': 'Joe', 'email': 'a@b.c'});
      expect(s2, equals('E-mail is "a@b.c"!'));
    });

    test('parse: if{ var }_else 1', () {
      var source = 'E-mail is {{:name}}"{{email}}"{{?}}unknown_user{{/}}!';

      var template = DOMTemplate.parse(source);
      expect(template.nodes.length, equals(3));
      expect(template.toString(), equals(source));

      var s1 = template.buildAsString({'email': 'a@b.c'});
      expect(s1, equals('E-mail is unknown_user!'));

      var s2 = template.buildAsString({'name': 'Joe', 'email': 'a@b.c'});
      expect(s2, equals('E-mail is "a@b.c"!'));
    });

    test('parse: if{ var_else }_else 1', () {
      var source =
          'E-mail is {{:name}}"{{?email}}NULL_MAIL{{/}}"{{?}}unknown_user{{/}}!';

      var template = DOMTemplate.parse(source);
      expect(template.nodes.length, equals(3));
      expect(template.toString(), equals(source));

      var s1 = template.buildAsString({'email': 'a@b.c'});
      expect(s1, equals('E-mail is unknown_user!'));

      var s2 = template.buildAsString({'name': 'Joe', 'email': 'a@b.c'});
      expect(s2, equals('E-mail is "a@b.c"!'));

      var s3 = template.buildAsString({'name': 'Joe'});
      expect(s3, equals('E-mail is "NULL_MAIL"!'));
    });

    test('parse: ifList 1', () {
      var source = 'Routes:{{*:routes}} [{{name}}]{{/}}!';

      var template = DOMTemplate.parse(source);
      expect(template.nodes.length, equals(3));
      expect(template.toString(), equals(source));

      var s1 = template.buildAsString({
        'routes': [
          {'name': 'Home'},
          {'name': 'About'}
        ]
      });
      expect(s1, equals('Routes: [Home] [About]!'));

      var s2 = template.buildAsString({'routes': []});
      expect(s2, equals('Routes:!'));

      var s3 = template.buildAsString({});
      expect(s3, equals('Routes:!'));
    });

    test('parse: ifList 2', () {
      var source = 'Route 1: {{routes.1.name}}!';

      var template = DOMTemplate.parse(source);
      expect(template.nodes.length, equals(3));
      expect(template.toString(), equals(source));

      var s1 = template.buildAsString({
        'routes': [
          {'name': 'Home'},
          {'name': 'About'}
        ]
      });
      expect(s1, equals('Route 1: About!'));

      var s2 = template.buildAsString({'routes': []});
      expect(s2, equals('Route 1: !'));

      var s3 = template.buildAsString({});
      expect(s3, equals('Route 1: !'));

      var s4 = template.buildAsString({
        'routes': [
          {'name': 'Home'}
        ]
      });
      expect(s4, equals('Route 1: !'));
    });

    test('parse: ifList 3', () {
      var source = 'Routes:{{*:routes}} [{{.}}]{{/}}!';

      var template = DOMTemplate.parse(source);
      expect(template.nodes.length, equals(3));
      expect(template.toString(), equals(source));

      var s1 = template.buildAsString({
        'routes': [
          {'name': 'Home'},
          {'name': 'About'}
        ]
      });
      expect(s1, equals('Routes: [name: Home] [name: About]!'));

      var s2 = template.buildAsString({'routes': []});
      expect(s2, equals('Routes:!'));

      var s3 = template.buildAsString({});
      expect(s3, equals('Routes:!'));

      var s4 = template.buildAsString({
        'routes': ['Home', 'About']
      });
      expect(s4, equals('Routes: [Home] [About]!'));
    });

    test('parse: ifList_else 1', () {
      var source = 'Routes:{{*:routes}} [{{name}}]{{?}} NO ROUTES{{/}}!';

      var template = DOMTemplate.parse(source);
      expect(template.nodes.length, equals(3));
      expect(template.toString(), equals(source));

      var s1 = template.buildAsString({
        'routes': [
          {'name': 'Home'},
          {'name': 'About'}
        ]
      });
      expect(s1, equals('Routes: [Home] [About]!'));

      var s2 = template.buildAsString({'routes': []});
      expect(s2, equals('Routes: NO ROUTES!'));

      var s3 = template.buildAsString({});
      expect(s3, equals('Routes: NO ROUTES!'));
    });

    test('parse: notList 1', () {
      var source = 'Routes:{{!routes}}{{no_routes}}{{/}}!';

      var template = DOMTemplate.parse(source);
      expect(template.nodes.length, equals(3));
      expect(template.toString(), equals(source));

      var s1 = template.buildAsString({
        'no_routes': 'Empty routes',
        'routes': [
          {'name': 'Home'},
          {'name': 'About'}
        ]
      });
      expect(s1, equals('Routes:!'));

      var s2 = template.buildAsString({'no_routes': 'Empty routes'});
      expect(s2, equals('Routes:Empty routes!'));
    });

    test('parse: query element', () {
      var source = 'Element: {{:ok}}{{#element_x}}{{/}}!';

      var template = DOMTemplate.parse(source);
      expect(template.nodes.length, equals(3));
      expect(template.toString(), equals(source));

      String? elementProvider(String q) {
        return q == '#element_x' ? 'XXX' : null;
      }

      var s1 = template
          .buildAsString({'ok': true}, elementProvider: elementProvider);
      expect(s1, equals('Element: XXX!'));

      var s2 = template
          .buildAsString({'ok': false}, elementProvider: elementProvider);
      expect(s2, equals('Element: !'));
    });

    test('parse: ifEq{ var } 1', () {
      var source =
          'Hello! Good {{:period=="am"}}morning{{?:period=="pm"}}afternoon{{?}}day{{/}}!';

      var template = DOMTemplate.parse(source);
      expect(template.nodes.length, equals(3));
      expect(template.toString(), equals(source));

      var s1 = template.buildAsString({'period': 'am'});
      expect(s1, equals('Hello! Good morning!'));

      var s2 = template.buildAsString({'period': 'pm'});
      expect(s2, equals('Hello! Good afternoon!'));

      var s3 = template.buildAsString({'period': ''});
      expect(s3, equals('Hello! Good day!'));
    });

    test('parse: ifEq{ var } 2', () {
      var source =
          'Hello! Period: {{:period==hourPeriod}}match{{?}}no match{{/}}!';

      var template = DOMTemplate.parse(source);
      expect(template.nodes.length, equals(3));
      expect(template.toString(), equals(source));

      var s1 = template.buildAsString({'period': 'am', 'hourPeriod': 'am'});
      expect(s1, equals('Hello! Period: match!'));

      var s2 = template.buildAsString({'period': 'am', 'hourPeriod': 'pm'});
      expect(s2, equals('Hello! Period: no match!'));
    });

    test('parse: ifNotEq{ var } 2', () {
      var source = 'Hello! Period: {{:period!=hourPeriod}}diff{{?}}eq{{/}}!';

      var template = DOMTemplate.parse(source);
      expect(template.nodes.length, equals(3));
      expect(template.toString(), equals(source));

      var s1 = template.buildAsString({'period': 'am', 'hourPeriod': 'am'});
      expect(s1, equals('Hello! Period: eq!'));

      var s2 = template.buildAsString({'period': 'am', 'hourPeriod': 'pm'});
      expect(s2, equals('Hello! Period: diff!'));
    });

    test('parse: ifList (menu)', () {
      var source = 'Menu:\n'
          '{{*:menu}}'
          '- #{{route}}: {{name}}{{:current}} (active){{/}}\n'
          '{{/}}';

      var template = DOMTemplate.parse(source);
      expect(template.nodes.length, equals(2));
      expect(template.toString(), equals(source));

      var s1 = template.buildAsString({
        'menu': [
          {'route': 'home', 'name': 'Welcome', 'current': true},
          {'route': 'help', 'name': 'Help-me'},
        ]
      });
      expect(
          s1,
          equals('Menu:\n'
              '- #home: Welcome (active)\n'
              '- #help: Help-me\n'));
    });

    test('tryParse', () {
      var source1 = 'Hello! Period: {{:period!=hourPeriod}}diff{{?}}eq{{/}}!';
      var source2 = 'Hello! Period: {{:period!=hourPeriod}}diff{{?}}eq!';

      var template1 = DOMTemplate.tryParse(source1)!;
      expect(template1.nodes.length, equals(3));
      expect(template1.toString(), equals(source1));

      var template2 = DOMTemplate.tryParse(source2);
      expect(template2, isNull);
    });

    test('intl:hi', () {
      var source1 = '{{intl:hi}} Joe!';

      var template1 = DOMTemplate.tryParse(source1)!;
      expect(template1.nodes.length, equals(2));
      expect(template1.toString(), equals(source1));

      expect(
          template1.buildAsString({},
              intlMessageResolver: toIntlMessageResolver({'hi': 'Hi'})),
          equals('Hi Joe!'));

      expect(
          template1.buildAsString({},
              intlMessageResolver: toIntlMessageResolver({'hi': 'Olá'})),
          equals('Olá Joe!'));
    });

    test('intl:parameters', () {
      var source1 = '{{intl:hi}} {{intl:child}}!';

      var template1 = DOMTemplate.tryParse(source1)!;
      expect(template1.nodes.length, equals(4));
      expect(template1.toString(), equals(source1));

      String msgResolver(String key, [Map<String, dynamic>? parameters]) {
        switch (key) {
          case 'hi':
            return 'Hello';
          case 'child':
            return parameters!['n'] > 1 ? 'children' : 'child';
          default:
            return '?';
        }
      }

      expect(
          template1.buildAsString({'n': 1}, intlMessageResolver: msgResolver),
          equals('Hello child!'));

      expect(
          template1.buildAsString({'n': 2}, intlMessageResolver: msgResolver),
          equals('Hello children!'));
    });

    test('DOMNode with template', () {
      var clicks = <int>[];

      String clickFunction() {
        clicks.add(clicks.length);
        return '!RET!';
      }

      var source1 = '<div title="{{intl:hi}}" onclick="${clickFunction.dsx()}">'
          '{{:period=="am"}}<b>morning</b>{{?:period=="pm"}}afternoon{{?}}day{{/}}'
          '</div>';

      var div = $htmlRoot(source1)!;

      expect(div.hasTemplate, isTrue);
      expect(div.hasUnresolvedTemplate, isTrue);

      expect(clicks, isEmpty);

      var contextAM = DOMContext(
          intlMessageResolver: (k, [p]) => k.trim().toUpperCase(),
          variables: {'period': 'am'});

      var contextPM = DOMContext(
          intlMessageResolver: (k, [p]) => k.trim().toUpperCase(),
          variables: {'period': 'pm'});

      var source2 = div.buildHTML(domContext: contextAM);

      expectFilteredDSXFunction(
        source2,
        '<div title="HI" onclick="{{__DSX__function_D}}">'
        '{{:period=="am"}}<b>morning</b>{{?:period=="pm"}}afternoon{{?}}day{{/}}'
        '</div>',
      );

      var source3 = div.buildHTML(domContext: contextAM, buildTemplates: true);

      expectFilteredDSXFunction(
        source3,
        '<div title="HI" onclick="{{__DSX__function_D}}"><b>morning</b></div>',
      );

      var source4 = div.buildHTML(domContext: contextPM, buildTemplates: true);

      expectFilteredDSXFunction(
        source4,
        '<div title="HI" onclick="{{__DSX__function_D}}">afternoon</div>',
      );

      expect(clicks, isEmpty);

      var template = DOMTemplate.parse(source2);

      expect(template.hasOnlyContent, isFalse);

      expect(clicks, isEmpty);

      var s1 = template.buildAsString({'period': 'am'}, resolveDSX: false);
      expectFilteredDSXFunction(s1,
          '<div title="HI" onclick="{{__DSX__function_D}}"><b>morning</b></div>');

      expect(clicks, isEmpty);

      var s2 = template.buildAsString({'period': 'pm'}, resolveDSX: false);
      expectFilteredDSXFunction(s2,
          '<div title="HI" onclick="{{__DSX__function_D}}">afternoon</div>');

      expect(clicks, isEmpty);

      var s3 = template.buildAsString({'period': '?'}, resolveDSX: false);
      expectFilteredDSXFunction(
          s3, '<div title="HI" onclick="{{__DSX__function_D}}">day</div>');

      expect(clicks, isEmpty);

      var s4 = template.buildAsString({'period': 'am'}, resolveDSX: true);
      expect(
          s4, equals('<div title="HI" onclick="!RET!"><b>morning</b></div>'));

      expect(clicks, isNotEmpty);
    });
  });
}

void expectFilteredDSXFunction(String s, String expected) {
  expectFiltered(
      s, RegExp(r'__DSX__function_\d+'), '__DSX__function_D', expected);
}

void expectFiltered(String s, RegExp filter, String replace, String expected) {
  expect(s.replaceAll(filter, replace), equals(expected));
}
