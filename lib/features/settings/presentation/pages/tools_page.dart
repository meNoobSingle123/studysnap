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

  Widget _buildSectionHeader(BuildContext context, String title) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 6),
      child: Text(
        title,
        style: theme.textTheme.labelMedium?.copyWith(
          color: theme.colorScheme.outline,
          fontWeight: FontWeight.bold,
          letterSpacing: 1.1,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text(AppStrings.toolsTab),
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(vertical: 8.0),
        children: [
          // NHÓM HỌC TẬP
          _buildSectionHeader(context, 'HỌC TẬP'),
          ListTile(
            leading: const Icon(Icons.picture_as_pdf_outlined),
            title: const Text(AppStrings.pdfExportTitle),
            subtitle: const Text('Xuất Thời khóa biểu & Ghi chú A4'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => context.push(Routes.pdfExport),
          ),
          Divider(indent: 56, height: 1, color: theme.colorScheme.outlineVariant.withValues(alpha: 0.3)),
          ListTile(
            leading: const Icon(Icons.document_scanner_outlined),
            title: const Text(AppStrings.ocrScanner),
            subtitle: const Text('Chụp/chọn ảnh để nhận diện chữ in tự động'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => context.push(Routes.ocrScanner),
          ),
          Divider(indent: 56, height: 1, color: theme.colorScheme.outlineVariant.withValues(alpha: 0.3)),
          ListTile(
            leading: const Icon(Icons.qr_code_scanner_outlined),
            title: const Text(AppStrings.scannerTitle),
            subtitle: const Text('Quét tài liệu và chụp ảnh bài giảng'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => context.push(Routes.scanner),
          ),

          // NHÓM HỆ THỐNG
          _buildSectionHeader(context, 'HỆ THỐNG'),
          ListTile(
            leading: const Icon(Icons.notifications_active_outlined),
            title: const Text(AppStrings.notificationTitle),
            subtitle: const Text('Lên lịch nhắc tự động trước ca học'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => context.push(Routes.notifications),
          ),
          Divider(indent: 56, height: 1, color: theme.colorScheme.outlineVariant.withValues(alpha: 0.3)),
          ListTile(
            leading: const Icon(Icons.map_outlined),
            title: const Text(AppStrings.mapNavigation),
            subtitle: const Text('Chỉ đường đi bộ đến tòa nhà trong khuôn viên'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => context.push(Routes.campusMap),
          ),
          Divider(indent: 56, height: 1, color: theme.colorScheme.outlineVariant.withValues(alpha: 0.3)),
          ListTile(
            leading: const Icon(Icons.settings_outlined),
            title: const Text(AppStrings.appSettings),
            subtitle: const Text('Cấu hình ứng dụng và lưu trữ'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {
              // S13: System settings shortcut
            },
          ),

          // NHÓM BẢO MẬT
          _buildSectionHeader(context, 'BẢO MẬT'),
          SwitchListTile(
            secondary: const Icon(Icons.fingerprint),
            title: const Text(AppStrings.biometricLockTitle),
            subtitle: const Text(AppStrings.biometricLockSubtitle),
            value: _isLockEnabled,
            onChanged: _onToggleLock,
          ),
        ],
      ),
    );
  }
}


