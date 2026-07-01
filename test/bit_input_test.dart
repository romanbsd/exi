import 'dart:typed_data';

import 'package:exi/src/bit_input.dart';
import 'package:test/test.dart';

void main() {
  group('BitInput', () {
    test('reads bits most-significant first across byte boundaries', () {
      final input = BitInput(Uint8List.fromList([0xb2, 0x61]));

      expect(input.readBits(3), 5);
      expect(input.readBits(7), 0x49);
      expect(input.readBits(6), 0x21);
      expect(input.isAtEnd, isTrue);
    });

    test('reads EXI unsigned integers least-significant group first', () {
      final input = BitInput(Uint8List.fromList([0x81, 0x01]));

      expect(input.readUnsignedInteger(), BigInt.from(129));
      expect(input.isAtEnd, isTrue);
    });

    test('supports arbitrary-magnitude EXI unsigned integers', () {
      final input = BitInput(Uint8List.fromList([0xff, 0xff, 0xff, 0xff, 0x0f]));

      expect(input.readUnsignedInteger(), BigInt.parse('4294967295'));
    });

    test('rejects reads past the end of the stream', () {
      final input = BitInput(Uint8List.fromList([0]));
      input.readBits(8);

      expect(() => input.readBit(), throwsA(isA<FormatException>()));
    });

    test('reads byte-aligned bounded integers least-significant byte first', () {
      final input = BitInput(Uint8List.fromList([0x34, 0x02]));
      input.useByteAlignment();

      expect(input.readNBitUnsigned(12), 0x234);
      expect(input.isAtEnd, isTrue);
    });

    test('skips header padding to the next byte boundary', () {
      final input = BitInput(Uint8List.fromList([0xbf, 0x2a]));
      expect(input.readBits(3), 5);

      input.alignToByte();

      expect(input.readBits(8), 0x2a);
    });
  });
}
