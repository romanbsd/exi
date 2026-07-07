import 'bit_input.dart';
import 'model.dart';
import 'schema.dart';

const _xmlUri = 'http://www.w3.org/XML/1998/namespace';
const _xsiUri = 'http://www.w3.org/2001/XMLSchema-instance';
const _xsdUri = 'http://www.w3.org/2001/XMLSchema';
const _xsdLocalNames = {
  'ENTITIES',
  'ENTITY',
  'ID',
  'IDREF',
  'IDREFS',
  'NCName',
  'NMTOKEN',
  'NMTOKENS',
  'NOTATION',
  'Name',
  'QName',
  'anySimpleType',
  'anyType',
  'anyURI',
  'base64Binary',
  'boolean',
  'byte',
  'date',
  'dateTime',
  'decimal',
  'double',
  'duration',
  'float',
  'gDay',
  'gMonth',
  'gMonthDay',
  'gYear',
  'gYearMonth',
  'hexBinary',
  'int',
  'integer',
  'language',
  'long',
  'negativeInteger',
  'nonNegativeInteger',
  'nonPositiveInteger',
  'normalizedString',
  'positiveInteger',
  'short',
  'string',
  'time',
  'token',
  'unsignedByte',
  'unsignedInt',
  'unsignedLong',
  'unsignedShort',
};

final class ExiStringTable {
  ExiStringTable({this.preservePrefixes = false, this.valueMaxLength, this.valuePartitionCapacity, ExiSchema? schema}) {
    if (schema != null) {
      _prepopulateSchema(schema);
    }
  }

  final bool preservePrefixes;
  final int? valueMaxLength;
  final int? valuePartitionCapacity;
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
  final List<_GlobalValue?> _globalValues = [];
  final Map<ExiQName, List<String?>> _localValues = {};
  var _globalId = 0;

  void _prepopulateSchema(ExiSchema schema) {
    _uris.add(_xsdUri);
    final qNames = <ExiQName>{...schema.stringTableQNames};
    final uris = <String>{...schema.stringTableUris};
    final seenElements = Set<ExiElementDeclaration>.identity();
    late void Function(ExiElementDeclaration) collectElement;
    late void Function(ExiParticle?) collectParticle;

    collectElement = (element) {
      if (!seenElements.add(element)) {
        return;
      }
      qNames.add(element.name);
      uris.add(element.name.uri);
      for (final attribute in element.attributes) {
        qNames.add(attribute.name);
        uris.add(attribute.name.uri);
      }
      final wildcardNamespaces = element.attributeWildcardNamespaces;
      if (wildcardNamespaces != null) {
        uris.addAll(wildcardNamespaces);
      }
      for (final child in element.children) {
        collectElement(child);
      }
      collectParticle(element.content);
      for (final alternative in element.typeAlternatives.values) {
        collectElement(alternative);
      }
    };

    collectParticle = (particle) {
      switch (particle) {
        case null:
        case ExiEmptyParticle():
          return;
        case ExiElementParticle(:final element):
          collectElement(element);
        case ExiWildcardParticle(:final namespaces):
          if (namespaces != null) {
            uris.addAll(namespaces);
          }
        case ExiSequenceParticle(:final particles):
        case ExiChoiceParticle(:final particles):
        case ExiAllParticle(:final particles):
          for (final child in particles) {
            collectParticle(child);
          }
        case ExiRepeatedParticle(:final particle):
          collectParticle(particle);
      }
    };

    for (final element in schema.globalElements) {
      collectElement(element);
    }
    for (final attribute in schema.globalAttributes) {
      qNames.add(attribute.name);
      uris.add(attribute.name.uri);
    }

    uris.removeAll(_uris);
    uris.remove('');
    _uris.addAll(uris.toList()..sort());

    _localNames.putIfAbsent(_xsdUri, () => []).addAll(_xsdLocalNames);
    for (final name in qNames) {
      _localNames.putIfAbsent(name.uri, () => []).add(name.localName);
    }
    for (final partition in _localNames.values) {
      final sorted = partition.toSet().toList()..sort();
      partition
        ..clear()
        ..addAll(sorted);
    }
  }

  ExiQName readQName(BitInput input) {
    final uri = _readCompactOptimized(input, _uris);
    final localName = _readLiteralOptimized(input, _localNames.putIfAbsent(uri, () => []));
    String? prefix;
    if (preservePrefixes) {
      final partition = _prefixes.putIfAbsent(uri, () => []);
      final compactId = input.readNBitUnsigned(_bitWidth(partition.isEmpty ? 1 : partition.length));
      if (partition.isNotEmpty) {
        if (compactId >= partition.length) {
          throw const FormatException('Invalid EXI prefix compact identifier');
        }
        prefix = partition[compactId];
      }
    }
    return ExiQName(uri: uri, localName: localName, prefix: prefix);
  }

  String readString(BitInput input, {List<int>? restrictedCharacters}) =>
      _readCharacters(input, _readLength(input), restrictedCharacters: restrictedCharacters);

  void addPrefix(String uri, String prefix) {
    if (!_uris.contains(uri)) {
      _uris.add(uri);
    }
    if (uri.isEmpty) {
      return;
    }
    final partition = _prefixes.putIfAbsent(uri, () => []);
    if (!partition.contains(prefix)) {
      partition.add(prefix);
    }
  }

  void addQName(ExiQName name) {
    if (!_uris.contains(name.uri)) {
      _uris.add(name.uri);
    }
    final localNames = _localNames.putIfAbsent(name.uri, () => []);
    if (!localNames.contains(name.localName)) {
      localNames.add(name.localName);
    }
    final prefix = name.prefix;
    if (preservePrefixes && prefix != null) {
      addPrefix(name.uri, prefix);
    }
  }

  String readValue(BitInput input, ExiQName context, {List<int>? restrictedCharacters}) {
    final marker = _readLength(input);
    final local = _localValues.putIfAbsent(context, () => []);

    if (marker == 0) {
      return _readAssigned(input, local, 'local value');
    }
    if (marker == 1) {
      if (_globalValues.isEmpty) {
        throw const FormatException('Compact identifier used with empty global value partition');
      }
      final compactId = input.readNBitUnsigned(_bitWidth(_globalValues.length));
      if (compactId >= _globalValues.length || _globalValues[compactId] == null) {
        throw const FormatException('Invalid global value compact identifier');
      }
      return _globalValues[compactId]!.value;
    }

    final value = _readCharacters(input, marker - 2, restrictedCharacters: restrictedCharacters);
    if (value.isNotEmpty &&
        (valueMaxLength == null || value.runes.length <= valueMaxLength!) &&
        valuePartitionCapacity != 0) {
      final localId = local.length;
      local.add(value);
      final entry = _GlobalValue(value, context, localId);
      final capacity = valuePartitionCapacity;
      if (capacity == null) {
        _globalValues.add(entry);
      } else {
        if (_globalId < _globalValues.length) {
          final replaced = _globalValues[_globalId];
          if (replaced != null) {
            _localValues[replaced.context]![replaced.localId] = null;
          }
          _globalValues[_globalId] = entry;
        } else {
          _globalValues.add(entry);
        }
        _globalId++;
        if (_globalId == capacity) {
          _globalId = 0;
        }
      }
    }
    return value;
  }

  String _readCompactOptimized(BitInput input, List<String> partition) {
    final encoded = input.readNBitUnsigned(_bitWidth(partition.length + 1));
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

  String _readCharacters(BitInput input, int length, {List<int>? restrictedCharacters}) {
    final codePoints = <int>[];
    for (var index = 0; index < length; index++) {
      BigInt codePoint;
      if (restrictedCharacters == null) {
        codePoint = input.readUnsignedInteger();
      } else {
        final encoded = input.readNBitUnsigned(restrictedCharacters.length.bitLength);
        if (encoded > restrictedCharacters.length) {
          throw const FormatException('Invalid restricted-character-set code');
        }
        codePoint = encoded == restrictedCharacters.length
            ? input.readUnsignedInteger()
            : BigInt.from(restrictedCharacters[encoded]);
      }
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
    final compactId = input.readNBitUnsigned(_bitWidth(partition.length));
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

final class _GlobalValue {
  const _GlobalValue(this.value, this.context, this.localId);

  final String value;
  final ExiQName context;
  final int localId;
}

int _bitWidth(int valueCount) {
  if (valueCount <= 1) {
    return 0;
  }
  return (valueCount - 1).bitLength;
}
