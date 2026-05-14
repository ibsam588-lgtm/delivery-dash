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
        super(anchor: Anchor.center, priority: 3);

  bool get isLethal =>
      type == ObstacleType.car ||
      type == ObstacleType.dog ||
      type == ObstacleType.worker;

  // Aspect ratio (width / height) for each obstacle, based on the
  // actual source artwork dimensions in assets/images/.
  double get _aspect {
    switch (type) {
      case ObstacleType.car:
        return 56.0 / 80.0;
      case ObstacleType.dog:
        return 32.0 / 48.0;
      case ObstacleType.worker:
        return 48.0 / 64.0;
      case ObstacleType.cone:
        return 48.0 / 32.0;
      case ObstacleType.barrier:
        return 80.0 / 100.0;
      case ObstacleType.pothole:
        return 80.0 / 100.0;
    }
  }

  // Target width as a fraction of lane width.
  double get _widthFactor {
    switch (type) {
      case ObstacleType.car:
        return 0.78;
      case ObstacleType.dog:
        return 0.62;
      case ObstacleType.worker:
        return 0.66;
      case ObstacleType.cone:
        return 0.55;
      case ObstacleType.barrier:
        return 0.92;
      case ObstacleType.pothole:
        return 0.80;
    }
  }

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
    final laneWidth = gameRef.laneManager.laneWidth;
    final w = laneWidth * _widthFactor;
    final h = w / _aspect;
    size = Vector2(w, h);
    position = Vector2(gameRef.laneManager.laneX(lane), -size.y);
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
