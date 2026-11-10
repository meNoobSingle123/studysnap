import 'dart:io';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:path_provider/path_provider.dart';

import '../../../../core/di/injection.dart';
import '../../../../core/network/dio_client.dart';
import '../../../../core/router/routes.dart';
import '../../../../core/security/auth_lock_listenable.dart';
import '../../../../core/security/key_storage_service.dart';
import '../../../ai_assistant/data/datasources/gemini_remote_datasource.dart';
import '../../../timetable/data/datasources/timetable_local_datasource.dart';

/// Màn hình Cài đặt hệ thống hoàn chỉnh cho ứng dụng StudySnap.
class SystemSettingsPage extends StatefulWidget {
  final KeyStorageService? keyStorageService;
  final GeminiRemoteDataSource? geminiRemoteDataSource;
  final TimetableLocalDataSource? timetableLocalDataSource;

  const SystemSettingsPage({
    super.key,
    this.keyStorageService,
    this.geminiRemoteDataSource,
    this.timetableLocalDataSource,
  });

  @override
  State<SystemSettingsPage> createState() => _SystemSettingsPageState();
}

class _SystemSettingsPageState extends State<SystemSettingsPage> {
  late final KeyStorageService _keyStorage;
  late final GeminiRemoteDataSource _geminiDataSource;
  late final TimetableLocalDataSource _timetableDataSource;

  String? _savedApiKey;
  bool _isLoadingKey = true;
  bool _isTestingConnection = false;
  bool _isClearingCache = false;
  bool _isResettingData = false;
  bool _isLockEnabled = false;

  @override
  void initState() {
    super.initState();
    _keyStorage = widget.keyStorageService ??
        (getIt.isRegistered<KeyStorageService>()
            ? getIt<KeyStorageService>()
            : KeyStorageService());
    _geminiDataSource = widget.geminiRemoteDataSource ??
        (getIt.isRegistered<GeminiRemoteDataSource>()
            ? getIt<GeminiRemoteDataSource>()
            : GeminiRemoteDataSourceImpl(
                dioClient: getIt.isRegistered<DioClient>()
                    ? getIt<DioClient>()
                    : DioClient(),
                keyStorageService: _keyStorage,
              ));
    _timetableDataSource = widget.timetableLocalDataSource ??
        (getIt.isRegistered<TimetableLocalDataSource>()
            ? getIt<TimetableLocalDataSource>()
            : TimetableLocalDataSourceImpl(keyStorageService: _keyStorage));

    _isLockEnabled = AuthLockListenable.instance.isLockEnabled;
    _loadInitialState();
  }

  Future<void> _loadInitialState() async {
    final apiKey = await _keyStorage.getGeminiApiKey();
    final lockEnabled = await _keyStorage.isLockEnabled();
    if (mounted) {
      setState(() {
        _savedApiKey = apiKey;
        _isLockEnabled = lockEnabled;
        _isLoadingKey = false;
      });
    }
  }

  String _maskApiKey(String key) {
    if (key.length <= 8) return '••••••••';
    return '${key.substring(0, 6)}...${key.substring(key.length - 4)}';
  }

  Future<void> _showEditApiKeyDialog() async {
    final textController = TextEditingController(text: _savedApiKey ?? '');
    bool isObscured = true;

    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            final theme = Theme.of(context);
            return AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              title: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFF5E48E8).withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.key_rounded, color: Color(0xFF5E48E8), size: 22),
                  ),
                  const SizedBox(width: 10),
                  const Text('Khóa Google Gemini API', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                ],
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Nhập khóa API từ Google AI Studio (bắt đầu bằng AIzaSy...) để sử dụng Trợ lý học tập AI khi có mạng Wifi/4G.',
                      style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                    ),
                    const SizedBox(height: 14),
                    TextField(
                      controller: textController,
                      obscureText: isObscured,
                      maxLines: 1,
                      autocorrect: false,
                      enableSuggestions: false,
                      decoration: InputDecoration(
                        labelText: 'API Key',
                        hintText: 'AIzaSy...',
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        prefixIcon: const Icon(Icons.password_rounded),
                        suffixIcon: IconButton(
                          icon: Icon(isObscured ? Icons.visibility_off : Icons.visibility),
                          onPressed: () {
                            setDialogState(() {
                              isObscured = !isObscured;
                            });
                          },
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Khóa được lưu mã hóa an toàn trong bộ nhớ máy (FlutterSecureStorage).',
                      style: TextStyle(fontSize: 11, color: theme.colorScheme.primary),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogContext),
                  child: const Text('Hủy'),
                ),
                FilledButton(
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFF5E48E8),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  onPressed: () async {
                    final newKey = textController.text.trim();
                    final nav = Navigator.of(dialogContext);
                    final messenger = ScaffoldMessenger.of(context);

                    if (newKey.isNotEmpty) {
                      await _keyStorage.saveGeminiApiKey(newKey);
                      if (mounted) {
                        setState(() {
                          _savedApiKey = newKey;
                        });
                        nav.pop();
                        messenger.showSnackBar(
                          const SnackBar(
                            content: Text('Đã lưu khóa API Gemini thành công!'),
                            backgroundColor: Colors.green,
                          ),
                        );
                      }
                    } else {
                      await _keyStorage.clearGeminiApiKey();
                      if (mounted) {
                        setState(() {
                          _savedApiKey = null;
                        });
                        nav.pop();
                        messenger.showSnackBar(
                          const SnackBar(
                            content: Text('Đã xóa khóa cá nhân. Trở về khóa mặc định.'),
                          ),
                        );
                      }
                    }
                  },
                  child: const Text('Lưu khóa'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _testAiConnection() async {
    setState(() {
      _isTestingConnection = true;
    });

    final messenger = ScaffoldMessenger.of(context);

    try {
      final response = await _geminiDataSource.generateContent(
        prompt: 'Xin chào, trả lời duy nhất: OK',
      );

      if (mounted) {
        messenger.showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.check_circle_rounded, color: Colors.white, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text('Kết nối Google Gemini AI thành công! (${response.trim()})'),
                ),
              ],
            ),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 4),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        messenger.showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.error_outline_rounded, color: Colors.white, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text('Kiểm tra thất bại: ${e.toString().replaceAll("Exception: ", "")}'),
                ),
              ],
            ),
            backgroundColor: Colors.redAccent,
            duration: const Duration(seconds: 5),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isTestingConnection = false;
        });
      }
    }
  }

  Future<void> _clearAppCache() async {
    setState(() {
      _isClearingCache = true;
    });

    final messenger = ScaffoldMessenger.of(context);

    try {
      final tempDir = await getTemporaryDirectory();
      if (tempDir.existsSync()) {
        final files = tempDir.listSync(recursive: true);
        for (final file in files) {
          try {
            if (file is File) {
              file.deleteSync();
            }
          } catch (_) {}
        }
      }

      if (mounted) {
        messenger.showSnackBar(
          const SnackBar(
            content: Text('Đã dọn dẹp bộ nhớ đệm (Cache) thành công!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (_) {
      if (mounted) {
        messenger.showSnackBar(
          const SnackBar(content: Text('Không thể xóa toàn bộ bộ nhớ đệm.')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isClearingCache = false;
        });
      }
    }
  }

  Future<void> _confirmResetData() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: const Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: Colors.orange, size: 24),
            SizedBox(width: 10),
            Text('Khôi phục dữ liệu gốc?'),
          ],
        ),
        content: const Text(
          'Hành động này sẽ thiết lập lại danh sách môn học và thời khóa biểu về trạng thái mẫu ban đầu.\n\nBạn có muốn tiếp tục?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Hủy'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Colors.redAccent,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Khôi phục'),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      final messenger = ScaffoldMessenger.of(context);
      setState(() {
        _isResettingData = true;
      });

      try {
        await _timetableDataSource.init();
        if (mounted) {
          messenger.showSnackBar(
            const SnackBar(
              content: Text('Đã khôi phục dữ liệu mẫu ban đầu thành công!'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } catch (_) {
        if (mounted) {
          messenger.showSnackBar(
            const SnackBar(content: Text('Không thể khôi phục dữ liệu gốc.')),
          );
        }
      } finally {
        if (mounted) {
          setState(() {
            _isResettingData = false;
          });
        }
      }
    }
  }

  void _showChangelogDialog() {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Theme.of(ctx).colorScheme.primaryContainer,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(Icons.update_rounded, color: Theme.of(ctx).colorScheme.primary, size: 22),
            ),
            const SizedBox(width: 12),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Nhật ký cập nhật', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  Text('StudySnap v1.1.0 • Build 2026', style: TextStyle(fontSize: 12, color: Colors.grey)),
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
                  color: Theme.of(ctx).colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '🚀 Tính năng & Nâng cấp nổi bật:',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                    ),
                    SizedBox(height: 8),
                    Text('• 🗓️ Thời khóa biểu: Quản lý ca học linh hoạt, tính điểm GPA mục tiêu, đồng bộ thời khóa biểu trực quan.'),
                    SizedBox(height: 6),
                    Text('• 🤖 Trợ lý AI Gemini: Tích hợp gemini-2.0-flash tốc độ cao, tóm tắt bài giảng & trắc nghiệm kiểm tra kiến thức.'),
                    SizedBox(height: 6),
                    Text('• 📝 Ghi chú & Bảng vẽ: Canvas đa màu sắc, nhận diện ký tự quang học OCR cục bộ không cần mạng.'),
                    SizedBox(height: 6),
                    Text('• 🔒 Bảo mật: Mã hóa dữ liệu cục bộ chuẩn AES-256 trên nền Hive CE.'),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              const Text(
                '© 2026 Nhóm 7 • Đại học Khoa học Tự nhiên',
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
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title, IconData icon) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 18, 4, 8),
      child: Row(
        children: [
          Icon(icon, size: 16, color: theme.colorScheme.primary),
          const SizedBox(width: 8),
          Text(
            title,
            style: theme.textTheme.labelLarge?.copyWith(
              color: theme.colorScheme.primary,
              fontWeight: FontWeight.bold,
              letterSpacing: 0.5,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Cài đặt hệ thống'),
        centerTitle: true,
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
        children: [
          // ── 1. Cấu hình Gemini AI ──────────────────────────────────────
          _buildSectionHeader('TRÍ TUỆ NHÂN TẠO (AI GEMINI)', Icons.auto_awesome_rounded),
          Card(
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: BorderSide(color: const Color(0xFF5E48E8).withValues(alpha: 0.25)),
            ),
            color: colorScheme.surfaceContainerLow,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: const Color(0xFF5E48E8).withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(Icons.smart_toy_rounded, color: Color(0xFF5E48E8), size: 22),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Google Gemini 2.0 Flash',
                              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              _isLoadingKey
                                  ? 'Đang kiểm tra...'
                                  : (_savedApiKey != null
                                      ? 'Đã cấu hình khóa cá nhân (${_maskApiKey(_savedApiKey!)})'
                                      : 'Đang dùng khóa mặc định hệ thống'),
                              style: TextStyle(
                                fontSize: 12,
                                color: _savedApiKey != null ? Colors.green.shade700 : colorScheme.onSurfaceVariant,
                                fontWeight: _savedApiKey != null ? FontWeight.w600 : FontWeight.normal,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                        icon: const Icon(Icons.key_rounded, size: 16),
                        label: Text(_savedApiKey != null ? 'Đổi khóa API' : 'Nhập API Key'),
                        onPressed: _showEditApiKeyDialog,
                      ),
                      if (_savedApiKey != null)
                        OutlinedButton.icon(
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.redAccent,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                          icon: const Icon(Icons.delete_outline_rounded, size: 16),
                          label: const Text('Xóa key'),
                          onPressed: () async {
                            final messenger = ScaffoldMessenger.of(context);
                            await _keyStorage.clearGeminiApiKey();
                            if (mounted) {
                              setState(() {
                                _savedApiKey = null;
                              });
                              messenger.showSnackBar(
                                const SnackBar(content: Text('Đã xóa khóa cá nhân.')),
                              );
                            }
                          },
                        ),
                      FilledButton.icon(
                        style: FilledButton.styleFrom(
                          backgroundColor: const Color(0xFF5E48E8),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                        icon: _isTestingConnection
                            ? const SizedBox(
                                width: 14,
                                height: 14,
                                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                              )
                            : const Icon(Icons.wifi_tethering_rounded, size: 16),
                        label: Text(_isTestingConnection ? 'Đang kiểm tra...' : 'Kiểm tra kết nối'),
                        onPressed: _isTestingConnection ? null : _testAiConnection,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),

          // ── 2. Dữ liệu & Bộ nhớ ─────────────────────────────────────────
          _buildSectionHeader('DỮ LIỆU & LƯU TRỮ', Icons.storage_rounded),
          Card(
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: BorderSide(color: colorScheme.outlineVariant.withValues(alpha: 0.3)),
            ),
            color: colorScheme.surfaceContainerLow,
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.lock_clock_rounded, color: Colors.teal),
                  title: const Text('Cơ sở dữ liệu Hive CE'),
                  subtitle: const Text('Mã hóa an toàn phần cứng chuẩn AES-256'),
                  trailing: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.teal.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Text(
                      'AES-256',
                      style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.teal),
                    ),
                  ),
                ),
                Divider(height: 1, indent: 64, color: colorScheme.outlineVariant.withValues(alpha: 0.2)),
                ListTile(
                  leading: const Icon(Icons.cleaning_services_rounded, color: Colors.blueGrey),
                  title: const Text('Dọn dẹp bộ nhớ đệm (Cache)'),
                  subtitle: const Text('Giải phóng các file ảnh và dữ liệu xử lý tạm'),
                  trailing: _isClearingCache
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : OutlinedButton(
                          style: OutlinedButton.styleFrom(
                            visualDensity: VisualDensity.compact,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          ),
                          onPressed: _clearAppCache,
                          child: const Text('Dọn dẹp'),
                        ),
                ),
                Divider(height: 1, indent: 64, color: colorScheme.outlineVariant.withValues(alpha: 0.2)),
                ListTile(
                  leading: const Icon(Icons.restore_rounded, color: Colors.redAccent),
                  title: const Text('Khôi phục dữ liệu ban đầu'),
                  subtitle: const Text('Thiết lập lại danh sách môn học mẫu'),
                  trailing: _isResettingData
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : OutlinedButton(
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.redAccent,
                            visualDensity: VisualDensity.compact,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          ),
                          onPressed: _confirmResetData,
                          child: const Text('Khôi phục'),
                        ),
                ),
              ],
            ),
          ),

          // ── 3. Lối tắt Tiện ích ──────────────────────────────────────
          _buildSectionHeader('CÀI ĐẶT NHANH', Icons.tune_rounded),
          Card(
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: BorderSide(color: colorScheme.outlineVariant.withValues(alpha: 0.3)),
            ),
            color: colorScheme.surfaceContainerLow,
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.notifications_active_outlined, color: Colors.orange),
                  title: const Text('Cài đặt Nhắc giờ học'),
                  subtitle: const Text('Khung giờ nhắc nhở, âm thanh và thông báo'),
                  trailing: const Icon(Icons.chevron_right, size: 20),
                  onTap: () => context.push(Routes.notifications),
                ),
                Divider(height: 1, indent: 64, color: colorScheme.outlineVariant.withValues(alpha: 0.2)),
                ListTile(
                  leading: const Icon(Icons.fingerprint_rounded, color: Colors.deepPurple),
                  title: const Text('Khóa bảo mật ứng dụng'),
                  subtitle: Text(_isLockEnabled ? 'Đang kích hoạt' : 'Đang tắt'),
                  trailing: const Icon(Icons.chevron_right, size: 20),
                  onTap: () => context.push(Routes.tools),
                ),
              ],
            ),
          ),

          // ── 4. Thông tin ứng dụng ──────────────────────────────────────
          _buildSectionHeader('THÔNG TIN ỨNG DỤNG', Icons.info_outline_rounded),
          Card(
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: BorderSide(color: colorScheme.outlineVariant.withValues(alpha: 0.3)),
            ),
            color: colorScheme.surfaceContainerLow,
            child: Column(
              children: [
                ListTile(
                  leading: Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: colorScheme.primary,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    alignment: Alignment.center,
                    child: const Icon(Icons.school_rounded, color: Colors.white, size: 22),
                  ),
                  title: const Text('StudySnap', style: TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: const Text('Phiên bản v1.1.0 • Bản dựng 2026'),
                ),
                Divider(height: 1, indent: 64, color: colorScheme.outlineVariant.withValues(alpha: 0.2)),
                ListTile(
                  leading: const Icon(Icons.history_edu_rounded, color: Colors.blue),
                  title: const Text('Nhật ký cập nhật'),
                  subtitle: const Text('Xem các điểm mới trong phiên bản hiện tại'),
                  trailing: const Icon(Icons.chevron_right, size: 20),
                  onTap: _showChangelogDialog,
                ),
                Divider(height: 1, indent: 64, color: colorScheme.outlineVariant.withValues(alpha: 0.2)),
                ListTile(
                  leading: const Icon(Icons.explore_outlined, color: Colors.indigo),
                  title: const Text('Hướng dẫn sử dụng (Onboarding)'),
                  subtitle: const Text('Xem lại tổng quan các tính năng của ứng dụng'),
                  trailing: const Icon(Icons.chevron_right, size: 20),
                  onTap: () => context.push(Routes.onboarding),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          const Center(
            child: Text(
              'Đồ án Quản lý Học tập Sinh viên • Nhóm 7\nĐại học Khoa học Tự nhiên',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 11, color: Colors.grey),
            ),
          ),
        ],
      ),
    );
  }
}
