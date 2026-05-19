import 'package:flame_audio/flame_audio.dart';
import 'package:flutter/widgets.dart';

/// Wraps FlameAudio so missing sound files never crash the game.
/// All play methods are fire-and-forget; failures are swallowed.
class AudioService with WidgetsBindingObserver {
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

  // _bgmDesired tracks the user's intent: true when the user wants the
  // soundtrack on (i.e. between playBgm() and stopBgm()). It stays true
  // across pauseBgm()/resumeBgm() and across app lifecycle transitions,
  // because flame_audio's built-in observer can leave the underlying
  // AudioPlayer paused without resuming (e.g. after Android audio focus
  // loss). We use this flag from our own lifecycle observer to force a
  // restart of the BGM when the app comes back to the foreground.
  bool _bgmDesired = false;
  bool _initialized = false;
  bool _hasNewBgm = false;
  bool _hasWindowSmash = false;
  bool _lifecycleObserverRegistered = false;
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

    if (!_lifecycleObserverRegistered) {
      try {
        WidgetsBinding.instance.addObserver(this);
        _lifecycleObserverRegistered = true;
      } catch (_) {}
    }

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

  Future<void> _startBgm() async {
    try {
      await FlameAudio.bgm.play(_hasNewBgm ? _bgm : _fallbackBgm, volume: 0.58);
    } catch (_) {}
  }

  Future<void> playBgm({bool fromUserGesture = false}) async {
    await init();
    _bgmDesired = true;
    // If flame_audio thinks the BGM is already playing, just make sure it's
    // not paused. Otherwise start a fresh playback. This handles cases where
    // an OS interruption (audio focus loss, headphone unplug, lifecycle
    // transient) left the underlying player paused or stopped.
    if (FlameAudio.bgm.isPlaying) {
      try {
        await FlameAudio.bgm.resume();
      } catch (_) {}
      return;
    }
    await _startBgm();
  }

  Future<void> stopBgm() async {
    if (!_bgmDesired) return;
    _bgmDesired = false;
    try {
      await FlameAudio.bgm.stop();
    } catch (_) {}
  }

  Future<void> pauseBgm() async {
    if (!_bgmDesired) return;
    try {
      await FlameAudio.bgm.pause();
    } catch (_) {}
  }

  Future<void> resumeBgm() async {
    if (!_bgmDesired) return;
    try {
      await FlameAudio.bgm.resume();
    } catch (_) {}
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // flame_audio's Bgm installs its own observer that pauses on every
    // non-resumed state and only resumes if the internal isPlaying flag and
    // audioPlayer.state line up exactly. In practice Android audio focus
    // changes (notification pulldown, brief interruptions, SFX taking focus)
    // can leave the player in a state where the auto-resume silently no-ops,
    // killing music for the rest of the run. Our observer is a safety net:
    // whenever the app returns to the foreground and the user's intent is
    // to keep music on, force a resume — and if that doesn't kick the player
    // back to playing, start a fresh BGM playback.
    if (state != AppLifecycleState.resumed) return;
    if (!_bgmDesired) return;
    () async {
      try {
        await FlameAudio.bgm.resume();
      } catch (_) {}
      if (!FlameAudio.bgm.isPlaying) {
        await _startBgm();
      }
    }();
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
