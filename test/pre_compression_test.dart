import 'dart:typed_data';

import 'package:exi/exi.dart';
import 'package:test/test.dart';

void main() {
  test('decodes a single final pre-compression block', () {
    const schemaId = 'pre-compression-values';
    const schema = ExiSchema(
      id: schemaId,
      globalElements: [
        ExiElementDeclaration.sequence(ExiQName(localName: 'root'), [
          ExiElementDeclaration.value(ExiQName(localName: 'text'), ExiDatatype.string),
          ExiElementDeclaration.value(ExiQName(localName: 'count'), ExiDatatype.integer),
        ]),
      ],
    );

    final document =
        ExiDecoder(
          options: const ExiOptions(
            alignment: ExiAlignment.preCompression,
            strict: true,
            schemaId: ExiSchemaId.named(schemaId),
          ),
          schemaResolver: (_) => schema,
        ).decode(
          Uint8List.fromList([
            // Header.
            0x80,
            // Structure channel: schema root selection. Remaining events are fixed.
            0x00,
            // {text} value channel: literal "x".
            0x03, 0x78,
            // {count} value channel: positive integer 7.
            0x00, 0x07,
          ]),
        );

    expect(document.toXmlString(), '<root><text>x</text><count>7</count></root>');
  });

  test('demultiplexes value channels in first-occurrence order', () {
    const schemaId = 'pre-compression-channels';
    const first = ExiElementDeclaration.value(ExiQName(localName: 'first'), ExiDatatype.string);
    const second = ExiElementDeclaration.value(ExiQName(localName: 'second'), ExiDatatype.string);
    const schema = ExiSchema(
      id: schemaId,
      globalElements: [
        ExiElementDeclaration.sequence(ExiQName(localName: 'root'), [first, second, first]),
      ],
    );

    final document =
        ExiDecoder(
          options: const ExiOptions(
            alignment: ExiAlignment.preCompression,
            strict: true,
            schemaId: ExiSchemaId.named(schemaId),
          ),
          schemaResolver: (_) => schema,
        ).decode(
          Uint8List.fromList([
            0x80,
            // Structure channel: schema root selection.
            0x00,
            // {first} channel contains its two non-contiguous event values.
            ..._stringValue('one'),
            ..._stringValue('three'),
            // {second} channel follows because its first event occurs later.
            ..._stringValue('two'),
          ]),
        );

    expect(document.toXmlString(), '<root><first>one</first><second>two</second><first>three</first></root>');
  });

  test('reports multi-block pre-compression streams explicitly', () {
    const schemaId = 'pre-compression-block-limit';
    const schema = ExiSchema(
      id: schemaId,
      globalElements: [
        ExiElementDeclaration.sequence(ExiQName(localName: 'root'), [
          ExiElementDeclaration.value(ExiQName(localName: 'first'), ExiDatatype.string),
          ExiElementDeclaration.value(ExiQName(localName: 'second'), ExiDatatype.string),
        ]),
      ],
    );

    expect(
      () => ExiDecoder(
        options: const ExiOptions(
          alignment: ExiAlignment.preCompression,
          blockSize: 2,
          strict: true,
          schemaId: ExiSchemaId.named(schemaId),
        ),
        schemaResolver: (_) => schema,
      ).decode(Uint8List.fromList([0x80, 0x00])),
      throwsUnsupportedError,
    );
  });
}

List<int> _stringValue(String value) => [value.runes.length + 2, ...value.runes];
