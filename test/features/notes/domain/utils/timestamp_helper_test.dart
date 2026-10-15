import 'package:flutter_test/flutter_test.dart';
import 'package:nhom_7/features/notes/domain/utils/timestamp_helper.dart';

void main() {
  group('TimestampHelper.format', () {
    test('formats seconds and minutes correctly for under 60 minutes', () {
      expect(TimestampHelper.format(Duration.zero), '[00:00]');
      expect(TimestampHelper.format(const Duration(seconds: 45)), '[00:45]');
      expect(
        TimestampHelper.format(const Duration(minutes: 3, seconds: 15)),
        '[03:15]',
      );
      expect(
        TimestampHelper.format(const Duration(minutes: 59, seconds: 59)),
        '[59:59]',
      );
    });

    test('formats hours correctly when duration has hours or > 99 minutes', () {
      expect(
        TimestampHelper.format(const Duration(hours: 1, minutes: 2, seconds: 3)),
        '[01:02:03]',
      );
      expect(
        TimestampHelper.format(const Duration(minutes: 105, seconds: 20)),
        '[01:45:20]',
      );
    });

    test('clamps negative duration to zero', () {
      expect(TimestampHelper.format(const Duration(seconds: -10)), '[00:00]');
    });
  });

  group('TimestampHelper.parse', () {
    test('parses [mm:ss] format', () {
      final d = TimestampHelper.parse('[04:20]');
      expect(d, const Duration(minutes: 4, seconds: 20));
    });

    test('parses [hh:mm:ss] format', () {
      final d = TimestampHelper.parse('[01:15:30]');
      expect(d, const Duration(hours: 1, minutes: 15, seconds: 30));
    });

    test('parses without square brackets', () {
      final d = TimestampHelper.parse('02:45');
      expect(d, const Duration(minutes: 2, seconds: 45));
    });

    test('returns null on invalid timestamp formats', () {
      expect(TimestampHelper.parse('invalid'), isNull);
      expect(TimestampHelper.parse('[abc]'), isNull);
      expect(TimestampHelper.parse('123'), isNull);
    });
  });

  group('TimestampHelper.extractAll and extractUniqueSorted', () {
    test('extracts all occurrences in order', () {
      const text =
          'Khái niệm bắt đầu ở [01:30], sau đó xem ví dụ tại [05:45] và tóm tắt lại ở [01:30].';
      final list = TimestampHelper.extractAll(text);
      expect(list.length, 3);
      expect(list[0].tag, '[01:30]');
      expect(list[0].duration, const Duration(minutes: 1, seconds: 30));
      expect(list[1].tag, '[05:45]');
      expect(list[2].tag, '[01:30]');
    });

    test('extractUniqueSorted returns deduplicated list sorted by duration', () {
      const text =
          'Thảo luận [10:00], mở đầu [00:15], ví dụ [02:30], lại nói về [00:15].';
      final unique = TimestampHelper.extractUniqueSorted(text);
      expect(unique.length, 3);
      expect(unique[0].tag, '[00:15]');
      expect(unique[0].duration, const Duration(seconds: 15));
      expect(unique[1].tag, '[02:30]');
      expect(unique[1].duration, const Duration(minutes: 2, seconds: 30));
      expect(unique[2].tag, '[10:00]');
      expect(unique[2].duration, const Duration(minutes: 10));
    });

    test('returns empty list for text without timestamps', () {
      expect(TimestampHelper.extractAll(''), isEmpty);
      expect(TimestampHelper.extractUniqueSorted('Ghi chú bài giảng thường ngày'), isEmpty);
    });
  });
}
