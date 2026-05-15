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

    // ── Ground shadow ─────────────────────────────────────────────────────
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(w * 0.5, h * 0.96),
        width: w * 0.7,
        height: h * 0.06,
      ),
      Paint()..color = const Color(0x55000000),
    );

    // ── Rear wheel (back-view: full circle, centred) ──────────────────────
    final wheelCenter = Offset(w * 0.5, h * 0.76);
    const tyreR = 19.0;
    const rimR = 15.0;
    canvas.drawCircle(
        wheelCenter, tyreR, Paint()..color = const Color(0xFF1A1A1A));
    canvas.drawCircle(
        wheelCenter, rimR, Paint()..color = const Color(0xFFB0B0B0));
    final spokePaint = Paint()
      ..color = const Color(0xFF888888)
      ..strokeWidth = 1.2;
    for (int i = 0; i < 8; i++) {
      final a = i * pi / 4 + _wheelAngle;
      canvas.drawLine(
        Offset(wheelCenter.dx + cos(a) * 3, wheelCenter.dy + sin(a) * 3),
        Offset(wheelCenter.dx + cos(a) * rimR * 0.88,
            wheelCenter.dy + sin(a) * rimR * 0.88),
        spokePaint,
      );
    }
    canvas.drawCircle(
        wheelCenter, 4.0, Paint()..color = const Color(0xFFE0E0E0));

    // ── Bike frame visible on both sides ──────────────────────────────────
    final framePaint = Paint()
      ..color = const Color(0xFFD32F2F)
      ..strokeWidth = 3.0
      ..strokeCap = StrokeCap.round;
    // Left seat stay.
    canvas.drawLine(
      Offset(wheelCenter.dx - 5, wheelCenter.dy - tyreR + 2),
      Offset(w * 0.34, h * 0.56),
      framePaint,
    );
    // Right seat stay.
    canvas.drawLine(
      Offset(wheelCenter.dx + 5, wheelCenter.dy - tyreR + 2),
      Offset(w * 0.66, h * 0.56),
      framePaint,
    );
    // Seat post (vertical).
    canvas.drawLine(
      Offset(w * 0.5, h * 0.56),
      Offset(w * 0.5, h * 0.44),
      framePaint,
    );

    // ── Saddle ────────────────────────────────────────────────────────────
    final saddlePaint = Paint()
      ..color = const Color(0xFF212121)
      ..strokeWidth = 5.0
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(
        Offset(w * 0.36, h * 0.44), Offset(w * 0.64, h * 0.44), saddlePaint);

    // ── Front fork (foreshortened stub below rider) ───────────────────────
    canvas.drawLine(
      Offset(w * 0.5, h * 0.76 - tyreR),
      Offset(w * 0.5, h * 0.62),
      Paint()
        ..color = const Color(0xFFD32F2F)
        ..strokeWidth = 2.5,
    );

    // ── Rider legs (visible each side of bike) ────────────────────────────
    final legPaint = Paint()
      ..color = const Color(0xFF1A237E)
      ..strokeWidth = 5.0
      ..strokeCap = StrokeCap.round;
    final phase = _pedalPhase ? 1.0 : -1.0;
    // Left thigh down and out.
    canvas.drawLine(
        Offset(w * 0.38, h * 0.52),
        Offset(w * 0.28 - phase * 4, h * 0.68),
        legPaint);
    // Left calf to pedal.
    canvas.drawLine(
        Offset(w * 0.28 - phase * 4, h * 0.68),
        Offset(w * 0.24 - phase * 2, h * 0.80),
        legPaint);
    // Right leg (opposite phase).
    canvas.drawLine(
        Offset(w * 0.62, h * 0.52),
        Offset(w * 0.72 + phase * 4, h * 0.68),
        legPaint);
    canvas.drawLine(
        Offset(w * 0.72 + phase * 4, h * 0.68),
        Offset(w * 0.76 + phase * 2, h * 0.80),
        legPaint);

    // Pedals.
    final pedalPaint = Paint()
      ..color = const Color(0xFF424242)
      ..strokeWidth = 4.0
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(
        Offset(w * 0.18, h * 0.80), Offset(w * 0.30, h * 0.80), pedalPaint);
    canvas.drawLine(
        Offset(w * 0.70, h * 0.80), Offset(w * 0.82, h * 0.80), pedalPaint);

    // ── Torso (filled trapezoid jacket) ───────────────────────────────────
    final torsoPath = Path()
      ..moveTo(w * 0.28, h * 0.44)
      ..lineTo(w * 0.72, h * 0.44)
      ..lineTo(w * 0.64, h * 0.18)
      ..lineTo(w * 0.36, h * 0.18)
      ..close();
    canvas.drawPath(torsoPath, Paint()..color = const Color(0xFF1565C0));
    // Jacket pocket line.
    canvas.drawLine(
      Offset(w * 0.36, h * 0.34),
      Offset(w * 0.64, h * 0.34),
      Paint()
        ..color = const Color(0xFF0D47A1)
        ..strokeWidth = 1.5,
    );
    if (isVip) {
      canvas.drawPath(torsoPath, Paint()..color = vipTint);
    }

    // ── Handlebars ────────────────────────────────────────────────────────
    // Stem.
    canvas.drawLine(
      Offset(w * 0.5, h * 0.24),
      Offset(w * 0.5, h * 0.18),
      Paint()
        ..color = const Color(0xFF424242)
        ..strokeWidth = 3.5,
    );
    // Bar.
    canvas.drawLine(
      Offset(w * 0.18, h * 0.22),
      Offset(w * 0.82, h * 0.22),
      Paint()
        ..color = const Color(0xFF616161)
        ..strokeWidth = 4.5
        ..strokeCap = StrokeCap.round,
    );
    // Grips (darker ends).
    canvas.drawLine(
        Offset(w * 0.18, h * 0.22),
        Offset(w * 0.26, h * 0.22),
        Paint()
          ..color = const Color(0xFF212121)
          ..strokeWidth = 6.0
          ..strokeCap = StrokeCap.round);
    canvas.drawLine(
        Offset(w * 0.74, h * 0.22),
        Offset(w * 0.82, h * 0.22),
        Paint()
          ..color = const Color(0xFF212121)
          ..strokeWidth = 6.0
          ..strokeCap = StrokeCap.round);

    // Arms: from grip to shoulder.
    final armPaint = Paint()
      ..color = const Color(0xFF1565C0)
      ..strokeWidth = 5.0
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(
        Offset(w * 0.26, h * 0.22), Offset(w * 0.30, h * 0.40), armPaint);
    canvas.drawLine(
        Offset(w * 0.74, h * 0.22), Offset(w * 0.70, h * 0.40), armPaint);

    // ── Head & Helmet ─────────────────────────────────────────────────────
    // Head (back of head — just a round shape, no face).
    canvas.drawCircle(
        Offset(w * 0.5, h * 0.12), 8.0, Paint()..color = const Color(0xFFFFCC99));

    // Helmet — top dome arc covering top half of head.
    final helmetPath = Path();
    helmetPath.addArc(
      Rect.fromCenter(
          center: Offset(w * 0.5, h * 0.10), width: 32, height: 24),
      pi,
      pi,
    );
    helmetPath.lineTo(w * 0.5 + 16, h * 0.10);
    helmetPath.close();
    canvas.drawPath(helmetPath, Paint()..color = const Color(0xFFFFD600));
    // Helmet strap (thin lines down each side).
    canvas.drawLine(
      Offset(w * 0.5 - 8, h * 0.14),
      Offset(w * 0.5 - 6, h * 0.18),
      Paint()
        ..color = const Color(0xFF5D4037)
        ..strokeWidth = 1.5,
    );
    canvas.drawLine(
      Offset(w * 0.5 + 8, h * 0.14),
      Offset(w * 0.5 + 6, h * 0.18),
      Paint()
        ..color = const Color(0xFF5D4037)
        ..strokeWidth = 1.5,
    );

    // ── Throwing arm overlay (in the chosen throw direction) ──────────────
    if (_throwArmTimer > 0) {
      final t = _throwArmTimer / _throwArmDuration;
