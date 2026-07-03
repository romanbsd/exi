import 'model.dart';
import 'schema.dart';

enum ExiAlignment { bitPacked, byteAligned, preCompression }

enum ExiSchemaIdKind { absent, schemaLess, builtInTypes, named }

final class ExiSchemaId {
  const ExiSchemaId._(this.kind, [this.value]);

  const ExiSchemaId.named(String schemaId) : assert(schemaId != ''), kind = ExiSchemaIdKind.named, value = schemaId;

  static const absent = ExiSchemaId._(ExiSchemaIdKind.absent);
  static const schemaLess = ExiSchemaId._(ExiSchemaIdKind.schemaLess);
  static const builtInTypes = ExiSchemaId._(ExiSchemaIdKind.builtInTypes, '');

  final ExiSchemaIdKind kind;
  final String? value;

  @override
  bool operator ==(Object other) => other is ExiSchemaId && other.kind == kind && other.value == value;

  @override
  int get hashCode => Object.hash(kind, value);
}

final class ExiFidelityOptions {
  const ExiFidelityOptions({
    this.comments = false,
    this.processingInstructions = false,
    this.dtd = false,
    this.prefixes = false,
    this.lexicalValues = false,
  });

  final bool comments;
  final bool processingInstructions;
  final bool dtd;
  final bool prefixes;
  final bool lexicalValues;
}

final class ExiDatatypeRepresentationMap {
  const ExiDatatypeRepresentationMap({required this.schemaDatatype, required this.representation})
    : representationName = null;

  const ExiDatatypeRepresentationMap.userDefined({required this.schemaDatatype, required this.representationName})
    : representation = null;

  final ExiQName schemaDatatype;
  final ExiDatatype? representation;
  final ExiQName? representationName;
}

final class ExiHeaderMetadata {
  const ExiHeaderMetadata({required this.name, required this.events});

  final ExiQName name;
  final List<ExiEvent> events;
}

final class ExiOptions {
  const ExiOptions({
    this.alignment = ExiAlignment.bitPacked,
    this.compression = false,
    this.fragment = false,
    this.strict = false,
    this.selfContained = false,
    this.fidelity = const ExiFidelityOptions(),
    this.blockSize = 1000000,
    this.valueMaxLength,
    this.valuePartitionCapacity,
    this.schemaId = ExiSchemaId.absent,
    this.datatypeRepresentationMap = const [],
    this.metadata = const [],
  });

  final ExiAlignment alignment;
  final bool compression;
  final bool fragment;
  final bool strict;
  final bool selfContained;
  final ExiFidelityOptions fidelity;
  final int blockSize;
  final int? valueMaxLength;
  final int? valuePartitionCapacity;
  final ExiSchemaId schemaId;
  final List<ExiDatatypeRepresentationMap> datatypeRepresentationMap;
  final List<ExiHeaderMetadata> metadata;
}
