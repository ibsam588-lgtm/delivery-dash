import 'dart:math';
import 'dart:ui';
import 'package:flame/collisions.dart';
import 'package:flame/components.dart';
import '../delivery_dash_game.dart';
import 'parked_car.dart' show renderTopDownCar;
import 'player.dart';

/// A horizontal cross-street that scrolls down with the world. While it
/// is on-screen it spawns [CrossingCarComponent]s that drive across the
/// road. Players must dodge them.
class IntersectionComponent extends PositionComponent
    with HasGameRef<DeliveryDashGame> {
  static const double bandHeight = 100;

  final Random _rng = Random();
  double _spawnTimer = 0;
  bool _spawnedFirst = false;

  IntersectionComponent()
      : super(
          size: Vector2(0, bandHeight),
          anchor: Anchor.topLeft,
          priority: -9,
        );

  @override
  Future<void> onLoad() async {
    size = Vector2(gameRef.size.x, bandHeight);
    position = Vector2(0, -bandHeight);
  }

  @override
  void update(double dt) {
    super.update(dt);
    if (gameRef.state != GameState.playing) return;
    position.y += gameRef.scrollSpeed * dt;

    final onScreen = position.y + bandHeight > 0 && position.y < gameRef.size.y;
    if (onScreen) {
      if (!_spawnedFirst) {
        _spawnedFirst = true;
        _spawnCar();
      }
      _spawnTimer += dt;
      if (_spawnTimer >= 0.8) {
        _spawnTimer = 0;
        if (_rng.nextDouble() < 0.7) _spawnCar();
      }
    }
    if (position.y > gameRef.size.y) removeFromParent();
  }

  void _spawnCar() {
    final leftToRight = _rng.nextBool();
    gameRef.add(CrossingCarComponent(
      bandY: position.y + bandHeight / 2,
      leftToRight: leftToRight,
      variant: _rng.nextInt(2),
    ));
  }

  @override
  void render(Canvas canvas) {
    final h = size.y;
    final lm = gameRef.laneManager;

    // Asphalt cross-street: a band that spans only the road width at the
    // band's Y (so houses & grass outside the road remain visible). The
    // road tapers with perspective, so use the road bounds at top & bottom
    // of this band (in world coords) to build a parallelogram.
    final topY = position.y;
    final botY = position.y + h;
    final leftTop = lm.roadLeftAt(topY);
    final rightTop = lm.roadRightAt(topY);
    final leftBot = lm.roadLeftAt(botY);
    final rightBot = lm.roadRightAt(botY);

    final asphaltPath = Path()
      ..moveTo(leftTop, 0)
      ..lineTo(rightTop, 0)
      ..lineTo(rightBot, h)
      ..lineTo(leftBot, h)
      ..close();
    canvas.drawPath(
      asphaltPath,
      Paint()..color = const Color(0xFF2A2A2A),
    );

    // Crosswalk stripes near top and bottom of the band.
    final stripePaint = Paint()..color = const Color(0xFFFFFFFF);
    const stripeW = 18.0;
    const stripeGap = 12.0;
    const stripeH = 14.0;
    // Stripes at top edge — use roadLeftAt(topY).
    var cx = leftTop + 4;
    while (cx + stripeW < rightTop - 4) {
      canvas.drawRect(
        Rect.fromLTWH(cx, 4, stripeW, stripeH),
        stripePaint,
      );
      cx += stripeW + stripeGap;
    }
    // Stripes at bottom edge — use roadLeftAt(botY).
    cx = leftBot + 4;
    while (cx + stripeW < rightBot - 4) {
      canvas.drawRect(
        Rect.fromLTWH(cx, h - stripeH - 4, stripeW, stripeH),
        stripePaint,
      );
      cx += stripeW + stripeGap;
    }
  }
}

class CrossingCarComponent extends PositionComponent
    with HasGameRef<DeliveryDashGame>, CollisionCallbacks {
  static const double speed = 320;

  static const List<Color> _bodyColors = [
    Color(0xFFE53935),
    Color(0xFF1565C0),
    Color(0xFF9E9E9E),
    Color(0xFFFBC02D),
  ];

  final bool leftToRight;
  final int variant;
  bool _hasHit = false;

  CrossingCarComponent({
    required double bandY,
    required this.leftToRight,
    required this.variant,
  }) : super(
          size: Vector2(80, 50),
          anchor: Anchor.center,
          priority: 3,
        ) {
    position = Vector2(0, bandY);
  }

  @override
  Future<void> onLoad() async {
    final startX = leftToRight ? -size.x : gameRef.size.x + size.x;
    position.x = startX;
    angle = leftToRight ? pi / 2 : -pi / 2;
    add(RectangleHitbox(
      size: Vector2(size.x * 0.85, size.y * 0.78),
      position: Vector2(size.x * 0.075, size.y * 0.11),
    ));
  }

  @override
  void update(double dt) {
    super.update(dt);
    if (gameRef.state != GameState.playing) return;
    position.x += (leftToRight ? 1 : -1) * speed * dt;
    position.y += gameRef.scrollSpeed * dt;
    if (position.x < -size.x * 2 || position.x > gameRef.size.x + size.x * 2) {
      removeFromParent();
    }
    if (position.y > gameRef.size.y + size.y) removeFromParent();
  }

  @override
  void render(Canvas canvas) {
    renderTopDownCar(
      canvas, size.x, size.y, _bodyColors[variant % _bodyColors.length],
    );
  }

  @override
  void onCollisionStart(
      Set<Vector2> intersectionPoints, PositionComponent other) {
    super.onCollisionStart(intersectionPoints, other);
    if (_hasHit) return;
    if (other is PlayerComponent) {
      _hasHit = true;
      gameRef.onPlayerHitObstacle();
    }
  }
}
