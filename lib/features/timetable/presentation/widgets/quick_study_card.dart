import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:uuid/uuid.dart';

import '../../../../core/router/routes.dart';
import '../../domain/entities/subject.dart';
import '../../domain/entities/timetable_slot.dart';

/// Thẻ học nhanh (Quick Study Card) thiết kế tinh gọn theo chuẩn BA.
/// Hiển thị ca học tiếp theo dạng thẻ mỏng, tiết kiệm tối đa không gian màn hình
/// để sinh viên nhìn thấy ngay danh sách tiết học bên dưới.
class QuickStudyCard extends StatelessWidget {
  final TimetableSlot? nextSlot;
  final int? minutesUntilNextSlot;
  final int todaySlotsCount;
  final Map<String, Subject> subjectsMap;

  const QuickStudyCard({
    super.key,
    required this.nextSlot,
    required this.minutesUntilNextSlot,
    required this.todaySlotsCount,
    required this.subjectsMap,
  });

  String _getTimeStatus(TimetableSlot slot) {
    if (minutesUntilNextSlot != null) {
      if (minutesUntilNextSlot! <= 0) {
        return 'Đang diễn ra';
      } else if (minutesUntilNextSlot! < 60) {
        return 'Bắt đầu sau $minutesUntilNextSlot phút';
      }
    }
    return '${slot.startTimeFormatted} - ${slot.endTimeFormatted}';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final slot = nextSlot;
    final subject = slot != null ? subjectsMap[slot.subjectId] : null;

    final subjectColor = subject != null
        ? Color(subject.colorArgb)
        : colorScheme.primary;

    if (slot != null) {
      return Card(
        elevation: 0,
        margin: const EdgeInsets.only(bottom: 10),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: BorderSide(
            color: colorScheme.outlineVariant.withValues(alpha: 0.6),
            width: 1,
          ),
        ),
        color: colorScheme.surfaceContainerLow,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              // Hàng trên: Tên môn, trạng thái thời gian và số ca học
              Row(
                children: [
                  Container(
                    width: 10,
                    height: 10,
                    decoration: BoxDecoration(
                      color: subjectColor,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      subject?.name ?? 'Môn học (${slot.subjectId})',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: (minutesUntilNextSlot != null &&
                              minutesUntilNextSlot! <= 0)
                          ? colorScheme.errorContainer
                          : colorScheme.primaryContainer,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      _getTimeStatus(slot),
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: (minutesUntilNextSlot != null &&
                                minutesUntilNextSlot! <= 0)
                            ? colorScheme.onErrorContainer
                            : colorScheme.onPrimaryContainer,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),

              // Hàng giữa: Địa điểm phòng & tòa nhà + badge số ca
              Row(
                children: [
                  Icon(
                    Icons.meeting_room_outlined,
                    size: 14,
                    color: colorScheme.onSurfaceVariant,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    'Phòng ${slot.room.isNotEmpty ? slot.room : 'Chưa xếp'}',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                  if (slot.buildingId != null &&
                      slot.buildingId!.isNotEmpty) ...[
                    const SizedBox(width: 10),
                    Icon(
                      Icons.business_outlined,
                      size: 14,
                      color: colorScheme.onSurfaceVariant,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      'Tòa ${slot.buildingId}',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                  const Spacer(),
                  Text(
                    todaySlotsCount > 0
                        ? '$todaySlotsCount ca học hôm nay'
                        : 'Không có ca học',
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: colorScheme.outline,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),

              // Hàng nút thao tác nhanh: Ghi chép ngay & Quét bảng OCR
              Row(
                children: [
                  Expanded(
                    child: FilledButton.tonalIcon(
                      style: FilledButton.styleFrom(
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        visualDensity: VisualDensity.compact,
                      ),
                      onPressed: () {
                        final newNoteId = const Uuid().v4();
                        context.push(
                          Routes.noteEdit(newNoteId),
                          extra: {
                            'subjectId': slot.subjectId,
                            'slotId': slot.id,
                          },
                        );
                      },
                      icon: const Icon(Icons.edit_note_rounded, size: 16),
                      label: const Text('Ghi chép ngay', style: TextStyle(fontSize: 12)),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        side: BorderSide(color: colorScheme.outlineVariant),
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        visualDensity: VisualDensity.compact,
                      ),
                      onPressed: () {
                        context.push(Routes.ocrScanner);
                      },
                      icon: const Icon(Icons.document_scanner_outlined, size: 16),
                      label: const Text('Quét bảng OCR', style: TextStyle(fontSize: 12)),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      );
    }

    // Khi không có ca học tiếp theo (hoặc đã học xong)
    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 10),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(
          color: colorScheme.outlineVariant.withValues(alpha: 0.5),
          width: 1,
        ),
      ),
      color: colorScheme.surfaceContainerLow,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        child: Row(
          children: [
            Icon(
              todaySlotsCount > 0
                  ? Icons.check_circle_outline_rounded
                  : Icons.beach_access_rounded,
              size: 20,
              color: todaySlotsCount > 0
                  ? Colors.teal
                  : colorScheme.onSurfaceVariant,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    todaySlotsCount > 0
                        ? 'Đã hoàn thành các ca học hôm nay! 🎉'
                        : 'Hôm nay bạn không có lịch học 🏖️',
                    style: theme.textTheme.bodySmall?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: colorScheme.onSurface,
                    ),
                  ),
                  Text(
                    todaySlotsCount > 0
                        ? '$todaySlotsCount ca học hôm nay'
                        : 'Không có ca học',
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: colorScheme.outline,
                    ),
                  ),
                ],
              ),
            ),
            IconButton(
              iconSize: 20,
              visualDensity: VisualDensity.compact,
              tooltip: 'Tạo ghi chú mới',
              onPressed: () {
                final newNoteId = const Uuid().v4();
                context.push(Routes.noteEdit(newNoteId));
              },
              icon: const Icon(Icons.add),
            ),
          ],
        ),
      ),
    );
  }
}
