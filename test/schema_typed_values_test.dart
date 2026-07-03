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
      // Unpatterned Boolean true.
      ..write('1')
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

  test('preserves lexical forms of schema-typed element and attribute values', () {
    const schemaId = 'lexical-values';
    const schema = ExiSchema(
      id: schemaId,
      globalElements: [
        ExiElementDeclaration.complex(
          ExiQName(localName: 'root'),
          attributes: [
            ExiAttributeDeclaration(
              name: ExiQName(localName: 'count'),
              datatype: ExiDatatype.integer,
              required: true,
            ),
          ],
          content: ExiElementParticle(ExiElementDeclaration.value(ExiQName(localName: 'flag'), ExiDatatype.boolean)),
        ),
      ],
    );
    final bits = StringBuffer('10000000')
      // Root selection and required attribute/child productions are implicit.
      ..write('0')
      ..write(_restrictedValue('+007', _integerCharacters))
      ..write(_restrictedValue('1', _booleanCharacters));

    final document = ExiDecoder(
      options: const ExiOptions(
        strict: true,
        schemaId: ExiSchemaId.named(schemaId),
        fidelity: ExiFidelityOptions(lexicalValues: true),
      ),
      schemaResolver: (_) => schema,
    ).decode(_pack(bits.toString()));

    expect(document.toXmlString(), '<root count="+007"><flag>1</flag></root>');
  });

  test('uses lexical String values for xsi:nil and xsi:type', () {
    const nilSchemaId = 'lexical-nil';
    const nilSchema = ExiSchema(
      id: nilSchemaId,
      globalElements: [ExiElementDeclaration.value(ExiQName(localName: 'value'), ExiDatatype.integer, nillable: true)],
    );
    final nilBits = StringBuffer('10000000')
      // Root selection and xsi:nil escape.
      ..write('01')
      ..write(_restrictedValue('1', _booleanCharacters));
    final nilDocument = ExiDecoder(
      options: const ExiOptions(
        strict: true,
        schemaId: ExiSchemaId.named(nilSchemaId),
        fidelity: ExiFidelityOptions(lexicalValues: true),
      ),
      schemaResolver: (_) => nilSchema,
    ).decode(_pack(nilBits.toString()));

    expect(nilDocument.events.whereType<ExiAttribute>().single.value, '1');
    expect(nilDocument.events.whereType<ExiCharacters>(), isEmpty);

    const typeSchemaId = 'lexical-type';
    const rootName = ExiQName(localName: 'root');
    final typeSchema = ExiSchema(
      id: typeSchemaId,
      globalElements: [
        ExiElementDeclaration.empty(
          rootName,
          typeAlternatives: {ExiQName(uri: 'urn:types', localName: 'Derived'): ExiElementDeclaration.empty(rootName)},
        ),
      ],
    );
    final typeBits = StringBuffer('10000000')
      // Root selection and xsi:type escape.
      ..write('01')
      ..write(_value('t:Derived'));
    final typeDocument = ExiDecoder(
      options: const ExiOptions(
        strict: true,
        schemaId: ExiSchemaId.named(typeSchemaId),
        fidelity: ExiFidelityOptions(lexicalValues: true),
      ),
      schemaResolver: (_) => typeSchema,
    ).decode(_pack(typeBits.toString()));

    expect(typeDocument.events.whereType<ExiAttribute>().single.value, 't:Derived');
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

  test('decodes Float boundary and special values', () {
    const schemaId = 'float-values';
    const schema = ExiSchema(
      id: schemaId,
      globalElements: [
        ExiElementDeclaration.sequence(ExiQName(localName: 'root'), [
          ExiElementDeclaration.value(ExiQName(localName: 'maximum'), ExiDatatype.float),
          ExiElementDeclaration.value(ExiQName(localName: 'minimum'), ExiDatatype.float),
          ExiElementDeclaration.value(ExiQName(localName: 'infinity'), ExiDatatype.float),
          ExiElementDeclaration.value(ExiQName(localName: 'notANumber'), ExiDatatype.float),
        ]),
      ],
    );
    final bits = StringBuffer('10000000')
      ..write('0')
      ..write(_signed((BigInt.one << 63) - BigInt.one))
      ..write(_signed((BigInt.one << 14) - BigInt.one))
      ..write(_signed(-(BigInt.one << 63)))
      ..write(_signed(-(BigInt.one << 14) + BigInt.one))
      ..write(_signed(BigInt.one))
      ..write(_signed(-(BigInt.one << 14)))
      ..write(_signed(BigInt.zero))
      ..write(_signed(-(BigInt.one << 14)));

    final document = ExiDecoder(
      options: const ExiOptions(strict: true, schemaId: ExiSchemaId.named(schemaId)),
      schemaResolver: (_) => schema,
    ).decode(_pack(bits.toString()));

    expect(
      document.toXmlString(),
      '<root><maximum>9223372036854775807E16383</maximum>'
      '<minimum>-9223372036854775808E-16383</minimum>'
      '<infinity>INF</infinity><notANumber>NaN</notANumber></root>',
    );
  });

  test('rejects Float components outside the EXI representation ranges', () {
    const schemaId = 'invalid-float';
    const schema = ExiSchema(
      id: schemaId,
      globalElements: [ExiElementDeclaration.value(ExiQName(localName: 'value'), ExiDatatype.float)],
    );

    for (final (mantissa, exponent) in [
      (BigInt.one << 63, BigInt.zero),
      (BigInt.zero, BigInt.one << 14),
      (BigInt.zero, -(BigInt.one << 14) - BigInt.one),
    ]) {
      final bits = StringBuffer('10000000')
        ..write('0')
        ..write(_signed(mantissa))
        ..write(_signed(exponent));

      expect(
        () => ExiDecoder(
          options: const ExiOptions(strict: true, schemaId: ExiSchemaId.named(schemaId)),
          schemaResolver: (_) => schema,
        ).decode(_pack(bits.toString())),
        throwsFormatException,
        reason: 'mantissa=$mantissa exponent=$exponent',
      );
    }
  });

  test('rejects invalid XML Schema calendar boundaries', () {
    const timeSchemaId = 'invalid-time-boundary';
    const timeSchema = ExiSchema(
      id: timeSchemaId,
      globalElements: [ExiElementDeclaration.value(ExiQName(localName: 'value'), ExiDatatype.time)],
    );
    final invalidTime = StringBuffer('10000000')
      ..write('0')
      ..write((((24 * 64) + 1) * 64).toRadixString(2).padLeft(17, '0'))
      ..write('0')
      ..write('0');
    expect(
      () => ExiDecoder(
        options: const ExiOptions(strict: true, schemaId: ExiSchemaId.named(timeSchemaId)),
        schemaResolver: (_) => timeSchema,
      ).decode(_pack(invalidTime.toString())),
      throwsFormatException,
    );

    const dateSchemaId = 'invalid-year-zero';
    const dateSchema = ExiSchema(
      id: dateSchemaId,
      globalElements: [ExiElementDeclaration.value(ExiQName(localName: 'value'), ExiDatatype.date)],
    );
    final invalidDate = StringBuffer('10000000')
      ..write('0')
      ..write(_signed(BigInt.from(-2000)))
      ..write((1 * 32 + 1).toRadixString(2).padLeft(9, '0'))
      ..write('0');
    expect(
      () => ExiDecoder(
        options: const ExiOptions(strict: true, schemaId: ExiSchemaId.named(dateSchemaId)),
        schemaResolver: (_) => dateSchema,
      ).decode(_pack(invalidDate.toString())),
      throwsFormatException,
    );
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

  test('accepts representation-neutral XSD facets', () {
    const schemaId = 'neutral-facets';
    final schema = ExiSchemaCompiler.compile(
      id: schemaId,
      source: '''
        <xs:schema xmlns:xs="http://www.w3.org/2001/XMLSchema">
          <xs:simpleType name="Amount">
            <xs:restriction base="xs:decimal">
              <xs:minExclusive value="-10"/>
              <xs:maxInclusive value="10"/>
              <xs:totalDigits value="3"/>
              <xs:fractionDigits value="2"/>
            </xs:restriction>
          </xs:simpleType>
          <xs:simpleType name="Label">
            <xs:restriction base="xs:string">
              <xs:minLength value="1"/>
              <xs:maxLength value="10"/>
              <xs:whiteSpace value="preserve"/>
            </xs:restriction>
          </xs:simpleType>
          <xs:element name="root">
            <xs:complexType>
              <xs:sequence>
                <xs:element name="amount" type="Amount"/>
                <xs:element name="label" type="Label"/>
              </xs:sequence>
            </xs:complexType>
          </xs:element>
        </xs:schema>
      ''',
    );
    final bits = StringBuffer('10000000')
      ..write('0')
      // Decimal 1.25: positive sign, integral, reversed fraction.
      ..write('0')
      ..write(_unsigned(1))
      ..write(_unsigned(52))
      ..write(_value('example'));

    final document = ExiDecoder(
      options: const ExiOptions(strict: true, schemaId: ExiSchemaId.named(schemaId)),
      schemaResolver: (_) => schema,
    ).decode(_pack(bits.toString()));

    expect(document.toXmlString(), '<root><amount>1.25</amount><label>example</label></root>');
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
      ..write('1')
      ..write('0')
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

  test('decodes schema enumeration values by schema-order ordinal', () {
    const schemaId = 'enumerations';
    final schema = ExiSchemaCompiler.compile(
      id: schemaId,
      source: '''
        <xs:schema xmlns:xs="http://www.w3.org/2001/XMLSchema">
          <xs:simpleType name="Color">
            <xs:restriction base="xs:string">
              <xs:enumeration value="red"/>
              <xs:enumeration value="green"/>
              <xs:enumeration value="blue"/>
            </xs:restriction>
          </xs:simpleType>
          <xs:simpleType name="Number">
            <xs:restriction base="xs:integer">
              <xs:enumeration value="1"/>
              <xs:enumeration value="2"/>
              <xs:enumeration value="3"/>
            </xs:restriction>
          </xs:simpleType>
          <xs:element name="root">
            <xs:complexType>
              <xs:sequence>
                <xs:element name="color" type="Color"/>
                <xs:element name="number" type="Number"/>
              </xs:sequence>
            </xs:complexType>
          </xs:element>
        </xs:schema>
      ''',
    );
    final bits = StringBuffer('10000000')
      // Root selection; color ordinal 2 and number ordinal 1.
      ..write('0')
      ..write('10')
      ..write('01');

    final document = ExiDecoder(
      options: const ExiOptions(strict: true, schemaId: ExiSchemaId.named(schemaId)),
      schemaResolver: (_) => schema,
    ).decode(_pack(bits.toString()));

    expect(document.toXmlString(), '<root><color>blue</color><number>2</number></root>');
  });

  test('rejects an unused enumeration ordinal', () {
    const schemaId = 'invalid-enumeration';
    final schema = ExiSchemaCompiler.compile(
      id: schemaId,
      source: '''
        <xs:schema xmlns:xs="http://www.w3.org/2001/XMLSchema">
          <xs:element name="value">
            <xs:simpleType>
              <xs:restriction base="xs:string">
                <xs:enumeration value="red"/>
                <xs:enumeration value="green"/>
                <xs:enumeration value="blue"/>
              </xs:restriction>
            </xs:simpleType>
          </xs:element>
        </xs:schema>
      ''',
    );

    expect(
      () => ExiDecoder(
        options: const ExiOptions(strict: true, schemaId: ExiSchemaId.named(schemaId)),
        schemaResolver: (_) => schema,
      ).decode(_pack('10000000011')),
      throwsFormatException,
    );
  });

  test('decodes a bounded integer as an offset from its minimum', () {
    const schemaId = 'bounded-integer';
    final schema = ExiSchemaCompiler.compile(
      id: schemaId,
      source: '''
        <xs:schema xmlns:xs="http://www.w3.org/2001/XMLSchema">
          <xs:element name="value">
            <xs:simpleType>
              <xs:restriction base="xs:integer">
                <xs:minInclusive value="-2"/>
                <xs:maxExclusive value="3"/>
              </xs:restriction>
            </xs:simpleType>
          </xs:element>
        </xs:schema>
      ''',
    );

    final document = ExiDecoder(
      options: const ExiOptions(strict: true, schemaId: ExiSchemaId.named(schemaId)),
      schemaResolver: (_) => schema,
    ).decode(_pack('100000000011'));

    expect(document.toXmlString(), '<value>1</value>');
  });

  test('rejects an unused bounded-integer offset', () {
    const schemaId = 'invalid-bounded-integer';
    final schema = ExiSchemaCompiler.compile(
      id: schemaId,
      source: '''
        <xs:schema xmlns:xs="http://www.w3.org/2001/XMLSchema">
          <xs:element name="value">
            <xs:simpleType>
              <xs:restriction base="xs:integer">
                <xs:minInclusive value="-2"/>
                <xs:maxInclusive value="2"/>
              </xs:restriction>
            </xs:simpleType>
          </xs:element>
        </xs:schema>
      ''',
    );

    expect(
      () => ExiDecoder(
        options: const ExiOptions(strict: true, schemaId: ExiSchemaId.named(schemaId)),
        schemaResolver: (_) => schema,
      ).decode(_pack('100000000111')),
      throwsFormatException,
    );
  });

  test('uses the absolute unsigned value for a one-sided nonnegative integer range', () {
    const schemaId = 'one-sided-integer';
    final schema = ExiSchemaCompiler.compile(
      id: schemaId,
      source: '''
        <xs:schema xmlns:xs="http://www.w3.org/2001/XMLSchema">
          <xs:element name="value">
            <xs:simpleType>
              <xs:restriction base="xs:integer">
                <xs:minExclusive value="4"/>
              </xs:restriction>
            </xs:simpleType>
          </xs:element>
        </xs:schema>
      ''',
    );
    final bits = StringBuffer('10000000')
      ..write('0')
      ..write(_unsigned(7));

    final document = ExiDecoder(
      options: const ExiOptions(strict: true, schemaId: ExiSchemaId.named(schemaId)),
      schemaResolver: (_) => schema,
    ).decode(_pack(bits.toString()));

    expect(document.toXmlString(), '<value>7</value>');
  });

  test('uses unsigned integer encoding when a bounded range exceeds 4096 values', () {
    const schemaId = 'large-bounded-integer';
    final schema = ExiSchemaCompiler.compile(
      id: schemaId,
      source: '''
        <xs:schema xmlns:xs="http://www.w3.org/2001/XMLSchema">
          <xs:element name="value">
            <xs:simpleType>
              <xs:restriction base="xs:integer">
                <xs:minInclusive value="0"/>
                <xs:maxInclusive value="4096"/>
              </xs:restriction>
            </xs:simpleType>
          </xs:element>
        </xs:schema>
      ''',
    );
    final bits = StringBuffer('10000000')
      ..write('0')
      ..write(_unsigned(4096));

    final document = ExiDecoder(
      options: const ExiOptions(strict: true, schemaId: ExiSchemaId.named(schemaId)),
      schemaResolver: (_) => schema,
    ).decode(_pack(bits.toString()));

    expect(document.toXmlString(), '<value>4096</value>');
  });

  test('rejects an integer outside a one-sided schema range', () {
    const schemaId = 'out-of-range-integer';
    final schema = ExiSchemaCompiler.compile(
      id: schemaId,
      source: '''
        <xs:schema xmlns:xs="http://www.w3.org/2001/XMLSchema">
          <xs:element name="value">
            <xs:simpleType>
              <xs:restriction base="xs:integer">
                <xs:minInclusive value="5"/>
              </xs:restriction>
            </xs:simpleType>
          </xs:element>
        </xs:schema>
      ''',
    );
    final bits = StringBuffer('10000000')
      ..write('0')
      ..write(_unsigned(4));

    expect(
      () => ExiDecoder(
        options: const ExiOptions(strict: true, schemaId: ExiSchemaId.named(schemaId)),
        schemaResolver: (_) => schema,
      ).decode(_pack(bits.toString())),
      throwsFormatException,
    );
  });

  test('decodes an enumerated schema attribute', () {
    const schemaId = 'attribute-enumeration';
    final schema = ExiSchemaCompiler.compile(
      id: schemaId,
      source: '''
        <xs:schema xmlns:xs="http://www.w3.org/2001/XMLSchema">
          <xs:element name="root">
            <xs:complexType>
              <xs:attribute name="state" use="required">
                <xs:simpleType>
                  <xs:restriction base="xs:string">
                    <xs:enumeration value="off"/>
                    <xs:enumeration value="on"/>
                  </xs:restriction>
                </xs:simpleType>
              </xs:attribute>
            </xs:complexType>
          </xs:element>
        </xs:schema>
      ''',
    );

    // Root and required attribute events are implicit; "on" is ordinal 1.
    final document = ExiDecoder(
      options: const ExiOptions(strict: true, schemaId: ExiSchemaId.named(schemaId)),
      schemaResolver: (_) => schema,
    ).decode(_pack('1000000001'));

    expect(document.toXmlString(), '<root state="on"/>');
  });

  test('keeps union enumerations on the String representation', () {
    const schemaId = 'union-enumeration';
    final schema = ExiSchemaCompiler.compile(
      id: schemaId,
      source: '''
        <xs:schema xmlns:xs="http://www.w3.org/2001/XMLSchema">
          <xs:simpleType name="Scalar">
            <xs:union memberTypes="xs:boolean xs:integer"/>
          </xs:simpleType>
          <xs:simpleType name="RestrictedScalar">
            <xs:restriction base="Scalar">
              <xs:enumeration value="true"/>
              <xs:enumeration value="7"/>
            </xs:restriction>
          </xs:simpleType>
          <xs:element name="value" type="RestrictedScalar"/>
        </xs:schema>
      ''',
    );
    final bits = StringBuffer('10000000')
      ..write('0')
      ..write(_value('true'));

    final document = ExiDecoder(
      options: const ExiOptions(strict: true, schemaId: ExiSchemaId.named(schemaId)),
      schemaResolver: (_) => schema,
    ).decode(_pack(bits.toString()));

    expect(document.toXmlString(), '<value>true</value>');
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
      // Root=0; xsi:nil escape=1; true=1; required id remains implicit.
      ..write('011')
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
                <xs:element name="flag">
                  <xs:simpleType>
                    <xs:restriction base="xs:boolean">
                      <xs:pattern value="true|1"/>
                    </xs:restriction>
                  </xs:simpleType>
                </xs:element>
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

  test('uses the four Boolean lexical codes when a pattern facet is available', () {
    const schemaId = 'patterned-boolean';
    final schema = ExiSchemaCompiler.compile(
      id: schemaId,
      source: '''
        <xs:schema xmlns:xs="http://www.w3.org/2001/XMLSchema">
          <xs:simpleType name="PatternedBoolean">
            <xs:restriction base="xs:boolean">
              <xs:pattern value="true|1"/>
            </xs:restriction>
          </xs:simpleType>
          <xs:simpleType name="DerivedBoolean">
            <xs:restriction base="PatternedBoolean"/>
          </xs:simpleType>
          <xs:element name="flag" type="DerivedBoolean"/>
        </xs:schema>
      ''',
    );

    for (final (code, lexical) in [('00', 'false'), ('01', '0'), ('10', 'true'), ('11', '1')]) {
      final document = ExiDecoder(
        options: const ExiOptions(strict: true, schemaId: ExiSchemaId.named(schemaId)),
        schemaResolver: (_) => schema,
      ).decode(_pack('100000000$code'));

      expect(document.toXmlString(), '<flag>$lexical</flag>');
    }
  });

  test('uses a restricted character set derived from a string pattern', () {
    const schemaId = 'patterned-string';
    final schema = ExiSchemaCompiler.compile(
      id: schemaId,
      source: '''
        <xs:schema xmlns:xs="http://www.w3.org/2001/XMLSchema">
          <xs:simpleType name="Code">
            <xs:restriction base="xs:string">
              <xs:pattern value="[A-F-[DE]][0-2]+"/>
            </xs:restriction>
          </xs:simpleType>
          <xs:element name="code" type="Code"/>
        </xs:schema>
      ''',
    );
    const characters = [48, 49, 50, 65, 66, 67, 70];
    final bits = '100000000${_restrictedValue('B20', characters)}';

    final document = ExiDecoder(
      options: const ExiOptions(strict: true, schemaId: ExiSchemaId.named(schemaId)),
      schemaResolver: (_) => schema,
    ).decode(_pack(bits));

    expect(document.toXmlString(), '<code>B20</code>');
  });

  test('uses only the most-derived immediate string patterns', () {
    const schemaId = 'derived-patterned-string';
    final schema = ExiSchemaCompiler.compile(
      id: schemaId,
      source: '''
        <xs:schema xmlns:xs="http://www.w3.org/2001/XMLSchema">
          <xs:simpleType name="BaseCode">
            <xs:restriction base="xs:string">
              <xs:pattern value="[A-C]"/>
            </xs:restriction>
          </xs:simpleType>
          <xs:simpleType name="InheritedCode">
            <xs:restriction base="BaseCode"/>
          </xs:simpleType>
          <xs:simpleType name="DerivedCode">
            <xs:restriction base="InheritedCode">
              <xs:pattern value="(X|[Y-Z])"/>
            </xs:restriction>
          </xs:simpleType>
          <xs:element name="code" type="DerivedCode"/>
        </xs:schema>
      ''',
    );
    const characters = [88, 89, 90];
    final bits = '100000000${_restrictedValue('Y', characters)}';

    final document = ExiDecoder(
      options: const ExiOptions(strict: true, schemaId: ExiSchemaId.named(schemaId)),
      schemaResolver: (_) => schema,
    ).decode(_pack(bits));

    expect(document.toXmlString(), '<code>Y</code>');
  });

  test('falls back to the normal String representation for an unbounded pattern charset', () {
    const schemaId = 'unbounded-patterned-string';
    final schema = ExiSchemaCompiler.compile(
      id: schemaId,
      source: r'''
        <xs:schema xmlns:xs="http://www.w3.org/2001/XMLSchema">
          <xs:simpleType name="Digits">
            <xs:restriction base="xs:string">
              <xs:pattern value="\d+"/>
            </xs:restriction>
          </xs:simpleType>
          <xs:element name="value" type="Digits"/>
        </xs:schema>
      ''',
    );
    final bits = '100000000${_value('123')}';

    final document = ExiDecoder(
      options: const ExiOptions(strict: true, schemaId: ExiSchemaId.named(schemaId)),
      schemaResolver: (_) => schema,
    ).decode(_pack(bits));

    expect(document.toXmlString(), '<value>123</value>');
  });

  test('propagates the union of immediate pattern charsets to attributes and list items', () {
    const schemaId = 'patterned-attribute-list';
    final schema = ExiSchemaCompiler.compile(
      id: schemaId,
      source: '''
        <xs:schema xmlns:xs="http://www.w3.org/2001/XMLSchema">
          <xs:simpleType name="Code">
            <xs:restriction base="xs:string">
              <xs:pattern value="[A-C]+"/>
              <xs:pattern value="[0-1]+"/>
            </xs:restriction>
          </xs:simpleType>
          <xs:simpleType name="Codes">
            <xs:list itemType="Code"/>
          </xs:simpleType>
          <xs:element name="root">
            <xs:complexType>
              <xs:sequence>
                <xs:element name="values" type="Codes"/>
              </xs:sequence>
              <xs:attribute name="code" type="Code" use="required"/>
            </xs:complexType>
          </xs:element>
        </xs:schema>
      ''',
    );
    const characters = [48, 49, 65, 66, 67];
    final bits = StringBuffer('100000000')
      ..write(_restrictedValue('B1', characters))
      ..write(_unsigned(2))
      ..write(_restrictedString('A0', characters))
      ..write(_restrictedString('C1', characters));

    final document = ExiDecoder(
      options: const ExiOptions(strict: true, schemaId: ExiSchemaId.named(schemaId)),
      schemaResolver: (_) => schema,
    ).decode(_pack(bits.toString()));

    expect(document.toXmlString(), '<root code="B1"><values>A0 C1</values></root>');
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

String _signed(BigInt value) {
  var magnitude = value < BigInt.zero ? -value - BigInt.one : value;
  final bits = StringBuffer(value < BigInt.zero ? '1' : '0');
  do {
    final group = (magnitude & BigInt.from(0x7f)).toInt();
    magnitude >>= 7;
    bits.write((group | (magnitude == BigInt.zero ? 0 : 0x80)).toRadixString(2).padLeft(8, '0'));
  } while (magnitude != BigInt.zero);
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

const _integerCharacters = [9, 10, 13, 32, 43, 45, 48, 49, 50, 51, 52, 53, 54, 55, 56, 57];
const _booleanCharacters = [9, 10, 13, 32, 48, 49, 97, 101, 102, 108, 114, 115, 116, 117];

String _restrictedValue(String value, List<int> characters) {
  final width = characters.length.bitLength;
  return '${_unsigned(value.runes.length + 2)}${value.runes.map((character) => characters.indexOf(character).toRadixString(2).padLeft(width, '0')).join()}';
}

String _restrictedString(String value, List<int> characters) {
  final width = characters.length.bitLength;
  return '${_unsigned(value.runes.length)}${value.runes.map((character) => characters.indexOf(character).toRadixString(2).padLeft(width, '0')).join()}';
}
