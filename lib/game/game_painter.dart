import 'dart:math';
import 'package:flutter/material.dart';
import '../game/game_controller.dart';
import '../models/obstacle_data.dart';
import '../utils/game_constants.dart';

class GamePainter extends CustomPainter {
  final GameController controller;
  final double animValue; // 0..1 looping

  GamePainter({required this.controller, required this.animValue});

  @override
  void paint(Canvas canvas, Size size) {
    // Screen shake offset on game over / hit
    final shake = controller.shakeAmount;
    Offset shakeOffset = Offset.zero;
    if (shake > 0) {
      final r = Random(DateTime.now().millisecondsSinceEpoch);
      shakeOffset = Offset(
        (r.nextDouble() - 0.5) * shake,
        (r.nextDouble() - 0.5) * shake,
      );
    }

    canvas.save();
    canvas.translate(shakeOffset.dx, shakeOffset.dy);

    _drawBackground(canvas, size);
    _drawLaneGuides(canvas, size);
    _drawObstacles(canvas, size);
    _drawTileEffects(canvas, size);
    _drawBallTrail(canvas, size);
    _drawBall(canvas, size);
    _drawBallColorRing(canvas, size);

    canvas.restore();
  }

  // ── Helpers ────────────────────────────────────────────────
  List<double> _laneXs(Size size) => [
        size.width * GameConstants.leftLaneFraction,
        size.width * GameConstants.centerLaneFraction,
        size.width * GameConstants.rightLaneFraction,
      ];

  // ── Background ────────────────────────────────────────────
  void _drawBackground(Canvas canvas, Size size) {
    canvas.drawRect(
      Rect.fromLTWH(0, 0, size.width, size.height),
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF050510), Color(0xFF070720), Color(0xFF050510)],
        ).createShader(Rect.fromLTWH(0, 0, size.width, size.height)),
    );

    final gp = Paint()..color = GameColors.neonBlue.withOpacity(0.038)..strokeWidth = 1;
    const gs = 40.0;
    final so = controller.worldOffset % gs;
    for (double y = -(so % gs); y < size.height; y += gs) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), gp);
    }
    for (double x = 0; x < size.width; x += gs) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), gp);
    }
  }

  // ── Lane guides ───────────────────────────────────────────
  void _drawLaneGuides(Canvas canvas, Size size) {
    final lx = _laneXs(size);
    final p = Paint()..color = Colors.white.withOpacity(0.04)..strokeWidth = 1;
    const dh = 22.0, gh = 14.0;
    for (final x in lx) {
      final off = controller.worldOffset % (dh + gh);
      double y = -off;
      while (y < size.height) {
        canvas.drawLine(Offset(x, y), Offset(x, y + dh), p);
        y += dh + gh;
      }
    }
  }

  // ── Obstacles ─────────────────────────────────────────────
  void _drawObstacles(Canvas canvas, Size size) {
    final lx = _laneXs(size);
    for (final obs in controller.obstacles) {
      final sy = controller.obstacleScreenY(obs);
      if (sy < -250 || sy > size.height + 250) continue;

      // Draw tile if not yet passed OR if hit animation still playing
      if (!obs.passed || obs.hitAge < 1.0) {
        switch (obs.type) {
          case ObstacleType.colorGate:
            _drawColorGate(canvas, lx, obs, sy);
            break;
          case ObstacleType.colorChangeGate:
            _drawColorGate(canvas, lx, obs, sy, isSwap: true);
            break;
          case ObstacleType.rotatingBar:
            _drawRotatingBar(canvas, size, obs, sy);
            break;
          case ObstacleType.movingWall:
            _drawMovingWall(canvas, size, lx, obs, sy);
            break;
          case ObstacleType.splitRing:
            _drawSplitRing(canvas, size, obs, sy);
            break;
        }
      }

      if (obs.hitSuccess && obs.hitAge < 1.0) _drawSuccessEffect(canvas, lx, obs, sy);
      if (obs.hitFail && obs.hitAge < 1.0)    _drawFailEffect(canvas, lx, obs, sy);
    }
  }

  // ── Color Gate ────────────────────────────────────────────
  void _drawColorGate(Canvas canvas, List<double> lx, ObstacleData obs, double sy, {bool isSwap = false}) {
    const h = GameConstants.obstacleHeight;
    const w = GameConstants.gateWidth;

    for (int i = 0; i < 3; i++) {
      final c = obs.laneColors[i];
      final cx = lx[i];
      final rect = RRect.fromRectAndRadius(
        Rect.fromCenter(center: Offset(cx, sy), width: w, height: h),
        const Radius.circular(14),
      );
      canvas.drawRRect(rect, Paint()..color = c.withOpacity(0.28)..maskFilter = const MaskFilter.blur(BlurStyle.normal, 14));
      canvas.drawRRect(rect, Paint()..color = c.withOpacity(0.16));
      canvas.drawRRect(rect, Paint()..color = c..style = PaintingStyle.stroke..strokeWidth = 2.5);
      canvas.drawCircle(Offset(cx, sy), 5, Paint()..color = c..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4));
    }
    canvas.drawLine(Offset(lx[0], sy), Offset(lx[2], sy),
        Paint()..color = Colors.white.withOpacity(0.05)..strokeWidth = 1.5);

    if (isSwap) {
      final so = 0.12 + 0.09 * sin(animValue * pi * 4);
      for (int i = 0; i < 3; i++) {
        canvas.drawCircle(Offset(lx[i], sy), 24,
            Paint()..color = Colors.white.withOpacity(so)..maskFilter = const MaskFilter.blur(BlurStyle.normal, 10));
      }
      final tp = TextPainter(
        text: TextSpan(
          text: '⚡ COLOR SWAP',
          style: TextStyle(color: Colors.white.withOpacity(0.8), fontSize: 9, fontWeight: FontWeight.bold, letterSpacing: 1.5),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, Offset(lx[1] - tp.width / 2, sy - h / 2 - 18));
    }
  }

  // ── Rotating Bar ──────────────────────────────────────────
  void _drawRotatingBar(Canvas canvas, Size size, ObstacleData obs, double sy) {
    canvas.save();
    canvas.translate(size.width / 2, sy);
    canvas.rotate(obs.rotationAngle);
    const len = 130.0, bw = 14.0;
    for (int i = 0; i < 3; i++) {
      final angle = (i / 3) * pi * 2;
      final c = obs.laneColors[i];
      final p1 = Offset(cos(angle) * 18, sin(angle) * 18);
      final p2 = Offset(cos(angle) * len, sin(angle) * len);
      canvas.drawLine(p1, p2, Paint()..color = c.withOpacity(0.4)..strokeWidth = bw + 10..strokeCap = StrokeCap.round..maskFilter = const MaskFilter.blur(BlurStyle.normal, 10));
      canvas.drawLine(p1, p2, Paint()..color = c..strokeWidth = bw..strokeCap = StrokeCap.round);
    }
    canvas.drawCircle(Offset.zero, 11, Paint()..color = Colors.white);
    canvas.drawCircle(Offset.zero, 6,  Paint()..color = const Color(0xFF050510));
    canvas.restore();
  }

  // ── Moving Wall ───────────────────────────────────────────
  // Gap is at lx[obs.wallLane] — exactly matches collision system
  void _drawMovingWall(Canvas canvas, Size size, List<double> lx, ObstacleData obs, double sy) {
    final gapLane = obs.wallLane;
    final gapCX   = lx[gapLane];
    final gapColor = obs.laneColors[gapLane];
    const gapW = GameConstants.gateWidth + 12.0;
    const h    = GameConstants.obstacleHeight;

    final leftWallEnd   = gapCX - gapW / 2;
    final rightWallStart = gapCX + gapW / 2;

    // Left wall
    if (leftWallEnd > 0) {
      _wallSeg(canvas, 0, leftWallEnd, sy, h, gapColor);
    }
    // Right wall
    if (rightWallStart < size.width) {
      _wallSeg(canvas, rightWallStart, size.width, sy, h, gapColor);
    }

    // Gap glow + border to make opening obvious
    final gapRect = RRect.fromRectAndRadius(
      Rect.fromCenter(center: Offset(gapCX, sy), width: gapW, height: h),
      const Radius.circular(14),
    );
    canvas.drawRRect(gapRect,
        Paint()..color = gapColor.withOpacity(0.22)..maskFilter = const MaskFilter.blur(BlurStyle.normal, 14));
    canvas.drawRRect(gapRect,
        Paint()..color = gapColor.withOpacity(0.55)..style = PaintingStyle.stroke..strokeWidth = 2);

    // Animated arrow chevron above gap
    final chevronY = sy - h / 2 - 18;
    final bounce = sin(animValue * pi * 4) * 4;
    final ap = Paint()..color = gapColor.withOpacity(0.8)..strokeWidth = 2.5..strokeCap = StrokeCap.round;
    canvas.drawLine(Offset(gapCX - 11, chevronY - 5 + bounce), Offset(gapCX, chevronY + 3 + bounce), ap);
    canvas.drawLine(Offset(gapCX + 11, chevronY - 5 + bounce), Offset(gapCX, chevronY + 3 + bounce), ap);
  }

  void _wallSeg(Canvas canvas, double x1, double x2, double cy, double h, Color c) {
    if (x2 <= x1) return;
    final rect = Rect.fromLTRB(x1, cy - h / 2, x2, cy + h / 2);
    canvas.drawRect(rect, Paint()..color = c.withOpacity(0.26)..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8));
    canvas.drawRect(rect, Paint()..color = c.withOpacity(0.32));
    canvas.drawRect(rect, Paint()..color = c..style = PaintingStyle.stroke..strokeWidth = 2);
  }

  // ── Split Ring ────────────────────────────────────────────
  void _drawSplitRing(Canvas canvas, Size size, ObstacleData obs, double sy) {
    canvas.save();
    canvas.translate(size.width / 2, sy);
    canvas.rotate(obs.rotationAngle * 0.65);
    const radius = 60.0, gapAngle = 0.38;
    for (int i = 0; i < 3; i++) {
      final c = obs.laneColors[i];
      final start = (i / 3) * pi * 2 + gapAngle / 2;
      final sweep = pi * 2 / 3 - gapAngle;
      canvas.drawArc(Rect.fromCircle(center: Offset.zero, radius: radius), start, sweep, false,
          Paint()..color = c.withOpacity(0.4)..style = PaintingStyle.stroke..strokeWidth = 22..strokeCap = StrokeCap.round..maskFilter = const MaskFilter.blur(BlurStyle.normal, 10));
      canvas.drawArc(Rect.fromCircle(center: Offset.zero, radius: radius), start, sweep, false,
          Paint()..color = c..style = PaintingStyle.stroke..strokeWidth = 13..strokeCap = StrokeCap.round);
    }
    canvas.restore();
  }

  // ── Success effect ────────────────────────────────────────
  void _drawSuccessEffect(Canvas canvas, List<double> lx, ObstacleData obs, double sy) {
    final t = obs.hitAge;
    final cx = lx[obs.hitLane.clamp(0, 2)];
    final c = obs.matchColor;

    // Expanding ring
    canvas.drawCircle(Offset(cx, sy), 18 + 52 * t,
        Paint()..color = c.withOpacity((1 - t) * 0.85)..style = PaintingStyle.stroke..strokeWidth = 3.5 * (1 - t)
          ..maskFilter = MaskFilter.blur(BlurStyle.normal, 9 * (1 - t)));
    if (t > 0.12) {
      final t2 = (t - 0.12) / 0.88;
      canvas.drawCircle(Offset(cx, sy), 12 + 32 * t2,
          Paint()..color = Colors.white.withOpacity((1 - t2) * 0.45)..style = PaintingStyle.stroke..strokeWidth = 2);
    }

    // White flash
    if (t < 0.3) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromCenter(center: Offset(cx, sy), width: GameConstants.gateWidth, height: GameConstants.obstacleHeight),
          const Radius.circular(14),
        ),
        Paint()..color = Colors.white.withOpacity((0.3 - t) / 0.3 * 0.45),
      );
    }

    // 8 sparkle dots fanning out
    for (int d = 0; d < 8; d++) {
      final angle = (d / 8) * pi * 2;
      final dist = 38 * t;
      canvas.drawCircle(
        Offset(cx + cos(angle) * dist, sy + sin(angle) * dist),
        4.5 * (1 - t),
        Paint()..color = c.withOpacity((1 - t) * 0.95),
      );
    }
  }

  // ── Fail effect ───────────────────────────────────────────
  void _drawFailEffect(Canvas canvas, List<double> lx, ObstacleData obs, double sy) {
    final t = obs.hitAge;
    final cx = lx[obs.hitLane.clamp(0, 2)];

    canvas.drawCircle(Offset(cx, sy), 14 + 65 * t,
        Paint()..color = GameColors.red.withOpacity((1 - t) * 0.9)..style = PaintingStyle.stroke..strokeWidth = 4.5 * (1 - t)
          ..maskFilter = MaskFilter.blur(BlurStyle.normal, 14 * (1 - t)));

    if (t < 0.65) {
      final o = (0.65 - t) / 0.65;
      final len = 32.0 * min(t * 5, 1.0);
      final cp = Paint()..color = GameColors.red.withOpacity(o)..strokeWidth = 3.5..strokeCap = StrokeCap.round;
      canvas.drawLine(Offset(cx - len, sy - len), Offset(cx + len, sy + len), cp);
      canvas.drawLine(Offset(cx + len, sy - len), Offset(cx - len, sy + len), cp);
    }

    if (t < 0.25) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromCenter(center: Offset(cx, sy), width: GameConstants.gateWidth, height: GameConstants.obstacleHeight),
          const Radius.circular(14),
        ),
        Paint()..color = GameColors.red.withOpacity((0.25 - t) / 0.25 * 0.55),
      );
    }
  }

  // ── Floating effects ──────────────────────────────────────
  void _drawTileEffects(Canvas canvas, Size size) {
    for (final e in controller.tileEffects) {
      final t = e.age;
      if (e.isSuccess) {
        canvas.drawCircle(
          Offset(e.x, e.y - 48 * t),
          9 * (1 - t * 0.5),
          Paint()..color = e.color.withOpacity((1 - t).clamp(0.0, 1.0) * 0.7)..maskFilter = const MaskFilter.blur(BlurStyle.normal, 7),
        );
      } else {
        canvas.drawCircle(
          Offset(e.x, e.y),
          70 * t,
          Paint()..color = GameColors.red.withOpacity((1 - t) * 0.28)..style = PaintingStyle.stroke..strokeWidth = 2.5,
        );
      }
    }
  }

  // ── Ball trail ────────────────────────────────────────────
  void _drawBallTrail(Canvas canvas, Size size) {
    final bx = controller.ballScreenX;
    final by = controller.ballScreenY;
    final c  = controller.ballColor;
    // Longer trail in hyper mode
    final trailLen = controller.currentPhase >= 4 ? 10 : 6;
    for (int i = trailLen; i >= 1; i--) {
      canvas.drawCircle(
        Offset(bx, by + i * 8.5),
        GameConstants.ballRadius * (1 - i / (trailLen + 1)),
        Paint()..color = c.withOpacity((i / trailLen) * 0.3)..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6),
      );
    }
  }

  // ── Ball ──────────────────────────────────────────────────
  void _drawBall(Canvas canvas, Size size) {
    final bx = controller.ballScreenX;
    final by = controller.ballScreenY;
    final c  = controller.ballColor;
    final gp = 0.5 + 0.5 * sin(animValue * pi * 2);

    canvas.drawCircle(Offset(bx, by), GameConstants.ballRadius + 5,
        Paint()..color = c.withOpacity(0.35 + 0.2 * gp)..maskFilter = MaskFilter.blur(BlurStyle.normal, 20 + 8 * gp));

    canvas.drawCircle(Offset(bx, by), GameConstants.ballRadius,
        Paint()..shader = RadialGradient(
          center: const Alignment(-0.3, -0.4),
          colors: [Colors.white.withOpacity(0.95), c, c.withOpacity(0.5)],
          stops: const [0.04, 0.42, 1.0],
        ).createShader(Rect.fromCircle(center: Offset(bx, by), radius: GameConstants.ballRadius)));

    canvas.drawCircle(
      Offset(bx - GameConstants.ballRadius * 0.28, by - GameConstants.ballRadius * 0.3),
      GameConstants.ballRadius * 0.27,
      Paint()..color = Colors.white.withOpacity(0.65)..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3),
    );
  }

  // ── Ball color ring indicator at bottom ───────────────────
  // Subtle glowing ring showing current ball color — always visible
  void _drawBallColorRing(Canvas canvas, Size size) {
    final bx = controller.ballScreenX;
    final by = controller.ballScreenY;
    final c  = controller.ballColor;
    final pulse = 0.5 + 0.5 * sin(animValue * pi * 2);

    // Orbit ring around ball
    canvas.drawCircle(
      Offset(bx, by),
      GameConstants.ballRadius + 9 + 2 * pulse,
      Paint()
        ..color = c.withOpacity(0.25 + 0.15 * pulse)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5,
    );

    // Color label at very bottom of screen
    final labelY = size.height - 28.0;
    final tp = TextPainter(
      text: TextSpan(
        text: '● YOUR COLOR',
        style: TextStyle(
          color: c.withOpacity(0.55),
          fontSize: 9,
          fontWeight: FontWeight.w700,
          letterSpacing: 2,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, Offset(size.width / 2 - tp.width / 2, labelY));

    // Small color swatch
    canvas.drawCircle(
      Offset(size.width / 2 - tp.width / 2 - 10, labelY + 5),
      4.5,
      Paint()..color = c..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5),
    );
  }

  @override
  bool shouldRepaint(covariant GamePainter old) => true;
}
