import '../../../timetable/domain/entities/subject.dart';

/// Pure Dart helper for resolving subject links, filtering, and searching notes
/// (including Vietnamese accent-insensitive search).
abstract final class NoteFilterHelper {
  /// Sentinel filter ID representing notes without a linked subject ('general').
  static const String generalSubjectFilterId = '__general__';

  static const Map<String, String> _vietnameseCharMap = {
    'à': 'a', 'á': 'a', 'ạ': 'a', 'ả': 'a', 'ã': 'a',
    'â': 'a', 'ầ': 'a', 'ấ': 'a', 'ậ': 'a', 'ẩ': 'a', 'ẫ': 'a',
    'ă': 'a', 'ằ': 'a', 'ắ': 'a', 'ặ': 'a', 'ẳ': 'a', 'ẵ': 'a',
    'è': 'e', 'é': 'e', 'ẹ': 'e', 'ẻ': 'e', 'ẽ': 'e',
    'ê': 'e', 'ề': 'e', 'ế': 'e', 'ệ': 'e', 'ể': 'e', 'ễ': 'e',
    'ì': 'i', 'í': 'i', 'ị': 'i', 'ỉ': 'i', 'ĩ': 'i',
    'ò': 'o', 'ó': 'o', 'ọ': 'o', 'ỏ': 'o', 'õ': 'o',
    'ô': 'o', 'ồ': 'o', 'ố': 'o', 'ộ': 'o', 'ổ': 'o', 'ỗ': 'o',
    'ơ': 'o', 'ờ': 'o', 'ớ': 'o', 'ợ': 'o', 'ở': 'o', 'ỡ': 'o',
    'ù': 'u', 'ú': 'u', 'ụ': 'u', 'ủ': 'u', 'ũ': 'u',
    'ư': 'u', 'ừ': 'u', 'ứ': 'u', 'ự': 'u', 'ử': 'u', 'ữ': 'u',
    'ỳ': 'y', 'ý': 'y', 'ỵ': 'y', 'ỷ': 'y', 'ỹ': 'y',
    'đ': 'd',
  };

  /// Lowercases [input] and strips Vietnamese diacritics.
  static String normalizeVietnamese(String input) {
    final lower = input.toLowerCase();
    final buffer = StringBuffer();
    for (final rune in lower.runes) {
      final ch = String.fromCharCode(rune);
      buffer.write(_vietnameseCharMap[ch] ?? ch);
    }
    return buffer.toString();
  }

  /// Returns true if [input] contains Vietnamese diacritical marks.
  static bool hasVietnameseDiacritics(String input) {
    final lower = input.toLowerCase();
    for (final rune in lower.runes) {
      if (_vietnameseCharMap.containsKey(String.fromCharCode(rune))) {
        return true;
      }
    }
    return false;
  }

  /// Checks whether [text] matches [query].
  /// Supports exact case-insensitive matching, plus accent-insensitive matching
  /// when the user enters a query without Vietnamese diacritics.
  static bool matchesQuery(String text, String query) {
    final cleanQuery = query.trim().toLowerCase();
    if (cleanQuery.isEmpty) return true;

    final cleanText = text.toLowerCase();
    if (cleanText.contains(cleanQuery)) {
      return true;
    }

    if (!hasVietnameseDiacritics(cleanQuery)) {
      return normalizeVietnamese(cleanText)
          .contains(normalizeVietnamese(cleanQuery));
    }

    return false;
  }

  /// Returns true when [subjectId] represents a general/unassigned note.
  static bool isGeneralSubjectId(String subjectId) {
    final trimmed = subjectId.trim();
    return trimmed.isEmpty || trimmed == 'general';
  }

  /// Resolves a note's [subjectId] against [subjectsMap].
  /// Supports both canonical subject UUID/ID keys and legacy notes that stored
  /// subject name or code directly in `subjectId`.
  static Subject? resolveSubject(
    String subjectId,
    Map<String, Subject> subjectsMap,
  ) {
    if (isGeneralSubjectId(subjectId)) return null;

    final direct = subjectsMap[subjectId];
    if (direct != null) return direct;

    final needle = subjectId.trim().toLowerCase();
    for (final s in subjectsMap.values) {
      if (s.name.trim().toLowerCase() == needle ||
          s.code.trim().toLowerCase() == needle) {
        return s;
      }
    }
    return null;
  }
}
