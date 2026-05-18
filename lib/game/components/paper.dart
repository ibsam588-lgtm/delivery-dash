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
          size: Vector2(38, 24),
          anchor: Anchor.center,
          position: startPosition,
          priority: 50,
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

    final page = RRect.fromRectAndRadius(
      Rect.fromLTWH(w * 0.08, h * 0.18, w * 0.84, h * 0.64),
      const Radius.circular(2),
    );
    canvas.drawRRect(
      page,
      Paint()
        ..shader = Gradient.linear(
          Offset(w * 0.08, h * 0.18),
          Offset(w * 0.92, h * 0.82),
          [const Color(0xFFF7F4E6), const Color(0xFFD8D3C4)],
        ),
    );

    final foldPath = Path()
      ..moveTo(w * 0.52, h * 0.18)
      ..lineTo(w * 0.92, h * 0.25)
      ..lineTo(w * 0.86, h * 0.82)
      ..lineTo(w * 0.52, h * 0.72)
      ..close();
    canvas.drawPath(
      foldPath,
      Paint()..color = const Color(0xFFE7E1CF).withValues(alpha: 0.85),
    );

    canvas.drawRRect(
      page,
      Paint()
        ..color = const Color(0xFF77705E)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.0,
    );
    canvas.drawLine(
      Offset(w * 0.52, h * 0.20),
      Offset(w * 0.52, h * 0.76),
      Paint()
        ..color = const Color(0x9977705E)
        ..strokeWidth = 1.0,
    );

    canvas.drawRect(
      Rect.fromLTWH(w * 0.16, h * 0.27, w * 0.28, h * 0.10),
      Paint()..color = const Color(0xFF263238),
    );
    canvas.drawRect(
      Rect.fromLTWH(w * 0.58, h * 0.29, w * 0.22, h * 0.08),
      Paint()..color = const Color(0xFF1976D2),
    );

    final linePaint = Paint()
      ..color = const Color(0xFF8D8778)
      ..strokeWidth = 1.1
      ..strokeCap = StrokeCap.round;
    for (final yFrac in [0.46, 0.55, 0.64, 0.73]) {
      canvas.drawLine(
        Offset(w * 0.16, h * yFrac),
        Offset(w * 0.46, h * yFrac),
        linePaint,
      );
      canvas.drawLine(
        Offset(w * 0.58, h * (yFrac + 0.01)),
        Offset(w * 0.82, h * (yFrac + 0.01)),
        linePaint,
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
