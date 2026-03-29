import 'package:flutter/material.dart';
import '../utils/game_constants.dart';
import '../widgets/particle_background.dart';
import 'game_screen.dart';
import 'home_screen.dart';

class GameOverScreen extends StatefulWidget {
  final int score;
  final int bestScore;

  const GameOverScreen({
    super.key,
    required this.score,
    required this.bestScore,
  });

  @override
  State<GameOverScreen> createState() => _GameOverScreenState();
}

class _GameOverScreenState extends State<GameOverScreen>
    with TickerProviderStateMixin {
  late AnimationController _entranceController;
  late AnimationController _pulseController;
  late Animation<double> _fadeAnim;
  late Animation<Offset> _slideAnim;
  late Animation<double> _pulseAnim;

  bool _isNewBest = false;

  @override
  void initState() {
    super.initState();

    _isNewBest = widget.score >= widget.bestScore && widget.score > 0;

    _entranceController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 1200),
      vsync: this,
    )..repeat(reverse: true);

    _fadeAnim = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _entranceController, curve: Curves.easeOut),
    );
    _slideAnim =
        Tween<Offset>(begin: const Offset(0, 0.3), end: Offset.zero).animate(
      CurvedAnimation(
          parent: _entranceController, curve: Curves.easeOutCubic),
    );
    _pulseAnim = Tween<double>(begin: 8, end: 24).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    _entranceController.forward();
  }

  @override
  void dispose() {
    _entranceController.dispose();
    _pulseController.dispose();
    super.dispose();
  }

  String get _motivation {
    if (_isNewBest) return '🏆 NEW RECORD!';
    if (widget.score >= 30) return '⚡ Great reflex!';
    if (widget.score >= 15) return '🔥 Almost there!';
    if (widget.score >= 5) return '💪 Keep pushing!';
    return '🚀 Try again!';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: GameColors.background,
      body: Stack(
        children: [
          const Positioned.fill(child: ParticleBackground()),

          // Dark overlay
          Positioned.fill(
            child: Container(color: Colors.black.withOpacity(0.5)),
          ),

          SafeArea(
            child: FadeTransition(
              opacity: _fadeAnim,
              child: SlideTransition(
                position: _slideAnim,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 32),
                  child: Column(
                    children: [
                      const Spacer(),

                      // ── GAME OVER TITLE ──────────────────────
                      const Text(
                        'GAME',
                        style: TextStyle(
                          fontSize: 20,
                          color: Colors.white54,
                          letterSpacing: 8,
                        ),
                      ),
                      ShaderMask(
                        shaderCallback: (bounds) => const LinearGradient(
                          colors: [Color(0xFFFF3366), Color(0xFFFF8C00)],
                        ).createShader(bounds),
                        child: const Text(
                          'OVER',
                          style: TextStyle(
                            fontSize: 56,
                            fontWeight: FontWeight.w800,
                            color: Colors.white,
                            letterSpacing: 12,
                            height: 0.9,
                          ),
                        ),
                      ),

                      const SizedBox(height: 8),

                      // Motivation text
                      Text(
                        _motivation,
                        style: const TextStyle(
                          fontSize: 14,
                          color: Colors.white70,
                          letterSpacing: 2,
                        ),
                      ),

                      const Spacer(),

                      // ── SCORE CARD ───────────────────────────
                      AnimatedBuilder(
                        animation: _pulseAnim,
                        builder: (context, child) => Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(28),
                          decoration: BoxDecoration(
                            color: const Color(0xFF0D0D2B),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: _isNewBest
                                  ? const Color(0xFFFFD700)
                                  : GameColors.neonBlue.withOpacity(0.3),
                              width: _isNewBest ? 2 : 1,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: (_isNewBest
                                        ? const Color(0xFFFFD700)
                                        : GameColors.neonBlue)
                                    .withOpacity(0.2),
                                blurRadius: _pulseAnim.value,
                                spreadRadius: 2,
                              ),
                            ],
                          ),
                          child: Column(
                            children: [
                              if (_isNewBest)
                                const Padding(
                                  padding: EdgeInsets.only(bottom: 16),
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(Icons.emoji_events,
                                          color: Color(0xFFFFD700), size: 18),
                                      SizedBox(width: 8),
                                      Text(
                                        'NEW BEST SCORE',
                                        style: TextStyle(
                                          color: Color(0xFFFFD700),
                                          fontSize: 12,
                                          letterSpacing: 3,
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),

                              // Current score
                              Text(
                                widget.score.toString(),
                                style: TextStyle(
                                  fontSize: 72,
                                  fontWeight: FontWeight.w800,
                                  color: _isNewBest
                                      ? const Color(0xFFFFD700)
                                      : Colors.white,
                                  letterSpacing: -2,
                                  shadows: [
                                    Shadow(
                                      color: _isNewBest
                                          ? const Color(0xFFFFD700)
                                          : GameColors.neonBlue,
                                      blurRadius: 20,
                                    ),
                                  ],
                                ),
                              ),

                              Text(
                                'SCORE',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: Colors.white.withOpacity(0.4),
                                  letterSpacing: 4,
                                ),
                              ),

                              const SizedBox(height: 20),

                              // Divider
                              Container(
                                height: 1,
                                color: Colors.white.withOpacity(0.08),
                              ),

                              const SizedBox(height: 20),

                              // Best score
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    'BEST SCORE',
                                    style: TextStyle(
                                      color: Colors.white.withOpacity(0.5),
                                      fontSize: 11,
                                      letterSpacing: 2,
                                    ),
                                  ),
                                  Text(
                                    widget.bestScore.toString(),
                                    style: const TextStyle(
                                      color: Color(0xFFFFD700),
                                      fontSize: 20,
                                      fontWeight: FontWeight.w700,
                                      letterSpacing: 1,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),

                      const Spacer(),

                      // ── ACTION BUTTONS ───────────────────────
                      // Restart
                      GestureDetector(
                        onTap: () {
                          Navigator.of(context).pushReplacement(
                            PageRouteBuilder(
                              pageBuilder: (_, __, ___) => const GameScreen(),
                              transitionDuration:
                                  const Duration(milliseconds: 400),
                              transitionsBuilder: (_, anim, __, child) =>
                                  FadeTransition(
                                opacity: anim,
                                child: child,
                              ),
                            ),
                          );
                        },
                        child: Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(vertical: 18),
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [
                                Color(0xFF00D4FF),
                                Color(0xFF0077AA),
                              ],
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
                              Icon(Icons.refresh_rounded,
                                  color: Colors.white, size: 22),
                              SizedBox(width: 10),
                              Text(
                                'PLAY AGAIN',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w800,
                                  color: Colors.white,
                                  letterSpacing: 4,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),

                      const SizedBox(height: 14),

                      // Home
                      GestureDetector(
                        onTap: () {
                          Navigator.of(context).pushAndRemoveUntil(
                            MaterialPageRoute(
                                builder: (_) => const HomeScreen()),
                            (route) => false,
                          );
                        },
                        child: Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          decoration: BoxDecoration(
                            color: Colors.transparent,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: Colors.white.withOpacity(0.2),
                              width: 1.5,
                            ),
                          ),
                          child: const Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.home_rounded,
                                  color: Colors.white54, size: 20),
                              SizedBox(width: 10),
                              Text(
                                'HOME',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w700,
                                  color: Colors.white54,
                                  letterSpacing: 4,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),

                      const Spacer(),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
