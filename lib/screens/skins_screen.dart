import 'dart:math';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../utils/game_constants.dart';
import '../utils/skin_manager.dart';
import '../utils/game_state.dart';

class SkinsScreen extends StatelessWidget {
  const SkinsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final skinManager = context.watch<SkinManager>();
    final gameState = context.watch<GameState>();

    return Scaffold(
      backgroundColor: GameColors.background,
      body: SafeArea(
        child: Column(
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.all(20),
              child: Row(
                children: [
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: const Icon(Icons.arrow_back_ios,
                        color: Colors.white70, size: 20),
                  ),
                  const Expanded(
                    child: Text(
                      'BALL SKINS',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                        letterSpacing: 4,
                      ),
                    ),
                  ),
                  const SizedBox(width: 20),
                ],
              ),
            ),

            // Best score indicator
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              padding:
                  const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              decoration: BoxDecoration(
                color: const Color(0xFF0D0D2B),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                    color: const Color(0xFFFFD700).withOpacity(0.3)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'YOUR BEST SCORE',
                    style: TextStyle(
                        color: Colors.white.withOpacity(0.5),
                        fontSize: 10,
                        letterSpacing: 2),
                  ),
                  Text(
                    gameState.bestScore.toString(),
                    style: const TextStyle(
                      color: Color(0xFFFFD700),
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 8),

            // Skin grid
            Expanded(
              child: GridView.builder(
                padding: const EdgeInsets.all(20),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  mainAxisSpacing: 16,
                  crossAxisSpacing: 16,
                  childAspectRatio: 0.85,
                ),
                itemCount: BallSkin.values.length,
                itemBuilder: (context, i) {
                  final skin = BallSkin.values[i];
                  final isUnlocked = skinManager.isSkinUnlocked(skin);
                  final isSelected = skinManager.selectedSkin == skin;

                  return GestureDetector(
                    onTap: () {
                      if (isUnlocked) {
                        skinManager.selectSkin(skin);
                      }
                    },
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 250),
                      decoration: BoxDecoration(
                        color: const Color(0xFF0D0D2B),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: isSelected
                              ? skin.primaryColor
                              : isUnlocked
                                  ? Colors.white12
                                  : Colors.white.withOpacity(0.05),
                          width: isSelected ? 2 : 1,
                        ),
                        boxShadow: isSelected
                            ? [
                                BoxShadow(
                                  color: skin.primaryColor.withOpacity(0.3),
                                  blurRadius: 16,
                                  spreadRadius: 2,
                                ),
                              ]
                            : null,
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          // Ball preview
                          SizedBox(
                            width: 80,
                            height: 80,
                            child: CustomPaint(
                              painter: _BallSkinPainter(
                                skin: skin,
                                isUnlocked: isUnlocked,
                              ),
                            ),
                          ),

                          const SizedBox(height: 12),

                          Text(
                            skin.displayName.toUpperCase(),
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: isUnlocked
                                  ? Colors.white
                                  : Colors.white38,
                              letterSpacing: 2,
                            ),
                          ),

                          const SizedBox(height: 4),

                          if (!isUnlocked)
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.lock_rounded,
                                    color: Colors.white38, size: 12),
                                const SizedBox(width: 4),
                                Text(
                                  'SCORE ${skin.requiredScore}',
                                  style: const TextStyle(
                                    fontSize: 10,
                                    color: Colors.white38,
                                    letterSpacing: 1,
                                  ),
                                ),
                              ],
                            )
                          else if (isSelected)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 4),
                              decoration: BoxDecoration(
                                color: skin.primaryColor.withOpacity(0.2),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Text(
                                'SELECTED',
                                style: TextStyle(
                                  fontSize: 9,
                                  color: skin.primaryColor,
                                  letterSpacing: 2,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            )
                          else
                            Text(
                              'UNLOCKED',
                              style: TextStyle(
                                fontSize: 10,
                                color: GameColors.neonGreen.withOpacity(0.8),
                                letterSpacing: 1,
                              ),
                            ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _BallSkinPainter extends CustomPainter {
  final BallSkin skin;
  final bool isUnlocked;

  _BallSkinPainter({required this.skin, required this.isUnlocked});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width * 0.35;

    if (!isUnlocked) {
      // Draw locked ball (grayscale)
      final lockPaint = Paint()
        ..color = Colors.white12
        ..style = PaintingStyle.fill;
      canvas.drawCircle(center, radius, lockPaint);

      final borderPaint = Paint()
        ..color = Colors.white24
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2;
      canvas.drawCircle(center, radius, borderPaint);
      return;
    }

    // Glow
    final glowPaint = Paint()
      ..color = skin.primaryColor.withOpacity(0.4)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 14);
    canvas.drawCircle(center, radius + 6, glowPaint);

    // Ball
    final ballPaint = Paint()
      ..shader = RadialGradient(
        center: const Alignment(-0.3, -0.3),
        colors: [
          Colors.white.withOpacity(0.9),
          skin.primaryColor,
          skin.secondaryColor,
        ],
        stops: const [0.05, 0.45, 1.0],
      ).createShader(
          Rect.fromCircle(center: center, radius: radius));
    canvas.drawCircle(center, radius, ballPaint);

    // Specular
    final specPaint = Paint()
      ..color = Colors.white.withOpacity(0.5)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3);
    canvas.drawCircle(
      Offset(center.dx - radius * 0.3, center.dy - radius * 0.3),
      radius * 0.28,
      specPaint,
    );

    // Skin-specific effects
    switch (skin) {
      case BallSkin.fire:
        _drawFireTrail(canvas, center, radius);
        break;
      case BallSkin.electric:
        _drawElectricBolt(canvas, center, radius);
        break;
      case BallSkin.galaxy:
        _drawStars(canvas, center, radius);
        break;
      default:
        break;
    }
  }

  void _drawFireTrail(Canvas canvas, Offset center, double radius) {
    final flamePaint = Paint()
      ..color = const Color(0xFFFF8800).withOpacity(0.6)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8);
    canvas.drawOval(
      Rect.fromCenter(
          center: Offset(center.dx, center.dy + radius * 0.8),
          width: radius * 0.8,
          height: radius * 1.2),
      flamePaint,
    );
  }

  void _drawElectricBolt(Canvas canvas, Offset center, double radius) {
    final boltPaint = Paint()
      ..color = const Color(0xFFFFFF00).withOpacity(0.8)
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;

    final path = Path();
    path.moveTo(center.dx + radius * 0.2, center.dy - radius * 0.5);
    path.lineTo(center.dx - radius * 0.1, center.dy);
    path.lineTo(center.dx + radius * 0.15, center.dy);
    path.lineTo(center.dx - radius * 0.2, center.dy + radius * 0.5);

    canvas.drawPath(path, boltPaint);
  }

  void _drawStars(Canvas canvas, Offset center, double radius) {
    final starPaint = Paint()
      ..color = Colors.white.withOpacity(0.7)
      ..style = PaintingStyle.fill;

    const starPositions = [
      Offset(0.2, -0.3),
      Offset(-0.3, 0.1),
      Offset(0.1, 0.35),
      Offset(-0.15, -0.2),
    ];

    for (final pos in starPositions) {
      canvas.drawCircle(
        Offset(center.dx + pos.dx * radius * 2,
            center.dy + pos.dy * radius * 2),
        2,
        starPaint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
