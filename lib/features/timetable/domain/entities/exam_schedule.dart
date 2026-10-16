/// Thực thể Lịch thi - Domain Layer.
class ExamSchedule {
  final String id;
  final String subjectId;
  final DateTime date;       // Ngày thi
  final int startMin;        // Giờ thi (số phút từ 00:00)
  final int durationMin;     // Thời lượng thi (phút)
  final String room;         // Phòng thi
  final String? buildingId;  // Tòa nhà
  final String source;       // "system"

  const ExamSchedule({
    required this.id,
    required this.subjectId,
    required this.date,
    required this.startMin,
    required this.durationMin,
    required this.room,
    this.buildingId,
    required this.source,
  });

  String get startTimeFormatted {
    final h = startMin ~/ 60;
    final m = startMin % 60;
    return '${h.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')}';
  }
}
