import 'dart:typed_data';

import 'package:exi/exi.dart';
import 'package:test/test.dart';

void main() {
  group('byte alignment', () {
    test('decodes the official W3C schema-less string vector', () {
      final bytes = Uint8List.fromList([
        0x80,
        0x01,
        0x02,
        0x61,
        0x03,
        0x11,
        0x30,
        0x31,
        0x32,
        0x33,
        0x34,
        0x35,
        0x36,
        0x37,
        0x41,
        0x38,
        0x39,
        0x61,
        0x62,
        0x63,
        0x64,
        0x00,
      ]);

      final document = ExiDecoder(options: const ExiOptions(alignment: ExiAlignment.byteAligned)).decode(bytes);

      expect(document.toXmlString(), '<a>01234567A89abcd</a>');
    });

    test('applies in-band byte alignment after header padding', () {
      final bytes = Uint8List.fromList([
        // Header and options: <lesscommon><uncommon><alignment><byte/>.
        0xa0, 0x01, 0x4a,
        // Same byte-aligned body as the W3C vector.
        0x01, 0x02, 0x61, 0x03, 0x03, 0x78, 0x00,
      ]);

      final document = ExiDecoder().decode(bytes);

      expect(document.options.alignment, ExiAlignment.byteAligned);
      expect(document.toXmlString(), '<a>x</a>');
    });
  });
}
