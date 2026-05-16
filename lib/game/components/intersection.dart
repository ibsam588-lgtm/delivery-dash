import 'dart:ui' as ui;
import 'package:flame/collisions.dart';
import 'package:flame/components.dart';
import 'package:flutter/painting.dart' hide Gradient;
import '../delivery_dash_game.dart';
import 'parked_car.dart' show renderTopDownCar;
import 'player.dart';

/// Cleaner, wider Paperboy-style crossroads with no cross traffic.
///
/// Cars now come from ahead only through the normal obstacle spawner. The
/// intersection is purely a readable road feature with stop bars, crosswalks,
/// curbs, and traffic lights.
class IntersectionComponent extends PositionComponent
    with HasGameRef<DeliveryDashGame> {
  static const double bandHeight = 170;
  static const double _lightCycleTime = 3.0;

  bool _spawnedPedestrians = false;
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
    if (onScreen && !_spawnedPedestrians) {
      _spawnedPedestrians = true;
      _spawnPedestrians();
    }
    if (position.y > gameRef.size.y + bandHeight) removeFromParent();
  }

  void _spawnPedestrians() {
    for (int i = 0; i < 2; i++) {
      gameRef.add(CrossingPedestrianComponent(
        bandY: position.y + bandHeight * 0.48 + (i - 0.5) * 18,
        leftToRight: i.isEven,
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

    final sidePaint = Paint()
      ..shader = ui.Gradient.linear(
        const Offset(0, 0),
        Offset(0, h),
        const [Color(0xFF3E4648), Color(0xFF22282A)],
      );
    canvas.drawRect(Rect.fromLTWH(0, h * 0.32, size.x, h * 0.36), sidePaint);

    final sidewalk = Paint()..color = const Color(0xFFE8E0CF);
    final grass = Paint()..color = const Color(0xFF4CAF50);
    canvas.drawRect(Rect.fromLTWH(0, 0, leftEdge, h), grass);
    canvas.drawRect(Rect.fromLTWH(rightEdge, 0, size.x - rightEdge, h), grass);
    canvas.drawRect(Rect.fromLTWH(0, h * 0.08, leftEdge, h * 0.20), sidewalk);
    canvas.drawRect(Rect.fromLTWH(rightEdge, h * 0.08, size.x - rightEdge, h * 0.20), sidewalk);
    canvas.drawRect(Rect.fromLTWH(0, h * 0.72, leftEdge, h * 0.20), sidewalk);
    canvas.drawRect(Rect.fromLTWH(rightEdge, h * 0.72, size.x - rightEdge, h * 0.20), sidewalk);

    final roadPaint = Paint()..color = const Color(0xFF25292B);
    canvas.drawRect(Rect.fromLTWH(leftEdge, 0, roadW, h), roadPaint);

    final curbPaint = Paint()
      ..color = const Color(0xFFF5F1E5)
      ..strokeWidth = 4.0;
    canvas.drawLine(Offset(leftEdge, 0), Offset(leftEdge, h), curbPaint);
    canvas.drawLine(Offset(rightEdge, 0), Offset(rightEdge, h), curbPaint);

    final yellow = Paint()..color = const Color(0xFFFFC928);
    _drawCrossStreetDashes(canvas, 8, leftEdge - 8, h, yellow);
    _drawCrossStreetDashes(canvas, rightEdge + 8, size.x - 8, h, yellow);

    final stopPaint = Paint()
      ..color = const Color(0xFFF8F6E8)
      ..strokeWidth = 4.0;
    canvas.drawLine(Offset(leftEdge + 8, h * 0.24), Offset(rightEdge - 8, h * 0.24), stopPaint);
    canvas.drawLine(Offset(leftEdge + 8, h * 0.76), Offset(rightEdge - 8, h * 0.76), stopPaint);

    final stripePaint = Paint()..color = const Color(0xFFEDEBE0);
    _drawCrosswalk(canvas, leftEdge + 14, rightEdge - 14, h * 0.31, stripePaint);
    _drawCrosswalk(canvas, leftEdge + 14, rightEdge - 14, h * 0.61, stripePaint);

    final lanePaint = Paint()
      ..color = const Color(0x99FFC928)
      ..strokeWidth = 2.0;
    canvas.drawLine(Offset((leftEdge + rightEdge) / 2, 0), Offset((leftEdge + rightEdge) / 2, h), lanePaint);

    _drawStopText(canvas, leftEdge, rightEdge, h * 0.80);
    _drawTrafficLight(canvas, leftEdge - 20, h * 0.18, _isGreen);
    _drawTrafficLight(canvas, rightEdge + 4, h * 0.58, _isGreen);
  }

  void _drawCrossStreetDashes(Canvas canvas, double left, double right, double h, Paint paint) {
    double x = left;
    while (x < right - 12) {
      canvas.drawRect(Rect.fromLTWH(x, h * 0.49, 18, 4), paint);
      x += 34;
    }
  }

  void _drawCrosswalk(Canvas canvas, double left, double right, double y, Paint paint) {
    const stripeW = 7.0;
    const gap = 9.0;
    const stripeH = 22.0;
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
          fontSize: 14,
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
    canvas.drawRect(Rect.fromLTWH(x + 7, y + 28, 3, 42), Paint()..color = const Color(0xFF2A2A2A));
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
  static const double speed = 48;

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
    return colors[DateTime.now().millisecond % colors.length];
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
    final swing = (_animTimer * 6.0) % 2 > 1 ? 3.0 : -3.0;

    canvas.drawOval(Rect.fromCenter(center: Offset(w / 2, h - 1), width: w * 0.7, height: 4), Paint()..color = const Color(0x66000000));
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
      3.14,
      3.14,
      false,
      Paint()..color = const Color(0xFF3E2723),
    );
  }
}
