/// Thực thể Môn học - Domain Layer (Dart thuần, tuân thủ Clean Architecture).
class Subject {
  final String id;
  final String code;        // VD: "CS201"
  final String name;        // VD: "Cấu trúc dữ liệu"
  final int credits;        // Số tín chỉ
  final int colorArgb;      // Mã màu hiển thị dạng số nguyên ARGB
  final double? gradePoint; // Điểm số hệ 4 (0.0 - 4.0), null nếu chưa có điểm
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? deletedAt; // Cơ chế xóa mềm (Soft delete)

  const Subject({
    required this.id,
    required this.code,
    required this.name,
    required this.credits,
    required this.colorArgb,
    this.gradePoint,
    required this.createdAt,
    required this.updatedAt,
    this.deletedAt,
  });

  /// Điểm chữ quy đổi theo thang điểm đại học
  String? get letterGrade {
    final point = gradePoint;
    if (point == null) return null;
    if (point >= 3.85) return 'A+';
    if (point >= 3.6) return 'A';
    if (point >= 3.25) return 'B+';
    if (point >= 2.75) return 'B';
    if (point >= 2.25) return 'C+';
    if (point >= 1.75) return 'C';
    if (point >= 1.25) return 'D+';
    if (point >= 0.75) return 'D';
    return 'F';
  }

  /// Kiểm tra môn học đã bị xóa mềm hay chưa.
  bool get isDeleted => deletedAt != null;

  Subject copyWith({
    String? id,
    String? code,
    String? name,
    int? credits,
    int? colorArgb,
    double? gradePoint,
    bool clearGrade = false,
    DateTime? createdAt,
    DateTime? updatedAt,
    DateTime? deletedAt,
  }) {
    return Subject(
      id: id ?? this.id,
      code: code ?? this.code,
      name: name ?? this.name,
      credits: credits ?? this.credits,
      colorArgb: colorArgb ?? this.colorArgb,
      gradePoint: clearGrade ? null : (gradePoint ?? this.gradePoint),
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      deletedAt: deletedAt ?? this.deletedAt,
    );
  }
}
