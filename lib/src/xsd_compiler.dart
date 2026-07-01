import 'package:xml/xml.dart';

import 'model.dart';
import 'schema.dart';

const _xsdUri = 'http://www.w3.org/2001/XMLSchema';

final class ExiSchemaCompiler {
  static ExiSchema compile({required String id, required String source}) {
    final document = XmlDocument.parse(source);
    final root = document.rootElement;
    if (root.name.local != 'schema' || root.name.namespaceUri != _xsdUri) {
      throw const FormatException('Expected an XML Schema document');
    }
    return _Compiler(id, root).compile();
  }
}

final class _Compiler {
  _Compiler(this.id, this.root)
    : targetNamespace = root.getAttribute('targetNamespace') ?? '',
      localElementsAreQualified = root.getAttribute('elementFormDefault') == 'qualified';

  final String id;
  final XmlElement root;
  final String targetNamespace;
  final bool localElementsAreQualified;

  late final Map<String, XmlElement> _complexTypes = _collectComplexTypes();

  Map<String, XmlElement> _collectComplexTypes() {
    final result = <String, XmlElement>{};
    for (final element in _children(root, 'complexType')) {
      final name = element.getAttribute('name');
      if (name != null) {
        result[name] = element;
      }
    }
    return result;
  }

  ExiSchema compile() {
    final globals = [for (final element in _children(root, 'element')) _compileElement(element, global: true)];
    if (globals.isEmpty) {
      throw const FormatException('XML Schema contains no global elements');
    }
    return ExiSchema(id: id, globalElements: globals);
  }

  ExiElementDeclaration _compileElement(XmlElement element, {required bool global}) {
    if (element.getAttribute('ref') != null) {
      throw UnsupportedError('XSD element references are not supported yet');
    }
    final localName = element.getAttribute('name');
    if (localName == null || localName.isEmpty) {
      throw const FormatException('XSD element declaration is missing a name');
    }
    _requireSingleOccurrence(element);
    final name = ExiQName(uri: global || localElementsAreQualified ? targetNamespace : '', localName: localName);

    final typeName = element.getAttribute('type');
    if (typeName != null) {
      final builtin = _builtinDatatype(typeName);
      if (builtin != null) {
        return ExiElementDeclaration.value(name, builtin);
      }
      final complexType = _complexTypes[_localPart(typeName)];
      if (complexType == null) {
        throw UnsupportedError('Unknown or unsupported XSD type "$typeName"');
      }
      return _compileComplexType(name, complexType);
    }

    final inlineComplex = _children(element, 'complexType').firstOrNull;
    if (inlineComplex != null) {
      return _compileComplexType(name, inlineComplex);
    }
    final inlineSimple = _children(element, 'simpleType').firstOrNull;
    if (inlineSimple != null) {
      return ExiElementDeclaration.value(name, _compileSimpleType(inlineSimple));
    }
    return ExiElementDeclaration.empty(name);
  }

  ExiElementDeclaration _compileComplexType(ExiQName name, XmlElement complexType) {
    if (_children(complexType, 'attribute').isNotEmpty ||
        _children(complexType, 'choice').isNotEmpty ||
        _children(complexType, 'all').isNotEmpty) {
      throw UnsupportedError('XSD attributes, choice, and all compositors are not supported yet');
    }
    final sequence = _children(complexType, 'sequence').firstOrNull;
    if (sequence == null) {
      return ExiElementDeclaration.empty(name);
    }
    final children = [for (final child in _children(sequence, 'element')) _compileElement(child, global: false)];
    return ExiElementDeclaration.sequence(name, children);
  }

  ExiDatatype _compileSimpleType(XmlElement simpleType) {
    final restriction = _children(simpleType, 'restriction').firstOrNull;
    final base = restriction?.getAttribute('base');
    if (base == null) {
      throw UnsupportedError('Only XSD simple-type restrictions are supported');
    }
    return _builtinDatatype(base) ?? (throw UnsupportedError('Unsupported XSD simple type "$base"'));
  }

  void _requireSingleOccurrence(XmlElement element) {
    final minOccurs = element.getAttribute('minOccurs') ?? '1';
    final maxOccurs = element.getAttribute('maxOccurs') ?? '1';
    if (minOccurs != '1' || maxOccurs != '1') {
      throw UnsupportedError('Only required single-occurrence XSD particles are supported');
    }
  }

  ExiDatatype? _builtinDatatype(String qualifiedName) {
    final separator = qualifiedName.indexOf(':');
    final prefix = separator == -1 ? '' : qualifiedName.substring(0, separator);
    if (!root.namespaces.any((namespace) => namespace.prefix == prefix && namespace.uri == _xsdUri)) {
      return null;
    }
    final localName = _localPart(qualifiedName);
    return switch (localName) {
      'string' ||
      'anySimpleType' ||
      'normalizedString' ||
      'token' ||
      'language' ||
      'Name' ||
      'NCName' ||
      'NMTOKEN' ||
      'ID' ||
      'IDREF' ||
      'ENTITY' ||
      'anyURI' => ExiDatatype.string,
      'boolean' => ExiDatatype.boolean,
      'decimal' => ExiDatatype.decimal,
      'float' || 'double' => ExiDatatype.float,
      'integer' || 'long' || 'int' || 'short' || 'negativeInteger' || 'nonPositiveInteger' => ExiDatatype.integer,
      'byte' => ExiDatatype.byte,
      'nonNegativeInteger' ||
      'positiveInteger' ||
      'unsignedLong' ||
      'unsignedInt' ||
      'unsignedShort' => ExiDatatype.unsignedInteger,
      'unsignedByte' => ExiDatatype.unsignedByte,
      'base64Binary' => ExiDatatype.base64Binary,
      'hexBinary' => ExiDatatype.hexBinary,
      'dateTime' => ExiDatatype.dateTime,
      'date' => ExiDatatype.date,
      'time' => ExiDatatype.time,
      _ => null,
    };
  }
}

Iterable<XmlElement> _children(XmlElement parent, String localName) => parent.children.whereType<XmlElement>().where(
  (element) => element.name.local == localName && element.name.namespaceUri == _xsdUri,
);

String _localPart(String qualifiedName) {
  final separator = qualifiedName.indexOf(':');
  return separator == -1 ? qualifiedName : qualifiedName.substring(separator + 1);
}
