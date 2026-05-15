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
      : super(size: Vector2(80, 110), anchor: Anchor.center, priority: 100);

  double get opacity => _opacity;
  set opacity(double v) => _opacity = v.clamp(0.0, 1.0);

  void triggerThrowArm({bool throwLeft = true}) {
    _throwArmTimer = _throwArmDuration;
    _throwArmLeft = throwLeft;
  }

  @override
  Future<void> onLoad() async {
    position = Vector2(gameRef.size.x * 0.5, gameRef.size.y * 0.78);
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

    // Keep player pinned at 78% down (camera depth).
    position.y = gameRef.size.y * 0.78;

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
    // Wrap everything in an opacity layer when flashing (invincibility).
    // saveLayer must be outermost — before any rotation — so its Rect bounds
    // are in the unrotated component coordinate space and the nesting is clean.
    final needsLayer = _opacity < 1.0;
    if (needsLayer) {
      canvas.saveLayer(
        Rect.fromLTWH(0, 0, size.x, size.y),
        Paint()
          ..color = Color.fromARGB((_opacity * 255).round(), 255, 255, 255),
      );
    }

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

    // Sway rotation around component centre.
    canvas.save();
    canvas.translate(size.x / 2, size.y / 2);
    final swayRad = (_swayAmplitudeDeg * pi / 180) *
        sin(_swayTimer * 2 * pi * _swayHz);
    canvas.rotate(swayRad);
    canvas.translate(-size.x / 2, -size.y / 2);

    _renderBike(canvas);

    if (_wetTimer > 0) {
      final phase = _wetTimer / _wetDuration;
      final alpha = (1 - (phase - 0.5).abs() * 2) * 0.4;
      canvas.drawRect(
        Rect.fromLTWH(0, 0, size.x, size.y),
        Paint()..color = const Color(0xFF42A5F5).withValues(alpha: alpha),
      );
    }

    canvas.restore(); // sway rotation

    if (needsLayer) canvas.restore(); // opacity layer
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
    final w = size.x; // 80
    final h = size.y; // 110

    // Pedal phase drives leg/pedal animation.
    final phase = _pedalPhase ? 1.0 : -1.0;

    // ── Ground shadow ─────────────────────────────────────────────────────
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(w * 0.5, h * 0.97),
        width: w * 0.75,
        height: h * 0.05,
      ),
      Paint()..color = const Color(0x55000000),
    );

    // ── Front wheel peek (partially hidden behind rider) ──────────────────
    canvas.drawArc(
      Rect.fromCenter(
        center: Offset(w * 0.50, h * 0.63),
        width: 20,
        height: 20,
      ),
      pi,
      pi,
      false,
      Paint()
        ..color = const Color(0xFF2A2A2A)
        ..strokeWidth = 3.0
        ..style = PaintingStyle.stroke,
    );

    // ── Rear wheel ────────────────────────────────────────────────────────
    final wCx = Offset(w * 0.50, h * 0.80);
    const tyreR = 22.0;
    const rimR = 17.0;
    // Tyre shadow.
    canvas.drawCircle(wCx, tyreR + 1.5, Paint()..color = const Color(0x44000000));
    // Tyre.
    canvas.drawCircle(wCx, tyreR, Paint()..color = const Color(0xFF1A1A1A));
    // Tyre glint.
    canvas.drawArc(
      Rect.fromCenter(center: wCx, width: tyreR * 2, height: tyreR * 2),
      -pi * 0.75, pi * 0.5, false,
      Paint()
        ..color = const Color(0xFF404040)
        ..strokeWidth = 3.5
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round,
    );
    // Rim.
    canvas.drawCircle(wCx, rimR, Paint()..color = const Color(0xFFD0D0D0));
    canvas.drawCircle(
        wCx, rimR,
        Paint()
          ..color = const Color(0xFF777777)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.2);
    // Spokes — 12.
    final spokePaint = Paint()
      ..color = const Color(0xFF999999)
      ..strokeWidth = 1.0;
    for (int i = 0; i < 12; i++) {
      final a = i * pi / 6 + _wheelAngle;
      canvas.drawLine(
        Offset(wCx.dx + cos(a) * 3.5, wCx.dy + sin(a) * 3.5),
        Offset(wCx.dx + cos(a) * (rimR - 1), wCx.dy + sin(a) * (rimR - 1)),
        spokePaint,
      );
    }
    // Hub.
    canvas.drawCircle(wCx, 4.5, Paint()..color = const Color(0xFF555555));
    canvas.drawCircle(wCx, 2.5, Paint()..color = const Color(0xFFAAAAAA));

    // ── Frame: seat stays + seat post ────────────────────────────────────
    final framePaint = Paint()
      ..color = const Color(0xFFCC1F1F)
      ..strokeWidth = 3.5
      ..strokeCap = StrokeCap.round;
    // Left seat stay (axle → saddle cluster).
    canvas.drawLine(
      Offset(wCx.dx - 8, wCx.dy - tyreR + 4),
      Offset(w * 0.31, h * 0.57),
      framePaint,
    );
    // Right seat stay.
    canvas.drawLine(
      Offset(wCx.dx + 8, wCx.dy - tyreR + 4),
      Offset(w * 0.69, h * 0.57),
      framePaint,
    );
    // Seat post (saddle cluster → saddle).
    canvas.drawLine(
      Offset(w * 0.50, h * 0.57),
      Offset(w * 0.50, h * 0.47),
      framePaint,
    );
    // Chain stays (foreshortened stubs at axle level).
    final chainStayPaint = Paint()
      ..color = const Color(0xFFCC1F1F)
      ..strokeWidth = 2.5
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(
      Offset(wCx.dx - 4, wCx.dy),
      Offset(w * 0.37, h * 0.82),
      chainStayPaint,
    );
    canvas.drawLine(
      Offset(wCx.dx + 4, wCx.dy),
      Offset(w * 0.63, h * 0.82),
      chainStayPaint,
    );

    // ── Delivery bag on rear rack ─────────────────────────────────────────
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(w * 0.30, h * 0.57, w * 0.40, h * 0.12),
        const Radius.circular(3),
      ),
      Paint()..color = const Color(0xFF5D4037),
    );
    canvas.drawLine(
      Offset(w * 0.30, h * 0.61),
      Offset(w * 0.70, h * 0.61),
      Paint()..color = const Color(0xFF4E342E)..strokeWidth = 1.0,
    );
    // Bag buckle.
    canvas.drawRect(
      Rect.fromCenter(center: Offset(w * 0.50, h * 0.60), width: 6, height: 4),
      Paint()..color = const Color(0xFFD4A017),
    );

    // ── Saddle ───────────────────────────────────────────────────────────
    // Rails (under saddle).
    canvas.drawLine(
      Offset(w * 0.32, h * 0.48),
      Offset(w * 0.68, h * 0.48),
      Paint()..color = const Color(0xFF444444)..strokeWidth = 1.5,
    );
    // Saddle body (oval — wider at rear, narrowing to nose in front).
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(w * 0.50, h * 0.46),
        width: w * 0.42,
        height: h * 0.055,
      ),
      Paint()..color = const Color(0xFF1A1A1A),
    );

    // ── Rider legs ───────────────────────────────────────────────────────
    final legPaint = Paint()
      ..color = const Color(0xFF0D1B5E)
      ..strokeWidth = 6.0
      ..strokeCap = StrokeCap.round;
    // Left leg.
    final lKneeX = w * 0.25 - phase * 3;
    final lKneeY = h * 0.64 + phase * 4;
    final lFootX = w * 0.21 - phase * 2;
    final lFootY = h * 0.78 + phase * 5;
    canvas.drawLine(Offset(w * 0.33, h * 0.49), Offset(lKneeX, lKneeY), legPaint);
    canvas.drawLine(Offset(lKneeX, lKneeY), Offset(lFootX, lFootY), legPaint);
    // Right leg (opposite phase).
    final rKneeX = w * 0.75 + phase * 3;
    final rKneeY = h * 0.64 - phase * 4;
    final rFootX = w * 0.79 + phase * 2;
    final rFootY = h * 0.78 - phase * 5;
    canvas.drawLine(Offset(w * 0.67, h * 0.49), Offset(rKneeX, rKneeY), legPaint);
    canvas.drawLine(Offset(rKneeX, rKneeY), Offset(rFootX, rFootY), legPaint);

    // Cycling shoes + pedals.
    final pedalPaint = Paint()
      ..color = const Color(0xFF333333)
      ..strokeWidth = 5.0
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(
      Offset(lFootX - 8, lFootY), Offset(lFootX + 8, lFootY), pedalPaint);
    canvas.drawLine(
      Offset(rFootX - 8, rFootY), Offset(rFootX + 8, rFootY), pedalPaint);

    // ── Torso (crouched forward — wide at hips, narrower at shoulders) ────
    final torsoPath = Path()
      ..moveTo(w * 0.27, h * 0.47)
      ..lineTo(w * 0.73, h * 0.47)
      ..lineTo(w * 0.63, h * 0.21)
      ..lineTo(w * 0.37, h * 0.21)
      ..close();
    canvas.drawPath(torsoPath, Paint()..color = const Color(0xFF1565C0));
    // Jersey centre stripe.
    canvas.drawLine(
      Offset(w * 0.50, h * 0.47),
      Offset(w * 0.50, h * 0.21),
      Paint()..color = const Color(0xFFFFD600)..strokeWidth = 3.0,
    );
    // Jersey pocket.
    canvas.drawRect(
      Rect.fromLTWH(w * 0.42, h * 0.36, w * 0.16, h * 0.06),
      Paint()..color = const Color(0xFF0D47A1),
    );
    if (isVip) {
      canvas.drawPath(torsoPath, Paint()..color = vipTint);
    }

    // ── Drop handlebars ───────────────────────────────────────────────────
    // Stem (short — rear view).
    canvas.drawLine(
      Offset(w * 0.50, h * 0.22),
      Offset(w * 0.50, h * 0.29),
      Paint()..color = const Color(0xFF666666)..strokeWidth = 3.5,
    );
    // Crossbar.
    canvas.drawLine(
      Offset(w * 0.17, h * 0.29),
      Offset(w * 0.83, h * 0.29),
      Paint()
        ..color = const Color(0xFF888888)
        ..strokeWidth = 4.5
        ..strokeCap = StrokeCap.round,
    );
    // Drops (bend down).
    canvas.drawLine(
      Offset(w * 0.17, h * 0.29),
      Offset(w * 0.15, h * 0.37),
      Paint()
        ..color = const Color(0xFF888888)
        ..strokeWidth = 4.0
        ..strokeCap = StrokeCap.round,
    );
    canvas.drawLine(
      Offset(w * 0.83, h * 0.29),
      Offset(w * 0.85, h * 0.37),
      Paint()
        ..color = const Color(0xFF888888)
        ..strokeWidth = 4.0
        ..strokeCap = StrokeCap.round,
    );
    // Bar tape grips.
    canvas.drawLine(
      Offset(w * 0.15, h * 0.33),
      Offset(w * 0.15, h * 0.39),
      Paint()
        ..color = const Color(0xFF1A1A1A)
        ..strokeWidth = 7.0
        ..strokeCap = StrokeCap.round,
    );
    canvas.drawLine(
      Offset(w * 0.85, h * 0.33),
      Offset(w * 0.85, h * 0.39),
      Paint()
        ..color = const Color(0xFF1A1A1A)
        ..strokeWidth = 7.0
        ..strokeCap = StrokeCap.round,
    );

    // ── Arms (from shoulders to bar grips) ───────────────────────────────
    final armPaint = Paint()
      ..color = const Color(0xFF1565C0)
      ..strokeWidth = 5.5
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(
        Offset(w * 0.37, h * 0.23), Offset(w * 0.15, h * 0.37), armPaint);
    canvas.drawLine(
        Offset(w * 0.63, h * 0.23), Offset(w * 0.85, h * 0.37), armPaint);

    // ── Head (back — no face) ─────────────────────────────────────────────
    canvas.drawCircle(
        Offset(w * 0.50, h * 0.14),
        8.0,
        Paint()..color = const Color(0xFFFFCC99));

    // ── Aero helmet (elongated oval, yellow) ──────────────────────────────
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(w * 0.50, h * 0.09),
        width: 28,
        height: 17,
      ),
      Paint()..color = const Color(0xFFFFD600),
    );
    // Helmet vents.
    final ventPaint = Paint()
      ..color = const Color(0xFFCC9900)
      ..strokeWidth = 1.5;
    canvas.drawLine(
        Offset(w * 0.44, h * 0.05), Offset(w * 0.44, h * 0.13), ventPaint);
    canvas.drawLine(
        Offset(w * 0.50, h * 0.04), Offset(w * 0.50, h * 0.14), ventPaint);
    canvas.drawLine(
        Offset(w * 0.56, h * 0.05), Offset(w * 0.56, h * 0.13), ventPaint);
    // Helmet straps.
    canvas.drawLine(
      Offset(w * 0.44, h * 0.13),
      Offset(w * 0.41, h * 0.17),
      Paint()..color = const Color(0xFF5D4037)..strokeWidth = 1.5,
    );
    canvas.drawLine(
      Offset(w * 0.56, h * 0.13),
      Offset(w * 0.59, h * 0.17),
      Paint()..color = const Color(0xFF5D4037)..strokeWidth = 1.5,
    );

    // ── Throwing arm overlay ──────────────────────────────────────────────
    if (_throwArmTimer > 0) {
      final t = _throwArmTimer / _throwArmDuration;
      final base = _throwArmLeft
          ? Offset(w * 0.15, h * 0.37)
          : Offset(w * 0.85, h * 0.37);
      final dir = _throwArmLeft ? -1.0 : 1.0;
      final tip = Offset(base.dx + dir * (22 * t + 6), base.dy - 8 * t);
      canvas.drawLine(
        base,
        tip,
        Paint()
          ..color = const Color(0xFF1565C0)
          ..strokeWidth = 5
          ..strokeCap = StrokeCap.round,
      );
      canvas.drawCircle(tip, 4.0, Paint()..color = const Color(0xFFFFCC80));
    }
  }
}
