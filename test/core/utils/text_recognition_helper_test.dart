import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:nhom_7/core/utils/text_recognition_helper.dart';

void main() {
  group('TextRecognitionHelper.formatPositionedBlocks', () {
    test('orders multi-row and side-by-side blocks in natural reading order without losing lines',
        () {
      final blocks = [
        // Khối dưới cùng
        const PositionedTextBlock(
          boundingBox: Rect.fromLTWH(20, 220, 300, 60),
          lines: [
            PositionedTextLine(
              boundingBox: Rect.fromLTWH(20, 220, 280, 24),
              text: 'Dòng cuối   có   nhiều   khoảng trắng',
            ),
          ],
          fallbackText: '',
        ),
        // Khối hàng 1 bên phải (cột 2)
        const PositionedTextBlock(
          boundingBox: Rect.fromLTWH(260, 20, 180, 50),
          lines: [
            PositionedTextLine(
              boundingBox: Rect.fromLTWH(260, 20, 170, 22),
              text: 'Cột phải hàng 1',
            ),
          ],
          fallbackText: '',
        ),
        // Khối hàng 1 bên trái (cột 1)
        const PositionedTextBlock(
          boundingBox: Rect.fromLTWH(20, 22, 180, 50),
          lines: [
            PositionedTextLine(
              boundingBox: Rect.fromLTWH(20, 48, 170, 22),
              text: 'Dòng 2 cột trái',
            ),
            PositionedTextLine(
              boundingBox: Rect.fromLTWH(20, 22, 170, 22),
              text: 'Dòng 1 cột trái',
            ),
          ],
          fallbackText: '',
        ),
      ];

      final formatted = TextRecognitionHelper.formatPositionedBlocks(blocks);
      expect(
        formatted,
        equals(
          'Dòng 1 cột trái\nDòng 2 cột trái\n\nCột phải hàng 1\n\nDòng cuối có nhiều khoảng trắng',
        ),
      );
    });

    test('returns fallbackText when lines are empty and handles empty blocks', () {
      expect(TextRecognitionHelper.formatPositionedBlocks(const []), isEmpty);

      final formatted = TextRecognitionHelper.formatPositionedBlocks(const [
        PositionedTextBlock(
          boundingBox: Rect.fromLTWH(0, 0, 100, 30),
          lines: [],
          fallbackText: 'Văn bản dự phòng',
        ),
      ]);
      expect(formatted, equals('Văn bản dự phòng'));
    });
  });
}

