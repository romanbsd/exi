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

    test('extends named complex types with attributes and particles', () {
      final schema = ExiSchemaCompiler.compile(
        id: 'complex-extension.xsd',
        source: '''
          <xs:schema xmlns:xs="http://www.w3.org/2001/XMLSchema">
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
          </xs:schema>
        ''',
      );

      final root = schema.globalElements.single;
      expect(root.attributes.map((attribute) => attribute.name.localName), ['id', 'kind']);
      final content = root.content as ExiSequenceParticle;
      expect(content.particles.cast<ExiElementParticle>().map((particle) => particle.element.name.localName), [
        'first',
        'second',
      ]);
    });

    test('rejects recursive complex type inheritance', () {
      expect(
        () => ExiSchemaCompiler.compile(
          id: 'recursive-complex.xsd',
          source: '''
            <xs:schema xmlns:xs="http://www.w3.org/2001/XMLSchema">
              <xs:complexType name="First">
                <xs:complexContent>
                  <xs:extension base="Second"/>
                </xs:complexContent>
              </xs:complexType>
              <xs:complexType name="Second">
                <xs:complexContent>
                  <xs:extension base="First"/>
                </xs:complexContent>
              </xs:complexType>
              <xs:element name="root" type="First"/>
            </xs:schema>
          ''',
        ),
        throwsUnsupportedError,
      );
    });

    test('records named derived types for xsi:type', () {
      final schema = ExiSchemaCompiler.compile(
        id: 'type-alternatives.xsd',
        source: '''
          <xs:schema xmlns:xs="http://www.w3.org/2001/XMLSchema">
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
          </xs:schema>
        ''',
      );

      expect(schema.globalElements.single.typeAlternatives.keys, [const ExiQName(localName: 'Derived')]);
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

    test('compiles named and chained simple type restrictions', () {
      final schema = ExiSchemaCompiler.compile(
        id: 'named-simple.xsd',
        source: '''
          <xs:schema xmlns:xs="http://www.w3.org/2001/XMLSchema">
            <xs:simpleType name="BaseCount">
              <xs:restriction base="xs:integer"/>
            </xs:simpleType>
            <xs:simpleType name="Count">
              <xs:restriction base="BaseCount"/>
            </xs:simpleType>
            <xs:element name="count" type="Count"/>
          </xs:schema>
        ''',
      );

      expect(schema.globalElements.single.datatype, ExiDatatype.integer);
    });

    test('compiles simple content with attributes', () {
      final schema = ExiSchemaCompiler.compile(
        id: 'simple-content.xsd',
        source: '''
          <xs:schema xmlns:xs="http://www.w3.org/2001/XMLSchema">
            <xs:complexType name="ValueWithUnit">
              <xs:simpleContent>
                <xs:extension base="xs:decimal">
                  <xs:attribute name="unit" type="xs:string" use="required"/>
                </xs:extension>
              </xs:simpleContent>
            </xs:complexType>
            <xs:element name="value" type="ValueWithUnit"/>
          </xs:schema>
        ''',
      );

      final value = schema.globalElements.single;
      expect(value.datatype, ExiDatatype.decimal);
      expect(value.attributes.single.name.localName, 'unit');
      expect(value.attributes.single.required, isTrue);
    });

    test('rejects unsupported simple type facets', () {
      expect(
        () => ExiSchemaCompiler.compile(
          id: 'facets.xsd',
          source: '''
            <xs:schema xmlns:xs="http://www.w3.org/2001/XMLSchema">
              <xs:simpleType name="Code">
                <xs:restriction base="xs:string">
                  <xs:enumeration value="A"/>
                </xs:restriction>
              </xs:simpleType>
              <xs:element name="code" type="Code"/>
            </xs:schema>
          ''',
        ),
        throwsUnsupportedError,
      );
    });

    test('rejects recursive simple type restrictions', () {
      expect(
        () => ExiSchemaCompiler.compile(
          id: 'recursive-simple.xsd',
          source: '''
            <xs:schema xmlns:xs="http://www.w3.org/2001/XMLSchema">
              <xs:simpleType name="First">
                <xs:restriction base="Second"/>
              </xs:simpleType>
              <xs:simpleType name="Second">
                <xs:restriction base="First"/>
              </xs:simpleType>
              <xs:element name="value" type="First"/>
            </xs:schema>
          ''',
        ),
        throwsUnsupportedError,
      );
    });

    test('compiles nillable element declarations', () {
      final schema = ExiSchemaCompiler.compile(
        id: 'nillable.xsd',
        source: '''
          <xs:schema xmlns:xs="http://www.w3.org/2001/XMLSchema">
            <xs:element name="root" nillable="true"/>
          </xs:schema>
        ''',
      );

      expect(schema.globalElements.single.nillable, isTrue);
    });

    test('rejects an invalid nillable flag', () {
      expect(
        () => ExiSchemaCompiler.compile(
          id: 'invalid-nillable.xsd',
          source: '''
            <xs:schema xmlns:xs="http://www.w3.org/2001/XMLSchema">
              <xs:element name="root" nillable="sometimes"/>
            </xs:schema>
          ''',
        ),
        throwsFormatException,
      );
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

    test('resolves nested named attribute groups', () {
      final schema = ExiSchemaCompiler.compile(
        id: 'attribute-groups.xsd',
        source: '''
          <xs:schema xmlns:xs="http://www.w3.org/2001/XMLSchema">
            <xs:attributeGroup name="identity">
              <xs:attribute name="id" use="required"/>
            </xs:attributeGroup>
            <xs:attributeGroup name="metadata">
              <xs:attributeGroup ref="identity"/>
              <xs:attribute name="kind"/>
            </xs:attributeGroup>
            <xs:element name="root">
              <xs:complexType>
                <xs:attributeGroup ref="metadata"/>
              </xs:complexType>
            </xs:element>
          </xs:schema>
        ''',
      );

      expect(schema.globalElements.single.attributes.map((attribute) => attribute.name.localName), ['id', 'kind']);
    });

    test('rejects recursive attribute groups', () {
      expect(
        () => ExiSchemaCompiler.compile(
          id: 'recursive-attribute-group.xsd',
          source: '''
            <xs:schema xmlns:xs="http://www.w3.org/2001/XMLSchema">
              <xs:attributeGroup name="recursive">
                <xs:attributeGroup ref="recursive"/>
              </xs:attributeGroup>
              <xs:element name="root">
                <xs:complexType>
                  <xs:attributeGroup ref="recursive"/>
                </xs:complexType>
              </xs:element>
            </xs:schema>
          ''',
        ),
        throwsUnsupportedError,
      );
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

    test('applies local element and attribute form overrides', () {
      final schema = ExiSchemaCompiler.compile(
        id: 'forms.xsd',
        source: '''
          <xs:schema
              xmlns:xs="http://www.w3.org/2001/XMLSchema"
              targetNamespace="urn:example"
              elementFormDefault="unqualified"
              attributeFormDefault="qualified">
            <xs:element name="root">
              <xs:complexType>
                <xs:sequence>
                  <xs:element name="qualifiedChild" form="qualified"/>
                  <xs:element name="plainChild"/>
                </xs:sequence>
                <xs:attribute name="plain" form="unqualified"/>
                <xs:attribute name="qualified"/>
              </xs:complexType>
            </xs:element>
          </xs:schema>
        ''',
      );

      final root = schema.globalElements.single;
      final particles = (root.content as ExiSequenceParticle).particles.cast<ExiElementParticle>().toList();
      expect(particles[0].element.name.uri, 'urn:example');
      expect(particles[1].element.name.uri, isEmpty);
      expect(root.attributes[0].name, const ExiQName(localName: 'plain'));
      expect(root.attributes[1].name, const ExiQName(uri: 'urn:example', localName: 'qualified'));
    });

    test('resolves target-namespace named type QNames', () {
      final schema = ExiSchemaCompiler.compile(
        id: 'qualified-types.xsd',
        source: '''
          <xs:schema
              xmlns:xs="http://www.w3.org/2001/XMLSchema"
              xmlns:tns="urn:example"
              targetNamespace="urn:example">
            <xs:simpleType name="Code">
              <xs:restriction base="xs:string"/>
            </xs:simpleType>
            <xs:complexType name="Container">
              <xs:sequence>
                <xs:element name="code" type="tns:Code"/>
              </xs:sequence>
            </xs:complexType>
            <xs:element name="root" type="tns:Container"/>
          </xs:schema>
        ''',
      );

      expect(schema.globalElements.single.children.single.datatype, ExiDatatype.string);
    });

    test('rejects external and undeclared type prefixes', () {
      for (final typeName in ['external:Local', 'missing:Local']) {
        expect(
          () => ExiSchemaCompiler.compile(
            id: 'invalid-type-prefix.xsd',
            source:
                '''
              <xs:schema
                  xmlns:xs="http://www.w3.org/2001/XMLSchema"
                  xmlns:external="urn:external">
                <xs:complexType name="Local"/>
                <xs:element name="root" type="$typeName"/>
              </xs:schema>
            ''',
          ),
          anyOf(throwsFormatException, throwsUnsupportedError),
        );
      }
    });

    test('rejects invalid namespace form values', () {
      expect(
        () => ExiSchemaCompiler.compile(
          id: 'invalid-form.xsd',
          source: '''
            <xs:schema xmlns:xs="http://www.w3.org/2001/XMLSchema">
              <xs:element name="root">
                <xs:complexType>
                  <xs:sequence>
                    <xs:element name="child" form="sometimes"/>
                  </xs:sequence>
                </xs:complexType>
              </xs:element>
            </xs:schema>
          ''',
        ),
        throwsFormatException,
      );
    });

    test('compiles mixed complex content', () {
      final schema = ExiSchemaCompiler.compile(
        id: 'mixed.xsd',
        source: '''
          <xs:schema xmlns:xs="http://www.w3.org/2001/XMLSchema">
            <xs:element name="root">
              <xs:complexType mixed="true">
                <xs:sequence>
                  <xs:element name="child"/>
                </xs:sequence>
              </xs:complexType>
            </xs:element>
          </xs:schema>
        ''',
      );

      final root = schema.globalElements.single;
      expect(root.mixed, isTrue);
      expect(root.content, isA<ExiSequenceParticle>());
    });

    test('rejects an invalid mixed-content flag', () {
      expect(
        () => ExiSchemaCompiler.compile(
          id: 'invalid-mixed.xsd',
          source: '''
            <xs:schema xmlns:xs="http://www.w3.org/2001/XMLSchema">
              <xs:element name="root">
                <xs:complexType mixed="sometimes"/>
              </xs:element>
            </xs:schema>
          ''',
        ),
        throwsFormatException,
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
