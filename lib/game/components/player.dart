import 'dart:math';
import 'dart:ui';
import 'package:flame/collisions.dart';
import 'package:flame/components.dart';
import '../delivery_dash_game.dart';
import '../perspective.dart';
import 'bike_trail.dart';

/// Player bicycle courier — drawn in a 3/4 diagonal perspective matching the
/// classic Paperboy arcade look. The bike faces upper-right (into the screen),
/// so you see the left-side profile with the front wheel at upper-right and
/// rear wheel at lower-left.
class PlayerComponent extends PositionComponent
    with HasGameRef<DeliveryDashGame>, CollisionCallbacks {
  static const Color vipTint = Color(0x88FFD54F);
  static const double _followSpeed = 8.0;
  static const double _flashInterval = 0.1;
  static const double _trailInterval = 0.06;
  static const double _pedalInterval = 0.25;

  // Sway: ±2° at 1.5 Hz.
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
      : super(size: Vector2(55, 80), anchor: Anchor.center, priority: 100);

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

    // Ground shadow (oval under bike).
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(size.x / 2, size.y - 2),
        width: size.x * 0.85 * s,
        height: 11 * s,
      ),
      Paint()..color = const Color(0x66000000),
    );

    // Speed lines at high levels.
    if (gameRef.level >= 5) {
      _renderSpeedLines(canvas, s);
    }

    canvas.save();
    canvas.translate(size.x / 2, size.y / 2);

    // Sway oscillation.
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
      ..strokeWidth = 1.5
      ..strokeCap = StrokeCap.round;
    for (int i = 0; i < 4; i++) {
      final lineY = size.y * (0.30 + i * 0.12);
      final lineLen = (20 + i * 8) * scale;
      canvas.drawLine(
        Offset(-lineLen - 4, lineY),
        Offset(-4, lineY),
        linePaint,
      );
    }
  }

  // ── 3/4 Diagonal bike rendering (Paperboy-style) ──────────────────────────

  void _renderBike(Canvas canvas) {
    final w = size.x;
    final h = size.y;

    // Rear wheel: lower-left, larger (closer to viewer).
    // Front wheel: upper-right, slightly smaller (isometric depth).
    final rearCenter = Offset(w * 0.30, h * 0.72);
    final frontCenter = Offset(w * 0.68, h * 0.38);
    const rearR = 12.0;
    const frontR = 10.0;

    // Motion-blur ovals behind rear wheel.
    for (int i = 1; i <= 3; i++) {
      canvas.drawOval(
        Rect.fromCenter(
          center: Offset(rearCenter.dx, rearCenter.dy + i * 3.5),
          width: rearR * 2 * 0.9,
          height: 5.0,
        ),
        Paint()..color = Color.fromARGB(35 - i * 9, 100, 100, 100),
      );
    }

    // Wheels — dark fill, tyre ring, spinning spokes, chrome hub.
    final wheelFill = Paint()..color = const Color(0xFF111111);
    final tirePaint = Paint()
      ..color = const Color(0xFF111111)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.2;
    final hubPaint = Paint()..color = const Color(0xFFD0D0D0);
    final spokePaint = Paint()
      ..color = const Color(0xFF777777)
      ..strokeWidth = 1.0;

    void drawWheel(Offset center, double r) {
      canvas.drawCircle(center, r, wheelFill);
      canvas.drawCircle(center, r + 1.5, tirePaint);
      canvas.save();
      canvas.translate(center.dx, center.dy);
      canvas.rotate(_wheelAngle);
      for (int i = 0; i < 6; i++) {
        final ang = i * pi / 3;
        canvas.drawLine(
          Offset(cos(ang) * r * 0.15, sin(ang) * r * 0.15),
          Offset(cos(ang) * r * 0.85, sin(ang) * r * 0.85),
          spokePaint,
        );
      }
      canvas.restore();
      canvas.drawCircle(center, 3.0, hubPaint);
    }

    drawWheel(rearCenter, rearR);
    drawWheel(frontCenter, frontR);

    // Frame — classic diamond layout in bright red.
    final bb = Offset(w * 0.50, h * 0.60);       // bottom bracket
    final seatTop = Offset(w * 0.35, h * 0.42);  // seat post top
    final headTop = Offset(w * 0.55, h * 0.28);  // head tube top

    final framePaint = Paint()
      ..color = const Color(0xFFCC2020)
      ..strokeWidth = 2.8
      ..strokeCap = StrokeCap.round;

    // Chain stay: rear wheel → BB.
    canvas.drawLine(rearCenter, bb, framePaint);
    // Seat stay: rear wheel → seat top.
    canvas.drawLine(rearCenter, seatTop, framePaint..strokeWidth = 2.0);
    // Seat tube: seat top → BB.
    canvas.drawLine(seatTop, bb, framePaint..strokeWidth = 2.2);
    // Down tube: head top → BB.
    canvas.drawLine(headTop, bb, framePaint..strokeWidth = 2.8);
    // Top tube: seat top → head top.
    canvas.drawLine(seatTop, headTop, framePaint..strokeWidth = 2.8);
    // Fork: head top → front wheel.
    canvas.drawLine(headTop, frontCenter, framePaint..strokeWidth = 2.2);

    // Saddle.
    canvas.drawLine(
      Offset(w * 0.24, h * 0.40),
      Offset(w * 0.44, h * 0.41),
      Paint()
        ..color = const Color(0xFF222222)
        ..strokeWidth = 3.5
        ..strokeCap = StrokeCap.round,
    );

    // Handlebar (at head tube top, slightly tilted).
    canvas.drawLine(
      Offset(w * 0.48, h * 0.24),
      Offset(w * 0.72, h * 0.26),
      Paint()
        ..color = const Color(0xFF333333)
        ..strokeWidth = 3.0
        ..strokeCap = StrokeCap.round,
    );

    // Delivery bag (rear rack).
    final bagRect = Rect.fromLTWH(w * 0.08, h * 0.70, w * 0.44, h * 0.10);
    canvas.drawRRect(
      RRect.fromRectAndRadius(bagRect, const Radius.circular(3)),
      Paint()..color = const Color(0xFFFDD835),
    );
    canvas.drawLine(
      Offset(w * 0.30, h * 0.70),
      Offset(w * 0.30, h * 0.80),
      Paint()..color = const Color(0xFFE65100)..strokeWidth = 1.5,
    );

    // Pedalling legs (dark blue pants).
    final legPaint = Paint()..color = const Color(0xFF0D47A1);
    final legFrontY = _pedalPhase ? h * 0.70 : h * 0.62;
    final legRearY = _pedalPhase ? h * 0.58 : h * 0.66;
    // Front leg (near BB, down stroke).
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTRB(w * 0.44, h * 0.57, w * 0.54, legFrontY),
        const Radius.circular(3),
      ),
      legPaint,
    );
    // Rear leg (up stroke).
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTRB(w * 0.32, h * 0.54, w * 0.42, legRearY),
        const Radius.circular(3),
      ),
      legPaint,
    );
    final shoePaint = Paint()..color = const Color(0xFF111111);
    canvas.drawOval(
      Rect.fromCenter(
          center: Offset(w * 0.49, legFrontY), width: 9, height: 4),
      shoePaint,
    );
    canvas.drawOval(
      Rect.fromCenter(
          center: Offset(w * 0.37, legRearY), width: 9, height: 4),
      shoePaint,
    );

    // Torso — blue jacket leaning forward toward handlebar.
    final torsoRect = Rect.fromLTWH(w * 0.30, h * 0.31, w * 0.46, h * 0.22);
    final torsoRRect =
        RRect.fromRectAndRadius(torsoRect, const Radius.circular(5));
    canvas.drawRRect(
      torsoRRect,
      Paint()
        ..shader = Gradient.linear(
          torsoRect.topLeft,
          torsoRect.bottomRight,
          [const Color(0xFF1565C0), const Color(0xFF0D47A1)],
        ),
    );
    if (isVip) canvas.drawRRect(torsoRRect, Paint()..color = vipTint);

    // Throw arm: extends left on throw.
    if (_throwArmTimer > 0) {
      final t = _throwArmTimer / _throwArmDuration;
      final armX = w * 0.28 - t * 16;
      final armY = h * 0.35;
      canvas.drawLine(
        Offset(w * 0.30, h * 0.37),
        Offset(armX, armY),
        Paint()
          ..color = const Color(0xFF1565C0)
          ..strokeWidth = 4.5
          ..strokeCap = StrokeCap.round,
      );
      canvas.drawCircle(
        Offset(armX, armY),
        3.5,
        Paint()..color = const Color(0xFFFFCC99),
      );
    }

    // Head — peach/tan face circle.
    canvas.drawCircle(
      Offset(w * 0.56, h * 0.21),
      4.0,
      Paint()..color = const Color(0xFFFFCC99),
    );

    // Helmet — yellow, slightly flattened oval.
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(w * 0.56, h * 0.15),
        width: 16,
        height: 10,
      ),
      Paint()..color = const Color(0xFFFFD600),
    );
    // Helmet brim.
    canvas.drawRect(
      Rect.fromLTWH(w * 0.36, h * 0.185, w * 0.38, 2.0),
      Paint()..color = const Color(0xFFCCAA00),
    );
    // Visor glare.
    canvas.drawArc(
      Rect.fromCenter(
        center: Offset(w * 0.48, h * 0.13),
        width: 7,
        height: 4.5,
      ),
      -pi * 0.75,
      pi * 0.45,
      false,
      Paint()
        ..color = const Color(0x88FFFFFF)
        ..strokeWidth = 1.5
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round,
    );
  }
}
