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
  late final Map<String, XmlElement> _simpleTypes = _collectSimpleTypes();
  late final Map<String, XmlElement> _modelGroups = _collectModelGroups();
  late final Map<String, XmlElement> _attributeGroups = _collectAttributeGroups();
  late final Map<String, XmlElement> _globalElementNodes = _collectGlobalElements();
  late final Map<String, XmlElement> _globalAttributeNodes = _collectGlobalAttributes();
  final Map<String, ExiElementDeclaration> _compiledGlobalElements = {};
  final Map<String, ExiAttributeDeclaration> _compiledGlobalAttributes = {};
  final Map<String, ExiParticle> _compiledModelGroups = {};
  final Map<String, ExiDatatype> _compiledSimpleTypes = {};
  final Map<String, List<ExiAttributeDeclaration>> _compiledAttributeGroups = {};
  final Set<String> _compilingComplexTypes = {};
  final Set<String> _compilingGlobalElements = {};
  final Set<String> _compilingModelGroups = {};
  final Set<String> _compilingSimpleTypes = {};
  final Set<String> _compilingAttributeGroups = {};

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

  Map<String, XmlElement> _collectSimpleTypes() {
    final result = <String, XmlElement>{};
    for (final element in _children(root, 'simpleType')) {
      final name = element.getAttribute('name');
      if (name == null || name.isEmpty) {
        throw const FormatException('Global XSD simple type is missing a name');
      }
      if (result.containsKey(name)) {
        throw FormatException('Duplicate global XSD simple type "$name"');
      }
      result[name] = element;
    }
    return result;
  }

  Map<String, XmlElement> _collectAttributeGroups() {
    final result = <String, XmlElement>{};
    for (final group in _children(root, 'attributeGroup')) {
      final name = group.getAttribute('name');
      if (name == null || name.isEmpty) {
        throw const FormatException('Global XSD attribute group is missing a name');
      }
      if (result.containsKey(name)) {
        throw FormatException('Duplicate global XSD attribute group "$name"');
      }
      result[name] = group;
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
      globalAttributes: [for (final name in _globalAttributeNodes.keys) _compileGlobalAttribute(name)],
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
    final qualified = global
        ? element.getAttribute('form') == null
        : _isQualifiedForm(element, defaultQualified: localElementsAreQualified, kind: 'element');
    if (global && element.getAttribute('form') != null) {
      throw const FormatException('Global XSD elements cannot specify form');
    }
    final name = ExiQName(uri: qualified ? targetNamespace : '', localName: localName);
    final nillable = switch (element.getAttribute('nillable')) {
      null || 'false' || '0' => false,
      'true' || '1' => true,
      final value => throw FormatException('Invalid XSD nillable value "$value"'),
    };

    final typeName = element.getAttribute('type');
    if (typeName != null) {
      final simpleDatatype = _resolveSimpleDatatype(element, typeName);
      if (simpleDatatype != null) {
        return ExiElementDeclaration.value(name, simpleDatatype, nillable: nillable);
      }
      final complexTypeName = _resolveNamedTypeLocalName(element, typeName);
      final complexType = _complexTypes[complexTypeName];
      if (complexType == null) {
        throw UnsupportedError('Unknown or unsupported XSD type "$typeName"');
      }
      final declaration = _compileNamedComplexType(name, complexTypeName, nillable: nillable);
      final alternatives = <ExiQName, ExiElementDeclaration>{};
      for (final candidate in _complexTypes.keys) {
        if (candidate != complexTypeName && _isComplexTypeDerivedFrom(candidate, complexTypeName, <String>{})) {
          alternatives[ExiQName(uri: targetNamespace, localName: candidate)] = _compileNamedComplexType(
            name,
            candidate,
            nillable: false,
          );
        }
      }
      return alternatives.isEmpty ? declaration : _withTypeAlternatives(declaration, alternatives);
    }

    final inlineComplex = _children(element, 'complexType').firstOrNull;
    if (inlineComplex != null) {
      return _compileComplexType(name, inlineComplex, nillable: nillable);
    }
    final inlineSimple = _children(element, 'simpleType').firstOrNull;
    if (inlineSimple != null) {
      return ExiElementDeclaration.value(name, _compileSimpleType(inlineSimple), nillable: nillable);
    }
    return ExiElementDeclaration.empty(name, nillable: nillable);
  }

  ExiElementDeclaration _compileNamedComplexType(ExiQName name, String typeName, {required bool nillable}) {
    final complexType = _complexTypes[typeName];
    if (complexType == null) {
      throw FormatException('Unknown global XSD complex type "$typeName"');
    }
    if (!_compilingComplexTypes.add(typeName)) {
      throw UnsupportedError('Recursive XSD complex type "$typeName" is not supported');
    }
    try {
      return _compileComplexType(name, complexType, nillable: nillable);
    } finally {
      _compilingComplexTypes.remove(typeName);
    }
  }

  bool _isComplexTypeDerivedFrom(String candidate, String base, Set<String> visited) {
    if (!visited.add(candidate)) {
      return false;
    }
    final complexType = _complexTypes[candidate]!;
    final complexContent = _children(complexType, 'complexContent').firstOrNull;
    final extension = complexContent == null ? null : _children(complexContent, 'extension').firstOrNull;
    final baseName = extension?.getAttribute('base');
    if (baseName == null) {
      return false;
    }
    final parent = _resolveNamedTypeLocalName(extension!, baseName);
    return parent == base || (_complexTypes.containsKey(parent) && _isComplexTypeDerivedFrom(parent, base, visited));
  }

  ExiElementDeclaration _withTypeAlternatives(
    ExiElementDeclaration declaration,
    Map<ExiQName, ExiElementDeclaration> alternatives,
  ) {
    if (declaration.datatype != null) {
      return ExiElementDeclaration.simpleContent(
        declaration.name,
        declaration.datatype,
        attributes: declaration.attributes,
        nillable: declaration.nillable,
        typeAlternatives: alternatives,
        anyAttribute: declaration.anyAttribute,
        attributeWildcardNamespaces: declaration.attributeWildcardNamespaces,
        attributeWildcardExcludedNamespaces: declaration.attributeWildcardExcludedNamespaces,
        attributeProcessContents: declaration.attributeProcessContents,
      );
    }
    if (declaration.content != null ||
        declaration.attributes.isNotEmpty ||
        declaration.mixed ||
        declaration.anyAttribute) {
      return ExiElementDeclaration.complex(
        declaration.name,
        attributes: declaration.attributes,
        content: declaration.content,
        mixed: declaration.mixed,
        nillable: declaration.nillable,
        typeAlternatives: alternatives,
        anyAttribute: declaration.anyAttribute,
        attributeWildcardNamespaces: declaration.attributeWildcardNamespaces,
        attributeWildcardExcludedNamespaces: declaration.attributeWildcardExcludedNamespaces,
        attributeProcessContents: declaration.attributeProcessContents,
      );
    }
    if (declaration.children.isNotEmpty) {
      return ExiElementDeclaration.sequence(
        declaration.name,
        declaration.children,
        nillable: declaration.nillable,
        typeAlternatives: alternatives,
      );
    }
    return ExiElementDeclaration.empty(
      declaration.name,
      nillable: declaration.nillable,
      typeAlternatives: alternatives,
    );
  }

  ExiElementDeclaration _compileComplexType(ExiQName name, XmlElement complexType, {required bool nillable}) {
    final mixed = switch (complexType.getAttribute('mixed')) {
      null || 'false' || '0' => false,
      'true' || '1' => true,
      final value => throw FormatException('Invalid XSD mixed value "$value"'),
    };
    final simpleContent = _children(complexType, 'simpleContent').firstOrNull;
    final complexContent = _children(complexType, 'complexContent').firstOrNull;
    if (simpleContent != null && complexContent != null) {
      throw const FormatException('An XSD complex type cannot have both simple and complex content');
    }
    if (simpleContent != null) {
      if (mixed) {
        throw const FormatException('XSD simple content cannot be mixed');
      }
      return _compileSimpleContent(name, simpleContent, nillable: nillable);
    }
    if (complexContent != null) {
      return _compileComplexContent(name, complexContent, mixed: mixed, nillable: nillable);
    }
    final attributes = _compileAttributes(complexType);
    final anyAttribute = _hasAnyAttribute(complexType);
    final attributeWildcardNamespaces = _attributeWildcardNamespaces(complexType);
    final attributeWildcardExcludedNamespaces = _attributeWildcardExcludedNamespaces(complexType);
    final compositors = [
      ..._children(complexType, 'sequence'),
      ..._children(complexType, 'choice'),
      ..._children(complexType, 'all'),
      ..._children(complexType, 'group'),
    ];
    if (compositors.length > 1) {
      throw UnsupportedError('A complex type with multiple compositors is not supported');
    }
    if (compositors.isEmpty) {
      if (attributes.isNotEmpty || mixed || anyAttribute) {
        return ExiElementDeclaration.complex(
          name,
          attributes: attributes,
          mixed: mixed,
          nillable: nillable,
          anyAttribute: anyAttribute,
          attributeWildcardNamespaces: attributeWildcardNamespaces,
          attributeWildcardExcludedNamespaces: attributeWildcardExcludedNamespaces,
          attributeProcessContents: _attributeProcessContents(complexType),
        );
      }
      return ExiElementDeclaration.empty(name, nillable: nillable);
    }
    final compositor = compositors.single;
    final content = _compileParticle(compositor);
    final particles = content is ExiSequenceParticle ? content.particles : const <ExiParticle>[];
    final isFixedSequence =
        attributes.isEmpty &&
        !mixed &&
        compositor.name.local == 'sequence' &&
        content is ExiSequenceParticle &&
        particles.every(
          (particle) => particle is ExiElementParticle && particle.minOccurs == 1 && particle.maxOccurs == 1,
        );
    if (isFixedSequence) {
      return ExiElementDeclaration.sequence(name, [
        for (final particle in particles.cast<ExiElementParticle>()) particle.element,
      ], nillable: nillable);
    }
    return ExiElementDeclaration.complex(
      name,
      attributes: attributes,
      content: content,
      mixed: mixed,
      nillable: nillable,
      anyAttribute: anyAttribute,
      attributeWildcardNamespaces: attributeWildcardNamespaces,
      attributeWildcardExcludedNamespaces: attributeWildcardExcludedNamespaces,
      attributeProcessContents: _attributeProcessContents(complexType),
    );
  }

  ExiElementDeclaration _compileComplexContent(
    ExiQName name,
    XmlElement complexContent, {
    required bool mixed,
    required bool nillable,
  }) {
    final extension = _children(complexContent, 'extension').firstOrNull;
    if (extension == null || _children(complexContent, 'restriction').isNotEmpty) {
      throw UnsupportedError('Only XSD complex-content extension is supported');
    }
    final baseName = extension.getAttribute('base');
    if (baseName == null) {
      throw const FormatException('XSD complex-content extension is missing its base type');
    }
    final base = _compileNamedComplexType(name, _resolveNamedTypeLocalName(extension, baseName), nillable: nillable);
    if (base.datatype != null) {
      throw UnsupportedError('XSD complex content cannot extend simple content');
    }

    final attributes = [...base.attributes, ..._compileAttributes(extension)]..sort(_compareAttributes);
    for (var index = 1; index < attributes.length; index++) {
      if (attributes[index - 1].name == attributes[index].name) {
        throw FormatException('Duplicate inherited XSD attribute "${attributes[index].name.localName}"');
      }
    }

    final compositors = [
      ..._children(extension, 'sequence'),
      ..._children(extension, 'choice'),
      ..._children(extension, 'all'),
      ..._children(extension, 'group'),
    ];
    for (final child in extension.children.whereType<XmlElement>()) {
      if (child.name.namespaceUri == _xsdUri &&
          !const {
            'annotation',
            'sequence',
            'choice',
            'all',
            'group',
            'attribute',
            'attributeGroup',
          }.contains(child.name.local)) {
        throw UnsupportedError('Unsupported XSD complex-content component "${child.name.local}"');
      }
    }
    if (compositors.length > 1) {
      throw UnsupportedError('A complex-content extension with multiple compositors is not supported');
    }
    final extensionContent = compositors.isEmpty ? const ExiEmptyParticle() : _compileParticle(compositors.single);
    final content = _concatenateParticles(_declarationContent(base), extensionContent);
    final contentMixed = switch (complexContent.getAttribute('mixed')) {
      null || 'false' || '0' => false,
      'true' || '1' => true,
      final value => throw FormatException('Invalid XSD mixed value "$value"'),
    };
    final extensionAnyAttribute = _hasAnyAttribute(extension);
    if ((base.attributeWildcardExcludedNamespaces != null && extensionAnyAttribute) ||
        (_attributeWildcardExcludedNamespaces(extension) != null && base.anyAttribute)) {
      throw UnsupportedError('Combining ##other with inherited attribute wildcards is not supported yet');
    }
    final anyAttribute = base.anyAttribute || extensionAnyAttribute;
    final attributeWildcardNamespaces = _mergeWildcardNamespaces(
      base.anyAttribute,
      base.attributeWildcardNamespaces,
      extensionAnyAttribute,
      _attributeWildcardNamespaces(extension),
    );
    return ExiElementDeclaration.complex(
      name,
      attributes: attributes,
      content: content,
      mixed: mixed || contentMixed || base.mixed,
      nillable: nillable,
      anyAttribute: anyAttribute,
      attributeWildcardNamespaces: attributeWildcardNamespaces,
      attributeWildcardExcludedNamespaces:
          base.attributeWildcardExcludedNamespaces ?? _attributeWildcardExcludedNamespaces(extension),
      attributeProcessContents: extensionAnyAttribute
          ? _attributeProcessContents(extension)
          : base.attributeProcessContents,
    );
  }

  ExiParticle _declarationContent(ExiElementDeclaration declaration) {
    return declaration.content ??
        (declaration.children.isEmpty
            ? const ExiEmptyParticle()
            : ExiSequenceParticle([for (final child in declaration.children) ExiElementParticle(child)]));
  }

  ExiParticle _concatenateParticles(ExiParticle left, ExiParticle right) {
    final particles = <ExiParticle>[];
    for (final particle in [left, right]) {
      switch (particle) {
        case ExiEmptyParticle():
          break;
        case ExiSequenceParticle(particles: final nested):
          particles.addAll(nested);
        default:
          particles.add(particle);
      }
    }
    if (particles.isEmpty) {
      return const ExiEmptyParticle();
    }
    return particles.length == 1 ? particles.single : ExiSequenceParticle(particles);
  }

  ExiElementDeclaration _compileSimpleContent(ExiQName name, XmlElement simpleContent, {required bool nillable}) {
    final derivations = [..._children(simpleContent, 'extension'), ..._children(simpleContent, 'restriction')];
    if (derivations.length != 1) {
      throw const FormatException('XSD simple content must contain one extension or restriction');
    }
    final derivation = derivations.single;
    final base = derivation.getAttribute('base');
    if (base == null) {
      throw const FormatException('XSD simple-content derivation is missing its base type');
    }
    final datatype =
        _resolveSimpleDatatype(derivation, base) ??
        (throw UnsupportedError('Unsupported XSD simple-content base "$base"'));
    for (final child in derivation.children.whereType<XmlElement>()) {
      if (child.name.namespaceUri == _xsdUri &&
          child.name.local != 'annotation' &&
          child.name.local != 'attribute' &&
          child.name.local != 'attributeGroup') {
        throw UnsupportedError('Unsupported XSD simple-content component "${child.name.local}"');
      }
    }
    final attributes = _compileAttributes(derivation);
    return ExiElementDeclaration.simpleContent(
      name,
      datatype,
      attributes: attributes,
      nillable: nillable,
      anyAttribute: _hasAnyAttribute(derivation),
      attributeWildcardNamespaces: _attributeWildcardNamespaces(derivation),
      attributeWildcardExcludedNamespaces: _attributeWildcardExcludedNamespaces(derivation),
      attributeProcessContents: _attributeProcessContents(derivation),
    );
  }

  bool _hasAnyAttribute(XmlElement container) {
    final wildcards = _children(container, 'anyAttribute');
    if (wildcards.length > 1) {
      throw const FormatException('An XSD declaration cannot contain multiple attribute wildcards');
    }
    if (wildcards.isEmpty) {
      return false;
    }
    return true;
  }

  Set<String>? _attributeWildcardNamespaces(XmlElement container) {
    final wildcards = _children(container, 'anyAttribute');
    if (wildcards.isEmpty) {
      return null;
    }
    final namespace = wildcards.single.getAttribute('namespace');
    if (namespace == null || namespace == '##any') {
      return null;
    }
    if (namespace.trim() == '##other') {
      return null;
    }
    final result = <String>{};
    for (final token in namespace.split(RegExp(r'\s+')).where((token) => token.isNotEmpty)) {
      switch (token) {
        case '##local':
          result.add('');
        case '##targetNamespace':
          result.add(targetNamespace);
        case '##other':
          throw const FormatException('##other cannot be combined with other wildcard namespaces');
        default:
          result.add(token);
      }
    }
    return result;
  }

  Set<String>? _attributeWildcardExcludedNamespaces(XmlElement container) {
    final wildcards = _children(container, 'anyAttribute');
    if (wildcards.isEmpty || wildcards.single.getAttribute('namespace')?.trim() != '##other') {
      return null;
    }
    return {'', targetNamespace};
  }

  ExiProcessContents _attributeProcessContents(XmlElement container) {
    final wildcard = _children(container, 'anyAttribute').firstOrNull;
    return switch (wildcard?.getAttribute('processContents')) {
      null || 'strict' => ExiProcessContents.strict,
      'lax' => ExiProcessContents.lax,
      'skip' => ExiProcessContents.skip,
      final value => throw FormatException('Invalid XSD processContents value "$value"'),
    };
  }

  Set<String>? _mergeWildcardNamespaces(bool leftEnabled, Set<String>? left, bool rightEnabled, Set<String>? right) {
    if (!leftEnabled) return right;
    if (!rightEnabled) return left;
    if (left == null || right == null) return null;
    return {...left, ...right};
  }

  ExiParticle _compileParticle(XmlElement particle) {
    switch (particle.name.local) {
      case 'element':
        return _compileElementParticle(particle);
      case 'sequence':
      case 'choice':
        final children = <ExiParticle>[];
        for (final child in particle.children.whereType<XmlElement>()) {
          if (child.name.namespaceUri != _xsdUri || child.name.local == 'annotation') {
            continue;
          }
          if (!const {'element', 'sequence', 'choice', 'all', 'group'}.contains(child.name.local)) {
            throw UnsupportedError('Unsupported XSD particle "${child.name.local}"');
          }
          children.add(_compileParticle(child));
        }
        final compositor = particle.name.local == 'sequence'
            ? ExiSequenceParticle(children)
            : ExiChoiceParticle(children);
        return _applyParticleOccurrences(particle, compositor);
      case 'all':
        final children = <ExiParticle>[];
        for (final child in particle.children.whereType<XmlElement>()) {
          if (child.name.namespaceUri != _xsdUri || child.name.local == 'annotation') {
            continue;
          }
          if (child.name.local != 'element') {
            throw UnsupportedError('An XSD all compositor can contain only element particles');
          }
          final minOccurs = _occurs(child, 'minOccurs', defaultValue: 1);
          final maxOccurs = _occurs(child, 'maxOccurs', defaultValue: 1);
          if (minOccurs > 1 || maxOccurs > 1) {
            throw const FormatException('Children of an XSD all compositor can occur at most once');
          }
          children.add(_compileElementParticle(child));
        }
        final maxOccurs = _occurs(particle, 'maxOccurs', defaultValue: 1);
        if (maxOccurs > 1) {
          throw const FormatException('An XSD all compositor can occur at most once');
        }
        return _applyParticleOccurrences(particle, ExiAllParticle(children));
      case 'group':
        final reference = particle.getAttribute('ref');
        if (reference == null || reference.isEmpty) {
          throw const FormatException('An XSD model-group particle must specify ref');
        }
        final group = _compileModelGroup(_resolveLocalReference(particle, reference, 'model-group'));
        return _applyParticleOccurrences(particle, group);
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

  ExiParticle _applyParticleOccurrences(XmlElement source, ExiParticle particle) {
    final minOccurs = _occurs(source, 'minOccurs', defaultValue: 1);
    final maxValue = source.getAttribute('maxOccurs') ?? '1';
    final maxOccurs = maxValue == 'unbounded'
        ? null
        : int.tryParse(maxValue) ?? (throw FormatException('Invalid XSD maxOccurs value "$maxValue"'));
    if (maxOccurs != null && maxOccurs < minOccurs) {
      throw const FormatException('Invalid XSD particle occurrence range');
    }
    if (minOccurs == 1 && maxOccurs == 1) {
      return particle;
    }
    if (maxOccurs == 0) {
      return const ExiEmptyParticle();
    }
    if (_particleIsNullable(particle)) {
      if (minOccurs == 0 && maxOccurs == 1) {
        return particle;
      }
      throw UnsupportedError('Occurrence constraints on nullable XSD compositors are not supported yet');
    }
    return ExiRepeatedParticle(particle, minOccurs: minOccurs, maxOccurs: maxOccurs);
  }

  bool _particleIsNullable(ExiParticle particle) {
    return switch (particle) {
      ExiEmptyParticle() => true,
      ExiElementParticle(:final minOccurs) => minOccurs == 0,
      ExiSequenceParticle(:final particles) => particles.every(_particleIsNullable),
      ExiChoiceParticle(:final particles) => particles.any(_particleIsNullable),
      ExiAllParticle(:final particles) => particles.every(_particleIsNullable),
      ExiRepeatedParticle(:final particle, :final minOccurs) => minOccurs == 0 || _particleIsNullable(particle),
    };
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
        element.getAttribute('nillable') != null ||
        element.getAttribute('form') != null ||
        _children(element, 'complexType').isNotEmpty ||
        _children(element, 'simpleType').isNotEmpty) {
      throw const FormatException('An XSD element reference cannot declare a name, type, nillability, or form');
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

  List<ExiAttributeDeclaration> _compileAttributes(XmlElement container) {
    final attributes = <ExiAttributeDeclaration>[
      for (final attribute in _children(container, 'attribute')) _compileAttribute(attribute),
    ];
    for (final reference in _children(container, 'attributeGroup')) {
      final name = reference.getAttribute('ref');
      if (name == null || name.isEmpty || reference.getAttribute('name') != null) {
        throw const FormatException('An XSD attribute-group reference must specify only ref');
      }
      attributes.addAll(_compileAttributeGroup(_resolveLocalReference(reference, name, 'attribute-group')));
    }
    attributes.sort(_compareAttributes);
    for (var index = 1; index < attributes.length; index++) {
      if (attributes[index - 1].name == attributes[index].name) {
        throw FormatException('Duplicate XSD attribute "${attributes[index].name.localName}"');
      }
    }
    return attributes;
  }

  List<ExiAttributeDeclaration> _compileAttributeGroup(String localName) {
    final cached = _compiledAttributeGroups[localName];
    if (cached != null) {
      return cached;
    }
    final group = _attributeGroups[localName];
    if (group == null) {
      throw FormatException('Unknown global XSD attribute group "$localName"');
    }
    if (!_compilingAttributeGroups.add(localName)) {
      throw UnsupportedError('Recursive XSD attribute group "$localName" is not supported');
    }
    try {
      for (final child in group.children.whereType<XmlElement>()) {
        if (child.name.namespaceUri == _xsdUri &&
            !const {'annotation', 'attribute', 'attributeGroup'}.contains(child.name.local)) {
          throw UnsupportedError('Unsupported XSD attribute-group component "${child.name.local}"');
        }
      }
      return _compiledAttributeGroups[localName] = List.unmodifiable(_compileAttributes(group));
    } finally {
      _compilingAttributeGroups.remove(localName);
    }
  }

  int _compareAttributes(ExiAttributeDeclaration left, ExiAttributeDeclaration right) {
    final localNameOrder = left.name.localName.compareTo(right.name.localName);
    return localNameOrder != 0 ? localNameOrder : left.name.uri.compareTo(right.name.uri);
  }

  ExiAttributeDeclaration _compileAttribute(XmlElement attribute) {
    final reference = attribute.getAttribute('ref');
    if (reference != null) {
      if (attribute.getAttribute('name') != null ||
          attribute.getAttribute('type') != null ||
          attribute.getAttribute('form') != null ||
          _children(attribute, 'simpleType').isNotEmpty) {
        throw const FormatException('An XSD attribute reference cannot declare a name, type, or form');
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
        ? _resolveSimpleDatatype(attribute, typeName)
        : inlineSimple != null
        ? _compileSimpleType(inlineSimple)
        : ExiDatatype.string;
    if (datatype == null) {
      throw UnsupportedError('Unsupported XSD attribute type "$typeName"');
    }
    return ExiAttributeDeclaration(
      name: ExiQName(
        uri: _isQualifiedForm(attribute, defaultQualified: localAttributesAreQualified, kind: 'attribute')
            ? targetNamespace
            : '',
        localName: localName,
      ),
      datatype: datatype,
      required: _isRequiredAttribute(attribute),
    );
  }

  bool _isQualifiedForm(XmlElement declaration, {required bool defaultQualified, required String kind}) {
    return switch (declaration.getAttribute('form')) {
      null => defaultQualified,
      'qualified' => true,
      'unqualified' => false,
      final value => throw FormatException('Invalid XSD $kind form "$value"'),
    };
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
    if (attribute.getAttribute('ref') != null ||
        attribute.getAttribute('use') != null ||
        attribute.getAttribute('form') != null) {
      throw const FormatException('Global XSD attributes cannot specify ref, use, or form');
    }
    final typeName = attribute.getAttribute('type');
    final inlineSimple = _children(attribute, 'simpleType').firstOrNull;
    final datatype = typeName != null
        ? _resolveSimpleDatatype(attribute, typeName)
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
    final facets = restriction!.children.whereType<XmlElement>().where(
      (child) => child.name.namespaceUri == _xsdUri && child.name.local != 'annotation',
    );
    if (facets.isNotEmpty) {
      throw UnsupportedError('XSD simple-type facets are not supported yet');
    }
    return _resolveSimpleDatatype(restriction, base) ?? (throw UnsupportedError('Unsupported XSD simple type "$base"'));
  }

  ExiDatatype? _resolveSimpleDatatype(XmlElement context, String qualifiedName) {
    final builtin = _builtinDatatype(qualifiedName);
    if (builtin != null) {
      return builtin;
    }
    final localName = _resolveNamedTypeLocalName(context, qualifiedName);
    if (!_simpleTypes.containsKey(localName)) {
      return null;
    }
    return _compileNamedSimpleType(localName);
  }

  String _resolveNamedTypeLocalName(XmlElement context, String qualifiedName) {
    final separator = qualifiedName.indexOf(':');
    if (separator != qualifiedName.lastIndexOf(':')) {
      throw FormatException('Invalid XSD type QName "$qualifiedName"');
    }
    final prefix = separator == -1 ? '' : qualifiedName.substring(0, separator);
    final localName = separator == -1 ? qualifiedName : qualifiedName.substring(separator + 1);
    if (localName.isEmpty || (separator != -1 && prefix.isEmpty)) {
      throw FormatException('Invalid XSD type QName "$qualifiedName"');
    }

    String? namespaceUri;
    for (final namespace in context.namespaces) {
      if (namespace.prefix == prefix) {
        namespaceUri = namespace.uri;
        break;
      }
    }
    if (prefix.isNotEmpty && namespaceUri == null) {
      throw FormatException('Unknown namespace prefix "$prefix" in XSD type QName');
    }
    namespaceUri ??= '';
    if (namespaceUri != targetNamespace) {
      throw UnsupportedError('References to types in external XSD namespaces are not supported yet');
    }
    return localName;
  }

  ExiDatatype _compileNamedSimpleType(String localName) {
    final cached = _compiledSimpleTypes[localName];
    if (cached != null) {
      return cached;
    }
    final simpleType = _simpleTypes[localName];
    if (simpleType == null) {
      throw FormatException('Unknown global XSD simple type "$localName"');
    }
    if (!_compilingSimpleTypes.add(localName)) {
      throw UnsupportedError('Recursive XSD simple type "$localName" is not supported');
    }
    try {
      return _compiledSimpleTypes[localName] = _compileSimpleType(simpleType);
    } finally {
      _compilingSimpleTypes.remove(localName);
    }
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
