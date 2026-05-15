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

/// Top-down isometric car. Rich, chunky, readable from any angle.
/// When [isOncoming] is true, the sprite is flipped 180° so the headlights
/// face the bottom of the screen (toward the player).
/// When [windshieldBroken] is true, draws a shattered windshield overlay
/// (used by parked cars after a paper hits them).
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
    ((bodyColor.r * 255 + 30).clamp(0.0, 255.0)).round(),
    ((bodyColor.g * 255 + 30).clamp(0.0, 255.0)).round(),
    ((bodyColor.b * 255 + 30).clamp(0.0, 255.0)).round(),
  );
  final darkColor = Color.fromARGB(
    255,
    ((bodyColor.r * 255 * 0.78).clamp(0.0, 255.0)).round(),
    ((bodyColor.g * 255 * 0.78).clamp(0.0, 255.0)).round(),
    ((bodyColor.b * 255 * 0.78).clamp(0.0, 255.0)).round(),
  );

  // ── Under-car shadow ─────────────────────────────────────────────────────
  canvas.drawOval(
    Rect.fromCenter(
      center: Offset(w / 2, h / 2 + 2),
      width: w * 0.94,
      height: h * 0.98,
    ),
    Paint()..color = const Color(0x55000000),
  );

  // ── Tapered body — rear full width, front 90% width (subtle taper) ───────
  final bodyPath = Path()
    ..moveTo(w * 0.10, h * 0.10)   // front-left
    ..lineTo(w * 0.90, h * 0.10)   // front-right
    ..lineTo(w * 0.95, h * 0.50)   // right midline
    ..lineTo(w * 0.92, h * 0.92)   // rear-right
    ..lineTo(w * 0.08, h * 0.92)   // rear-left
    ..lineTo(w * 0.05, h * 0.50)   // left midline
    ..close();

  // Fill with linear gradient: lighter at centre, darker at edges.
  canvas.drawPath(
    bodyPath,
    Paint()
      ..shader = Gradient.linear(
        Offset(w * 0.05, h * 0.5),
        Offset(w * 0.95, h * 0.5),
        [darkColor, lightColor, darkColor],
        [0.0, 0.5, 1.0],
      ),
  );

  // ── Hood panel (front) — two raised lines angled toward center ───────────
  final hoodLinePaint = Paint()
    ..color = lightColor
    ..strokeWidth = 1.0;
  canvas.drawLine(
      Offset(w * 0.30, h * 0.14), Offset(w * 0.40, h * 0.26), hoodLinePaint);
  canvas.drawLine(
      Offset(w * 0.70, h * 0.14), Offset(w * 0.60, h * 0.26), hoodLinePaint);

  // ── Grille (front center) ────────────────────────────────────────────────
  canvas.drawRect(
    Rect.fromLTWH(w * 0.40, h * 0.08, w * 0.20, h * 0.05),
    Paint()..color = const Color(0xFF1A1A1A),
  );
  final grillePaint = Paint()
    ..color = const Color(0xFF444444)
    ..strokeWidth = 0.8;
  for (int i = 1; i < 4; i++) {
    final gy = h * 0.08 + h * 0.05 * (i / 4);
    canvas.drawLine(
        Offset(w * 0.41, gy), Offset(w * 0.59, gy), grillePaint);
  }

  // ── Windshield (front trapezoid, 70% width, 18% height) ──────────────────
  final windshieldPath = Path()
    ..moveTo(w * 0.20, h * 0.20)
    ..lineTo(w * 0.80, h * 0.20)
    ..lineTo(w * 0.74, h * 0.38)
    ..lineTo(w * 0.26, h * 0.38)
    ..close();
  canvas.drawPath(
    windshieldPath,
    Paint()..color = const Color(0xCC90CAF9),
  );
  // Smashed windshield overlay — dark interior + radial cracks.
  if (windshieldBroken) {
    canvas.save();
    canvas.clipPath(windshieldPath);
    canvas.drawPath(
      windshieldPath,
      Paint()..color = const Color(0xCC1A1A1A),
    );
    final cx = w * 0.50;
    final cy = h * 0.29;
    final crackPaint = Paint()
      ..color = const Color(0xFFE0E0E0)
      ..strokeWidth = 0.9
      ..strokeCap = StrokeCap.round;
    for (int i = 0; i < 8; i++) {
      final ang = i * pi / 4;
      canvas.drawLine(
        Offset(cx, cy),
        Offset(cx + cos(ang) * w * 0.34, cy + sin(ang) * h * 0.12),
        crackPaint,
      );
    }
    canvas.restore();
  }
  // Glare streak.
  canvas.drawLine(
    Offset(w * 0.30, h * 0.23),
    Offset(w * 0.46, h * 0.36),
    Paint()
      ..color = const Color(0x99FFFFFF)
      ..strokeWidth = 2.0
      ..strokeCap = StrokeCap.round,
  );

  // ── Roof (raised rectangle, 50% width, 40% height, lighter) ───────────────
  final roofRect = Rect.fromLTWH(w * 0.25, h * 0.38, w * 0.50, h * 0.24);
  canvas.drawRRect(
    RRect.fromRectAndRadius(roofRect, Radius.circular(w * 0.04)),
    Paint()..color = lightColor,
  );
  // Highlight along top edge of roof.
  canvas.drawLine(
    Offset(w * 0.27, h * 0.39),
    Offset(w * 0.73, h * 0.39),
    Paint()
      ..color = const Color(0x99FFFFFF)
      ..strokeWidth = 1.2,
  );

  // ── Rear window (trapezoid, 65% width, 12% height) ───────────────────────
  final rearWinPath = Path()
    ..moveTo(w * 0.28, h * 0.62)
    ..lineTo(w * 0.72, h * 0.62)
    ..lineTo(w * 0.78, h * 0.74)
    ..lineTo(w * 0.22, h * 0.74)
    ..close();
  canvas.drawPath(
    rearWinPath,
    Paint()..color = const Color(0xBB6B8FB0),
  );

  // ── Side windows (mid-height of body) ────────────────────────────────────
  canvas.drawRect(
    Rect.fromLTWH(w * 0.10, h * 0.42, w * 0.08, h * 0.18),
    Paint()..color = const Color(0xCC90CAF9),
  );
  canvas.drawRect(
    Rect.fromLTWH(w * 0.82, h * 0.42, w * 0.08, h * 0.18),
    Paint()..color = const Color(0xCC90CAF9),
  );

  // ── Wheels — 4 isometric ovals ───────────────────────────────────────────
  for (final wc in [
    Offset(w * 0.10, h * 0.14),
    Offset(w * 0.90, h * 0.14),
    Offset(w * 0.10, h * 0.86),
    Offset(w * 0.90, h * 0.86),
  ]) {
    // Wheel arch shadow.
    canvas.drawOval(
      Rect.fromCenter(center: wc, width: w * 0.22, height: h * 0.10),
      Paint()..color = const Color(0x66000000),
    );
    // Tyre.
    canvas.drawOval(
      Rect.fromCenter(center: wc, width: w * 0.20, height: h * 0.09),
      Paint()..color = const Color(0xFF202020),
    );
    // Rim.
    canvas.drawOval(
      Rect.fromCenter(center: wc, width: w * 0.13, height: h * 0.06),
      Paint()..color = const Color(0xFFC0C0C0),
    );
    // 5 rim spokes.
    final spokePaint = Paint()
      ..color = const Color(0xFFA0A0A0)
      ..strokeWidth = 0.9;
    for (int i = 0; i < 5; i++) {
      final ang = i * 2 * pi / 5;
      canvas.drawLine(
        wc,
        Offset(
          wc.dx + cos(ang) * w * 0.06,
          wc.dy + sin(ang) * h * 0.028,
        ),
        spokePaint,
      );
    }
  }

  // ── Headlights (front two corners) ───────────────────────────────────────
  for (final hx in [w * 0.20, w * 0.80]) {
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(hx, h * 0.10),
        width: w * 0.14,
        height: h * 0.04,
      ),
      Paint()..color = const Color(0xFFFFF9C4),
    );
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(hx, h * 0.10),
        width: w * 0.10,
        height: h * 0.028,
      ),
      Paint()..color = const Color(0xFFFFEB3B),
    );
  }

  // ── Taillights (rear two corners) ────────────────────────────────────────
  for (final tx in [w * 0.20, w * 0.80]) {
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(tx, h * 0.90),
        width: w * 0.14,
        height: h * 0.04,
      ),
      Paint()..color = const Color(0xFFEF5350),
    );
  }

  // ── Side mirrors (front quarter, oval) ───────────────────────────────────
  canvas.drawOval(
    Rect.fromCenter(
      center: Offset(w * 0.05, h * 0.28),
      width: w * 0.05,
      height: h * 0.03,
    ),
    Paint()..color = darkColor,
  );
  canvas.drawOval(
    Rect.fromCenter(
      center: Offset(w * 0.95, h * 0.28),
      width: w * 0.05,
      height: h * 0.03,
    ),
    Paint()..color = darkColor,
  );

  // ── Body outline ─────────────────────────────────────────────────────────
  canvas.drawPath(
    bodyPath,
    Paint()
      ..color = const Color(0x77000000)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2,
  );

  if (isOncoming) canvas.restore();
}
