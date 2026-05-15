import 'dart:math';
import 'dart:ui';
import 'package:flame/collisions.dart';
import 'package:flame/components.dart';
import '../delivery_dash_game.dart';
import '../perspective.dart';
import 'bike_trail.dart';

/// Player bicycle courier — chunky Paperboy 3/4 side profile.
/// The bike faces upper-right (into the screen) so the left side is shown.
class PlayerComponent extends PositionComponent
    with HasGameRef<DeliveryDashGame>, CollisionCallbacks {
  static const Color vipTint = Color(0x88FFD54F);
  static const double _followSpeed = 8.0;
  static const double _flashInterval = 0.1;
  static const double _trailInterval = 0.06;
  static const double _pedalInterval = 0.25;

  static const double _swayAmplitudeDeg = 2.0;
  static const double _swayHz = 1.5;
  static const double _throwArmDuration = 0.20;

  final bool isVip;
  double _targetX = 0;
  double _flashTimer = 0;
  double _trailTimer = 0;
  double _opacity = 1.0;
  double _wetTimer = 0;
  double _wheelAngle = 0;
  double _pedalTimer = 0;
  bool _pedalPhase = false;
  double _swayTimer = 0;
  double _throwArmTimer = 0;
  bool _throwArmLeft = true;
  static const double _wetDuration = 0.4;

  PlayerComponent({this.isVip = false})
      : super(size: Vector2(72, 105), anchor: Anchor.center, priority: 100);

  double get opacity => _opacity;
  set opacity(double v) => _opacity = v.clamp(0.0, 1.0);

  void triggerThrowArm({bool throwLeft = true}) {
    _throwArmTimer = _throwArmDuration;
    _throwArmLeft = throwLeft;
  }

  @override
  Future<void> onLoad() async {
    final lm = gameRef.laneManager;
    _targetX = lm.roadCenter;
    position = Vector2(_targetX, gameRef.size.y * 0.82);
    add(RectangleHitbox(
      size: Vector2(50, 80),
      position: Vector2((size.x - 50) / 2, (size.y - 80) / 2),
    ));
  }

  void moveTo(double worldX) {
    // Player can move from far-left footpath to far-right footpath.
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

    _wheelAngle += dt * 12.0;
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
    final lm = gameRef.laneManager;
    final h = gameRef.size.y;
    final s = depthScale(position.y, h);
    final dx = depthXShiftDiag(
      worldX: position.x,
      leftRef: lm.roadLeft,
      widthRef: lm.roadWidth,
      leftY: lm.roadLeftAt(position.y),
      widthY: lm.roadWidthAt(position.y),
    );
    canvas.translate(dx, 0);

    // Ground shadow.
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(size.x / 2, size.y - 2),
        width: size.x * 0.85 * s,
        height: 13 * s,
      ),
      Paint()..color = const Color(0x77000000),
    );

    if (gameRef.level >= 5) {
      _renderSpeedLines(canvas, s);
    }

    canvas.save();
    canvas.translate(size.x / 2, size.y / 2);

    final swayRad = (_swayAmplitudeDeg * pi / 180) *
        sin(_swayTimer * 2 * pi * _swayHz);
    canvas.rotate(swayRad);

    canvas.scale(s, s * 0.88);
    canvas.translate(-size.x / 2, -size.y / 2);

    if (_opacity < 1.0) {
      canvas.saveLayer(
        Rect.fromLTWH(0, 0, size.x, size.y),
        Paint()
          ..color = Color.fromARGB((_opacity * 255).round(), 255, 255, 255),
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

  void _renderSpeedLines(Canvas canvas, double scale) {
    final speedFraction =
        ((gameRef.scrollSpeed - 300) / 200).clamp(0.0, 1.0);
    if (speedFraction <= 0) return;
    final linePaint = Paint()
      ..color = const Color(0xFFFFFFFF).withValues(alpha: speedFraction * 0.7)
      ..strokeWidth = 1.6
      ..strokeCap = StrokeCap.round;
    for (int i = 0; i < 4; i++) {
      final lineY = size.y * (0.30 + i * 0.12);
      final lineLen = (24 + i * 8) * scale;
      canvas.drawLine(
        Offset(-lineLen - 4, lineY),
        Offset(-4, lineY),
        linePaint,
      );
    }
  }

  // ── 3/4 Diagonal bike rendering ───────────────────────────────────────────

  void _renderBike(Canvas canvas) {
    final w = size.x;
    final h = size.y;

    // Isometric oval wheels — rear larger (closer to viewer), front smaller.
    final rearCenter = Offset(w * 0.27, h * 0.73);
    final frontCenter = Offset(w * 0.70, h * 0.38);
    _drawWheel(canvas, rearCenter, 15, 11);
    _drawWheel(canvas, frontCenter, 13, 10);

    // Frame anchor points.
    final bb = Offset(w * 0.50, h * 0.60);
    final seatTop = Offset(w * 0.33, h * 0.41);
    final headTube = Offset(w * 0.64, h * 0.26);

    final framePaint = Paint()
      ..color = const Color(0xFFE53935)
      ..strokeWidth = 3.2
      ..strokeCap = StrokeCap.round;

    // Chain stay (rear → BB).
    canvas.drawLine(rearCenter, bb, framePaint);
    // Seat stay (rear → seat top).
    canvas.drawLine(rearCenter, seatTop, framePaint);
    // Seat tube (BB → seat top).
    canvas.drawLine(bb, seatTop, framePaint);
    // Down tube (head tube → BB).
    canvas.drawLine(headTube, bb, framePaint);
    // Top tube (seat top → head tube).
    canvas.drawLine(seatTop, headTube, framePaint);
    // Fork: two parallel lines, 2px apart, head tube → front wheel.
    final forkPaint = Paint()
      ..color = const Color(0xFFE53935)
      ..strokeWidth = 2.0
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(headTube, frontCenter, forkPaint);
    canvas.drawLine(
      Offset(headTube.dx + 2, headTube.dy),
      Offset(frontCenter.dx + 2, frontCenter.dy),
      forkPaint,
    );

    // Chain (dotted BB → rear hub).
    final chainPaint = Paint()..color = const Color(0xFF444444);
    const chainSteps = 6;
    for (int i = 0; i < chainSteps; i++) {
      if (i.isOdd) continue;
      final t = i / chainSteps;
      final x = bb.dx + (rearCenter.dx - bb.dx) * t;
      final y = bb.dy + (rearCenter.dy - bb.dy) * t;
      canvas.drawCircle(Offset(x, y), 1.0, chainPaint);
    }

    // Handlebar with grips.
    final handlebarPaint = Paint()
      ..color = const Color(0xFF333333)
      ..strokeWidth = 3.2
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(
      Offset(headTube.dx - 9, headTube.dy - 3),
      Offset(headTube.dx + 11, headTube.dy - 5),
      handlebarPaint,
    );
    canvas.drawCircle(
        Offset(headTube.dx - 10, headTube.dy - 2), 2.2, handlebarPaint);
    canvas.drawCircle(
        Offset(headTube.dx + 12, headTube.dy - 4), 2.2, handlebarPaint);

    // Saddle.
    canvas.drawArc(
      Rect.fromCenter(
        center: Offset(seatTop.dx, seatTop.dy - 3),
        width: 18,
        height: 6,
      ),
      pi * 1.1,
      pi * 0.8,
      false,
      Paint()
        ..color = const Color(0xFF1A1A1A)
        ..strokeWidth = 3.5
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round,
    );

    // Delivery bag on rear rack (yellow with orange flap).
    final bagRect = Rect.fromLTWH(w * 0.08, h * 0.74, w * 0.42, h * 0.13);
    canvas.drawRRect(
      RRect.fromRectAndRadius(bagRect, const Radius.circular(3)),
      Paint()..color = const Color(0xFFFDD835),
    );
    canvas.drawRect(
      Rect.fromLTWH(w * 0.08, h * 0.74, w * 0.42, h * 0.03),
      Paint()..color = const Color(0xFFE65100),
    );

    // Pedals.
    final pedalAngle = _pedalPhase ? 0.0 : pi;
    final pedalPaint = Paint()..color = const Color(0xFF1A1A1A);
    for (final off in [pedalAngle, pedalAngle + pi]) {
      final px = bb.dx + cos(off) * 7;
      final py = bb.dy + sin(off) * 7;
      canvas.drawRect(
        Rect.fromCenter(center: Offset(px, py), width: 7, height: 3),
        pedalPaint,
      );
    }

    // ── Rider ──────────────────────────────────────────────────────────────
    // Blue jacket as filled polygon — torso leaning forward.
    final jacketPath = Path()
      ..moveTo(w * 0.27, h * 0.55)
      ..lineTo(w * 0.30, h * 0.32)
      ..lineTo(w * 0.62, h * 0.30)
      ..lineTo(w * 0.70, h * 0.50)
      ..lineTo(w * 0.55, h * 0.58)
      ..close();
    canvas.drawPath(
      jacketPath,
      Paint()
        ..shader = Gradient.linear(
          Offset(w * 0.30, h * 0.32),
          Offset(w * 0.70, h * 0.55),
          [const Color(0xFF1976D2), const Color(0xFF0D47A1)],
        ),
    );
    canvas.drawPath(
      jacketPath,
      Paint()
        ..color = const Color(0xFF0A2E5C)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.2,
    );
    if (isVip) {
      canvas.drawPath(jacketPath, Paint()..color = vipTint);
    }

    // Backpack visible on rider's back.
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(w * 0.56, h * 0.34, w * 0.16, h * 0.18),
        const Radius.circular(3),
      ),
      Paint()..color = const Color(0xFF6D4C41),
    );

    // Legs — thigh + calf.
    final legPaint = Paint()
      ..color = const Color(0xFF1A237E)
      ..strokeWidth = 5
      ..strokeCap = StrokeCap.round;
    final hipL = Offset(w * 0.42, h * 0.55);
    final hipR = Offset(w * 0.52, h * 0.55);

    final pedalLow = bb + Offset(cos(pedalAngle) * 7, sin(pedalAngle) * 7);
    final pedalHigh =
        bb + Offset(cos(pedalAngle + pi) * 7, sin(pedalAngle + pi) * 7);

    final kneeRear = Offset(hipL.dx - 2, (hipL.dy + pedalLow.dy) / 2 + 2);
    canvas.drawLine(hipL, kneeRear, legPaint);
    canvas.drawLine(kneeRear, pedalLow, legPaint);

    final kneeFront = Offset(hipR.dx + 4, hipR.dy + 8);
    canvas.drawLine(hipR, kneeFront, legPaint);
    canvas.drawLine(kneeFront, pedalHigh, legPaint);

    // Shoes.
    final shoePaint = Paint()..color = const Color(0xFF111111);
    canvas.drawOval(
      Rect.fromCenter(center: pedalLow, width: 9, height: 4),
      shoePaint,
    );
    canvas.drawOval(
      Rect.fromCenter(center: pedalHigh, width: 8, height: 4),
      shoePaint,
    );

    // Front arm reaching to handlebar.
    final armPaint = Paint()
      ..color = const Color(0xFF1976D2)
      ..strokeWidth = 4
      ..strokeCap = StrokeCap.round;
    final shoulder = Offset(w * 0.58, h * 0.34);
    final elbow = Offset(w * 0.62, h * 0.30);
    final grip = Offset(headTube.dx + 8, headTube.dy);
    canvas.drawLine(shoulder, elbow, armPaint);
    canvas.drawLine(elbow, grip, armPaint);

    // Throwing arm extends in the direction of the last throw.
    if (_throwArmTimer > 0) {
      final t = _throwArmTimer / _throwArmDuration;
      final base = _throwArmLeft
          ? Offset(w * 0.30, h * 0.34)
          : Offset(w * 0.66, h * 0.34);
      final dir = _throwArmLeft ? -1.0 : 1.0;
      final tip = Offset(base.dx + dir * (14 * t + 6), base.dy - 8 * t);
      canvas.drawLine(
        base,
        tip,
        Paint()
          ..color = const Color(0xFF1976D2)
          ..strokeWidth = 4.5
          ..strokeCap = StrokeCap.round,
      );
      canvas.drawCircle(tip, 3.8, Paint()..color = const Color(0xFFFFCC80));
    }

    // Head (peach skin tone, radius 7).
    final headCenter = Offset(w * 0.50, h * 0.22);
    canvas.drawCircle(
      headCenter,
      7,
      Paint()..color = const Color(0xFFFFCC99),
    );

    // Yellow helmet as squashed semicircle (drawArc 180°).
    canvas.drawArc(
      Rect.fromCenter(
        center: Offset(headCenter.dx, headCenter.dy - 1),
        width: 18,
        height: 14,
      ),
      pi,
      pi,
      false,
      Paint()..color = const Color(0xFFFFD600),
    );
    canvas.drawArc(
      Rect.fromCenter(
        center: Offset(headCenter.dx, headCenter.dy - 1),
        width: 18,
        height: 14,
      ),
      pi,
      pi,
      false,
      Paint()
        ..color = const Color(0xFFB37700)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.4,
    );
    canvas.drawLine(
      Offset(headCenter.dx - 6, headCenter.dy - 4),
      Offset(headCenter.dx + 6, headCenter.dy - 4),
      Paint()
        ..color = const Color(0xFFB37700)
        ..strokeWidth = 1.0,
    );
    canvas.drawLine(
      Offset(headCenter.dx - 5, headCenter.dy + 5),
      Offset(headCenter.dx + 5, headCenter.dy + 5),
      Paint()
        ..color = const Color(0xFF1A1A1A)
        ..strokeWidth = 0.9,
    );
  }

  /// Isometric oval wheel — rx is in-plane radius, ry is the squashed
  /// vertical radius (gives the wheel a 3/4 perspective).
  void _drawWheel(Canvas canvas, Offset center, double rx, double ry) {
    canvas.drawOval(
      Rect.fromCenter(center: center, width: rx * 2 + 4, height: ry * 2 + 4),
      Paint()..color = const Color(0xFF1A1A1A),
    );
    canvas.drawOval(
      Rect.fromCenter(center: center, width: rx * 2, height: ry * 2),
      Paint()..color = const Color(0xFFB0B0B0),
    );
    final spokePaint = Paint()
      ..color = const Color(0xFF888888)
      ..strokeWidth = 1.0;
    for (int i = 0; i < 8; i++) {
      final a = i * pi / 4 + _wheelAngle;
      final dx = cos(a);
      final dy = sin(a) * (ry / rx);
      canvas.drawLine(
        Offset(center.dx + dx * 2, center.dy + dy * 2),
        Offset(center.dx + dx * rx * 0.9, center.dy + dy * ry * 0.9),
        spokePaint,
      );
    }
    canvas.drawOval(
      Rect.fromCenter(center: center, width: 8, height: 6),
      Paint()..color = const Color(0xFFDDDDDD),
    );
  }
}
