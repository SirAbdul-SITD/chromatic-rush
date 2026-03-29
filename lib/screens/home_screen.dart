import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../utils/game_constants.dart';
import '../utils/game_state.dart';
import '../widgets/particle_background.dart';
import 'game_screen.dart';
import 'skins_screen.dart';
import 'settings_screen.dart';
import 'leaderboard_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with TickerProviderStateMixin {
  late AnimationController _rotateCtrl;
  late AnimationController _floatCtrl;
  late AnimationController _pulseCtrl;
  late AnimationController _tipCtrl;
  late Animation<double> _floatAnim;
  late Animation<double> _pulseAnim;
  late Animation<double> _tipFade;

  Timer? _tipTimer;
  int _tipIndex = 0;

  static const _tips = [
    '💡 TAP or SWIPE left/right to switch lane',
    '🎯 Match your ball color to the gate color',
    '⚡ SWAP gates instantly change your ball color',
    '🔥 5 correct passes in a row = COMBO BONUS',
    '🏎️ Speed increases every 20 seconds — stay sharp!',
    '🌈 Phase 3: your ball color changes automatically',
    '🎮 Skins unlock as your best score grows',
    '👁️ Watch the gap on moving wall obstacles',
  ];

  @override
  void initState() {
    super.initState();

    _rotateCtrl = AnimationController(duration: const Duration(seconds: 5), vsync: this)..repeat();
    _floatCtrl = AnimationController(duration: const Duration(milliseconds: 2200), vsync: this)..repeat(reverse: true);
    _pulseCtrl = AnimationController(duration: const Duration(milliseconds: 1800), vsync: this)..repeat(reverse: true);
    _tipCtrl = AnimationController(duration: const Duration(milliseconds: 500), vsync: this);

    _floatAnim = Tween<double>(begin: -12, end: 12).animate(CurvedAnimation(parent: _floatCtrl, curve: Curves.easeInOut));
    _pulseAnim = Tween<double>(begin: 6, end: 22).animate(CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeInOut));
    _tipFade = Tween<double>(begin: 0, end: 1).animate(CurvedAnimation(parent: _tipCtrl, curve: Curves.easeIn));

    _tipCtrl.forward();
    _tipTimer = Timer.periodic(const Duration(seconds: 4), (_) {
      _tipCtrl.reverse().then((_) {
        if (mounted) {
          setState(() => _tipIndex = (_tipIndex + 1) % _tips.length);
          _tipCtrl.forward();
        }
      });
    });
  }

  @override
  void dispose() {
    _rotateCtrl.dispose();
    _floatCtrl.dispose();
    _pulseCtrl.dispose();
    _tipCtrl.dispose();
    _tipTimer?.cancel();
    super.dispose();
  }

  void _startGame() {
    Navigator.of(context).push(
      PageRouteBuilder(
        pageBuilder: (_, __, ___) => const GameScreen(),
        transitionDuration: const Duration(milliseconds: 500),
        transitionsBuilder: (_, anim, __, child) => FadeTransition(opacity: anim, child: child),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final gameState = context.watch<GameState>();

    return Scaffold(
      backgroundColor: GameColors.background,
      body: Stack(
        children: [
          const Positioned.fill(child: ParticleBackground()),

          // Subtle radial glow at center
          Positioned.fill(
            child: Container(
              decoration: const BoxDecoration(
                gradient: RadialGradient(
                  center: Alignment.center,
                  radius: 0.75,
                  colors: [Color(0x1A0033AA), Colors.transparent],
                ),
              ),
            ),
          ),

          SafeArea(
            child: Column(
              children: [
                const SizedBox(height: 44),

                // ── TITLE ──────────────────────────────────
                ShaderMask(
                  shaderCallback: (bounds) => const LinearGradient(
                    colors: [Color(0xFF00D4FF), Color(0xFFBB44FF)],
                  ).createShader(bounds),
                  child: const Text(
                    'CHROMATIC',
                    style: TextStyle(fontSize: 28, fontWeight: FontWeight.w800, color: Colors.white, letterSpacing: 6),
                  ),
                ),
                const Text(
                  'RUSH',
                  style: TextStyle(fontSize: 46, fontWeight: FontWeight.w800, color: Colors.white, letterSpacing: 14, height: 0.85),
                ),

                const SizedBox(height: 10),

                // Best score pill
                if (gameState.bestScore > 0)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 5),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFD700).withOpacity(0.12),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: const Color(0xFFFFD700).withOpacity(0.4)),
                    ),
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      const Icon(Icons.emoji_events, color: Color(0xFFFFD700), size: 14),
                      const SizedBox(width: 6),
                      Text('BEST: ${gameState.bestScore}',
                          style: const TextStyle(fontSize: 13, color: Color(0xFFFFD700), letterSpacing: 3, fontWeight: FontWeight.w700)),
                    ]),
                  ),

                const Spacer(),

                // ── ANIMATED OBSTACLE PREVIEW ───────────────
                AnimatedBuilder(
                  animation: Listenable.merge([_rotateCtrl, _floatCtrl, _pulseCtrl]),
                  builder: (_, __) => Transform.translate(
                    offset: Offset(0, _floatAnim.value),
                    child: SizedBox(
                      width: 200, height: 200,
                      child: CustomPaint(
                        painter: _ObstaclePreviewPainter(
                          rotation: _rotateCtrl.value * 2 * math.pi,
                          glowRadius: _pulseAnim.value,
                        ),
                      ),
                    ),
                  ),
                ),

                const Spacer(),

                // ── BUTTONS ─────────────────────────────────
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 28),
                  child: Column(children: [
                    // PLAY
                    GestureDetector(
                      onTap: _startGame,
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(vertical: 20),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(colors: [Color(0xFF00D4FF), Color(0xFF0077AA)]),
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: [BoxShadow(color: GameColors.neonBlue.withOpacity(0.4), blurRadius: 20, spreadRadius: 2)],
                        ),
                        child: const Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                          Icon(Icons.play_arrow_rounded, color: Colors.white, size: 28),
                          SizedBox(width: 8),
                          Text('PLAY', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: Colors.white, letterSpacing: 6)),
                        ]),
                      ),
                    ),

                    const SizedBox(height: 14),

                    // Secondary row
                    Row(children: [
                      Expanded(child: _SecBtn(icon: Icons.auto_awesome, label: 'SKINS',
                          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const SkinsScreen())))),
                      const SizedBox(width: 10),
                      Expanded(child: _SecBtn(icon: Icons.settings, label: 'SETTINGS',
                          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const SettingsScreen())))),
                      const SizedBox(width: 10),
                      Expanded(child: _SecBtn(icon: Icons.leaderboard, label: 'SCORES',
                          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const LeaderboardScreen())))),
                    ]),
                  ]),
                ),

                const SizedBox(height: 20),

                // ── ROTATING TIPS ────────────────────────────
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 28),
                  child: FadeTransition(
                    opacity: _tipFade,
                    child: Container(
                      key: ValueKey(_tipIndex),
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
                      decoration: BoxDecoration(
                        color: const Color(0xFF0A0A1E),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: GameColors.neonBlue.withOpacity(0.18)),
                      ),
                      child: Row(children: [
                        const Icon(Icons.lightbulb_outline, color: GameColors.neonBlue, size: 16),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            _tips[_tipIndex],
                            style: TextStyle(
                              fontSize: 11.5,
                              color: Colors.white.withOpacity(0.65),
                              height: 1.3,
                            ),
                          ),
                        ),
                        // Dot progress
                        Column(
                          children: List.generate(_tips.length, (i) => Container(
                            width: 4, height: 4,
                            margin: const EdgeInsets.symmetric(vertical: 1.5),
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: i == _tipIndex
                                  ? GameColors.neonBlue
                                  : Colors.white.withOpacity(0.12),
                            ),
                          )),
                        ),
                      ]),
                    ),
                  ),
                ),

                const SizedBox(height: 32),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SecBtn extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  const _SecBtn({required this.icon, required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: const Color(0xFF0D0D2B),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: GameColors.neonBlue.withOpacity(0.25)),
        ),
        child: Column(children: [
          Icon(icon, color: GameColors.neonBlue, size: 22),
          const SizedBox(height: 4),
          Text(label, style: const TextStyle(fontSize: 9, color: Colors.white60, letterSpacing: 1.5, fontWeight: FontWeight.w600)),
        ]),
      ),
    );
  }
}

class _ObstaclePreviewPainter extends CustomPainter {
  final double rotation;
  final double glowRadius;
  _ObstaclePreviewPainter({required this.rotation, required this.glowRadius});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width * 0.38;

    // Outer glow ring
    canvas.drawCircle(center, radius,
        Paint()..color = GameColors.neonBlue.withOpacity(0.18)..style = PaintingStyle.stroke..strokeWidth = 18
          ..maskFilter = MaskFilter.blur(BlurStyle.normal, glowRadius));
    canvas.drawCircle(center, radius,
        Paint()..color = GameColors.neonBlue.withOpacity(0.5)..style = PaintingStyle.stroke..strokeWidth = 2.5);

    // Rotating colored arcs
    canvas.save();
    canvas.translate(center.dx, center.dy);
    canvas.rotate(rotation);
    const colors = [GameColors.red, GameColors.blue, GameColors.green, GameColors.yellow, GameColors.purple, GameColors.orange];
    for (int i = 0; i < colors.length; i++) {
      final start = (i / colors.length) * math.pi * 2;
      final sweep = math.pi * 2 / colors.length * 0.68;
      canvas.drawArc(Rect.fromCircle(center: Offset.zero, radius: radius), start, sweep, false,
          Paint()..color = colors[i]..style = PaintingStyle.stroke..strokeWidth = 9..strokeCap = StrokeCap.round
            ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5));
    }
    canvas.restore();

    // Center ball
    canvas.drawCircle(center, 24,
        Paint()..color = GameColors.neonBlue.withOpacity(0.45)..maskFilter = MaskFilter.blur(BlurStyle.normal, glowRadius * 0.7));
    canvas.drawCircle(center, 23,
        Paint()..shader = RadialGradient(
          colors: [Colors.white, GameColors.neonBlue, const Color(0xFF003366)],
          stops: const [0.08, 0.5, 1.0],
        ).createShader(Rect.fromCircle(center: center, radius: 23)));
  }

  @override
  bool shouldRepaint(covariant CustomPainter old) => true;
}
