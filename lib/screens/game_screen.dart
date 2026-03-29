import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../game/game_controller.dart';
import '../game/game_painter.dart';
import '../utils/game_constants.dart';
import '../utils/audio_manager.dart';
import '../utils/settings_manager.dart';
import '../utils/score_history_manager.dart';
import 'game_over_screen.dart';

class GameScreen extends StatefulWidget {
  const GameScreen({super.key});

  @override
  State<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen> with TickerProviderStateMixin {
  late GameController _controller;
  late AnimationController _loopController;
  late AnimationController _comboController;
  late Animation<double> _comboScale;
  final AudioManager _audio = AudioManager();

  Timer? _gameLoopTimer;
  DateTime _lastUpdate = DateTime.now();
  bool _initialized = false;
  int _lastScore = 0; // track score changes to trigger sound

  @override
  void initState() {
    super.initState();
    _controller = GameController();

    _loopController = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    )..repeat();

    _comboController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );
    _comboScale = Tween<double>(begin: 0.4, end: 1.25).animate(
      CurvedAnimation(parent: _comboController, curve: Curves.elasticOut),
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_initialized) {
      _initialized = true;
      final settings = context.read<SettingsManager>();
      _audio.init(settings).then((_) => _audio.startMusic());
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          final size = MediaQuery.of(context).size;
          _controller.startGame(size.width, size.height);
          _startGameLoop();
        }
      });
    }
  }

  void _startGameLoop() {
    _lastUpdate = DateTime.now();
    _gameLoopTimer = Timer.periodic(const Duration(milliseconds: 16), (_) {
      if (!mounted) return;

      final now = DateTime.now();
      final dt = now.difference(_lastUpdate).inMilliseconds / 1000.0;
      _lastUpdate = now;

      if (_controller.engineState == GameEngineState.playing) {
        _controller.update(dt.clamp(0.0, 0.05));

        // Score increased → correct pass sound
        if (_controller.score > _lastScore) {
          _lastScore = _controller.score;
          if (_controller.showComboEffect) {
            _audio.playCombo();
            _comboController.forward(from: 0);
          } else {
            _audio.playCorrectPass();
          }
        }
      }

      if (_controller.engineState == GameEngineState.over) {
        _gameLoopTimer?.cancel();
        _audio.playLose();
        _audio.stopMusic();
        _onGameOver();
      }
    });
  }

  void _onGameOver() async {
    final score = _controller.score;
    final best = _controller.bestScore;
    await ScoreHistoryManager.saveScore(score);

    if (mounted) {
      await Future.delayed(const Duration(milliseconds: 400));
      if (mounted) {
        Navigator.of(context).pushReplacement(
          PageRouteBuilder(
            pageBuilder: (_, __, ___) =>
                GameOverScreen(score: score, bestScore: best),
            transitionDuration: const Duration(milliseconds: 500),
            transitionsBuilder: (_, anim, __, child) =>
                FadeTransition(opacity: anim, child: child),
          ),
        );
      }
    }
  }

  @override
  void dispose() {
    _gameLoopTimer?.cancel();
    _loopController.dispose();
    _comboController.dispose();
    _controller.dispose();
    _audio.stopMusic();
    super.dispose();
  }

  void _handleTap(TapUpDetails details) {
    if (_controller.engineState != GameEngineState.playing) return;
    final tapX = details.localPosition.dx;
    _audio.playTap();
    if (tapX < screenWidth / 2) {
      _controller.onTapLeft();
    } else {
      _controller.onTapRight();
    }
  }

  double get screenWidth => MediaQuery.of(context).size.width;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: GameColors.background,
      body: GestureDetector(
        onTapUp: _handleTap,
        behavior: HitTestBehavior.opaque,
        child: Stack(
          children: [
            // ── GAME CANVAS ──────────────────────────────
            AnimatedBuilder(
              animation: Listenable.merge([_controller, _loopController]),
              builder: (_, __) => CustomPaint(
                painter: GamePainter(
                  controller: _controller,
                  animValue: _loopController.value,
                ),
                child: const SizedBox.expand(),
              ),
            ),

            // ── HUD ──────────────────────────────────────
            SafeArea(
              child: AnimatedBuilder(
                animation: _controller,
                builder: (_, __) => _buildHUD(),
              ),
            ),

            // ── PHASE BADGE ──────────────────────────────
            AnimatedBuilder(
              animation: _controller,
              builder: (_, __) => _buildPhaseBadge(),
            ),

            // ── COMBO POPUP ──────────────────────────────
            AnimatedBuilder(
              animation: Listenable.merge([_comboController, _controller]),
              builder: (_, __) {
                if (!_controller.showComboEffect) return const SizedBox.shrink();
                return Center(
                  child: Transform.scale(
                    scale: _comboScale.value,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 14),
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.75),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: GameColors.neonBlue, width: 1.5),
                        boxShadow: [BoxShadow(color: GameColors.neonBlue.withOpacity(0.4), blurRadius: 24)],
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            'COMBO ×${_controller.combo}',
                            style: const TextStyle(color: GameColors.neonBlue, fontSize: 22, fontWeight: FontWeight.w800, letterSpacing: 4),
                          ),
                          Text(
                            '+${GameConstants.comboBonus} BONUS',
                            style: TextStyle(color: Colors.white.withOpacity(0.65), fontSize: 12, letterSpacing: 2),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),

            // ── COLOR CHANGE FLASH ───────────────────────
            AnimatedBuilder(
              animation: _controller,
              builder: (_, __) {
                if (!_controller.showColorChangeEffect) return const SizedBox.shrink();
                return Positioned.fill(
                  child: IgnorePointer(
                    child: Container(color: _controller.ballColor.withOpacity(0.18)),
                  ),
                );
              },
            ),

            // ── PAUSE OVERLAY ────────────────────────────
            AnimatedBuilder(
              animation: _controller,
              builder: (_, __) {
                if (_controller.engineState != GameEngineState.paused) {
                  return const SizedBox.shrink();
                }
                return _buildPauseOverlay();
              },
            ),

            // ── TUTORIAL HINT ────────────────────────────
            AnimatedBuilder(
              animation: _controller,
              builder: (_, __) {
                if (_controller.gameTime > 3 || _controller.score > 0) {
                  return const SizedBox.shrink();
                }
                return _buildTutorialHint();
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHUD() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      child: Row(
        children: [
          _ScoreBox(label: 'SCORE', value: '${_controller.score}', color: GameColors.neonBlue),
          const Spacer(),
          GestureDetector(
            onTap: () {
              if (_controller.engineState == GameEngineState.playing) {
                _controller.pause();
                _audio.pauseMusic();
              }
            },
            child: Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.black38,
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white24),
              ),
              child: const Icon(Icons.pause_rounded, color: Colors.white70, size: 20),
            ),
          ),
          const Spacer(),
          _ScoreBox(label: 'BEST', value: '${_controller.bestScore}', color: const Color(0xFFFFD700), alignRight: true),
        ],
      ),
    );
  }

  Widget _buildPhaseBadge() {
    final phase = _controller.currentPhase;
    final colors = [GameColors.neonGreen, GameColors.neonBlue, GameColors.orange, GameColors.red];
    final labels = ['PHASE 1', 'PHASE 2', 'PHASE 3', '⚡ HYPER'];
    return Positioned(
      bottom: 36,
      left: 0,
      right: 0,
      child: Center(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
          decoration: BoxDecoration(
            color: Colors.black38,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: colors[phase - 1].withOpacity(0.35)),
          ),
          child: Text(
            labels[phase - 1],
            style: TextStyle(color: colors[phase - 1], fontSize: 10, letterSpacing: 3, fontWeight: FontWeight.w700),
          ),
        ),
      ),
    );
  }

  Widget _buildPauseOverlay() {
    return Positioned.fill(
      child: Container(
        color: Colors.black.withOpacity(0.72),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('PAUSED', style: TextStyle(fontSize: 38, fontWeight: FontWeight.w800, color: Colors.white, letterSpacing: 8)),
              const SizedBox(height: 36),
              GestureDetector(
                onTap: () {
                  _controller.resume();
                  _audio.resumeMusic();
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 44, vertical: 18),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(colors: [Color(0xFF00D4FF), Color(0xFF0066AA)]),
                    borderRadius: BorderRadius.circular(14),
                    boxShadow: [BoxShadow(color: GameColors.neonBlue.withOpacity(0.35), blurRadius: 20)],
                  ),
                  child: const Text('RESUME', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: Colors.white, letterSpacing: 4)),
                ),
              ),
              const SizedBox(height: 18),
              GestureDetector(
                onTap: () => Navigator.of(context).pop(),
                child: const Text('QUIT', style: TextStyle(color: Colors.white38, fontSize: 13, letterSpacing: 3)),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTutorialHint() {
    return Positioned(
      bottom: 90,
      left: 0,
      right: 0,
      child: Center(
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.arrow_back_ios, color: Colors.white38, size: 14),
            const SizedBox(width: 10),
            Text('TAP SIDES TO SWITCH LANES', style: TextStyle(color: Colors.white.withOpacity(0.45), fontSize: 10, letterSpacing: 2.5)),
            const SizedBox(width: 10),
            const Icon(Icons.arrow_forward_ios, color: Colors.white38, size: 14),
          ],
        ),
      ),
    );
  }
}

class _ScoreBox extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  final bool alignRight;

  const _ScoreBox({required this.label, required this.value, required this.color, this.alignRight = false});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: alignRight ? CrossAxisAlignment.end : CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(label, style: TextStyle(fontSize: 9, color: Colors.white.withOpacity(0.45), letterSpacing: 2)),
        Text(
          value,
          style: TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.w800,
            color: color,
            letterSpacing: 1,
            shadows: [Shadow(color: color, blurRadius: 14)],
          ),
        ),
      ],
    );
  }
}
