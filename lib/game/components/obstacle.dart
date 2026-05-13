import 'package:flame/collisions.dart';
import 'package:flame/components.dart';
import '../delivery_dash_game.dart';
import 'player.dart';

enum ObstacleType { car0, car1, car2, car3, dog, worker, cone, barrier, pothole }

class ObstacleComponent extends SpriteComponent
    with HasGameRef<DeliveryDashGame>, CollisionCallbacks {
  final ObstacleType type;
  final int lane;

  ObstacleComponent({required this.type, required this.lane})
      : super(size: _sizeFor(type), anchor: Anchor.center);

  static Vector2 _sizeFor(ObstacleType t) => switch (t) {
        ObstacleType.car0 ||
        ObstacleType.car1 ||
        ObstacleType.car2 ||
        ObstacleType.car3 =>
          Vector2(52, 76),
        ObstacleType.dog => Vector2(44, 36),
        ObstacleType.worker => Vector2(36, 60),
        ObstacleType.cone => Vector2(28, 44),
        ObstacleType.barrier => Vector2(60, 28),
        ObstacleType.pothole => Vector2(44, 28),
      };

  static String _spriteFor(ObstacleType t) => switch (t) {
        ObstacleType.car0 => 'car_0.png',
        ObstacleType.car1 => 'car_1.png',
        ObstacleType.car2 => 'car_2.png',
        ObstacleType.car3 => 'car_3.png',
        ObstacleType.dog => 'dog.png',
        ObstacleType.worker => 'worker.png',
        ObstacleType.cone => 'cone.png',
        ObstacleType.barrier => 'barrier.png',
        ObstacleType.pothole => 'pothole.png',
      };

  @override
  Future<void> onLoad() async {
    sprite = await gameRef.loadSprite(_spriteFor(type));
    position = Vector2(gameRef.laneManager.laneX(lane), -size.y);
    add(RectangleHitbox(size: size * 0.8, position: size * 0.1));
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
  void onCollisionStart(Set<Vector2> intersectionPoints, PositionComponent other) {
    super.onCollisionStart(intersectionPoints, other);
    if (other is PlayerComponent) {
      gameRef.onPlayerHitObstacle();
    }
  }
}
