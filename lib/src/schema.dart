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
  const ExiElementDeclaration.empty(this.name)
    : children = const [],
      datatype = null,
      attributes = const [],
      content = null;

  const ExiElementDeclaration.sequence(this.name, this.children)
    : datatype = null,
      attributes = const [],
      content = null;

  const ExiElementDeclaration.value(this.name, this.datatype)
    : children = const [],
      attributes = const [],
      content = null;

  const ExiElementDeclaration.complex(this.name, {this.attributes = const [], this.content})
    : children = const [],
      datatype = null;

  final ExiQName name;
  final List<ExiElementDeclaration> children;
  final ExiDatatype? datatype;
  final List<ExiAttributeDeclaration> attributes;
  final ExiParticle? content;
}

final class ExiAttributeDeclaration {
  const ExiAttributeDeclaration({required this.name, required this.datatype, this.required = false});

  final ExiQName name;
  final ExiDatatype datatype;
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

final class ExiSequenceParticle extends ExiParticle {
  const ExiSequenceParticle(this.particles);

  final List<ExiParticle> particles;
}

final class ExiChoiceParticle extends ExiParticle {
  const ExiChoiceParticle(this.particles);

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
