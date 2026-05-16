import 'package:flutter/services.dart';

/// Small native cue used alongside the audio asset for glass/window hits.
/// This keeps the feedback audible even when the bundled wav is quiet or absent.
class GlassSoundService {
  const GlassSoundService._();

  static void playCue() {
    try {
      SystemSound.play(SystemSoundType.click);
      Future<void>.delayed(const Duration(milliseconds: 60), () {
        SystemSound.play(SystemSoundType.alert);
      });
    } catch (_) {}
  }
}
