import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sokode_app/make/editor_state.dart';
import 'package:sokode_app/make/maker_screen.dart';
import 'package:sokode_app/store/level_repository.dart';
import 'package:sokode_core/sokode_core.dart';

void main() {
  testWidgets(
    'publish is gated on a verified solve and emits an importable code',
    (tester) async {
      final repo = MemoryLevelRepository();
      // Inject the editor so the test can author directly (driving every paint
      // gesture through the canvas is editor_state_test's coverage, not this
      // test's). Default 8x8 board: player 9, crate 10, target 11 — one right
      // push solves it.
      final editor = EditorState();
      await tester.pumpWidget(
        MaterialApp(
          home: MakerScreen(repository: repo, editor: editor),
        ),
      );
      await tester.pumpAndSettle();

      editor.brush = Brush.player;
      editor.paint(9);
      editor.brush = Brush.crate;
      editor.paint(10);
      editor.brush = Brush.target;
      editor.paint(11);
      await tester.pumpAndSettle();

      expect(
        tester
            .widget<ElevatedButton>(find.byKey(const ValueKey('publish')))
            .enabled,
        isFalse,
        reason: 'no solve captured yet',
      );

      await tester.tap(find.byKey(const ValueKey('test-play')));
      await tester.pumpAndSettle();
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Done'));
      await tester.pumpAndSettle();

      expect(
        tester
            .widget<ElevatedButton>(find.byKey(const ValueKey('publish')))
            .enabled,
        isTrue,
      );
      await tester.tap(find.byKey(const ValueKey('publish')));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('publish-dialog')), findsOneWidget);

      // The saved code must survive the full import gate.
      final saved = (await repo.loadCodes()).single;
      expect(saved.kind, 'mine');
      expect(
        const LevelImporter(SokobanPlus()).import(saved.code),
        isA<ImportSuccess>(),
      );
    },
  );
}
