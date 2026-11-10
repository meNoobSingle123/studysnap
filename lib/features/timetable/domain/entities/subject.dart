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
    if (gradePoint == null) return null;
    if (gradePoint! >= 3.8) return 'A+';
    if (gradePoint! >= 3.5) return 'A';
    if (gradePoint! >= 3.0) return 'B+';
    if (gradePoint! >= 2.5) return 'B';
    if (gradePoint! >= 2.0) return 'C+';
    if (gradePoint! >= 1.5) return 'C';
    if (gradePoint! >= 1.0) return 'D';
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
