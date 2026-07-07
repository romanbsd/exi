import 'dart:typed_data';

import 'package:exi/exi.dart';
import 'package:test/test.dart';

void main() {
  group('EXI header', () {
    test('decodes the optional EXI cookie and final version 1', () {
      final bytes = Uint8List.fromList([0x24, 0x45, 0x58, 0x49, ..._minimalDocument()]);

      final document = ExiDecoder().decode(bytes);

      expect(document.header.hasCookie, isTrue);
      expect(document.header.version, 1);
      expect(document.header.isPreview, isFalse);
    });

    test('rejects invalid distinguishing bits', () {
      expect(() => ExiDecoder().decode(Uint8List.fromList([0x00])), throwsA(isA<FormatException>()));
    });

    test('rejects unsupported preview and final versions', () {
      expect(() => ExiDecoder().decode(Uint8List.fromList([0x90])), throwsA(isA<UnsupportedError>()));
      expect(() => ExiDecoder().decode(Uint8List.fromList([0x81])), throwsA(isA<UnsupportedError>()));
    });

    test('rejects a truncated in-band options document', () {
      expect(() => ExiDecoder().decode(Uint8List.fromList([0xa0])), throwsA(isA<FormatException>()));
    });
  });

  group('schema-less built-in grammar', () {
    test('decodes an empty element document', () {
      final document = ExiDecoder().decode(Uint8List.fromList(_minimalDocument()));

      expect(document.events, hasLength(4));
      expect(document.events[0], isA<ExiStartDocument>());
      expect(document.events[1], isA<ExiStartElement>());
      expect((document.events[1] as ExiStartElement).name, const ExiQName(localName: 'root'));
      expect(document.events[2], isA<ExiEndElement>());
      expect(document.events[3], isA<ExiEndDocument>());
      expect(document.toXmlString(), '<root/>');
    });

    test('decodes character content and XML-escapes it', () {
      final bits = StringBuffer('10000000')
        ..write(_qName('', 'message'))
        ..write('11')
        ..write(_value('<&>'))
        ..write('0');

      final document = ExiDecoder().decode(_pack(bits.toString()));

      expect(document.events.whereType<ExiCharacters>().single.value, '<&>');
      expect(document.toXmlString(), '<message>&lt;&amp;&gt;</message>');
    });

    test('decodes attributes before element content', () {
      final bits = StringBuffer('10000000')
        ..write(_qName('', 'item'))
        ..write('01')
        ..write(_qName('', 'id'))
        ..write(_value('42'))
        ..write('100');

      final document = ExiDecoder().decode(_pack(bits.toString()));

      final attribute = document.events.whereType<ExiAttribute>().single;
      expect(attribute.name, const ExiQName(localName: 'id'));
      expect(attribute.value, '42');
      expect(document.toXmlString(), '<item id="42"/>');
    });

    test('rejects malformed element names during XML reconstruction', () {
      final bits = StringBuffer('10000000')
        ..write(_qName('', 'bad name'))
        ..write('00');

      final document = ExiDecoder().decode(_pack(bits.toString()));

      expect(document.events.whereType<ExiStartElement>().single.name, const ExiQName(localName: 'bad name'));
      expect(document.toXmlString, throwsFormatException);
    });

    test('rejects malformed attribute names during XML reconstruction', () {
      final bits = StringBuffer('10000000')
        ..write(_qName('', 'item'))
        ..write('01')
        ..write(_qName('', 'bad name'))
        ..write(_value('42'))
        ..write('100');

      final document = ExiDecoder().decode(_pack(bits.toString()));

      final attribute = document.events.whereType<ExiAttribute>().single;
      expect(attribute.name, const ExiQName(localName: 'bad name'));
      expect(attribute.value, '42');
      expect(document.toXmlString, throwsFormatException);
    });

    test('rejects duplicate attributes in a built-in element grammar', () {
      final bits = StringBuffer('10000000')
        ..write(_qName('', 'item'))
        // StartTagContent -> AT(*).
        ..write('01')
        ..write(_qName('', 'id'))
        ..write(_value('42'))
        // StartTagContent -> learned AT(id).
        ..write('0')
        ..write(_value('again'))
        // StartTagContent -> EE.
        ..write('100');

      expect(() => ExiDecoder().decode(_pack(bits.toString())), throwsA(isA<FormatException>()));
    });

    test('rejects built-in xsi:type after xsi:nil', () {
      final bits = StringBuffer('10000000')
        ..write(_qName('', 'item'))
        // StartTagContent -> AT(*) with xsi:nil.
        ..write('01')
        ..write(_qNameHit(uriId: 2, localNameId: 0, localNameCount: 2))
        ..write(_value('false'))
        // StartTagContent -> AT(*) with xsi:type. This violates the
        // special-attribute order: xsi:type must precede xsi:nil.
        ..write('101')
        ..write(_qNameHit(uriId: 2, localNameId: 1, localNameCount: 2))
        ..write(_value('Example'))
        // StartTagContent -> EE.
        ..write('100');

      expect(() => ExiDecoder().decode(_pack(bits.toString())), throwsA(isA<FormatException>()));
    });

    test('decodes built-in xsi:type values as QNames by default', () {
      const xsdUri = 'http://www.w3.org/2001/XMLSchema';
      final bits = StringBuffer('10000000')
        ..write(_qName('', 'item'))
        // StartTagContent -> AT(*) with xsi:type.
        ..write('01')
        ..write(_qNameHit(uriId: 2, localNameId: 1, localNameCount: 2))
        // xsi:type value uses QName representation when lexical values are not preserved.
        ..write(_literalQName(xsdUri, 'string'))
        // StartTagContent -> EE.
        ..write('100');

      final document = ExiDecoder().decode(_pack(bits.toString()));

      expect(document.events.whereType<ExiAttribute>().single.value, '{$xsdUri}string');
    });

    test('decodes built-in xsi:type values as Strings when preserving lexical values', () {
      final bits = StringBuffer('10000000')
        ..write(_qName('', 'item'))
        // StartTagContent -> AT(*) with xsi:type.
        ..write('01')
        ..write(_qNameHit(uriId: 2, localNameId: 1, localNameCount: 2))
        // Preserve.lexicalValues keeps xsi:type on the String value representation.
        ..write(_value('xsd:string'))
        // StartTagContent -> EE.
        ..write('100');

      final document = ExiDecoder(
        options: const ExiOptions(fidelity: ExiFidelityOptions(lexicalValues: true)),
      ).decode(_pack(bits.toString()));

      expect(document.events.whereType<ExiAttribute>().single.value, 'xsd:string');
    });

    test('uses namespace prefixes for built-in QName-encoded xsi:type values', () {
      const xsdUri = 'http://www.w3.org/2001/XMLSchema';
      final bits = StringBuffer('10000000')
        ..write(_qName('', 'item'))
        // StartTagContent -> NS, declaring the prefix used by the xsi:type value.
        ..write('010')
        ..write(_literal(xsdUri, lengthOffset: 0))
        ..write(_literal('xsd', lengthOffset: 0))
        ..write('0')
        // StartTagContent -> AT(*) with xsi:type.
        ..write('001')
        ..write(_qNameHit(uriId: 2, uriCount: 4, localNameId: 1, localNameCount: 2))
        // QName value uses the declared xsd prefix partition.
        ..write(_literalQName(xsdUri, 'integer', uriCount: 4))
        // StartTagContent -> EE.
        ..write('100');

      final document = ExiDecoder(
        options: const ExiOptions(fidelity: ExiFidelityOptions(prefixes: true)),
      ).decode(_pack(bits.toString()));

      expect(document.events.whereType<ExiAttribute>().single.value, '{$xsdUri}xsd:integer');
    });

    test('learns repeated child QNames and character productions', () {
      final bits = StringBuffer('10000000')
        ..write(_qName('', 'root'))
        // StartTagContent -> SE(*).
        ..write('10')
        ..write(_qName('', 'child'))
        // child StartTagContent -> CH.
        ..write('11')
        ..write(_value('one'))
        // child ElementContent -> initial EE.
        ..write('0')
        // root ElementContent -> SE(*) and a string-table QName hit.
        ..write('10')
        ..write(_qNameHit(uriId: 0, localNameId: 1, localNameCount: 2))
        // child StartTagContent -> learned CH, event code 0.
        ..write('0')
        ..write(_value('two'))
        // child ElementContent -> learned EE, event code 0.
        ..write('00')
        // root ElementContent -> EE after learned SE(child), event code 1.
        ..write('01');

      final document = ExiDecoder().decode(_pack(bits.toString()));

      expect(document.toXmlString(), '<root><child>one</child><child>two</child></root>');
    });

    test('resolves local and global value partition hits', () {
      final bits = StringBuffer('10000000')
        ..write(_qName('', 'root'))
        // StartTagContent -> CH(*) with a new value.
        ..write('11')
        ..write(_value('same'))
        // ElementContent -> CH(*) with a local value hit.
        ..write('11')
        ..write(_unsigned(0))
        // ElementContent -> learned CH with a global value hit.
        ..write('00')
        ..write(_unsigned(1))
        // ElementContent -> EE.
        ..write('01');

      final document = ExiDecoder().decode(_pack(bits.toString()));

      expect(document.events.whereType<ExiCharacters>().map((event) => event.value), ['same', 'same', 'same']);
      expect(document.toXmlString(), '<root>samesamesame</root>');
    });

    test('decodes a literal namespace URI into the QName event', () {
      final bits = StringBuffer('10000000')
        ..write('00')
        ..write(_literal('urn:example', lengthOffset: 0))
        ..write(_literal('root', lengthOffset: 1))
        ..write('00');

      final document = ExiDecoder().decode(_pack(bits.toString()));
      final root = document.events.whereType<ExiStartElement>().single;

      expect(root.name, const ExiQName(uri: 'urn:example', localName: 'root'));
      expect(document.toXmlString, throwsA(isA<UnsupportedError>()));
    });

    test('reports truncated event content as malformed', () {
      final truncated = _minimalDocument().sublist(0, 2);

      expect(() => ExiDecoder().decode(Uint8List.fromList(truncated)), throwsA(isA<FormatException>()));
    });
  });
}

List<int> _minimalDocument() {
  final bits = StringBuffer('10000000')
    ..write(_qName('', 'root'))
    ..write('00');
  return _pack(bits.toString());
}

String _qName(String uri, String localName) {
  if (uri.isNotEmpty) {
    throw ArgumentError.value(uri, 'uri', 'test helper only supports the initial empty URI');
  }
  return '01${_literal(localName, lengthOffset: 1)}';
}

String _qNameHit({required int uriId, int uriCount = 3, required int localNameId, required int localNameCount}) {
  final encodedUri = (uriId + 1).toRadixString(2).padLeft(uriCount.bitLength, '0');
  final localNameWidth = (localNameCount - 1).bitLength;
  final encodedLocalName = localNameId.toRadixString(2).padLeft(localNameWidth, '0');
  return '$encodedUri${_unsigned(0)}$encodedLocalName';
}

String _literalQName(String uri, String localName, {int uriCount = 3}) =>
    '${''.padLeft(uriCount.bitLength, '0')}${_literal(uri, lengthOffset: 0)}${_literal(localName, lengthOffset: 1)}';

String _value(String value) => _literal(value, lengthOffset: 2);

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
