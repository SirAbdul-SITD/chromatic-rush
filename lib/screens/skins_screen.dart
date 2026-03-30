import 'dart:math';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../utils/game_constants.dart';
import '../utils/skin_manager.dart';
import '../utils/game_state.dart';

class SkinsScreen extends StatefulWidget {
  const SkinsScreen({super.key});
  @override
  State<SkinsScreen> createState() => _SkinsScreenState();
}

class _SkinsScreenState extends State<SkinsScreen> with SingleTickerProviderStateMixin {
  late AnimationController _animCtrl;

  @override
  void initState() {
    super.initState();
    _animCtrl = AnimationController(duration: const Duration(seconds: 3), vsync: this)..repeat();
  }

  @override
  void dispose() {
    _animCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final skinManager = context.watch<SkinManager>();
    final gameState   = context.watch<GameState>();
    final best        = gameState.bestScore;

    return Scaffold(
      backgroundColor: GameColors.background,
      body: SafeArea(
        child: Column(
          children: [
            // ── Header ─────────────────────────────────────
            Padding(
              padding: const EdgeInsets.all(20),
              child: Row(
                children: [
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: const Icon(Icons.arrow_back_ios, color: Colors.white70, size: 20),
                  ),
                  const Expanded(
                    child: Text('BALL SKINS', textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800,
                            color: Colors.white, letterSpacing: 4)),
                  ),
                  const SizedBox(width: 20),
                ],
              ),
            ),

            // ── Best score bar ─────────────────────────────
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              decoration: BoxDecoration(
                color: const Color(0xFF0D0D2B),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFFFD700).withOpacity(0.3)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('YOUR BEST SCORE',
                      style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 10, letterSpacing: 2)),
                  Text(best.toString(),
                      style: const TextStyle(color: Color(0xFFFFD700), fontSize: 18, fontWeight: FontWeight.w800)),
                ],
              ),
            ),

            const SizedBox(height: 8),

            // ── Skin grid ──────────────────────────────────
            Expanded(
              child: AnimatedBuilder(
                animation: _animCtrl,
                builder: (context, _) {
                  return GridView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      mainAxisSpacing: 14,
                      crossAxisSpacing: 14,
                      childAspectRatio: 0.82,
                    ),
                    itemCount: BallSkin.values.length,
                    itemBuilder: (context, i) {
                      final skin      = BallSkin.values[i];
                      final unlocked  = skinManager.isSkinUnlocked(skin);
                      final selected  = skinManager.selectedSkin == skin;
                      return _SkinCard(
                        skin: skin,
                        unlocked: unlocked,
                        selected: selected,
                        best: best,
                        animValue: _animCtrl.value,
                        onTap: () {
                          if (unlocked) skinManager.selectSkin(skin);
                        },
                      );
                    },
                  );
                },
              ),
            ),

            // ── Unlock hint ────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 16),
              child: Text(
                'Skins unlock every 30 best-score points',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.white.withOpacity(0.3), fontSize: 11, letterSpacing: 1),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SkinCard extends StatelessWidget {
  final BallSkin skin;
  final bool unlocked, selected;
  final int best;
  final double animValue;
  final VoidCallback onTap;

  const _SkinCard({
    required this.skin,
    required this.unlocked,
    required this.selected,
    required this.best,
    required this.animValue,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final progress = (best / skin.requiredScore).clamp(0.0, 1.0);

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        decoration: BoxDecoration(
          color: const Color(0xFF0D0D2B),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: selected
                ? skin.primaryColor
                : unlocked
                    ? skin.primaryColor.withOpacity(0.3)
                    : Colors.white.withOpacity(0.07),
            width: selected ? 2.2 : 1,
          ),
          boxShadow: selected
              ? [BoxShadow(color: skin.primaryColor.withOpacity(0.35), blurRadius: 18, spreadRadius: 2)]
              : null,
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Ball preview with live skin effects
            SizedBox(
              width: 88,
              height: 88,
              child: CustomPaint(
                painter: _SkinBallPainter(
                  skin: skin,
                  unlocked: unlocked,
                  animValue: animValue,
                ),
              ),
            ),

            const SizedBox(height: 10),

            // Emoji + name
            Text(skin.emoji, style: const TextStyle(fontSize: 18)),
            const SizedBox(height: 2),
            Text(
              skin.displayName.toUpperCase(),
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w800,
                color: unlocked ? Colors.white : Colors.white38,
                letterSpacing: 1.5,
              ),
            ),

            const SizedBox(height: 6),

            // Status badge / progress
            if (skin.requiredScore == 0)
              _badge('DEFAULT', GameColors.neonBlue)
            else if (selected)
              _badge('EQUIPPED', skin.primaryColor)
            else if (unlocked)
              _badge('UNLOCKED ✓', GameColors.neonGreen)
            else ...[
              Text(
                'SCORE ${skin.requiredScore}',
                style: TextStyle(color: Colors.white38, fontSize: 9, letterSpacing: 1.5),
              ),
              const SizedBox(height: 5),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: progress,
                    backgroundColor: Colors.white.withOpacity(0.05),
                    valueColor: AlwaysStoppedAnimation<Color>(skin.primaryColor.withOpacity(0.6)),
                    minHeight: 4,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _badge(String text, Color color) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
    decoration: BoxDecoration(
      color: color.withOpacity(0.15),
      borderRadius: BorderRadius.circular(20),
      border: Border.all(color: color.withOpacity(0.5)),
    ),
    child: Text(text,
        style: TextStyle(color: color, fontSize: 8, fontWeight: FontWeight.w800, letterSpacing: 1.5)),
  );
}

class _SkinBallPainter extends CustomPainter {
  final BallSkin skin;
  final bool unlocked;
  final double animValue;

  _SkinBallPainter({required this.skin, required this.unlocked, required this.animValue});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    const r = 26.0;

    if (!unlocked) {
      canvas.drawCircle(center, r, Paint()..color = Colors.white.withOpacity(0.08));
      canvas.drawCircle(center, r, Paint()..color = Colors.white.withOpacity(0.15)
          ..style = PaintingStyle.stroke..strokeWidth = 1.5);
      // Lock icon
      final tp = TextPainter(text: const TextSpan(text: '🔒', style: TextStyle(fontSize: 22)),
          textDirection: TextDirection.ltr)..layout();
      tp.paint(canvas, Offset(center.dx - tp.width / 2, center.dy - tp.height / 2));
      return;
    }

    final t = animValue;
    final p = skin.primaryColor;
    final s = skin.secondaryColor;

    // ── Skin-specific background effects ────────────────────
    switch (skin) {
      case BallSkin.fire:
        // Flame behind ball
        for (int f = 0; f < 4; f++) {
          final angle = -pi / 2 + (f - 1.5) * 0.55;
          final h = 22 + 8 * sin(t * pi * 2 + f);
          canvas.drawOval(
            Rect.fromCenter(center: Offset(center.dx + cos(angle) * 8, center.dy - r * 0.5 - h / 2),
                width: 9, height: h),
            Paint()..color = Color.lerp(const Color(0xFFFFFF00), const Color(0xFFFF2200), f / 3)!.withOpacity(0.5)
              ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6),
          );
        }
        break;

      case BallSkin.ice:
        // Crystal ring
        for (int i = 0; i < 6; i++) {
          final angle = (i / 6) * pi * 2 + t * 0.4;
          canvas.drawCircle(Offset(center.dx + cos(angle) * (r + 6), center.dy + sin(angle) * (r + 6)),
              2.5, Paint()..color = const Color(0xFFCCEEFF).withOpacity(0.75));
        }
        break;

      case BallSkin.galaxy:
        // Orbiting stars
        for (int i = 0; i < 4; i++) {
          final angle = (i / 4) * pi * 2 + t * pi * 2;
          canvas.drawCircle(
              Offset(center.dx + cos(angle) * (r + 8), center.dy + sin(angle) * (r + 8) * 0.5),
              2, Paint()..color = Colors.white.withOpacity(0.8)..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2));
        }
        break;

      case BallSkin.electric:
        // Electric sparks
        final rng = Random((t * 8).toInt());
        for (int i = 0; i < 3; i++) {
          final a = rng.nextDouble() * pi * 2;
          final len = 12 + rng.nextDouble() * 8;
          canvas.drawLine(
            Offset(center.dx + cos(a) * r, center.dy + sin(a) * r),
            Offset(center.dx + cos(a) * (r + len), center.dy + sin(a) * (r + len)),
            Paint()..color = const Color(0xFFFFFF00).withOpacity(0.8)..strokeWidth = 1.5
              ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3),
          );
        }
        break;

      case BallSkin.ghostRider:
        // Green ghost aura
        canvas.drawCircle(center, r + 10,
            Paint()..color = const Color(0xFF44FF88).withOpacity(0.1 + 0.06 * sin(t * pi * 2))
              ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 10));
        break;

      default:
        // Neon: outer glow ring only
        canvas.drawCircle(center, r + 8,
            Paint()..color = p.withOpacity(0.15 + 0.08 * sin(t * pi * 2))
              ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8));
    }

    // ── Glow ─────────────────────────────────────────────────
    canvas.drawCircle(center, r + 4,
        Paint()..color = p.withOpacity(0.38 + 0.15 * sin(t * pi * 2))
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 14));

    // ── Ball body ─────────────────────────────────────────────
    canvas.drawCircle(center, r,
        Paint()..shader = RadialGradient(
          center: const Alignment(-0.3, -0.4),
          colors: [Colors.white.withOpacity(0.95), p, s],
          stops: const [0.04, 0.45, 1.0],
        ).createShader(Rect.fromCircle(center: center, radius: r)));

    // ── Specular ──────────────────────────────────────────────
    canvas.drawCircle(Offset(center.dx - r * 0.28, center.dy - r * 0.3), r * 0.28,
        Paint()..color = Colors.white.withOpacity(0.65)..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3));

    // ── Ghost Rider skull eyes ────────────────────────────────
    if (skin == BallSkin.ghostRider) {
      canvas.drawCircle(Offset(center.dx - 7, center.dy - 3), 3,
          Paint()..color = Colors.white.withOpacity(0.9));
      canvas.drawCircle(Offset(center.dx + 7, center.dy - 3), 3,
          Paint()..color = Colors.white.withOpacity(0.9));
      canvas.drawCircle(Offset(center.dx - 7, center.dy - 3), 2,
          Paint()..color = const Color(0xFF44FF88));
      canvas.drawCircle(Offset(center.dx + 7, center.dy - 3), 2,
          Paint()..color = const Color(0xFF44FF88));
    }
  }

  @override
  bool shouldRepaint(covariant _SkinBallPainter old) =>
      old.animValue != animValue || old.unlocked != unlocked || old.skin != skin;
}
