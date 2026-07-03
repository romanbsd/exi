import 'dart:typed_data';

/// Reads the bit-packed representation used by EXI streams.
final class BitInput {
  BitInput(this._bytes, {int byteOffset = 0}) : _bitOffset = byteOffset * 8 {
    if (byteOffset < 0 || byteOffset > _bytes.length) {
      throw RangeError.range(byteOffset, 0, _bytes.length, 'byteOffset');
    }
  }

  final Uint8List _bytes;
  int _bitOffset;
  var _byteAligned = false;

  int get bitOffset => _bitOffset;

  bool get isAtEnd => _bitOffset == _bytes.length * 8;

  int readBit() => readBits(1);

  void alignToByte() {
    final remainder = _bitOffset & 7;
    if (remainder != 0) {
      _bitOffset += 8 - remainder;
    }
  }

  void useByteAlignment() {
    if (_bitOffset & 7 != 0) {
      throw StateError('Byte-aligned EXI input must start on a byte boundary');
    }
    _byteAligned = true;
  }

  Uint8List readRemainingBytes() {
    if (_bitOffset & 7 != 0) {
      throw StateError('Remaining EXI bytes can be read only on a byte boundary');
    }
    final remaining = Uint8List.sublistView(_bytes, _bitOffset >> 3);
    _bitOffset = _bytes.length * 8;
    return remaining;
  }

  int readNBitUnsigned(int bitCount) {
    if (!_byteAligned) {
      return readBits(bitCount);
    }
    if (bitCount < 0 || bitCount > 63) {
      throw RangeError.range(bitCount, 0, 63, 'bitCount');
    }
    if (bitCount == 0) {
      return 0;
    }

    final byteCount = (bitCount + 7) >> 3;
    var value = 0;
    for (var index = 0; index < byteCount; index++) {
      value |= readBits(8) << (index * 8);
    }
    if (value >= 1 << bitCount) {
      throw const FormatException('Byte-aligned bounded integer exceeds its bit width');
    }
    return value;
  }

  int readBits(int count) {
    if (count < 0 || count > 63) {
      throw RangeError.range(count, 0, 63, 'count');
    }
    if (_bitOffset + count > _bytes.length * 8) {
      throw const FormatException('Unexpected end of EXI stream');
    }

    var value = 0;
    for (var index = 0; index < count; index++) {
      final byte = _bytes[_bitOffset >> 3];
      final shift = 7 - (_bitOffset & 7);
      value = (value << 1) | ((byte >> shift) & 1);
      _bitOffset++;
    }
    return value;
  }

  BigInt readUnsignedInteger() {
    var value = BigInt.zero;
    var shift = 0;

    while (true) {
      final octet = readBits(8);
      value |= BigInt.from(octet & 0x7f) << shift;
      if (octet & 0x80 == 0) {
        return value;
      }
      shift += 7;
    }
  }
}
