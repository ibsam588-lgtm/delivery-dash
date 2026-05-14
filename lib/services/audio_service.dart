import 'package:flame_audio/flame_audio.dart';

/// Wraps FlameAudio so that missing sound files never crash the game.
/// Every method is fire-and-forget and swallows errors silently.
class AudioService {
  static final AudioService instance = AudioService._();
  AudioService._();

  static const _bgm = 'bgm.wav';
  static const _delivery = 'delivery.wav';
  static const _hit = 'hit.wav';
  static const _splash = 'splash.wav';
  static const _pickup = 'pickup.wav';
  static const _levelup = 'levelup.wav';
  static const _gameOver = 'gameover.wav';

  bool _bgmPlaying = false;
  bool _initialized = false;

  Future<void> init() async {
    if (_initialized) return;
    _initialized = true;
    try {
      await FlameAudio.audioCache.loadAll(const [
        _delivery,
        _hit,
        _splash,
        _pickup,
        _levelup,
        _gameOver,
      ]);
    } catch (_) {
      // Files may be missing; play methods will fail silently.
    }
  }

  Future<void> playBgm() async {
    if (_bgmPlaying) return;
    try {
      await FlameAudio.bgm.play(_bgm, volume: 0.45);
      _bgmPlaying = true;
    } catch (_) {}
  }

  Future<void> stopBgm() async {
    if (!_bgmPlaying) return;
    try {
      await FlameAudio.bgm.stop();
    } catch (_) {}
    _bgmPlaying = false;
  }

  void playDelivery() => _play(_delivery);
  void playHit() => _play(_hit);
  void playSplash() => _play(_splash);
  void playPickup() => _play(_pickup);
  void playLevelUp() => _play(_levelup);
  void playGameOver() => _play(_gameOver);

  void _play(String file) {
    try {
      FlameAudio.play(file, volume: 0.8);
    } catch (_) {}
  }
}
