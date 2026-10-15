import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/l10n/strings.dart';
import '../../../../core/router/routes.dart';

class ToolsPage extends StatelessWidget {
  const ToolsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(AppStrings.toolsTab),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16.0),
        children: [
          Card(
            child: ListTile(
              leading: const Icon(Icons.qr_code_scanner_rounded),
              title: const Text(AppStrings.scannerTitle),
              subtitle: const Text('Quét tài liệu và chụp ảnh bài giảng (S08)'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => context.push(Routes.scanner),
            ),
          ),
          const SizedBox(height: 12),
          Card(
            child: ListTile(
              leading: const Icon(Icons.map_outlined),
              title: const Text(AppStrings.mapNavigation),
              trailing: const Icon(Icons.chevron_right),
              onTap: () {
                // S10: Campus map navigation shortcut
              },
            ),
          ),
          const SizedBox(height: 12),
          Card(
            child: ListTile(
              leading: const Icon(Icons.settings_outlined),
              title: const Text(AppStrings.appSettings),
              trailing: const Icon(Icons.chevron_right),
              onTap: () {
                // S13: System settings shortcut
              },
            ),
          ),
        ],
      ),
    );
  }
}
