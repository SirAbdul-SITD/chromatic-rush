import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'game_constants.dart';

class GameState extends ChangeNotifier {
  int _currentScore = 0;
  int _bestScore = 0;
  int _combo = 0;
  int _totalObstaclesPassed = 0;
  bool _isPlaying = false;
  bool _isPaused = false;
  bool _isGameOver = false;
  double _gameTime = 0.0;
  Lane _currentLane = Lane.center;
  Color _ballColor = GameColors.blue;
  String _lastMotivation = '';

  static const List<String> _motivations = [
    'Almost there! 🔥',
    'Great reflex! ⚡',
    'Try again! 💪',
    'So close! 🎯',
    'You\'re improving! 🚀',
    'Keep pushing! ⚡',
    'Next time! 🌟',
  ];

  int get currentScore => _currentScore;
  int get bestScore => _bestScore;
  int get combo => _combo;
  int get totalObstaclesPassed => _totalObstaclesPassed;
  bool get isPlaying => _isPlaying;
  bool get isPaused => _isPaused;
  bool get isGameOver => _isGameOver;
  double get gameTime => _gameTime;
  Lane get currentLane => _currentLane;
  Color get ballColor => _ballColor;
  String get lastMotivation => _lastMotivation;

  GameState() {
    _loadBestScore();
  }

  Future<void> _loadBestScore() async {
    final prefs = await SharedPreferences.getInstance();
    _bestScore = prefs.getInt('best_score') ?? 0;
    notifyListeners();
  }

  Future<void> _saveBestScore() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('best_score', _bestScore);
  }

  void startGame() {
    _currentScore = 0;
    _combo = 0;
    _totalObstaclesPassed = 0;
    _isPlaying = true;
    _isPaused = false;
    _isGameOver = false;
    _gameTime = 0.0;
    _currentLane = Lane.center;
    _ballColor = GameColors.blue;
    notifyListeners();
  }

  void pauseGame() {
    _isPaused = true;
    notifyListeners();
  }

  void resumeGame() {
    _isPaused = false;
    notifyListeners();
  }

  void updateGameTime(double delta) {
    _gameTime += delta;
  }

  void passObstacle() {
    _currentScore++;
    _totalObstaclesPassed++;
    _combo++;

    if (_combo > 0 && _combo % GameConstants.comboThreshold == 0) {
      _currentScore += GameConstants.comboBonus;
    }

    if (_currentScore > _bestScore) {
      _bestScore = _currentScore;
      _saveBestScore();
    }
    notifyListeners();
  }

  void switchLane(Lane lane) {
    _currentLane = lane;
    notifyListeners();
  }

  void changeBallColor(Color color) {
    _ballColor = color;
    notifyListeners();
  }

  void gameOver() {
    _isPlaying = false;
    _isGameOver = true;
    _combo = 0;
    _motivations.shuffle();
    _lastMotivation = _motivations.first;
    notifyListeners();
  }

  double get currentSpeed {
    if (_gameTime < GameConstants.phase2Time) return GameConstants.phase1Speed;
    if (_gameTime < GameConstants.phase3Time) return GameConstants.phase2Speed;
    if (_gameTime < GameConstants.phase4Time) return GameConstants.phase3Speed;
    return GameConstants.phase4Speed;
  }

  int get currentPhase {
    if (_gameTime < GameConstants.phase2Time) return 1;
    if (_gameTime < GameConstants.phase3Time) return 2;
    if (_gameTime < GameConstants.phase4Time) return 3;
    return 4;
  }

  bool get hasComboBonus => _combo > 0 && _combo % GameConstants.comboThreshold == 0;
}
