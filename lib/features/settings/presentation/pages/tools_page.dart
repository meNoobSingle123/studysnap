import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:local_auth/local_auth.dart';

import '../../../../core/di/injection.dart';
import '../../../../core/l10n/strings.dart';
import '../../../../core/router/routes.dart';
import '../../../../core/security/auth_lock_listenable.dart';
import '../../../../core/security/key_storage_service.dart';
import '../../../ai_assistant/presentation/widgets/ai_assistant_bottom_sheet.dart';

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

  Widget _buildSectionHeader(BuildContext context, String title, IconData icon) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 10),
      child: Row(
        children: [
          Icon(icon, size: 16, color: theme.colorScheme.primary),
          const SizedBox(width: 8),
          Text(
            title,
            style: theme.textTheme.labelLarge?.copyWith(
              color: theme.colorScheme.primary,
              fontWeight: FontWeight.bold,
              letterSpacing: 0.8,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildToolGridCard({
    required BuildContext context,
    required String title,
    required String subtitle,
    required IconData icon,
    required Color iconColor,
    required VoidCallback onTap,
    String? badge,
  }) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Card(
      elevation: 0,
      color: colorScheme.surfaceContainerLow,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: colorScheme.outlineVariant.withValues(alpha: 0.4),
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(14.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      color: iconColor.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    alignment: Alignment.center,
                    child: Icon(icon, color: iconColor, size: 22),
                  ),
                  if (badge != null)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: colorScheme.secondaryContainer,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        badge,
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: colorScheme.onSecondaryContainer,
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    subtitle,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                      fontSize: 11,
                      height: 1.25,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text(AppStrings.toolsTab),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        children: [
          // ── 1. Hero Header Banner ──────────────────────────────────────────
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  colorScheme.primaryContainer.withValues(alpha: 0.7),
                  colorScheme.surfaceContainerHighest,
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: colorScheme.primary.withValues(alpha: 0.2),
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    color: colorScheme.primary,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: const Icon(
                    Icons.school_rounded,
                    color: Colors.white,
                    size: 28,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            'Trung tâm Tiện ích',
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: colorScheme.primary.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              'Offline-First',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                color: colorScheme.primary,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Bộ công cụ hỗ trợ sinh viên học tập, ghi chép và tính toán tối ưu',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                          height: 1.3,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // ── 2. Nhóm Tiện ích Học tập hàng đầu (Cards 2x2) ───────────────────
          _buildSectionHeader(context, AppStrings.sectionStudy, Icons.apps_rounded),
          Row(
            children: [
              Expanded(
                child: _buildToolGridCard(
                  context: context,
                  title: AppStrings.gpaProjectionTitle,
                  subtitle: 'Tính điểm GPA cần đạt cho mục tiêu',
                  icon: Icons.calculate_rounded,
                  iconColor: const Color(0xFF1E88E5),
                  badge: 'CĐ 2',
                  onTap: () => context.push(Routes.gpaProjection),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _buildToolGridCard(
                  context: context,
                  title: AppStrings.pdfExportTitle,
                  subtitle: 'Xuất lịch học & ghi chú A4 Unicode',
                  icon: Icons.picture_as_pdf_rounded,
                  iconColor: const Color(0xFFE53935),
                  badge: 'CĐ 4',
                  onTap: () => context.push(Routes.pdfExport),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: _buildToolGridCard(
                  context: context,
                  title: AppStrings.ocrScanner,
                  subtitle: AppStrings.ocrScannerSubtitle,
                  icon: Icons.document_scanner_rounded,
                  iconColor: const Color(0xFF43A047),
                  badge: 'CĐ 12',
                  onTap: () => context.push(Routes.ocrScanner),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _buildToolGridCard(
                  context: context,
                  title: 'Chụp ảnh bài giảng',
                  subtitle: 'Chụp slide & lưu vào bài học',
                  icon: Icons.camera_enhance_rounded,
                  iconColor: const Color(0xFFFB8C00),
                  onTap: () => context.push(Routes.scanner),
                ),
              ),
            ],
          ),

          // ── 3. Thẻ Trí tuệ Nhân tạo (AI) ──────────────────────────────────
          _buildSectionHeader(context, 'TRÍ TUỆ NHÂN TẠO (AI)', Icons.auto_awesome_rounded),
          Card(
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: BorderSide(color: const Color(0xFF5E48E8).withValues(alpha: 0.3)),
            ),
            child: Ink(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    const Color(0xFF5E48E8).withValues(alpha: 0.08),
                    colorScheme.surfaceContainerLow,
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(16),
              ),
              child: ListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                leading: Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: const Color(0xFF5E48E8).withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  alignment: Alignment.center,
                  child: const Icon(
                    Icons.auto_awesome_rounded,
                    color: Color(0xFF5E48E8),
                    size: 24,
                  ),
                ),
                title: const Text(
                  'Trợ lý Học tập AI',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                subtitle: const Text(
                  'Tóm tắt bài học & Tạo bộ câu hỏi trắc nghiệm Active Recall',
                  style: TextStyle(fontSize: 12),
                ),
                trailing: FilledButton.tonal(
                  onPressed: () {
                    AiAssistantBottomSheet.show(
                      context: context,
                      noteTitle: 'Khám phá Trợ lý Học tập AI',
                      noteContent:
                          'Tính năng Trợ lý AI StudySnap hỗ trợ sinh viên tóm tắt bài giảng nhanh gọn, trích xuất điểm nhấn và tự động tạo bộ câu hỏi trắc nghiệm Active Recall để chuẩn bị cho kỳ thi.',
                      subjectName: 'Trải nghiệm AI',
                    );
                  },
                  style: FilledButton.styleFrom(
                    visualDensity: VisualDensity.compact,
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                  ),
                  child: const Text('Mở AI ✨', style: TextStyle(fontSize: 12)),
                ),
              ),
            ),
          ),

          // ── 4. Nhóm Hệ thống ──────────────────────────────────────────────
          _buildSectionHeader(context, AppStrings.sectionSystem, Icons.tune_rounded),
          Card(
            elevation: 0,
            color: colorScheme.surfaceContainerLow,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: BorderSide(color: colorScheme.outlineVariant.withValues(alpha: 0.4)),
            ),
            child: Column(
              children: [
                ListTile(
                  leading: Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      color: Colors.indigo.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    alignment: Alignment.center,
                    child: const Icon(Icons.explore_outlined, color: Colors.indigo, size: 20),
                  ),
                  title: const Text('Giới thiệu & Chào mừng (Onboarding)'),
                  subtitle: const Text('Xem lại tổng quan các tính năng của StudySnap'),
                  trailing: const Icon(Icons.chevron_right, size: 20),
                  onTap: () => context.push(Routes.onboarding),
                ),
                Divider(
                  indent: 68,
                  height: 1,
                  color: colorScheme.outlineVariant.withValues(alpha: 0.25),
                ),
                ListTile(
                  leading: Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      color: Colors.teal.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    alignment: Alignment.center,
                    child: const Icon(Icons.notifications_active_outlined, color: Colors.teal, size: 20),
                  ),
                  title: const Text(AppStrings.notificationTitle),
                  subtitle: const Text(AppStrings.notificationSubtitle),
                  trailing: const Icon(Icons.chevron_right, size: 20),
                  onTap: () => context.push(Routes.notifications),
                ),
                Divider(
                  indent: 68,
                  height: 1,
                  color: colorScheme.outlineVariant.withValues(alpha: 0.25),
                ),
                ListTile(
                  leading: Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      color: Colors.blueGrey.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    alignment: Alignment.center,
                    child: const Icon(Icons.info_outline_rounded, color: Colors.blueGrey, size: 20),
                  ),
                  title: const Text(AppStrings.appSettings),
                  subtitle: const Text('StudySnap v1.1.0 (Bản dựng 2) • Xem nhật ký cập nhật'),
                  trailing: const Icon(Icons.chevron_right, size: 20),
                  onTap: () {
                    showDialog<void>(
                      context: context,
                      builder: (ctx) => AlertDialog(
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                        title: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: colorScheme.primaryContainer,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Icon(Icons.update_rounded, color: colorScheme.primary, size: 22),
                            ),
                            const SizedBox(width: 12),
                            const Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('StudySnap', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                                  Text('Phiên bản v1.1.0 • Build 2', style: TextStyle(fontSize: 12, color: Colors.grey)),
                                ],
                              ),
                            ),
                          ],
                        ),
                        content: SingleChildScrollView(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: const Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      '🚀 Điểm mới trong bản cập nhật v1.1.0:',
                                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                                    ),
                                    SizedBox(height: 8),
                                    Text('• 🗓️ Thời khóa biểu ma trận: Thao tác Chèn hàng (Insert Row), Xóa hàng (Delete Row), Sửa khung giờ trực tiếp tại từng ca học.'),
                                    SizedBox(height: 6),
                                    Text('• 🤖 Trợ lý Học tập AI (Gemini Flash ngầm): Nạp nhiều ảnh Slide bài giảng tự động quét OCR offline; tạo câu hỏi trắc nghiệm tùy chọn số lượng (3, 5, 10 câu) và độ khó (Dễ, Trung bình, Khó).'),
                                    SizedBox(height: 6),
                                    Text('• 📊 Bộ công cụ học đường: Tối ưu tính GPA tích lũy, Quét bảng viết OCR không cần mạng, Xuất file PDF A4 chuẩn tiếng Việt.'),
                                    SizedBox(height: 6),
                                    Text('• 📖 Giới thiệu & Onboarding: Dễ dàng xem lại trang giới thiệu và hướng dẫn tính năng bất cứ lúc nào.'),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 12),
                              const Text(
                                '© 2026 Nhóm 7 • Clean Architecture • Local-First Hive CE AES-256',
                                style: TextStyle(fontSize: 11, color: Colors.grey),
                              ),
                            ],
                          ),
                        ),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(ctx),
                            child: const Text('Đóng'),
                          ),
                          FilledButton.icon(
                            style: FilledButton.styleFrom(
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            ),
                            icon: const Icon(Icons.explore_outlined, size: 16),
                            label: const Text('Xem giới thiệu'),
                            onPressed: () {
                              Navigator.pop(ctx);
                              context.push(Routes.onboarding);
                            },
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ],
            ),
          ),

          // ── 5. Nhóm Bảo mật (CĐ 11) ──────────────────────────────────────
          _buildSectionHeader(context, AppStrings.sectionSecurity, Icons.security_rounded),
          Card(
            elevation: 0,
            color: colorScheme.surfaceContainerLow,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: BorderSide(color: colorScheme.outlineVariant.withValues(alpha: 0.4)),
            ),
            child: Column(
              children: [
                SwitchListTile(
                  secondary: Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      color: colorScheme.primary.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    alignment: Alignment.center,
                    child: Icon(Icons.fingerprint, color: colorScheme.primary, size: 22),
                  ),
                  title: const Text(
                    AppStrings.biometricLockTitle,
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  subtitle: const Text(AppStrings.biometricLockSubtitle),
                  value: _isLockEnabled,
                  onChanged: _onToggleLock,
                ),
                Divider(
                  indent: 68,
                  height: 1,
                  color: colorScheme.outlineVariant.withValues(alpha: 0.25),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
                  child: Row(
                    children: [
                      Icon(Icons.lock_outline_rounded, size: 16, color: colorScheme.outline),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Dữ liệu mã hóa AES-256 lưu hoàn toàn trên thiết bị (Local-First).',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: colorScheme.outline,
                            fontSize: 11,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}



