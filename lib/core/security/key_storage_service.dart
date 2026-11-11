import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Dịch vụ quản lý khóa mã hóa AES 256-bit trong FlutterSecureStorage (Keystore / Keychain)
/// theo đặc tả CĐ 11 (rules/05-security-secrets.md).
///
/// Phục vụ cung cấp khóa bảo mật cho HiveAesCipher của CSDL cục bộ.
class KeyStorageService {
  static const String kDbEncryptionKeyName = 'db_encryption_key_v1';
  static const String kAppLockEnabledKey = 'is_app_lock_enabled';
  static const String kGeminiApiKeyName = 'gemini_api_key_v1';
  static const String kOnboardingCompletedKey = 'is_onboarding_completed_v1';
  static const String kAppLockPinKey = 'app_lock_pin_v1';
  static const String kFailedPinAttemptsKey = 'failed_pin_attempts_v1';
  static const String kPinLockoutUntilKey = 'pin_lockout_until_v1';
  static const String kReminderLeadMinutesKey = 'reminder_lead_minutes_v1';
  static const String kReminderEnabledKey = 'reminder_enabled_v1';
  static const String kSchoolApiUrlKey = 'school_api_url_v1';
  static const String kDefaultSchoolApiUrl =
      String.fromEnvironment('SCHOOL_API_URL', defaultValue: '');

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
  }

  /// Kiểm tra khóa mã hóa đã tồn tại trong secure storage chưa.
  Future<bool> hasEncryptionKey() async {
    return _storage.containsKey(key: kDbEncryptionKeyName);
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

  static const String kDefaultApiKey =
      String.fromEnvironment('GEMINI_API_KEY', defaultValue: '');

  /// Lấy khóa AI API Key đã lưu hoặc sử dụng khóa mặc định được cấu hình an toàn qua env.json / dart-define.
  Future<String?> getGeminiApiKey() async {
    try {
      final savedKey = await _storage.read(key: kGeminiApiKeyName);
      if (savedKey != null && savedKey.trim().isNotEmpty) {
        return savedKey.trim();
      }
      return kDefaultApiKey.isNotEmpty ? kDefaultApiKey : null;
    } catch (_) {
      return kDefaultApiKey.isNotEmpty ? kDefaultApiKey : null;
    }
  }

  /// Lưu khóa Gemini API Key vào secure storage.
  Future<void> saveGeminiApiKey(String apiKey) async {
    try {
      await _storage.write(key: kGeminiApiKeyName, value: apiKey.trim());
    } catch (_) {}
  }

  /// Xóa khóa Gemini API Key.
  Future<void> clearGeminiApiKey() async {
    try {
      await _storage.delete(key: kGeminiApiKeyName);
    } catch (_) {}
  }

  /// Kiểm tra xem người dùng đã hoàn thành màn hình chào mừng/giới thiệu chưa.
  Future<bool> isOnboardingCompleted() async {
    try {
      final val = await _storage.read(key: kOnboardingCompletedKey);
      return val == 'true';
    } catch (_) {
      return false;
    }
  }

  /// Đánh dấu đã xem xong màn hình chào mừng/giới thiệu.
  Future<void> setOnboardingCompleted(bool completed) async {
    try {
      await _storage.write(
        key: kOnboardingCompletedKey,
        value: completed ? 'true' : 'false',
      );
    } catch (_) {}
  }

  /// Xóa khóa mã hóa khỏi secure storage.
  Future<void> clearEncryptionKey() async {
    await _storage.delete(key: kDbEncryptionKeyName);
  }

  /// Lấy mã PIN đã cài đặt (nếu có).
  Future<String?> getPin() async {
    try {
      return await _storage.read(key: kAppLockPinKey);
    } catch (_) {
      return null;
    }
  }

  /// Cài đặt mã PIN mới.
  Future<void> setPin(String pin) async {
    try {
      await _storage.write(key: kAppLockPinKey, value: pin.trim());
    } catch (_) {}
  }

  /// Kiểm tra xem người dùng đã thiết lập mã PIN chưa.
  Future<bool> hasPin() async {
    try {
      final pin = await _storage.read(key: kAppLockPinKey);
      return pin != null && pin.trim().isNotEmpty;
    } catch (_) {
      return false;
    }
  }

  /// Xóa mã PIN.
  Future<void> clearPin() async {
    try {
      await _storage.delete(key: kAppLockPinKey);
    } catch (_) {}
  }

  /// Lấy số lần nhập sai PIN hiện tại.
  Future<int> getFailedPinAttempts() async {
    try {
      final val = await _storage.read(key: kFailedPinAttemptsKey);
      return val != null ? int.tryParse(val) ?? 0 : 0;
    } catch (_) {
      return 0;
    }
  }

  /// Tăng số lần nhập sai PIN lên 1.
  Future<int> incrementFailedPinAttempts() async {
    final current = await getFailedPinAttempts();
    final next = current + 1;
    try {
      await _storage.write(key: kFailedPinAttemptsKey, value: next.toString());
    } catch (_) {}
    return next;
  }

  /// Đặt lại số lần nhập sai PIN về 0.
  Future<void> resetFailedPinAttempts() async {
    try {
      await _storage.delete(key: kFailedPinAttemptsKey);
    } catch (_) {}
  }

  /// Lấy thời điểm kết thúc khóa tạm (lockout).
  Future<DateTime?> getLockoutUntil() async {
    try {
      final val = await _storage.read(key: kPinLockoutUntilKey);
      if (val != null) {
        final ms = int.tryParse(val);
        if (ms != null) {
          final dt = DateTime.fromMillisecondsSinceEpoch(ms);
          if (dt.isAfter(DateTime.now())) {
            return dt;
          }
        }
      }
      return null;
    } catch (_) {
      return null;
    }
  }

  /// Đặt thời điểm kết thúc khóa tạm (lockout).
  Future<void> setLockoutUntil(DateTime until) async {
    try {
      await _storage.write(
        key: kPinLockoutUntilKey,
        value: until.millisecondsSinceEpoch.toString(),
      );
    } catch (_) {}
  }

  /// Xóa trạng thái khóa tạm.
  Future<void> clearLockout() async {
    try {
      await _storage.delete(key: kPinLockoutUntilKey);
    } catch (_) {}
  }

  /// Lấy số phút nhắc trước ca học (mặc định 15 phút).
  Future<int> getReminderLeadMinutes() async {
    try {
      final val = await _storage.read(key: kReminderLeadMinutesKey);
      if (val != null) {
        final mins = int.tryParse(val);
        if (mins != null && [5, 10, 15, 30].contains(mins)) {
          return mins;
        }
      }
      return 15;
    } catch (_) {
      return 15;
    }
  }

  /// Lưu số phút nhắc trước ca học.
  Future<void> saveReminderLeadMinutes(int minutes) async {
    try {
      await _storage.write(
        key: kReminderLeadMinutesKey,
        value: minutes.toString(),
      );
    } catch (_) {}
  }

  /// Lấy trạng thái bật/tắt nhắc nhở (mặc định true).
  Future<bool> getReminderEnabled() async {
    try {
      final val = await _storage.read(key: kReminderEnabledKey);
      return val != 'false';
    } catch (_) {
      return true;
    }
  }

  /// Lưu trạng thái bật/tắt nhắc nhở.
  Future<void> saveReminderEnabled(bool enabled) async {
    try {
      await _storage.write(
        key: kReminderEnabledKey,
        value: enabled.toString(),
      );
    } catch (_) {}
  }

  /// Lấy địa chỉ API máy chủ trường đã cấu hình (nếu có).
  Future<String?> getSchoolApiUrl() async {
    try {
      final val = await _storage.read(key: kSchoolApiUrlKey);
      if (val != null && val.trim().isNotEmpty) {
        return val.trim();
      }
      return kDefaultSchoolApiUrl.isNotEmpty ? kDefaultSchoolApiUrl : null;
    } catch (_) {
      return kDefaultSchoolApiUrl.isNotEmpty ? kDefaultSchoolApiUrl : null;
    }
  }

  /// Lưu địa chỉ API máy chủ trường.
  Future<void> saveSchoolApiUrl(String url) async {
    try {
      final clean = url.trim();
      if (clean.isEmpty) {
        await _storage.delete(key: kSchoolApiUrlKey);
      } else {
        await _storage.write(key: kSchoolApiUrlKey, value: clean);
      }
    } catch (_) {}
  }
}
