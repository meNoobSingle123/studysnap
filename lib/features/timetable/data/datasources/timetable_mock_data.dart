import '../models/building_model.dart';
import '../models/exam_model.dart';
import '../models/slot_model.dart';
import '../models/subject_model.dart';

/// Dữ liệu mẫu chuẩn của StudySnap (Do Huy phụ trách theo SRS mục 13.2).
///
/// Bao gồm 10 mã phòng chuẩn theo tòa nhà (H2, H1, B3, A1),
/// danh sách môn học đại học chuẩn, và thời khóa biểu trong tuần.
abstract final class TimetableMockData {
  // 1. Danh sách Tòa nhà khuôn viên trường (Campus Buildings)
  static final List<CampusBuildingModel> buildings = [
    const CampusBuildingModel(
      id: 'H2',
      code: 'H2',
      name: 'Tòa H2 - Khoa Công nghệ Thông tin',
      latitude: 10.8018,
      longitude: 106.7142,
    ),
    const CampusBuildingModel(
      id: 'H1',
      code: 'H1',
      name: 'Tòa H1 - Giảng đường Trung tâm',
      latitude: 10.8012,
      longitude: 106.7138,
    ),
    const CampusBuildingModel(
      id: 'B3',
      code: 'B3',
      name: 'Tòa B3 - Trung tâm Thí nghiệm',
      latitude: 10.8025,
      longitude: 106.7150,
    ),
    const CampusBuildingModel(
      id: 'A1',
      code: 'A1',
      name: 'Tòa A1 - Nhà Hiệu bộ & Thư viện',
      latitude: 10.8008,
      longitude: 106.7132,
    ),
  ];

  // 2. Danh sách Môn học (Subjects)
  static final List<SubjectModel> subjects = [
    SubjectModel(
      id: 'subj_cs201',
      code: 'CS201',
      name: 'Cấu trúc dữ liệu & Giải thuật',
      credits: 4,
      colorArgb: 0xFF1E88E5, // Xanh dương
      createdAt: DateTime(2026, 10, 1),
      updatedAt: DateTime(2026, 10, 1),
    ),
    SubjectModel(
      id: 'subj_cmp177',
      code: 'CMP177',
      name: 'Lập trình trên thiết bị di động (Flutter)',
      credits: 3,
      colorArgb: 0xFF43A047, // Xanh lá
      createdAt: DateTime(2026, 10, 1),
      updatedAt: DateTime(2026, 10, 1),
    ),
    SubjectModel(
      id: 'subj_se302',
      code: 'SE302',
      name: 'Kiến trúc & Thiết kế Phần mềm',
      credits: 3,
      colorArgb: 0xFFE53935, // Đỏ
      createdAt: DateTime(2026, 10, 1),
      updatedAt: DateTime(2026, 10, 1),
    ),
    SubjectModel(
      id: 'subj_net103',
      code: 'NET103',
      name: 'Mạng máy tính & Truyền thông',
      credits: 3,
      colorArgb: 0xFFFB8C00, // Cam
      createdAt: DateTime(2026, 10, 1),
      updatedAt: DateTime(2026, 10, 1),
    ),
    SubjectModel(
      id: 'subj_ai401',
      code: 'AI401',
      name: 'Trí tuệ nhân tạo & Thị giác máy tính',
      credits: 3,
      colorArgb: 0xFF8E24AA, // Tím
      createdAt: DateTime(2026, 10, 1),
      updatedAt: DateTime(2026, 10, 1),
    ),
  ];

  // 3. Danh sách Ca học trong tuần (10 phòng chuẩn: H2.304, H2.501, H1.201, B3.102...)
  static List<TimetableSlotModel> getSlots() {
    final termStart = DateTime(2026, 10, 19);
    final termEnd = DateTime(2027, 1, 15);
    final now = DateTime.now();

    return [
      // Thứ Hai (dayOfWeek: 1)
      TimetableSlotModel(
        id: 'slot_mon_01',
        subjectId: 'subj_cs201',
        dayOfWeek: 1,
        startMin: 450, // 07:30
        endMin: 570,   // 09:30
        room: 'H2.304',
        buildingId: 'H2',
        termStart: termStart,
        termEnd: termEnd,
        source: 'system',
        updatedAt: now,
      ),
      TimetableSlotModel(
        id: 'slot_mon_02',
        subjectId: 'subj_net103',
        dayOfWeek: 1,
        startMin: 810, // 13:30
        endMin: 930,   // 15:30
        room: 'H1.201',
        buildingId: 'H1',
        termStart: termStart,
        termEnd: termEnd,
        source: 'system',
        updatedAt: now,
      ),

      // Thứ Ba (dayOfWeek: 2)
      TimetableSlotModel(
        id: 'slot_tue_01',
        subjectId: 'subj_cmp177',
        dayOfWeek: 2,
        startMin: 450, // 07:30
        endMin: 600,   // 10:00
        room: 'H2.501',
        buildingId: 'H2',
        termStart: termStart,
        termEnd: termEnd,
        source: 'system',
        updatedAt: now,
      ),

      // Thứ Tư (dayOfWeek: 3)
      TimetableSlotModel(
        id: 'slot_wed_01',
        subjectId: 'subj_se302',
        dayOfWeek: 3,
        startMin: 450, // 07:30
        endMin: 570,   // 09:30
        room: 'B3.102',
        buildingId: 'B3',
        termStart: termStart,
        termEnd: termEnd,
        source: 'system',
        updatedAt: now,
      ),
      TimetableSlotModel(
        id: 'slot_wed_02',
        subjectId: 'subj_cs201',
        dayOfWeek: 3,
        startMin: 600, // 10:00
        endMin: 700,   // 11:40
        room: 'H2.304',
        buildingId: 'H2',
        termStart: termStart,
        termEnd: termEnd,
        source: 'system',
        updatedAt: now,
      ),

      // Thứ Năm (dayOfWeek: 4)
      TimetableSlotModel(
        id: 'slot_thu_01',
        subjectId: 'subj_cmp177',
        dayOfWeek: 4,
        startMin: 810, // 13:30
        endMin: 990,   // 16:30
        room: 'H2.502',
        buildingId: 'H2',
        termStart: termStart,
        termEnd: termEnd,
        source: 'system',
        updatedAt: now,
      ),

      // Thứ Sáu (dayOfWeek: 5)
      TimetableSlotModel(
        id: 'slot_fri_01',
        subjectId: 'subj_ai401',
        dayOfWeek: 5,
        startMin: 450, // 07:30
        endMin: 630,   // 10:30
        room: 'B3.205',
        buildingId: 'B3',
        termStart: termStart,
        termEnd: termEnd,
        source: 'system',
        updatedAt: now,
      ),

      // Thứ Bảy (dayOfWeek: 6)
      TimetableSlotModel(
        id: 'slot_sat_01',
        subjectId: 'subj_net103',
        dayOfWeek: 6,
        startMin: 510, // 08:30
        endMin: 630,   // 10:30
        room: 'A1.401',
        buildingId: 'A1',
        termStart: termStart,
        termEnd: termEnd,
        source: 'user', // Ca tự học do người dùng thêm
        updatedAt: now,
      ),

      // Chủ Nhật (dayOfWeek: 7)
      TimetableSlotModel(
        id: 'slot_sun_01',
        subjectId: 'subj_cmp177',
        dayOfWeek: 7,
        startMin: 540, // 09:00
        endMin: 660,   // 11:00
        room: 'H2.304',
        buildingId: 'H2',
        termStart: termStart,
        termEnd: termEnd,
        source: 'user',
        updatedAt: now,
      ),
    ];
  }

  // 4. Danh sách Lịch thi mẫu (Exams)
  static final List<ExamScheduleModel> exams = [
    ExamScheduleModel(
      id: 'exam_cs201',
      subjectId: 'subj_cs201',
      date: DateTime(2027, 1, 18),
      startMin: 450, // 07:30
      durationMin: 90,
      room: 'H2.304',
      buildingId: 'H2',
      source: 'system',
    ),
    ExamScheduleModel(
      id: 'exam_cmp177',
      subjectId: 'subj_cmp177',
      date: DateTime(2027, 1, 20),
      startMin: 810, // 13:30
      durationMin: 90,
      room: 'H2.501',
      buildingId: 'H2',
      source: 'system',
    ),
  ];
}
