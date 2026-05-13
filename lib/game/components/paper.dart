import 'package:flame/collisions.dart';
import 'package:flame/components.dart';
import '../delivery_dash_game.dart';
import 'mailbox.dart';

class PaperComponent extends SpriteComponent
    with HasGameRef<DeliveryDashGame>, CollisionCallbacks {
  static const double _speed = 380.0;
  bool _hasHit = false;

  PaperComponent({required Vector2 startPosition})
      : super(
          size: Vector2(24, 24),
          anchor: Anchor.center,
          position: startPosition,
        );

  @override
  Future<void> onLoad() async {
    sprite = await gameRef.loadSprite('paper.png');
    add(RectangleHitbox());
  }

  @override
  void update(double dt) {
    super.update(dt);
    position.y -= _speed * dt;

    // Fake perspective: shrink as paper goes upscreen
    final progress = (1.0 - position.y / gameRef.size.y).clamp(0.0, 1.0);
    final s = (1.0 - progress * 0.35).clamp(0.4, 1.0);
    scale = Vector2.all(s);

    if (position.y < -size.y) {
      removeFromParent();
    }
  }

  @override
  void onCollisionStart(Set<Vector2> intersectionPoints, PositionComponent other) {
    super.onCollisionStart(intersectionPoints, other);
    if (_hasHit) return;
    if (other is MailboxComponent) {
      _hasHit = true;
      gameRef.onPaperHitMailbox(other.isBlue, position.clone());
      removeFromParent();
    }
  }
}
