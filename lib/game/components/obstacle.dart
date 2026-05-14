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
  trashBin,
  kidBike,
  manhole,
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
    case ObstacleType.trashBin:
      return Vector2(40, 56);
    case ObstacleType.kidBike:
      return Vector2(48, 70);
    case ObstacleType.manhole:
      return Vector2(48, 30);
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
  bool _paperedOnce = false;
  double _life = 0;

  // Lateral motion (dogs / kids on bikes do a sine sweep).
  double _lateralPhase = 0;
  double? _baseX;

  // Paper-hit reaction state.
  double _reactionTimer = 0;
  static const double _reactionDuration = 0.35;
  double _tipAngle = 0; // For trash bin tipping over.

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
      type == ObstacleType.worker ||
      type == ObstacleType.kidBike;

  bool get isDrenching => type == ObstacleType.hydrant;

  bool get isStaticOnSidewalk =>
      type == ObstacleType.worker ||
      type == ObstacleType.trashBin ||
      onRightSidewalk;

  bool get hasLateralSweep =>
      type == ObstacleType.dog || type == ObstacleType.kidBike;

  /// Points awarded when a paper hits this obstacle (0 = no score).
  int get paperHitPoints {
    switch (type) {
      case ObstacleType.trashBin:
        return 5;
      case ObstacleType.dog:
        return 3;
      case ObstacleType.worker:
        return 5;
      case ObstacleType.kidBike:
        return 3;
      case ObstacleType.cone:
      case ObstacleType.barrier:
        return 2;
      case ObstacleType.hydrant:
      case ObstacleType.car:
      case ObstacleType.pothole:
      case ObstacleType.manhole:
        return 0;
    }
  }

  String? get _spriteName {
    switch (type) {
      case ObstacleType.car:
        switch (carVariant) {
          case 0:
            return 'car_2.png';
          default:
            return 'car_3.png';
        }
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
      case ObstacleType.kidBike:
        return 'player.png';
      case ObstacleType.hydrant:
      case ObstacleType.trashBin:
      case ObstacleType.manhole:
        return null; // procedural draw
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
    _baseX = x;
    position = Vector2(x, -size.y);
    add(RectangleHitbox(
      size: size * 0.78,
      position: size * 0.11,
      collisionType: CollisionType.active,
    ));
  }

  void onHitByPaper() {
    if (_paperedOnce) return;
    _paperedOnce = true;
    _reactionTimer = _reactionDuration;
    if (type == ObstacleType.trashBin) {
      _tipAngle = pi / 2.5;
    } else if (hasLateralSweep) {
      // Swerve away from current motion.
      _lateralPhase += pi;
    }
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

    if (hasLateralSweep) {
      _lateralPhase += dt * 2.2;
      final amp = type == ObstacleType.kidBike ? 60.0 : 80.0;
      final lm = gameRef.laneManager;
      final base = _baseX ?? lm.roadCenter;
      final desired = base + sin(_lateralPhase) * amp;
      position.x = lm.clampToRoad(desired, size.x / 2);
    }

    if (_reactionTimer > 0) {
      _reactionTimer = (_reactionTimer - dt).clamp(0.0, _reactionDuration);
    }

    if (position.y > gameRef.size.y + size.y) {
      removeFromParent();
    }
  }

  /// Subtle depth scale: smaller far from the player, larger near.
  double _depthScale() {
    final h = gameRef.size.y;
    final t = (position.y / h).clamp(0.0, 1.0);
    return 0.78 + 0.27 * t; // 0.78 (far) → 1.05 (near)
  }

  @override
  void render(Canvas canvas) {
    final scale = _depthScale();
    final bounce =
        _reactionTimer > 0 ? sin(_reactionTimer / _reactionDuration * pi) * 0.12 : 0.0;
    final s = scale * (1 + bounce);

    // Ground shadow under the object — gives a sense of grounded depth.
    if (type != ObstacleType.pothole && type != ObstacleType.manhole) {
      canvas.drawOval(
        Rect.fromCenter(
          center: Offset(size.x / 2, size.y - 3),
          width: size.x * 0.85 * s,
          height: 10 * s,
        ),
        Paint()..color = const Color(0x66000000),
      );
    }

    canvas.save();
    canvas.translate(size.x / 2, size.y / 2);
    // Apply a 15% vertical squish on top of the depth scale to suggest
    // a slightly tilted top-down camera angle.
    canvas.scale(s, s * 0.85);
    if (_tipAngle != 0) {
      canvas.rotate(_tipAngle);
    }
    canvas.translate(-size.x / 2, -size.y / 2);

    if (sprite != null) {
      super.render(canvas);
    } else if (type == ObstacleType.hydrant) {
      _renderHydrant(canvas);
    } else if (type == ObstacleType.trashBin) {
      _renderTrashBin(canvas);
    } else if (type == ObstacleType.manhole) {
      _renderManhole(canvas);
    }
    canvas.restore();
  }

  void _renderHydrant(Canvas canvas) {
    final body = RRect.fromRectAndRadius(
      Rect.fromLTWH(size.x * 0.15, size.y * 0.20, size.x * 0.70, size.y * 0.75),
      const Radius.circular(6),
    );
    canvas.drawRRect(body, Paint()..color = const Color(0xFFD32F2F));
    canvas.drawOval(
      Rect.fromLTWH(size.x * 0.05, size.y * 0.08, size.x * 0.90, size.y * 0.22),
      Paint()..color = const Color(0xFFB71C1C),
    );
    final pulse = 0.7 + 0.3 * (0.5 + 0.5 * sin(_life * 2 * pi * 3));
    canvas.drawCircle(
      Offset(size.x / 2, size.y * 0.12),
      3 * pulse,
      Paint()..color = const Color(0xFF42A5F5),
    );
  }

  void _renderTrashBin(Canvas canvas) {
    // Cylindrical metal-gray bin with darker lid and a vertical band.
    final w = size.x;
    final h = size.y;
    final body = RRect.fromRectAndRadius(
      Rect.fromLTWH(w * 0.10, h * 0.18, w * 0.80, h * 0.78),
      const Radius.circular(4),
    );
    canvas.drawRRect(body, Paint()..color = const Color(0xFF6E6E6E));
    // Vertical highlight band.
    canvas.drawRect(
      Rect.fromLTWH(w * 0.32, h * 0.20, w * 0.08, h * 0.74),
      Paint()..color = const Color(0xFF8C8C8C),
    );
    // Horizontal ridges.
    final ridge = Paint()..color = const Color(0xFF4D4D4D);
    canvas.drawRect(Rect.fromLTWH(w * 0.10, h * 0.40, w * 0.80, 2), ridge);
    canvas.drawRect(Rect.fromLTWH(w * 0.10, h * 0.65, w * 0.80, 2), ridge);
    // Lid.
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(w * 0.05, h * 0.05, w * 0.90, h * 0.18),
        const Radius.circular(5),
      ),
      Paint()..color = const Color(0xFF3F3F3F),
    );
    // Lid handle.
    canvas.drawRect(
      Rect.fromLTWH(w * 0.42, h * 0.00, w * 0.16, h * 0.07),
      Paint()..color = const Color(0xFF555555),
    );
  }

  void _renderManhole(Canvas canvas) {
    final c = Offset(size.x / 2, size.y / 2);
    canvas.drawOval(
      Rect.fromCenter(center: c, width: size.x, height: size.y),
      Paint()..color = const Color(0xFF1A1A1A),
    );
    canvas.drawOval(
      Rect.fromCenter(center: c, width: size.x * 0.88, height: size.y * 0.78),
      Paint()..color = const Color(0xFF333333),
    );
    // Cross detail.
    final cp = Paint()
      ..color = const Color(0xFF1A1A1A)
      ..strokeWidth = 2;
    canvas.drawLine(
      Offset(c.dx - size.x * 0.35, c.dy),
      Offset(c.dx + size.x * 0.35, c.dy),
      cp,
    );
    canvas.drawLine(
      Offset(c.dx, c.dy - size.y * 0.30),
      Offset(c.dx, c.dy + size.y * 0.30),
      cp,
    );
  }

  @override
  void onCollisionStart(
      Set<Vector2> intersectionPoints, PositionComponent other) {
    super.onCollisionStart(intersectionPoints, other);
    if (_hasHitPlayer) return;
    if (other is PlayerComponent) {
      _hasHitPlayer = true;
      // Static sidewalk things don't hurt the road-bound player.
      if (isStaticOnSidewalk && !isLethal) return;
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
