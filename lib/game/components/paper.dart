import 'dart:math';
import 'dart:ui';
import 'package:flame/collisions.dart';
import 'package:flame/components.dart';
import '../delivery_dash_game.dart';
import 'house.dart';
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

    // Shadow.
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(w * 0.5, h * 0.92),
        width: w * 0.7,
        height: h * 0.12,
      ),
      Paint()..color = const Color(0x66000000),
    );

    // Cylinder body.
    final bodyRect = Rect.fromLTRB(w * 0.12, h * 0.28, w * 0.88, h * 0.82);
    canvas.drawRect(
      bodyRect,
      Paint()
        ..shader = Gradient.linear(
          Offset(w * 0.12, 0),
          Offset(w * 0.88, 0),
          [
            const Color(0xFFF5F0D8),
            const Color(0xFFE8E2C0),
            const Color(0xFFF5F0D8),
          ],
          [0.0, 0.5, 1.0],
        ),
    );

    // Front circular face of cylinder.
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(w * 0.5, h * 0.28),
        width: w * 0.76,
        height: h * 0.22,
      ),
      Paint()..color = const Color(0xFFF0EBD0),
    );
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(w * 0.5, h * 0.28),
        width: w * 0.76,
        height: h * 0.22,
      ),
      Paint()
        ..color = const Color(0xFF8A7E60)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1,
    );

    // Back circular face.
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(w * 0.5, h * 0.82),
        width: w * 0.76,
        height: h * 0.22,
      ),
      Paint()..color = const Color(0xFFDDD6B0),
    );

    // Body outline.
    canvas.drawRect(
      bodyRect,
      Paint()
        ..color = const Color(0xFF8A7E60)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1,
    );

    // Red rubber bands (2).
    final bandPaint = Paint()
      ..color = const Color(0xFFCC1010)
      ..strokeWidth = 2.5
      ..strokeCap = StrokeCap.round;
    for (final yFrac in [0.45, 0.65]) {
      canvas.drawLine(
        Offset(w * 0.12, h * yFrac),
        Offset(w * 0.88, h * yFrac),
        bandPaint,
      );
      canvas.drawOval(
        Rect.fromCenter(
          center: Offset(w * 0.5, h * yFrac),
          width: w * 0.76,
          height: h * 0.10,
        ),
        Paint()
          ..color = const Color(0xFFCC1010)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.0,
      );
    }

    // Text lines on body.
    final textPaint = Paint()
      ..color = const Color(0xFF9A9070)
      ..strokeWidth = 1.2;
    for (final yFrac in [0.50, 0.56, 0.70, 0.76]) {
      canvas.drawLine(
        Offset(w * 0.20, h * yFrac),
        Offset(w * 0.80, h * yFrac),
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
      if (other.delivered) return;
      _hasHit = true;
      final worldHit = other.absolutePosition.clone();
      gameRef.onPaperHitMailbox(other.isBlue, worldHit);
      other.markDelivered();
      removeFromParent();
      return;
    }
    if (other is DoorMatComponent) {
      if (other.delivered) return;
      _hasHit = true;
      final worldHit = other.absolutePosition.clone();
      gameRef.onPaperHitDoorMat(other, worldHit);
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
