TÀI LIỆU ĐẶC TẢ YÊU CẦU VÀ KIẾN TRÚC HỆ THỐNG (SRS & SDD)
Dự án: StudySnap – v3 (Bản chuẩn triển khai)Cập nhật: 13/10/2026 – @Duy
StudySnap là ứng dụng Flutter phát triển theo hướng Local-First, giúp sinh viên tập hợp thời khóa biểu, ảnh chụp bảng, slide và video bài giảng vào một ghi chú thống nhất theo từng tiết học. Bản v3 chốt phạm vi MVP, dữ liệu, API, phân công và lộ trình 12 tuần để nhóm 3 người tiến hành lập trình.
CHƯƠNG 0: CÁC QUYẾT ĐỊNH ĐÃ CHỐT VÀ THAY ĐỔI SO VỚI V2
0.1. Quyết định cho các câu hỏi mở ở v2
Vấn đề
Quyết định tại v3
Hệ quả
Đồng bộ ghi chú lên server?
Không. Dữ liệu chỉ lưu trên máy. Mạng chỉ dùng để lấy thời khóa biểu, lịch thi, nhận FCM, thanh toán MoMo và mở Maps.
Bỏ SyncActionQueue và Client-Wins. Giữ UUID, updatedAt, deletedAt để mở rộng sau MVP.
Nghiệp vụ Quỹ môn học?
Thủ quỹ tạo khoản thu, chia sẻ mã 6 ký tự/QR. Sinh viên trả bằng MoMo Sandbox, backend ghi nhận qua IPN. Không có đăng nhập, định danh bằng deviceId.
Backend lưu giao dịch trên Firestore. Bỏ tính năng mua/đổi tài liệu ôn tập.
Hỗ trợ iOS không?
Giả định chưa có Mac/Apple Developer. Android là nền tảng nghiệm thu. iOS ở mức best-effort (biên dịch được nhưng không nằm trong Definition of Done).
Bỏ qua FCM trên iOS (do cần APNs).
Thời gian dự án?
12 tuần. Bắt đầu: 19/10/2026, Demo cuối: 08/01/2027.
Lộ trình tính theo tuần, có thể dời ngày nếu thực tế thay đổi.
0.2. Các thay đổi chính so với v2
Backend: Chuyển từ Postman Mock Server + Node/Firebase Functions sang một dịch vụ Node/Express duy nhất (deploy Render) dùng Firebase Admin cho Firestore và FCM. Postman chỉ dùng để test.
Đồng bộ: Chỉ tải dữ liệu hệ thống xuống (Server-Wins), không đẩy ghi chú lên.
Mã QR: Chốt 2 deep link cụ thể: vào quỹ và mở tài liệu.
Quyền ảnh & Camera: Bỏ quyền READ_MEDIA_IMAGES (dùng Photo Picker), bỏ thư viện camera (dùng image_picker chụp ảnh, mobile_scanner quét QR).
Bản đồ: Chỉ dùng url_launcher, bỏ google_maps_flutter để không cần Maps API key.
Cơ sở dữ liệu & Mã hóa: Dùng hive_ce, tách ảnh và nét vẽ thành NoteImage, chuẩn hóa tọa độ nét vẽ. Áp dụng mã hóa Hive ngay từ Chặng 1.
Phân công & Lộ trình: Seed API chuyển cho Huy. Lộ trình chốt 12 tuần, 4 mốc demo, DoD áp dụng cho cả 12 phân hệ.
CHƯƠNG 1: TỔNG QUAN VÀ PHẠM VI
1.1. Bài toán thực tế
Phân mảnh thông tin: Dữ liệu học tập rải rác ở cổng đào tạo, email, thư viện ảnh, link video gây khó tra cứu.
Khó liên kết: Tư liệu không gắn với từng tiết học hay mốc thời gian, làm giảm hiệu quả ôn tập.
Mạng yếu: Ứng dụng phụ thuộc máy chủ dễ bị gián đoạn tại giảng đường.
1.2. Đối tượng và nền tảng
Đối tượng: Sinh viên đại học, cao đẳng, học viên khóa chuyên đề.
Nền tảng: Android 6.0 (API 23) trở lên (nghiệm thu). iOS 15.5 trở lên (best-effort, theo yêu cầu của ML Kit).
1.3. Phạm vi MVP (Minimum Viable Product)
• Trong phạm vi (In-Scope):
Thời khóa biểu, lịch thi, nhắc giờ học trước 15 phút (vượt Doze mode).
Ghi chú theo tiết học (văn bản, nhiều ảnh, vẽ vector có Undo/Redo, video có mốc thời gian).
Nhận diện OCR trên máy cho ảnh chụp bảng/slide.
Xuất PDF A4 chuẩn tiếng Việt.
Chỉ đường đi bộ đến tòa nhà (Google Maps) và tự gắn vị trí ghi chú.
Quản lý quỹ lớp, thanh toán MoMo Sandbox.
Thông báo đổi lịch qua FCM.
Mã hóa dữ liệu và khóa sinh trắc học.
• Ngoài phạm vi (Out-of-Scope):
Chat thời gian thực, điểm danh tự động phía trường, nhận diện khuôn mặt.
Tài khoản đăng nhập, đồng bộ ghi chú lên đám mây, mua bán tài liệu.
Quay video/ghi âm trực tiếp trong app (chỉ lấy từ thư viện).
FCM trên iOS, phát hành lên Store.
1.4. Kịch bản Demo chính (Chạy liên tục)
Mở app, mở khóa vân tay, kéo thời khóa biểu từ API.
Nhận thông báo FCM dời phòng, lịch tự cập nhật.
(Bật chế độ máy bay) Tạo ghi chú, vị trí tự động được ghim.
(Chế độ máy bay) Chụp ảnh bảng, chạy OCR, chữ chèn vào ghi chú.
(Chế độ máy bay) Vẽ/tô highlight lên ảnh, Undo, lưu lại.
(Chế độ máy bay) Chọn video, chèn mốc thời gian, chạm mốc để tua.
(Chế độ máy bay) Xuất PDF A4, mở kiểm tra tiếng Việt.
(Bật mạng) Tạo khoản thu, quét QR bằng máy phụ, thanh toán MoMo Sandbox.
CHƯƠNG 2: YÊU CẦU CHỨC NĂNG (FR)
(M: Bắt buộc, S: Nên có, cắt đầu tiên nếu trễ tiến độ)
Mã
Yêu cầu chức năng
Chủ đề
Ưu tiên
FR-01
Thêm, sửa, xóa môn học (mã, tên, tín chỉ, màu)
2
M
FR-02
Xem lịch tuần/tháng, chạm ngày xem ca học
2
M
FR-03
Kéo lịch từ API, phân loại nhãn hệ thống/cá nhân
5
M
FR-04
Thẻ ca học hiển thị phòng, giờ, đếm ngược ca tiếp theo
2
M
FR-05
Thanh trượt dự phóng GPA
2
S
FR-06
Nhắc giờ học trước 15 phút (có thể chọn 5, 10, 15, 30), bật/tắt theo ca
7
M
FR-07
Nhận thông báo đổi phòng/dời lịch (FCM) và cập nhật lịch
8
M
FR-08
Quản lý ghi chú gắn môn/ca; lọc theo môn, ngày, tòa nhà
11
M
FR-09
Soạn ghi chú, tự lưu sau 2 giây không thao tác
11
M
FR-10
Chụp/chọn ảnh từ thư viện, đính nhiều ảnh vào ghi chú
10
M
FR-11
Xem ảnh: kéo và phóng to tối đa 500%
3
M
FR-12
Vẽ tay, tô highlight, chọn màu, cỡ cọ 1-30px, Undo/Redo/Xóa hết
1, 2
M
FR-13
Lưu nét vector để sửa, đồng thời xuất ảnh phẳng
1
M
FR-14
OCR ảnh trên máy, chèn văn bản tại con trỏ
12
M
FR-15
Gắn video, phát Split-View, thu thành Mini-Player khi mở bàn phím
6
M
FR-16
Chèn mốc [mm:ss], chạm để tua video
6
M
FR-17
Tự gắn vị trí khi tạo ghi chú (cho phép tắt)
9
M
FR-18
Chỉ đường đi bộ từ thẻ ca học đến tòa nhà (Google Maps)
9
M
FR-19
Xuất PDF A4, xem trước và chia sẻ
4
M
FR-20
Quét QR vào quỹ hoặc mở tài liệu
10
S
FR-21
Thủ quỹ tạo khoản thu, nhận mã 6 ký tự và QR
8
S
FR-22
Tham gia khoản thu, xem số tiền và hạn đóng
8
S
FR-23
Thanh toán MoMo Sandbox, xem trạng thái
8
M
FR-24
Thủ quỹ xem danh sách đã đóng/chưa đóng
8
S
FR-25
Khóa ứng dụng (vân tay/FaceID/PIN)
11
M
FR-26
Mã hóa cơ sở dữ liệu cục bộ
11
M
FR-27
Giao diện Sáng/Tối
5
M
FR-28
Rung phản hồi khi thao tác
5
S
FR-29
Hiển thị banner khi mất mạng internet
5
M
FR-30
Xin quyền đúng ngữ cảnh, giải thích và dẫn vào Cài đặt
7
M
CHƯƠNG 4: MÔ HÌNH DỮ LIỆU
Tất cả thực thể dùng khóa chính UUID v4, nằm trong lớp Domain thuần (không chứa thư viện Flutter).
4.1. Thực thể chính
Subject: id, code, name, credits, colorArgb (xóa mềm bằng deletedAt).
TimetableSlot: id, subjectId, dayOfWeek, startMin, endMin, room, buildingId, source (Ca system chỉ đọc).
ExamSchedule: Lấy từ API.
LectureNote: Nội dung chứa token [mm:ss] cho mốc video.
NoteImage: flatPath lưu ảnh đã gộp nét, mỗi ảnh chứa một bộ nét vẽ (strokes) riêng.
Stroke: Lưu điểm chạm (points) dưới dạng số thực phẳng đã chuẩn hóa, cùng màu sắc và tỷ lệ độ dày nét.
LocationPoint: Lưu tọa độ GPS. placeName tự định vị tòa nhà gần nhất trong 150m.
FundCache / AppSettings: Quản lý cấu hình thiết bị (deviceId) và quỹ nội bộ.
4.2. Quy ước kỹ thuật dữ liệu
Tọa độ nét vẽ: Chuẩn hóa từ 0 đến 1 so với chiều rộng/cao ảnh gốc, đảm bảo nét vẽ không bị lệch khi zoom hay xoay màn hình. Dùng hàm toScene() để đổi tọa độ chạm trong InteractiveViewer.
Hive DB: Dùng hive_ce, mở hộp bằng HiveAesCipher (khóa sinh bằng Hive.generateSecureKey() lưu ở flutter_secure_storage).
Tệp đa phương tiện (ảnh/video): Lưu tại getApplicationDocumentsDirectory (chấp nhận rủi ro chưa mã hóa file trong MVP).
CHƯƠNG 5: BACKEND VÀ HỢP ĐỒNG API
Xây dựng qua dịch vụ Node/Express (deploy Render/Railway), dùng Firebase Admin (Firestore & FCM). Ứng dụng truyền UUID qua header X-Device-Id (không có tài khoản người dùng).
5.1. Danh sách Endpoint (tiền tố /v1)
HTTP
Đường dẫn
Mục đích
GET
/health
Kiểm tra kết nối mạng.
GET
/terms/current
Lấy thông tin học kỳ hiện tại.
GET
/timetable?termId=
Lấy ca học (hỗ trợ ETag).
GET
/exams?termId=
Lấy lịch thi.
GET
/campus/buildings
Tọa độ các tòa nhà.
POST
/devices
Đăng ký deviceId và FCM token.
POST
/funds & GET /funds/{code}
Tạo và xem khoản thu.
POST
/funds/{code}/payments
Tạo đơn MoMo, trả payUrl.
GET
/payments/{paymentId}
Kiểm tra trạng thái thanh toán.
POST
/momo/ipn
Webhook MoMo xác minh chữ ký.
POST
/admin/schedule-change
Dời lịch và đẩy FCM.
5.2. Luồng xử lý quan trọng
Server-Wins: App kéo lịch khi khởi động, khi quay lại foreground sau 6h, hoặc khi nhận FCM. Bản ghi source=system sẽ bị ghi đè, source=user giữ nguyên.
MoMo Sandbox: App gọi API lấy payUrl, mở trình duyệt ngoài. MoMo gọi IPN về server để xác thực chữ ký HMAC-SHA256, chuyển trạng thái thành PAID/FAILED. Trình duyệt redirect về app qua deep link studysnap://payment?id=...
FCM: App gửi token đăng ký topic. Admin kích hoạt API, server đẩy JSON qua FCM. Chạm vào thông báo sẽ kích hoạt tải lại lịch.
CHƯƠNG 6: MÀN HÌNH VÀ LUỒNG ĐIỀU HƯỚNG
Hệ thống sử dụng go_router với 4 Tab chính dưới đáy màn hình.
Tab / Luồng
Màn hình chi tiết
Phụ trách
Khởi động
S01: Khóa ứng dụng (Sinh trắc học/PIN).
Duy
Lịch học
S02: Thời khóa biểuS03: Chi tiết ca họcS04: Dự phóng GPA.
Huy
Ghi chú
S05: Danh sách ghi chúS06: Chi tiết buổi học (Video Split-View)S07: Trình xem và vẽ ảnhS08: Camera & QRS09: Xuất PDF.
Huy, Duy
Quỹ
S11: Quỹ môn họcS12: Thanh toán MoMo Sandbox.
Khiêm
Công cụ
S10: Chỉ đường (Google Maps)S13: Cài đặt hệ thống.
Khiêm
Quy tắc giao diện bắt buộc:
Bố cục bàn phím (S06): Phải đặt resizeToAvoidBottomInset: true. Khi bật phím, video thu thành Mini-Player nổi (120x68 dp).
Mất mạng: Các màn S11, S12 và tải lịch phải hiển thị "Cần kết nối", các màn khác hoạt động bình thường.
CHƯƠNG 7: ĐẶC TẢ KỸ THUẬT 12 CHỦ ĐỀ
CĐ
Tên chủ đề
Phụ trách
Gói thư viện chính
Yêu cầu cốt lõi
1
Hiệu ứng nâng cao
Duy
CustomPainter
Nét vector, highlight BlendMode.multiply (mờ 40%), Undo/Redo bằng 2 stack.
2
Slider / Lịch
Huy
table_calendar
Lịch tuần/tháng, thanh trượt GPA, cỡ cọ vẽ (1-30px).
3
Tương tác ảnh
Duy
InteractiveViewer
Zoom max 500%, nút đổi Xem/Vẽ, đổi tọa độ toScene().
4
Tương tác file
Huy
pdf, printing...
Xuất PDF A4, nhúng font Roboto, nén ảnh.
5
Tương tác hệ thống
Khiêm
connectivity_plus
Cảnh báo Offline, Theme Sáng/Tối, Haptic.
6
Tương tác media
Duy
video_player
Split-View, Mini-Player, chèn mốc thời gian [mm:ss], seekTo.
7
Thông báo, Quyền
Huy
flutter_local_notifications
Nhắc lịch 15 phút, exact alarm, khôi phục sau reboot.
8
Push / Thanh toán
Khiêm
firebase_messaging
FCM Topic, MoMo IPN Sandbox.
9
Định vị, Bản đồ
Khiêm
geolocator, url_launcher
Dẫn đường đi bộ, tự động Geotag vị trí (bán kính 150m).
10
Quét mã / Camera
Huy
image_picker, mobile_scanner
Chụp bảng, quét mã deep link (studysnap://).
11
Bảo mật, Hiệu năng
Duy
local_auth, hive_ce
Khóa vân tay, mã hóa Hive, tối ưu FPS.
12
AI / Công cụ
Khiêm
google_mlkit_...
OCR xử lý offline, chèn tại con trỏ (chỉ cam kết chữ in).
CHƯƠNG 8 & 9: CẤU HÌNH, PHÂN CÔNG VÀ QUY TRÌNH
Công cụ: Khóa phiên bản Flutter bằng fvm (.fvmrc), Node.js LTS 20+.
Android Config: minSdkVersion: 23, cấu hình bộ nhận ScheduledNotificationBootReceiver, allowBackup="false" (tránh rò rỉ khóa mã hóa).
Bảo mật: Không push API keys, MoMo keys lên source code. Dùng --dart-define-from-file=env.json.
Phân công chéo: Duyệt PR chéo nhau (Duy duyệt Khiêm, Khiêm duyệt Huy, Huy duyệt Duy). Nhánh main được bảo vệ, gộp bằng squash, tối đa 400 dòng/PR.
CHƯƠNG 11: YÊU CẦU PHI CHỨC NĂNG (NFR)
(Đo trên một máy chuẩn duy nhất, bản Profile hoặc Release)
Chỉ số
Ngưỡng yêu cầu
Phương pháp đo
Tốc độ khung hình (FPS)
55 - 60 FPS, giật khung < 1.5%
Vẽ liên tục 60s trên ảnh 12MP (Flutter DevTools).
RAM
< 180 MB
Vừa phát video vừa xem 10 ảnh nén (dumpsys meminfo).
Thời gian OCR
< 1.2 giây (Ảnh Full HD)
Trung vị 10 lần đo Stopwatch.
Tốc độ xuất PDF
< 2.5 giây (Tệp 10 trang)
Tính từ lúc bấm xuất đến lúc hoàn thành.
Dung lượng PDF
< 8 MB (Chứa 10 ảnh)
Kiểm tra file vật lý.
Khởi động lạnh
< 3 giây
adb shell am start -W.
CHƯƠNG 12: TIÊU CHUẨN NGHIỆM THU (DEFINITION OF DONE)
12.1. Tiêu chuẩn chung (General DoD)
PR được duyệt, CI xanh, không cảnh báo flutter analyze, có Unit test.
Không lỗi RenderFlex overflowed, không crash trên máy thật.
Xử lý tường minh trạng thái mất kết nối mạng.
12.2. Kiểm thử kịch bản ngoại tuyến (Chế độ máy bay)
Khởi động app, xem lịch, mở chi tiết ca.
Tạo/sửa ghi chú, chụp ảnh, vẽ tay Undo/Redo.
Chạy OCR chèn chữ, gắn video và tua mốc thời gian.
Xuất và xem file PDF.
Yêu cầu: Toàn bộ quy trình không được văng lỗi máy chủ, hiển thị đúng banner "Cần kết nối" trong 5 giây.
CHƯƠNG 13: RỦI RO & CÂU HỎI MỞ
13.1. Các rủi ro kỹ thuật chính
Rủi ro
Giải pháp phòng ngừa
Phụ trách
Tech Lead quá tải
Chốt sớm kiến trúc ở tuần 1 & 2. Rút gọn yêu cầu mức "S" nếu chậm.
Duy
MoMo/Backend sập khi Demo
Gọi /health làm nóng server 10 phút trước. Quay video dự phòng.
Khiêm
Vẽ chậm/Tràn RAM trên ảnh 12MP
Dùng tính năng lưu Picture tạm, bật cacheWidth, giới hạn cạnh dài 4096px.
Duy
Thông báo trễ do tiết kiệm pin
Hướng dẫn người dùng tắt tối ưu pin, ghi chú hạn chế vào báo cáo.
Huy
Mất khóa khi gỡ ứng dụng
Cấu hình allowBackup="false", cảnh báo rõ trong Settings.
Duy
13.2. Cần giải quyết trong Tuần 1
Xác định cấu hình máy điện thoại chuẩn dùng để đo đạc NFR.
Cung cấp danh sách 10 mã phòng mẫu, lịch thi, danh sách tòa nhà chuẩn.
Thiết lập xong MoMo Sandbox và quyết định nền tảng Deploy (Render/Railway).