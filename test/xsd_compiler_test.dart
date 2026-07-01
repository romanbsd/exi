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

    test('rejects occurrence ranges outside the supported grammar subset', () {
      expect(
        () => ExiSchemaCompiler.compile(
          id: 'repeated.xsd',
          source: '''
            <xs:schema xmlns:xs="http://www.w3.org/2001/XMLSchema">
              <xs:element name="root">
                <xs:complexType>
                  <xs:sequence>
                    <xs:element name="item" maxOccurs="unbounded"/>
                  </xs:sequence>
                </xs:complexType>
              </xs:element>
            </xs:schema>
          ''',
        ),
        throwsA(isA<UnsupportedError>()),
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
  });
}
