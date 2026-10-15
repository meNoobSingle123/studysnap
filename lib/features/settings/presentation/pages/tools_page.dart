import 'package:flutter/material.dart';
import 'package:local_auth/local_auth.dart';

import '../../../../core/di/injection.dart';
import '../../../../core/l10n/strings.dart';
import '../../../../core/security/auth_lock_listenable.dart';
import '../../../../core/security/key_storage_service.dart';
import '../../../maps/campus_map_page.dart';
import '../../../ocr/ocr_scanner_page.dart';

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

  void _go(BuildContext context, Widget page) =>
      Navigator.push(context, MaterialPageRoute(builder: (_) => page));

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
          // Campus Map
          Card(
            child: ListTile(
              leading: const Icon(Icons.map_outlined),
              title: const Text(AppStrings.mapNavigation),
              subtitle: const Text('Chỉ đường đi bộ đến tòa nhà trong khuôn viên'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => _go(context, const CampusMapPage()),
            ),
          ),
          const SizedBox(height: 12),
          // OCR Scanner
          Card(
            child: ListTile(
              leading: const Icon(Icons.document_scanner_outlined),
              title: const Text(AppStrings.ocrScanner),
              subtitle: const Text('Chụp/chọn ảnh để nhận diện chữ in tự động'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => _go(context, const OcrScannerPage()),
            ),
          ),
          const SizedBox(height: 12),
          // App Settings
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
