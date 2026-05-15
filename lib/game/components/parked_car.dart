import 'dart:math';
import 'dart:ui';
import 'package:flame/collisions.dart';
import 'package:flame/components.dart';
import '../delivery_dash_game.dart';
import '../perspective.dart';

class ParkedCarComponent extends PositionComponent
    with HasGameRef<DeliveryDashGame>, CollisionCallbacks {
  static const int bonusPoints = 15;

  static const List<Color> _bodyColors = [
    Color(0xFFE53935), // bright red
    Color(0xFF1E88E5), // bright blue
    Color(0xFFFDD835), // bright yellow
    Color(0xFFF5F5F5), // white
    Color(0xFF43A047), // green
    Color(0xFFFF7043), // orange
  ];

  final int variant;
  bool _hit = false;
  bool _windowBroken = false;
  double _bounce = 0;

  ParkedCarComponent({this.variant = 0})
      : super(
          size: Vector2(68, 105),
          anchor: Anchor.center,
          priority: 2,
        );

  static int get colorCount => _bodyColors.length;

  @override
  Future<void> onLoad() async {
    final lm = gameRef.laneManager;
    final x = lm.roadRight + 4 + size.x / 2;
    position = Vector2(x, -size.y);
    add(RectangleHitbox(
      size: size * 0.85,
      position: size * 0.075,
      collisionType: CollisionType.passive,
    ));
  }

  void onPaperHit() {
    _hit = true;
    _bounce = 0.2;
    _windowBroken = true;
  }

  bool get windowBroken => _windowBroken;

  @override
  void update(double dt) {
    super.update(dt);
    if (gameRef.state == GameState.playing) {
      position.y += gameRef.scrollSpeed * dt;
    }
    if (_bounce > 0) {
      _bounce = (_bounce - dt).clamp(0.0, 0.2);
    }
    if (position.y > gameRef.size.y + size.y) removeFromParent();
  }

  @override
  void render(Canvas canvas) {
    final h = gameRef.size.y;
    final s = depthScale(position.y, h);
    final lm = gameRef.laneManager;
    final dx = depthXShiftDiag(
      worldX: position.x,
      leftRef: lm.roadLeft,
      widthRef: lm.roadWidth,
      leftY: lm.roadLeftAt(position.y),
      widthY: lm.roadWidthAt(position.y),
    );
    canvas.translate(dx, 0);

    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(size.x / 2 + 4, size.y - 4),
        width: (size.x + 6) * s,
        height: 14 * s,
      ),
      Paint()..color = const Color(0x66000000),
    );

    final bounceS = _bounce > 0 ? 1 + (_bounce / 0.2) * 0.08 : 1.0;
    canvas.save();
    canvas.translate(size.x / 2, size.y / 2);
    canvas.scale(s * bounceS, s * bounceS * 0.85);
    canvas.translate(-size.x / 2, -size.y / 2);

    renderTopDownCar(
      canvas,
      size.x,
      size.y,
      _bodyColors[variant % _bodyColors.length],
      windshieldBroken: _windowBroken,
    );

    canvas.restore();

    if (_hit) {
      canvas.drawRect(
        Rect.fromLTWH(0, 0, size.x, size.y),
        Paint()
          ..color = const Color(0xCCFFD600)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.5,
      );
    }
  }
}

/// 3/4 rear-view car for the straight-ahead camera. Cars are seen from
/// slightly above and behind — rear bumper / taillights at the bottom of
/// the sprite, roof + rear window above, partial front body visible.
/// When [isOncoming] is true, the sprite is flipped 180° so an oncoming
/// car shows its front headlights to the player.
void renderTopDownCar(
  Canvas canvas,
  double w,
  double h,
  Color bodyColor, {
  bool isOncoming = false,
  bool windshieldBroken = false,
}) {
  if (isOncoming) {
    canvas.save();
    canvas.translate(w / 2, h / 2);
    canvas.rotate(pi);
    canvas.translate(-w / 2, -h / 2);
  }
  final lightColor = Color.fromARGB(
    255,
    ((bodyColor.r * 255 + 32).clamp(0.0, 255.0)).round(),
    ((bodyColor.g * 255 + 32).clamp(0.0, 255.0)).round(),
    ((bodyColor.b * 255 + 32).clamp(0.0, 255.0)).round(),
  );
  final darkColor = Color.fromARGB(
    255,
    ((bodyColor.r * 255 * 0.74).clamp(0.0, 255.0)).round(),
    ((bodyColor.g * 255 * 0.74).clamp(0.0, 255.0)).round(),
    ((bodyColor.b * 255 * 0.74).clamp(0.0, 255.0)).round(),
  );

  // ── Ground shadow (oval slightly larger than the footprint) ─────────────
  canvas.drawOval(
    Rect.fromCenter(
      center: Offset(w / 2, h * 0.96),
      width: w * 1.04,
      height: h * 0.16,
    ),
    Paint()..color = const Color(0x66000000),
  );

  // ── Main body — tapered from rear (wide) to front (slightly narrower) ──
  // Bottom of sprite = closest to camera (rear bumper).
  final bodyPath = Path()
    ..moveTo(w * 0.12, h * 0.18)   // front-left (further away)
    ..lineTo(w * 0.88, h * 0.18)   // front-right
    ..lineTo(w * 0.94, h * 0.55)   // right midline
    ..lineTo(w * 0.96, h * 0.88)   // rear-right (closer)
    ..lineTo(w * 0.04, h * 0.88)   // rear-left
    ..lineTo(w * 0.06, h * 0.55)   // left midline
    ..close();
  canvas.drawPath(
    bodyPath,
    Paint()
      ..shader = Gradient.linear(
        Offset(0, h * 0.18),
        Offset(0, h * 0.88),
        [lightColor, darkColor],
      ),
  );

  // Subtle edge-lighter along the sides for a body roll.
  canvas.drawLine(
    Offset(w * 0.06, h * 0.55),
    Offset(w * 0.96, h * 0.55),
    Paint()
      ..color = lightColor.withValues(alpha: 0.55)
      ..strokeWidth = 1.2,
  );

  // ── Roof (narrower rounded rectangle inset on top 35%) ──────────────────
  final roofRect = Rect.fromLTWH(w * 0.20, h * 0.20, w * 0.60, h * 0.30);
  canvas.drawRRect(
    RRect.fromRectAndRadius(roofRect, Radius.circular(w * 0.06)),
    Paint()..color = lightColor,
  );
  // Diagonal highlight streak across the roof.
  canvas.drawLine(
    Offset(w * 0.24, h * 0.24),
    Offset(w * 0.50, h * 0.30),
    Paint()
      ..color = const Color(0x99FFFFFF)
      ..strokeWidth = 2.0
      ..strokeCap = StrokeCap.round,
  );

  // ── Rear windshield — trapezoid, wider at bottom (closest), narrower top
  final rearWinPath = Path()
    ..moveTo(w * 0.26, h * 0.30)
    ..lineTo(w * 0.74, h * 0.30)
    ..lineTo(w * 0.80, h * 0.50)
    ..lineTo(w * 0.20, h * 0.50)
    ..close();
  canvas.drawPath(
    rearWinPath,
    Paint()..color = const Color(0xCC90CAF9),
  );
  // Wiper arcs.
  final wiperPaint = Paint()
    ..color = const Color(0xFF333333)
    ..strokeWidth = 1.0
    ..style = PaintingStyle.stroke;
  canvas.drawArc(
    Rect.fromLTWH(w * 0.30, h * 0.40, w * 0.18, h * 0.16),
    pi * 1.1, pi * 0.8, false,
    wiperPaint,
  );
  canvas.drawArc(
    Rect.fromLTWH(w * 0.52, h * 0.40, w * 0.18, h * 0.16),
    pi * 1.1, pi * 0.8, false,
    wiperPaint,
  );
  if (windshieldBroken) {
    canvas.save();
    canvas.clipPath(rearWinPath);
    canvas.drawPath(
      rearWinPath,
      Paint()..color = const Color(0xCC1A1A1A),
    );
    final cx = w * 0.50;
    final cy = h * 0.40;
    final crackPaint = Paint()
      ..color = const Color(0xFFE0E0E0)
      ..strokeWidth = 0.9
      ..strokeCap = StrokeCap.round;
    for (int i = 0; i < 8; i++) {
      final ang = i * pi / 4;
      canvas.drawLine(
        Offset(cx, cy),
        Offset(cx + cos(ang) * w * 0.34, cy + sin(ang) * h * 0.14),
        crackPaint,
      );
    }
    canvas.restore();
  }

  // ── Trunk lid (between rear window and bumper) ─────────────────────────
  canvas.drawRect(
    Rect.fromLTWH(w * 0.08, h * 0.50, w * 0.84, h * 0.30),
    Paint()..color = darkColor,
  );
  // Trunk crease (subtle horizontal seam).
  canvas.drawLine(
    Offset(w * 0.10, h * 0.65),
    Offset(w * 0.90, h * 0.65),
    Paint()
      ..color = const Color(0x55000000)
      ..strokeWidth = 0.8,
  );

  // ── Rear bumper (dark grey horizontal bar at the very bottom) ──────────
  canvas.drawRect(
    Rect.fromLTWH(w * 0.04, h * 0.82, w * 0.92, h * 0.07),
    Paint()..color = const Color(0xFF2A2A2A),
  );
  // Licence plate (small white rect centred in bumper).
  canvas.drawRect(
    Rect.fromLTWH(w * 0.40, h * 0.83, w * 0.20, h * 0.045),
    Paint()..color = const Color(0xFFF5F5F5),
  );
  canvas.drawRect(
    Rect.fromLTWH(w * 0.40, h * 0.83, w * 0.20, h * 0.045),
    Paint()
      ..color = const Color(0xFF333333)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.6,
  );

  // ── Rear lights (bottom corners) ────────────────────────────────────────
  for (final tx in [w * 0.10, w * 0.90]) {
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(tx, h * 0.78),
        width: w * 0.16,
        height: h * 0.06,
      ),
      Paint()..color = const Color(0xFFFF1744),
    );
    // Inner glow.
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(tx, h * 0.78),
        width: w * 0.10,
        height: h * 0.035,
      ),
      Paint()..color = const Color(0xFFFFCDD2),
    );
  }

  // ── Wheels (perspective — rear visible, front partial) ─────────────────
  // Rear wheels: bigger ovals at the bottom (closer to camera).
  for (final wc in [
    Offset(w * 0.08, h * 0.83),
    Offset(w * 0.92, h * 0.83),
  ]) {
    // Tyre.
    canvas.drawOval(
      Rect.fromCenter(center: wc, width: w * 0.28, height: h * 0.14),
      Paint()..color = const Color(0xFF111111),
    );
    // Rim.
    canvas.drawOval(
      Rect.fromCenter(center: wc, width: w * 0.18, height: h * 0.08),
      Paint()..color = const Color(0xFFC0C0C0),
    );
    final spokePaint = Paint()
      ..color = const Color(0xFF888888)
      ..strokeWidth = 1.0;
    for (int i = 0; i < 5; i++) {
      final ang = i * 2 * pi / 5;
      canvas.drawLine(
        wc,
        Offset(
          wc.dx + cos(ang) * w * 0.08,
          wc.dy + sin(ang) * h * 0.038,
        ),
        spokePaint,
      );
    }
  }
  // Front wheels — smaller, partially hidden behind the body.
  for (final wc in [
    Offset(w * 0.10, h * 0.20),
    Offset(w * 0.90, h * 0.20),
  ]) {
    canvas.drawOval(
      Rect.fromCenter(center: wc, width: w * 0.22, height: h * 0.11),
      Paint()..color = const Color(0xFF1A1A1A),
    );
    canvas.drawOval(
      Rect.fromCenter(center: wc, width: w * 0.13, height: h * 0.06),
      Paint()..color = const Color(0xFFB0B0B0),
    );
  }

  // ── Body outline ───────────────────────────────────────────────────────
  canvas.drawPath(
    bodyPath,
    Paint()
      ..color = const Color(0x77000000)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2,
  );

  if (isOncoming) canvas.restore();
}
