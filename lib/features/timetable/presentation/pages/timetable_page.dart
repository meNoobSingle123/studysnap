import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:table_calendar/table_calendar.dart';

import '../../../../core/di/injection.dart';
import '../../../../core/errors/app_exception.dart';
import '../../../../core/l10n/strings.dart';
import '../../../../core/router/routes.dart';
import '../../data/datasources/timetable_remote_data_source.dart';
import '../../domain/entities/subject.dart';
import '../../domain/entities/timetable_slot.dart';
import '../../domain/usecases/get_subjects_usecase.dart';
import '../../domain/usecases/get_timetable_slots_usecase.dart';
import '../bloc/timetable_bloc.dart';

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

      if (blocContext != null && blocContext.mounted) {
        blocContext.read<TimetableBloc>().add(DaySelectedEvent(DateTime.now()));
      }

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
    if (widget.remoteDataSource != null) {
      return _buildTeamSyncView(context);
    }

    return BlocProvider(
      create: (context) => TimetableBloc(
        slotsUseCase: getIt<GetTimetableSlotsUseCase>(),
        subjectsUseCase: getIt<GetSubjectsUseCase>(),
      )..add(DaySelectedEvent(DateTime.now())),
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
  CalendarFormat _calendarFormat = CalendarFormat.week;
  DateTime _focusedDay = DateTime.now();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text(AppStrings.timetableTitle),
        actions: [
          // Nút đồng bộ với server
          IconButton(
            tooltip: AppStrings.syncTimetable,
            icon: widget.isSyncing
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.sync),
            onPressed: widget.isSyncing ? null : widget.onSync,
          ),
          // Nút xuất PDF Thời khóa biểu (S09)
          IconButton(
            tooltip: AppStrings.pdfExportTitle,
            icon: const Icon(Icons.picture_as_pdf_outlined),
            onPressed: () => context.push(Routes.pdfExport),
          ),
          // Nút mở nhanh Dự phóng GPA (S04)
          IconButton(
            tooltip: AppStrings.gpaProjectionTitle,
            icon: const Icon(Icons.calculate_outlined),
            onPressed: () => context.push(Routes.gpaProjection),
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

          return RefreshIndicator(
            onRefresh: () async {
              widget.onSync();
              context
                  .read<TimetableBloc>()
                  .add(DaySelectedEvent(loaded.selectedDay));
              await Future.delayed(const Duration(milliseconds: 600));
            },
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              children: [
                if (widget.syncedData != null) ...[
                  const SizedBox(height: 8),
                  Card(
                    elevation: 0,
                    color: theme.colorScheme.primaryContainer.withValues(alpha: 0.6),
                    child: Padding(
                      padding: const EdgeInsets.all(12.0),
                      child: Row(
                        children: [
                          Icon(Icons.cloud_done_rounded, color: theme.colorScheme.primary),
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

                const SizedBox(height: 8),

                // 1. Table Calendar (Chủ đề 2: Lịch tuần / tháng)
                Card(
                  elevation: 0,
                  color: theme.colorScheme.surfaceContainerLow,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: TableCalendar<TimetableSlot>(
                      firstDay: DateTime(2026, 1, 1),
                      lastDay: DateTime(2027, 12, 31),
                      focusedDay: _focusedDay,
                      calendarFormat: _calendarFormat,
                      startingDayOfWeek: StartingDayOfWeek.monday,
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
                        return loaded.allSlots
                            .where((s) => s.dayOfWeek == day.weekday)
                            .toList();
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
                      headerStyle: const HeaderStyle(
                        formatButtonVisible: true,
                        titleCentered: true,
                        formatButtonShowsNext: false,
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 16),

                // 2. Thẻ Đếm ngược ca học tiếp theo trong ngày
                if (loaded.nextUpcomingSlot != null &&
                    loaded.minutesUntilNextSlot != null)
                  _buildCountdownCard(
                    context,
                    loaded.nextUpcomingSlot!,
                    loaded.minutesUntilNextSlot!,
                    loaded.subjectsMap,
                  ),

                const SizedBox(height: 16),

                // 3. Tiêu đề danh sách ca học
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Danh sách ca học (${loaded.daySlots.length})',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      _formatWeekday(loaded.selectedDay.weekday),
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.primary,
                        fontWeight: FontWeight.w600,
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
                            AppStrings.noClassToday,
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
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
    );
  }

  Widget _buildCountdownCard(
    BuildContext context,
    TimetableSlot slot,
    int minutesDiff,
    Map<String, Subject> subjectsMap,
  ) {
    final theme = Theme.of(context);
    final subject = subjectsMap[slot.subjectId];
    final hours = minutesDiff ~/ 60;
    final mins = minutesDiff % 60;

    final countdownStr = hours > 0 ? '$hours giờ $mins phút' : '$mins phút';

    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: () => context.push(Routes.slotDetailRoute(slot.id)),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              theme.colorScheme.primaryContainer,
              theme.colorScheme.surfaceContainerHigh,
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: theme.colorScheme.primary,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.access_time_filled_rounded,
                color: Colors.white,
                size: 28,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        AppStrings.nextClassCountdown,
                        style: theme.textTheme.labelMedium?.copyWith(
                          color: theme.colorScheme.onPrimaryContainer,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.redAccent.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          countdownStr,
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: Colors.redAccent,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subject?.name ?? 'Môn học (${slot.subjectId})',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${slot.startTimeFormatted} - ${slot.endTimeFormatted} | Phòng ${slot.room}',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.outline,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right_rounded),
          ],
        ),
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
    final subjectColor = subject != null ? Color(subject.colorArgb) : Colors.blue;

    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: theme.colorScheme.outlineVariant.withValues(alpha: 0.5),
        ),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => context.push(Routes.slotDetailRoute(slot.id)),
        child: Padding(
          padding: const EdgeInsets.all(12.0),
          child: Row(
            children: [
              // Vạch màu môn học
              Container(
                width: 4,
                height: 52,
                decoration: BoxDecoration(
                  color: subjectColor,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(width: 12),

              // Thông tin giờ học
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    slot.startTimeFormatted,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    slot.endTimeFormatted,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.outline,
                    ),
                  ),
                ],
              ),
              const SizedBox(width: 16),

              // Thông tin môn học & phòng
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      subject?.name ?? slot.subjectId,
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Icon(
                          Icons.room_outlined,
                          size: 14,
                          color: theme.colorScheme.outline,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          slot.room,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.outline,
                          ),
                        ),
                        if (slot.buildingId != null) ...[
                          const SizedBox(width: 8),
                          Icon(
                            Icons.business_outlined,
                            size: 14,
                            color: theme.colorScheme.outline,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            slot.buildingId!,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.outline,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),

              // Nút bật/tắt nhắc giờ nhanh
              Switch(
                value: isReminderActive,
                onChanged: (active) {
                  context
                      .read<TimetableBloc>()
                      .add(ToggleSlotReminderEvent(slot.id));
                },
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
}

