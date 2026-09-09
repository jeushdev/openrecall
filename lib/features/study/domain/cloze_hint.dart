import 'package:characters/characters.dart';
import 'package:flutter/foundation.dart';

/// Grapheme-safe progressive reveal state for one Cloze answer.
@immutable
class ClozeHint {
  ClozeHint._({
    required this.answer,
    required this.revealedCount,
    required this.isActivated,
  }) : _graphemes = answer.characters.toList(growable: false);

  factory ClozeHint.initial(String answer) =>
      ClozeHint._(answer: answer, revealedCount: 0, isActivated: false);

  final String answer;

  /// Number of non-separator graphemes currently visible.
  final int revealedCount;

  /// Becomes true on the first effective press. This makes punctuation-only
  /// answers revealable once even though they contain no counted graphemes.
  final bool isActivated;

  final List<String> _graphemes;

  int get revealableCount =>
      _graphemes.where((grapheme) => !_isSeparator(grapheme)).length;

  bool get canReveal => !isActivated || revealedCount < revealableCount;

  /// The preview is intentionally absent until the first hint is requested.
  String? get maskedAnswer {
    if (!isActivated) return null;
    var seen = 0;
    final buffer = StringBuffer();
    for (final grapheme in _graphemes) {
      if (_isSeparator(grapheme)) {
        buffer.write(grapheme);
      } else {
        seen++;
        buffer.write(seen <= revealedCount ? grapheme : '•');
      }
    }
    return buffer.toString();
  }

  ClozeHint revealNext() {
    if (!canReveal) return this;
    return ClozeHint._(
      answer: answer,
      revealedCount: revealableCount == 0
          ? 0
          : (revealedCount + 1).clamp(0, revealableCount),
      isActivated: true,
    );
  }
}

bool _isSeparator(String grapheme) {
  for (final rune in grapheme.runes) {
    if (!_isWhitespace(rune) && !_isPunctuation(rune)) return false;
  }
  return true;
}

bool _isWhitespace(int rune) => String.fromCharCode(rune).trim().isEmpty;

// Unicode punctuation blocks plus the punctuation members of ASCII and
// Latin-1. Currency/math/modifier symbols deliberately remain revealable.
bool _isPunctuation(int rune) =>
    (rune >= 0x21 && rune <= 0x23) ||
    (rune >= 0x25 && rune <= 0x2F && rune != 0x2B) ||
    (rune >= 0x3A && rune <= 0x3B) ||
    rune == 0x3F ||
    rune == 0x40 ||
    (rune >= 0x5B && rune <= 0x5D) ||
    rune == 0x5F ||
    (rune >= 0x7B && rune <= 0x7D) ||
    rune == 0xA1 ||
    rune == 0xA7 ||
    rune == 0xAB ||
    rune == 0xB6 ||
    rune == 0xB7 ||
    rune == 0xBB ||
    rune == 0xBF ||
    (rune >= 0x2000 && rune <= 0x206F) ||
    (rune >= 0x2E00 && rune <= 0x2E7F) ||
    (rune >= 0x3000 && rune <= 0x303F) ||
    (rune >= 0xFE10 && rune <= 0xFE1F) ||
    (rune >= 0xFE30 && rune <= 0xFE4F) ||
    (rune >= 0xFF01 && rune <= 0xFF03) ||
    (rune >= 0xFF05 && rune <= 0xFF0F && rune != 0xFF0B) ||
    (rune >= 0xFF1A && rune <= 0xFF1B) ||
    rune == 0xFF1F ||
    rune == 0xFF20 ||
    (rune >= 0xFF3B && rune <= 0xFF3D) ||
    rune == 0xFF3F ||
    (rune >= 0xFF5B && rune <= 0xFF5D);
