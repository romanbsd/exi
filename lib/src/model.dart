import 'options.dart';

/// The qualified name carried by an EXI start-element or attribute event.
final class ExiQName {
  const ExiQName({this.uri = '', required this.localName, this.prefix});

  final String uri;
  final String localName;
  final String? prefix;

  String get lexicalName {
    final currentPrefix = prefix;
    if (currentPrefix == null || currentPrefix.isEmpty) {
      return localName;
    }
    return '$currentPrefix:$localName';
  }

  @override
  bool operator ==(Object other) => other is ExiQName && other.uri == uri && other.localName == localName;

  @override
  int get hashCode => Object.hash(uri, localName);

  @override
  String toString() => uri.isEmpty ? lexicalName : '{$uri}$lexicalName';
}

sealed class ExiEvent {
  const ExiEvent();
}

final class ExiStartDocument extends ExiEvent {
  const ExiStartDocument();
}

final class ExiEndDocument extends ExiEvent {
  const ExiEndDocument();
}

final class ExiStartElement extends ExiEvent {
  const ExiStartElement(this.name);

  final ExiQName name;
}

final class ExiEndElement extends ExiEvent {
  const ExiEndElement(this.name);

  final ExiQName name;
}

final class ExiAttribute extends ExiEvent {
  const ExiAttribute(this.name, this.value);

  final ExiQName name;
  final String value;
}

final class ExiCharacters extends ExiEvent {
  const ExiCharacters(this.value);

  final String value;
}

final class ExiNamespaceDeclaration extends ExiEvent {
  const ExiNamespaceDeclaration({required this.uri, required this.prefix, required this.localElementNamespace});

  final String uri;
  final String prefix;
  final bool localElementNamespace;

  @override
  bool operator ==(Object other) =>
      other is ExiNamespaceDeclaration &&
      other.uri == uri &&
      other.prefix == prefix &&
      other.localElementNamespace == localElementNamespace;

  @override
  int get hashCode => Object.hash(uri, prefix, localElementNamespace);
}

final class ExiComment extends ExiEvent {
  const ExiComment(this.text);

  final String text;
}

final class ExiProcessingInstruction extends ExiEvent {
  const ExiProcessingInstruction(this.target, this.text);

  final String target;
  final String text;
}

final class ExiDocumentType extends ExiEvent {
  const ExiDocumentType({required this.name, required this.publicId, required this.systemId, required this.text});

  final String name;
  final String publicId;
  final String systemId;
  final String text;
}

final class ExiEntityReference extends ExiEvent {
  const ExiEntityReference(this.name);

  final String name;
}

final class ExiHeader {
  const ExiHeader({required this.hasCookie, required this.hasOptions, required this.isPreview, required this.version});

  final bool hasCookie;
  final bool hasOptions;
  final bool isPreview;
  final int version;
}

final class ExiDocument {
  ExiDocument({required this.header, required List<ExiEvent> events, this.options = const ExiOptions()})
    : events = List.unmodifiable(events);

  final ExiHeader header;
  final List<ExiEvent> events;
  final ExiOptions options;

  String toXmlString() {
    final output = StringBuffer();
    final elements = <ExiQName>[];
    var startTagIsOpen = false;

    for (final event in events) {
      switch (event) {
        case ExiStartDocument() || ExiEndDocument():
          break;
        case ExiStartElement(:final name):
          if (startTagIsOpen) {
            output.write('>');
          }
          _ensureRenderableElement(name);
          output
            ..write('<')
            ..write(name.lexicalName);
          elements.add(name);
          startTagIsOpen = true;
        case ExiAttribute(:final name, :final value):
          if (!startTagIsOpen) {
            throw StateError('Attribute event occurred outside a start tag');
          }
          _ensureRenderableAttribute(name);
          output
            ..write(' ')
            ..write(name.lexicalName)
            ..write('="')
            ..write(_escapeXml(value, attribute: true))
            ..write('"');
        case ExiNamespaceDeclaration(:final uri, :final prefix):
          if (!startTagIsOpen) {
            throw StateError('Namespace event occurred outside a start tag');
          }
          if (prefix.isNotEmpty) {
            _ensureXmlNcName(prefix, 'namespace prefix');
          }
          output
            ..write(prefix.isEmpty ? ' xmlns="' : ' xmlns:$prefix="')
            ..write(_escapeXml(uri, attribute: true))
            ..write('"');
        case ExiCharacters(:final value):
          if (startTagIsOpen) {
            output.write('>');
            startTagIsOpen = false;
          }
          output.write(_escapeXml(value));
        case ExiEndElement(:final name):
          if (elements.isEmpty || elements.removeLast() != name) {
            throw StateError('Mismatched EXI end-element event');
          }
          if (startTagIsOpen) {
            output.write('/>');
            startTagIsOpen = false;
          } else {
            output
              ..write('</')
              ..write(name.lexicalName)
              ..write('>');
          }
        case ExiComment(:final text):
          if (startTagIsOpen) {
            output.write('>');
            startTagIsOpen = false;
          }
          _ensureRenderableComment(text);
          output
            ..write('<!--')
            ..write(text)
            ..write('-->');
        case ExiProcessingInstruction(:final target, :final text):
          if (startTagIsOpen) {
            output.write('>');
            startTagIsOpen = false;
          }
          _ensureRenderableProcessingInstruction(target, text);
          output
            ..write('<?')
            ..write(target);
          if (text.isNotEmpty) {
            output
              ..write(' ')
              ..write(text);
          }
          output.write('?>');
        case ExiDocumentType(:final name, :final publicId, :final systemId, :final text):
          output
            ..write('<!DOCTYPE ')
            ..write(name);
          if (publicId.isNotEmpty) {
            output
              ..write(' PUBLIC "')
              ..write(_escapeXml(publicId, attribute: true))
              ..write('" "')
              ..write(_escapeXml(systemId, attribute: true))
              ..write('"');
          } else if (systemId.isNotEmpty) {
            output
              ..write(' SYSTEM "')
              ..write(_escapeXml(systemId, attribute: true))
              ..write('"');
          }
          if (text.isNotEmpty) {
            output
              ..write(' [')
              ..write(text)
              ..write(']');
          }
          output.write('>');
        case ExiEntityReference(:final name):
          if (startTagIsOpen) {
            output.write('>');
            startTagIsOpen = false;
          }
          _ensureXmlName(name, 'entity reference');
          output
            ..write('&')
            ..write(name)
            ..write(';');
      }
    }

    if (elements.isNotEmpty || startTagIsOpen) {
      throw StateError('Incomplete EXI event sequence');
    }
    return output.toString();
  }

  static void _ensureRenderableElement(ExiQName name) {
    if (name.uri.isNotEmpty && name.prefix == null) {
      throw UnsupportedError('XML reconstruction requires preserved prefixes for namespaced QNames');
    }
    _ensureXmlQName(name, 'element');
  }

  static void _ensureRenderableAttribute(ExiQName name) {
    if (name.uri.isNotEmpty && (name.prefix == null || name.prefix!.isEmpty)) {
      throw UnsupportedError('XML reconstruction requires preserved non-empty prefixes for namespaced attributes');
    }
    _ensureXmlQName(name, 'attribute');
  }

  static void _ensureRenderableComment(String text) {
    if (text.contains('--') || text.endsWith('-')) {
      throw const FormatException('XML comments cannot contain "--" or end with "-"');
    }
  }

  static void _ensureRenderableProcessingInstruction(String target, String text) {
    _ensureXmlName(target, 'processing-instruction target');
    if (target.toLowerCase() == 'xml') {
      throw const FormatException('XML processing-instruction target cannot be "xml"');
    }
    if (text.contains('?>')) {
      throw const FormatException('XML processing-instruction text cannot contain "?>"');
    }
  }

  static void _ensureXmlName(String value, String label) {
    final runes = value.runes.toList();
    if (runes.isEmpty || !_isXmlNameStart(runes.first) || runes.skip(1).any((rune) => !_isXmlNameChar(rune))) {
      throw FormatException('Invalid XML $label name');
    }
  }

  static void _ensureXmlQName(ExiQName name, String label) {
    _ensureXmlNcName(name.localName, '$label local-name');
    final prefix = name.prefix;
    if (prefix != null && prefix.isNotEmpty) {
      _ensureXmlNcName(prefix, '$label prefix');
    }
  }

  static void _ensureXmlNcName(String value, String label) {
    _ensureXmlName(value, label);
    if (value.contains(':')) {
      throw FormatException('Invalid XML $label name');
    }
  }

  static bool _isXmlNameStart(int rune) =>
      rune == 0x3a ||
      rune == 0x5f ||
      (rune >= 0x41 && rune <= 0x5a) ||
      (rune >= 0x61 && rune <= 0x7a) ||
      (rune >= 0xc0 && rune <= 0xd6) ||
      (rune >= 0xd8 && rune <= 0xf6) ||
      (rune >= 0xf8 && rune <= 0x2ff) ||
      (rune >= 0x370 && rune <= 0x37d) ||
      (rune >= 0x37f && rune <= 0x1fff) ||
      (rune >= 0x200c && rune <= 0x200d) ||
      (rune >= 0x2070 && rune <= 0x218f) ||
      (rune >= 0x2c00 && rune <= 0x2fef) ||
      (rune >= 0x3001 && rune <= 0xd7ff) ||
      (rune >= 0xf900 && rune <= 0xfdcf) ||
      (rune >= 0xfdf0 && rune <= 0xfffd) ||
      (rune >= 0x10000 && rune <= 0xeffff);

  static bool _isXmlNameChar(int rune) =>
      _isXmlNameStart(rune) ||
      rune == 0x2d ||
      rune == 0x2e ||
      (rune >= 0x30 && rune <= 0x39) ||
      rune == 0xb7 ||
      (rune >= 0x300 && rune <= 0x36f) ||
      (rune >= 0x203f && rune <= 0x2040);

  static String _escapeXml(String value, {bool attribute = false}) {
    var escaped = value.replaceAll('&', '&amp;').replaceAll('<', '&lt;').replaceAll('>', '&gt;');
    if (attribute) {
      escaped = escaped.replaceAll('"', '&quot;');
    }
    return escaped;
  }
}
