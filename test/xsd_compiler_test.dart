import 'package:exi/exi.dart';
import 'package:test/test.dart';

void main() {
  group('ExiSchemaCompiler', () {
    test('compiles named complex types and primitive sequence children', () {
      final schema = ExiSchemaCompiler.compile(
        id: 'types.xsd',
        source: '''
          <xs:schema xmlns:xs="http://www.w3.org/2001/XMLSchema">
            <xs:complexType name="RootType">
              <xs:sequence>
                <xs:element name="flag" type="xs:boolean"/>
                <xs:element name="count" type="xs:integer"/>
              </xs:sequence>
            </xs:complexType>
            <xs:element name="root" type="RootType"/>
          </xs:schema>
        ''',
      );

      final root = schema.globalElements.single;
      expect(root.name, const ExiQName(localName: 'root'));
      expect(root.children.map((child) => child.name.localName), ['flag', 'count']);
      expect(root.children[0].datatype, ExiDatatype.boolean);
      expect(root.children[1].datatype, ExiDatatype.integer);
    });

    test('compiles inline empty and simple type declarations', () {
      final schema = ExiSchemaCompiler.compile(
        id: 'inline.xsd',
        source: '''
          <xsd:schema xmlns:xsd="http://www.w3.org/2001/XMLSchema">
            <xsd:element name="empty">
              <xsd:complexType/>
            </xsd:element>
            <xsd:element name="text">
              <xsd:simpleType>
                <xsd:restriction base="xsd:string"/>
              </xsd:simpleType>
            </xsd:element>
          </xsd:schema>
        ''',
      );

      expect(schema.globalElements[0].children, isEmpty);
      expect(schema.globalElements[1].datatype, ExiDatatype.string);
    });

    test('compiles occurrence ranges and choices into particle models', () {
      final schema = ExiSchemaCompiler.compile(
        id: 'repeated.xsd',
        source: '''
            <xs:schema xmlns:xs="http://www.w3.org/2001/XMLSchema">
              <xs:element name="root">
                <xs:complexType>
                  <xs:choice>
                    <xs:element name="item" maxOccurs="unbounded"/>
                    <xs:element name="other" minOccurs="0"/>
                  </xs:choice>
                </xs:complexType>
              </xs:element>
            </xs:schema>
          ''',
      );

      expect(schema.globalElements.single.content, isA<ExiChoiceParticle>());
    });

    test('rejects an invalid maximum occurrence', () {
      expect(
        () => ExiSchemaCompiler.compile(
          id: 'invalid-occurrence.xsd',
          source: '''
            <xs:schema xmlns:xs="http://www.w3.org/2001/XMLSchema">
              <xs:element name="root">
                <xs:complexType>
                  <xs:sequence>
                    <xs:element name="item" maxOccurs="many"/>
                  </xs:sequence>
                </xs:complexType>
              </xs:element>
            </xs:schema>
          ''',
        ),
        throwsFormatException,
      );
    });

    test('compiles nested sequence and choice compositors', () {
      final schema = ExiSchemaCompiler.compile(
        id: 'nested-compositors.xsd',
        source: '''
          <xs:schema xmlns:xs="http://www.w3.org/2001/XMLSchema">
            <xs:element name="root">
              <xs:complexType>
                <xs:sequence>
                  <xs:element name="first"/>
                  <xs:choice>
                    <xs:element name="left"/>
                    <xs:element name="right"/>
                  </xs:choice>
                </xs:sequence>
              </xs:complexType>
            </xs:element>
          </xs:schema>
        ''',
      );

      final sequence = schema.globalElements.single.content as ExiSequenceParticle;
      expect(sequence.particles, hasLength(2));
      expect(sequence.particles.last, isA<ExiChoiceParticle>());
    });

    test('compiles an all compositor as unordered particles', () {
      final schema = ExiSchemaCompiler.compile(
        id: 'all.xsd',
        source: '''
          <xs:schema xmlns:xs="http://www.w3.org/2001/XMLSchema">
            <xs:element name="root">
              <xs:complexType>
                <xs:all>
                  <xs:element name="first"/>
                  <xs:element name="second" minOccurs="0"/>
                </xs:all>
              </xs:complexType>
            </xs:element>
          </xs:schema>
        ''',
      );

      final all = schema.globalElements.single.content as ExiAllParticle;
      expect(all.particles, hasLength(2));
    });

    test('rejects repeated children in an all compositor', () {
      expect(
        () => ExiSchemaCompiler.compile(
          id: 'invalid-all.xsd',
          source: '''
            <xs:schema xmlns:xs="http://www.w3.org/2001/XMLSchema">
              <xs:element name="root">
                <xs:complexType>
                  <xs:all>
                    <xs:element name="child" maxOccurs="2"/>
                  </xs:all>
                </xs:complexType>
              </xs:element>
            </xs:schema>
          ''',
        ),
        throwsFormatException,
      );
    });

    test('resolves a named model-group reference', () {
      final schema = ExiSchemaCompiler.compile(
        id: 'groups.xsd',
        source: '''
          <xs:schema xmlns:xs="http://www.w3.org/2001/XMLSchema">
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
          </xs:schema>
        ''',
      );

      expect(schema.globalElements.single.content, isA<ExiSequenceParticle>());
    });

    test('rejects unresolved and recursive model-group references', () {
      expect(
        () => ExiSchemaCompiler.compile(
          id: 'missing-group.xsd',
          source: '''
            <xs:schema xmlns:xs="http://www.w3.org/2001/XMLSchema">
              <xs:element name="root">
                <xs:complexType>
                  <xs:group ref="missing"/>
                </xs:complexType>
              </xs:element>
            </xs:schema>
          ''',
        ),
        throwsFormatException,
      );
      expect(
        () => ExiSchemaCompiler.compile(
          id: 'recursive-group.xsd',
          source: '''
            <xs:schema xmlns:xs="http://www.w3.org/2001/XMLSchema">
              <xs:group name="recursive">
                <xs:sequence>
                  <xs:group ref="recursive"/>
                </xs:sequence>
              </xs:group>
              <xs:element name="root">
                <xs:complexType>
                  <xs:group ref="recursive"/>
                </xs:complexType>
              </xs:element>
            </xs:schema>
          ''',
        ),
        throwsUnsupportedError,
      );
    });

    test('resolves a local particle reference to a global element', () {
      final schema = ExiSchemaCompiler.compile(
        id: 'references.xsd',
        source: '''
          <xs:schema
              xmlns:xs="http://www.w3.org/2001/XMLSchema"
              xmlns:tns="urn:example"
              targetNamespace="urn:example">
            <xs:element name="root">
              <xs:complexType>
                <xs:sequence>
                  <xs:element ref="tns:item" minOccurs="0" maxOccurs="2"/>
                </xs:sequence>
              </xs:complexType>
            </xs:element>
            <xs:element name="item" type="xs:boolean"/>
          </xs:schema>
        ''',
      );

      final root = schema.globalElements.first;
      final particle = (root.content as ExiSequenceParticle).particles.single as ExiElementParticle;
      expect(particle.element.name, const ExiQName(uri: 'urn:example', localName: 'item'));
      expect(particle.element.datatype, ExiDatatype.boolean);
      expect(particle.minOccurs, 0);
      expect(particle.maxOccurs, 2);
    });

    test('rejects unresolved element references', () {
      expect(
        () => ExiSchemaCompiler.compile(
          id: 'missing-reference.xsd',
          source: '''
            <xs:schema xmlns:xs="http://www.w3.org/2001/XMLSchema">
              <xs:element name="root">
                <xs:complexType>
                  <xs:sequence>
                    <xs:element ref="missing"/>
                  </xs:sequence>
                </xs:complexType>
              </xs:element>
            </xs:schema>
          ''',
        ),
        throwsFormatException,
      );
    });

    test('rejects recursive and external element references', () {
      expect(
        () => ExiSchemaCompiler.compile(
          id: 'recursive-reference.xsd',
          source: '''
            <xs:schema xmlns:xs="http://www.w3.org/2001/XMLSchema">
              <xs:element name="node">
                <xs:complexType>
                  <xs:sequence>
                    <xs:element ref="node"/>
                  </xs:sequence>
                </xs:complexType>
              </xs:element>
            </xs:schema>
          ''',
        ),
        throwsUnsupportedError,
      );
      expect(
        () => ExiSchemaCompiler.compile(
          id: 'external-reference.xsd',
          source: '''
            <xs:schema
                xmlns:xs="http://www.w3.org/2001/XMLSchema"
                xmlns:external="urn:external">
              <xs:element name="root">
                <xs:complexType>
                  <xs:sequence>
                    <xs:element ref="external:item"/>
                  </xs:sequence>
                </xs:complexType>
              </xs:element>
            </xs:schema>
          ''',
        ),
        throwsUnsupportedError,
      );
    });

    test('resolves a required attribute reference to a global attribute', () {
      final schema = ExiSchemaCompiler.compile(
        id: 'attribute-reference.xsd',
        source: '''
          <xs:schema
              xmlns:xs="http://www.w3.org/2001/XMLSchema"
              xmlns:tns="urn:example"
              targetNamespace="urn:example">
            <xs:element name="root">
              <xs:complexType>
                <xs:attribute ref="tns:code" use="required"/>
              </xs:complexType>
            </xs:element>
            <xs:attribute name="code" type="xs:integer"/>
          </xs:schema>
        ''',
      );

      final attribute = schema.globalElements.single.attributes.single;
      expect(attribute.name, const ExiQName(uri: 'urn:example', localName: 'code'));
      expect(attribute.datatype, ExiDatatype.integer);
      expect(attribute.required, isTrue);
    });

    test('rejects unresolved attribute references', () {
      expect(
        () => ExiSchemaCompiler.compile(
          id: 'missing-attribute.xsd',
          source: '''
            <xs:schema xmlns:xs="http://www.w3.org/2001/XMLSchema">
              <xs:element name="root">
                <xs:complexType>
                  <xs:attribute ref="missing"/>
                </xs:complexType>
              </xs:element>
            </xs:schema>
          ''',
        ),
        throwsFormatException,
      );
    });

    test('resolves arbitrary XML Schema prefixes and bounded byte types', () {
      final schema = ExiSchemaCompiler.compile(
        id: 'prefix.xsd',
        source: '''
          <schema:schema xmlns:schema="http://www.w3.org/2001/XMLSchema">
            <schema:element name="signed" type="schema:byte"/>
            <schema:element name="unsigned" type="schema:unsignedByte"/>
          </schema:schema>
        ''',
      );

      expect(schema.globalElements[0].datatype, ExiDatatype.byte);
      expect(schema.globalElements[1].datatype, ExiDatatype.unsignedByte);
    });

    test('rejects mixed complex content', () {
      expect(
        () => ExiSchemaCompiler.compile(
          id: 'mixed.xsd',
          source: '''
            <xs:schema xmlns:xs="http://www.w3.org/2001/XMLSchema">
              <xs:element name="root">
                <xs:complexType mixed="true"/>
              </xs:element>
            </xs:schema>
          ''',
        ),
        throwsUnsupportedError,
      );
    });

    test('compiles occurrence constraints on compositors', () {
      final schema = ExiSchemaCompiler.compile(
        id: 'compositor-occurs.xsd',
        source: '''
          <xs:schema xmlns:xs="http://www.w3.org/2001/XMLSchema">
            <xs:element name="root">
              <xs:complexType>
                <xs:sequence minOccurs="0" maxOccurs="unbounded">
                  <xs:element name="child"/>
                </xs:sequence>
              </xs:complexType>
            </xs:element>
          </xs:schema>
        ''',
      );

      final repeated = schema.globalElements.single.content as ExiRepeatedParticle;
      expect(repeated.minOccurs, 0);
      expect(repeated.maxOccurs, isNull);
    });

    test('applies occurrence constraints to model-group references', () {
      final schema = ExiSchemaCompiler.compile(
        id: 'group-occurs.xsd',
        source: '''
          <xs:schema xmlns:xs="http://www.w3.org/2001/XMLSchema">
            <xs:group name="pair">
              <xs:sequence>
                <xs:element name="first"/>
                <xs:element name="second"/>
              </xs:sequence>
            </xs:group>
            <xs:element name="root">
              <xs:complexType>
                <xs:group ref="pair" minOccurs="0" maxOccurs="2"/>
              </xs:complexType>
            </xs:element>
          </xs:schema>
        ''',
      );

      final repeated = schema.globalElements.single.content as ExiRepeatedParticle;
      expect(repeated.minOccurs, 0);
      expect(repeated.maxOccurs, 2);
    });

    test('rejects repetition of a nullable compositor', () {
      expect(
        () => ExiSchemaCompiler.compile(
          id: 'nullable-repetition.xsd',
          source: '''
            <xs:schema xmlns:xs="http://www.w3.org/2001/XMLSchema">
              <xs:element name="root">
                <xs:complexType>
                  <xs:sequence maxOccurs="unbounded">
                    <xs:element name="child" minOccurs="0"/>
                  </xs:sequence>
                </xs:complexType>
              </xs:element>
            </xs:schema>
          ''',
        ),
        throwsUnsupportedError,
      );
    });
  });
}
