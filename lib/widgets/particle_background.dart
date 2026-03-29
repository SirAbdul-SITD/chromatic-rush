import 'dart:async';
import 'package:flutter/material.dart';
import '../models/particle.dart';

class ParticleBackground extends StatefulWidget {
  const ParticleBackground({super.key});

  @override
  State<ParticleBackground> createState() => _ParticleBackgroundState();
}

class _ParticleBackgroundState extends State<ParticleBackground> {
  List<Particle> _particles = [];
  late Timer _timer;
  bool _initialized = false;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(milliseconds: 33), (_) {
      if (_initialized) {
        setState(() {
          final size = context.size;
          if (size != null) {
            for (final p in _particles) {
              p.update(0.033, size.width, size.height);
            }
          }
        });
      }
    });
  }

  void _initParticles(Size size) {
    if (!_initialized) {
      _particles = List.generate(
        60,
        (_) => Particle.random(size.width, size.height),
      );
      _initialized = true;
    }
  }

  @override
  void dispose() {
    _timer.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, constraints) {
      final size = Size(constraints.maxWidth, constraints.maxHeight);
      _initParticles(size);
      return CustomPaint(
        painter: _ParticlePainter(_particles),
        size: size,
      );
    });
  }
}

class _ParticlePainter extends CustomPainter {
  final List<Particle> particles;

  _ParticlePainter(this.particles);

  @override
  void paint(Canvas canvas, Size size) {
    for (final p in particles) {
      final paint = Paint()
        ..color = p.color.withOpacity(p.opacity)
        ..style = PaintingStyle.fill;

      if (p.isGlow) {
        final glowPaint = Paint()
          ..color = p.color.withOpacity(p.opacity * 0.3)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6);
        canvas.drawCircle(Offset(p.x, p.y), p.size * 2.5, glowPaint);
      }

      canvas.drawCircle(Offset(p.x, p.y), p.size, paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
