import 'package:flame_audio/flame_audio.dart';

/// Wraps FlameAudio so missing sound files never crash the game.
/// All play methods are fire-and-forget; failures are swallowed.
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
      // Wires Bgm into Flutter's app lifecycle (pause on background,
      // resume on foreground) and prepares the BGM audio player.
      FlameAudio.bgm.initialize();
    } catch (_) {}
    try {
      // Preload everything (BGM included). loadAll caches the file
      // bytes so the first play() doesn't stall on a network/asset
      // resolve and so we surface any decoder errors up front.
      await FlameAudio.audioCache.loadAll(const [
        _bgm,
        _delivery,
        _hit,
        _splash,
        _pickup,
        _levelup,
        _gameOver,
      ]);
    } catch (_) {
      // Files may be missing on dev builds; play methods will fail
      // silently if so.
    }
  }

  Future<void> playBgm() async {
    if (_bgmPlaying) return;
    _bgmPlaying = true;
    try {
      await FlameAudio.bgm.play(_bgm, volume: 0.5);
    } catch (_) {
      _bgmPlaying = false;
    }
  }

  Future<void> stopBgm() async {
    if (!_bgmPlaying) return;
    _bgmPlaying = false;
    try {
      await FlameAudio.bgm.stop();
    } catch (_) {}
  }

  Future<void> pauseBgm() async {
    if (!_bgmPlaying) return;
    try {
      await FlameAudio.bgm.pause();
    } catch (_) {}
  }

  Future<void> resumeBgm() async {
    if (!_bgmPlaying) return;
    try {
      await FlameAudio.bgm.resume();
    } catch (_) {}
  }

  void playDelivery() => _play(_delivery);
  void playHit() => _play(_hit);
  void playWindowSmash() => _play(_hit);
  void playSplash() => _play(_splash);
  void playPickup() => _play(_pickup);
  void playLevelUp() => _play(_levelup);
  void playGameOver() => _play(_gameOver);

  /// Plays a window-smash sound. There is no dedicated glass file, so we
  /// reuse the impact "hit" sample — fails silently if asset missing.
  void playWindowSmash() => _play(_hit);

  void _play(String file) {
    try {
      FlameAudio.play(file, volume: 0.8);
    } catch (_) {}
  }
}
