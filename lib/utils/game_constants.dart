import 'package:flutter/material.dart';

class GameColors {
  // Ball / obstacle colors
  static const Color red = Color(0xFFFF3366);
  static const Color blue = Color(0xFF00D4FF);
  static const Color green = Color(0xFF00FF88);
  static const Color yellow = Color(0xFFFFD700);
  static const Color purple = Color(0xFFBB44FF);
  static const Color orange = Color(0xFFFF8C00);

  // UI colors
  static const Color background = Color(0xFF050510);
  static const Color backgroundSecondary = Color(0xFF0A0A1E);
  static const Color neonBlue = Color(0xFF00D4FF);
  static const Color neonPurple = Color(0xFF9B59B6);
  static const Color neonGreen = Color(0xFF00FF88);
  static const Color textPrimary = Color(0xFFFFFFFF);
  static const Color textSecondary = Color(0xFFAAAAAA);
  static const Color cardBg = Color(0xFF0D0D2B);

  static const List<Color> gameColors = [red, blue, green, yellow, purple, orange];

  static Color randomGameColor() {
    gameColors.shuffle();
    return gameColors.first;
  }

  static Color getGlowColor(Color base) {
    return base.withOpacity(0.6);
  }
}

class GameConstants {
  // Lane positions (as fractions of screen width)
  static const double leftLaneFraction = 0.2;
  static const double centerLaneFraction = 0.5;
  static const double rightLaneFraction = 0.8;

  // Ball
  static const double ballRadius = 20.0;
  static const double ballStartYFraction = 0.75;

  // Obstacle
  static const double obstacleHeight = 120.0;   // 2× taller tiles
  static const double obstacleSpacing = 380.0;  // wider gap between rows
  static const double gateWidth = 64.0;

  // Speed phases
  static const double phase1Speed = 200.0;
  static const double phase2Speed = 320.0;
  static const double phase3Speed = 450.0;
  static const double phase4Speed = 600.0;

  // Timing thresholds (seconds)
  static const double phase2Time = 20.0;
  static const double phase3Time = 40.0;
  static const double phase4Time = 70.0;

  // Score
  static const int comboThreshold = 5;
  static const int comboBonus = 3;

  // Animation
  static const Duration laneSwitchDuration = Duration(milliseconds: 180);
  static const Duration colorChangeDuration = Duration(milliseconds: 200);
}

enum Lane { left, center, right }

enum ObstacleType { colorGate, rotatingBar, movingWall, splitRing, colorChangeGate }

enum BallSkin {
  neon,
  fire,
  ice,
  galaxy,
  electric,
}

extension BallSkinExtension on BallSkin {
  String get displayName {
    switch (this) {
      case BallSkin.neon:
        return 'Neon';
      case BallSkin.fire:
        return 'Fire';
      case BallSkin.ice:
        return 'Ice';
      case BallSkin.galaxy:
        return 'Galaxy';
      case BallSkin.electric:
        return 'Electric';
    }
  }

  Color get primaryColor {
    switch (this) {
      case BallSkin.neon:
        return GameColors.neonBlue;
      case BallSkin.fire:
        return const Color(0xFFFF4500);
      case BallSkin.ice:
        return const Color(0xFF88DDFF);
      case BallSkin.galaxy:
        return const Color(0xFFAA44FF);
      case BallSkin.electric:
        return const Color(0xFFFFFF00);
    }
  }

  Color get secondaryColor {
    switch (this) {
      case BallSkin.neon:
        return GameColors.neonPurple;
      case BallSkin.fire:
        return const Color(0xFFFFAA00);
      case BallSkin.ice:
        return const Color(0xFFCCEEFF);
      case BallSkin.galaxy:
        return const Color(0xFF5500AA);
      case BallSkin.electric:
        return const Color(0xFF88FF00);
    }
  }

  int get requiredScore {
    switch (this) {
      case BallSkin.neon:
        return 0;
      case BallSkin.fire:
        return 20;
      case BallSkin.ice:
        return 50;
      case BallSkin.galaxy:
        return 100;
      case BallSkin.electric:
        return 200;
    }
  }
}
