import 'dart:math';
import 'dart:ui';
import 'package:flame/collisions.dart';
import 'package:flame/components.dart';
import 'package:flame/flame.dart';
import '../delivery_dash_game.dart';
import 'player.dart';

enum ObstacleType {
  car,
  dog,
  worker,
  cone,
  barrier,
  pothole,
  hydrant,
}

Vector2 _sizeFor(ObstacleType t) {
  switch (t) {
    case ObstacleType.car:
      return Vector2(72, 110);
    case ObstacleType.dog:
      return Vector2(55, 45);
    case ObstacleType.worker:
      return Vector2(50, 75);
    case ObstacleType.cone:
      return Vector2(40, 50);
    case ObstacleType.barrier:
      return Vector2(80, 45);
    case ObstacleType.pothole:
      return Vector2(50, 35);
    case ObstacleType.hydrant:
      return Vector2(28, 42);
  }
}

class ObstacleComponent extends SpriteComponent
    with HasGameRef<DeliveryDashGame>, CollisionCallbacks {
  final ObstacleType type;
  final double laneFraction;
  final int carVariant;
  final bool onRightSidewalk;
  final double speedFactor;
  final bool isOvertaker;

  bool _hasHitPlayer = false;
  double _life = 0;

  ObstacleComponent({
    required this.type,
    required this.laneFraction,
    int? carVariant,
    this.speedFactor = 1.0,
    this.isOvertaker = false,
    this.onRightSidewalk = false,
  })  : carVariant = carVariant ?? Random().nextInt(4),
        super(
          size: _sizeFor(type),
          anchor: Anchor.center,
          priority: 3,
        );

  bool get isLethal =>
      type == ObstacleType.car ||
      type == ObstacleType.dog ||
      type == ObstacleType.worker;

  bool get isDrenching => type == ObstacleType.hydrant;

  String? get _spriteName {
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
      case ObstacleType.hydrant:
        return null; // drawn as colored rect fallback
    }
  }

  @override
  Future<void> onLoad() async {
    final name = _spriteName;
    if (name != null) {
      sprite = Sprite(Flame.images.fromCache(name));
    }
    paint
      ..filterQuality = FilterQuality.none
      ..isAntiAlias = false;

    final lm = gameRef.laneManager;
    final double x;
    if (onRightSidewalk) {
      final lo = lm.roadRight + 6;
      final hi = gameRef.size.x - 6;
      final t = laneFraction.clamp(0.0, 1.0);
      x = lo + (hi - lo) * t;
    } else {
      x = lm.roadXFromFraction(laneFraction);
    }
    position = Vector2(x, -size.y);
    add(RectangleHitbox(
      size: size * 0.78,
      position: size * 0.11,
    ));
  }

  @override
  void update(double dt) {
    super.update(dt);
    _life += dt;

    final road = gameRef.scrollSpeed;
    final vy = type == ObstacleType.car
        ? (isOvertaker ? road * 1.3 : road * speedFactor)
        : road;
    position.y += vy * dt;

    if (position.y > gameRef.size.y + size.y) {
      removeFromParent();
    }
  }

  @override
  void render(Canvas canvas) {
    if (sprite != null) {
      super.render(canvas);
    } else if (type == ObstacleType.hydrant) {
      _renderHydrant(canvas);
    }
  }

  void _renderHydrant(Canvas canvas) {
    // Simple stable shape: orange/red rounded rectangle with a cap on top.
    final body = RRect.fromRectAndRadius(
      Rect.fromLTWH(size.x * 0.15, size.y * 0.20, size.x * 0.70, size.y * 0.75),
      const Radius.circular(6),
    );
    canvas.drawRRect(body, Paint()..color = const Color(0xFFD32F2F));
    canvas.drawOval(
      Rect.fromLTWH(size.x * 0.05, size.y * 0.08, size.x * 0.90, size.y * 0.22),
      Paint()..color = const Color(0xFFB71C1C),
    );
    // Tiny "splash" indicator that pulses, drawn as a small blue dot.
    final pulse = 0.7 + 0.3 * (0.5 + 0.5 * sin(_life * 2 * pi * 3));
    canvas.drawCircle(
      Offset(size.x / 2, size.y * 0.12),
      3 * pulse,
      Paint()..color = const Color(0xFF42A5F5),
    );
  }

  @override
  void onCollisionStart(
      Set<Vector2> intersectionPoints, PositionComponent other) {
    super.onCollisionStart(intersectionPoints, other);
    if (_hasHitPlayer) return;
    if (other is PlayerComponent) {
      _hasHitPlayer = true;
      if (isDrenching) {
        gameRef.onPlayerDrenched();
        return;
      }
      if (isLethal) {
        gameRef.onPlayerHitObstacle();
      } else {
        gameRef.onPlayerHitSlowObstacle();
      }
    }
  }
}
