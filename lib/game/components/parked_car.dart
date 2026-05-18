import 'dart:math';
import 'dart:ui';
import 'package:flame/collisions.dart';
import 'package:flame/components.dart';
import '../delivery_dash_game.dart';
import '../perspective.dart';

class ParkedCarComponent extends PositionComponent
    with HasGameRef<DeliveryDashGame>, CollisionCallbacks {
  static const int bonusPoints = 15;
  static const int variantCount = 6;

  final int variant;
  final bool onRightCurb;
  bool _hit = false;
  bool _windowBroken = false;
  double _bounce = 0;

  ParkedCarComponent({this.variant = 0, this.onRightCurb = true})
      : super(
          size: Vector2(72, 112),
          anchor: Anchor.center,
          priority: 15,
        );

  static int get colorCount => variantCount;

  @override
  Future<void> onLoad() async {
    final lm = gameRef.laneManager;
    final spawnY = -size.y * 0.75;
    final x = lm.roadXFromFraction(onRightCurb ? 0.90 : 0.10, spawnY);
    position = Vector2(x, spawnY);
    add(RectangleHitbox(
      size: size * 0.82,
      position: size * 0.09,
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
    final s = depthScale(position.y, h).clamp(0.42, 1.0);
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
        center: Offset(size.x / 2 + (onRightCurb ? 4 : -4), size.y - 4),
        width: (size.x + 12) * s,
        height: 16 * s,
      ),
      Paint()..color = const Color(0x77000000),
    );

    final bounceS = _bounce > 0 ? 1 + (_bounce / 0.2) * 0.08 : 1.0;
    canvas.save();
    canvas.translate(size.x / 2, size.y / 2);
    canvas.rotate(onRightCurb ? -0.03 : 0.03);
    canvas.scale(s * bounceS, s * bounceS * 0.88);
    canvas.translate(-size.x / 2, -size.y / 2);

    renderTopDownCar(canvas, size.x, size.y, variant);

    if (_windowBroken) {
      _renderGlassCracks(canvas, size.x, size.y);
    }

    canvas.restore();

    if (_hit) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(2, 2, size.x - 4, size.y - 4),
          const Radius.circular(12),
        ),
        Paint()
          ..color = const Color(0xCCFFD600)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.5,
      );
    }
  }
}

const List<Color> _carPaints = [
  Color(0xFFE53935),
  Color(0xFF0288D1),
  Color(0xFF00A86B),
  Color(0xFFFFC928),
  Color(0xFF263238),
  Color(0xFFF5F7FA),
];

void renderTopDownCar(
  Canvas canvas,
  double w,
  double h,
  int variant, {
  bool isOncoming = false,
  bool headlightsOn = false,
}) {
  if (isOncoming) {
    canvas.save();
    canvas.translate(0, h);
    canvas.scale(1, -1);
    _renderCarBody(canvas, w, h, variant, headlightsOn: headlightsOn);
    canvas.restore();
  } else {
    _renderCarBody(canvas, w, h, variant, headlightsOn: headlightsOn);
  }
}

void _renderCarBody(Canvas canvas, double w, double h, int variant,
    {bool headlightsOn = false}) {
  final base = _carPaints[variant % _carPaints.length];
  final dark = _darken(base, 0.50);
  final darker = _darken(base, 0.68);
  final light = _lighten(base, 0.36);
  final trim = Paint()..color = const Color(0xFF111111);

  canvas.drawOval(
    Rect.fromCenter(
      center: Offset(w * 0.50, h * 0.98),
      width: w * 0.78,
      height: h * 0.08,
    ),
    Paint()..color = const Color(0x66000000),
  );

  for (final x in [w * 0.075, w * 0.925]) {
    for (final y in [h * 0.27, h * 0.72]) {
      final tire = RRect.fromRectAndRadius(
        Rect.fromCenter(
          center: Offset(x, y),
          width: w * 0.20,
          height: h * 0.18,
        ),
        const Radius.circular(7),
      );
      canvas.drawRRect(tire, trim);
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromCenter(
            center: Offset(x, y),
            width: w * 0.082,
            height: h * 0.12,
          ),
          const Radius.circular(4),
        ),
        Paint()..color = const Color(0xFF303030),
      );
      canvas.drawCircle(
        Offset(x, y),
        w * 0.025,
        Paint()..color = const Color(0xFF8D8D8D),
      );
    }
  }

  for (final side in [-1.0, 1.0]) {
    final mirror = Path()
      ..moveTo(w * (0.50 + side * 0.36), h * 0.34)
      ..lineTo(w * (0.50 + side * 0.48), h * 0.30)
      ..lineTo(w * (0.50 + side * 0.47), h * 0.38)
      ..close();
    canvas.drawPath(mirror, Paint()..color = const Color(0xFF151515));
  }

  final bodyPath = Path()
    ..moveTo(w * 0.31, h * 0.02)
    ..lineTo(w * 0.69, h * 0.02)
    ..cubicTo(w * 0.82, h * 0.04, w * 0.91, h * 0.14, w * 0.90, h * 0.28)
    ..lineTo(w * 0.84, h * 0.78)
    ..cubicTo(w * 0.81, h * 0.94, w * 0.69, h * 0.99, w * 0.57, h * 0.99)
    ..lineTo(w * 0.43, h * 0.99)
    ..cubicTo(w * 0.31, h * 0.99, w * 0.19, h * 0.94, w * 0.16, h * 0.78)
    ..lineTo(w * 0.10, h * 0.28)
    ..cubicTo(w * 0.09, h * 0.14, w * 0.18, h * 0.04, w * 0.31, h * 0.02)
    ..close();
  canvas.drawPath(
    bodyPath,
    Paint()
      ..shader = Gradient.linear(
        Offset(w * 0.18, h * 0.05),
        Offset(w * 0.86, h * 0.98),
        [light, base, dark, darker],
        [0.0, 0.38, 0.74, 1.0],
      ),
  );
  canvas.drawPath(
    bodyPath,
    Paint()
      ..color = const Color(0xBB111111)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0,
  );

  final seamPaint = Paint()
    ..color = const Color(0x77000000)
    ..strokeWidth = 1.2
    ..strokeCap = StrokeCap.round;
  final panelPaint = Paint()
    ..color = const Color(0x44000000)
    ..style = PaintingStyle.stroke
    ..strokeWidth = 1.0;

  final hood = Path()
    ..moveTo(w * 0.30, h * 0.08)
    ..lineTo(w * 0.70, h * 0.08)
    ..lineTo(w * 0.76, h * 0.28)
    ..lineTo(w * 0.24, h * 0.28)
    ..close();
  canvas.drawPath(
    hood,
    Paint()
      ..shader = Gradient.linear(
        Offset(w * 0.25, h * 0.08),
        Offset(w * 0.75, h * 0.28),
        [light.withValues(alpha: 0.38), const Color(0x00000000)],
      ),
  );
  canvas.drawPath(hood, panelPaint);

  canvas.drawLine(
      Offset(w * 0.27, h * 0.30), Offset(w * 0.73, h * 0.30), seamPaint);
  canvas.drawLine(
      Offset(w * 0.24, h * 0.76), Offset(w * 0.76, h * 0.76), seamPaint);
  canvas.drawLine(
      Offset(w * 0.22, h * 0.24), Offset(w * 0.20, h * 0.74), seamPaint);
  canvas.drawLine(
      Offset(w * 0.78, h * 0.24), Offset(w * 0.80, h * 0.74), seamPaint);
  canvas.drawLine(
      Offset(w * 0.36, h * 0.08), Offset(w * 0.30, h * 0.22), seamPaint);
  canvas.drawLine(
      Offset(w * 0.64, h * 0.08), Offset(w * 0.70, h * 0.22), seamPaint);
  canvas.drawLine(
      Offset(w * 0.36, h * 0.82), Offset(w * 0.31, h * 0.92), seamPaint);
  canvas.drawLine(
      Offset(w * 0.64, h * 0.82), Offset(w * 0.69, h * 0.92), seamPaint);

  final glass = Paint()
    ..shader = Gradient.linear(
      Offset(w * 0.28, h * 0.27),
      Offset(w * 0.72, h * 0.70),
      [
        const Color(0xFFE7F7FF),
        const Color(0xFF5AA9E6),
        const Color(0xFF1565A8)
      ],
      [0.0, 0.48, 1.0],
    );
  final windshield = Path()
    ..moveTo(w * 0.31, h * 0.32)
    ..lineTo(w * 0.69, h * 0.32)
    ..lineTo(w * 0.74, h * 0.45)
    ..lineTo(w * 0.26, h * 0.45)
    ..close();
  canvas.drawPath(windshield, glass);
  canvas.drawPath(
    windshield,
    Paint()
      ..color = const Color(0x66000000)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.1,
  );

  final leftWindow = Path()
    ..moveTo(w * 0.27, h * 0.48)
    ..lineTo(w * 0.47, h * 0.48)
    ..lineTo(w * 0.45, h * 0.63)
    ..lineTo(w * 0.25, h * 0.62)
    ..close();
  final rightWindow = Path()
    ..moveTo(w * 0.53, h * 0.48)
    ..lineTo(w * 0.73, h * 0.48)
    ..lineTo(w * 0.75, h * 0.62)
    ..lineTo(w * 0.55, h * 0.63)
    ..close();
  canvas.drawPath(leftWindow, glass);
  canvas.drawPath(rightWindow, glass);
  canvas.drawPath(leftWindow, panelPaint);
  canvas.drawPath(rightWindow, panelPaint);
  canvas.drawLine(
      Offset(w * 0.50, h * 0.47), Offset(w * 0.50, h * 0.65), seamPaint);

  final rear = Path()
    ..moveTo(w * 0.29, h * 0.66)
    ..lineTo(w * 0.71, h * 0.66)
    ..lineTo(w * 0.66, h * 0.75)
    ..lineTo(w * 0.34, h * 0.75)
    ..close();
  canvas.drawPath(rear, Paint()..color = const Color(0xAA64B5F6));
  canvas.drawPath(
    rear,
    Paint()
      ..color = const Color(0x66000000)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.1,
  );

  canvas.drawRRect(
    RRect.fromRectAndRadius(
        Rect.fromLTWH(w * 0.20, h * 0.075, w * 0.20, h * 0.055),
        const Radius.circular(4)),
    Paint()..color = const Color(0xFFFFFDE7),
  );
  canvas.drawRRect(
    RRect.fromRectAndRadius(
        Rect.fromLTWH(w * 0.60, h * 0.075, w * 0.20, h * 0.055),
        const Radius.circular(4)),
    Paint()..color = const Color(0xFFFFFDE7),
  );
  canvas.drawCircle(
    Offset(w * 0.27, h * 0.10),
    w * 0.055,
    Paint()..color = const Color(0x33FFF9C4),
  );
  canvas.drawCircle(
    Offset(w * 0.73, h * 0.10),
    w * 0.055,
    Paint()..color = const Color(0x33FFF9C4),
  );
  if (headlightsOn) {
    _renderHeadlightBeams(canvas, w, h);
  }
  canvas.drawRRect(
    RRect.fromRectAndRadius(
        Rect.fromLTWH(w * 0.25, h * 0.90, w * 0.14, h * 0.05),
        const Radius.circular(3)),
    Paint()..color = const Color(0xFFFF1744),
  );
  canvas.drawRRect(
    RRect.fromRectAndRadius(
        Rect.fromLTWH(w * 0.61, h * 0.90, w * 0.14, h * 0.05),
        const Radius.circular(3)),
    Paint()..color = const Color(0xFFFF1744),
  );
  canvas.drawRRect(
    RRect.fromRectAndRadius(
      Rect.fromCenter(
          center: Offset(w * 0.50, h * 0.92),
          width: w * 0.18,
          height: h * 0.035),
      const Radius.circular(2),
    ),
    Paint()..color = const Color(0xFFECEFF1),
  );

  final grillePaint = Paint()
    ..color = const Color(0xFF263238)
    ..strokeWidth = 1.2
    ..strokeCap = StrokeCap.round;
  for (int i = 0; i < 4; i++) {
    final gy = h * (0.155 + i * 0.018);
    canvas.drawLine(Offset(w * 0.39, gy), Offset(w * 0.61, gy), grillePaint);
  }

  for (final side in [-1.0, 1.0]) {
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(
          center: Offset(w * (0.50 + side * 0.31), h * 0.56),
          width: w * 0.05,
          height: h * 0.015,
        ),
        const Radius.circular(1),
      ),
      Paint()..color = const Color(0xAA111111),
    );
  }

  final roofRect = RRect.fromRectAndRadius(
    Rect.fromCenter(
      center: Offset(w * 0.50, h * 0.49),
      width: w * 0.48,
      height: h * 0.34,
    ),
    const Radius.circular(13),
  );
  canvas.drawRRect(
    roofRect,
    Paint()
      ..shader = Gradient.linear(
        Offset(w * 0.32, h * 0.32),
        Offset(w * 0.68, h * 0.66),
        [
          const Color(0xFFEAF9FF),
          const Color(0xFF77BDE8),
          const Color(0xFF0D3755),
        ],
        [0.0, 0.48, 1.0],
      ),
  );
  canvas.drawRRect(
    roofRect,
    Paint()
      ..color = const Color(0x66000000)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2,
  );
  canvas.drawRRect(
    RRect.fromRectAndRadius(
      Rect.fromCenter(
        center: Offset(w * 0.50, h * 0.50),
        width: w * 0.25,
        height: h * 0.24,
      ),
      const Radius.circular(10),
    ),
    Paint()..color = const Color(0x66263036),
  );

  final ledPaint = Paint()
    ..color = const Color(0xFFE8F8FF)
    ..strokeWidth = 2.2
    ..strokeCap = StrokeCap.round;
  canvas.drawLine(
      Offset(w * 0.26, h * 0.085), Offset(w * 0.42, h * 0.072), ledPaint);
  canvas.drawLine(
      Offset(w * 0.58, h * 0.072), Offset(w * 0.74, h * 0.085), ledPaint);
  final tailPaint = Paint()
    ..color = const Color(0xFFFF1744)
    ..strokeWidth = 2.4
    ..strokeCap = StrokeCap.round;
  canvas.drawLine(
      Offset(w * 0.28, h * 0.925), Offset(w * 0.42, h * 0.942), tailPaint);
  canvas.drawLine(
      Offset(w * 0.58, h * 0.942), Offset(w * 0.72, h * 0.925), tailPaint);

  canvas.drawLine(
    Offset(w * 0.35, h * 0.08),
    Offset(w * 0.28, h * 0.70),
    Paint()
      ..color = const Color(0x66FFFFFF)
      ..strokeWidth = 2.4
      ..strokeCap = StrokeCap.round,
  );
  canvas.drawLine(
    Offset(w * 0.58, h * 0.50),
    Offset(w * 0.68, h * 0.60),
    Paint()
      ..color = const Color(0x88FFFFFF)
      ..strokeWidth = 1.4
      ..strokeCap = StrokeCap.round,
  );
}

void _renderHeadlightBeams(Canvas canvas, double w, double h) {
  for (final x in [w * 0.30, w * 0.70]) {
    final beam = Path()
      ..moveTo(x - w * 0.06, h * 0.10)
      ..quadraticBezierTo(x - w * 0.10, h * 0.00, x - w * 0.16, -h * 0.18)
      ..lineTo(x + w * 0.16, -h * 0.18)
      ..quadraticBezierTo(x + w * 0.10, h * 0.00, x + w * 0.06, h * 0.10)
      ..close();
    canvas.drawPath(
      beam,
      Paint()
        ..shader = Gradient.linear(
          Offset(x, -h * 0.18),
          Offset(x, h * 0.12),
          [
            const Color(0x00FFF8CF),
            const Color(0x4DFFF4C4),
            const Color(0x11FFFDF0),
          ],
          [0.0, 0.45, 1.0],
        ),
    );
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(x, h * 0.06),
        width: w * 0.18,
        height: h * 0.11,
      ),
      Paint()
        ..color = const Color(0x66FFF7C7)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4.0),
    );
  }
}

void _renderGlassCracks(Canvas canvas, double w, double h) {
  final cx = w * 0.50;
  final cy = h * 0.30;
  final crackPaint = Paint()
    ..color = const Color(0xFFE0E0E0)
    ..strokeWidth = 0.9
    ..strokeCap = StrokeCap.round;
  for (int i = 0; i < 8; i++) {
    final ang = i * pi / 4;
    canvas.drawLine(
      Offset(cx, cy),
      Offset(cx + cos(ang) * w * 0.30, cy + sin(ang) * h * 0.10),
      crackPaint,
    );
  }
}

Color _lighten(Color c, double amount) {
  return Color.lerp(c, const Color(0xFFFFFFFF), amount) ?? c;
}

Color _darken(Color c, double amount) {
  return Color.lerp(c, const Color(0xFF000000), amount) ?? c;
}
