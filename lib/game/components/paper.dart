import 'dart:math';
import 'dart:ui';
import 'package:flame/collisions.dart';
import 'package:flame/components.dart';
import '../delivery_dash_game.dart';
import 'house_window.dart';
import 'mailbox.dart';
import 'obstacle.dart';
import 'parked_car.dart';

/// Flying folded newspaper — drawn procedurally.
class PaperComponent extends PositionComponent
    with HasGameRef<DeliveryDashGame>, CollisionCallbacks {
  static const double _baseSpeed = 540.0;
  static const double _spinPerSec = 12.0;

  final Vector2 _velocity;
  bool _hasHit = false;
  double _life = 1.6;

  PaperComponent({
    required Vector2 startPosition,
    double angleDeg = 0,
  })  : _velocity = _initialVelocity(angleDeg),
        super(
          size: Vector2(28, 36),
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

    // Paper body with subtle gradient (off-white / cream).
    final bodyRect = Rect.fromLTWH(0, 0, w, h);
    final bodyRRect = RRect.fromRectAndRadius(bodyRect, const Radius.circular(2));
    canvas.drawRRect(
      bodyRRect,
      Paint()
        ..shader = Gradient.linear(
          bodyRect.topLeft,
          bodyRect.bottomRight,
          [const Color(0xFFF8F4E0), const Color(0xFFEDE8CC)],
        ),
    );

    // Outline.
    canvas.drawRRect(
      bodyRRect,
      Paint()
        ..color = const Color(0xFF8A8470)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1,
    );

    // Headline strip (darker band at top).
    canvas.drawRect(
      Rect.fromLTWH(w * 0.08, h * 0.06, w * 0.84, h * 0.13),
      Paint()..color = const Color(0xFF1A1A1A),
    );
    // Bold headline white text simulation.
    canvas.drawRect(
      Rect.fromLTWH(w * 0.12, h * 0.08, w * 0.50, h * 0.045),
      Paint()..color = const Color(0xFFFFFFFF),
    );

    // Fold crease — diagonal lighter line across the middle.
    canvas.drawLine(
      Offset(0, h * 0.48),
      Offset(w, h * 0.52),
      Paint()
        ..color = const Color(0xFFD8D0B8)
        ..strokeWidth = 1.2,
    );

    // Faux text lines (grey horizontal strokes).
    final textPaint = Paint()
      ..color = const Color(0xFF7A7460)
      ..strokeWidth = 1.2
      ..strokeCap = StrokeCap.butt;
    final lineData = [
      (0.26, 0.76), (0.32, 0.68), (0.38, 0.72),
      (0.58, 0.78), (0.64, 0.62), (0.70, 0.74), (0.76, 0.58),
    ];
    for (final (ty, widthFrac) in lineData) {
      final lineW = w * widthFrac;
      canvas.drawLine(
        Offset(w * 0.10, h * ty),
        Offset(w * 0.10 + lineW, h * ty),
        textPaint,
      );
    }

    // Small image box (bottom-left quadrant).
    canvas.drawRect(
      Rect.fromLTWH(w * 0.10, h * 0.56, w * 0.34, h * 0.26),
      Paint()..color = const Color(0xFFCCC8A8),
    );
    canvas.drawRect(
      Rect.fromLTWH(w * 0.10, h * 0.56, w * 0.34, h * 0.26),
      Paint()
        ..color = const Color(0xFF9A9480)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0.8,
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
