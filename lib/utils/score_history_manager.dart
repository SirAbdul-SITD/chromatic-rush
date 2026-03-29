import 'package:shared_preferences/shared_preferences.dart';

class ScoreHistoryManager {
  static const _key = 'score_history';
  static const _maxEntries = 20;

  static Future<void> saveScore(int score) async {
    if (score <= 0) return;
    final prefs = await SharedPreferences.getInstance();
    final existing = prefs.getStringList(_key) ?? [];
    existing.add(score.toString());

    // Keep only most recent entries, sorted descending
    final sorted = existing
        .map(int.parse)
        .toList()
      ..sort((a, b) => b.compareTo(a));

    await prefs.setStringList(
      _key,
      sorted.take(_maxEntries).map((s) => s.toString()).toList(),
    );
  }

  static Future<List<int>> getHistory() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getStringList(_key) ?? [];
    return raw.map(int.parse).toList()..sort((a, b) => b.compareTo(a));
  }

  static Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_key);
  }
}
