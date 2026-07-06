import 'package:sokode_core/sokode_core.dart';
import 'package:test/test.dart';

void main() {
  test('nibble values are stable (share-code format depends on them)', () {
    expect(Tile.floor.nibble, 0);
    expect(Tile.wall.nibble, 1);
    expect(Tile.target.nibble, 2);
    expect(Tile.onewayUp.nibble, 3);
    expect(Tile.onewayRight.nibble, 4);
    expect(Tile.onewayDown.nibble, 5);
    expect(Tile.onewayLeft.nibble, 6);
    expect(Tile.switchA.nibble, 7);
    expect(Tile.switchB.nibble, 8);
    expect(Tile.gateAOpen.nibble, 9);
    expect(Tile.gateAClosed.nibble, 10);
    expect(Tile.gateBOpen.nibble, 11);
    expect(Tile.gateBClosed.nibble, 12);
    expect(Tile.values.length, 13);
  });

  test('fromNibble roundtrips and rejects reserved values', () {
    for (final t in Tile.values) {
      expect(Tile.fromNibble(t.nibble), t);
    }
    expect(Tile.fromNibble(13), isNull);
    expect(Tile.fromNibble(15), isNull);
    expect(Tile.fromNibble(-1), isNull);
  });

  test('classification getters', () {
    expect(Tile.onewayRight.onewayDirection, Direction.right);
    expect(Tile.floor.onewayDirection, isNull);
    expect(Tile.switchA.switchChannel, 0);
    expect(Tile.switchB.switchChannel, 1);
    expect(Tile.wall.switchChannel, isNull);
    expect(Tile.gateAOpen.gateChannel, 0);
    expect(Tile.gateBClosed.gateChannel, 1);
    expect(Tile.target.gateChannel, isNull);
    expect(Tile.gateAOpen.gateStartsOpen, isTrue);
    expect(Tile.gateAClosed.gateStartsOpen, isFalse);
    expect(Tile.gateAOpen.isGate, isTrue);
    expect(Tile.switchA.isGate, isFalse);
  });
}
