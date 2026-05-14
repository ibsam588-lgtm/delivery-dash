import 'dart:ui';
import 'package:flame/collisions.dart';
import 'package:flame/components.dart';
import '../delivery_dash_game.dart';

class PlayerComponent extends SpriteComponent
    with HasGameRef<DeliveryDashGame>, CollisionCallbacks {
  static const Color vipTint = Color(0xCCFF6F00);
  static const double _moveSpeed = 700.0;
  static const double _flashInterval = 0.1;

  final bool isVip;

  int currentLane = 1;
  double _targetX = 0;
  double _flashTimer = 0;

  PlayerComponent({this.isVip = false})
      : super(size: Vector2(72, 72), anchor: Anchor.center, priority: 5);

  @override
  Future<void> onLoad() async {
    sprite = await gameRef.loadSprite('player.png');
    if (isVip) {
      paint = Paint()
        ..colorFilter =
            const ColorFilter.mode(vipTint, BlendMode.srcATop);
    }
    _targetX = gameRef.laneManager.laneX(1);
    position = Vector2(_targetX, gameRef.size.y - 120);
    add(RectangleHitbox(
      size: Vector2(52, 56),
      position: Vector2((72 - 52) / 2, (72 - 56) / 2),
    ));
  }

  @override
  void update(double dt) {
    super.update(dt);

    final dx = _targetX - position.x;
    if (dx.abs() > 1) {
      final step = dx.sign * _moveSpeed * dt;
      position.x += step.abs() > dx.abs() ? dx : step;
    } else {
      position.x = _targetX;
    }

    if (gameRef.isInvincible) {
      _flashTimer += dt;
      if (_flashTimer >= _flashInterval) {
        _flashTimer = 0;
        opacity = opacity > 0.5 ? 0.2 : 1.0;
      }
    } else {
      _flashTimer = 0;
      if (opacity != 1.0) opacity = 1.0;
    }
  }

  void moveLeft() {
    if (currentLane > 0) {
      currentLane--;
      _targetX = gameRef.laneManager.laneX(currentLane);
    }
  }

  void moveRight() {
    if (currentLane < 2) {
      currentLane++;
      _targetX = gameRef.laneManager.laneX(currentLane);
    }
  }
}
