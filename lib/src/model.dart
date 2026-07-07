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
          output
            ..write('<!--')
            ..write(text)
            ..write('-->');
        case ExiProcessingInstruction(:final target, :final text):
          if (startTagIsOpen) {
            output.write('>');
            startTagIsOpen = false;
          }
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
  }

  static void _ensureRenderableAttribute(ExiQName name) {
    if (name.uri.isNotEmpty && (name.prefix == null || name.prefix!.isEmpty)) {
      throw UnsupportedError('XML reconstruction requires preserved non-empty prefixes for namespaced attributes');
    }
  }

  static String _escapeXml(String value, {bool attribute = false}) {
    var escaped = value.replaceAll('&', '&amp;').replaceAll('<', '&lt;').replaceAll('>', '&gt;');
    if (attribute) {
      escaped = escaped.replaceAll('"', '&quot;');
    }
    return escaped;
  }
}
