import 'bit_input.dart';
import 'options.dart';

/// Decodes the schema-informed EXI body defined by Appendix C.
///
/// The options schema is fixed by the EXI specification, so materializing a
/// general-purpose XML Schema model here would add complexity without changing
/// the wire grammar.
final class HeaderOptionsDecoder {
  HeaderOptionsDecoder(this._input);

  final BitInput _input;

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
        throw UnsupportedError('User-defined EXI header metadata is not supported yet');
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
        throw UnsupportedError('Datatype representation maps are not supported yet');
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
        throw UnsupportedError('In-band schemaId is not supported yet');
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
      readChild(children[childIndex]);
      position = childIndex + 1;
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
