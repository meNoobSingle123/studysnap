import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:nhom_7/core/l10n/strings.dart';
import 'package:nhom_7/features/notes/domain/entities/stroke.dart';
import 'package:nhom_7/features/notes/presentation/bloc/canvas_bloc.dart';
import 'package:nhom_7/features/notes/presentation/bloc/canvas_event.dart';
import 'package:nhom_7/features/notes/presentation/pages/canvas_page.dart';
import 'package:nhom_7/features/notes/presentation/widgets/canvas/canvas_drawing_board.dart';
import 'package:nhom_7/features/notes/presentation/widgets/canvas/canvas_toolbar.dart';

void main() {
  setUp(() {
    final getIt = GetIt.instance;
    if (!getIt.isRegistered<CanvasBloc>()) {
      getIt.registerFactory<CanvasBloc>(() => CanvasBloc());
    }
  });

  tearDown(() {
    GetIt.instance.reset();
  });

  Widget buildTestHarness({
    Future<void> Function(List<Stroke> strokes, Uint8List? flatBytes)? onSave,
  }) {
    return MaterialApp(
      home: CanvasPage(
        noteId: 'test-note-1',
        originalImageSize: const Size(400, 400),
        onSave: onSave,
      ),
    );
  }

  group('CanvasPage Widget', () {
    testWidgets('renders AppBar, CanvasDrawingBoard, and CanvasToolbar', (tester) async {
      await tester.pumpWidget(buildTestHarness());

      expect(find.text(AppStrings.canvasPageTitle), findsOneWidget);
      expect(find.text(AppStrings.save), findsOneWidget);
      expect(find.byType(CanvasDrawingBoard), findsOneWidget);
      expect(find.byType(CanvasToolbar), findsOneWidget);
    });

    testWidgets('tapping save button calls onSave and displays success SnackBar', (tester) async {
      var saveCalled = false;

      await tester.pumpWidget(
        buildTestHarness(
          onSave: (strokes, flatBytes) async {
            saveCalled = true;
          },
        ),
      );

      // Tap Save
      await tester.tap(find.text(AppStrings.save));
      await tester.pump();
      await tester.runAsync(() async {
        await Future.delayed(const Duration(milliseconds: 300));
      });
      await tester.pump();

      expect(saveCalled, isTrue);
      expect(find.text(AppStrings.canvasExportSuccess), findsOneWidget);
    });

    testWidgets('back navigation with strokes shows discard dialog', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (ctx) => TextButton(
                onPressed: () {
                  Navigator.of(ctx).push(
                    MaterialPageRoute(
                      builder: (_) => const CanvasPage(
                        noteId: 'note-1',
                        originalImageSize: Size(400, 400),
                      ),
                    ),
                  );
                },
                child: const Text('Open Canvas'),
              ),
            ),
          ),
        ),
      );

      // Open Canvas Page
      await tester.tap(find.text('Open Canvas'));
      await tester.pumpAndSettle();

      // Add a stroke to CanvasBloc
      final bloc = tester.element(find.byType(CanvasDrawingBoard)).read<CanvasBloc>();
      bloc.add(
        AddStrokeEvent(
          Stroke(
            id: 'stroke-1',
            tool: StrokeTool.pen,
            colorValue: 0xFF000000,
            widthNorm: 0.01,
            points: const [0.1, 0.1, 0.5, 0.5],
            createdAt: DateTime.now(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Tap Back button in AppBar
      await tester.tap(find.byType(BackButton));
      await tester.pumpAndSettle();

      // Discard confirmation dialog should be displayed
      expect(find.text(AppStrings.canvasDiscardConfirmTitle), findsOneWidget);
      expect(find.text(AppStrings.canvasDiscardConfirmMessage), findsOneWidget);

      // Tap Cancel in dialog
      await tester.tap(find.text(AppStrings.cancel));
      await tester.pumpAndSettle();

      // Canvas page still visible
      expect(find.byType(CanvasPage), findsOneWidget);
    });

    testWidgets('after saving, back button pops without discard dialog', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (ctx) => TextButton(
                onPressed: () {
                  Navigator.of(ctx).push(
                    MaterialPageRoute(
                      builder: (_) => CanvasPage(
                        noteId: 'note-1',
                        originalImageSize: const Size(400, 400),
                        onSave: (_, _) async {},
                      ),
                    ),
                  );
                },
                child: const Text('Open Canvas'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open Canvas'));
      await tester.pumpAndSettle();

      // Add a stroke
      final bloc = tester.element(find.byType(CanvasDrawingBoard)).read<CanvasBloc>();
      bloc.add(
        AddStrokeEvent(
          Stroke(
            id: 'stroke-1',
            tool: StrokeTool.pen,
            colorValue: 0xFF000000,
            widthNorm: 0.01,
            points: const [0.1, 0.1, 0.5, 0.5],
            createdAt: DateTime.now(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Tap Save
      await tester.tap(find.text(AppStrings.save));
      await tester.pump();
      await tester.runAsync(() async {
        await Future.delayed(const Duration(milliseconds: 300));
      });
      await tester.pump();

      // Tap Back
      await tester.tap(find.byType(BackButton));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // Should be back to the initial page, no dialog shown
      expect(find.text(AppStrings.canvasDiscardConfirmTitle), findsNothing);
      expect(find.text('Open Canvas'), findsOneWidget);
    });
  });
}
