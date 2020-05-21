
import 'dart:collection';

import 'package:swiss_knife/swiss_knife.dart';

import 'package:html/parser.dart' as html_parse ;
import 'package:html/dom.dart' as html_dom ;

import 'dom_builder_generator.dart';


final RegExp STRING_LIST_DELIMITER = RegExp(r'[,;\s]+') ;

final RegExp CSS_LIST_DELIMITER = RegExp(r'\s*;\s*') ;

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

//
// DOMAttribute:
//

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

//
// NodeSelector:
//

typedef NodeSelector = bool Function( DOMNode node ) ;

final RegExp _SELECTOR_DELIMITER = RegExp(r'\s*,\s*') ;

NodeSelector asNodeSelector(dynamic selector) {
  if (selector == null) return null ;

  if (selector is NodeSelector) {
    return selector ;
  }
  else if (selector is String) {
    var str = selector.trim() ;
    if (str.isEmpty) return null ;

    var selectors = str.split(_SELECTOR_DELIMITER) ;
    selectors.removeWhere( (s) => s.isEmpty ) ;

    if (selectors.isEmpty) {
      return null ;
    }
    else if (selectors.length == 1) {
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
    else {
      var multiSelector = selectors.map(asNodeSelector).toList() ;
      return (n) => multiSelector.any( (f) => f(n) ) ;
    }
  }
  else if (selector is DOMNode) {
    return (n) => n == selector ;
  }
  else if (selector is List) {
    if ( selector.isEmpty ) return null ;
    if ( selector.length == 1 ) return asNodeSelector( selector[0] ) ;

    var multiSelector = selector.map(asNodeSelector).toList() ;

    return (n) => multiSelector.any( (f) => f(n) ) ;
  }

  throw ArgumentError("Can't use NodeSelector of type: [ ${ selector.runtimeType }") ;
}

//
// DOMNode:
//

class DOMNode {

  static List<DOMNode> parseNodes(entry) {
    if (entry == null) return null ;

    if ( entry is DOMNode ) {
      return [entry] ;
    }
    else if ( entry is html_dom.Node ) {
      return [ DOMNode.from(entry) ];
    }
    else if ( entry is List ) {
      entry.removeWhere( (e) => e == null ) ;
      return entry.expand( parseNodes ).toList() ;
    }
    else if ( entry is String ) {
      if ( isHTMLElement(entry) ) {
        return parseHTML( entry ) ;
      }
      else {
        return [ TextNode(entry) ] ;
      }
    }
    else if ( entry is num || entry is bool ) {
      return [ TextNode(entry.toString()) ] ;
    }
    else if ( entry is DOMElementGenerator ) {
      return [ ExternalElementNode( entry ) ] ;
    }
    else {
      return [ ExternalElementNode( entry ) ] ;
    }
  }

  static dynamic _parseNode(entry) {
    if (entry == null) return null ;

    if ( entry is DOMNode ) {
      return entry ;
    }
    else if ( entry is html_dom.Node ) {
      return DOMNode.from(entry) ;
    }
    else if ( entry is List ) {
      entry.removeWhere( (e) => e == null ) ;
      return entry.expand( parseNodes ).toList() ;
    }
    else if ( entry is String ) {
      if ( isHTMLElement(entry) ) {
        return parseHTML( entry ) ;
      }
      else {
        return TextNode(entry) ;
      }
    }
    else if ( entry is num || entry is bool ) {
      return TextNode(entry.toString()) ;
    }
    else if ( entry is DOMElementGenerator ) {
      return ExternalElementNode( entry ) ;
    }
    else {
      return ExternalElementNode( entry ) ;
    }
  }

  factory DOMNode.from(entry) {
    if (entry == null) return null ;

    if (entry is DOMNode) {
      return entry ;
    }
    else if (entry is html_dom.Node) {
      return DOMNode._fromHtmlNode(entry) ;
    }
    else if ( entry is List ) {
      if ( entry.isEmpty ) return null ;
      entry.removeWhere( (e) => e == null ) ;
      return DOMNode.from( entry.single ) ;
    }
    else if (entry is String) {
      if ( isHTMLElement(entry) ) {
        return parseHTML( entry ).single ;
      }
      else {
        return TextNode(entry) ;
      }
    }
    else if ( entry is num || entry is bool ) {
      return TextNode(entry.toString()) ;
    }
    else if ( entry is DOMElementGenerator ) {
      return ExternalElementNode( entry ) ;
    }
    else {
      return ExternalElementNode( entry ) ;
    }
  }

  factory DOMNode._fromHtmlNode( html_dom.Node entry ) {
    if ( entry is html_dom.Text ) {
      return TextNode( entry.text ) ;
    }
    else if ( entry is html_dom.Element ) {
      return DOMNode._fromHtmlNodeElement( entry ) ;
    }

    return null ;
  }

  factory DOMNode._fromHtmlNodeElement( html_dom.Element entry ) {
    var name = entry.localName;

    var attributes = entry.attributes.map( (k,v) => MapEntry( k.toString() , v) ) ;

    //var subNodes = DOMNode.parseNodes( entry.nodes ) ;

    return DOMElement( name , attributes: attributes , content: List.from(entry.nodes) ) ;
  }

  //////////////////////////////////////////////////////////////////////////////

  final bool allowContent ;

  bool _commented ;

  DOMNode._(bool allowContent, bool commented) :
        allowContent = allowContent ?? true ,
        _commented = commented ?? false
  ;

  DOMNode( { content } ) :
        allowContent = true
  {

    if (content != null) {
      _content = DOMNode.parseNodes(content) ;
    }

  }

  bool get isCommented => _commented;

  set commented(bool value) {
    _commented = value ?? false ;
  }


  //////////////////////////////////////////////////////////////////////////////

  String buildHTML( { bool withIdent = false, String parentIdent = '' , String ident = '  ' } ) {
    if ( isCommented ) return '' ;

    var allowIdent = withIdent && isNotEmpty && hasOnlyElements ;

    var innerIdent = allowIdent ? parentIdent : '' ;

    var innerBreakLine = allowIdent ? '\n' : '' ;

    var html = (withIdent ? parentIdent : '') + innerBreakLine ;

    if ( isObjectNotEmpty(_content) ) {
      for (var node in _content) {
        var subElement = node.buildHTML( withIdent: withIdent, parentIdent: parentIdent+ident, ident: ident );
        if (subElement != null) {
          html += innerIdent + subElement + innerBreakLine;
        }
      }
    }

    return html ;
  }

  // DOM Generator:

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
    if (isCommented) return null ;

    generator ??= defaultDomGenerator ;
    return generator.generate( this ) ;
  }

  //////////////////////////////////////////////////////////////////////////////

  List<DOMNode> _content ;

  List<DOMNode> get content => _content ;

  Iterable<DOMNode> get nodes => allowContent ? List.from( _content ).cast() : [] ;

  int get length => allowContent && _content != null ? _content.length : 0 ;

  bool get isEmpty => allowContent && _content != null ? _content.isEmpty : true ;
  bool get isNotEmpty => !isEmpty ;

  bool get hasOnlyElements {
    if ( isEmpty ) return false ;
    return _content.any( (n) => !(n is DOMElement) ) == false ;
  }

  bool get hasOnlyTexts {
    if ( isEmpty ) return false ;
    return _content.any( (n) => (n is DOMElement) ) == false ;
  }

  void _addToContent(dynamic entry) {
    if ( entry is List ) {
      _addListToContent(entry) ;
    }
    else {
      _addNodeToContent(entry) ;
    }
  }

  void _addListToContent(List<DOMNode> list) {
    if (list == null) return ;
    list.removeWhere( (e) => e == null ) ;
    if (list.isEmpty) return ;

    for (var elem in list) {
      _addNodeToContent(elem) ;
    }
  }

  void _addNodeToContent(DOMNode entry) {
    if (entry == null) return ;

    _checkAllowContent();

    if (_content == null) {
      _content = [entry] ;
    }
    else {
      _content.add(entry);
    }
  }

  void _insertToContent(int index, dynamic entry) {
    if (entry is List) {
      _insertListToContent(index, entry) ;
    }
    else {
      _insertNodeToContent(index, entry) ;
    }
  }

  void _insertListToContent(int index, List<DOMNode> list) {
    if (list == null) return ;
    list.removeWhere( (e) => e == null ) ;
    if (list.isEmpty) return ;

    if ( list.length == 1 ) {
      _addNodeToContent( list[0] ) ;
      return ;
    }

    _checkAllowContent();

    if (_content == null) {
      _content = List.from( list ).cast() ;
    }
    else {
      if (index > _content.length) index = _content.length ;
      if (index == _content.length) {
        for (var entry in list) {
          _addNodeToContent(entry) ;
        }
      }
      else {
        _content.insertAll(index, list) ;
      }
    }
  }

  void _insertNodeToContent(int index, DOMNode entry) {
    if (entry == null) return ;

    _checkAllowContent();

    if (_content == null) {
      _content = [entry] ;
    }
    else {
      if (index > _content.length) index = _content.length ;
      if (index == _content.length) {
        _addNodeToContent(entry) ;
      }
      else {
        _content.insert(index, entry);
      }
    }
  }

  void _checkAllowContent() {
    if ( !allowContent ) throw UnsupportedError("$runtimeType: can't insert entry to content!") ;
  }

  void normalizeContent() {

  }

  DOMNode setContent(elementContent) {
    _content = DOMNode.parseNodes(elementContent) ;
    normalizeContent();
    return this ;
  }

  //////////////////////////////////////////////////////////////////////////////

  T nodeByIndex<T extends DOMNode>( int index ) {
    if ( index == null || isEmpty ) return null ;
    return _content[index] ;
  }

  T nodeByID<T extends DOMNode>( String id ) {
    if ( id == null || isEmpty ) return null ;
    if (id.startsWith('#')) id = id.substring(1) ;
    return nodeWhere( (n) => n is DOMElement && n.id == id ) ;
  }

  T selectByID<T extends DOMNode>( String id ) {
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

  T nodeWhere<T extends DOMNode>( dynamic selector ) {
    if ( selector == null || isEmpty ) return null ;
    var nodeSelector = asNodeSelector(selector) ;

    return _content.firstWhere( nodeSelector , orElse: () => null ) ;
  }

  List<T> nodesWhere<T extends DOMNode>( dynamic selector ) {
    if ( selector == null || isEmpty ) return [] ;
    var nodeSelector = asNodeSelector(selector) ;

    return _content.where( nodeSelector ).toList() ;
  }

  void catchNodesWhere<T extends DOMNode>( dynamic selector , List<T> destiny ) {
    if ( selector == null || isEmpty ) return ;
    var nodeSelector = asNodeSelector(selector) ;

    destiny.addAll( _content.where( nodeSelector ).whereType<T>() ) ;
  }

  T selectWhere<T extends DOMNode>( dynamic selector ) {
    if ( selector == null || isEmpty ) return null ;
    var nodeSelector = asNodeSelector(selector) ;

    var found = nodeWhere(nodeSelector) ;
    if (found != null) return found ;

    for (var n in _content.whereType<DOMNode>() ) {
      found = n.selectWhere(selector) ;
      if (found != null) return found ;
    }

    return null ;
  }

  List<T> selectAllWhere<T extends DOMNode>( dynamic selector ) {
    if ( selector == null || isEmpty ) return [] ;
    var nodeSelector = asNodeSelector(selector) ;

    var all = <T>[] ;
    _selectAllWhereImpl(nodeSelector, all) ;
    return all ;
  }

  void _selectAllWhereImpl<T extends DOMNode>( NodeSelector selector , List<T> all ) {
    if ( isEmpty ) return ;

    catchNodesWhere(selector, all) ;

    for (var n in _content.whereType<DOMNode>() ) {
      n._selectAllWhereImpl(selector, all) ;
    }
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

  int indexOf( dynamic selector ) {
    if (selector == null || _content == null || _content.isEmpty) return -1 ;

    if (selector is num) {
      return selector ;
    }

    var nodeSelector = asNodeSelector(selector) ;
    return _content.indexWhere(nodeSelector) ;
  }

  //////////////////////////////////////////////////////////////////////////////

  DOMNode addEach<T>( Iterable<T> iterable , [ ElementGenerator<T> elementGenerator ] ) {
    if ( elementGenerator != null ) {
      for (var entry in iterable) {
        var elem = elementGenerator(entry) ;
        _addImpl( elem ) ;
      }
    }
    else {
      for (var entry in iterable) {
        _addImpl( entry ) ;
      }
    }

    normalizeContent();
    return this ;
  }

  DOMNode addEachAsTag<T>( String tag, Iterable<T> iterable , [ ElementGenerator<T> elementGenerator ] ) {
    if ( elementGenerator != null ) {
      for (var entry in iterable) {
        var elem = elementGenerator(entry) ;
        var tagElem = $tag(tag , content: elem) ;
        _addImpl( tagElem ) ;
      }
    }
    else {
      for (var entry in iterable) {
        var tagElem = $tag(tag , content: entry) ;
        _addImpl( tagElem ) ;
      }
    }

    normalizeContent();
    return this ;
  }

  DOMNode addHTML(String html) {
    var list = $html(html) ;
    _addListToContent(list) ;

    normalizeContent();
    return this ;
  }

  DOMNode add(dynamic entry) {
    _addImpl(entry);
    normalizeContent();
    return this ;
  }

  void _addImpl(entry) {
    var node = _parseNode(entry) ;
    _addToContent(node) ;
  }

  DOMNode insertAt(dynamic indexSelector, dynamic entry) {
    var idx = indexOf(indexSelector) ;

    if (idx >= 0) {
      var node = _parseNode(entry) ;
      _insertToContent(idx, node) ;

      normalizeContent();
    }

    return this ;
  }

  DOMNode insertAfter(dynamic indexSelector, dynamic entry) {
    var idx = indexOf(indexSelector) ;

    if (idx >= 0) {
      idx++;

      var node = _parseNode(entry) ;
      _insertToContent(idx, node) ;

      normalizeContent();
    }

    return this ;
  }

}

class TextNode extends DOMNode implements WithValue {

  final String text ;

  TextNode(this.text) : super._(false, false) ;

  @override
  bool get hasValue => isObjectNotEmpty(text) ;

  @override
  String buildHTML( { bool withIdent = false, String parentIdent = '' , String ident = '  ' } ) {
    return text ;
  }

  @override
  String get value => text ;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is TextNode &&
          runtimeType == other.runtimeType &&
          text == other.text;

  @override
  int get hashCode => text.hashCode;

}

//
// ElementGenerator:
//

typedef ElementGenerator<T> = dynamic Function( T entry ) ;

//

void _checkTag(String expectedTag, DOMElement domElement) {
  if (domElement.tag != expectedTag) throw StateError('Not a $expectedTag tag: $domElement') ;
}

//
// DOMElement:
//

class DOMElement extends DOMNode {

  final Set<String> _NO_CONTENT_TAG = { 'p', 'hr', 'br', 'input' } ;

  final Set<String> _ATTRIBUTES_VALUE_AS_BOOLEAN = { 'checked' } ;

  final Map<String,Pattern> _ATTRIBUTES_VALUE_AS_LIST_DELIMITERS = { 'class': ' ' , 'style': ';' } ;
  final Map<String,Pattern> _ATTRIBUTES_VALUE_AS_LIST_DELIMITERS_PATTERNS = { 'class': RegExp(r'\s+') , 'style': RegExp(r'\s*;\s*') } ;

  //////////////////////////////////////////////////////////////////////////////


  final String tag ;

  factory DOMElement(String tag, { Map<String, dynamic> attributes, id, classes, style, content , bool commented }) {
    if (tag == null) throw ArgumentError('Null tag');

    tag = tag.toLowerCase().trim() ;

    if (tag == 'div') {
      return DIVElement( attributes: attributes, id: id, classes: classes, style: style, content: content , commented: commented ) ;
    }
    else if (tag == 'table') {
      return TABLEElement( attributes: attributes, id: id, classes: classes, style: style, content: content , commented: commented ) ;
    }
    else if (tag == 'thead') {
      return THEADElement( attributes: attributes, id: id, classes: classes, style: style, rows: content , commented: commented ) ;
    }
    else if (tag == 'tbody') {
      return TBODYElement( attributes: attributes, id: id, classes: classes, style: style, rows: content , commented: commented ) ;
    }
    else if (tag == 'tfoot') {
      return TFOOTElement( attributes: attributes, id: id, classes: classes, style: style, rows: content , commented: commented ) ;
    }
    else if (tag == 'tr') {
      return TRowElement( attributes: attributes, id: id, classes: classes, style: style, cells: content , commented: commented ) ;
    }
    else if (tag == 'td') {
      return TDElement( attributes: attributes, id: id, classes: classes, style: style, content: content , commented: commented ) ;
    }
    else if (tag == 'th') {
      return THElement( attributes: attributes, id: id, classes: classes, style: style, content: content , commented: commented ) ;
    }
    else {
      return DOMElement._(tag, attributes: attributes, id: id, classes: classes, style: style, content: content) ;
    }
  }

  DOMElement._(this.tag, {Map<String, dynamic> attributes, id, classes, style, content, bool commented}) : super._(true, commented) {

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
      setContent(content) ;
    }

  }

  //////

  String get id => getAttributeValue('id') ;

  String get classes => getAttributeValue('class') ;
  String get style => getAttributeValue('style') ;

  bool containsClass(String className) {
    var attribute = getAttribute('class') ;
    if (attribute == null) return false ;
    return attribute.containsValue(className) ;
  }

  //////

  LinkedHashMap<String, DOMAttribute> _attributes ;

  Iterable<String> get attributesNames => _attributes != null ? _attributes.keys : [] ;

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

  T apply<T extends DOMElement>( {id, classes, style} ) {
    if (id != null) {
      attribute('id', id) ;
    }

    if (classes != null) {
      attributeAppendValue('classes', classes) ;
    }

    if (style != null) {
      attributeAppendValue('style', style) ;
    }

    return this ;
  }

  T applyWhere<T extends DOMElement>( dynamic selector , {id, classes, style} ) {
    var nodeSelector = asNodeSelector(selector) ;

    var all = selectAllWhere(nodeSelector) ;

    for (var elem in all) {
      if (elem is DOMElement) {
        elem.apply(id: id, classes: classes, style: style);
      }
    }

    return this ;
  }

  //////////////////////////////////////////////////////////////////////////////

  @override
  DOMElement add(entry) {
    return super.add(entry) ;
  }

  @override
  DOMElement addEach<T>(Iterable<T> iterable, [ElementGenerator<T> elementGenerator]) {
    return super.addEach(iterable, elementGenerator);
  }

  @override
  DOMElement addEachAsTag<T>(String tag, Iterable<T> iterable, [ElementGenerator<T> elementGenerator]) {
    return super.addEachAsTag(tag, iterable, elementGenerator);
  }

  @override
  DOMElement addHTML(String html) {
    return super.addHTML(html);
  }

  @override
  DOMElement insertAfter(indexSelector, entry) {
    return super.insertAfter(indexSelector, entry);
  }

  @override
  DOMElement insertAt(indexSelector, entry) {
    return super.insertAt(indexSelector, entry);
  }

  @override
  DOMElement setContent(elementContent) {
    return super.setContent(elementContent);
  }

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

    var innerIdent = allowIdent ? parentIdent+ident : '' ;
    var innerBreakLine = allowIdent ? '\n' : '' ;

    if ( _NO_CONTENT_TAG.contains(tag) ) {
      var html = parentIdent + buildOpenTagHTML() ;
      return html ;
    }

    var html = parentIdent + buildOpenTagHTML() + innerBreakLine ;

    if ( isObjectNotEmpty(_content) ) {
      for (var node in _content) {
        var subElement = node.buildHTML( withIdent: withIdent, parentIdent: innerIdent, ident: ident );
        if (subElement != null) {
          html += subElement + innerBreakLine;
        }
      }
    }

    html += (allowIdent ? parentIdent : '')  + buildCloseTagHTML() ;

    return html ;
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

  @override
  String toString() {
    return 'DOMElement{tag: $tag, _attributes: $_attributes}';
  }
}

//
// ExternalElementNode:
//

class ExternalElementNode extends DOMNode {

  final dynamic externalElement ;

  ExternalElementNode(this.externalElement, [bool allowContent]) : super._(allowContent, false) ;

  @override
  String buildHTML({bool withIdent = false, String parentIdent = '', String ident = '  '}) {
    if ( externalElement == null ) return null ;

    if ( externalElement is String ) {
      return externalElement ;
    }
    else {
      return '$externalElement' ;
    }

  }

}

//
// DIVElement:
//

class DIVElement extends DOMElement {

  factory DIVElement.from(dynamic entry) {
    if (entry == null) return null ;
    if (entry is DIVElement) return entry ;

    if ( entry is DOMElement ) {
      _checkTag('div', entry) ;
      return DIVElement( attributes: entry._attributes , content: entry._content , commented: entry.isCommented ) ;
    }

    return null ;
  }

  DIVElement( { Map<String, dynamic> attributes, id, classes, style, content , bool commented} ) : super._('div', attributes: attributes, id: id, classes: classes, style: style, content: content, commented: commented);

}

//
// TABLEElement:
//

List createTableContent( content, head, body, foot , { bool header , bool footer} ) {

  if (content == null) {
    return [ createTableEntry(head, header: true), createTableEntry(body), createTableEntry(foot, footer: true) ] ;
  }
  else if (content is List) {
    if ( listMatchesAll(content, (e) => e is html_dom.Node) ) {
      var thread = content.firstWhere( (e) => e is html_dom.Element && e.localName == 'thead' , orElse: () => null ) ;
      var tfoot = content.firstWhere( (e) => e is html_dom.Element && e.localName == 'tfoot' , orElse: () => null ) ;
      var tbody = content.firstWhere( (e) => e is html_dom.Element && e.localName == 'tbody' , orElse: () => null ) ;

      var list = [ DOMNode.from(thread) , DOMNode.from(tbody) , DOMNode.from(tfoot) ] ;
      list.removeWhere( (e) => e == null ) ;
      return list ;
    }
    else {
      return content.map( (e) => createTableEntry( e ) ).toList() ;
    }
  }
  else {
    return [  createTableEntry(body) ] ;
  }

}

TABLENode createTableEntry( dynamic entry , { bool header , bool footer} ) {
  if (entry == null) return null ;
  header ??= false ;
  footer ??= false ;

  if ( entry is THEADElement ) {
    return entry ;
  }
  else if ( entry is TBODYElement ) {
    return entry ;
  }
  else if ( entry is TFOOTElement ) {
    return entry ;
  }
  else if ( entry is html_dom.Element ) {
    return DOMNode.from(entry) ;
  }
  else if ( entry is html_dom.Text ) {
    return DOMNode.from(entry) ;
  }
  else {
    if (header) {
      return $thead( rows: entry ) ;
    }
    else if (footer) {
      return $tfoot( rows: entry ) ;
    }
    else {
      return $tbody( rows: entry ) ;
    }
  }
}

List<TRowElement> createTableRows(dynamic rows, bool header) {
  List<TRowElement> tableRows ;

  if (rows is Iterable) {
    var rowsList = List.from(rows) ;

    if ( listMatchesAll(rowsList, (e) => e is TRowElement) ) {
      return rowsList.cast() ;
    }
    else if ( listMatchesAll(rowsList, (e) => e is html_dom.Node) ) {
      var trList = rowsList.where( (e) => e is html_dom.Element && e.localName == 'tr' ) ;
      var list = trList.map( (e) => DOMNode.from(e) ).toList();
      list.removeWhere( (e) => e == null ) ;
      return list.cast() ;
    }
    else if ( listMatchesAll(rowsList, (e) => e is MapEntry) ) {
      var mapEntries = rowsList.whereType<MapEntry>().toList() ;
      tableRows = mapEntries.map( (e) => createTableRow( [e.key , e.value] , header) ).toList() ;
    }
    else if ( rowsList.any( (e) => e is List ) ) {
      tableRows = [] ;
      for (var rowCells in rowsList) {
        var tr = createTableRow(rowCells, header) ;
        tableRows.add(tr) ;
      }
    }
    else {
      tableRows = [ createTableRow(rowsList, header) ] ;
    }
  }
  else {
    tableRows = [ createTableRow(rows, header) ] ;
  }

  return tableRows;
}

TRowElement createTableRow( dynamic rowCells , [ bool header ] ) {
  header ??= false ;

  if ( rowCells is TRowElement ) {
    return rowCells ;
  }

  Iterable iterable ;

  if (rowCells is Iterable) {
    iterable = List.from(rowCells) ;
  }
  else {
    iterable = [rowCells] ;
  }

  var tr = TRowElement() ;

  if ( header ) {
    tr.addEachAsTag('th', iterable ) ;
  }
  else {
    tr.addEachAsTag('td', iterable ) ;
  }

  return tr ;
}

List<TABLENode> createTableCells( dynamic rowCells , [ bool header ] ) {
  header ??= false ;

  if ( rowCells is List && listMatchesAll(rowCells, (e) => e is DIVElement) ) {
    return rowCells ;
  }
  else if ( rowCells is List && listMatchesAll(rowCells, (e) => e is html_dom.Node) ) {
    var tdList = rowCells.where( (e) => e is html_dom.Element && ( e.localName == 'td' || e.localName == 'th' ) ) ;
    var list = tdList.map( (e) => DOMNode.from(e) ).toList() ;
    list.removeWhere( (e) => e == null ) ;
    return list.cast() ;
  }


  List list ;
  if ( header ) {
    list = $tags('th', rowCells );
  }
  else {
    list = $tags('td', rowCells );
  }

  return list != null ? list.cast() : null ;
}

abstract class TABLENode extends DOMElement {

  TABLENode._(String tag, {Map<String, dynamic> attributes, id, classes, style, content, bool commented}) : super._(tag, attributes: attributes, id: id, classes: classes, style: style, content: content, commented: commented) ;

}

class TABLEElement extends DOMElement {

  factory TABLEElement.from(dynamic entry) {
    if (entry == null) return null ;
    if (entry is TABLEElement) return entry ;

    if ( entry is DOMElement ) {
      _checkTag('table', entry) ;
      return TABLEElement( attributes: entry._attributes , body: entry._content , commented: entry.isCommented ) ;
    }

    return null ;
  }

  TABLEElement( { Map<String, dynamic> attributes, id, classes, style, head, body, foot , content, bool commented } ) : super._('table', attributes: attributes, id: id, classes: classes, style: style, content: createTableContent(content, head, body, foot) , commented: commented );

}

class THEADElement extends TABLENode {

  factory THEADElement.from(dynamic entry) {
    if (entry == null) return null ;
    if (entry is THEADElement) return entry ;

    if ( entry is DOMElement ) {
      _checkTag('thead', entry) ;
      return THEADElement( attributes: entry._attributes , rows: entry._content, commented: entry.isCommented ) ;
    }

    return null ;
  }

  THEADElement( { Map<String, dynamic> attributes, id, classes, style, rows , bool commented} ) : super._('thead', attributes: attributes, id: id, classes: classes, style: style, content: createTableRows(rows, true) , commented: commented);

}


class TBODYElement extends TABLENode {

  factory TBODYElement.from(dynamic entry) {
    if (entry == null) return null ;
    if (entry is TBODYElement) return entry ;

    if ( entry is DOMElement ) {
      _checkTag('tbody', entry) ;
      return TBODYElement( attributes: entry._attributes , rows: entry._content , commented: entry.isCommented ) ;
    }

    return null ;
  }

  TBODYElement( { Map<String, dynamic> attributes, id, classes, style, rows , bool commented } ) : super._('tbody', attributes: attributes, id: id, classes: classes, style: style, content: createTableRows(rows, false) , commented: commented);

}


class TFOOTElement extends TABLENode {

  factory TFOOTElement.from(dynamic entry) {
    if (entry == null) return null ;
    if (entry is TFOOTElement) return entry ;

    if ( entry is DOMElement ) {
      _checkTag('tfoot', entry) ;
      return TFOOTElement( attributes: entry._attributes , rows: entry._content , commented: entry.isCommented ) ;
    }

    return null ;
  }

  TFOOTElement( { Map<String, dynamic> attributes, id, classes, style, rows , bool commented } ) : super._('tfoot', attributes: attributes, id: id, classes: classes, style: style, content: createTableRows(rows, false) , commented: commented);

}

class TRowElement extends TABLENode {

  factory TRowElement.from(dynamic entry) {
    if (entry == null) return null ;
    if (entry is TRowElement) return entry ;

    if ( entry is DOMElement ) {
      _checkTag('tr', entry) ;
      return TRowElement( attributes: entry._attributes , cells: entry._content , commented: entry.isCommented ) ;
    }

    return null ;
  }

  TRowElement( { Map<String, dynamic> attributes, id, classes, style, cells , bool commented } ) : super._('tr', attributes: attributes, id: id, classes: classes, style: style, content: createTableCells(cells) , commented: commented);

}

class THElement extends TABLENode {

  factory THElement.from(dynamic entry) {
    if (entry == null) return null ;
    if (entry is THElement) return entry ;

    if ( entry is DOMElement ) {
      _checkTag('th', entry) ;
      return THElement( attributes: entry._attributes , content: entry._content , commented: entry.isCommented ) ;
    }

    return null ;
  }

  THElement( { Map<String, dynamic> attributes, id, classes, style, content , bool commented } ) : super._('th', attributes: attributes, id: id, classes: classes, style: style, content: content , commented: commented);

}

class TDElement extends TABLENode {

  factory TDElement.from(dynamic entry) {
    if (entry == null) return null ;
    if (entry is TDElement) return entry ;

    if ( entry is DOMElement ) {
      _checkTag('td', entry) ;
      return TDElement( attributes: entry._attributes , content: entry._content , commented: entry.isCommented ) ;
    }

    return null ;
  }

  TDElement( { Map<String, dynamic> attributes, id, classes, style, content , bool commented } ) : super._('td', attributes: attributes, id: id, classes: classes, style: style, content: content , commented: commented);

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

final RegExp _PATTERN_HTML_ELEMENT_INIT = RegExp(r'\s*<\w+');

bool isHTMLElement(String s) {
  if (s == null) return false ;
  return s.startsWith( _PATTERN_HTML_ELEMENT_INIT ) ;
}

DOMNode $node( { content } ) {
  return DOMNode( content: content ) ;
}

DOMElement $tag( String tag , { id, classes, style, Map<String,String> attributes, content , bool commented } ) {
  return DOMElement(tag, id: id, classes: classes, style: style, attributes: attributes, content: content, commented: commented) ;
}

T $tagHTML<T extends DOMElement>(dynamic html) => $html<DOMElement>(html).whereType<T>().first ;

List<DOMElement> $tags<T>( String tag, Iterable<T> iterable , [ ElementGenerator<T> elementGenerator ] ) {
  if (iterable == null) return null ;

  var elements = <DOMElement>[] ;

  if ( elementGenerator != null ) {
    for (var entry in iterable) {
      var elem = elementGenerator(entry) ;
      var tagElem = $tag(tag , content: elem) ;
      elements.add( tagElem ) ;
    }
  }
  else {
    for (var entry in iterable) {
      var tagElem = $tag(tag , content: entry) ;
      elements.add( tagElem ) ;
    }
  }

  return elements ;
}


TABLEElement $table( { id, classes , style, Map<String,String> attributes, head, body, foot, bool commented } ) {
  return TABLEElement( id: id, classes: classes, style: style, attributes: attributes, head: head, body: body, foot: foot, commented: commented );
}

THEADElement $thead( { id, classes , style, Map<String,String> attributes, rows , bool commented } ) {
  return THEADElement( id: id, classes: classes, style: style, attributes: attributes, rows: rows, commented: commented );
}

TBODYElement $tbody( { id, classes , style, Map<String,String> attributes, rows , bool commented } ) {
  return TBODYElement( id: id, classes: classes, style: style, attributes: attributes, rows: rows, commented: commented );
}

TFOOTElement $tfoot( { id, classes , style, Map<String,String> attributes, rows , bool commented } ) {
  return TFOOTElement( id: id, classes: classes, style: style, attributes: attributes, rows: rows, commented: commented );
}

TRowElement $tr( { id, classes , style, Map<String,String> attributes, cells , bool commented } ) {
  return TRowElement( id: id, classes: classes, style: style, attributes: attributes, cells: cells, commented: commented);
}

DOMElement $td( { id, classes , style, Map<String,String> attributes, content , bool commented } ) => $tag('td', id: id, classes: classes, style: style, attributes: attributes, content: content, commented: commented) ;
DOMElement $th( { id, classes , style, Map<String,String> attributes, content , bool commented } ) => $tag('td', id: id, classes: classes, style: style, attributes: attributes, content: content, commented: commented) ;

DIVElement $div( { id, classes , style, Map<String,String> attributes, content , bool commented } ) => $tag('div', id: id, classes: classes, style: style, attributes: attributes, content: content, commented: commented) ;

DIVElement $divInline( { id, classes , style, Map<String,String> attributes, content , bool commented } ) => $tag('div', id: id, classes: classes, style: toFlatListOfStrings(['display: inline-block', style], delimiter: CSS_LIST_DELIMITER) , attributes: attributes, content: content, commented: commented) ;

DIVElement $divHTML(dynamic html) => $tagHTML(html);

DOMElement $span( { id, classes , style, Map<String,String> attributes, content , bool commented } ) => $tag('span', id: id, classes: classes, style: style, attributes: attributes, content: content, commented: commented) ;

DOMElement $button( { id, classes , style, type, Map<String,String> attributes, content , bool commented } ) => $tag('button', id: id, classes: classes, style: style, attributes: { 'type': type, ...?attributes }, content: content, commented: commented) ;

DOMElement $label( { id, classes , style, Map<String,String> attributes, content , bool commented } ) => $tag('label', id: id, classes: classes, style: style, attributes: attributes, content: content, commented: commented) ;

DOMElement $textarea( { id, classes , style, Map<String,String> attributes, content , bool commented } ) => $tag('textarea', id: id, classes: classes, style: style, attributes: attributes, content: content, commented: commented) ;

DOMElement $input( { id, classes , style, type, Map<String,String> attributes, value , bool commented } ) => $tag('input', id: id, classes: classes, style: style, attributes: { 'type': type, 'value': value, ...?attributes }, commented: commented) ;

DOMElement $p( { id, classes , style, Map<String,String> attributes , bool commented } ) => $tag('p', id: id, classes: classes, style: style, attributes: attributes, commented: commented) ;

DOMElement $br( { id, classes , style, Map<String,String> attributes , bool commented } ) => $tag('br', id: id, classes: classes, style: style, attributes: attributes, commented: commented) ;

DOMElement $hr( { id, classes , style, Map<String,String> attributes , bool commented } ) => $tag('hr', id: id, classes: classes, style: style, attributes: attributes, commented: commented) ;



