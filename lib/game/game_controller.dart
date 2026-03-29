import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import '../models/obstacle_data.dart';
import '../utils/game_constants.dart';

enum GameEngineState { idle, playing, paused, over }

class GameController extends ChangeNotifier {
  // ── Engine state ────────────────────────────────────────
  GameEngineState engineState = GameEngineState.idle;

  // ── Score & time ────────────────────────────────────────
  int score = 0;
  int bestScore = 0;
  int combo = 0;
  double gameTime = 0;

  // ── Ball ────────────────────────────────────────────────
  Lane currentLane = Lane.center;
  Color ballColor = GameColors.blue;
  double _targetBallX = 0;
  double _currentBallX = 0;

  // ── World ────────────────────────────────────────────────
  double _worldOffset = 0;
  double _nextObstacleWorldY = 0;
  double _obstacleIdCounter = 0;
  final List<ObstacleData> obstacles = [];

  // ── Effects ─────────────────────────────────────────────
  bool showComboEffect = false;
  bool showColorChangeEffect = false;
  Timer? _comboTimer;

  // ── Screen info ─────────────────────────────────────────
  double screenWidth = 375;
  double screenHeight = 812;

  // ── Public getters ───────────────────────────────────────
  double get worldOffset => _worldOffset;
  double get ballScreenX => _currentBallX;
  double get ballScreenY => screenHeight * GameConstants.ballStartYFraction;

  int get currentPhase {
    if (gameTime < GameConstants.phase2Time) return 1;
    if (gameTime < GameConstants.phase3Time) return 2;
    if (gameTime < GameConstants.phase4Time) return 3;
    return 4;
  }

  double get currentSpeed {
    switch (currentPhase) {
      case 1: return GameConstants.phase1Speed;
      case 2: return GameConstants.phase2Speed;
      case 3: return GameConstants.phase3Speed;
      default: return GameConstants.phase4Speed;
    }
  }

  double getLaneX(Lane lane) {
    switch (lane) {
      case Lane.left:   return screenWidth * GameConstants.leftLaneFraction;
      case Lane.center: return screenWidth * GameConstants.centerLaneFraction;
      case Lane.right:  return screenWidth * GameConstants.rightLaneFraction;
    }
  }

  // ── Obstacle screen Y ────────────────────────────────────
  // World system: ball is fixed on screen at ballScreenY.
  // Obstacles are spawned at positive Y values (distance ahead of ball start).
  // As _worldOffset grows, obstacles scroll down toward the ball.
  // screenY = ballScreenY - (obstacleY - _worldOffset)
  double obstacleScreenY(ObstacleData obs) {
    return ballScreenY - (obs.yPosition - _worldOffset);
  }

  // ── Lifecycle ─────────────────────────────────────────────
  void startGame(double sw, double sh) {
    screenWidth = sw;
    screenHeight = sh;
    engineState = GameEngineState.playing;
    score = 0;
    combo = 0;
    gameTime = 0;
    _worldOffset = 0;
    _obstacleIdCounter = 0;
    currentLane = Lane.center;
    ballColor = GameColors.blue;
    _currentBallX = getLaneX(Lane.center);
    _targetBallX = _currentBallX;
    obstacles.clear();

    // First obstacle appears well above screen (player has time to see it scroll down)
    _nextObstacleWorldY = 500;
    for (int i = 0; i < 8; i++) {
      _spawnObstacle();
    }
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
    notifyListeners();
  }

  // ── Input ─────────────────────────────────────────────────
  void onTapLeft() {
    if (engineState != GameEngineState.playing) return;
    switch (currentLane) {
      case Lane.right:
        currentLane = Lane.center;
        break;
      case Lane.center:
        currentLane = Lane.left;
        break;
      case Lane.left:
        break;
    }
    _targetBallX = getLaneX(currentLane);
    notifyListeners();
  }

  void onTapRight() {
    if (engineState != GameEngineState.playing) return;
    switch (currentLane) {
      case Lane.left:
        currentLane = Lane.center;
        break;
      case Lane.center:
        currentLane = Lane.right;
        break;
      case Lane.right:
        break;
    }
    _targetBallX = getLaneX(currentLane);
    notifyListeners();
  }

  // ── Update ────────────────────────────────────────────────
  void update(double dt) {
    if (engineState != GameEngineState.playing) return;

    gameTime += dt;
    _worldOffset += currentSpeed * dt;

    // Smooth ball X interpolation
    _currentBallX += (_targetBallX - _currentBallX) * 14 * dt;

    // Rotate/move animated obstacles
    for (final obs in obstacles) {
      if (obs.type == ObstacleType.rotatingBar || obs.type == ObstacleType.splitRing) {
        obs.rotationAngle += obs.rotationSpeed * dt;
      }
      if (obs.type == ObstacleType.movingWall) {
        obs.wallOffset += obs.wallSpeed * (obs.wallMovesRight ? 1 : -1) * dt;
        if (obs.wallOffset > screenWidth * 0.22) {
          obs.wallOffset = screenWidth * 0.22;
          // bounce direction handled by flipping in obstacle data
        }
        if (obs.wallOffset < -screenWidth * 0.22) {
          obs.wallOffset = -screenWidth * 0.22;
        }
      }
    }

    // Spawn more obstacles as needed
    while (_nextObstacleWorldY < _worldOffset + screenHeight * 1.5) {
      _spawnObstacle();
    }

    // Collision check
    _checkCollisions();

    // Cull passed/off-screen
    obstacles.removeWhere((obs) {
      final sy = obstacleScreenY(obs);
      return sy > screenHeight + 100;
    });

    notifyListeners();
  }

  void _spawnObstacle() {
    _obstacleIdCounter++;
    final obs = ObstacleData.generate(
      yPosition: _nextObstacleWorldY,
      ballColor: ballColor,
      phase: currentPhase,
      id: _obstacleIdCounter.toStringAsFixed(0),
    );
    obstacles.add(obs);
    _nextObstacleWorldY += GameConstants.obstacleSpacing;
  }

  void _checkCollisions() {
    // Don't check collisions in the first 1.5 seconds — give player time to see the game
    if (gameTime < 1.5) return;

    final by = ballScreenY;

    for (final obs in obstacles) {
      if (obs.passed) continue;

      final sy = obstacleScreenY(obs);

      // Only check obstacles that are on screen and approaching
      if (sy < -50 || sy > screenHeight + 50) continue;

      // Collision band — ball centre must overlap obstacle centre ± half height
      // Use a slightly tighter band (80% of height) so the edges feel forgiving
      final halfH = GameConstants.obstacleHeight * 0.4;
      final obsTop    = sy - halfH;
      final obsBottom = sy + halfH;

      if (by >= obsTop && by <= obsBottom) {
        final ballLaneIdx = currentLane.index; // 0=left, 1=center, 2=right

        if (ballLaneIdx == obs.correctLane) {
          obs.passed = true;
          _onCorrectPass(obs);
        } else {
          triggerGameOver();
          return;
        }
      }

      // Obstacle has fully scrolled past ball without being passed — mark it
      // Only do this if the obstacle centre has passed at least 60px below ball
      // (never fires on the first frame since we gate on gameTime above)
      if (sy > by + GameConstants.obstacleHeight && !obs.passed) {
        obs.passed = true; // silently skip — don't punish extremely early frames
      }
    }
  }

  void _onCorrectPass(ObstacleData obs) {
    score++;
    combo++;

    if (combo % GameConstants.comboThreshold == 0) {
      score += GameConstants.comboBonus;
      _triggerComboEffect();
    }

    if (score > bestScore) bestScore = score;

    // Color change gate
    if (obs.isColorChanger) {
      ballColor = obs.newBallColor;
      showColorChangeEffect = true;
      Future.delayed(const Duration(milliseconds: 350), () {
        showColorChangeEffect = false;
        notifyListeners();
      });
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

  @override
  void dispose() {
    _comboTimer?.cancel();
    super.dispose();
  }
}
