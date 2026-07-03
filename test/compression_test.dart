import 'dart:io';
import 'dart:typed_data';

import 'package:exi/exi.dart';
import 'package:test/test.dart';

void main() {
  test('decodes a single compressed stream with at most 100 values', () {
    const schemaId = 'compressed-values';
    const schema = ExiSchema(
      id: schemaId,
      globalElements: [
        ExiElementDeclaration.sequence(ExiQName(localName: 'root'), [
          ExiElementDeclaration.value(ExiQName(localName: 'text'), ExiDatatype.string),
          ExiElementDeclaration.value(ExiQName(localName: 'count'), ExiDatatype.integer),
        ]),
      ],
    );
    final compressedBody = ZLibEncoder(raw: true).convert([
      // Structure channel: schema root selection.
      0x00,
      // {text} channel: literal "x".
      0x03, 0x78,
      // {count} channel: positive integer 7.
      0x00, 0x07,
    ]);

    final document = ExiDecoder(
      options: const ExiOptions(compression: true, strict: true, schemaId: ExiSchemaId.named(schemaId)),
      schemaResolver: (_) => schema,
    ).decode(Uint8List.fromList([0x80, ...compressedBody]));

    expect(document.toXmlString(), '<root><text>x</text><count>7</count></root>');
  });

  test('demultiplexes compressed QName value channels', () {
    const schemaId = 'compressed-channels';
    const first = ExiElementDeclaration.value(ExiQName(localName: 'first'), ExiDatatype.string);
    const second = ExiElementDeclaration.value(ExiQName(localName: 'second'), ExiDatatype.string);
    const schema = ExiSchema(
      id: schemaId,
      globalElements: [
        ExiElementDeclaration.sequence(ExiQName(localName: 'root'), [first, second, first]),
      ],
    );
    final compressedBody = ZLibEncoder(
      raw: true,
    ).convert([0x00, ..._stringValue('one'), ..._stringValue('three'), ..._stringValue('two')]);

    final document = ExiDecoder(
      options: const ExiOptions(compression: true, strict: true, schemaId: ExiSchemaId.named(schemaId)),
      schemaResolver: (_) => schema,
    ).decode(Uint8List.fromList([0x80, ...compressedBody]));

    expect(document.toXmlString(), '<root><first>one</first><second>two</second><first>three</first></root>');
  });
}

List<int> _stringValue(String value) => [value.runes.length + 2, ...value.runes];
