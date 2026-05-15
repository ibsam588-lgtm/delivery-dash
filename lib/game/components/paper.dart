import 'dart:math';
import 'dart:ui';
import 'package:flame/collisions.dart';
import 'package:flame/components.dart';
import '../delivery_dash_game.dart';
import 'house_window.dart';
import 'mailbox.dart';
import 'obstacle.dart';
import 'parked_car.dart';

/// Flying rolled-up newspaper. Arcs toward the upper-left or upper-right
/// depending on the throw direction. Spins visibly.
class PaperComponent extends PositionComponent
    with HasGameRef<DeliveryDashGame>, CollisionCallbacks {
  static const double _baseSpeed = 540.0;
  static const double _spinPerSec = 12.0;

  // Throw direction in degrees, measured from straight up (negative = left).
  static const double _throwAngleDeg = -38.0;

  final Vector2 _velocity;
  bool _hasHit = false;
  double _life = 1.6;

  PaperComponent({
    required Vector2 startPosition,
    double angleDeg = _throwAngleDeg,
  })  : _velocity = _initialVelocity(angleDeg),
        super(
          size: Vector2(34, 18),
          anchor: Anchor.center,
          position: startPosition,
          priority: 6,
        );

  static Vector2 _initialVelocity(double angleDeg) {
    final rad = angleDeg * pi / 180.0;
    return Vector2(_baseSpeed * sin(rad), -_baseSpeed * cos(rad));
  }

  @override
  Future<void> onLoad() async {
    add(RectangleHitbox(size: size * 0.8, position: size * 0.1));
  }

  @override
  void update(double dt) {
    super.update(dt);
    _life -= dt;
    if (_life <= 0) {
      removeFromParent();
      return;
    }

    position += _velocity * dt;
    angle += _spinPerSec * dt;

    if (position.y < -size.y ||
        position.x < -size.x ||
        position.x > gameRef.size.x + size.x ||
        position.y > gameRef.size.y + size.y) {
      removeFromParent();
    }
  }

  @override
  void render(Canvas canvas) {
    final w = size.x;
    final h = size.y;

    // Drop shadow — flat oval beneath the cylinder.
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(w * 0.5, h * 1.05),
        width: w * 0.85,
        height: h * 0.35,
      ),
      Paint()..color = const Color(0x55000000),
    );

    // ── Rolled newspaper as a horizontal cylinder ──────────────────────────
    // Cylinder body (rectangle between the two end caps).
    final bodyRect = Rect.fromLTRB(w * 0.15, h * 0.10, w * 0.85, h * 0.90);
    canvas.drawRect(
      bodyRect,
      Paint()
        ..shader = Gradient.linear(
          bodyRect.topLeft,
          bodyRect.topRight,
          [const Color(0xFFF0EBD0), const Color(0xFFE8E2C0)],
        ),
    );

    // Back end cap (right side, slightly darker).
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(w * 0.85, h * 0.50),
        width: w * 0.20,
        height: h * 0.80,
      ),
      Paint()..color = const Color(0xFFE0DAB8),
    );

    // Front face — main circular cross-section (cream).
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(w * 0.15, h * 0.50),
        width: w * 0.22,
        height: h * 0.80,
      ),
      Paint()..color = const Color(0xFFF5F0D8),
    );
    // Inner roll spiral (suggests the rolled-paper end).
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(w * 0.15, h * 0.50),
        width: w * 0.14,
        height: h * 0.52,
      ),
      Paint()
        ..color = const Color(0xFFC8C2A0)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0.8,
    );
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(w * 0.15, h * 0.50),
        width: w * 0.08,
        height: h * 0.30,
      ),
      Paint()
        ..color = const Color(0xFFB0A878)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0.7,
    );

    // Rubber band: two parallel red lines around the cylinder middle.
    final bandPaint = Paint()
      ..color = const Color(0xFFCC2020)
      ..strokeWidth = 2.0;
    canvas.drawLine(
      Offset(w * 0.18, h * 0.46),
      Offset(w * 0.82, h * 0.46),
      bandPaint,
    );
    canvas.drawLine(
      Offset(w * 0.18, h * 0.56),
      Offset(w * 0.82, h * 0.56),
      bandPaint,
    );

    // Headline text suggestion: 3 thin dark lines on the surface.
    final textPaint = Paint()
      ..color = const Color(0xFF7A7060)
      ..strokeWidth = 1.0;
    for (final ty in const [0.22, 0.32, 0.72]) {
      canvas.drawLine(
        Offset(w * 0.25, h * ty),
        Offset(w * 0.75, h * ty),
        textPaint,
      );
    }
  }

  @override
  void onCollisionStart(
      Set<Vector2> intersectionPoints, PositionComponent other) {
    super.onCollisionStart(intersectionPoints, other);
    if (_hasHit) return;
    if (other is MailboxComponent) {
      _hasHit = true;
      final worldHit = other.absolutePosition.clone();
      gameRef.onPaperHitMailbox(other.isBlue, worldHit);
      other.removeFromParent();
      removeFromParent();
      return;
    }
    if (other is ObstacleComponent) {
      _hasHit = true;
      final worldHit = other.absolutePosition.clone();
      gameRef.onPaperHitObstacle(other, worldHit);
      removeFromParent();
      return;
    }
    if (other is ParkedCarComponent) {
      _hasHit = true;
      final worldHit = other.absolutePosition.clone();
      gameRef.onPaperHitParkedCar(other, worldHit);
      removeFromParent();
      return;
    }
    if (other is HouseWindow) {
      if (other.broken) return;
      _hasHit = true;
      final worldHit = other.absolutePosition.clone();
      gameRef.onPaperHitWindow(other, worldHit);
      removeFromParent();
      return;
    }
  }
}
