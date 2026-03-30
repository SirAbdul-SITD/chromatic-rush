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
    final shake = controller.shakeAmount;
    if (shake > 0) {
      final r = Random(DateTime.now().millisecondsSinceEpoch);
      canvas.save();
      canvas.translate(
        (r.nextDouble() - 0.5) * shake,
        (r.nextDouble() - 0.5) * shake,
      );
    }

    _drawBackground(canvas, size);
    _drawLaneGuides(canvas, size);
    _drawObstacles(canvas, size);
    _drawTileEffects(canvas, size);
    _drawSkinTrail(canvas, size);  // skin-specific trail
    _drawBall(canvas, size);
    _drawSkinEffect(canvas, size); // skin overlay effect on ball
    _drawBallColorRing(canvas, size);

    if (shake > 0) canvas.restore();
  }

  List<double> _laneXs(Size size) => [
        size.width * GameConstants.leftLaneFraction,
        size.width * GameConstants.centerLaneFraction,
        size.width * GameConstants.rightLaneFraction,
      ];

  // ── Background ─────────────────────────────────────────────
  void _drawBackground(Canvas canvas, Size size) {
    canvas.drawRect(
      Rect.fromLTWH(0, 0, size.width, size.height),
      Paint()..shader = const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [Color(0xFF050510), Color(0xFF07071E), Color(0xFF050510)],
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

  // ── Lane guides ────────────────────────────────────────────
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

  // ── Obstacles ──────────────────────────────────────────────
  void _drawObstacles(Canvas canvas, Size size) {
    final lx = _laneXs(size);
    for (final obs in controller.obstacles) {
      final sy = controller.obstacleScreenY(obs);
      if (sy < -250 || sy > size.height + 250) continue;

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
      if (obs.hitFail    && obs.hitAge < 1.0) _drawFailEffect(canvas, lx, obs, sy);
    }
  }

  void _drawColorGate(Canvas canvas, List<double> lx, ObstacleData obs, double sy, {bool isSwap = false}) {
    const h = GameConstants.obstacleHeight, w = GameConstants.gateWidth;
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

  void _drawMovingWall(Canvas canvas, Size size, List<double> lx, ObstacleData obs, double sy) {
    final gapLane  = obs.wallLane;
    final gapCX    = lx[gapLane];
    final gapColor = obs.laneColors[gapLane];
    const gapW = GameConstants.gateWidth + 12.0;
    const h    = GameConstants.obstacleHeight;

    final leftEnd    = gapCX - gapW / 2;
    final rightStart = gapCX + gapW / 2;

    if (leftEnd > 0)           _wallSeg(canvas, 0, leftEnd, sy, h, gapColor);
    if (rightStart < size.width) _wallSeg(canvas, rightStart, size.width, sy, h, gapColor);

    final gapRect = RRect.fromRectAndRadius(
      Rect.fromCenter(center: Offset(gapCX, sy), width: gapW, height: h),
      const Radius.circular(14),
    );
    canvas.drawRRect(gapRect, Paint()..color = gapColor.withOpacity(0.22)..maskFilter = const MaskFilter.blur(BlurStyle.normal, 14));
    canvas.drawRRect(gapRect, Paint()..color = gapColor.withOpacity(0.55)..style = PaintingStyle.stroke..strokeWidth = 2);

    // Bouncing chevron
    final chevY = sy - h / 2 - 18;
    final bounce = sin(animValue * pi * 4) * 4;
    final ap = Paint()..color = gapColor.withOpacity(0.8)..strokeWidth = 2.5..strokeCap = StrokeCap.round;
    canvas.drawLine(Offset(gapCX - 11, chevY - 5 + bounce), Offset(gapCX, chevY + 3 + bounce), ap);
    canvas.drawLine(Offset(gapCX + 11, chevY - 5 + bounce), Offset(gapCX, chevY + 3 + bounce), ap);

    // FROZEN indicator — shows lock icon when wall is frozen
    if (obs.wallFrozen) {
      final tp = TextPainter(
        text: TextSpan(
          text: '🔒 LOCKED',
          style: TextStyle(color: gapColor.withOpacity(0.7), fontSize: 9, fontWeight: FontWeight.bold, letterSpacing: 1),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, Offset(gapCX - tp.width / 2, sy + h / 2 + 6));
    }
  }

  void _wallSeg(Canvas canvas, double x1, double x2, double cy, double h, Color c) {
    if (x2 <= x1) return;
    final rect = Rect.fromLTRB(x1, cy - h / 2, x2, cy + h / 2);
    canvas.drawRect(rect, Paint()..color = c.withOpacity(0.25)..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8));
    canvas.drawRect(rect, Paint()..color = c.withOpacity(0.32));
    canvas.drawRect(rect, Paint()..color = c..style = PaintingStyle.stroke..strokeWidth = 2);
  }

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

  // ── Hit animations ─────────────────────────────────────────
  void _drawSuccessEffect(Canvas canvas, List<double> lx, ObstacleData obs, double sy) {
    final t = obs.hitAge;
    final cx = lx[obs.hitLane.clamp(0, 2)];
    final c = obs.matchColor;

    canvas.drawCircle(Offset(cx, sy), 18 + 52 * t,
        Paint()..color = c.withOpacity((1 - t) * 0.85)..style = PaintingStyle.stroke..strokeWidth = 3.5 * (1 - t)
          ..maskFilter = MaskFilter.blur(BlurStyle.normal, 9 * (1 - t)));
    if (t > 0.12) {
      final t2 = (t - 0.12) / 0.88;
      canvas.drawCircle(Offset(cx, sy), 12 + 32 * t2,
          Paint()..color = Colors.white.withOpacity((1 - t2) * 0.45)..style = PaintingStyle.stroke..strokeWidth = 2);
    }
    if (t < 0.3) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(Rect.fromCenter(center: Offset(cx, sy), width: GameConstants.gateWidth, height: GameConstants.obstacleHeight), const Radius.circular(14)),
        Paint()..color = Colors.white.withOpacity((0.3 - t) / 0.3 * 0.45),
      );
    }
    for (int d = 0; d < 8; d++) {
      final angle = (d / 8) * pi * 2;
      canvas.drawCircle(Offset(cx + cos(angle) * 38 * t, sy + sin(angle) * 38 * t), 4.5 * (1 - t),
          Paint()..color = c.withOpacity((1 - t) * 0.95));
    }
  }

  void _drawFailEffect(Canvas canvas, List<double> lx, ObstacleData obs, double sy) {
    final t = obs.hitAge;
    final cx = lx[obs.hitLane.clamp(0, 2)];
    canvas.drawCircle(Offset(cx, sy), 14 + 65 * t,
        Paint()..color = GameColors.red.withOpacity((1 - t) * 0.9)..style = PaintingStyle.stroke..strokeWidth = 4.5 * (1 - t)
          ..maskFilter = MaskFilter.blur(BlurStyle.normal, 14 * (1 - t)));
    if (t < 0.65) {
      final len = 32.0 * min(t * 5, 1.0);
      final cp = Paint()..color = GameColors.red.withOpacity((0.65 - t) / 0.65)..strokeWidth = 3.5..strokeCap = StrokeCap.round;
      canvas.drawLine(Offset(cx - len, sy - len), Offset(cx + len, sy + len), cp);
      canvas.drawLine(Offset(cx + len, sy - len), Offset(cx - len, sy + len), cp);
    }
    if (t < 0.25) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(Rect.fromCenter(center: Offset(cx, sy), width: GameConstants.gateWidth, height: GameConstants.obstacleHeight), const Radius.circular(14)),
        Paint()..color = GameColors.red.withOpacity((0.25 - t) / 0.25 * 0.55),
      );
    }
  }

  void _drawTileEffects(Canvas canvas, Size size) {
    for (final e in controller.tileEffects) {
      final t = e.age;
      if (e.isSuccess) {
        canvas.drawCircle(Offset(e.x, e.y - 48 * t), 9 * (1 - t * 0.5),
            Paint()..color = e.color.withOpacity((1 - t).clamp(0.0, 1.0) * 0.7)..maskFilter = const MaskFilter.blur(BlurStyle.normal, 7));
      } else {
        canvas.drawCircle(Offset(e.x, e.y), 70 * t,
            Paint()..color = GameColors.red.withOpacity((1 - t) * 0.28)..style = PaintingStyle.stroke..strokeWidth = 2.5);
      }
    }
  }

  // ── Skin-specific trail ────────────────────────────────────
  void _drawSkinTrail(Canvas canvas, Size size) {
    final bx = controller.ballScreenX;
    final by = controller.ballScreenY;
    final skin = controller.activeSkin;
    final trailLen = controller.currentPhase >= 4 ? 12 : 8;

    switch (skin) {
      case BallSkin.fire:
        _drawFireTrail(canvas, bx, by, trailLen);
        break;
      case BallSkin.ice:
        _drawIceTrail(canvas, bx, by, trailLen);
        break;
      case BallSkin.galaxy:
        _drawGalaxyTrail(canvas, bx, by, trailLen);
        break;
      case BallSkin.electric:
        _drawElectricTrail(canvas, bx, by, trailLen);
        break;
      case BallSkin.ghostRider:
        _drawGhostTrail(canvas, bx, by, trailLen);
        break;
      default:
        _drawDefaultTrail(canvas, bx, by, skin.primaryColor, trailLen);
    }
  }

  void _drawDefaultTrail(Canvas canvas, double bx, double by, Color c, int len) {
    for (int i = len; i >= 1; i--) {
      canvas.drawCircle(Offset(bx, by + i * 8.5), GameConstants.ballRadius * (1 - i / (len + 1)),
          Paint()..color = c.withOpacity((i / len) * 0.3)..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6));
    }
  }

  void _drawFireTrail(Canvas canvas, double bx, double by, int len) {
    final rng = Random(42);
    for (int i = len; i >= 1; i--) {
      final jitter = (rng.nextDouble() - 0.5) * 8 * (i / len);
      final radius = GameConstants.ballRadius * (1 - i / (len + 2)) * 1.2;
      final t = i / len;
      final c = Color.lerp(const Color(0xFFFFFF00), const Color(0xFFFF4500), t)!;
      canvas.drawCircle(Offset(bx + jitter, by + i * 9.0), radius,
          Paint()..color = c.withOpacity(t * 0.55)..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8));
    }
  }

  void _drawIceTrail(Canvas canvas, double bx, double by, int len) {
    for (int i = len; i >= 1; i--) {
      final t = i / len;
      canvas.drawCircle(Offset(bx, by + i * 8.5), GameConstants.ballRadius * (1 - i / (len + 1)),
          Paint()..color = const Color(0xFF88DDFF).withOpacity(t * 0.35)..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5));
    }
    // Ice crystal shards scattered behind
    final rng = Random(DateTime.now().millisecond ~/ 100);
    for (int i = 0; i < 5; i++) {
      final dy = (i + 1) * 14.0;
      final dx = (rng.nextDouble() - 0.5) * 14;
      final path = Path();
      const s = 4.0;
      path.moveTo(bx + dx, by + dy - s);
      path.lineTo(bx + dx + s * 0.5, by + dy);
      path.lineTo(bx + dx, by + dy + s);
      path.lineTo(bx + dx - s * 0.5, by + dy);
      path.close();
      canvas.drawPath(path, Paint()..color = Colors.white.withOpacity(0.4 * (1 - i / 5)));
    }
  }

  void _drawGalaxyTrail(Canvas canvas, double bx, double by, int len) {
    // Purple nebula trail + star dots
    for (int i = len; i >= 1; i--) {
      final t = i / len;
      final c = Color.lerp(const Color(0xFFAA44FF), const Color(0xFF220044), t)!;
      canvas.drawCircle(Offset(bx, by + i * 9.0), GameConstants.ballRadius * (1 - i / (len + 1)) * 1.1,
          Paint()..color = c.withOpacity(t * 0.45)..maskFilter = const MaskFilter.blur(BlurStyle.normal, 9));
    }
    // Star dots
    final rng = Random(animValue.toInt());
    for (int s = 0; s < 6; s++) {
      final dx = (rng.nextDouble() - 0.5) * 30;
      final dy = rng.nextDouble() * 80 + 5;
      canvas.drawCircle(Offset(bx + dx, by + dy), 1.5 + rng.nextDouble() * 2,
          Paint()..color = Colors.white.withOpacity(0.6 * rng.nextDouble()));
    }
  }

  void _drawElectricTrail(Canvas canvas, double bx, double by, int len) {
    // Default yellow trail
    _drawDefaultTrail(canvas, bx, by, const Color(0xFFFFFF00), len);
    // Zigzag lightning bolt behind ball
    if (animValue % 0.1 < 0.05) { // flicker
      final paint = Paint()
        ..color = const Color(0xFFFFFF88).withOpacity(0.7)
        ..strokeWidth = 2
        ..strokeCap = StrokeCap.round
        ..style = PaintingStyle.stroke;
      final path = Path();
      path.moveTo(bx, by + 10);
      path.lineTo(bx - 8, by + 25);
      path.lineTo(bx + 5, by + 25);
      path.lineTo(bx - 6, by + 50);
      canvas.drawPath(path, paint);
    }
  }

  void _drawGhostTrail(Canvas canvas, double bx, double by, int len) {
    // Ethereal green smoke
    for (int i = len; i >= 1; i--) {
      final t = i / len;
      final c = Color.lerp(const Color(0xFF44FF88), const Color(0xFF003322), t)!;
      final jitter = sin(animValue * pi * 3 + i) * 4;
      canvas.drawCircle(Offset(bx + jitter, by + i * 9.5), GameConstants.ballRadius * (1 - i / (len + 1)) * 1.3,
          Paint()..color = c.withOpacity(t * 0.35)..maskFilter = const MaskFilter.blur(BlurStyle.normal, 12));
    }
  }

  // ── Ball ───────────────────────────────────────────────────
  void _drawBall(Canvas canvas, Size size) {
    final bx = controller.ballScreenX;
    final by = controller.ballScreenY;
    final c  = controller.ballColor;
    final gp = 0.5 + 0.5 * sin(animValue * pi * 2);
    final skin = controller.activeSkin;

    // Outer glow — skin-tinted
    canvas.drawCircle(Offset(bx, by), GameConstants.ballRadius + 5,
        Paint()..color = skin.primaryColor.withOpacity(0.35 + 0.2 * gp)..maskFilter = MaskFilter.blur(BlurStyle.normal, 20 + 8 * gp));

    // Ball body with current color (changes as game progresses)
    canvas.drawCircle(Offset(bx, by), GameConstants.ballRadius,
        Paint()..shader = RadialGradient(
          center: const Alignment(-0.3, -0.4),
          colors: [Colors.white.withOpacity(0.95), c, c.withOpacity(0.5)],
          stops: const [0.04, 0.42, 1.0],
        ).createShader(Rect.fromCircle(center: Offset(bx, by), radius: GameConstants.ballRadius)));

    // Specular
    canvas.drawCircle(
      Offset(bx - GameConstants.ballRadius * 0.28, by - GameConstants.ballRadius * 0.3),
      GameConstants.ballRadius * 0.27,
      Paint()..color = Colors.white.withOpacity(0.65)..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3),
    );
  }

  // ── Skin overlay effects ON the ball ─────────────────────
  void _drawSkinEffect(Canvas canvas, Size size) {
    final bx = controller.ballScreenX;
    final by = controller.ballScreenY;
    final r  = GameConstants.ballRadius;
    final skin = controller.activeSkin;
    final t = animValue;

    switch (skin) {
      case BallSkin.fire:
        // Flame corona above ball
        for (int f = 0; f < 5; f++) {
          final angle = -pi / 2 + (f - 2) * 0.35;
          final height = 18 + 8 * sin(t * pi * 2 + f);
          canvas.drawOval(
            Rect.fromCenter(
              center: Offset(bx + cos(angle) * 10, by - r * 0.6 - height / 2),
              width: 8,
              height: height,
            ),
            Paint()..color = Color.lerp(const Color(0xFFFFFF00), const Color(0xFFFF2200), f / 4)!.withOpacity(0.55)
              ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5),
          );
        }
        break;

      case BallSkin.ice:
        // 6-point snowflake ring around ball
        for (int i = 0; i < 6; i++) {
          final angle = (i / 6) * pi * 2 + t * pi * 0.2;
          final px = bx + cos(angle) * (r + 6);
          final py = by + sin(angle) * (r + 6);
          canvas.drawCircle(Offset(px, py), 2.5,
              Paint()..color = const Color(0xFFCCEEFF).withOpacity(0.7));
          canvas.drawLine(Offset(px - 4, py), Offset(px + 4, py),
              Paint()..color = const Color(0xFF88DDFF).withOpacity(0.5)..strokeWidth = 1.5);
          canvas.drawLine(Offset(px, py - 4), Offset(px, py + 4),
              Paint()..color = const Color(0xFF88DDFF).withOpacity(0.5)..strokeWidth = 1.5);
        }
        break;

      case BallSkin.galaxy:
        // Orbiting star particles
        for (int i = 0; i < 4; i++) {
          final angle = (i / 4) * pi * 2 + t * pi * 2;
          final orbit = r + 8 + 3 * sin(t * pi * 2 + i);
          canvas.drawCircle(
            Offset(bx + cos(angle) * orbit, by + sin(angle) * orbit * 0.5),
            2.5,
            Paint()..color = Colors.white.withOpacity(0.7)..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3),
          );
        }
        // Purple nebula haze
        canvas.drawCircle(Offset(bx, by), r + 10,
            Paint()..color = const Color(0xFFAA44FF).withOpacity(0.12 + 0.06 * sin(t * pi))
              ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8));
        break;

      case BallSkin.electric:
        // Arcing bolts from ball surface
        final rng = Random((t * 10).toInt());
        for (int i = 0; i < 3; i++) {
          final boltAngle = rng.nextDouble() * pi * 2;
          final boltLen = 16 + rng.nextDouble() * 10;
          final midX = bx + cos(boltAngle) * (r + 4) + (rng.nextDouble() - 0.5) * 8;
          final midY = by + sin(boltAngle) * (r + 4) + (rng.nextDouble() - 0.5) * 8;
          final endX = bx + cos(boltAngle) * (r + boltLen);
          final endY = by + sin(boltAngle) * (r + boltLen);
          final boltPath = Path()
            ..moveTo(bx + cos(boltAngle) * r, by + sin(boltAngle) * r)
            ..lineTo(midX, midY)
            ..lineTo(endX, endY);
          canvas.drawPath(boltPath,
              Paint()..color = const Color(0xFFFFFF00).withOpacity(0.7)..strokeWidth = 1.5
                ..style = PaintingStyle.stroke..strokeCap = StrokeCap.round
                ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3));
        }
        break;

      case BallSkin.ghostRider:
        // Green flame ring + skull-ish aura
        for (int i = 0; i < 8; i++) {
          final angle = (i / 8) * pi * 2 + t * pi;
          final flameH = 14 + 6 * sin(t * pi * 3 + i);
          final px = bx + cos(angle) * r * 0.7;
          final py = by + sin(angle) * r * 0.7;
          canvas.drawOval(
            Rect.fromCenter(center: Offset(px, py - flameH / 3), width: 5, height: flameH),
            Paint()..color = const Color(0xFF44FF88).withOpacity(0.45)
              ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6),
          );
        }
        // Skull eye dots
        canvas.drawCircle(Offset(bx - 5, by - 3), 2.5,
            Paint()..color = Colors.white.withOpacity(0.8));
        canvas.drawCircle(Offset(bx + 5, by - 3), 2.5,
            Paint()..color = Colors.white.withOpacity(0.8));
        canvas.drawCircle(Offset(bx - 5, by - 3), 1.5,
            Paint()..color = const Color(0xFF44FF88));
        canvas.drawCircle(Offset(bx + 5, by - 3), 1.5,
            Paint()..color = const Color(0xFF44FF88));
        break;

      default:
        // Neon: pulsing ring already handled by color ring indicator
        break;
    }
  }

  // ── Ball color ring indicator ──────────────────────────────
  void _drawBallColorRing(Canvas canvas, Size size) {
    final bx = controller.ballScreenX;
    final by = controller.ballScreenY;
    final c  = controller.ballColor;
    final pulse = 0.5 + 0.5 * sin(animValue * pi * 2);

    canvas.drawCircle(
      Offset(bx, by),
      GameConstants.ballRadius + 9 + 2 * pulse,
      Paint()
        ..color = c.withOpacity(0.25 + 0.15 * pulse)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5,
    );

    // Bottom HUD: skin name + color indicator
    final skin = controller.activeSkin;
    final labelY = size.height - 28.0;
    final tp = TextPainter(
      text: TextSpan(
        text: '${skin.emoji} ${skin.displayName.toUpperCase()}  ●',
        style: TextStyle(color: skin.primaryColor.withOpacity(0.6), fontSize: 9, fontWeight: FontWeight.w700, letterSpacing: 2),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, Offset(size.width / 2 - tp.width / 2, labelY));
  }

  @override
  bool shouldRepaint(covariant GamePainter old) => true;
}
