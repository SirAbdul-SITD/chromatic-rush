import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'game_constants.dart';

class SkinManager extends ChangeNotifier {
  BallSkin _selectedSkin = BallSkin.neon;
  Set<BallSkin> _unlockedSkins = {BallSkin.neon};

  BallSkin get selectedSkin => _selectedSkin;
  Set<BallSkin> get unlockedSkins => _unlockedSkins;

  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    final skinIndex = prefs.getInt('selected_skin') ?? 0;
    _selectedSkin = BallSkin.values[skinIndex];

    final unlockedIndices = prefs.getStringList('unlocked_skins') ?? ['0'];
    _unlockedSkins = unlockedIndices
        .map((i) => BallSkin.values[int.parse(i)])
        .toSet();
    notifyListeners();
  }

  Future<void> selectSkin(BallSkin skin) async {
    if (_unlockedSkins.contains(skin)) {
      _selectedSkin = skin;
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt('selected_skin', skin.index);
      notifyListeners();
    }
  }

  Future<void> unlockSkin(BallSkin skin) async {
    _unlockedSkins.add(skin);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(
      'unlocked_skins',
      _unlockedSkins.map((s) => s.index.toString()).toList(),
    );
    notifyListeners();
  }

  bool isSkinUnlocked(BallSkin skin) => _unlockedSkins.contains(skin);

  void checkUnlocks(int bestScore) {
    for (final skin in BallSkin.values) {
      if (bestScore >= skin.requiredScore && !_unlockedSkins.contains(skin)) {
        unlockSkin(skin);
      }
    }
  }
}
