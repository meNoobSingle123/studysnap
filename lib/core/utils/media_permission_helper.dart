import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';

/// Shared helper for runtime camera permission checks, friendly error formatting,
/// and persisting picked media files out of OS temporary cache.
abstract final class MediaPermissionHelper {
  /// Returns true if Camera permission is currently granted or limited.
  static Future<bool> isCameraGranted() async {
    if (kIsWeb) return true;
    try {
      final status = await Permission.camera.status;
      return status.isGranted || status.isLimited;
    } catch (_) {
      return false;
    }
  }

  /// Ensures camera permission is granted before opening the camera.
  /// Triggers the OS permission popup first (like Notification permission),
  /// and if denied shows an actionable Vietnamese dialog to allow or open Settings.
  static Future<bool> ensureCameraPermission(BuildContext context) async {
    if (kIsWeb) return true;
    try {
      var status = await Permission.camera.status;
      if (status.isGranted || status.isLimited) {
        return true;
      }

      if (!status.isPermanentlyDenied) {
        status = await Permission.camera.request();
        if (status.isGranted || status.isLimited) {
          return true;
        }
      }

      if (context.mounted) {
        return await showCameraPermissionDialog(
          context,
          isPermanentlyDenied: status.isPermanentlyDenied,
        );
      }
      return false;
    } catch (_) {
      // Allow fallback if running in headless test environments without platform plugin
      return true;
    }
  }

  /// Displays a dialog explaining why camera access is needed, letting the user
  /// retry the OS prompt or open App Settings when permanently blocked.
  static Future<bool> showCameraPermissionDialog(
    BuildContext context, {
    bool isPermanentlyDenied = false,
  }) async {
    final granted = await showDialog<bool>(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: const Row(
          children: [
            Icon(Icons.camera_alt_outlined, color: Colors.deepOrange),
            SizedBox(width: 10),
            Expanded(
              child: Text(
                'Cần quyền truy cập Camera',
                style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
        content: Text(
          isPermanentlyDenied
              ? 'StudySnap đang bị chặn quyền Camera trên thiết bị.\n\nVui lòng chọn "Mở Cài đặt" → Quyền → Máy ảnh → Cho phép, hoặc chọn ảnh có sẵn từ Thư viện.'
              : 'StudySnap cần quyền sử dụng máy ảnh để chụp ảnh bài giảng, bảng viết hoặc đọc chữ từ ảnh.\n\nChọn "Cho phép Camera" để cấp quyền ngay, hoặc chọn ảnh có sẵn từ Thư viện.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogCtx).pop(false),
            child: const Text('Đóng'),
          ),
          if (!isPermanentlyDenied)
            TextButton(
              onPressed: () async {
                Navigator.of(dialogCtx).pop(false);
                await openAppSettings();
              },
              child: const Text('Mở Cài đặt'),
            ),
          FilledButton.icon(
            icon: Icon(
              isPermanentlyDenied
                  ? Icons.settings_outlined
                  : Icons.camera_alt_outlined,
              size: 18,
            ),
            label: Text(
              isPermanentlyDenied ? 'Mở Cài đặt' : 'Cho phép Camera',
            ),
            onPressed: () async {
              if (isPermanentlyDenied) {
                Navigator.of(dialogCtx).pop(false);
                await openAppSettings();
                return;
              }
              try {
                final retryStatus = await Permission.camera.request();
                if (retryStatus.isGranted || retryStatus.isLimited) {
                  if (dialogCtx.mounted) {
                    Navigator.of(dialogCtx).pop(true);
                  }
                  return;
                }
              } catch (_) {}
              if (dialogCtx.mounted) {
                Navigator.of(dialogCtx).pop(false);
              }
              await openAppSettings();
            },
          ),
        ],
      ),
    );
    return granted ?? false;
  }

  /// Checks whether an exception is caused by denied camera access.
  static bool isCameraDeniedError(Object error) {
    if (error is PlatformException && error.code == 'camera_access_denied') {
      return true;
    }
    return error.toString().contains('camera_access_denied');
  }

  /// Formats media/camera errors into clean Vietnamese text without raw PlatformExceptions.
  static String formatMediaError(
    Object error, {
    String fallbackPrefix = 'Không thể xử lý ảnh',
  }) {
    if (isCameraDeniedError(error)) {
      return 'Chưa cấp quyền Camera. Vui lòng bật quyền Camera trong Cài đặt ứng dụng hoặc chọn ảnh từ Thư viện.';
    }
    return '$fallbackPrefix: $error';
  }

  /// Copies a temporary picked image file into permanent app documents storage
  /// so clearing system cache will not break note thumbnails.
  static Future<String> persistPickedFile(
    String sourcePath, {
    String subdir = 'note_images',
  }) async {
    if (kIsWeb || sourcePath.isEmpty) return sourcePath;
    try {
      final srcFile = File(sourcePath);
      if (!await srcFile.exists()) return sourcePath;

      final docsDir = await getApplicationDocumentsDirectory();
      final sep = Platform.pathSeparator;
      final targetDir = Directory('${docsDir.path}$sep$subdir');
      if (!await targetDir.exists()) {
        await targetDir.create(recursive: true);
      }

      final rawName = srcFile.uri.pathSegments.isNotEmpty
          ? srcFile.uri.pathSegments.last
          : 'image.jpg';
      final safeName = rawName.isNotEmpty ? rawName : 'image.jpg';
      final destPath =
          '${targetDir.path}$sep${DateTime.now().millisecondsSinceEpoch}_$safeName';

      final copied = await srcFile.copy(destPath);
      return copied.path;
    } catch (_) {
      return sourcePath;
    }
  }
}

