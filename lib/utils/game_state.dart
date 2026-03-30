import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class GameState extends ChangeNotifier {
  int _bestScore = 0;

  int get bestScore => _bestScore;

  // Fresh key — abandons any old corrupt value stored under 'best_score'
  static const _key = 'best_score_v2';

  GameState() {
    _load();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    _bestScore = prefs.getInt(_key) ?? 0;
    notifyListeners();
  }

  Future<void> _save() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_key, _bestScore);
  }

  /// Called from game_screen after game over
  Future<void> syncBestScore(int controllerBest) async {
    if (controllerBest > _bestScore) {
      _bestScore = controllerBest;
      await _save();
      notifyListeners();
    } else {
      // Reload from prefs to pick up any value saved by controller
      final prefs = await SharedPreferences.getInstance();
      final saved = prefs.getInt(_key) ?? 0;
      if (saved > _bestScore) {
        _bestScore = saved;
        notifyListeners();
      }
    }
  }
}
