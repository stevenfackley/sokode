import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sokode_app/make/editor_state.dart';
import 'package:sokode_app/make/maker_screen.dart';
import 'package:sokode_app/screens/level_list_screen.dart';
import 'package:sokode_app/store/level_repository.dart';
import 'package:sokode_core/sokode_core.dart';

void main() {
  testWidgets(
    'FULL ROUNDTRIP: author -> verify -> code -> fresh import -> play -> win',
    (tester) async {
      // --- Author + publish (maker) ---
      final authorRepo = MemoryLevelRepository();
      final editor = EditorState();
      await tester.pumpWidget(
        MaterialApp(
          home: MakerScreen(repository: authorRepo, editor: editor),
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

      await tester.tap(find.byKey(const ValueKey('test-play')));
      await tester.pumpAndSettle();
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Done'));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('publish')));
      await tester.pumpAndSettle();
      final code = (await authorRepo.loadCodes()).single.code;

      // --- A fresh instance imports via the web-fragment path ---
      // Tear the maker down completely first (a bare SizedBox forces the old
      // element tree — including the open publish dialog — to be discarded)
      // so the second MaterialApp boots with a clean Navigator.
      await tester.pumpWidget(const SizedBox());
      await tester.pumpAndSettle();
      final playerRepo = MemoryLevelRepository();
      await tester.pumpWidget(
        MaterialApp(
          home: LevelListScreen(
            repository: playerRepo,
            initialImportCode: code,
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect((await playerRepo.loadCodes()).single.kind, 'imported');

      // --- Play it to the win ---
      await tester.tap(find.text('Imported')); // switch to the Imported tab
      await tester.pumpAndSettle();
      final title = titleForLevel((decode(code) as DecodeSuccess).level);
      await tester.tap(find.text(title));
      await tester.pumpAndSettle();
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('win-dialog')), findsOneWidget);
    },
  );
}
