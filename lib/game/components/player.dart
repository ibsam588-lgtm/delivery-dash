import 'package:flame/collisions.dart';
import 'package:flame/components.dart';
import '../delivery_dash_game.dart';

class PlayerComponent extends SpriteComponent
    with HasGameRef<DeliveryDashGame>, CollisionCallbacks {
  int currentLane = 1;
  double _targetX = 0;

  static const double _moveSpeed = 450.0;
  double _flashTimer = 0;
  static const double _flashInterval = 0.1;

  PlayerComponent() : super(size: Vector2(48, 64), anchor: Anchor.center);

  @override
  Future<void> onLoad() async {
    sprite = await gameRef.loadSprite('player.png');
    _targetX = gameRef.laneManager.laneX(1);
    position = Vector2(_targetX, gameRef.size.y * 0.75);
    add(RectangleHitbox(size: Vector2(36, 52), position: Vector2(6, 6)));
  }

  @override
  void update(double dt) {
    super.update(dt);

    // Smooth lane slide
    final dx = _targetX - position.x;
    if (dx.abs() > 1) {
      final step = dx.sign * _moveSpeed * dt;
      position.x += (step.abs() > dx.abs()) ? dx : step;
    } else {
      position.x = _targetX;
    }

    // Flash when invincible
    if (gameRef.isInvincible) {
      _flashTimer += dt;
      if (_flashTimer >= _flashInterval) {
        _flashTimer = 0;
        opacity = opacity > 0.5 ? 0.15 : 1.0;
      }
    } else {
      opacity = 1.0;
      _flashTimer = 0;
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

  @override
  void onCollisionStart(Set<Vector2> intersectionPoints, PositionComponent other) {
    super.onCollisionStart(intersectionPoints, other);
    if (other is RectangleHitbox) return;
    gameRef.onPlayerHitObstacle();
  }
}
