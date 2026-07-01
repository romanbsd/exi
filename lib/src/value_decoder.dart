import 'dart:convert';

import 'bit_input.dart';
import 'model.dart';
import 'schema.dart';
import 'string_table.dart';

final class ExiValueDecoder {
  ExiValueDecoder(this.input, this.strings);

  final BitInput input;
  final ExiStringTable strings;

  String read(ExiDatatype datatype, ExiQName context) {
    return switch (datatype) {
      ExiDatatype.string => strings.readValue(input, context),
      ExiDatatype.boolean => input.readNBitUnsigned(1) == 0 ? 'false' : 'true',
      ExiDatatype.decimal => _readDecimal(),
      ExiDatatype.float => _readFloat(),
      ExiDatatype.integer => _readInteger().toString(),
      ExiDatatype.unsignedInteger => input.readUnsignedInteger().toString(),
      ExiDatatype.byte => (input.readNBitUnsigned(8) - 128).toString(),
      ExiDatatype.unsignedByte => input.readNBitUnsigned(8).toString(),
      ExiDatatype.base64Binary => base64Encode(_readBinary()),
      ExiDatatype.hexBinary => _readBinary().map((byte) => byte.toRadixString(16).padLeft(2, '0')).join(),
      ExiDatatype.dateTime => _readDateTime(includeDate: true, includeTime: true),
      ExiDatatype.date => _readDateTime(includeDate: true, includeTime: false),
      ExiDatatype.time => _readDateTime(includeDate: false, includeTime: true),
    };
  }

  BigInt _readInteger() {
    final negative = input.readNBitUnsigned(1) == 1;
    final magnitude = input.readUnsignedInteger();
    return negative ? -(magnitude + BigInt.one) : magnitude;
  }

  String _readDecimal() {
    final negative = input.readNBitUnsigned(1) == 1;
    final integral = input.readUnsignedInteger();
    final reversedFraction = input.readUnsignedInteger().toString();
    final fraction = reversedFraction.split('').reversed.join();
    return '${negative ? '-' : ''}$integral.$fraction';
  }

  String _readFloat() {
    final mantissa = _readInteger();
    final exponent = _readInteger();
    if (exponent == BigInt.from(-16384)) {
      if (mantissa == BigInt.one) {
        return 'INF';
      }
      if (mantissa == -BigInt.one) {
        return '-INF';
      }
      return 'NaN';
    }
    return '${mantissa}E$exponent';
  }

  List<int> _readBinary() {
    final encodedLength = input.readUnsignedInteger();
    if (encodedLength > BigInt.from(0x7fffffff)) {
      throw const FormatException('EXI binary value is too large to materialize');
    }
    return [for (var index = 0; index < encodedLength.toInt(); index++) input.readBits(8)];
  }

  String _readDateTime({required bool includeDate, required bool includeTime}) {
    final output = StringBuffer();
    if (includeDate) {
      final year = _readInteger().toInt() + 2000;
      final monthDay = input.readNBitUnsigned(9);
      final month = monthDay >> 5;
      final day = monthDay & 31;
      if (month < 1 || month > 12 || day < 1 || day > 31) {
        throw const FormatException('Invalid EXI month/day value');
      }
      output
        ..write(_year(year))
        ..write('-')
        ..write(_two(month))
        ..write('-')
        ..write(_two(day));
    }
    if (includeDate && includeTime) {
      output.write('T');
    }
    if (includeTime) {
      final encodedTime = input.readNBitUnsigned(17);
      final second = encodedTime & 63;
      final minute = (encodedTime >> 6) & 63;
      final hour = encodedTime >> 12;
      if (hour > 24 || minute > 59 || second > 60) {
        throw const FormatException('Invalid EXI time value');
      }
      output
        ..write(_two(hour))
        ..write(':')
        ..write(_two(minute))
        ..write(':')
        ..write(_two(second));
      if (input.readNBitUnsigned(1) == 1) {
        final fraction = input.readUnsignedInteger().toString().split('').reversed.join();
        output
          ..write('.')
          ..write(fraction);
      }
    }
    if (input.readNBitUnsigned(1) == 1) {
      final timezone = input.readNBitUnsigned(11) - 896;
      if (timezone == 0) {
        output.write('Z');
      } else {
        final sign = timezone < 0 ? '-' : '+';
        final absolute = timezone.abs();
        output
          ..write(sign)
          ..write(_two(absolute ~/ 64))
          ..write(':')
          ..write(_two(absolute % 64));
      }
    }
    return output.toString();
  }
}

String _two(int value) => value.toString().padLeft(2, '0');

String _year(int value) {
  if (value < 0) {
    return '-${(-value).toString().padLeft(4, '0')}';
  }
  return value.toString().padLeft(4, '0');
}
