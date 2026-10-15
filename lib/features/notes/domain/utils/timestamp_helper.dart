import 'package:equatable/equatable.dart';

/// Pure domain representation of a video timestamp extracted from lecture notes.
class TimestampEntry extends Equatable {
  /// The raw string tag, e.g. `[03:45]` or `[01:15:30]`.
  final String tag;

  /// Parsed duration corresponding to this timestamp.
  final Duration duration;

  /// Index in the text where this tag starts.
  final int startIndex;

  /// Index in the text where this tag ends.
  final int endIndex;

  const TimestampEntry({
    required this.tag,
    required this.duration,
    required this.startIndex,
    required this.endIndex,
  });

  @override
  List<Object?> get props => [tag, duration, startIndex, endIndex];
}

/// Utility for formatting, parsing, and extracting `[mm:ss]` and `[hh:mm:ss]`
/// timestamps from lecture note bodies (Spec 6.3 & FR-16).
class TimestampHelper {
  /// Matches `[mm:ss]` or `[hh:mm:ss]`.
  static final RegExp timestampRegex = RegExp(
    r'\[(?:(\d{1,2}):)?(\d{1,2}):(\d{2})\]',
  );

  /// Flexible regex for parsing strings with or without enclosing brackets.
  static final RegExp _parseRegex = RegExp(
    r'^\[?(?:(\d{1,2}):)?(\d{1,2}):(\d{2})\]?$',
  );

  /// Formats a [Duration] into `[mm:ss]` (or `[hh:mm:ss]` if > 99 minutes or >= 1 hour).
  static String format(Duration duration) {
    final clamped = duration.isNegative ? Duration.zero : duration;
    final totalSeconds = clamped.inSeconds;
    final totalMinutes = totalSeconds ~/ 60;
    final seconds = totalSeconds % 60;

    if (totalMinutes > 99 || clamped.inHours > 0) {
      final hours = clamped.inHours.toString().padLeft(2, '0');
      final minutes = (totalMinutes % 60).toString().padLeft(2, '0');
      final secs = seconds.toString().padLeft(2, '0');
      return '[$hours:$minutes:$secs]';
    } else {
      final minutes = totalMinutes.toString().padLeft(2, '0');
      final secs = seconds.toString().padLeft(2, '0');
      return '[$minutes:$secs]';
    }
  }

  /// Parses a string like `[03:45]`, `03:45`, `[01:15:30]` into a [Duration].
  /// Returns `null` if the format is invalid.
  static Duration? parse(String raw) {
    final trimmed = raw.trim();
    final match = _parseRegex.firstMatch(trimmed);
    if (match == null) return null;

    final hourPart = match.group(1);
    final minutePart = match.group(2);
    final secondPart = match.group(3);

    if (minutePart == null || secondPart == null) return null;

    final minutes = int.tryParse(minutePart) ?? 0;
    final seconds = int.tryParse(secondPart) ?? 0;
    final hours = hourPart != null ? (int.tryParse(hourPart) ?? 0) : 0;

    return Duration(hours: hours, minutes: minutes, seconds: seconds);
  }

  /// Extracts all timestamp occurrences in [text] in order of appearance.
  static List<TimestampEntry> extractAll(String text) {
    if (text.isEmpty) return const [];
    final entries = <TimestampEntry>[];

    for (final match in timestampRegex.allMatches(text)) {
      final rawTag = match.group(0)!;
      final duration = parse(rawTag);
      if (duration != null) {
        entries.add(
          TimestampEntry(
            tag: rawTag,
            duration: duration,
            startIndex: match.start,
            endIndex: match.end,
          ),
        );
      }
    }

    return entries;
  }

  /// Extracts unique timestamps sorted in ascending order of duration.
  /// Ideal for rendering the quick-seek chip bar under the video player.
  static List<TimestampEntry> extractUniqueSorted(String text) {
    final all = extractAll(text);
    if (all.isEmpty) return const [];

    final seenDurations = <int, TimestampEntry>{};
    for (final entry in all) {
      final sec = entry.duration.inSeconds;
      if (!seenDurations.containsKey(sec)) {
        seenDurations[sec] = entry;
      }
    }

    final sorted = seenDurations.values.toList()
      ..sort((a, b) => a.duration.compareTo(b.duration));
    return sorted;
  }
}
