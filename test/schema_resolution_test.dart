import 'dart:typed_data';

import 'package:exi/exi.dart';
import 'package:test/test.dart';

void main() {
  group('schemaId', () {
    test('extracts the named schema from the official W3C vector', () {
      final bytes = Uint8List.fromList([
        0xa0,
        0x30,
        0xd1,
        0x91,
        0x85,
        0xd1,
        0x84,
        0xbd,
        0xa5,
        0xb9,
        0xd1,
        0x95,
        0xc9,
        0xbd,
        0xc0,
        0xbd,
        0x89,
        0xd5,
        0xa5,
        0xb1,
        0xd1,
        0x25,
        0xb9,
        0x1d,
        0xc9,
        0x85,
        0xb5,
        0xb5,
        0x85,
        0xc8,
        0xbd,
        0x95,
        0xb1,
        0x95,
        0xb5,
        0x95,
        0xb9,
        0xd0,
        0xbd,
        0xa5,
        0xb9,
        0x8d,
        0xbd,
        0xb5,
        0xc1,
        0xb1,
        0x95,
        0xd1,
        0x94,
        0xb9,
        0xe1,
        0xcd,
        0x93,
        0x20,
        0x4c,
        0x31,
        0x00,
        0x20,
      ]);

      expect(
        () => ExiDecoder().decode(bytes),
        throwsA(
          isA<ExiSchemaNotFoundException>().having(
            (error) => error.schemaId,
            'schemaId',
            'data/interop/builtInGrammar/element/incomplete.xsd',
          ),
        ),
      );
    });

    test('resolves a named strict schema and omits declared QNames', () {
      const schemaId = 'example';
      final optionsBits = StringBuffer('00110')
        ..write('0')
        ..write(_value(schemaId))
        // After common/schemaId, select strict and close header.
        ..write('0');
      final streamBits = StringBuffer('10100000')
        ..write(optionsBits)
        // Declared root element, its EE, and ED all use zero-bit codes.
        ..write('0');
      final requestedIds = <String>[];

      final document = ExiDecoder(
        schemaResolver: (id) {
          requestedIds.add(id);
          return const ExiSchema(
            id: schemaId,
            globalElements: [ExiElementDeclaration.empty(ExiQName(localName: 'root'))],
          );
        },
      ).decode(_pack(streamBits.toString()));

      expect(requestedIds, [schemaId]);
      expect(document.options.schemaId, const ExiSchemaId.named(schemaId));
      expect(document.toXmlString(), '<root/>');
    });

    test('accepts an empty schemaId as built-in XML Schema types', () {
      final bits = StringBuffer('10100000')
        ..write('00110')
        ..write('0')
        ..write(_value(''))
        // Close header rather than selecting strict.
        ..write('1')
        ..write(_qName('', 'root'))
        ..write('00');

      final document = ExiDecoder().decode(_pack(bits.toString()));

      expect(document.options.schemaId, ExiSchemaId.builtInTypes);
      expect(document.toXmlString(), '<root/>');
    });

    test('decodes xsi:nil schemaId as an explicitly schema-less stream', () {
      final bytes = Uint8List.fromList([0xa0, 0x37, 0x41, 0x5c, 0x9b, 0xdb, 0xdd, 0x00]);

      final document = ExiDecoder().decode(bytes);

      expect(document.options.schemaId, ExiSchemaId.schemaLess);
      expect(document.toXmlString(), '<root/>');
    });

    test('decodes a strict declared element sequence without QName payloads', () {
      const schemaId = 'sequence';
      final bits = StringBuffer('10100000')
        ..write('00110')
        ..write('0')
        ..write(_value(schemaId))
        ..write('0')
        // Root selection, child selection, both EE events, and ED are zero.
        ..write('0');

      final document = ExiDecoder(
        schemaResolver: (id) => const ExiSchema(
          id: schemaId,
          globalElements: [
            ExiElementDeclaration.sequence(ExiQName(localName: 'root'), [
              ExiElementDeclaration.empty(ExiQName(localName: 'child')),
            ]),
          ],
        ),
      ).decode(_pack(bits.toString()));

      expect(document.toXmlString(), '<root><child/></root>');
    });
  });
}

String _qName(String uri, String localName) {
  final encodedUri = uri.isEmpty ? '01' : '00${_rawString(uri)}';
  return '$encodedUri${_literal(localName, lengthOffset: 1)}';
}

String _value(String value) => _literal(value, lengthOffset: 2);

String _rawString(String value) => _literal(value, lengthOffset: 0);

String _literal(String value, {required int lengthOffset}) {
  final codePoints = value.runes.toList();
  return '${_unsigned(codePoints.length + lengthOffset)}${codePoints.map(_unsigned).join()}';
}

String _unsigned(int value) {
  final bits = StringBuffer();
  var remainder = value;
  do {
    final group = remainder & 0x7f;
    remainder >>= 7;
    bits.write((group | (remainder == 0 ? 0 : 0x80)).toRadixString(2).padLeft(8, '0'));
  } while (remainder != 0);
  return bits.toString();
}

Uint8List _pack(String bits) {
  final padded = bits.padRight((bits.length + 7) ~/ 8 * 8, '0');
  return Uint8List.fromList([
    for (var offset = 0; offset < padded.length; offset += 8) int.parse(padded.substring(offset, offset + 8), radix: 2),
  ]);
}
