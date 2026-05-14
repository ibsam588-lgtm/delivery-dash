import 'dart:math';
import 'package:flame/collisions.dart';
import 'package:flame/components.dart';
import '../delivery_dash_game.dart';
import 'mailbox.dart';

class PaperComponent extends SpriteComponent
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
          size: Vector2(36, 36),
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
    sprite = Sprite(gameRef.images.fromCache('mailbox_red.png'));
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
    }
  }
}
