// Generates placeholder WAV sound effects under assets/audio/.
//
// Run with: dart run tool/gen_placeholders.dart
//
// Each file is mono, 8-bit unsigned PCM at 8000 Hz. Tiny and universally
// playable. Replace with real sounds whenever those are available.
// ignore_for_file: prefer_const_constructors, prefer_const_declarations
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

class _Sound {
  final String name;
  final double durationSec;
  // A sequence of (start time, end time, frequency Hz) segments.
  final List<List<double>> segments;
  const _Sound(this.name, this.durationSec, this.segments);
}

void main() {
  final sounds = <_Sound>[
    // BGM: steady low drone.
    _Sound('bgm', 2.0, [
      [0.0, 2.0, 220.0],
    ]),
    // Delivery: bright high blip.
    _Sound('delivery', 0.30, [
      [0.0, 0.30, 880.0],
    ]),
    // Hit: low thud.
    _Sound('hit', 0.50, [
      [0.0, 0.50, 150.0],
    ]),
    // Splash: two-tone burst.
    _Sound('splash', 0.40, [
      [0.0, 0.20, 440.0],
      [0.20, 0.40, 660.0],
    ]),
    // Pickup: rising chirp.
    _Sound('pickup', 0.30, [
      [0.0, 0.15, 550.0],
      [0.15, 0.30, 880.0],
    ]),
    // Level up: C-E-G arpeggio.
    _Sound('levelup', 0.45, [
      [0.0, 0.15, 523.0],
      [0.15, 0.30, 659.0],
      [0.30, 0.45, 784.0],
    ]),
    // Game over: descending tone.
    _Sound('gameover', 1.00, [
      [0.0, 0.50, 220.0],
      [0.50, 1.00, 110.0],
    ]),
  ];

  final outDir = Directory('assets/audio');
  outDir.createSync(recursive: true);

  for (final s in sounds) {
    final path = 'assets/audio/${s.name}.wav';
    File(path).writeAsBytesSync(_buildWav(s));
    stdout.writeln('wrote $path');
  }
  // Keep .gitkeep so the directory exists even if assets are stripped.
  final keep = File('assets/audio/.gitkeep');
  if (!keep.existsSync()) keep.writeAsStringSync('');
}

Uint8List _buildWav(_Sound s) {
  const sampleRate = 8000;
  final totalSamples = (sampleRate * s.durationSec).round();

  // Build PCM samples first.
  final samples = Uint8List(totalSamples);
  for (var i = 0; i < totalSamples; i++) {
    final t = i / sampleRate;
    final freq = _freqAt(s, t);
    final raw = sin(2 * pi * freq * t);
    // Simple AR envelope so we don't click at the edges.
    final envelope = _envelope(t, s.durationSec);
    final amp = raw * envelope * 100;
    // Unsigned 8-bit center = 128.
    final v = (amp + 128).round().clamp(0, 255);
    samples[i] = v;
  }

  final byteRate = sampleRate * 1; // mono, 1 byte/sample
  final headerSize = 44;
  final dataSize = samples.length;
  final fileSize = headerSize - 8 + dataSize;

  final out = BytesBuilder();
  // RIFF header
  out.add(_ascii('RIFF'));
  out.add(_u32(fileSize));
  out.add(_ascii('WAVE'));
  // fmt chunk
  out.add(_ascii('fmt '));
  out.add(_u32(16)); // PCM chunk size
  out.add(_u16(1));  // PCM format
  out.add(_u16(1));  // channels
  out.add(_u32(sampleRate));
  out.add(_u32(byteRate));
  out.add(_u16(1));  // block align
  out.add(_u16(8));  // bits per sample
  // data chunk
  out.add(_ascii('data'));
  out.add(_u32(dataSize));
  out.add(samples);
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

List<int> _u32(int v) => [
      v & 0xFF,
      (v >> 8) & 0xFF,
      (v >> 16) & 0xFF,
      (v >> 24) & 0xFF,
    ];
