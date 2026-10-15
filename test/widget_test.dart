import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nhom_7/core/di/injection.dart';
import 'package:nhom_7/core/l10n/strings.dart';
import 'package:nhom_7/core/router/app_router.dart';
import 'package:nhom_7/core/router/routes.dart';
import 'package:nhom_7/core/security/bloc/auth_lock_bloc.dart';
import 'package:nhom_7/core/security/bloc/auth_lock_event.dart';
import 'package:nhom_7/features/security/presentation/pages/app_lock_page.dart';
import 'package:nhom_7/main.dart';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:nhom_7/core/security/auth_lock_listenable.dart';

void main() {
  setUp(() async {
    FlutterSecureStorage.setMockInitialValues({});
    AuthLockListenable.instance.updateLockState(true);
    await configureDependencies(isTest: true);
  });

  tearDown(() async {
    await getIt.reset();
  });

  testWidgets(
      'MyApp shows AppLockPage when locked and transitions to main tabs when unlocked',
      (WidgetTester tester) async {
    await tester.pumpWidget(const MyApp());
    await tester.pumpAndSettle();

    // Navigate to lock screen
    AppRouter.router.go(Routes.lock);
    await tester.pumpAndSettle();

    // Verify S01 AppLockPage is displayed on locked state
    expect(find.byType(AppLockPage), findsOneWidget);
    expect(find.text(AppStrings.unlockWithBiometrics), findsOneWidget);

    // Unlock app
    getIt<AuthLockBloc>().add(const UnlockApp());
    await tester.pump();
    await tester.pumpAndSettle();

    // Verify main tabs are displayed
    expect(find.byType(NavigationBar), findsOneWidget);
    expect(find.text(AppStrings.timetableTab), findsWidgets);
  });

  testWidgets('MyApp boots up with 3 tabs and switches branches correctly',
      (WidgetTester tester) async {
    await tester.pumpWidget(const MyApp());
    await tester.pumpAndSettle();

    // Verify NavigationBar has 3 destinations
    expect(find.byType(NavigationBar), findsOneWidget);
    expect(find.text(AppStrings.timetableTab), findsWidgets);
    expect(find.text(AppStrings.notesTab), findsOneWidget);
    expect(find.text(AppStrings.toolsTab), findsOneWidget);

    // Tap on Tools tab and verify ToolsPage is displayed
    await tester.tap(find.text(AppStrings.toolsTab));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(find.text(AppStrings.appSettings), 100.0);
    expect(find.text(AppStrings.appSettings), findsOneWidget);

    // Tap on Notes tab and verify branch switched
    await tester.tap(find.text(AppStrings.notesTab));
    await tester.pumpAndSettle();
    expect(find.text(AppStrings.notesTab), findsWidgets);
    expect(find.text(AppStrings.createNote), findsOneWidget);

    // Tap on Create Note FAB to navigate to S06 NoteEditorPage
    await tester.tap(find.text(AppStrings.createNote));
    await tester.pumpAndSettle();

    // Verify S06 NoteEditorPage is displayed
    expect(find.text(AppStrings.noteEditorTitle), findsOneWidget);
    expect(find.text(AppStrings.save), findsOneWidget);
  });
}
