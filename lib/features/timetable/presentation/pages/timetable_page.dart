import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:uuid/uuid.dart';

import '../../../../core/di/injection.dart';
import '../../../../core/errors/app_exception.dart';
import '../../../../core/l10n/strings.dart';
import '../../../../core/router/routes.dart';
import '../../data/datasources/timetable_remote_data_source.dart';
import '../../domain/entities/subject.dart';
import '../../domain/entities/timetable_slot.dart';
import '../../domain/repositories/timetable_repository.dart';
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
      floatingActionButton: FloatingActionButton.extended(
        key: const ValueKey('add_slot_fab'),
        heroTag: null,
        onPressed: () => _showAddSlotModal(context),
        icon: const Icon(Icons.add),
        label: const Text('Thêm ca học'),
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
            context: context,
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
    required BuildContext context,
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

    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Đã thêm $repeatWeeks ca học môn "$subjectName" thành công!',
          ),
          backgroundColor: Colors.green,
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }
}

/// Form nhập ca học trượt từ dưới lên (BottomSheet) với thuật toán lặp tuần chuẩn Google Calendar.
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
      firstDate: DateTime(2025),
      lastDate: DateTime(2030),
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
          content: Text('Giờ kết thúc phải sau giờ bắt đầu'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() {
      _isSaving = true;
    });

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
        repeatWeeks: _repeatWeeks,
      );
      if (mounted) {
        Navigator.of(context).pop();
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
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
                      Icons.event_repeat_rounded,
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
                          'Thêm ca học lặp lại',
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          'Chuẩn Google Calendar (lặp theo tuần)',
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

              // Nhập Tên môn học
              TextFormField(
                key: const ValueKey('add_slot_subject_field'),
                controller: _subjectController,
                decoration: const InputDecoration(
                  labelText: 'Tên môn học *',
                  hintText: 'VD: Lập trình Flutter',
                  prefixIcon: Icon(Icons.menu_book_rounded),
                  border: OutlineInputBorder(),
                ),
                validator: (val) {
                  if (val == null || val.trim().isEmpty) {
                    return 'Vui lòng nhập tên môn học';
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
                        labelText: 'Phòng học *',
                        hintText: 'VD: H2.304',
                        prefixIcon: Icon(Icons.room_outlined),
                        border: OutlineInputBorder(),
                      ),
                      validator: (val) {
                        if (val == null || val.trim().isEmpty) {
                          return 'Vui lòng nhập phòng';
                        }
                        return null;
                      },
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

              // Ngày bắt đầu
              InkWell(
                key: const ValueKey('add_slot_date_picker'),
                onTap: _pickDate,
                borderRadius: BorderRadius.circular(8),
                child: InputDecorator(
                  decoration: const InputDecoration(
                    labelText: 'Ngày bắt đầu *',
                    prefixIcon: Icon(Icons.calendar_today_rounded),
                    suffixIcon: Icon(Icons.arrow_drop_down),
                    border: OutlineInputBorder(),
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

              // Dropdown số tuần học lặp lại
              DropdownButtonFormField<int>(
                key: const ValueKey('add_slot_repeat_weeks_dropdown'),
                initialValue: _repeatWeeks,
                decoration: const InputDecoration(
                  labelText: 'Số tuần lặp lại (Google Calendar) *',
                  prefixIcon: Icon(Icons.repeat_rounded),
                  border: OutlineInputBorder(),
                ),
                items: List.generate(15, (index) => index + 1).map((week) {
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

              // Hộp tóm tắt chu kỳ học
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
                        'Sẽ tạo $_repeatWeeks ca học vào lúc ${_formatTime(_startTime)} - ${_formatTime(_endTime)} mỗi ${_formatWeekdayName(_startDate.weekday)} từ ${DateFormat('dd/MM/yyyy').format(_startDate)} đến ${DateFormat('dd/MM/yyyy').format(endDate)}.',
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
                  _isSaving ? 'Đang lưu trữ...' : 'Lưu ca học',
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

