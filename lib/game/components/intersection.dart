import 'dart:math';
import 'dart:ui' as ui;
import 'package:flame/collisions.dart';
import 'package:flame/components.dart';
import 'package:flutter/painting.dart' hide Gradient;
import '../delivery_dash_game.dart';
import 'parked_car.dart' show renderTopDownCar;
import 'player.dart';

/// Crossroads — the main road continues, a cross-street goes left/right.
/// Renders zebra crossing, traffic lights with a 3-s red/green cycle,
/// and spawns [CrossingCarComponent]s that drive downward through the
/// side strips (oncoming cross-traffic).
class IntersectionComponent extends PositionComponent
    with HasGameRef<DeliveryDashGame> {
  static const double bandHeight = 160;

  static const int _maxCarsPerIntersection = 3;
  static const double _lightCycleTime = 3.0;

  final Random _rng = Random();
  double _spawnTimer = 0;
  bool _spawnedFirst = false;
  bool _spawnedPedestrians = false;
  int _carsSpawned = 0;

  double _lightTimer = 0;
  bool _isGreen = true;

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
    _lightTimer = _rng.nextDouble() * _lightCycleTime;
    _isGreen = _rng.nextBool();
  }

  @override
  void update(double dt) {
    super.update(dt);
    if (gameRef.state != GameState.playing) return;
    position.y += gameRef.scrollSpeed * dt;

    _lightTimer += dt;
    if (_lightTimer >= _lightCycleTime) {
      _lightTimer -= _lightCycleTime;
      _isGreen = !_isGreen;
    }

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
        if (_spawnTimer >= 0.9) {
          _spawnTimer = 0;
          if (_rng.nextDouble() < 0.65) _spawnCar();
        }
      }
    }
    if (position.y > gameRef.size.y) removeFromParent();
  }

  void _spawnCar() {
    if (_carsSpawned >= _maxCarsPerIntersection) return;
    if (!_isGreen) return;
    _carsSpawned++;
    gameRef.add(CrossingCarComponent(
      spawnY: position.y,
      inLeftStrip: _rng.nextBool(),
      variant: _rng.nextInt(4),
    ));
  }

  void _spawnPedestrians() {
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

    // Use FIXED road edges — not y-dependent — so the strips don't
    // appear to oscillate as the band scrolls.
    final leftEdge = lm.roadLeft;
    final rightEdge = lm.roadRight;

    // ── Cross-street asphalt (rectangular side strips) ────────────────────
    final asphaltPaint = Paint()..color = const Color(0xFF2A2A2A);
    final leftStrip = Path()
      ..moveTo(0, 0)
      ..lineTo(leftEdge, 0)
      ..lineTo(leftEdge, h)
      ..lineTo(0, h)
      ..close();
    final rightStrip = Path()
      ..moveTo(rightEdge, 0)
      ..lineTo(size.x, 0)
      ..lineTo(size.x, h)
      ..lineTo(rightEdge, h)
      ..close();
    canvas.drawPath(leftStrip, asphaltPaint);
    canvas.drawPath(rightStrip, asphaltPaint);

    // Dot texture on strips.
    final dotPaint = Paint()..color = const Color(0xFF222222);
    final rng = Random(42);
    for (int i = 0; i < 30; i++) {
      canvas.drawCircle(
        Offset(rng.nextDouble() * leftEdge * 0.9, rng.nextDouble() * h),
        1.0, dotPaint,
      );
    }
    for (int i = 0; i < 30; i++) {
      canvas.drawCircle(
        Offset(rightEdge + rng.nextDouble() * (size.x - rightEdge) * 0.9,
            rng.nextDouble() * h),
        1.0, dotPaint,
      );
    }

    // Perspective shading on strips.
    canvas.drawPath(
      leftStrip,
      Paint()
        ..shader = ui.Gradient.linear(
          const Offset(0, 0),
          Offset(0, h),
          const [Color(0x33FFFFFF), Color(0x00FFFFFF)],
        ),
    );
    canvas.drawPath(
      rightStrip,
      Paint()
        ..shader = ui.Gradient.linear(
          const Offset(0, 0),
          Offset(0, h),
          const [Color(0x33FFFFFF), Color(0x00FFFFFF)],
        ),
    );

    // Yellow dashed centre line of the cross-street.
    final yellowPaint = Paint()..color = const Color(0xFFFFD600);
    double cx = 0;
    while (cx < size.x) {
      canvas.drawRect(Rect.fromLTWH(cx, h * 0.47, 18, 5), yellowPaint);
      cx += 30;
    }

    // ── Stop lines — solid white 8 px across the road at each edge ────────
    final stopPaint = Paint()
      ..color = const Color(0xFFFFFFFF)
      ..strokeWidth = 8.0
      ..strokeCap = StrokeCap.butt;
    canvas.drawLine(Offset(leftEdge, 8), Offset(rightEdge, 8), stopPaint);
    canvas.drawLine(Offset(leftEdge, h - 8), Offset(rightEdge, h - 8), stopPaint);

    // ── Yellow box junction ────────────────────────────────────────────────
    canvas.drawRect(
      Rect.fromLTRB(leftEdge + 4, h * 0.18, rightEdge - 4, h * 0.82),
      Paint()
        ..color = const Color(0xAAFFD600)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 4.0,
    );

    // ── Zebra crossing stripes (thicker) ──────────────────────────────────
    final stripePaint = Paint()..color = const Color(0xFFFFFFFF);
    const stripeW = 20.0;
    const stripeGap = 10.0;
    const stripeBandH = 24.0;
    // Top stripes.
    var sx = leftEdge + 4;
    while (sx + stripeW < rightEdge - 4) {
      canvas.drawRect(Rect.fromLTWH(sx, 14, stripeW, stripeBandH), stripePaint);
      sx += stripeW + stripeGap;
    }
    // Bottom stripes.
    sx = leftEdge + 4;
    while (sx + stripeW < rightEdge - 4) {
      canvas.drawRect(
        Rect.fromLTWH(sx, h - stripeBandH - 14, stripeW, stripeBandH),
        stripePaint,
      );
      sx += stripeW + stripeGap;
    }

    // ── STOP text ─────────────────────────────────────────────────────────
    if (position.y + h > gameRef.size.y * 0.5 &&
        position.y + h < gameRef.size.y) {
      _drawStopText(canvas, leftEdge, rightEdge, h - stripeBandH - 14);
    }

    // ── Traffic lights at 4 corners (bigger housing) ──────────────────────
    _drawTrafficLight(canvas, leftEdge - 22, 4, _isGreen);
    _drawTrafficLight(canvas, rightEdge + 4, 4, _isGreen);
    _drawTrafficLight(canvas, leftEdge - 22, h - 38, _isGreen);
    _drawTrafficLight(canvas, rightEdge + 4, h - 38, _isGreen);
  }

  void _drawStopText(
      Canvas canvas, double leftEdge, double rightEdge, double yBaseline) {
    final cxText = (leftEdge + rightEdge) / 2;
    final textY = yBaseline - 26;
    final painter = TextPainter(
      text: const TextSpan(
        text: 'STOP',
        style: TextStyle(
          color: Color(0xFFFFFFFF),
          fontSize: 20,
          fontWeight: FontWeight.w900,
          letterSpacing: 3.0,
        ),
      ),
      textDirection: TextDirection.ltr,
    );
    painter.layout();
    painter.paint(canvas, Offset(cxText - painter.width / 2, textY));
  }

  void _drawTrafficLight(Canvas canvas, double x, double y, bool isGreen) {
    // Pole.
    canvas.drawRect(
      Rect.fromLTWH(x + 8, y, 3, 42),
      Paint()..color = const Color(0xFF333333),
    );
    // Housing — bigger than before.
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(x, y, 20, 34),
        const Radius.circular(3),
      ),
      Paint()..color = const Color(0xFF111111),
    );
    // Red light (top).
    canvas.drawCircle(
      Offset(x + 10, y + 6.5),
      3.5,
      Paint()
        ..color = isGreen
            ? const Color(0xFF7F1C1C)
            : const Color(0xFFEF5350),
    );
    if (!isGreen) {
      canvas.drawCircle(
        Offset(x + 10, y + 6.5), 6.0,
        Paint()..color = const Color(0x44EF5350),
      );
    }
    // Yellow (middle) — always dim.
    canvas.drawCircle(
      Offset(x + 10, y + 17),
      3.5,
      Paint()..color = const Color(0xFF7A5900),
    );
    // Green light (bottom).
    canvas.drawCircle(
      Offset(x + 10, y + 27.5),
      3.5,
      Paint()
        ..color = isGreen
            ? const Color(0xFF66BB6A)
            : const Color(0xFF1B5E20),
    );
    if (isGreen) {
      canvas.drawCircle(
        Offset(x + 10, y + 27.5), 6.0,
        Paint()..color = const Color(0x4466BB6A),
      );
    }
  }
}

/// A car driving downward through the intersection side strip (cross-traffic).
/// Spawns at the top of the intersection band and drives toward the player.
class CrossingCarComponent extends PositionComponent
    with HasGameRef<DeliveryDashGame>, CollisionCallbacks {
  static const double speed = 280;

  final bool inLeftStrip;
  final int variant;
  bool _hasHit = false;

  CrossingCarComponent({
    required double spawnY,
    required this.inLeftStrip,
    required this.variant,
  }) : super(
          size: Vector2(50, 90),
          anchor: Anchor.center,
          priority: 10,
        ) {
    position.y = spawnY;
  }

  @override
  Future<void> onLoad() async {
    final lm = gameRef.laneManager;
    // Place in the centre of the left or right side strip.
    position.x = inLeftStrip
        ? lm.roadLeft / 2
        : lm.roadRight + (gameRef.size.x - lm.roadRight) / 2;
    add(RectangleHitbox(
      size: Vector2(size.x * 0.88, size.y * 0.85),
      position: Vector2(size.x * 0.06, size.y * 0.075),
    ));
  }

  @override
  void update(double dt) {
    super.update(dt);
    if (gameRef.state != GameState.playing) return;
    // Move downward at own speed + world scroll so the car moves through
    // the scene at [speed] px/s relative to the world.
    position.y += (speed + gameRef.scrollSpeed) * dt;
    if (position.y > gameRef.size.y + size.y) removeFromParent();
  }

  @override
  void render(Canvas canvas) {
    // Drop shadow.
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(size.x / 2, size.y - 4),
        width: size.x * 0.85,
        height: 10,
      ),
      Paint()..color = const Color(0x66000000),
    );
    renderTopDownCar(canvas, size.x, size.y, variant);
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
    final swing = sin(_animTimer * 6.0) * 3.0;

    canvas.drawOval(
      Rect.fromCenter(center: Offset(w / 2, h - 1), width: w * 0.7, height: 4),
      Paint()..color = const Color(0x66000000),
    );
    final legPaint = Paint()
      ..color = const Color(0xFF1A1A1A)
      ..strokeWidth = 2.5
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(Offset(w * 0.40, h * 0.60),
        Offset(w * 0.40 + swing * 0.5, h * 0.95), legPaint);
    canvas.drawLine(Offset(w * 0.60, h * 0.60),
        Offset(w * 0.60 - swing * 0.5, h * 0.95), legPaint);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
          Rect.fromLTWH(w * 0.20, h * 0.32, w * 0.60, h * 0.30),
          const Radius.circular(2)),
      Paint()..color = _shirtColor,
    );
    canvas.drawCircle(Offset(w * 0.50, h * 0.18), w * 0.30,
        Paint()..color = const Color(0xFFFFCC99));
    canvas.drawArc(
      Rect.fromCenter(
          center: Offset(w * 0.50, h * 0.16),
          width: w * 0.60,
          height: w * 0.50),
      pi, pi, false,
      Paint()..color = const Color(0xFF3E2723),
    );
  }
}
