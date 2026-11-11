import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';

import '../../../../core/di/injection.dart';
import '../../domain/entities/subject.dart';
import '../../domain/entities/timetable_slot.dart';
import '../../domain/repositories/timetable_repository.dart';

/// Bảng lưới Thời khóa biểu theo trục từng giờ (Hourly Timeline Grid, 06:00 - 23:00+).
///
/// - Hiển thị chính xác từng phút (VD: 13:30 - 16:00) và cả ca tối (19:30 - 22:00+).
/// - Lọc đúng các ca học thuộc tuần đang xem (`Tuần trước` / `Tuần này` / `Tuần sau`).
/// - Ca học không bật lặp lại chỉ hiển thị ở đúng 1 ngày đó, không tự lặp sang tuần sau.
class TimetableGridView extends StatefulWidget {
  final List<TimetableSlot> allSlots;
  final Map<String, Subject> subjectsMap;
  final VoidCallback onDataChanged;
  final DateTime? initialFocusDate;
  final int todayResetVersion;
  final DateTime? nowForTest;

  const TimetableGridView({
    super.key,
    required this.allSlots,
    required this.subjectsMap,
    required this.onDataChanged,
    this.initialFocusDate,
    this.todayResetVersion = 0,
    this.nowForTest,
  });

  @override
  State<TimetableGridView> createState() => _TimetableGridViewState();
}

class _SlotGroup {
  final TimetableSlot primary;
  final List<TimetableSlot> groupSlots;
  int laneIndex = 0;
  int laneCount = 1;

  _SlotGroup({
    required this.primary,
    required this.groupSlots,
  });
}

class _DayOption {
  final int day;
  final String fullLabel;
  final String shortLabel;

  const _DayOption({
    required this.day,
    required this.fullLabel,
    required this.shortLabel,
  });
}

class _TimetableGridViewState extends State<TimetableGridView> {
  static const double _hourHeight = 64.0;
  static const double _timeAxisWidth = 58.0;
  static const double _dayColWidth = 114.0;
  static const double _dayColSpacing = 4.0;
  static const double _headerHeight = 56.0;

  static const List<_DayOption> _days = [
    _DayOption(day: 1, fullLabel: 'Thứ 2', shortLabel: 'T2'),
    _DayOption(day: 2, fullLabel: 'Thứ 3', shortLabel: 'T3'),
    _DayOption(day: 3, fullLabel: 'Thứ 4', shortLabel: 'T4'),
    _DayOption(day: 4, fullLabel: 'Thứ 5', shortLabel: 'T5'),
    _DayOption(day: 5, fullLabel: 'Thứ 6', shortLabel: 'T6'),
    _DayOption(day: 6, fullLabel: 'Thứ 7', shortLabel: 'T7'),
    _DayOption(day: 7, fullLabel: 'Chủ nhật', shortLabel: 'CN'),
  ];

  late final ScrollController _headerHScroll;
  late final ScrollController _bodyHScroll;
  late final ScrollController _vScroll;

  late DateTime _weekMonday;

  bool _syncingHeader = false;
  bool _syncingBody = false;

  @override
  void initState() {
    super.initState();
    _headerHScroll = ScrollController()..addListener(_onHeaderHScroll);
    _bodyHScroll = ScrollController()..addListener(_onBodyHScroll);
    _vScroll = ScrollController();

    final seedDate = widget.initialFocusDate ?? widget.nowForTest ?? DateTime.now();
    _weekMonday = _mondayOfWeek(seedDate);
  }

  @override
  void didUpdateWidget(covariant TimetableGridView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.todayResetVersion != oldWidget.todayResetVersion) {
      _weekMonday = _mondayOfWeek(widget.nowForTest ?? DateTime.now());
      return;
    }
    final newFocus = widget.initialFocusDate;
    final oldFocus = oldWidget.initialFocusDate;
    if (newFocus != null && newFocus != oldFocus) {
      _weekMonday = _mondayOfWeek(newFocus);
    }
  }

  @override
  void dispose() {
    _headerHScroll.removeListener(_onHeaderHScroll);
    _bodyHScroll.removeListener(_onBodyHScroll);
    _headerHScroll.dispose();
    _bodyHScroll.dispose();
    _vScroll.dispose();
    super.dispose();
  }

  DateTime _dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);

  DateTime _mondayOfWeek(DateTime d) {
    final clean = _dateOnly(d);
    return clean.subtract(Duration(days: clean.weekday - 1));
  }

  DateTime _dateForWeekday(int dayOfWeek) {
    return _weekMonday.add(Duration(days: dayOfWeek - 1));
  }

  void _onHeaderHScroll() {
    if (_syncingHeader || !_bodyHScroll.hasClients) return;
    _syncingBody = true;
    final target =
        _headerHScroll.offset.clamp(0.0, _bodyHScroll.position.maxScrollExtent);
    if ((_bodyHScroll.offset - target).abs() > 0.5) {
      _bodyHScroll.jumpTo(target);
    }
    _syncingBody = false;
  }

  void _onBodyHScroll() {
    if (_syncingBody || !_headerHScroll.hasClients) return;
    _syncingHeader = true;
    final target =
        _bodyHScroll.offset.clamp(0.0, _headerHScroll.position.maxScrollExtent);
    if ((_headerHScroll.offset - target).abs() > 0.5) {
      _headerHScroll.jumpTo(target);
    }
    _syncingHeader = false;
  }

  ({int startHour, int endHour}) _computeHourBounds(
    Map<int, List<_SlotGroup>> dayGroups,
  ) {
    int startHour = 6;
    int endHour = 23;
    for (final groups in dayGroups.values) {
      for (final g in groups) {
        final slot = g.primary;
        final slotStartHour = (slot.startMin ~/ 60).clamp(0, 23);
        final slotEndHour = ((slot.endMin + 59) ~/ 60).clamp(1, 24);
        if (slotStartHour < startHour) startHour = slotStartHour;
        if (slotEndHour > endHour) endHour = slotEndHour;
      }
    }
    if (endHour <= startHour) endHour = math.min(24, startHour + 1);
    return (startHour: startHour, endHour: endHour);
  }

  /// Lọc đúng các ca có hiệu lực trong tuần [_weekMonday .. _weekMonday + 6d],
  /// gom ca trùng và chia cột cạnh nhau nếu có 2 môn khác nhau chồng giờ.
  Map<int, List<_SlotGroup>> _buildPositionedGroupsForDisplayedWeek() {
    final result = <int, List<_SlotGroup>>{};

    for (final d in _days) {
      final colDate = _dateForWeekday(d.day);
      final daySlots = widget.allSlots.where((s) {
        if (s.isDeleted || s.dayOfWeek != d.day || s.endMin <= s.startMin) {
          return false;
        }
        final startOnly = _dateOnly(s.termStart);
        final endOnly = _dateOnly(s.termEnd);
        return !colDate.isBefore(startOnly) && !colDate.isAfter(endOnly);
      }).toList();

      if (daySlots.isEmpty) continue;

      final groupedByKey = <String, List<TimetableSlot>>{};
      for (final slot in daySlots) {
        final key =
            '${slot.subjectId}|${slot.startMin}|${slot.endMin}|${slot.room}';
        groupedByKey.putIfAbsent(key, () => []).add(slot);
      }

      final groups = groupedByKey.values
          .map((list) => _SlotGroup(primary: list.first, groupSlots: list))
          .toList()
        ..sort((a, b) {
          final cmp = a.primary.startMin.compareTo(b.primary.startMin);
          if (cmp != 0) return cmp;
          return a.primary.endMin.compareTo(b.primary.endMin);
        });

      final clusters = <List<_SlotGroup>>[];
      var currentCluster = <_SlotGroup>[];
      int clusterEnd = -1;

      for (final g in groups) {
        if (currentCluster.isEmpty) {
          currentCluster.add(g);
          clusterEnd = g.primary.endMin;
        } else if (g.primary.startMin < clusterEnd) {
          currentCluster.add(g);
          if (g.primary.endMin > clusterEnd) {
            clusterEnd = g.primary.endMin;
          }
        } else {
          clusters.add(currentCluster);
          currentCluster = [g];
          clusterEnd = g.primary.endMin;
        }
      }
      if (currentCluster.isNotEmpty) {
        clusters.add(currentCluster);
      }

      for (final cluster in clusters) {
        final laneEnds = <int>[];
        for (final g in cluster) {
          int placedLane = -1;
          for (int i = 0; i < laneEnds.length; i++) {
            if (laneEnds[i] <= g.primary.startMin) {
              laneEnds[i] = g.primary.endMin;
              placedLane = i;
              break;
            }
          }
          if (placedLane == -1) {
            placedLane = laneEnds.length;
            laneEnds.add(g.primary.endMin);
          }
          g.laneIndex = placedLane;
        }
        final totalLanes = laneEnds.length;
        for (final g in cluster) {
          g.laneCount = totalLanes;
        }
      }

      result[d.day] = groups;
    }

    return result;
  }

  bool _isSlotRecurring(TimetableSlot slot, _SlotGroup? group) {
    final startOnly = _dateOnly(slot.termStart);
    final endOnly = _dateOnly(slot.termEnd);
    final spanDays = endOnly.difference(startOnly).inDays;
    return spanDays >= 6 || (group != null && group.groupSlots.length > 1);
  }

  String _formatHourTick(int hour) {
    return '${hour.toString().padLeft(2, '0')}:00';
  }

  String _formatTimeOfDay(TimeOfDay t) {
    return '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';
  }

  TimeOfDay _minutesToTimeOfDay(int minutes) {
    final clamped = minutes.clamp(0, 23 * 60 + 59);
    return TimeOfDay(hour: clamped ~/ 60, minute: clamped % 60);
  }

  Future<void> _openCellEditor(
    DateTime targetDate, {
    required int initialStartMin,
    required int initialEndMin,
    _SlotGroup? existingGroup,
  }) async {
    final existingSlot = existingGroup?.primary;
    final targetDateOnly = _dateOnly(targetDate);
    final dayOfWeek = targetDateOnly.weekday;
    final theme = Theme.of(context);

    final subjectCtrl = TextEditingController(
      text: existingSlot != null
          ? (widget.subjectsMap[existingSlot.subjectId]?.name ?? '')
          : '',
    );
    final roomCtrl = TextEditingController(text: existingSlot?.room ?? '');
    final buildingCtrl =
        TextEditingController(text: existingSlot?.buildingId ?? '');

    int selectedColorArgb = existingSlot != null
        ? (widget.subjectsMap[existingSlot.subjectId]?.colorArgb ?? 0xFFFFA000)
        : 0xFFFFA000;

    TimeOfDay startTime = _minutesToTimeOfDay(
      existingSlot?.startMin ?? initialStartMin,
    );
    TimeOfDay endTime = _minutesToTimeOfDay(
      existingSlot?.endMin ?? initialEndMin,
    );

    bool repeatWeekly = existingSlot != null
        ? _isSlotRecurring(existingSlot, existingGroup)
        : false;
    int repeatWeeks = 15;
    if (existingSlot != null && repeatWeekly) {
      final diffDays =
          _dateOnly(existingSlot.termEnd).difference(_dateOnly(existingSlot.termStart)).inDays;
      if (diffDays >= 7) {
        repeatWeeks = ((diffDays ~/ 7) + 1).clamp(2, 20);
      } else if (existingGroup != null && existingGroup.groupSlots.length > 1) {
        repeatWeeks = existingGroup.groupSlots.length.clamp(2, 20);
      }
    }

    final selectedDays = <int>{dayOfWeek};
    String? inlineError;

    final targetDateText = DateFormat('dd/MM/yyyy').format(targetDateOnly);
    final dayOptionLabel = _days
        .firstWhere((d) => d.day == dayOfWeek, orElse: () => _days.first)
        .fullLabel;

    final result = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetCtx) {
        return StatefulBuilder(
          builder: (modalContext, setSheetState) {
            final sortedDayNames = _days
                .where((d) => selectedDays.contains(d.day))
                .map((d) => d.fullLabel)
                .join(', ');

            Future<void> pickStart() async {
              final picked = await showTimePicker(
                context: sheetCtx,
                initialTime: startTime,
                helpText: 'Chọn hoặc nhập giờ bắt đầu',
              );
              if (picked == null) return;
              setSheetState(() {
                startTime = picked;
                final newStart = picked.hour * 60 + picked.minute;
                final currentEnd = endTime.hour * 60 + endTime.minute;
                if (currentEnd <= newStart) {
                  endTime = _minutesToTimeOfDay(
                    math.min(newStart + 60, 23 * 60 + 59),
                  );
                }
                inlineError = null;
              });
            }

            Future<void> pickEnd() async {
              final picked = await showTimePicker(
                context: sheetCtx,
                initialTime: endTime,
                helpText: 'Chọn hoặc nhập giờ kết thúc',
              );
              if (picked == null) return;
              setSheetState(() {
                endTime = picked;
                inlineError = null;
              });
            }

            return Padding(
              padding: EdgeInsets.only(
                left: 20,
                right: 20,
                top: 14,
                bottom: MediaQuery.of(sheetCtx).viewInsets.bottom + 20,
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(
                      child: Container(
                        width: 40,
                        height: 4,
                        decoration: BoxDecoration(
                          color: Colors.grey.shade300,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            existingSlot != null
                                ? 'Chỉnh sửa ca học'
                                : 'Thêm ca học vào lưới',
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        if (existingSlot != null)
                          IconButton(
                            icon: const Icon(Icons.delete_outline,
                                color: Colors.red),
                            tooltip: 'Xóa ca học này',
                            onPressed: () =>
                                Navigator.of(sheetCtx).pop('delete'),
                          ),
                      ],
                    ),
                    Text(
                      repeatWeekly
                          ? '${_formatTimeOfDay(startTime)} - ${_formatTimeOfDay(endTime)} • Lặp lại: ${sortedDayNames.isEmpty ? dayOptionLabel : sortedDayNames}'
                          : '${_formatTimeOfDay(startTime)} - ${_formatTimeOfDay(endTime)} • Duy nhất $dayOptionLabel ($targetDateText)',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.primary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 14),

                    // 1. Tên môn học
                    TextField(
                      key: const ValueKey('grid_editor_subject_field'),
                      controller: subjectCtrl,
                      decoration: InputDecoration(
                        labelText: 'Tên môn học *',
                        hintText: 'VD: Lập trình Flutter, Tiếng Anh tối...',
                        prefixIcon: const Icon(Icons.book_outlined),
                        border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12)),
                        filled: true,
                        fillColor: theme.colorScheme.surfaceContainerLow,
                      ),
                    ),
                    const SizedBox(height: 10),

                    // Chọn nhanh môn có sẵn
                    if (widget.subjectsMap.isNotEmpty) ...[
                      Text('Chọn nhanh môn có sẵn:',
                          style: theme.textTheme.labelSmall),
                      const SizedBox(height: 6),
                      SizedBox(
                        height: 34,
                        child: ListView(
                          scrollDirection: Axis.horizontal,
                          children: widget.subjectsMap.values.map((subj) {
                            return Padding(
                              padding: const EdgeInsets.only(right: 6),
                              child: ActionChip(
                                avatar: CircleAvatar(
                                  backgroundColor: Color(subj.colorArgb),
                                  radius: 6,
                                ),
                                label: Text(subj.name,
                                    style: const TextStyle(fontSize: 12)),
                                onPressed: () {
                                  setSheetState(() {
                                    subjectCtrl.text = subj.name;
                                    selectedColorArgb = subj.colorArgb;
                                  });
                                },
                              ),
                            );
                          }).toList(),
                        ),
                      ),
                      const SizedBox(height: 12),
                    ],

                    // 2. Chọn hoặc nhập trực tiếp giờ bắt đầu / kết thúc
                    Text('Khung giờ học:',
                        style: theme.textTheme.labelMedium
                            ?.copyWith(fontWeight: FontWeight.w600)),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: InkWell(
                            key: const ValueKey('grid_editor_start_time'),
                            onTap: pickStart,
                            borderRadius: BorderRadius.circular(12),
                            child: InputDecorator(
                              decoration: InputDecoration(
                                labelText: 'Bắt đầu',
                                prefixIcon: const Icon(
                                    Icons.access_time_rounded,
                                    size: 18),
                                border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12)),
                                contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 10, vertical: 10),
                              ),
                              child: Text(
                                _formatTimeOfDay(startTime),
                                style: const TextStyle(
                                    fontWeight: FontWeight.bold),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: InkWell(
                            key: const ValueKey('grid_editor_end_time'),
                            onTap: pickEnd,
                            borderRadius: BorderRadius.circular(12),
                            child: InputDecorator(
                              decoration: InputDecoration(
                                labelText: 'Kết thúc',
                                prefixIcon: const Icon(
                                    Icons.access_time_filled_rounded,
                                    size: 18),
                                border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12)),
                                contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 10, vertical: 10),
                              ),
                              child: Text(
                                _formatTimeOfDay(endTime),
                                style: const TextStyle(
                                    fontWeight: FontWeight.bold),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),

                    // 3. Công tắc Bật/Tắt Lặp lại hàng tuần (tắt mặc định để không lặp tuần sau)
                    Card(
                      elevation: 0,
                      margin: EdgeInsets.zero,
                      color: theme.colorScheme.surfaceContainerLow,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                        side: BorderSide(
                          color: theme.colorScheme.outlineVariant
                              .withValues(alpha: 0.5),
                        ),
                      ),
                      child: SwitchListTile(
                        key: const ValueKey('grid_editor_repeat_switch'),
                        value: repeatWeekly,
                        contentPadding:
                            const EdgeInsets.symmetric(horizontal: 12),
                        secondary: Icon(
                          repeatWeekly
                              ? Icons.event_repeat_rounded
                              : Icons.today_rounded,
                          color: repeatWeekly
                              ? theme.colorScheme.primary
                              : theme.colorScheme.outline,
                        ),
                        title: const Text(
                          'Lặp lại hàng tuần',
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 13.5,
                          ),
                        ),
                        subtitle: Text(
                          repeatWeekly
                              ? 'Hiện lịch vào các thứ đã chọn ở các tuần sau'
                              : 'Chỉ học 1 ngày $targetDateText (tuần sau không hiện)',
                          style: const TextStyle(fontSize: 11.5),
                        ),
                        onChanged: (val) {
                          setSheetState(() {
                            repeatWeekly = val;
                            if (!val) {
                              selectedDays
                                ..clear()
                                ..add(dayOfWeek);
                            }
                            inlineError = null;
                          });
                        },
                      ),
                    ),

                    if (repeatWeekly) ...[
                      const SizedBox(height: 12),
                      Text('Chọn các thứ lặp lại trong tuần:',
                          style: theme.textTheme.labelMedium
                              ?.copyWith(fontWeight: FontWeight.w600)),
                      const SizedBox(height: 6),
                      Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: _days.map((d) {
                          final isSelected = selectedDays.contains(d.day);
                          return FilterChip(
                            key: ValueKey('grid_weekday_chip_${d.day}'),
                            label: Text(
                              d.shortLabel,
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: isSelected
                                    ? FontWeight.bold
                                    : FontWeight.normal,
                              ),
                            ),
                            selected: isSelected,
                            showCheckmark: false,
                            visualDensity: VisualDensity.compact,
                            onSelected: (checked) {
                              setSheetState(() {
                                if (checked) {
                                  selectedDays.add(d.day);
                                } else if (selectedDays.length > 1) {
                                  selectedDays.remove(d.day);
                                }
                                inlineError = null;
                              });
                            },
                          );
                        }).toList(),
                      ),
                      const SizedBox(height: 10),
                      DropdownButtonFormField<int>(
                        key: const ValueKey('grid_editor_repeat_weeks'),
                        initialValue: repeatWeeks.clamp(2, 20),
                        decoration: InputDecoration(
                          labelText: 'Thời gian lặp lại',
                          prefixIcon: const Icon(Icons.repeat_on_rounded, size: 19),
                          border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12)),
                          contentPadding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 10),
                        ),
                        items: List.generate(19, (index) => index + 2).map((w) {
                          return DropdownMenuItem<int>(
                            value: w,
                            child: Text('$w tuần liên tiếp'),
                          );
                        }).toList(),
                        onChanged: (val) {
                          if (val != null) {
                            setSheetState(() => repeatWeeks = val);
                          }
                        },
                      ),
                    ],
                    const SizedBox(height: 12),

                    // 4. Phòng học & Địa điểm
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: roomCtrl,
                            decoration: InputDecoration(
                              labelText: 'Phòng học',
                              hintText: 'VD: H2.304',
                              prefixIcon:
                                  const Icon(Icons.meeting_room_outlined),
                              border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12)),
                              filled: true,
                              fillColor: theme.colorScheme.surfaceContainerLow,
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: TextField(
                            controller: buildingCtrl,
                            decoration: InputDecoration(
                              labelText: 'Địa điểm',
                              hintText: 'VD: Tòa H2...',
                              prefixIcon: const Icon(Icons.business_outlined),
                              border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12)),
                              filled: true,
                              fillColor: theme.colorScheme.surfaceContainerLow,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),

                    // 5. Màu sắc môn học
                    Text('Màu đánh dấu môn học:',
                        style: theme.textTheme.labelMedium),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 10,
                      children: [
                        0xFFFFA000,
                        0xFF5E48E8,
                        0xFF00897B,
                        0xFFE53935,
                        0xFF1E88E5,
                        0xFF8E24AA,
                        0xFFFB8C00,
                      ].map((colorValue) {
                        final isSelected = selectedColorArgb == colorValue;
                        return GestureDetector(
                          onTap: () {
                            setSheetState(() => selectedColorArgb = colorValue);
                          },
                          child: Container(
                            width: 30,
                            height: 30,
                            decoration: BoxDecoration(
                              color: Color(colorValue),
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: isSelected
                                    ? Colors.black
                                    : Colors.transparent,
                                width: 2.5,
                              ),
                            ),
                            child: isSelected
                                ? const Icon(Icons.check,
                                    size: 17, color: Colors.white)
                                : null,
                          ),
                        );
                      }).toList(),
                    ),

                    if (inlineError != null) ...[
                      const SizedBox(height: 10),
                      Text(
                        inlineError ?? '',
                        style: TextStyle(
                          color: theme.colorScheme.error,
                          fontSize: 12.5,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                    const SizedBox(height: 16),

                    SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: FilledButton.icon(
                        key: const ValueKey('grid_editor_save_btn'),
                        style: FilledButton.styleFrom(
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12)),
                        ),
                        onPressed: () {
                          if (subjectCtrl.text.trim().isEmpty) {
                            setSheetState(() =>
                                inlineError = 'Vui lòng nhập tên môn học.');
                            return;
                          }
                          final s = startTime.hour * 60 + startTime.minute;
                          final e = endTime.hour * 60 + endTime.minute;
                          if (e <= s) {
                            setSheetState(() => inlineError =
                                'Giờ kết thúc phải sau giờ bắt đầu.');
                            return;
                          }
                          Navigator.of(sheetCtx).pop('save');
                        },
                        icon: const Icon(Icons.save_rounded),
                        label: Text(
                          repeatWeekly
                              ? (selectedDays.length > 1
                                  ? 'Lưu lặp ${selectedDays.length} thứ ($repeatWeeks tuần)'
                                  : 'Lưu lặp hàng tuần ($repeatWeeks tuần)')
                              : 'Lưu duy nhất ngày $targetDateText',
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );

    if (result == 'delete' && existingSlot != null) {
      try {
        final repo = getIt<TimetableRepository>();
        final idsToDelete =
            existingGroup?.groupSlots.map((s) => s.id).toList() ??
                [existingSlot.id];
        for (final id in idsToDelete) {
          await repo.deleteSlot(id);
        }
        widget.onDataChanged();
      } catch (_) {}
      return;
    }

    if (result == 'save') {
      final subjName = subjectCtrl.text.trim();
      final room = roomCtrl.text.trim();
      final building = buildingCtrl.text.trim();
      final chosenStartMin = startTime.hour * 60 + startTime.minute;
      final chosenEndMin = endTime.hour * 60 + endTime.minute;
      final now = DateTime.now();

      try {
        final repo = getIt<TimetableRepository>();

        Subject? matchedSubj;
        for (final s in widget.subjectsMap.values) {
          if (s.name.toLowerCase() == subjName.toLowerCase()) {
            matchedSubj = s;
            break;
          }
        }

        final subjectId = matchedSubj?.id ?? const Uuid().v4();
        if (matchedSubj == null) {
          final code = subjName
              .split(' ')
              .map((w) => w.isNotEmpty ? w[0].toUpperCase() : '')
              .take(4)
              .join();
          final newSubj = Subject(
            id: subjectId,
            code: code.isNotEmpty ? code : 'SUB',
            name: subjName,
            credits: 3,
            colorArgb: selectedColorArgb,
            createdAt: now,
            updatedAt: now,
          );
          await repo.saveSubject(newSubj);
        } else if (matchedSubj.colorArgb != selectedColorArgb) {
          await repo.saveSubject(
            matchedSubj.copyWith(colorArgb: selectedColorArgb, updatedAt: now),
          );
        }

        final slotsToSave = <TimetableSlot>[];
        final effectiveDays = repeatWeekly ? selectedDays : <int>{dayOfWeek};

        DateTime startDateForDay(int d) => _dateForWeekday(d);
        DateTime endDateForDay(int d) {
          final start = startDateForDay(d);
          if (!repeatWeekly) return start;
          return start.add(Duration(days: 7 * (repeatWeeks - 1)));
        }

        if (existingSlot != null) {
          final existingDay = existingSlot.dayOfWeek;
          final groupList =
              existingGroup?.groupSlots ?? <TimetableSlot>[existingSlot];

          if (effectiveDays.contains(existingDay)) {
            final primary = groupList.first;
            // Nếu trước đó có nhiều bản ghi tuần mà nay tắt lặp lại, dọn bớt các bản ghi khác
            if (!repeatWeekly && groupList.length > 1) {
              for (int i = 1; i < groupList.length; i++) {
                await repo.deleteSlot(groupList[i].id);
              }
            }
            slotsToSave.add(
              primary.copyWith(
                subjectId: subjectId,
                startMin: chosenStartMin,
                endMin: chosenEndMin,
                room: room,
                buildingId: building.isNotEmpty ? building : null,
                termStart: startDateForDay(existingDay),
                termEnd: endDateForDay(existingDay),
                updatedAt: now,
              ),
            );
          } else {
            for (final s in groupList) {
              await repo.deleteSlot(s.id);
            }
          }

          if (repeatWeekly) {
            for (final day in effectiveDays) {
              if (day == existingDay) continue;
              final dStart = startDateForDay(day);
              final dEnd = endDateForDay(day);
              final alreadyHas = widget.allSlots.any((s) =>
                  !s.isDeleted &&
                  s.dayOfWeek == day &&
                  s.subjectId == subjectId &&
                  s.startMin == chosenStartMin &&
                  s.endMin == chosenEndMin &&
                  !dStart.isBefore(_dateOnly(s.termStart)) &&
                  !dStart.isAfter(_dateOnly(s.termEnd)));
              if (!alreadyHas) {
                slotsToSave.add(
                  TimetableSlot(
                    id: const Uuid().v4(),
                    subjectId: subjectId,
                    room: room,
                    buildingId: building.isNotEmpty ? building : null,
                    dayOfWeek: day,
                    startMin: chosenStartMin,
                    endMin: chosenEndMin,
                    termStart: dStart,
                    termEnd: dEnd,
                    source: 'user',
                    updatedAt: now,
                  ),
                );
              }
            }
          }
        } else {
          for (final day in effectiveDays) {
            slotsToSave.add(
              TimetableSlot(
                id: const Uuid().v4(),
                subjectId: subjectId,
                room: room,
                buildingId: building.isNotEmpty ? building : null,
                dayOfWeek: day,
                startMin: chosenStartMin,
                endMin: chosenEndMin,
                termStart: startDateForDay(day),
                termEnd: endDateForDay(day),
                source: 'user',
                updatedAt: now,
              ),
            );
          }
        }

        if (slotsToSave.isNotEmpty) {
          await repo.saveSlots(slotsToSave);
        }
        widget.onDataChanged();
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Lỗi khi lưu ca học: $e')),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final now = widget.nowForTest ?? DateTime.now();
    final todayOnly = _dateOnly(now);
    final currentWeekMonday = _mondayOfWeek(todayOnly);
    final isCurrentWeekDisplayed = _weekMonday == currentWeekMonday;
    final nowMin = now.hour * 60 + now.minute;

    final weekSunday = _weekMonday.add(const Duration(days: 6));
    final weekRangeLabel =
        'Tuần ${DateFormat('dd/MM').format(_weekMonday)} - ${DateFormat('dd/MM/yyyy').format(weekSunday)}';

    final dayGroups = _buildPositionedGroupsForDisplayedWeek();
    final bounds = _computeHourBounds(dayGroups);
    final startHour = bounds.startHour;
    final endHour = bounds.endHour;
    final totalHours = endHour - startHour;
    final timelineHeight = totalHours * _hourHeight;
    final dayGridWidth =
        (_days.length * _dayColWidth) + (_days.length * _dayColSpacing);

    final showNowLine = isCurrentWeekDisplayed &&
        nowMin >= startHour * 60 &&
        nowMin <= endHour * 60;
    final nowTop = ((nowMin - startHour * 60) / 60.0) * _hourHeight;

    final weekNavBar = Container(
      margin: const EdgeInsets.fromLTRB(8, 6, 8, 2),
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: colorScheme.outlineVariant.withValues(alpha: 0.35),
        ),
      ),
      child: Row(
        children: [
          IconButton(
            key: const ValueKey('grid_prev_week_btn'),
            tooltip: 'Tuần trước',
            visualDensity: VisualDensity.compact,
            icon: const Icon(Icons.chevron_left_rounded, size: 22),
            onPressed: () {
              setState(() {
                _weekMonday = _weekMonday.subtract(const Duration(days: 7));
              });
            },
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Text(
                weekRangeLabel,
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.labelLarge?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: colorScheme.onSurface,
                ),
              ),
            ),
          ),
          IconButton(
            key: const ValueKey('grid_next_week_btn'),
            tooltip: 'Tuần sau',
            visualDensity: VisualDensity.compact,
            icon: const Icon(Icons.chevron_right_rounded, size: 22),
            onPressed: () {
              setState(() {
                _weekMonday = _weekMonday.add(const Duration(days: 7));
              });
            },
          ),
        ],
      ),
    );

    final headerBar = Padding(
      padding: const EdgeInsets.fromLTRB(8, 4, 8, 6),
      child: Row(
        children: [
          Container(
            width: _timeAxisWidth,
            height: _headerHeight,
            decoration: BoxDecoration(
              color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.7),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: colorScheme.outlineVariant.withValues(alpha: 0.4),
              ),
            ),
            alignment: Alignment.center,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.schedule_rounded,
                    size: 16, color: colorScheme.primary),
                const SizedBox(height: 2),
                Text(
                  'Giờ',
                  style: theme.textTheme.labelMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: colorScheme.onSurface,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 4),
          Expanded(
            child: SingleChildScrollView(
              controller: _headerHScroll,
              scrollDirection: Axis.horizontal,
              physics: const BouncingScrollPhysics(),
              child: Row(
                children: _days.map((d) {
                  final colDate = _dateForWeekday(d.day);
                  final isToday = colDate == todayOnly;
                  final dateLabel = DateFormat('dd/MM').format(colDate);
                  return Container(
                    width: _dayColWidth,
                    height: _headerHeight,
                    margin: const EdgeInsets.only(right: _dayColSpacing),
                    decoration: BoxDecoration(
                      color: isToday
                          ? colorScheme.primaryContainer
                          : colorScheme.surfaceContainerLow,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: isToday
                            ? colorScheme.primary.withValues(alpha: 0.6)
                            : colorScheme.outlineVariant
                                .withValues(alpha: 0.35),
                        width: isToday ? 1.5 : 1.0,
                      ),
                    ),
                    alignment: Alignment.center,
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Flexible(
                              child: Text(
                                d.fullLabel,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: isToday
                                      ? colorScheme.onPrimaryContainer
                                      : colorScheme.onSurface,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12,
                                ),
                              ),
                            ),
                            if (isToday) ...[
                              const SizedBox(width: 4),
                              Container(
                                width: 6,
                                height: 6,
                                decoration: BoxDecoration(
                                  color: colorScheme.primary,
                                  shape: BoxShape.circle,
                                ),
                              ),
                            ],
                          ],
                        ),
                        const SizedBox(height: 1),
                        Text(
                          isToday ? 'Hôm nay ($dateLabel)' : dateLabel,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: isToday
                                ? colorScheme.primary
                                : colorScheme.onSurfaceVariant,
                            fontSize: 10,
                            fontWeight:
                                isToday ? FontWeight.bold : FontWeight.normal,
                          ),
                        ),
                      ],
                    ),
                  );
                }).toList(),
              ),
            ),
          ),
        ],
      ),
    );

    final timelineContent = Padding(
      padding: const EdgeInsets.fromLTRB(8, 0, 8, 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Cột mốc giờ cố định bên trái (06:00, 07:00, ..., 22:00)
          SizedBox(
            width: _timeAxisWidth,
            height: timelineHeight,
            child: Stack(
              children: List.generate(totalHours, (index) {
                final hour = startHour + index;
                return Positioned(
                  top: index * _hourHeight,
                  left: 0,
                  right: 0,
                  height: _hourHeight,
                  child: Align(
                    alignment: Alignment.topRight,
                    child: Padding(
                      padding: const EdgeInsets.only(top: 4, right: 8),
                      child: Text(
                        _formatHourTick(hour),
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                          fontWeight: FontWeight.w600,
                          fontSize: 11.5,
                        ),
                      ),
                    ),
                  ),
                );
              }),
            ),
          ),
          const SizedBox(width: 4),

          // Bảng lưới 7 cột ngày theo tỷ lệ giờ chính xác từng phút
          Expanded(
            child: SingleChildScrollView(
              controller: _bodyHScroll,
              scrollDirection: Axis.horizontal,
              physics: const BouncingScrollPhysics(),
              child: SizedBox(
                width: dayGridWidth,
                height: timelineHeight,
                child: Stack(
                  children: [
                    // 1. Nền từng ô 1 giờ cho 7 ngày
                    Row(
                      children: _days.map((d) {
                        final colDate = _dateForWeekday(d.day);
                        final isToday = colDate == todayOnly;
                        return Container(
                          width: _dayColWidth,
                          height: timelineHeight,
                          margin: const EdgeInsets.only(right: _dayColSpacing),
                          child: Column(
                            children: List.generate(totalHours, (hourIdx) {
                              final hour = startHour + hourIdx;
                              return InkWell(
                                key: ValueKey('grid_empty_${d.day}_$hour'),
                                borderRadius: BorderRadius.circular(10),
                                onTap: () => _openCellEditor(
                                  colDate,
                                  initialStartMin: hour * 60,
                                  initialEndMin:
                                      math.min((hour + 1) * 60, 23 * 60 + 59),
                                ),
                                child: Container(
                                  height: _hourHeight,
                                  decoration: BoxDecoration(
                                    color: isToday
                                        ? colorScheme.primary
                                            .withValues(alpha: 0.03)
                                        : colorScheme.surfaceContainerLowest,
                                    borderRadius: BorderRadius.circular(10),
                                    border: Border.all(
                                      color: colorScheme.outlineVariant
                                          .withValues(alpha: 0.3),
                                      width: 0.7,
                                    ),
                                  ),
                                ),
                              );
                            }),
                          ),
                        );
                      }).toList(),
                    ),

                    // 2. Các khối môn học đặt chính xác theo startMin..endMin
                    for (int colIdx = 0; colIdx < _days.length; colIdx++)
                      ...(() {
                        final dayInt = _days[colIdx].day;
                        final colDate = _dateForWeekday(dayInt);
                        final groups = dayGroups[dayInt] ?? const <_SlotGroup>[];
                        final colLeft = colIdx * (_dayColWidth + _dayColSpacing);

                        return groups.map((group) {
                          final slot = group.primary;
                          final subject = widget.subjectsMap[slot.subjectId];
                          final baseColor = subject != null
                              ? Color(subject.colorArgb)
                              : const Color(0xFF1E88E5);

                          const innerPad = 2.5;
                          const laneGap = 2.0;
                          final usableWidth = _dayColWidth -
                              (2 * innerPad) -
                              ((group.laneCount - 1) * laneGap);
                          final cardWidth =
                              math.max(24.0, usableWidth / group.laneCount);
                          final cardLeft = colLeft +
                              innerPad +
                              group.laneIndex * (cardWidth + laneGap);

                          final cardTop = ((slot.startMin - startHour * 60) /
                                      60.0) *
                                  _hourHeight +
                              1.5;
                          final cardHeight = math.max(
                            30.0,
                            ((slot.endMin - slot.startMin) / 60.0) *
                                    _hourHeight -
                                3.0,
                          );

                          final cardBg = Color.alphaBlend(
                            baseColor.withValues(
                              alpha: theme.brightness == Brightness.dark
                                  ? 0.28
                                  : 0.16,
                            ),
                            colorScheme.surface,
                          );

                          final timeRangeLabel =
                              '${slot.startTimeFormatted} - ${slot.endTimeFormatted}';

                          return Positioned(
                            key: ValueKey('grid_slot_${slot.id}'),
                            left: cardLeft,
                            top: cardTop,
                            width: cardWidth,
                            height: cardHeight,
                            child: Material(
                              color: Colors.transparent,
                              child: InkWell(
                                borderRadius: BorderRadius.circular(10),
                                onTap: () => _openCellEditor(
                                  colDate,
                                  initialStartMin: slot.startMin,
                                  initialEndMin: slot.endMin,
                                  existingGroup: group,
                                ),
                                child: Container(
                                  decoration: BoxDecoration(
                                    color: cardBg,
                                    borderRadius: BorderRadius.circular(10),
                                    border: Border.all(
                                      color: baseColor.withValues(alpha: 0.55),
                                      width: 1.2,
                                    ),
                                  ),
                                  clipBehavior: Clip.antiAlias,
                                  child: Stack(
                                    children: [
                                      Positioned(
                                        left: 0,
                                        top: 0,
                                        bottom: 0,
                                        width: 4.0,
                                        child: Container(color: baseColor),
                                      ),
                                      Padding(
                                        padding: const EdgeInsets.fromLTRB(
                                            8, 4, 5, 4),
                                        child: _buildSlotCardContent(
                                          theme: theme,
                                          colorScheme: colorScheme,
                                          baseColor: baseColor,
                                          subjectName:
                                              subject?.name ?? 'Môn học',
                                          timeRange: timeRangeLabel,
                                          room: slot.room,
                                          cardHeight: cardHeight,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          );
                        });
                      })(),

                    // 3. Vạch chỉ giờ hiện tại (Google Calendar style)
                    if (showNowLine) ...[
                      Positioned(
                        left: 0,
                        right: 0,
                        top: nowTop.clamp(0.0, timelineHeight - 2),
                        child: IgnorePointer(
                          child: Container(
                            height: 1.2,
                            color: colorScheme.onSurface.withValues(alpha: 0.22),
                          ),
                        ),
                      ),
                      Positioned(
                        left: ((todayOnly.weekday - 1) *
                                (_dayColWidth + _dayColSpacing))
                            .clamp(0.0, dayGridWidth - _dayColWidth),
                        width: _dayColWidth,
                        top: (nowTop - 5).clamp(0.0, timelineHeight - 10),
                        child: IgnorePointer(
                          child: Row(
                            children: [
                              Container(
                                width: 10,
                                height: 10,
                                decoration: BoxDecoration(
                                  color: colorScheme.onSurface,
                                  shape: BoxShape.circle,
                                ),
                              ),
                              Expanded(
                                child: Container(
                                  height: 2.0,
                                  color: colorScheme.onSurface
                                      .withValues(alpha: 0.9),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );

    final tipBar = Container(
      margin: const EdgeInsets.fromLTRB(8, 0, 8, 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: colorScheme.outlineVariant.withValues(alpha: 0.35),
        ),
      ),
      child: Row(
        children: [
          Icon(Icons.touch_app_outlined, size: 16, color: colorScheme.primary),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Chạm vào ô giờ để thêm/chỉnh giờ lẻ hoặc bật lặp lại theo thứ.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: colorScheme.onSurfaceVariant,
                fontSize: 11.5,
              ),
            ),
          ),
        ],
      ),
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        if (!constraints.hasBoundedHeight) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              weekNavBar,
              headerBar,
              timelineContent,
              tipBar,
            ],
          );
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            weekNavBar,
            headerBar,
            Expanded(
              child: SingleChildScrollView(
                controller: _vScroll,
                physics: const AlwaysScrollableScrollPhysics(
                  parent: BouncingScrollPhysics(),
                ),
                child: timelineContent,
              ),
            ),
            tipBar,
          ],
        );
      },
    );
  }

  Widget _buildSlotCardContent({
    required ThemeData theme,
    required ColorScheme colorScheme,
    required Color baseColor,
    required String subjectName,
    required String timeRange,
    required String room,
    required double cardHeight,
  }) {
    if (cardHeight < 44) {
      return Align(
        alignment: Alignment.centerLeft,
        child: Text(
          '$subjectName • $timeRange',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: theme.textTheme.bodySmall?.copyWith(
            fontWeight: FontWeight.bold,
            fontSize: 11,
            color: colorScheme.onSurface,
          ),
        ),
      );
    }

    if (cardHeight < 68) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            subjectName,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.bodySmall?.copyWith(
              fontWeight: FontWeight.bold,
              fontSize: 11.5,
              height: 1.15,
              color: colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            room.isNotEmpty ? '$timeRange • $room' : timeRange,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w600,
              color: colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              subjectName,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodySmall?.copyWith(
                fontWeight: FontWeight.bold,
                fontSize: 11.5,
                height: 1.2,
                color: colorScheme.onSurface,
              ),
            ),
            const SizedBox(height: 3),
            Text(
              timeRange,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w600,
                color: colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
        if (room.isNotEmpty)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
            decoration: BoxDecoration(
              color: baseColor.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.meeting_room_rounded, size: 10.5, color: baseColor),
                const SizedBox(width: 3),
                Flexible(
                  child: Text(
                    room,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 9.5,
                      fontWeight: FontWeight.bold,
                      color: colorScheme.onSurface,
                    ),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}
