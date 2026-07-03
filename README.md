# exi

A staged, specification-driven Dart implementation of the W3C Efficient XML
Interchange (EXI) Format 1.0 (Second Edition).

The current decoder stage supports:

- optional `$EXI` cookies and final EXI version 1 headers;
- schema-less documents using the built-in document and element grammars;
- schema-less self-contained elements with required byte boundaries and
  isolated/restored string-table and learned-grammar state;
- schema-less fragments with dynamic top-level QName learning and strict
  schema-informed fragments with unambiguous declared element QNames;
- configurable out-of-band fidelity options for comments, processing
  instructions, DTD/entity events, and namespace prefixes;
- in-band EXI options for strict mode, fragments, fidelity preservation, and
  value-table limits, including nilled, empty, named, and explicitly non-nilled
  schema IDs;
- bit-packed and byte-aligned event/content decoding, including header padding,
  plus single-final-block pre-compression and DEFLATE compression with
  QName-grouped small and large value-channel streams;
- absent, schema-less, built-in-types, and named schema IDs with resolver-based
  schema selection;
- strict compiled schemas and schema-valid first-level paths plus common
  non-strict deviations, including early end elements, untyped characters,
  wildcard elements, typed/untyped attributes, `xsi:type`, `xsi:nil`, entity
  references, namespace declarations, self-contained content, comments, and
  processing instructions; schemas can contain global elements, attributes,
  sequences, choices, unordered `all` groups, and optional, bounded, or
  unbounded element and compositor particles, including mixed and nillable
  content and named derived-type selection;
- XSD compilation for global elements, named/inline complex types, attributes,
  global element and attribute references, named model and attribute groups,
  nested sequences and choices, `all` compositors, empty content, occurrence
  ranges including repeated nullable compositors, local namespace form
  overrides, and primitive, named, and chained simple types, schema-order
  enumerations, integer range and Boolean pattern
  facets, string-pattern restricted character sets, typed lists, and
  String-represented unions, plus attributed
  `simpleContent` and `complexContent` extension, unconstrained element and
  attribute wildcards with global declaration lookup, finite
  namespace-constrained wildcards, `##other` wildcards, wildcard datatype
  lookup independent of XSD `processContents`, and namespace-aware type
  resolution;
- schema-typed string, boolean, integer, decimal, float, binary, date, time,
  date-time, partial Gregorian calendar, and list values, with the required
  String fallback for duration, QName, and NOTATION schema types and restricted
  String representations for preserved lexical values;
- in-band and out-of-band datatype representation maps targeting built-in EXI
  datatype identifiers, including closest-ancestor selection for named schema
  types and mapped list-item representations;
- repeated user-defined EXI header metadata elements, retained as isolated
  event streams on the decoded options;
- URI, local-name, and value string-table partitions, including schema-informed
  URI and declared-name prepopulation;
- start/end document, start/end element, attribute, character, namespace,
  comment, processing-instruction, document-type, and entity-reference events;
- XML reconstruction, including preserved namespace declarations.

User-defined datatype representation implementations remain unsupported. XSD
imports/includes, complex-content restriction, defaults and fixed values,
substitution groups, abstract
declarations and derivation controls, inherited wildcard unions involving
`##other`, schema-informed grammars requiring unsupported XSD features, relaxed
element-fragment grammars for ambiguous declarations, multi-block
pre-compression, and multi-block compression are also not yet available.

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
