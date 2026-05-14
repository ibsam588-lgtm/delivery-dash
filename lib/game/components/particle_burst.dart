import 'dart:math';
import 'dart:ui';
import 'package:flame/components.dart';

/// Pixel-style spark burst at [position]. Used for paper hits, dust trail,
/// and other one-shot impact reactions. Renders as a handful of tiny
/// bright squares that fly outward and fade.
class ParticleBurst extends PositionComponent {
  static final Random _rng = Random();

  final List<_Particle> _parts = [];
  double _life;
  final double _maxLife;

  ParticleBurst({
    required Vector2 position,
    int count = 10,
    double spread = 90,
    Color color = const Color(0xFFFFEB3B),
    Color color2 = const Color(0xFFFFFFFF),
    double maxLife = 0.45,
    double pixelSize = 4,
  })  : _life = maxLife,
        _maxLife = maxLife,
        super(position: position, priority: 25) {
    for (var i = 0; i < count; i++) {
      final ang = _rng.nextDouble() * 2 * pi;
      final speed = spread * (0.4 + _rng.nextDouble() * 0.8);
      final c = _rng.nextBool() ? color : color2;
      _parts.add(_Particle(
        velocity: Vector2(cos(ang) * speed, sin(ang) * speed),
        color: c,
        size: pixelSize * (0.7 + _rng.nextDouble() * 0.6),
      ));
    }
  }

  @override
  void update(double dt) {
    super.update(dt);
    _life -= dt;
    if (_life <= 0) {
      removeFromParent();
      return;
    }
    for (final p in _parts) {
      p.position += p.velocity * dt;
      p.velocity.y += 140 * dt; // gravity
      p.velocity *= (1 - 1.2 * dt).clamp(0.0, 1.0);
    }
  }

  @override
  void render(Canvas canvas) {
    final alpha = (_life / _maxLife).clamp(0.0, 1.0);
    final paint = Paint();
    for (final p in _parts) {
      paint.color = p.color.withValues(alpha: alpha);
      final s = p.size;
      canvas.drawRect(
        Rect.fromLTWH(p.position.x - s / 2, p.position.y - s / 2, s, s),
        paint,
      );
    }
  }
}

class _Particle {
  Vector2 position = Vector2.zero();
  Vector2 velocity;
  final Color color;
  final double size;
  _Particle({required this.velocity, required this.color, required this.size});
}
