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

  test('decodes a large value channel from its own compressed stream', () {
    const schemaId = 'compressed-large-channel';
    const value = ExiElementDeclaration.value(ExiQName(localName: 'value'), ExiDatatype.string);
    final schema = ExiSchema(
      id: schemaId,
      globalElements: [ExiElementDeclaration.sequence(const ExiQName(localName: 'root'), List.filled(101, value))],
    );
    final structureStream = ZLibEncoder(raw: true).convert([0x00]);
    final valueStream = ZLibEncoder(
      raw: true,
    ).convert([for (var index = 0; index < 101; index++) ..._stringValue('$index')]);

    final document = ExiDecoder(
      options: const ExiOptions(
        compression: true,
        strict: true,
        schemaId: ExiSchemaId.named(schemaId),
        blockSize: 1000,
      ),
      schemaResolver: (_) => schema,
    ).decode(Uint8List.fromList([0x80, ...structureStream, ...valueStream]));

    expect(document.toXmlString(), '<root>${List.generate(101, (index) => '<value>$index</value>').join()}</root>');
  });

  test('decodes small channels before separately compressed large channels', () {
    const schemaId = 'compressed-mixed-channels';
    const small = ExiElementDeclaration.value(ExiQName(localName: 'small'), ExiDatatype.string);
    const large = ExiElementDeclaration.value(ExiQName(localName: 'large'), ExiDatatype.string);
    final children = [small, ...List.filled(101, large), small];
    final schema = ExiSchema(
      id: schemaId,
      globalElements: [ExiElementDeclaration.sequence(const ExiQName(localName: 'root'), children)],
    );
    final structureStream = ZLibEncoder(raw: true).convert([0x00]);
    final smallStream = ZLibEncoder(raw: true).convert([..._stringValue('before'), ..._stringValue('after')]);
    final largeStream = ZLibEncoder(
      raw: true,
    ).convert([for (var index = 0; index < 101; index++) ..._stringValue('$index')]);

    final document = ExiDecoder(
      options: const ExiOptions(
        compression: true,
        strict: true,
        schemaId: ExiSchemaId.named(schemaId),
        blockSize: 1000,
      ),
      schemaResolver: (_) => schema,
    ).decode(Uint8List.fromList([0x80, ...structureStream, ...smallStream, ...largeStream]));

    expect(
      document.toXmlString(),
      '<root><small>before</small>'
      '${List.generate(101, (index) => '<large>$index</large>').join()}'
      '<small>after</small></root>',
    );
  });

  test('continues the active grammar across compressed blocks', () {
    const schemaId = 'compressed-blocks';
    const value = ExiElementDeclaration.value(ExiQName(localName: 'value'), ExiDatatype.string);
    final schema = ExiSchema(
      id: schemaId,
      globalElements: [
        ExiElementDeclaration.sequence(const ExiQName(localName: 'root'), const [value, value, value]),
      ],
    );
    final firstBlock = ZLibEncoder(raw: true).convert([0x00, ..._stringValue('one'), ..._stringValue('two')]);
    final finalBlock = ZLibEncoder(raw: true).convert(_stringValue('three'));

    final document = ExiDecoder(
      options: const ExiOptions(compression: true, strict: true, schemaId: ExiSchemaId.named(schemaId), blockSize: 2),
      schemaResolver: (_) => schema,
    ).decode(Uint8List.fromList([0x80, ...firstBlock, ...finalBlock]));

    expect(document.toXmlString(), '<root><value>one</value><value>two</value><value>three</value></root>');
  });

  test('does not require an empty final compressed stream', () {
    const schemaId = 'compressed-exact-block';
    const value = ExiElementDeclaration.value(ExiQName(localName: 'value'), ExiDatatype.string);
    const schema = ExiSchema(
      id: schemaId,
      globalElements: [
        ExiElementDeclaration.sequence(ExiQName(localName: 'root'), [value, value]),
      ],
    );
    final block = ZLibEncoder(raw: true).convert([0x00, ..._stringValue('one'), ..._stringValue('two')]);

    final document = ExiDecoder(
      options: const ExiOptions(compression: true, strict: true, schemaId: ExiSchemaId.named(schemaId), blockSize: 2),
      schemaResolver: (_) => schema,
    ).decode(Uint8List.fromList([0x80, ...block]));

    expect(document.toXmlString(), '<root><value>one</value><value>two</value></root>');
  });
}

List<int> _stringValue(String value) => [value.runes.length + 2, ...value.runes];
