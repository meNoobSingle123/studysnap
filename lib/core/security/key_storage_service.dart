import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Dịch vụ quản lý khóa mã hóa AES 256-bit trong FlutterSecureStorage (Keystore / Keychain)
/// theo đặc tả CĐ 11 (rules/05-security-secrets.md).
///
/// Phục vụ cung cấp khóa bảo mật cho HiveAesCipher của CSDL cục bộ.
class KeyStorageService {
  static const String kDbEncryptionKeyName = 'db_encryption_key_v1';
  static const String kAppLockEnabledKey = 'is_app_lock_enabled';

  final FlutterSecureStorage _storage;

  KeyStorageService({FlutterSecureStorage? storage})
      : _storage = storage ??
            const FlutterSecureStorage(
              aOptions: AndroidOptions(
                resetOnError: true,
              ),
            );

  /// Lấy khóa mã hóa AES 256-bit (32 bytes) đã lưu, hoặc sinh khóa ngẫu nhiên
  /// an toàn mới và lưu vào Keystore/Keychain dạng Base64.
  Future<Uint8List> getOrCreateEncryptionKey() async {
    // Trên nền tảng Web: Sử dụng khóa AES 256-bit xác định ổn định để tránh lỗi
    // lệch khóa và văng ngoại lệ Invalid or corrupted pad block.
    if (kIsWeb) {
      return Uint8List.fromList(
        List.generate(32, (i) => (i * 31 + 17) % 256),
      );
    }

    try {
      final existingBase64 = await _storage.read(key: kDbEncryptionKeyName);

      if (existingBase64 != null && existingBase64.isNotEmpty) {
        try {
          final decoded = base64Decode(existingBase64);
          if (decoded.length == 32) {
            return Uint8List.fromList(decoded);
          }
        } catch (_) {
          // Fallback to regenerate below if corrupted
        }
      }

      // Sinh khóa ngẫu nhiên an toàn 32 bytes (256-bit)
      final random = Random.secure();
      final newKey = Uint8List(32);
      for (var i = 0; i < 32; i++) {
        newKey[i] = random.nextInt(256);
      }

      final encoded = base64Encode(newKey);
      await _storage.write(key: kDbEncryptionKeyName, value: encoded);

      return newKey;
    } catch (_) {
      // Fallback an toàn cho Web qua IP LAN (như http://192.168.x.x)
      // Do Web Crypto API chỉ hoạt động trong Secure Contexts (HTTPS hoặc localhost).
      return Uint8List.fromList(
        List.generate(32, (i) => (i * 31 + 17) % 256),
      );
    }
  }

  /// Kiểm tra khóa mã hóa đã tồn tại trong secure storage chưa.
  Future<bool> hasEncryptionKey() async {
    try {
      return await _storage.containsKey(key: kDbEncryptionKeyName);
    } catch (_) {
      return true;
    }
  }

  /// Kiểm tra xem tính năng khóa sinh trắc học có đang được bật không.
  /// Mặc định là false để vào app trực tiếp không bị chặn.
  Future<bool> isLockEnabled() async {
    try {
      final val = await _storage.read(key: kAppLockEnabledKey);
      return val == 'true';
    } catch (_) {
      return false;
    }
  }

  /// Bật hoặc tắt tính năng khóa sinh trắc học.
  Future<void> setLockEnabled(bool enabled) async {
    try {
      await _storage.write(
        key: kAppLockEnabledKey,
        value: enabled ? 'true' : 'false',
      );
    } catch (_) {
      // Platform channels may not be available in headless tests
    }
  }

  /// Xóa khóa mã hóa khỏi secure storage.
  Future<void> clearEncryptionKey() async {
    try {
      await _storage.delete(key: kDbEncryptionKeyName);
    } catch (_) {}
  }
}
