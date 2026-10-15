import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:local_auth/local_auth.dart';

import '../../../../core/di/injection.dart';
import '../../../../core/l10n/strings.dart';
import '../../../../core/router/routes.dart';
import '../../../../core/security/auth_lock_listenable.dart';
import '../../../../core/security/key_storage_service.dart';

class ToolsPage extends StatefulWidget {
  final KeyStorageService? keyStorageService;
  final LocalAuthentication? localAuth;

  const ToolsPage({
    super.key,
    this.keyStorageService,
    this.localAuth,
  });

  @override
  State<ToolsPage> createState() => _ToolsPageState();
}

class _ToolsPageState extends State<ToolsPage> {
  late final KeyStorageService _keyStorage;
  late final LocalAuthentication _localAuth;
  bool _isLockEnabled = false;

  @override
  void initState() {
    super.initState();
    _keyStorage = widget.keyStorageService ??
        (getIt.isRegistered<KeyStorageService>()
            ? getIt<KeyStorageService>()
            : KeyStorageService());
    _localAuth = widget.localAuth ??
        (getIt.isRegistered<LocalAuthentication>()
            ? getIt<LocalAuthentication>()
            : LocalAuthentication());

    _isLockEnabled = AuthLockListenable.instance.isLockEnabled;
    _syncFromStorage();
  }

  Future<void> _syncFromStorage() async {
    final enabled = await _keyStorage.isLockEnabled();
    if (mounted && _isLockEnabled != enabled) {
      setState(() {
        _isLockEnabled = enabled;
      });
    }
  }

  Future<void> _onToggleLock(bool value) async {
    if (value) {
      try {
        final isSupported = await _localAuth.isDeviceSupported();
        final canCheck = await _localAuth.canCheckBiometrics;
        if (!isSupported && !canCheck) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text(AppStrings.biometricsNotAvailable)),
            );
          }
          return;
        }

        final didAuthenticate = await _localAuth.authenticate(
          localizedReason: AppStrings.biometricAuthRequiredToEnable,
          biometricOnly: false,
          persistAcrossBackgrounding: true,
        );

        if (!didAuthenticate) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text(AppStrings.biometricsFailed)),
            );
          }
          return;
        }
      } catch (_) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text(AppStrings.biometricsFailed)),
          );
        }
        return;
      }
    }

    await _keyStorage.setLockEnabled(value);
    AuthLockListenable.instance.setLockEnabled(value);

    if (mounted) {
      setState(() {
        _isLockEnabled = value;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            value
                ? AppStrings.biometricLockEnabledSuccess
                : AppStrings.biometricLockDisabledSuccess,
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(AppStrings.toolsTab),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16.0),
        children: [
          // Security / Biometrics Lock Switch
          Card(
            child: SwitchListTile(
              secondary: const Icon(Icons.fingerprint),
              title: const Text(AppStrings.biometricLockTitle),
              subtitle: const Text(AppStrings.biometricLockSubtitle),
              value: _isLockEnabled,
              onChanged: _onToggleLock,
            ),
          ),
          const SizedBox(height: 12),
          Card(
            child: ListTile(
              leading: const Icon(Icons.qr_code_scanner_rounded),
              title: const Text(AppStrings.scannerTitle),
              subtitle: const Text('Quét tài liệu và chụp ảnh bài giảng (S08)'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => context.push(Routes.scanner),
            ),
          ),
          const SizedBox(height: 12),
          Card(
            child: ListTile(
              leading: const Icon(Icons.picture_as_pdf_rounded),
              title: const Text(AppStrings.pdfExportTitle),
              subtitle: const Text('Xuất Thời khóa biểu & Ghi chú A4 (S09)'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => context.push(Routes.pdfExport),
            ),
          ),
          const SizedBox(height: 12),
          Card(
            child: ListTile(
              leading: const Icon(Icons.notifications_active_rounded),
              title: const Text(AppStrings.notificationTitle),
              subtitle: const Text('Lên lịch nhắc tự động 15 phút trước ca học (CĐ 7)'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => context.push(Routes.notifications),
            ),
          ),
          const SizedBox(height: 12),
          Card(
            child: ListTile(
              leading: const Icon(Icons.map_outlined),
              title: const Text(AppStrings.mapNavigation),
              trailing: const Icon(Icons.chevron_right),
              onTap: () {
                // S10: Campus map navigation shortcut
              },
            ),
          ),
          const SizedBox(height: 12),
          Card(
            child: ListTile(
              leading: const Icon(Icons.settings_outlined),
              title: const Text(AppStrings.appSettings),
              trailing: const Icon(Icons.chevron_right),
              onTap: () {
                // S13: System settings shortcut
              },
            ),
          ),
        ],
      ),
    );
  }
}
