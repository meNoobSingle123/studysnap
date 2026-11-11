import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';

import '../../features/ai_assistant/data/datasources/gemini_remote_datasource.dart';
import '../di/injection.dart';

/// Kết quả đọc chữ từ ảnh kèm thời gian xử lý và nguồn nhận diện.
class TextRecognitionResult {
  final String text;
  final int elapsedMs;
  final bool usedAiVision;

  const TextRecognitionResult({
    required this.text,
    required this.elapsedMs,
    this.usedAiVision = false,
  });
}

/// Một khối chữ có tọa độ để sắp xếp đúng thứ tự đọc (trên xuống dưới, trái qua phải).
class PositionedTextBlock {
  final Rect boundingBox;
  final List<PositionedTextLine> lines;
  final String fallbackText;

  const PositionedTextBlock({
    required this.boundingBox,
    required this.lines,
    required this.fallbackText,
  });
}

class PositionedTextLine {
  final Rect boundingBox;
  final String text;

  const PositionedTextLine({
    required this.boundingBox,
    required this.text,
  });
}

/// Bộ đọc chữ từ ảnh dùng chung cho cả màn hình Đọc chữ và Trợ lý Học tập AI:
/// - Nếu có mạng và API Key Gemini hợp lệ: ưu tiên Gemini Vision để đọc chuẩn cả chữ viết tay và dấu tiếng Việt.
/// - Mọi trường hợp ngoại tuyến / lỗi mạng / chưa cấu hình key: tự động dùng ML Kit ngoại tuyến kèm thuật toán sắp xếp khối chữ không bỏ sót dòng.
class TextRecognitionHelper {
  const TextRecognitionHelper._();

  static Future<TextRecognitionResult> extractFromImagePath(
    String imagePath, {
    bool preferAiVision = true,
  }) async {
    final sw = Stopwatch()..start();

    if (preferAiVision && getIt.isRegistered<GeminiRemoteDataSource>()) {
      final aiText = await _tryGeminiVisionExtract(imagePath);
      if (aiText != null && aiText.trim().isNotEmpty) {
        sw.stop();
        return TextRecognitionResult(
          text: aiText.trim(),
          elapsedMs: sw.elapsedMilliseconds,
          usedAiVision: true,
        );
      }
    }

    final recognizer = TextRecognizer(script: TextRecognitionScript.latin);
    try {
      final recognized =
          await recognizer.processImage(InputImage.fromFilePath(imagePath));
      final structured = formatRecognizedText(recognized);
      sw.stop();
      return TextRecognitionResult(
        text: structured,
        elapsedMs: sw.elapsedMilliseconds,
        usedAiVision: false,
      );
    } finally {
      await recognizer.close();
    }
  }

  static Future<String?> _tryGeminiVisionExtract(String imagePath) async {
    try {
      final gemini = getIt<GeminiRemoteDataSource>();
      if (!(await gemini.hasApiKey())) return null;

      final connectivity = await Connectivity().checkConnectivity();
      final isOnline =
          connectivity.any((r) => r != ConnectivityResult.none);
      if (!isOnline) return null;

      final file = File(imagePath);
      if (!await file.exists()) return null;

      Uint8List bytes = await file.readAsBytes();
      String mimeType = imagePath.toLowerCase().endsWith('.png')
          ? 'image/png'
          : 'image/jpeg';

      // Chỉ nén nhẹ nếu ảnh quá lớn (> 2.5MB) để gửi nhanh mà vẫn giữ nét chữ & dấu tiếng Việt
      if (bytes.lengthInBytes > 2500000) {
        final compressed = await FlutterImageCompress.compressWithList(
          bytes,
          minWidth: 2400,
          minHeight: 2400,
          quality: 90,
          format: CompressFormat.jpeg,
        );
        if (compressed.isNotEmpty) {
          bytes = compressed;
          mimeType = 'image/jpeg';
        }
      }

      return await gemini.extractTextFromImage(
        imageBytes: bytes,
        mimeType: mimeType,
      );
    } catch (_) {
      return null;
    }
  }

  /// Ghép văn bản từ kết quả ML Kit theo đúng thứ tự đọc tự nhiên (không sót dòng/khối).
  static String formatRecognizedText(RecognizedText recognized) {
    if (recognized.blocks.isEmpty) {
      return recognized.text.trim();
    }

    final positioned = recognized.blocks.map((block) {
      final lines = block.lines
          .map((line) {
            final cleanLine = line.elements.isNotEmpty
                ? line.elements
                    .map((e) => e.text.trim())
                    .where((t) => t.isNotEmpty)
                    .join(' ')
                : line.text.replaceAll(RegExp(r'[ \t]+'), ' ').trim();
            return PositionedTextLine(
              boundingBox: line.boundingBox,
              text: cleanLine,
            );
          })
          .where((l) => l.text.isNotEmpty)
          .toList();

      return PositionedTextBlock(
        boundingBox: block.boundingBox,
        lines: lines,
        fallbackText: block.text.trim(),
      );
    }).toList();

    final formatted = formatPositionedBlocks(positioned);
    return formatted.isNotEmpty ? formatted : recognized.text.trim();
  }

  /// Thuật toán sắp xếp các khối chữ theo hàng ngang (left -> right) rồi từ trên xuống dưới.
  static String formatPositionedBlocks(List<PositionedTextBlock> blocks) {
    final validBlocks = blocks
        .where((b) => b.lines.isNotEmpty || b.fallbackText.isNotEmpty)
        .toList();
    if (validBlocks.isEmpty) return '';

    final sortedBlocks = List<PositionedTextBlock>.from(validBlocks)
      ..sort((a, b) {
        final aBox = a.boundingBox;
        final bBox = b.boundingBox;
        final minHeight = math.min(
          math.max(aBox.height, 1.0),
          math.max(bBox.height, 1.0),
        );
        final overlapY = math.min(aBox.bottom, bBox.bottom) -
            math.max(aBox.top, bBox.top);

        // Nếu 2 khối nằm cùng hàng ngang đáng kể (>= 45% chiều cao khối nhỏ hơn), đọc trái qua phải
        if (overlapY > minHeight * 0.45) {
          return aBox.left.compareTo(bBox.left);
        }
        return aBox.top.compareTo(bBox.top);
      });

    final blockStrings = <String>[];
    for (final block in sortedBlocks) {
      if (block.lines.isEmpty) {
        if (block.fallbackText.isNotEmpty) {
          blockStrings.add(block.fallbackText);
        }
        continue;
      }

      final sortedLines = List<PositionedTextLine>.from(block.lines)
        ..sort((a, b) {
          final dy = (a.boundingBox.top - b.boundingBox.top).abs();
          final lineH = math.max(
            math.min(a.boundingBox.height, b.boundingBox.height),
            1.0,
          );
          if (dy <= lineH * 0.4) {
            return a.boundingBox.left.compareTo(b.boundingBox.left);
          }
          return a.boundingBox.top.compareTo(b.boundingBox.top);
        });

      final lineTexts = sortedLines
          .map((l) => l.text.replaceAll(RegExp(r'\s+'), ' ').trim())
          .where((t) => t.isNotEmpty)
          .toList();
      if (lineTexts.isNotEmpty) {
        blockStrings.add(lineTexts.join('\n'));
      }
    }

    return blockStrings.join('\n\n').trim();
  }
}

