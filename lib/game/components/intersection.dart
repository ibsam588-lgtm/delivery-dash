import 'dart:math';
import 'dart:ui' as ui;
import 'package:flame/collisions.dart';
import 'package:flame/components.dart';
import 'package:flutter/painting.dart';
import '../delivery_dash_game.dart';
import 'parked_car.dart' show renderTopDownCar;
import 'player.dart';

/// Crossroads — the main road continues, a cross-street goes left/right.
/// Renders zebra crossing, traffic-light poles, "STOP" on approach,
/// and lets [CrossingCarComponent]s drive across.
class IntersectionComponent extends PositionComponent
    with HasGameRef<DeliveryDashGame> {
  static const double bandHeight = 110;

  // Cap concurrent traffic per intersection so a slow-scrolling or paused
  // game can't accumulate dozens of crossing cars and bog down the game.
  static const int _maxCarsPerIntersection = 3;

  final Random _rng = Random();
  double _spawnTimer = 0;
  bool _spawnedFirst = false;
  bool _spawnedPedestrians = false;
  int _carsSpawned = 0;

  IntersectionComponent()
      : super(
          size: Vector2(0, bandHeight),
          anchor: Anchor.topLeft,
          priority: -8,
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
      if (!_spawnedPedestrians) {
        _spawnedPedestrians = true;
        _spawnPedestrians();
      }
      if (_carsSpawned < _maxCarsPerIntersection) {
        _spawnTimer += dt;
        if (_spawnTimer >= 0.8) {
          _spawnTimer = 0;
          if (_rng.nextDouble() < 0.7) _spawnCar();
        }
      }
    }
    if (position.y > gameRef.size.y) removeFromParent();
  }

  void _spawnCar() {
    if (_carsSpawned >= _maxCarsPerIntersection) return;
    _carsSpawned++;
    final leftToRight = _rng.nextBool();
    gameRef.add(CrossingCarComponent(
      bandY: position.y + bandHeight / 2,
      leftToRight: leftToRight,
      variant: _rng.nextInt(2),
    ));
  }

  void _spawnPedestrians() {
    // 2-3 pedestrians walking across the road on the zebra crossing.
    final count = 2 + _rng.nextInt(2);
    for (int i = 0; i < count; i++) {
      final leftToRight = _rng.nextBool();
      gameRef.add(CrossingPedestrianComponent(
        bandY: position.y + bandHeight * 0.5 + (i - count / 2) * 12,
        leftToRight: leftToRight,
        delay: i * 0.4,
      ));
    }
  }

  @override
  void render(Canvas canvas) {
    final h = size.y;
    final lm = gameRef.laneManager;

    final topY = position.y;
    final botY = position.y + h;
    final leftTop = lm.roadLeftAt(topY);
    final rightTop = lm.roadRightAt(topY);
    final leftBot = lm.roadLeftAt(botY);
    final rightBot = lm.roadRightAt(botY);

    // ── Cross-street asphalt — only outside the main road ────────────────
    // Draw two trapezoids (left strip and right strip) so the main road area
    // remains transparent and the road surface shows through.
    final asphaltPaint = Paint()..color = const Color(0xFF2A2A2A);

    // Left strip: (0,0) → (leftTop,0) → (leftBot,h) → (0,h)
    final leftStrip = Path()
      ..moveTo(0, 0)
      ..lineTo(leftTop, 0)
      ..lineTo(leftBot, h)
      ..lineTo(0, h)
      ..close();
    canvas.drawPath(leftStrip, asphaltPaint);

    // Right strip: (rightTop,0) → (size.x,0) → (size.x,h) → (rightBot,h)
    final rightStrip = Path()
      ..moveTo(rightTop, 0)
      ..lineTo(size.x, 0)
      ..lineTo(size.x, h)
      ..lineTo(rightBot, h)
      ..close();
    canvas.drawPath(rightStrip, asphaltPaint);

    // Subtle perspective shading — top slightly lighter, on both side strips.
    final shadePaint = Paint()
      ..shader = ui.Gradient.linear(
        const Offset(0, 0),
        Offset(0, h),
        const [Color(0x33FFFFFF), Color(0x00FFFFFF)],
      );
    canvas.drawPath(leftStrip, shadePaint);
    canvas.drawPath(rightStrip, shadePaint);

    // Yellow dashed lane line down centre of the cross-street.
    final yellowPaint = Paint()..color = const Color(0xFFFFD600);
    double cx = 0;
    while (cx < size.x) {
      canvas.drawRect(
        Rect.fromLTWH(cx, h * 0.48, 16, 4),
        yellowPaint,
      );
      cx += 28;
    }

    // ── Zebra crossing stripes — only across the main road's width ────────
    final stripePaint = Paint()..color = const Color(0xFFFFFFFF);
    const stripeW = 16.0;
    const stripeGap = 10.0;
    const stripeBandH = 18.0;
    // Stripes at top edge of intersection (entering from far away).
    var sx = leftTop + 4;
    while (sx + stripeW < rightTop - 4) {
      canvas.drawRect(
        Rect.fromLTWH(sx, 4, stripeW, stripeBandH),
        stripePaint,
      );
      sx += stripeW + stripeGap;
    }
    // Stripes at bottom edge (entering from close).
    sx = leftBot + 4;
    while (sx + stripeW < rightBot - 4) {
      canvas.drawRect(
        Rect.fromLTWH(sx, h - stripeBandH - 4, stripeW, stripeBandH),
        stripePaint,
      );
      sx += stripeW + stripeGap;
    }

    // ── "STOP" text on the road surface just below the bottom crossing ────
    // Render only when the bottom of the intersection is well within the
    // viewport, so the text reads properly.
    if (position.y + h > gameRef.size.y * 0.5 &&
        position.y + h < gameRef.size.y) {
      _drawStopText(canvas, leftBot, rightBot, h - stripeBandH - 4);
    }

    // ── Traffic-light poles at the 4 corners ──────────────────────────────
    _drawTrafficLight(canvas, leftTop - 12, 6);
    _drawTrafficLight(canvas, rightTop + 4, 6);
    _drawTrafficLight(canvas, leftBot - 12, h - 22);
    _drawTrafficLight(canvas, rightBot + 4, h - 22);
  }

  void _drawStopText(Canvas canvas, double leftBot, double rightBot,
      double yBaseline) {
    final cxText = (leftBot + rightBot) / 2;
    final textY = yBaseline - 24;
    // Stylised "STOP" — block letters scaled to read on the road.
    final painter = TextPainter(
      text: const TextSpan(
        text: 'STOP',
        style: TextStyle(
          color: Color(0xFFFFFFFF),
          fontSize: 18,
          fontWeight: FontWeight.w900,
          letterSpacing: 2.0,
        ),
      ),
      textDirection: TextDirection.ltr,
    );
    painter.layout();
    painter.paint(canvas, Offset(cxText - painter.width / 2, textY));
  }

  void _drawTrafficLight(Canvas canvas, double x, double y) {
    // Pole.
    canvas.drawRect(
      Rect.fromLTWH(x + 4, y, 2, 26),
      Paint()..color = const Color(0xFF333333),
    );
    // Light housing.
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(x, y, 10, 18),
        const Radius.circular(2),
      ),
      Paint()..color = const Color(0xFF111111),
    );
    // Red light at top, yellow middle, green bottom.
    canvas.drawCircle(
        Offset(x + 5, y + 3.5), 1.6, Paint()..color = const Color(0xFFEF5350));
    canvas.drawCircle(
        Offset(x + 5, y + 9), 1.6, Paint()..color = const Color(0xFFFFC107));
    canvas.drawCircle(
        Offset(x + 5, y + 14.5), 1.6, Paint()..color = const Color(0xFF66BB6A));
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

/// Simple pedestrian walking across the zebra crossing.
class CrossingPedestrianComponent extends PositionComponent
    with HasGameRef<DeliveryDashGame> {
  static const double speed = 60;

  final bool leftToRight;
  double _delay;
  double _animTimer = 0;
  final Color _shirtColor;

  CrossingPedestrianComponent({
    required double bandY,
    required this.leftToRight,
    double delay = 0,
  })  : _delay = delay,
        _shirtColor = _pickShirtColor(),
        super(
          size: Vector2(14, 24),
          anchor: Anchor.center,
          priority: 4,
        ) {
    position = Vector2(0, bandY);
  }

  static Color _pickShirtColor() {
    final colors = [
      const Color(0xFF1976D2),
      const Color(0xFFE53935),
      const Color(0xFF43A047),
      const Color(0xFF8E24AA),
      const Color(0xFFFB8C00),
    ];
    return colors[Random().nextInt(colors.length)];
  }

  @override
  Future<void> onLoad() async {
    position.x = leftToRight ? -size.x : gameRef.size.x + size.x;
  }

  @override
  void update(double dt) {
    super.update(dt);
    if (gameRef.state != GameState.playing) return;
    if (_delay > 0) {
      _delay -= dt;
    } else {
      position.x += (leftToRight ? 1 : -1) * speed * dt;
      _animTimer += dt;
    }
    position.y += gameRef.scrollSpeed * dt;
    if (position.x < -size.x * 2 ||
        position.x > gameRef.size.x + size.x * 2 ||
        position.y > gameRef.size.y + size.y) {
      removeFromParent();
    }
  }

  @override
  void render(Canvas canvas) {
    if (_delay > 0) return;
    final w = size.x;
    final h = size.y;

    // Walking leg swing.
    final swing = sin(_animTimer * 6.0) * 3.0;

    // Shadow.
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(w / 2, h - 1),
        width: w * 0.7,
        height: 4,
      ),
      Paint()..color = const Color(0x66000000),
    );
    // Legs.
    final legPaint = Paint()
      ..color = const Color(0xFF1A1A1A)
      ..strokeWidth = 2.5
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(
      Offset(w * 0.40, h * 0.60),
      Offset(w * 0.40 + swing * 0.5, h * 0.95),
      legPaint,
    );
    canvas.drawLine(
      Offset(w * 0.60, h * 0.60),
      Offset(w * 0.60 - swing * 0.5, h * 0.95),
      legPaint,
    );
    // Torso.
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(w * 0.20, h * 0.32, w * 0.60, h * 0.30),
        const Radius.circular(2),
      ),
      Paint()..color = _shirtColor,
    );
    // Head.
    canvas.drawCircle(
      Offset(w * 0.50, h * 0.18),
      w * 0.30,
      Paint()..color = const Color(0xFFFFCC99),
    );
    // Hair cap.
    canvas.drawArc(
      Rect.fromCenter(
        center: Offset(w * 0.50, h * 0.16),
        width: w * 0.60,
        height: w * 0.50,
      ),
      pi, pi, false,
      Paint()..color = const Color(0xFF3E2723),
    );
  }
}
