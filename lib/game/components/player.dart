import 'dart:math';
import 'dart:ui';
import 'package:flame/collisions.dart';
import 'package:flame/components.dart';
import '../delivery_dash_game.dart';
import 'bike_trail.dart';

/// Player bicycle courier — back-of-bike view, Road Rash perspective.
/// Camera is directly behind the player; the bike fills the bottom-center
/// of the screen with the rider looking forward into the scene.
class PlayerComponent extends PositionComponent
    with HasGameRef<DeliveryDashGame>, CollisionCallbacks {
  static const Color vipTint = Color(0x88FFD54F);
  static const double _followSpeed = 8.0;
  static const double _flashInterval = 0.1;
  static const double _trailInterval = 0.06;
  static const double _pedalInterval = 0.25;

  static const double _swayAmplitudeDeg = 1.5;
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
      : super(size: Vector2(80, 100), anchor: Anchor.center, priority: 100);

  double get opacity => _opacity;
  set opacity(double v) => _opacity = v.clamp(0.0, 1.0);

  void triggerThrowArm({bool throwLeft = true}) {
    _throwArmTimer = _throwArmDuration;
    _throwArmLeft = throwLeft;
  }

  @override
  Future<void> onLoad() async {
    position = Vector2(gameRef.size.x * 0.5, gameRef.size.y * 0.85);
    _targetX = position.x;
    add(RectangleHitbox(
      size: Vector2(56, 78),
      position: Vector2((size.x - 56) / 2, (size.y - 78) / 2),
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

    // Keep player pinned at 85% down (camera depth).
    position.y = gameRef.size.y * 0.85;

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
    // Ground shadow.
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(size.x / 2, size.y - 2),
        width: size.x * 0.85,
        height: 14,
      ),
      Paint()..color = const Color(0x88000000),
    );

    if (gameRef.level >= 5) {
      _renderSpeedLines(canvas);
    }

    canvas.save();
    canvas.translate(size.x / 2, size.y / 2);

    final swayRad = (_swayAmplitudeDeg * pi / 180) *
        sin(_swayTimer * 2 * pi * _swayHz);
    canvas.rotate(swayRad);

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

  void _renderSpeedLines(Canvas canvas) {
    final speedFraction =
        ((gameRef.scrollSpeed - 300) / 200).clamp(0.0, 1.0);
    if (speedFraction <= 0) return;
    final linePaint = Paint()
      ..color = const Color(0xFFFFFFFF).withValues(alpha: speedFraction * 0.7)
      ..strokeWidth = 1.6
      ..strokeCap = StrokeCap.round;
    for (int i = 0; i < 4; i++) {
      final lineY = size.y * (0.30 + i * 0.12);
      final lineLen = 24 + i * 8;
      canvas.drawLine(
        Offset(-lineLen - 4, lineY),
        Offset(-4, lineY),
        linePaint,
      );
    }
  }

  // ── Back-of-bike rendering ────────────────────────────────────────────────

  void _renderBike(Canvas canvas) {
    final w = size.x;
    final h = size.y;
    final cx = w * 0.5;

    // ── Distant front wheel partially visible between rider's legs ─────────
    final frontWheelCenter = Offset(cx, h * 0.52);
    final frontTyre = Paint()..color = const Color(0xFF1A1A1A);
    canvas.drawCircle(frontWheelCenter, 18, frontTyre);
    canvas.drawCircle(
      frontWheelCenter,
      14,
      Paint()..color = const Color(0xFF888888),
    );
    canvas.drawCircle(
      frontWheelCenter,
      3,
      Paint()..color = const Color(0xFFC8C8C8),
    );

    // ── Rear wheel (large, closest to camera) ──────────────────────────────
    final rearWheelCenter = Offset(cx, h * 0.75);
    // Outer tyre.
    canvas.drawCircle(
      rearWheelCenter,
      32,
      Paint()..color = const Color(0xFF1A1A1A),
    );
    // Rim.
    canvas.drawCircle(
      rearWheelCenter,
      27,
      Paint()..color = const Color(0xFFC8C8C8),
    );
    // Spokes.
    final spokePaint = Paint()
      ..color = const Color(0xFF888888)
      ..strokeWidth = 1.4;
    for (int i = 0; i < 8; i++) {
      final a = i * pi / 4 + _wheelAngle;
      canvas.drawLine(
        rearWheelCenter,
        Offset(
          rearWheelCenter.dx + cos(a) * 26,
          rearWheelCenter.dy + sin(a) * 26,
        ),
        spokePaint,
      );
    }
    // Hub.
    canvas.drawCircle(
      rearWheelCenter,
      5,
      Paint()..color = const Color(0xFFE8E8E8),
    );

    // ── Frame visible from behind ──────────────────────────────────────────
    final framePaint = Paint()
      ..color = const Color(0xFFE53935)
      ..strokeWidth = 3.4
      ..strokeCap = StrokeCap.round;

    // Chainstays — V-shape from rear axle outward/upward.
    canvas.drawLine(
      rearWheelCenter,
      Offset(cx - 10, h * 0.62),
      framePaint,
    );
    canvas.drawLine(
      rearWheelCenter,
      Offset(cx + 10, h * 0.62),
      framePaint,
    );
    // Seat stays from axle to seat post.
    canvas.drawLine(
      rearWheelCenter,
      Offset(cx, h * 0.44),
      framePaint,
    );

    // Seat post.
    canvas.drawLine(
      Offset(cx, h * 0.75),
      Offset(cx, h * 0.42),
      Paint()
        ..color = const Color(0xFF333333)
        ..strokeWidth = 4
        ..strokeCap = StrokeCap.round,
    );

    // Seat.
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(cx, h * 0.42),
        width: 30,
        height: 8,
      ),
      Paint()..color = const Color(0xFF1A1A1A),
    );

    // ── Rider — back view ──────────────────────────────────────────────────
    // Torso: blue jacket as a rounded rectangle.
    final jacketRect = RRect.fromRectAndRadius(
      Rect.fromLTRB(w * 0.28, h * 0.18, w * 0.72, h * 0.45),
      const Radius.circular(8),
    );
    canvas.drawRRect(
      jacketRect,
      Paint()
        ..shader = Gradient.linear(
          Offset(w * 0.28, h * 0.18),
          Offset(w * 0.72, h * 0.45),
          [const Color(0xFF1976D2), const Color(0xFF0D47A1)],
        ),
    );
    canvas.drawRRect(
      jacketRect,
      Paint()
        ..color = const Color(0xFF0A2E5C)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.2,
    );
    if (isVip) {
      canvas.drawRRect(jacketRect, Paint()..color = vipTint);
    }

    // Backpack on rider's back.
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTRB(w * 0.36, h * 0.22, w * 0.64, h * 0.40),
        const Radius.circular(4),
      ),
      Paint()..color = const Color(0xFF5D4037),
    );
    canvas.drawRect(
      Rect.fromLTWH(w * 0.36, h * 0.30, w * 0.28, 2),
      Paint()..color = const Color(0xFF3E2723),
    );

    // ── Arms going out to handlebars ─────────────────────────────────────
    final armPaint = Paint()
      ..color = const Color(0xFF1976D2)
      ..strokeWidth = 6
      ..strokeCap = StrokeCap.round;
    final leftShoulder = Offset(w * 0.30, h * 0.24);
    final rightShoulder = Offset(w * 0.70, h * 0.24);
    final leftGrip = Offset(w * 0.18, h * 0.34);
    final rightGrip = Offset(w * 0.82, h * 0.34);
    canvas.drawLine(leftShoulder, leftGrip, armPaint);
    canvas.drawLine(rightShoulder, rightGrip, armPaint);

    // Forearms — slightly lighter colour.
    final forearmPaint = Paint()
      ..color = const Color(0xFF42A5F5)
      ..strokeWidth = 5
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(
      Offset(w * 0.24, h * 0.30),
      leftGrip,
      forearmPaint,
    );
    canvas.drawLine(
      Offset(w * 0.76, h * 0.30),
      rightGrip,
      forearmPaint,
    );

    // Hands.
    final handPaint = Paint()..color = const Color(0xFFFFCC99);
    canvas.drawCircle(leftGrip, 4, handPaint);
    canvas.drawCircle(rightGrip, 4, handPaint);

    // ── Handlebar (horizontal bar between hands) ──────────────────────────
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTRB(w * 0.16, h * 0.33, w * 0.84, h * 0.355),
        const Radius.circular(3),
      ),
      Paint()..color = const Color(0xFF222222),
    );

    // ── Legs (visible on each side of bike) ────────────────────────────────
    final pedalAngle = _pedalPhase ? 0.0 : pi;
    final legPaint = Paint()
      ..color = const Color(0xFF1A237E)
      ..strokeWidth = 8
      ..strokeCap = StrokeCap.round;

    final hipL = Offset(w * 0.36, h * 0.46);
    final hipR = Offset(w * 0.64, h * 0.46);
    final kneeL = Offset(w * 0.30, h * 0.62 + sin(pedalAngle) * 4);
    final kneeR = Offset(w * 0.70, h * 0.62 + sin(pedalAngle + pi) * 4);
    final pedalL = Offset(w * 0.34, h * 0.78 + sin(pedalAngle) * 4);
    final pedalR = Offset(w * 0.66, h * 0.78 + sin(pedalAngle + pi) * 4);

    canvas.drawLine(hipL, kneeL, legPaint);
    canvas.drawLine(kneeL, pedalL, legPaint);
    canvas.drawLine(hipR, kneeR, legPaint);
    canvas.drawLine(kneeR, pedalR, legPaint);

    // Pedals (horizontal rectangles).
    final pedalPaint = Paint()..color = const Color(0xFF111111);
    canvas.drawRect(
      Rect.fromCenter(center: pedalL, width: 12, height: 4),
      pedalPaint,
    );
    canvas.drawRect(
      Rect.fromCenter(center: pedalR, width: 12, height: 4),
      pedalPaint,
    );

    // ── Helmet (round, viewed from behind) ────────────────────────────────
    final helmetCenter = Offset(cx, h * 0.14);
    canvas.drawOval(
      Rect.fromCenter(
        center: helmetCenter,
        width: w * 0.32,
        height: w * 0.30,
      ),
      Paint()..color = const Color(0xFFFFD600),
    );
    canvas.drawOval(
      Rect.fromCenter(
        center: helmetCenter,
        width: w * 0.32,
        height: w * 0.30,
      ),
      Paint()
        ..color = const Color(0xFFB37700)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.4,
    );
    // Helmet rear vent stripe.
    canvas.drawRect(
      Rect.fromCenter(
        center: helmetCenter,
        width: w * 0.20,
        height: 2,
      ),
      Paint()..color = const Color(0xFFB37700),
    );
    // Chin strap lines on sides.
    final strapPaint = Paint()
      ..color = const Color(0xFF333333)
      ..strokeWidth = 1.2;
    canvas.drawLine(
      Offset(helmetCenter.dx - w * 0.15, helmetCenter.dy + 2),
      Offset(helmetCenter.dx - w * 0.12, helmetCenter.dy + h * 0.08),
      strapPaint,
    );
    canvas.drawLine(
      Offset(helmetCenter.dx + w * 0.15, helmetCenter.dy + 2),
      Offset(helmetCenter.dx + w * 0.12, helmetCenter.dy + h * 0.08),
      strapPaint,
    );

    // ── Throwing arm overlay (in the chosen throw direction) ──────────────
    if (_throwArmTimer > 0) {
      final t = _throwArmTimer / _throwArmDuration;
      final base = _throwArmLeft
          ? Offset(w * 0.30, h * 0.28)
          : Offset(w * 0.70, h * 0.28);
      final dir = _throwArmLeft ? -1.0 : 1.0;
      final tip = Offset(base.dx + dir * (20 * t + 8), base.dy - 10 * t);
      canvas.drawLine(
        base,
        tip,
        Paint()
          ..color = const Color(0xFF1976D2)
          ..strokeWidth = 5
          ..strokeCap = StrokeCap.round,
      );
      canvas.drawCircle(tip, 4.0, Paint()..color = const Color(0xFFFFCC80));
    }
  }
}
