import '../entities/campus_building.dart';
import '../entities/exam_schedule.dart';
import '../entities/subject.dart';
import '../entities/timetable_slot.dart';

/// Hợp đồng Repository cho phân hệ Thời khóa biểu & Môn học (Domain Layer).
///
/// Tuân thủ quy tắc Clean Architecture: Domain chỉ định nghĩa Interface Dart thuần,
/// không phụ thuộc vào Hive, SQLite hay Dio.
abstract class TimetableRepository {
  /// Lắng nghe luồng dữ liệu các ca học trong một ngày cụ thể (1=T2..7=CN).
  Stream<List<TimetableSlot>> watchSlotsByDay(int dayOfWeek);

  /// Lắng nghe luồng dữ liệu toàn bộ ca học đang hoạt động.
  Stream<List<TimetableSlot>> watchAllSlots();

  /// Lắng nghe luồng dữ liệu danh sách môn học (chưa bị xóa mềm).
  Stream<List<Subject>> watchSubjects();

  /// Lấy danh sách môn học một lần.
  Future<List<Subject>> getSubjects();

  /// Tìm môn học theo ID.
  Future<Subject?> getSubjectById(String id);

  /// Tạo mới hoặc cập nhật một môn học.
  Future<void> saveSubject(Subject subject);

  /// Xóa mềm một môn học theo ID.
  Future<void> softDeleteSubject(String id);

  /// Lưu danh sách ca học (từ server hoặc người dùng).
  Future<void> saveSlots(List<TimetableSlot> slots);

  /// Tìm ca học theo ID.
  Future<TimetableSlot?> getSlotById(String id);

  /// Xóa một ca học.
  Future<void> deleteSlot(String id);

  /// Lấy danh sách lịch thi.
  Future<List<ExamSchedule>> getExams();

  /// Lưu danh sách lịch thi.
  Future<void> saveExams(List<ExamSchedule> exams);

  /// Lấy danh sách tòa nhà khuôn viên trường.
  Future<List<CampusBuilding>> getBuildings();

  /// Lưu danh sách tòa nhà.
  Future<void> saveBuildings(List<CampusBuilding> buildings);
}
