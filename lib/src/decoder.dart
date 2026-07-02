import 'dart:typed_data';

import 'bit_input.dart';
import 'header_options.dart';
import 'model.dart';
import 'options.dart';
import 'schema.dart';
import 'string_table.dart';
import 'value_decoder.dart';

const _cookie = [0x24, 0x45, 0x58, 0x49];
const _xsiNilName = ExiQName(uri: 'http://www.w3.org/2001/XMLSchema-instance', localName: 'nil', prefix: 'xsi');
const _xsiTypeName = ExiQName(uri: 'http://www.w3.org/2001/XMLSchema-instance', localName: 'type', prefix: 'xsi');

final class ExiDecoder {
  ExiDecoder({this.options = const ExiOptions(), this.schemaResolver}) {
    _validateOptions(options);
  }

  final ExiOptions options;
  final ExiSchemaResolver? schemaResolver;

  ExiDocument decode(Uint8List bytes) {
    final hasCookie = bytes.length >= _cookie.length && _matchesCookie(bytes);
    final input = BitInput(bytes, byteOffset: hasCookie ? _cookie.length : 0);
    final parsedHeader = _readHeader(input, hasCookie: hasCookie);
    _validateOptions(parsedHeader.options);
    final schema = _resolveSchema(parsedHeader.options.schemaId);
    if (schema != null && !parsedHeader.options.strict) {
      throw UnsupportedError('Non-strict schema-informed grammars are not supported yet');
    }
    if (schema != null && parsedHeader.options.fragment) {
      throw UnsupportedError('Schema-informed fragments are not supported yet');
    }
    final state = _DecoderState(input, parsedHeader.options, schema);
    final events = state.decode();
    return ExiDocument(header: parsedHeader.header, events: events, options: parsedHeader.options);
  }

  ExiSchema? _resolveSchema(ExiSchemaId schemaId) {
    if (schemaId.kind != ExiSchemaIdKind.named) {
      return null;
    }
    final id = schemaId.value!;
    final schema = schemaResolver?.call(id);
    if (schema == null) {
      throw ExiSchemaNotFoundException(id);
    }
    return schema;
  }

  bool _matchesCookie(Uint8List bytes) {
    for (var index = 0; index < _cookie.length; index++) {
      if (bytes[index] != _cookie[index]) {
        return false;
      }
    }
    return true;
  }

  ({ExiHeader header, ExiOptions options}) _readHeader(BitInput input, {required bool hasCookie}) {
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
    final effectiveOptions = hasOptions ? HeaderOptionsDecoder(input).decode() : options;
    if (effectiveOptions.compression || effectiveOptions.alignment != ExiAlignment.bitPacked) {
      input.alignToByte();
    }
    if (effectiveOptions.alignment == ExiAlignment.byteAligned) {
      input.useByteAlignment();
    }
    return (
      header: ExiHeader(hasCookie: hasCookie, hasOptions: hasOptions, isPreview: isPreview, version: version),
      options: effectiveOptions,
    );
  }
}

void _validateOptions(ExiOptions options) {
  if (options.compression && options.alignment != ExiAlignment.bitPacked) {
    throw ArgumentError('EXI compression and alignment options are mutually exclusive');
  }
  if (options.selfContained &&
      (options.compression || options.alignment == ExiAlignment.preCompression || options.strict)) {
    throw ArgumentError('Self-contained mode cannot be combined with compression, pre-compression, or strict mode');
  }
  if (options.compression) {
    throw UnsupportedError('EXI compression is not supported yet');
  }
  if (options.alignment == ExiAlignment.preCompression) {
    throw UnsupportedError('${options.alignment.name} alignment is not supported yet');
  }
  if (options.selfContained) {
    throw UnsupportedError('Self-contained EXI elements are not supported yet');
  }
  if (options.blockSize < 1) {
    throw ArgumentError.value(options.blockSize, 'blockSize', 'must be at least 1');
  }
  if (options.valueMaxLength case final value? when value < 0) {
    throw ArgumentError.value(value, 'valueMaxLength', 'must be non-negative');
  }
  if (options.valuePartitionCapacity case final value? when value < 0) {
    throw ArgumentError.value(value, 'valuePartitionCapacity', 'must be non-negative');
  }
  if (options.strict &&
      (options.fidelity.comments ||
          options.fidelity.processingInstructions ||
          options.fidelity.dtd ||
          options.fidelity.prefixes)) {
    throw ArgumentError('Strict EXI mode cannot preserve comments, PIs, DTDs, or prefixes');
  }
}

final class _DecoderState {
  _DecoderState(this.input, this.options, this.schema)
    : strings = ExiStringTable(
        preservePrefixes: options.fidelity.prefixes,
        valueMaxLength: options.valueMaxLength,
        valuePartitionCapacity: options.valuePartitionCapacity,
      );

  final BitInput input;
  final ExiOptions options;
  final ExiSchema? schema;
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
    final currentSchema = schema;
    if (currentSchema != null) {
      final globals = [...currentSchema.globalElements]
        ..sort((left, right) {
          final localNameOrder = left.name.localName.compareTo(right.name.localName);
          return localNameOrder != 0 ? localNameOrder : left.name.uri.compareTo(right.name.uri);
        });
      final selected = input.readNBitUnsigned(_bitWidth(globals.length + 1));
      if (selected > globals.length) {
        throw const FormatException('Invalid schema-informed document event code');
      }
      if (selected < globals.length) {
        _decodeElement(globals[selected].name, declaration: globals[selected]);
      } else {
        _decodeElement(strings.readQName(input));
      }
      _decodeDocumentEnd();
      return;
    }

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

  void _decodeElement(ExiQName initialName, {ExiElementDeclaration? declaration}) {
    var elementName = initialName;
    final startEventIndex = events.length;
    events.add(ExiStartElement(elementName));
    if (declaration != null) {
      _decodeDeclaredContent(elementName, declaration);
      return;
    }

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
          final globalDeclaration = schema?.globalElements.where((element) => element.name == name).firstOrNull;
          _decodeElement(name, declaration: globalDeclaration);
          current = grammar.elementContent;
        case _EventType.characters:
          current.learn(production);
          events.add(ExiCharacters(strings.readValue(input, elementName)));
          current = grammar.elementContent;
        case _EventType.namespaceDeclaration:
          final uri = strings.readString(input);
          final prefix = strings.readString(input);
          final localElementNamespace = input.readNBitUnsigned(1) == 1;
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

  void _decodeDeclaredContent(
    ExiQName elementName,
    ExiElementDeclaration declaration, {
    bool allowSpecialAttributes = true,
  }) {
    final datatype = declaration.datatype;
    final attributes = [...declaration.attributes]
      ..sort((left, right) {
        final localNameOrder = left.name.localName.compareTo(right.name.localName);
        return localNameOrder != 0 ? localNameOrder : left.name.uri.compareTo(right.name.uri);
      });
    var attributeIndex = 0;
    var content = declaration.content ?? _legacyContent(declaration.children);
    var nilSeen = false;
    var nilled = false;
    var specialAttributesAllowed = allowSpecialAttributes;
    final seenAttributes = <ExiQName>{};

    while (true) {
      final candidates = <_DeclaredEvent>[];
      var contentIsReachable = true;
      for (var index = attributeIndex; index < attributes.length; index++) {
        final attribute = attributes[index];
        candidates.add(_DeclaredEvent.attribute(index, attribute));
        if (attribute.required) {
          contentIsReachable = false;
          break;
        }
      }
      if (contentIsReachable) {
        if (declaration.anyAttribute) {
          final namespaces = declaration.attributeWildcardNamespaces;
          if (namespaces == null) {
            candidates.add(const _DeclaredEvent.wildcardAttribute(null));
          } else {
            for (final uri in namespaces.toList()..sort()) {
              candidates.add(_DeclaredEvent.wildcardAttribute(uri));
            }
          }
        }
        if (datatype != null) {
          candidates.add(nilled ? const _DeclaredEvent.end() : const _DeclaredEvent.typedCharacters());
        } else {
          for (final child in _leadingElements(content)) {
            candidates.add(_DeclaredEvent.element(child));
          }
          if (_isNullable(content)) {
            candidates.add(const _DeclaredEvent.end());
          }
          if (declaration.mixed && !nilled) {
            candidates.add(const _DeclaredEvent.characters());
          }
        }
      }
      final canReadType = declaration.typeAlternatives.isNotEmpty && specialAttributesAllowed;
      final canReadNil = declaration.nillable && !nilSeen && specialAttributesAllowed;
      final specialCount = (canReadType ? 1 : 0) + (canReadNil ? 1 : 0);
      final candidateCount = candidates.length + (specialCount > 0 ? 1 : 0);
      if (candidateCount == 0) {
        throw const FormatException('Schema grammar has no valid next event');
      }

      final selected = input.readNBitUnsigned(_bitWidth(candidateCount));
      if (specialCount > 0 && selected == candidates.length) {
        final special = input.readNBitUnsigned(_bitWidth(specialCount));
        if (canReadType && special == 0) {
          final targetName = ExiQName(uri: strings.readString(input), localName: strings.readString(input));
          final target = declaration.typeAlternatives[targetName];
          if (target == null) {
            throw FormatException('Unknown xsi:type "${targetName.localName}"');
          }
          final lexicalValue = targetName.uri.isEmpty
              ? targetName.localName
              : '{${targetName.uri}}${targetName.localName}';
          events.add(ExiAttribute(_xsiTypeName, lexicalValue));
          _decodeDeclaredContent(elementName, target, allowSpecialAttributes: false);
          return;
        }
        final nilIndex = canReadType ? 1 : 0;
        if (!canReadNil || special != nilIndex) {
          throw const FormatException('Invalid strict schema special-attribute event code');
        }
        final value = ExiValueDecoder(input, strings).read(ExiDatatype.boolean, _xsiNilName);
        events.add(ExiAttribute(_xsiNilName, value));
        nilSeen = true;
        if (value == 'true') {
          content = const ExiEmptyParticle();
          nilled = true;
        }
        continue;
      }
      if (selected >= candidates.length) {
        throw const FormatException('Invalid schema-informed element event code');
      }
      final event = candidates[selected];
      switch (event.kind) {
        case _DeclaredEventKind.attribute:
          specialAttributesAllowed = false;
          final attribute = event.attribute!;
          attributeIndex = event.attributeIndex! + 1;
          final value = ExiValueDecoder(input, strings).read(attribute.datatype, attribute.name);
          if (!seenAttributes.add(attribute.name)) {
            throw const FormatException('Duplicate schema attribute');
          }
          events.add(ExiAttribute(attribute.name, value));
        case _DeclaredEventKind.wildcardAttribute:
          specialAttributesAllowed = false;
          attributeIndex = attributes.length;
          final wildcardUri = event.wildcardUri;
          final name = wildcardUri == null
              ? strings.readQName(input)
              : ExiQName(uri: wildcardUri, localName: strings.readString(input));
          if (declaration.attributeWildcardExcludedNamespaces?.contains(name.uri) ?? false) {
            throw const FormatException('Attribute QName does not match the schema wildcard namespace constraint');
          }
          if (!seenAttributes.add(name)) {
            throw const FormatException('Duplicate wildcard attribute');
          }
          final globalAttribute = schema?.globalAttributes.where((attribute) => attribute.name == name).firstOrNull;
          final value = switch (declaration.attributeProcessContents) {
            ExiProcessContents.skip => strings.readValue(input, name),
            ExiProcessContents.lax =>
              globalAttribute == null
                  ? strings.readValue(input, name)
                  : ExiValueDecoder(input, strings).read(globalAttribute.datatype, name),
            ExiProcessContents.strict =>
              globalAttribute == null
                  ? throw FormatException('No global attribute declaration for wildcard QName "${name.localName}"')
                  : ExiValueDecoder(input, strings).read(globalAttribute.datatype, name),
          };
          events.add(ExiAttribute(name, value));
        case _DeclaredEventKind.element:
          specialAttributesAllowed = false;
          attributeIndex = attributes.length;
          final child = event.element!;
          final derivative = _derive(content, child);
          if (derivative == null) {
            throw const FormatException('Element does not match the schema particle');
          }
          content = derivative;
          _decodeElement(child.name, declaration: child);
        case _DeclaredEventKind.characters:
          specialAttributesAllowed = false;
          attributeIndex = attributes.length;
          events.add(ExiCharacters(strings.readValue(input, elementName)));
        case _DeclaredEventKind.typedCharacters:
          specialAttributesAllowed = false;
          events.add(ExiCharacters(ExiValueDecoder(input, strings).read(datatype!, elementName)));
          events.add(ExiEndElement(elementName));
          return;
        case _DeclaredEventKind.end:
          specialAttributesAllowed = false;
          events.add(ExiEndElement(elementName));
          return;
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
    final first = input.readNBitUnsigned(_bitWidth(hasOther ? 2 : 1));
    if (first == 0) {
      return const _Production(_EventType.startElement);
    }
    if (!hasOther || first != 1) {
      throw const FormatException('Invalid document-content event code');
    }

    final hasCommentOrPi = options.fidelity.comments || options.fidelity.processingInstructions;
    final secondCount = (options.fidelity.dtd ? 1 : 0) + (hasCommentOrPi ? 1 : 0);
    final second = input.readNBitUnsigned(_bitWidth(secondCount));
    if (options.fidelity.dtd && second == 0) {
      return const _Production(_EventType.documentType);
    }
    return _readCommentOrPi();
  }

  _Production _readDocumentEnd() {
    final hasCommentOrPi = options.fidelity.comments || options.fidelity.processingInstructions;
    final first = input.readNBitUnsigned(_bitWidth(hasCommentOrPi ? 2 : 1));
    if (first == 0) {
      return const _Production(_EventType.endDocument);
    }
    return _readCommentOrPi();
  }

  _Production _readFragmentContent() {
    final hasCommentOrPi = options.fidelity.comments || options.fidelity.processingInstructions;
    final firstCount = _fragmentElements.length + 2 + (hasCommentOrPi ? 1 : 0);
    final first = input.readNBitUnsigned(_bitWidth(firstCount));
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
    final selected = input.readNBitUnsigned(_bitWidth(choices.length));
    if (selected >= choices.length) {
      throw const FormatException('Invalid comment/PI event code');
    }
    return choices[selected];
  }
}

enum _DeclaredEventKind { attribute, wildcardAttribute, element, end, characters, typedCharacters }

final class _DeclaredEvent {
  const _DeclaredEvent.attribute(this.attributeIndex, this.attribute)
    : kind = _DeclaredEventKind.attribute,
      element = null,
      wildcardUri = null;

  const _DeclaredEvent.element(this.element)
    : kind = _DeclaredEventKind.element,
      attributeIndex = null,
      attribute = null,
      wildcardUri = null;

  const _DeclaredEvent.wildcardAttribute(this.wildcardUri)
    : kind = _DeclaredEventKind.wildcardAttribute,
      attributeIndex = null,
      attribute = null,
      element = null;

  const _DeclaredEvent.end()
    : kind = _DeclaredEventKind.end,
      attributeIndex = null,
      attribute = null,
      element = null,
      wildcardUri = null;

  const _DeclaredEvent.characters()
    : kind = _DeclaredEventKind.characters,
      attributeIndex = null,
      attribute = null,
      element = null,
      wildcardUri = null;

  const _DeclaredEvent.typedCharacters()
    : kind = _DeclaredEventKind.typedCharacters,
      attributeIndex = null,
      attribute = null,
      element = null,
      wildcardUri = null;

  final _DeclaredEventKind kind;
  final int? attributeIndex;
  final ExiAttributeDeclaration? attribute;
  final ExiElementDeclaration? element;
  final String? wildcardUri;
}

ExiParticle _legacyContent(List<ExiElementDeclaration> children) {
  if (children.isEmpty) {
    return const ExiEmptyParticle();
  }
  return ExiSequenceParticle([for (final child in children) ExiElementParticle(child)]);
}

bool _isNullable(ExiParticle particle) {
  return switch (particle) {
    ExiEmptyParticle() => true,
    ExiElementParticle(:final minOccurs) => minOccurs == 0,
    ExiSequenceParticle(:final particles) => particles.every(_isNullable),
    ExiChoiceParticle(:final particles) => particles.any(_isNullable),
    ExiAllParticle(:final particles) => particles.every(_isNullable),
    ExiRepeatedParticle(:final particle, :final minOccurs) => minOccurs == 0 || _isNullable(particle),
  };
}

List<ExiElementDeclaration> _leadingElements(ExiParticle particle) {
  final result = <ExiElementDeclaration>[];
  void collect(ExiParticle current) {
    switch (current) {
      case ExiEmptyParticle():
        return;
      case ExiElementParticle(:final element, :final maxOccurs):
        if (maxOccurs != 0) {
          if (result.any((candidate) => candidate.name == element.name)) {
            throw UnsupportedError('Ambiguous schema particles with the same leading QName are not supported yet');
          }
          result.add(element);
        }
      case ExiSequenceParticle(:final particles):
        for (final child in particles) {
          collect(child);
          if (!_isNullable(child)) {
            break;
          }
        }
      case ExiChoiceParticle(:final particles):
        for (final child in particles) {
          collect(child);
        }
      case ExiAllParticle(:final particles):
        for (final child in particles) {
          collect(child);
        }
      case ExiRepeatedParticle(:final particle, :final maxOccurs):
        if (maxOccurs != 0) {
          collect(particle);
        }
    }
  }

  collect(particle);
  return result;
}

ExiParticle? _derive(ExiParticle particle, ExiElementDeclaration selected) {
  switch (particle) {
    case ExiEmptyParticle():
      return null;
    case ExiElementParticle(:final element, :final minOccurs, :final maxOccurs):
      if (!identical(element, selected)) {
        return null;
      }
      final remainingMin = minOccurs > 0 ? minOccurs - 1 : 0;
      final remainingMax = maxOccurs == null ? null : maxOccurs - 1;
      if (remainingMax == 0) {
        return const ExiEmptyParticle();
      }
      return ExiElementParticle(element, minOccurs: remainingMin, maxOccurs: remainingMax);
    case ExiSequenceParticle(:final particles):
      final alternatives = <ExiParticle>[];
      for (var index = 0; index < particles.length; index++) {
        final derivative = _derive(particles[index], selected);
        if (derivative != null) {
          alternatives.add(_sequence([derivative, ...particles.skip(index + 1)]));
        }
        if (!_isNullable(particles[index])) {
          break;
        }
      }
      return _choice(alternatives);
    case ExiChoiceParticle(:final particles):
      final alternatives = <ExiParticle>[];
      for (final child in particles) {
        final derivative = _derive(child, selected);
        if (derivative != null) {
          alternatives.add(derivative);
        }
      }
      return _choice(alternatives);
    case ExiAllParticle(:final particles):
      for (var index = 0; index < particles.length; index++) {
        final derivative = _derive(particles[index], selected);
        if (derivative == null) {
          continue;
        }
        final remaining = [...particles];
        if (derivative is ExiEmptyParticle) {
          remaining.removeAt(index);
        } else {
          remaining[index] = derivative;
        }
        return ExiAllParticle(remaining);
      }
      return null;
    case ExiRepeatedParticle(:final particle, :final minOccurs, :final maxOccurs):
      if (maxOccurs == 0) {
        return null;
      }
      if (_isNullable(particle)) {
        throw UnsupportedError('Repeating a nullable schema particle is not supported yet');
      }
      final derivative = _derive(particle, selected);
      if (derivative == null) {
        return null;
      }
      final remainingMin = minOccurs > 0 ? minOccurs - 1 : 0;
      final remainingMax = maxOccurs == null ? null : maxOccurs - 1;
      final remainder = remainingMax == 0
          ? const ExiEmptyParticle()
          : ExiRepeatedParticle(particle, minOccurs: remainingMin, maxOccurs: remainingMax);
      return _sequence([derivative, remainder]);
  }
}

ExiParticle _sequence(List<ExiParticle> particles) {
  final flattened = <ExiParticle>[];
  for (final particle in particles) {
    switch (particle) {
      case ExiEmptyParticle():
        break;
      case ExiSequenceParticle(:final particles):
        flattened.addAll(particles);
      default:
        flattened.add(particle);
    }
  }
  if (flattened.isEmpty) {
    return const ExiEmptyParticle();
  }
  if (flattened.length == 1) {
    return flattened.single;
  }
  return ExiSequenceParticle(flattened);
}

ExiParticle? _choice(List<ExiParticle> particles) {
  if (particles.isEmpty) {
    return null;
  }
  if (particles.length == 1) {
    return particles.single;
  }
  return ExiChoiceParticle(particles);
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
    final firstPart = input.readNBitUnsigned(_bitWidth(firstPartCount));
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
    final secondPart = input.readNBitUnsigned(_bitWidth(undeclared.length));
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
    final thirdPart = input.readNBitUnsigned(_bitWidth(commentOrPi.length));
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
