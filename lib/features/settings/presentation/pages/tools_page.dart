import 'package:flutter/foundation.dart';
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
    if (kIsWeb) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text(AppStrings.mobileOnlyFeature)),
        );
      }
      return;
    }

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

  Widget _buildLeadingIcon(BuildContext context, IconData icon, {Color? color}) {
    final theme = Theme.of(context);
    final iconColor = color ?? theme.colorScheme.primary;
    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        color: iconColor.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(10),
      ),
      alignment: Alignment.center,
      child: Icon(
        icon,
        size: 20,
        color: iconColor,
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
          _buildSectionHeader(context, AppStrings.sectionStudy),
          ListTile(
            leading: _buildLeadingIcon(context, Icons.picture_as_pdf_outlined),
            title: const Text(AppStrings.pdfExportTitle),
            subtitle: const Text(AppStrings.pdfExportSubtitle),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => context.push(Routes.pdfExport),
          ),
          Divider(indent: 72, height: 1, color: theme.colorScheme.outlineVariant.withValues(alpha: 0.3)),
          ListTile(
            leading: _buildLeadingIcon(context, Icons.document_scanner_outlined),
            title: const Text(AppStrings.ocrScanner),
            subtitle: const Text(AppStrings.ocrScannerSubtitle),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => context.push(Routes.ocrScanner),
          ),
          Divider(indent: 72, height: 1, color: theme.colorScheme.outlineVariant.withValues(alpha: 0.3)),
          ListTile(
            leading: _buildLeadingIcon(context, Icons.camera_alt_outlined),
            title: const Text('Chụp ảnh bài giảng'),
            subtitle: const Text('Chụp ảnh tài liệu, bài giảng lưu vào ghi chú'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => context.push(Routes.scanner),
          ),

          // NHÓM HỆ THỐNG
          _buildSectionHeader(context, AppStrings.sectionSystem),
          ListTile(
            leading: _buildLeadingIcon(context, Icons.notifications_active_outlined),
            title: const Text(AppStrings.notificationTitle),
            subtitle: const Text(AppStrings.notificationSubtitle),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => context.push(Routes.notifications),
          ),
          Divider(indent: 72, height: 1, color: theme.colorScheme.outlineVariant.withValues(alpha: 0.3)),
          ListTile(
            leading: _buildLeadingIcon(context, Icons.settings_outlined),
            title: const Text(AppStrings.appSettings),
            subtitle: const Text(AppStrings.appSettingsSubtitle),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {
              // S13: System settings shortcut
            },
          ),

          // NHÓM BẢO MẬT
          _buildSectionHeader(context, AppStrings.sectionSecurity),
          SwitchListTile(
            secondary: _buildLeadingIcon(context, Icons.fingerprint),
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


