import 'dart:math';
import 'package:flame/collisions.dart';
import 'package:flame/components.dart';
import '../delivery_dash_game.dart';
import 'player.dart';

enum ObstacleType { car, dog, worker, cone, barrier, pothole }

class ObstacleComponent extends SpriteComponent
    with HasGameRef<DeliveryDashGame>, CollisionCallbacks {
  final ObstacleType type;
  final int lane;
  final int carVariant;
  bool _hasHitPlayer = false;

  ObstacleComponent({
    required this.type,
    required this.lane,
    int? carVariant,
  })  : carVariant = carVariant ?? Random().nextInt(4),
        super(size: _sizeFor(type), anchor: Anchor.center, priority: 3);

  static Vector2 _sizeFor(ObstacleType t) {
    switch (t) {
      case ObstacleType.car:
        return Vector2(64, 96);
      case ObstacleType.dog:
        return Vector2(64, 52);
      case ObstacleType.worker:
        return Vector2(52, 72);
      case ObstacleType.cone:
        return Vector2(42, 54);
      case ObstacleType.barrier:
        return Vector2(84, 42);
      case ObstacleType.pothole:
        return Vector2(64, 40);
    }
  }

  String get _spriteName {
    switch (type) {
      case ObstacleType.car:
        return 'car_$carVariant.png';
      case ObstacleType.dog:
        return 'dog.png';
      case ObstacleType.worker:
        return 'worker.png';
      case ObstacleType.cone:
        return 'cone.png';
      case ObstacleType.barrier:
        return 'barrier.png';
      case ObstacleType.pothole:
        return 'pothole.png';
    }
  }

  @override
  Future<void> onLoad() async {
    sprite = await gameRef.loadSprite(_spriteName);
    position = Vector2(gameRef.laneManager.laneX(lane), -size.y);
    final hbInset = 0.1;
    add(RectangleHitbox(
      size: size * (1 - 2 * hbInset),
      position: size * hbInset,
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

  @override
  void onCollisionStart(
      Set<Vector2> intersectionPoints, PositionComponent other) {
    super.onCollisionStart(intersectionPoints, other);
    if (_hasHitPlayer) return;
    if (other is PlayerComponent) {
      _hasHitPlayer = true;
      gameRef.onPlayerHitObstacle();
    }
  }
}
