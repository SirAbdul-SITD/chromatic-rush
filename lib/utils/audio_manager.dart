import 'package:audioplayers/audioplayers.dart';
import 'settings_manager.dart';

class AudioManager {
  static final AudioManager _instance = AudioManager._internal();
  factory AudioManager() => _instance;
  AudioManager._internal();

  // Use a pool of SFX players so rapid sounds don't cut each other off
  final List<AudioPlayer> _sfxPool = List.generate(4, (_) => AudioPlayer());
  int _sfxPoolIndex = 0;

  final AudioPlayer _musicPlayer = AudioPlayer();
  bool _musicStarted = false;

  SettingsManager? _settings;

  Future<void> init(SettingsManager settings) async {
    _settings = settings;
    // Pre-configure music player for looping
    await _musicPlayer.setReleaseMode(ReleaseMode.loop);
    await _musicPlayer.setVolume(0.45);
    for (final p in _sfxPool) {
      await p.setVolume(0.75);
    }
  }

  // Round-robin SFX player so overlapping sounds don't cancel
  AudioPlayer get _nextSfx {
    final p = _sfxPool[_sfxPoolIndex % _sfxPool.length];
    _sfxPoolIndex++;
    return p;
  }

  Future<void> playTap() async {
    if (!(_settings?.soundEnabled ?? true)) return;
    try {
      await _nextSfx.play(AssetSource('sounds/tap.mp3'), volume: 0.6);
    } catch (_) {}
  }

  Future<void> playCorrectPass() async {
    if (!(_settings?.soundEnabled ?? true)) return;
    try {
      await _nextSfx.play(AssetSource('sounds/pass.mp3'), volume: 0.75);
    } catch (_) {}
  }

  Future<void> playLose() async {
    if (!(_settings?.soundEnabled ?? true)) return;
    try {
      await _nextSfx.play(AssetSource('sounds/lose.mp3'), volume: 0.85);
    } catch (_) {}
  }

  Future<void> playCombo() async {
    if (!(_settings?.soundEnabled ?? true)) return;
    try {
      await _nextSfx.play(AssetSource('sounds/combo.mp3'), volume: 0.8);
    } catch (_) {}
  }

  Future<void> startMusic() async {
    if (!(_settings?.musicEnabled ?? true)) return;
    if (_musicStarted) return;
    try {
      _musicStarted = true;
      await _musicPlayer.play(AssetSource('sounds/music.mp3'));
    } catch (_) {}
  }

  Future<void> stopMusic() async {
    _musicStarted = false;
    try {
      await _musicPlayer.stop();
    } catch (_) {}
  }

  Future<void> pauseMusic() async {
    try {
      await _musicPlayer.pause();
    } catch (_) {}
  }

  Future<void> resumeMusic() async {
    if (!(_settings?.musicEnabled ?? true)) return;
    try {
      await _musicPlayer.resume();
    } catch (_) {}
  }

  Future<void> dispose() async {
    for (final p in _sfxPool) {
      await p.dispose();
    }
    await _musicPlayer.dispose();
  }
}
