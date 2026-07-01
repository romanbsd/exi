enum ExiAlignment { bitPacked, byteAligned, preCompression }

final class ExiFidelityOptions {
  const ExiFidelityOptions({
    this.comments = false,
    this.processingInstructions = false,
    this.dtd = false,
    this.prefixes = false,
    this.lexicalValues = false,
  });

  final bool comments;
  final bool processingInstructions;
  final bool dtd;
  final bool prefixes;
  final bool lexicalValues;
}

final class ExiOptions {
  const ExiOptions({
    this.alignment = ExiAlignment.bitPacked,
    this.compression = false,
    this.fragment = false,
    this.strict = false,
    this.selfContained = false,
    this.fidelity = const ExiFidelityOptions(),
  });

  final ExiAlignment alignment;
  final bool compression;
  final bool fragment;
  final bool strict;
  final bool selfContained;
  final ExiFidelityOptions fidelity;
}
