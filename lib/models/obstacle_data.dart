import 'dart:math';
import 'package:flutter/material.dart';
import '../utils/game_constants.dart';

class ObstacleData {
  final String id;
  final ObstacleType type;
  double yPosition;
  final List<Color> laneColors;
  final Color matchColor;
  int correctLane; // MUTABLE — moving wall updates this each frame
  bool passed;
  bool isColorChanger;

  // Hit animation state
  bool hitSuccess = false;
  bool hitFail = false;
  double hitAge = 0.0; // 0..1, animated by controller
  int hitLane = -1;   // which lane was hit

  // Rotating bar / split ring
  double rotationAngle;
  final double rotationSpeed;

  // Moving wall — wallFraction oscillates -1..+1
  double wallFraction;
  final double wallSpeed; // fraction per second

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
    this.wallFraction = -1.0,
    this.wallSpeed = 0.8,
  });

  static ObstacleData generate({
    required double yPosition,
    required Color ballColor,
    required int phase,
    required String id,
  }) {
    final random = Random();

    // Type distribution per phase
    ObstacleType type;
    if (phase == 1) {
      type = ObstacleType.colorGate;
    } else if (phase == 2) {
      type = [
        ObstacleType.colorGate,
        ObstacleType.colorGate,
        ObstacleType.rotatingBar,
        ObstacleType.movingWall,
      ][random.nextInt(4)];
    } else {
      type = [
        ObstacleType.colorGate,
        ObstacleType.rotatingBar,
        ObstacleType.movingWall,
        ObstacleType.splitRing,
        ObstacleType.colorChangeGate,
      ][random.nextInt(5)];
    }

    // Build lane colors — one lane always matches ball
    final allColors = List<Color>.from(GameColors.gameColors)..remove(ballColor);
    allColors.shuffle(random);
    final correctLane = random.nextInt(3);
    final laneColors = [allColors[0], allColors[1], allColors[2]];
    laneColors[correctLane] = ballColor;

    final bool isColorChanger = type == ObstacleType.colorChangeGate ||
        (phase >= 3 && random.nextDouble() < 0.15);

    // Moving wall starts with gap at left lane (fraction = -1.0)
    // wallFraction: -1=left lane, 0=center, +1=right lane
    final startFraction = [-1.0, 0.0, 1.0][random.nextInt(3)];

    return ObstacleData(
      id: id,
      type: type,
      yPosition: yPosition,
      laneColors: laneColors,
      matchColor: ballColor,
      correctLane: correctLane,
      isColorChanger: isColorChanger,
      rotationSpeed: phase == 4 ? 2.8 : (phase == 3 ? 2.0 : 1.5),
      wallFraction: startFraction,
      wallSpeed: phase >= 3 ? 1.1 : 0.75,
    );
  }

  Color get newBallColor {
    final others = GameColors.gameColors.where((c) => c != matchColor).toList()..shuffle();
    return others.first;
  }

  /// For moving walls: returns which lane (0/1/2) the gap is currently in
  int get wallLane {
    // wallFraction: -1=left, 0=center, +1=right
    if (wallFraction < -0.33) return 0;
    if (wallFraction < 0.33) return 1;
    return 2;
  }
}
