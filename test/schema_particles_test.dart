import 'dart:typed_data';

import 'package:exi/exi.dart';
import 'package:test/test.dart';

void main() {
  test('decodes schema-valid productions in a non-strict schema grammar', () {
    final schema = _compile('''
      <xs:element name="root">
        <xs:complexType>
          <xs:sequence>
            <xs:element name="child"/>
          </xs:sequence>
          <xs:attribute name="id" type="xs:string" use="required"/>
        </xs:complexType>
      </xs:element>
    ''');
    final bits = StringBuffer()
      // Document root and declared attribute first-level productions.
      ..write('00')
      ..write(_value('7'))
      // Declared child, child EE, and root EE first-level productions.
      ..write('000');

    final document = ExiDecoder(
      options: const ExiOptions(schemaId: ExiSchemaId.named('particles')),
      schemaResolver: (_) => schema,
    ).decode(_pack('10000000$bits'));

    expect(document.toXmlString(), '<root id="7"><child/></root>');
  });

  test('decodes an early end-element non-strict deviation', () {
    final schema = _compile('''
      <xs:element name="root">
        <xs:complexType>
          <xs:sequence>
            <xs:element name="required"/>
          </xs:sequence>
        </xs:complexType>
      </xs:element>
    ''');

    // Document root=0; first-level escape=1; second-level EE=000.
    final document = ExiDecoder(
      options: const ExiOptions(schemaId: ExiSchemaId.named('particles')),
      schemaResolver: (_) => schema,
    ).decode(_pack('1000000001000'));

    expect(document.toXmlString(), '<root/>');
  });

  test('decodes untyped characters before required schema content', () {
    final schema = _compile('''
      <xs:element name="root">
        <xs:complexType>
          <xs:sequence>
            <xs:element name="required"/>
          </xs:sequence>
        </xs:complexType>
      </xs:element>
    ''');
    final bits = StringBuffer('10000000')
      // Document root=0; first-level escape=1; second-level untyped CH=110.
      ..write('01110')
      ..write(_value('unexpected'))
      // Required child, child EE, and root EE remain first-level productions.
      ..write('000');

    final document = ExiDecoder(
      options: const ExiOptions(schemaId: ExiSchemaId.named('particles')),
      schemaResolver: (_) => schema,
    ).decode(_pack(bits.toString()));

    expect(document.toXmlString(), '<root>unexpected<required/></root>');
  });

  test('decodes an undeclared child before required schema content', () {
    final schema = _compile('''
      <xs:element name="root">
        <xs:complexType>
          <xs:sequence>
            <xs:element name="required"/>
          </xs:sequence>
        </xs:complexType>
      </xs:element>
    ''');
    final bits = StringBuffer('10000000')
      // Document root=0; first-level escape=1; second-level SE(*)=101.
      ..write('01101')
      ..write(_schemaQName('', 'unexpected', localNames: ['required', 'root']))
      // Unexpected built-in child EE.
      ..write('00')
      // Required child, child EE, and root EE remain first-level productions.
      ..write('000');

    final document = ExiDecoder(
      options: const ExiOptions(schemaId: ExiSchemaId.named('particles')),
      schemaResolver: (_) => schema,
    ).decode(_pack(bits.toString()));

    expect(document.toXmlString(), '<root><unexpected/><required/></root>');
  });

  test('decodes an undeclared non-strict attribute', () {
    final schema = _compile('<xs:element name="root"/>');
    final bits = StringBuffer('10000000')
      // Document root=0; first-level escape=1; second-level AT(*)=010.
      ..write('01010')
      ..write(_schemaQName('', 'extra', localNames: ['root']))
      ..write(_value('value'))
      // Root EE remains a first-level production.
      ..write('0');

    final document = ExiDecoder(
      options: const ExiOptions(schemaId: ExiSchemaId.named('particles')),
      schemaResolver: (_) => schema,
    ).decode(_pack(bits.toString()));

    expect(document.toXmlString(), '<root extra="value"/>');
  });

  test('uses a global datatype for a non-strict wildcard attribute', () {
    final schema = _compile('''
      <xs:attribute name="count" type="xs:integer"/>
      <xs:element name="root"/>
    ''');
    final bits = StringBuffer('10000000')
      // Document root=0; first-level escape=1; second-level AT(*)=010.
      ..write('01010')
      ..write(_schemaQName('', 'count', localNames: ['count', 'root']))
      // Integer -3.
      ..write('1')
      ..write(_unsigned(2))
      // Root EE remains a first-level production.
      ..write('0');

    final document = ExiDecoder(
      options: const ExiOptions(schemaId: ExiSchemaId.named('particles')),
      schemaResolver: (_) => schema,
    ).decode(_pack(bits.toString()));

    expect(document.toXmlString(), '<root count="-3"/>');
  });

  test('decodes an untyped value for a declared non-strict attribute', () {
    final schema = _compile('''
      <xs:element name="root">
        <xs:complexType>
          <xs:attribute name="count" type="xs:integer"/>
        </xs:complexType>
      </xs:element>
    ''');
    final bits = StringBuffer('10000000')
      // Document root=0; first-level escape=10; untyped AT group=011;
      // declared count attribute=0.
      ..write('0100110')
      ..write(_value('not-an-integer'))
      // Root EE remains a first-level production.
      ..write('0');

    final document = ExiDecoder(
      options: const ExiOptions(schemaId: ExiSchemaId.named('particles')),
      schemaResolver: (_) => schema,
    ).decode(_pack(bits.toString()));

    expect(document.toXmlString(), '<root count="not-an-integer"/>');
  });

  test('switches a non-strict element grammar through xsi:type', () {
    final schema = _compile('''
      <xs:complexType name="Base"/>
      <xs:complexType name="Derived">
        <xs:complexContent>
          <xs:extension base="Base">
            <xs:sequence>
              <xs:element name="child"/>
            </xs:sequence>
          </xs:extension>
        </xs:complexContent>
      </xs:complexType>
      <xs:element name="root" type="Base"/>
    ''');
    final bits = StringBuffer('10000000')
      // Document root=0; first-level escape=1; second-level xsi:type=000.
      ..write('01000')
      ..write(_schemaQName('', 'Derived', localNames: ['Base', 'Derived', 'child', 'root']))
      // Derived child, child EE, and root EE first-level productions.
      ..write('000');

    final document = ExiDecoder(
      options: const ExiOptions(schemaId: ExiSchemaId.named('particles')),
      schemaResolver: (_) => schema,
    ).decode(_pack(bits.toString()));

    expect(document.events.whereType<ExiAttribute>().single.value, 'Derived');
    expect(document.toXmlString(), contains('<child/>'));
  });

  test('applies xsi:nil to a non-nillable element in non-strict mode', () {
    final schema = _compile('''
      <xs:element name="root">
        <xs:complexType>
          <xs:sequence>
            <xs:element name="required"/>
          </xs:sequence>
        </xs:complexType>
      </xs:element>
    ''');

    // Document root=0; first-level escape=1; second-level xsi:nil=010;
    // Boolean true=1; empty-type EE=0.
    final document = ExiDecoder(
      options: const ExiOptions(schemaId: ExiSchemaId.named('particles')),
      schemaResolver: (_) => schema,
    ).decode(_pack('100000000101010'));

    expect(document.events.whereType<ExiAttribute>().single.value, 'true');
    expect(document.events.whereType<ExiStartElement>().map((event) => event.name.localName), ['root']);
  });

  test('decodes invalid xsi:nil through the non-strict untyped wildcard attribute', () {
    final schema = _compile('''
      <xs:element name="root">
        <xs:complexType>
          <xs:sequence>
            <xs:element name="required"/>
          </xs:sequence>
        </xs:complexType>
      </xs:element>
    ''');
    final bits = StringBuffer('10000000')
      // Document root=0; first-level escape=1; second-level untyped AT group=100.
      ..write('01100')
      ..write(_schemaQName('http://www.w3.org/2001/XMLSchema-instance', 'nil', localNames: ['required', 'root']))
      ..write(_value('maybe'))
      // Required child, child EE, and root EE first-level productions.
      ..write('000');

    final document = ExiDecoder(
      options: const ExiOptions(schemaId: ExiSchemaId.named('particles')),
      schemaResolver: (_) => schema,
    ).decode(_pack(bits.toString()));

    final attribute = document.events.whereType<ExiAttribute>().single;
    expect(attribute.name, const ExiQName(uri: 'http://www.w3.org/2001/XMLSchema-instance', localName: 'nil'));
    expect(attribute.value, 'maybe');
    expect(document.events.whereType<ExiStartElement>().map((event) => event.name.localName), ['root', 'required']);
  });

  test('rejects xsi:type through the non-strict untyped wildcard attribute', () {
    final schema = _compile('<xs:element name="root"/>');
    final bits = StringBuffer('10000000')
      // Document root=0; first-level escape=1; second-level untyped AT group=011.
      ..write('01011')
      ..write(_schemaQName('http://www.w3.org/2001/XMLSchema-instance', 'type', localNames: ['root']))
      ..write(_value('Anything'))
      // Root EE remains a first-level production.
      ..write('0');

    expect(
      () => ExiDecoder(
        options: const ExiOptions(schemaId: ExiSchemaId.named('particles')),
        schemaResolver: (_) => schema,
      ).decode(_pack(bits.toString())),
      throwsFormatException,
    );
  });

  test('decodes non-strict entity and comment deviations', () {
    final schema = _compile('''
      <xs:element name="root">
        <xs:complexType>
          <xs:sequence>
            <xs:element name="required"/>
          </xs:sequence>
        </xs:complexType>
      </xs:element>
    ''');
    final bits = StringBuffer('10000000')
      // Document root=0; escape=1; second-level ER=0111.
      ..write('010111')
      ..write(_rawString('example'))
      // Content2 escape=1; comment/PI branch=100; CM=0.
      ..write('11000')
      ..write(_rawString('note'))
      // Required child, child EE, and root EE.
      ..write('000');

    final document = ExiDecoder(
      options: const ExiOptions(
        schemaId: ExiSchemaId.named('particles'),
        fidelity: ExiFidelityOptions(dtd: true, comments: true, processingInstructions: true),
      ),
      schemaResolver: (_) => schema,
    ).decode(_pack(bits.toString()));

    expect(document.toXmlString(), '<root>&example;<!--note--><required/></root>');
  });

  test('decodes a namespace declaration in a non-strict schema grammar', () {
    final schema = ExiSchemaCompiler.compile(
      id: 'particles',
      source: '''
        <xs:schema
            xmlns:xs="http://www.w3.org/2001/XMLSchema"
            targetNamespace="urn:example"
            elementFormDefault="qualified">
          <xs:element name="root"/>
        </xs:schema>
      ''',
    );
    final bits = StringBuffer('10000000')
      // Document root=0; escape=1; second-level NS=100.
      ..write('01100')
      ..write(_rawString('urn:example'))
      ..write(_rawString('p'))
      // Local-element namespace=true; root EE=0.
      ..write('10');

    final document = ExiDecoder(
      options: const ExiOptions(schemaId: ExiSchemaId.named('particles'), fidelity: ExiFidelityOptions(prefixes: true)),
      schemaResolver: (_) => schema,
    ).decode(_pack(bits.toString()));

    expect(document.toXmlString(), '<p:root xmlns:p="urn:example"/>');
  });

  test('decodes a self-contained non-strict schema element', () {
    final schema = _compile('''
      <xs:element name="root">
        <xs:complexType>
          <xs:sequence>
            <xs:element name="required"/>
          </xs:sequence>
        </xs:complexType>
      </xs:element>
    ''');
    final bits = StringBuffer('10000000')
      // Document root=0; escape=1; second-level SC=101.
      ..write('01101');
    _alignBits(bits);
    // Fresh declared grammar: required child, child EE, root EE.
    bits.write('000');
    _alignBits(bits);

    final document = ExiDecoder(
      options: const ExiOptions(schemaId: ExiSchemaId.named('particles'), selfContained: true),
      schemaResolver: (_) => schema,
    ).decode(_pack(bits.toString()));

    expect(document.toXmlString(), '<root><required/></root>');
  });

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

      // Two empty sequence occurrences also satisfy minOccurs=2.
      final emptyDocument = _decode(schema, '01');
      expect(emptyDocument.toXmlString(), '<root/>');
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

    test('decodes all-compositor children out of declaration order', () {
      final schema = _compile('''
        <xs:element name="root">
          <xs:complexType>
            <xs:all>
              <xs:element name="first"/>
              <xs:element name="second"/>
            </xs:all>
          </xs:complexType>
        </xs:element>
      ''');

      // Root=0; second is event 1; first is then implicit.
      final document = _decode(schema, '01');

      expect(document.toXmlString(), '<root><second/><first/></root>');
    });

    test('allows an optional all-compositor child to be absent', () {
      final schema = _compile('''
        <xs:element name="root">
          <xs:complexType>
            <xs:all>
              <xs:element name="first"/>
              <xs:element name="second" minOccurs="0"/>
            </xs:all>
          </xs:complexType>
        </xs:element>
      ''');

      // Root=0; first=0; EE=1 after the required child is consumed.
      final document = _decode(schema, '001');

      expect(document.toXmlString(), '<root><first/></root>');
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

    test('decodes repetition of a nullable sequence', () {
      final schema = _compile('''
        <xs:element name="root">
          <xs:complexType>
            <xs:sequence minOccurs="2" maxOccurs="3">
              <xs:element name="item" minOccurs="0"/>
            </xs:sequence>
          </xs:complexType>
        </xs:element>
      ''');

      // Root=0, two item events=0/0, then EE=1. Empty occurrences satisfy
      // the remaining minimum count because the repeated sequence is nullable.
      final document = _decode(schema, '0001');

      expect(document.toXmlString(), '<root><item/><item/></root>');
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

  test('decodes inherited complex-type attributes and particles', () {
    final schema = _compile('''
      <xs:complexType name="Base">
        <xs:sequence>
          <xs:element name="first"/>
        </xs:sequence>
        <xs:attribute name="id" use="required"/>
      </xs:complexType>
      <xs:complexType name="Derived">
        <xs:complexContent>
          <xs:extension base="Base">
            <xs:sequence>
              <xs:element name="second"/>
            </xs:sequence>
            <xs:attribute name="kind" use="required"/>
          </xs:extension>
        </xs:complexContent>
      </xs:complexType>
      <xs:element name="root" type="Derived"/>
    ''');
    final bits = StringBuffer()
      // Root and both required attribute productions are implicit.
      ..write('0')
      ..write(_value('7'))
      ..write(_value('example'));

    final document = _decode(schema, bits.toString());

    expect(document.toXmlString(), '<root id="7" kind="example"><first/><second/></root>');
  });

  test('switches to a named derived grammar through xsi:type', () {
    final schema = _compile('''
      <xs:complexType name="Base"/>
      <xs:complexType name="Derived">
        <xs:complexContent>
          <xs:extension base="Base">
            <xs:sequence>
              <xs:element name="child"/>
            </xs:sequence>
          </xs:extension>
        </xs:complexContent>
      </xs:complexType>
      <xs:element name="root" type="Base"/>
    ''');
    final bits = StringBuffer()
      // Root=0; xsi:type uses the second-level escape=1.
      ..write('01')
      // QName value uses the prepopulated empty-URI and local-name partitions.
      ..write(_schemaQName('', 'Derived', localNames: ['Base', 'Derived', 'child', 'root']));

    final document = _decode(schema, bits.toString());
    final type = document.events.whereType<ExiAttribute>().single;

    expect(type.name.localName, 'type');
    expect(type.value, 'Derived');
    expect(document.events.whereType<ExiStartElement>().map((event) => event.name.localName), ['root', 'child']);
  });

  test('resolves a namespace-qualified xsi:type QName', () {
    final schema = ExiSchemaCompiler.compile(
      id: 'particles',
      source: '''
        <xs:schema
            xmlns:xs="http://www.w3.org/2001/XMLSchema"
            xmlns:tns="urn:example"
            targetNamespace="urn:example">
          <xs:complexType name="Base"/>
          <xs:complexType name="Derived">
            <xs:complexContent>
              <xs:extension base="tns:Base">
                <xs:sequence>
                  <xs:element name="child"/>
                </xs:sequence>
              </xs:extension>
            </xs:complexContent>
          </xs:complexType>
          <xs:element name="root" type="tns:Base"/>
        </xs:schema>
      ''',
    );
    final bits = StringBuffer()
      // Root=0; xsi:type uses the second-level escape=1.
      ..write('01')
      ..write(
        _schemaQName('urn:example', 'Derived', schemaUris: ['urn:example'], localNames: ['Base', 'Derived', 'root']),
      );

    final document = _decode(schema, bits.toString());
    final type = document.events.whereType<ExiAttribute>().single;

    expect(type.value, '{urn:example}Derived');
    expect(document.events.whereType<ExiStartElement>().map((event) => event.name.localName), ['root', 'child']);
  });

  test('decodes characters in empty mixed content', () {
    final schema = _compile('''
      <xs:element name="root">
        <xs:complexType mixed="true"/>
      </xs:element>
    ''');
    final bits = StringBuffer()
      // Root=0; CH=1; untyped string; EE=0.
      ..write('01')
      ..write(_value('hello'))
      ..write('0');

    final document = _decode(schema, bits.toString());

    expect(document.toXmlString(), '<root>hello</root>');
  });

  test('decodes xsi:nil true using the empty type grammar', () {
    final schema = _compile('''
      <xs:element name="root" nillable="true">
        <xs:complexType>
          <xs:sequence>
            <xs:element name="required"/>
          </xs:sequence>
        </xs:complexType>
      </xs:element>
    ''');

    // Root=0; xsi:nil escape=1; Boolean true=1; EE is implicit.
    final document = _decode(schema, '011');
    final nil = document.events.whereType<ExiAttribute>().single;

    expect(nil.name.uri, 'http://www.w3.org/2001/XMLSchema-instance');
    expect(nil.name.localName, 'nil');
    expect(nil.value, 'true');
    expect(document.events.whereType<ExiStartElement>().map((event) => event.name.localName), ['root']);
  });

  test('continues with normal content after xsi:nil false', () {
    final schema = _compile('''
      <xs:element name="root" nillable="true">
        <xs:complexType>
          <xs:sequence>
            <xs:element name="required"/>
          </xs:sequence>
        </xs:complexType>
      </xs:element>
    ''');

    // Root=0; xsi:nil escape=1; Boolean false=0; required child is implicit.
    final document = _decode(schema, '010');

    expect(document.events.whereType<ExiStartElement>().map((event) => event.name.localName), ['root', 'required']);
  });

  test('decodes mixed characters around a declared child', () {
    final schema = _compile('''
      <xs:element name="root">
        <xs:complexType mixed="true">
          <xs:sequence>
            <xs:element name="child"/>
          </xs:sequence>
        </xs:complexType>
      </xs:element>
    ''');
    final bits = StringBuffer()
      // Root=0; CH=1; child=0; CH=1; EE=0.
      ..write('01')
      ..write(_value('before'))
      ..write('01')
      ..write(_value('after'))
      ..write('0');

    final document = _decode(schema, bits.toString());

    expect(document.toXmlString(), '<root>before<child/>after</root>');
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

  test('decodes attributes expanded from a named attribute group', () {
    final schema = _compile('''
      <xs:attributeGroup name="metadata">
        <xs:attribute name="id" use="required"/>
        <xs:attribute name="kind" use="required"/>
      </xs:attributeGroup>
      <xs:element name="root">
        <xs:complexType>
          <xs:attributeGroup ref="metadata"/>
        </xs:complexType>
      </xs:element>
    ''');
    final bits = StringBuffer()
      // Root and both required attribute events are implicit.
      ..write('0')
      ..write(_value('7'))
      ..write(_value('example'));

    final document = _decode(schema, bits.toString());

    expect(document.toXmlString(), '<root id="7" kind="example"/>');
  });

  test('decodes an unconstrained schema attribute wildcard', () {
    final schema = _compile('''
      <xs:element name="root">
        <xs:complexType>
          <xs:anyAttribute processContents="lax"/>
        </xs:complexType>
      </xs:element>
    ''');
    final bits = StringBuffer()
      // Root=0; AT(*)=0.
      ..write('00')
      ..write(_schemaQName('', 'extra', localNames: ['root']))
      ..write(_value('7'))
      // EE=1 after the wildcard attribute.
      ..write('1');

    final document = _decode(schema, bits.toString());

    expect(document.toXmlString(), '<root extra="7"/>');
  });

  test('decodes an unknown attribute through a default schema wildcard', () {
    final schema = _compile('''
      <xs:element name="root">
        <xs:complexType>
          <xs:anyAttribute/>
        </xs:complexType>
      </xs:element>
    ''');
    final bits = StringBuffer()
      // Root=0; AT(*)=0.
      ..write('00')
      ..write(_schemaQName('', 'extra', localNames: ['root']))
      ..write(_value('7'))
      ..write('1');

    final document = _decode(schema, bits.toString());

    expect(document.toXmlString(), '<root extra="7"/>');
  });

  test('uses a global attribute datatype for a wildcard match', () {
    final schema = _compile('''
      <xs:attribute name="code" type="xs:integer"/>
      <xs:element name="root">
        <xs:complexType>
          <xs:anyAttribute/>
        </xs:complexType>
      </xs:element>
    ''');
    final bits = StringBuffer()
      // Root=0; AT(*)=0; QName code.
      ..write('00')
      ..write(_schemaQName('', 'code', localNames: ['code', 'root']))
      // Positive integer 7.
      ..write('0')
      ..write(_unsigned(7))
      // EE=1.
      ..write('1');

    final document = _decode(schema, bits.toString());

    expect(document.toXmlString(), '<root code="7"/>');
  });

  test('uses a global wildcard attribute datatype regardless of processContents', () {
    final schema = _compile('''
      <xs:attribute name="code" type="xs:integer"/>
      <xs:element name="root">
        <xs:complexType>
          <xs:anyAttribute processContents="skip"/>
        </xs:complexType>
      </xs:element>
    ''');
    final bits = StringBuffer()
      ..write('00')
      ..write(_schemaQName('', 'code', localNames: ['code', 'root']))
      // Positive integer 7.
      ..write('0')
      ..write(_unsigned(7))
      ..write('1');

    final document = _decode(schema, bits.toString());

    expect(document.toXmlString(), '<root code="7"/>');
  });

  test('decodes an attribute with an implicit wildcard namespace', () {
    final schema = ExiSchemaCompiler.compile(
      id: 'qualified-wildcard',
      source: '''
        <xs:schema
            xmlns:xs="http://www.w3.org/2001/XMLSchema"
            targetNamespace="urn:example">
          <xs:element name="root">
            <xs:complexType>
              <xs:anyAttribute namespace="##targetNamespace" processContents="lax"/>
            </xs:complexType>
          </xs:element>
        </xs:schema>
      ''',
    );
    final bits = StringBuffer()
      // Root=0; AT(urn:example:*)=0; only the local-name String is encoded.
      ..write('00')
      ..write(_rawString('code'))
      ..write(_value('7'))
      // EE=1.
      ..write('1');

    final document = _decode(schema, bits.toString());
    final attribute = document.events.whereType<ExiAttribute>().single;

    expect(attribute.name, const ExiQName(uri: 'urn:example', localName: 'code'));
    expect(attribute.value, '7');
  });

  test('decodes an attribute matched by an other-namespace wildcard', () {
    final schema = ExiSchemaCompiler.compile(
      id: 'other-wildcard',
      source: '''
        <xs:schema
            xmlns:xs="http://www.w3.org/2001/XMLSchema"
            targetNamespace="urn:example">
          <xs:element name="root">
            <xs:complexType>
              <xs:anyAttribute namespace="##other" processContents="lax"/>
            </xs:complexType>
          </xs:element>
        </xs:schema>
      ''',
    );
    final bits = StringBuffer()
      // Root=0; AT(*)=0; full QName in a permitted namespace.
      ..write('00')
      ..write(_schemaQName('urn:other', 'code', schemaUris: ['urn:example']))
      ..write(_value('7'))
      ..write('1');

    final document = _decode(schema, bits.toString());
    final attribute = document.events.whereType<ExiAttribute>().single;

    expect(attribute.name, const ExiQName(uri: 'urn:other', localName: 'code'));
  });

  test('decodes an unknown child through a lax element wildcard', () {
    final schema = ExiSchemaCompiler.compile(
      id: 'particles',
      source: '''
        <xs:schema
            xmlns:xs="http://www.w3.org/2001/XMLSchema"
            targetNamespace="urn:example">
          <xs:element name="root">
            <xs:complexType>
              <xs:sequence>
                <xs:any namespace="urn:other" processContents="lax"/>
              </xs:sequence>
            </xs:complexType>
          </xs:element>
        </xs:schema>
      ''',
    );
    final bits = StringBuffer()
      // Root=0; SE(urn:other:*) is implicit and encodes only the local name.
      ..write('0')
      ..write(_rawString('child'))
      // The unknown child uses its schema-less start-tag EE production.
      ..write('00');

    final document = _decode(schema, bits.toString());
    final elements = document.events.whereType<ExiStartElement>().toList();

    expect(elements[1].name, const ExiQName(uri: 'urn:other', localName: 'child'));
    expect(document.events.whereType<ExiEndElement>(), hasLength(2));
  });

  test('uses a global element declaration for a strict wildcard match', () {
    final schema = _compile('''
      <xs:element name="child" type="xs:integer"/>
      <xs:element name="root">
        <xs:complexType>
          <xs:sequence>
            <xs:any/>
          </xs:sequence>
        </xs:complexType>
      </xs:element>
    ''');
    final bits = StringBuffer()
      // Global roots are child=00, root=01, SE(*)=10.
      ..write('01')
      // The wildcard QName is child.
      ..write(_schemaQName('', 'child', localNames: ['child', 'root']))
      // Positive integer 7.
      ..write('0')
      ..write(_unsigned(7));

    final document = _decode(schema, bits.toString());

    expect(document.toXmlString(), '<root><child>7</child></root>');
  });

  test('uses a built-in grammar for a wildcard without a global declaration', () {
    final schema = _compile('''
      <xs:element name="root">
        <xs:complexType>
          <xs:sequence>
            <xs:any/>
          </xs:sequence>
        </xs:complexType>
      </xs:element>
    ''');
    final bits = StringBuffer()
      ..write('0')
      ..write(_schemaQName('', 'missing', localNames: ['root']))
      // The synthesized global element grammar starts with schema-less EE.
      ..write('00');

    final document = _decode(schema, bits.toString());

    expect(document.toXmlString(), '<root><missing/></root>');
  });

  test('uses a global declaration regardless of XSD wildcard processing mode', () {
    final schema = _compile('''
      <xs:element name="child" type="xs:integer"/>
      <xs:element name="root">
        <xs:complexType>
          <xs:sequence>
            <xs:any processContents="skip"/>
          </xs:sequence>
        </xs:complexType>
      </xs:element>
    ''');
    final bits = StringBuffer()
      // Root=01; SE(*) is implicit and names the global child.
      ..write('01')
      ..write(_schemaQName('', 'child', localNames: ['child', 'root']))
      // EXI wildcard semantics use the global integer grammar.
      ..write('0')
      ..write(_unsigned(7));

    final document = _decode(schema, bits.toString());

    expect(document.toXmlString(), '<root><child>7</child></root>');
  });

  test('uses schema-prepopulated URI and local-name compact identifiers', () {
    final schema = ExiSchemaCompiler.compile(
      id: 'particles',
      source: '''
        <xs:schema
            xmlns:xs="http://www.w3.org/2001/XMLSchema"
            targetNamespace="urn:example">
          <xs:element name="child"/>
          <xs:element name="root">
            <xs:complexType>
              <xs:sequence>
                <xs:any/>
              </xs:sequence>
            </xs:complexType>
          </xs:element>
        </xs:schema>
      ''',
    );
    final bits = StringBuffer()
      // Global roots are child=00 and root=01.
      ..write('01')
      // URI compact ID 4 is encoded as 5 in the hit-optimized partition.
      ..write('101')
      // The child local name is compact ID 0 in ['child', 'root'].
      ..write('00000000')
      ..write('0');

    final document = _decode(schema, bits.toString());

    expect(document.events.whereType<ExiStartElement>().map((event) => event.name), [
      const ExiQName(uri: 'urn:example', localName: 'root'),
      const ExiQName(uri: 'urn:example', localName: 'child'),
    ]);
  });

  test('uses a global declaration for a schema document wildcard', () {
    final schema = _compile('''
      <xs:element name="child" type="xs:integer"/>
      <xs:element name="root"/>
    ''');
    final bits = StringBuffer()
      // Global roots are child=00, root=01, SE(*)=10.
      ..write('10')
      ..write(_schemaQName('', 'child', localNames: ['child', 'root']))
      // The matching global declaration supplies the integer grammar.
      ..write('0')
      ..write(_unsigned(7));

    final document = _decode(schema, bits.toString());

    expect(document.toXmlString(), '<child>7</child>');
  });

  test('uses a built-in grammar for an undeclared schema document wildcard', () {
    final schema = _compile('<xs:element name="root"/>');
    final bits = StringBuffer()
      // Root=0, SE(*)=1.
      ..write('1')
      ..write(_schemaQName('', 'other', localNames: ['root']))
      // Built-in element start-tag EE.
      ..write('00');

    final document = _decode(schema, bits.toString());

    expect(document.toXmlString(), '<other/>');
  });

  test('decodes a local declaration as a schema-informed fragment root', () {
    final schema = _compile('''
      <xs:element name="root">
        <xs:complexType>
          <xs:sequence>
            <xs:element name="child"/>
          </xs:sequence>
        </xs:complexType>
      </xs:element>
    ''');

    // Fragment declarations are child=00 and root=01; ED=11.
    final document = _decodeFragment(schema, '0011');

    expect(document.events.whereType<ExiStartElement>().map((event) => event.name.localName), ['child']);
  });

  test('uses a built-in grammar for a schema-informed fragment wildcard', () {
    final schema = _compile('''
      <xs:element name="root">
        <xs:complexType>
          <xs:sequence>
            <xs:element name="child"/>
          </xs:sequence>
        </xs:complexType>
      </xs:element>
    ''');
    final bits = StringBuffer()
      // Fragment declarations are child=00, root=01, SE(*)=10, ED=11.
      ..write('10')
      ..write(_schemaQName('', 'other', localNames: ['child', 'root']))
      // Built-in element start-tag EE, followed by fragment ED.
      ..write('00')
      ..write('11');

    final document = _decodeFragment(schema, bits.toString());

    expect(document.events.whereType<ExiStartElement>().single.name.localName, 'other');
  });

  test('uses a global grammar for a schema-informed fragment wildcard', () {
    final schema = _compile('''
      <xs:element name="child" type="xs:integer"/>
      <xs:element name="root"/>
    ''');
    final bits = StringBuffer()
      // Fragment declarations are child=00, root=01, SE(*)=10, ED=11.
      ..write('10')
      ..write(_schemaQName('', 'child', localNames: ['child', 'root']))
      ..write('0')
      ..write(_unsigned(7))
      ..write('11');

    final document = _decodeFragment(schema, bits.toString());

    expect(document.toXmlString(), '<child>7</child>');
  });

  test('includes fragment declarations from unused named types', () {
    final schema = _compile('''
      <xs:complexType name="Unused">
        <xs:sequence>
          <xs:element name="orphan"/>
        </xs:sequence>
      </xs:complexType>
      <xs:element name="root"/>
    ''');

    // Fragment declarations are orphan=00 and root=01; ED=11.
    final document = _decodeFragment(schema, '0011');

    expect(document.events.whereType<ExiStartElement>().single.name.localName, 'orphan');
  });

  test('uses a relaxed grammar for ambiguous fragment declarations', () {
    final schema = _compile('''
      <xs:element name="root">
        <xs:complexType>
          <xs:choice>
            <xs:element name="item" type="xs:string"/>
            <xs:element name="item" type="xs:integer"/>
          </xs:choice>
        </xs:complexType>
      </xs:element>
    ''');

    final bits = StringBuffer()
      // Unique fragment QNames are item=00 and root=01.
      ..write('00')
      // Relaxed start-tag grammar: AT(*)=0, item=1, root=2,
      // SE(*)=3, EE=4, CH=5.
      ..write('101')
      ..write(_value('text'))
      // Relaxed content grammar: item=0, root=1, SE(*)=2, EE=3.
      ..write('011')
      // Fragment ED=3.
      ..write('11');

    final document = _decodeFragment(schema, bits.toString());

    expect(document.toXmlString(), '<item>text</item>');
  });

  test('uses a specific fragment grammar for duplicate declarations with the same schema type', () {
    final schema = _compile('''
      <xs:element name="root">
        <xs:complexType>
          <xs:choice>
            <xs:element name="item" type="xs:string"/>
            <xs:element name="item" type="xs:string"/>
          </xs:choice>
        </xs:complexType>
      </xs:element>
    ''');
    final bits = StringBuffer()
      // Unique fragment QNames are item=00 and root=01. Because both item
      // declarations have the same schema type and nillability, the fragment
      // element uses the specific string-value grammar, not relaxed CH=5.
      ..write('00')
      ..write(_value('text'))
      // Fragment ED=3.
      ..write('11');

    final document = _decodeFragment(schema, bits.toString());

    expect(document.toXmlString(), '<item>text</item>');
  });

  test('keeps duplicate fragment declarations relaxed when nillability differs', () {
    final schema = _compile('''
      <xs:element name="root">
        <xs:complexType>
          <xs:choice>
            <xs:element name="item" type="xs:string"/>
            <xs:element name="item" type="xs:string" nillable="true"/>
          </xs:choice>
        </xs:complexType>
      </xs:element>
    ''');
    final bits = StringBuffer()
      // Unique fragment QNames are item=00 and root=01.
      ..write('00')
      // Relaxed start-tag grammar with xsi:nil available: CH=6.
      ..write('110')
      ..write(_value('text'))
      // Relaxed content grammar: EE=3.
      ..write('011')
      // Fragment ED=3.
      ..write('11');

    final document = _decodeFragment(schema, bits.toString());

    expect(document.toXmlString(), '<item>text</item>');
  });

  test('decodes xsi:nil in a relaxed fragment grammar', () {
    final schema = _compile('''
      <xs:element name="root">
        <xs:complexType>
          <xs:choice>
            <xs:element name="item" type="xs:string"/>
            <xs:element name="item" type="xs:integer" nillable="true"/>
          </xs:choice>
        </xs:complexType>
      </xs:element>
    ''');
    final bits = StringBuffer()
      // Fragment item=00; relaxed AT(xsi:nil)=1 after AT(*).
      ..write('00001')
      // Boolean true.
      ..write('1')
      // Relaxed content grammar: EE=3; fragment ED=3.
      ..write('10011');

    final document = _decodeFragment(schema, bits.toString());

    expect(document.toXmlString(), '<item xsi:nil="true"/>');
  });

  test('switches a relaxed fragment grammar through xsi:type', () {
    final schema = _compile('''
      <xs:complexType name="Base"/>
      <xs:complexType name="Derived">
        <xs:complexContent>
          <xs:extension base="Base">
            <xs:sequence>
              <xs:element name="child"/>
            </xs:sequence>
          </xs:extension>
        </xs:complexContent>
      </xs:complexType>
      <xs:element name="root">
        <xs:complexType>
          <xs:choice>
            <xs:element name="item" type="xs:string"/>
            <xs:element name="item" type="Base"/>
          </xs:choice>
        </xs:complexType>
      </xs:element>
    ''');
    final bits = StringBuffer()
      // Fragment QNames are child=000, item=001, root=010, SE(*)=011, ED=100.
      ..write('001')
      // Relaxed AT(xsi:type)=1 after AT(*).
      ..write('001')
      ..write(_schemaQName('', 'Derived', localNames: ['Base', 'Derived', 'child', 'item', 'root']))
      // The Derived grammar decodes child and both EE events implicitly.
      ..write('100');

    final document = _decodeFragment(schema, bits.toString());

    expect(document.toXmlString(), '<item xsi:type="Derived"><child/></item>');
  });

  test('decodes comments in a non-strict relaxed fragment grammar', () {
    final schema = _compile('''
      <xs:element name="root">
        <xs:complexType>
          <xs:choice>
            <xs:element name="item" type="xs:string"/>
            <xs:element name="item" type="xs:integer"/>
          </xs:choice>
        </xs:complexType>
      </xs:element>
    ''');
    final bits = StringBuffer('10000000')
      // Fragment item=000 when the top-level fragment grammar includes CM.
      ..write('000')
      // Non-strict relaxed start-tag/content escape after the six base events.
      ..write('110')
      ..write(_rawString('note'))
      // Relaxed content EE=3; top-level fragment ED=3 when comments are enabled.
      ..write('011')
      ..write('011');

    final document = ExiDecoder(
      options: const ExiOptions(
        strict: false,
        fragment: true,
        schemaId: ExiSchemaId.named('particles'),
        fidelity: ExiFidelityOptions(comments: true),
      ),
      schemaResolver: (_) => schema,
    ).decode(_pack(bits.toString()));

    expect(document.toXmlString(), '<item><!--note--></item>');
  });

  test('decodes processing instructions in a non-strict relaxed fragment grammar', () {
    final schema = _compile('''
      <xs:element name="root">
        <xs:complexType>
          <xs:choice>
            <xs:element name="item" type="xs:string"/>
            <xs:element name="item" type="xs:integer"/>
          </xs:choice>
        </xs:complexType>
      </xs:element>
    ''');
    final bits = StringBuffer('10000000')
      ..write('000')
      ..write('110')
      ..write(_rawString('target'))
      ..write(_rawString('data'))
      ..write('011')
      ..write('011');

    final document = ExiDecoder(
      options: const ExiOptions(
        strict: false,
        fragment: true,
        schemaId: ExiSchemaId.named('particles'),
        fidelity: ExiFidelityOptions(processingInstructions: true),
      ),
      schemaResolver: (_) => schema,
    ).decode(_pack(bits.toString()));

    expect(document.toXmlString(), '<item><?target data?></item>');
  });

  test('decodes entity references in a non-strict relaxed fragment grammar', () {
    final schema = _compile('''
      <xs:element name="root">
        <xs:complexType>
          <xs:choice>
            <xs:element name="item" type="xs:string"/>
            <xs:element name="item" type="xs:integer"/>
          </xs:choice>
        </xs:complexType>
      </xs:element>
    ''');
    final bits = StringBuffer('10000000')
      ..write('00')
      ..write('110')
      ..write(_rawString('example'))
      ..write('011')
      ..write('11');

    final document = ExiDecoder(
      options: const ExiOptions(
        strict: false,
        fragment: true,
        schemaId: ExiSchemaId.named('particles'),
        fidelity: ExiFidelityOptions(dtd: true),
      ),
      schemaResolver: (_) => schema,
    ).decode(_pack(bits.toString()));

    expect(document.toXmlString(), '<item>&example;</item>');
  });

  test('decodes namespace declarations in a non-strict relaxed fragment grammar', () {
    final schema = ExiSchemaCompiler.compile(
      id: 'particles',
      source: '''
        <xs:schema
            xmlns:xs="http://www.w3.org/2001/XMLSchema"
            targetNamespace="urn:example">
          <xs:element name="root">
            <xs:complexType>
              <xs:choice>
                <xs:element name="item" type="xs:string" form="qualified"/>
                <xs:element name="item" type="xs:integer" form="qualified"/>
              </xs:choice>
            </xs:complexType>
          </xs:element>
        </xs:schema>
      ''',
    );
    final bits = StringBuffer('10000000')
      // Fragment item=00; relaxed non-strict NS escape=6.
      ..write('00110')
      ..write(_rawString('urn:example'))
      ..write(_rawString('p'))
      // Local-element namespace=true; relaxed start-tag EE=4; fragment ED=3.
      ..write('110011');

    final document = ExiDecoder(
      options: const ExiOptions(
        strict: false,
        fragment: true,
        schemaId: ExiSchemaId.named('particles'),
        fidelity: ExiFidelityOptions(prefixes: true),
      ),
      schemaResolver: (_) => schema,
    ).decode(_pack(bits.toString()));

    expect(document.toXmlString(), '<p:item xmlns:p="urn:example"/>');
  });

  test('decodes self-contained content in a non-strict relaxed fragment grammar', () {
    final schema = _compile('''
      <xs:element name="root">
        <xs:complexType>
          <xs:choice>
            <xs:element name="item" type="xs:string"/>
            <xs:element name="item" type="xs:integer"/>
          </xs:choice>
        </xs:complexType>
      </xs:element>
    ''');
    final bits = StringBuffer('10000000')
      // Fragment item=00; relaxed non-strict SC escape=6.
      ..write('00110');
    _alignBits(bits);
    bits
      // Isolated relaxed start-tag CH=5, value, then content EE=3.
      ..write('101')
      ..write(_value('text'))
      ..write('011');
    _alignBits(bits);
    // Fragment ED=3.
    bits.write('11');

    final document = ExiDecoder(
      options: const ExiOptions(
        strict: false,
        fragment: true,
        selfContained: true,
        schemaId: ExiSchemaId.named('particles'),
      ),
      schemaResolver: (_) => schema,
    ).decode(_pack(bits.toString()));

    expect(document.toXmlString(), '<item>text</item>');
  });

  test('uses declared child productions in a relaxed fragment grammar', () {
    final schema = _compile('''
      <xs:element name="child"/>
      <xs:element name="root">
        <xs:complexType>
          <xs:choice>
            <xs:element name="item" type="xs:string"/>
            <xs:element name="item" type="xs:integer"/>
          </xs:choice>
        </xs:complexType>
      </xs:element>
    ''');

    // Fragment QNames are child=0, item=1, root=2. In the relaxed
    // start-tag grammar AT(*)=0 and SE(child)=1. After child, EE=4.
    final document = _decodeFragment(schema, '001001100100');

    expect(document.toXmlString(), '<item><child/></item>');
  });

  test('uses typed declared attributes in a relaxed fragment grammar', () {
    final schema = _compile('''
      <xs:attribute name="code" type="xs:integer"/>
      <xs:element name="root">
        <xs:complexType>
          <xs:choice>
            <xs:element name="item" type="xs:string"/>
            <xs:element name="item" type="xs:integer"/>
          </xs:choice>
        </xs:complexType>
      </xs:element>
    ''');
    final bits = StringBuffer()
      // Fragment item=00; relaxed AT(code)=000.
      ..write('00000')
      // Positive integer 7.
      ..write('0')
      ..write(_unsigned(7))
      // Relaxed EE=5; fragment ED=3.
      ..write('10111');

    final document = _decodeFragment(schema, bits.toString());

    expect(document.toXmlString(), '<item code="7"/>');
  });

  test('decodes untyped declared attributes in a non-strict relaxed fragment grammar', () {
    final schema = _compile('''
      <xs:attribute name="code" type="xs:integer"/>
      <xs:element name="root">
        <xs:complexType>
          <xs:choice>
            <xs:element name="item" type="xs:string"/>
            <xs:element name="item" type="xs:integer"/>
          </xs:choice>
        </xs:complexType>
      </xs:element>
    ''');
    final bits = StringBuffer('10000000')
      // Fragment item=00; relaxed non-strict escape=7 after AT(code), AT(*), and content events.
      ..write('00111')
      // Untyped declared attribute code=0.
      ..write('0')
      ..write(_value('not-an-integer'))
      // Relaxed EE=5; fragment ED=3.
      ..write('10111');

    final document = ExiDecoder(
      options: const ExiOptions(strict: false, fragment: true, schemaId: ExiSchemaId.named('particles')),
      schemaResolver: (_) => schema,
    ).decode(_pack(bits.toString()));

    expect(document.toXmlString(), '<item code="not-an-integer"/>');
  });

  test('decodes untyped wildcard attributes in a non-strict relaxed fragment grammar', () {
    final schema = _compile('''
      <xs:attribute name="code" type="xs:integer"/>
      <xs:element name="root">
        <xs:complexType>
          <xs:choice>
            <xs:element name="item" type="xs:string"/>
            <xs:element name="item" type="xs:integer"/>
          </xs:choice>
        </xs:complexType>
      </xs:element>
    ''');
    final bits = StringBuffer('10000000')
      // Fragment item=00; relaxed non-strict escape=7 after AT(code), AT(*), and content events.
      ..write('00111')
      // Untyped wildcard attribute with QName code.
      ..write('1')
      ..write(_schemaQName('', 'code', localNames: ['code', 'item', 'root']))
      ..write(_value('not-an-integer'))
      // Relaxed EE=5; fragment ED=3.
      ..write('10111');

    final document = ExiDecoder(
      options: const ExiOptions(strict: false, fragment: true, schemaId: ExiSchemaId.named('particles')),
      schemaResolver: (_) => schema,
    ).decode(_pack(bits.toString()));

    expect(document.toXmlString(), '<item code="not-an-integer"/>');
  });

  test('decodes invalid xsi:nil through a relaxed fragment untyped wildcard attribute', () {
    final schema = _compile('''
      <xs:attribute name="code" type="xs:integer"/>
      <xs:element name="root">
        <xs:complexType>
          <xs:choice>
            <xs:element name="item" type="xs:string"/>
            <xs:element name="item" type="xs:string" nillable="true"/>
          </xs:choice>
        </xs:complexType>
      </xs:element>
    ''');
    final bits = StringBuffer('10000000')
      // Fragment item=00; relaxed non-strict escape=8 after AT(code), AT(*),
      // AT(xsi:nil), and content events.
      ..write('001000')
      // Untyped wildcard attribute with QName xsi:nil.
      ..write('1')
      ..write(_schemaQName('http://www.w3.org/2001/XMLSchema-instance', 'nil', localNames: ['code', 'item', 'root']))
      ..write(_value('maybe'))
      // Relaxed EE=5 after xsi:nil is consumed; fragment ED=3.
      ..write('10111');

    final document = ExiDecoder(
      options: const ExiOptions(strict: false, fragment: true, schemaId: ExiSchemaId.named('particles')),
      schemaResolver: (_) => schema,
    ).decode(_pack(bits.toString()));
    final attribute = document.events.whereType<ExiAttribute>().single;

    expect(attribute.name, const ExiQName(uri: 'http://www.w3.org/2001/XMLSchema-instance', localName: 'nil'));
    expect(attribute.value, 'maybe');
    expect(document.events.whereType<ExiStartElement>().single.name.localName, 'item');
  });

  test('uses String for conflicting relaxed fragment attribute types', () {
    final schema = _compile('''
      <xs:element name="root">
        <xs:complexType>
          <xs:choice>
            <xs:element name="item">
              <xs:complexType>
                <xs:attribute name="code" type="xs:string"/>
              </xs:complexType>
            </xs:element>
            <xs:element name="item">
              <xs:complexType>
                <xs:attribute name="code" type="xs:integer"/>
              </xs:complexType>
            </xs:element>
          </xs:choice>
        </xs:complexType>
      </xs:element>
    ''');
    final bits = StringBuffer()
      // Fragment item=00; relaxed AT(code)=000.
      ..write('00000')
      ..write(_value('not-an-integer'))
      // Relaxed EE=5; fragment ED=3.
      ..write('10111');

    final document = _decodeFragment(schema, bits.toString());

    expect(document.toXmlString(), '<item code="not-an-integer"/>');
  });

  test('decodes qualified local names from schema form overrides', () {
    final schema = ExiSchemaCompiler.compile(
      id: 'forms',
      source: '''
        <xs:schema
            xmlns:xs="http://www.w3.org/2001/XMLSchema"
            targetNamespace="urn:example">
          <xs:element name="root">
            <xs:complexType>
              <xs:sequence>
                <xs:element name="child" form="qualified"/>
              </xs:sequence>
              <xs:attribute name="id" form="qualified" use="required"/>
            </xs:complexType>
          </xs:element>
        </xs:schema>
      ''',
    );
    final bits = StringBuffer()
      // Root and required attribute/child productions are schema-declared.
      ..write('0')
      ..write(_value('7'));

    final document = _decode(schema, bits.toString());
    final attribute = document.events.whereType<ExiAttribute>().single;
    final elements = document.events.whereType<ExiStartElement>().toList();

    expect(attribute.name, const ExiQName(uri: 'urn:example', localName: 'id'));
    expect(elements[1].name, const ExiQName(uri: 'urn:example', localName: 'child'));
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

ExiDocument _decodeFragment(ExiSchema schema, String bodyBits) {
  final bits = '10000000$bodyBits';
  return ExiDecoder(
    options: const ExiOptions(strict: true, fragment: true, schemaId: ExiSchemaId.named('particles')),
    schemaResolver: (_) => schema,
  ).decode(_pack(bits));
}

String _value(String value) {
  final codePoints = value.runes.toList();
  return '${_unsigned(codePoints.length + 2)}${codePoints.map(_unsigned).join()}';
}

String _rawString(String value) {
  final codePoints = value.runes.toList();
  return '${_unsigned(codePoints.length)}${codePoints.map(_unsigned).join()}';
}

String _schemaQName(
  String uri,
  String localName, {
  List<String> schemaUris = const [],
  List<String> localNames = const [],
}) {
  final initialUris = [
    '',
    'http://www.w3.org/XML/1998/namespace',
    'http://www.w3.org/2001/XMLSchema-instance',
    'http://www.w3.org/2001/XMLSchema',
  ];
  final additionalUris = schemaUris.where((candidate) => !initialUris.contains(candidate)).toSet().toList()..sort();
  final uris = [...initialUris, ...additionalUris];
  final uriWidth = _nBitWidth(uris.length + 1);
  final uriIndex = uris.indexOf(uri);
  final encodedUri = uriIndex == -1
      ? '${''.padLeft(uriWidth, '0')}${_rawString(uri)}'
      : (uriIndex + 1).toRadixString(2).padLeft(uriWidth, '0');

  final names = localNames.toSet().toList()..sort();
  final localNameIndex = names.indexOf(localName);
  final encodedLocalName = localNameIndex == -1
      ? _literal(localName, 1)
      : '${_unsigned(0)}${localNameIndex.toRadixString(2).padLeft(_nBitWidth(names.length), '0')}';
  return '$encodedUri$encodedLocalName';
}

int _nBitWidth(int valueCount) => valueCount <= 1 ? 0 : (valueCount - 1).bitLength;

String _literal(String value, int lengthOffset) {
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
