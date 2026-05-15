import 'dart:math';
import 'dart:ui' as ui;
import 'package:flame/collisions.dart';
import 'package:flame/components.dart';
import 'package:flutter/painting.dart';
import '../delivery_dash_game.dart';
import 'player.dart';

/// Crossroads — the main road continues, a cross-street goes left/right.
/// Renders zebra crossing, larger traffic lights with a 3-s red/green cycle,
/// and lets [CrossingCarComponent]s drive across only on green.
class IntersectionComponent extends PositionComponent
    with HasGameRef<DeliveryDashGame> {
  static const double bandHeight = 130;

  // Cap concurrent traffic per intersection.
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
    // Randomise starting phase so not all intersections are in sync.
    _lightTimer = _rng.nextDouble() * _lightCycleTime;
    _isGreen = _rng.nextBool();
  }

  @override
  void update(double dt) {
    super.update(dt);
    if (gameRef.state != GameState.playing) return;
    position.y += gameRef.scrollSpeed * dt;

    // Advance traffic-light state.
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
    if (!_isGreen) return; // cars wait for green
    _carsSpawned++;
    final leftToRight = _rng.nextBool();
    gameRef.add(CrossingCarComponent(
      bandY: position.y + bandHeight / 2,
      leftToRight: leftToRight,
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

    final topY = position.y;
    final botY = position.y + h;
    final leftTop = lm.roadLeftAt(topY);
    final rightTop = lm.roadRightAt(topY);
    final leftBot = lm.roadLeftAt(botY);
    final rightBot = lm.roadRightAt(botY);

    // ── Cross-street asphalt (trapezoid strips outside main road) ────────
    final asphaltPaint = Paint()..color = const Color(0xFF2A2A2A);
    final leftStrip = Path()
      ..moveTo(0, 0)
      ..lineTo(leftTop, 0)
      ..lineTo(leftBot, h)
      ..lineTo(0, h)
      ..close();
    final rightStrip = Path()
      ..moveTo(rightTop, 0)
      ..lineTo(size.x, 0)
      ..lineTo(size.x, h)
      ..lineTo(rightBot, h)
      ..close();
    canvas.drawPath(leftStrip, asphaltPaint);
    canvas.drawPath(rightStrip, asphaltPaint);

    // Subtle random-dot texture on asphalt strips.
    final dotPaint = Paint()..color = const Color(0xFF222222);
    final rng = Random(42);
    for (int i = 0; i < 30; i++) {
      final dx = rng.nextDouble() * (leftBot) * 0.9;
      final dy = rng.nextDouble() * h;
      canvas.drawCircle(Offset(dx, dy), 1.0, dotPaint);
    }
    for (int i = 0; i < 30; i++) {
      final dx = rightTop + rng.nextDouble() * (size.x - rightTop) * 0.9;
      final dy = rng.nextDouble() * h;
      canvas.drawCircle(Offset(dx, dy), 1.0, dotPaint);
    }

    // Perspective shading on side strips.
    final shadePaint = Paint()
      ..shader = ui.Gradient.linear(
        const Offset(0, 0),
        Offset(0, h),
        const [Color(0x33FFFFFF), Color(0x00FFFFFF)],
      );
    canvas.drawPath(leftStrip, shadePaint);
    canvas.drawPath(rightStrip, shadePaint);

    // Yellow dashed centre line of the cross-street.
    final yellowPaint = Paint()..color = const Color(0xFFFFD600);
    double cx = 0;
    while (cx < size.x) {
      canvas.drawRect(
        Rect.fromLTWH(cx, h * 0.47, 18, 5),
        yellowPaint,
      );
      cx += 30;
    }

    // ── Zebra crossing stripes ────────────────────────────────────────────
    final stripePaint = Paint()..color = const Color(0xFFFFFFFF);
    const stripeW = 18.0;
    const stripeGap = 10.0;
    const stripeBandH = 20.0;
    // Top stripes.
    var sx = leftTop + 4;
    while (sx + stripeW < rightTop - 4) {
      canvas.drawRect(Rect.fromLTWH(sx, 5, stripeW, stripeBandH), stripePaint);
      sx += stripeW + stripeGap;
    }
    // Bottom stripes.
    sx = leftBot + 4;
    while (sx + stripeW < rightBot - 4) {
      canvas.drawRect(
        Rect.fromLTWH(sx, h - stripeBandH - 5, stripeW, stripeBandH),
        stripePaint,
      );
      sx += stripeW + stripeGap;
    }

    // ── STOP text on road ─────────────────────────────────────────────────
    if (position.y + h > gameRef.size.y * 0.5 &&
        position.y + h < gameRef.size.y) {
      _drawStopText(canvas, leftBot, rightBot, h - stripeBandH - 5);
    }

    // ── Traffic lights at 4 corners ───────────────────────────────────────
    _drawTrafficLight(canvas, leftTop - 18, 4, _isGreen);
    _drawTrafficLight(canvas, rightTop + 5, 4, _isGreen);
    _drawTrafficLight(canvas, leftBot - 18, h - 30, _isGreen);
    _drawTrafficLight(canvas, rightBot + 5, h - 30, _isGreen);
  }

  void _drawStopText(
      Canvas canvas, double leftBot, double rightBot, double yBaseline) {
    final cxText = (leftBot + rightBot) / 2;
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
      Rect.fromLTWH(x + 6, y, 3, 34),
      Paint()..color = const Color(0xFF333333),
    );
    // Housing (larger than before).
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(x, y, 16, 28),
        const Radius.circular(3),
      ),
      Paint()..color = const Color(0xFF111111),
    );
    // Red light (top) — active when !isGreen.
    canvas.drawCircle(
      Offset(x + 8, y + 5.5),
      3.0,
      Paint()
        ..color = isGreen
            ? const Color(0xFF7F1C1C)
            : const Color(0xFFEF5350),
    );
    if (!isGreen) {
      // Glow around active red.
      canvas.drawCircle(
        Offset(x + 8, y + 5.5),
        5.0,
        Paint()..color = const Color(0x44EF5350),
      );
    }
    // Yellow (middle) — always dim.
    canvas.drawCircle(
      Offset(x + 8, y + 14),
      3.0,
      Paint()..color = const Color(0xFF7A5900),
    );
    // Green light (bottom) — active when isGreen.
    canvas.drawCircle(
      Offset(x + 8, y + 22.5),
      3.0,
      Paint()
        ..color = isGreen
            ? const Color(0xFF66BB6A)
            : const Color(0xFF1B5E20),
    );
    if (isGreen) {
      // Glow around active green.
      canvas.drawCircle(
        Offset(x + 8, y + 22.5),
        5.0,
        Paint()..color = const Color(0x4466BB6A),
      );
    }
  }
}

/// A car driving across the intersection (side view, no rotation).
class CrossingCarComponent extends PositionComponent
    with HasGameRef<DeliveryDashGame>, CollisionCallbacks {
  static const double speed = 300;

  static const List<Color> _bodyColors = [
    Color(0xFFE53935), // red
    Color(0xFF1565C0), // blue
    Color(0xFF9E9E9E), // silver
    Color(0xFFFBC02D), // yellow
  ];

  final bool leftToRight;
  final int variant;
  bool _hasHit = false;
  double _bandY;

  CrossingCarComponent({
    required double bandY,
    required this.leftToRight,
    required this.variant,
  })  : _bandY = bandY,
        super(
          size: Vector2(90, 40),
          anchor: Anchor.center,
          priority: 10,
        ) {
    position = Vector2(0, bandY);
  }

  @override
  Future<void> onLoad() async {
    position.x = leftToRight ? -size.x : gameRef.size.x + size.x;
    add(RectangleHitbox(
      size: Vector2(size.x * 0.88, size.y * 0.80),
      position: Vector2(size.x * 0.06, size.y * 0.10),
    ));
  }

  @override
  void update(double dt) {
    super.update(dt);
    if (gameRef.state != GameState.playing) return;
    position.x += (leftToRight ? 1 : -1) * speed * dt;
    _bandY += gameRef.scrollSpeed * dt;
    position.y = _bandY;
    if (position.x < -size.x * 2 || position.x > gameRef.size.x + size.x * 2) {
      removeFromParent();
    }
    if (_bandY > gameRef.size.y + size.y) removeFromParent();
  }

  @override
  void render(Canvas canvas) {
    _renderSideViewCar(
      canvas,
      size.x,
      size.y,
      _bodyColors[variant % _bodyColors.length],
      leftToRight,
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

/// Draws a side-view car in a [w]×[h] canvas. [facingRight] mirrors the car.
void _renderSideViewCar(
    Canvas canvas, double w, double h, Color body, bool facingRight) {
  if (!facingRight) {
    canvas.save();
    canvas.translate(w, 0);
    canvas.scale(-1, 1);
  }

  // Shadow.
  canvas.drawOval(
    Rect.fromCenter(
      center: Offset(w * 0.50, h * 0.96),
      width: w * 0.80,
      height: h * 0.14,
    ),
    Paint()..color = const Color(0x44000000),
  );

  // Body silhouette (sedan profile).
  final bodyPath = Path()
    ..moveTo(w * 0.04, h * 0.60) // front-bottom
    ..lineTo(w * 0.10, h * 0.26) // front windshield base
    ..lineTo(w * 0.26, h * 0.04) // front windshield top
    ..lineTo(w * 0.64, h * 0.04) // rear windshield top
    ..lineTo(w * 0.82, h * 0.26) // rear windshield base
    ..lineTo(w * 0.96, h * 0.52) // trunk top
    ..lineTo(w * 0.96, h * 0.68) // rear bottom
    ..lineTo(w * 0.04, h * 0.68) // front bottom
    ..close();
  canvas.drawPath(bodyPath, Paint()..color = body);

  // Body gradient shading (top lighter).
  canvas.drawPath(
    bodyPath,
    Paint()
      ..shader = ui.Gradient.linear(
        Offset(0, h * 0.04),
        Offset(0, h * 0.68),
        [
          const Color(0x44FFFFFF),
          const Color(0x00FFFFFF),
        ],
      ),
  );

  // Cabin glass area.
  final windowPath = Path()
    ..moveTo(w * 0.12, h * 0.28)
    ..lineTo(w * 0.28, h * 0.07)
    ..lineTo(w * 0.62, h * 0.07)
    ..lineTo(w * 0.80, h * 0.28)
    ..close();
  canvas.drawPath(windowPath, Paint()..color = const Color(0x9990CAF9));
  // Window frame.
  canvas.drawPath(
    windowPath,
    Paint()
      ..color = const Color(0x55000000)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0,
  );
  // B-pillar (between front and rear windows).
  canvas.drawLine(
    Offset(w * 0.50, h * 0.07),
    Offset(w * 0.51, h * 0.28),
    Paint()
      ..color = const Color(0xFF333333)
      ..strokeWidth = 4.0,
  );

  // Door line.
  canvas.drawLine(
    Offset(w * 0.50, h * 0.28),
    Offset(w * 0.50, h * 0.65),
    Paint()
      ..color = const Color(0x33000000)
      ..strokeWidth = 1.5,
  );

  // Wheels.
  _drawSideWheel(canvas, Offset(w * 0.19, h * 0.78), h * 0.25);
  _drawSideWheel(canvas, Offset(w * 0.79, h * 0.78), h * 0.25);

  // Wheel arches.
  canvas.drawArc(
    Rect.fromCenter(center: Offset(w * 0.19, h * 0.70), width: h * 0.54, height: h * 0.44),
    pi, pi, false,
    Paint()..color = _darkenC(body, 0.12)..style = PaintingStyle.stroke..strokeWidth = 5.0,
  );
  canvas.drawArc(
    Rect.fromCenter(center: Offset(w * 0.79, h * 0.70), width: h * 0.54, height: h * 0.44),
    pi, pi, false,
    Paint()..color = _darkenC(body, 0.12)..style = PaintingStyle.stroke..strokeWidth = 5.0,
  );

  // Headlight (front = right side since facingRight).
  canvas.drawOval(
    Rect.fromCenter(
        center: Offset(w * 0.07, h * 0.44), width: w * 0.07, height: h * 0.15),
    Paint()..color = const Color(0xFFFFEE99),
  );
  // Tail light (rear).
  canvas.drawOval(
    Rect.fromCenter(
        center: Offset(w * 0.93, h * 0.44), width: w * 0.07, height: h * 0.15),
    Paint()..color = const Color(0xFFEF5350),
  );

  // Body outline.
  canvas.drawPath(
    bodyPath,
    Paint()
      ..color = const Color(0x44000000)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0,
  );

  if (!facingRight) canvas.restore();
}

void _drawSideWheel(Canvas canvas, Offset center, double r) {
  canvas.drawCircle(center, r * 1.05, Paint()..color = const Color(0xFF111111));
  canvas.drawCircle(center, r, Paint()..color = const Color(0xFF1A1A1A));
  canvas.drawCircle(center, r * 0.62, Paint()..color = const Color(0xFFAAAAAA));
  // Spokes (5).
  for (int i = 0; i < 5; i++) {
    final a = i * 2 * pi / 5;
    canvas.drawLine(
      Offset(center.dx + cos(a) * r * 0.10, center.dy + sin(a) * r * 0.10),
      Offset(center.dx + cos(a) * r * 0.58, center.dy + sin(a) * r * 0.58),
      Paint()..color = const Color(0xFF777777)..strokeWidth = 1.5,
    );
  }
  canvas.drawCircle(center, r * 0.15, Paint()..color = const Color(0xFF555555));
}

Color _darkenC(Color c, double amount) {
  final inv = 1.0 - amount;
  return Color.fromARGB(
    ((c.a * 255).clamp(0.0, 255.0)).round(),
    ((c.r * 255 * inv).clamp(0.0, 255.0)).round(),
    ((c.g * 255 * inv).clamp(0.0, 255.0)).round(),
    ((c.b * 255 * inv).clamp(0.0, 255.0)).round(),
  );
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
