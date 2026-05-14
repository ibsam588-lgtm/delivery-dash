import 'dart:ui';
import 'package:flame/collisions.dart';
import 'package:flame/components.dart';
import 'package:flame/flame.dart';
import '../delivery_dash_game.dart';

class MailboxComponent extends SpriteComponent
    with HasGameRef<DeliveryDashGame>, CollisionCallbacks {
  final bool isBlue;

  MailboxComponent({required this.isBlue})
      : super(
          size: Vector2(40, 60),
          anchor: Anchor.center,
          priority: 4,
        );

  @override
  Future<void> onLoad() async {
    sprite = Sprite(
        Flame.images.fromCache(isBlue ? 'mailbox_blue.png' : 'mailbox_red.png'));
    paint
      ..filterQuality = FilterQuality.none
      ..isAntiAlias = false;
    add(RectangleHitbox(
      size: size * 0.85,
      position: size * 0.075,
      collisionType: CollisionType.passive,
    ));
  }
}
