import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';

import '../../../../core/di/injection.dart';
import '../../domain/entities/subject.dart';
import '../../domain/entities/timetable_slot.dart';
import '../../domain/repositories/timetable_repository.dart';

/// Khung giờ học mặc định của sinh viên đại học
class TimeInterval {
  final int startMin; // phút trong ngày (vd 480 = 08:00)
  final int endMin;   // phút trong ngày (vd 540 = 09:00)

  const TimeInterval(this.startMin, this.endMin);

  String get label {
    final startH = (startMin ~/ 60).toString().padLeft(2, '0');
    final startM = (startMin % 60).toString().padLeft(2, '0');
    final endH = (endMin ~/ 60).toString().padLeft(2, '0');
    final endM = (endMin % 60).toString().padLeft(2, '0');
    return '$startH:$startM -\n$endH:$endM';
  }

  String get singleLineLabel {
    final startH = (startMin ~/ 60).toString().padLeft(2, '0');
    final startM = (startMin % 60).toString().padLeft(2, '0');
    final endH = (endMin ~/ 60).toString().padLeft(2, '0');
    final endM = (endMin % 60).toString().padLeft(2, '0');
    return '$startH:$startM - $endH:$endM';
  }
}

/// Bảng ma trận Thời khóa biểu theo tuần (College Grid Timetable)
/// theo đúng phong cách bảng lưới quản lý trực quan của sinh viên đại học:
/// - Cột đầu hiển thị Khung giờ (Time) màu xanh lá.
/// - Các cột tiếp theo hiển thị các Thứ (Thứ 2 -> Chủ nhật) màu xanh dương.
/// - Các ô lưới hiển thị môn học với khối màu đặc trưng (Physics, Maths...).
/// - Chạm vào bất kỳ ô nào để nhập/chỉnh sửa môn học trực tiếp ("muốn nhập gì cũng được").
class TimetableGridView extends StatefulWidget {
  final List<TimetableSlot> allSlots;
  final Map<String, Subject> subjectsMap;
  final VoidCallback onDataChanged;

  const TimetableGridView({
    super.key,
    required this.allSlots,
    required this.subjectsMap,
    required this.onDataChanged,
  });

  @override
  State<TimetableGridView> createState() => _TimetableGridViewState();
}

class _TimetableGridViewState extends State<TimetableGridView> {
  // Danh sách các khung giờ mặc định (có thể thêm/xóa hàng)
  late List<TimeInterval> _timeIntervals;

  final List<Map<String, dynamic>> _days = const [
    {'day': 1, 'label': 'Thứ 2\nMon'},
    {'day': 2, 'label': 'Thứ 3\nTue'},
    {'day': 3, 'label': 'Thứ 4\nWed'},
    {'day': 4, 'label': 'Thứ 5\nThu'},
    {'day': 5, 'label': 'Thứ 6\nFri'},
    {'day': 6, 'label': 'Thứ 7\nSat'},
    {'day': 7, 'label': 'Chủ nhật\nSun'},
  ];

  @override
  void initState() {
    super.initState();
    _initTimeIntervals();
  }

  void _initTimeIntervals() {
    // Khung giờ chuẩn theo lịch học đại học
    _timeIntervals = [
      const TimeInterval(420, 540),   // 07:00 - 09:00
      const TimeInterval(555, 675),   // 09:15 - 11:15
      const TimeInterval(780, 900),   // 13:00 - 15:00
      const TimeInterval(915, 1035),  // 15:15 - 17:15
      const TimeInterval(1050, 1170), // 17:30 - 19:30
    ];

    // Bổ sung các khung giờ đặc thù nếu trong slots có sẵn các giờ khác
    for (final slot in widget.allSlots) {
      if (slot.isDeleted) continue;
      final exists = _timeIntervals.any(
        (t) => (slot.startMin >= t.startMin && slot.startMin < t.endMin) ||
               (slot.endMin > t.startMin && slot.endMin <= t.endMin),
      );
      if (!exists) {
        _timeIntervals.add(TimeInterval(slot.startMin, slot.endMin));
      }
    }
    _timeIntervals.sort((a, b) => a.startMin.compareTo(b.startMin));
  }

  /// Tìm slot nằm trong ngày và khung giờ này
  TimetableSlot? _findSlotFor(int dayOfWeek, TimeInterval interval) {
    for (final slot in widget.allSlots) {
      if (slot.isDeleted || slot.dayOfWeek != dayOfWeek) continue;
      // Trùng hoặc giao nhau với khung giờ
      if ((slot.startMin >= interval.startMin && slot.startMin < interval.endMin) ||
          (slot.endMin > interval.startMin && slot.endMin <= interval.endMin) ||
          (slot.startMin <= interval.startMin && slot.endMin >= interval.endMin)) {
        return slot;
      }
    }
    return null;
  }

  /// Thêm hàng giờ mới
  Future<void> _addNewTimeInterval() async {
    const start = TimeOfDay(hour: 8, minute: 0);

    final pickedStart = await showTimePicker(
      context: context,
      initialTime: start,
      helpText: 'Chọn giờ bắt đầu ca học',
    );
    if (pickedStart == null || !mounted) return;

    final pickedEnd = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: pickedStart.hour + 1, minute: pickedStart.minute + 30),
      helpText: 'Chọn giờ kết thúc ca học',
    );
    if (pickedEnd == null || !mounted) return;

    final startMin = pickedStart.hour * 60 + pickedStart.minute;
    final endMin = pickedEnd.hour * 60 + pickedEnd.minute;

    if (endMin <= startMin) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Giờ kết thúc phải sau giờ bắt đầu!')),
      );
      return;
    }

    setState(() {
      _timeIntervals.add(TimeInterval(startMin, endMin));
      _timeIntervals.sort((a, b) => a.startMin.compareTo(b.startMin));
    });
  }

  /// Chèn hàng giờ mới (Insert Row) tại vị trí chỉ định
  Future<void> _insertTimeInterval(int index) async {
    final current = _timeIntervals[index];
    final defaultStartH = current.endMin ~/ 60;
    final defaultStartM = current.endMin % 60;

    final pickedStart = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: defaultStartH % 24, minute: defaultStartM),
      helpText: 'Chọn giờ bắt đầu hàng mới (Insert Row)',
    );
    if (pickedStart == null || !mounted) return;

    final pickedEnd = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(
        hour: (pickedStart.hour + 1) % 24,
        minute: pickedStart.minute,
      ),
      helpText: 'Chọn giờ kết thúc hàng mới',
    );
    if (pickedEnd == null || !mounted) return;

    final startMin = pickedStart.hour * 60 + pickedStart.minute;
    final endMin = pickedEnd.hour * 60 + pickedEnd.minute;

    if (endMin <= startMin) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Giờ kết thúc phải sau giờ bắt đầu!')),
      );
      return;
    }

    setState(() {
      _timeIntervals.add(TimeInterval(startMin, endMin));
      _timeIntervals.sort((a, b) => a.startMin.compareTo(b.startMin));
    });
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Đã chèn hàng khung giờ mới.')),
      );
    }
  }

  /// Sửa khung giờ ca học (Edit Time)
  Future<void> _editTimeInterval(int index) async {
    final current = _timeIntervals[index];
    final pickedStart = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: current.startMin ~/ 60, minute: current.startMin % 60),
      helpText: 'Sửa giờ bắt đầu',
    );
    if (pickedStart == null || !mounted) return;

    final pickedEnd = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: current.endMin ~/ 60, minute: current.endMin % 60),
      helpText: 'Sửa giờ kết thúc',
    );
    if (pickedEnd == null || !mounted) return;

    final startMin = pickedStart.hour * 60 + pickedStart.minute;
    final endMin = pickedEnd.hour * 60 + pickedEnd.minute;

    if (endMin <= startMin) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Giờ kết thúc phải sau giờ bắt đầu!')),
      );
      return;
    }

    setState(() {
      _timeIntervals[index] = TimeInterval(startMin, endMin);
      _timeIntervals.sort((a, b) => a.startMin.compareTo(b.startMin));
    });
  }

  /// Xóa hàng khung giờ (Delete Row - có xác nhận nếu có ca học)
  Future<void> _deleteTimeInterval(int index) async {
    final interval = _timeIntervals[index];
    final affectedSlots = widget.allSlots.where((s) =>
        !s.isDeleted &&
        ((s.startMin >= interval.startMin && s.startMin < interval.endMin) ||
            (s.endMin > interval.startMin && s.endMin <= interval.endMin) ||
            (s.startMin <= interval.startMin && s.endMin >= interval.endMin))).toList();

    if (affectedSlots.isNotEmpty) {
      final confirm = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Xác nhận xóa hàng'),
          content: Text(
            'Hàng này đang có ${affectedSlots.length} ca học. Xóa hàng sẽ xóa luôn các ca học trên lịch. Bạn có chắc muốn xóa?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Hủy'),
            ),
            FilledButton(
              style: FilledButton.styleFrom(backgroundColor: Colors.red),
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Xóa tất cả'),
            ),
          ],
        ),
      );
      if (confirm != true || !mounted) return;

      try {
        final repo = getIt<TimetableRepository>();
        for (final s in affectedSlots) {
          await repo.deleteSlot(s.id);
        }
        widget.onDataChanged();
      } catch (_) {}
    }

    setState(() {
      _timeIntervals.removeAt(index);
    });
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Đã xóa hàng khung giờ.')),
      );
    }
  }

  /// Nhập môn học trực tiếp vào ô lưới ("muốn nhập gì trong đây cx được")
  Future<void> _openCellEditor(int dayOfWeek, TimeInterval interval, [TimetableSlot? existingSlot]) async {
    final theme = Theme.of(context);
    final subjectCtrl = TextEditingController(
      text: existingSlot != null
          ? (widget.subjectsMap[existingSlot.subjectId]?.name ?? '')
          : '',
    );
    final roomCtrl = TextEditingController(text: existingSlot?.room ?? '');
    final buildingCtrl = TextEditingController(text: existingSlot?.buildingId ?? '');

    int selectedColorArgb = existingSlot != null
        ? (widget.subjectsMap[existingSlot.subjectId]?.colorArgb ?? 0xFFFFA000)
        : 0xFFFFA000; // Mặc định vàng ấm học đường

    final dayName = _days.firstWhere((d) => d['day'] == dayOfWeek)['label'].replaceAll('\n', ' - ');

    final result = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetCtx) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            return Padding(
              padding: EdgeInsets.only(
                left: 20,
                right: 20,
                top: 16,
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
                        Text(
                          existingSlot != null ? 'Chỉnh sửa môn học' : 'Nhập môn học vào bảng',
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        if (existingSlot != null)
                          IconButton(
                            icon: const Icon(Icons.delete_outline, color: Colors.red),
                            tooltip: 'Xóa ca học này',
                            onPressed: () => Navigator.of(sheetCtx).pop(false),
                          ),
                      ],
                    ),
                    Text(
                      '$dayName | Khung giờ: ${interval.singleLineLabel}',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.primary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 16),

                    // 1. Tên môn học
                    TextField(
                      controller: subjectCtrl,
                      autofocus: existingSlot == null,
                      decoration: InputDecoration(
                        labelText: 'Tên môn học (*)',
                        hintText: 'Ví dụ: Lập trình Flutter, Toán rời rạc...',
                        prefixIcon: const Icon(Icons.book_outlined),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        filled: true,
                        fillColor: theme.colorScheme.surfaceContainerLow,
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Gợi ý chọn nhanh từ các môn đã có
                    if (widget.subjectsMap.isNotEmpty) ...[
                      Text('Hoặc chọn nhanh môn có sẵn:', style: theme.textTheme.labelSmall),
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
                                label: Text(subj.name, style: const TextStyle(fontSize: 12)),
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

                    // 2. Phòng học & Tòa nhà
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: roomCtrl,
                            decoration: InputDecoration(
                              labelText: 'Phòng học',
                              hintText: 'VD: A1-402',
                              prefixIcon: const Icon(Icons.meeting_room_outlined),
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
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
                              labelText: 'Tòa nhà',
                              hintText: 'VD: Tòa A',
                              prefixIcon: const Icon(Icons.business_outlined),
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                              filled: true,
                              fillColor: theme.colorScheme.surfaceContainerLow,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),

                    // 3. Màu sắc môn học (Pastel Palette)
                    Text('Màu đánh dấu môn học:', style: theme.textTheme.labelMedium),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 10,
                      children: [
                        0xFFFFA000, // Vàng hổ phách (Physics style)
                        0xFF5E48E8, // Indigo tím hiện đại
                        0xFF00897B, // Xanh mòng két
                        0xFFE53935, // Đỏ san hô
                        0xFF1E88E5, // Xanh lam
                        0xFF8E24AA, // Tím violet
                        0xFFFB8C00, // Cam ấm
                      ].map((colorValue) {
                        final isSelected = selectedColorArgb == colorValue;
                        return GestureDetector(
                          onTap: () {
                            setSheetState(() => selectedColorArgb = colorValue);
                          },
                          child: Container(
                            width: 32,
                            height: 32,
                            decoration: BoxDecoration(
                              color: Color(colorValue),
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: isSelected ? Colors.black : Colors.transparent,
                                width: 2.5,
                              ),
                            ),
                            child: isSelected
                                ? const Icon(Icons.check, size: 18, color: Colors.white)
                                : null,
                          ),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 20),

                    // Nút Lưu ca học
                    SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: FilledButton.icon(
                        style: FilledButton.styleFrom(
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        onPressed: () {
                          if (subjectCtrl.text.trim().isEmpty) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Vui lòng nhập tên môn học!')),
                            );
                            return;
                          }
                          Navigator.of(sheetCtx).pop(true);
                        },
                        icon: const Icon(Icons.save_rounded),
                        label: const Text('Lưu vào bảng thời khóa biểu', style: TextStyle(fontWeight: FontWeight.bold)),
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

    if (result == false && existingSlot != null) {
      // Xóa ca học
      try {
        final repo = getIt<TimetableRepository>();
        await repo.deleteSlot(existingSlot.id);
        widget.onDataChanged();
      } catch (_) {}
    } else if (result == true) {
      // Lưu ca học mới hoặc cập nhật
      final subjName = subjectCtrl.text.trim();
      final room = roomCtrl.text.trim();
      final building = buildingCtrl.text.trim();

      try {
        final repo = getIt<TimetableRepository>();

        // Tìm môn học đã có theo tên hoặc tạo mới
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
            createdAt: DateTime.now(),
            updatedAt: DateTime.now(),
          );
          await repo.saveSubject(newSubj);
        } else if (matchedSubj.colorArgb != selectedColorArgb) {
          final updatedSubj = matchedSubj.copyWith(
            colorArgb: selectedColorArgb,
            updatedAt: DateTime.now(),
          );
          await repo.saveSubject(updatedSubj);
        }

        final slotId = existingSlot?.id ?? const Uuid().v4();
        final newSlot = TimetableSlot(
          id: slotId,
          subjectId: subjectId,
          room: room,
          buildingId: building.isNotEmpty ? building : null,
          dayOfWeek: dayOfWeek,
          startMin: interval.startMin,
          endMin: interval.endMin,
          termStart: DateTime.now().subtract(const Duration(days: 30)),
          termEnd: DateTime.now().add(const Duration(days: 120)),
          source: 'manual',
          updatedAt: DateTime.now(),
        );

        await repo.saveSlots([newSlot]);
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
    final currentWeekday = DateTime.now().weekday; // 1: Thứ 2 ... 7: Chủ nhật

    const double colWidth = 112.0;
    const double timeColWidth = 80.0;
    const double rowHeight = 86.0;

    return SingleChildScrollView(
      scrollDirection: Axis.vertical,
      physics: const BouncingScrollPhysics(),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 10, 16, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── HÀNG TIÊU ĐỀ: Khung giờ & Các Thứ trong tuần ──────────────────
              Row(
                children: [
                  // Cột Tiêu đề Khung Giờ (Time)
                  Container(
                    width: timeColWidth,
                    height: 56,
                    decoration: BoxDecoration(
                      color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.7),
                      borderRadius: const BorderRadius.only(
                        topLeft: Radius.circular(14),
                        bottomLeft: Radius.circular(14),
                      ),
                      border: Border.all(
                        color: colorScheme.outlineVariant.withValues(alpha: 0.4),
                      ),
                    ),
                    alignment: Alignment.center,
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.schedule_rounded,
                          size: 16,
                          color: colorScheme.primary,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Ca học',
                          style: theme.textTheme.labelMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: colorScheme.onSurface,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 4),

                  // Các cột Thứ (Mon -> Sun) với chỉ báo Hôm nay (Today Highlight)
                  ..._days.map((d) {
                    final dayInt = d['day'] as int;
                    final isToday = dayInt == currentWeekday;
                    final labelParts = (d['label'] as String).split('\n');
                    final dayVi = labelParts.first;
                    final dayEn = labelParts.length > 1 ? labelParts[1] : '';

                    return Container(
                      width: colWidth,
                      height: 56,
                      margin: const EdgeInsets.only(right: 4),
                      decoration: BoxDecoration(
                        color: isToday
                            ? colorScheme.primaryContainer
                            : colorScheme.surfaceContainerLow,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: isToday
                              ? colorScheme.primary.withValues(alpha: 0.6)
                              : colorScheme.outlineVariant.withValues(alpha: 0.35),
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
                                  dayVi,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    color: isToday
                                        ? colorScheme.onPrimaryContainer
                                        : colorScheme.onSurface,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 11.5,
                                  ),
                                ),
                              ),
                              if (isToday) ...[
                                const SizedBox(width: 3),
                                Container(
                                  width: 5,
                                  height: 5,
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
                            isToday ? 'Hôm nay' : dayEn,
                            style: TextStyle(
                              color: isToday
                                  ? colorScheme.primary
                                  : colorScheme.onSurfaceVariant,
                              fontSize: 10,
                              fontWeight: isToday ? FontWeight.bold : FontWeight.normal,
                            ),
                          ),
                        ],
                      ),
                    );
                  }),
                ],
              ),
              const SizedBox(height: 6),

              // ── CÁC HÀNG MA TRẬN: Khung giờ & Môn học trong ô ────────────────
              ..._timeIntervals.asMap().entries.map((entry) {
                final rowIndex = entry.key;
                final interval = entry.value;

                final startH = (interval.startMin ~/ 60).toString().padLeft(2, '0');
                final startM = (interval.startMin % 60).toString().padLeft(2, '0');
                final endH = (interval.endMin ~/ 60).toString().padLeft(2, '0');
                final endM = (interval.endMin % 60).toString().padLeft(2, '0');

                return Padding(
                  padding: const EdgeInsets.only(bottom: 6.0),
                  child: Row(
                    children: [
                      // Cột Giờ bên trái: PopupMenuButton mở menu Insert / Delete Row chuẩn xác tại hàng
                      PopupMenuButton<String>(
                        tooltip: 'Thao tác hàng ca học',
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        elevation: 6,
                        onSelected: (selected) {
                          if (selected == 'insert') {
                            _insertTimeInterval(rowIndex);
                          } else if (selected == 'delete') {
                            _deleteTimeInterval(rowIndex);
                          } else if (selected == 'edit') {
                            _editTimeInterval(rowIndex);
                          }
                        },
                        itemBuilder: (ctx) => [
                          const PopupMenuItem<String>(
                            value: 'insert',
                            child: Row(
                              children: [
                                Icon(Icons.add_circle_outline, color: Color(0xFF5E48E8), size: 19),
                                SizedBox(width: 10),
                                Text(
                                  'Insert Row',
                                  style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13.5),
                                ),
                              ],
                            ),
                          ),
                          const PopupMenuDivider(height: 1),
                          const PopupMenuItem<String>(
                            value: 'delete',
                            child: Row(
                              children: [
                                Icon(Icons.delete_outline, color: Colors.red, size: 19),
                                SizedBox(width: 10),
                                Text(
                                  'Delete Row',
                                  style: TextStyle(
                                    fontWeight: FontWeight.w600,
                                    fontSize: 13.5,
                                    color: Colors.red,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const PopupMenuDivider(height: 1),
                          const PopupMenuItem<String>(
                            value: 'edit',
                            child: Row(
                              children: [
                                Icon(Icons.access_time_rounded, color: Colors.teal, size: 19),
                                SizedBox(width: 10),
                                Text(
                                  'Sửa khung giờ',
                                  style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13.5),
                                ),
                              ],
                            ),
                          ),
                        ],
                        child: Container(
                          width: timeColWidth,
                          height: rowHeight,
                          decoration: BoxDecoration(
                            color: colorScheme.surfaceContainerLow,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: colorScheme.outlineVariant.withValues(alpha: 0.35),
                            ),
                          ),
                          alignment: Alignment.center,
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                                    decoration: BoxDecoration(
                                      color: colorScheme.primary.withValues(alpha: 0.12),
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: Text(
                                      'Ca ${rowIndex + 1}',
                                      style: TextStyle(
                                        color: colorScheme.primary,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 9.5,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 2),
                                  Icon(
                                    Icons.more_vert_rounded,
                                    size: 13,
                                    color: colorScheme.onSurfaceVariant.withValues(alpha: 0.5),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 4),
                              Text(
                                '$startH:$startM',
                                style: theme.textTheme.bodySmall?.copyWith(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 11,
                                ),
                              ),
                              Text(
                                '$endH:$endM',
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: colorScheme.onSurfaceVariant,
                                  fontSize: 10,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(width: 4),

                      // Các ô môn học của từng Thứ
                      ..._days.map((d) {
                        final dayOfWeek = d['day'] as int;
                        final isToday = dayOfWeek == currentWeekday;
                        final slot = _findSlotFor(dayOfWeek, interval);
                        final subject = slot != null ? widget.subjectsMap[slot.subjectId] : null;

                        final Color baseColor = subject != null
                            ? Color(subject.colorArgb)
                            : (slot != null ? const Color(0xFF1E88E5) : Colors.transparent);

                        return Container(
                          width: colWidth,
                          height: rowHeight,
                          margin: const EdgeInsets.only(right: 4),
                          child: slot != null
                              ? Material(
                                  color: Colors.transparent,
                                  child: InkWell(
                                    borderRadius: BorderRadius.circular(12),
                                    onTap: () => _openCellEditor(dayOfWeek, interval, slot),
                                    child: Container(
                                      decoration: BoxDecoration(
                                        color: baseColor.withValues(alpha: 0.14),
                                        borderRadius: BorderRadius.circular(12),
                                        border: Border.all(
                                          color: baseColor.withValues(alpha: 0.45),
                                          width: 1.2,
                                        ),
                                      ),
                                      clipBehavior: Clip.antiAlias,
                                      child: Stack(
                                        children: [
                                          // Dải màu nhấn nổi bật ở cạnh trái
                                          Positioned(
                                            left: 0,
                                            top: 0,
                                            bottom: 0,
                                            width: 4.5,
                                            child: Container(
                                              decoration: BoxDecoration(
                                                color: baseColor,
                                                borderRadius: const BorderRadius.only(
                                                  topLeft: Radius.circular(12),
                                                  bottomLeft: Radius.circular(12),
                                                ),
                                              ),
                                            ),
                                          ),
                                          // Nội dung môn học
                                          Padding(
                                            padding: const EdgeInsets.fromLTRB(10, 8, 6, 6),
                                            child: Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                              children: [
                                                Text(
                                                  subject?.name ?? 'Môn học',
                                                  maxLines: 2,
                                                  overflow: TextOverflow.ellipsis,
                                                  style: theme.textTheme.bodySmall?.copyWith(
                                                    fontWeight: FontWeight.bold,
                                                    fontSize: 11.5,
                                                    height: 1.2,
                                                    color: colorScheme.onSurface,
                                                  ),
                                                ),
                                                if (slot.room.isNotEmpty)
                                                  Container(
                                                    padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                                                    decoration: BoxDecoration(
                                                      color: baseColor.withValues(alpha: 0.2),
                                                      borderRadius: BorderRadius.circular(6),
                                                    ),
                                                    child: Row(
                                                      mainAxisSize: MainAxisSize.min,
                                                      children: [
                                                        Icon(
                                                          Icons.meeting_room_rounded,
                                                          size: 11,
                                                          color: baseColor,
                                                        ),
                                                        const SizedBox(width: 3),
                                                        Flexible(
                                                          child: Text(
                                                            slot.room,
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
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                )
                              : Material(
                                  color: Colors.transparent,
                                  child: InkWell(
                                    borderRadius: BorderRadius.circular(12),
                                    onTap: () => _openCellEditor(dayOfWeek, interval, slot),
                                    child: Container(
                                      decoration: BoxDecoration(
                                        color: isToday
                                            ? colorScheme.primary.withValues(alpha: 0.03)
                                            : colorScheme.surfaceContainerLowest,
                                        borderRadius: BorderRadius.circular(12),
                                        border: Border.all(
                                          color: isToday
                                              ? colorScheme.primary.withValues(alpha: 0.25)
                                              : colorScheme.outlineVariant.withValues(alpha: 0.25),
                                          width: 0.8,
                                        ),
                                      ),
                                      alignment: Alignment.center,
                                      child: Icon(
                                        Icons.add_rounded,
                                        size: 18,
                                        color: colorScheme.outline.withValues(alpha: 0.35),
                                      ),
                                    ),
                                  ),
                                ),
                        );
                      }),
                    ],
                  ),
                );
              }),

              const SizedBox(height: 6),

              // ── HÀNG NÚT "+" ĐỂ THÊM KHUNG GIỜ MỚI & THANH HƯỚNG DẪN ─────────
              Row(
                children: [
                  Material(
                    color: Colors.transparent,
                    child: InkWell(
                      borderRadius: BorderRadius.circular(12),
                      onTap: _addNewTimeInterval,
                      child: Container(
                        width: timeColWidth,
                        height: 44,
                        decoration: BoxDecoration(
                          color: const Color(0xFF5E48E8), // Sắc tím hiện đại như ảnh mẫu
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFF5E48E8).withValues(alpha: 0.3),
                              blurRadius: 6,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        alignment: Alignment.center,
                        child: const Icon(
                          Icons.add_rounded,
                          color: Colors.white,
                          size: 24,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),

                  // Thanh hướng dẫn M3
                  Container(
                    height: 44,
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    decoration: BoxDecoration(
                      color: colorScheme.surfaceContainerLow,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: colorScheme.outlineVariant.withValues(alpha: 0.35),
                      ),
                    ),
                    alignment: Alignment.centerLeft,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.lightbulb_outline_rounded,
                          size: 16,
                          color: colorScheme.primary,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Chạm ô để nhập môn • Chạm cột Giờ để Chèn & Xóa hàng',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: colorScheme.onSurfaceVariant,
                            fontSize: 11,
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
      ),
    );
  }
}
