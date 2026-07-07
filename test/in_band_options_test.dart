import 'dart:typed_data';

import 'package:exi/exi.dart';
import 'package:test/test.dart';

void main() {
  group('in-band EXI options', () {
    test('decodes the official W3C strict-only header vector', () {
      // OpenEXI encoding from the W3C EXI 1.0 interoperability framework.
      final bytes = Uint8List.fromList([
        0x24,
        0x45,
        0x58,
        0x49,
        0xa0,
        0x48,
        0x13,
        0x0e,
        0x22,
        0x60,
        0x62,
        0x64,
        0x66,
        0x68,
        0x6a,
        0x6c,
        0x6e,
        0x82,
        0x70,
        0x72,
        0xc2,
        0xc4,
        0xc6,
        0xc8,
      ]);

      final document = ExiDecoder().decode(bytes);

      expect(document.options.strict, isTrue);
      expect(document.header.hasOptions, isTrue);
      expect(document.toXmlString(), '<a>01234567A89abcd</a>');
    });

    test('applies the fragment option to the following body', () {
      final bits = StringBuffer('10100000')
        // Options document: SE(header), SE(common), SE(fragment),
        // EE(common), EE(header).
        ..write('0010111')
        // Fragment body with two empty <item> elements.
        ..write('0')
        ..write(_qName('', 'item'))
        ..write('00')
        ..write('00')
        ..write('0')
        ..write('10');

      final document = ExiDecoder().decode(_pack(bits.toString()));

      expect(document.options.fragment, isTrue);
      expect(document.toXmlString(), '<item/><item/>');
    });

    test('applies preserve-comments to the following body', () {
      final bits = StringBuffer('10100000')
        // header/lesscommon/preserve/comments, then close each sequence.
        ..write('000010111110')
        // Document body with a comment inside <root>.
        ..write('0')
        ..write(_qName('', 'root'))
        ..write('100')
        ..write(_rawString('note'))
        ..write('0')
        ..write('0');

      final document = ExiDecoder().decode(_pack(bits.toString()));

      expect(document.options.fidelity.comments, isTrue);
      expect(document.events.whereType<ExiComment>().single.text, 'note');
      expect(document.toXmlString(), '<root><!--note--></root>');
    });

    test('reads preserve-lexical-values from the options document', () {
      final bits = StringBuffer('10100000')
        // header/lesscommon/preserve/lexicalValues, then close each sequence.
        ..write('0000101010110')
        // Empty schema-less document body.
        ..write(_qName('', 'root'))
        ..write('00');

      final document = ExiDecoder().decode(_pack(bits.toString()));

      expect(document.options.fidelity.lexicalValues, isTrue);
      expect(document.toXmlString(), '<root/>');
    });

    test('rejects strict with forbidden preserve options from the options document', () {
      final bits = StringBuffer('10100000')
        // header/lesscommon/preserve/comments, then strict.
        ..write('000010111101');

      expect(() => ExiDecoder().decode(_pack(bits.toString())), throwsArgumentError);
    });

    test('allows strict with lexical values from the options document', () {
      final bits = StringBuffer('10100000')
        // header/lesscommon/preserve/lexicalValues, then strict.
        ..write('0000101010101')
        // Empty schema-less document body.
        ..write(_qName('', 'root'))
        ..write('00');

      final document = ExiDecoder().decode(_pack(bits.toString()));

      expect(document.options.strict, isTrue);
      expect(document.options.fidelity.lexicalValues, isTrue);
      expect(document.toXmlString(), '<root/>');
    });

    test('applies self-contained mode to the following body', () {
      final bits = StringBuffer('10100000')
        // header/lesscommon/uncommon/selfContained, then close each sequence.
        ..write('00000010111010')
        // Document body: SE(root), then SC.
        ..write(_qName('', 'root'))
        ..write('010');
      _alignBits(bits);
      // Fresh root grammar -> EE.
      bits.write('000');
      _alignBits(bits);

      final document = ExiDecoder().decode(_pack(bits.toString()));

      expect(document.options.selfContained, isTrue);
      expect(document.toXmlString(), '<root/>');
    });

    test('applies a built-in datatype representation map to the following body', () {
      const schemaId = 'mapped-options';
      final schema = ExiSchemaCompiler.compile(
        id: schemaId,
        source: '''
          <xs:schema xmlns:xs="http://www.w3.org/2001/XMLSchema">
            <xs:element name="amount" type="xs:decimal"/>
          </xs:schema>
        ''',
      );
      final bits = StringBuffer('10100000')
        // header/lesscommon/uncommon/datatypeRepresentationMap.
        ..write('00000101')
        // First wildcard child: xsd:decimal, then its built-in EE.
        ..write(_optionsQName(_xsdUri, 'decimal'))
        ..write('00')
        // Second wildcard child: exi:string, then its built-in EE.
        ..write(_optionsQName(_exiUri, 'string'))
        ..write('00')
        // Repeat datatypeRepresentationMap: xsd:boolean -> exi:integer.
        ..write('0')
        ..write(_optionsQName(_xsdUri, 'boolean'))
        ..write('00')
        ..write(_optionsQName(_exiUri, 'integer'))
        ..write('00')
        // Close uncommon and lesscommon; select common/schemaId.
        ..write('1100010')
        // schemaId CH production.
        ..write('0')
        ..write(_literal(schemaId, lengthOffset: 2))
        // Select strict; header then closes implicitly.
        ..write('0')
        // Schema root selection followed by String-represented decimal content.
        ..write('0')
        ..write(_literal('12.50', lengthOffset: 2));

      final document = ExiDecoder(schemaResolver: (_) => schema).decode(_pack(bits.toString()));

      expect(document.options.datatypeRepresentationMap, hasLength(2));
      expect(document.options.datatypeRepresentationMap.first.representation, ExiDatatype.string);
      expect(document.options.datatypeRepresentationMap.last.representation, ExiDatatype.integer);
      expect(document.toXmlString(), '<amount>12.50</amount>');
    });

    test('retains an unused user-defined datatype representation', () {
      const schemaId = 'unused-custom-map';
      const representation = ExiQName(uri: 'urn:representation', localName: 'custom');
      final schema = ExiSchemaCompiler.compile(
        id: schemaId,
        source: '''
          <xs:schema xmlns:xs="http://www.w3.org/2001/XMLSchema">
            <xs:element name="amount" type="xs:decimal"/>
          </xs:schema>
        ''',
      );
      final bits = StringBuffer('10100000')
        ..write('00000101')
        ..write(_optionsQName(_xsdUri, 'boolean'))
        ..write('00')
        ..write(_literalOptionsQName(representation.uri, representation.localName))
        ..write('00')
        ..write('1100010')
        ..write('0')
        ..write(_literal(schemaId, lengthOffset: 2))
        ..write('00')
        // Decimal 1.25.
        ..write('0')
        ..write(_unsigned(1))
        ..write(_unsigned(52));

      final document = ExiDecoder(schemaResolver: (_) => schema).decode(_pack(bits.toString()));
      final mapping = document.options.datatypeRepresentationMap.single;

      expect(mapping.representation, isNull);
      expect(mapping.representationName, representation);
      expect(document.toXmlString(), '<amount>1.25</amount>');
    });

    test('rejects a user-defined representation when its typed value is encountered', () {
      const schemaId = 'required-custom-map';
      final schema = ExiSchemaCompiler.compile(
        id: schemaId,
        source: '''
          <xs:schema xmlns:xs="http://www.w3.org/2001/XMLSchema">
            <xs:element name="amount" type="xs:decimal"/>
          </xs:schema>
        ''',
      );
      final bits = StringBuffer('10100000')
        ..write('00000101')
        ..write(_optionsQName(_xsdUri, 'decimal'))
        ..write('00')
        ..write(_literalOptionsQName('urn:representation', 'custom'))
        ..write('00')
        ..write('1100010')
        ..write('0')
        ..write(_literal(schemaId, lengthOffset: 2))
        ..write('00');

      expect(() => ExiDecoder(schemaResolver: (_) => schema).decode(_pack(bits.toString())), throwsUnsupportedError);
    });

    test('preserves repeated user-defined metadata elements', () {
      final bits = StringBuffer('10100000')
        // header/lesscommon/uncommon/metadata wildcard.
        ..write('00000000')
        ..write(_literalOptionsQName('urn:meta:first', 'first'))
        ..write('11')
        ..write(_literal('alpha', lengthOffset: 2))
        ..write('0')
        // Repeat the metadata wildcard.
        ..write('000')
        ..write(_literalOptionsQName('urn:meta:second', 'second'))
        ..write('11')
        ..write(_literal('beta', lengthOffset: 2))
        ..write('0')
        // Close uncommon, lesscommon, and header.
        ..write('1101010')
        // Empty schema-less body.
        ..write(_qName('', 'root'))
        ..write('00');

      final document = ExiDecoder().decode(_pack(bits.toString()));

      expect(document.options.metadata, hasLength(2));
      expect(document.options.metadata.first.name, const ExiQName(uri: 'urn:meta:first', localName: 'first'));
      expect(document.options.metadata.first.events.whereType<ExiCharacters>().single.value, 'alpha');
      expect(document.options.metadata.last.name, const ExiQName(uri: 'urn:meta:second', localName: 'second'));
      expect(document.options.metadata.last.events.whereType<ExiCharacters>().single.value, 'beta');
      expect(document.toXmlString(), '<root/>');
    });

    test('decodes metadata xsi:type values as QNames', () {
      final bits = StringBuffer('10100000')
        // header/lesscommon/uncommon/metadata wildcard.
        ..write('00000000')
        ..write(_literalOptionsQName('urn:meta', 'typed'))
        // Metadata start tag -> AT(*).
        ..write('01')
        ..write(_literalOptionsQName(_xsiUri, 'type'))
        ..write(_optionsQName(_xsdUri, 'string'))
        // Metadata start tag -> EE after learning the attribute.
        ..write('100')
        // Close uncommon, lesscommon, and header.
        ..write('1101010')
        // Empty schema-less body.
        ..write(_qName('', 'root'))
        ..write('00');

      final document = ExiDecoder().decode(_pack(bits.toString()));
      final metadata = document.options.metadata.single;

      expect(metadata.name, const ExiQName(uri: 'urn:meta', localName: 'typed'));
      expect(metadata.events.whereType<ExiAttribute>().single.value, '{$_xsdUri}string');
      expect(document.toXmlString(), '<root/>');
    });

    test('reads schemaId content after xsi:nil false', () {
      const schemaId = 'false-nil-schema';
      final schema = ExiSchemaCompiler.compile(
        id: schemaId,
        source: '''
          <xs:schema xmlns:xs="http://www.w3.org/2001/XMLSchema">
            <xs:element name="root"/>
          </xs:schema>
        ''',
      );
      final bits = StringBuffer('10100000')
        // header/common/schemaId, AT(xsi:nil), Boolean false.
        ..write('0011010')
        // The normal schemaId content follows the false nil value.
        ..write(_literal(schemaId, lengthOffset: 2))
        // Select strict; header closes implicitly. Select the schema root.
        ..write('00');

      final document = ExiDecoder(schemaResolver: (_) => schema).decode(_pack(bits.toString()));

      expect(document.options.schemaId, const ExiSchemaId.named(schemaId));
      expect(document.toXmlString(), '<root/>');
    });

    test('reads an empty built-in-types schemaId after xsi:nil false', () {
      final bits = StringBuffer('10100000')
        ..write('0011010')
        ..write(_literal('', lengthOffset: 2))
        // Close header, then encode an empty schema-less root.
        ..write('1')
        ..write(_qName('', 'root'))
        ..write('00');

      final document = ExiDecoder().decode(_pack(bits.toString()));

      expect(document.options.schemaId, ExiSchemaId.builtInTypes);
      expect(document.toXmlString(), '<root/>');
    });
  });
}

String _optionsQName(String uri, String localName) {
  final uriIndex = [_emptyUri, _xmlUri, _xsiUri, _xsdUri, _exiUri].indexOf(uri);
  final localNames = (uri == _xsdUri ? [..._xsdLocalNames] : [..._exiLocalNames])..sort();
  final localNameIndex = localNames.indexOf(localName);
  if (uriIndex == -1 || localNameIndex == -1) {
    throw ArgumentError('QName is not prepopulated in the EXI options string table');
  }
  return '${(uriIndex + 1).toRadixString(2).padLeft(3, '0')}'
      '${_unsigned(0)}'
      '${localNameIndex.toRadixString(2).padLeft((localNames.length - 1).bitLength, '0')}';
}

String _literalOptionsQName(String uri, String localName) =>
    '000${_rawString(uri)}${_literal(localName, lengthOffset: 1)}';

String _qName(String uri, String localName) {
  final encodedUri = uri.isEmpty ? '01' : '00${_rawString(uri)}';
  return '$encodedUri${_literal(localName, lengthOffset: 1)}';
}

String _rawString(String value) => _literal(value, lengthOffset: 0);

String _literal(String value, {required int lengthOffset}) {
  final codePoints = value.runes.toList();
  return '${_unsigned(codePoints.length + lengthOffset)}${codePoints.map(_unsigned).join()}';
}

String _unsigned(int value) {
  final bits = StringBuffer();
  var remainder = value;
  do {
    final group = remainder & 0x7f;
    remainder >>= 7;
    bits.write((group | (remainder == 0 ? 0 : 0x80)).toRadixString(2).padLeft(8, '0'));
  } while (remainder != 0);
  return bits.toString();
}

Uint8List _pack(String bits) {
  final padded = bits.padRight((bits.length + 7) ~/ 8 * 8, '0');
  return Uint8List.fromList([
    for (var offset = 0; offset < padded.length; offset += 8) int.parse(padded.substring(offset, offset + 8), radix: 2),
  ]);
}

void _alignBits(StringBuffer bits) {
  while (bits.length % 8 != 0) {
    bits.write('0');
  }
}

const _emptyUri = '';
const _xmlUri = 'http://www.w3.org/XML/1998/namespace';
const _xsiUri = 'http://www.w3.org/2001/XMLSchema-instance';
const _xsdUri = 'http://www.w3.org/2001/XMLSchema';
const _exiUri = 'http://www.w3.org/2009/exi';

const _xsdLocalNames = [
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
];

const _exiLocalNames = [
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
