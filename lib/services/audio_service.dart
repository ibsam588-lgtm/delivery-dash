import 'package:flame_audio/flame_audio.dart';

class AudioService {
  static final AudioService instance = AudioService._();
  AudioService._();

  static const _delivery = 'delivery.mp3';
  static const _hit = 'hit.mp3';
  static const _gameOver = 'game_over.mp3';
  static const _bgm = 'bgm.mp3';

  bool _bgmPlaying = false;

  Future<void> init() async {
    try {
      await FlameAudio.audioCache.loadAll([_delivery, _hit, _gameOver]);
    } catch (_) {
      // Audio files may be missing; play methods will fail silently.
    }
  }

  void playDelivery() => _play(_delivery);
  void playHit() => _play(_hit);
  void playGameOver() => _play(_gameOver);

  Future<void> playBgm() async {
    if (_bgmPlaying) return;
    try {
      await FlameAudio.bgm.play(_bgm);
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

  void _play(String file) {
    try {
      FlameAudio.play(file);
    } catch (_) {}
  }
}
