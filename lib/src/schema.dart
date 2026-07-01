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
}

final class ExiSchema {
  const ExiSchema({required this.id, required this.globalElements});

  final String id;
  final List<ExiElementDeclaration> globalElements;
}

final class ExiElementDeclaration {
  const ExiElementDeclaration.empty(this.name) : children = const [], datatype = null;

  const ExiElementDeclaration.sequence(this.name, this.children) : datatype = null;

  const ExiElementDeclaration.value(this.name, this.datatype) : children = const [];

  final ExiQName name;
  final List<ExiElementDeclaration> children;
  final ExiDatatype? datatype;
}

final class ExiSchemaNotFoundException implements Exception {
  const ExiSchemaNotFoundException(this.schemaId);

  final String schemaId;

  @override
  String toString() => 'No EXI schema is registered for "$schemaId"';
}
