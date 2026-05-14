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

/// Base size for each obstacle type at scale 1.0 (i.e. when at the
/// bottom of the screen). Actual rendered size shrinks toward the
/// vanishing point.
Vector2 _baseSizeFor(ObstacleType t) {
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
    case ObstacleType.hydrant:
      return Vector2(28, 38);
  }
}

class ObstacleComponent extends PositionComponent
    with HasGameRef<DeliveryDashGame>, CollisionCallbacks {
  final ObstacleType type;
  final double laneFraction; // 0..1 across road, or special values
  final int carVariant;
  final bool onRightSidewalk;

  // Behavior parameters set in constructor.
  final double _speedFactor;
  final bool _isOvertaker;

  // Sprite is null for hydrant (drawn procedurally).
  Sprite? _sprite;

  bool _hasHitPlayer = false;
  final Vector2 _baseSize;

  // For animated obstacles.
  final double _animPhase = Random().nextDouble() * 2 * pi;
  double _life = 0;
  final double _zigzagSeed = Random().nextDouble() * 2 * pi;
  final double _zigzagDir = 1; // for dogs that run across the road
  double _dogStartX = 0;

  ObstacleComponent({
    required this.type,
    required this.laneFraction,
    int? carVariant,
    double speedFactor = 1.0,
    bool isOvertaker = false,
    this.onRightSidewalk = false,
  })  : carVariant = carVariant ?? Random().nextInt(4),
        _speedFactor = speedFactor,
        _isOvertaker = isOvertaker,
        _baseSize = _baseSizeFor(type).clone(),
        super(anchor: Anchor.bottomCenter, priority: 3);

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
        return null;
    }
  }

  @override
  Future<void> onLoad() async {
    final name = _spriteName;
    if (name != null) {
      _sprite = Sprite(Flame.images.fromCache(name));
    }
    size = _baseSize.clone();

    // Initial position: just above the screen at depth ~ -size.y, X chosen
    // by lane fraction or sidewalk position.
    final lm = gameRef.laneManager;
    const initialY = -10.0;
    final scale = lm.scaleAt(initialY);
    size = _baseSize * scale;

    final double x;
    if (onRightSidewalk) {
      final sidewalkLeft = lm.roadRightAt(initialY);
      final sidewalkRight = gameRef.size.x;
      final t = laneFraction.clamp(0.0, 1.0);
      x = sidewalkLeft + (sidewalkRight - sidewalkLeft) * t;
    } else {
      x = lm.roadXFromFraction(laneFraction, initialY);
    }
    position = Vector2(x, initialY);
    _dogStartX = x;

    add(RectangleHitbox(
      size: size * 0.78,
      position: size * 0.11,
    ));
  }

  @override
  void update(double dt) {
    super.update(dt);
    _life += dt;

    final lm = gameRef.laneManager;
    final road = gameRef.scrollSpeed;

    // Vertical movement: scrolling speed with optional overtake bonus.
    double vy;
    if (type == ObstacleType.car) {
      final base = road * _speedFactor;
      vy = _isOvertaker ? road * 1.3 : base;
    } else {
      vy = road;
    }
    position.y += vy * dt;

    // Rescale based on current depth so size shrinks toward the horizon.
    final scale = lm.scaleAt(position.y);
    final newSize = _baseSize * scale;
    // Keep hitbox proportional.
    if ((newSize - size).length > 0.5) {
      size = newSize;
      _resizeHitbox();
    }

    // Recompute X so we stay aligned with the converging road/sidewalk.
    if (onRightSidewalk) {
      final sidewalkLeft = lm.roadRightAt(position.y);
      final sidewalkRight = gameRef.size.x;
      final t = laneFraction.clamp(0.0, 1.0);
      position.x = sidewalkLeft + (sidewalkRight - sidewalkLeft) * t;
    } else {
      position.x = lm.roadXFromFraction(laneFraction, position.y);
    }

    // Per-type behaviors layered on top.
    switch (type) {
      case ObstacleType.worker:
        // Bob up/down 4px at ~1.5 Hz.
        final bob = sin((_life + _animPhase) * 2 * pi * 1.5) * 4 * scale;
        position.y += bob * dt; // small drift, but main motion is scroll
        break;
      case ObstacleType.dog:
        // Run laterally across the road in a sine pattern.
        final amplitude = lm.roadWidthAt(position.y) * 0.45;
        final phase = _life * 1.6 + _zigzagSeed;
        position.x = _dogStartX + sin(phase) * amplitude * _zigzagDir;
        // Allow dogs to wander into either sidewalk slightly.
        position.x = position.x.clamp(
          lm.roadLeftAt(position.y) - 20,
          lm.roadRightAt(position.y) + 20,
        );
        break;
      default:
        break;
    }

    if (position.y > gameRef.size.y + size.y) {
      removeFromParent();
    }
  }

  void _resizeHitbox() {
    for (final c in children.whereType<RectangleHitbox>().toList()) {
      c.size.setFrom(size * 0.78);
      c.position.setFrom(size * 0.11);
    }
  }

  @override
  void render(Canvas canvas) {
    if (_sprite != null) {
      _sprite!.render(
        canvas,
        size: size,
      );
    } else if (type == ObstacleType.hydrant) {
      _renderHydrant(canvas);
    }
  }

  void _renderHydrant(Canvas canvas) {
    // Body: red rounded rect.
    final bodyRect = RRect.fromRectAndRadius(
      Rect.fromLTWH(size.x * 0.18, size.y * 0.30, size.x * 0.64, size.y * 0.65),
      Radius.circular(size.x * 0.18),
    );
    canvas.drawRRect(bodyRect, Paint()..color = const Color(0xFFD32F2F));
    // Cap on top.
    canvas.drawOval(
      Rect.fromLTWH(size.x * 0.10, size.y * 0.20, size.x * 0.80, size.y * 0.20),
      Paint()..color = const Color(0xFFB71C1C),
    );
    // Side nozzles.
    canvas.drawOval(
      Rect.fromLTWH(0, size.y * 0.45, size.x * 0.22, size.y * 0.20),
      Paint()..color = const Color(0xFFB71C1C),
    );
    canvas.drawOval(
      Rect.fromLTWH(size.x * 0.78, size.y * 0.45, size.x * 0.22, size.y * 0.20),
      Paint()..color = const Color(0xFFB71C1C),
    );

    // Water burst: 3 blue arcs above the cap, oscillating scale 0.8..1.0.
    final pulse =
        0.8 + 0.2 * (0.5 + 0.5 * sin(_life * 2 * pi * 3));
    final centerX = size.x / 2;
    final baseY = size.y * 0.18;
    final blue = Paint()
      ..color = const Color(0xFF42A5F5)
      ..strokeWidth = 3
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    for (var i = -1; i <= 1; i++) {
      final dx = i * size.x * 0.32 * pulse;
      final dy = -size.y * 0.28 * pulse;
      final p = Path()
        ..moveTo(centerX, baseY)
        ..quadraticBezierTo(
          centerX + dx * 0.5,
          baseY + dy * 0.8,
          centerX + dx,
          baseY + dy,
        );
      canvas.drawPath(p, blue);
    }
    // Light water dots near the cap.
    final dotPaint = Paint()..color = const Color(0xFFBBDEFB);
    canvas.drawCircle(Offset(centerX, baseY - 4), 2 * pulse, dotPaint);
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
