import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:local_auth/local_auth.dart';

import '../l10n/strings.dart';
import 'auth_lock_listenable.dart';
import 'key_storage_service.dart';

/// Shared helper to toggle biometric/device security lock consistently across
/// ToolsPage and SystemSettingsPage without duplicating verification logic.
abstract final class BiometricLockHelper {
  /// Attempts to toggle the app lock to [targetValue].
  /// Returns the resulting enabled state after verification & persistence.
  static Future<bool?> toggleLock({
    required BuildContext context,
    required bool targetValue,
    required KeyStorageService keyStorage,
    required LocalAuthentication localAuth,
  }) async {
    if (kIsWeb) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text(AppStrings.mobileOnlyFeature)),
        );
      }
      return null;
    }

    if (targetValue) {
      try {
        final isSupported = await localAuth.isDeviceSupported();
        final canCheck = await localAuth.canCheckBiometrics;
        if (!isSupported && !canCheck) {
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text(AppStrings.biometricsNotAvailable)),
            );
          }
          return null;
        }

        final didAuthenticate = await localAuth.authenticate(
          localizedReason: AppStrings.biometricAuthRequiredToEnable,
          biometricOnly: false,
          persistAcrossBackgrounding: true,
        );

        if (!didAuthenticate) {
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text(AppStrings.biometricsFailed)),
            );
          }
          return null;
        }
      } catch (_) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text(AppStrings.biometricsFailed)),
          );
        }
        return null;
      }
    }

    await keyStorage.setLockEnabled(targetValue);
    AuthLockListenable.instance.setLockEnabled(targetValue);

    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            targetValue
                ? AppStrings.biometricLockEnabledSuccess
                : AppStrings.biometricLockDisabledSuccess,
          ),
        ),
      );
    }
    return targetValue;
  }
}

