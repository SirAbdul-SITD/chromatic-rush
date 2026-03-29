import 'dart:math';
import 'package:flutter/material.dart';
import '../game/game_controller.dart';
import '../models/obstacle_data.dart';
import '../utils/game_constants.dart';

class GamePainter extends CustomPainter {
  final GameController controller;
  final double animValue;

  GamePainter({required this.controller, required this.animValue});

  @override
  void paint(Canvas canvas, Size size) {
    _drawBackground(canvas, size);
    _drawLaneGuides(canvas, size);
    _drawObstacles(canvas, size);
    _drawBallTrail(canvas, size);
    _drawBall(canvas, size);
  }

  void _drawBackground(Canvas canvas, Size size) {
    final bgPaint = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [Color(0xFF050510), Color(0xFF080820), Color(0xFF050510)],
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height));
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), bgPaint);

    // Scrolling grid
    final gridPaint = Paint()
      ..color = GameColors.neonBlue.withOpacity(0.04)
      ..strokeWidth = 1;
    const gridSpacing = 40.0;
    final scrollOffset = controller.worldOffset % gridSpacing;
    for (double y = -(scrollOffset % gridSpacing); y < size.height; y += gridSpacing) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), gridPaint);
    }
    for (double x = 0; x < size.width; x += gridSpacing) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), gridPaint);
    }
  }

  void _drawLaneGuides(Canvas canvas, Size size) {
    final lanePositions = [
      size.width * GameConstants.leftLaneFraction,
      size.width * GameConstants.centerLaneFraction,
      size.width * GameConstants.rightLaneFraction,
    ];
    final paint = Paint()
      ..color = Colors.white.withOpacity(0.04)
      ..strokeWidth = 1;
    const dashH = 20.0, gapH = 15.0;
    for (final x in lanePositions) {
      final offset = controller.worldOffset % (dashH + gapH);
      double y = -offset;
      while (y < size.height) {
        canvas.drawLine(Offset(x, y), Offset(x, y + dashH), paint);
        y += dashH + gapH;
      }
    }
  }

  void _drawObstacles(Canvas canvas, Size size) {
    for (final obs in controller.obstacles) {
      if (obs.passed) continue;
      final screenY = controller.obstacleScreenY(obs);
      if (screenY < -150 || screenY > size.height + 150) continue;
      switch (obs.type) {
        case ObstacleType.colorGate:
          _drawColorGate(canvas, size, obs, screenY);
          break;
        case ObstacleType.rotatingBar:
          _drawRotatingBar(canvas, size, obs, screenY);
          break;
        case ObstacleType.movingWall:
          _drawMovingWall(canvas, size, obs, screenY);
          break;
        case ObstacleType.splitRing:
          _drawSplitRing(canvas, size, obs, screenY);
          break;
        case ObstacleType.colorChangeGate:
          _drawColorChangeGate(canvas, size, obs, screenY);
          break;
      }
    }
  }

  void _drawColorGate(Canvas canvas, Size size, ObstacleData obs, double sy) {
    final lanes = [
      size.width * GameConstants.leftLaneFraction,
      size.width * GameConstants.centerLaneFraction,
      size.width * GameConstants.rightLaneFraction,
    ];
    for (int i = 0; i < 3; i++) {
      final color = obs.laneColors[i];
      final cx = lanes[i];
      final rect = RRect.fromRectAndRadius(
        Rect.fromCenter(center: Offset(cx, sy), width: GameConstants.gateWidth, height: GameConstants.obstacleHeight),
        const Radius.circular(12),
      );
      canvas.drawRRect(rect, Paint()..color = color.withOpacity(0.3)..maskFilter = const MaskFilter.blur(BlurStyle.normal, 12));
      canvas.drawRRect(rect, Paint()..color = color.withOpacity(0.2));
      canvas.drawRRect(rect, Paint()..color = color..style = PaintingStyle.stroke..strokeWidth = 2.5);
      canvas.drawCircle(Offset(cx, sy), 5, Paint()..color = color.withOpacity(0.9)..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4));
    }
    canvas.drawLine(Offset(lanes[0], sy), Offset(lanes[2], sy), Paint()..color = Colors.white.withOpacity(0.05)..strokeWidth = 1.5);
  }

  void _drawRotatingBar(Canvas canvas, Size size, ObstacleData obs, double sy) {
    canvas.save();
    canvas.translate(size.width / 2, sy);
    canvas.rotate(obs.rotationAngle);
    const barLength = 120.0, barWidth = 14.0;
    for (int i = 0; i < 3; i++) {
      final angle = (i / 3) * pi * 2;
      final color = obs.laneColors[i];
      canvas.drawLine(
        Offset(cos(angle) * 20, sin(angle) * 20),
        Offset(cos(angle) * barLength, sin(angle) * barLength),
        Paint()..color = color.withOpacity(0.4)..strokeWidth = barWidth + 8..strokeCap = StrokeCap.round..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8),
      );
      canvas.drawLine(
        Offset(cos(angle) * 20, sin(angle) * 20),
        Offset(cos(angle) * barLength, sin(angle) * barLength),
        Paint()..color = color..strokeWidth = barWidth..strokeCap = StrokeCap.round,
      );
    }
    canvas.drawCircle(Offset.zero, 10, Paint()..color = Colors.white);
    canvas.restore();
  }

  void _drawMovingWall(Canvas canvas, Size size, ObstacleData obs, double sy) {
    final color = obs.laneColors[obs.correctLane];
    final gapCX = size.width * GameConstants.centerLaneFraction + obs.wallOffset;
    const gapW = 70.0, wallH = 20.0;
    if (gapCX - gapW / 2 > 0) _wallSeg(canvas, 0, gapCX - gapW / 2, sy, wallH, color);
    if (gapCX + gapW / 2 < size.width) _wallSeg(canvas, gapCX + gapW / 2, size.width, sy, wallH, color);
    canvas.drawRect(
      Rect.fromCenter(center: Offset(gapCX, sy), width: gapW, height: wallH + 8),
      Paint()..color = color.withOpacity(0.35)..maskFilter = const MaskFilter.blur(BlurStyle.normal, 10),
    );
  }

  void _wallSeg(Canvas canvas, double x1, double x2, double y, double h, Color c) {
    final r = Rect.fromLTRB(x1, y - h / 2, x2, y + h / 2);
    canvas.drawRect(r, Paint()..color = c.withOpacity(0.3)..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8));
    canvas.drawRect(r, Paint()..color = c.withOpacity(0.35));
    canvas.drawRect(r, Paint()..color = c..style = PaintingStyle.stroke..strokeWidth = 2);
  }

  void _drawSplitRing(Canvas canvas, Size size, ObstacleData obs, double sy) {
    canvas.save();
    canvas.translate(size.width / 2, sy);
    canvas.rotate(obs.rotationAngle * 0.7);
    const radius = 55.0, gapAngle = 0.4;
    for (int i = 0; i < 3; i++) {
      final color = obs.laneColors[i];
      final startAngle = (i / 3) * pi * 2 + gapAngle / 2;
      final sweepAngle = pi * 2 / 3 - gapAngle;
      canvas.drawArc(Rect.fromCircle(center: Offset.zero, radius: radius), startAngle, sweepAngle, false,
          Paint()..color = color.withOpacity(0.4)..style = PaintingStyle.stroke..strokeWidth = 20..strokeCap = StrokeCap.round..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8));
      canvas.drawArc(Rect.fromCircle(center: Offset.zero, radius: radius), startAngle, sweepAngle, false,
          Paint()..color = color..style = PaintingStyle.stroke..strokeWidth = 12..strokeCap = StrokeCap.round);
    }
    canvas.restore();
  }

  void _drawColorChangeGate(Canvas canvas, Size size, ObstacleData obs, double sy) {
    _drawColorGate(canvas, size, obs, sy);
    final sparkOpacity = 0.15 + 0.1 * sin(animValue * pi * 4);
    final lanes = [
      size.width * GameConstants.leftLaneFraction,
      size.width * GameConstants.centerLaneFraction,
      size.width * GameConstants.rightLaneFraction,
    ];
    for (int i = 0; i < 3; i++) {
      canvas.drawCircle(Offset(lanes[i], sy), 18, Paint()..color = Colors.white.withOpacity(sparkOpacity)..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8));
    }
    final tp = TextPainter(
      text: TextSpan(text: '⚡ SWAP', style: TextStyle(color: Colors.white.withOpacity(0.8), fontSize: 9, fontWeight: FontWeight.bold, letterSpacing: 1)),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, Offset(size.width / 2 - tp.width / 2, sy - 38));
  }

  void _drawBallTrail(Canvas canvas, Size size) {
    final bx = controller.ballScreenX;
    final by = controller.ballScreenY;
    final color = controller.ballColor;
    for (int i = 5; i >= 1; i--) {
      canvas.drawCircle(
        Offset(bx, by + i * 10.0),
        GameConstants.ballRadius * (1 - i * 0.12),
        Paint()..color = color.withOpacity((i / 5) * 0.3)..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6),
      );
    }
  }

  void _drawBall(Canvas canvas, Size size) {
    final bx = controller.ballScreenX;
    final by = controller.ballScreenY;
    final color = controller.ballColor;
    final glowPulse = 0.5 + 0.5 * sin(animValue * pi * 2);

    canvas.drawCircle(Offset(bx, by), GameConstants.ballRadius + 4,
        Paint()..color = color.withOpacity(0.4 + 0.2 * glowPulse)..maskFilter = MaskFilter.blur(BlurStyle.normal, 18 + 8 * glowPulse));

    canvas.drawCircle(
      Offset(bx, by),
      GameConstants.ballRadius,
      Paint()..shader = RadialGradient(
        center: const Alignment(-0.3, -0.3),
        colors: [Colors.white.withOpacity(0.9), color, color.withOpacity(0.6)],
        stops: const [0.05, 0.4, 1.0],
      ).createShader(Rect.fromCircle(center: Offset(bx, by), radius: GameConstants.ballRadius)),
    );

    canvas.drawCircle(
      Offset(bx - GameConstants.ballRadius * 0.3, by - GameConstants.ballRadius * 0.3),
      GameConstants.ballRadius * 0.3,
      Paint()..color = Colors.white.withOpacity(0.6)..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3),
    );
  }

  @override
  bool shouldRepaint(covariant GamePainter oldDelegate) => true;
}
