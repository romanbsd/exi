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

    test('rejects malformed comments during XML reconstruction', () {
      final bits = StringBuffer('10000000')
        ..write('0')
        ..write(_qName('', 'root'))
        // StartTagContent -> CM.
        ..write('100')
        ..write(_rawString('bad--comment'))
        // ElementContent -> EE; DocEnd -> ED.
        ..write('0')
        ..write('0');

      final document = ExiDecoder(
        options: const ExiOptions(fidelity: ExiFidelityOptions(comments: true)),
      ).decode(_pack(bits.toString()));

      expect(document.events.whereType<ExiComment>().single.text, 'bad--comment');
      expect(document.toXmlString, throwsFormatException);
    });

    test('rejects malformed processing instructions during XML reconstruction', () {
      final bits = StringBuffer('10000000')
        ..write('0')
        ..write(_qName('', 'root'))
        // StartTagContent -> PI: second-level branch 4, third-level PI 1.
        ..write('1001')
        ..write(_rawString('xml'))
        ..write(_rawString('bad?>data'))
        ..write('0')
        ..write('0');

      final document = ExiDecoder(
        options: const ExiOptions(fidelity: ExiFidelityOptions(comments: true, processingInstructions: true)),
      ).decode(_pack(bits.toString()));

      final instruction = document.events.whereType<ExiProcessingInstruction>().single;
      expect(instruction.target, 'xml');
      expect(instruction.text, 'bad?>data');
      expect(document.toXmlString, throwsFormatException);
    });

    test('preserves document-level comments and processing instructions', () {
      final bits = StringBuffer('10000000')
        // DocContent -> CM.
        ..write('10')
        ..write(_rawString('before'))
        // DocContent -> SE(*).
        ..write('0')
        ..write(_qName('', 'root'))
        // StartTagContent -> EE.
        ..write('000')
        // DocEnd -> PI.
        ..write('11')
        ..write(_rawString('after'))
        ..write(_rawString('done'))
        // DocEnd -> ED.
        ..write('0');

      final document = ExiDecoder(
        options: const ExiOptions(fidelity: ExiFidelityOptions(comments: true, processingInstructions: true)),
      ).decode(_pack(bits.toString()));

      expect(document.events.whereType<ExiComment>().single.text, 'before');
      final instruction = document.events.whereType<ExiProcessingInstruction>().single;
      expect(instruction.target, 'after');
      expect(instruction.text, 'done');
      expect(document.toXmlString(), '<!--before--><root/><?after done?>');
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

    test('rejects malformed entity references during XML reconstruction', () {
      final bits = StringBuffer('10000000')
        ..write('0')
        ..write(_qName('', 'root'))
        // StartTagContent -> ER.
        ..write('100')
        ..write(_rawString('bad name'))
        // ElementContent -> EE; DocEnd -> ED.
        ..write('0')
        ..write('0');

      final document = ExiDecoder(
        options: const ExiOptions(fidelity: ExiFidelityOptions(dtd: true)),
      ).decode(_pack(bits.toString()));

      expect(document.events.whereType<ExiEntityReference>().single.name, 'bad name');
      expect(document.toXmlString, throwsFormatException);
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

    test('renders an element resolved through a default namespace declaration', () {
      final bits = StringBuffer('10000000')
        ..write(_qName('urn:example', 'root'))
        // StartTagContent -> NS.
        ..write('010')
        ..write(_rawString('urn:example'))
        ..write(_rawString(''))
        ..write('1')
        // StartTagContent -> EE.
        ..write('000');

      final document = ExiDecoder(
        options: const ExiOptions(fidelity: ExiFidelityOptions(prefixes: true)),
      ).decode(_pack(bits.toString()));

      final root = document.events.whereType<ExiStartElement>().single;
      expect(root.name, const ExiQName(uri: 'urn:example', localName: 'root', prefix: ''));
      final namespace = document.events.whereType<ExiNamespaceDeclaration>().single;
      expect(namespace, const ExiNamespaceDeclaration(uri: 'urn:example', prefix: '', localElementNamespace: true));
      expect(document.toXmlString(), '<root xmlns="urn:example"/>');
    });

    test('rejects malformed namespace prefixes during XML reconstruction', () {
      final bits = StringBuffer('10000000')
        ..write(_qName('urn:example', 'root'))
        // StartTagContent -> NS.
        ..write('010')
        ..write(_rawString('urn:example'))
        ..write(_rawString('bad prefix'))
        ..write('1')
        // StartTagContent -> EE.
        ..write('000');

      final document = ExiDecoder(
        options: const ExiOptions(fidelity: ExiFidelityOptions(prefixes: true)),
      ).decode(_pack(bits.toString()));

      final namespace = document.events.whereType<ExiNamespaceDeclaration>().single;
      expect(namespace.prefix, 'bad prefix');
      expect(document.toXmlString, throwsFormatException);
    });

    test('rejects malformed non-local namespace declaration prefixes during XML reconstruction', () {
      final bits = StringBuffer('10000000')
        ..write(_qName('', 'root'))
        // StartTagContent -> NS.
        ..write('010')
        ..write(_rawString('urn:example'))
        ..write(_rawString('bad prefix'))
        ..write('0')
        // StartTagContent -> EE.
        ..write('000');

      final document = ExiDecoder(
        options: const ExiOptions(fidelity: ExiFidelityOptions(prefixes: true)),
      ).decode(_pack(bits.toString()));

      final namespace = document.events.whereType<ExiNamespaceDeclaration>().single;
      expect(namespace.prefix, 'bad prefix');
      expect(document.toXmlString, throwsFormatException);
    });

    test('rejects a namespaced element without a resolvable prefix', () {
      final bits = StringBuffer('10000000')
        ..write(_qName('urn:example', 'root'))
        // StartTagContent -> EE without a local NS resolving the prefix.
        ..write('000');

      expect(
        () => ExiDecoder(
          options: const ExiOptions(fidelity: ExiFidelityOptions(prefixes: true)),
        ).decode(_pack(bits.toString())),
        throwsFormatException,
      );
    });

    test('rejects a namespaced attribute without a resolvable prefix', () {
      final bits = StringBuffer('10000000')
        ..write(_qName('', 'root'))
        // StartTagContent -> AT(*).
        ..write('001')
        ..write(_qName('urn:example', 'attr'))
        ..write(_value('value'))
        // StartTagContent -> EE after the learned attribute.
        ..write('1000');

      expect(
        () => ExiDecoder(
          options: const ExiOptions(fidelity: ExiFidelityOptions(prefixes: true)),
        ).decode(_pack(bits.toString())),
        throwsFormatException,
      );
    });

    test('uses namespace declarations as URI and prefix partition entries for child QNames', () {
      final bits = StringBuffer('10000000')
        ..write(_qName('', 'root'))
        // StartTagContent -> NS.
        ..write('010')
        ..write(_rawString('urn:example'))
        ..write(_rawString('p'))
        ..write('0')
        // StartTagContent -> SE(*), with a QName URI hit for the namespace declaration.
        ..write('011')
        ..write(_qNameUriHit(uriId: 3, uriCount: 4, localName: 'child'))
        // child StartTagContent -> EE.
        ..write('000')
        // root ElementContent -> EE.
        ..write('0');

      final document = ExiDecoder(
        options: const ExiOptions(fidelity: ExiFidelityOptions(prefixes: true)),
      ).decode(_pack(bits.toString()));

      final child = document.events.whereType<ExiStartElement>().last;
      expect(child.name, const ExiQName(uri: 'urn:example', localName: 'child', prefix: 'p'));
      expect(document.toXmlString(), '<root xmlns:p="urn:example"><p:child/></root>');
    });

    test('does not add namespace undeclaration prefixes to the empty-URI prefix partition', () {
      final bits = StringBuffer('10000000')
        ..write(_qName('', 'root'))
        // StartTagContent -> NS undeclaration for prefix p.
        ..write('010')
        ..write(_rawString(''))
        ..write(_rawString('p'))
        ..write('0')
        // StartTagContent -> SE(*) with an empty-URI QName.
        ..write('011')
        ..write(_qName('', 'child'))
        // child StartTagContent -> EE.
        ..write('000')
        // root ElementContent -> EE.
        ..write('0');

      final document = ExiDecoder(
        options: const ExiOptions(fidelity: ExiFidelityOptions(prefixes: true)),
      ).decode(_pack(bits.toString()));

      final child = document.events.whereType<ExiStartElement>().last;
      expect(child.name, const ExiQName(localName: 'child'));
      expect(document.toXmlString(), '<root xmlns:p=""><child/></root>');
    });

    test('does not resolve no-namespace attributes through namespace undeclarations', () {
      final bits = StringBuffer('10000000')
        ..write(_qName('', 'root'))
        // StartTagContent -> NS undeclaration for prefix p.
        ..write('010')
        ..write(_rawString(''))
        ..write(_rawString('p'))
        ..write('0')
        // StartTagContent -> AT(*) with an empty-URI QName.
        ..write('001')
        ..write(_qName('', 'attr'))
        ..write(_value('value'))
        // StartTagContent -> EE after the learned attribute.
        ..write('1000');

      final document = ExiDecoder(
        options: const ExiOptions(fidelity: ExiFidelityOptions(prefixes: true)),
      ).decode(_pack(bits.toString()));

      final attribute = document.events.whereType<ExiAttribute>().single;
      expect(attribute.name.prefix, isNot('p'));
      expect(document.toXmlString(), '<root xmlns:p="" attr="value"/>');
    });

    test('uses namespace declarations as multiple prefix partition entries for QNames', () {
      final bits = StringBuffer('10000000')
        ..write(_qName('', 'root'))
        // StartTagContent -> NS.
        ..write('010')
        ..write(_rawString('urn:example'))
        ..write(_rawString('p'))
        ..write('0')
        // StartTagContent -> a second NS for the same URI.
        ..write('010')
        ..write(_rawString('urn:example'))
        ..write(_rawString('q'))
        ..write('0')
        // StartTagContent -> SE(*), with URI id 3 and prefix id 1 ("q").
        ..write('011')
        ..write(_qNameUriHit(uriId: 3, uriCount: 4, localName: 'child', prefixId: 1, prefixCount: 2))
        // child StartTagContent -> EE.
        ..write('000')
        // root ElementContent -> EE.
        ..write('0');

      final document = ExiDecoder(
        options: const ExiOptions(fidelity: ExiFidelityOptions(prefixes: true)),
      ).decode(_pack(bits.toString()));

      final child = document.events.whereType<ExiStartElement>().last;
      expect(child.name, const ExiQName(uri: 'urn:example', localName: 'child', prefix: 'q'));
      expect(document.toXmlString(), '<root xmlns:p="urn:example" xmlns:q="urn:example"><q:child/></root>');
    });

    test('rejects more than one local namespace declaration for an element', () {
      final bits = StringBuffer('10000000')
        ..write(_qName('urn:example', 'root'))
        // StartTagContent -> first local NS.
        ..write('010')
        ..write(_rawString('urn:example'))
        ..write(_rawString('p'))
        ..write('1')
        // StartTagContent -> second local NS for the same element.
        ..write('010')
        ..write(_rawString('urn:example'))
        ..write(_rawString('q'))
        ..write('1');

      expect(
        () => ExiDecoder(
          options: const ExiOptions(fidelity: ExiFidelityOptions(prefixes: true)),
        ).decode(_pack(bits.toString())),
        throwsFormatException,
      );
    });

    test('uses namespace declarations as URI and prefix partition entries for attribute QNames', () {
      final bits = StringBuffer('10000000')
        ..write(_qName('', 'root'))
        // StartTagContent -> NS.
        ..write('010')
        ..write(_rawString('urn:example'))
        ..write(_rawString('p'))
        ..write('0')
        // StartTagContent -> AT(*), with a QName URI hit for the namespace declaration.
        ..write('001')
        ..write(_qNameUriHit(uriId: 3, uriCount: 4, localName: 'id'))
        ..write(_value('42'))
        // StartTagContent -> EE after the learned attribute.
        ..write('1000');

      final document = ExiDecoder(
        options: const ExiOptions(fidelity: ExiFidelityOptions(prefixes: true)),
      ).decode(_pack(bits.toString()));

      final attribute = document.events.whereType<ExiAttribute>().single;
      expect(attribute.name, const ExiQName(uri: 'urn:example', localName: 'id', prefix: 'p'));
      expect(document.toXmlString(), '<root xmlns:p="urn:example" p:id="42"/>');
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
        // StartTagContent -> EE.
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

    test('preserves fragment-level comments', () {
      final bits = StringBuffer('10000000')
        // FragmentContent -> CM.
        ..write('10')
        ..write(_rawString('before'))
        // FragmentContent -> SE(*).
        ..write('00')
        ..write(_qName('', 'item'))
        // StartTagContent -> EE.
        ..write('000')
        // FragmentContent -> CM after one learned SE(item).
        ..write('11')
        ..write(_rawString('after'))
        // FragmentContent -> ED.
        ..write('10');

      final document = ExiDecoder(
        options: const ExiOptions(fragment: true, fidelity: ExiFidelityOptions(comments: true)),
      ).decode(_pack(bits.toString()));

      expect(document.events.whereType<ExiComment>().map((event) => event.text), ['before', 'after']);
      expect(document.toXmlString(), '<!--before--><item/><!--after-->');
    });

    test('preserves fragment-level processing instructions', () {
      final bits = StringBuffer('10000000')
        // FragmentContent -> PI.
        ..write('10')
        ..write(_rawString('target'))
        ..write(_rawString('data'))
        // FragmentContent -> SE(*).
        ..write('00')
        ..write(_qName('', 'item'))
        // StartTagContent -> EE.
        ..write('000')
        // FragmentContent -> ED after one learned SE(item).
        ..write('10');

      final document = ExiDecoder(
        options: const ExiOptions(fragment: true, fidelity: ExiFidelityOptions(processingInstructions: true)),
      ).decode(_pack(bits.toString()));

      final instruction = document.events.whereType<ExiProcessingInstruction>().single;
      expect(instruction.target, 'target');
      expect(instruction.text, 'data');
      expect(document.toXmlString(), '<?target data?><item/>');
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

  test('rejects strict mode combined with forbidden fidelity options', () {
    const forbidden = [
      ExiFidelityOptions(dtd: true),
      ExiFidelityOptions(prefixes: true),
      ExiFidelityOptions(comments: true),
      ExiFidelityOptions(processingInstructions: true),
    ];

    for (final fidelity in forbidden) {
      expect(() => ExiDecoder(options: ExiOptions(strict: true, fidelity: fidelity)), throwsArgumentError);
    }
  });

  test('allows strict mode with lexical value preservation', () {
    expect(
      ExiDecoder(options: const ExiOptions(strict: true, fidelity: ExiFidelityOptions(lexicalValues: true))),
      isA<ExiDecoder>(),
    );
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

  test('does not add values longer than valueMaxLength to value partitions', () {
    final bits = StringBuffer('10000000')
      ..write(_qName('', 'root'))
      // StartTagContent -> CH(*) with a value too long to add.
      ..write('11')
      ..write(_value('long'))
      // ElementContent -> CH(*) with a local value hit against the empty partition.
      ..write('11')
      ..write(_unsigned(0));

    expect(
      () => ExiDecoder(options: const ExiOptions(valueMaxLength: 2)).decode(_pack(bits.toString())),
      throwsA(isA<FormatException>()),
    );
  });

  test('applies valueMaxLength to attribute value partitions', () {
    final bits = StringBuffer('10000000')
      // FragmentContent -> SE(*).
      ..write('0')
      ..write(_qName('', 'item'))
      // StartTagContent -> AT(*) with a value too long to add.
      ..write('01')
      ..write(_qName('', 'id'))
      ..write(_value('long'))
      // StartTagContent -> EE.
      ..write('100')
      // FragmentContent -> learned SE(item).
      ..write('00')
      // StartTagContent -> learned AT(id), after the learned EE production.
      ..write('01')
      ..write(_unsigned(0));

    expect(
      () => ExiDecoder(options: const ExiOptions(fragment: true, valueMaxLength: 2)).decode(_pack(bits.toString())),
      throwsA(isA<FormatException>()),
    );
  });

  test('does not add empty values to value partitions', () {
    final bits = StringBuffer('10000000')
      ..write(_qName('', 'root'))
      // StartTagContent -> CH(*) with an empty value.
      ..write('11')
      ..write(_value(''))
      // ElementContent -> CH(*) with a local value hit against the empty partition.
      ..write('11')
      ..write(_unsigned(0));

    expect(() => ExiDecoder().decode(_pack(bits.toString())), throwsA(isA<FormatException>()));
  });

  test('reuses the newest global value after capacity replacement', () {
    final bits = StringBuffer('10000000')
      ..write(_qName('', 'root'))
      // StartTagContent -> CH(*) with the first value.
      ..write('11')
      ..write(_value('first'))
      // ElementContent -> CH(*) with a second value that replaces global id 0.
      ..write('11')
      ..write(_value('second'))
      // ElementContent -> learned CH with a global value hit.
      ..write('00')
      ..write(_unsigned(1))
      // ElementContent -> EE.
      ..write('01');

    final document = ExiDecoder(options: const ExiOptions(valuePartitionCapacity: 1)).decode(_pack(bits.toString()));

    expect(document.toXmlString(), '<root>firstsecondsecond</root>');
  });

  test('resolves attribute local value partition hits across repeated elements', () {
    final bits = StringBuffer('10000000')
      // FragmentContent -> SE(*).
      ..write('0')
      ..write(_qName('', 'item'))
      // StartTagContent -> AT(*) with a new value.
      ..write('01')
      ..write(_qName('', 'id'))
      ..write(_value('same'))
      // StartTagContent -> EE.
      ..write('100')
      // FragmentContent -> learned SE(item).
      ..write('00')
      // StartTagContent -> learned AT(id), after the learned EE production.
      ..write('01')
      ..write(_unsigned(0))
      // StartTagContent -> learned EE.
      ..write('00')
      // FragmentContent -> ED.
      ..write('10');

    final document = ExiDecoder(options: const ExiOptions(fragment: true)).decode(_pack(bits.toString()));

    expect(document.events.whereType<ExiAttribute>().map((event) => event.value), ['same', 'same']);
    expect(document.toXmlString(), '<item id="same"/><item id="same"/>');
  });

  test('invalidates local value ids replaced by valuePartitionCapacity', () {
    final bits = StringBuffer('10000000')
      ..write(_qName('', 'root'))
      // StartTagContent -> CH(*) with the first value.
      ..write('11')
      ..write(_value('first'))
      // ElementContent -> CH(*) with a second value that replaces the first.
      ..write('11')
      ..write(_value('second'))
      // ElementContent -> learned CH with a local value hit for replaced local id 0.
      ..write('00')
      ..write(_unsigned(0))
      ..write('0');

    expect(
      () => ExiDecoder(options: const ExiOptions(valuePartitionCapacity: 1)).decode(_pack(bits.toString())),
      throwsA(isA<FormatException>()),
    );
  });
}

String _qName(String uri, String localName) {
  final encodedUri = uri.isEmpty ? '01' : '00${_rawString(uri)}';
  return '$encodedUri${_literal(localName, lengthOffset: 1)}';
}

String _qNameUriHit({
  required int uriId,
  required int uriCount,
  required String localName,
  int? prefixId,
  int? prefixCount,
}) {
  final encodedUri = (uriId + 1).toRadixString(2).padLeft(uriCount.bitLength, '0');
  final encodedPrefix = switch ((prefixId, prefixCount)) {
    (final int id, final int count) => id.toRadixString(2).padLeft((count - 1).bitLength, '0'),
    _ => '',
  };
  return '$encodedUri${_literal(localName, lengthOffset: 1)}$encodedPrefix';
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
