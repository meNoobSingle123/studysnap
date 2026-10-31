import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:uuid/uuid.dart';

import '../../../../core/di/injection.dart';
import '../../../../core/l10n/strings.dart';
import '../../../../core/router/routes.dart';
import '../../data/datasources/timetable_local_datasource.dart';
import '../../data/datasources/timetable_remote_data_source.dart';
import '../../domain/entities/subject.dart';
import '../../domain/entities/timetable_slot.dart';
import '../../domain/repositories/timetable_repository.dart';
import '../../domain/usecases/get_subjects_usecase.dart';
import '../../domain/usecases/get_timetable_slots_usecase.dart';
import '../bloc/timetable_bloc.dart';
import '../widgets/quick_study_card.dart';
import '../widgets/timetable_grid_view.dart';

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

  Future<void> _syncTimetable([BuildContext? blocContext]) async {
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

      // Nếu có subjects/slots trả về từ server, cập nhật vào local DB
      if (getIt.isRegistered<TimetableRepository>()) {
        final repo = getIt<TimetableRepository>();
        final subjectsRaw = data['subjects'] as List<dynamic>? ?? [];
        final slotsRaw = data['slots'] as List<dynamic>? ?? [];

        for (final item in subjectsRaw) {
          final m = item as Map<String, dynamic>;
          final subj = Subject(
            id: m['id'] as String,
            name: m['name'] as String,
            code: m['code'] as String? ?? '',
            credits: m['credits'] as int? ?? 3,
            colorArgb: m['colorArgb'] as int? ?? 0xFF1976D2,
            createdAt: DateTime.now(),
            updatedAt: DateTime.now(),
          );
          await repo.saveSubject(subj);
        }

        final slots = slotsRaw.map((e) {
          final m = e as Map<String, dynamic>;
          return TimetableSlot(
            id: m['id'] as String,
            subjectId: m['subjectId'] as String,
            room: m['room'] as String? ?? '',
            buildingId: m['buildingId'] as String?,
            dayOfWeek: m['dayOfWeek'] as int? ?? 1,
            startMin: m['startMin'] as int? ?? 420,
            endMin: m['endMin'] as int? ?? 540,
            termStart: DateTime.tryParse(m['termStart'] as String? ?? '') ??
                DateTime.now(),
            termEnd: DateTime.tryParse(m['termEnd'] as String? ?? '') ??
                DateTime.now(),
            source: 'system',
            updatedAt: DateTime.now(),
          );
        }).toList();

        if (slots.isNotEmpty) {
          await repo.saveSlots(slots);
        }
      }

      if (blocContext != null && blocContext.mounted) {
        blocContext.read<TimetableBloc>().add(DaySelectedEvent(DateTime.now()));
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(AppStrings.syncTimetableSuccess),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 2),
          ),
        );
      }
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _isSyncing = false;
      });

      // Vẫn reload dữ liệu từ database cục bộ để UI luôn được làm mới
      if (blocContext != null && blocContext.mounted) {
        blocContext.read<TimetableBloc>().add(DaySelectedEvent(DateTime.now()));
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Ứng dụng đang chạy Ngoại tuyến (Local-First). Không kết nối được tới máy chủ trường học (Port 3000). Đã làm mới dữ liệu từ máy.',
          ),
          backgroundColor: Colors.blueGrey,
          duration: Duration(seconds: 4),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.remoteDataSource != null) {
      return _buildTeamSyncView(context);
    }

    return BlocProvider(
      create: (context) => TimetableBloc(
        slotsUseCase: getIt<GetTimetableSlotsUseCase>(),
        subjectsUseCase: getIt<GetSubjectsUseCase>(),
      )
        ..add(const InitTimetableSubscription())
        ..add(DaySelectedEvent(DateTime.now())),
      child: Builder(
        builder: (blocContext) => _TimetableView(
          onSync: () => _syncTimetable(blocContext),
          isSyncing: _isSyncing,
          syncedData: _syncedData,
        ),
      ),
    );
  }

  Widget _buildTeamSyncView(BuildContext context) {

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
      ),
    );
  }
}

class _TimetableView extends StatefulWidget {

  final VoidCallback onSync;
  final bool isSyncing;
  final Map<String, dynamic>? syncedData;

  const _TimetableView({
    required this.onSync,
    required this.isSyncing,
    this.syncedData,
  });

  @override
  State<_TimetableView> createState() => _TimetableViewState();
}

class _TimetableViewState extends State<_TimetableView> {
  bool _isGridView = true;
  CalendarFormat _calendarFormat = CalendarFormat.week;
  DateTime _focusedDay = DateTime.now();

  Future<void> _pickYearMonth(BuildContext context, DateTime current) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: current,
      firstDate: DateTime(2020, 1, 1),
      lastDate: DateTime(2035, 12, 31),
      initialDatePickerMode: DatePickerMode.year,
      locale: const Locale('vi', 'VN'),
      helpText: 'Chọn Tháng & Năm',
      cancelText: 'Hủy',
      confirmText: 'Chọn',
      fieldLabelText: 'Nhập ngày',
      fieldHintText: 'dd/mm/yyyy',
      errorFormatText: 'Định dạng ngày không hợp lệ (ngày/tháng/năm)',
      errorInvalidText: 'Ngày không hợp lệ',
    );
    if (picked != null) {
      setState(() {
        _focusedDay = picked;
      });
      if (context.mounted) {
        context.read<TimetableBloc>().add(DaySelectedEvent(picked));
      }
    }
  }

  Future<void> _clearSystemSlots(BuildContext blocContext) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      final repo = getIt<TimetableRepository>();
      final slots = await repo.watchAllSlots().first;
      final systemSlots = slots.where((s) => s.isSystem).toList();
      for (final s in systemSlots) {
        await repo.deleteSlot(s.id);
      }
      if (!mounted) return;
      if (blocContext.mounted) {
        blocContext.read<TimetableBloc>().add(DaySelectedEvent(_focusedDay));
      }
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            'Đã xóa ${systemSlots.length} ca học mẫu. Lịch hiện chỉ hiển thị ca học do bạn tự tạo!',
          ),
          backgroundColor: Colors.blueAccent,
        ),
      );
    } catch (e) {
      if (mounted) {
        messenger.showSnackBar(
          SnackBar(content: Text('Lỗi khi xóa ca học mẫu: $e')),
        );
      }
    }
  }

  Future<void> _restoreMockData(BuildContext blocContext) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      if (getIt.isRegistered<TimetableLocalDataSource>()) {
        await getIt<TimetableLocalDataSource>().seedMockData(force: true);
      }
      if (!mounted) return;
      if (blocContext.mounted) {
        blocContext.read<TimetableBloc>().add(DaySelectedEvent(_focusedDay));
      }
      messenger.showSnackBar(
        const SnackBar(
          content: Text('Đã khôi phục dữ liệu ca học mẫu hệ thống.'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      if (mounted) {
        messenger.showSnackBar(
          SnackBar(content: Text('Lỗi khi khôi phục dữ liệu: $e')),
        );
      }
    }
  }

  Future<void> _clearAllSlots(BuildContext blocContext) async {
    final messenger = ScaffoldMessenger.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Xác nhận xóa toàn bộ'),
        content: const Text(
          'Hành động này sẽ xóa tất cả ca học hiện có trên thời khóa biểu. Bạn có chắc chắn không?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Hủy'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Xóa hết'),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      try {
        final repo = getIt<TimetableRepository>();
        final slots = await repo.watchAllSlots().first;
        for (final s in slots) {
          await repo.deleteSlot(s.id);
        }
        if (!mounted) return;
        if (blocContext.mounted) {
          blocContext.read<TimetableBloc>().add(DaySelectedEvent(_focusedDay));
        }
        messenger.showSnackBar(
          const SnackBar(
            content: Text('Đã xóa toàn bộ ca học khỏi thời khóa biểu.'),
            backgroundColor: Colors.redAccent,
          ),
        );
      } catch (e) {
        if (mounted) {
          messenger.showSnackBar(
            SnackBar(content: Text('Lỗi khi xóa thời khóa biểu: $e')),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        titleSpacing: 12,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              AppStrings.timetableTitle,
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
            ),
            Text(
              'Tháng ${_focusedDay.month}/${_focusedDay.year}',
              style: theme.textTheme.labelSmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
        actions: [
          // Nút "Hôm nay": 1-chạm quay lại ngày hiện tại
          TextButton.icon(
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 6),
              visualDensity: VisualDensity.compact,
            ),
            icon: const Icon(Icons.today_rounded, size: 16),
            label: const Text('Hôm nay', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
            onPressed: () {
              final now = DateTime.now();
              setState(() => _focusedDay = now);
              context.read<TimetableBloc>().add(DaySelectedEvent(now));
            },
          ),
          // Nút chuyển chế độ xem: Bảng lưới (Grid như ảnh) <-> Lịch ngày (List)
          IconButton(
            tooltip: _isGridView
                ? 'Xem dạng danh sách ngày'
                : 'Xem dạng bảng lưới tuần (College Timetable)',
            icon: Icon(
              _isGridView
                  ? Icons.calendar_view_day_outlined
                  : Icons.grid_on_rounded,
            ),
            onPressed: () {
              setState(() {
                _isGridView = !_isGridView;
              });
            },
          ),
          // Nút chuyển chế độ xem: Tuần <-> Tháng
          if (!_isGridView)
            IconButton(
              tooltip: _calendarFormat == CalendarFormat.week
                  ? 'Xem dạng tháng'
                  : 'Xem dạng tuần',
              icon: Icon(
                _calendarFormat == CalendarFormat.week
                    ? Icons.calendar_month_outlined
                    : Icons.view_week_outlined,
              ),
              onPressed: () {
                setState(() {
                  _calendarFormat = _calendarFormat == CalendarFormat.week
                      ? CalendarFormat.month
                      : CalendarFormat.week;
                });
              },
            ),
          // Menu 3 chấm tiện ích: Gom các tính năng phụ gọn gàng
          PopupMenuButton<String>(
            tooltip: 'Tính năng & Dữ liệu',
            icon: const Icon(Icons.more_vert_rounded),
            onSelected: (value) async {
              if (value == 'gpa') {
                context.push(Routes.gpaProjection);
              } else if (value == 'pdf') {
                context.push(Routes.pdfExport);
              } else if (value == 'refresh') {
                context
                    .read<TimetableBloc>()
                    .add(DaySelectedEvent(_focusedDay));
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Đã làm mới dữ liệu thời khóa biểu.'),
                    duration: Duration(seconds: 2),
                    behavior: SnackBarBehavior.floating,
                  ),
                );
              } else if (value == 'sync_api') {
                widget.onSync();
              } else if (value == 'clear_mock') {
                await _clearSystemSlots(context);
              } else if (value == 'restore_mock') {
                await _restoreMockData(context);
              } else if (value == 'clear_all') {
                await _clearAllSlots(context);
              }
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'gpa',
                child: Row(
                  children: [
                    Icon(Icons.calculate_outlined, size: 20, color: Colors.indigo),
                    SizedBox(width: 10),
                    Text('Dự phóng GPA học tập'),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'pdf',
                child: Row(
                  children: [
                    Icon(Icons.picture_as_pdf_outlined, size: 20, color: Colors.deepOrange),
                    SizedBox(width: 10),
                    Text('Xuất PDF thời khóa biểu'),
                  ],
                ),
              ),
              const PopupMenuDivider(),
              const PopupMenuItem(
                value: 'refresh',
                child: Row(
                  children: [
                    Icon(Icons.refresh_rounded, size: 20, color: Colors.teal),
                    SizedBox(width: 10),
                    Text('Làm mới lịch học'),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'sync_api',
                child: Row(
                  children: [
                    Icon(Icons.cloud_sync_outlined, size: 20, color: Colors.blueAccent),
                    SizedBox(width: 10),
                    Text('Đồng bộ máy chủ trường (API)'),
                  ],
                ),
              ),
              const PopupMenuDivider(),
              const PopupMenuItem(
                value: 'clear_mock',
                child: Row(
                  children: [
                    Icon(Icons.cleaning_services_outlined, size: 20, color: Colors.blue),
                    SizedBox(width: 10),
                    Text('Xóa ca mẫu (Chỉ giữ ca tự tạo)'),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'restore_mock',
                child: Row(
                  children: [
                    Icon(Icons.restore_page_outlined, size: 20, color: Colors.green),
                    SizedBox(width: 10),
                    Text('Khôi phục ca mẫu hệ thống'),
                  ],
                ),
              ),
              const PopupMenuDivider(),
              const PopupMenuItem(
                value: 'clear_all',
                child: Row(
                  children: [
                    Icon(Icons.delete_sweep_outlined, size: 20, color: Colors.red),
                    SizedBox(width: 10),
                    Text('Xóa toàn bộ thời khóa biểu'),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
      body: BlocBuilder<TimetableBloc, TimetableState>(
        builder: (context, state) {
          if (state is TimetableLoading || state is TimetableInitial) {
            return const Center(child: CircularProgressIndicator());
          }

          if (state is TimetableError) {
            return Center(child: Text(state.message));
          }

          final loaded = state as TimetableLoaded;

          if (_isGridView) {
            return RefreshIndicator(
              onRefresh: () async {
                context
                    .read<TimetableBloc>()
                    .add(DaySelectedEvent(loaded.selectedDay));
                await Future.delayed(const Duration(milliseconds: 300));
              },
              child: TimetableGridView(
                allSlots: loaded.allSlots,
                subjectsMap: loaded.subjectsMap,
                onDataChanged: () {
                  context
                      .read<TimetableBloc>()
                      .add(DaySelectedEvent(_focusedDay));
                },
              ),
            );
          }

          return RefreshIndicator(
            onRefresh: () async {
              context
                  .read<TimetableBloc>()
                  .add(DaySelectedEvent(loaded.selectedDay));
              await Future.delayed(const Duration(milliseconds: 300));
            },
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              children: [
                const SizedBox(height: 6),

                // 1. Table Calendar (Chủ đề 2: Lịch tuần / tháng đặt trên cùng, gọn gàng)
                Card(
                  elevation: 0,
                  margin: const EdgeInsets.only(bottom: 8),
                  color: theme.colorScheme.surfaceContainerLow,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(6.0),
                    child: TableCalendar<TimetableSlot>(
                      locale: 'vi_VN',
                      firstDay: DateTime(2020, 1, 1),
                      lastDay: DateTime(2035, 12, 31),
                      focusedDay: _focusedDay,
                      calendarFormat: _calendarFormat,
                      startingDayOfWeek: StartingDayOfWeek.monday,
                      calendarBuilders: CalendarBuilders(
                        dowBuilder: (context, day) {
                          const weekdays = [
                            'T2',
                            'T3',
                            'T4',
                            'T5',
                            'T6',
                            'T7',
                            'CN'
                          ];
                          final text = weekdays[day.weekday - 1];
                          final isSunday = day.weekday == DateTime.sunday;
                          return Center(
                            child: Text(
                              text,
                              style: TextStyle(
                                color: isSunday
                                    ? Colors.redAccent
                                    : theme.colorScheme.onSurfaceVariant,
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                              ),
                            ),
                          );
                        },
                      ),
                      selectedDayPredicate: (day) =>
                          isSameDay(loaded.selectedDay, day),
                      onDaySelected: (selectedDay, focusedDay) {
                        setState(() {
                          _focusedDay = focusedDay;
                        });
                        context
                            .read<TimetableBloc>()
                            .add(DaySelectedEvent(selectedDay));
                      },
                      onFormatChanged: (format) {
                        setState(() {
                          _calendarFormat = format;
                        });
                      },
                      eventLoader: (day) {
                        final dayOnly = DateTime(day.year, day.month, day.day);
                        return loaded.allSlots.where((s) {
                          if (s.isDeleted || s.dayOfWeek != day.weekday) return false;
                          final startOnly = DateTime(
                              s.termStart.year, s.termStart.month, s.termStart.day);
                          final endOnly = DateTime(
                              s.termEnd.year, s.termEnd.month, s.termEnd.day);
                          return !dayOnly.isBefore(startOnly) &&
                              !dayOnly.isAfter(endOnly);
                        }).toList();
                      },
                      calendarStyle: CalendarStyle(
                        todayDecoration: BoxDecoration(
                          color: theme.colorScheme.primary.withValues(alpha: 0.3),
                          shape: BoxShape.circle,
                        ),
                        selectedDecoration: BoxDecoration(
                          color: theme.colorScheme.primary,
                            shape: BoxShape.circle,
                        ),
                        markerDecoration: BoxDecoration(
                          color: theme.colorScheme.secondary,
                          shape: BoxShape.circle,
                        ),
                      ),
                      onHeaderTapped: (focusedDay) {
                        _pickYearMonth(context, focusedDay);
                      },
                      headerStyle: HeaderStyle(
                        formatButtonVisible: false,
                        titleCentered: true,
                        titleTextFormatter: (date, locale) =>
                            'Tháng ${date.month} năm ${date.year}',
                      ),
                    ),
                  ),
                ),

                // 2. Thẻ học nhanh / Smart Capsule (Chỉ hiện khi xem ngày hôm nay)
                if (isSameDay(loaded.selectedDay, DateTime.now()))
                  QuickStudyCard(
                    nextSlot: loaded.nextUpcomingSlot,
                    minutesUntilNextSlot: loaded.minutesUntilNextSlot,
                    todaySlotsCount: loaded.daySlots.length,
                    subjectsMap: loaded.subjectsMap,
                  ),

                if (widget.syncedData != null) ...[
                  Card(
                    elevation: 0,
                    margin: const EdgeInsets.only(bottom: 8),
                    color: theme.colorScheme.primaryContainer.withValues(alpha: 0.6),
                    child: Padding(
                      padding: const EdgeInsets.all(10.0),
                      child: Row(
                        children: [
                          Icon(Icons.cloud_done_rounded, color: theme.colorScheme.primary, size: 20),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Đã đồng bộ học kỳ: ${widget.syncedData!['termId'] ?? '2026-1'}',
                              style: theme.textTheme.bodyMedium?.copyWith(
                                fontWeight: FontWeight.bold,
                                color: theme.colorScheme.onPrimaryContainer,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],

                const SizedBox(height: 6),

                // 3. Tiêu đề danh sách ca học
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Lịch học ${_formatWeekday(loaded.selectedDay.weekday)}',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.secondaryContainer,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        '${loaded.daySlots.length} ca học',
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: theme.colorScheme.onSecondaryContainer,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),

                // 4. Danh sách các thẻ ca học
                if (loaded.daySlots.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 40.0),
                    child: Center(
                      child: Column(
                        children: [
                          Icon(
                            Icons.event_busy_outlined,
                            size: 48,
                            color: theme.colorScheme.outline,
                          ),
                          const SizedBox(height: 12),
                          Text(
                            isSameDay(loaded.selectedDay, DateTime.now())
                                ? AppStrings.noClassToday
                                : AppStrings.noClassSelectedDate,
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                          if (loaded.allSlots.isNotEmpty) ...[
                            const SizedBox(height: 8),
                            Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 24.0),
                              child: Text(
                                'Bạn có ${loaded.allSlots.length} ca học trong tuần. Hãy chạm vào ngày có chấm tròn trên lịch để xem.',
                                textAlign: TextAlign.center,
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: theme.colorScheme.primary,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  )
                else
                  ...loaded.daySlots.map(
                    (slot) => _buildSlotCard(
                       context,
                       slot,
                       loaded.subjectsMap[slot.subjectId],
                       loaded.slotReminders[slot.id] ?? true,
                     ),
                  ),

                const SizedBox(height: 24),
              ],
            ),
          );
        },
      ),
      floatingActionButton: _isGridView
          ? null
          : FloatingActionButton.extended(
              key: const ValueKey('add_slot_fab'),
              heroTag: null,
              onPressed: () => _showAddSlotModal(context),
              icon: const Icon(Icons.add),
              label: const Text(AppStrings.addSlot),
            ),
    );
  }

  Widget _buildSlotCard(
    BuildContext context,
    TimetableSlot slot,
    Subject? subject,
    bool isReminderActive,
  ) {
    final theme = Theme.of(context);
    final subjectColor =
        subject != null ? Color(subject.colorArgb) : theme.colorScheme.primary;

    final durationMin = slot.endMin - slot.startMin;
    final durHours = durationMin ~/ 60;
    final durMins = durationMin % 60;
    final durationText = durHours > 0
        ? (durMins > 0 ? '$durHours h $durMins p' : '$durHours tiếng')
        : '$durMins phút';

    final roomDisplay =
        slot.room.trim().isEmpty ? 'Chưa xếp phòng' : 'Phòng ${slot.room}';

    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: theme.colorScheme.outlineVariant.withValues(alpha: 0.6),
          width: 1,
        ),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => context.push(Routes.slotDetailRoute(slot.id)),
        child: Padding(
          padding: const EdgeInsets.all(14.0),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // 1. Dải màu nổi bật cạnh trái
              Container(
                width: 5,
                height: 56,
                decoration: BoxDecoration(
                  color: subjectColor,
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
              const SizedBox(width: 12),

              // 2. Khung giờ học to, trực quan
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      slot.startTimeFormatted,
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: theme.colorScheme.onSurface,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      slot.endTimeFormatted,
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      durationText,
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        color: theme.colorScheme.primary,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 14),

              // 3. Thông tin môn học & địa điểm phòng/tòa
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      subject?.name ?? slot.subjectId,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 6,
                      runSpacing: 4,
                      children: [
                        // Badge phòng học có chữ rõ ràng
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: slot.room.trim().isEmpty
                                ? theme.colorScheme.surfaceContainerHighest
                                : theme.colorScheme.primaryContainer.withValues(alpha: 0.4),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.meeting_room_outlined,
                                size: 14,
                                color: theme.colorScheme.primary,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                roomDisplay,
                                style: theme.textTheme.labelSmall?.copyWith(
                                  color: theme.colorScheme.onSurface,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                        // Badge tòa nhà
                        if (slot.buildingId != null &&
                            slot.buildingId!.isNotEmpty)
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: theme.colorScheme.surfaceContainerHighest
                                  .withValues(alpha: 0.6),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.business_outlined,
                                  size: 14,
                                  color: theme.colorScheme.outline,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  'Tòa ${slot.buildingId}',
                                  style: theme.textTheme.labelSmall?.copyWith(
                                    color: theme.colorScheme.onSurfaceVariant,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),

              // 4. Switch thông báo gọn gàng
              Transform.scale(
                scale: 0.85,
                child: Switch(
                  value: isReminderActive,
                  onChanged: (active) {
                    context
                        .read<TimetableBloc>()
                        .add(ToggleSlotReminderEvent(slot.id));
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _formatWeekday(int weekday) {
    switch (weekday) {
      case DateTime.monday:
        return 'Thứ Hai';
      case DateTime.tuesday:
        return 'Thứ Ba';
      case DateTime.wednesday:
        return 'Thứ Tư';
      case DateTime.thursday:
        return 'Thứ Năm';
      case DateTime.friday:
        return 'Thứ Sáu';
      case DateTime.saturday:
        return 'Thứ Bảy';
      case DateTime.sunday:
        return 'Chủ Nhật';
      default:
        return '';
    }
  }

  Future<void> _showAddSlotModal(BuildContext context) async {
    final bloc = context.read<TimetableBloc>();
    final currentSelectedDay = bloc.state is TimetableLoaded
        ? (bloc.state as TimetableLoaded).selectedDay
        : _focusedDay;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (bottomSheetContext) => AddSlotBottomSheet(
        initialDate: currentSelectedDay,
        onSave: ({
          required String subjectName,
          required String room,
          String? building,
          required DateTime startDate,
          required TimeOfDay startTime,
          required TimeOfDay endTime,
          required int repeatWeeks,
        }) async {
          await _handleSaveSlot(
            subjectName: subjectName,
            room: room,
            building: building,
            startDate: startDate,
            startTime: startTime,
            endTime: endTime,
            repeatWeeks: repeatWeeks,
          );
        },
      ),
    );
  }

  Future<void> _handleSaveSlot({
    required String subjectName,
    required String room,
    String? building,
    required DateTime startDate,
    required TimeOfDay startTime,
    required TimeOfDay endTime,
    required int repeatWeeks,
  }) async {
    final repo = getIt<TimetableRepository>();
    final existingSubjects = await repo.getSubjects();

    Subject? subject = existingSubjects.cast<Subject?>().firstWhere(
      (s) =>
          s != null &&
          s.name.trim().toLowerCase() == subjectName.trim().toLowerCase(),
      orElse: () => null,
    );

    final now = DateTime.now();
    if (subject == null) {
      final subId = const Uuid().v4();
      final cleanName = subjectName.replaceAll(' ', '');
      final code = cleanName.length >= 3
          ? cleanName
              .substring(0, math.min(6, cleanName.length))
              .toUpperCase()
          : 'MH${now.millisecondsSinceEpoch % 1000}';
      subject = Subject(
        id: subId,
        code: code,
        name: subjectName,
        credits: 3,
        colorArgb: 0xFF1E88E5,
        createdAt: now,
        updatedAt: now,
      );
      await repo.saveSubject(subject);
    }

    final startMin = startTime.hour * 60 + startTime.minute;
    final endMin = endTime.hour * 60 + endTime.minute;
    final slotsToSave = <TimetableSlot>[];

    for (int i = 0; i < repeatWeeks; i++) {
      final currentDate = startDate.add(Duration(days: 7 * i));
      final dateOnly =
          DateTime(currentDate.year, currentDate.month, currentDate.day);

      slotsToSave.add(
        TimetableSlot(
          id: const Uuid().v4(),
          subjectId: subject.id,
          dayOfWeek: currentDate.weekday,
          startMin: startMin,
          endMin: endMin,
          room: room,
          buildingId: building,
          termStart: dateOnly,
          termEnd: dateOnly,
          source: 'user',
          updatedAt: now,
        ),
      );
    }

    await repo.saveSlots(slotsToSave);

    if (!mounted) return;

    setState(() {
      _focusedDay = startDate;
    });
    context.read<TimetableBloc>().add(DaySelectedEvent(startDate));

    final msg = repeatWeeks > 1
        ? 'Đã thêm $repeatWeeks ca học môn "$subjectName" thành công!'
        : 'Đã thêm lịch "$subjectName" thành công!';
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: Colors.green,
        duration: const Duration(seconds: 2),
      ),
    );
  }
}

/// Form nhập ca học/sự kiện trượt từ dưới lên (BottomSheet) với tùy chọn sự kiện 1 lần hoặc lặp tuần chuẩn Google Calendar.
class AddSlotBottomSheet extends StatefulWidget {
  final DateTime initialDate;
  final Future<void> Function({
    required String subjectName,
    required String room,
    String? building,
    required DateTime startDate,
    required TimeOfDay startTime,
    required TimeOfDay endTime,
    required int repeatWeeks,
  }) onSave;

  const AddSlotBottomSheet({
    super.key,
    required this.initialDate,
    required this.onSave,
  });

  @override
  State<AddSlotBottomSheet> createState() => _AddSlotBottomSheetState();
}

class _AddSlotBottomSheetState extends State<AddSlotBottomSheet> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _subjectController;
  late final TextEditingController _roomController;
  late final TextEditingController _buildingController;

  late DateTime _startDate;
  TimeOfDay _startTime = const TimeOfDay(hour: 7, minute: 30);
  TimeOfDay _endTime = const TimeOfDay(hour: 9, minute: 30);
  bool _repeatWeekly = false;
  int _repeatWeeks = 5;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _subjectController = TextEditingController();
    _roomController = TextEditingController();
    _buildingController = TextEditingController();
    _startDate = widget.initialDate;
  }

  @override
  void dispose() {
    _subjectController.dispose();
    _roomController.dispose();
    _buildingController.dispose();
    super.dispose();
  }

  String _formatWeekdayName(int weekday) {
    switch (weekday) {
      case DateTime.monday:
        return 'Thứ Hai';
      case DateTime.tuesday:
        return 'Thứ Ba';
      case DateTime.wednesday:
        return 'Thứ Tư';
      case DateTime.thursday:
        return 'Thứ Năm';
      case DateTime.friday:
        return 'Thứ Sáu';
      case DateTime.saturday:
        return 'Thứ Bảy';
      case DateTime.sunday:
        return 'Chủ Nhật';
      default:
        return '';
    }
  }

  String _formatTime(TimeOfDay t) {
    final h = t.hour.toString().padLeft(2, '0');
    final m = t.minute.toString().padLeft(2, '0');
    return '$h:$m';
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _startDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2035),
    );
    if (picked != null) {
      setState(() {
        _startDate = picked;
      });
    }
  }

  Future<void> _pickStartTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _startTime,
    );
    if (picked != null) {
      setState(() {
        _startTime = picked;
      });
    }
  }

  Future<void> _pickEndTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _endTime,
    );
    if (picked != null) {
      setState(() {
        _endTime = picked;
      });
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    final startMinutes = _startTime.hour * 60 + _startTime.minute;
    final endMinutes = _endTime.hour * 60 + _endTime.minute;
    if (startMinutes >= endMinutes) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(AppStrings.invalidTimeRange),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() {
      _isSaving = true;
    });

    final actualRepeatWeeks = _repeatWeekly ? _repeatWeeks : 1;

    try {
      await widget.onSave(
        subjectName: _subjectController.text.trim(),
        room: _roomController.text.trim(),
        building: _buildingController.text.trim().isNotEmpty
            ? _buildingController.text.trim()
            : null,
        startDate: _startDate,
        startTime: _startTime,
        endTime: _endTime,
        repeatWeeks: actualRepeatWeeks,
      );
      if (mounted) {
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Không thể lưu ca học: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final endDate = _startDate.add(Duration(days: 7 * (_repeatWeeks - 1)));

    return Padding(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 12,
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
      ),
      child: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Thanh kéo drag handle
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.outlineVariant,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),

              // Tiêu đề BottomSheet
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.primaryContainer,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      _repeatWeekly
                          ? Icons.event_repeat_rounded
                          : Icons.event_note_rounded,
                      color: theme.colorScheme.primary,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          AppStrings.addSlotTitle,
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          AppStrings.addSlotSubtitle,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.outline,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Nhập Tên môn học hoặc Sự kiện
              TextFormField(
                key: const ValueKey('add_slot_subject_field'),
                controller: _subjectController,
                decoration: const InputDecoration(
                  labelText: AppStrings.eventTitleLabel,
                  hintText: AppStrings.eventTitleHint,
                  prefixIcon: Icon(Icons.edit_calendar_rounded),
                  border: OutlineInputBorder(),
                ),
                validator: (val) {
                  if (val == null || val.trim().isEmpty) {
                    return 'Vui lòng nhập tên môn học hoặc sự kiện';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 12),

              // Hàng Phòng học & Tòa nhà
              Row(
                children: [
                  Expanded(
                    flex: 3,
                    child: TextFormField(
                      key: const ValueKey('add_slot_room_field'),
                      controller: _roomController,
                      decoration: const InputDecoration(
                        labelText: 'Phòng học / Địa điểm (tùy chọn)',
                        hintText: 'VD: H2.304 hoặc Online',
                        prefixIcon: Icon(Icons.room_outlined),
                        border: OutlineInputBorder(),
                      ),
                      validator: null,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 2,
                    child: TextFormField(
                      key: const ValueKey('add_slot_building_field'),
                      controller: _buildingController,
                      decoration: const InputDecoration(
                        labelText: 'Tòa nhà',
                        hintText: 'VD: H2',
                        prefixIcon: Icon(Icons.business_outlined),
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // Ngày diễn ra / bắt đầu
              InkWell(
                key: const ValueKey('add_slot_date_picker'),
                onTap: _pickDate,
                borderRadius: BorderRadius.circular(8),
                child: InputDecorator(
                  decoration: InputDecoration(
                    labelText:
                        _repeatWeekly ? 'Ngày bắt đầu *' : 'Ngày diễn ra *',
                    prefixIcon: const Icon(Icons.calendar_today_rounded),
                    suffixIcon: const Icon(Icons.arrow_drop_down),
                    border: const OutlineInputBorder(),
                  ),
                  child: Text(
                    '${DateFormat('dd/MM/yyyy').format(_startDate)} (${_formatWeekdayName(_startDate.weekday)})',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),

              // Khung chọn Giờ bắt đầu & Giờ kết thúc
              Row(
                children: [
                  Expanded(
                    child: InkWell(
                      key: const ValueKey('add_slot_start_time_picker'),
                      onTap: _pickStartTime,
                      borderRadius: BorderRadius.circular(8),
                      child: InputDecorator(
                        decoration: const InputDecoration(
                          labelText: 'Giờ bắt đầu *',
                          prefixIcon: Icon(Icons.access_time_rounded),
                          border: OutlineInputBorder(),
                        ),
                        child: Text(
                          _formatTime(_startTime),
                          style: theme.textTheme.bodyMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: InkWell(
                      key: const ValueKey('add_slot_end_time_picker'),
                      onTap: _pickEndTime,
                      borderRadius: BorderRadius.circular(8),
                      child: InputDecorator(
                        decoration: const InputDecoration(
                          labelText: 'Giờ kết thúc *',
                          prefixIcon: Icon(Icons.access_time_filled_rounded),
                          border: OutlineInputBorder(),
                        ),
                        child: Text(
                          _formatTime(_endTime),
                          style: theme.textTheme.bodyMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // SwitchListTile: Lặp lại hàng tuần (mặc định tắt)
              Card(
                elevation: 0,
                color: theme.colorScheme.surfaceContainerLow,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                  side: BorderSide(
                    color: theme.colorScheme.outlineVariant.withValues(alpha: 0.6),
                  ),
                ),
                child: SwitchListTile(
                  key: const ValueKey('add_slot_repeat_switch'),
                  value: _repeatWeekly,
                  onChanged: (val) {
                    setState(() {
                      _repeatWeekly = val;
                    });
                  },
                  secondary: Icon(
                    Icons.repeat_rounded,
                    color: _repeatWeekly
                        ? theme.colorScheme.primary
                        : theme.colorScheme.outline,
                  ),
                  title: const Text(
                    AppStrings.repeatWeekly,
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                  subtitle: const Text(
                    AppStrings.repeatWeeklySubtitle,
                    style: TextStyle(fontSize: 12),
                  ),
                ),
              ),
              const SizedBox(height: 12),

              // Khung chọn số tuần khi bật lặp lại
              if (_repeatWeekly) ...[
                DropdownButtonFormField<int>(
                  key: const ValueKey('add_slot_repeat_weeks_dropdown'),
                  initialValue: _repeatWeeks < 2 ? 2 : _repeatWeeks,
                  decoration: const InputDecoration(
                    labelText: 'Số tuần lặp lại (Google Calendar) *',
                    prefixIcon: Icon(Icons.repeat_on_rounded),
                    border: OutlineInputBorder(),
                  ),
                  items: List.generate(14, (index) => index + 2).map((week) {
                    return DropdownMenuItem<int>(
                      value: week,
                      child: Text('$week tuần ($week ca học)'),
                    );
                  }).toList(),
                  onChanged: (val) {
                    if (val != null) {
                      setState(() {
                        _repeatWeeks = val;
                      });
                    }
                  },
                ),
                const SizedBox(height: 12),
              ],

              // Hộp tóm tắt chu kỳ học / sự kiện
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surfaceContainerHighest
                      .withValues(alpha: 0.5),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color:
                        theme.colorScheme.outlineVariant.withValues(alpha: 0.5),
                  ),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      Icons.info_outline_rounded,
                      size: 18,
                      color: theme.colorScheme.primary,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _repeatWeekly
                            ? 'Sẽ tạo $_repeatWeeks ca học vào lúc ${_formatTime(_startTime)} - ${_formatTime(_endTime)} mỗi ${_formatWeekdayName(_startDate.weekday)} từ ${DateFormat('dd/MM/yyyy').format(_startDate)} đến ${DateFormat('dd/MM/yyyy').format(endDate)}.'
                            : 'Sẽ tạo 1 lịch sự kiện vào lúc ${_formatTime(_startTime)} - ${_formatTime(_endTime)} ngày ${DateFormat('dd/MM/yyyy').format(_startDate)} (${_formatWeekdayName(_startDate.weekday)}).',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Nút Lưu
              FilledButton.icon(
                key: const ValueKey('add_slot_submit_button'),
                onPressed: _isSaving ? null : _submit,
                icon: _isSaving
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.check_rounded),
                label: Text(
                  _isSaving
                      ? 'Đang lưu trữ...'
                      : (_repeatWeekly ? 'Lưu lịch lặp lại' : 'Lưu lịch sự kiện'),
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

