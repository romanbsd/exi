import 'bit_input.dart';
import 'model.dart';

const _xmlUri = 'http://www.w3.org/XML/1998/namespace';
const _xsiUri = 'http://www.w3.org/2001/XMLSchema-instance';

final class ExiStringTable {
  ExiStringTable({this.preservePrefixes = false});

  final bool preservePrefixes;
  final List<String> _uris = ['', _xmlUri, _xsiUri];
  final Map<String, List<String>> _prefixes = {
    '': [''],
    _xmlUri: ['xml'],
    _xsiUri: ['xsi'],
  };
  final Map<String, List<String>> _localNames = {
    _xmlUri: ['base', 'id', 'lang', 'space'],
    _xsiUri: ['nil', 'type'],
  };
  final List<String?> _globalValues = [];
  final Map<ExiQName, List<String?>> _localValues = {};

  ExiQName readQName(BitInput input) {
    final uri = _readCompactOptimized(input, _uris);
    final localName = _readLiteralOptimized(input, _localNames.putIfAbsent(uri, () => []));
    String? prefix;
    if (preservePrefixes) {
      final partition = _prefixes.putIfAbsent(uri, () => []);
      final compactId = input.readBits(_bitWidth(partition.isEmpty ? 1 : partition.length));
      if (partition.isNotEmpty) {
        if (compactId >= partition.length) {
          throw const FormatException('Invalid EXI prefix compact identifier');
        }
        prefix = partition[compactId];
      }
    }
    return ExiQName(uri: uri, localName: localName, prefix: prefix);
  }

  String readString(BitInput input) => _readString(input);

  void addPrefix(String uri, String prefix) {
    final partition = _prefixes.putIfAbsent(uri, () => []);
    if (!partition.contains(prefix)) {
      partition.add(prefix);
    }
  }

  String readValue(BitInput input, ExiQName context) {
    final marker = _readLength(input);
    final local = _localValues.putIfAbsent(context, () => []);

    if (marker == 0) {
      return _readAssigned(input, local, 'local value');
    }
    if (marker == 1) {
      return _readAssigned(input, _globalValues, 'global value');
    }

    final value = _readCharacters(input, marker - 2);
    if (value.isNotEmpty) {
      local.add(value);
      _globalValues.add(value);
    }
    return value;
  }

  String _readCompactOptimized(BitInput input, List<String> partition) {
    final encoded = input.readBits(_bitWidth(partition.length + 1));
    if (encoded == 0) {
      final value = _readString(input);
      partition.add(value);
      return value;
    }

    final compactId = encoded - 1;
    if (compactId >= partition.length) {
      throw const FormatException('Invalid EXI string-table compact identifier');
    }
    return partition[compactId];
  }

  String _readLiteralOptimized(BitInput input, List<String> partition) {
    final encodedLength = _readLength(input);
    if (encodedLength == 0) {
      return _readAssigned(input, partition, 'local-name');
    }

    final value = _readCharacters(input, encodedLength - 1);
    partition.add(value);
    return value;
  }

  String _readString(BitInput input) => _readCharacters(input, _readLength(input));

  String _readCharacters(BitInput input, int length) {
    final codePoints = <int>[];
    for (var index = 0; index < length; index++) {
      final codePoint = input.readUnsignedInteger();
      if (codePoint > BigInt.from(0x10ffff)) {
        throw const FormatException('Invalid Unicode code point in EXI string');
      }
      final value = codePoint.toInt();
      if (value >= 0xd800 && value <= 0xdfff) {
        throw const FormatException('Unicode surrogate is not a valid EXI code point');
      }
      codePoints.add(value);
    }
    return String.fromCharCodes(codePoints);
  }

  String _readAssigned(BitInput input, List<String?> partition, String partitionName) {
    if (partition.isEmpty) {
      throw FormatException('Compact identifier used with empty $partitionName partition');
    }
    final compactId = input.readBits(_bitWidth(partition.length));
    if (compactId >= partition.length || partition[compactId] == null) {
      throw FormatException('Invalid $partitionName compact identifier');
    }
    return partition[compactId]!;
  }

  int _readLength(BitInput input) {
    final value = input.readUnsignedInteger();
    if (value > BigInt.from(0x7fffffff)) {
      throw const FormatException('EXI string is too large to materialize');
    }
    return value.toInt();
  }
}

int _bitWidth(int valueCount) {
  if (valueCount <= 1) {
    return 0;
  }
  return (valueCount - 1).bitLength;
}
