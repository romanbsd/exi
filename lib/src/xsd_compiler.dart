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
      localElementsAreQualified = root.getAttribute('elementFormDefault') == 'qualified',
      localAttributesAreQualified = root.getAttribute('attributeFormDefault') == 'qualified';

  final String id;
  final XmlElement root;
  final String targetNamespace;
  final bool localElementsAreQualified;
  final bool localAttributesAreQualified;

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
    final globals = <ExiElementDeclaration>[];
    for (final element in _children(root, 'element')) {
      _requireGlobalOccurrence(element);
      globals.add(_compileElement(element, global: true));
    }
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
    if (switch (complexType.getAttribute('mixed')) {
      'true' || '1' => true,
      _ => false,
    }) {
      throw UnsupportedError('Mixed XSD complex content is not supported yet');
    }
    if (_children(complexType, 'all').isNotEmpty) {
      throw UnsupportedError('The XSD all compositor is not supported yet');
    }
    final attributes = [for (final attribute in _children(complexType, 'attribute')) _compileAttribute(attribute)]
      ..sort((left, right) {
        final localNameOrder = left.name.localName.compareTo(right.name.localName);
        return localNameOrder != 0 ? localNameOrder : left.name.uri.compareTo(right.name.uri);
      });
    final sequence = _children(complexType, 'sequence').firstOrNull;
    final choice = _children(complexType, 'choice').firstOrNull;
    if (sequence != null && choice != null) {
      throw UnsupportedError('A complex type with multiple compositors is not supported');
    }
    if (sequence == null && choice == null) {
      if (attributes.isNotEmpty) {
        return ExiElementDeclaration.complex(name, attributes: attributes);
      }
      return ExiElementDeclaration.empty(name);
    }
    final compositor = sequence ?? choice!;
    if ((compositor.getAttribute('minOccurs') ?? '1') != '1' || (compositor.getAttribute('maxOccurs') ?? '1') != '1') {
      throw UnsupportedError('Occurrence constraints on XSD compositors are not supported yet');
    }
    final particles = [for (final child in _children(compositor, 'element')) _compileElementParticle(child)];
    final content = sequence != null ? ExiSequenceParticle(particles) : ExiChoiceParticle(particles);
    final isFixedSequence =
        attributes.isEmpty &&
        sequence != null &&
        particles.every(
          (particle) => particle is ExiElementParticle && particle.minOccurs == 1 && particle.maxOccurs == 1,
        );
    if (isFixedSequence) {
      return ExiElementDeclaration.sequence(name, [
        for (final particle in particles.cast<ExiElementParticle>()) particle.element,
      ]);
    }
    return ExiElementDeclaration.complex(name, attributes: attributes, content: content);
  }

  ExiParticle _compileElementParticle(XmlElement element) {
    final declaration = _compileElement(element, global: false);
    final minOccurs = _occurs(element, 'minOccurs', defaultValue: 1);
    final maxValue = element.getAttribute('maxOccurs') ?? '1';
    final maxOccurs = maxValue == 'unbounded' ? null : int.tryParse(maxValue);
    if (maxOccurs != null && (maxOccurs < minOccurs || maxOccurs < 0)) {
      throw const FormatException('Invalid XSD element occurrence range');
    }
    return ExiElementParticle(declaration, minOccurs: minOccurs, maxOccurs: maxOccurs);
  }

  ExiAttributeDeclaration _compileAttribute(XmlElement attribute) {
    if (attribute.getAttribute('ref') != null) {
      throw UnsupportedError('XSD attribute references are not supported yet');
    }
    final localName = attribute.getAttribute('name');
    if (localName == null || localName.isEmpty) {
      throw const FormatException('XSD attribute declaration is missing a name');
    }
    final typeName = attribute.getAttribute('type');
    final inlineSimple = _children(attribute, 'simpleType').firstOrNull;
    final datatype = typeName != null
        ? _builtinDatatype(typeName)
        : inlineSimple != null
        ? _compileSimpleType(inlineSimple)
        : ExiDatatype.string;
    if (datatype == null) {
      throw UnsupportedError('Unsupported XSD attribute type "$typeName"');
    }
    return ExiAttributeDeclaration(
      name: ExiQName(uri: localAttributesAreQualified ? targetNamespace : '', localName: localName),
      datatype: datatype,
      required: attribute.getAttribute('use') == 'required',
    );
  }

  ExiDatatype _compileSimpleType(XmlElement simpleType) {
    final restriction = _children(simpleType, 'restriction').firstOrNull;
    final base = restriction?.getAttribute('base');
    if (base == null) {
      throw UnsupportedError('Only XSD simple-type restrictions are supported');
    }
    return _builtinDatatype(base) ?? (throw UnsupportedError('Unsupported XSD simple type "$base"'));
  }

  void _requireGlobalOccurrence(XmlElement element) {
    if (element.getAttribute('minOccurs') != null || element.getAttribute('maxOccurs') != null) {
      throw const FormatException('Global XSD elements cannot specify occurrence constraints');
    }
  }

  int _occurs(XmlElement element, String attribute, {required int defaultValue}) {
    final value = element.getAttribute(attribute);
    if (value == null) {
      return defaultValue;
    }
    final parsed = int.tryParse(value);
    if (parsed == null || parsed < 0) {
      throw FormatException('Invalid XSD $attribute value "$value"');
    }
    return parsed;
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
