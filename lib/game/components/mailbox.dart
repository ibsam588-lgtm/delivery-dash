import 'package:flame/collisions.dart';
import 'package:flame/components.dart';
import '../delivery_dash_game.dart';

class MailboxComponent extends SpriteComponent
    with HasGameRef<DeliveryDashGame>, CollisionCallbacks {
  final bool isBlue;
  final bool onLeft;

  MailboxComponent({required this.isBlue, required this.onLeft})
      : super(size: Vector2(52, 64), anchor: Anchor.center, priority: 2);

  @override
  Future<void> onLoad() async {
    sprite = await gameRef.loadSprite(
        isBlue ? 'mailbox_blue.png' : 'mailbox_red.png');

    final lm = gameRef.laneManager;
    final sidewalkCenter = onLeft
        ? lm.roadLeft / 2
        : lm.roadRight + (gameRef.size.x - lm.roadRight) / 2;
    final inwardNudge = onLeft ? size.x * 0.1 : -size.x * 0.1;

    position = Vector2(sidewalkCenter + inwardNudge, -size.y);

    add(RectangleHitbox(
      size: size * 0.85,
      position: size * 0.075,
    ));
  }

  @override
  void update(double dt) {
    super.update(dt);
    position.y += gameRef.scrollSpeed * dt;
    if (position.y > gameRef.size.y + size.y) {
      removeFromParent();
    }
  }
}
