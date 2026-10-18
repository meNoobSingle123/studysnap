import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';
import '../../../../core/di/injection.dart';
import '../../../../core/l10n/strings.dart';
import '../../../../core/router/routes.dart';
import '../../../notes/domain/entities/lecture_note.dart';
import '../../../notes/domain/repositories/note_repository.dart';
import '../../domain/entities/campus_building.dart';
import '../../domain/entities/subject.dart';
import '../../domain/entities/timetable_slot.dart';
import '../../domain/repositories/timetable_repository.dart';

/// Màn hình S03: Chi tiết ca học.
///
/// Hiển thị thông tin giảng đường, giờ học, tùy chọn chỉnh sửa/xóa ca học,
/// cài đặt thời gian nhắc nhở (5, 10, 15, 30 phút), và nút tạo ghi chú liên kết môn học.
class SlotDetailPage extends StatefulWidget {
  final String slotId;

  const SlotDetailPage({super.key, required this.slotId});

  @override
  State<SlotDetailPage> createState() => _SlotDetailPageState();
}

class _SlotDetailPageState extends State<SlotDetailPage> {
  bool _isLoading = true;
  TimetableSlot? _slot;
  Subject? _subject;
  CampusBuilding? _building;
  List<LectureNote> _linkedNotes = [];

  bool _isReminderEnabled = true;
  int _reminderLeadMinutes = 15; // Mặc định 15 phút theo đặc tả FR-06

  @override
  void initState() {
    super.initState();
    _loadSlotDetails();
  }

  Future<void> _loadSlotDetails() async {
    final repo = getIt<TimetableRepository>();
    final slot = await repo.getSlotById(widget.slotId);

    if (slot != null) {
      final subject = await repo.getSubjectById(slot.subjectId);
      final buildings = await repo.getBuildings();
      CampusBuilding? building;

      if (slot.buildingId != null) {
        try {
          building = buildings.firstWhere(
            (b) => b.code.toLowerCase() == slot.buildingId!.toLowerCase(),
          );
        } catch (_) {}
      }

      if (mounted) {
        setState(() {
          _slot = slot;
          _subject = subject;
          _building = building;
          _isLoading = false;
        });
      }

      // Tải danh sách ghi chú đã gắn kết với ca học này
      if (getIt.isRegistered<NoteRepository>()) {
        try {
          final allNotes = await getIt<NoteRepository>().getAllNotes();
          final linked =
              allNotes.where((n) => n.slotId == widget.slotId).toList();
          if (mounted) {
            setState(() {
              _linkedNotes = linked;
            });
          }
        } catch (_) {}
      }
    } else {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _duplicateSlotToNextWeek() async {
    if (_slot == null) return;
    final slot = _slot!;
    final nextWeekDate = slot.termStart.add(const Duration(days: 7));
    final nextDateOnly =
        DateTime(nextWeekDate.year, nextWeekDate.month, nextWeekDate.day);

    final newSlot = slot.copyWith(
      id: const Uuid().v4(),
      termStart: nextDateOnly,
      termEnd: nextDateOnly,
      dayOfWeek: nextDateOnly.weekday,
      source: 'user',
      updatedAt: DateTime.now(),
    );

    final repo = getIt<TimetableRepository>();
    await repo.saveSlots([newSlot]);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Đã thêm ca học sang tuần sau (${DateFormat('dd/MM/yyyy').format(nextDateOnly)}) thành công!',
          ),
          backgroundColor: Colors.green,
        ),
      );
    }
  }

  Future<void> _confirmDeleteSlot() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Xóa ca học'),
        content: Text(
          'Bạn có chắc chắn muốn xóa ca học "${_subject?.name ?? _slot?.subjectId}" khỏi thời khóa biểu không?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Hủy'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Xóa'),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      final repo = getIt<TimetableRepository>();
      await repo.deleteSlot(widget.slotId);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Đã xóa ca học khỏi thời khóa biểu.'),
            backgroundColor: Colors.redAccent,
          ),
        );
        Navigator.of(context).pop();
      }
    }
  }

  Future<void> _openEditSlotModal() async {
    if (_slot == null) return;
    final slot = _slot!;
    final subject = _subject;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (bottomSheetContext) => _EditSlotBottomSheet(
        initialSubjectName: subject?.name ?? slot.subjectId,
        initialRoom: slot.room,
        initialBuilding: slot.buildingId ?? '',
        initialDate: slot.termStart,
        initialStartTime: TimeOfDay(
          hour: slot.startMin ~/ 60,
          minute: slot.startMin % 60,
        ),
        initialEndTime: TimeOfDay(
          hour: slot.endMin ~/ 60,
          minute: slot.endMin % 60,
        ),
        onSave: ({
          required String subjectName,
          required String room,
          String? building,
          required DateTime date,
          required TimeOfDay startTime,
          required TimeOfDay endTime,
          int repeatWeeks = 0,
        }) async {
          final repo = getIt<TimetableRepository>();

          // 1. Cập nhật Subject nếu tên thay đổi
          if (subject != null && subject.name != subjectName) {
            final updatedSubject = subject.copyWith(
              name: subjectName,
              updatedAt: DateTime.now(),
            );
            await repo.saveSubject(updatedSubject);
          }

          // 2. Cập nhật Slot hiện tại
          final startMin = startTime.hour * 60 + startTime.minute;
          final endMin = endTime.hour * 60 + endTime.minute;
          final dateOnly = DateTime(date.year, date.month, date.day);

          final updatedSlot = slot.copyWith(
            room: room,
            buildingId: building,
            dayOfWeek: date.weekday,
            startMin: startMin,
            endMin: endMin,
            termStart: dateOnly,
            termEnd: dateOnly,
            updatedAt: DateTime.now(),
          );

          // 3. Nếu người dùng chọn thêm các tuần tiếp theo
          final extraSlots = <TimetableSlot>[];
          if (repeatWeeks > 0) {
            for (int i = 1; i <= repeatWeeks; i++) {
              final nextDate = dateOnly.add(Duration(days: 7 * i));
              extraSlots.add(
                slot.copyWith(
                  id: const Uuid().v4(),
                  room: room,
                  buildingId: building,
                  dayOfWeek: nextDate.weekday,
                  startMin: startMin,
                  endMin: endMin,
                  termStart: nextDate,
                  termEnd: nextDate,
                  source: 'user',
                  updatedAt: DateTime.now(),
                ),
              );
            }
          }

          await repo.saveSlots([updatedSlot, ...extraSlots]);
          await _loadSlotDetails();

          if (mounted) {
            final msg = repeatWeeks > 0
                ? 'Đã cập nhật ca học và tạo thêm $repeatWeeks tuần tiếp theo!'
                : 'Đã cập nhật ca học thành công!';
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(msg),
                backgroundColor: Colors.green,
              ),
            );
          }
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(title: const Text(AppStrings.slotDetails)),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    if (_slot == null) {
      return Scaffold(
        appBar: AppBar(title: const Text(AppStrings.slotDetails)),
        body: const Center(child: Text('Không tìm thấy ca học này.')),
      );
    }

    final slot = _slot!;
    final subject = _subject;
    final subjectColor = subject != null
        ? Color(subject.colorArgb)
        : theme.colorScheme.primary;

    return Scaffold(
      appBar: AppBar(
        title: const Text(AppStrings.slotDetails),
        actions: [
          IconButton(
            icon: const Icon(Icons.add_to_photos_outlined),
            tooltip: 'Thêm ca học sang tuần sau',
            onPressed: _duplicateSlotToNextWeek,
          ),
          IconButton(
            icon: const Icon(Icons.edit_outlined),
            tooltip: 'Chỉnh sửa ca học',
            onPressed: _openEditSlotModal,
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline_rounded),
            tooltip: 'Xóa ca học',
            onPressed: _confirmDeleteSlot,
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // 1. Thẻ thông tin tiêu đề môn học
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: subjectColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: subjectColor.withValues(alpha: 0.3),
                  width: 1.5,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: subjectColor,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          subject?.code ?? 'MÔN HỌC',
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      // Nhãn nguồn: Hệ thống hay Cá nhân
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: slot.isSystem
                              ? theme.colorScheme.secondaryContainer
                              : theme.colorScheme.tertiaryContainer,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          slot.isSystem ? 'Lịch hệ thống' : 'Lịch cá nhân',
                          style: TextStyle(
                            color: slot.isSystem
                                ? theme.colorScheme.onSecondaryContainer
                                : theme.colorScheme.onTertiaryContainer,
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    subject?.name ?? 'Môn học (${slot.subjectId})',
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Số tín chỉ: ${subject?.credits ?? 3} tín chỉ',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),

            // 2. Thẻ Thời gian & Địa điểm phòng học
            Card(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  children: [
                    _buildInfoRow(
                      context,
                      icon: Icons.calendar_today_outlined,
                      label: 'Ngày diễn ra',
                      value: '${DateFormat('dd/MM/yyyy').format(slot.termStart)} (${_formatWeekday(slot.dayOfWeek)})',
                    ),
                    const Divider(height: 20),
                    _buildInfoRow(
                      context,
                      icon: Icons.access_time_rounded,
                      label: 'Thời gian học',
                      value: '${slot.startTimeFormatted} - ${slot.endTimeFormatted}',
                    ),
                    const Divider(height: 20),
                    _buildInfoRow(
                      context,
                      icon: Icons.meeting_room_outlined,
                      label: AppStrings.room,
                      value: slot.room.trim().isEmpty ? 'Chưa xếp phòng' : 'Phòng ${slot.room}',
                    ),
                    if (slot.buildingId != null && slot.buildingId!.isNotEmpty) ...[
                      const Divider(height: 20),
                      _buildInfoRow(
                        context,
                        icon: Icons.business_outlined,
                        label: AppStrings.building,
                        value: _building?.name ?? 'Tòa ${slot.buildingId}',
                      ),
                    ],
                  ],
                ),
              ),
            ),

            const SizedBox(height: 20),

            // 3. Tùy chọn Nhắc nhở giờ học (Chủ đề 7 - FR-06)
            Card(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            Icon(
                              _isReminderEnabled
                                  ? Icons.notifications_active_outlined
                                  : Icons.notifications_off_outlined,
                              color: theme.colorScheme.primary,
                            ),
                            const SizedBox(width: 10),
                            Text(
                              'Nhắc giờ học',
                              style: theme.textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                        Switch(
                          value: _isReminderEnabled,
                          onChanged: (val) {
                            setState(() {
                              _isReminderEnabled = val;
                            });
                          },
                        ),
                      ],
                    ),
                    if (_isReminderEnabled) ...[
                      const SizedBox(height: 12),
                      Text(
                        'Thời gian báo trước giờ vào lớp:',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: 8),
                      // Cho phép chọn 5, 10, 15, 30 phút theo yêu cầu FR-06
                      Wrap(
                        spacing: 8,
                        children: [5, 10, 15, 30].map((mins) {
                          final isSelected = _reminderLeadMinutes == mins;
                          return ChoiceChip(
                            label: Text('$mins phút'),
                            selected: isSelected,
                            onSelected: (selected) {
                              if (selected) {
                                setState(() {
                                  _reminderLeadMinutes = mins;
                                });
                              }
                            },
                          );
                        }).toList(),
                      ),
                    ],
                  ],
                ),
              ),
            ),

            const SizedBox(height: 24),

            // 4. Mục Ghi chú liên kết ca học
            if (_linkedNotes.isNotEmpty) ...[
              Card(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.notes_rounded,
                              color: theme.colorScheme.primary),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Ghi chú bài giảng (${_linkedNotes.length})',
                              style: theme.textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      ..._linkedNotes.map((note) {
                        final title = note.title.isNotEmpty
                            ? note.title
                            : 'Ghi chú ${DateFormat('dd/MM/yyyy HH:mm').format(note.updatedAt)}';
                        final snippet = note.bodyText.isNotEmpty
                            ? note.bodyText
                            : (note.imagePaths.isNotEmpty
                                ? '[Có ${note.imagePaths.length} ảnh đính kèm]'
                                : 'Chưa có nội dung');
                        return Card(
                          elevation: 0,
                          color: theme.colorScheme.surfaceContainerHighest
                              .withValues(alpha: 0.5),
                          margin: const EdgeInsets.only(bottom: 8),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                            side: BorderSide(
                              color: theme.colorScheme.outlineVariant,
                            ),
                          ),
                          child: ListTile(
                            leading: Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: theme.colorScheme.primaryContainer,
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                Icons.edit_note_rounded,
                                color: theme.colorScheme.primary,
                                size: 20,
                              ),
                            ),
                            title: Text(
                              title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style:
                                  const TextStyle(fontWeight: FontWeight.bold),
                            ),
                            subtitle: Text(
                              snippet,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: theme.textTheme.bodySmall,
                            ),
                            trailing: const Icon(
                              Icons.arrow_forward_ios_rounded,
                              size: 14,
                            ),
                            onTap: () async {
                              await context.push(Routes.noteEdit(note.id));
                              await _loadSlotDetails();
                            },
                          ),
                        );
                      }),
                      const SizedBox(height: 8),
                      OutlinedButton.icon(
                        icon: const Icon(Icons.add),
                        label: const Text('Viết thêm ghi chú khác cho ca này'),
                        style: OutlinedButton.styleFrom(
                          minimumSize: const Size(double.infinity, 44),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        onPressed: () async {
                          final newNoteId = const Uuid().v4();
                          final uri = Uri(
                            path: Routes.noteEdit(newNoteId),
                            queryParameters: {
                              'subjectId': slot.subjectId,
                              'slotId': slot.id,
                            },
                          );
                          await context.push(
                            uri.toString(),
                            extra: {
                              'subjectId': slot.subjectId,
                              'slotId': slot.id,
                            },
                          );
                          await _loadSlotDetails();
                        },
                      ),
                    ],
                  ),
                ),
              ),
            ] else ...[
              FilledButton.icon(
                icon: const Icon(Icons.note_add_outlined),
                label: const Text(AppStrings.createNoteForSlot),
                style: FilledButton.styleFrom(
                  minimumSize: const Size(double.infinity, 50),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                onPressed: () async {
                  final newNoteId = const Uuid().v4();
                  final uri = Uri(
                    path: Routes.noteEdit(newNoteId),
                    queryParameters: {
                      'subjectId': slot.subjectId,
                      'slotId': slot.id,
                    },
                  );
                  await context.push(
                    uri.toString(),
                    extra: {
                      'subjectId': slot.subjectId,
                      'slotId': slot.id,
                    },
                  );
                  await _loadSlotDetails();
                },
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(
    BuildContext context, {
    required IconData icon,
    required String label,
    required String value,
  }) {
    final theme = Theme.of(context);
    return Row(
      children: [
        Icon(icon, size: 20, color: theme.colorScheme.primary),
        const SizedBox(width: 12),
        Text(
          label,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Text(
            value,
            textAlign: TextAlign.end,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ],
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

/// BottomSheet cho phép chỉnh sửa thông tin ca học
class _EditSlotBottomSheet extends StatefulWidget {
  final String initialSubjectName;
  final String initialRoom;
  final String initialBuilding;
  final DateTime initialDate;
  final TimeOfDay initialStartTime;
  final TimeOfDay initialEndTime;
  final Future<void> Function({
    required String subjectName,
    required String room,
    String? building,
    required DateTime date,
    required TimeOfDay startTime,
    required TimeOfDay endTime,
    int repeatWeeks,
  }) onSave;

  const _EditSlotBottomSheet({
    required this.initialSubjectName,
    required this.initialRoom,
    required this.initialBuilding,
    required this.initialDate,
    required this.initialStartTime,
    required this.initialEndTime,
    required this.onSave,
  });

  @override
  State<_EditSlotBottomSheet> createState() => _EditSlotBottomSheetState();
}

class _EditSlotBottomSheetState extends State<_EditSlotBottomSheet> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _subjectController;
  late final TextEditingController _roomController;
  late final TextEditingController _buildingController;
  late DateTime _date;
  late TimeOfDay _startTime;
  late TimeOfDay _endTime;
  int _repeatWeeks = 0;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _subjectController =
        TextEditingController(text: widget.initialSubjectName);
    _roomController = TextEditingController(text: widget.initialRoom);
    _buildingController =
        TextEditingController(text: widget.initialBuilding);
    _date = widget.initialDate;
    _startTime = widget.initialStartTime;
    _endTime = widget.initialEndTime;
  }

  @override
  void dispose() {
    _subjectController.dispose();
    _roomController.dispose();
    _buildingController.dispose();
    super.dispose();
  }

  String _formatTime(TimeOfDay t) {
    final h = t.hour.toString().padLeft(2, '0');
    final m = t.minute.toString().padLeft(2, '0');
    return '$h:$m';
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(2020),
      lastDate: DateTime(2035),
    );
    if (picked != null) {
      setState(() => _date = picked);
    }
  }

  Future<void> _pickStartTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _startTime,
    );
    if (picked != null) {
      setState(() => _startTime = picked);
    }
  }

  Future<void> _pickEndTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _endTime,
    );
    if (picked != null) {
      setState(() => _endTime = picked);
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

    setState(() => _isSaving = true);

    try {
      await widget.onSave(
        subjectName: _subjectController.text.trim(),
        room: _roomController.text.trim(),
        building: _buildingController.text.trim().isNotEmpty
            ? _buildingController.text.trim()
            : null,
        date: _date,
        startTime: _startTime,
        endTime: _endTime,
        repeatWeeks: _repeatWeeks,
      );
      if (mounted) {
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSaving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Lỗi khi cập nhật ca học: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

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
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.primaryContainer,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.edit_calendar_rounded,
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
                          'Chỉnh sửa ca học',
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          'Cập nhật thông tin môn, phòng và thời gian',
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
              TextFormField(
                controller: _subjectController,
                decoration: const InputDecoration(
                  labelText: 'Tên môn học / Sự kiện *',
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
              Row(
                children: [
                  Expanded(
                    flex: 3,
                    child: TextFormField(
                      controller: _roomController,
                      decoration: const InputDecoration(
                        labelText: 'Phòng học (tùy chọn)',
                        prefixIcon: Icon(Icons.room_outlined),
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 2,
                    child: TextFormField(
                      controller: _buildingController,
                      decoration: const InputDecoration(
                        labelText: 'Tòa nhà',
                        prefixIcon: Icon(Icons.business_outlined),
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              InkWell(
                onTap: _pickDate,
                borderRadius: BorderRadius.circular(8),
                child: InputDecorator(
                  decoration: const InputDecoration(
                    labelText: 'Ngày diễn ra *',
                    prefixIcon: Icon(Icons.calendar_today_rounded),
                    suffixIcon: Icon(Icons.arrow_drop_down),
                    border: OutlineInputBorder(),
                  ),
                  child: Text(
                    DateFormat('dd/MM/yyyy').format(_date),
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: InkWell(
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
              DropdownButtonFormField<int>(
                initialValue: _repeatWeeks,
                decoration: const InputDecoration(
                  labelText: 'Lặp lại / Thêm tuần tiếp theo',
                  prefixIcon: Icon(Icons.repeat_rounded),
                  border: OutlineInputBorder(),
                  helperText: 'Tự động tạo thêm ca học này vào các tuần sau',
                ),
                items: const [
                  DropdownMenuItem(
                    value: 0,
                    child: Text('Không lặp (Chỉ ngày này)'),
                  ),
                  DropdownMenuItem(
                    value: 1,
                    child: Text('Thêm vào 1 tuần sau (+1 tuần)'),
                  ),
                  DropdownMenuItem(
                    value: 2,
                    child: Text('Thêm vào 2 tuần sau (+2 tuần)'),
                  ),
                  DropdownMenuItem(
                    value: 4,
                    child: Text('Lặp 4 tuần tiếp theo (+4 tuần)'),
                  ),
                  DropdownMenuItem(
                    value: 8,
                    child: Text('Lặp cả học kỳ (+8 tuần)'),
                  ),
                ],
                onChanged: (val) {
                  if (val != null) {
                    setState(() => _repeatWeeks = val);
                  }
                },
              ),
              const SizedBox(height: 16),
              FilledButton.icon(
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
                  _isSaving ? 'Đang lưu...' : 'Lưu thay đổi',
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
