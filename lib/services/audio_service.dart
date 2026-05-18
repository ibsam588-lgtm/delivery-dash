import 'package:flame_audio/flame_audio.dart';

/// Wraps FlameAudio so missing sound files never crash the game.
/// All play methods are fire-and-forget; failures are swallowed.
class AudioService {
  static final AudioService instance = AudioService._();
  AudioService._();

  // Keep filenames simple so replacement with better production audio is easy.
  static const _bgm = 'paperboy_bgm.wav';
  static const _fallbackBgm = 'bgm.wav';
  static const _delivery = 'delivery.wav';
  static const _hit = 'hit.wav';
  static const _windowSmash = 'window_smash.wav';
  static const _splash = 'splash.wav';
  static const _pickup = 'pickup.wav';
  static const _levelup = 'levelup.wav';
  static const _gameOver = 'gameover.wav';

  bool _bgmPlaying = false;
  bool _initialized = false;
  bool _hasNewBgm = false;
  bool _hasWindowSmash = false;
  Future<void>? _initFuture;

  Future<void> init() {
    if (_initialized) return Future<void>.value();
    final pending = _initFuture;
    if (pending != null) return pending;
    _initFuture = _doInit();
    return _initFuture!;
  }

  Future<void> _doInit() async {
    try {
      FlameAudio.bgm.initialize();
    } catch (_) {}

    // Load required legacy files first.
    try {
      await FlameAudio.audioCache.loadAll(const [
        _fallbackBgm,
        _delivery,
        _hit,
        _splash,
        _pickup,
        _levelup,
        _gameOver,
      ]);
    } catch (_) {}

    // Optional upgraded files. If they do not exist yet, the game falls back
    // without crashing. Drop replacement assets into assets/audio/ with these
    // filenames to improve music/SFX without code changes.
    try {
      await FlameAudio.audioCache.load(_bgm);
      _hasNewBgm = true;
    } catch (_) {
      _hasNewBgm = false;
    }
    try {
      await FlameAudio.audioCache.load(_windowSmash);
      _hasWindowSmash = true;
    } catch (_) {
      _hasWindowSmash = false;
    }
    _initialized = true;
  }

  Future<void> playBgm({bool fromUserGesture = false}) async {
    await init();
    if (_bgmPlaying) {
      try {
        await FlameAudio.bgm.resume();
      } catch (_) {}
      return;
    }
    _bgmPlaying = true;
    try {
      await FlameAudio.bgm.play(_hasNewBgm ? _bgm : _fallbackBgm, volume: 0.58);
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

  void playDelivery() => _play(_delivery, volume: 0.85);
  void playHit() => _play(_hit, volume: 0.8);
  void playWindowSmash() =>
      _play(_hasWindowSmash ? _windowSmash : _hit, volume: 1.0);
  void playSplash() => _play(_splash, volume: 0.8);
  void playPickup() => _play(_pickup, volume: 0.8);
  void playLevelUp() => _play(_levelup, volume: 0.85);
  void playGameOver() => _play(_gameOver, volume: 0.8);

  void _play(String file, {double volume = 0.8}) {
    init().then<void>((_) {
      try {
        FlameAudio.play(file, volume: volume);
      } catch (_) {}
    }).catchError((_) {});
  }
}
