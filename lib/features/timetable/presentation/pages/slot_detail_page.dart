import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../../core/di/injection.dart';
import '../../../../core/l10n/strings.dart';
import '../../../../core/router/routes.dart';
import '../../domain/entities/campus_building.dart';
import '../../domain/entities/subject.dart';
import '../../domain/entities/timetable_slot.dart';
import '../../domain/repositories/timetable_repository.dart';

/// Màn hình S03: Chi tiết ca học (Do Huy phụ trách).
///
/// Hiển thị thông tin giảng đường, giờ học, nút chỉ đường Google Maps đi bộ,
/// tùy chọn thời gian nhắc nhở (5, 10, 15, 30 phút), và nút tạo ghi chú.
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
    } else {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _openWalkingDirections() async {
    if (_building == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Không tìm thấy tọa độ tòa nhà cho phòng này'),
        ),
      );
      return;
    }

    final lat = _building!.latitude;
    final lng = _building!.longitude;
    // Mở Google Maps ở chế độ đi bộ theo đặc tả mục 7.4
    final uri = Uri.parse(
      'https://www.google.com/maps/dir/?api=1&destination=$lat,$lng&travelmode=walking',
    );

    try {
      final launched = await launchUrl(
        uri,
        mode: LaunchMode.externalApplication,
      );
      if (!launched && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Không thể mở ứng dụng bản đồ')),
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Lỗi khi mở bản đồ')),
        );
      }
    }
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
                      label: 'Thứ trong tuần',
                      value: _formatWeekday(slot.dayOfWeek),
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
                      value: 'Phòng ${slot.room}',
                    ),
                    if (_building != null) ...[
                      const Divider(height: 20),
                      _buildInfoRow(
                        context,
                        icon: Icons.business_outlined,
                        label: AppStrings.building,
                        value: _building!.name,
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

            const SizedBox(height: 28),

            // 4. Các nút thao tác chính
            // Nút Chỉ đường (FR-18)
            OutlinedButton.icon(
              icon: const Icon(Icons.directions_walk_rounded),
              label: const Text(AppStrings.getDirections),
              style: OutlinedButton.styleFrom(
                minimumSize: const Size(double.infinity, 50),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              onPressed: _openWalkingDirections,
            ),
            const SizedBox(height: 12),

            // Nút Tạo ghi chú cho ca này
            FilledButton.icon(
              icon: const Icon(Icons.note_add_outlined),
              label: const Text(AppStrings.createNoteForSlot),
              style: FilledButton.styleFrom(
                minimumSize: const Size(double.infinity, 50),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              onPressed: () {
                context.push(
                  Routes.noteEdit('new'),
                  extra: {
                    'subjectId': slot.subjectId,
                    'slotId': slot.id,
                  },
                );
              },
            ),
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
