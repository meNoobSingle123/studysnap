import 'package:flutter/material.dart';

import '../../../../core/l10n/strings.dart';
import '../../../maps/campus_map_page.dart';
import '../../../ocr/ocr_scanner_page.dart';

class ToolsPage extends StatelessWidget {
  const ToolsPage({super.key});

  void _go(BuildContext context, Widget page) =>
      Navigator.push(context, MaterialPageRoute(builder: (_) => page));

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text(AppStrings.toolsTab)),
      body: ListView(padding: const EdgeInsets.all(16), children: [
        _ToolCard(
          icon: Icons.map_outlined,
          title: AppStrings.mapNavigation,
          subtitle: 'Chỉ đường đi bộ đến tòa nhà trong khuôn viên',
          onTap: () => _go(context, const CampusMapPage()),
        ),
        _ToolCard(
          icon: Icons.document_scanner_outlined,
          title: AppStrings.ocrScanner,
          subtitle: 'Chụp/chọn ảnh để nhận diện chữ in tự động',
          onTap: () => _go(context, const OcrScannerPage()),
        ),
        _ToolCard(
          icon: Icons.settings_outlined,
          title: AppStrings.appSettings,
          subtitle: 'Tùy chỉnh ứng dụng',
          onTap: () {
            // TODO S13: Màn cài đặt sẽ bổ sung sau
          },
        ),
      ]),
    );
  }
}

class _ToolCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _ToolCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Card(
        child: ListTile(
          leading: Icon(icon),
          title: Text(title),
          subtitle: Text(subtitle),
          trailing: const Icon(Icons.chevron_right),
          onTap: onTap,
        ),
      ),
    );
  }
}

