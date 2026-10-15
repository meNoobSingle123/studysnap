import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../features/notes/presentation/pages/canvas_page.dart';
import '../../features/notes/presentation/pages/note_editor_page.dart';
import '../../features/notes/presentation/pages/notes_page.dart';
import '../../features/security/presentation/pages/app_lock_page.dart';
import '../../features/settings/presentation/pages/tools_page.dart';
import '../../features/timetable/presentation/pages/timetable_page.dart';
import '../l10n/strings.dart';
<<<<<<< HEAD
import '../security/auth_lock_listenable.dart';
=======
>>>>>>> 65bb05b538bafaaf5ee63db54ee8a586f3e3f474
import 'routes.dart';

final GlobalKey<NavigatorState> _rootNavigatorKey =
    GlobalKey<NavigatorState>(debugLabel: 'root');

/// AppRouter centralizes navigation using GoRouter and StatefulShellRoute (3 Tabs).
abstract final class AppRouter {
  static final GoRouter router = GoRouter(
    navigatorKey: _rootNavigatorKey,
    initialLocation: Routes.timetable,
<<<<<<< HEAD
    refreshListenable: AuthLockListenable.instance,
    redirect: (context, state) {
      final isLockLocation = state.matchedLocation == Routes.lock;
      final isLocked = AuthLockListenable.instance.isLocked;

      if (isLocked) {
        return isLockLocation ? null : Routes.lock;
      }

      if (isLockLocation || state.matchedLocation == Routes.home) {
        return Routes.timetable;
      }

=======
    redirect: (context, state) {
      if (state.matchedLocation == Routes.home) {
        return Routes.timetable;
      }
>>>>>>> 65bb05b538bafaaf5ee63db54ee8a586f3e3f474
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
          final subjectId = state.uri.queryParameters['subjectId'];
          final slotId = state.uri.queryParameters['slotId'];
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
