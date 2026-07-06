import 'dart:typed_data';

import 'package:exi/exi.dart';
import 'package:test/test.dart';

void main() {
  group('fidelity options', () {
    test('preserves a comment inside an element', () {
      final bits = StringBuffer('10000000')
        // DocContent -> SE(*).
        ..write('0')
        ..write(_qName('', 'root'))
        // StartTagContent -> CM.
        ..write('100')
        ..write(_rawString('note'))
        // ElementContent -> EE; DocEnd -> ED.
        ..write('0')
        ..write('0');

      final document = ExiDecoder(
        options: const ExiOptions(fidelity: ExiFidelityOptions(comments: true)),
      ).decode(_pack(bits.toString()));

      expect(document.events.whereType<ExiComment>().single.text, 'note');
      expect(document.toXmlString(), '<root><!--note--></root>');
    });

    test('preserves a processing instruction', () {
      final bits = StringBuffer('10000000')
        ..write('0')
        ..write(_qName('', 'root'))
        // StartTagContent -> PI: second-level branch 4, third-level PI 1.
        ..write('1001')
        ..write(_rawString('target'))
        ..write(_rawString('data'))
        ..write('0')
        ..write('0');

      final document = ExiDecoder(
        options: const ExiOptions(fidelity: ExiFidelityOptions(comments: true, processingInstructions: true)),
      ).decode(_pack(bits.toString()));

      final instruction = document.events.whereType<ExiProcessingInstruction>().single;
      expect(instruction.target, 'target');
      expect(instruction.text, 'data');
      expect(document.toXmlString(), '<root><?target data?></root>');
    });

    test('preserves a document type and entity reference', () {
      final bits = StringBuffer('10000000')
        // DocContent -> DT.
        ..write('1')
        ..write(_rawString('root'))
        ..write(_rawString(''))
        ..write(_rawString('root.dtd'))
        ..write(_rawString(''))
        // DocContent -> SE(*).
        ..write('0')
        ..write(_qName('', 'root'))
        // StartTagContent -> ER.
        ..write('100')
        ..write(_rawString('example'))
        // ElementContent -> EE; DocEnd -> ED.
        ..write('0')
        ..write('0');

      final document = ExiDecoder(
        options: const ExiOptions(fidelity: ExiFidelityOptions(dtd: true)),
      ).decode(_pack(bits.toString()));

      final documentType = document.events.whereType<ExiDocumentType>().single;
      expect(documentType.name, 'root');
      expect(documentType.systemId, 'root.dtd');
      expect(document.events.whereType<ExiEntityReference>().single.name, 'example');
      expect(document.toXmlString(), '<!DOCTYPE root SYSTEM "root.dtd"><root>&example;</root>');
    });

    test('resolves an element prefix from its local namespace event', () {
      final bits = StringBuffer('10000000')
        ..write(_qName('urn:example', 'root'))
        // StartTagContent -> NS.
        ..write('010')
        ..write(_rawString('urn:example'))
        ..write(_rawString('p'))
        ..write('1')
        // StartTagContent -> EE.
        ..write('000');

      final document = ExiDecoder(
        options: const ExiOptions(fidelity: ExiFidelityOptions(prefixes: true)),
      ).decode(_pack(bits.toString()));

      final root = document.events.whereType<ExiStartElement>().single;
      expect(root.name.prefix, 'p');
      final namespace = document.events.whereType<ExiNamespaceDeclaration>().single;
      expect(namespace, const ExiNamespaceDeclaration(uri: 'urn:example', prefix: 'p', localElementNamespace: true));
      expect(document.toXmlString(), '<p:root xmlns:p="urn:example"/>');
    });

    test('rejects a namespace declaration after an attribute', () {
      final bits = StringBuffer('10000000')
        ..write(_qName('', 'root'))
        // StartTagContent -> AT(*).
        ..write('001')
        ..write(_qName('', 'id'))
        ..write(_value('42'))
        // StartTagContent -> undeclared NS after learned AT(id).
        ..write('1010')
        ..write(_rawString('urn:example'))
        ..write(_rawString('p'))
        ..write('0')
        // StartTagContent -> EE.
        ..write('1000');

      expect(
        () => ExiDecoder(
          options: const ExiOptions(fidelity: ExiFidelityOptions(prefixes: true)),
        ).decode(_pack(bits.toString())),
        throwsA(isA<FormatException>()),
      );
    });

    test('rejects a self-contained marker after an attribute', () {
      final bits = StringBuffer('10000000')
        ..write(_qName('', 'root'))
        // StartTagContent -> AT(*).
        ..write('001')
        ..write(_qName('', 'id'))
        ..write(_value('42'))
        // StartTagContent -> undeclared SC after learned AT(id).
        ..write('1010');
      _alignBits(bits);
      // Self-contained root content: StartTagContent -> EE.
      bits.write('00');

      expect(
        () => ExiDecoder(options: const ExiOptions(selfContained: true)).decode(_pack(bits.toString())),
        throwsA(isA<FormatException>()),
      );
    });

    test('rejects a self-contained marker after a namespace declaration', () {
      final bits = StringBuffer('10000000')
        ..write(_qName('', 'root'))
        // StartTagContent -> NS.
        ..write('010')
        ..write(_rawString('urn:example'))
        ..write(_rawString('p'))
        ..write('0')
        // StartTagContent -> SC after NS.
        ..write('011');
      _alignBits(bits);
      // Self-contained root content: StartTagContent -> EE.
      bits.write('00');

      expect(
        () => ExiDecoder(
          options: const ExiOptions(selfContained: true, fidelity: ExiFidelityOptions(prefixes: true)),
        ).decode(_pack(bits.toString())),
        throwsA(isA<FormatException>()),
      );
    });
  });

  group('fragment option', () {
    test('decodes multiple top-level elements and learns their QName', () {
      final bits = StringBuffer('10000000')
        // FragmentContent -> SE(*).
        ..write('0')
        ..write(_qName('', 'item'))
        ..write('00')
        // Learned SE(item), followed by learned EE in its global grammar.
        ..write('00')
        ..write('0')
        // FragmentContent -> ED.
        ..write('10');

      final document = ExiDecoder(options: const ExiOptions(fragment: true)).decode(_pack(bits.toString()));

      expect(document.events.whereType<ExiStartElement>(), hasLength(2));
      expect(document.toXmlString(), '<item/><item/>');
    });
  });

  test('decodes a self-contained element and restores the outer string table', () {
    final bits = StringBuffer('10000000')
      // DocContent -> SE(root).
      ..write(_qName('', 'root'))
      // StartTagContent -> AT(*), then the attribute QName and value.
      ..write('001')
      ..write(_qName('', 'id'))
      ..write(_value('outer'))
      // Learned start-tag branch -> SE(*).
      ..write('1')
      ..write('011')
      ..write(_qName('', 'child'))
      // Child StartTagContent -> SC.
      ..write('010');
    _alignBits(bits);
    bits
      // Fresh child grammar -> CH, followed by EE.
      ..write('100')
      ..write(_value('inner'))
      ..write('01');
    _alignBits(bits);
    bits
      // Restored root grammar -> CH using the outer global value, then EE.
      ..write('11')
      ..write(_unsigned(1))
      ..write('01');

    final document = ExiDecoder(options: const ExiOptions(selfContained: true)).decode(_pack(bits.toString()));

    expect(document.toXmlString(), '<root id="outer"><child>inner</child>outer</root>');
  });

  test('accepts pre-compression options', () {
    expect(ExiDecoder(options: const ExiOptions(alignment: ExiAlignment.preCompression)), isA<ExiDecoder>());
  });

  test('enforces a zero value-partition capacity', () {
    final bits = StringBuffer('10000000')
      ..write(_qName('', 'root'))
      ..write('11')
      ..write(_value('x'))
      ..write('11')
      ..write(_unsigned(0));

    expect(
      () => ExiDecoder(options: const ExiOptions(valuePartitionCapacity: 0)).decode(_pack(bits.toString())),
      throwsA(isA<FormatException>()),
    );
  });
}

String _qName(String uri, String localName) {
  final encodedUri = uri.isEmpty ? '01' : '00${_rawString(uri)}';
  return '$encodedUri${_literal(localName, lengthOffset: 1)}';
}

String _rawString(String value) => _literal(value, lengthOffset: 0);

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

void _alignBits(StringBuffer bits) {
  while (bits.length % 8 != 0) {
    bits.write('0');
  }
}
