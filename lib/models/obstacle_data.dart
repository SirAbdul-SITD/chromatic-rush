import 'dart:math';
import 'package:flutter/material.dart';
import '../utils/game_constants.dart';

class ObstacleData {
  final String id;
  final ObstacleType type;
  double yPosition; // World position (increases as ball moves up)
  final List<Color> laneColors; // Colors for left, center, right lanes
  final Color matchColor; // The color ball must match
  final int correctLane; // 0=left, 1=center, 2=right
  bool passed;
  bool isColorChanger;

  // For rotating bar
  double rotationAngle;
  final double rotationSpeed;

  // For moving wall
  double wallOffset;
  final double wallSpeed;
  final bool wallMovesRight;

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
    this.wallOffset = 0,
    this.wallSpeed = 100,
    this.wallMovesRight = true,
  });

  static ObstacleData generate({
    required double yPosition,
    required Color ballColor,
    required int phase,
    required String id,
  }) {
    final random = Random();

    // Which type to use based on phase
    ObstacleType type;
    if (phase == 1) {
      type = ObstacleType.colorGate;
    } else if (phase == 2) {
      final r = random.nextInt(3);
      type = [
        ObstacleType.colorGate,
        ObstacleType.rotatingBar,
        ObstacleType.movingWall,
      ][r];
    } else {
      final r = random.nextInt(5);
      type = ObstacleType.values[r];
    }

    // Pick colors for lanes
    final allColors = List<Color>.from(GameColors.gameColors)..remove(ballColor);
    allColors.shuffle(random);

    final correctLane = random.nextInt(3);

    final List<Color> laneColors = [
      allColors[0],
      allColors[1],
      allColors[2],
    ];
    laneColors[correctLane] = ballColor;

    final bool isColorChanger = type == ObstacleType.colorChangeGate ||
        (phase >= 3 && random.nextDouble() < 0.2);

    return ObstacleData(
      id: id,
      type: type,
      yPosition: yPosition,
      laneColors: laneColors,
      matchColor: ballColor,
      correctLane: correctLane,
      isColorChanger: isColorChanger,
      rotationSpeed: phase == 4 ? 3.0 : 1.5,
      wallSpeed: phase >= 3 ? 150 : 100,
      wallMovesRight: random.nextBool(),
    );
  }

  Color get newBallColor {
    // If color changer, pick a random different color
    final others = GameColors.gameColors.where((c) => c != matchColor).toList();
    others.shuffle();
    return others.first;
  }
}
