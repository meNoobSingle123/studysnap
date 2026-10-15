import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nhom_7/features/notes/domain/entities/stroke.dart';
import 'package:nhom_7/features/notes/presentation/utils/canvas_image_exporter.dart';

void main() {
  group('CanvasImageExporter.computeConstrainedDimensions', () {
    test('keeps dimensions below maxLongEdge intact', () {
      const original = Size(1920, 1080);
      final result = CanvasImageExporter.computeConstrainedDimensions(original);
      expect(result.width, 1920.0);
      expect(result.height, 1080.0);
    });

    test('downscales landscape image with edge > 4096 keeping aspect ratio', () {
      const hugeLandscape = Size(8000, 4000); // 2:1 ratio
      final result = CanvasImageExporter.computeConstrainedDimensions(
        hugeLandscape,
        maxLongEdge: 4096.0,
      );
      expect(result.width, 4096.0);
      expect(result.height, 2048.0);
    });

    test('downscales portrait image with edge > 4096 keeping aspect ratio', () {
      const hugePortrait = Size(3000, 6000); // 1:2 ratio
      final result = CanvasImageExporter.computeConstrainedDimensions(
        hugePortrait,
        maxLongEdge: 4096.0,
      );
      expect(result.height, 4096.0);
      expect(result.width, 2048.0);
    });

    test('falls back to default 1080x1920 on zero or negative size', () {
      const zero = Size(0, 0);
      final result = CanvasImageExporter.computeConstrainedDimensions(zero);
      expect(result.width, 1080.0);
      expect(result.height, 1920.0);
    });
  });

  group('CanvasImageExporter.exportToBytes', () {
    testWidgets('exports valid PNG bytes from empty stroke list', (tester) async {
      Uint8List? bytes;
      await tester.runAsync(() async {
        bytes = await CanvasImageExporter.exportToBytes(
          strokes: [],
          targetSize: const Size(200, 200),
        );
      });

      expect(bytes, isNotNull);
      expect(bytes!.length, greaterThan(0));

      // Validate PNG magic bytes: 0x89, 0x50, 0x4E, 0x47 (PNG)
      expect(bytes![0], 0x89);
      expect(bytes![1], 0x50);
      expect(bytes![2], 0x4E);
      expect(bytes![3], 0x47);
    });

    testWidgets('exports valid PNG with pen, highlighter, and eraser strokes', (tester) async {
      final strokes = [
        Stroke(
          id: 'pen-1',
          tool: StrokeTool.pen,
          colorValue: 0xFF000000,
          widthNorm: 0.01,
          points: const [0.1, 0.1, 0.5, 0.5],
          createdAt: DateTime.now(),
        ),
        Stroke(
          id: 'hl-1',
          tool: StrokeTool.highlighter,
          colorValue: 0xFFFFEB3B,
          widthNorm: 0.03,
          points: const [0.2, 0.2, 0.8, 0.2],
          createdAt: DateTime.now(),
        ),
        Stroke(
          id: 'erase-1',
          tool: StrokeTool.eraser,
          colorValue: 0xFFFFFFFF,
          widthNorm: 0.02,
          points: const [0.3, 0.3, 0.3, 0.6],
          createdAt: DateTime.now(),
        ),
      ];

      Uint8List? bytes;
      await tester.runAsync(() async {
        bytes = await CanvasImageExporter.exportToBytes(
          strokes: strokes,
          targetSize: const Size(300, 300),
        );
      });

      expect(bytes, isNotNull);
      expect(bytes!.length, greaterThan(0));
      expect(bytes![0], 0x89);
      expect(bytes![1], 0x50);
      expect(bytes![2], 0x4E);
      expect(bytes![3], 0x47);
    });
  });
}
