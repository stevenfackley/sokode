import 'package:flutter_test/flutter_test.dart';
import 'package:sokode_app/make/editor_state.dart';
import 'package:sokode_core/sokode_core.dart';

void main() {
  test('starts with border walls and floor interior', () {
    final editor = EditorState(width: 6, height: 4);
    expect(editor.tileAt(0), Tile.wall);
    expect(editor.tileAt(7), Tile.floor);
  });

  test('painting tiles, placing entities, eviction rules', () {
    final editor = EditorState(width: 6, height: 4);
    editor.brush = Brush.target;
    editor.paint(8);
    expect(editor.tileAt(8), Tile.target);
    editor.brush = Brush.player;
    editor.paint(7);
    expect(editor.playerIndex, 7);
    editor.brush = Brush.crate;
    editor.paint(8);
    expect(editor.crateIndexes, {8});
    // crate refuses player's cell; player brush moves the marker
    editor.paint(7);
    expect(editor.crateIndexes, {8});
    editor.brush = Brush.wall;
    editor.paint(8); // wall under crate evicts it
    expect(editor.crateIndexes, isEmpty);
  });

  test(
    'toLevel is null until a player exists; validation maps core errors',
    () {
      final editor = EditorState(width: 6, height: 4);
      expect(editor.toLevel(), isNull);
      expect(editor.validationProblems(), ['Place the player.']);
      editor.brush = Brush.player;
      editor.paint(7);
      expect(editor.toLevel(), isNotNull);
      expect(editor.validationProblems(), contains('Add at least one target.'));
    },
  );
}
