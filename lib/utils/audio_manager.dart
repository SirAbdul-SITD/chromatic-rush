import 'package:audioplayers/audioplayers.dart';
import 'settings_manager.dart';

class AudioManager {
  static final AudioManager _instance = AudioManager._internal();
  factory AudioManager() => _instance;
  AudioManager._internal();

  final AudioPlayer _sfxPlayer = AudioPlayer();
  final AudioPlayer _musicPlayer = AudioPlayer();

  SettingsManager? _settings;

  void init(SettingsManager settings) {
    _settings = settings;
  }

  Future<void> playTap() async {
    if (_settings?.soundEnabled ?? true) {
      // In production, load from assets
      // await _sfxPlayer.play(AssetSource('sounds/tap.mp3'));
    }
  }

  Future<void> playCorrectPass() async {
    if (_settings?.soundEnabled ?? true) {
      // await _sfxPlayer.play(AssetSource('sounds/pass.mp3'));
    }
  }

  Future<void> playLose() async {
    if (_settings?.soundEnabled ?? true) {
      // await _sfxPlayer.play(AssetSource('sounds/lose.mp3'));
    }
  }

  Future<void> playCombo() async {
    if (_settings?.soundEnabled ?? true) {
      // await _sfxPlayer.play(AssetSource('sounds/combo.mp3'));
    }
  }

  Future<void> startMusic() async {
    if (_settings?.musicEnabled ?? true) {
      // await _musicPlayer.play(AssetSource('sounds/music.mp3'));
      // await _musicPlayer.setReleaseMode(ReleaseMode.loop);
    }
  }

  Future<void> stopMusic() async {
    await _musicPlayer.stop();
  }

  Future<void> pauseMusic() async {
    await _musicPlayer.pause();
  }

  Future<void> resumeMusic() async {
    if (_settings?.musicEnabled ?? true) {
      await _musicPlayer.resume();
    }
  }

  void dispose() {
    _sfxPlayer.dispose();
    _musicPlayer.dispose();
  }
}
