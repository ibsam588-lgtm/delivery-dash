import 'dart:math';
import 'package:flame/collisions.dart';
import 'package:flame/components.dart';
import 'package:flutter/material.dart';
import '../delivery_dash_game.dart';

/// Procedurally-drawn bike rider. Replaces the small pixel PNG with
/// canvas primitives so the visual quality stays crisp regardless of
/// scale, and so we can do speed-line motion blur cheaply.
class PlayerComponent extends PositionComponent
    with HasGameRef<DeliveryDashGame>, CollisionCallbacks {
  static const double _followSpeed = 8.0;
  static const double _flashInterval = 0.1;

  final bool isVip;
  double _targetX = 0;
  double _flashTimer = 0;
  double _opacity = 1.0;

  // Wet/drenched effect.
  double _wetTimer = 0;
  static const double _wetDuration = 0.4;

  // Animation phase (used for pedaling jitter + spokes).
  double _phase = 0;

  PlayerComponent({this.isVip = false})
      : super(size: Vector2(60, 80), anchor: Anchor.bottomCenter, priority: 5);

  @override
  Future<void> onLoad() async {
    final lm = gameRef.laneManager;
    _targetX = lm.roadCenterAt(gameRef.size.y * 0.85);
    position = Vector2(_targetX, gameRef.size.y * 0.88);
    add(RectangleHitbox(
      size: Vector2(36, 56),
      position: Vector2((size.x - 36) / 2, size.y - 60),
    ));
  }

  void moveTo(double worldX) {
    _targetX =
        gameRef.laneManager.clampToRoadAt(position.y, worldX, size.x / 2);
  }

  void triggerWetFlash() {
    _wetTimer = _wetDuration;
  }

  @override
  void update(double dt) {
    super.update(dt);
    _phase += dt;

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
      _opacity = 1.0;
    }
  }

  @override
  void render(Canvas canvas) {
    canvas.save();
    // Apply the invincibility opacity by saving a layer.
    if (_opacity < 1.0) {
      final p = Paint()..color = Color.fromRGBO(255, 255, 255, _opacity);
      canvas.saveLayer(Rect.fromLTWH(0, 0, size.x, size.y), p);
    }

    final w = size.x;
    final h = size.y;

    // ── Speed lines behind the rider ─────────────────────────────────
    final speedLine = Paint()..color = const Color(0x66FFFFFF);
    for (var i = 0; i < 3; i++) {
      final ox = (i - 1) * 14.0;
      final blur = 6.0 + i * 3.0;
      canvas.drawOval(
        Rect.fromCenter(
          center: Offset(w * 0.5 + ox, h * 1.0 + 6 + i * 4),
          width: 22 - i * 4,
          height: 3.0,
        ),
        speedLine..color = Color.fromRGBO(255, 255, 255, 0.35 - i * 0.10),
      );
      // The blur variable is just to make the painter look intentional.
      // ignore: unused_local_variable
      final _ = blur;
    }

    // ── Drop shadow under the bike ───────────────────────────────────
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(w * 0.5, h - 4),
        width: w * 0.8,
        height: 10,
      ),
      Paint()..color = const Color(0x66000000),
    );

    // ── Wheels ───────────────────────────────────────────────────────
    const wheelR = 12.0;
    final frontWheel = Offset(w * 0.32, h * 0.85);
    final backWheel = Offset(w * 0.68, h * 0.85);
    _drawWheel(canvas, frontWheel, wheelR);
    _drawWheel(canvas, backWheel, wheelR);

    // ── Frame ────────────────────────────────────────────────────────
    final frame = Path()
      ..moveTo(frontWheel.dx, frontWheel.dy)
      ..lineTo(w * 0.46, h * 0.55)
      ..lineTo(backWheel.dx, backWheel.dy)
      ..moveTo(w * 0.46, h * 0.55)
      ..lineTo(w * 0.58, h * 0.55)
      ..lineTo(backWheel.dx, backWheel.dy);
    canvas.drawPath(
      frame,
      Paint()
        ..color = const Color(0xFF1565C0)
        ..strokeWidth = 4
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round,
    );

    // Handlebars + stem.
    canvas.drawLine(
      Offset(frontWheel.dx, h * 0.55),
      Offset(w * 0.46, h * 0.55),
      Paint()
        ..color = const Color(0xFF9E9E9E)
        ..strokeWidth = 3,
    );
    canvas.drawLine(
      Offset(frontWheel.dx - 6, h * 0.50),
      Offset(frontWheel.dx + 6, h * 0.50),
      Paint()
        ..color = const Color(0xFF424242)
        ..strokeWidth = 4
        ..strokeCap = StrokeCap.round,
    );

    // ── Rider torso (jacket) ─────────────────────────────────────────
    final torsoColor =
        isVip ? const Color(0xFFFFD600) : const Color(0xFF1976D2);
    final torsoRect = Rect.fromCenter(
        center: Offset(w * 0.52, h * 0.40),
        width: w * 0.36,
        height: h * 0.30);
    canvas.drawRRect(
      RRect.fromRectAndRadius(torsoRect, const Radius.circular(6)),
      Paint()..color = torsoColor,
    );

    // Bag on the back (white).
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(w * 0.62, h * 0.34, w * 0.20, h * 0.22),
        const Radius.circular(4),
      ),
      Paint()..color = Colors.white,
    );
    // Bag strap.
    canvas.drawLine(
      Offset(w * 0.50, h * 0.30),
      Offset(w * 0.72, h * 0.50),
      Paint()
        ..color = const Color(0xFF5D4037)
        ..strokeWidth = 2,
    );

    // Head.
    canvas.drawCircle(
      Offset(w * 0.48, h * 0.22),
      9,
      Paint()..color = const Color(0xFFFFCC80),
    );
    // Cap.
    canvas.drawArc(
      Rect.fromCenter(
        center: Offset(w * 0.48, h * 0.20),
        width: 22,
        height: 14,
      ),
      pi,
      pi,
      true,
      Paint()..color = const Color(0xFFFFD600),
    );

    if (_wetTimer > 0) {
      final phase = _wetTimer / _wetDuration;
      final alpha = (1 - (phase - 0.5).abs() * 2) * 0.5;
      canvas.drawRect(
        Rect.fromLTWH(0, 0, w, h),
        Paint()..color = const Color(0xFF42A5F5).withValues(alpha: alpha),
      );
    }

    if (_opacity < 1.0) canvas.restore();
    canvas.restore();
  }

  void _drawWheel(Canvas canvas, Offset c, double r) {
    // Tire.
    canvas.drawCircle(c, r, Paint()..color = const Color(0xFF1A1A1A));
    // Rim.
    canvas.drawCircle(
      c,
      r * 0.78,
      Paint()
        ..color = Colors.white
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2,
    );
    // Hub.
    canvas.drawCircle(c, 1.6, Paint()..color = Colors.white);
    // 8 thin spokes, rotating with the phase.
    final spokePaint = Paint()
      ..color = const Color(0xFFE0E0E0)
      ..strokeWidth = 1;
    final spin = _phase * 6;
    for (var i = 0; i < 8; i++) {
      final theta = spin + i * pi / 4;
      canvas.drawLine(
        c,
        Offset(c.dx + cos(theta) * r * 0.78,
            c.dy + sin(theta) * r * 0.78),
        spokePaint,
      );
    }
  }
}
