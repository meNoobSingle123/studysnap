import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:table_calendar/table_calendar.dart';
import '../../../../core/di/injection.dart';
import '../../../../core/l10n/strings.dart';
import '../../../../core/router/routes.dart';
import '../../domain/entities/subject.dart';
import '../../domain/entities/timetable_slot.dart';
import '../../domain/usecases/get_subjects_usecase.dart';
import '../../domain/usecases/get_timetable_slots_usecase.dart';
import '../bloc/timetable_bloc.dart';

class TimetablePage extends StatelessWidget {
  const TimetablePage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => TimetableBloc(
        slotsUseCase: getIt<GetTimetableSlotsUseCase>(),
        subjectsUseCase: getIt<GetSubjectsUseCase>(),
      )..add(const InitTimetableSubscription()),
      child: const _TimetableView(),
    );
  }
}

class _TimetableView extends StatefulWidget {
  const _TimetableView();

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
              // Kéo để làm mới: phát sự kiện đồng bộ
              context
                  .read<TimetableBloc>()
                  .add(DaySelectedEvent(loaded.selectedDay));
              await Future.delayed(const Duration(milliseconds: 600));
            },
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              children: [
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
            theme.colorScheme.primary,
            theme.colorScheme.primaryContainer,
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: theme.colorScheme.primary.withValues(alpha: 0.25),
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
              color: Colors.white.withValues(alpha: 0.2),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.timer_outlined,
              color: Colors.white,
              size: 28,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Ca học kế tiếp: ${subject?.name ?? slot.subjectId}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Phòng ${slot.room} • Bắt đầu sau $countdownStr',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.9),
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    ),
  );
  }

  Widget _buildSlotCard(
    BuildContext context,
    TimetableSlot slot,
    Subject? subject,
    bool isReminderOn,
  ) {
    final theme = Theme.of(context);
    final subjectColor = subject != null
        ? Color(subject.colorArgb)
        : theme.colorScheme.primary;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(
          color: theme.colorScheme.outlineVariant.withValues(alpha: 0.5),
        ),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () {
          // Mở màn hình S03: Chi tiết ca học
          context.push(Routes.slotDetailRoute(slot.id));
        },
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Row(
            children: [
              // Thanh màu nhận diện môn học
              Container(
                width: 5,
                height: 52,
                decoration: BoxDecoration(
                  color: subjectColor,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
              const SizedBox(width: 14),

              // Thông tin ca học
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      subject?.name ?? 'Môn học (${slot.subjectId})',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Icon(
                          Icons.access_time_rounded,
                          size: 15,
                          color: theme.colorScheme.outline,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          '${slot.startTimeFormatted} - ${slot.endTimeFormatted}',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(width: 14),
                        Icon(
                          Icons.meeting_room_outlined,
                          size: 15,
                          color: theme.colorScheme.outline,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          'Phòng ${slot.room}',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              // Switch toggle nhắc nhở nhanh cho ca học
              IconButton(
                tooltip: isReminderOn ? 'Tắt nhắc giờ' : 'Bật nhắc giờ',
                icon: Icon(
                  isReminderOn
                      ? Icons.notifications_active_rounded
                      : Icons.notifications_off_outlined,
                  color: isReminderOn
                      ? theme.colorScheme.primary
                      : theme.colorScheme.outline,
                ),
                onPressed: () {
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

  String _formatWeekday(int day) {
    switch (day) {
      case 1:
        return 'Thứ Hai';
      case 2:
        return 'Thứ Ba';
      case 3:
        return 'Thứ Tư';
      case 4:
        return 'Thứ Năm';
      case 5:
        return 'Thứ Sáu';
      case 6:
        return 'Thứ Bảy';
      case 7:
        return 'Chủ Nhật';
      default:
        return '';
    }
  }
}
