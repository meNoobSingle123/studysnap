/// Thực thể Tòa nhà khuôn viên trường - Domain Layer.
class CampusBuilding {
  final String id;
  final String code;       // Mã tòa nhà, VD: "H2"
  final String name;       // Tên tòa nhà, VD: "Tòa H2 - Khoa CNTT"
  final double latitude;
  final double longitude;

  const CampusBuilding({
    required this.id,
    required this.code,
    required this.name,
    required this.latitude,
    required this.longitude,
  });
}
