List<int>? deriveXsdPatternCharacters(Iterable<String> patterns) {
  final characters = <int>{};
  for (final pattern in patterns) {
    final parsed = _XsdPatternParser(pattern).parse();
    if (parsed == null) {
      return null;
    }
    characters.addAll(parsed);
    if (characters.length >= 256 || characters.any((character) => character > 0xffff)) {
      return null;
    }
  }
  return List.unmodifiable(characters.toList()..sort());
}

final class _XsdPatternParser {
  _XsdPatternParser(this.pattern);

  final String pattern;
  var _offset = 0;

  Set<int>? parse() {
    final characters = _parseExpression(inGroup: false);
    if (_offset != pattern.length) {
      throw FormatException('Unexpected XSD pattern character at offset $_offset');
    }
    return characters;
  }

  Set<int>? _parseExpression({required bool inGroup}) {
    Set<int>? characters = <int>{};
    while (_offset < pattern.length) {
      final rune = _peekRune();
      if (rune == 0x29) {
        if (!inGroup) {
          throw FormatException('Unmatched ")" in XSD pattern at offset $_offset');
        }
        break;
      }
      if (rune == 0x7c) {
        _offset++;
        continue;
      }
      final atom = _parseAtom();
      characters = _union(characters, atom);
      _parseQuantifier();
    }
    return characters;
  }

  Set<int>? _parseAtom() {
    final rune = _readRune();
    return switch (rune) {
      0x28 => _parseGroup(),
      0x5b => _parseCharacterClass(),
      0x5c => _parseEscape(),
      0x2e => null,
      0x2a ||
      0x2b ||
      0x3f ||
      0x7b ||
      0x7d => throw FormatException('XSD pattern quantifier has no atom at offset ${_offset - 1}'),
      _ => {rune},
    };
  }

  Set<int>? _parseGroup() {
    final characters = _parseExpression(inGroup: true);
    if (_offset >= pattern.length || _readRune() != 0x29) {
      throw FormatException('Unclosed group in XSD pattern at offset $_offset');
    }
    return characters;
  }

  Set<int>? _parseCharacterClass() {
    if (_offset >= pattern.length) {
      throw const FormatException('Unclosed character class in XSD pattern');
    }
    if (_peekRune() == 0x5e) {
      _offset++;
      _consumeCharacterClass();
      return null;
    }

    Set<int>? characters = <int>{};
    var hasAtom = false;
    while (_offset < pattern.length && _peekRune() != 0x5d) {
      if (_peekRune() == 0x2d && _offset + 1 < pattern.length && pattern.codeUnitAt(_offset + 1) == 0x5b) {
        _offset += 2;
        final subtraction = _parseCharacterClass();
        if (_offset >= pattern.length || _readRune() != 0x5d) {
          throw const FormatException('Unclosed character-class subtraction in XSD pattern');
        }
        return characters == null || subtraction == null ? null : characters.difference(subtraction);
      }
      hasAtom = true;
      final first = _parseClassAtom();
      if (_offset < pattern.length && _peekRune() == 0x2d) {
        _offset++;
        if (_offset >= pattern.length || _peekRune() == 0x5d) {
          characters = _union(characters, first);
          characters = _union(characters, {0x2d});
          continue;
        }
        final last = _parseClassAtom();
        if (first == null || last == null || first.length != 1 || last.length != 1) {
          characters = null;
          continue;
        }
        final start = first.single;
        final end = last.single;
        if (end < start) {
          throw const FormatException('Descending range in XSD pattern character class');
        }
        if (end > 0xffff) {
          characters = null;
          continue;
        }
        characters = _union(characters, {for (var value = start; value <= end; value++) value});
      } else {
        characters = _union(characters, first);
      }
    }
    if (_offset >= pattern.length || _readRune() != 0x5d) {
      throw const FormatException('Unclosed character class in XSD pattern');
    }
    if (!hasAtom) {
      throw const FormatException('Empty character class in XSD pattern');
    }
    return characters;
  }

  Set<int>? _parseClassAtom() {
    final rune = _readRune();
    if (rune == 0x5c) {
      return _parseEscape();
    }
    if (rune == 0x5b) {
      throw FormatException('Unexpected "[" in XSD pattern character class at offset ${_offset - 1}');
    }
    return {rune};
  }

  Set<int>? _parseEscape() {
    if (_offset >= pattern.length) {
      throw const FormatException('Trailing escape in XSD pattern');
    }
    final rune = _readRune();
    if (rune == 0x73) {
      return {9, 10, 13, 32};
    }
    if (rune == 0x70 || rune == 0x50) {
      if (_offset >= pattern.length || _readRune() != 0x7b) {
        throw const FormatException('Malformed category escape in XSD pattern');
      }
      while (_offset < pattern.length && _peekRune() != 0x7d) {
        _readRune();
      }
      if (_offset >= pattern.length || _readRune() != 0x7d) {
        throw const FormatException('Unclosed category escape in XSD pattern');
      }
      return null;
    }
    if (_isAsciiLetterOrDigit(rune)) {
      return null;
    }
    return {rune};
  }

  void _parseQuantifier() {
    if (_offset >= pattern.length) {
      return;
    }
    final rune = _peekRune();
    if (rune == 0x2a || rune == 0x2b || rune == 0x3f) {
      _offset++;
      return;
    }
    if (rune != 0x7b) {
      return;
    }
    final start = _offset++;
    final minimum = _readDigits();
    if (minimum == null) {
      throw FormatException('Malformed XSD pattern quantifier at offset $start');
    }
    if (_offset < pattern.length && _peekRune() == 0x2c) {
      _offset++;
      final maximum = _readDigits();
      if (maximum != null && maximum < minimum) {
        throw FormatException('Descending XSD pattern quantifier at offset $start');
      }
    }
    if (_offset >= pattern.length || _readRune() != 0x7d) {
      throw FormatException('Unclosed XSD pattern quantifier at offset $start');
    }
  }

  int? _readDigits() {
    final start = _offset;
    var value = 0;
    while (_offset < pattern.length) {
      final rune = _peekRune();
      if (rune < 0x30 || rune > 0x39) {
        break;
      }
      _offset++;
      value = value * 10 + rune - 0x30;
    }
    return _offset == start ? null : value;
  }

  void _consumeCharacterClass() {
    var escaped = false;
    var nested = 0;
    while (_offset < pattern.length) {
      final rune = _readRune();
      if (escaped) {
        escaped = false;
      } else if (rune == 0x5c) {
        escaped = true;
      } else if (rune == 0x5b) {
        nested++;
      } else if (rune == 0x5d) {
        if (nested == 0) {
          return;
        }
        nested--;
      }
    }
    throw const FormatException('Unclosed character class in XSD pattern');
  }

  int _peekRune() => pattern.codeUnitAt(_offset);

  int _readRune() {
    final first = pattern.codeUnitAt(_offset++);
    if (first < 0xd800 || first > 0xdbff || _offset >= pattern.length) {
      return first;
    }
    final second = pattern.codeUnitAt(_offset);
    if (second < 0xdc00 || second > 0xdfff) {
      return first;
    }
    _offset++;
    return 0x10000 + ((first - 0xd800) << 10) + second - 0xdc00;
  }
}

Set<int>? _union(Set<int>? left, Set<int>? right) {
  if (left == null || right == null) {
    return null;
  }
  left.addAll(right);
  return left.any((character) => character > 0xffff) ? null : left;
}

bool _isAsciiLetterOrDigit(int rune) =>
    (rune >= 0x30 && rune <= 0x39) || (rune >= 0x41 && rune <= 0x5a) || (rune >= 0x61 && rune <= 0x7a);
