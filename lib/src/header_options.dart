import 'bit_input.dart';
import 'model.dart';
import 'options.dart';
import 'schema.dart';
import 'string_table.dart';

/// Decodes the schema-informed EXI body defined by Appendix C.
///
/// The options schema is fixed by the EXI specification, so materializing a
/// general-purpose XML Schema model here would add complexity without changing
/// the wire grammar.
final class HeaderOptionsDecoder {
  HeaderOptionsDecoder(this._input) : _strings = ExiStringTable(schema: _optionsSchema);

  final BitInput _input;
  final ExiStringTable _strings;
  final _wildcardGrammars = <ExiQName, _SkippedElementGrammar>{};

  var _alignment = ExiAlignment.bitPacked;
  var _compression = false;
  var _fragment = false;
  var _strict = false;
  var _selfContained = false;
  var _comments = false;
  var _processingInstructions = false;
  var _dtd = false;
  var _prefixes = false;
  var _lexicalValues = false;
  var _blockSize = 1000000;
  int? _valueMaxLength;
  int? _valuePartitionCapacity;
  var _schemaId = ExiSchemaId.absent;
  final _datatypeRepresentationMap = <ExiDatatypeRepresentationMap>[];
  final _metadata = <ExiHeaderMetadata>[];

  ExiOptions decode() {
    // The strict schema-informed document grammar contains SE(header) and the
    // SE(*) fallback. The declared global element has event code zero.
    if (_input.readBits(1) != 0) {
      throw const FormatException('EXI options document must start with exi:header');
    }

    _readSequence(_headerChildren, _readHeaderChild);
    return ExiOptions(
      alignment: _alignment,
      compression: _compression,
      fragment: _fragment,
      strict: _strict,
      selfContained: _selfContained,
      fidelity: ExiFidelityOptions(
        comments: _comments,
        processingInstructions: _processingInstructions,
        dtd: _dtd,
        prefixes: _prefixes,
        lexicalValues: _lexicalValues,
      ),
      blockSize: _blockSize,
      valueMaxLength: _valueMaxLength,
      valuePartitionCapacity: _valuePartitionCapacity,
      schemaId: _schemaId,
      datatypeRepresentationMap: List.unmodifiable(_datatypeRepresentationMap),
      metadata: List.unmodifiable(_metadata),
    );
  }

  void _readHeaderChild(_OptionElement element) {
    switch (element) {
      case _OptionElement.lesscommon:
        _readSequence(_lessCommonChildren, _readLessCommonChild);
      case _OptionElement.common:
        _readSequence(_commonChildren, _readCommonChild);
      case _OptionElement.strict:
        _strict = true;
      default:
        throw StateError('Invalid header child: $element');
    }
  }

  void _readLessCommonChild(_OptionElement element) {
    switch (element) {
      case _OptionElement.uncommon:
        _readSequence(_uncommonChildren, _readUncommonChild);
      case _OptionElement.preserve:
        _readSequence(_preserveChildren, _readPreserveChild);
      case _OptionElement.blockSize:
        _blockSize = _readUnsignedInt(minimum: 1, name: 'blockSize');
      default:
        throw StateError('Invalid lesscommon child: $element');
    }
  }

  void _readUncommonChild(_OptionElement element) {
    switch (element) {
      case _OptionElement.metadata:
        _readMetadata();
      case _OptionElement.alignment:
        final selected = _input.readBits(1);
        _alignment = selected == 0 ? ExiAlignment.byteAligned : ExiAlignment.preCompression;
      case _OptionElement.selfContained:
        _selfContained = true;
      case _OptionElement.valueMaxLength:
        _valueMaxLength = _readUnsignedInt(name: 'valueMaxLength');
      case _OptionElement.valuePartitionCapacity:
        _valuePartitionCapacity = _readUnsignedInt(name: 'valuePartitionCapacity');
      case _OptionElement.datatypeRepresentationMap:
        _readDatatypeRepresentationMap();
      default:
        throw StateError('Invalid uncommon child: $element');
    }
  }

  void _readPreserveChild(_OptionElement element) {
    switch (element) {
      case _OptionElement.dtd:
        _dtd = true;
      case _OptionElement.prefixes:
        _prefixes = true;
      case _OptionElement.lexicalValues:
        _lexicalValues = true;
      case _OptionElement.comments:
        _comments = true;
      case _OptionElement.pis:
        _processingInstructions = true;
      default:
        throw StateError('Invalid preserve child: $element');
    }
  }

  void _readCommonChild(_OptionElement element) {
    switch (element) {
      case _OptionElement.compression:
        _compression = true;
      case _OptionElement.fragment:
        _fragment = true;
      case _OptionElement.schemaId:
        _readSchemaId();
      default:
        throw StateError('Invalid common child: $element');
    }
  }

  void _readSequence(List<_OptionElement> children, void Function(_OptionElement element) readChild) {
    var position = 0;
    while (true) {
      final choiceCount = children.length - position + 1;
      final selected = _input.readBits(_bitWidth(choiceCount));
      if (selected >= choiceCount) {
        throw const FormatException('Invalid event code in EXI options document');
      }
      if (selected == choiceCount - 1) {
        return;
      }

      final childIndex = position + selected;
      final child = children[childIndex];
      readChild(child);
      position = child == _OptionElement.datatypeRepresentationMap || child == _OptionElement.metadata
          ? childIndex
          : childIndex + 1;
    }
  }

  int _readUnsignedInt({int minimum = 0, required String name}) {
    final value = _input.readUnsignedInteger();
    if (value > BigInt.from(0xffffffff)) {
      throw FormatException('$name exceeds the XML Schema unsignedInt range');
    }
    final result = value.toInt();
    if (result < minimum) {
      throw FormatException('$name must be at least $minimum');
    }
    return result;
  }

  void _readSchemaId() {
    final eventCode = _input.readBits(1);
    if (eventCode == 1) {
      final isNilled = _input.readBit() == 1;
      if (isNilled) {
        _schemaId = ExiSchemaId.schemaLess;
        return;
      }
    }

    final marker = _input.readUnsignedInteger();
    if (marker < BigInt.two || marker > BigInt.from(0x7fffffff)) {
      throw const FormatException('Invalid schemaId string representation');
    }
    final length = marker.toInt() - 2;
    final codePoints = <int>[];
    for (var index = 0; index < length; index++) {
      final codePoint = _input.readUnsignedInteger();
      if (codePoint > BigInt.from(0x10ffff)) {
        throw const FormatException('Invalid Unicode code point in schemaId');
      }
      final value = codePoint.toInt();
      if (value >= 0xd800 && value <= 0xdfff) {
        throw const FormatException('Unicode surrogate is not valid in schemaId');
      }
      codePoints.add(value);
    }
    final value = String.fromCharCodes(codePoints);
    _schemaId = value.isEmpty ? ExiSchemaId.builtInTypes : ExiSchemaId.named(value);
  }

  void _readDatatypeRepresentationMap() {
    final schemaDatatype = _readWildcardElement();
    if (schemaDatatype.uri == _exiUri) {
      throw const FormatException('EXI datatype-map source must match the ##other namespace wildcard');
    }
    final representationName = _readWildcardElement();
    final representation = _builtInRepresentation(representationName);
    _datatypeRepresentationMap.add(
      representation == null
          ? ExiDatatypeRepresentationMap.userDefined(
              schemaDatatype: schemaDatatype,
              representationName: representationName,
            )
          : ExiDatatypeRepresentationMap(schemaDatatype: schemaDatatype, representation: representation),
    );
  }

  void _readMetadata() {
    final events = <ExiEvent>[];
    final name = _readWildcardElement(null, events);
    if (name.uri == _exiUri) {
      throw const FormatException('EXI header metadata must match the ##other namespace wildcard');
    }
    _metadata.add(ExiHeaderMetadata(name: name, events: List.unmodifiable(events)));
  }

  ExiQName _readWildcardElement([ExiQName? knownName, List<ExiEvent>? events]) {
    final name = knownName ?? _strings.readQName(_input);
    events?.add(ExiStartElement(name));
    final grammar = _wildcardGrammars.putIfAbsent(name, _SkippedElementGrammar.new);
    var state = grammar.startTag;
    while (true) {
      final production = state.read(_input);
      switch (production.event) {
        case _SkippedEvent.endElement:
          events?.add(ExiEndElement(name));
          return name;
        case _SkippedEvent.attribute:
          final attributeName = production.name ?? _strings.readQName(_input);
          final value = _readSkippedAttributeValue(attributeName);
          events?.add(ExiAttribute(attributeName, value));
          state.learn(_SkippedProduction(_SkippedEvent.attribute, attributeName));
        case _SkippedEvent.startElement:
          final childName = production.name ?? _strings.readQName(_input);
          _readWildcardElement(childName, events);
          state.learn(_SkippedProduction(_SkippedEvent.startElement, childName));
          state = grammar.elementContent;
        case _SkippedEvent.characters:
          events?.add(ExiCharacters(_strings.readValue(_input, name)));
          state.learn(production);
          state = grammar.elementContent;
      }
    }
  }

  String _readSkippedAttributeValue(ExiQName name) {
    if (name == _xsiTypeName) {
      return _strings.readQName(_input).toString();
    }
    return _strings.readValue(_input, name);
  }
}

enum _OptionElement {
  lesscommon,
  uncommon,
  metadata,
  alignment,
  selfContained,
  valueMaxLength,
  valuePartitionCapacity,
  datatypeRepresentationMap,
  preserve,
  dtd,
  prefixes,
  lexicalValues,
  comments,
  pis,
  blockSize,
  common,
  compression,
  fragment,
  schemaId,
  strict,
}

const _headerChildren = [_OptionElement.lesscommon, _OptionElement.common, _OptionElement.strict];

const _lessCommonChildren = [_OptionElement.uncommon, _OptionElement.preserve, _OptionElement.blockSize];

const _uncommonChildren = [
  _OptionElement.metadata,
  _OptionElement.alignment,
  _OptionElement.selfContained,
  _OptionElement.valueMaxLength,
  _OptionElement.valuePartitionCapacity,
  _OptionElement.datatypeRepresentationMap,
];

const _preserveChildren = [
  _OptionElement.dtd,
  _OptionElement.prefixes,
  _OptionElement.lexicalValues,
  _OptionElement.comments,
  _OptionElement.pis,
];

const _commonChildren = [_OptionElement.compression, _OptionElement.fragment, _OptionElement.schemaId];

int _bitWidth(int valueCount) {
  if (valueCount <= 1) {
    return 0;
  }
  return (valueCount - 1).bitLength;
}

ExiDatatype? _builtInRepresentation(ExiQName name) {
  if (name.uri != _exiUri) {
    return null;
  }
  return switch (name.localName) {
    'base64Binary' => ExiDatatype.base64Binary,
    'hexBinary' => ExiDatatype.hexBinary,
    'boolean' => ExiDatatype.boolean,
    'decimal' => ExiDatatype.decimal,
    'double' => ExiDatatype.float,
    'integer' => ExiDatatype.integer,
    'string' => ExiDatatype.string,
    'dateTime' => ExiDatatype.dateTime,
    'date' => ExiDatatype.date,
    'time' => ExiDatatype.time,
    'gYearMonth' => ExiDatatype.gYearMonth,
    'gMonthDay' => ExiDatatype.gMonthDay,
    'gYear' => ExiDatatype.gYear,
    'gMonth' => ExiDatatype.gMonth,
    'gDay' => ExiDatatype.gDay,
    _ => null,
  };
}

const _exiUri = 'http://www.w3.org/2009/exi';
const _xsiTypeName = ExiQName(uri: 'http://www.w3.org/2001/XMLSchema-instance', localName: 'type', prefix: 'xsi');

final _optionsSchema = ExiSchema(
  id: 'http://www.w3.org/2009/exi/options',
  globalElements: const [],
  stringTableQNames: [for (final localName in _optionsSchemaLocalNames) ExiQName(uri: _exiUri, localName: localName)],
  stringTableUris: const {_exiUri},
);

const _optionsSchemaLocalNames = [
  'alignment',
  'base64Binary',
  'blockSize',
  'boolean',
  'byte',
  'comments',
  'common',
  'compression',
  'datatypeRepresentationMap',
  'date',
  'dateTime',
  'decimal',
  'double',
  'dtd',
  'fragment',
  'gDay',
  'gMonth',
  'gMonthDay',
  'gYear',
  'gYearMonth',
  'header',
  'hexBinary',
  'ieeeBinary32',
  'ieeeBinary64',
  'integer',
  'lesscommon',
  'lexicalValues',
  'pis',
  'pre-compress',
  'prefixes',
  'preserve',
  'schemaId',
  'selfContained',
  'string',
  'strict',
  'time',
  'uncommon',
  'valueMaxLength',
  'valuePartitionCapacity',
];

enum _SkippedEvent { endElement, attribute, startElement, characters }

final class _SkippedElementGrammar {
  final startTag = _SkippedGrammarState(startTag: true);
  final elementContent = _SkippedGrammarState(startTag: false);
}

final class _SkippedGrammarState {
  _SkippedGrammarState({required this.startTag});

  final bool startTag;
  final _learned = <_SkippedProduction>[];

  _SkippedProduction read(BitInput input) {
    final firstPartCount = _learned.length + (startTag ? 1 : 2);
    final firstPart = input.readNBitUnsigned(_bitWidth(firstPartCount));
    if (firstPart >= firstPartCount) {
      throw const FormatException('Invalid event code in EXI datatype-map QName element');
    }
    if (firstPart < _learned.length) {
      return _learned[firstPart];
    }
    if (!startTag && firstPart == _learned.length) {
      return const _SkippedProduction(_SkippedEvent.endElement);
    }

    final undeclared = startTag
        ? const [
            _SkippedEvent.endElement,
            _SkippedEvent.attribute,
            _SkippedEvent.startElement,
            _SkippedEvent.characters,
          ]
        : const [_SkippedEvent.startElement, _SkippedEvent.characters];
    final secondPart = input.readNBitUnsigned(_bitWidth(undeclared.length));
    if (secondPart >= undeclared.length) {
      throw const FormatException('Invalid event code in EXI datatype-map QName element');
    }
    return _SkippedProduction(undeclared[secondPart]);
  }

  void learn(_SkippedProduction production) {
    if (production.event == _SkippedEvent.endElement ||
        _learned.any((candidate) => candidate.event == production.event && candidate.name == production.name)) {
      return;
    }
    _learned.insert(0, production);
  }
}

final class _SkippedProduction {
  const _SkippedProduction(this.event, [this.name]);

  final _SkippedEvent event;
  final ExiQName? name;
}
