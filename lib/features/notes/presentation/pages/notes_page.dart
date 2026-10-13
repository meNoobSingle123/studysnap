import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:uuid/uuid.dart';

import '../../../../core/l10n/strings.dart';
import '../../../../core/router/routes.dart';

class NotesPage extends StatelessWidget {
  const NotesPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(AppStrings.notesTab),
      ),
      body: const Center(
        child: Text(AppStrings.emptyNotesList),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          final newNoteId = const Uuid().v4();
          context.push(Routes.noteEdit(newNoteId));
        },
        icon: const Icon(Icons.edit_note),
        label: const Text(AppStrings.createNote),
      ),
    );
  }
}
