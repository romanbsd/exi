import 'package:xml/xml.dart';

import 'model.dart';
import 'schema.dart';
import 'xsd_pattern.dart';

const _xsdUri = 'http://www.w3.org/2001/XMLSchema';
typedef _SimpleType = ({
  ExiDatatype datatype,
  ExiDatatype? listItemDatatype,
  List<ExiQName> schemaDatatypeHierarchy,
  List<ExiQName> listItemSchemaDatatypeHierarchy,
  List<int>? restrictedCharacters,
  List<int>? listItemRestrictedCharacters,
  List<String> enumerationValues,
  List<String> listItemEnumerationValues,
  bool enumerationEligible,
  bool patternCharsetEligible,
  bool booleanPattern,
  bool listItemBooleanPattern,
  BigInt? integerMinInclusive,
  BigInt? integerMaxInclusive,
  BigInt? listItemIntegerMinInclusive,
  BigInt? listItemIntegerMaxInclusive,
});

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
  final Map<String, _SimpleType> _compiledSimpleTypes = {};
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
    final stringTableQNames = _collectStringTableQNames();
    final globalElements = [for (final name in _globalElementNodes.keys) _compileGlobalElement(name)];
    return ExiSchema(
      id: id,
      globalElements: globalElements,
      globalAttributes: [for (final name in _globalAttributeNodes.keys) _compileGlobalAttribute(name)],
      fragmentElements: _compileFragmentElements(globalElements),
      stringTableQNames: stringTableQNames.toList(),
      stringTableUris: _collectStringTableUris(stringTableQNames),
    );
  }

  List<ExiElementDeclaration> _compileFragmentElements(List<ExiElementDeclaration> globals) {
    final result = [...globals];
    for (final element in root.descendants.whereType<XmlElement>()) {
      if (element.name.namespaceUri != _xsdUri ||
          element.name.local != 'element' ||
          identical(element.parent, root) ||
          element.getAttribute('name') == null) {
        continue;
      }
      result.add(_compileElement(element, global: false));
    }
    return result;
  }

  Set<ExiQName> _collectStringTableQNames() {
    final result = <ExiQName>{};
    for (final declaration in root.descendants.whereType<XmlElement>()) {
      if (declaration.name.namespaceUri != _xsdUri) {
        continue;
      }
      final localName = declaration.getAttribute('name');
      if (localName == null || localName.isEmpty) {
        continue;
      }
      switch (declaration.name.local) {
        case 'element':
          final global = identical(declaration.parent, root);
          final qualified = global
              ? true
              : _isQualifiedForm(declaration, defaultQualified: localElementsAreQualified, kind: 'element');
          result.add(ExiQName(uri: qualified ? targetNamespace : '', localName: localName));
        case 'attribute':
          final global = identical(declaration.parent, root);
          final qualified = global
              ? true
              : _isQualifiedForm(declaration, defaultQualified: localAttributesAreQualified, kind: 'attribute');
          result.add(ExiQName(uri: qualified ? targetNamespace : '', localName: localName));
        case 'complexType':
        case 'simpleType':
          if (identical(declaration.parent, root)) {
            result.add(ExiQName(uri: targetNamespace, localName: localName));
          }
      }
    }
    return result;
  }

  Set<String> _collectStringTableUris(Set<ExiQName> qNames) {
    final result = {for (final name in qNames) name.uri};
    for (final wildcard in root.descendants.whereType<XmlElement>()) {
      if (wildcard.name.namespaceUri != _xsdUri ||
          (wildcard.name.local != 'any' && wildcard.name.local != 'anyAttribute')) {
        continue;
      }
      final namespaces = _wildcardNamespaces(wildcard);
      if (namespaces != null) {
        result.addAll(namespaces);
      }
    }
    result.remove('');
    return result;
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
    _rejectUnsupportedElementSemantics(element);
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
        return ExiElementDeclaration.value(
          name,
          simpleDatatype.datatype,
          schemaTypeName: simpleDatatype.schemaDatatypeHierarchy.firstOrNull,
          listItemDatatype: simpleDatatype.listItemDatatype,
          schemaDatatypeHierarchy: simpleDatatype.schemaDatatypeHierarchy,
          listItemSchemaDatatypeHierarchy: simpleDatatype.listItemSchemaDatatypeHierarchy,
          restrictedCharacters: simpleDatatype.restrictedCharacters,
          listItemRestrictedCharacters: simpleDatatype.listItemRestrictedCharacters,
          enumerationValues: simpleDatatype.enumerationValues,
          listItemEnumerationValues: simpleDatatype.listItemEnumerationValues,
          booleanPattern: simpleDatatype.booleanPattern,
          listItemBooleanPattern: simpleDatatype.listItemBooleanPattern,
          integerMinInclusive: simpleDatatype.integerMinInclusive,
          integerMaxInclusive: simpleDatatype.integerMaxInclusive,
          listItemIntegerMinInclusive: simpleDatatype.listItemIntegerMinInclusive,
          listItemIntegerMaxInclusive: simpleDatatype.listItemIntegerMaxInclusive,
          nillable: nillable,
        );
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
      final simpleType = _compileSimpleType(inlineSimple);
      return ExiElementDeclaration.value(
        name,
        simpleType.datatype,
        listItemDatatype: simpleType.listItemDatatype,
        schemaDatatypeHierarchy: simpleType.schemaDatatypeHierarchy,
        listItemSchemaDatatypeHierarchy: simpleType.listItemSchemaDatatypeHierarchy,
        restrictedCharacters: simpleType.restrictedCharacters,
        listItemRestrictedCharacters: simpleType.listItemRestrictedCharacters,
        enumerationValues: simpleType.enumerationValues,
        listItemEnumerationValues: simpleType.listItemEnumerationValues,
        booleanPattern: simpleType.booleanPattern,
        listItemBooleanPattern: simpleType.listItemBooleanPattern,
        integerMinInclusive: simpleType.integerMinInclusive,
        integerMaxInclusive: simpleType.integerMaxInclusive,
        listItemIntegerMinInclusive: simpleType.listItemIntegerMinInclusive,
        listItemIntegerMaxInclusive: simpleType.listItemIntegerMaxInclusive,
        nillable: nillable,
      );
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
      return _compileComplexType(
        name,
        complexType,
        nillable: nillable,
        schemaTypeName: ExiQName(uri: targetNamespace, localName: typeName),
      );
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
        schemaTypeName: declaration.schemaTypeName,
        listItemDatatype: declaration.listItemDatatype,
        schemaDatatypeHierarchy: declaration.schemaDatatypeHierarchy,
        listItemSchemaDatatypeHierarchy: declaration.listItemSchemaDatatypeHierarchy,
        restrictedCharacters: declaration.restrictedCharacters,
        listItemRestrictedCharacters: declaration.listItemRestrictedCharacters,
        enumerationValues: declaration.enumerationValues,
        listItemEnumerationValues: declaration.listItemEnumerationValues,
        booleanPattern: declaration.booleanPattern,
        listItemBooleanPattern: declaration.listItemBooleanPattern,
        integerMinInclusive: declaration.integerMinInclusive,
        integerMaxInclusive: declaration.integerMaxInclusive,
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
        schemaTypeName: declaration.schemaTypeName,
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
        schemaTypeName: declaration.schemaTypeName,
        nillable: declaration.nillable,
        typeAlternatives: alternatives,
      );
    }
    return ExiElementDeclaration.empty(
      declaration.name,
      schemaTypeName: declaration.schemaTypeName,
      nillable: declaration.nillable,
      typeAlternatives: alternatives,
    );
  }

  ExiElementDeclaration _compileComplexType(
    ExiQName name,
    XmlElement complexType, {
    required bool nillable,
    ExiQName? schemaTypeName,
  }) {
    if (complexType.getAttribute('abstract') == 'true' ||
        complexType.getAttribute('abstract') == '1' ||
        complexType.getAttribute('block') != null ||
        complexType.getAttribute('final') != null) {
      throw UnsupportedError('Abstract, blocked, or final XSD complex types are not supported yet');
    }
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
      return _compileSimpleContent(name, simpleContent, nillable: nillable, schemaTypeName: schemaTypeName);
    }
    if (complexContent != null) {
      return _compileComplexContent(
        name,
        complexContent,
        mixed: mixed,
        nillable: nillable,
        schemaTypeName: schemaTypeName,
      );
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
          schemaTypeName: schemaTypeName,
          attributes: attributes,
          mixed: mixed,
          nillable: nillable,
          anyAttribute: anyAttribute,
          attributeWildcardNamespaces: attributeWildcardNamespaces,
          attributeWildcardExcludedNamespaces: attributeWildcardExcludedNamespaces,
          attributeProcessContents: _attributeProcessContents(complexType),
        );
      }
      return ExiElementDeclaration.empty(name, schemaTypeName: schemaTypeName, nillable: nillable);
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
      return ExiElementDeclaration.sequence(
        name,
        [for (final particle in particles.cast<ExiElementParticle>()) particle.element],
        schemaTypeName: schemaTypeName,
        nillable: nillable,
      );
    }
    return ExiElementDeclaration.complex(
      name,
      schemaTypeName: schemaTypeName,
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
    ExiQName? schemaTypeName,
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
      schemaTypeName: schemaTypeName,
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

  ExiElementDeclaration _compileSimpleContent(
    ExiQName name,
    XmlElement simpleContent, {
    required bool nillable,
    ExiQName? schemaTypeName,
  }) {
    final derivations = [..._children(simpleContent, 'extension'), ..._children(simpleContent, 'restriction')];
    if (derivations.length != 1) {
      throw const FormatException('XSD simple content must contain one extension or restriction');
    }
    final derivation = derivations.single;
    final base = derivation.getAttribute('base');
    if (base == null) {
      throw const FormatException('XSD simple-content derivation is missing its base type');
    }
    final simpleType =
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
      simpleType.datatype,
      schemaTypeName: schemaTypeName,
      listItemDatatype: simpleType.listItemDatatype,
      schemaDatatypeHierarchy: simpleType.schemaDatatypeHierarchy,
      listItemSchemaDatatypeHierarchy: simpleType.listItemSchemaDatatypeHierarchy,
      restrictedCharacters: simpleType.restrictedCharacters,
      listItemRestrictedCharacters: simpleType.listItemRestrictedCharacters,
      enumerationValues: simpleType.enumerationValues,
      listItemEnumerationValues: simpleType.listItemEnumerationValues,
      booleanPattern: simpleType.booleanPattern,
      listItemBooleanPattern: simpleType.listItemBooleanPattern,
      integerMinInclusive: simpleType.integerMinInclusive,
      integerMaxInclusive: simpleType.integerMaxInclusive,
      listItemIntegerMinInclusive: simpleType.listItemIntegerMinInclusive,
      listItemIntegerMaxInclusive: simpleType.listItemIntegerMaxInclusive,
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
    return _wildcardNamespaces(wildcards.single);
  }

  Set<String>? _wildcardNamespaces(XmlElement wildcard) {
    final namespace = wildcard.getAttribute('namespace')?.trim();
    if (namespace == null || namespace == '##any') {
      return null;
    }
    if (namespace == '##other') {
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
    if (wildcards.isEmpty) {
      return null;
    }
    return _wildcardExcludedNamespaces(wildcards.single);
  }

  Set<String>? _wildcardExcludedNamespaces(XmlElement wildcard) {
    return wildcard.getAttribute('namespace')?.trim() == '##other' ? {'', targetNamespace} : null;
  }

  ExiProcessContents _attributeProcessContents(XmlElement container) {
    final wildcard = _children(container, 'anyAttribute').firstOrNull;
    return wildcard == null ? ExiProcessContents.strict : _wildcardProcessContents(wildcard);
  }

  ExiProcessContents _wildcardProcessContents(XmlElement wildcard) {
    return switch (wildcard.getAttribute('processContents')) {
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
      case 'any':
        return _compileWildcardParticle(particle);
      case 'sequence':
      case 'choice':
        final children = <ExiParticle>[];
        for (final child in particle.children.whereType<XmlElement>()) {
          if (child.name.namespaceUri != _xsdUri || child.name.local == 'annotation') {
            continue;
          }
          if (!const {'element', 'any', 'sequence', 'choice', 'all', 'group'}.contains(child.name.local)) {
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
    return ExiRepeatedParticle(particle, minOccurs: minOccurs, maxOccurs: maxOccurs);
  }

  ExiParticle _compileWildcardParticle(XmlElement wildcard) {
    if (wildcard.getAttribute('notNamespace') != null || wildcard.getAttribute('notQName') != null) {
      throw UnsupportedError('XSD 1.1 wildcard exclusions are not supported yet');
    }
    for (final child in wildcard.children.whereType<XmlElement>()) {
      if (child.name.namespaceUri == _xsdUri && child.name.local != 'annotation') {
        throw UnsupportedError('Unsupported XSD element-wildcard component "${child.name.local}"');
      }
    }
    return _applyParticleOccurrences(
      wildcard,
      ExiWildcardParticle(
        namespaces: _wildcardNamespaces(wildcard),
        excludedNamespaces: _wildcardExcludedNamespaces(wildcard),
        processContents: _wildcardProcessContents(wildcard),
      ),
    );
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
    _rejectUnsupportedElementSemantics(element);
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
    _rejectUnsupportedAttributeSemantics(attribute);
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
        listItemDatatype: declaration.listItemDatatype,
        schemaDatatypeHierarchy: declaration.schemaDatatypeHierarchy,
        listItemSchemaDatatypeHierarchy: declaration.listItemSchemaDatatypeHierarchy,
        restrictedCharacters: declaration.restrictedCharacters,
        listItemRestrictedCharacters: declaration.listItemRestrictedCharacters,
        enumerationValues: declaration.enumerationValues,
        listItemEnumerationValues: declaration.listItemEnumerationValues,
        booleanPattern: declaration.booleanPattern,
        listItemBooleanPattern: declaration.listItemBooleanPattern,
        integerMinInclusive: declaration.integerMinInclusive,
        integerMaxInclusive: declaration.integerMaxInclusive,
        listItemIntegerMinInclusive: declaration.listItemIntegerMinInclusive,
        listItemIntegerMaxInclusive: declaration.listItemIntegerMaxInclusive,
        required: _isRequiredAttribute(attribute),
      );
    }
    final localName = attribute.getAttribute('name');
    if (localName == null || localName.isEmpty) {
      throw const FormatException('XSD attribute declaration is missing a name');
    }
    final typeName = attribute.getAttribute('type');
    final inlineSimple = _children(attribute, 'simpleType').firstOrNull;
    final simpleType = typeName != null
        ? _resolveSimpleDatatype(attribute, typeName)
        : inlineSimple != null
        ? _compileSimpleType(inlineSimple)
        : _scalarType(ExiDatatype.string, patternCharsetEligible: true);
    if (simpleType == null) {
      throw UnsupportedError('Unsupported XSD attribute type "$typeName"');
    }
    return ExiAttributeDeclaration(
      name: ExiQName(
        uri: _isQualifiedForm(attribute, defaultQualified: localAttributesAreQualified, kind: 'attribute')
            ? targetNamespace
            : '',
        localName: localName,
      ),
      datatype: simpleType.datatype,
      listItemDatatype: simpleType.listItemDatatype,
      schemaDatatypeHierarchy: simpleType.schemaDatatypeHierarchy,
      listItemSchemaDatatypeHierarchy: simpleType.listItemSchemaDatatypeHierarchy,
      restrictedCharacters: simpleType.restrictedCharacters,
      listItemRestrictedCharacters: simpleType.listItemRestrictedCharacters,
      enumerationValues: simpleType.enumerationValues,
      listItemEnumerationValues: simpleType.listItemEnumerationValues,
      booleanPattern: simpleType.booleanPattern,
      listItemBooleanPattern: simpleType.listItemBooleanPattern,
      integerMinInclusive: simpleType.integerMinInclusive,
      integerMaxInclusive: simpleType.integerMaxInclusive,
      listItemIntegerMinInclusive: simpleType.listItemIntegerMinInclusive,
      listItemIntegerMaxInclusive: simpleType.listItemIntegerMaxInclusive,
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
    _rejectUnsupportedAttributeSemantics(attribute);
    if (attribute.getAttribute('ref') != null ||
        attribute.getAttribute('use') != null ||
        attribute.getAttribute('form') != null) {
      throw const FormatException('Global XSD attributes cannot specify ref, use, or form');
    }
    final typeName = attribute.getAttribute('type');
    final inlineSimple = _children(attribute, 'simpleType').firstOrNull;
    final simpleType = typeName != null
        ? _resolveSimpleDatatype(attribute, typeName)
        : inlineSimple != null
        ? _compileSimpleType(inlineSimple)
        : _scalarType(ExiDatatype.string, patternCharsetEligible: true);
    if (simpleType == null) {
      throw UnsupportedError('Unsupported XSD attribute type "$typeName"');
    }
    return _compiledGlobalAttributes[localName] = ExiAttributeDeclaration(
      name: ExiQName(uri: targetNamespace, localName: localName),
      datatype: simpleType.datatype,
      listItemDatatype: simpleType.listItemDatatype,
      schemaDatatypeHierarchy: simpleType.schemaDatatypeHierarchy,
      listItemSchemaDatatypeHierarchy: simpleType.listItemSchemaDatatypeHierarchy,
      restrictedCharacters: simpleType.restrictedCharacters,
      listItemRestrictedCharacters: simpleType.listItemRestrictedCharacters,
      enumerationValues: simpleType.enumerationValues,
      listItemEnumerationValues: simpleType.listItemEnumerationValues,
      booleanPattern: simpleType.booleanPattern,
      listItemBooleanPattern: simpleType.listItemBooleanPattern,
      integerMinInclusive: simpleType.integerMinInclusive,
      integerMaxInclusive: simpleType.integerMaxInclusive,
      listItemIntegerMinInclusive: simpleType.listItemIntegerMinInclusive,
      listItemIntegerMaxInclusive: simpleType.listItemIntegerMaxInclusive,
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

  void _rejectUnsupportedElementSemantics(XmlElement element) {
    if (element.getAttribute('default') != null ||
        element.getAttribute('fixed') != null ||
        element.getAttribute('substitutionGroup') != null ||
        element.getAttribute('block') != null ||
        element.getAttribute('final') != null ||
        element.getAttribute('abstract') == 'true' ||
        element.getAttribute('abstract') == '1') {
      throw UnsupportedError(
        'XSD element defaults, fixed values, substitution groups, abstractness, and derivation controls '
        'are not supported yet',
      );
    }
  }

  void _rejectUnsupportedAttributeSemantics(XmlElement attribute) {
    if (attribute.getAttribute('default') != null || attribute.getAttribute('fixed') != null) {
      throw UnsupportedError('XSD attribute default and fixed values are not supported yet');
    }
  }

  _SimpleType _compileSimpleType(XmlElement simpleType) {
    final restrictions = _children(simpleType, 'restriction');
    final lists = _children(simpleType, 'list');
    final unions = _children(simpleType, 'union');
    if (restrictions.length + lists.length + unions.length != 1) {
      throw const FormatException('An XSD simple type must contain exactly one restriction, list, or union');
    }
    final restriction = restrictions.firstOrNull;
    final list = lists.firstOrNull;
    final union = unions.firstOrNull;

    if (union != null) {
      final memberTypes = (union.getAttribute('memberTypes') ?? '')
          .split(RegExp(r'\s+'))
          .where((value) => value.isNotEmpty)
          .toList();
      final inlineTypes = _children(union, 'simpleType');
      if (memberTypes.isEmpty && inlineTypes.isEmpty) {
        throw const FormatException('An XSD union must contain at least one member type');
      }
      for (final child in union.children.whereType<XmlElement>()) {
        if (child.name.namespaceUri == _xsdUri &&
            child.name.local != 'annotation' &&
            child.name.local != 'simpleType') {
          throw UnsupportedError('Unsupported XSD union component "${child.name.local}"');
        }
      }
      for (final memberType in memberTypes) {
        if (_resolveSimpleDatatype(union, memberType) == null) {
          throw UnsupportedError('Unsupported XSD union member type "$memberType"');
        }
      }
      for (final inlineType in inlineTypes) {
        _compileSimpleType(inlineType);
      }
      return _scalarType(ExiDatatype.string, enumerationEligible: false);
    }

    if (list != null) {
      final itemTypeName = list.getAttribute('itemType');
      final inlineTypes = _children(list, 'simpleType');
      if ((itemTypeName == null && inlineTypes.isEmpty) ||
          (itemTypeName != null && inlineTypes.isNotEmpty) ||
          inlineTypes.length > 1) {
        throw const FormatException('An XSD list must contain exactly one itemType or inline simpleType');
      }
      for (final child in list.children.whereType<XmlElement>()) {
        if (child.name.namespaceUri == _xsdUri &&
            child.name.local != 'annotation' &&
            child.name.local != 'simpleType') {
          throw UnsupportedError('Unsupported XSD list component "${child.name.local}"');
        }
      }
      final itemType = itemTypeName != null
          ? _resolveSimpleDatatype(list, itemTypeName)
          : _compileSimpleType(inlineTypes.single);
      if (itemType == null) {
        throw UnsupportedError('Unsupported XSD list item type "$itemTypeName"');
      }
      if (itemType.datatype == ExiDatatype.list) {
        throw UnsupportedError('Nested XSD list datatypes are not supported');
      }
      return (
        datatype: ExiDatatype.list,
        listItemDatatype: itemType.datatype,
        schemaDatatypeHierarchy: const [],
        listItemSchemaDatatypeHierarchy: itemType.schemaDatatypeHierarchy,
        restrictedCharacters: null,
        listItemRestrictedCharacters: itemType.restrictedCharacters,
        enumerationValues: const [],
        listItemEnumerationValues: itemType.enumerationValues,
        enumerationEligible: false,
        patternCharsetEligible: false,
        booleanPattern: false,
        listItemBooleanPattern: itemType.booleanPattern,
        integerMinInclusive: null,
        integerMaxInclusive: null,
        listItemIntegerMinInclusive: itemType.integerMinInclusive,
        listItemIntegerMaxInclusive: itemType.integerMaxInclusive,
      );
    }

    final base = restriction?.getAttribute('base');
    if (base == null) {
      throw UnsupportedError('Only XSD simple-type restrictions are supported');
    }
    final baseType =
        _resolveSimpleDatatype(restriction!, base) ?? (throw UnsupportedError('Unsupported XSD simple type "$base"'));
    final facets = restriction.children
        .whereType<XmlElement>()
        .where((child) => child.name.namespaceUri == _xsdUri && child.name.local != 'annotation')
        .toList();
    const supportedFacets = {
      'enumeration',
      'minInclusive',
      'minExclusive',
      'maxInclusive',
      'maxExclusive',
      'pattern',
      'length',
      'minLength',
      'maxLength',
      'whiteSpace',
      'totalDigits',
      'fractionDigits',
    };
    final unsupported = facets.where((facet) => !supportedFacets.contains(facet.name.local)).firstOrNull;
    if (unsupported != null) {
      throw UnsupportedError('Unsupported XSD simple-type facet "${unsupported.name.local}"');
    }
    final values = <String>[
      for (final facet in facets.where((facet) => facet.name.local == 'enumeration'))
        facet.getAttribute('value') ?? (throw const FormatException('An XSD enumeration facet must specify a value')),
    ];
    final patterns = facets.where((facet) => facet.name.local == 'pattern').toList();
    final patternValues = <String>[];
    for (final pattern in patterns) {
      patternValues.add(
        pattern.getAttribute('value') ?? (throw const FormatException('An XSD pattern facet must specify a value')),
      );
    }
    for (final facet in facets.where(
      (facet) =>
          facet.name.local == 'length' ||
          facet.name.local == 'minLength' ||
          facet.name.local == 'maxLength' ||
          facet.name.local == 'whiteSpace' ||
          facet.name.local == 'totalDigits' ||
          facet.name.local == 'fractionDigits',
    )) {
      final lexical = facet.getAttribute('value');
      if (lexical == null) {
        throw FormatException('An XSD ${facet.name.local} facet must specify a value');
      }
      if (facet.name.local == 'whiteSpace') {
        if (lexical != 'preserve' && lexical != 'replace' && lexical != 'collapse') {
          throw FormatException('Invalid XSD whiteSpace facet "$lexical"');
        }
      } else {
        final parsed = int.tryParse(lexical.trim());
        final minimum = facet.name.local == 'totalDigits' ? 1 : 0;
        if (parsed == null || parsed < minimum) {
          throw FormatException('Invalid XSD ${facet.name.local} facet "$lexical"');
        }
      }
    }
    var minimum = baseType.integerMinInclusive;
    var maximum = baseType.integerMaxInclusive;
    final boundFacets = facets
        .where(
          (facet) =>
              facet.name.local == 'minInclusive' ||
              facet.name.local == 'minExclusive' ||
              facet.name.local == 'maxInclusive' ||
              facet.name.local == 'maxExclusive',
        )
        .toList();
    final integerDatatype =
        baseType.datatype == ExiDatatype.integer ||
        baseType.datatype == ExiDatatype.unsignedInteger ||
        baseType.datatype == ExiDatatype.byte ||
        baseType.datatype == ExiDatatype.unsignedByte;
    if (integerDatatype) {
      final seenBounds = <String>{};
      for (final facet in boundFacets) {
        if (!seenBounds.add(facet.name.local)) {
          throw FormatException('Duplicate XSD ${facet.name.local} facet');
        }
        final lexical =
            facet.getAttribute('value') ??
            (throw FormatException('An XSD ${facet.name.local} facet must specify a value'));
        final parsed = BigInt.tryParse(lexical.trim());
        if (parsed == null) {
          throw FormatException('Invalid XSD integer bound "$lexical"');
        }
        switch (facet.name.local) {
          case 'minInclusive':
            minimum = minimum == null || parsed > minimum ? parsed : minimum;
          case 'minExclusive':
            final inclusive = parsed + BigInt.one;
            minimum = minimum == null || inclusive > minimum ? inclusive : minimum;
          case 'maxInclusive':
            maximum = maximum == null || parsed < maximum ? parsed : maximum;
          case 'maxExclusive':
            final inclusive = parsed - BigInt.one;
            maximum = maximum == null || inclusive < maximum ? inclusive : maximum;
        }
      }
    } else {
      for (final facet in boundFacets) {
        if (facet.getAttribute('value') == null) {
          throw FormatException('An XSD ${facet.name.local} facet must specify a value');
        }
      }
    }
    if (minimum != null && maximum != null && maximum < minimum) {
      throw const FormatException('XSD integer restriction has an empty value range');
    }
    return (
      datatype: baseType.datatype,
      listItemDatatype: baseType.listItemDatatype,
      schemaDatatypeHierarchy: baseType.schemaDatatypeHierarchy,
      listItemSchemaDatatypeHierarchy: baseType.listItemSchemaDatatypeHierarchy,
      restrictedCharacters: patternValues.isNotEmpty && baseType.patternCharsetEligible
          ? deriveXsdPatternCharacters(patternValues)
          : patternValues.isEmpty
          ? baseType.restrictedCharacters
          : null,
      listItemRestrictedCharacters: baseType.listItemRestrictedCharacters,
      enumerationValues: values.isNotEmpty && baseType.enumerationEligible
          ? List.unmodifiable(values)
          : baseType.enumerationValues,
      listItemEnumerationValues: baseType.listItemEnumerationValues,
      enumerationEligible: baseType.enumerationEligible,
      patternCharsetEligible: baseType.patternCharsetEligible,
      booleanPattern: baseType.booleanPattern || (baseType.datatype == ExiDatatype.boolean && patterns.isNotEmpty),
      listItemBooleanPattern: baseType.listItemBooleanPattern,
      integerMinInclusive: minimum,
      integerMaxInclusive: maximum,
      listItemIntegerMinInclusive: baseType.listItemIntegerMinInclusive,
      listItemIntegerMaxInclusive: baseType.listItemIntegerMaxInclusive,
    );
  }

  _SimpleType? _resolveSimpleDatatype(XmlElement context, String qualifiedName) {
    final builtin = _builtinSimpleType(qualifiedName);
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

  _SimpleType _compileNamedSimpleType(String localName) {
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
      final compiled = _compileSimpleType(simpleType);
      return _compiledSimpleTypes[localName] = _withSchemaDatatype(
        compiled,
        ExiQName(uri: targetNamespace, localName: localName),
      );
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

  _SimpleType? _builtinSimpleType(String qualifiedName) {
    final separator = qualifiedName.indexOf(':');
    final prefix = separator == -1 ? '' : qualifiedName.substring(0, separator);
    if (!root.namespaces.any((namespace) => namespace.prefix == prefix && namespace.uri == _xsdUri)) {
      return null;
    }
    final localName = _localPart(qualifiedName);
    final _SimpleType? simpleType = switch (localName) {
      'string' ||
      'normalizedString' ||
      'token' ||
      'language' ||
      'Name' ||
      'NCName' ||
      'NMTOKEN' ||
      'ID' ||
      'IDREF' ||
      'ENTITY' => _scalarType(ExiDatatype.string, patternCharsetEligible: true),
      'anySimpleType' || 'anyURI' => _scalarType(ExiDatatype.string),
      'NMTOKENS' || 'IDREFS' || 'ENTITIES' => (
        datatype: ExiDatatype.list,
        listItemDatatype: ExiDatatype.string,
        schemaDatatypeHierarchy: const [],
        listItemSchemaDatatypeHierarchy: _builtinDatatypeHierarchy(switch (localName) {
          'NMTOKENS' => 'NMTOKEN',
          'IDREFS' => 'IDREF',
          _ => 'ENTITY',
        }),
        restrictedCharacters: null,
        listItemRestrictedCharacters: null,
        enumerationValues: const [],
        listItemEnumerationValues: const [],
        enumerationEligible: false,
        patternCharsetEligible: false,
        booleanPattern: false,
        listItemBooleanPattern: false,
        integerMinInclusive: null,
        integerMaxInclusive: null,
        listItemIntegerMinInclusive: null,
        listItemIntegerMaxInclusive: null,
      ),
      'boolean' => _scalarType(ExiDatatype.boolean),
      'decimal' => _scalarType(ExiDatatype.decimal),
      'float' || 'double' => _scalarType(ExiDatatype.float),
      'integer' => _scalarType(ExiDatatype.integer),
      'long' => _scalarType(
        ExiDatatype.integer,
        integerMinInclusive: -(BigInt.one << 63),
        integerMaxInclusive: (BigInt.one << 63) - BigInt.one,
      ),
      'int' => _scalarType(
        ExiDatatype.integer,
        integerMinInclusive: -(BigInt.one << 31),
        integerMaxInclusive: (BigInt.one << 31) - BigInt.one,
      ),
      'short' => _scalarType(
        ExiDatatype.integer,
        integerMinInclusive: -(BigInt.one << 15),
        integerMaxInclusive: (BigInt.one << 15) - BigInt.one,
      ),
      'negativeInteger' => _scalarType(ExiDatatype.integer, integerMaxInclusive: -BigInt.one),
      'nonPositiveInteger' => _scalarType(ExiDatatype.integer, integerMaxInclusive: BigInt.zero),
      'byte' => _scalarType(
        ExiDatatype.byte,
        integerMinInclusive: BigInt.from(-128),
        integerMaxInclusive: BigInt.from(127),
      ),
      'nonNegativeInteger' => _scalarType(ExiDatatype.unsignedInteger, integerMinInclusive: BigInt.zero),
      'positiveInteger' => _scalarType(ExiDatatype.unsignedInteger, integerMinInclusive: BigInt.one),
      'unsignedLong' => _scalarType(
        ExiDatatype.unsignedInteger,
        integerMinInclusive: BigInt.zero,
        integerMaxInclusive: (BigInt.one << 64) - BigInt.one,
      ),
      'unsignedInt' => _scalarType(
        ExiDatatype.unsignedInteger,
        integerMinInclusive: BigInt.zero,
        integerMaxInclusive: (BigInt.one << 32) - BigInt.one,
      ),
      'unsignedShort' => _scalarType(
        ExiDatatype.unsignedInteger,
        integerMinInclusive: BigInt.zero,
        integerMaxInclusive: BigInt.from(65535),
      ),
      'unsignedByte' => _scalarType(
        ExiDatatype.unsignedByte,
        integerMinInclusive: BigInt.zero,
        integerMaxInclusive: BigInt.from(255),
      ),
      'base64Binary' => _scalarType(ExiDatatype.base64Binary),
      'hexBinary' => _scalarType(ExiDatatype.hexBinary),
      'dateTime' => _scalarType(ExiDatatype.dateTime),
      'date' => _scalarType(ExiDatatype.date),
      'time' => _scalarType(ExiDatatype.time),
      'gYear' => _scalarType(ExiDatatype.gYear),
      'gYearMonth' => _scalarType(ExiDatatype.gYearMonth),
      'gMonth' => _scalarType(ExiDatatype.gMonth),
      'gMonthDay' => _scalarType(ExiDatatype.gMonthDay),
      'gDay' => _scalarType(ExiDatatype.gDay),
      'duration' => _scalarType(ExiDatatype.string),
      'QName' || 'NOTATION' => _scalarType(ExiDatatype.string, enumerationEligible: false),
      _ => null,
    };
    return simpleType == null ? null : _withSchemaDatatypeHierarchy(simpleType, _builtinDatatypeHierarchy(localName));
  }
}

_SimpleType _scalarType(
  ExiDatatype datatype, {
  bool enumerationEligible = true,
  bool patternCharsetEligible = false,
  BigInt? integerMinInclusive,
  BigInt? integerMaxInclusive,
}) => (
  datatype: datatype,
  listItemDatatype: null,
  schemaDatatypeHierarchy: const [],
  listItemSchemaDatatypeHierarchy: const [],
  restrictedCharacters: null,
  listItemRestrictedCharacters: null,
  enumerationValues: const [],
  listItemEnumerationValues: const [],
  enumerationEligible: enumerationEligible,
  patternCharsetEligible: patternCharsetEligible,
  booleanPattern: false,
  listItemBooleanPattern: false,
  integerMinInclusive: integerMinInclusive,
  integerMaxInclusive: integerMaxInclusive,
  listItemIntegerMinInclusive: null,
  listItemIntegerMaxInclusive: null,
);

_SimpleType _withSchemaDatatype(_SimpleType type, ExiQName datatype) =>
    _withSchemaDatatypeHierarchy(type, [datatype, ...type.schemaDatatypeHierarchy]);

_SimpleType _withSchemaDatatypeHierarchy(_SimpleType type, List<ExiQName> hierarchy) => (
  datatype: type.datatype,
  listItemDatatype: type.listItemDatatype,
  schemaDatatypeHierarchy: List.unmodifiable(hierarchy),
  listItemSchemaDatatypeHierarchy: type.listItemSchemaDatatypeHierarchy,
  restrictedCharacters: type.restrictedCharacters,
  listItemRestrictedCharacters: type.listItemRestrictedCharacters,
  enumerationValues: type.enumerationValues,
  listItemEnumerationValues: type.listItemEnumerationValues,
  enumerationEligible: type.enumerationEligible,
  patternCharsetEligible: type.patternCharsetEligible,
  booleanPattern: type.booleanPattern,
  listItemBooleanPattern: type.listItemBooleanPattern,
  integerMinInclusive: type.integerMinInclusive,
  integerMaxInclusive: type.integerMaxInclusive,
  listItemIntegerMinInclusive: type.listItemIntegerMinInclusive,
  listItemIntegerMaxInclusive: type.listItemIntegerMaxInclusive,
);

List<ExiQName> _builtinDatatypeHierarchy(String localName) {
  final hierarchy = <ExiQName>[];
  final boundary = _defaultRepresentationAncestor(localName);
  String? current = localName;
  while (current != null) {
    hierarchy.add(ExiQName(uri: _xsdUri, localName: current));
    if (current == boundary) {
      break;
    }
    current = _builtinDatatypeParent(current);
  }
  return hierarchy;
}

String _defaultRepresentationAncestor(String localName) {
  if (const {
    'normalizedString',
    'token',
    'language',
    'Name',
    'NCName',
    'NMTOKEN',
    'ID',
    'IDREF',
    'ENTITY',
  }.contains(localName)) {
    return 'string';
  }
  if (const {
    'nonPositiveInteger',
    'negativeInteger',
    'long',
    'int',
    'short',
    'byte',
    'nonNegativeInteger',
    'unsignedLong',
    'unsignedInt',
    'unsignedShort',
    'unsignedByte',
    'positiveInteger',
  }.contains(localName)) {
    return 'integer';
  }
  if (const {'duration', 'anyURI', 'QName', 'NOTATION'}.contains(localName)) {
    return 'anySimpleType';
  }
  return localName;
}

String? _builtinDatatypeParent(String localName) => switch (localName) {
  'normalizedString' => 'string',
  'token' => 'normalizedString',
  'language' || 'Name' || 'NMTOKEN' => 'token',
  'NCName' => 'Name',
  'ID' || 'IDREF' || 'ENTITY' => 'NCName',
  'nonPositiveInteger' || 'long' || 'nonNegativeInteger' => 'integer',
  'negativeInteger' => 'nonPositiveInteger',
  'int' => 'long',
  'short' => 'int',
  'byte' => 'short',
  'unsignedLong' || 'positiveInteger' => 'nonNegativeInteger',
  'unsignedInt' => 'unsignedLong',
  'unsignedShort' => 'unsignedInt',
  'unsignedByte' => 'unsignedShort',
  'integer' => 'decimal',
  'string' ||
  'boolean' ||
  'decimal' ||
  'float' ||
  'double' ||
  'duration' ||
  'dateTime' ||
  'time' ||
  'date' ||
  'gYearMonth' ||
  'gYear' ||
  'gMonthDay' ||
  'gDay' ||
  'gMonth' ||
  'hexBinary' ||
  'base64Binary' ||
  'anyURI' ||
  'QName' ||
  'NOTATION' ||
  'NMTOKENS' ||
  'IDREFS' ||
  'ENTITIES' => 'anySimpleType',
  'anySimpleType' => null,
  _ => null,
};

Iterable<XmlElement> _children(XmlElement parent, String localName) => parent.children.whereType<XmlElement>().where(
  (element) => element.name.local == localName && element.name.namespaceUri == _xsdUri,
);

String _localPart(String qualifiedName) {
  final separator = qualifiedName.indexOf(':');
  return separator == -1 ? qualifiedName : qualifiedName.substring(separator + 1);
}
