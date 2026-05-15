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
    Color(0xFF1976D2), // bright blue
    Color(0xFF9E9E9E), // silver
    Color(0xFF212121), // black
    Color(0xFFFAFAFA), // white
    Color(0xFF388E3C), // green
  ];

  final int variant;
  bool _hit = false;
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
  }

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
        canvas, size.x, size.y, _bodyColors[variant % _bodyColors.length]);

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
void renderTopDownCar(Canvas canvas, double w, double h, Color bodyColor) {
  final roofColor = Color.fromARGB(
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
      width: w * 0.92,
      height: h * 0.98,
    ),
    Paint()..color = const Color(0x55000000),
  );

  // ── Main body — rounded rectangle ────────────────────────────────────────
  final bodyRect = Rect.fromLTWH(w * 0.08, h * 0.04, w * 0.84, h * 0.92);
  final bodyRRect =
      RRect.fromRectAndRadius(bodyRect, Radius.circular(w * 0.16));
  canvas.drawRRect(bodyRRect, Paint()..color = bodyColor);

  // Body gradient highlight (subtle lighter band down centre).
  canvas.drawRRect(
    bodyRRect,
    Paint()
      ..shader = Gradient.linear(
        bodyRect.topCenter,
        bodyRect.bottomCenter,
        [
          const Color(0x00FFFFFF),
          const Color(0x33FFFFFF),
          const Color(0x00FFFFFF),
        ],
        [0.0, 0.5, 1.0],
      ),
  );

  // ── Hood (front darker trapezoid) ─────────────────────────────────────────
  final hoodPath = Path()
    ..moveTo(w * 0.20, h * 0.05)
    ..lineTo(w * 0.80, h * 0.05)
    ..lineTo(w * 0.74, h * 0.22)
    ..lineTo(w * 0.26, h * 0.22)
    ..close();
  canvas.drawPath(hoodPath, Paint()..color = darkColor);
  // Hood lines.
  final hoodLinePaint = Paint()
    ..color = bodyColor
    ..strokeWidth = 0.9;
  canvas.drawLine(
      Offset(w * 0.42, h * 0.07), Offset(w * 0.40, h * 0.21), hoodLinePaint);
  canvas.drawLine(
      Offset(w * 0.58, h * 0.07), Offset(w * 0.60, h * 0.21), hoodLinePaint);

  // ── Trunk (rear darker trapezoid) ─────────────────────────────────────────
  final trunkPath = Path()
    ..moveTo(w * 0.26, h * 0.78)
    ..lineTo(w * 0.74, h * 0.78)
    ..lineTo(w * 0.80, h * 0.95)
    ..lineTo(w * 0.20, h * 0.95)
    ..close();
  canvas.drawPath(trunkPath, Paint()..color = darkColor);

  // ── Windshield (front, big trapezoid) ─────────────────────────────────────
  final windshieldPath = Path()
    ..moveTo(w * 0.20, h * 0.24)
    ..lineTo(w * 0.80, h * 0.24)
    ..lineTo(w * 0.74, h * 0.40)
    ..lineTo(w * 0.26, h * 0.40)
    ..close();
  canvas.drawPath(
    windshieldPath,
    Paint()
      ..shader = Gradient.linear(
        Offset(w * 0.20, h * 0.24),
        Offset(w * 0.80, h * 0.40),
        [const Color(0x99AACCEE), const Color(0xCC7E9EC0)],
      ),
  );
  // Wiper arcs.
  final wiperPaint = Paint()
    ..color = const Color(0xAA1A1A1A)
    ..strokeWidth = 1.0
    ..style = PaintingStyle.stroke;
  canvas.drawArc(
    Rect.fromCenter(
      center: Offset(w * 0.36, h * 0.40),
      width: w * 0.18,
      height: h * 0.10,
    ),
    pi * 1.05,
    pi * 0.9,
    false,
    wiperPaint,
  );
  canvas.drawArc(
    Rect.fromCenter(
      center: Offset(w * 0.64, h * 0.40),
      width: w * 0.18,
      height: h * 0.10,
    ),
    pi * 1.05,
    pi * 0.9,
    false,
    wiperPaint,
  );

  // ── Rear window ───────────────────────────────────────────────────────────
  final rearWinPath = Path()
    ..moveTo(w * 0.26, h * 0.62)
    ..lineTo(w * 0.74, h * 0.62)
    ..lineTo(w * 0.78, h * 0.78)
    ..lineTo(w * 0.22, h * 0.78)
    ..close();
  canvas.drawPath(
    rearWinPath,
    Paint()..color = const Color(0xCC7E9EC0),
  );

  // ── Side windows (small rects on left/right edges) ────────────────────────
  for (final wx in [w * 0.07, w * 0.83]) {
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(wx, h * 0.42, w * 0.10, h * 0.18),
        Radius.circular(w * 0.025),
      ),
      Paint()..color = const Color(0xCC7E9EC0),
    );
  }

  // ── Roof (raised lighter rectangle between windshield and rear) ───────────
  final roofRect = Rect.fromLTWH(w * 0.20, h * 0.40, w * 0.60, h * 0.22);
  canvas.drawRRect(
    RRect.fromRectAndRadius(roofRect, Radius.circular(w * 0.06)),
    Paint()..color = roofColor,
  );
  // Roof glare streak.
  canvas.drawLine(
    Offset(w * 0.26, h * 0.43),
    Offset(w * 0.38, h * 0.58),
    Paint()
      ..color = const Color(0x77FFFFFF)
      ..strokeWidth = 2.5
      ..strokeCap = StrokeCap.round,
  );

  // ── Wheels (4 corners) — oval with arch shadow ────────────────────────────
  final wheelOvalW = w * 0.22;
  final wheelOvalH = h * 0.11;
  const tireColor = Color(0xFF222222);
  const spokeColor = Color(0xFF888888);
  const hubColor = Color(0xFFE0E0E0);
  for (final wc in [
    Offset(w * 0.02, h * 0.18),
    Offset(w * 0.98, h * 0.18),
    Offset(w * 0.02, h * 0.82),
    Offset(w * 0.98, h * 0.82),
  ]) {
    // Wheel arch shadow above each wheel.
    canvas.drawArc(
      Rect.fromCenter(
        center: wc,
        width: wheelOvalW * 1.5,
        height: wheelOvalH * 2.5,
      ),
      pi,
      pi,
      false,
      Paint()..color = const Color(0x55000000),
    );
    // Tyre.
    canvas.drawOval(
      Rect.fromCenter(center: wc, width: wheelOvalW, height: wheelOvalH),
      Paint()..color = tireColor,
    );
    // Wheel spokes (3-spoke pattern).
    final spokePaint = Paint()
      ..color = spokeColor
      ..strokeWidth = 1.3
      ..strokeCap = StrokeCap.round;
    for (int i = 0; i < 3; i++) {
      final ang = i * 2 * pi / 3;
      canvas.drawLine(
        wc,
        Offset(
          wc.dx + cos(ang) * wheelOvalW * 0.40,
          wc.dy + sin(ang) * wheelOvalH * 0.40,
        ),
        spokePaint,
      );
    }
    // Hub.
    canvas.drawCircle(wc, 1.6, Paint()..color = hubColor);
  }

  // ── Headlights (front, bright yellow ovals) ───────────────────────────────
  for (final hx in [w * 0.16, w * 0.84]) {
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(hx, h * 0.06),
        width: w * 0.14,
        height: h * 0.04,
      ),
      Paint()..color = const Color(0xFFFFEE58),
    );
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(hx, h * 0.06),
        width: w * 0.10,
        height: h * 0.03,
      ),
      Paint()..color = const Color(0xCCFFFFFF),
    );
  }

  // ── Taillights (rear, bright red ovals) ───────────────────────────────────
  for (final tx in [w * 0.16, w * 0.84]) {
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(tx, h * 0.93),
        width: w * 0.14,
        height: h * 0.04,
      ),
      Paint()..color = const Color(0xFFF44336),
    );
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(tx, h * 0.93),
        width: w * 0.08,
        height: h * 0.025,
      ),
      Paint()..color = const Color(0xCCFFB0B0),
    );
  }

  // ── Side mirrors (sticking out at front corners) ──────────────────────────
  final mirrorPaint = Paint()..color = darkColor;
  canvas.drawRRect(
    RRect.fromRectAndRadius(
      Rect.fromLTWH(w * 0.02, h * 0.30, w * 0.08, h * 0.05),
      const Radius.circular(2),
    ),
    mirrorPaint,
  );
  canvas.drawRRect(
    RRect.fromRectAndRadius(
      Rect.fromLTWH(w * 0.90, h * 0.30, w * 0.08, h * 0.05),
      const Radius.circular(2),
    ),
    mirrorPaint,
  );

  // ── Body outline ──────────────────────────────────────────────────────────
  canvas.drawRRect(
    bodyRRect,
    Paint()
      ..color = const Color(0x77000000)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2,
  );
}
