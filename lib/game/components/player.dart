import 'dart:ui';
import 'package:flame/collisions.dart';
import 'package:flame/components.dart';
import 'package:flame/flame.dart';
import '../delivery_dash_game.dart';

class PlayerComponent extends SpriteComponent
    with HasGameRef<DeliveryDashGame>, CollisionCallbacks {
  static const Color vipTint = Color(0xCCFFD54F);
  static const double _followSpeed = 8.0;
  static const double _flashInterval = 0.1;

  final bool isVip;
  double _targetX = 0;
  double _flashTimer = 0;

  PlayerComponent({this.isVip = false})
      : super(size: Vector2(55, 80), anchor: Anchor.center, priority: 5);

  @override
  Future<void> onLoad() async {
    sprite = Sprite(Flame.images.fromCache('mailbox_blue.png'));
    if (isVip) {
      paint = Paint()
        ..colorFilter = const ColorFilter.mode(vipTint, BlendMode.srcATop);
    }
    final lm = gameRef.laneManager;
    _targetX = lm.roadCenter;
    position = Vector2(_targetX, gameRef.size.y * 0.75);
    add(RectangleHitbox(
      size: Vector2(38, 60),
      position: Vector2((size.x - 38) / 2, (size.y - 60) / 2),
    ));
  }

  void moveTo(double worldX) {
    _targetX = gameRef.laneManager.clampToRoad(worldX, size.x / 2);
  }

  @override
  void update(double dt) {
    super.update(dt);

    // Smooth follow toward target X (lerp).
    final dx = _targetX - position.x;
    final t = (_followSpeed * dt).clamp(0.0, 1.0);
    position.x += dx * t;

    if (gameRef.isInvincible) {
      _flashTimer += dt;
      if (_flashTimer >= _flashInterval) {
        _flashTimer = 0;
        opacity = opacity > 0.5 ? 0.25 : 1.0;
      }
    } else {
      _flashTimer = 0;
      if (opacity != 1.0) opacity = 1.0;
    }
  }
}
