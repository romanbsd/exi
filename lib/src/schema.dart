import 'model.dart';

typedef ExiSchemaResolver = ExiSchema? Function(String schemaId);

final class ExiSchema {
  const ExiSchema({required this.id, required this.globalElements});

  final String id;
  final List<ExiElementDeclaration> globalElements;
}

final class ExiElementDeclaration {
  const ExiElementDeclaration.empty(this.name) : children = const [];

  const ExiElementDeclaration.sequence(this.name, this.children);

  final ExiQName name;
  final List<ExiElementDeclaration> children;
}

final class ExiSchemaNotFoundException implements Exception {
  const ExiSchemaNotFoundException(this.schemaId);

  final String schemaId;

  @override
  String toString() => 'No EXI schema is registered for "$schemaId"';
}
