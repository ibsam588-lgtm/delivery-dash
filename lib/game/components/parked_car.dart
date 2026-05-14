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
    Color(0xFFCC2424), // deep red
    Color(0xFF1A237E), // navy blue
    Color(0xFF757575), // silver grey
    Color(0xFF1A1A1A), // black
    Color(0xFFF5F5F5), // white
    Color(0xFF2E7D32), // forest green
  ];

  final int variant;
  bool _hit = false;
  double _bounce = 0;

  ParkedCarComponent({this.variant = 0})
      : super(
          size: Vector2(56, 90),
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
    final dx = depthXShift(
      position.x, position.y, gameRef.laneManager.roadCenter, h,
    );
    canvas.translate(dx, 0);

    // Ground shadow.
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(size.x / 2 + 4, size.y - 4),
        width: (size.x + 6) * s,
        height: 12 * s,
      ),
      Paint()..color = const Color(0x66000000),
    );

    final bounceS = _bounce > 0 ? 1 + (_bounce / 0.2) * 0.08 : 1.0;
    canvas.save();
    canvas.translate(size.x / 2, size.y / 2);
    canvas.scale(s * bounceS, s * bounceS * 0.85);
    canvas.translate(-size.x / 2, -size.y / 2);

    renderTopDownCar(canvas, size.x, size.y, _bodyColors[variant % _bodyColors.length]);

    canvas.restore();

    if (_hit) {
      canvas.drawRect(
        Rect.fromLTWH(0, 0, size.x, size.y),
        Paint()
          ..color = const Color(0xCCFFD600)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2,
      );
    }
  }
}

void renderTopDownCar(Canvas canvas, double w, double h, Color bodyColor) {
  // Derive lighter roof and darker hood/trunk shades from body color.
  final roofColor = Color.fromARGB(
    255,
    ((bodyColor.r * 255 + 28).clamp(0.0, 255.0)).round(),
    ((bodyColor.g * 255 + 28).clamp(0.0, 255.0)).round(),
    ((bodyColor.b * 255 + 28).clamp(0.0, 255.0)).round(),
  );
  final darkColor = Color.fromARGB(
    255,
    ((bodyColor.r * 255 * 0.80).clamp(0.0, 255.0)).round(),
    ((bodyColor.g * 255 * 0.80).clamp(0.0, 255.0)).round(),
    ((bodyColor.b * 255 * 0.80).clamp(0.0, 255.0)).round(),
  );

  // Under-car shadow.
  canvas.drawOval(
    Rect.fromCenter(
      center: Offset(w / 2, h / 2),
      width: w * 0.86,
      height: h * 0.96,
    ),
    Paint()..color = const Color(0x44000000),
  );

  // Main body (rounded rect, wider in the middle).
  final bodyRRect = RRect.fromRectAndRadius(
    Rect.fromLTWH(w * 0.09, h * 0.04, w * 0.82, h * 0.92),
    Radius.circular(w * 0.15),
  );
  canvas.drawRRect(bodyRRect, Paint()..color = bodyColor);

  // Hood (front darker trapezoid).
  final hoodPath = Path()
    ..moveTo(w * 0.18, h * 0.04)
    ..lineTo(w * 0.82, h * 0.04)
    ..lineTo(w * 0.76, h * 0.22)
    ..lineTo(w * 0.24, h * 0.22)
    ..close();
  canvas.drawPath(hoodPath, Paint()..color = darkColor);

  // Trunk (rear darker trapezoid).
  final trunkPath = Path()
    ..moveTo(w * 0.26, h * 0.78)
    ..lineTo(w * 0.74, h * 0.78)
    ..lineTo(w * 0.80, h * 0.96)
    ..lineTo(w * 0.20, h * 0.96)
    ..close();
  canvas.drawPath(trunkPath, Paint()..color = darkColor);

  // Wheels (4 corners) — thick black ring + alloy disc + 5 spokes + hub.
  const double wheelR = 6.0;
  const double alloyR = wheelR * 0.75;
  const double hubR = wheelR * 0.20;
  const int spokes = 5;
  const wheelColor = Color(0xFF111111);
  const alloyColor = Color(0xFF9E9E9E);
  const hubColor = Color(0xFFE0E0E0);
  const spokeColor = Color(0xFF757575);

  for (final wc in [
    Offset(w * 0.155, h * 0.115),
    Offset(w * 0.845, h * 0.115),
    Offset(w * 0.155, h * 0.885),
    Offset(w * 0.845, h * 0.885),
  ]) {
    canvas.drawCircle(wc, wheelR, Paint()..color = wheelColor);
    canvas.drawCircle(wc, alloyR, Paint()..color = alloyColor);
    // 5 spokes.
    final spokePaint = Paint()
      ..color = spokeColor
      ..strokeWidth = 1.2
      ..strokeCap = StrokeCap.round;
    for (int s = 0; s < spokes; s++) {
      final ang = s * 2 * 3.14159265 / spokes;
      canvas.drawLine(
        wc,
        Offset(wc.dx + alloyR * 0.9 * _cos(ang),
            wc.dy + alloyR * 0.9 * _sin(ang)),
        spokePaint,
      );
    }
    canvas.drawCircle(wc, hubR, Paint()..color = hubColor);
  }

  // Windshield (front glass, ice-blue tinted).
  final windshieldRect =
      Rect.fromLTWH(w * 0.16, h * 0.085, w * 0.68, h * 0.155);
  canvas.drawRRect(
    RRect.fromRectAndRadius(windshieldRect, Radius.circular(w * 0.04)),
    Paint()
      ..shader = Gradient.linear(
        windshieldRect.topLeft,
        windshieldRect.bottomRight,
        [const Color(0xFFB8DDEF), const Color(0xFF80B8D0)],
      ),
  );

  // Side windows (two small rects along sides of roof area).
  canvas.drawRRect(
    RRect.fromRectAndRadius(
      Rect.fromLTWH(w * 0.09, h * 0.30, w * 0.10, h * 0.22),
      Radius.circular(w * 0.03),
    ),
    Paint()..color = const Color(0xFF80B8D0),
  );
  canvas.drawRRect(
    RRect.fromRectAndRadius(
      Rect.fromLTWH(w * 0.81, h * 0.30, w * 0.10, h * 0.22),
      Radius.circular(w * 0.03),
    ),
    Paint()..color = const Color(0xFF80B8D0),
  );

  // Rear window (slightly narrower).
  final rearWinRect =
      Rect.fromLTWH(w * 0.18, h * 0.745, w * 0.64, h * 0.13);
  canvas.drawRRect(
    RRect.fromRectAndRadius(rearWinRect, Radius.circular(w * 0.04)),
    Paint()..color = const Color(0xFF80B8D0),
  );

  // Roof (inner lighter raised shape).
  final roofRect = Rect.fromLTWH(w * 0.20, h * 0.28, w * 0.60, h * 0.44);
  canvas.drawRRect(
    RRect.fromRectAndRadius(roofRect, Radius.circular(w * 0.07)),
    Paint()..color = roofColor,
  );
  // Roof glare streak.
  canvas.drawLine(
    Offset(w * 0.26, h * 0.30),
    Offset(w * 0.38, h * 0.44),
    Paint()
      ..color = const Color(0x66FFFFFF)
      ..strokeWidth = 2.5
      ..strokeCap = StrokeCap.round,
  );

  // Side mirrors (tiny rounded rects near windshield).
  final mirrorPaint = Paint()..color = darkColor;
  canvas.drawRRect(
    RRect.fromRectAndRadius(
      Rect.fromLTWH(w * 0.03, h * 0.20, w * 0.07, h * 0.05),
      const Radius.circular(2),
    ),
    mirrorPaint,
  );
  canvas.drawRRect(
    RRect.fromRectAndRadius(
      Rect.fromLTWH(w * 0.90, h * 0.20, w * 0.07, h * 0.05),
      const Radius.circular(2),
    ),
    mirrorPaint,
  );

  // Headlights (front) — bright rect with inner glow circle.
  for (final hx in [w * 0.13, w * 0.68]) {
    final hlRect = Rect.fromLTWH(hx, h * 0.047, w * 0.19, h * 0.055);
    canvas.drawRRect(
      RRect.fromRectAndRadius(hlRect, const Radius.circular(2)),
      Paint()..color = const Color(0xFFFFF9C4),
    );
    canvas.drawCircle(
      Offset(hx + w * 0.095, h * 0.074),
      w * 0.05,
      Paint()
        ..color = const Color(0xAAFFFFFF)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3),
    );
  }

  // Taillights (rear) — red rect with brighter inner dot.
  for (final tx in [w * 0.13, w * 0.68]) {
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(tx, h * 0.898, w * 0.19, h * 0.055),
        const Radius.circular(2),
      ),
      Paint()..color = const Color(0xFFCC1111),
    );
    canvas.drawCircle(
      Offset(tx + w * 0.095, h * 0.925),
      w * 0.04,
      Paint()..color = const Color(0xFFFF4444),
    );
  }

  // Body outline.
  canvas.drawRRect(
    bodyRRect,
    Paint()
      ..color = const Color(0x55000000)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0,
  );
}

double _cos(double a) => cos(a);
double _sin(double a) => sin(a);
