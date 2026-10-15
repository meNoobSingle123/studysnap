import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:geolocator/geolocator.dart';
import 'package:url_launcher/url_launcher.dart';

// ── Entity ─────────────────────────────────────────────────────────────────
/// Tòa nhà / địa điểm học tập. code phải khớp với buildingCode trong ClassSession.
class Building {
  final String code;
  final String name;
  final double latitude;
  final double longitude;
  final String kind; // 'building' | 'library' | 'hall'

  const Building({
    required this.code,
    required this.name,
    required this.latitude,
    required this.longitude,
    this.kind = 'building',
  });

  factory Building.fromJson(Map<String, dynamic> j) => Building(
        code: j['code'] as String,
        name: j['name'] as String,
        latitude: (j['lat'] as num).toDouble(),
        longitude: (j['lng'] as num).toDouble(),
        kind: (j['kind'] as String?) ?? 'building',
      );
}

// ── Service ────────────────────────────────────────────────────────────────
/// CĐ 9: lấy vị trí GPS, tìm tòa nhà gần nhất, mở Google Maps chỉ đường đi bộ.
class _LocationService {
  Future<Position?> currentPosition() async {
    if (!await Geolocator.isLocationServiceEnabled()) {
      return null;
    }
    var perm = await Geolocator.checkPermission();
    if (perm == LocationPermission.denied) {
      perm = await Geolocator.requestPermission();
    }
    if (perm == LocationPermission.denied ||
        perm == LocationPermission.deniedForever) {
      return null;
    }
    return Geolocator.getCurrentPosition(
      locationSettings:
          const LocationSettings(accuracy: LocationAccuracy.high),
    );
  }

  static Building? nearest(Position p, List<Building> buildings,
      {double maxMeters = 150}) {
    Building? best;
    var bestDist = double.infinity;
    for (final b in buildings) {
      final d = Geolocator.distanceBetween(
          p.latitude, p.longitude, b.latitude, b.longitude);
      if (d < bestDist) {
        bestDist = d;
        best = b;
      }
    }
    return bestDist <= maxMeters ? best : null;
  }

  static Future<bool> openWalking(Building b) => launchUrl(
        Uri.https('www.google.com', '/maps/dir/', {
          'api': '1',
          'destination': '${b.latitude},${b.longitude}',
          'travelmode': 'walking',
        }),
        mode: LaunchMode.externalApplication,
      );
}

// ── Dữ liệu mẫu (thay bằng API /campus/buildings khi có) ──────────────────
const _buildings = <Building>[
  Building(code: 'H2', name: 'Tòa nhà H2', latitude: 10.8012, longitude: 106.7143),
  Building(code: 'A1', name: 'Tòa nhà A1', latitude: 10.8015, longitude: 106.7150),
  Building(
      code: 'LIB',
      name: 'Thư viện trung tâm',
      latitude: 10.8008,
      longitude: 106.7139,
      kind: 'library'),
];

// ── Page ───────────────────────────────────────────────────────────────────
/// Màn hình chỉ đường khuôn viên (CĐ 9 / S10).
class CampusMapPage extends StatefulWidget {
  const CampusMapPage({super.key});

  @override
  State<CampusMapPage> createState() => _CampusMapPageState();
}

class _CampusMapPageState extends State<CampusMapPage> {
  final _loc = _LocationService();
  String _status = 'Chưa lấy vị trí';
  bool _loading = false;

  Future<void> _tagLocation() async {
    setState(() {
      _loading = true;
      _status = 'Đang lấy vị trí...';
    });
    final pos = await _loc.currentPosition();
    if (!mounted) {
      return;
    }
    if (pos == null) {
      setState(() {
        _loading = false;
        _status = 'Không lấy được vị trí (tắt dịch vụ hoặc từ chối quyền)';
      });
      return;
    }
    final near = _LocationService.nearest(pos, _buildings);
    setState(() {
      _loading = false;
      _status =
          '📍 (${pos.latitude.toStringAsFixed(5)}, ${pos.longitude.toStringAsFixed(5)})\n'
          '→ ${near?.name ?? 'Không gần tòa nhà nào trong 150 m'}';
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Chỉ đường khuôn viên')),
      body: ListView(padding: const EdgeInsets.all(16), children: [
        // Danh sách tòa nhà
        for (final b in _buildings)
          Card(
            child: ListTile(
              leading: Icon(
                  b.kind == 'library' ? Icons.local_library : Icons.business),
              title: Text(b.name),
              subtitle: Text(b.code),
              trailing: const Icon(Icons.directions_walk),
              onTap: () async {
                HapticFeedback.lightImpact();
                final ok = await _LocationService.openWalking(b);
                if (!ok && context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                        content: Text('Không mở được Google Maps')),
                  );
                }
              },
            ),
          ),

        const SizedBox(height: 20),

        // Nút gắn vị trí hiện tại
        FilledButton.icon(
          onPressed: _loading ? null : _tagLocation,
          icon: _loading
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                )
              : const Icon(Icons.my_location),
          label: const Text('Gắn vị trí hiện tại'),
        ),
        const SizedBox(height: 12),
        Text(_status),
      ]),
    );
  }
}
