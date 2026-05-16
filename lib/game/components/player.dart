import 'dart:math';
import 'dart:ui';
import 'package:flame/collisions.dart';
import 'package:flame/components.dart';
import '../delivery_dash_game.dart';
import 'bike_trail.dart';

/// Rear-view newspaper courier inspired by classic Paperboy arcade framing.
///
/// The player is intentionally drawn larger and from behind so it reads more
/// like the reference mockup: cap, blue jacket, yellow Daily News bag, narrow
/// red bike, and readable wheel silhouette.
class PlayerComponent extends PositionComponent
    with HasGameRef<DeliveryDashGame>, CollisionCallbacks {
  static const Color vipTint = Color(0x88FFD54F);
  static const double _followSpeed = 8.0;
  static const double _flashInterval = 0.1;
  static const double _trailInterval = 0.06;
  static const double _pedalInterval = 0.22;
  static const double _swayAmplitudeDeg = 1.2;
  static const double _swayHz = 1.35;
  static const double _throwArmDuration = 0.20;
  static const double _wetDuration = 0.4;

  final bool isVip;
  double _targetX = 0;
  double _flashTimer = 0;
  double _trailTimer = 0;
  double _opacity = 1.0;
  double _wetTimer = 0;
  double _pedalTimer = 0;
  bool _pedalPhase = false;
  bool _throwLeft = true;
  double _swayTimer = 0;
  double _throwArmTimer = 0;

  PlayerComponent({this.isVip = false})
      : super(size: Vector2(100, 150), anchor: Anchor.center, priority: 100);

  double get opacity => _opacity;
  set opacity(double v) => _opacity = v.clamp(0.0, 1.0);

  void triggerThrowArm({bool throwLeft = true}) {
    _throwLeft = throwLeft;
    _throwArmTimer = _throwArmDuration;
  }

  @override
  Future<void> onLoad() async {
    position = Vector2(gameRef.size.x * 0.5, gameRef.size.y * 0.80);
    _targetX = position.x;
    add(RectangleHitbox(
      size: Vector2(48, 92),
      position: Vector2((size.x - 48) / 2, (size.y - 92) / 2 + 12),
    ));
  }

  void moveTo(double worldX) {
    final lo = size.x / 2;
    final hi = gameRef.size.x - size.x / 2;
    _targetX = worldX.clamp(lo, hi);
  }

  void triggerWetFlash() {
    _wetTimer = _wetDuration;
  }

  @override
  void update(double dt) {
    super.update(dt);
    _swayTimer += dt;

    _pedalTimer += dt;
    if (_pedalTimer >= _pedalInterval) {
      _pedalTimer = 0;
      _pedalPhase = !_pedalPhase;
    }

    if (_throwArmTimer > 0) {
      _throwArmTimer = (_throwArmTimer - dt).clamp(0.0, _throwArmDuration);
    }

    final dx = _targetX - position.x;
    final t = (_followSpeed * dt).clamp(0.0, 1.0);
    position.x += dx * t;
    position.y = gameRef.size.y * 0.80;

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
      _opacity = 1.0;
    }

    if (gameRef.state == GameState.playing) {
      _trailTimer += dt;
      if (_trailTimer >= _trailInterval) {
        _trailTimer = 0;
        gameRef.add(BikeTrailPuff(
          position: position + Vector2(0, size.y * 0.39),
        ));
      }
    }
  }

  @override
  void render(Canvas canvas) {
    final needsLayer = _opacity < 1.0;
    if (needsLayer) {
      canvas.saveLayer(
        null,
        Paint()
          ..color = Color.fromARGB((_opacity * 255).round(), 255, 255, 255),
      );
    }

    canvas.save();
    canvas.translate(size.x / 2, size.y / 2);
    canvas.rotate(sin(_swayTimer * _swayHz * 2 * pi) * _swayAmplitudeDeg * pi / 180);
    canvas.translate(-size.x / 2, -size.y / 2);

    _renderCourier(canvas);

    if (_wetTimer > 0) {
      final a = (_wetTimer / _wetDuration) * 0.42;
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(8, 8, size.x - 16, size.y - 16),
          const Radius.circular(18),
        ),
        Paint()..color = const Color(0xFF42A5F5).withValues(alpha: a),
      );
    }

    canvas.restore();
    if (needsLayer) canvas.restore();
  }

  void _renderCourier(Canvas canvas) {
    final w = size.x;
    final h = size.y;
    final wheelAngle = _swayTimer * 13.0;
    final throwT = _throwArmTimer / _throwArmDuration;
    final pedalLift = _pedalPhase ? 1.0 : -1.0;

    if (isVip) {
      canvas.drawOval(
        Rect.fromCenter(
          center: Offset(w * 0.50, h * 0.58),
          width: w * 1.00,
          height: h * 0.92,
        ),
        Paint()..color = vipTint.withValues(alpha: 0.24),
      );
    }

    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(w * 0.50, h * 0.90),
        width: w * 0.82,
        height: h * 0.12,
      ),
      Paint()..color = const Color(0x77000000),
    );

    // Bike wheels: reference-like vertical/rear perspective.
    final rear = Offset(w * 0.50, h * 0.78);
    final front = Offset(w * 0.50, h * 0.56);
    _drawWheel(canvas, rear, w * 0.22, wheelAngle, vertical: true);
    _drawWheel(canvas, front, w * 0.17, wheelAngle + pi / 8, vertical: true);

    final frameShadow = Paint()
      ..color = const Color(0x88000000)
      ..strokeWidth = 6.4
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    final framePaint = Paint()
      ..color = const Color(0xFFD71920)
      ..strokeWidth = 4.8
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final seat = Offset(w * 0.50, h * 0.49);
    final crank = Offset(w * 0.50, h * 0.66);
    final handle = Offset(w * 0.50, h * 0.39);
    final leftFork = Offset(w * 0.43, h * 0.58);
    final rightFork = Offset(w * 0.57, h * 0.58);

    void frame(Paint p) {
      canvas.drawLine(seat, crank, p);
      canvas.drawLine(crank, leftFork, p);
      canvas.drawLine(crank, rightFork, p);
      canvas.drawLine(seat, leftFork, p);
      canvas.drawLine(seat, rightFork, p);
      canvas.drawLine(handle, leftFork, p);
      canvas.drawLine(handle, rightFork, p);
      canvas.drawLine(crank, rear, p);
    }

    frame(frameShadow);
    frame(framePaint);

    // Handlebar.
    canvas.drawLine(
      Offset(w * 0.30, h * 0.39),
      Offset(w * 0.70, h * 0.39),
      Paint()
        ..color = const Color(0xFF263238)
        ..strokeWidth = 4.0
        ..strokeCap = StrokeCap.round,
    );

    // Pedals.
    canvas.drawCircle(crank, 5.5, Paint()..color = const Color(0xFF1B1B1B));
    final pedalPaint = Paint()
      ..color = const Color(0xFF263238)
      ..strokeWidth = 3.2
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(
      crank,
      Offset(crank.dx + 13, crank.dy + pedalLift * 9),
      pedalPaint,
    );
    canvas.drawLine(
      crank,
      Offset(crank.dx - 13, crank.dy - pedalLift * 9),
      pedalPaint,
    );

    _drawNewsBag(canvas, w, h);
    _drawRearRider(canvas, w, h, pedalLift, throwT);
  }

  void _drawRearRider(Canvas canvas, double w, double h, double pedalLift, double throwT) {
    // Legs behind bike frame.
    final legPaint = Paint()
      ..color = const Color(0xFF1B3855)
      ..strokeWidth = 6.0
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(Offset(w * 0.44, h * 0.53), Offset(w * 0.40, h * 0.67 - pedalLift * 4), legPaint);
    canvas.drawLine(Offset(w * 0.56, h * 0.53), Offset(w * 0.60, h * 0.67 + pedalLift * 4), legPaint);
    canvas.drawLine(Offset(w * 0.40, h * 0.67 - pedalLift * 4), Offset(w * 0.35, h * 0.80), legPaint);
    canvas.drawLine(Offset(w * 0.60, h * 0.67 + pedalLift * 4), Offset(w * 0.65, h * 0.80), legPaint);

    // Shoes.
    canvas.drawOval(Rect.fromCenter(center: Offset(w * 0.35, h * 0.81), width: 15, height: 7), Paint()..color = const Color(0xFF212121));
    canvas.drawOval(Rect.fromCenter(center: Offset(w * 0.65, h * 0.81), width: 15, height: 7), Paint()..color = const Color(0xFF212121));

    // Blue jacket/back.
    final body = RRect.fromRectAndRadius(
      Rect.fromCenter(center: Offset(w * 0.50, h * 0.39), width: w * 0.38, height: h * 0.28),
      const Radius.circular(14),
    );
    canvas.drawRRect(
      body,
      Paint()
        ..shader = Gradient.linear(
          Offset(w * 0.38, h * 0.25),
          Offset(w * 0.62, h * 0.53),
          [const Color(0xFF1E88E5), const Color(0xFF0B3D72)],
        ),
    );
    canvas.drawRRect(
      body,
      Paint()
        ..color = const Color(0xFF05294D)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.8,
    );

    // Yellow strap across the back.
    canvas.drawLine(
      Offset(w * 0.40, h * 0.25),
      Offset(w * 0.61, h * 0.52),
      Paint()
        ..color = const Color(0xFFFFC928)
        ..strokeWidth = 5.0
        ..strokeCap = StrokeCap.round,
    );
    canvas.drawLine(
      Offset(w * 0.40, h * 0.25),
      Offset(w * 0.61, h * 0.52),
      Paint()
        ..color = const Color(0xFF6D4C00)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.0,
    );

    // Arms toward the handlebar. During throw, one arm opens outward.
    final sleevePaint = Paint()
      ..color = const Color(0xFF1565C0)
      ..strokeWidth = 8
      ..strokeCap = StrokeCap.round;
    final skinPaint = Paint()
      ..color = const Color(0xFFFFC590)
      ..strokeWidth = 5
      ..strokeCap = StrokeCap.round;
    final leftShoulder = Offset(w * 0.36, h * 0.32);
    final rightShoulder = Offset(w * 0.64, h * 0.32);
    final leftHand = Offset(w * (0.31 - (_throwLeft ? throwT * 0.20 : 0)), h * (0.40 - (_throwLeft ? throwT * 0.12 : 0)));
    final rightHand = Offset(w * (0.69 + (!_throwLeft ? throwT * 0.20 : 0)), h * (0.40 - (!_throwLeft ? throwT * 0.12 : 0)));
    canvas.drawLine(leftShoulder, leftHand, sleevePaint);
    canvas.drawLine(rightShoulder, rightHand, sleevePaint);
    canvas.drawLine(leftHand, Offset(leftHand.dx, leftHand.dy + 1), skinPaint);
    canvas.drawLine(rightHand, Offset(rightHand.dx, rightHand.dy + 1), skinPaint);

    // Head from behind.
    canvas.drawCircle(Offset(w * 0.50, h * 0.19), w * 0.15, Paint()..color = const Color(0xFFFFC590));
    canvas.drawArc(
      Rect.fromCenter(center: Offset(w * 0.50, h * 0.20), width: w * 0.32, height: w * 0.25),
      0,
      pi,
      false,
      Paint()
        ..color = const Color(0xFF5D2F16)
        ..strokeWidth = 8
        ..strokeCap = StrokeCap.round,
    );

    // Red and white cap, back view.
    final cap = Path()
      ..moveTo(w * 0.33, h * 0.16)
      ..quadraticBezierTo(w * 0.50, h * 0.01, w * 0.67, h * 0.16)
      ..quadraticBezierTo(w * 0.50, h * 0.12, w * 0.33, h * 0.16)
      ..close();
    canvas.drawPath(cap, Paint()..color = const Color(0xFFFDF9ED));
    final redPanel = Path()
      ..moveTo(w * 0.49, h * 0.03)
      ..quadraticBezierTo(w * 0.60, h * 0.07, w * 0.66, h * 0.16)
      ..quadraticBezierTo(w * 0.56, h * 0.13, w * 0.50, h * 0.13)
      ..close();
    canvas.drawPath(redPanel, Paint()..color = const Color(0xFFD71920));
    canvas.drawPath(
      cap,
      Paint()
        ..color = const Color(0xFF7F0000)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.6,
    );
    canvas.drawRect(Rect.fromCenter(center: Offset(w * 0.50, h * 0.22), width: w * 0.18, height: 5), Paint()..color = const Color(0xFF5D2F16));
  }

  void _drawNewsBag(Canvas canvas, double w, double h) {
    final bag = RRect.fromRectAndRadius(
      Rect.fromCenter(center: Offset(w * 0.29, h * 0.51), width: w * 0.28, height: h * 0.25),
      const Radius.circular(8),
    );
    canvas.drawRRect(bag, Paint()..color = const Color(0xFFFFC928));
    canvas.drawRRect(
      bag,
      Paint()
        ..color = const Color(0xFF6D4C00)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.2,
    );

    // Papers sticking out.
    for (int i = 0; i < 4; i++) {
      final x = w * (0.18 + i * 0.035);
      canvas.drawRRect(
        RRect.fromRectAndRadius(Rect.fromLTWH(x, h * 0.34 - i * 2, w * 0.08, h * 0.09), const Radius.circular(2)),
        Paint()..color = const Color(0xFFF6F0D8),
      );
      canvas.drawLine(Offset(x + 2, h * 0.37 - i * 2), Offset(x + w * 0.07, h * 0.37 - i * 2), Paint()..color = const Color(0xFF7A7460)..strokeWidth = 1);
    }

    // Label hints: looks like DAILY NEWS without needing a font dependency.
    final labelPaint = Paint()..color = const Color(0xFF2B2413);
    canvas.drawRect(Rect.fromLTWH(w * 0.205, h * 0.49, w * 0.16, 3), labelPaint);
    canvas.drawRect(Rect.fromLTWH(w * 0.205, h * 0.535, w * 0.12, 3), labelPaint);
    canvas.drawRect(Rect.fromLTWH(w * 0.205, h * 0.58, w * 0.15, 3), labelPaint);
  }

  void _drawWheel(Canvas canvas, Offset c, double r, double angle, {bool vertical = false}) {
    canvas.save();
    if (vertical) {
      canvas.translate(c.dx, c.dy);
      canvas.scale(0.42, 1.0);
      canvas.translate(-c.dx, -c.dy);
    }
    canvas.drawCircle(c, r, Paint()..color = const Color(0xFF0C0C0C));
    canvas.drawCircle(c, r * 0.78, Paint()..color = const Color(0xFF515151));
    canvas.drawCircle(c, r * 0.58, Paint()..color = const Color(0xFFEEEEEE));
    canvas.drawCircle(c, r * 0.20, Paint()..color = const Color(0xFF202020));
    canvas.translate(c.dx, c.dy);
    canvas.rotate(angle);
    final spoke = Paint()
      ..color = const Color(0xFFBDBDBD)
      ..strokeWidth = 1.1
      ..strokeCap = StrokeCap.round;
    for (int i = 0; i < 12; i++) {
      final a = i * 2 * pi / 12;
      canvas.drawLine(Offset.zero, Offset(cos(a) * r * 0.72, sin(a) * r * 0.72), spoke);
    }
    canvas.restore();
  }
}
