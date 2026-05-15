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
        super(position: position, priority: 150) {
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

// ── Glass shard burst ───────────────────────────────────────────────────────

/// Triangular glass shards that spin and fade — used for broken windows.
class GlassShardBurst extends PositionComponent {
  static final Random _rng = Random();

  final List<_Shard> _shards = [];
  double _life = 0.6;
  static const double _maxLife = 0.6;

  GlassShardBurst({required Vector2 position})
      : super(position: position, priority: 150) {
    final count = 6 + _rng.nextInt(3);
    for (var i = 0; i < count; i++) {
      final ang = _rng.nextDouble() * 2 * pi;
      final speed = 55.0 + _rng.nextDouble() * 110;
      _shards.add(_Shard(
        velocity: Vector2(cos(ang) * speed, sin(ang) * speed),
        spinSpeed: (_rng.nextDouble() - 0.5) * 18.0,
        size: 4.0 + _rng.nextDouble() * 5.0,
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
    for (final s in _shards) {
      s.position += s.velocity * dt;
      s.velocity.y += 120 * dt;
      s.angle += s.spinSpeed * dt;
    }
  }

  @override
  void render(Canvas canvas) {
    final alpha = (_life / _maxLife).clamp(0.0, 1.0);
    final fillPaint = Paint();
    for (final s in _shards) {
      canvas.save();
      canvas.translate(s.position.x, s.position.y);
      canvas.rotate(s.angle);
      final path = Path()
        ..moveTo(0, -s.size * 0.6)
        ..lineTo(s.size * 0.5, s.size * 0.5)
        ..lineTo(-s.size * 0.5, s.size * 0.5)
        ..close();
      fillPaint.color = const Color(0xFFB3E5FC).withValues(alpha: alpha * 0.85);
      canvas.drawPath(path, fillPaint);
      fillPaint.color = const Color(0xFFFFFFFF).withValues(alpha: alpha * 0.5);
      fillPaint.style = PaintingStyle.stroke;
      fillPaint.strokeWidth = 0.8;
      canvas.drawPath(path, fillPaint);
      fillPaint.style = PaintingStyle.fill;
      canvas.restore();
    }
  }
}

class _Shard {
  Vector2 position = Vector2.zero();
  Vector2 velocity;
  double spinSpeed;
  double size;
  double angle = 0;
  _Shard(
      {required this.velocity,
      required this.spinSpeed,
      required this.size});
}

// ── Flying hat / item ───────────────────────────────────────────────────────

/// Small tumbling yellow oval that arcs up then falls — used when a worker
/// or kid-on-bike is hit by a newspaper (hat flies off).
class FlyingHatComponent extends PositionComponent {
  static final Random _rng = Random();

  double _life = 1.0;
  double _spin = 0;
  double _vy = 0;
  double _vx = 0;

  FlyingHatComponent({required Vector2 position})
      : super(position: position, size: Vector2(12, 8), priority: 150) {
    _vy = -130.0 - _rng.nextDouble() * 50;
    _vx = (_rng.nextBool() ? 1 : -1) * (15.0 + _rng.nextDouble() * 25);
  }

  @override
  void update(double dt) {
    super.update(dt);
    _life -= dt;
    if (_life <= 0) {
      removeFromParent();
      return;
    }
    position.y += _vy * dt;
    position.x += _vx * dt;
    _vy += 220 * dt; // gravity
    _spin += 9 * dt;
  }

  @override
  void render(Canvas canvas) {
    final alpha = _life.clamp(0.0, 1.0);
    canvas.save();
    canvas.translate(size.x / 2, size.y / 2);
    canvas.rotate(_spin);
    canvas.translate(-size.x / 2, -size.y / 2);
    canvas.drawOval(
      Rect.fromLTWH(0, 0, size.x, size.y),
      Paint()..color = const Color(0xFFFFD600).withValues(alpha: alpha),
    );
    canvas.drawOval(
      Rect.fromLTWH(0, 0, size.x, size.y),
      Paint()
        ..color = const Color(0xFFB37700).withValues(alpha: alpha)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.0,
    );
    canvas.restore();
  }
}
