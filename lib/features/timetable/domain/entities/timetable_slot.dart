/// Thực thể Ca học trong thời khóa biểu - Domain Layer.
class TimetableSlot {
  final String id;
  final String subjectId;   // ID môn học liên kết
  final int dayOfWeek;      // 1=Thứ 2, 2=Thứ 3, ..., 7=Chủ nhật
  final int startMin;       // Số phút tính từ 00:00 (VD: 450 = 07:30)
  final int endMin;         // Số phút tính từ 00:00 (VD: 540 = 09:00)
  final String room;        // Phòng học, VD: "H2.304"
  final String? buildingId; // Tòa nhà, VD: "H2"
  final DateTime termStart; // Ngày bắt đầu học kỳ
  final DateTime termEnd;   // Ngày kết thúc học kỳ
  final String source;      // "system" (kéo từ trường) hoặc "user" (tự thêm)
  final DateTime updatedAt;
  final DateTime? deletedAt; // Xóa mềm

  const TimetableSlot({
    required this.id,
    required this.subjectId,
    required this.dayOfWeek,
    required this.startMin,
    required this.endMin,
    required this.room,
    this.buildingId,
    required this.termStart,
    required this.termEnd,
    required this.source,
    required this.updatedAt,
    this.deletedAt,
  });

  bool get isSystem => source == 'system';
  bool get isDeleted => deletedAt != null;

  /// Định dạng giờ bắt đầu "HH:mm" (VD: 450 -> "07:30").
  String get startTimeFormatted {
    final h = startMin ~/ 60;
    final m = startMin % 60;
    return '${h.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')}';
  }

  /// Định dạng giờ kết thúc "HH:mm" (VD: 540 -> "09:00").
  String get endTimeFormatted {
    final h = endMin ~/ 60;
    final m = endMin % 60;
    return '${h.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')}';
  }

  TimetableSlot copyWith({
    String? id,
    String? subjectId,
    int? dayOfWeek,
    int? startMin,
    int? endMin,
    String? room,
    String? buildingId,
    DateTime? termStart,
    DateTime? termEnd,
    String? source,
    DateTime? updatedAt,
    DateTime? deletedAt,
  }) {
    return TimetableSlot(
      id: id ?? this.id,
      subjectId: subjectId ?? this.subjectId,
      dayOfWeek: dayOfWeek ?? this.dayOfWeek,
      startMin: startMin ?? this.startMin,
      endMin: endMin ?? this.endMin,
      room: room ?? this.room,
      buildingId: buildingId ?? this.buildingId,
      termStart: termStart ?? this.termStart,
      termEnd: termEnd ?? this.termEnd,
      source: source ?? this.source,
      updatedAt: updatedAt ?? this.updatedAt,
      deletedAt: deletedAt ?? this.deletedAt,
    );
  }
}
