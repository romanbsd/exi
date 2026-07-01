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
  late final Map<String, XmlElement> _modelGroups = _collectModelGroups();
  late final Map<String, XmlElement> _globalElementNodes = _collectGlobalElements();
  late final Map<String, XmlElement> _globalAttributeNodes = _collectGlobalAttributes();
  final Map<String, ExiElementDeclaration> _compiledGlobalElements = {};
  final Map<String, ExiAttributeDeclaration> _compiledGlobalAttributes = {};
  final Map<String, ExiParticle> _compiledModelGroups = {};
  final Set<String> _compilingGlobalElements = {};
  final Set<String> _compilingModelGroups = {};

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

  Map<String, XmlElement> _collectGlobalAttributes() {
    final result = <String, XmlElement>{};
    for (final attribute in _children(root, 'attribute')) {
      final name = attribute.getAttribute('name');
      if (name == null || name.isEmpty) {
        throw const FormatException('Global XSD attribute declaration is missing a name');
      }
      if (result.containsKey(name)) {
        throw FormatException('Duplicate global XSD attribute "$name"');
      }
      result[name] = attribute;
    }
    return result;
  }

  Map<String, XmlElement> _collectModelGroups() {
    final result = <String, XmlElement>{};
    for (final group in _children(root, 'group')) {
      final name = group.getAttribute('name');
      if (name == null || name.isEmpty) {
        throw const FormatException('Global XSD model group is missing a name');
      }
      if (result.containsKey(name)) {
        throw FormatException('Duplicate global XSD model group "$name"');
      }
      result[name] = group;
    }
    return result;
  }

  Map<String, XmlElement> _collectGlobalElements() {
    final result = <String, XmlElement>{};
    for (final element in _children(root, 'element')) {
      _requireGlobalOccurrence(element);
      final name = element.getAttribute('name');
      if (name == null || name.isEmpty) {
        throw const FormatException('Global XSD element declaration is missing a name');
      }
      if (result.containsKey(name)) {
        throw FormatException('Duplicate global XSD element "$name"');
      }
      result[name] = element;
    }
    return result;
  }

  ExiSchema compile() {
    if (_globalElementNodes.isEmpty) {
      throw const FormatException('XML Schema contains no global elements');
    }
    return ExiSchema(
      id: id,
      globalElements: [for (final name in _globalElementNodes.keys) _compileGlobalElement(name)],
    );
  }

  ExiElementDeclaration _compileGlobalElement(String localName) {
    final cached = _compiledGlobalElements[localName];
    if (cached != null) {
      return cached;
    }
    final element = _globalElementNodes[localName];
    if (element == null) {
      throw FormatException('Unknown global XSD element "$localName"');
    }
    if (!_compilingGlobalElements.add(localName)) {
      throw UnsupportedError('Recursive XSD element reference "$localName" is not supported yet');
    }
    try {
      return _compiledGlobalElements[localName] = _compileElement(element, global: true);
    } finally {
      _compilingGlobalElements.remove(localName);
    }
  }

  ExiElementDeclaration _compileElement(XmlElement element, {required bool global}) {
    if (element.getAttribute('ref') != null) {
      throw const FormatException('Global XSD elements cannot use ref');
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
    final compositors = [
      ..._children(complexType, 'sequence'),
      ..._children(complexType, 'choice'),
      ..._children(complexType, 'group'),
    ];
    if (compositors.length > 1) {
      throw UnsupportedError('A complex type with multiple compositors is not supported');
    }
    if (compositors.isEmpty) {
      if (attributes.isNotEmpty) {
        return ExiElementDeclaration.complex(name, attributes: attributes);
      }
      return ExiElementDeclaration.empty(name);
    }
    final compositor = compositors.single;
    final content = _compileParticle(compositor);
    final particles = content is ExiSequenceParticle ? content.particles : const <ExiParticle>[];
    final isFixedSequence =
        attributes.isEmpty &&
        compositor.name.local == 'sequence' &&
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

  ExiParticle _compileParticle(XmlElement particle) {
    switch (particle.name.local) {
      case 'element':
        return _compileElementParticle(particle);
      case 'sequence':
      case 'choice':
        _requireSingleCompositorOccurrence(particle);
        final children = <ExiParticle>[];
        for (final child in particle.children.whereType<XmlElement>()) {
          if (child.name.namespaceUri != _xsdUri || child.name.local == 'annotation') {
            continue;
          }
          if (child.name.local == 'all') {
            throw UnsupportedError('The XSD all compositor is not supported yet');
          }
          if (!const {'element', 'sequence', 'choice', 'group'}.contains(child.name.local)) {
            throw UnsupportedError('Unsupported XSD particle "${child.name.local}"');
          }
          children.add(_compileParticle(child));
        }
        return particle.name.local == 'sequence' ? ExiSequenceParticle(children) : ExiChoiceParticle(children);
      case 'group':
        _requireSingleCompositorOccurrence(particle);
        final reference = particle.getAttribute('ref');
        if (reference == null || reference.isEmpty) {
          throw const FormatException('An XSD model-group particle must specify ref');
        }
        return _compileModelGroup(_resolveLocalReference(particle, reference, 'model-group'));
      default:
        throw UnsupportedError('Unsupported XSD particle "${particle.name.local}"');
    }
  }

  ExiParticle _compileModelGroup(String localName) {
    final cached = _compiledModelGroups[localName];
    if (cached != null) {
      return cached;
    }
    final group = _modelGroups[localName];
    if (group == null) {
      throw FormatException('Unknown global XSD model group "$localName"');
    }
    if (!_compilingModelGroups.add(localName)) {
      throw UnsupportedError('Recursive XSD model group "$localName" is not supported yet');
    }
    try {
      final compositors = [..._children(group, 'sequence'), ..._children(group, 'choice')];
      if (compositors.length != 1) {
        throw const FormatException('A global XSD model group must contain one sequence or choice');
      }
      return _compiledModelGroups[localName] = _compileParticle(compositors.single);
    } finally {
      _compilingModelGroups.remove(localName);
    }
  }

  void _requireSingleCompositorOccurrence(XmlElement compositor) {
    if ((compositor.getAttribute('minOccurs') ?? '1') != '1' || (compositor.getAttribute('maxOccurs') ?? '1') != '1') {
      throw UnsupportedError('Occurrence constraints on XSD compositors are not supported yet');
    }
  }

  ExiParticle _compileElementParticle(XmlElement element) {
    final reference = element.getAttribute('ref');
    final declaration = reference == null
        ? _compileElement(element, global: false)
        : _resolveElementReference(element, reference);
    final minOccurs = _occurs(element, 'minOccurs', defaultValue: 1);
    final maxValue = element.getAttribute('maxOccurs') ?? '1';
    final maxOccurs = maxValue == 'unbounded'
        ? null
        : int.tryParse(maxValue) ?? (throw FormatException('Invalid XSD maxOccurs value "$maxValue"'));
    if (maxOccurs != null && (maxOccurs < minOccurs || maxOccurs < 0)) {
      throw const FormatException('Invalid XSD element occurrence range');
    }
    return ExiElementParticle(declaration, minOccurs: minOccurs, maxOccurs: maxOccurs);
  }

  ExiElementDeclaration _resolveElementReference(XmlElement element, String reference) {
    if (element.getAttribute('name') != null ||
        element.getAttribute('type') != null ||
        _children(element, 'complexType').isNotEmpty ||
        _children(element, 'simpleType').isNotEmpty) {
      throw const FormatException('An XSD element reference cannot declare a name or type');
    }
    return _compileGlobalElement(_resolveLocalReference(element, reference, 'element'));
  }

  String _resolveLocalReference(XmlElement context, String reference, String kind) {
    final separator = reference.indexOf(':');
    if (separator != reference.lastIndexOf(':')) {
      throw FormatException('Invalid XSD $kind reference "$reference"');
    }
    final prefix = separator == -1 ? '' : reference.substring(0, separator);
    final localName = separator == -1 ? reference : reference.substring(separator + 1);
    if (localName.isEmpty || (separator != -1 && prefix.isEmpty)) {
      throw FormatException('Invalid XSD $kind reference "$reference"');
    }

    String? namespaceUri;
    for (final namespace in context.namespaces) {
      if (namespace.prefix == prefix) {
        namespaceUri = namespace.uri;
        break;
      }
    }
    if (prefix.isNotEmpty && namespaceUri == null) {
      throw FormatException('Unknown namespace prefix "$prefix" in XSD $kind reference');
    }
    namespaceUri ??= '';
    if (namespaceUri != targetNamespace) {
      throw UnsupportedError('References to $kind declarations in external XSD namespaces are not supported yet');
    }
    return localName;
  }

  ExiAttributeDeclaration _compileAttribute(XmlElement attribute) {
    final reference = attribute.getAttribute('ref');
    if (reference != null) {
      if (attribute.getAttribute('name') != null ||
          attribute.getAttribute('type') != null ||
          _children(attribute, 'simpleType').isNotEmpty) {
        throw const FormatException('An XSD attribute reference cannot declare a name or type');
      }
      final declaration = _compileGlobalAttribute(_resolveLocalReference(attribute, reference, 'attribute'));
      return ExiAttributeDeclaration(
        name: declaration.name,
        datatype: declaration.datatype,
        required: _isRequiredAttribute(attribute),
      );
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
      required: _isRequiredAttribute(attribute),
    );
  }

  ExiAttributeDeclaration _compileGlobalAttribute(String localName) {
    final cached = _compiledGlobalAttributes[localName];
    if (cached != null) {
      return cached;
    }
    final attribute = _globalAttributeNodes[localName];
    if (attribute == null) {
      throw FormatException('Unknown global XSD attribute "$localName"');
    }
    if (attribute.getAttribute('ref') != null || attribute.getAttribute('use') != null) {
      throw const FormatException('Global XSD attributes cannot specify ref or use');
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
    return _compiledGlobalAttributes[localName] = ExiAttributeDeclaration(
      name: ExiQName(uri: targetNamespace, localName: localName),
      datatype: datatype,
    );
  }

  bool _isRequiredAttribute(XmlElement attribute) {
    return switch (attribute.getAttribute('use')) {
      null || 'optional' => false,
      'required' => true,
      'prohibited' => throw UnsupportedError('Prohibited XSD attributes are not supported yet'),
      final value => throw FormatException('Invalid XSD attribute use "$value"'),
    };
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
