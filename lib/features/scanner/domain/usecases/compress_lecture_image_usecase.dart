import 'dart:io';

import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:path_provider/path_provider.dart';

/// Usecase to compress captured lecture photos to max 1280px and quality 75% according to SRS spec.
class CompressLectureImageUseCase {
  const CompressLectureImageUseCase();

  Future<File> call(
    File sourceFile, {
    int minWidth = 1280,
    int minHeight = 1280,
    int quality = 75,
  }) async {
    try {
      final tempDir = await getTemporaryDirectory();
      final targetPath =
          '${tempDir.path}/compressed_${DateTime.now().microsecondsSinceEpoch}.jpg';

      final compressedXFile = await FlutterImageCompress.compressAndGetFile(
        sourceFile.path,
        targetPath,
        minWidth: minWidth,
        minHeight: minHeight,
        quality: quality,
      );

      if (compressedXFile != null) {
        return File(compressedXFile.path);
      }
      return sourceFile;
    } catch (_) {
      // Graceful fallback to original file in test or fallback environments
      return sourceFile;
    }
  }
}
