import 'package:flutter_test/flutter_test.dart';
import 'package:nhom_7/features/timetable/domain/utils/timetable_sync_parser.dart';

void main() {
  group('TimetableSyncParser', () {
    test('parses backend payload with ISO dates and numeric times', () {
      final now = DateTime(2026, 11, 11, 12, 0);
      final payload = {
        'termId': '2026-1',
        'subjects': [
          {
            'id': 'sub_1',
            'code': 'CSC10006',
            'name': 'Mạng máy tính cơ bản',
            'credits': 4,
            'colorArgb': 4280391410,
          },
        ],
        'slots': [
          {
            'id': 'slot_mon_1',
            'subjectId': 'sub_1',
            'dayOfWeek': 1,
            'startMin': 450,
            'endMin': 540,
            'room': 'H2.304',
            'buildingId': 'H2',
            'termStart': '2026-09-01T00:00:00.000Z',
            'termEnd': '2026-12-31T23:59:59.000Z',
          },
        ],
      };

      final parsed = TimetableSyncParser.parse(payload, nowOverride: now);
      expect(parsed.termId, '2026-1');
      expect(parsed.subjects.length, 1);
      expect(parsed.subjects.first.name, 'Mạng máy tính cơ bản');
      expect(parsed.slots.length, 1);

      final slot = parsed.slots.first;
      expect(slot.dayOfWeek, 1);
      expect(slot.startMin, 450);
      expect(slot.endMin, 540);
      expect(slot.source, 'system');
      expect(slot.termStart.isBefore(now), isTrue);
      expect(slot.termEnd.isAfter(now), isTrue);
    });

    test(
        'parses flexible HH:mm strings, #hex colors, Sunday=0, and omitted term dates across current semester',
        () {
      final now = DateTime(2026, 11, 11, 12, 0);
      final payload = {
        'subjects': [
          {
            'id': 101,
            'name': 'Toán rời rạc',
            'color': '#FF5722',
          },
        ],
        'slots': [
          {
            'id': 'ext_1',
            'subjectId': 101,
            'dayOfWeek': 0, // Chủ nhật
            'startTime': '13:30',
            'endTime': '16:00',
            'room': 'C.305',
          },
        ],
      };

      final parsed = TimetableSyncParser.parse(payload, nowOverride: now);
      expect(parsed.subjects.single.id, '101');
      expect(parsed.subjects.single.colorArgb, 0xFFFF5722);

      final slot = parsed.slots.single;
      expect(slot.dayOfWeek, 7);
      expect(slot.startMin, 810); // 13:30
      expect(slot.endMin, 960); // 16:00

      // Không có termStart/termEnd vẫn hiển thị cho cả tuần trước & sau trong học kỳ
      final thisMonday = DateTime(2026, 11, 9);
      final nextSunday = DateTime(2026, 11, 22);
      expect(slot.termStart.isAfter(thisMonday), isFalse);
      expect(slot.termEnd.isBefore(nextSunday), isFalse);
    });
  });
}

