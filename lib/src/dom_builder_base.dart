
import 'dart:collection';

import 'package:swiss_knife/swiss_knife.dart';

import 'package:html/parser.dart' as html_parse ;
import 'package:html/dom.dart' as html_dom ;

import 'dom_builder_generator.dart';


final RegExp STRING_LIST_DELIMITER = RegExp(r'[,;\s]+') ;

List<String> parseListOfStrings(dynamic s, [Pattern delimiter, bool trim = true]) {
  if (s == null) return null ;

  List<String> list ;

  if (s is List) {
    list = s.map( parseString ).toList() ;
  }
  else {
    var str = parseString(s) ;
    if (trim) str = str.trim() ;
    list = str.split(delimiter);
  }

  if (trim) {
    list = list.where( (e) => e != null ).map( (e) => e.trim() ).where( (e) => e.isNotEmpty ).toList() ;
  }

  return list ;
}

bool isObjectEmpty(dynamic o) {
  if (o == null) return true ;

  if (o is List) {
    return o.isEmpty ;
  }
  else if (o is Map) {
    return o.isEmpty ;
  }
  else {
    return o.toString().isEmpty ;
  }
}

bool isObjectNotEmpty(dynamic o) {
  return !isObjectEmpty(o) ;
}

abstract class WithValue {

  bool get hasValue ;

  String get value ;


}

class DOMAttribute implements WithValue {

  static bool hasAttribute( DOMAttribute attribute ) => attribute != null && attribute.hasValue ;
  static bool hasAttributes( Map<String, DOMAttribute> attributes ) => attributes != null && attributes.isNotEmpty ;

  final String name ;

  String _value ;
  List<String> _values ;
  final String delimiter ;

  bool _boolean ;

  DOMAttribute(String name, { dynamic value, List values, this.delimiter , dynamic boolean } ) :
      name = name.toLowerCase().trim() ,
      _value = parseString(value) ,
      _values = parseListOfStrings(values) ,
      _boolean = parseBool(boolean)
  {
    if (_value != null && _values != null) throw ArgumentError('Attribute $name: Only value or values can be defined, not both.') ;
    if (_boolean != null && (_value != null || _values != null) ) throw ArgumentError("Attribute $name: Boolean attribute doesn't have value.") ;
    if (_values != null && delimiter == null) throw ArgumentError('Attribute $name: If values is defined a delimiter is required.') ;
  }

  bool get isBoolean => _boolean != null ;
  bool get isListValue => delimiter != null ;

  @override
  bool get hasValue {
    if ( isBoolean ) return _boolean ;

    if ( isListValue ) {
      if ( isObjectNotEmpty(_values) ) {
        if (_values.length == 1) {
          return _values[0].isNotEmpty;
        }
        else {
          return true;
        }
      }
    }
    else {
      return isObjectNotEmpty(_value) ;
    }

    return false ;
  }

  @override
  String get value {
    if ( isBoolean ) return _boolean.toString() ;

    if ( isListValue ) {
      if ( isObjectNotEmpty(_values) ) {
        if (_values.length == 1) {
          return _values[0] ;
        }
        else {
          return _values.join(delimiter) ;
        }
      }
    }
    else {
      if ( isObjectNotEmpty(_value) ) {
        return _value ;
      }
    }

    return null ;
  }

  List<String> get values {
    if ( isBoolean ) return [ _boolean.toString() ] ;

    if ( isListValue ) {
      if ( isObjectNotEmpty(_values) ) {
        return _values ;
      }
    }
    else {
      if ( isObjectNotEmpty(_value) ) {
        return [_value] ;
      }
    }

    return null ;
  }

  bool containsValue(String v) {
    if ( isBoolean ) {
      v ??= 'false' ;
      return _boolean.toString() == v ;
    }

    if ( isListValue ) {
      if ( isObjectNotEmpty(_values) ) {
        return _values.contains(v) ;
      }
    }
    else {
      if ( isObjectNotEmpty(_value) ) {
        return _value == v ;
      }
    }

    return false ;
  }

  void setBoolean(dynamic value) {
    _boolean = parseBool(value, false) ;
  }

  void setValue(value) {
    if ( isBoolean ) {
      setBoolean(value) ;
      return ;
    }

    if ( isListValue ) {
      if ( _values != null && _values.length == 1 ) {
        _values[0] = parseString(value) ;
      }
      else {
        _values = [ parseString(value) ] ;
      }
    }
    else {
      _value = parseString(value) ;
    }
  }

  void appendValue(value) {
    if ( !isListValue ) {
      setValue(value) ;
      return ;
    }

    _values ??= [] ;

    var s = parseString(value);
    if (s != null) {
      _values.add(s);
    }
  }

  String buildHTML() {
    if ( isBoolean ) {
      return _boolean ? name : '' ;
    }

    var htmlValue = value ;

    if ( htmlValue != null ) {
      var html = '$name=' ;
      html += htmlValue.contains('"') ? "'$htmlValue'" : '"$htmlValue"' ;
      return html ;
    }
    else {
      return '' ;
    }
  }

}

abstract class DOMNode {

  static List<DOMNode> parse(entry) {
    if (entry == null) return null ;

    if ( entry is DOMNode ) return [entry] ;

    if ( entry is html_dom.Node ) {
      return [ DOMNode.from(entry) ];
    }

    if ( entry is List ) {
      return entry.expand( parse ).toList() ;
    }
    else if ( entry is String ) {
      return [ TextNode(entry) ] ;
    }

    return null ;
  }

  DOMNode() ;

  factory DOMNode.from(entry) {
    if (entry is DOMNode) return entry ;
    if (entry is String) return TextNode(entry) ;

    if (entry is html_dom.Node) return DOMNode._fromHtmlNode( entry) ;

    return null ;
  }

  factory DOMNode._fromHtmlNode( html_dom.Node entry) {
    if ( entry is html_dom.Text ) {
      return TextNode( entry.text ) ;
    }
    else if ( entry is html_dom.Element ) {
      return DOMNode._fromHtmlNodeElement( entry ) ;
    }

    return null ;
  }

  factory DOMNode._fromHtmlNodeElement( html_dom.Element entry) {
    var name = entry.localName;

    var attributes = entry.attributes.map( (k,v) => MapEntry( k.toString() , v) ) ;

    var subNodes = DOMNode.parse( entry.nodes ) ;

    return DOMElement( name , attributes: attributes , content: subNodes ) ;
  }

  String buildHTML( { bool withIdent = false, String parentIdent = '' , String ident = '  ' } ) ;

}

class TextNode extends DOMNode implements WithValue {

  final String text ;

  TextNode(this.text) ;

  @override
  bool get hasValue => isObjectNotEmpty(text) ;

  @override
  String buildHTML( { bool withIdent = false, String parentIdent = '' , String ident = '  ' } ) {
    return text ;
  }

  @override
  String get value => text ;

}

typedef NodeSelector = bool Function( DOMNode node ) ;

NodeSelector asNodeSelector(dynamic selector) {
  if (selector == null) return null ;

  if (selector is String) {
    var str = selector.trim() ;
    if (str.isEmpty) return null ;

    // id:
    if ( str.startsWith('#') ) {
      return (n) => n is DOMElement && n.id == str.substring(1) ;
    }
    // class
    else if ( str.startsWith('.') ) {
      return (n) => n is DOMElement && n.containsClass( str.substring(1) ) ;
    }
    // tag
    else {
      return (n) => n is DOMElement && n.tag == str ;
    }
  }
  else if (selector is DOMNode) {
    return (n) => n == selector ;
  }
  else if (selector is NodeSelector) {
    return selector ;
  }
  else if (selector is List) {
    if ( selector.isEmpty ) return null ;
    if ( selector.length == 1 ) return asNodeSelector( selector[0] ) ;

    var multiSelector = selector.map(asNodeSelector).toList() ;

    return (n) => multiSelector.any( (f) => f(n) ) ;
  }

  throw ArgumentError("Can't use NodeSelector of type: [ ${ selector.runtimeType }") ;
}

class DOMElement extends DOMNode {

  final String tag ;

  factory DOMElement(String tag, { Map<String, dynamic> attributes, id, classes, style, content }) {
    if (tag == null) throw ArgumentError('Null tag');

    tag = tag.toLowerCase().trim() ;

    if (tag == 'div') {
      return DIVElement(tag, attributes: attributes, id: id, classes: classes, style: style, content: content) ;
    }
    else {
      return DOMElement._(tag, attributes: attributes, id: id, classes: classes, style: style, content: content) ;
    }
  }

  DOMElement._(this.tag, {Map<String, dynamic> attributes, id, classes, style, content}) {

    addAttributes( attributes ) ;

    if (id != null) {
      attribute('id', id) ;
    }

    if (classes != null) {
      attributeAppendValue('class', classes) ;
    }

    if (style != null) {
      attributeAppendValue('style', style) ;
    }

    if (content != null) {
      _content = DOMNode.parse(content) ;
    }

  }

  //////

  String get id => getAttributeValue('id') ;

  String get classes => getAttributeValue('class') ;
  String get style => getAttributeValue('style') ;

  bool containsClass(String className) {
    var attribute = getAttribute('class') ;
    if (attribute == null) return null ;
    return attribute.containsValue(className) ;
  }

  //////

  final Set<String> _ATTRIBUTES_VALUE_AS_BOOLEAN = { 'checked' } ;

  final Map<String,Pattern> _ATTRIBUTES_VALUE_AS_LIST_DELIMITERS = { 'class': ' ' , 'style': ';' } ;
  final Map<String,Pattern> _ATTRIBUTES_VALUE_AS_LIST_DELIMITERS_PATTERNS = { 'class': RegExp(r'\s+') , 'style': RegExp(r'\s*;\s*') } ;

  LinkedHashMap<String, DOMAttribute> _attributes ;

  Iterable<String> get attributesNames => _attributes.keys;

  String operator [](String name) => getAttributeValue(name) ;
  void operator []=(String name, dynamic value) => attribute(name, value) ;

  String getAttributeValue( String name ) {
    var attr = getAttribute(name) ;
    return attr != null ? attr.value : null ;
  }

  DOMAttribute getAttribute( String name ) {
    if ( isObjectEmpty(_attributes) ) return null ;
    return _attributes[name] ;
  }

  DOMElement attribute( String name , dynamic value ) {
    if (name == null) return null ;

    name = name.toLowerCase().trim() ;

    DOMAttribute attribute ;

    var delimiter = _ATTRIBUTES_VALUE_AS_LIST_DELIMITERS[name] ;

    if ( delimiter != null ) {
      var delimiterPattern = _ATTRIBUTES_VALUE_AS_LIST_DELIMITERS_PATTERNS[name] ;
      assert( delimiterPattern != null ) ;
      attribute = DOMAttribute(name, values: parseListOfStrings(value, delimiterPattern), delimiter: delimiter) ;
    }
    else {
      var attrBoolean = _ATTRIBUTES_VALUE_AS_BOOLEAN.contains(name) ;

      if (attrBoolean) {
        if (value != null) {
          attribute = DOMAttribute(name, value: value) ;
        }
      }
      else {
        attribute = DOMAttribute(name, value: value) ;
      }
    }

    if (attribute != null) {
      addDOMAttribute(attribute);
    }

    return this ;
  }

  DOMElement attributeAppendValue( String name , dynamic value ) {
    // ignore: prefer_collection_literals
    _attributes ??= LinkedHashMap();

    var attr = getAttribute(name) ;

    if (attr == null) {
      return attribute(name, value) ;
    }

    if ( attr.isListValue ) {
      attr.appendValue(value) ;
    }
    else {
      attr.setValue(value) ;
    }

    return this ;
  }

  DOMElement addAttributes( Map<String,dynamic> attributes ) {
    if ( isObjectNotEmpty(attributes) ) {
      for (var entry in attributes.entries) {
        var name = entry.key ;
        var value = entry.value ;
        attribute(name, value);
      }
    }

    return this ;
  }

  DOMElement addDOMAttribute( DOMAttribute attribute ) {
    if (attribute == null) return this ;

    // ignore: prefer_collection_literals
    _attributes ??= LinkedHashMap() ;
    _attributes[attribute.name] = attribute ;

    return this ;
  }

  bool get hasAttributes => DOMAttribute.hasAttributes(_attributes) ;

  //////////////////////////////////////////////////////////////////////////////

  String buildOpenTagHTML() {
    var html = '<$tag' ;

    if (hasAttributes) {
      for ( var attr in _attributes.values.where((v) => v != null && v.hasValue) ) {
        html += ' '+ attr.buildHTML() ;
      }
    }

    html += '>' ;

    return html ;
  }

  String buildCloseTagHTML() {
    return '</$tag>' ;
  }

  @override
  String buildHTML( { bool withIdent = false, String parentIdent = '' , String ident = '  ' } ) {
    var allowIdent = withIdent && isNotEmpty && hasOnlyElements ;

    var innerIdent = allowIdent ? parentIdent : '' ;

    var innerBreakLine = allowIdent ? '\n' : '' ;

    var html = (withIdent ? parentIdent : '') + buildOpenTagHTML() + innerBreakLine ;

    if ( isObjectNotEmpty(_content) ) {
      for (var node in _content) {
        html += innerIdent + node.buildHTML( withIdent: withIdent, parentIdent: parentIdent+ident, ident: ident ) + innerBreakLine ;
      }
    }

    html += innerIdent + buildCloseTagHTML() ;

    return html ;
  }

  //////////////////////////////////////////////////////////////////////////////

  static DOMGenerator setDefaultDomGeneratorToDartHTML() {
    return _defaultDomGenerator = DOMGenerator.dartHTML() ;
  }

  static DOMGenerator _defaultDomGenerator ;

  static DOMGenerator get defaultDomGenerator {
    return _defaultDomGenerator ?? DOMGenerator.dartHTML() ;
  }

  static set defaultDomGenerator(DOMGenerator value) {
    _defaultDomGenerator = value ?? DOMGenerator.dartHTML() ;
  }

  T buildDOM<T>( [ DOMGenerator<T> generator ] ) {
    generator ??= defaultDomGenerator ;
    return generator.generate( this ) ;
  }

  //////////////////////////////////////////////////////////////////////////////

  List<DOMNode> _content ;

  Iterable<DOMNode> get nodes => List.from( _content ).cast() ;

  int get length => _content != null ? _content.length : 0 ;

  bool get isEmpty => _content != null ? _content.isEmpty : true ;
  bool get isNotEmpty => !isEmpty ;

  bool get hasOnlyElements {
    if ( isEmpty ) return false ;
    return _content.any( (n) => !(n is DOMElement) ) == false ;
  }

  bool get hasOnlyTexts {
    if ( isEmpty ) return false ;
    return _content.any( (n) => (n is DOMElement) ) == false ;
  }

  void _addToContent(DOMNode entry) {
    if (_content == null) {
      _content = [entry] ;
    }
    else {
      _content.add(entry);
    }
  }

  void _insertToContent(int index, DOMNode entry) {
    if (_content == null) {
      _content = [entry] ;
    }
    else {
      if (index > _content.length) index = _content.length ;
      if (index == _content.length) {
        _addToContent(entry) ;
      }
      else {
        _content.insert(index, entry);
      }
    }
  }

  T nodeByIndex<T extends DOMNode>( int index ) {
    if ( index == null || isEmpty ) return null ;
    return _content[index] ;
  }

  DOMElement nodeByID( String id ) {
    if ( id == null || isEmpty ) return null ;
    if (id.startsWith('#')) id = id.substring(1) ;
    return nodeWhere( (n) => n is DOMElement && n.id == id ) ;
  }

  DOMElement selectByID( String id ) {
    if ( id == null || isEmpty ) return null ;
    if (id.startsWith('#')) id = id.substring(1) ;
    return selectWhere( (n) => n is DOMElement && n.id == id ) ;
  }

  T nodeEquals<T extends DOMNode>( DOMNode node ) {
    if ( node == null || isEmpty ) return null ;
    return nodeWhere( (n) => n == node ) ;
  }

  T selectEquals<T extends DOMNode>( DOMNode node ) {
    if ( node == null || isEmpty ) return null ;
    return selectWhere( (n) => n == node ) ;
  }

  T nodeWhere<T extends DOMNode>( NodeSelector selector ) {
    if ( selector == null || isEmpty ) return null ;
    return _content.firstWhere( selector , orElse: () => null ) ;
  }

  T selectWhere<T extends DOMNode>( NodeSelector selector ) {
    if ( selector == null || isEmpty ) return null ;

    var found = nodeWhere(selector) ;
    if (found != null) return found ;

    for (var n in _content.whereType<DOMElement>() ) {
      found = n.selectWhere(selector) ;
      if (found != null) return found ;
    }

    return null ;
  }

  T node<T extends DOMNode>( dynamic selector ) {
    if ( selector == null || isEmpty ) return null ;

    if ( selector is num ) {
      return nodeByIndex(selector) ;
    }
    else {
      var nodeSelector = asNodeSelector(selector) ;
      return nodeWhere(nodeSelector) ;
    }
  }

  T select<T extends DOMNode>( dynamic selector ) {
    if ( selector == null || isEmpty ) return null ;

    if ( selector is num ) {
      return nodeByIndex(selector) ;
    }
    else {
      var nodeSelector = asNodeSelector(selector) ;
      return selectWhere(nodeSelector) ;
    }
  }

  //////////////////////////////////////////////////////////////////////////////

  DOMElement addHTML(String html) {
    var list = $html(html) ;
    if (list == null || list.isEmpty) return this;

    for (var node in list) {
      _addToContent(node) ;
    }

    return this ;
  }

  DOMElement add(dynamic entry) {
    var node = DOMNode.from(entry) ;
    _addToContent(node) ;
    return this ;
  }

  DOMElement insertAt(dynamic indexSelector, dynamic entry) {
    var idx = indexOf(indexSelector) ;

    if (idx >= 0) {
      var node = DOMNode.from(entry) ;
      _insertToContent(idx, node) ;
    }

    return this ;
  }

  DOMElement insertAfter(dynamic indexSelector, dynamic entry) {
    var idx = indexOf(indexSelector) ;

    if (idx >= 0) {
      idx++;
      var node = DOMNode.from(entry) ;
      _insertToContent(idx, node) ;
    }

    return this ;
  }

  int indexOf( dynamic selector ) {
    if (selector == null || _content == null || _content.isEmpty) return -1 ;

    if (selector is num) {
      return selector ;
    }

    var nodeSelector = asNodeSelector(selector) ;
    return _content.indexWhere(nodeSelector) ;
  }

  //////////////////////////////////////////////////////////////////////////////

  DOMElement addExternalElement( dynamic externalElement ) {
    var node = ExternalElementNode(externalElement) ;
    _addToContent(node) ;
    return this ;
  }

  DOMElement insertExternalElementAt(dynamic indexSelector, dynamic element) {
    var idx = indexOf(indexSelector) ;

    if (idx >= 0) {
      var node = ExternalElementNode(element) ;
      _insertToContent(idx, node) ;
    }

    return this ;
  }

  DOMElement insertExternalElementAfter(dynamic indexSelector, dynamic element) {
    var idx = indexOf(indexSelector) ;

    if (idx >= 0) {
      idx++;
      var node = ExternalElementNode(element) ;
      _insertToContent(idx, node) ;
    }

    return this ;
  }

  //////////////////////////////////////////////////////////////////////////////

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is DOMElement &&
          runtimeType == other.runtimeType &&
          tag == other.tag &&
          isEqualsDeep(_attributes, other._attributes) &&
          isEqualsDeep(_content, other._content)
          ;

  @override
  int get hashCode => tag.hashCode ^ deepHashCode( _attributes ) ^ deepHashCode( _content ) ;

}

class ExternalElementNode extends DOMNode {

  final dynamic element ;

  ExternalElementNode(this.element);

  @override
  String buildHTML({bool withIdent = false, String parentIdent = '', String ident = '  '}) {
    return null ;
  }

}

class DIVElement extends DOMElement {

  factory DIVElement.from(dynamic entry) {
    if (entry == null) return null ;
    if (entry is DIVElement) return entry ;

    if ( entry is DOMElement ) {
      return DIVElement( entry.tag , attributes: entry._attributes , content: entry._content ) ;
    }

    return null ;
  }

  DIVElement(String tag, { Map<String, dynamic> attributes, id, classes, style, content } ) : super._(tag, attributes: attributes, id: id, classes: classes, style: style, content: content);

}

////////////////////////////////////////////////////////////////////////////////

List<DOMNode> parseHTML(String html) {
  if (html == null) return null ;

  var parsed = html_parse.parseFragment(html, container: 'div') ;

  if ( parsed.nodes.isEmpty ) {
    return null ;
  }
  else if ( parsed.nodes.length == 1 ) {
    var node = parsed.nodes[0] ;
    return [ DOMNode.from(node) ] ;
  }
  else {
    return parsed.nodes.map( (e) => DOMNode.from(e) ).toList() ;
  }
}

List<DOMNode> $html<T extends DOMNode>(dynamic html) {
  if (html == null) return null ;
  if (html is String) {
    return parseHTML(html) ;
  }
  throw ArgumentError("Ca't parse type: ${ html.runtimeType}") ;
}

////////////////////////////////////////////////////////////////////////////////

DOMElement $tag( String tag , { id, classes, style, Map<String,String> attributes, content } ) {
  return DOMElement(tag, id: id, classes: classes, style: style, attributes: attributes, content: content) ;
}

T $tagHTML<T extends DOMElement>(dynamic html) => $html<DOMElement>(html).whereType<T>().first ;

DOMElement $div( { id, classes , style, Map<String,String> attributes, content } ) => $tag('div', id: id, classes: classes, style: style, attributes: attributes, content: content) ;

DIVElement $divHTML(dynamic html) => $tagHTML(html);

DOMElement $span( { id, classes , style, Map<String,String> attributes, content } ) => $tag('span', id: id, classes: classes, style: style, attributes: attributes, content: content) ;

DOMElement $button( { id, classes , style, type, Map<String,String> attributes, content } ) => $tag('button', id: id, classes: classes, style: style, attributes: { 'type': type, ...attributes }, content: content) ;


