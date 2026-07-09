import 'package:flutter_test/flutter_test.dart';
import 'package:sokode_core/sokode_core.dart';

void main() {
  test('app can see the core package', () {
    expect(Direction.values, hasLength(4));
  });
}
