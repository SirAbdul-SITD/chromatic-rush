import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import '../models/obstacle_data.dart';
import '../utils/game_constants.dart';

enum GameEngineState { idle, playing, paused, over }

class TileEffect {
  final double x;
  final double y;
  final Color color;
  final bool isSuccess;
  double age = 0.0;
  TileEffect({required this.x, required this.y, required this.color, required this.isSuccess});
}

class GameController extends ChangeNotifier {
  // ── Engine ───────────────────────────────────────────────
  GameEngineState engineState = GameEngineState.idle;

  // ── Score ────────────────────────────────────────────────
  int score = 0;
  int bestScore = 0;
  int combo = 0;
  double gameTime = 0;
  int _passCount = 0;

  // ── Ball ─────────────────────────────────────────────────
  Lane currentLane = Lane.center;
  Color ballColor = GameColors.blue;
  double _targetBallX = 0;
  double _currentBallX = 0;

  // ── World ────────────────────────────────────────────────
  double _worldOffset = 0;
  double _nextObstacleWorldY = 0;
  double _idCounter = 0;
  final List<ObstacleData> obstacles = [];

  // ── Visual effects ───────────────────────────────────────
  bool showComboEffect = false;
  bool showColorChangeEffect = false;
  bool showPhaseUpBanner = false;
  int lastBannerPhase = 0;
  double shakeAmount = 0; // pixels — decays each frame
  final List<TileEffect> tileEffects = [];
  Timer? _comboTimer;
  Timer? _bannerTimer;

  // ── Screen ───────────────────────────────────────────────
  double screenWidth = 375;
  double screenHeight = 812;

  // ── Getters ──────────────────────────────────────────────
  double get worldOffset => _worldOffset;
  double get ballScreenX => _currentBallX;
  double get ballScreenY => screenHeight * GameConstants.ballStartYFraction;

  int get currentPhase {
    if (gameTime < GameConstants.phase2Time) return 1;
    if (gameTime < GameConstants.phase3Time) return 2;
    if (gameTime < GameConstants.phase4Time) return 3;
    return 4;
  }

  /// Smoothly interpolated speed — ramps over 2 seconds between phase thresholds
  double get currentSpeed {
    final p = currentPhase;
    final speeds = [
      GameConstants.phase1Speed,
      GameConstants.phase2Speed,
      GameConstants.phase3Speed,
      GameConstants.phase4Speed,
    ];

    if (p >= 4) return GameConstants.phase4Speed;

    final thresholds = [0.0, GameConstants.phase2Time, GameConstants.phase3Time, GameConstants.phase4Time];
    final rampDuration = 2.5; // seconds to ramp to next speed
    final timeIntoPhase = gameTime - thresholds[p - 1];
    final t = (timeIntoPhase / rampDuration).clamp(0.0, 1.0);
    // Smooth cubic interpolation
    final smoothT = t * t * (3 - 2 * t);
    return speeds[p - 1] + (speeds[p] - speeds[p - 1]) * smoothT;
  }

  double getLaneX(Lane lane) {
    switch (lane) {
      case Lane.left:   return screenWidth * GameConstants.leftLaneFraction;
      case Lane.center: return screenWidth * GameConstants.centerLaneFraction;
      case Lane.right:  return screenWidth * GameConstants.rightLaneFraction;
    }
  }

  double getLaneXByIndex(int idx) => getLaneX(Lane.values[idx.clamp(0, 2)]);

  double obstacleScreenY(ObstacleData obs) =>
      ballScreenY - (obs.yPosition - _worldOffset);

  // ── Lifecycle ─────────────────────────────────────────────
  void startGame(double sw, double sh) {
    screenWidth = sw;
    screenHeight = sh;
    engineState = GameEngineState.playing;
    score = 0; combo = 0; _passCount = 0;
    gameTime = 0; _worldOffset = 0; _idCounter = 0;
    lastBannerPhase = 1; shakeAmount = 0;
    showComboEffect = false; showColorChangeEffect = false; showPhaseUpBanner = false;
    currentLane = Lane.center;
    ballColor = GameColors.blue;
    _currentBallX = getLaneX(Lane.center);
    _targetBallX = _currentBallX;
    obstacles.clear();
    tileEffects.clear();

    // First tile appears ~2.6 seconds ahead at phase 1 speed (200*520/200 = 2.6s)
    _nextObstacleWorldY = 520;
    for (int i = 0; i < 10; i++) _spawnObstacle();
    notifyListeners();
  }

  void pause() {
    if (engineState == GameEngineState.playing) {
      engineState = GameEngineState.paused;
      notifyListeners();
    }
  }

  void resume() {
    if (engineState == GameEngineState.paused) {
      engineState = GameEngineState.playing;
      notifyListeners();
    }
  }

  void triggerGameOver() {
    engineState = GameEngineState.over;
    shakeAmount = 18.0; // screen shake on death
    notifyListeners();
  }

  // ── Input ─────────────────────────────────────────────────
  void onMoveLeft() {
    if (engineState != GameEngineState.playing) return;
    if (currentLane == Lane.right)  currentLane = Lane.center;
    else if (currentLane == Lane.center) currentLane = Lane.left;
    _targetBallX = getLaneX(currentLane);
    notifyListeners();
  }

  void onMoveRight() {
    if (engineState != GameEngineState.playing) return;
    if (currentLane == Lane.left)   currentLane = Lane.center;
    else if (currentLane == Lane.center) currentLane = Lane.right;
    _targetBallX = getLaneX(currentLane);
    notifyListeners();
  }

  // ── Main update ───────────────────────────────────────────
  void update(double dt) {
    if (engineState != GameEngineState.playing) return;

    // Phase-up banner
    final phase = currentPhase;
    if (phase > lastBannerPhase) {
      lastBannerPhase = phase;
      _triggerPhaseUpBanner();
    }

    gameTime += dt;
    _worldOffset += currentSpeed * dt;

    // Ball X: faster snap at higher speed so player can keep up
    final snapFactor = 14.0 + currentSpeed * 0.01;
    _currentBallX += (_targetBallX - _currentBallX) * snapFactor * dt;

    // Decay screen shake
    if (shakeAmount > 0) {
      shakeAmount = (shakeAmount - dt * 80).clamp(0.0, 20.0);
    }

    // Obstacle animation
    for (final obs in obstacles) {
      if (obs.type == ObstacleType.rotatingBar || obs.type == ObstacleType.splitRing) {
        obs.rotationAngle += obs.rotationSpeed * dt;
      }
      if (obs.type == ObstacleType.movingWall) {
        obs.rotationAngle += obs.wallSpeed * dt;
        obs.wallFraction = sin(obs.rotationAngle);
        obs.correctLane  = obs.wallLane;
      }
      if ((obs.hitSuccess || obs.hitFail) && obs.hitAge < 1.0) {
        obs.hitAge = (obs.hitAge + dt * 2.8).clamp(0.0, 1.0);
      }
    }

    // Tile effects
    tileEffects.removeWhere((e) { e.age += dt * 2.0; return e.age >= 1.0; });

    // Spawn ahead
    while (_nextObstacleWorldY < _worldOffset + screenHeight * 2.0) _spawnObstacle();

    _checkCollisions();

    // Cull obstacles below ball
    obstacles.removeWhere((obs) => obstacleScreenY(obs) > screenHeight + 200);

    notifyListeners();
  }

  void _spawnObstacle() {
    _idCounter++;
    obstacles.add(ObstacleData.generate(
      yPosition: _nextObstacleWorldY,
      ballColor: ballColor,
      phase: currentPhase,
      id: _idCounter.toStringAsFixed(0),
    ));
    _nextObstacleWorldY += GameConstants.obstacleSpacing;
  }

  // ── Collision ─────────────────────────────────────────────
  void _checkCollisions() {
    if (gameTime < 2.0) return;

    final by = ballScreenY;

    for (final obs in obstacles) {
      if (obs.passed) continue;

      final sy = obstacleScreenY(obs);
      if (sy < -120 || sy > screenHeight + 120) continue;

      final halfH = GameConstants.obstacleHeight * 0.44;

      if (by >= sy - halfH && by <= sy + halfH) {
        obs.passed = true;
        final ballIdx = currentLane.index;
        final reqLane = obs.type == ObstacleType.movingWall ? obs.wallLane : obs.correctLane;

        if (ballIdx == reqLane) {
          _onCorrectPass(obs, sy, reqLane);
        } else {
          _onWrongLane(obs, ballIdx, sy);
          return;
        }
      }

      // Silently skip obstacles the ball has passed without touching
      if (sy > by + GameConstants.obstacleHeight * 0.55 && !obs.passed) {
        obs.passed = true;
      }
    }
  }

  void _onCorrectPass(ObstacleData obs, double sy, int passedLane) {
    _passCount++;
    score++;
    combo++;
    if (score > bestScore) bestScore = score;

    obs.hitSuccess = true;
    obs.hitAge = 0.0;
    obs.hitLane = passedLane; // the lane ball was actually in

    tileEffects.add(TileEffect(
      x: getLaneXByIndex(passedLane),
      y: sy,
      color: obs.matchColor,
      isSuccess: true,
    ));

    if (combo % GameConstants.comboThreshold == 0) {
      score += GameConstants.comboBonus;
      _triggerComboEffect();
    }

    // Auto color change — phase 3: every 3 passes, phase 4: every 2
    final shouldChange = obs.isColorChanger
        || (currentPhase == 3 && _passCount % 3 == 0)
        || (currentPhase >= 4 && _passCount % 2 == 0);

    if (shouldChange) _changeBallColor(obs.newBallColor, sy);
  }

  void _onWrongLane(ObstacleData obs, int ballIdx, double sy) {
    obs.hitFail = true;
    obs.hitAge = 0.0;
    obs.hitLane = ballIdx;

    tileEffects.add(TileEffect(
      x: getLaneXByIndex(ballIdx),
      y: sy,
      color: GameColors.red,
      isSuccess: false,
    ));

    triggerGameOver();
  }

  void _changeBallColor(Color newColor, double nearSy) {
    ballColor = newColor;
    showColorChangeEffect = true;
    _refreshUpcomingColors(nearSy);
    Future.delayed(const Duration(milliseconds: 320), () {
      showColorChangeEffect = false;
      notifyListeners();
    });
  }

  /// Regenerate colors on obstacles that are far enough ahead of the ball
  void _refreshUpcomingColors(double changedAtSy) {
    final random = Random();
    final safeMargin = GameConstants.obstacleSpacing * 0.8;

    for (final obs in obstacles) {
      if (obs.passed) continue;
      final sy = obstacleScreenY(obs);
      // Only refresh obstacles that are still well above ball (far ahead)
      if (sy > changedAtSy - safeMargin) continue;

      final others = List<Color>.from(GameColors.gameColors)..remove(ballColor);
      others.shuffle(random);
      final newCorrect = random.nextInt(3);

      // Build 3 distinct colors: one slot = ballColor, rest from others
      final threeColors = others.take(2).toList();
      obs.laneColors[newCorrect] = ballColor;
      int fill = 0;
      for (int i = 0; i < 3; i++) {
        if (i != newCorrect) obs.laneColors[i] = threeColors[fill++];
      }
      // Only update correctLane if obstacle doesn't have a dynamic lane (moving wall)
      if (obs.type != ObstacleType.movingWall) {
        obs.correctLane = newCorrect;
      }
    }
  }

  void _triggerComboEffect() {
    showComboEffect = true;
    _comboTimer?.cancel();
    _comboTimer = Timer(const Duration(milliseconds: 900), () {
      showComboEffect = false;
      notifyListeners();
    });
  }

  void _triggerPhaseUpBanner() {
    showPhaseUpBanner = true;
    _bannerTimer?.cancel();
    _bannerTimer = Timer(const Duration(milliseconds: 1800), () {
      showPhaseUpBanner = false;
      notifyListeners();
    });
  }

  @override
  void dispose() {
    _comboTimer?.cancel();
    _bannerTimer?.cancel();
    super.dispose();
  }
}
