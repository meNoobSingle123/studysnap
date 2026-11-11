import '../entities/subject.dart';
import '../entities/timetable_slot.dart';

/// Kết quả phân tích dữ liệu JSON đồng bộ từ máy chủ API thành thực thể Domain.
class ParsedTimetableSyncData {
  final String termId;
  final List<Subject> subjects;
  final List<TimetableSlot> slots;

  const ParsedTimetableSyncData({
    required this.termId,
    required this.subjects,
    required this.slots,
  });
}

/// Bộ chuyển đổi an toàn JSON đồng bộ thời khóa biểu sang [Subject] & [TimetableSlot].
///
/// Hỗ trợ linh hoạt cả định dạng chuẩn StudySnap (`startMin`/`endMin`, ISO `termStart`/`termEnd`)
/// lẫn định dạng JSON phổ biến khác (`startTime: "07:30"`, màu `#RRGGBB`, thiếu `termStart`/`termEnd`).
class TimetableSyncParser {
  const TimetableSyncParser._();

  static ParsedTimetableSyncData parse(
    Map<String, dynamic> data, {
    DateTime? nowOverride,
  }) {
    final now = nowOverride ?? DateTime.now();
    final termId = data['termId']?.toString().trim().isNotEmpty == true
        ? data['termId'].toString().trim()
        : '2026-1';

    final rootTermStart =
        _parseDate(data['termStart'] ?? data['startDate']) ??
            now.subtract(const Duration(days: 30));
    final rootTermEnd = _parseDate(data['termEnd'] ?? data['endDate']) ??
        now.add(const Duration(days: 120));

    final subjectsRaw = data['subjects'] as List<dynamic>? ?? const [];
    final subjects = <Subject>[];
    for (var i = 0; i < subjectsRaw.length; i++) {
      final raw = subjectsRaw[i];
      if (raw is! Map) continue;
      final m = Map<String, dynamic>.from(raw);
      final name = (m['name'] ?? m['subjectName'] ?? '').toString().trim();
      final id = (m['id'] ?? 'sync_subj_$i').toString().trim();
      if (id.isEmpty || name.isEmpty) continue;

      subjects.add(
        Subject(
          id: id,
          code: (m['code'] ?? '').toString().trim(),
          name: name,
          credits: _parseInt(m['credits']) ?? 3,
          colorArgb: _parseColor(m['colorArgb'] ?? m['color']) ?? 0xFF1976D2,
          gradePoint: _parseDouble(m['gradePoint']),
          createdAt: now,
          updatedAt: now,
        ),
      );
    }

    final slotsRaw = data['slots'] as List<dynamic>? ?? const [];
    final slots = <TimetableSlot>[];
    for (var i = 0; i < slotsRaw.length; i++) {
      final raw = slotsRaw[i];
      if (raw is! Map) continue;
      final m = Map<String, dynamic>.from(raw);
      final id = (m['id'] ?? 'sync_slot_$i').toString().trim();
      final subjectId = (m['subjectId'] ?? '').toString().trim();
      if (id.isEmpty || subjectId.isEmpty) continue;

      final rawDay = _parseInt(m['dayOfWeek']) ?? 1;
      final normalizedDay = rawDay == 0 ? 7 : rawDay.clamp(1, 7);

      final startMin = _parseMinutes(m['startMin'] ?? m['startTime']) ?? 420;
      var endMin =
          _parseMinutes(m['endMin'] ?? m['endTime']) ?? (startMin + 90);
      if (endMin <= startMin) {
        endMin = (startMin + 60).clamp(1, 23 * 60 + 59);
      }

      final slotStart = _parseDate(m['termStart']) ?? rootTermStart;
      var slotEnd = _parseDate(m['termEnd']) ?? rootTermEnd;
      if (slotEnd.isBefore(slotStart)) {
        slotEnd = slotStart;
      }

      slots.add(
        TimetableSlot(
          id: id,
          subjectId: subjectId,
          dayOfWeek: normalizedDay,
          startMin: startMin,
          endMin: endMin,
          room: (m['room'] ?? '').toString().trim(),
          buildingId: m['buildingId']?.toString().trim().isNotEmpty == true
              ? m['buildingId'].toString().trim()
              : null,
          termStart: slotStart,
          termEnd: slotEnd,
          source: 'system',
          updatedAt: now,
        ),
      );
    }

    return ParsedTimetableSyncData(
      termId: termId,
      subjects: subjects,
      slots: slots,
    );
  }

  static int? _parseInt(dynamic val) {
    if (val is int) return val;
    if (val is num) return val.toInt();
    if (val is String) return int.tryParse(val.trim());
    return null;
  }

  static double? _parseDouble(dynamic val) {
    if (val is double) return val;
    if (val is num) return val.toDouble();
    if (val is String) return double.tryParse(val.replaceAll(',', '.').trim());
    return null;
  }

  static int? _parseColor(dynamic val) {
    if (val is int) return val;
    if (val is num) return val.toInt();
    if (val is String) {
      var s = val.trim().toUpperCase();
      if (s.startsWith('#')) {
        s = s.substring(1);
        if (s.length == 6) s = 'FF$s';
        return int.tryParse(s, radix: 16);
      }
      if (s.startsWith('0X')) {
        return int.tryParse(s.substring(2), radix: 16);
      }
      return int.tryParse(s);
    }
    return null;
  }

  static int? _parseMinutes(dynamic val) {
    if (val is num) return val.toInt().clamp(0, 23 * 60 + 59);
    if (val is String) {
      final trimmed = val.trim();
      final asInt = int.tryParse(trimmed);
      if (asInt != null) return asInt.clamp(0, 23 * 60 + 59);
      final match = RegExp(r'^(\d{1,2}):(\d{1,2})').firstMatch(trimmed);
      if (match != null) {
        final h = int.tryParse(match.group(1) ?? '');
        final m = int.tryParse(match.group(2) ?? '');
        if (h != null && m != null && h >= 0 && h <= 23 && m >= 0 && m <= 59) {
          return h * 60 + m;
        }
      }
    }
    return null;
  }

  static DateTime? _parseDate(dynamic val) {
    if (val == null) return null;
    final parsed = DateTime.tryParse(val.toString().trim());
    if (parsed == null) return null;
    final local = parsed.isUtc ? parsed.toLocal() : parsed;
    return DateTime(local.year, local.month, local.day);
  }
}

