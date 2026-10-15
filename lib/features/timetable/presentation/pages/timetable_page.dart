import 'package:flutter/material.dart';

<<<<<<< HEAD
import '../../../../core/l10n/strings.dart';

class TimetablePage extends StatelessWidget {
  const TimetablePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(AppStrings.timetableTab),
      ),
      body: const Center(
        child: Text(AppStrings.timetableTab),
=======
import '../../../../core/di/injection.dart';
import '../../../../core/errors/app_exception.dart';
import '../../../../core/l10n/strings.dart';
import '../../data/datasources/timetable_remote_data_source.dart';

/// Màn hình Thời khóa biểu (S02, CĐ 2).
/// Hỗ trợ kéo để làm mới (FR-03) và nút đồng bộ API theo Chương 5.
class TimetablePage extends StatefulWidget {
  final TimetableRemoteDataSource? remoteDataSource;

  const TimetablePage({super.key, this.remoteDataSource});

  @override
  State<TimetablePage> createState() => _TimetablePageState();
}

class _TimetablePageState extends State<TimetablePage> {
  bool _isSyncing = false;
  Map<String, dynamic>? _syncedData;

  TimetableRemoteDataSource get _effectiveDataSource {
    return widget.remoteDataSource ??
        (getIt.isRegistered<TimetableRemoteDataSource>()
            ? getIt<TimetableRemoteDataSource>()
            : TimetableRemoteDataSourceImpl(dioClient: getIt()));
  }

  Future<void> _syncTimetable() async {
    if (_isSyncing) return;

    setState(() {
      _isSyncing = true;
    });

    try {
      final data = await _effectiveDataSource.getTimetable('2026-1');
      if (!mounted) return;

      setState(() {
        _syncedData = data;
        _isSyncing = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(AppStrings.syncTimetableSuccess),
          backgroundColor: Colors.green,
          duration: Duration(seconds: 2),
        ),
      );
    } on AppException catch (e) {
      if (!mounted) return;
      setState(() {
        _isSyncing = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.message),
          backgroundColor: Theme.of(context).colorScheme.error,
          duration: const Duration(seconds: 3),
        ),
      );
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _isSyncing = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(AppStrings.syncTimetableFailed),
          backgroundColor: Colors.red,
          duration: Duration(seconds: 3),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final subjects = _syncedData?['subjects'] as List<dynamic>? ?? [];
    final slots = _syncedData?['slots'] as List<dynamic>? ?? [];

    return Scaffold(
      appBar: AppBar(
        title: const Text(AppStrings.timetableTab),
        actions: [
          IconButton(
            tooltip: AppStrings.syncTimetable,
            icon: _isSyncing
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.sync),
            onPressed: _isSyncing ? null : _syncTimetable,
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _syncTimetable,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16.0),
          children: [
            if (_syncedData != null) ...[
              Card(
                elevation: 0,
                color: theme.colorScheme.primaryContainer,
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Học kỳ: ${_syncedData!['termId'] ?? '2026-1'}',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: theme.colorScheme.onPrimaryContainer,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Đã đồng bộ ${subjects.length} môn học, ${slots.length} ca học',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.onPrimaryContainer,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
            ],
            Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 48.0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.calendar_month_outlined,
                      size: 64,
                      color: theme.colorScheme.outline,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      AppStrings.timetableTab,
                      style: theme.textTheme.titleLarge?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _syncedData != null
                          ? AppStrings.syncTimetableSuccess
                          : AppStrings.emptyData,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.outline,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
>>>>>>> 65bb05b538bafaaf5ee63db54ee8a586f3e3f474
      ),
    );
  }
}
