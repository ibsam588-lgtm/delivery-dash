import 'dart:math';
import 'dart:ui';
import 'package:flame/collisions.dart';
import 'package:flame/components.dart';
import '../delivery_dash_game.dart';
import 'bike_trail.dart';

class PlayerComponent extends PositionComponent
    with HasGameRef<DeliveryDashGame>, CollisionCallbacks {
  static const Color vipTint = Color(0x88FFD54F);
  static const double _followSpeed = 8.0;
  static const double _flashInterval = 0.1;
  static const double _trailInterval = 0.08;
  static const double _pedalInterval = 0.22;
  static const double _swayAmplitudeDeg = 0.8;
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
      : super(size: Vector2(74, 110), anchor: Anchor.center, priority: 100);

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
      size: Vector2(36, 70),
      position: Vector2((size.x - 36) / 2, (size.y - 70) / 2 + 8),
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
          position: position + Vector2(0, size.y * 0.38),
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
          Rect.fromLTWH(6, 6, size.x - 12, size.y - 12),
          const Radius.circular(16),
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
        Rect.fromCenter(center: Offset(w * 0.50, h * 0.58), width: w * 0.95, height: h * 0.88),
        Paint()..color = vipTint.withValues(alpha: 0.22),
      );
    }

    canvas.drawOval(
      Rect.fromCenter(center: Offset(w * 0.50, h * 0.91), width: w * 0.72, height: h * 0.09),
      Paint()..color = const Color(0x77000000),
    );

    // Two bicycle wheels now align front/back on the bike path, not left/right.
    final rearWheel = Offset(w * 0.50, h * 0.78);
    final frontWheel = Offset(w * 0.50, h * 0.55);
    _drawVerticalWheel(canvas, rearWheel, w * 0.18, wheelAngle);
    _drawVerticalWheel(canvas, frontWheel, w * 0.15, wheelAngle + pi / 8);

    final framePaint = Paint()
      ..color = const Color(0xFFD71920)
      ..strokeWidth = 4.0
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    final frameShadow = Paint()
      ..color = const Color(0x88000000)
      ..strokeWidth = 5.5
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final seat = Offset(w * 0.50, h * 0.49);
    final crank = Offset(w * 0.50, h * 0.65);
    final handle = Offset(w * 0.50, h * 0.39);

    void frame(Paint p) {
      canvas.drawLine(seat, crank, p);
      canvas.drawLine(crank, rearWheel, p);
      canvas.drawLine(crank, frontWheel, p);
      canvas.drawLine(seat, rearWheel, p);
      canvas.drawLine(seat, frontWheel, p);
      canvas.drawLine(handle, frontWheel, p);
      canvas.drawLine(seat, handle, p);
    }

    frame(frameShadow);
    frame(framePaint);

    canvas.drawLine(
      Offset(w * 0.30, h * 0.39),
      Offset(w * 0.70, h * 0.39),
      Paint()
        ..color = const Color(0xFF263238)
        ..strokeWidth = 3.4
        ..strokeCap = StrokeCap.round,
    );

    canvas.drawCircle(crank, 4.2, Paint()..color = const Color(0xFF1B1B1B));
    final pedalPaint = Paint()
      ..color = const Color(0xFF263238)
      ..strokeWidth = 2.5
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(crank, Offset(crank.dx + 10, crank.dy + pedalLift * 7), pedalPaint);
    canvas.drawLine(crank, Offset(crank.dx - 10, crank.dy - pedalLift * 7), pedalPaint);

    _drawNewsBag(canvas, w, h);
    _drawRearRider(canvas, w, h, pedalLift, throwT);
  }

  void _drawRearRider(Canvas canvas, double w, double h, double pedalLift, double throwT) {
    final legPaint = Paint()
      ..color = const Color(0xFF1B3855)
      ..strokeWidth = 4.5
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(Offset(w * 0.44, h * 0.53), Offset(w * 0.42, h * 0.68 - pedalLift * 3), legPaint);
    canvas.drawLine(Offset(w * 0.56, h * 0.53), Offset(w * 0.58, h * 0.68 + pedalLift * 3), legPaint);
    canvas.drawLine(Offset(w * 0.42, h * 0.68 - pedalLift * 3), Offset(w * 0.45, h * 0.81), legPaint);
    canvas.drawLine(Offset(w * 0.58, h * 0.68 + pedalLift * 3), Offset(w * 0.55, h * 0.81), legPaint);

    canvas.drawOval(Rect.fromCenter(center: Offset(w * 0.45, h * 0.82), width: 11, height: 6), Paint()..color = const Color(0xFF212121));
    canvas.drawOval(Rect.fromCenter(center: Offset(w * 0.55, h * 0.82), width: 11, height: 6), Paint()..color = const Color(0xFF212121));

    final body = RRect.fromRectAndRadius(
      Rect.fromCenter(center: Offset(w * 0.50, h * 0.39), width: w * 0.36, height: h * 0.27),
      const Radius.circular(12),
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
    canvas.drawRRect(body, Paint()..color = const Color(0xFF05294D)..style = PaintingStyle.stroke..strokeWidth = 1.5);

    canvas.drawLine(
      Offset(w * 0.40, h * 0.25),
      Offset(w * 0.61, h * 0.52),
      Paint()..color = const Color(0xFFFFC928)..strokeWidth = 4.0..strokeCap = StrokeCap.round,
    );

    final sleevePaint = Paint()..color = const Color(0xFF1565C0)..strokeWidth = 5.5..strokeCap = StrokeCap.round;
    final skinPaint = Paint()..color = const Color(0xFFFFC590)..strokeWidth = 3.8..strokeCap = StrokeCap.round;
    final leftShoulder = Offset(w * 0.36, h * 0.32);
    final rightShoulder = Offset(w * 0.64, h * 0.32);
    final leftHand = Offset(w * (0.31 - (_throwLeft ? throwT * 0.20 : 0)), h * (0.40 - (_throwLeft ? throwT * 0.12 : 0)));
    final rightHand = Offset(w * (0.69 + (!_throwLeft ? throwT * 0.20 : 0)), h * (0.40 - (!_throwLeft ? throwT * 0.12 : 0)));
    canvas.drawLine(leftShoulder, leftHand, sleevePaint);
    canvas.drawLine(rightShoulder, rightHand, sleevePaint);
    canvas.drawLine(leftHand, Offset(leftHand.dx, leftHand.dy + 1), skinPaint);
    canvas.drawLine(rightHand, Offset(rightHand.dx, rightHand.dy + 1), skinPaint);

    canvas.drawCircle(Offset(w * 0.50, h * 0.19), w * 0.13, Paint()..color = const Color(0xFFFFC590));
    canvas.drawArc(
      Rect.fromCenter(center: Offset(w * 0.50, h * 0.20), width: w * 0.28, height: w * 0.22),
      0,
      pi,
      false,
      Paint()..color = const Color(0xFF5D2F16)..strokeWidth = 5.5..strokeCap = StrokeCap.round,
    );

    final cap = Path()
      ..moveTo(w * 0.35, h * 0.16)
      ..quadraticBezierTo(w * 0.50, h * 0.03, w * 0.65, h * 0.16)
      ..quadraticBezierTo(w * 0.50, h * 0.12, w * 0.35, h * 0.16)
      ..close();
    canvas.drawPath(cap, Paint()..color = const Color(0xFFFDF9ED));
    canvas.drawPath(cap, Paint()..color = const Color(0xFFD71920)..style = PaintingStyle.stroke..strokeWidth = 1.5);
  }

  void _drawNewsBag(Canvas canvas, double w, double h) {
    final bag = RRect.fromRectAndRadius(
      Rect.fromCenter(center: Offset(w * 0.25, h * 0.52), width: w * 0.25, height: h * 0.22),
      const Radius.circular(7),
    );
    canvas.drawRRect(bag, Paint()..color = const Color(0xFFFFC928));
    canvas.drawRRect(bag, Paint()..color = const Color(0xFF6D4C00)..style = PaintingStyle.stroke..strokeWidth = 1.8);
    for (int i = 0; i < 3; i++) {
      final x = w * (0.16 + i * 0.035);
      canvas.drawRRect(
        RRect.fromRectAndRadius(Rect.fromLTWH(x, h * 0.36 - i * 2, w * 0.07, h * 0.075), const Radius.circular(2)),
        Paint()..color = const Color(0xFFF6F0D8),
      );
    }
  }

  void _drawVerticalWheel(Canvas canvas, Offset c, double r, double angle) {
    canvas.save();
    canvas.translate(c.dx, c.dy);
    canvas.scale(0.42, 1.0);
    canvas.drawCircle(Offset.zero, r, Paint()..color = const Color(0xFF0C0C0C));
    canvas.drawCircle(Offset.zero, r * 0.78, Paint()..color = const Color(0xFF515151));
    canvas.drawCircle(Offset.zero, r * 0.58, Paint()..color = const Color(0xFFEEEEEE));
    canvas.drawCircle(Offset.zero, r * 0.20, Paint()..color = const Color(0xFF202020));
    canvas.rotate(angle);
    final spoke = Paint()..color = const Color(0xFFBDBDBD)..strokeWidth = 0.8..strokeCap = StrokeCap.round;
    for (int i = 0; i < 8; i++) {
      final a = i * 2 * pi / 8;
      canvas.drawLine(Offset.zero, Offset(cos(a) * r * 0.72, sin(a) * r * 0.72), spoke);
    }
    canvas.restore();
  }
}
