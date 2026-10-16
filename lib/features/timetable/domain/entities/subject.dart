/// Thực thể Môn học - Domain Layer (Dart thuần, tuân thủ Clean Architecture).
class Subject {
  final String id;
  final String code;        // VD: "CS201"
  final String name;        // VD: "Cấu trúc dữ liệu"
  final int credits;        // Số tín chỉ
  final int colorArgb;      // Mã màu hiển thị dạng số nguyên ARGB
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? deletedAt; // Cơ chế xóa mềm (Soft delete)

  const Subject({
    required this.id,
    required this.code,
    required this.name,
    required this.credits,
    required this.colorArgb,
    required this.createdAt,
    required this.updatedAt,
    this.deletedAt,
  });

  /// Kiểm tra môn học đã bị xóa mềm hay chưa.
  bool get isDeleted => deletedAt != null;

  Subject copyWith({
    String? id,
    String? code,
    String? name,
    int? credits,
    int? colorArgb,
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
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      deletedAt: deletedAt ?? this.deletedAt,
    );
  }
}
