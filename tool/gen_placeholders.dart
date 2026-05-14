// ignore_for_file: prefer_const_constructors, prefer_const_declarations
//
// Generates placeholder WAV sound effects under assets/audio/.
// Run with: dart run tool/gen_placeholders.dart
//
// Format: mono 16-bit signed PCM at 22050 Hz. This is the most widely
// supported uncompressed audio format on both Android and iOS audio
// stacks (audioplayers/AVAudioPlayer/MediaPlayer/ExoPlayer all decode
// it without complaint). 8-bit PCM was not reliably playable on Android.
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

class _Sound {
  final String name;
  final double durationSec;
  // List of (start, end, freqHz) segments.
  final List<List<double>> segments;
  const _Sound(this.name, this.durationSec, this.segments);
}

void main() {
  final sounds = <_Sound>[
    _Sound('bgm', 4.0, [
      [0.0, 1.0, 196.0], // G3
      [1.0, 2.0, 246.94], // B3
      [2.0, 3.0, 220.0], // A3
      [3.0, 4.0, 196.0], // G3
    ]),
    _Sound('delivery', 0.30, [
      [0.0, 0.10, 880.0],
      [0.10, 0.30, 1175.0],
    ]),
    _Sound('hit', 0.45, [
      [0.0, 0.45, 130.0],
    ]),
    _Sound('splash', 0.40, [
      [0.0, 0.20, 440.0],
      [0.20, 0.40, 660.0],
    ]),
    _Sound('pickup', 0.30, [
      [0.0, 0.10, 660.0],
      [0.10, 0.20, 880.0],
      [0.20, 0.30, 1175.0],
    ]),
    _Sound('levelup', 0.55, [
      [0.0, 0.15, 523.0],
      [0.15, 0.30, 659.0],
      [0.30, 0.45, 784.0],
      [0.45, 0.55, 1046.0],
    ]),
    _Sound('gameover', 1.0, [
      [0.0, 0.35, 220.0],
      [0.35, 0.70, 175.0],
      [0.70, 1.0, 110.0],
    ]),
  ];

  Directory('assets/audio').createSync(recursive: true);
  for (final s in sounds) {
    final path = 'assets/audio/${s.name}.wav';
    File(path).writeAsBytesSync(_buildWav(s));
    stdout.writeln('wrote $path');
  }
  final keep = File('assets/audio/.gitkeep');
  if (!keep.existsSync()) keep.writeAsStringSync('');
}

Uint8List _buildWav(_Sound s) {
  const sampleRate = 22050;
  const bitsPerSample = 16;
  const channels = 1;
  final totalSamples = (sampleRate * s.durationSec).round();

  final pcm = Int16List(totalSamples);
  for (var i = 0; i < totalSamples; i++) {
    final t = i / sampleRate;
    final freq = _freqAt(s, t);
    final raw = sin(2 * pi * freq * t);
    final env = _envelope(t, s.durationSec);
    // ~25% of full scale so audio isn't ear-splitting.
    final amp = (raw * env * 8000).round();
    pcm[i] = amp.clamp(-32768, 32767);
  }

  final byteRate = sampleRate * channels * bitsPerSample ~/ 8;
  final blockAlign = channels * bitsPerSample ~/ 8;
  final dataBytes = pcm.lengthInBytes;
  final fileSize = 36 + dataBytes;

  final out = BytesBuilder();
  out.add(_ascii('RIFF'));
  out.add(_u32(fileSize));
  out.add(_ascii('WAVE'));
  out.add(_ascii('fmt '));
  out.add(_u32(16));
  out.add(_u16(1)); // PCM
  out.add(_u16(channels));
  out.add(_u32(sampleRate));
  out.add(_u32(byteRate));
  out.add(_u16(blockAlign));
  out.add(_u16(bitsPerSample));
  out.add(_ascii('data'));
  out.add(_u32(dataBytes));
  out.add(pcm.buffer.asUint8List());
  return out.toBytes();
}

double _freqAt(_Sound s, double t) {
  for (final seg in s.segments) {
    if (t >= seg[0] && t < seg[1]) return seg[2];
  }
  return s.segments.last[2];
}

double _envelope(double t, double dur) {
  const fade = 0.02;
  if (t < fade) return t / fade;
  if (t > dur - fade) return (dur - t) / fade;
  return 1.0;
}

List<int> _ascii(String s) => s.codeUnits;
List<int> _u16(int v) => [v & 0xFF, (v >> 8) & 0xFF];
List<int> _u32(int v) =>
    [v & 0xFF, (v >> 8) & 0xFF, (v >> 16) & 0xFF, (v >> 24) & 0xFF];
