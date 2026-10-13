import 'package:flutter/material.dart';

import '../../../../core/l10n/strings.dart';

class TimetablePage extends StatelessWidget {
  const TimetablePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(AppStrings.timetableTab),
      ),
      body: const Center(
        child: Text(AppStrings.timetableTab),
      ),
    );
  }
}
