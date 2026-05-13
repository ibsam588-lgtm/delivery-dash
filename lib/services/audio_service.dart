import 'package:flame_audio/flame_audio.dart';

class AudioService {
  static final AudioService instance = AudioService._();
  AudioService._();

  bool _available = false;

  Future<void> init() async {
    try {
      await FlameAudio.audioCache.loadAll([
        'throw.mp3',
        'hit.mp3',
        'miss.mp3',
        'hurt.mp3',
        'gameover.mp3',
      ]);
      _available = true;
    } catch (_) {
      _available = false;
    }
  }

  void playThrow() => _play('throw.mp3');
  void playHit() => _play('hit.mp3');
  void playMiss() => _play('miss.mp3');
  void playHurt() => _play('hurt.mp3');
  void playGameOver() => _play('gameover.mp3');

  void _play(String name) {
    if (!_available) return;
    try {
      FlameAudio.play(name);
    } catch (_) {}
  }
}
