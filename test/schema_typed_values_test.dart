import 'dart:typed_data';

import 'package:exi/exi.dart';
import 'package:test/test.dart';

void main() {
  test('decodes boolean, integer, and decimal schema values', () {
    const schemaId = 'values';
    const schema = ExiSchema(
      id: schemaId,
      globalElements: [
        ExiElementDeclaration.sequence(ExiQName(localName: 'root'), [
          ExiElementDeclaration.value(ExiQName(localName: 'flag'), ExiDatatype.boolean),
          ExiElementDeclaration.value(ExiQName(localName: 'count'), ExiDatatype.integer),
          ExiElementDeclaration.value(ExiQName(localName: 'amount'), ExiDatatype.decimal),
        ]),
      ],
    );
    final bits = StringBuffer('10000000')
      // Schema document root selection.
      ..write('0')
      // boolean true (two-bit lexical-value representation)
      ..write('10')
      // integer -3: negative sign and magnitude minus one.
      ..write('1')
      ..write(_unsigned(2))
      // decimal -12.034: sign, integral, reversed fractional 430.
      ..write('1')
      ..write(_unsigned(12))
      ..write(_unsigned(430));

    final document = ExiDecoder(
      options: const ExiOptions(strict: true, schemaId: ExiSchemaId.named(schemaId)),
      schemaResolver: (_) => schema,
    ).decode(_pack(bits.toString()));

    expect(document.toXmlString(), '<root><flag>true</flag><count>-3</count><amount>-12.034</amount></root>');
  });

  test('decodes a dateTime schema value', () {
    const schemaId = 'date-time';
    const schema = ExiSchema(
      id: schemaId,
      globalElements: [ExiElementDeclaration.value(ExiQName(localName: 'when'), ExiDatatype.dateTime)],
    );
    final encodedTime = ((12 * 64) + 34) * 64 + 56;
    final bits = StringBuffer('10000000')
      ..write('0')
      // Year 2024, month/day 07-01, time 12:34:56.
      ..write('0')
      ..write(_unsigned(24))
      ..write((7 * 32 + 1).toRadixString(2).padLeft(9, '0'))
      ..write(encodedTime.toRadixString(2).padLeft(17, '0'))
      // Fraction .25 (digits reversed), timezone +02:30.
      ..write('1')
      ..write(_unsigned(52))
      ..write('1')
      ..write((896 + 2 * 64 + 30).toRadixString(2).padLeft(11, '0'));

    final document = ExiDecoder(
      options: const ExiOptions(strict: true, schemaId: ExiSchemaId.named(schemaId)),
      schemaResolver: (_) => schema,
    ).decode(_pack(bits.toString()));

    expect(document.toXmlString(), '<when>2024-07-01T12:34:56.25+02:30</when>');
  });

  test('decodes partial Gregorian calendar schema values', () {
    const schemaId = 'calendar-values';
    final schema = ExiSchemaCompiler.compile(
      id: schemaId,
      source: '''
        <xs:schema xmlns:xs="http://www.w3.org/2001/XMLSchema">
          <xs:element name="root">
            <xs:complexType>
              <xs:sequence>
                <xs:element name="year" type="xs:gYear"/>
                <xs:element name="yearMonth" type="xs:gYearMonth"/>
                <xs:element name="month" type="xs:gMonth"/>
                <xs:element name="monthDay" type="xs:gMonthDay"/>
                <xs:element name="day" type="xs:gDay"/>
              </xs:sequence>
            </xs:complexType>
          </xs:element>
        </xs:schema>
      ''',
    );
    final bits = StringBuffer('10000000')
      // Root selection; gYear 2024 without timezone.
      ..write('0')
      ..write('0')
      ..write(_unsigned(24))
      ..write('0')
      // gYearMonth 1999-12Z.
      ..write('1')
      ..write(_unsigned(0))
      ..write((12 * 32).toRadixString(2).padLeft(9, '0'))
      ..write('1')
      ..write(896.toRadixString(2).padLeft(11, '0'))
      // gMonth --07-- without timezone.
      ..write((7 * 32).toRadixString(2).padLeft(9, '0'))
      ..write('0')
      // gMonthDay --07-01+02:30.
      ..write((7 * 32 + 1).toRadixString(2).padLeft(9, '0'))
      ..write('1')
      ..write((896 + 2 * 64 + 30).toRadixString(2).padLeft(11, '0'))
      // gDay ---31-05:00.
      ..write(31.toRadixString(2).padLeft(9, '0'))
      ..write('1')
      ..write((896 - 5 * 64).toRadixString(2).padLeft(11, '0'));

    final document = ExiDecoder(
      options: const ExiOptions(strict: true, schemaId: ExiSchemaId.named(schemaId)),
      schemaResolver: (_) => schema,
    ).decode(_pack(bits.toString()));

    expect(
      document.toXmlString(),
      '<root><year>2024</year><yearMonth>1999-12Z</yearMonth><month>--07--</month>'
      '<monthDay>--07-01+02:30</monthDay><day>---31-05:00</day></root>',
    );
  });

  test('rejects an invalid Gregorian month/day combination', () {
    const schemaId = 'invalid-calendar';
    const schema = ExiSchema(
      id: schemaId,
      globalElements: [ExiElementDeclaration.value(ExiQName(localName: 'value'), ExiDatatype.gMonthDay)],
    );
    final bits = StringBuffer('10000000')
      ..write('0')
      // April 31, followed by no timezone.
      ..write((4 * 32 + 31).toRadixString(2).padLeft(9, '0'))
      ..write('0');

    expect(
      () => ExiDecoder(
        options: const ExiOptions(strict: true, schemaId: ExiSchemaId.named(schemaId)),
        schemaResolver: (_) => schema,
      ).decode(_pack(bits.toString())),
      throwsFormatException,
    );
  });

  test('decodes a value declared through a named simple type', () {
    const schemaId = 'named-simple';
    final schema = ExiSchemaCompiler.compile(
      id: schemaId,
      source: '''
        <xs:schema xmlns:xs="http://www.w3.org/2001/XMLSchema">
          <xs:simpleType name="Count">
            <xs:restriction base="xs:integer"/>
          </xs:simpleType>
          <xs:element name="count" type="Count"/>
        </xs:schema>
      ''',
    );
    final bits = StringBuffer('10000000')
      // Root selection, positive integer sign, then magnitude 7.
      ..write('00')
      ..write(_unsigned(7));

    final document = ExiDecoder(
      options: const ExiOptions(strict: true, schemaId: ExiSchemaId.named(schemaId)),
      schemaResolver: (_) => schema,
    ).decode(_pack(bits.toString()));

    expect(document.toXmlString(), '<count>7</count>');
  });

  test('uses the String representation for schema QName and NOTATION values', () {
    const schemaId = 'qname-element';
    final schema = ExiSchemaCompiler.compile(
      id: schemaId,
      source: '''
        <xs:schema
            xmlns:xs="http://www.w3.org/2001/XMLSchema"
            targetNamespace="urn:values">
          <xs:element name="value" type="xs:QName"/>
        </xs:schema>
      ''',
    );
    final bits = StringBuffer('10000000')
      // Root selection followed by the QName lexical form as a String value.
      ..write('0')
      ..write(_value('tns:value'));

    final document = ExiDecoder(
      options: const ExiOptions(strict: true, schemaId: ExiSchemaId.named(schemaId)),
      schemaResolver: (_) => schema,
    ).decode(_pack(bits.toString()));

    expect(schema.globalElements.single.datatype, ExiDatatype.string);
    expect(document.events.whereType<ExiCharacters>().single.value, 'tns:value');

    final notationSchema = ExiSchemaCompiler.compile(
      id: 'notation',
      source: '''
        <xs:schema xmlns:xs="http://www.w3.org/2001/XMLSchema">
          <xs:element name="notation" type="xs:NOTATION"/>
        </xs:schema>
      ''',
    );
    expect(notationSchema.globalElements.single.datatype, ExiDatatype.string);
  });

  test('uses the String representation for a schema QName attribute', () {
    const schemaId = 'qname-attribute';
    final schema = ExiSchemaCompiler.compile(
      id: schemaId,
      source: '''
        <xs:schema
            xmlns:xs="http://www.w3.org/2001/XMLSchema"
            targetNamespace="urn:values">
          <xs:element name="root">
            <xs:complexType>
              <xs:attribute name="code" type="xs:QName" use="required"/>
            </xs:complexType>
          </xs:element>
        </xs:schema>
      ''',
    );
    final bits = StringBuffer('10000000')
      // Root and required attribute events are implicit; the value is a String.
      ..write('0')
      ..write(_value('tns:root'));

    final document = ExiDecoder(
      options: const ExiOptions(strict: true, schemaId: ExiSchemaId.named(schemaId)),
      schemaResolver: (_) => schema,
    ).decode(_pack(bits.toString()));

    expect(document.events.whereType<ExiAttribute>().single.value, 'tns:root');
  });

  test('uses the String representation for schema duration values', () {
    const schemaId = 'durations';
    final schema = ExiSchemaCompiler.compile(
      id: schemaId,
      source: '''
        <xs:schema xmlns:xs="http://www.w3.org/2001/XMLSchema">
          <xs:element name="root">
            <xs:complexType>
              <xs:sequence>
                <xs:element name="positive" type="xs:duration"/>
                <xs:element name="negative" type="xs:duration"/>
                <xs:element name="zero" type="xs:duration"/>
              </xs:sequence>
            </xs:complexType>
          </xs:element>
        </xs:schema>
      ''',
    );
    final bits = StringBuffer('10000000')
      // Root/children are schema-declared; duration has no default EXI
      // datatype representation and is therefore encoded as String.
      ..write('0')
      ..write(_value('P1Y2M3DT4H5M6.7S'))
      ..write(_value('-P3DT1S'))
      ..write(_value('PT0S'));

    final document = ExiDecoder(
      options: const ExiOptions(strict: true, schemaId: ExiSchemaId.named(schemaId)),
      schemaResolver: (_) => schema,
    ).decode(_pack(bits.toString()));

    expect(
      document.toXmlString(),
      '<root><positive>P1Y2M3DT4H5M6.7S</positive><negative>-P3DT1S</negative><zero>PT0S</zero></root>',
    );
  });

  test('decodes a named list of schema-typed integers', () {
    const schemaId = 'integer-list';
    final schema = ExiSchemaCompiler.compile(
      id: schemaId,
      source: '''
        <xs:schema xmlns:xs="http://www.w3.org/2001/XMLSchema">
          <xs:simpleType name="IntegerList">
            <xs:list itemType="xs:integer"/>
          </xs:simpleType>
          <xs:element name="values" type="IntegerList"/>
        </xs:schema>
      ''',
    );
    final bits = StringBuffer('10000000')
      // Root selection and list length.
      ..write('0')
      ..write(_unsigned(3))
      // Integer items 1, -2, and 3.
      ..write('0')
      ..write(_unsigned(1))
      ..write('1')
      ..write(_unsigned(1))
      ..write('0')
      ..write(_unsigned(3));

    final document = ExiDecoder(
      options: const ExiOptions(strict: true, schemaId: ExiSchemaId.named(schemaId)),
      schemaResolver: (_) => schema,
    ).decode(_pack(bits.toString()));

    expect(schema.globalElements.single.datatype, ExiDatatype.list);
    expect(schema.globalElements.single.listItemDatatype, ExiDatatype.integer);
    expect(document.toXmlString(), '<values>1 -2 3</values>');
  });

  test('decodes built-in and inline schema list types', () {
    const schemaId = 'other-lists';
    final schema = ExiSchemaCompiler.compile(
      id: schemaId,
      source: '''
        <xs:schema xmlns:xs="http://www.w3.org/2001/XMLSchema">
          <xs:element name="root">
            <xs:complexType>
              <xs:sequence>
                <xs:element name="tokens" type="xs:NMTOKENS"/>
              </xs:sequence>
              <xs:attribute name="flags" use="required">
                <xs:simpleType>
                  <xs:list itemType="xs:boolean"/>
                </xs:simpleType>
              </xs:attribute>
            </xs:complexType>
          </xs:element>
        </xs:schema>
      ''',
    );
    final bits = StringBuffer('10000000')
      // Root and required attribute are implicit; two Boolean list items.
      ..write('0')
      ..write(_unsigned(2))
      ..write('10')
      ..write('00')
      // The tokens child is implicit; two String list items.
      ..write(_unsigned(2))
      ..write(_rawString('one'))
      ..write(_rawString('two'));

    final document = ExiDecoder(
      options: const ExiOptions(strict: true, schemaId: ExiSchemaId.named(schemaId)),
      schemaResolver: (_) => schema,
    ).decode(_pack(bits.toString()));

    expect(document.toXmlString(), '<root flags="true false"><tokens>one two</tokens></root>');
  });

  test('uses the String representation for named and inline union types', () {
    const schemaId = 'unions';
    final schema = ExiSchemaCompiler.compile(
      id: schemaId,
      source: '''
        <xs:schema xmlns:xs="http://www.w3.org/2001/XMLSchema">
          <xs:simpleType name="Scalar">
            <xs:union memberTypes="xs:boolean xs:integer"/>
          </xs:simpleType>
          <xs:element name="root">
            <xs:complexType>
              <xs:sequence>
                <xs:element name="value" type="Scalar"/>
              </xs:sequence>
              <xs:attribute name="choice" use="required">
                <xs:simpleType>
                  <xs:union>
                    <xs:simpleType>
                      <xs:restriction base="xs:date"/>
                    </xs:simpleType>
                    <xs:simpleType>
                      <xs:restriction base="xs:time"/>
                    </xs:simpleType>
                  </xs:union>
                </xs:simpleType>
              </xs:attribute>
            </xs:complexType>
          </xs:element>
        </xs:schema>
      ''',
    );
    final bits = StringBuffer('10000000')
      // Root and required attribute are implicit; union values are Strings.
      ..write('0')
      ..write(_value('2026-07-03'))
      ..write(_value('true'));

    final document = ExiDecoder(
      options: const ExiOptions(strict: true, schemaId: ExiSchemaId.named(schemaId)),
      schemaResolver: (_) => schema,
    ).decode(_pack(bits.toString()));

    expect(document.toXmlString(), '<root choice="2026-07-03"><value>true</value></root>');
  });

  test('rejects an XSD union without member types', () {
    expect(
      () => ExiSchemaCompiler.compile(
        id: 'empty-union',
        source: '''
          <xs:schema xmlns:xs="http://www.w3.org/2001/XMLSchema">
            <xs:element name="value">
              <xs:simpleType>
                <xs:union/>
              </xs:simpleType>
            </xs:element>
          </xs:schema>
        ''',
      ),
      throwsFormatException,
    );
  });

  test('decodes typed simple content after a required attribute', () {
    const schemaId = 'simple-content';
    final schema = ExiSchemaCompiler.compile(
      id: schemaId,
      source: '''
        <xs:schema xmlns:xs="http://www.w3.org/2001/XMLSchema">
          <xs:element name="label">
            <xs:complexType>
              <xs:simpleContent>
                <xs:extension base="xs:string">
                  <xs:attribute name="id" type="xs:string" use="required"/>
                </xs:extension>
              </xs:simpleContent>
            </xs:complexType>
          </xs:element>
        </xs:schema>
      ''',
    );
    final bits = StringBuffer('10000000')
      // Root selection; required id and typed CH productions are implicit.
      ..write('0')
      ..write(_value('7'))
      ..write(_value('hello'));

    final document = ExiDecoder(
      options: const ExiOptions(strict: true, schemaId: ExiSchemaId.named(schemaId)),
      schemaResolver: (_) => schema,
    ).decode(_pack(bits.toString()));

    expect(document.toXmlString(), '<label id="7">hello</label>');
  });

  test('applies the empty grammar to nilled simple content', () {
    const schemaId = 'nilled-simple-content';
    final schema = ExiSchemaCompiler.compile(
      id: schemaId,
      source: '''
        <xs:schema xmlns:xs="http://www.w3.org/2001/XMLSchema">
          <xs:element name="label" nillable="true">
            <xs:complexType>
              <xs:simpleContent>
                <xs:extension base="xs:string">
                  <xs:attribute name="id" type="xs:string" use="required"/>
                </xs:extension>
              </xs:simpleContent>
            </xs:complexType>
          </xs:element>
        </xs:schema>
      ''',
    );
    final bits = StringBuffer('10000000')
      // Root=0; xsi:nil escape=1; true=10; required id remains implicit.
      ..write('0110')
      ..write(_value('7'));

    final document = ExiDecoder(
      options: const ExiOptions(strict: true, schemaId: ExiSchemaId.named(schemaId)),
      schemaResolver: (_) => schema,
    ).decode(_pack(bits.toString()));

    expect(document.events.whereType<ExiAttribute>().map((event) => event.value), ['true', '7']);
    expect(document.events.whereType<ExiCharacters>(), isEmpty);
  });

  test('matches an OpenEXI strict schema-typed vector', () {
    const schemaId = 'openexi';
    final schema = ExiSchemaCompiler.compile(
      id: schemaId,
      source: '''
        <xs:schema xmlns:xs="http://www.w3.org/2001/XMLSchema">
          <xs:element name="root">
            <xs:complexType>
              <xs:sequence>
                <xs:element name="flag" type="xs:boolean"/>
                <xs:element name="count" type="xs:integer"/>
              </xs:sequence>
            </xs:complexType>
          </xs:element>
        </xs:schema>
      ''',
    );

    final document = ExiDecoder(
      options: const ExiOptions(strict: true, schemaId: ExiSchemaId.named(schemaId)),
      schemaResolver: (_) => schema,
    ).decode(Uint8List.fromList([0x80, 0x50, 0x20]));

    expect(document.toXmlString(), '<root><flag>true</flag><count>-3</count></root>');
  });
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

String _value(String value) {
  final codePoints = value.runes.toList();
  return '${_unsigned(codePoints.length + 2)}${codePoints.map(_unsigned).join()}';
}

String _rawString(String value) {
  final codePoints = value.runes.toList();
  return '${_unsigned(codePoints.length)}${codePoints.map(_unsigned).join()}';
}

Uint8List _pack(String bits) {
  final padded = bits.padRight((bits.length + 7) ~/ 8 * 8, '0');
  return Uint8List.fromList([
    for (var offset = 0; offset < padded.length; offset += 8) int.parse(padded.substring(offset, offset + 8), radix: 2),
  ]);
}
