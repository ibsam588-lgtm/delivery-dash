import 'package:flame/collisions.dart';
import 'package:flame/components.dart';
import '../delivery_dash_game.dart';

class MailboxComponent extends SpriteComponent
    with HasGameRef<DeliveryDashGame>, CollisionCallbacks {
  final bool isBlue;
  final int lane;
  final bool onLeft;

  MailboxComponent({
    required this.isBlue,
    required this.lane,
    required this.onLeft,
  }) : super(size: Vector2(40, 56), anchor: Anchor.center);

  @override
  Future<void> onLoad() async {
    sprite = await gameRef.loadSprite(isBlue ? 'mailbox_blue.png' : 'mailbox_red.png');

    final laneX = gameRef.laneManager.laneX(lane);
    final halfLane = gameRef.laneManager.laneWidth * 0.5;
    position = Vector2(
      onLeft ? laneX - halfLane * 0.5 : laneX + halfLane * 0.5,
      -size.y,
    );

    add(RectangleHitbox(size: size * 0.85, position: size * 0.075));
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
