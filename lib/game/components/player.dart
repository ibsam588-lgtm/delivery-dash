import 'dart:math';
import 'dart:ui';
import 'package:flame/collisions.dart';
import 'package:flame/components.dart';
import '../delivery_dash_game.dart';
import 'bike_trail.dart';

/// Player bicycle courier — hand-drawn Paperboy-style bike/rider art.
///
/// The rider is drawn procedurally instead of depending on a PNG sprite so the
/// game keeps a consistent retro arcade style across devices and resolutions.
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
  double _pedalTimer = 0;
  bool _pedalPhase = false;
  bool _throwLeft = true;
  double _swayTimer = 0;
  double _throwArmTimer = 0;
  static const double _wetDuration = 0.4;

  PlayerComponent({this.isVip = false})
      : super(size: Vector2(90, 120), anchor: Anchor.center, priority: 100);

  double get opacity => _opacity;
  set opacity(double v) => _opacity = v.clamp(0.0, 1.0);

  void triggerThrowArm({bool throwLeft = true}) {
    _throwLeft = throwLeft;
    _throwArmTimer = _throwArmDuration;
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
      _opacity = 1.0;
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
    canvas.rotate(_swayTimer > 0
        ? sin(_swayTimer * _swayHz * 2 * pi) * _swayAmplitudeDeg * pi / 180
        : 0);
    canvas.translate(-size.x / 2, -size.y / 2);

    _renderCourier(canvas);

    if (_wetTimer > 0) {
      final a = (_wetTimer / _wetDuration) * 0.45;
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(8, 8, size.x - 16, size.y - 16),
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
    final wheelAngle = _swayTimer * 12.0;
    final throwT = _throwArmTimer / _throwArmDuration;
    final pedalLift = _pedalPhase ? 1.0 : -1.0;

    if (isVip) {
      canvas.drawOval(
        Rect.fromCenter(
          center: Offset(w * 0.50, h * 0.58),
          width: w * 0.95,
          height: h * 0.95,
        ),
        Paint()..color = vipTint.withValues(alpha: 0.22),
      );
    }

    // Ground contact shadow.
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(w * 0.50, h * 0.92),
        width: w * 0.78,
        height: h * 0.10,
      ),
      Paint()..color = const Color(0x66000000),
    );

    final rear = Offset(w * 0.34, h * 0.80);
    final front = Offset(w * 0.66, h * 0.80);
    final rearR = w * 0.18;
    final frontR = w * 0.17;
    _drawWheel(canvas, rear, rearR, wheelAngle);
    _drawWheel(canvas, front, frontR, wheelAngle + pi / 8);

    final framePaint = Paint()
      ..color = const Color(0xFFE53935)
      ..strokeWidth = 4.2
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    final frameShadow = Paint()
      ..color = const Color(0x66000000)
      ..strokeWidth = 6.0
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final seat = Offset(w * 0.43, h * 0.49);
    final handle = Offset(w * 0.63, h * 0.47);
    final crank = Offset(w * 0.50, h * 0.66);

    void line(Offset a, Offset b, Paint p) => canvas.drawLine(a, b, p);
    for (final p in [frameShadow, framePaint]) {
      line(seat, crank, p);
      line(handle, crank, p);
      line(seat, handle, p);
      line(seat, rear, p);
      line(crank, rear, p);
      line(handle, front, p);
      line(crank, front, p);
    }

    // Pedals and crank.
    canvas.drawCircle(crank, 5, Paint()..color = const Color(0xFF212121));
    final pedalPaint = Paint()
      ..color = const Color(0xFF263238)
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(
      crank,
      Offset(crank.dx + 11, crank.dy + pedalLift * 8),
      pedalPaint,
    );
    canvas.drawLine(
      crank,
      Offset(crank.dx - 11, crank.dy - pedalLift * 8),
      pedalPaint,
    );

    // Rear newspaper bag.
    final bagRect = RRect.fromRectAndRadius(
      Rect.fromCenter(
        center: Offset(w * 0.30, h * 0.52),
        width: w * 0.28,
        height: h * 0.22,
      ),
      const Radius.circular(6),
    );
    canvas.drawRRect(bagRect, Paint()..color = const Color(0xFFFFC107));
    canvas.drawRRect(
      bagRect,
      Paint()
        ..color = const Color(0xFF5D4037)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2,
    );
    canvas.drawLine(
      Offset(w * 0.20, h * 0.49),
      Offset(w * 0.40, h * 0.49),
      Paint()
        ..color = const Color(0xFF6D4C41)
        ..strokeWidth = 2,
    );

    // Rider body.
    final bodyRect = RRect.fromRectAndRadius(
      Rect.fromCenter(
        center: Offset(w * 0.50, h * 0.42),
        width: w * 0.25,
        height: h * 0.27,
      ),
      const Radius.circular(9),
    );
    canvas.drawRRect(
      bodyRect,
      Paint()
        ..shader = Gradient.linear(
          Offset(w * 0.42, h * 0.28),
          Offset(w * 0.58, h * 0.55),
          [const Color(0xFF2196F3), const Color(0xFF0D47A1)],
        ),
    );
    canvas.drawRRect(
      bodyRect,
      Paint()
        ..color = const Color(0xFF05294D)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5,
    );

    // Head and helmet.
    canvas.drawCircle(
      Offset(w * 0.50, h * 0.23),
      w * 0.13,
      Paint()..color = const Color(0xFFFFCC99),
    );
    final helmet = Path()
      ..moveTo(w * 0.36, h * 0.22)
      ..quadraticBezierTo(w * 0.50, h * 0.04, w * 0.64, h * 0.22)
      ..lineTo(w * 0.60, h * 0.17)
      ..quadraticBezierTo(w * 0.50, h * 0.11, w * 0.40, h * 0.17)
      ..close();
    canvas.drawPath(helmet, Paint()..color = const Color(0xFFE53935));
    canvas.drawPath(
      helmet,
      Paint()
        ..color = const Color(0xFF7F0000)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.4,
    );

    // Simple face from rear/three-quarter view.
    canvas.drawCircle(
      Offset(w * 0.46, h * 0.24),
      1.6,
      Paint()..color = const Color(0xFF222222),
    );
    canvas.drawCircle(
      Offset(w * 0.54, h * 0.24),
      1.6,
      Paint()..color = const Color(0xFF222222),
    );

    // Arms. During a throw, one arm extends toward the chosen sidewalk.
    final armPaint = Paint()
      ..color = const Color(0xFFFFCC99)
      ..strokeWidth = 5
      ..strokeCap = StrokeCap.round;
    final sleevePaint = Paint()
      ..color = const Color(0xFF1565C0)
      ..strokeWidth = 7
      ..strokeCap = StrokeCap.round;
    final shoulderL = Offset(w * 0.42, h * 0.36);
    final shoulderR = Offset(w * 0.58, h * 0.36);
    final handL = Offset(
      w * (0.34 - (_throwLeft ? throwT * 0.18 : 0)),
      h * (0.48 - (_throwLeft ? throwT * 0.10 : 0)),
    );
    final handR = Offset(
      w * (0.66 + (!_throwLeft ? throwT * 0.18 : 0)),
      h * (0.48 - (!_throwLeft ? throwT * 0.10 : 0)),
    );
    canvas.drawLine(shoulderL, handL, sleevePaint);
    canvas.drawLine(shoulderR, handR, sleevePaint);
    canvas.drawLine(shoulderL, handL, armPaint);
    canvas.drawLine(shoulderR, handR, armPaint);

    // Legs down to pedals.
    final legPaint = Paint()
      ..color = const Color(0xFF263238)
      ..strokeWidth = 5
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(
      Offset(w * 0.45, h * 0.55),
      Offset(crank.dx - 11, crank.dy - pedalLift * 8),
      legPaint,
    );
    canvas.drawLine(
      Offset(w * 0.55, h * 0.55),
      Offset(crank.dx + 11, crank.dy + pedalLift * 8),
      legPaint,
    );

    // Handlebar.
    canvas.drawLine(
      Offset(w * 0.58, h * 0.44),
      Offset(w * 0.70, h * 0.42),
      Paint()
        ..color = const Color(0xFF263238)
        ..strokeWidth = 3.5
        ..strokeCap = StrokeCap.round,
    );
  }

  void _drawWheel(Canvas canvas, Offset c, double r, double angle) {
    canvas.drawCircle(c, r, Paint()..color = const Color(0xFF111111));
    canvas.drawCircle(c, r * 0.76, Paint()..color = const Color(0xFF616161));
    canvas.drawCircle(c, r * 0.58, Paint()..color = const Color(0xFFBDBDBD));
    canvas.drawCircle(c, r * 0.18, Paint()..color = const Color(0xFF212121));
    canvas.save();
    canvas.translate(c.dx, c.dy);
    canvas.rotate(angle);
    final spoke = Paint()
      ..color = const Color(0xFFEEEEEE)
      ..strokeWidth = 1.1
      ..strokeCap = StrokeCap.round;
    for (int i = 0; i < 10; i++) {
      final a = i * 2 * pi / 10;
      canvas.drawLine(
        Offset.zero,
        Offset(cos(a) * r * 0.70, sin(a) * r * 0.70),
        spoke,
      );
    }
    canvas.restore();
  }
}
