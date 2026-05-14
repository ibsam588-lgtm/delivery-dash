import 'dart:math';
import 'package:flame/collisions.dart';
import 'package:flame/components.dart';
import '../delivery_dash_game.dart';
import 'player.dart';

enum ObstacleType { car, dog, worker, cone, barrier, pothole }

class ObstacleComponent extends SpriteComponent
    with HasGameRef<DeliveryDashGame>, CollisionCallbacks {
  final ObstacleType type;
  final double spawnX;
  final int carVariant;
  bool _hasHitPlayer = false;

  ObstacleComponent({
    required this.type,
    required this.spawnX,
    int? carVariant,
  })  : carVariant = carVariant ?? Random().nextInt(4),
        super(anchor: Anchor.center, priority: 3);

  static Vector2 _sizeFor(ObstacleType t) {
    switch (t) {
      case ObstacleType.car:
        return Vector2(60, 100);
      case ObstacleType.dog:
        return Vector2(50, 40);
      case ObstacleType.worker:
        return Vector2(50, 80);
      case ObstacleType.cone:
        return Vector2(40, 50);
      case ObstacleType.barrier:
        return Vector2(80, 50);
      case ObstacleType.pothole:
        return Vector2(50, 35);
    }
  }

  bool get isLethal =>
      type == ObstacleType.car ||
      type == ObstacleType.dog ||
      type == ObstacleType.worker;

  String get _spriteName {
    switch (type) {
      case ObstacleType.car:
        switch (carVariant) {
          case 0:
            return 'car_2.png';
          case 1:
            return 'car_3.png';
          case 2:
            return 'dog.png';
          default:
            return 'worker.png';
        }
      case ObstacleType.dog:
        return 'cone.png';
      case ObstacleType.worker:
        return 'barrier.png';
      case ObstacleType.cone:
        return 'pothole.png';
      case ObstacleType.barrier:
        return 'house_0.png';
      case ObstacleType.pothole:
        return 'house_1.png';
    }
  }

  @override
  Future<void> onLoad() async {
    sprite = Sprite(gameRef.images.fromCache(_spriteName));
    size = _sizeFor(type);
    position = Vector2(spawnX, -size.y);
    const hbInset = 0.14;
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
      if (isLethal) {
        gameRef.onPlayerHitObstacle();
      } else {
        gameRef.onPlayerHitSlowObstacle();
      }
    }
  }
}
