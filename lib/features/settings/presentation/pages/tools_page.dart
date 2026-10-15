import 'package:flutter/material.dart';
<<<<<<< HEAD

import '../../../../core/l10n/strings.dart';
import '../../../maps/campus_map_page.dart';
import '../../../ocr/ocr_scanner_page.dart';

class ToolsPage extends StatelessWidget {
  const ToolsPage({super.key});

  void _go(BuildContext context, Widget page) =>
      Navigator.push(context, MaterialPageRoute(builder: (_) => page));
=======
import 'package:local_auth/local_auth.dart';

import '../../../../core/di/injection.dart';
import '../../../../core/l10n/strings.dart';
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
>>>>>>> 65bb05b538bafaaf5ee63db54ee8a586f3e3f474

  @override
  Widget build(BuildContext context) {
    return Scaffold(
<<<<<<< HEAD
      appBar: AppBar(title: const Text(AppStrings.toolsTab)),
      body: ListView(padding: const EdgeInsets.all(16), children: [
        _ToolCard(
          icon: Icons.map_outlined,
          title: AppStrings.mapNavigation,
          subtitle: 'Chỉ đường đi bộ đến tòa nhà trong khuôn viên',
          onTap: () => _go(context, const CampusMapPage()),
        ),
        _ToolCard(
          icon: Icons.document_scanner_outlined,
          title: AppStrings.ocrScanner,
          subtitle: 'Chụp/chọn ảnh để nhận diện chữ in tự động',
          onTap: () => _go(context, const OcrScannerPage()),
        ),
        _ToolCard(
          icon: Icons.settings_outlined,
          title: AppStrings.appSettings,
          subtitle: 'Tùy chỉnh ứng dụng',
          onTap: () {
            // TODO S13: Màn cài đặt sẽ bổ sung sau
          },
        ),
      ]),
    );
  }
}

class _ToolCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _ToolCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Card(
        child: ListTile(
          leading: Icon(icon),
          title: Text(title),
          subtitle: Text(subtitle),
          trailing: const Icon(Icons.chevron_right),
          onTap: onTap,
        ),
=======
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
>>>>>>> 65bb05b538bafaaf5ee63db54ee8a586f3e3f474
      ),
    );
  }
}
<<<<<<< HEAD

=======
>>>>>>> 65bb05b538bafaaf5ee63db54ee8a586f3e3f474
