import 'package:flutter/material.dart';

class GameColors {
  static const Color red    = Color(0xFFFF3366);
  static const Color blue   = Color(0xFF00D4FF);
  static const Color green  = Color(0xFF00FF88);
  static const Color yellow = Color(0xFFFFD700);
  static const Color purple = Color(0xFFBB44FF);
  static const Color orange = Color(0xFFFF8C00);

  static const Color background          = Color(0xFF050510);
  static const Color backgroundSecondary = Color(0xFF0A0A1E);
  static const Color neonBlue   = Color(0xFF00D4FF);
  static const Color neonPurple = Color(0xFF9B59B6);
  static const Color neonGreen  = Color(0xFF00FF88);
  static const Color textPrimary   = Color(0xFFFFFFFF);
  static const Color textSecondary  = Color(0xFFAAAAAA);
  static const Color cardBg = Color(0xFF0D0D2B);

  static const List<Color> gameColors = [red, blue, green, yellow, purple, orange];

  static Color randomGameColor() {
    final copy = [...gameColors]..shuffle();
    return copy.first;
  }

  static Color getGlowColor(Color base) => base.withOpacity(0.6);
}

class GameConstants {
  static const double leftLaneFraction   = 0.2;
  static const double centerLaneFraction = 0.5;
  static const double rightLaneFraction  = 0.8;

  static const double ballRadius          = 20.0;
  static const double ballStartYFraction  = 0.75;

  static const double obstacleHeight  = 120.0;
  static const double obstacleSpacing = 400.0;
  static const double gateWidth       = 64.0;

  static const double phase1Speed = 130.0;
  static const double phase2Speed = 195.0;
  static const double phase3Speed = 275.0;
  static const double phase4Speed = 380.0;

  static const double phase2Time = 30.0;
  static const double phase3Time = 65.0;
  static const double phase4Time = 110.0;

  static const int comboThreshold = 5;
  static const int comboBonus     = 3;

  static const Duration laneSwitchDuration  = Duration(milliseconds: 180);
  static const Duration colorChangeDuration = Duration(milliseconds: 200);
}

enum Lane { left, center, right }

enum ObstacleType { colorGate, rotatingBar, movingWall, splitRing, colorChangeGate }

// 6 skins — neon default, then unlocked every 30 points of best score
enum BallSkin { neon, fire, ice, galaxy, electric, ghostRider }

extension BallSkinExtension on BallSkin {
  String get displayName {
    switch (this) {
      case BallSkin.neon:        return 'Neon';
      case BallSkin.fire:        return 'Fire';
      case BallSkin.ice:         return 'Ice';
      case BallSkin.galaxy:      return 'Galaxy';
      case BallSkin.electric:    return 'Electric';
      case BallSkin.ghostRider:  return 'Ghost Rider';
    }
  }

  String get emoji {
    switch (this) {
      case BallSkin.neon:        return '💎';
      case BallSkin.fire:        return '🔥';
      case BallSkin.ice:         return '❄️';
      case BallSkin.galaxy:      return '🌌';
      case BallSkin.electric:    return '⚡';
      case BallSkin.ghostRider:  return '💀';
    }
  }

  // Primary ball body color
  Color get primaryColor {
    switch (this) {
      case BallSkin.neon:        return GameColors.neonBlue;
      case BallSkin.fire:        return const Color(0xFFFF4500);
      case BallSkin.ice:         return const Color(0xFF88DDFF);
      case BallSkin.galaxy:      return const Color(0xFFAA44FF);
      case BallSkin.electric:    return const Color(0xFFFFFF00);
      case BallSkin.ghostRider:  return const Color(0xFF22FF88);
    }
  }

  // Secondary / glow color
  Color get secondaryColor {
    switch (this) {
      case BallSkin.neon:        return GameColors.neonPurple;
      case BallSkin.fire:        return const Color(0xFFFFAA00);
      case BallSkin.ice:         return const Color(0xFFCCEEFF);
      case BallSkin.galaxy:      return const Color(0xFF5500AA);
      case BallSkin.electric:    return const Color(0xFF88FF00);
      case BallSkin.ghostRider:  return const Color(0xFF00FF44);
    }
  }

  // Trail / effect color
  Color get trailColor {
    switch (this) {
      case BallSkin.neon:        return GameColors.neonBlue;
      case BallSkin.fire:        return const Color(0xFFFF6600);
      case BallSkin.ice:         return const Color(0xFFAAEEFF);
      case BallSkin.galaxy:      return const Color(0xFF9933FF);
      case BallSkin.electric:    return const Color(0xFFFFFF44);
      case BallSkin.ghostRider:  return const Color(0xFF00FF66);
    }
  }

  // Unlock at this best-score milestone (30-point increments)
  int get requiredScore {
    switch (this) {
      case BallSkin.neon:        return 0;
      case BallSkin.fire:        return 50;
      case BallSkin.ice:         return 100;
      case BallSkin.galaxy:      return 150;
      case BallSkin.electric:    return 200;
      case BallSkin.ghostRider:  return 250;
    }
  }
}
