import 'dart:typed_data';

import 'package:archive/archive.dart' show Inflate, InputMemoryStream;

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
    var input = BitInput(bytes, byteOffset: hasCookie ? _cookie.length : 0);
    final parsedHeader = _readHeader(input, hasCookie: hasCookie);
    _validateOptions(parsedHeader.options);
    _CompressedStreams? compressedStreams;
    if (parsedHeader.options.compression) {
      compressedStreams = _CompressedStreams(input.readRemainingBytes());
      input = compressedStreams.read();
    }
    final schema = _resolveSchema(parsedHeader.options.schemaId);
    final state = _DecoderState(input, parsedHeader.options, schema, compressedStreams: compressedStreams);
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
    if (effectiveOptions.compression ||
        effectiveOptions.alignment == ExiAlignment.byteAligned ||
        effectiveOptions.alignment == ExiAlignment.preCompression) {
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
  if (options.blockSize < 1) {
    throw ArgumentError.value(options.blockSize, 'blockSize', 'must be at least 1');
  }
  if (options.valueMaxLength case final value? when value < 0) {
    throw ArgumentError.value(value, 'valueMaxLength', 'must be non-negative');
  }
  if (options.valuePartitionCapacity case final value? when value < 0) {
    throw ArgumentError.value(value, 'valuePartitionCapacity', 'must be non-negative');
  }
  final mappedDatatypes = <ExiQName>{};
  const supportedRepresentations = {
    ExiDatatype.string,
    ExiDatatype.boolean,
    ExiDatatype.decimal,
    ExiDatatype.float,
    ExiDatatype.integer,
    ExiDatatype.base64Binary,
    ExiDatatype.hexBinary,
    ExiDatatype.dateTime,
    ExiDatatype.date,
    ExiDatatype.time,
    ExiDatatype.gYear,
    ExiDatatype.gYearMonth,
    ExiDatatype.gMonth,
    ExiDatatype.gMonthDay,
    ExiDatatype.gDay,
  };
  for (final mapping in options.datatypeRepresentationMap) {
    if (!mappedDatatypes.add(mapping.schemaDatatype)) {
      throw ArgumentError.value(
        mapping.schemaDatatype,
        'datatypeRepresentationMap',
        'contains duplicate schema datatype mappings',
      );
    }
    final representation = mapping.representation;
    if (representation != null && !supportedRepresentations.contains(representation)) {
      throw ArgumentError.value(
        representation,
        'datatypeRepresentationMap',
        'is not an EXI datatype representation identifier',
      );
    }
  }
  if (options.strict &&
      (options.fidelity.comments ||
          options.fidelity.processingInstructions ||
          options.fidelity.dtd ||
          options.fidelity.prefixes)) {
    throw ArgumentError('Strict EXI mode cannot preserve comments, PIs, DTDs, or prefixes');
  }
}

ExiStringTable _newStringTable(ExiOptions options, ExiSchema? schema) => ExiStringTable(
  preservePrefixes: options.fidelity.prefixes,
  valueMaxLength: options.valueMaxLength,
  valuePartitionCapacity: options.valuePartitionCapacity,
  schema: schema,
);

final class _DecoderState {
  _DecoderState(this.input, this.options, this.schema, {this._compressedStreams})
    : strings = _newStringTable(options, schema);

  BitInput input;
  final ExiOptions options;
  final ExiSchema? schema;
  final _CompressedStreams? _compressedStreams;
  ExiStringTable strings;
  Map<ExiQName, _ElementGrammar> grammars = {};
  List<_Production> _fragmentElements = [];
  late final List<_FragmentElementGroup> _fragmentDeclarations = _collectFragmentDeclarations(schema);
  late final List<_FragmentAttributeGroup> _fragmentAttributes = _collectFragmentAttributes(
    schema,
    _fragmentDeclarations,
  );
  final List<ExiEvent> events = [];
  final Map<ExiQName, List<_DeferredValue>> _deferredChannels = {};
  var _deferredValueCount = 0;
  var _deferredMarkerCount = 0;
  var _deferredEventStartIndex = 0;

  List<ExiEvent> decode() {
    events.add(const ExiStartDocument());
    if (options.fragment) {
      _decodeFragment();
    } else {
      _decodeDocument();
    }
    events.add(const ExiEndDocument());
    _readDeferredValueChannels();
    return events;
  }

  String _readValue(ExiQName channel, String Function() read) {
    if (!_usesChannels) {
      return read();
    }
    _deferredValueCount++;
    final marker = '\u0000exi-deferred:${_deferredMarkerCount++}';
    _deferredChannels.putIfAbsent(channel, () => []).add(_DeferredValue(marker, read));
    if (_deferredValueCount == options.blockSize) {
      final values = _finishDeferredBlock();
      if (options.compression && _compressedStreams!.hasRemaining) {
        input = _compressedStreams.read();
      }
      return values[marker]!;
    }
    return marker;
  }

  void _readDeferredValueChannels() {
    if (!_usesChannels || _deferredValueCount == 0) {
      return;
    }
    _finishDeferredBlock();
  }

  Map<String, String> _finishDeferredBlock() {
    final values = <String, String>{};
    final channels = _deferredChannels.values.toList();
    if (_deferredValueCount > 100) {
      final smallChannels = channels.where((channel) => channel.length <= 100);
      final largeChannels = channels.where((channel) => channel.length > 100);
      if (smallChannels.isNotEmpty) {
        if (options.compression) {
          input = _compressedStreams!.read();
        }
        for (final channel in smallChannels) {
          _readDeferredChannel(channel, values);
        }
      }
      for (final channel in largeChannels) {
        if (options.compression) {
          input = _compressedStreams!.read();
        }
        _readDeferredChannel(channel, values);
      }
    } else {
      for (final channel in channels) {
        _readDeferredChannel(channel, values);
      }
    }
    _replaceDeferredValues(values);
    _deferredChannels.clear();
    _deferredValueCount = 0;
    return values;
  }

  void _replaceDeferredValues(Map<String, String> values) {
    for (var index = _deferredEventStartIndex; index < events.length; index++) {
      switch (events[index]) {
        case ExiAttribute(:final name, :final value) when values.containsKey(value):
          events[index] = ExiAttribute(name, values[value]!);
        case ExiCharacters(:final value) when values.containsKey(value):
          events[index] = ExiCharacters(values[value]!);
        default:
          break;
      }
    }
    _deferredEventStartIndex = events.length;
  }

  void _readDeferredChannel(List<_DeferredValue> channel, Map<String, String> values) {
    for (final deferred in channel) {
      values[deferred.marker] = deferred.read();
    }
  }

  bool get _usesChannels => options.compression || options.alignment == ExiAlignment.preCompression;

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
        final name = strings.readQName(input);
        final declaration = globals.where((element) => element.name == name).firstOrNull;
        _decodeElement(name, declaration: declaration);
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
          if (schema == null) {
            _learn(_fragmentElements, _Production(_EventType.startElement, name));
            _decodeElement(name);
            continue;
          }
          if (production.name == null) {
            final declaration = schema!.globalElements.where((element) => element.name == name).firstOrNull;
            _decodeElement(name, declaration: declaration);
            continue;
          }
          final group = _fragmentDeclarations.where((element) => element.name == name).firstOrNull;
          if (group == null) {
            throw const FormatException('Unknown schema-informed fragment element');
          }
          _decodeFragmentElement(group);
        case _EventType.comment:
          events.add(ExiComment(strings.readString(input)));
        case _EventType.processingInstruction:
          _decodeProcessingInstruction();
        default:
          throw StateError('Invalid fragment production');
      }
    }
  }

  void _decodeFragmentElement(_FragmentElementGroup group) {
    final declaration = group.declaration;
    if (declaration != null) {
      _decodeElement(group.name, declaration: declaration);
      return;
    }
    _decodeRelaxedFragmentElement(group.name);
  }

  void _decodeRelaxedFragmentElement(ExiQName elementName) {
    events.add(ExiStartElement(elementName));
    final seenAttributes = <ExiQName>{};
    var attributesAllowed = true;

    while (true) {
      final attributeCount = attributesAllowed ? _fragmentAttributes.length + 1 : 0;
      final selected = input.readNBitUnsigned(_bitWidth(attributeCount + _fragmentDeclarations.length + 3));
      if (attributesAllowed && selected < _fragmentAttributes.length) {
        final attribute = _fragmentAttributes[selected];
        if (!seenAttributes.add(attribute.name)) {
          throw const FormatException('Duplicate relaxed fragment attribute');
        }
        final declaration = attribute.declaration;
        final value = declaration == null
            ? _readValue(attribute.name, () => strings.readValue(input, attribute.name))
            : _readValue(attribute.name, () => _readTypedAttribute(declaration));
        events.add(ExiAttribute(attribute.name, value));
        continue;
      }
      if (attributesAllowed && selected == _fragmentAttributes.length) {
        final name = strings.readQName(input);
        if (name == _xsiTypeName || name == _xsiNilName) {
          throw const FormatException('xsi:type and xsi:nil cannot use the relaxed wildcard attribute');
        }
        if (!seenAttributes.add(name)) {
          throw const FormatException('Duplicate relaxed fragment attribute');
        }
        final declaration = schema?.globalAttributes.where((attribute) => attribute.name == name).firstOrNull;
        final value = declaration == null
            ? _readValue(name, () => strings.readValue(input, name))
            : _readValue(name, () => _readTypedAttribute(declaration));
        events.add(ExiAttribute(name, value));
        continue;
      }

      attributesAllowed = false;
      final contentIndex = selected - attributeCount;
      if (contentIndex < _fragmentDeclarations.length) {
        _decodeFragmentElement(_fragmentDeclarations[contentIndex]);
        continue;
      }
      if (contentIndex == _fragmentDeclarations.length) {
        final name = strings.readQName(input);
        final declaration = schema?.globalElements.where((element) => element.name == name).firstOrNull;
        _decodeElement(name, declaration: declaration);
        continue;
      }
      if (contentIndex == _fragmentDeclarations.length + 1) {
        events.add(ExiEndElement(elementName));
        return;
      }
      if (contentIndex == _fragmentDeclarations.length + 2) {
        events.add(ExiCharacters(_readValue(elementName, () => strings.readValue(input, elementName))));
        continue;
      }
      throw const FormatException('Invalid relaxed element-fragment event code');
    }
  }

  String _readTypedAttribute(ExiAttributeDeclaration attribute) =>
      ExiValueDecoder(
        input,
        strings,
        preserveLexicalValues: options.fidelity.lexicalValues,
        datatypeRepresentationMap: options.datatypeRepresentationMap,
      ).read(
        attribute.datatype,
        attribute.name,
        listItemDatatype: attribute.listItemDatatype,
        schemaDatatypeHierarchy: attribute.schemaDatatypeHierarchy,
        listItemSchemaDatatypeHierarchy: attribute.listItemSchemaDatatypeHierarchy,
        restrictedCharacters: attribute.restrictedCharacters,
        listItemRestrictedCharacters: attribute.listItemRestrictedCharacters,
        enumerationValues: attribute.enumerationValues,
        booleanPattern: attribute.booleanPattern,
        listItemBooleanPattern: attribute.listItemBooleanPattern,
        integerMinInclusive: attribute.integerMinInclusive,
        integerMaxInclusive: attribute.integerMaxInclusive,
      );

  void _decodeElement(ExiQName initialName, {ExiElementDeclaration? declaration}) {
    final startEventIndex = events.length;
    events.add(ExiStartElement(initialName));
    if (declaration != null) {
      _decodeDeclaredContent(initialName, declaration, startEventIndex: startEventIndex);
      return;
    }
    _decodeBuiltInContent(initialName, startEventIndex);
  }

  void _decodeBuiltInContent(ExiQName initialName, int startEventIndex) {
    var elementName = initialName;
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
          events.add(ExiAttribute(name, _readValue(name, () => strings.readValue(input, name))));
        case _EventType.startElement:
          final name = production.name ?? strings.readQName(input);
          current.learn(_Production(_EventType.startElement, name));
          final globalDeclaration = schema?.globalElements.where((element) => element.name == name).firstOrNull;
          _decodeElement(name, declaration: globalDeclaration);
          current = grammar.elementContent;
        case _EventType.characters:
          current.learn(production);
          events.add(ExiCharacters(_readValue(elementName, () => strings.readValue(input, elementName))));
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
        case _EventType.selfContained:
          _decodeSelfContained(elementName, startEventIndex);
          return;
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

  void _decodeSelfContained(ExiQName elementName, int startEventIndex) {
    final outerStrings = strings;
    final outerGrammars = grammars;
    final outerFragmentElements = _fragmentElements;
    try {
      strings = _newStringTable(options, schema)..addQName(elementName);
      grammars = {};
      _fragmentElements = [];
      input.alignToByte();
      _decodeBuiltInContent(elementName, startEventIndex);
      input.alignToByte();
    } finally {
      strings = outerStrings;
      grammars = outerGrammars;
      _fragmentElements = outerFragmentElements;
    }
  }

  void _decodeDeclaredSelfContained(ExiQName elementName, ExiElementDeclaration declaration, int startEventIndex) {
    final outerStrings = strings;
    final outerGrammars = grammars;
    final outerFragmentElements = _fragmentElements;
    try {
      strings = _newStringTable(options, schema)..addQName(elementName);
      grammars = {};
      _fragmentElements = [];
      input.alignToByte();
      _decodeDeclaredContent(elementName, declaration, startEventIndex: startEventIndex);
      input.alignToByte();
    } finally {
      strings = outerStrings;
      grammars = outerGrammars;
      _fragmentElements = outerFragmentElements;
    }
  }

  void _decodeDeclaredContent(
    ExiQName elementName,
    ExiElementDeclaration declaration, {
    required int startEventIndex,
    bool allowSpecialAttributes = true,
  }) {
    var currentElementName = elementName;
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
    var contentStarted = false;
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
          for (final child in _leadingElementEvents(content)) {
            candidates.add(child);
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
      final hasSecondLevel = !options.strict || specialCount > 0;
      final candidateCount = candidates.length + (hasSecondLevel ? 1 : 0);
      if (candidateCount == 0) {
        throw const FormatException('Schema grammar has no valid next event');
      }

      final selected = input.readNBitUnsigned(_bitWidth(candidateCount));
      if (selected == candidates.length && !options.strict) {
        final deviation = _readNonStrictDeviation(
          hasFirstLevelEnd: candidates.any((event) => event.kind == _DeclaredEventKind.end),
          atEntry: !contentStarted && attributeIndex == 0 && seenAttributes.isEmpty,
          inAttributePhase: !contentStarted,
        );
        switch (deviation) {
          case _NonStrictDeviation.endElement:
            events.add(ExiEndElement(currentElementName));
            return;
          case _NonStrictDeviation.characters:
            specialAttributesAllowed = false;
            contentStarted = true;
            attributeIndex = attributes.length;
            events.add(
              ExiCharacters(_readValue(currentElementName, () => strings.readValue(input, currentElementName))),
            );
            continue;
          case _NonStrictDeviation.startElement:
            specialAttributesAllowed = false;
            contentStarted = true;
            attributeIndex = attributes.length;
            final name = strings.readQName(input);
            final globalDeclaration = schema?.globalElements.where((element) => element.name == name).firstOrNull;
            _decodeElement(name, declaration: globalDeclaration);
            continue;
          case _NonStrictDeviation.attribute:
            specialAttributesAllowed = false;
            final name = strings.readQName(input);
            if (!seenAttributes.add(name)) {
              throw const FormatException('Duplicate non-strict schema attribute');
            }
            final globalAttribute = schema?.globalAttributes.where((attribute) => attribute.name == name).firstOrNull;
            final value = globalAttribute == null
                ? _readValue(name, () => strings.readValue(input, name))
                : _readValue(
                    name,
                    () =>
                        ExiValueDecoder(
                          input,
                          strings,
                          preserveLexicalValues: options.fidelity.lexicalValues,
                          datatypeRepresentationMap: options.datatypeRepresentationMap,
                        ).read(
                          globalAttribute.datatype,
                          name,
                          listItemDatatype: globalAttribute.listItemDatatype,
                          schemaDatatypeHierarchy: globalAttribute.schemaDatatypeHierarchy,
                          listItemSchemaDatatypeHierarchy: globalAttribute.listItemSchemaDatatypeHierarchy,
                          restrictedCharacters: globalAttribute.restrictedCharacters,
                          listItemRestrictedCharacters: globalAttribute.listItemRestrictedCharacters,
                          enumerationValues: globalAttribute.enumerationValues,
                          booleanPattern: globalAttribute.booleanPattern,
                          listItemBooleanPattern: globalAttribute.listItemBooleanPattern,
                          integerMinInclusive: globalAttribute.integerMinInclusive,
                          integerMaxInclusive: globalAttribute.integerMaxInclusive,
                        ),
                  );
            events.add(ExiAttribute(name, value));
            continue;
          case _NonStrictDeviation.untypedAttribute:
            specialAttributesAllowed = false;
            final declaredAttributes = candidates.where((event) => event.kind == _DeclaredEventKind.attribute).toList();
            final selectedAttribute = input.readNBitUnsigned(_bitWidth(declaredAttributes.length + 1));
            if (selectedAttribute > declaredAttributes.length) {
              throw const FormatException('Invalid non-strict untyped-attribute event code');
            }
            final ExiQName name;
            if (selectedAttribute < declaredAttributes.length) {
              final event = declaredAttributes[selectedAttribute];
              attributeIndex = event.attributeIndex! + 1;
              name = event.attribute!.name;
            } else {
              name = strings.readQName(input);
            }
            if (!seenAttributes.add(name)) {
              throw const FormatException('Duplicate non-strict schema attribute');
            }
            events.add(ExiAttribute(name, _readValue(name, () => strings.readValue(input, name))));
            continue;
          case _NonStrictDeviation.xsiType:
            final (:targetName, :lexicalValue) = _readXsiType(declaration);
            events.add(ExiAttribute(_xsiTypeName, lexicalValue));
            final target = declaration.typeAlternatives[targetName];
            if (target != null) {
              _decodeDeclaredContent(
                currentElementName,
                target,
                startEventIndex: startEventIndex,
                allowSpecialAttributes: false,
              );
              return;
            }
            specialAttributesAllowed = false;
            continue;
          case _NonStrictDeviation.xsiNil:
            final value = ExiValueDecoder(
              input,
              strings,
              preserveLexicalValues: options.fidelity.lexicalValues,
              datatypeRepresentationMap: options.datatypeRepresentationMap,
            ).read(ExiDatatype.boolean, _xsiNilName);
            final normalized = value.trim();
            if (normalized != 'true' && normalized != '1' && normalized != 'false' && normalized != '0') {
              throw FormatException('Invalid xsi:nil value "$value"');
            }
            events.add(ExiAttribute(_xsiNilName, value));
            nilSeen = true;
            if (normalized == 'true' || normalized == '1') {
              content = const ExiEmptyParticle();
              nilled = true;
            }
            continue;
          case _NonStrictDeviation.entityReference:
            specialAttributesAllowed = false;
            contentStarted = true;
            attributeIndex = attributes.length;
            events.add(ExiEntityReference(strings.readString(input)));
            continue;
          case _NonStrictDeviation.commentOrPi:
            specialAttributesAllowed = false;
            contentStarted = true;
            attributeIndex = attributes.length;
            final production = _readCommentOrPi();
            if (production.type == _EventType.comment) {
              events.add(ExiComment(strings.readString(input)));
            } else {
              _decodeProcessingInstruction();
            }
            continue;
          case _NonStrictDeviation.namespaceDeclaration:
            final uri = strings.readString(input);
            final prefix = strings.readString(input);
            final localElementNamespace = input.readNBitUnsigned(1) == 1;
            strings.addPrefix(uri, prefix);
            if (localElementNamespace) {
              if (uri != currentElementName.uri) {
                throw const FormatException('Local namespace URI does not match the start-element URI');
              }
              currentElementName = ExiQName(
                uri: currentElementName.uri,
                localName: currentElementName.localName,
                prefix: prefix,
              );
              events[startEventIndex] = ExiStartElement(currentElementName);
            }
            events.add(ExiNamespaceDeclaration(uri: uri, prefix: prefix, localElementNamespace: localElementNamespace));
            continue;
          case _NonStrictDeviation.selfContained:
            _decodeDeclaredSelfContained(currentElementName, declaration, startEventIndex);
            return;
        }
      }
      if (specialCount > 0 && selected == candidates.length) {
        final special = input.readNBitUnsigned(_bitWidth(specialCount));
        if (canReadType && special == 0) {
          final (:targetName, :lexicalValue) = _readXsiType(declaration);
          final target = declaration.typeAlternatives[targetName];
          if (target == null) {
            throw FormatException('Unknown xsi:type "${targetName.localName}"');
          }
          events.add(ExiAttribute(_xsiTypeName, lexicalValue));
          _decodeDeclaredContent(
            currentElementName,
            target,
            startEventIndex: startEventIndex,
            allowSpecialAttributes: false,
          );
          return;
        }
        final nilIndex = canReadType ? 1 : 0;
        if (!canReadNil || special != nilIndex) {
          throw const FormatException('Invalid strict schema special-attribute event code');
        }
        final value = ExiValueDecoder(
          input,
          strings,
          preserveLexicalValues: options.fidelity.lexicalValues,
          datatypeRepresentationMap: options.datatypeRepresentationMap,
        ).read(ExiDatatype.boolean, _xsiNilName);
        events.add(ExiAttribute(_xsiNilName, value));
        nilSeen = true;
        final normalized = value.trim();
        if (normalized != 'true' && normalized != '1' && normalized != 'false' && normalized != '0') {
          throw FormatException('Invalid xsi:nil value "$value"');
        }
        if (normalized == 'true' || normalized == '1') {
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
          final value = _readValue(
            attribute.name,
            () =>
                ExiValueDecoder(
                  input,
                  strings,
                  preserveLexicalValues: options.fidelity.lexicalValues,
                  datatypeRepresentationMap: options.datatypeRepresentationMap,
                ).read(
                  attribute.datatype,
                  attribute.name,
                  listItemDatatype: attribute.listItemDatatype,
                  schemaDatatypeHierarchy: attribute.schemaDatatypeHierarchy,
                  listItemSchemaDatatypeHierarchy: attribute.listItemSchemaDatatypeHierarchy,
                  restrictedCharacters: attribute.restrictedCharacters,
                  listItemRestrictedCharacters: attribute.listItemRestrictedCharacters,
                  enumerationValues: attribute.enumerationValues,
                  booleanPattern: attribute.booleanPattern,
                  listItemBooleanPattern: attribute.listItemBooleanPattern,
                  integerMinInclusive: attribute.integerMinInclusive,
                  integerMaxInclusive: attribute.integerMaxInclusive,
                ),
          );
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
          final value = globalAttribute == null
              ? _readValue(name, () => strings.readValue(input, name))
              : _readValue(
                  name,
                  () =>
                      ExiValueDecoder(
                        input,
                        strings,
                        preserveLexicalValues: options.fidelity.lexicalValues,
                        datatypeRepresentationMap: options.datatypeRepresentationMap,
                      ).read(
                        globalAttribute.datatype,
                        name,
                        listItemDatatype: globalAttribute.listItemDatatype,
                        schemaDatatypeHierarchy: globalAttribute.schemaDatatypeHierarchy,
                        listItemSchemaDatatypeHierarchy: globalAttribute.listItemSchemaDatatypeHierarchy,
                        restrictedCharacters: globalAttribute.restrictedCharacters,
                        listItemRestrictedCharacters: globalAttribute.listItemRestrictedCharacters,
                        enumerationValues: globalAttribute.enumerationValues,
                        booleanPattern: globalAttribute.booleanPattern,
                        listItemBooleanPattern: globalAttribute.listItemBooleanPattern,
                        integerMinInclusive: globalAttribute.integerMinInclusive,
                        integerMaxInclusive: globalAttribute.integerMaxInclusive,
                      ),
                );
          events.add(ExiAttribute(name, value));
        case _DeclaredEventKind.element:
          specialAttributesAllowed = false;
          contentStarted = true;
          attributeIndex = attributes.length;
          final child = event.element!;
          final derivative = _derive(content, child);
          if (derivative == null) {
            throw const FormatException('Element does not match the schema particle');
          }
          content = derivative;
          _decodeElement(child.name, declaration: child);
        case _DeclaredEventKind.wildcardElement:
          specialAttributesAllowed = false;
          contentStarted = true;
          attributeIndex = attributes.length;
          final wildcard = event.wildcardParticle!;
          final wildcardUri = event.wildcardUri;
          final name = wildcardUri == null
              ? strings.readQName(input)
              : ExiQName(uri: wildcardUri, localName: strings.readString(input));
          if (wildcard.excludedNamespaces?.contains(name.uri) ?? false) {
            throw const FormatException('Element QName does not match the schema wildcard namespace constraint');
          }
          final derivative = _derive(content, wildcard);
          if (derivative == null) {
            throw const FormatException('Element does not match the schema wildcard particle');
          }
          content = derivative;
          final globalElement = schema?.globalElements.where((element) => element.name == name).firstOrNull;
          _decodeElement(name, declaration: globalElement);
        case _DeclaredEventKind.characters:
          specialAttributesAllowed = false;
          contentStarted = true;
          attributeIndex = attributes.length;
          events.add(ExiCharacters(_readValue(currentElementName, () => strings.readValue(input, currentElementName))));
        case _DeclaredEventKind.typedCharacters:
          specialAttributesAllowed = false;
          events.add(
            ExiCharacters(
              _readValue(
                currentElementName,
                () =>
                    ExiValueDecoder(
                      input,
                      strings,
                      preserveLexicalValues: options.fidelity.lexicalValues,
                      datatypeRepresentationMap: options.datatypeRepresentationMap,
                    ).read(
                      datatype!,
                      currentElementName,
                      listItemDatatype: declaration.listItemDatatype,
                      schemaDatatypeHierarchy: declaration.schemaDatatypeHierarchy,
                      listItemSchemaDatatypeHierarchy: declaration.listItemSchemaDatatypeHierarchy,
                      restrictedCharacters: declaration.restrictedCharacters,
                      listItemRestrictedCharacters: declaration.listItemRestrictedCharacters,
                      enumerationValues: declaration.enumerationValues,
                      booleanPattern: declaration.booleanPattern,
                      listItemBooleanPattern: declaration.listItemBooleanPattern,
                      integerMinInclusive: declaration.integerMinInclusive,
                      integerMaxInclusive: declaration.integerMaxInclusive,
                    ),
              ),
            ),
          );
          events.add(ExiEndElement(currentElementName));
          return;
        case _DeclaredEventKind.end:
          specialAttributesAllowed = false;
          events.add(ExiEndElement(currentElementName));
          return;
      }
    }
  }

  _NonStrictDeviation _readNonStrictDeviation({
    required bool hasFirstLevelEnd,
    required bool atEntry,
    required bool inAttributePhase,
  }) {
    final productions = <_NonStrictDeviation>[
      if (!hasFirstLevelEnd) _NonStrictDeviation.endElement,
      if (atEntry) ...[_NonStrictDeviation.xsiType, _NonStrictDeviation.xsiNil],
      if (inAttributePhase) ...[_NonStrictDeviation.attribute, _NonStrictDeviation.untypedAttribute],
      if (atEntry && options.fidelity.prefixes) _NonStrictDeviation.namespaceDeclaration,
      if (atEntry && options.selfContained) _NonStrictDeviation.selfContained,
      _NonStrictDeviation.startElement,
      _NonStrictDeviation.characters,
      if (options.fidelity.dtd) _NonStrictDeviation.entityReference,
      if (options.fidelity.comments || options.fidelity.processingInstructions) _NonStrictDeviation.commentOrPi,
    ];
    final selected = input.readNBitUnsigned(_bitWidth(productions.length));
    if (selected >= productions.length) {
      throw const FormatException('Invalid non-strict schema event-code second part');
    }
    return productions[selected];
  }

  ({ExiQName targetName, String lexicalValue}) _readXsiType(ExiElementDeclaration declaration) {
    if (!options.fidelity.lexicalValues) {
      final name = strings.readQName(input);
      return (targetName: name, lexicalValue: name.toString());
    }

    final lexical = strings.readValue(input, _xsiTypeName);
    final normalized = lexical.trim();
    final separator = normalized.indexOf(':');
    if (normalized.isEmpty ||
        separator != normalized.lastIndexOf(':') ||
        separator == 0 ||
        separator == normalized.length - 1) {
      throw FormatException('Invalid lexical xsi:type QName "$lexical"');
    }
    final localName = separator == -1 ? normalized : normalized.substring(separator + 1);
    final matches = declaration.typeAlternatives.keys.where((name) => name.localName == localName).toList();
    if (matches.length != 1) {
      throw FormatException('Cannot resolve lexical xsi:type QName "$lexical"');
    }
    return (targetName: matches.single, lexicalValue: lexical);
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
    final declaredCount = schema == null ? _fragmentElements.length : _fragmentDeclarations.length;
    final firstCount = declaredCount + 2 + (hasCommentOrPi ? 1 : 0);
    final first = input.readNBitUnsigned(_bitWidth(firstCount));
    if (first >= firstCount) {
      throw const FormatException('Invalid fragment event code');
    }
    if (first < declaredCount) {
      return schema == null
          ? _fragmentElements[first]
          : _Production(_EventType.startElement, _fragmentDeclarations[first].name);
    }
    if (first == declaredCount) {
      return const _Production(_EventType.startElement);
    }
    if (first == declaredCount + 1) {
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

enum _DeclaredEventKind { attribute, wildcardAttribute, element, wildcardElement, end, characters, typedCharacters }

enum _NonStrictDeviation {
  endElement,
  xsiType,
  xsiNil,
  attribute,
  untypedAttribute,
  namespaceDeclaration,
  selfContained,
  startElement,
  characters,
  entityReference,
  commentOrPi,
}

final class _DeclaredEvent {
  const _DeclaredEvent.attribute(this.attributeIndex, this.attribute)
    : kind = _DeclaredEventKind.attribute,
      element = null,
      wildcardParticle = null,
      wildcardUri = null;

  const _DeclaredEvent.element(this.element)
    : kind = _DeclaredEventKind.element,
      attributeIndex = null,
      attribute = null,
      wildcardParticle = null,
      wildcardUri = null;

  const _DeclaredEvent.wildcardAttribute(this.wildcardUri)
    : kind = _DeclaredEventKind.wildcardAttribute,
      attributeIndex = null,
      attribute = null,
      element = null,
      wildcardParticle = null;

  const _DeclaredEvent.wildcardElement(this.wildcardParticle, this.wildcardUri)
    : kind = _DeclaredEventKind.wildcardElement,
      attributeIndex = null,
      attribute = null,
      element = null;

  const _DeclaredEvent.end()
    : kind = _DeclaredEventKind.end,
      attributeIndex = null,
      attribute = null,
      element = null,
      wildcardParticle = null,
      wildcardUri = null;

  const _DeclaredEvent.characters()
    : kind = _DeclaredEventKind.characters,
      attributeIndex = null,
      attribute = null,
      element = null,
      wildcardParticle = null,
      wildcardUri = null;

  const _DeclaredEvent.typedCharacters()
    : kind = _DeclaredEventKind.typedCharacters,
      attributeIndex = null,
      attribute = null,
      element = null,
      wildcardParticle = null,
      wildcardUri = null;

  final _DeclaredEventKind kind;
  final int? attributeIndex;
  final ExiAttributeDeclaration? attribute;
  final ExiElementDeclaration? element;
  final ExiWildcardParticle? wildcardParticle;
  final String? wildcardUri;
}

ExiParticle _legacyContent(List<ExiElementDeclaration> children) {
  if (children.isEmpty) {
    return const ExiEmptyParticle();
  }
  return ExiSequenceParticle([for (final child in children) ExiElementParticle(child)]);
}

List<_FragmentElementGroup> _collectFragmentDeclarations(ExiSchema? schema) {
  if (schema == null) {
    return const [];
  }
  final declarations = <ExiElementDeclaration>[];
  final seen = Set<ExiElementDeclaration>.identity();
  late void Function(ExiElementDeclaration) collectElement;
  late void Function(ExiParticle?) collectParticle;

  collectElement = (element) {
    if (!seen.add(element)) {
      return;
    }
    declarations.add(element);
    for (final child in element.children) {
      collectElement(child);
    }
    collectParticle(element.content);
  };
  collectParticle = (particle) {
    switch (particle) {
      case null:
      case ExiEmptyParticle():
      case ExiWildcardParticle():
        return;
      case ExiElementParticle(:final element):
        collectElement(element);
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

  final compiled = schema.fragmentElements;
  if (compiled.isEmpty) {
    for (final element in schema.globalElements) {
      collectElement(element);
    }
  } else {
    for (final element in compiled) {
      if (seen.add(element)) {
        declarations.add(element);
      }
    }
  }

  declarations.sort((left, right) {
    final localNameOrder = left.name.localName.compareTo(right.name.localName);
    return localNameOrder != 0 ? localNameOrder : left.name.uri.compareTo(right.name.uri);
  });
  final groups = <_FragmentElementGroup>[];
  for (final declaration in declarations) {
    if (groups.isEmpty || groups.last.name != declaration.name) {
      groups.add(_FragmentElementGroup(declaration.name, [declaration]));
    } else {
      groups.last.declarations.add(declaration);
    }
  }
  return groups;
}

List<_FragmentAttributeGroup> _collectFragmentAttributes(ExiSchema? schema, List<_FragmentElementGroup> elements) {
  if (schema == null) {
    return const [];
  }
  final declarations =
      <ExiAttributeDeclaration>[
        ...schema.globalAttributes,
        for (final group in elements)
          for (final element in group.declarations) ...element.attributes,
      ]..sort((left, right) {
        final localNameOrder = left.name.localName.compareTo(right.name.localName);
        return localNameOrder != 0 ? localNameOrder : left.name.uri.compareTo(right.name.uri);
      });
  final groups = <_FragmentAttributeGroup>[];
  for (final declaration in declarations) {
    if (groups.isEmpty || groups.last.name != declaration.name) {
      groups.add(_FragmentAttributeGroup(declaration.name, [declaration]));
    } else if (!groups.last.declarations.contains(declaration)) {
      groups.last.declarations.add(declaration);
    }
  }
  return groups;
}

bool _isNullable(ExiParticle particle) {
  return switch (particle) {
    ExiEmptyParticle() => true,
    ExiElementParticle(:final minOccurs) => minOccurs == 0,
    ExiWildcardParticle() => false,
    ExiSequenceParticle(:final particles) => particles.every(_isNullable),
    ExiChoiceParticle(:final particles) => particles.any(_isNullable),
    ExiAllParticle(:final particles) => particles.every(_isNullable),
    ExiRepeatedParticle(:final particle, :final minOccurs) => minOccurs == 0 || _isNullable(particle),
  };
}

List<_DeclaredEvent> _leadingElementEvents(ExiParticle particle) {
  final result = <_DeclaredEvent>[];
  void collect(ExiParticle current) {
    switch (current) {
      case ExiEmptyParticle():
        return;
      case ExiElementParticle(:final element, :final maxOccurs):
        if (maxOccurs != 0) {
          if (result.any((candidate) => candidate.element?.name == element.name)) {
            throw UnsupportedError('Ambiguous schema particles with the same leading QName are not supported yet');
          }
          result.add(_DeclaredEvent.element(element));
        }
      case ExiWildcardParticle(:final namespaces):
        final uris = namespaces?.toList();
        uris?.sort();
        if (uris == null) {
          if (result.any(
            (candidate) => candidate.kind == _DeclaredEventKind.wildcardElement && candidate.wildcardUri == null,
          )) {
            throw UnsupportedError('Ambiguous unconstrained schema element wildcards are not supported yet');
          }
          result.add(_DeclaredEvent.wildcardElement(current, null));
        } else {
          for (final uri in uris) {
            if (result.any(
              (candidate) => candidate.kind == _DeclaredEventKind.wildcardElement && candidate.wildcardUri == uri,
            )) {
              throw UnsupportedError('Ambiguous schema element wildcards for namespace "$uri" are not supported yet');
            }
            result.add(_DeclaredEvent.wildcardElement(current, uri));
          }
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

ExiParticle? _derive(ExiParticle particle, Object selected) {
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
    case ExiWildcardParticle():
      return identical(particle, selected) ? const ExiEmptyParticle() : null;
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
  selfContained,
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
        if (options.selfContained) const _Production(_EventType.selfContained),
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

final class _FragmentElementGroup {
  _FragmentElementGroup(this.name, this.declarations);

  final ExiQName name;
  final List<ExiElementDeclaration> declarations;

  ExiElementDeclaration? get declaration {
    if (declarations.length == 1) {
      return declarations.single;
    }
    final first = declarations.first;
    final schemaTypeName = first.schemaTypeName;
    if (schemaTypeName == null) {
      return null;
    }
    return declarations.every(
          (declaration) => declaration.schemaTypeName == schemaTypeName && declaration.nillable == first.nillable,
        )
        ? first
        : null;
  }
}

final class _FragmentAttributeGroup {
  _FragmentAttributeGroup(this.name, this.declarations);

  final ExiQName name;
  final List<ExiAttributeDeclaration> declarations;

  ExiAttributeDeclaration? get declaration => declarations.length == 1 ? declarations.single : null;
}

final class _CompressedStreams {
  _CompressedStreams(Uint8List bytes) : _input = InputMemoryStream(bytes);

  final InputMemoryStream _input;

  bool get hasRemaining => !_input.isEOS;

  BitInput read() {
    if (_input.isEOS) {
      throw const FormatException('Missing EXI compressed stream');
    }
    final bytes = Inflate.stream(_input).getBytes();
    return BitInput(bytes)..useByteAlignment();
  }
}

final class _DeferredValue {
  const _DeferredValue(this.marker, this.read);

  final String marker;
  final String Function() read;
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
