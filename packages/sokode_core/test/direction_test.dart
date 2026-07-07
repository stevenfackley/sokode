import 'package:sokode_core/sokode_core.dart';
import 'package:test/test.dart';

void main() {
  test('2-bit encodings are stable (codec + replay format depend on them)', () {
    expect(Direction.up.encoding, 0);
    expect(Direction.right.encoding, 1);
    expect(Direction.down.encoding, 2);
    expect(Direction.left.encoding, 3);
  });

  test('fromEncoding roundtrips', () {
    for (final d in Direction.values) {
      expect(Direction.fromEncoding(d.encoding), d);
    }
  });

  test('deltas point the right way (y grows downward, row-major)', () {
    expect(Direction.up.dx, 0);
    expect(Direction.up.dy, -1);
    expect(Direction.right.dx, 1);
    expect(Direction.right.dy, 0);
    expect(Direction.down.dx, 0);
    expect(Direction.down.dy, 1);
    expect(Direction.left.dx, -1);
    expect(Direction.left.dy, 0);
  });
}
