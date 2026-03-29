import 'package:audioplayers/audioplayers.dart';
import 'settings_manager.dart';

class AudioManager {
  static final AudioManager _instance = AudioManager._internal();
  factory AudioManager() => _instance;
  AudioManager._internal();

  final List<AudioPlayer> _sfxPool = List.generate(5, (_) => AudioPlayer());
  int _sfxIdx = 0;

  final AudioPlayer _musicPlayer = AudioPlayer();
  int _currentMusicPhase = 0; // 0=none, 1-4=phase
  bool _musicActive = false;

  SettingsManager? _settings;

  static const _musicAssets = {
    1: 'sounds/music_p1.mp3',
    2: 'sounds/music_p2.mp3',
    3: 'sounds/music_p3.mp3',
    4: 'sounds/music_p4.mp3',
  };

  Future<void> init(SettingsManager settings) async {
    _settings = settings;
    await _musicPlayer.setReleaseMode(ReleaseMode.loop);
    await _musicPlayer.setVolume(0.5);
    for (final p in _sfxPool) {
      await p.setVolume(0.75);
    }
  }

  AudioPlayer get _nextSfx {
    final p = _sfxPool[_sfxIdx % _sfxPool.length];
    _sfxIdx++;
    return p;
  }

  // ── SFX ───────────────────────────────────────────────────
  Future<void> playTap() async {
    if (!(_settings?.soundEnabled ?? true)) return;
    try { await _nextSfx.play(AssetSource('sounds/tap.mp3'), volume: 0.6); } catch (_) {}
  }

  Future<void> playCorrectPass() async {
    if (!(_settings?.soundEnabled ?? true)) return;
    try { await _nextSfx.play(AssetSource('sounds/pass.mp3'), volume: 0.75); } catch (_) {}
  }

  Future<void> playLose() async {
    if (!(_settings?.soundEnabled ?? true)) return;
    try { await _nextSfx.play(AssetSource('sounds/lose.mp3'), volume: 0.9); } catch (_) {}
  }

  Future<void> playCombo() async {
    if (!(_settings?.soundEnabled ?? true)) return;
    try { await _nextSfx.play(AssetSource('sounds/combo.mp3'), volume: 0.85); } catch (_) {}
  }

  // ── Music with phase switching ─────────────────────────────
  Future<void> startMusic({int phase = 1}) async {
    if (!(_settings?.musicEnabled ?? true)) return;
    _musicActive = true;
    _currentMusicPhase = phase;
    final asset = _musicAssets[phase] ?? _musicAssets[1]!;
    try {
      await _musicPlayer.stop();
      await _musicPlayer.play(AssetSource(asset));
    } catch (_) {}
  }

  /// Call this when the game phase changes — seamlessly switches track
  Future<void> setMusicPhase(int phase) async {
    if (!_musicActive) return;
    if (phase == _currentMusicPhase) return;
    if (!(_settings?.musicEnabled ?? true)) return;
    _currentMusicPhase = phase;
    final asset = _musicAssets[phase] ?? _musicAssets[4]!;
    try {
      // Get current position to attempt seamless ish switch
      await _musicPlayer.stop();
      await _musicPlayer.play(AssetSource(asset));
    } catch (_) {}
  }

  Future<void> stopMusic() async {
    _musicActive = false;
    _currentMusicPhase = 0;
    try { await _musicPlayer.stop(); } catch (_) {}
  }

  Future<void> pauseMusic() async {
    try { await _musicPlayer.pause(); } catch (_) {}
  }

  Future<void> resumeMusic() async {
    if (!(_settings?.musicEnabled ?? true)) return;
    try { await _musicPlayer.resume(); } catch (_) {}
  }

  Future<void> disposeAll() async {
    for (final p in _sfxPool) { await p.dispose(); }
    await _musicPlayer.dispose();
  }
}
