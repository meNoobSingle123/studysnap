import 'package:flutter/material.dart';

import '../../../../core/l10n/strings.dart';

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
