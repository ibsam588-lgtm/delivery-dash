import 'dart:math';
import 'dart:ui' as ui;
import 'package:flame/collisions.dart';
import 'package:flame/components.dart';
import 'package:flutter/painting.dart' hide Gradient;
import '../delivery_dash_game.dart';
import 'parked_car.dart' show renderTopDownCar;
import 'player.dart';

/// Cleaner Paperboy-style crossroads.
///
/// The old zebra stripes rendered as large white blocks on top of the road.
/// This version uses thinner stop bars, narrow crosswalk strokes, and compact
/// traffic lights so the road remains readable while riding.
class IntersectionComponent extends PositionComponent
    with HasGameRef<DeliveryDashGame> {
  static const double bandHeight = 150;
  static const int _maxCarsPerIntersection = 2;
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
        if (_spawnTimer >= 1.15) {
          _spawnTimer = 0;
          if (_rng.nextDouble() < 0.55) _spawnCar();
        }
      }
    }
    if (position.y > gameRef.size.y + bandHeight) removeFromParent();
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
    final count = 1 + _rng.nextInt(2);
    for (int i = 0; i < count; i++) {
      gameRef.add(CrossingPedestrianComponent(
        bandY: position.y + bandHeight * 0.5 + (i - count / 2) * 12,
        leftToRight: _rng.nextBool(),
        delay: i * 0.45,
      ));
    }
  }

  @override
  void render(Canvas canvas) {
    final h = size.y;
    final lm = gameRef.laneManager;
    final leftEdge = lm.roadLeft;
    final rightEdge = lm.roadRight;
    final roadW = rightEdge - leftEdge;

    // Cross street behind the main road.
    final sidePaint = Paint()
      ..shader = ui.Gradient.linear(
        const Offset(0, 0),
        Offset(0, h),
        const [Color(0xFF333739), Color(0xFF202426)],
      );
    canvas.drawRect(Rect.fromLTWH(0, h * 0.30, size.x, h * 0.40), sidePaint);

    // Sidewalk corners / curb pads.
    final curbPaint = Paint()..color = const Color(0xFFE8E0CF);
    canvas.drawRect(Rect.fromLTWH(0, 0, leftEdge, h * 0.30), curbPaint);
    canvas.drawRect(Rect.fromLTWH(rightEdge, 0, size.x - rightEdge, h * 0.30), curbPaint);
    canvas.drawRect(Rect.fromLTWH(0, h * 0.70, leftEdge, h * 0.30), curbPaint);
    canvas.drawRect(Rect.fromLTWH(rightEdge, h * 0.70, size.x - rightEdge, h * 0.30), curbPaint);

    final roadPaint = Paint()..color = const Color(0xFF25292B);
    canvas.drawRect(Rect.fromLTWH(leftEdge, 0, roadW, h), roadPaint);

    // Cross-street yellow dash lines only outside the main road.
    final yellow = Paint()..color = const Color(0xFFFFC928);
    double x = 8;
    while (x < leftEdge - 6) {
      canvas.drawRect(Rect.fromLTWH(x, h * 0.485, 18, 4), yellow);
      x += 32;
    }
    x = rightEdge + 8;
    while (x < size.x - 6) {
      canvas.drawRect(Rect.fromLTWH(x, h * 0.485, 18, 4), yellow);
      x += 32;
    }

    // Thin stop bars across the main road.
    final stopPaint = Paint()
      ..color = const Color(0xFFF8F6E8)
      ..strokeWidth = 4.0
      ..strokeCap = StrokeCap.butt;
    canvas.drawLine(Offset(leftEdge + 6, h * 0.25), Offset(rightEdge - 6, h * 0.25), stopPaint);
    canvas.drawLine(Offset(leftEdge + 6, h * 0.75), Offset(rightEdge - 6, h * 0.75), stopPaint);

    // Narrow crosswalk strokes, not blocky slabs.
    final stripePaint = Paint()..color = const Color(0xFFEDEBE0);
    _drawCrosswalk(canvas, leftEdge + 10, rightEdge - 10, h * 0.30, stripePaint);
    _drawCrosswalk(canvas, leftEdge + 10, rightEdge - 10, h * 0.64, stripePaint);

    // Yellow intersection corner marks.
    final boxPaint = Paint()
      ..color = const Color(0xCCFFC928)
      ..strokeWidth = 3.0
      ..style = PaintingStyle.stroke;
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTRB(leftEdge + 10, h * 0.34, rightEdge - 10, h * 0.66),
        const Radius.circular(4),
      ),
      boxPaint,
    );

    if (position.y + h > gameRef.size.y * 0.45 &&
        position.y + h < gameRef.size.y) {
      _drawStopText(canvas, leftEdge, rightEdge, h * 0.78);
    }

    // Only two visible signal posts. Four looked cluttered on phone screens.
    _drawTrafficLight(canvas, leftEdge - 18, h * 0.18, _isGreen);
    _drawTrafficLight(canvas, rightEdge + 6, h * 0.58, _isGreen);
  }

  void _drawCrosswalk(Canvas canvas, double left, double right, double y, Paint paint) {
    const stripeW = 8.0;
    const gap = 8.0;
    const stripeH = 18.0;
    double sx = left;
    while (sx + stripeW < right) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(sx, y, stripeW, stripeH),
          const Radius.circular(1.5),
        ),
        paint,
      );
      sx += stripeW + gap;
    }
  }

  void _drawStopText(Canvas canvas, double leftEdge, double rightEdge, double y) {
    final painter = TextPainter(
      text: const TextSpan(
        text: 'STOP',
        style: TextStyle(
          color: Color(0xFFEDEBE0),
          fontSize: 15,
          fontWeight: FontWeight.w900,
          letterSpacing: 2.0,
        ),
      ),
      textDirection: TextDirection.ltr,
    );
    painter.layout();
    painter.paint(canvas, Offset((leftEdge + rightEdge - painter.width) / 2, y));
  }

  void _drawTrafficLight(Canvas canvas, double x, double y, bool isGreen) {
    canvas.drawRect(
      Rect.fromLTWH(x + 7, y + 28, 3, 42),
      Paint()..color = const Color(0xFF2A2A2A),
    );
    canvas.drawOval(
      Rect.fromCenter(center: Offset(x + 8.5, y + 70), width: 18, height: 8),
      Paint()..color = const Color(0x66000000),
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(Rect.fromLTWH(x, y, 17, 29), const Radius.circular(4)),
      Paint()..color = const Color(0xFF101010),
    );
    void bulb(double cy, Color on, Color off, bool active) {
      canvas.drawCircle(Offset(x + 8.5, y + cy), 3.4, Paint()..color = active ? on : off);
      if (active) {
        canvas.drawCircle(Offset(x + 8.5, y + cy), 6.0, Paint()..color = on.withValues(alpha: 0.24));
      }
    }
    bulb(6.5, const Color(0xFFFF5252), const Color(0xFF641A1A), !isGreen);
    bulb(14.5, const Color(0xFFFFD54F), const Color(0xFF6D5100), false);
    bulb(22.5, const Color(0xFF66BB6A), const Color(0xFF1B5E20), isGreen);
  }
}

class CrossingCarComponent extends PositionComponent
    with HasGameRef<DeliveryDashGame>, CollisionCallbacks {
  static const double speed = 260;

  final bool inLeftStrip;
  final int variant;
  bool _hasHit = false;

  CrossingCarComponent({
    required double spawnY,
    required this.inLeftStrip,
    required this.variant,
  }) : super(
          size: Vector2(48, 84),
          anchor: Anchor.center,
          priority: 10,
        ) {
    position.y = spawnY;
  }

  @override
  Future<void> onLoad() async {
    final lm = gameRef.laneManager;
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
    position.y += (speed + gameRef.scrollSpeed) * dt;
    if (position.y > gameRef.size.y + size.y) removeFromParent();
  }

  @override
  void render(Canvas canvas) {
    canvas.drawOval(
      Rect.fromCenter(center: Offset(size.x / 2, size.y - 4), width: size.x * 0.85, height: 10),
      Paint()..color = const Color(0x66000000),
    );
    renderTopDownCar(canvas, size.x, size.y, variant);
  }

  @override
  void onCollisionStart(Set<Vector2> intersectionPoints, PositionComponent other) {
    super.onCollisionStart(intersectionPoints, other);
    if (_hasHit) return;
    if (other is PlayerComponent) {
      _hasHit = true;
      gameRef.onPlayerHitObstacle();
    }
  }
}

class CrossingPedestrianComponent extends PositionComponent
    with HasGameRef<DeliveryDashGame> {
  static const double speed = 54;

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
        super(size: Vector2(13, 23), anchor: Anchor.center, priority: 4) {
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
      ..strokeWidth = 2.4
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(Offset(w * 0.40, h * 0.60), Offset(w * 0.40 + swing * 0.5, h * 0.95), legPaint);
    canvas.drawLine(Offset(w * 0.60, h * 0.60), Offset(w * 0.60 - swing * 0.5, h * 0.95), legPaint);
    canvas.drawRRect(
      RRect.fromRectAndRadius(Rect.fromLTWH(w * 0.20, h * 0.32, w * 0.60, h * 0.30), const Radius.circular(2)),
      Paint()..color = _shirtColor,
    );
    canvas.drawCircle(Offset(w * 0.50, h * 0.18), w * 0.30, Paint()..color = const Color(0xFFFFCC99));
    canvas.drawArc(
      Rect.fromCenter(center: Offset(w * 0.50, h * 0.16), width: w * 0.60, height: w * 0.50),
      pi,
      pi,
      false,
      Paint()..color = const Color(0xFF3E2723),
    );
  }
}
