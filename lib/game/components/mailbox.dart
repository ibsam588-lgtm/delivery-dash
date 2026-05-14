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

  @override
  void render(Canvas canvas) {
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(size.x / 2, size.y - 2),
        width: size.x * 0.8,
        height: 7,
      ),
      Paint()..color = const Color(0x66000000),
    );
    canvas.save();
    canvas.translate(0, size.y * 0.075);
    canvas.scale(1.0, 0.85);
    super.render(canvas);
    canvas.restore();
  }
}
