import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../game/game_controller.dart';
import '../game/game_painter.dart';
import '../utils/game_constants.dart';
import '../utils/audio_manager.dart';
import '../utils/settings_manager.dart';
import '../utils/game_state.dart';
import '../utils/skin_manager.dart';
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
  late AnimationController _countdownController;
  late Animation<double> _comboScale;
  late Animation<double> _countdownScale;

  final AudioManager _audio = AudioManager();
  Timer? _gameLoopTimer;
  DateTime _lastUpdate = DateTime.now();

  // Countdown tutorial
  int _countdownValue = 3;
  bool _countdownActive = true;
  Timer? _countdownTimer;

  // Phase tracking for music switching
  int _lastPhase = 1;
  int _lastScore = 0;

  // Swipe tracking

  static const _tips = [
    'TAP LEFT or RIGHT side to switch lane',
    'SWIPE left or right to switch lane',
    'Match your ball color to the gate',
    'Every 5 correct = COMBO BONUS',
    '⚡ SWAP gates change your ball color!',
    'Stay calm — phase changes add speed',
  ];
  int _tipIndex = 0;

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

    _countdownController = AnimationController(
      duration: const Duration(milliseconds: 700),
      vsync: this,
    );
    _countdownScale = Tween<double>(begin: 1.6, end: 0.8).animate(
      CurvedAnimation(parent: _countdownController, curve: Curves.easeOut),
    );
  }

  bool _gameStarted = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_gameStarted) return;
    _gameStarted = true;

    final settings = context.read<SettingsManager>();
    _audio.init(settings);

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (mounted) {
        final size = MediaQuery.of(context).size;
        final skin = context.read<SkinManager>().selectedSkin;
        await _controller.startGame(size.width, size.height, skin: skin);
        _startCountdown();
      }
    });
  }

  void _startCountdown() {
    _countdownValue = 3;
    _countdownActive = true;
    _countdownController.forward(from: 0);

    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) { t.cancel(); return; }
      setState(() {
        _countdownValue--;
        _tipIndex = (_tipIndex + 1) % _tips.length;
      });
      _countdownController.forward(from: 0);

      if (_countdownValue <= 0) {
        t.cancel();
        setState(() => _countdownActive = false);
        _startGameLoop();
        _audio.startMusic(phase: 1);
      }
    });
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

        // Score changed → correct pass sound + vibration
        if (_controller.score > _lastScore) {
          _lastScore = _controller.score;
          if (_controller.showComboEffect) {
            _audio.playCombo();
            _comboController.forward(from: 0);
            _vibrateDouble(); // double-pulse for combo
          } else {
            _audio.playCorrectPass();
            _vibrateMedium(); // satisfying medium bump on each correct pass
          }
        }

        // Phase changed → switch music
        if (_controller.currentPhase != _lastPhase) {
          _lastPhase = _controller.currentPhase;
          _audio.setMusicPhase(_lastPhase);
        }
      }

      if (_controller.engineState == GameEngineState.over) {
        _gameLoopTimer?.cancel();
        _audio.playLose();
        _audio.stopMusic();
        _vibrateHeavy(); // strong thud on death
        _onGameOver();
      }
    });
  }

  void _onGameOver() async {
    final score    = _controller.score;
    final best     = _controller.bestScore; // already saved to prefs by controller
    await ScoreHistoryManager.saveScore(score);

    // Sync GameState best score so home screen shows it correctly
    if (mounted) {
      final gameState = context.read<GameState>();
      await gameState.syncBestScore(best);

      // Unlock skins based on new best
      final skinManager = context.read<SkinManager>();
      skinManager.checkUnlocks(best);
    }

    await Future.delayed(const Duration(milliseconds: 500));
    if (mounted) {
      Navigator.of(context).pushReplacement(
        PageRouteBuilder(
          pageBuilder: (_, __, ___) => GameOverScreen(score: score, bestScore: best),
          transitionDuration: const Duration(milliseconds: 500),
          transitionsBuilder: (_, anim, __, child) => FadeTransition(opacity: anim, child: child),
        ),
      );
    }
  }

  @override
  void dispose() {
    _gameLoopTimer?.cancel();
    _countdownTimer?.cancel();
    _loopController.dispose();
    _comboController.dispose();
    _countdownController.dispose();
    _controller.dispose();
    _audio.stopMusic();
    super.dispose();
  }

  // ── Haptic helpers ────────────────────────────────────────
  SettingsManager? get _settings {
    try { return context.read<SettingsManager>(); } catch (_) { return null; }
  }

  void _vibrateLight() {
    if (_settings?.vibrationEnabled ?? true) HapticFeedback.lightImpact();
  }

  void _vibrateMedium() {
    if (_settings?.vibrationEnabled ?? true) HapticFeedback.mediumImpact();
  }

  void _vibrateHeavy() {
    if (_settings?.vibrationEnabled ?? true) HapticFeedback.heavyImpact();
  }

  void _vibrateDouble() {
    if (!(_settings?.vibrationEnabled ?? true)) return;
    HapticFeedback.mediumImpact();
    Future.delayed(const Duration(milliseconds: 90), HapticFeedback.mediumImpact);
  }

  // ── Input: tap + swipe ────────────────────────────────────
  void _handleTapDown(TapDownDetails d) {
    if (_countdownActive) return;
    if (_controller.engineState != GameEngineState.playing) return;
    final tapX = d.localPosition.dx;
    _audio.playTap();
    _vibrateLight(); // light click on every lane switch
    if (tapX < MediaQuery.of(context).size.width / 2) {
      _controller.onMoveLeft();
    } else {
      _controller.onMoveRight();
    }
  }

  void _handleSwipeStart(DragStartDetails d) {
  }

  void _handleSwipeEnd(DragEndDetails d) {
    if (_countdownActive) return;
    if (_controller.engineState != GameEngineState.playing) return;
    final vel = d.velocity.pixelsPerSecond.dx;
    if (vel.abs() < 200) return; // ignore slow drags
    _audio.playTap();
    _vibrateLight(); // light click on swipe too
    if (vel < 0) {
      _controller.onMoveLeft();
    } else {
      _controller.onMoveRight();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: GameColors.background,
      body: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: _handleTapDown,
        onHorizontalDragStart: _handleSwipeStart,
        onHorizontalDragEnd: _handleSwipeEnd,
        child: Stack(
          children: [
            // Game canvas
            AnimatedBuilder(
              animation: Listenable.merge([_controller, _loopController]),
              builder: (_, __) => CustomPaint(
                painter: GamePainter(controller: _controller, animValue: _loopController.value),
                child: const SizedBox.expand(),
              ),
            ),

            // HUD
            SafeArea(
              child: AnimatedBuilder(
                animation: _controller,
                builder: (_, __) => _buildHUD(),
              ),
            ),

            // Phase badge
            AnimatedBuilder(
              animation: _controller,
              builder: (_, __) => _buildPhaseBadge(),
            ),

            // Combo popup
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
                        color: Colors.black.withOpacity(0.78),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: GameColors.neonBlue, width: 1.5),
                        boxShadow: [BoxShadow(color: GameColors.neonBlue.withOpacity(0.4), blurRadius: 24)],
                      ),
                      child: Column(mainAxisSize: MainAxisSize.min, children: [
                        Text('COMBO ×${_controller.combo}',
                            style: const TextStyle(color: GameColors.neonBlue, fontSize: 22, fontWeight: FontWeight.w800, letterSpacing: 4)),
                        Text('+${GameConstants.comboBonus} BONUS',
                            style: TextStyle(color: Colors.white.withOpacity(0.65), fontSize: 12, letterSpacing: 2)),
                      ]),
                    ),
                  ),
                );
              },
            ),

            // Color change flash
            AnimatedBuilder(
              animation: _controller,
              builder: (_, __) {
                if (!_controller.showColorChangeEffect) return const SizedBox.shrink();
                return Positioned.fill(
                  child: IgnorePointer(
                    child: Container(color: _controller.ballColor.withOpacity(0.2)),
                  ),
                );
              },
            ),

            // Pause overlay
            AnimatedBuilder(
              animation: _controller,
              builder: (_, __) {
                if (_controller.engineState != GameEngineState.paused) return const SizedBox.shrink();
                return _buildPauseOverlay();
              },
            ),

            // ── PHASE UP BANNER ──────────────────────────
            AnimatedBuilder(
              animation: _controller,
              builder: (_, __) {
                if (!_controller.showPhaseUpBanner) return const SizedBox.shrink();
                return _buildPhaseUpBanner();
              },
            ),

            // ── 3-second countdown tutorial ──────────────
            if (_countdownActive) _buildCountdownOverlay(),
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
              decoration: BoxDecoration(color: Colors.black38, shape: BoxShape.circle, border: Border.all(color: Colors.white24)),
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
      bottom: 36, left: 0, right: 0,
      child: Center(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
          decoration: BoxDecoration(
            color: Colors.black38,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: colors[phase - 1].withOpacity(0.35)),
          ),
          child: Text(labels[phase - 1],
              style: TextStyle(color: colors[phase - 1], fontSize: 10, letterSpacing: 3, fontWeight: FontWeight.w700)),
        ),
      ),
    );
  }

  Widget _buildPauseOverlay() {
    return Positioned.fill(
      child: Container(
        color: Colors.black.withOpacity(0.74),
        child: Center(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            const Text('PAUSED', style: TextStyle(fontSize: 38, fontWeight: FontWeight.w800, color: Colors.white, letterSpacing: 8)),
            const SizedBox(height: 36),
            GestureDetector(
              onTap: () { _controller.resume(); _audio.resumeMusic(); },
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
          ]),
        ),
      ),
    );
  }

  Widget _buildPhaseUpBanner() {
    final phase = _controller.currentPhase;
    final colors = [GameColors.neonGreen, GameColors.neonBlue, GameColors.orange, GameColors.red];
    final labels = ['PHASE 2', 'PHASE 3', 'HYPER MODE', 'HYPER MODE'];
    final idx = (phase - 2).clamp(0, 3);
    final color = colors[idx];
    final label = labels[idx];

    return Positioned(
      top: 100,
      left: 0,
      right: 0,
      child: Center(
        child: TweenAnimationBuilder<double>(
          tween: Tween(begin: 0.0, end: 1.0),
          duration: const Duration(milliseconds: 400),
          builder: (_, v, child) => Opacity(
            opacity: v,
            child: Transform.scale(scale: 0.7 + 0.3 * v, child: child),
          ),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.8),
              borderRadius: BorderRadius.circular(30),
              border: Border.all(color: color, width: 1.5),
              boxShadow: [BoxShadow(color: color.withOpacity(0.5), blurRadius: 20, spreadRadius: 2)],
            ),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Icon(Icons.rocket_launch_rounded, color: color, size: 16),
              const SizedBox(width: 8),
              Text(
                '⚡ $label — SPEED UP!',
                style: TextStyle(color: color, fontSize: 13, fontWeight: FontWeight.w800, letterSpacing: 2),
              ),
            ]),
          ),
        ),
      ),
    );
  }

  Widget _buildCountdownOverlay() {
    return Positioned.fill(
      child: Container(
        color: Colors.black.withOpacity(0.82),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Game starts in label
            Text(
              'GET READY',
              style: TextStyle(fontSize: 13, color: Colors.white.withOpacity(0.5), letterSpacing: 5),
            ),
            const SizedBox(height: 24),

            // Big countdown number
            AnimatedBuilder(
              animation: _countdownScale,
              builder: (_, __) => Transform.scale(
                scale: _countdownScale.value,
                child: Text(
                  _countdownValue > 0 ? '$_countdownValue' : 'GO!',
                  style: TextStyle(
                    fontSize: 100,
                    fontWeight: FontWeight.w900,
                    color: _countdownValue > 0 ? GameColors.neonBlue : GameColors.neonGreen,
                    shadows: [
                      Shadow(color: _countdownValue > 0 ? GameColors.neonBlue : GameColors.neonGreen, blurRadius: 30),
                    ],
                  ),
                ),
              ),
            ),

            const SizedBox(height: 40),

            // Tip box
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 400),
              child: Container(
                key: ValueKey(_tipIndex),
                margin: const EdgeInsets.symmetric(horizontal: 36),
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                decoration: BoxDecoration(
                  color: const Color(0xFF0D0D2B),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: GameColors.neonBlue.withOpacity(0.25)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.lightbulb_outline, color: GameColors.neonBlue, size: 18),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        _tips[_tipIndex],
                        style: const TextStyle(color: Colors.white70, fontSize: 13, height: 1.4),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 32),

            // Lane diagram hint
            _buildLaneDiagram(),
          ],
        ),
      ),
    );
  }

  Widget _buildLaneDiagram() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _laneHintBox('LEFT', GameColors.red, '←'),
        const SizedBox(width: 8),
        _laneHintBox('CENTER', GameColors.neonBlue, '●'),
        const SizedBox(width: 8),
        _laneHintBox('RIGHT', GameColors.neonGreen, '→'),
      ],
    );
  }

  Widget _laneHintBox(String label, Color color, String icon) {
    return Column(
      children: [
        Container(
          width: 52, height: 52,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: color, width: 1.5),
            color: color.withOpacity(0.12),
          ),
          child: Center(child: Text(icon, style: TextStyle(color: color, fontSize: 20))),
        ),
        const SizedBox(height: 4),
        Text(label, style: TextStyle(color: color.withOpacity(0.7), fontSize: 8, letterSpacing: 1)),
      ],
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
        Text(value, style: TextStyle(
          fontSize: 28, fontWeight: FontWeight.w800, color: color, letterSpacing: 1,
          shadows: [Shadow(color: color, blurRadius: 14)],
        )),
      ],
    );
  }
}
