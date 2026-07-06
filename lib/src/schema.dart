import 'model.dart';

typedef ExiSchemaResolver = ExiSchema? Function(String schemaId);

enum ExiDatatype {
  string,
  boolean,
  decimal,
  float,
  integer,
  unsignedInteger,
  byte,
  unsignedByte,
  base64Binary,
  hexBinary,
  dateTime,
  date,
  time,
  gYear,
  gYearMonth,
  gMonth,
  gMonthDay,
  gDay,
  list,
}

enum ExiProcessContents { strict, lax, skip }

final class ExiSchema {
  const ExiSchema({
    required this.id,
    required this.globalElements,
    this.globalAttributes = const [],
    this.fragmentElements = const [],
    this.stringTableQNames = const [],
    this.stringTableUris = const {},
  });

  final String id;
  final List<ExiElementDeclaration> globalElements;
  final List<ExiAttributeDeclaration> globalAttributes;
  final List<ExiElementDeclaration> fragmentElements;
  final List<ExiQName> stringTableQNames;
  final Set<String> stringTableUris;
}

final class ExiElementDeclaration {
  const ExiElementDeclaration.empty(
    this.name, {
    this.schemaTypeName,
    this.nillable = false,
    this.typeAlternatives = const {},
    this.anyAttribute = false,
    this.attributeWildcardNamespaces,
    this.attributeWildcardExcludedNamespaces,
    this.attributeProcessContents = ExiProcessContents.strict,
  }) : children = const [],
       datatype = null,
       listItemDatatype = null,
       schemaDatatypeHierarchy = const [],
       listItemSchemaDatatypeHierarchy = const [],
       restrictedCharacters = null,
       listItemRestrictedCharacters = null,
       enumerationValues = const [],
       booleanPattern = false,
       listItemBooleanPattern = false,
       integerMinInclusive = null,
       integerMaxInclusive = null,
       attributes = const [],
       content = null,
       mixed = false;

  const ExiElementDeclaration.sequence(
    this.name,
    this.children, {
    this.schemaTypeName,
    this.nillable = false,
    this.typeAlternatives = const {},
    this.anyAttribute = false,
    this.attributeWildcardNamespaces,
    this.attributeWildcardExcludedNamespaces,
    this.attributeProcessContents = ExiProcessContents.strict,
  }) : datatype = null,
       listItemDatatype = null,
       schemaDatatypeHierarchy = const [],
       listItemSchemaDatatypeHierarchy = const [],
       restrictedCharacters = null,
       listItemRestrictedCharacters = null,
       enumerationValues = const [],
       booleanPattern = false,
       listItemBooleanPattern = false,
       integerMinInclusive = null,
       integerMaxInclusive = null,
       attributes = const [],
       content = null,
       mixed = false;

  const ExiElementDeclaration.value(
    this.name,
    this.datatype, {
    this.schemaTypeName,
    this.listItemDatatype,
    this.schemaDatatypeHierarchy = const [],
    this.listItemSchemaDatatypeHierarchy = const [],
    this.restrictedCharacters,
    this.listItemRestrictedCharacters,
    this.enumerationValues = const [],
    this.booleanPattern = false,
    this.listItemBooleanPattern = false,
    this.integerMinInclusive,
    this.integerMaxInclusive,
    this.nillable = false,
    this.typeAlternatives = const {},
    this.anyAttribute = false,
    this.attributeWildcardNamespaces,
    this.attributeWildcardExcludedNamespaces,
    this.attributeProcessContents = ExiProcessContents.strict,
  }) : assert((datatype == ExiDatatype.list) == (listItemDatatype != null)),
       children = const [],
       attributes = const [],
       content = null,
       mixed = false;

  const ExiElementDeclaration.simpleContent(
    this.name,
    this.datatype, {
    this.schemaTypeName,
    this.listItemDatatype,
    this.schemaDatatypeHierarchy = const [],
    this.listItemSchemaDatatypeHierarchy = const [],
    this.restrictedCharacters,
    this.listItemRestrictedCharacters,
    this.enumerationValues = const [],
    this.booleanPattern = false,
    this.listItemBooleanPattern = false,
    this.integerMinInclusive,
    this.integerMaxInclusive,
    this.attributes = const [],
    this.nillable = false,
    this.typeAlternatives = const {},
    this.anyAttribute = false,
    this.attributeWildcardNamespaces,
    this.attributeWildcardExcludedNamespaces,
    this.attributeProcessContents = ExiProcessContents.strict,
  }) : assert((datatype == ExiDatatype.list) == (listItemDatatype != null)),
       children = const [],
       content = null,
       mixed = false;

  const ExiElementDeclaration.complex(
    this.name, {
    this.schemaTypeName,
    this.attributes = const [],
    this.content,
    this.mixed = false,
    this.nillable = false,
    this.typeAlternatives = const {},
    this.anyAttribute = false,
    this.attributeWildcardNamespaces,
    this.attributeWildcardExcludedNamespaces,
    this.attributeProcessContents = ExiProcessContents.strict,
  }) : children = const [],
       datatype = null,
       listItemDatatype = null,
       schemaDatatypeHierarchy = const [],
       listItemSchemaDatatypeHierarchy = const [],
       restrictedCharacters = null,
       listItemRestrictedCharacters = null,
       enumerationValues = const [],
       booleanPattern = false,
       listItemBooleanPattern = false,
       integerMinInclusive = null,
       integerMaxInclusive = null;

  final ExiQName name;
  final ExiQName? schemaTypeName;
  final List<ExiElementDeclaration> children;
  final ExiDatatype? datatype;
  final ExiDatatype? listItemDatatype;
  final List<ExiQName> schemaDatatypeHierarchy;
  final List<ExiQName> listItemSchemaDatatypeHierarchy;
  final List<int>? restrictedCharacters;
  final List<int>? listItemRestrictedCharacters;
  final List<String> enumerationValues;
  final bool booleanPattern;
  final bool listItemBooleanPattern;
  final BigInt? integerMinInclusive;
  final BigInt? integerMaxInclusive;
  final List<ExiAttributeDeclaration> attributes;
  final ExiParticle? content;
  final bool mixed;
  final bool nillable;
  final Map<ExiQName, ExiElementDeclaration> typeAlternatives;
  final bool anyAttribute;
  final Set<String>? attributeWildcardNamespaces;
  final Set<String>? attributeWildcardExcludedNamespaces;
  final ExiProcessContents attributeProcessContents;
}

final class ExiAttributeDeclaration {
  const ExiAttributeDeclaration({
    required this.name,
    required this.datatype,
    this.listItemDatatype,
    this.schemaDatatypeHierarchy = const [],
    this.listItemSchemaDatatypeHierarchy = const [],
    this.restrictedCharacters,
    this.listItemRestrictedCharacters,
    this.enumerationValues = const [],
    this.booleanPattern = false,
    this.listItemBooleanPattern = false,
    this.integerMinInclusive,
    this.integerMaxInclusive,
    this.required = false,
  }) : assert((datatype == ExiDatatype.list) == (listItemDatatype != null));

  final ExiQName name;
  final ExiDatatype datatype;
  final ExiDatatype? listItemDatatype;
  final List<ExiQName> schemaDatatypeHierarchy;
  final List<ExiQName> listItemSchemaDatatypeHierarchy;
  final List<int>? restrictedCharacters;
  final List<int>? listItemRestrictedCharacters;
  final List<String> enumerationValues;
  final bool booleanPattern;
  final bool listItemBooleanPattern;
  final BigInt? integerMinInclusive;
  final BigInt? integerMaxInclusive;
  final bool required;
}

sealed class ExiParticle {
  const ExiParticle();
}

final class ExiEmptyParticle extends ExiParticle {
  const ExiEmptyParticle();
}

final class ExiElementParticle extends ExiParticle {
  const ExiElementParticle(this.element, {this.minOccurs = 1, this.maxOccurs = 1});

  final ExiElementDeclaration element;
  final int minOccurs;
  final int? maxOccurs;
}

final class ExiWildcardParticle extends ExiParticle {
  const ExiWildcardParticle({
    this.namespaces,
    this.excludedNamespaces,
    this.processContents = ExiProcessContents.strict,
  });

  final Set<String>? namespaces;
  final Set<String>? excludedNamespaces;
  final ExiProcessContents processContents;
}

final class ExiSequenceParticle extends ExiParticle {
  const ExiSequenceParticle(this.particles);

  final List<ExiParticle> particles;
}

final class ExiChoiceParticle extends ExiParticle {
  const ExiChoiceParticle(this.particles);

  final List<ExiParticle> particles;
}

final class ExiAllParticle extends ExiParticle {
  const ExiAllParticle(this.particles);

  final List<ExiParticle> particles;
}

final class ExiRepeatedParticle extends ExiParticle {
  const ExiRepeatedParticle(this.particle, {required this.minOccurs, required this.maxOccurs})
    : assert(minOccurs >= 0),
      assert(maxOccurs == null || maxOccurs >= minOccurs);

  final ExiParticle particle;
  final int minOccurs;
  final int? maxOccurs;
}

final class ExiSchemaNotFoundException implements Exception {
  const ExiSchemaNotFoundException(this.schemaId);

  final String schemaId;

  @override
  String toString() => 'No EXI schema is registered for "$schemaId"';
}
