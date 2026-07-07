import 'grid_state.dart';

/// Deterministic, cross-platform fingerprint of a GridState.
///
/// Deliberately NOT a cryptographic hash and NOT hashCode: it must produce
/// the same value on the Dart VM and on the web (JS numbers), so all
/// arithmetic stays below 2^53. h*31 + v with h < 1e9+7 and v <= 65535
/// peaks around 3.1e10 — exact in a double. Used by the determinism golden
/// test and (later) the title generator.
int stateDigest(GridState state) {
  const modulus = 1000000007;
  var h = 7;
  void mix(int v) {
    h = (h * 31 + v + 2) % modulus;
  }

  mix(state.playerIndex);
  state.crateIndexes.forEach(mix);
  mix(modulus - 1); // section separator
  state.openGateIndexes.forEach(mix);
  return h;
}
