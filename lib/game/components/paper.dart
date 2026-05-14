import 'dart:math';
import 'dart:ui';
import 'package:flame/collisions.dart';
import 'package:flame/components.dart';
import '../delivery_dash_game.dart';
import 'house_window.dart';
import 'mailbox.dart';
import 'obstacle.dart';
import 'parked_car.dart';

/// A flying folded newspaper. Drawn procedurally as a cream rectangle
/// with faux text lines, so it never depends on a placeholder asset.
class PaperComponent extends PositionComponent
    with HasGameRef<DeliveryDashGame>, CollisionCallbacks {
  static const double _baseSpeed = 540.0;
  static const double _seekRange = 300.0;
  static const double _spinPerSec = 12.0;

  Vector2 _velocity;
  MailboxComponent? _target;
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
    _acquireTarget();
  }

  void _acquireTarget() {
    MailboxComponent? best;
    double bestDist = _seekRange;
    for (final mb in gameRef.descendants().whereType<MailboxComponent>()) {
      // Only seek subscriber (blue) mailboxes.
      if (!mb.isBlue) continue;
      final worldPos = mb.absolutePosition;
      final d = (worldPos - position).length;
      if (d < bestDist) {
        bestDist = d;
        best = mb;
      }
    }
    _target = best;
  }

  @override
  void update(double dt) {
    super.update(dt);
    _life -= dt;
    if (_life <= 0) {
      removeFromParent();
      return;
    }

    final target = _target;
    if (target != null && target.isMounted) {
      final targetPos = target.absolutePosition;
      final diff = targetPos - position;
      if (diff.length > 1) {
        final desired = diff.normalized() * _baseSpeed;
        _velocity = _velocity * 0.78 + desired * 0.22;
      }
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

    // Cream paper body.
    final body = RRect.fromRectAndRadius(
      Rect.fromLTWH(0, 0, w, h),
      const Radius.circular(2),
    );
    canvas.drawRRect(body, Paint()..color = const Color(0xFFF5F0DC));
    canvas.drawRRect(
      body,
      Paint()
        ..color = const Color(0xFF8A8470)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1,
    );

    // Center fold line.
    canvas.drawLine(
      Offset(0, h * 0.5),
      Offset(w, h * 0.5),
      Paint()
        ..color = const Color(0xFFBFB89E)
        ..strokeWidth = 1,
    );

    // "NEWS" masthead bar at the top.
    canvas.drawRect(
      Rect.fromLTWH(w * 0.12, h * 0.08, w * 0.76, h * 0.10),
      Paint()..color = const Color(0xFF222222),
    );

    // Faux text lines (grey horizontal strokes).
    final textPaint = Paint()
      ..color = const Color(0xFF6E6A58)
      ..strokeWidth = 1;
    final lineYs = [0.26, 0.32, 0.38, 0.60, 0.66, 0.72, 0.78, 0.84];
    for (final ty in lineYs) {
      final lineW = w * (0.55 + (ty * 0.4) % 0.25);
      canvas.drawLine(
        Offset(w * 0.10, h * ty),
        Offset(w * 0.10 + lineW, h * ty),
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
      if (other.broken) return; // pass through already-broken windows
      _hasHit = true;
      final worldHit = other.absolutePosition.clone();
      gameRef.onPaperHitWindow(other, worldHit);
      removeFromParent();
      return;
    }
  }
}
