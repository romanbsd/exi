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
      // QName value: empty URI, local name Derived.
      ..write(_rawString(''))
      ..write(_rawString('Derived'));

    final document = _decode(schema, bits.toString());
    final type = document.events.whereType<ExiAttribute>().single;

    expect(type.name.localName, 'type');
    expect(type.value, 'Derived');
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

    // Root=0; xsi:nil escape=1; Boolean true=10; EE is implicit.
    final document = _decode(schema, '0110');
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

    // Root=0; xsi:nil escape=1; Boolean false=00; required child is implicit.
    final document = _decode(schema, '0100');

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
