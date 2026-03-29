import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../utils/game_constants.dart';
import '../utils/game_state.dart';
import '../widgets/particle_background.dart';
import '../widgets/neon_button.dart';
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
  late AnimationController _rotateController;
  late AnimationController _floatController;
  late AnimationController _pulseController;
  late Animation<double> _floatAnim;
  late Animation<double> _pulseAnim;

  @override
  void initState() {
    super.initState();
    _rotateController = AnimationController(
      duration: const Duration(seconds: 4),
      vsync: this,
    )..repeat();

    _floatController = AnimationController(
      duration: const Duration(milliseconds: 2000),
      vsync: this,
    )..repeat(reverse: true);

    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 1800),
      vsync: this,
    )..repeat(reverse: true);

    _floatAnim = Tween<double>(begin: -12, end: 12).animate(
      CurvedAnimation(parent: _floatController, curve: Curves.easeInOut),
    );
    _pulseAnim = Tween<double>(begin: 6, end: 20).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _rotateController.dispose();
    _floatController.dispose();
    _pulseController.dispose();
    super.dispose();
  }

  void _startGame(BuildContext context) {
    Navigator.of(context).push(
      PageRouteBuilder(
        pageBuilder: (_, __, ___) => const GameScreen(),
        transitionDuration: const Duration(milliseconds: 500),
        transitionsBuilder: (_, anim, __, child) => FadeTransition(
          opacity: anim,
          child: child,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final gameState = context.watch<GameState>();
    final size = MediaQuery.of(context).size;

    return Scaffold(
      backgroundColor: GameColors.background,
      body: Stack(
        children: [
          // Particle background
          const Positioned.fill(child: ParticleBackground()),

          // Radial gradient overlay
          Positioned.fill(
            child: Container(
              decoration: const BoxDecoration(
                gradient: RadialGradient(
                  center: Alignment.center,
                  radius: 0.8,
                  colors: [
                    Color(0x220033AA),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),

          SafeArea(
            child: Column(
              children: [
                const SizedBox(height: 48),

                // ── TITLE ──────────────────────────────────────
                ShaderMask(
                  shaderCallback: (bounds) => const LinearGradient(
                    colors: [Color(0xFF00D4FF), Color(0xFFBB44FF)],
                  ).createShader(bounds),
                  child: const Text(
                    'CHROMATIC',
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                      letterSpacing: 6,
                    ),
                  ),
                ),
                const Text(
                  'RUSH',
                  style: TextStyle(
                    fontSize: 42,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                    letterSpacing: 12,
                    height: 0.85,
                  ),
                ),

                const SizedBox(height: 8),

                // Best score
                if (gameState.bestScore > 0)
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.emoji_events,
                          color: const Color(0xFFFFD700), size: 16),
                      const SizedBox(width: 6),
                      Text(
                        'BEST: ${gameState.bestScore}',
                        style: const TextStyle(
                          fontSize: 13,
                          color: Color(0xFFFFD700),
                          letterSpacing: 3,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),

                const Spacer(),

                // ── ANIMATED OBSTACLE PREVIEW ──────────────────
                AnimatedBuilder(
                  animation: Listenable.merge(
                      [_rotateController, _floatController, _pulseController]),
                  builder: (context, child) {
                    return Transform.translate(
                      offset: Offset(0, _floatAnim.value),
                      child: SizedBox(
                        width: 200,
                        height: 200,
                        child: CustomPaint(
                          painter: _ObstaclePreviewPainter(
                            rotation: _rotateController.value * 2 * 3.14159,
                            glowRadius: _pulseAnim.value,
                          ),
                        ),
                      ),
                    );
                  },
                ),

                const Spacer(),

                // ── BUTTONS ────────────────────────────────────
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 32),
                  child: Column(
                    children: [
                      // PLAY button (big)
                      GestureDetector(
                        onTap: () => _startGame(context),
                        child: Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(vertical: 20),
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [Color(0xFF00D4FF), Color(0xFF0077AA)],
                            ),
                            borderRadius: BorderRadius.circular(16),
                            boxShadow: [
                              BoxShadow(
                                color: GameColors.neonBlue.withOpacity(0.4),
                                blurRadius: 20,
                                spreadRadius: 2,
                              ),
                            ],
                          ),
                          child: const Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.play_arrow_rounded,
                                  color: Colors.white, size: 28),
                              SizedBox(width: 8),
                              Text(
                                'PLAY',
                                style: TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.w800,
                                  color: Colors.white,
                                  letterSpacing: 6,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),

                      const SizedBox(height: 16),

                      // Secondary buttons row
                      Row(
                        children: [
                          Expanded(
                            child: _SecondaryButton(
                              icon: Icons.auto_awesome,
                              label: 'SKINS',
                              onTap: () => Navigator.of(context).push(
                                MaterialPageRoute(
                                    builder: (_) => const SkinsScreen()),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _SecondaryButton(
                              icon: Icons.settings,
                              label: 'SETTINGS',
                              onTap: () => Navigator.of(context).push(
                                MaterialPageRoute(
                                    builder: (_) => const SettingsScreen()),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _SecondaryButton(
                              icon: Icons.leaderboard,
                              label: 'SCORES',
                              onTap: () => Navigator.of(context).push(
                                MaterialPageRoute(
                                    builder: (_) => const LeaderboardScreen()),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 40),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SecondaryButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _SecondaryButton({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: const Color(0xFF0D0D2B),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: GameColors.neonBlue.withOpacity(0.3),
            width: 1,
          ),
        ),
        child: Column(
          children: [
            Icon(icon, color: GameColors.neonBlue, size: 22),
            const SizedBox(height: 4),
            Text(
              label,
              style: const TextStyle(
                fontSize: 9,
                color: Colors.white70,
                letterSpacing: 1.5,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ObstaclePreviewPainter extends CustomPainter {
  final double rotation;
  final double glowRadius;

  _ObstaclePreviewPainter({
    required this.rotation,
    required this.glowRadius,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width * 0.38;

    // Outer ring glow
    final glowPaint = Paint()
      ..color = GameColors.neonBlue.withOpacity(0.2)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 16
      ..maskFilter = MaskFilter.blur(BlurStyle.normal, glowRadius);
    canvas.drawCircle(center, radius, glowPaint);

    // Outer ring
    final ringPaint = Paint()
      ..color = GameColors.neonBlue.withOpacity(0.6)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3;
    canvas.drawCircle(center, radius, ringPaint);

    // Rotating colored arcs
    final colors = [
      GameColors.red,
      GameColors.blue,
      GameColors.green,
      GameColors.yellow,
      GameColors.purple,
      GameColors.orange,
    ];

    canvas.save();
    canvas.translate(center.dx, center.dy);
    canvas.rotate(rotation);

    for (int i = 0; i < colors.length; i++) {
      final arcPaint = Paint()
        ..color = colors[i]
        ..style = PaintingStyle.stroke
        ..strokeWidth = 8
        ..strokeCap = StrokeCap.round
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, 4);

      final startAngle = (i / colors.length) * 3.14159 * 2;
      final sweepAngle = 3.14159 * 2 / colors.length * 0.7;

      canvas.drawArc(
        Rect.fromCircle(center: Offset.zero, radius: radius),
        startAngle,
        sweepAngle,
        false,
        arcPaint,
      );
    }

    canvas.restore();

    // Center ball
    final ballGlowPaint = Paint()
      ..color = GameColors.neonBlue.withOpacity(0.4)
      ..maskFilter = MaskFilter.blur(BlurStyle.normal, glowRadius * 0.8);
    canvas.drawCircle(center, 22, ballGlowPaint);

    final ballPaint = Paint()
      ..shader = RadialGradient(
        colors: [Colors.white, GameColors.neonBlue, const Color(0xFF003366)],
        stops: const [0.1, 0.5, 1.0],
      ).createShader(Rect.fromCircle(center: center, radius: 22));
    canvas.drawCircle(center, 22, ballPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
