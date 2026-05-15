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
  static const double _wetDuration = 0.4;

  PlayerComponent({this.isVip = false})
      : super(size: Vector2(70, 100), anchor: Anchor.center, priority: 100);

  double get opacity => _opacity;
  set opacity(double v) => _opacity = v.clamp(0.0, 1.0);

  void triggerThrowArm() {
    _throwArmTimer = _throwArmDuration;
  }

  @override
  Future<void> onLoad() async {
    final lm = gameRef.laneManager;
    _targetX = lm.roadCenter;
    position = Vector2(_targetX, gameRef.size.y * 0.82);
    add(RectangleHitbox(
      size: Vector2(44, 72),
      position: Vector2((size.x - 44) / 2, (size.y - 72) / 2),
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

  // ── Realistic Paperboy-style isometric bike (side profile, upper-right) ──

  void _renderBike(Canvas canvas) {
    final w = size.x;
    final h = size.y;

    // Frame anchor points.
    final bb = Offset(w * 0.50, h * 0.60);            // bottom bracket
    final seatTop = Offset(w * 0.33, h * 0.41);
    final headTube = Offset(w * 0.65, h * 0.25);

    // Wheels — isometric ellipses (squashed vertically).
    final rearCenter = Offset(w * 0.27, h * 0.74);
    final frontCenter = Offset(w * 0.70, h * 0.38);
    _drawIsoWheel(canvas, rearCenter, 28, 22, 24, 18, 6, 5);
    _drawIsoWheel(canvas, frontCenter, 24, 19, 20, 16, 5, 4);

    // Frame — bright red #D32F2F.
    final framePaint = Paint()
      ..color = const Color(0xFFD32F2F)
      ..strokeWidth = 3.0
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(seatTop, bb, framePaint);       // seat tube
    canvas.drawLine(seatTop, headTube, framePaint); // top tube
    canvas.drawLine(headTube, bb, framePaint);      // down tube
    canvas.drawLine(bb, rearCenter, framePaint);    // chain stay
    canvas.drawLine(rearCenter, seatTop, framePaint); // seat stay

    // Fork: two parallel lines from head tube to front wheel.
    const forkOffset = Offset(2, 0);
    canvas.drawLine(headTube - forkOffset, frontCenter - forkOffset, framePaint);
    canvas.drawLine(headTube + forkOffset, frontCenter + forkOffset, framePaint);

    // Handlebar at head tube.
    final stemTop = Offset(headTube.dx, headTube.dy - 6);
    canvas.drawLine(headTube, stemTop, framePaint);
    // Curved bar.
    final barPath = Path()
      ..moveTo(stemTop.dx - 8, stemTop.dy + 1)
      ..cubicTo(
        stemTop.dx - 4, stemTop.dy - 2,
        stemTop.dx + 4, stemTop.dy - 2,
        stemTop.dx + 8, stemTop.dy + 1,
      );
    canvas.drawPath(
      barPath,
      Paint()
        ..color = const Color(0xFF333333)
        ..strokeWidth = 2.4
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round,
    );
    // Grips at each end.
    final gripPaint = Paint()..color = const Color(0xFF1A1A1A);
    canvas.drawRect(
        Rect.fromLTWH(stemTop.dx - 10, stemTop.dy - 1, 4, 3), gripPaint);
    canvas.drawRect(
        Rect.fromLTWH(stemTop.dx + 6, stemTop.dy - 1, 4, 3), gripPaint);

    // Saddle — quadratic arc above seat post.
    final saddlePath = Path()
      ..moveTo(seatTop.dx - 9, seatTop.dy - 2)
      ..quadraticBezierTo(
        seatTop.dx, seatTop.dy - 6,
        seatTop.dx + 9, seatTop.dy - 2,
      );
    canvas.drawPath(
      saddlePath,
      Paint()
        ..color = const Color(0xFF222222)
        ..strokeWidth = 3.0
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round,
    );

    // Chain — dotted line BB → rear hub.
    final chainPaint = Paint()..color = const Color(0xFF555555);
    const chainSteps = 8;
    for (int i = 0; i <= chainSteps; i++) {
      final t = i / chainSteps;
      final cx = bb.dx + (rearCenter.dx - bb.dx) * t;
      final cy = bb.dy + (rearCenter.dy - bb.dy) * t;
      canvas.drawCircle(Offset(cx, cy), 0.9, chainPaint);
    }

    // Delivery bag on rear rack.
    final bagRect = Rect.fromLTWH(w * 0.06, h * 0.64, w * 0.36, h * 0.10);
    canvas.drawRRect(
      RRect.fromRectAndRadius(bagRect, const Radius.circular(3)),
      Paint()..color = const Color(0xFFFDD835),
    );
    canvas.drawRect(
      Rect.fromLTWH(w * 0.06, h * 0.64, w * 0.36, h * 0.022),
      Paint()..color = const Color(0xFFE65100),
    );

    // Pedals rotate with _wheelAngle.
    final pedalA = _wheelAngle;
    final pedalB = _wheelAngle + pi;
    final pedalPaint = Paint()..color = const Color(0xFF1A1A1A);
    final pedalAPos = bb + Offset(cos(pedalA) * 7, sin(pedalA) * 7);
    final pedalBPos = bb + Offset(cos(pedalB) * 7, sin(pedalB) * 7);
    canvas.save();
    canvas.translate(pedalAPos.dx, pedalAPos.dy);
    canvas.rotate(pedalA);
    canvas.drawRect(
        Rect.fromCenter(center: Offset.zero, width: 6, height: 2.5),
        pedalPaint);
    canvas.restore();
    canvas.save();
    canvas.translate(pedalBPos.dx, pedalBPos.dy);
    canvas.rotate(pedalB);
    canvas.drawRect(
        Rect.fromCenter(center: Offset.zero, width: 6, height: 2.5),
        pedalPaint);
    canvas.restore();

    // ── Rider ─────────────────────────────────────────────────────────
    // Hip / shoulder reference points (leaning forward).
    final hip = Offset(w * 0.38, h * 0.42);
    final shoulder = Offset(w * 0.62, h * 0.28);

    // Torso — filled polygon between hip and shoulder.
    const torsoHalf = 5.0;
    final torsoPath = Path()
      ..moveTo(hip.dx - torsoHalf, hip.dy)
      ..lineTo(shoulder.dx - torsoHalf, shoulder.dy)
      ..lineTo(shoulder.dx + torsoHalf, shoulder.dy)
      ..lineTo(hip.dx + torsoHalf, hip.dy)
      ..close();
    canvas.drawPath(
      torsoPath,
      Paint()..color = const Color(0xFF1565C0),
    );
    // Darker back-edge stripe.
    canvas.drawLine(
      Offset(shoulder.dx + torsoHalf, shoulder.dy),
      Offset(hip.dx + torsoHalf, hip.dy),
      Paint()
        ..color = const Color(0xFF0D47A1)
        ..strokeWidth = 2.0,
    );
    if (isVip) canvas.drawPath(torsoPath, Paint()..color = vipTint);

    // Legs (animate with _pedalPhase).
    final legPaint = Paint()
      ..color = const Color(0xFF1A237E)
      ..strokeWidth = 4
      ..strokeCap = StrokeCap.round;
    // Phase A: right leg down at pedalA_pos (calf to that pedal), left bent up.
    // Phase B: swap.
    final downPedal = _pedalPhase ? pedalAPos : pedalBPos;
    final upPedal = _pedalPhase ? pedalBPos : pedalAPos;
    final kneeDown = Offset(
      (hip.dx + downPedal.dx) / 2 - 2,
      (hip.dy + downPedal.dy) / 2 + 4,
    );
    final kneeUp = Offset(hip.dx + 5, hip.dy + 6);
    // Drive leg: hip → knee → down pedal.
    canvas.drawLine(hip, kneeDown, legPaint);
    canvas.drawLine(kneeDown, downPedal, legPaint);
    // Recovery leg: hip → knee bent up → up pedal.
    canvas.drawLine(hip, kneeUp, legPaint);
    canvas.drawLine(kneeUp, upPedal, legPaint);

    // Shoes on pedals.
    final shoePaint = Paint()..color = const Color(0xFF111111);
    canvas.drawOval(
        Rect.fromCenter(center: downPedal, width: 8, height: 4), shoePaint);
    canvas.drawOval(
        Rect.fromCenter(center: upPedal, width: 7, height: 4), shoePaint);

    // Head (squashed ellipse).
    final headCenter = Offset(w * 0.64, h * 0.20);
    canvas.drawOval(
      Rect.fromCenter(center: headCenter, width: 11, height: 10),
      Paint()..color = const Color(0xFFFFCC99),
    );

    // Helmet — yellow squashed dome.
    final helmetCenter = Offset(headCenter.dx, headCenter.dy - 3);
    canvas.drawOval(
      Rect.fromCenter(center: helmetCenter, width: 14, height: 8),
      Paint()..color = const Color(0xFFFFD600),
    );
    // Helmet outline.
    canvas.drawOval(
      Rect.fromCenter(center: helmetCenter, width: 14, height: 8),
      Paint()
        ..color = const Color(0xFFB37700)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.0,
    );
    // Chin strap.
    canvas.drawLine(
      Offset(headCenter.dx - 4, headCenter.dy + 3),
      Offset(headCenter.dx + 4, headCenter.dy + 3),
      Paint()
        ..color = const Color(0xFF1A1A1A)
        ..strokeWidth = 0.9,
    );

    // Arms.
    final upperArmPaint = Paint()
      ..color = const Color(0xFF1565C0)
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round;
    final forearmPaint = Paint()
      ..color = const Color(0xFFFFCC99)
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round;

    if (_throwArmTimer > 0) {
      // Throw arm: extends left-outward at ~-45° from body.
      final t = _throwArmTimer / _throwArmDuration;
      final ext = 8 + 14 * t;
      final throwElbow = Offset(shoulder.dx - 7, shoulder.dy + 3);
      final throwTip = Offset(
        shoulder.dx - 4 - cos(pi / 4) * ext,
        shoulder.dy + 2 - sin(pi / 4) * ext,
      );
      canvas.drawLine(shoulder, throwElbow, upperArmPaint);
      canvas.drawLine(throwElbow, throwTip, forearmPaint);
      canvas.drawCircle(throwTip, 2.4, Paint()..color = const Color(0xFFFFCC99));

      // Other arm still on handlebar.
      final elbow2 = Offset(shoulder.dx + 4, shoulder.dy + 3);
      canvas.drawLine(shoulder, elbow2, upperArmPaint);
      canvas.drawLine(elbow2, stemTop + const Offset(6, 0), forearmPaint);
    } else {
      // Both hands on handlebar.
      final elbow1 = Offset(shoulder.dx - 2, shoulder.dy + 4);
      final elbow2 = Offset(shoulder.dx + 4, shoulder.dy + 4);
      canvas.drawLine(shoulder, elbow1, upperArmPaint);
      canvas.drawLine(elbow1, stemTop + const Offset(-6, 0), forearmPaint);
      canvas.drawLine(shoulder, elbow2, upperArmPaint);
      canvas.drawLine(elbow2, stemTop + const Offset(6, 0), forearmPaint);
    }
  }

  // Isometric wheel — outer tyre oval, inner rim oval, hub, spokes.
  void _drawIsoWheel(
    Canvas canvas,
    Offset c,
    double tyreW,
    double tyreH,
    double rimW,
    double rimH,
    double hubW,
    double hubH,
  ) {
    canvas.drawOval(
      Rect.fromCenter(center: c, width: tyreW, height: tyreH),
      Paint()..color = const Color(0xFF1A1A1A),
    );
    canvas.drawOval(
      Rect.fromCenter(center: c, width: rimW, height: rimH),
      Paint()..color = const Color(0xFFCCCCCC),
    );
    canvas.drawOval(
      Rect.fromCenter(center: c, width: hubW, height: hubH),
      Paint()..color = const Color(0xFFE8E8E8),
    );
    // 6 spokes from hub edge to rim edge.
    final spokePaint = Paint()
      ..color = const Color(0xFF999999)
      ..strokeWidth = 1.2;
    canvas.save();
    canvas.translate(c.dx, c.dy);
    canvas.rotate(_wheelAngle);
    for (int i = 0; i < 6; i++) {
      final ang = i * pi / 3;
      canvas.drawLine(
        Offset(cos(ang) * hubW * 0.5, sin(ang) * hubH * 0.5),
        Offset(cos(ang) * rimW * 0.45, sin(ang) * rimH * 0.45),
        spokePaint,
      );
    }
    canvas.restore();
  }
}
