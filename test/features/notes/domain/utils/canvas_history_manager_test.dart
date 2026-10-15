import 'package:flutter_test/flutter_test.dart';
import 'package:nhom_7/features/notes/domain/entities/stroke.dart';
import 'package:nhom_7/features/notes/domain/utils/canvas_history_manager.dart';

Stroke _makeStroke(String id) => Stroke(
      id: id,
      tool: StrokeTool.pen,
      colorValue: 0xFF000000,
      widthNorm: 0.005,
      points: const [0.1, 0.1, 0.2, 0.2],
      createdAt: DateTime(2026, 10, 13),
    );

void main() {
  late CanvasHistoryManager manager;

  setUp(() {
    manager = CanvasHistoryManager(maxHistory: 100);
  });

  group('CanvasHistoryManager – basic state', () {
    test('starts empty, canUndo = false, canRedo = false', () {
      expect(manager.canUndo, false);
      expect(manager.canRedo, false);
      expect(manager.undoCount, 0);
      expect(manager.redoCount, 0);
    });

    test('pushCommand increases undoCount', () {
      manager.pushCommand(AddStrokeCommand(_makeStroke('s1')));
      expect(manager.undoCount, 1);
      expect(manager.canUndo, true);
    });

    test('push clears redoStack', () {
      final s1 = _makeStroke('s1');
      manager.pushCommand(AddStrokeCommand(s1));
      manager.undo();
      expect(manager.canRedo, true);

      // New push must clear redo
      manager.pushCommand(AddStrokeCommand(_makeStroke('s2')));
      expect(manager.canRedo, false);
      expect(manager.redoCount, 0);
    });
  });

  group('CanvasHistoryManager – undo / redo', () {
    test('undo on empty returns null', () {
      expect(manager.undo(), isNull);
    });

    test('redo on empty returns null', () {
      expect(manager.redo(), isNull);
    });

    test('undo returns most recent command and moves it to redoStack', () {
      final cmd = AddStrokeCommand(_makeStroke('s1'));
      manager.pushCommand(cmd);
      final undone = manager.undo();
      expect(undone, isA<AddStrokeCommand>());
      expect((undone! as AddStrokeCommand).stroke.id, 's1');
      expect(manager.canUndo, false);
      expect(manager.canRedo, true);
    });

    test('redo restores command and moves it back to undoStack', () {
      manager.pushCommand(AddStrokeCommand(_makeStroke('s1')));
      manager.undo();
      final redone = manager.redo();
      expect(redone, isA<AddStrokeCommand>());
      expect(manager.canRedo, false);
      expect(manager.canUndo, true);
    });
  });

  group('CanvasHistoryManager – 10+ step Undo/Redo integrity', () {
    test('10 pushes then 10 undos restores original empty list', () {
      final strokes = <Stroke>[];
      final strokes10 = List.generate(10, (i) => _makeStroke('stroke-$i'));

      // Draw 10 strokes
      for (final s in strokes10) {
        final cmd = AddStrokeCommand(s);
        manager.pushCommand(cmd);
        strokes.addAll(manager.applyCommand(strokes, cmd) // rebuild via manager
            .skip(strokes.length));
      }

      // Rebuild stroke list from scratch via manager
      var current = <Stroke>[];
      for (final s in strokes10) {
        current = manager.applyCommand(current, AddStrokeCommand(s));
      }
      expect(current.length, 10);

      // Undo all 10
      for (var i = 9; i >= 0; i--) {
        final cmd = manager.undo();
        expect(cmd, isNotNull);
        current = manager.reverseCommand(current, cmd!);
        expect(current.length, i);
      }
      expect(current, isEmpty);
      expect(manager.canUndo, false);
      expect(manager.canRedo, true);
      expect(manager.redoCount, 10);
    });

    test('10 pushes, 10 undos, then 10 redos restores all 10 strokes', () {
      var current = <Stroke>[];
      final strokes10 = List.generate(10, (i) => _makeStroke('redo-$i'));

      for (final s in strokes10) {
        final cmd = AddStrokeCommand(s);
        manager.pushCommand(cmd);
        current = manager.applyCommand(current, cmd);
      }

      // Undo all
      for (var i = 0; i < 10; i++) {
        final cmd = manager.undo()!;
        current = manager.reverseCommand(current, cmd);
      }
      expect(current, isEmpty);

      // Redo all
      for (var i = 0; i < 10; i++) {
        final cmd = manager.redo()!;
        current = manager.applyCommand(current, cmd);
        expect(current.length, i + 1);
      }
      expect(current.length, 10);
      expect(manager.canRedo, false);
    });

    test('interspersed undo/redo 10 times each maintains correct stroke count', () {
      var current = <Stroke>[];
      // Push 10 strokes
      for (var i = 0; i < 10; i++) {
        final cmd = AddStrokeCommand(_makeStroke('interspersed-$i'));
        manager.pushCommand(cmd);
        current = manager.applyCommand(current, cmd);
      }
      expect(current.length, 10);

      // Undo 5
      for (var i = 0; i < 5; i++) {
        current = manager.reverseCommand(current, manager.undo()!);
      }
      expect(current.length, 5);

      // Redo 3
      for (var i = 0; i < 3; i++) {
        current = manager.applyCommand(current, manager.redo()!);
      }
      expect(current.length, 8);

      // Undo 3
      for (var i = 0; i < 3; i++) {
        current = manager.reverseCommand(current, manager.undo()!);
      }
      expect(current.length, 5);
    });
  });

  group('CanvasHistoryManager – maxHistory cap', () {
    test('exceeding maxHistory evicts the oldest command', () {
      final small = CanvasHistoryManager(maxHistory: 5);
      for (var i = 0; i < 6; i++) {
        small.pushCommand(AddStrokeCommand(_makeStroke('cap-$i')));
      }
      expect(small.undoCount, 5);

      // The oldest command (cap-0) should be evicted; last undo should be cap-5.
      var last = small.undo();
      expect((last! as AddStrokeCommand).stroke.id, 'cap-5');
    });
  });

  group('CanvasHistoryManager – applyCommand / reverseCommand', () {
    test('applyCommand AddStroke appends stroke', () {
      final s = _makeStroke('a');
      final result = manager.applyCommand([], AddStrokeCommand(s));
      expect(result.length, 1);
      expect(result.first.id, 'a');
    });

    test('reverseCommand AddStroke removes stroke by id', () {
      final s = _makeStroke('b');
      final start = [s];
      final result = manager.reverseCommand(start, AddStrokeCommand(s));
      expect(result, isEmpty);
    });

    test('applyCommand RemoveStroke removes stroke', () {
      final s = _makeStroke('c');
      final result = manager.applyCommand([s], RemoveStrokeCommand(s));
      expect(result, isEmpty);
    });

    test('reverseCommand RemoveStroke re-appends stroke', () {
      final s = _makeStroke('d');
      final result = manager.reverseCommand([], RemoveStrokeCommand(s));
      expect(result.length, 1);
      expect(result.first.id, 'd');
    });
  });

  group('CanvasHistoryManager – clear', () {
    test('clear empties both stacks', () {
      manager.pushCommand(AddStrokeCommand(_makeStroke('e')));
      manager.undo();
      expect(manager.canUndo, false);
      expect(manager.canRedo, true);

      manager.clear();
      expect(manager.canUndo, false);
      expect(manager.canRedo, false);
    });
  });
}
