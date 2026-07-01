import 'dart:typed_data';

import 'bit_input.dart';
import 'model.dart';
import 'options.dart';
import 'string_table.dart';

const _cookie = [0x24, 0x45, 0x58, 0x49];

final class ExiDecoder {
  ExiDecoder({this.options = const ExiOptions()}) {
    if (options.compression) {
      throw UnsupportedError('EXI compression is not supported yet');
    }
    if (options.alignment != ExiAlignment.bitPacked) {
      throw UnsupportedError('${options.alignment.name} alignment is not supported yet');
    }
    if (options.selfContained) {
      throw UnsupportedError('Self-contained EXI elements are not supported yet');
    }
    if (options.strict &&
        (options.fidelity.comments ||
            options.fidelity.processingInstructions ||
            options.fidelity.dtd ||
            options.fidelity.prefixes)) {
      throw ArgumentError('Strict EXI mode cannot preserve comments, PIs, DTDs, or prefixes');
    }
  }

  final ExiOptions options;

  ExiDocument decode(Uint8List bytes) {
    final hasCookie = bytes.length >= _cookie.length && _matchesCookie(bytes);
    final input = BitInput(bytes, byteOffset: hasCookie ? _cookie.length : 0);
    final header = _readHeader(input, hasCookie: hasCookie);
    final state = _DecoderState(input, options);
    final events = state.decode();
    return ExiDocument(header: header, events: events);
  }

  bool _matchesCookie(Uint8List bytes) {
    for (var index = 0; index < _cookie.length; index++) {
      if (bytes[index] != _cookie[index]) {
        return false;
      }
    }
    return true;
  }

  ExiHeader _readHeader(BitInput input, {required bool hasCookie}) {
    if (input.readBits(2) != 2) {
      throw const FormatException('Invalid EXI distinguishing bits');
    }

    final hasOptions = input.readBit() == 1;
    final isPreview = input.readBit() == 1;
    var version = 1;
    int part;
    do {
      part = input.readBits(4);
      version += part;
    } while (part == 15);

    if (isPreview) {
      throw UnsupportedError('Preview EXI versions are not supported');
    }
    if (version != 1) {
      throw UnsupportedError('EXI version $version is not supported');
    }
    if (hasOptions) {
      throw UnsupportedError('In-band EXI options are not supported in this decoder stage');
    }

    return ExiHeader(hasCookie: hasCookie, hasOptions: hasOptions, isPreview: isPreview, version: version);
  }
}

final class _DecoderState {
  _DecoderState(this.input, this.options) : strings = ExiStringTable(preservePrefixes: options.fidelity.prefixes);

  final BitInput input;
  final ExiOptions options;
  final ExiStringTable strings;
  final Map<ExiQName, _ElementGrammar> grammars = {};
  final List<_Production> _fragmentElements = [];
  final List<ExiEvent> events = [];

  List<ExiEvent> decode() {
    events.add(const ExiStartDocument());
    if (options.fragment) {
      _decodeFragment();
    } else {
      _decodeDocument();
    }
    events.add(const ExiEndDocument());
    return events;
  }

  void _decodeDocument() {
    while (true) {
      final production = _readDocumentContent();
      switch (production.type) {
        case _EventType.startElement:
          _decodeElement(strings.readQName(input));
          _decodeDocumentEnd();
          return;
        case _EventType.documentType:
          _decodeDocumentType();
        case _EventType.comment:
          events.add(ExiComment(strings.readString(input)));
        case _EventType.processingInstruction:
          _decodeProcessingInstruction();
        default:
          throw StateError('Invalid document-content production');
      }
    }
  }

  void _decodeDocumentEnd() {
    while (true) {
      final production = _readDocumentEnd();
      switch (production.type) {
        case _EventType.endDocument:
          return;
        case _EventType.comment:
          events.add(ExiComment(strings.readString(input)));
        case _EventType.processingInstruction:
          _decodeProcessingInstruction();
        default:
          throw StateError('Invalid document-end production');
      }
    }
  }

  void _decodeFragment() {
    while (true) {
      final production = _readFragmentContent();
      switch (production.type) {
        case _EventType.endDocument:
          return;
        case _EventType.startElement:
          final name = production.name ?? strings.readQName(input);
          _learn(_fragmentElements, _Production(_EventType.startElement, name));
          _decodeElement(name);
        case _EventType.comment:
          events.add(ExiComment(strings.readString(input)));
        case _EventType.processingInstruction:
          _decodeProcessingInstruction();
        default:
          throw StateError('Invalid fragment production');
      }
    }
  }

  void _decodeElement(ExiQName initialName) {
    var elementName = initialName;
    final startEventIndex = events.length;
    events.add(ExiStartElement(elementName));

    final grammar = grammars.putIfAbsent(elementName, () => _ElementGrammar(options));
    var current = grammar.startTag;

    while (true) {
      final production = current.readProduction(input);
      switch (production.type) {
        case _EventType.endElement:
          current.learn(production);
          events.add(ExiEndElement(elementName));
          return;
        case _EventType.attribute:
          final name = production.name ?? strings.readQName(input);
          current.learn(_Production(_EventType.attribute, name));
          events.add(ExiAttribute(name, strings.readValue(input, name)));
        case _EventType.startElement:
          final name = production.name ?? strings.readQName(input);
          current.learn(_Production(_EventType.startElement, name));
          _decodeElement(name);
          current = grammar.elementContent;
        case _EventType.characters:
          current.learn(production);
          events.add(ExiCharacters(strings.readValue(input, elementName)));
          current = grammar.elementContent;
        case _EventType.namespaceDeclaration:
          final uri = strings.readString(input);
          final prefix = strings.readString(input);
          final localElementNamespace = input.readBit() == 1;
          strings.addPrefix(uri, prefix);
          if (localElementNamespace) {
            if (uri != elementName.uri) {
              throw const FormatException('Local namespace URI does not match the start-element URI');
            }
            elementName = ExiQName(uri: elementName.uri, localName: elementName.localName, prefix: prefix);
            events[startEventIndex] = ExiStartElement(elementName);
          }
          events.add(ExiNamespaceDeclaration(uri: uri, prefix: prefix, localElementNamespace: localElementNamespace));
        case _EventType.entityReference:
          events.add(ExiEntityReference(strings.readString(input)));
          current = grammar.elementContent;
        case _EventType.comment:
          events.add(ExiComment(strings.readString(input)));
          current = grammar.elementContent;
        case _EventType.processingInstruction:
          _decodeProcessingInstruction();
          current = grammar.elementContent;
        default:
          throw StateError('Invalid element production');
      }
    }
  }

  void _decodeProcessingInstruction() {
    events.add(ExiProcessingInstruction(strings.readString(input), strings.readString(input)));
  }

  void _decodeDocumentType() {
    events.add(
      ExiDocumentType(
        name: strings.readString(input),
        publicId: strings.readString(input),
        systemId: strings.readString(input),
        text: strings.readString(input),
      ),
    );
  }

  _Production _readDocumentContent() {
    final hasOther = options.fidelity.dtd || options.fidelity.comments || options.fidelity.processingInstructions;
    final first = input.readBits(_bitWidth(hasOther ? 2 : 1));
    if (first == 0) {
      return const _Production(_EventType.startElement);
    }
    if (!hasOther || first != 1) {
      throw const FormatException('Invalid document-content event code');
    }

    final hasCommentOrPi = options.fidelity.comments || options.fidelity.processingInstructions;
    final secondCount = (options.fidelity.dtd ? 1 : 0) + (hasCommentOrPi ? 1 : 0);
    final second = input.readBits(_bitWidth(secondCount));
    if (options.fidelity.dtd && second == 0) {
      return const _Production(_EventType.documentType);
    }
    return _readCommentOrPi();
  }

  _Production _readDocumentEnd() {
    final hasCommentOrPi = options.fidelity.comments || options.fidelity.processingInstructions;
    final first = input.readBits(_bitWidth(hasCommentOrPi ? 2 : 1));
    if (first == 0) {
      return const _Production(_EventType.endDocument);
    }
    return _readCommentOrPi();
  }

  _Production _readFragmentContent() {
    final hasCommentOrPi = options.fidelity.comments || options.fidelity.processingInstructions;
    final firstCount = _fragmentElements.length + 2 + (hasCommentOrPi ? 1 : 0);
    final first = input.readBits(_bitWidth(firstCount));
    if (first >= firstCount) {
      throw const FormatException('Invalid fragment event code');
    }
    if (first < _fragmentElements.length) {
      return _fragmentElements[first];
    }
    if (first == _fragmentElements.length) {
      return const _Production(_EventType.startElement);
    }
    if (first == _fragmentElements.length + 1) {
      return const _Production(_EventType.endDocument);
    }
    return _readCommentOrPi();
  }

  _Production _readCommentOrPi() {
    final choices = <_Production>[
      if (options.fidelity.comments) const _Production(_EventType.comment),
      if (options.fidelity.processingInstructions) const _Production(_EventType.processingInstruction),
    ];
    if (choices.isEmpty) {
      throw const FormatException('Comment/PI event is disabled');
    }
    final selected = input.readBits(_bitWidth(choices.length));
    if (selected >= choices.length) {
      throw const FormatException('Invalid comment/PI event code');
    }
    return choices[selected];
  }
}

enum _EventType {
  endDocument,
  startElement,
  endElement,
  attribute,
  characters,
  namespaceDeclaration,
  comment,
  processingInstruction,
  documentType,
  entityReference,
}

final class _Production {
  const _Production(this.type, [this.name]);

  final _EventType type;
  final ExiQName? name;

  bool matches(_Production other) => type == other.type && name == other.name;
}

final class _GrammarState {
  _GrammarState.startTag(this.options) : kind = _GrammarStateKind.startTag;

  _GrammarState.elementContent(this.options) : kind = _GrammarStateKind.elementContent;

  final ExiOptions options;
  final _GrammarStateKind kind;
  final List<_Production> _learned = [];

  _Production readProduction(BitInput input) {
    final firstPartCount = _learned.length + (kind == _GrammarStateKind.startTag ? 1 : 2);
    final firstPart = input.readBits(_bitWidth(firstPartCount));
    if (firstPart >= firstPartCount) {
      throw const FormatException('Invalid EXI event-code first part');
    }
    if (firstPart < _learned.length) {
      return _learned[firstPart];
    }

    if (kind == _GrammarStateKind.elementContent && firstPart == _learned.length) {
      return const _Production(_EventType.endElement);
    }

    final hasCommentOrPi = options.fidelity.comments || options.fidelity.processingInstructions;
    final undeclared = <_Production?>[
      if (kind == _GrammarStateKind.startTag) ...[
        const _Production(_EventType.endElement),
        const _Production(_EventType.attribute),
        if (options.fidelity.prefixes) const _Production(_EventType.namespaceDeclaration),
      ],
      const _Production(_EventType.startElement),
      const _Production(_EventType.characters),
      if (options.fidelity.dtd) const _Production(_EventType.entityReference),
      if (hasCommentOrPi) null,
    ];
    final secondPart = input.readBits(_bitWidth(undeclared.length));
    if (secondPart >= undeclared.length) {
      throw const FormatException('Invalid EXI event-code second part');
    }
    final production = undeclared[secondPart];
    if (production != null) {
      return production;
    }

    final commentOrPi = <_Production>[
      if (options.fidelity.comments) const _Production(_EventType.comment),
      if (options.fidelity.processingInstructions) const _Production(_EventType.processingInstruction),
    ];
    final thirdPart = input.readBits(_bitWidth(commentOrPi.length));
    if (thirdPart >= commentOrPi.length) {
      throw const FormatException('Invalid EXI event-code third part');
    }
    return commentOrPi[thirdPart];
  }

  void learn(_Production production) {
    if (production.type != _EventType.endElement &&
        production.type != _EventType.attribute &&
        production.type != _EventType.startElement &&
        production.type != _EventType.characters) {
      return;
    }
    if (_learned.any((candidate) => candidate.matches(production))) {
      return;
    }
    _learned.insert(0, production);
  }
}

enum _GrammarStateKind { startTag, elementContent }

final class _ElementGrammar {
  _ElementGrammar(ExiOptions options)
    : startTag = _GrammarState.startTag(options),
      elementContent = _GrammarState.elementContent(options);

  final _GrammarState startTag;
  final _GrammarState elementContent;
}

void _learn(List<_Production> productions, _Production production) {
  if (productions.any((candidate) => candidate.matches(production))) {
    return;
  }
  productions.insert(0, production);
}

int _bitWidth(int valueCount) {
  if (valueCount <= 1) {
    return 0;
  }
  return (valueCount - 1).bitLength;
}
