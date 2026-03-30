import 'dart:math';
import 'package:flutter/material.dart';
import '../utils/game_constants.dart';

class ObstacleData {
  final String id;
  final ObstacleType type;
  double yPosition;
  final List<Color> laneColors;
  final Color matchColor;
  int correctLane;
  bool passed;
  bool isColorChanger;

  // Hit animation
  bool hitSuccess = false;
  bool hitFail = false;
  double hitAge = 0.0;
  int hitLane = -1;

  // Spinning obstacles (rotatingBar / splitRing)
  double rotationAngle;
  final double rotationSpeed;

  // Moving wall
  double wallFraction;      // sin-oscillated -1..+1
  bool wallFrozen = false;  // frozen when ball approaches
  final double wallSpeed;

  ObstacleData({
    required this.id,
    required this.type,
    required this.yPosition,
    required this.laneColors,
    required this.matchColor,
    required this.correctLane,
    this.passed = false,
    this.isColorChanger = false,
    this.rotationAngle = 0,
    this.rotationSpeed = 1.5,
    this.wallFraction = 0.0,
    this.wallSpeed = 0.75,
  });

  static ObstacleData generate({
    required double yPosition,
    required Color ballColor,
    required int phase,
    required String id,
    ObstacleType? lastType, // prevent same spinning type twice in a row
  }) {
    final random = Random();

    // ── Type selection ────────────────────────────────────
    // Spinning types (rotatingBar, splitRing) must NOT follow each other
    final isLastSpin = lastType == ObstacleType.rotatingBar ||
        lastType == ObstacleType.splitRing;

    ObstacleType type;
    if (phase == 1) {
      // Phase 1: only simple color gates
      type = ObstacleType.colorGate;
    } else if (phase == 2) {
      // Phase 2: gates + moving wall, no spinning yet
      type = [
        ObstacleType.colorGate,
        ObstacleType.colorGate,
        ObstacleType.colorGate,
        ObstacleType.movingWall,
      ][random.nextInt(4)];
    } else {
      // Phase 3+: all types allowed, but no consecutive spinning
      final pool = <ObstacleType>[
        ObstacleType.colorGate,
        ObstacleType.colorGate,
        ObstacleType.movingWall,
        ObstacleType.colorChangeGate,
      ];
      if (!isLastSpin) {
        pool.add(ObstacleType.rotatingBar);
        pool.add(ObstacleType.splitRing);
      }
      type = pool[random.nextInt(pool.length)];
    }

    // ── Lane colors — guaranteed visually distinct ────────────
    // Pick 3 colors from the 5 non-ball colors that are maximally
    // distinct from each other. Yellow+Orange together are forbidden
    // because they look too similar at a glance.
    final candidates = List<Color>.from(GameColors.gameColors)..remove(ballColor);

    // Hue values in degrees for each game color (used for separation check)
    double hueOf(Color c) {
      if (c == GameColors.red)    return 345;
      if (c == GameColors.blue)   return 193;
      if (c == GameColors.green)  return 151;
      if (c == GameColors.yellow) return 51;
      if (c == GameColors.purple) return 285;
      if (c == GameColors.orange) return 30;
      return 0;
    }

    bool huesTooClose(Color a, Color b) {
      double diff = (hueOf(a) - hueOf(b)).abs();
      if (diff > 180) diff = 360 - diff;
      return diff < 45; // less than 45° apart = too similar
    }

    // Try shuffled orderings until we find 3 mutually distinct colors
    List<Color> picked = [];
    const maxTries = 40;
    for (int attempt = 0; attempt < maxTries; attempt++) {
      candidates.shuffle(random);
      final a = candidates[0], b = candidates[1], c = candidates[2];
      if (!huesTooClose(a, b) && !huesTooClose(b, c) && !huesTooClose(a, c)) {
        picked = [a, b, c];
        break;
      }
    }
    // Fallback: if we somehow couldn't find a valid triple (shouldn't happen),
    // use the first 3 with at least the worst offender swapped out
    if (picked.isEmpty) {
      candidates.shuffle(random);
      // Force-replace: if yellow and orange are both in first 3, drop the one
      // whose hue is closer to the third color
      picked = [candidates[0], candidates[1], candidates[2]];
      if (huesTooClose(picked[0], picked[1])) {
        picked[1] = candidates.firstWhere(
          (c) => !huesTooClose(c, picked[0]) && !huesTooClose(c, picked[2]),
          orElse: () => candidates[3],
        );
      }
    }

    final correctLane = random.nextInt(3);
    final laneColors  = [picked[0], picked[1], picked[2]];
    laneColors[correctLane] = ballColor;

    // ── Color changer flag ────────────────────────────────
    final isColorChanger = type == ObstacleType.colorChangeGate;

    // Moving wall: start at a random sine angle so gap begins in varied positions
    final startAngle = random.nextDouble() * pi * 2;

    return ObstacleData(
      id: id,
      type: type,
      yPosition: yPosition,
      laneColors: laneColors,
      matchColor: ballColor,
      correctLane: correctLane,
      isColorChanger: isColorChanger,
      rotationSpeed: phase >= 4 ? 2.2 : (phase == 3 ? 1.7 : 1.4),
      wallFraction: sin(startAngle),
      wallSpeed: phase >= 4 ? 0.95 : (phase == 3 ? 0.8 : 0.65),
      rotationAngle: startAngle, // reused as time accumulator for wall
    );
  }

  Color get newBallColor {
    final others = List<Color>.from(GameColors.gameColors)..remove(matchColor)..shuffle();
    return others.first;
  }

  /// Which lane the gap is currently in: 0=left, 1=center, 2=right
  int get wallLane {
    if (wallFraction < -0.33) return 0;
    if (wallFraction < 0.33)  return 1;
    return 2;
  }
}
