import 'dart:math';
import 'dart:ui';
import 'package:flame/collisions.dart';
import 'package:flame/components.dart';
import '../delivery_dash_game.dart';
import '../perspective.dart';
import 'bike_trail.dart';

class PlayerComponent extends PositionComponent
    with HasGameRef<DeliveryDashGame>, CollisionCallbacks {
  static const Color vipTint = Color(0x88FFD54F);
  static const double _followSpeed = 8.0;
  static const double _flashInterval = 0.1;
  static const double _trailInterval = 0.06;

  final bool isVip;
  double _targetX = 0;
  double _flashTimer = 0;
  double _trailTimer = 0;
  double _opacity = 1.0;
  double _wetTimer = 0;
  double _wheelAngle = 0;
  static const double _wetDuration = 0.4;

  PlayerComponent({this.isVip = false})
      : super(size: Vector2(55, 80), anchor: Anchor.center, priority: 5);

  double get opacity => _opacity;
  set opacity(double v) => _opacity = v.clamp(0.0, 1.0);

  @override
  Future<void> onLoad() async {
    final lm = gameRef.laneManager;
    _targetX = lm.roadCenter;
    position = Vector2(_targetX, gameRef.size.y * 0.82);
    add(RectangleHitbox(
      size: Vector2(38, 62),
      position: Vector2((size.x - 38) / 2, (size.y - 62) / 2),
    ));
  }

  void moveTo(double worldX) {
    _targetX = gameRef.laneManager.clampToRoad(worldX, size.x / 2);
  }

  void triggerWetFlash() {
    _wetTimer = _wetDuration;
  }

  @override
  void update(double dt) {
    super.update(dt);

    _wheelAngle += dt * 14.0;

    final dx = _targetX - position.x;
    final t = (_followSpeed * dt).clamp(0.0, 1.0);
    position.x += dx * t;

    if (_wetTimer > 0) {
      _wetTimer = (_wetTimer - dt).clamp(0.0, _wetDuration);
    }

    if (gameRef.isInvincible) {
      _flashTimer += dt;
      if (_flashTimer >= _flashInterval) {
        _flashTimer = 0;
        _opacity = _opacity > 0.5 ? 0.25 : 1.0;
      }
    } else {
      _flashTimer = 0;
      if (_opacity != 1.0) _opacity = 1.0;
    }

    if (gameRef.state == GameState.playing) {
      _trailTimer += dt;
      if (_trailTimer >= _trailInterval) {
        _trailTimer = 0;
        gameRef.add(BikeTrailPuff(
          position: position + Vector2(0, size.y * 0.35),
        ));
      }
    }
  }

  @override
  void render(Canvas canvas) {
    final h = gameRef.size.y;
    final s = depthScale(position.y, h);
    final dx = depthXShift(
      position.x, position.y, gameRef.laneManager.roadCenter, h,
    );
    canvas.translate(dx, 0);

    // Ground shadow.
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(size.x / 2, size.y - 2),
        width: size.x * 0.85 * s,
        height: 11 * s,
      ),
      Paint()..color = const Color(0x66000000),
    );

    canvas.save();
    canvas.translate(size.x / 2, size.y / 2);
    canvas.scale(s, s * 0.85);
    canvas.translate(-size.x / 2, -size.y / 2);

    if (_opacity < 1.0) {
      canvas.saveLayer(
        Rect.fromLTWH(0, 0, size.x, size.y),
        Paint()..color = Color.fromARGB((_opacity * 255).round(), 255, 255, 255),
      );
    }

    _renderBike(canvas);

    if (_opacity < 1.0) canvas.restore();

    if (_wetTimer > 0) {
      final phase = _wetTimer / _wetDuration;
      final alpha = (1 - (phase - 0.5).abs() * 2) * 0.4;
      canvas.drawRect(
        Rect.fromLTWH(0, 0, size.x, size.y),
        Paint()..color = const Color(0xFF42A5F5).withValues(alpha: alpha),
      );
    }

    canvas.restore();
  }

  void _renderBike(Canvas canvas) {
    final w = size.x;
    final h = size.y;

    // Motion blur ovals behind rear wheel.
    for (int i = 1; i <= 3; i++) {
      canvas.drawOval(
        Rect.fromCenter(
          center: Offset(w * 0.50, h * 0.78 + i * 4.0),
          width: w * 0.22,
          height: 5.5,
        ),
        Paint()..color = Color.fromARGB(40 - i * 10, 120, 120, 120),
      );
    }

    final wheelPaint = Paint()..color = const Color(0xFF1A1A1A);
    final hubPaint = Paint()..color = const Color(0xFFCCCCCC);
    final tirePaint = Paint()
      ..color = const Color(0xFF1A1A1A)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.5;

    const rearWheelX = 0.50;
    const rearWheelY = 0.74;
    const frontWheelY = 0.24;
    const wheelR = 9.0;

    final rear = Offset(w * rearWheelX, h * rearWheelY);
    final front = Offset(w * rearWheelX, h * frontWheelY);

    canvas.drawCircle(rear, wheelR, wheelPaint);
    canvas.drawCircle(front, wheelR, wheelPaint);
    canvas.drawCircle(rear, wheelR + 1.5, tirePaint);
    canvas.drawCircle(front, wheelR + 1.5, tirePaint);
    canvas.drawCircle(rear, 2.8, hubPaint);
    canvas.drawCircle(front, 2.8, hubPaint);

    // Spinning wheel spokes.
    final spokePaint = Paint()
      ..color = const Color(0xFF777777)
      ..strokeWidth = 1.2;
    for (final center in [rear, front]) {
      canvas.save();
      canvas.translate(center.dx, center.dy);
      canvas.rotate(_wheelAngle);
      canvas.drawLine(const Offset(0.0, -wheelR * 0.7), const Offset(0.0, wheelR * 0.7), spokePaint);
      canvas.rotate(pi / 2);
      canvas.drawLine(const Offset(0.0, -wheelR * 0.7), const Offset(0.0, wheelR * 0.7), spokePaint);
      canvas.restore();
    }

    // Bike diamond frame.
    final framePaint = Paint()
      ..color = const Color(0xFF9E9E9E)
      ..strokeWidth = 2.5
      ..strokeCap = StrokeCap.round;
    final bb = Offset(w * 0.50, h * 0.52);
    final seat = Offset(w * 0.50, h * 0.36);
    canvas.drawLine(rear, bb, framePaint);
    canvas.drawLine(front, bb, framePaint);
    canvas.drawLine(seat, bb, framePaint);
    canvas.drawLine(front, seat, framePaint);
    // Seat stay.
    canvas.drawLine(rear, seat, framePaint..strokeWidth = 2.0);

    // Handlebars.
    canvas.drawLine(
      Offset(w * 0.28, h * 0.20),
      Offset(w * 0.72, h * 0.20),
      Paint()
        ..color = const Color(0xFF333333)
        ..strokeWidth = 3.0
        ..strokeCap = StrokeCap.round,
    );

    // Delivery bag on rear rack (yellow).
    final bagRect = Rect.fromLTWH(w * 0.20, h * 0.74, w * 0.60, h * 0.13);
    canvas.drawRRect(
      RRect.fromRectAndRadius(bagRect, const Radius.circular(3)),
      Paint()..color = const Color(0xFFFDD835),
    );
    canvas.drawLine(
      Offset(w * 0.50, h * 0.74),
      Offset(w * 0.50, h * 0.87),
      Paint()..color = const Color(0xFFE65100)..strokeWidth = 1.5,
    );

    // Rider torso — blue jacket with gradient.
    final torsoRect = Rect.fromLTWH(w * 0.20, h * 0.34, w * 0.60, h * 0.26);
    final torsoRRect = RRect.fromRectAndRadius(torsoRect, const Radius.circular(5));
    canvas.drawRRect(
      torsoRRect,
      Paint()
        ..shader = Gradient.linear(
          torsoRect.topLeft,
          torsoRect.bottomRight,
          [const Color(0xFF1E6BCC), const Color(0xFF0A3D8A)],
        ),
    );
    if (isVip) {
      canvas.drawRRect(torsoRRect, Paint()..color = vipTint);
    }

    // Small backpack / satchel.
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(w * 0.62, h * 0.36, w * 0.16, h * 0.18),
        const Radius.circular(3),
      ),
      Paint()..color = const Color(0xFF6D4C41),
    );

    // Head.
    canvas.drawCircle(
      Offset(w * 0.50, h * 0.23),
      6.5,
      Paint()..color = const Color(0xFFFFCC80),
    );

    // Helmet dome.
    final helmetPaint = Paint()
      ..shader = Gradient.linear(
        Offset(w * 0.34, h * 0.13),
        Offset(w * 0.66, h * 0.22),
        [const Color(0xFFEF5350), const Color(0xFFB71C1C)],
      );
    final helmetPath = Path()
      ..addOval(Rect.fromCenter(
        center: Offset(w * 0.50, h * 0.17),
        width: 16,
        height: 10,
      ));
    canvas.drawPath(helmetPath, helmetPaint);
    // Visor brim.
    canvas.drawRect(
      Rect.fromLTWH(w * 0.30, h * 0.215, w * 0.40, 2.5),
      Paint()..color = const Color(0xFF8B0000),
    );
  }
}
