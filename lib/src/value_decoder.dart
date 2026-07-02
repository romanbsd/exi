import 'dart:convert';

import 'bit_input.dart';
import 'model.dart';
import 'schema.dart';
import 'string_table.dart';

final class ExiValueDecoder {
  ExiValueDecoder(this.input, this.strings, {this.preserveLexicalValues = false});

  final BitInput input;
  final ExiStringTable strings;
  final bool preserveLexicalValues;

  String read(
    ExiDatatype datatype,
    ExiQName context, {
    ExiDatatype? listItemDatatype,
    List<String> enumerationValues = const [],
    bool booleanPattern = false,
    bool listItemBooleanPattern = false,
    BigInt? integerMinInclusive,
    BigInt? integerMaxInclusive,
  }) {
    if (preserveLexicalValues) {
      return strings.readValue(
        input,
        context,
        restrictedCharacters: _restrictedCharacters(datatype, listItemDatatype: listItemDatatype),
      );
    }
    if (enumerationValues.isNotEmpty) {
      final ordinal = input.readNBitUnsigned(_bitWidth(enumerationValues.length));
      if (ordinal >= enumerationValues.length) {
        throw const FormatException('Invalid EXI enumeration ordinal');
      }
      return enumerationValues[ordinal];
    }
    return switch (datatype) {
      ExiDatatype.string => strings.readValue(input, context),
      ExiDatatype.boolean =>
        booleanPattern
            ? switch (input.readNBitUnsigned(2)) {
                0 => 'false',
                1 => '0',
                2 => 'true',
                _ => '1',
              }
            : input.readNBitUnsigned(1) == 0
            ? 'false'
            : 'true',
      ExiDatatype.decimal => _readDecimal(),
      ExiDatatype.float => _readFloat(),
      ExiDatatype.integer || ExiDatatype.unsignedInteger || ExiDatatype.byte || ExiDatatype.unsignedByte =>
        _readIntegerValue(datatype, minimum: integerMinInclusive, maximum: integerMaxInclusive),
      ExiDatatype.base64Binary => base64Encode(_readBinary()),
      ExiDatatype.hexBinary => _readBinary().map((byte) => byte.toRadixString(16).padLeft(2, '0')).join(),
      ExiDatatype.dateTime => _readDateTime(includeDate: true, includeTime: true),
      ExiDatatype.date => _readDateTime(includeDate: true, includeTime: false),
      ExiDatatype.time => _readDateTime(includeDate: false, includeTime: true),
      ExiDatatype.gYear => _readGregorian(ExiDatatype.gYear),
      ExiDatatype.gYearMonth => _readGregorian(ExiDatatype.gYearMonth),
      ExiDatatype.gMonth => _readGregorian(ExiDatatype.gMonth),
      ExiDatatype.gMonthDay => _readGregorian(ExiDatatype.gMonthDay),
      ExiDatatype.gDay => _readGregorian(ExiDatatype.gDay),
      ExiDatatype.list => _readList(
        listItemDatatype ?? (throw StateError('EXI list datatype is missing its item datatype')),
        context,
        itemBooleanPattern: listItemBooleanPattern,
      ),
    };
  }

  String _readList(ExiDatatype itemDatatype, ExiQName context, {required bool itemBooleanPattern}) {
    final encodedLength = input.readUnsignedInteger();
    if (encodedLength > BigInt.from(0x7fffffff)) {
      throw const FormatException('EXI list value is too large to materialize');
    }
    return [
      for (var index = 0; index < encodedLength.toInt(); index++)
        itemDatatype == ExiDatatype.string
            ? strings.readString(input)
            : read(itemDatatype, context, booleanPattern: itemBooleanPattern),
    ].join(' ');
  }

  BigInt _readInteger() {
    final negative = input.readNBitUnsigned(1) == 1;
    final magnitude = input.readUnsignedInteger();
    return negative ? -(magnitude + BigInt.one) : magnitude;
  }

  String _readIntegerValue(ExiDatatype datatype, {BigInt? minimum, BigInt? maximum}) {
    if (minimum == null && maximum == null) {
      return switch (datatype) {
        ExiDatatype.integer => _readInteger().toString(),
        ExiDatatype.unsignedInteger => input.readUnsignedInteger().toString(),
        ExiDatatype.byte => (input.readNBitUnsigned(8) - 128).toString(),
        ExiDatatype.unsignedByte => input.readNBitUnsigned(8).toString(),
        _ => throw StateError('$datatype is not an integer datatype'),
      };
    }

    BigInt value;
    if (minimum != null && maximum != null) {
      final valueCount = maximum - minimum + BigInt.one;
      if (valueCount <= BigInt.zero) {
        throw StateError('EXI integer datatype has an empty range');
      }
      if (valueCount <= BigInt.from(4096)) {
        final offset = input.readNBitUnsigned((valueCount.toInt() - 1).bitLength);
        if (offset >= valueCount.toInt()) {
          throw const FormatException('Invalid EXI bounded-integer offset');
        }
        value = minimum + BigInt.from(offset);
        return value.toString();
      }
    }

    final unsigned =
        datatype == ExiDatatype.unsignedInteger ||
        datatype == ExiDatatype.unsignedByte ||
        (minimum != null && minimum >= BigInt.zero);
    value = unsigned ? input.readUnsignedInteger() : _readInteger();
    if ((minimum != null && value < minimum) || (maximum != null && value > maximum)) {
      throw const FormatException('EXI integer value is outside its schema range');
    }
    return value.toString();
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

  String _readGregorian(ExiDatatype datatype) {
    final output = StringBuffer();
    int? year;
    int? month;
    int? day;

    if (datatype == ExiDatatype.gYear || datatype == ExiDatatype.gYearMonth) {
      year = _readInteger().toInt() + 2000;
    }
    if (datatype != ExiDatatype.gYear) {
      final monthDay = input.readNBitUnsigned(9);
      month = monthDay >> 5;
      day = monthDay & 31;
    }

    switch (datatype) {
      case ExiDatatype.gYear:
        output.write(_year(year!));
      case ExiDatatype.gYearMonth:
        if (month! < 1 || month > 12 || day != 0) {
          throw const FormatException('Invalid EXI gYearMonth value');
        }
        output
          ..write(_year(year!))
          ..write('-')
          ..write(_two(month));
      case ExiDatatype.gMonth:
        if (month! < 1 || month > 12 || day != 0) {
          throw const FormatException('Invalid EXI gMonth value');
        }
        output
          ..write('--')
          ..write(_two(month))
          ..write('--');
      case ExiDatatype.gMonthDay:
        if (!_isValidMonthDay(month!, day!)) {
          throw const FormatException('Invalid EXI gMonthDay value');
        }
        output
          ..write('--')
          ..write(_two(month))
          ..write('-')
          ..write(_two(day));
      case ExiDatatype.gDay:
        if (month != 0 || day! < 1 || day > 31) {
          throw const FormatException('Invalid EXI gDay value');
        }
        output
          ..write('---')
          ..write(_two(day));
      default:
        throw ArgumentError.value(datatype, 'datatype', 'is not a partial Gregorian datatype');
    }
    _readTimezone(output);
    return output.toString();
  }

  String _readDateTime({required bool includeDate, required bool includeTime}) {
    final output = StringBuffer();
    if (includeDate) {
      final year = _readInteger().toInt() + 2000;
      final monthDay = input.readNBitUnsigned(9);
      final month = monthDay >> 5;
      final day = monthDay & 31;
      if (!_isValidMonthDay(month, day, year: year)) {
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
    _readTimezone(output);
    return output.toString();
  }

  void _readTimezone(StringBuffer output) {
    if (input.readNBitUnsigned(1) == 0) {
      return;
    }
    final timezone = input.readNBitUnsigned(11) - 896;
    if (timezone == 0) {
      output.write('Z');
      return;
    }
    final sign = timezone < 0 ? '-' : '+';
    final absolute = timezone.abs();
    final hours = absolute ~/ 64;
    final minutes = absolute % 64;
    if (hours > 14 || minutes > 59 || (hours == 14 && minutes != 0)) {
      throw const FormatException('Invalid EXI timezone value');
    }
    output
      ..write(sign)
      ..write(_two(hours))
      ..write(':')
      ..write(_two(minutes));
  }
}

String _two(int value) => value.toString().padLeft(2, '0');

int _bitWidth(int valueCount) => valueCount <= 1 ? 0 : (valueCount - 1).bitLength;

List<int>? _restrictedCharacters(ExiDatatype datatype, {ExiDatatype? listItemDatatype}) {
  if (datatype == ExiDatatype.list) {
    return _restrictedCharacters(
      listItemDatatype ?? (throw StateError('EXI list datatype is missing its item datatype')),
    );
  }
  return switch (datatype) {
    ExiDatatype.base64Binary => _base64Characters,
    ExiDatatype.hexBinary => _hexCharacters,
    ExiDatatype.boolean => _booleanCharacters,
    ExiDatatype.dateTime ||
    ExiDatatype.date ||
    ExiDatatype.time ||
    ExiDatatype.gYear ||
    ExiDatatype.gYearMonth ||
    ExiDatatype.gMonth ||
    ExiDatatype.gMonthDay ||
    ExiDatatype.gDay => _dateTimeCharacters,
    ExiDatatype.decimal => _decimalCharacters,
    ExiDatatype.float => _floatCharacters,
    ExiDatatype.integer ||
    ExiDatatype.unsignedInteger ||
    ExiDatatype.byte ||
    ExiDatatype.unsignedByte => _integerCharacters,
    ExiDatatype.string || ExiDatatype.list => null,
  };
}

const _whitespaceCharacters = [9, 10, 13, 32];
final _base64Characters = [
  ..._whitespaceCharacters,
  43,
  47,
  ..._range(48, 57),
  61,
  ..._range(65, 90),
  ..._range(97, 122),
];
final _hexCharacters = [..._whitespaceCharacters, ..._range(48, 57), ..._range(65, 70), ..._range(97, 102)];
const _booleanCharacters = [..._whitespaceCharacters, 48, 49, 97, 101, 102, 108, 114, 115, 116, 117];
final _dateTimeCharacters = [..._whitespaceCharacters, 43, 45, 46, ..._range(48, 57), 58, 84, 90];
final _decimalCharacters = [..._whitespaceCharacters, 43, 45, 46, ..._range(48, 57)];
final _floatCharacters = [..._whitespaceCharacters, 43, 45, 46, ..._range(48, 57), 69, 70, 73, 78, 97, 101];
final _integerCharacters = [..._whitespaceCharacters, 43, 45, ..._range(48, 57)];

List<int> _range(int first, int last) => [for (var value = first; value <= last; value++) value];

bool _isValidMonthDay(int month, int day, {int? year}) {
  if (month < 1 || month > 12 || day < 1) {
    return false;
  }
  final leapYear = year == null || (year % 4 == 0 && (year % 100 != 0 || year % 400 == 0));
  final maximum = switch (month) {
    2 => leapYear ? 29 : 28,
    4 || 6 || 9 || 11 => 30,
    _ => 31,
  };
  return day <= maximum;
}

String _year(int value) {
  if (value < 0) {
    return '-${(-value).toString().padLeft(4, '0')}';
  }
  return value.toString().padLeft(4, '0');
}
