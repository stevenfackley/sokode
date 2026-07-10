import 'package:flutter/foundation.dart';
import 'package:sokode_core/sokode_core.dart';

/// Presentation-side play state: a stack of core GridStates plus the
/// recorded action sequence. All rules live in the core; this class only
/// orchestrates. The recording is the FINAL action sequence — undo pops
/// moves, so undone moves never appear in a published solution (spec §2.3).
class PlayerSession extends ChangeNotifier {
  PlayerSession(this.level) : _states = [GridState.initial(level)];

  final Level level;

  static const SokobanPlus _rules = SokobanPlus();
  static const Simulation _simulation = Simulation(_rules);

  final List<GridState> _states;
  final List<Direction> _moves = [];

  GridState get state => _states.last;

  /// The recorded solution-so-far. Unmodifiable snapshot.
  List<Direction> get moves => List.unmodifiable(_moves);

  int get moveCount => _moves.length;

  bool get isSolved => _rules.isSolved(state);

  bool get canUndo => _moves.isNotEmpty;

  /// Applies [direction] if legal. Returns false (and records nothing) on
  /// Blocked, and ignores input entirely once solved so the recorded
  /// solution stays exactly the sequence that won.
  bool tryMove(Direction direction) {
    if (isSolved) return false;
    switch (_simulation.apply(state, direction)) {
      case Moved(:final state):
        _states.add(state);
        _moves.add(direction);
        notifyListeners();
        return true;
      case Blocked():
        return false;
    }
  }

  void undo() {
    if (_moves.isEmpty) return;
    _states.removeLast();
    _moves.removeLast();
    notifyListeners();
  }

  void reset() {
    _states
      ..clear()
      ..add(GridState.initial(level));
    _moves.clear();
    notifyListeners();
  }
}
