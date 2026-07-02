import 'dart:typed_data';

import 'package:exi/exi.dart';
import 'package:test/test.dart';

void main() {
  group('in-band EXI options', () {
    test('decodes the official W3C strict-only header vector', () {
      // OpenEXI encoding from the W3C EXI 1.0 interoperability framework.
      final bytes = Uint8List.fromList([
        0x24,
        0x45,
        0x58,
        0x49,
        0xa0,
        0x48,
        0x13,
        0x0e,
        0x22,
        0x60,
        0x62,
        0x64,
        0x66,
        0x68,
        0x6a,
        0x6c,
        0x6e,
        0x82,
        0x70,
        0x72,
        0xc2,
        0xc4,
        0xc6,
        0xc8,
      ]);

      final document = ExiDecoder().decode(bytes);

      expect(document.options.strict, isTrue);
      expect(document.header.hasOptions, isTrue);
      expect(document.toXmlString(), '<a>01234567A89abcd</a>');
    });

    test('applies the fragment option to the following body', () {
      final bits = StringBuffer('10100000')
        // Options document: SE(header), SE(common), SE(fragment),
        // EE(common), EE(header).
        ..write('0010111')
        // Fragment body with two empty <item> elements.
        ..write('0')
        ..write(_qName('', 'item'))
        ..write('00')
        ..write('00')
        ..write('0')
        ..write('10');

      final document = ExiDecoder().decode(_pack(bits.toString()));

      expect(document.options.fragment, isTrue);
      expect(document.toXmlString(), '<item/><item/>');
    });

    test('applies preserve-comments to the following body', () {
      final bits = StringBuffer('10100000')
        // header/lesscommon/preserve/comments, then close each sequence.
        ..write('000010111110')
        // Document body with a comment inside <root>.
        ..write('0')
        ..write(_qName('', 'root'))
        ..write('100')
        ..write(_rawString('note'))
        ..write('0')
        ..write('0');

      final document = ExiDecoder().decode(_pack(bits.toString()));

      expect(document.options.fidelity.comments, isTrue);
      expect(document.events.whereType<ExiComment>().single.text, 'note');
      expect(document.toXmlString(), '<root><!--note--></root>');
    });

    test('reads preserve-lexical-values from the options document', () {
      final bits = StringBuffer('10100000')
        // header/lesscommon/preserve/lexicalValues, then close each sequence.
        ..write('0000101010110')
        // Empty schema-less document body.
        ..write(_qName('', 'root'))
        ..write('00');

      final document = ExiDecoder().decode(_pack(bits.toString()));

      expect(document.options.fidelity.lexicalValues, isTrue);
      expect(document.toXmlString(), '<root/>');
    });

    test('applies self-contained mode to the following body', () {
      final bits = StringBuffer('10100000')
        // header/lesscommon/uncommon/selfContained, then close each sequence.
        ..write('00000010111010')
        // Document body: SE(root), then SC.
        ..write(_qName('', 'root'))
        ..write('010');
      _alignBits(bits);
      // Fresh root grammar -> EE.
      bits.write('000');
      _alignBits(bits);

      final document = ExiDecoder().decode(_pack(bits.toString()));

      expect(document.options.selfContained, isTrue);
      expect(document.toXmlString(), '<root/>');
    });
  });
}

String _qName(String uri, String localName) {
  final encodedUri = uri.isEmpty ? '01' : '00${_rawString(uri)}';
  return '$encodedUri${_literal(localName, lengthOffset: 1)}';
}

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

void _alignBits(StringBuffer bits) {
  while (bits.length % 8 != 0) {
    bits.write('0');
  }
}
