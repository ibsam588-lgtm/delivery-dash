import 'dart:math';
import 'dart:ui';
import 'package:flame/collisions.dart';
import 'package:flame/components.dart';
import '../delivery_dash_game.dart';
import 'house_window.dart';
import 'mailbox.dart';
import 'obstacle.dart';
import 'parked_car.dart';

/// Flying folded newspaper. Always arcs toward the upper-left toward
/// houses on the left sidewalk. Spins visibly.
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
          size: Vector2(32, 40),
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

    // Drop shadow.
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(2, 3, w, h),
        const Radius.circular(2),
      ),
      Paint()..color = const Color(0x55000000),
    );

    // Cream paper body with gradient.
    final bodyRect = Rect.fromLTWH(0, 0, w, h);
    final bodyRRect =
        RRect.fromRectAndRadius(bodyRect, const Radius.circular(2));
    canvas.drawRRect(
      bodyRRect,
      Paint()
        ..shader = Gradient.linear(
          bodyRect.topLeft,
          bodyRect.bottomRight,
          [const Color(0xFFF5F0D8), const Color(0xFFEDE5C0)],
        ),
    );
    canvas.drawRRect(
      bodyRRect,
      Paint()
        ..color = const Color(0xFF8A8470)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1,
    );

    // NEWS masthead — black strip with three chunky white rectangles.
    canvas.drawRect(
      Rect.fromLTWH(w * 0.06, h * 0.06, w * 0.88, h * 0.16),
      Paint()..color = const Color(0xFF1A1A1A),
    );
    // 3 white "N E W S" blocks (no real text, just chunky rectangles).
    final letterPaint = Paint()..color = const Color(0xFFFFFFFF);
    final letterY = h * 0.10;
    final letterH = h * 0.08;
    for (int i = 0; i < 4; i++) {
      final x = w * (0.12 + i * 0.18);
      canvas.drawRect(
        Rect.fromLTWH(x, letterY, w * 0.13, letterH),
        letterPaint,
      );
    }

    // Diagonal fold crease (top-left to bottom-right).
    canvas.drawLine(
      const Offset(0, 0),
      Offset(w, h),
      Paint()
        ..color = const Color(0xFFD8D0B8)
        ..strokeWidth = 1.5,
    );

    // Headline text simulation (4-5 thin grey lines).
    final textPaint = Paint()
      ..color = const Color(0xFF7A7460)
      ..strokeWidth = 1.4;
    const lines = [
      (0.30, 0.74),
      (0.36, 0.66),
      (0.42, 0.72),
      (0.48, 0.62),
      (0.54, 0.70),
    ];
    for (final (ty, widthFrac) in lines) {
      canvas.drawLine(
        Offset(w * 0.10, h * ty),
        Offset(w * 0.10 + w * widthFrac, h * ty),
        textPaint,
      );
    }

    // Small photo box in lower-left quadrant.
    canvas.drawRect(
      Rect.fromLTWH(w * 0.10, h * 0.72, w * 0.34, h * 0.20),
      Paint()..color = const Color(0xFFB8B498),
    );
    canvas.drawRect(
      Rect.fromLTWH(w * 0.10, h * 0.72, w * 0.34, h * 0.20),
      Paint()
        ..color = const Color(0xFF7A7460)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0.8,
    );
    // Hint of an image: small triangle (mountain) + circle (sun).
    canvas.drawCircle(
      Offset(w * 0.20, h * 0.79),
      w * 0.04,
      Paint()..color = const Color(0xFFE0DAB0),
    );
    canvas.drawPath(
      Path()
        ..moveTo(w * 0.24, h * 0.92)
        ..lineTo(w * 0.32, h * 0.78)
        ..lineTo(w * 0.42, h * 0.92)
        ..close(),
      Paint()..color = const Color(0xFF8A8470),
    );

    // Rubber band — thin red-brown ring around the middle.
    canvas.drawRect(
      Rect.fromLTWH(0, h * 0.46, w, h * 0.04),
      Paint()..color = const Color(0xCCB55A2A),
    );
    canvas.drawRect(
      Rect.fromLTWH(0, h * 0.46, w, h * 0.04),
      Paint()
        ..color = const Color(0xFF7A3A18)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0.7,
    );
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
