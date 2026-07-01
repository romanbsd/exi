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

    test('rejects in-band EXI options in this stage', () {
      expect(() => ExiDecoder().decode(Uint8List.fromList([0xa0])), throwsA(isA<UnsupportedError>()));
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

String _qNameHit({required int uriId, required int localNameId, required int localNameCount}) {
  final encodedUri = (uriId + 1).toRadixString(2).padLeft(2, '0');
  final localNameWidth = (localNameCount - 1).bitLength;
  final encodedLocalName = localNameId.toRadixString(2).padLeft(localNameWidth, '0');
  return '$encodedUri${_unsigned(0)}$encodedLocalName';
}

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
