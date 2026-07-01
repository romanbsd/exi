import 'dart:typed_data';

import 'package:exi/exi.dart';
import 'package:test/test.dart';

void main() {
  group('strict schema particles', () {
    test('decodes an optional child that is absent', () {
      final schema = _compile('''
        <xs:element name="root">
          <xs:complexType>
            <xs:sequence>
              <xs:element name="child" minOccurs="0"/>
            </xs:sequence>
          </xs:complexType>
        </xs:element>
      ''');

      // Optional child has SE(child)=0 and EE=1.
      final document = _decode(schema, '01');

      expect(document.toXmlString(), '<root/>');
    });

    test('decodes repeated children until EE is selected', () {
      final schema = _compile('''
        <xs:element name="root">
          <xs:complexType>
            <xs:sequence>
              <xs:element name="item" minOccurs="0" maxOccurs="unbounded">
                <xs:complexType/>
              </xs:element>
            </xs:sequence>
          </xs:complexType>
        </xs:element>
      ''');

      // Two SE(item) events followed by EE.
      final document = _decode(schema, '0001');

      expect(document.toXmlString(), '<root><item/><item/></root>');
    });

    test('selects a branch from an XSD choice', () {
      final schema = _compile('''
        <xs:element name="root">
          <xs:complexType>
            <xs:choice>
              <xs:element name="left"/>
              <xs:element name="right"/>
            </xs:choice>
          </xs:complexType>
        </xs:element>
      ''');

      // SE(left)=0 and SE(right)=1.
      final document = _decode(schema, '01');

      expect(document.toXmlString(), '<root><right/></root>');
    });

    test('decodes a particle that references a global element', () {
      final schema = _compile('''
        <xs:element name="root">
          <xs:complexType>
            <xs:sequence>
              <xs:element ref="item"/>
            </xs:sequence>
          </xs:complexType>
        </xs:element>
        <xs:element name="item"/>
      ''');

      // Global element events are QName-sorted: item=00, root=01, wildcard=10.
      final document = _decode(schema, '01');

      expect(document.toXmlString(), '<root><item/></root>');
    });

    test('decodes nested sequence and choice particles', () {
      final schema = _compile('''
        <xs:element name="root">
          <xs:complexType>
            <xs:sequence>
              <xs:element name="first"/>
              <xs:choice>
                <xs:element name="left"/>
                <xs:element name="right"/>
              </xs:choice>
              <xs:element name="last"/>
            </xs:sequence>
          </xs:complexType>
        </xs:element>
      ''');

      // Root is 0; first is implicit; right is 1; last is implicit.
      final document = _decode(schema, '01');

      expect(document.toXmlString(), '<root><first/><right/><last/></root>');
    });

    test('decodes a referenced named model group', () {
      final schema = _compile('''
        <xs:group name="pair">
          <xs:sequence>
            <xs:element name="first"/>
            <xs:element name="second"/>
          </xs:sequence>
        </xs:group>
        <xs:element name="root">
          <xs:complexType>
            <xs:group ref="pair"/>
          </xs:complexType>
        </xs:element>
      ''');

      final document = _decode(schema, '0');

      expect(document.toXmlString(), '<root><first/><second/></root>');
    });

    test('decodes an optional sequence that is absent', () {
      final schema = _compile('''
        <xs:element name="root">
          <xs:complexType>
            <xs:sequence minOccurs="0">
              <xs:element name="child"/>
            </xs:sequence>
          </xs:complexType>
        </xs:element>
      ''');

      // Root is 0; EE is 1 because the repeated sequence is nullable.
      final document = _decode(schema, '01');

      expect(document.toXmlString(), '<root/>');
    });

    test('decodes an unbounded repeated sequence', () {
      final schema = _compile('''
        <xs:element name="root">
          <xs:complexType>
            <xs:sequence minOccurs="0" maxOccurs="unbounded">
              <xs:element name="first"/>
              <xs:element name="second"/>
            </xs:sequence>
          </xs:complexType>
        </xs:element>
      ''');

      // Root=0, two leading first events=0/0, then EE=1.
      final document = _decode(schema, '0001');

      expect(document.toXmlString(), '<root><first/><second/><first/><second/></root>');
    });
  });

  test('decodes required and optional schema attributes', () {
    final schema = _compile('''
      <xs:element name="root">
        <xs:complexType>
          <xs:attribute name="enabled" type="xs:boolean"/>
          <xs:attribute name="id" type="xs:string" use="required"/>
        </xs:complexType>
      </xs:element>
    ''');
    final bits = StringBuffer()
      // Schema document root selection.
      ..write('0')
      // Skip optional enabled and select required id.
      ..write('1')
      ..write(_value('7'));

    final document = _decode(schema, bits.toString());

    expect(document.toXmlString(), '<root id="7"/>');
  });

  test('decodes a referenced global schema attribute', () {
    final schema = _compile('''
      <xs:element name="root">
        <xs:complexType>
          <xs:attribute ref="code" use="required"/>
        </xs:complexType>
      </xs:element>
      <xs:attribute name="code" type="xs:string"/>
    ''');
    final bits = StringBuffer()
      // Schema document root selection; the required attribute is implicit.
      ..write('0')
      ..write(_value('7'));

    final document = _decode(schema, bits.toString());

    expect(document.toXmlString(), '<root code="7"/>');
  });

  test('matches an OpenEXI strict schema-attribute vector', () {
    final schema = _compile('''
      <xs:element name="root">
        <xs:complexType>
          <xs:attribute name="enabled" type="xs:boolean"/>
          <xs:attribute name="id" type="xs:string" use="required"/>
        </xs:complexType>
      </xs:element>
    ''');

    final document = ExiDecoder(
      options: const ExiOptions(strict: true, schemaId: ExiSchemaId.named('particles')),
      schemaResolver: (_) => schema,
    ).decode(Uint8List.fromList([0x80, 0x40, 0xcd, 0xc0]));

    expect(document.toXmlString(), '<root id="7"/>');
  });
}

ExiSchema _compile(String elementDeclaration) {
  return ExiSchemaCompiler.compile(
    id: 'particles',
    source:
        '''
      <xs:schema xmlns:xs="http://www.w3.org/2001/XMLSchema">
        $elementDeclaration
      </xs:schema>
    ''',
  );
}

ExiDocument _decode(ExiSchema schema, String bodyBits) {
  final bits = '10000000$bodyBits';
  return ExiDecoder(
    options: const ExiOptions(strict: true, schemaId: ExiSchemaId.named('particles')),
    schemaResolver: (_) => schema,
  ).decode(_pack(bits));
}

String _value(String value) {
  final codePoints = value.runes.toList();
  return '${_unsigned(codePoints.length + 2)}${codePoints.map(_unsigned).join()}';
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
