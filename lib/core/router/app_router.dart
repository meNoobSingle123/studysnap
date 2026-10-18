import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../features/export/domain/models/pdf_export_models.dart';
import '../../features/export/presentation/pages/pdf_export_page.dart';
import '../../features/notes/presentation/pages/canvas_page.dart';
import '../../features/notes/presentation/pages/note_editor_page.dart';
import '../../features/notes/presentation/pages/notes_page.dart';
import '../../features/notifications/presentation/pages/notification_settings_page.dart';
import '../../features/ocr/ocr_scanner_page.dart';
import '../../features/scanner/presentation/pages/scanner_camera_page.dart';
import '../../features/security/presentation/pages/app_lock_page.dart';
import '../../features/settings/presentation/pages/tools_page.dart';
import '../../features/timetable/presentation/pages/gpa_page.dart';
import '../../features/timetable/presentation/pages/slot_detail_page.dart';

import '../../features/timetable/presentation/pages/timetable_page.dart';
import '../l10n/strings.dart';
import '../security/auth_lock_listenable.dart';
import 'routes.dart';

final GlobalKey<NavigatorState> _rootNavigatorKey =
    GlobalKey<NavigatorState>(debugLabel: 'root');

/// AppRouter centralizes navigation using GoRouter and StatefulShellRoute (3 Tabs).
abstract final class AppRouter {
  static final GoRouter router = GoRouter(
    navigatorKey: _rootNavigatorKey,
    initialLocation: Routes.timetable,
    refreshListenable: AuthLockListenable.instance,
    redirect: (context, state) {
      final isLockLocation = state.matchedLocation == Routes.lock;
      final isLockEnabled = AuthLockListenable.instance.isLockEnabled;
      final isLocked = AuthLockListenable.instance.isLocked;

      if (isLockEnabled && isLocked) {
        return isLockLocation ? null : Routes.lock;
      }

      if (isLockLocation || state.matchedLocation == Routes.home) {
        return Routes.timetable;
      }

      return null;
    },
    routes: [
      GoRoute(
        parentNavigatorKey: _rootNavigatorKey,
        path: Routes.lock,
        builder: (context, state) => const AppLockPage(),
      ),
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) {
          return _ScaffoldWithNavBar(navigationShell: navigationShell);
        },
        branches: [
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: Routes.timetable,
                builder: (context, state) => const TimetablePage(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: Routes.notes,
                builder: (context, state) => const NotesPage(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: Routes.tools,
                builder: (context, state) => const ToolsPage(),
              ),
            ],
          ),
        ],
      ),
      GoRoute(
        parentNavigatorKey: _rootNavigatorKey,
        path: Routes.noteEditor,
        builder: (context, state) {
          final noteId = state.pathParameters['id'] ?? '';
          final extraMap = state.extra is Map<String, dynamic>
              ? state.extra as Map<String, dynamic>
              : null;
          final subjectId = extraMap?['subjectId'] as String? ??
              state.uri.queryParameters['subjectId'];
          final slotId = extraMap?['slotId'] as String? ??
              state.uri.queryParameters['slotId'];
          return NoteEditorPage(
            noteId: noteId,
            subjectId: subjectId,
            slotId: slotId,
          );
        },
      ),
      GoRoute(
        parentNavigatorKey: _rootNavigatorKey,
        path: Routes.canvas,
        builder: (context, state) {
          final noteId = state.uri.queryParameters['noteId'];
          return CanvasPage(noteId: noteId);
        },
      ),
      GoRoute(
        parentNavigatorKey: _rootNavigatorKey,
        path: Routes.gpaProjection,
        builder: (context, state) => const GpaPage(),
      ),
      GoRoute(
        parentNavigatorKey: _rootNavigatorKey,
        path: Routes.slotDetail,
        builder: (context, state) {
          final slotId = state.pathParameters['id'] ?? '';
          return SlotDetailPage(slotId: slotId);
        },
      ),
      GoRoute(
        parentNavigatorKey: _rootNavigatorKey,
        path: Routes.scanner,
        builder: (context, state) => const ScannerCameraPage(),
      ),
      GoRoute(
        parentNavigatorKey: _rootNavigatorKey,
        path: Routes.pdfExport,
        builder: (context, state) {
          final noteId = state.uri.queryParameters['noteId'];
          final type = noteId != null ? PdfExportType.note : PdfExportType.timetable;
          return PdfExportPage(
            initialType: type,
            initialNoteId: noteId,
          );
        },
      ),
      GoRoute(
        parentNavigatorKey: _rootNavigatorKey,
        path: Routes.notifications,
        builder: (context, state) => const NotificationSettingsPage(),
      ),
      GoRoute(
        parentNavigatorKey: _rootNavigatorKey,
        path: Routes.ocrScanner,
        builder: (context, state) => const OcrScannerPage(),
      ),
    ],

    errorBuilder: (context, state) => Scaffold(
      appBar: AppBar(title: const Text(AppStrings.appName)),
      body: const Center(
        child: Text(AppStrings.pageNotFound),
      ),
    ),
  );
}

class _ScaffoldWithNavBar extends StatelessWidget {
  const _ScaffoldWithNavBar({
    required this.navigationShell,
  });

  final StatefulNavigationShell navigationShell;

  void _onDestinationSelected(int index) {
    navigationShell.goBranch(
      index,
      initialLocation: index == navigationShell.currentIndex,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: navigationShell,
      bottomNavigationBar: NavigationBar(
        selectedIndex: navigationShell.currentIndex,
        onDestinationSelected: _onDestinationSelected,
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.calendar_month_outlined),
            selectedIcon: Icon(Icons.calendar_month),
            label: AppStrings.timetableTab,
          ),
          NavigationDestination(
            icon: Icon(Icons.note_alt_outlined),
            selectedIcon: Icon(Icons.note_alt),
            label: AppStrings.notesTab,
          ),
          NavigationDestination(
            icon: Icon(Icons.widgets_outlined),
            selectedIcon: Icon(Icons.widgets),
            label: AppStrings.toolsTab,
          ),
        ],
      ),
    );
  }
}
