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
<<<<<<< HEAD
=======
  static const String searchNotesHint = 'Tìm kiếm theo tiêu đề, nội dung...';
  static const String allSubjects = 'Tất cả môn';
  static const String filterByDate = 'Lọc theo ngày';
  static const String resetFilters = 'Đặt lại bộ lọc';
  static const String noMatchingNotes = 'Không tìm thấy ghi chú nào phù hợp.';
  static const String sortNewest = 'Mới nhất';
  static const String sortOldest = 'Cũ nhất';
  static const String sortTitleAz = 'Tên (A-Z)';
  static const String deleteNoteConfirmTitle = 'Xóa ghi chú?';
  static const String deleteNoteConfirmMessage = 'Ghi chú này sẽ bị xóa khỏi danh sách. Bạn có chắc chắn muốn xóa?';
  static const String untitledNote = 'Ghi chú không tiêu đề';
>>>>>>> origin/feature/huy-tasks

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
  static const String biometricLockTitle = 'Khóa ứng dụng bằng sinh trắc học';
  static const String biometricLockSubtitle = 'Yêu cầu vân tay hoặc mã PIN khi mở ứng dụng';
  static const String biometricLockEnabledSuccess = 'Đã bật khóa sinh trắc học';
  static const String biometricLockDisabledSuccess = 'Đã tắt khóa sinh trắc học';
  static const String biometricAuthRequiredToEnable = 'Xác thực để bật khóa ứng dụng';

  // Tools & Settings Feature (S10, S13)
  static const String toolsTitle = 'Công cụ & Cài đặt';
  static const String mapNavigation = 'Chỉ đường khuôn viên (Google Maps)';
  static const String appSettings = 'Cài đặt hệ thống';

  // Scanner & Camera Feature (S08, CĐ 10)
  static const String scannerTitle = 'Camera & Quét mã QR';
  static const String qrScannerTab = 'Quét mã QR';
  static const String cameraCaptureTab = 'Chụp ảnh bài giảng';
  static const String scanQrPrompt = 'Hướng camera về phía mã QR tài liệu';
  static const String invalidQrCode =
      'Mã QR không hợp lệ. Chỉ chấp nhận mã có định dạng studysnap://doc?url=https://...';
  static const String insecureHttpBlocked =
      'Liên kết bị từ chối vì không sử dụng giao thức HTTPS bảo mật.';
  static const String qrDocumentConfirmTitle = 'Xác nhận mở tài liệu';
  static const String qrDocumentConfirmMessage =
      'Bạn có muốn mở tài liệu từ tên miền:';
  static const String openInBrowser = 'Mở trình duyệt';
  static const String needNetworkConnection = 'Cần kết nối mạng để mở tài liệu';
  static const String cameraPermissionRequired = 'Cần cấp quyền Camera';
  static const String cameraPermissionGuide =
      'Ứng dụng cần quyền Camera để chụp ảnh bài giảng và quét mã QR tài liệu. Vui lòng cấp quyền trong Cài đặt hệ thống.';
  static const String openAppSettings = 'Mở Cài đặt';
  static const String capturedImages = 'Ảnh bài giảng đã chụp';
  static const String noImagesCaptured =
      'Chưa có ảnh bài giảng nào. Bấm vào nút camera để chụp hoặc chọn ảnh.';
  static const String takePhoto = 'Chụp ảnh';
  static const String pickFromGallery = 'Chọn từ thư viện';
  static const String compressingImage = 'Đang tối ưu & nén ảnh...';
  static const String createNoteFromImage = 'Tạo ghi chú từ ảnh';
  static const String testSampleQrCodes = 'Thử nghiệm mã QR mẫu';
  static const String sampleValidQr1 = 'Mã hợp lệ (HCMUS Syllabus)';
  static const String sampleValidQr2 = 'Mã hợp lệ (Google Drive)';
  static const String sampleInvalidHttp = 'Mã không hợp lệ (HTTP không an toàn)';
  static const String sampleInvalidScheme = 'Mã không hợp lệ (Sai Scheme)';

  // Timetable Feature (S02, S03, S04)
  static const String timetableTitle = 'Thời khóa biểu';
  static const String nextClassCountdown = 'Ca học tiếp theo';
  static const String noUpcomingClass = 'Không có ca học nào sắp tới hôm nay';
  static const String noClassToday = 'Hôm nay không có ca học nào';
  static const String gpaProjectionTitle = 'Dự phóng GPA';
  static const String currentGpa = 'GPA hiện tại';
  static const String completedCredits = 'Tín chỉ đã tích lũy';
  static const String remainingCredits = 'Tín chỉ còn lại';
  static const String targetGpa = 'GPA mục tiêu';
  static const String calculate = 'Tính toán';
  static const String gpaResult = 'Kết quả dự phóng';
  static const String slotDetails = 'Chi tiết ca học';
  static const String room = 'Phòng';
  static const String building = 'Tòa nhà';
  static const String credits = 'Tín chỉ';
  static const String reminderLead = 'Nhắc nhở trước';
  static const String getDirections = 'Chỉ đường';
  static const String createNoteForSlot = 'Tạo ghi chú cho ca này';

  // State Messages
  static const String loading = 'Đang tải...';
  static const String emptyData = 'Không có dữ liệu.';
  static const String success = 'Thao tác thành công';

  // Export PDF Feature (Huy - S09)
  static const String pdfExportTitle = 'Xuất & In PDF (A4)';
  static const String exportTimetable = 'Thời khóa biểu & Lịch thi';
  static const String exportNotes = 'Ghi chú bài giảng';
  static const String orientationPortrait = 'Khổ dọc (Portrait)';
  static const String orientationLandscape = 'Khổ ngang (Landscape)';
  static const String printPdf = 'In ấn';
  static const String sharePdf = 'Chia sẻ PDF';
  static const String openWithExternalApp = 'Mở ứng dụng ngoài';
  static const String pdfGeneratedSuccess = 'Tạo file PDF thành công';
  static const String benchmarkTitle = 'Chỉ số hiệu năng (NFR Benchmark)';
  static const String timetablePdfHeader = 'THỜI KHÓA BIỂU & LỊCH THI HỌC KỲ';
  static const String notePdfHeader = 'PHIẾU GHI CHÚ BÀI GIẢNG';
  static const String institutionName = 'ĐẠI HỌC KHOA HỌC TỰ NHIÊN - ĐHQG-HCM';

  // Notifications Feature (Huy - CĐ 7)
  static const String notificationTitle = 'Thông báo & Nhắc giờ';
  static const String notificationSettingsTitle = 'Cài đặt Nhắc giờ học (CĐ 7)';
  static const String notificationPermissionGranted = 'Đã cấp quyền thông báo';
  static const String notificationPermissionDenied = 'Chưa cấp quyền thông báo';
  static const String exactAlarmPermissionTitle = 'Quyền báo giờ chính xác (Exact Alarm)';
  static const String scheduleRollingReminders = 'Lên lịch nhắc tự động 7 ngày tới';
  static const String scheduleSuccessMessage = 'Đã lên lịch thành công cho các ca học sắp tới';
  static const String testNotificationTitle = 'Thử nghiệm thông báo tức thì';
  static const String testNotificationBody = 'StudySnap: Ca học tiếp theo sẽ bắt đầu sau 15 phút tại phòng H2.304!';
  static const String leadTimeTitle = 'Thời gian nhắc trước giờ học';
  static const String minutesLead = 'phút';
  static const String pendingReminders = 'Thông báo đang chờ phát';
  static const String noPendingReminders = 'Không có thông báo nào đang chờ';
  static const String cancelAllReminders = 'Hủy toàn bộ lịch nhắc';
  static const String reminderChannelName = 'Nhắc nhở lịch học & lịch thi';
  static const String reminderChannelDesc = 'Thông báo tự động nhắc trước giờ vào ca học hoặc ca thi';

  // Error Messages
  static const String errorNetwork = 'Lỗi kết nối mạng. Vui lòng kiểm tra lại đường truyền internet.';
  static const String errorServer = 'Hệ thống máy chủ đang bận. Vui lòng thử lại sau.';
  static const String errorStorage = 'Lỗi truy xuất cơ sở dữ liệu cục bộ.';
  static const String errorValidation = 'Dữ liệu nhập vào không hợp lệ.';
  static const String errorPermission = 'Ứng dụng chưa được cấp quyền để thực hiện tính năng này.';
  static const String errorUnknown = 'Đã có lỗi không xác định xảy ra. Vui lòng thử lại.';
  static const String pageNotFound = 'Không tìm thấy trang yêu cầu.';
  static const String errorPdfGeneration = 'Không thể tạo file PDF. Vui lòng thử lại.';
}

