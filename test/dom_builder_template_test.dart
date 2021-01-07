import 'package:dom_builder/src/dom_builder_template.dart';
import 'package:test/test.dart';

void main() {
  group('DOMAction', () {
    setUp(() {});

    test('parse: var 1', () {
      var source = 'My name is {{name}}!';

      var template = DOMTemplate.parse(source);
      expect(template.nodes.length, equals(3));
      expect(template.toString(), equals(source));

      var s1 = template.build({'name': 'Joe'});
      expect(s1, equals('My name is Joe!'));

      var s2 = template.build({});
      expect(s2, equals('My name is !'));
    });

    test('parse: var 2', () {
      var source = 'My name is {{name}}!!!';

      var template = DOMTemplate.parse(source);
      expect(template.nodes.length, equals(3));
      expect(template.toString(), equals(source));

      var s1 = template.build({'name': 'Joe'});
      expect(s1, equals('My name is Joe!!!'));

      var s2 = template.build({});
      expect(s2, equals('My name is !!!'));
    });

    test('parse: var 3', () {
      var source = 'My name is {{name}}';

      var template = DOMTemplate.parse(source);
      expect(template.nodes.length, equals(2));
      expect(template.toString(), equals(source));

      var s1 = template.build({'name': 'Joe'});
      expect(s1, equals('My name is Joe'));

      var s2 = template.build({});
      expect(s2, equals('My name is '));
    });

    test('parse: var 4', () {
      var source = 'My name is {{ name }}.';

      var template = DOMTemplate.parse(source);
      expect(template.nodes.length, equals(3));
      expect(template.toString(), equals('My name is {{name}}.'));

      var s1 = template.build({'name': 'Joe'});
      expect(s1, equals('My name is Joe.'));

      var s2 = template.build({});
      expect(s2, equals('My name is .'));
    });

    test('parse: var else', () {
      var source = 'name is {{?name}}unknown{{/}}!';

      var template = DOMTemplate.parse(source);
      expect(template.nodes.length, equals(3));
      expect(template.toString(), equals(source));

      var s1 = template.build({'name': 'Joe'});
      expect(s1, equals('name is Joe!'));

      var s2 = template.build({});
      expect(s2, equals('name is unknown!'));
    });

    test('parse: if 1', () {
      var source = 'name var {{:name}}present{{/}}!';

      var template = DOMTemplate.parse(source);
      expect(template.nodes.length, equals(3));
      expect(template.toString(), equals(source));

      var s1 = template.build({'name': 'Joe'});
      expect(s1, equals('name var present!'));

      var s2 = template.build({});
      expect(s2, equals('name var !'));
    });

    test('parse: if 2', () {
      var source = 'name var {{:name}}present{{/name}}!';

      var template = DOMTemplate.parse(source);
      expect(template.nodes.length, equals(3));
      expect(template.toString(), equals('name var {{:name}}present{{/}}!'));

      var s1 = template.build({'name': 'Joe'});
      expect(s1, equals('name var present!'));

      var s2 = template.build({});
      expect(s2, equals('name var !'));
    });

    test('parse: not 1', () {
      var source = 'Name is {{!name}}empty{{/}}!';

      var template = DOMTemplate.parse(source);
      expect(template.nodes.length, equals(3));
      expect(template.toString(), equals(source));

      var s1 = template.build({});
      expect(s1, equals('Name is empty!'));

      var s2 = template.build({'name': 'Joe'});
      expect(s2, equals('Name is !'));
    });

    test('parse: not 2', () {
      var source = 'Name is {{!name}}empty{{/name}}!';

      var template = DOMTemplate.parse(source);
      expect(template.nodes.length, equals(3));
      expect(template.toString(), equals('Name is {{!name}}empty{{/}}!'));

      var s1 = template.build({});
      expect(s1, equals('Name is empty!'));

      var s2 = template.build({'name': 'Joe'});
      expect(s2, equals('Name is !'));
    });

    test('parse: if_else 1', () {
      var source = 'My name is {{:name}}Foo{{?}}Bar{{/}}!';

      var template = DOMTemplate.parse(source);
      expect(template.nodes.length, equals(3));
      expect(template.toString(), equals(source));

      var s1 = template.build({'name': 'Joe'});
      expect(s1, equals('My name is Foo!'));

      var s2 = template.build({});
      expect(s2, equals('My name is Bar!'));
    });

    test('parse: if_elseif_else 1', () {
      var source = 'My name is {{:name}}Foo{{?:surname}}Fii{{?}}Bar{{/}}!';

      var template = DOMTemplate.parse(source);
      expect(template.nodes.length, equals(3));
      expect(template.toString(), equals(source));

      var s1 = template.build({'name': 'Joe'});
      expect(s1, equals('My name is Foo!'));

      var s2 = template.build({'surname': '2nd'});
      expect(s2, equals('My name is Fii!'));

      var s3 = template.build({});
      expect(s3, equals('My name is Bar!'));
    });

    test('parse: if_elseif_elseif_else 1', () {
      var source =
          'My name is {{:name}}Foo{{?:surname}}Fii{{?:nickname}}Fuu{{?}}Bar{{/}}!';

      var template = DOMTemplate.parse(source);
      expect(template.nodes.length, equals(3));
      expect(template.toString(), equals(source));

      var s1 = template.build({'name': 'Joe'});
      expect(s1, equals('My name is Foo!'));

      var s2 = template.build({'surname': '2nd'});
      expect(s2, equals('My name is Fii!'));

      var s3 = template.build({'nickname': 'J'});
      expect(s3, equals('My name is Fuu!'));

      var s4 = template.build({});
      expect(s4, equals('My name is Bar!'));
    });

    test('parse: if_elseif_elseif 1', () {
      var source = 'My name is {{:name}}Foo{{?:surname}}Fii{{/}}!';

      var template = DOMTemplate.parse(source);
      expect(template.nodes.length, equals(3));
      expect(template.toString(), equals(source));

      var s1 = template.build({'name': 'Joe'});
      expect(s1, equals('My name is Foo!'));

      var s2 = template.build({'surname': '2nd'});
      expect(s2, equals('My name is Fii!'));

      var s3 = template.build({});
      expect(s3, equals('My name is !'));
    });

    test('parse: not_else 1', () {
      var source = 'name is {{!name}}empty{{?}}present{{/}}!';

      var template = DOMTemplate.parse(source);
      expect(template.nodes.length, equals(3));
      expect(template.toString(), equals(source));

      var s1 = template.build({});
      expect(s1, equals('name is empty!'));

      var s2 = template.build({'name': 'Joe'});
      expect(s2, equals('name is present!'));
    });

    test('parse: if{ var } 1', () {
      var source = 'E-mail is {{:name}}"{{email}}"{{/}}!';

      var template = DOMTemplate.parse(source);
      expect(template.nodes.length, equals(3));
      expect(template.toString(), equals(source));

      var s1 = template.build({'email': 'a@b.c'});
      expect(s1, equals('E-mail is !'));

      var s2 = template.build({'name': 'Joe', 'email': 'a@b.c'});
      expect(s2, equals('E-mail is "a@b.c"!'));
    });

    test('parse: if{ var }_else 1', () {
      var source = 'E-mail is {{:name}}"{{email}}"{{?}}unknown_user{{/}}!';

      var template = DOMTemplate.parse(source);
      expect(template.nodes.length, equals(3));
      expect(template.toString(), equals(source));

      var s1 = template.build({'email': 'a@b.c'});
      expect(s1, equals('E-mail is unknown_user!'));

      var s2 = template.build({'name': 'Joe', 'email': 'a@b.c'});
      expect(s2, equals('E-mail is "a@b.c"!'));
    });

    test('parse: if{ var_else }_else 1', () {
      var source =
          'E-mail is {{:name}}"{{?email}}NULL_MAIL{{/}}"{{?}}unknown_user{{/}}!';

      var template = DOMTemplate.parse(source);
      expect(template.nodes.length, equals(3));
      expect(template.toString(), equals(source));

      var s1 = template.build({'email': 'a@b.c'});
      expect(s1, equals('E-mail is unknown_user!'));

      var s2 = template.build({'name': 'Joe', 'email': 'a@b.c'});
      expect(s2, equals('E-mail is "a@b.c"!'));

      var s3 = template.build({'name': 'Joe'});
      expect(s3, equals('E-mail is "NULL_MAIL"!'));
    });

    test('parse: ifList 1', () {
      var source = 'Routes:{{*:routes}} [{{name}}]{{/}}!';

      var template = DOMTemplate.parse(source);
      expect(template.nodes.length, equals(3));
      expect(template.toString(), equals(source));

      var s1 = template.build({
        'routes': [
          {'name': 'Home'},
          {'name': 'About'}
        ]
      });
      expect(s1, equals('Routes: [Home] [About]!'));

      var s2 = template.build({'routes': []});
      expect(s2, equals('Routes:!'));

      var s3 = template.build({});
      expect(s3, equals('Routes:!'));
    });

    test('parse: ifList 2', () {
      var source = 'Route 1: {{routes.1.name}}!';

      var template = DOMTemplate.parse(source);
      expect(template.nodes.length, equals(3));
      expect(template.toString(), equals(source));

      var s1 = template.build({
        'routes': [
          {'name': 'Home'},
          {'name': 'About'}
        ]
      });
      expect(s1, equals('Route 1: About!'));

      var s2 = template.build({'routes': []});
      expect(s2, equals('Route 1: !'));

      var s3 = template.build({});
      expect(s3, equals('Route 1: !'));

      var s4 = template.build({
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

      var s1 = template.build({
        'routes': [
          {'name': 'Home'},
          {'name': 'About'}
        ]
      });
      expect(s1, equals('Routes: [name: Home] [name: About]!'));

      var s2 = template.build({'routes': []});
      expect(s2, equals('Routes:!'));

      var s3 = template.build({});
      expect(s3, equals('Routes:!'));

      var s4 = template.build({
        'routes': ['Home', 'About']
      });
      expect(s4, equals('Routes: [Home] [About]!'));
    });

    test('parse: ifList_else 1', () {
      var source = 'Routes:{{*:routes}} [{{name}}]{{?}} NO ROUTES{{/}}!';

      var template = DOMTemplate.parse(source);
      expect(template.nodes.length, equals(3));
      expect(template.toString(), equals(source));

      var s1 = template.build({
        'routes': [
          {'name': 'Home'},
          {'name': 'About'}
        ]
      });
      expect(s1, equals('Routes: [Home] [About]!'));

      var s2 = template.build({'routes': []});
      expect(s2, equals('Routes: NO ROUTES!'));

      var s3 = template.build({});
      expect(s3, equals('Routes: NO ROUTES!'));
    });

    test('parse: notList 1', () {
      var source = 'Routes:{{!routes}}{{no_routes}}{{/}}!';

      var template = DOMTemplate.parse(source);
      expect(template.nodes.length, equals(3));
      expect(template.toString(), equals(source));

      var s1 = template.build({
        'no_routes': 'Empty routes',
        'routes': [
          {'name': 'Home'},
          {'name': 'About'}
        ]
      });
      expect(s1, equals('Routes:!'));

      var s2 = template.build({'no_routes': 'Empty routes'});
      expect(s2, equals('Routes:Empty routes!'));
    });

    test('parse: query element', () {
      var source = 'Element: {{:ok}}{{#element_x}}{{/}}!';

      var template = DOMTemplate.parse(source);
      expect(template.nodes.length, equals(3));
      expect(template.toString(), equals(source));

      var elementProvider = (q) {
        return q == '#element_x' ? 'XXX' : null;
      };

      var s1 = template.build({'ok': true}, elementProvider: elementProvider);
      expect(s1, equals('Element: XXX!'));

      var s2 = template.build({'ok': false}, elementProvider: elementProvider);
      expect(s2, equals('Element: !'));
    });

    test('parse: ifEq{ var } 1', () {
      var source =
          'Hello! Good {{:period=="am"}}morning{{?:period=="pm"}}afternoon{{?}}day{{/}}!';

      var template = DOMTemplate.parse(source);
      expect(template.nodes.length, equals(3));
      expect(template.toString(), equals(source));

      var s1 = template.build({'period': 'am'});
      expect(s1, equals('Hello! Good morning!'));

      var s2 = template.build({'period': 'pm'});
      expect(s2, equals('Hello! Good afternoon!'));

      var s3 = template.build({'period': ''});
      expect(s3, equals('Hello! Good day!'));
    });

    test('parse: ifEq{ var } 2', () {
      var source =
          'Hello! Period: {{:period==hourPeriod}}match{{?}}no match{{/}}!';

      var template = DOMTemplate.parse(source);
      expect(template.nodes.length, equals(3));
      expect(template.toString(), equals(source));

      var s1 = template.build({'period': 'am', 'hourPeriod': 'am'});
      expect(s1, equals('Hello! Period: match!'));

      var s2 = template.build({'period': 'am', 'hourPeriod': 'pm'});
      expect(s2, equals('Hello! Period: no match!'));
    });

    test('parse: ifNotEq{ var } 2', () {
      var source = 'Hello! Period: {{:period!=hourPeriod}}diff{{?}}eq{{/}}!';

      var template = DOMTemplate.parse(source);
      expect(template.nodes.length, equals(3));
      expect(template.toString(), equals(source));

      var s1 = template.build({'period': 'am', 'hourPeriod': 'am'});
      expect(s1, equals('Hello! Period: eq!'));

      var s2 = template.build({'period': 'am', 'hourPeriod': 'pm'});
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

      var s1 = template.build({
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

      var template1 = DOMTemplate.tryParse(source1);
      expect(template1.nodes.length, equals(3));
      expect(template1.toString(), equals(source1));

      var template2 = DOMTemplate.tryParse(source2);
      expect(template2, isNull);
    });
  });
}
