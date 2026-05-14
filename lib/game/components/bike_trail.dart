import 'dart:ui';
import 'package:flame/components.dart';

/// Single dust-puff sprite emitted behind the bike. Fades and grows as
/// it dies.
class BikeTrailPuff extends PositionComponent {
  double _life = 0.45;
  static const double _maxLife = 0.45;

  BikeTrailPuff({required Vector2 position})
      : super(
          position: position,
          anchor: Anchor.center,
          size: Vector2.all(10),
          priority: 4,
        );

  @override
  void update(double dt) {
    super.update(dt);
    _life -= dt;
    if (_life <= 0) {
      removeFromParent();
      return;
    }
    size += Vector2.all(20 * dt);
    position.y += 30 * dt;
  }

  @override
  void render(Canvas canvas) {
    final alpha = (_life / _maxLife).clamp(0.0, 1.0);
    canvas.drawCircle(
      Offset(size.x / 2, size.y / 2),
      size.x / 2,
      Paint()..color = const Color(0xFFB5A682).withValues(alpha: alpha * 0.4),
    );
  }
}
