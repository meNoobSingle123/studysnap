/// Centralized Vietnamese strings for StudySnap.
abstract final class AppStrings {
  // App General
  static const String appName = 'StudySnap';
  static const String appDescription = 'Ứng dụng hỗ trợ học tập và quản lý sinh viên';

  // Navigation / Tabs (3 Tabs)
  static const String timetableTab = 'Thời khóa biểu';
  static const String notesTab = 'Ghi chú';
  static const String toolsTab = 'Công cụ';

  // Common Actions
  static const String ok = 'Đồng ý';
  static const String cancel = 'Hủy';
  static const String save = 'Lưu';
  static const String delete = 'Xóa';
  static const String edit = 'Chỉnh sửa';
  static const String retry = 'Thử lại';
  static const String close = 'Đóng';
  // Timetable Feature (S02, CĐ 2, Chương 5)
  static const String syncTimetable = 'Đồng bộ';
  static const String syncingTimetable = 'Đang đồng bộ lịch học...';
  static const String syncTimetableSuccess = 'Đồng bộ lịch học thành công!';
  static const String syncTimetableFailed = 'Đồng bộ lịch học thất bại. Vui lòng thử lại.';

  // Notes Feature (S05, S06)
  static const String noteEditorTitle = 'Soạn ghi chú';
  static const String newNote = 'Ghi chú mới';
  static const String createNote = 'Tạo ghi chú';
  static const String noteTitleHint = 'Tiêu đề buổi học...';
  static const String noteContentHint = 'Nội dung bài giảng...';
  static const String noteSavedSuccess = 'Đã lưu ghi chú thành công.';
  static const String noteNotFound = 'Không tìm thấy ghi chú.';
  static const String emptyNotesList = 'Chưa có ghi chú nào. Hãy tạo ghi chú đầu tiên!';
  static const String savingStatus = 'Đang lưu...';
  static const String savedStatus = 'Đã lưu';
  static const String pinnedSlot = 'Ca học';
  static const String pinnedSubject = 'Môn học';

  // Canvas Drawing (S07)
  static const String canvasPageTitle = 'Bản vẽ ghi chú';
  static const String canvasModeView = 'Chế độ Xem';
  static const String canvasModeDraw = 'Chế độ Vẽ';
  static const String canvasPen = 'Bút vẽ';
  static const String canvasHighlighter = 'Highlight';
  static const String canvasEraser = 'Tẩy';
  static const String canvasUndo = 'Hoàn tác';
  static const String canvasRedo = 'Làm lại';
  static const String canvasClearAll = 'Xóa tất cả';
  static const String canvasClearConfirmTitle = 'Xóa toàn bộ nét vẽ?';
  static const String canvasClearConfirmMessage =
      'Tất cả các nét vẽ sẽ bị xóa. Bạn có chắc chắn muốn xóa không?';
  static const String canvasStrokeWidth = 'Cỡ nét';
  static const String canvasColors = 'Bảng màu';
  static const String canvasSaveNote = 'Lưu bản vẽ';
  static const String canvasExportSuccess = 'Đã lưu và xuất ảnh thành công';
  static const String canvasDiscardConfirmTitle = 'Rời khỏi bản vẽ?';
  static const String canvasDiscardConfirmMessage =
      'Các thay đổi chưa lưu sẽ bị mất. Bạn có chắc chắn muốn quay lại?';
  static const String canvasAttachmentTitle = 'Bản vẽ & Ảnh đính kèm';
  static const String canvasAddAttachment = 'Mở bản vẽ ghi chú';

  // Video Player & Split-View (S06, CĐ 6)
  static const String videoAttach = 'Gắn video bài giảng';
  static const String videoChange = 'Đổi video';
  static const String videoRemove = 'Gỡ video';
  static const String videoTimestampButton = 'Gắn mốc';
  static const String videoTimestampTooltip = 'Chèn mốc thời gian video vào văn bản';
  static const String videoMiniPlayerTitle = 'Video thu nhỏ';
  static const String videoSelectFailed = 'Không thể mở tệp video';
  static const String videoPlay = 'Phát';
  static const String videoPause = 'Tạm dừng';
  static const String videoTimestampsList = 'Mốc thời gian';
  static const String videoNoTimestamps = 'Chưa có mốc thời gian nào trong văn bản';
  static const String videoPlayerError = 'Không thể phát video này';

  // Security & App Lock (S01, CĐ 11)
  static const String appLockTitle = 'StudySnap đã khóa';
  static const String appLockSubtitle = 'Xác thực sinh trắc học hoặc PIN để tiếp tục';
  static const String unlockWithBiometrics = 'Mở khóa bằng sinh trắc học / PIN';
  static const String biometricsPrompt = 'Xác thực để mở khóa StudySnap';
  static const String biometricsNotAvailable = 'Thiết bị chưa thiết lập sinh trắc học hoặc mã PIN';
  static const String biometricsFailed = 'Xác thực không thành công. Vui lòng thử lại.';
  static const String biometricsSuccess = 'Mở khóa thành công';
  static const String appLocked = 'Ứng dụng đang khóa';
  static const String appUnlocked = 'Ứng dụng đã mở khóa';

  // Tools & Settings Feature (S10, S13)
  static const String toolsTitle = 'Công cụ & Cài đặt';
  static const String mapNavigation = 'Chỉ đường khuôn viên (Google Maps)';
  static const String appSettings = 'Cài đặt hệ thống';

  // State Messages
  static const String loading = 'Đang tải...';
  static const String emptyData = 'Không có dữ liệu.';
  static const String success = 'Thao tác thành công';

  // Error Messages
  static const String errorNetwork = 'Lỗi kết nối mạng. Vui lòng kiểm tra lại đường truyền internet.';
  static const String errorServer = 'Hệ thống máy chủ đang bận. Vui lòng thử lại sau.';
  static const String errorStorage = 'Lỗi truy xuất cơ sở dữ liệu cục bộ.';
  static const String errorValidation = 'Dữ liệu nhập vào không hợp lệ.';
  static const String errorPermission = 'Ứng dụng chưa được cấp quyền để thực hiện tính năng này.';
  static const String errorUnknown = 'Đã có lỗi không xác định xảy ra. Vui lòng thử lại.';
  static const String pageNotFound = 'Không tìm thấy trang yêu cầu.';
}
