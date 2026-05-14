import 'package:flame/collisions.dart';
import 'package:flame/components.dart';
import '../delivery_dash_game.dart';
import 'mailbox.dart';

class PaperComponent extends SpriteComponent
    with HasGameRef<DeliveryDashGame>, CollisionCallbacks {
  static const double _baseSpeed = 520.0;
  final Vector2 _velocity;
  bool _hasHit = false;

  PaperComponent({
    required Vector2 startPosition,
    double angleDeg = 0,
  })  : _velocity = _velocityFromAngle(angleDeg),
        super(
          size: Vector2(40, 40),
          anchor: Anchor.center,
          position: startPosition,
          priority: 6,
        );

  static Vector2 _velocityFromAngle(double angleDeg) {
    final rad = angleDeg * 3.141592653589793 / 180.0;
    final dx = _baseSpeed * 0.6 * (rad);
    final dy = -_baseSpeed;
    return Vector2(dx, dy);
  }

  @override
  Future<void> onLoad() async {
    sprite = await gameRef.loadSprite('paper.png');
    add(RectangleHitbox(size: size * 0.8, position: size * 0.1));
  }

  @override
  void update(double dt) {
    super.update(dt);
    position += _velocity * dt;
    angle += 8 * dt;

    if (position.y < -size.y ||
        position.x < -size.x ||
        position.x > gameRef.size.x + size.x) {
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
      gameRef.onPaperHitMailbox(other.isBlue, position.clone());
      other.removeFromParent();
      removeFromParent();
    }
  }
}
