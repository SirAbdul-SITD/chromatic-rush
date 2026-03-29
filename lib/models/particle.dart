import 'dart:math';
import 'package:flutter/material.dart';

class Particle {
  double x;
  double y;
  double size;
  double opacity;
  double speed;
  double dx;
  double dy;
  Color color;
  bool isGlow;

  Particle({
    required this.x,
    required this.y,
    required this.size,
    required this.opacity,
    required this.speed,
    required this.dx,
    required this.dy,
    required this.color,
    this.isGlow = false,
  });

  static Particle random(double screenWidth, double screenHeight) {
    final random = Random();
    final colors = [
      const Color(0xFF00D4FF),
      const Color(0xFF9B59B6),
      const Color(0xFF00FF88),
      const Color(0xFFFF3366),
    ];

    return Particle(
      x: random.nextDouble() * screenWidth,
      y: random.nextDouble() * screenHeight,
      size: random.nextDouble() * 3 + 1,
      opacity: random.nextDouble() * 0.6 + 0.1,
      speed: random.nextDouble() * 0.5 + 0.1,
      dx: (random.nextDouble() - 0.5) * 0.5,
      dy: -(random.nextDouble() * 0.8 + 0.2),
      color: colors[random.nextInt(colors.length)],
      isGlow: random.nextDouble() > 0.7,
    );
  }

  void update(double dt, double screenWidth, double screenHeight) {
    x += dx * speed * dt * 60;
    y += dy * speed * dt * 60;

    if (y < -10) y = screenHeight + 10;
    if (x < -10) x = screenWidth + 10;
    if (x > screenWidth + 10) x = -10;
  }
}
