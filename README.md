# exi

A staged, specification-driven Dart implementation of the W3C Efficient XML
Interchange (EXI) Format 1.0 (Second Edition).

The current decoder stage supports:

- optional `$EXI` cookies and final EXI version 1 headers;
- schema-less documents using the built-in document and element grammars;
- schema-less fragments with dynamic top-level QName learning;
- configurable out-of-band fidelity options for comments, processing
  instructions, DTD/entity events, and namespace prefixes;
- in-band EXI options for strict mode, fragments, fidelity preservation, and
  value-table limits;
- bit-packed and byte-aligned event/content decoding, including header padding;
- absent, schema-less, built-in-types, and named schema IDs with resolver-based
  schema selection;
- strict compiled schemas containing global empty elements and fixed child
  sequences;
- URI, local-name, and value string-table partitions;
- start/end document, start/end element, attribute, character, namespace,
  comment, processing-instruction, document-type, and entity-reference events;
- XML reconstruction, including preserved namespace declarations.

Datatype representation maps and user metadata remain unsupported. XSD
compilation, non-strict and more general schema-informed grammars,
self-contained elements, pre-compression, and compression are also not yet
available.

```dart
import 'dart:typed_data';

import 'package:exi/exi.dart';

final ExiDocument document = ExiDecoder().decode(Uint8List.fromList(bytes));
print(document.events);
print(document.toXmlString());
```

Options omitted from the EXI header can be supplied out of band:

```dart
final decoder = ExiDecoder(
  options: const ExiOptions(
    fragment: true,
    fidelity: ExiFidelityOptions(
      comments: true,
      processingInstructions: true,
      dtd: true,
      prefixes: true,
    ),
  ),
);
```

Decode a file from the command line:

```console
dart run bin/exi.dart document.exi
```
