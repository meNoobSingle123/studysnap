# StudySnap Mock Backend Server

Máy chủ Mock Backend dành cho dự án **StudySnap** (Flutter Mobile App) theo kiến trúc Clean Architecture & Local-First.
Đáp ứng đầy đủ 6 endpoints theo đặc tả Chương 5 (Tài liệu API Contract & Postman Collection `docs/studysnap_api.postman_collection.json`).

## 1. Tính năng cốt lõi
- **Zero-Dependency**: Chạy độc lập bằng Node.js thuần (Built-in `http`, `crypto`, `fs`, `path`), không phụ thuộc thư viện bên ngoài.
- **Tối ưu Băng thông (ETag / 304)**: Tự động tính weak ETag (MD5 hash) cho `/v1/timetable` và `/v1/exams`, phản hồi HTTP `304 Not Modified` khi client gửi `If-None-Match`.
- **Hỗ trợ Admin API**: Endpoint `/v1/admin/schedule-change` với xác thực `X-Admin-Key` để dời ca học trực tiếp trong bộ nhớ và mô phỏng gửi FCM push notification.
- **Khuôn viên trường (Campus GPS)**: Cung cấp tọa độ 10 tòa nhà cơ sở phục vụ tính năng điều hướng S10.

## 2. Hướng dẫn chạy Server

### Khởi động server:
```bash
node server.js
```
Hoặc cấu hình cổng tùy chọn qua biến môi trường:
```bash
PORT=3000 node server.js
```

### Chạy bộ kiểm thử tự động (Automated Tests):
```bash
node test_server.js
```
Kết quả kiểm thử tự động xác nhận 16/16 test case hợp đồng API (200, 304 ETag, 403, 202, 404).

## 3. Danh sách Endpoints

| Phương thức | Đường dẫn | Tham số / Header | Mô tả | Mã phản hồi |
|---|---|---|---|---|
| `GET` | `/v1/health` | Không | Kiểm tra trạng thái máy chủ | `200 OK` |
| `GET` | `/v1/terms/current` | Không | Lấy thông tin học kỳ hiện tại | `200 OK` |
| `GET` | `/v1/timetable` | `termId` (vd: `2026-1`), `If-None-Match` | Lấy môn học & ca học theo kỳ (ETag) | `200 OK` / `304 Not Modified` |
| `GET` | `/v1/exams` | `termId` (vd: `2026-1`), `If-None-Match` | Lấy lịch thi học kỳ (ETag) | `200 OK` / `304 Not Modified` |
| `GET` | `/v1/campus/buildings` | Không | Lấy danh sách 10 tòa nhà & GPS | `200 OK` |
| `POST` | `/v1/admin/schedule-change` | `X-Admin-Key: studysnap_admin_secret_key_2026` | Đổi lịch ca học & trigger FCM | `202 Accepted` / `403 Forbidden` |
