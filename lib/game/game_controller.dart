import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
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
  int bestScore = 0;    // loaded from prefs at startGame
  int combo = 0;
  double gameTime = 0;
  int _passCount = 0;
  int _nextColorChangeAt = 4; // randomised 3-6 each time

  // ── Ball ─────────────────────────────────────────────────
  Lane currentLane = Lane.center;
  Color ballColor = GameColors.blue;
  BallSkin activeSkin = BallSkin.neon;   // set from SkinManager before startGame
  double _targetBallX = 0;
  double _currentBallX = 0;

  // ── World ────────────────────────────────────────────────
  double _worldOffset = 0;
  double _nextObstacleWorldY = 0;
  double _idCounter = 0;
  ObstacleType? _lastSpawnedType;   // for consecutive-type prevention
  final List<ObstacleData> obstacles = [];

  // ── Visual effects ───────────────────────────────────────
  bool showComboEffect = false;
  bool showColorChangeEffect = false;
  bool showPhaseUpBanner = false;
  int  lastBannerPhase = 0;
  double shakeAmount = 0;
  final List<TileEffect> tileEffects = [];
  Timer? _comboTimer;
  Timer? _bannerTimer;

  // ── Screen ───────────────────────────────────────────────
  double screenWidth = 375;
  double screenHeight = 812;

  // ── Getters ──────────────────────────────────────────────
  double get worldOffset  => _worldOffset;
  double get ballScreenX  => _currentBallX;
  double get ballScreenY  => screenHeight * GameConstants.ballStartYFraction;

  int get currentPhase {
    if (gameTime < GameConstants.phase2Time) return 1;
    if (gameTime < GameConstants.phase3Time) return 2;
    if (gameTime < GameConstants.phase4Time) return 3;
    return 4;
  }

  /// Smooth cubic ramp between phase speeds over 3 seconds
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
    final t = ((gameTime - thresholds[p - 1]) / 3.0).clamp(0.0, 1.0);
    final smooth = t * t * (3 - 2 * t);
    return speeds[p - 1] + (speeds[p] - speeds[p - 1]) * smooth;
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
  Future<void> startGame(double sw, double sh, {BallSkin skin = BallSkin.neon}) async {
    screenWidth = sw;
    screenHeight = sh;
    activeSkin = skin;

    // Load saved best score — use same fresh key as GameState
    final prefs = await SharedPreferences.getInstance();
    bestScore = prefs.getInt('best_score_v2') ?? 0;

    engineState = GameEngineState.playing;
    score = 0; combo = 0; _passCount = 0;
    gameTime = 0; _worldOffset = 0; _idCounter = 0;
    lastBannerPhase = 1; shakeAmount = 0;
    _lastSpawnedType = null;
    _nextColorChangeAt = _randomColorInterval();
    showComboEffect = false; showColorChangeEffect = false; showPhaseUpBanner = false;
    currentLane = Lane.center;
    // Use skin primary color as starting ball color
    ballColor = skin.primaryColor;
    _currentBallX = getLaneX(Lane.center);
    _targetBallX = _currentBallX;
    obstacles.clear();
    tileEffects.clear();

    _nextObstacleWorldY = 520;
    for (int i = 0; i < 10; i++) _spawnObstacle();
    notifyListeners();
  }

  Future<void> _saveBestScore() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('best_score_v2', bestScore);
  }

  int _randomColorInterval() => 3 + Random().nextInt(4); // 3, 4, 5, or 6

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
    if (engineState == GameEngineState.over) return;
    engineState = GameEngineState.over;
    shakeAmount = 18.0;
    notifyListeners();
  }

  // ── Input ─────────────────────────────────────────────────
  void onMoveLeft() {
    if (engineState != GameEngineState.playing) return;
    if (currentLane == Lane.right)        currentLane = Lane.center;
    else if (currentLane == Lane.center)  currentLane = Lane.left;
    _targetBallX = getLaneX(currentLane);
    notifyListeners();
  }

  void onMoveRight() {
    if (engineState != GameEngineState.playing) return;
    if (currentLane == Lane.left)         currentLane = Lane.center;
    else if (currentLane == Lane.center)  currentLane = Lane.right;
    _targetBallX = getLaneX(currentLane);
    notifyListeners();
  }

  // ── Update ────────────────────────────────────────────────
  void update(double dt) {
    if (engineState != GameEngineState.playing) return;

    // Phase banner
    final phase = currentPhase;
    if (phase > lastBannerPhase) {
      lastBannerPhase = phase;
      _triggerPhaseUpBanner();
    }

    gameTime += dt;
    _worldOffset += currentSpeed * dt;

    // Ball X snap — faster at higher speed
    final snap = 14.0 + currentSpeed * 0.012;
    _currentBallX += (_targetBallX - _currentBallX) * snap * dt;

    // Shake decay
    if (shakeAmount > 0) shakeAmount = (shakeAmount - dt * 80).clamp(0.0, 20.0);

    // Animate obstacles
    for (final obs in obstacles) {
      if (obs.passed) continue;

      final sy = obstacleScreenY(obs);

      if (obs.type == ObstacleType.rotatingBar || obs.type == ObstacleType.splitRing) {
        obs.rotationAngle += obs.rotationSpeed * dt;
      }

      if (obs.type == ObstacleType.movingWall) {
        // FIX: Freeze wall movement when ball is within 200px — gives player time to react
        final distanceToBall = sy - ballScreenY;
        if (!obs.wallFrozen && distanceToBall < 200 && distanceToBall > -50) {
          obs.wallFrozen = true;
          // Lock correctLane to current wallLane at freeze moment
          obs.correctLane = obs.wallLane;
        }
        if (!obs.wallFrozen) {
          obs.rotationAngle += obs.wallSpeed * dt;
          obs.wallFraction = sin(obs.rotationAngle);
          obs.correctLane  = obs.wallLane;
        }
        // Once frozen, wallFraction stays fixed — no more updating
      }

      if ((obs.hitSuccess || obs.hitFail) && obs.hitAge < 1.0) {
        obs.hitAge = (obs.hitAge + dt * 2.8).clamp(0.0, 1.0);
      }
    }

    // Tile effects age
    tileEffects.removeWhere((e) { e.age += dt * 2.0; return e.age >= 1.0; });

    // Spawn ahead
    while (_nextObstacleWorldY < _worldOffset + screenHeight * 2.2) _spawnObstacle();

    _checkCollisions();

    // Cull
    obstacles.removeWhere((obs) => obstacleScreenY(obs) > screenHeight + 200);

    notifyListeners();
  }

  void _spawnObstacle() {
    _idCounter++;
    final obs = ObstacleData.generate(
      yPosition: _nextObstacleWorldY,
      ballColor: ballColor,
      phase: currentPhase,
      id: _idCounter.toStringAsFixed(0),
      lastType: _lastSpawnedType,
    );
    _lastSpawnedType = obs.type;
    obstacles.add(obs);
    _nextObstacleWorldY += GameConstants.obstacleSpacing;
  }

  // ── Collision ─────────────────────────────────────────────
  void _checkCollisions() {
    if (gameTime < 2.0) return;

    final by = ballScreenY;

    for (final obs in obstacles) {
      if (obs.passed) continue;

      final sy = obstacleScreenY(obs);
      if (sy < -150 || sy > screenHeight + 150) continue;

      final halfH = GameConstants.obstacleHeight * 0.44;

      if (by >= sy - halfH && by <= sy + halfH) {
        obs.passed = true;
        final ballIdx  = currentLane.index;
        // For moving wall use the frozen correctLane
        final reqLane  = obs.correctLane;

        if (ballIdx == reqLane) {
          _onCorrectPass(obs, sy, reqLane);
        } else {
          _onWrongLane(obs, ballIdx, sy);
          return;
        }
      }

      // Silently skip obstacles that slipped past
      if (sy > by + GameConstants.obstacleHeight * 0.55 && !obs.passed) {
        obs.passed = true;
      }
    }
  }

  void _onCorrectPass(ObstacleData obs, double sy, int passedLane) {
    _passCount++;
    score++;
    combo++;
    if (score > bestScore) {
      bestScore = score;
      _saveBestScore(); // persist immediately when new best
    }

    obs.hitSuccess = true;
    obs.hitAge     = 0.0;
    obs.hitLane    = passedLane;

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

    // Color change: starts at phase 2, every _nextColorChangeAt passes (3-6)
    final shouldChange = obs.isColorChanger
        || (currentPhase >= 2 && _passCount >= _nextColorChangeAt);

    if (shouldChange) {
      _passCount = 0; // reset counter
      _nextColorChangeAt = _randomColorInterval();
      _changeBallColor(obs.newBallColor, sy);
    }
  }

  void _onWrongLane(ObstacleData obs, int ballIdx, double sy) {
    obs.hitFail = true;
    obs.hitAge  = 0.0;
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
    Future.delayed(const Duration(milliseconds: 350), () {
      showColorChangeEffect = false;
      notifyListeners();
    });
  }

  void _refreshUpcomingColors(double changedAtSy) {
    final random = Random();
    // Only refresh obstacles that are far enough above the ball (safe margin)
    final safeScreenY = changedAtSy - GameConstants.obstacleSpacing * 0.9;

    for (final obs in obstacles) {
      if (obs.passed) continue;
      final sy = obstacleScreenY(obs);
      if (sy > safeScreenY) continue; // too close — don't change

      final others = List<Color>.from(GameColors.gameColors)..remove(ballColor)..shuffle(random);
      final newCorrect = random.nextInt(3);
      obs.laneColors[newCorrect] = ballColor;
      int fill = 0;
      for (int i = 0; i < 3; i++) {
        if (i != newCorrect) obs.laneColors[i] = others[fill++];
      }
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
    _bannerTimer = Timer(const Duration(milliseconds: 2000), () {
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
