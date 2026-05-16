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
    final spawnY = gameRef.size.y * 0.30;
    // Parked cars now sit just inside the road curb instead of outside the
    // road on the sidewalk/yard. This was the main reason cars looked like
    // they were driving on the sidewalk.
    final x = lm.roadXFromFraction(onRightCurb ? 0.84 : 0.16, spawnY);
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
  Color(0xFFC62828),
  Color(0xFF1565C0),
  Color(0xFF2E7D32),
  Color(0xFFFFB300),
  Color(0xFF455A64),
  Color(0xFFF5F5F5),
];

/// Render a more realistic top-down car into a [w]×[h] box.
void renderTopDownCar(
  Canvas canvas,
  double w,
  double h,
  int variant, {
  bool isOncoming = false,
}) {
  if (isOncoming) {
    canvas.save();
    canvas.translate(0, h);
    canvas.scale(1, -1);
    _renderCarBody(canvas, w, h, variant);
    canvas.restore();
  } else {
    _renderCarBody(canvas, w, h, variant);
  }
}

void _renderCarBody(Canvas canvas, double w, double h, int variant) {
  final base = _carPaints[variant % _carPaints.length];
  final dark = _darken(base, 0.46);
  final light = _lighten(base, 0.32);
  final trim = Paint()..color = const Color(0xFF101010);

  // Tire blocks tucked under the fenders.
  for (final x in [w * 0.10, w * 0.90]) {
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(center: Offset(x, h * 0.27), width: w * 0.16, height: h * 0.18),
        const Radius.circular(5),
      ),
      trim,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(center: Offset(x, h * 0.73), width: w * 0.16, height: h * 0.18),
        const Radius.circular(5),
      ),
      trim,
    );
  }

  // Door mirrors.
  canvas.drawRRect(
    RRect.fromRectAndRadius(Rect.fromLTWH(w * 0.08, h * 0.39, w * 0.09, h * 0.07), const Radius.circular(3)),
    Paint()..color = const Color(0xFF212121),
  );
  canvas.drawRRect(
    RRect.fromRectAndRadius(Rect.fromLTWH(w * 0.83, h * 0.39, w * 0.09, h * 0.07), const Radius.circular(3)),
    Paint()..color = const Color(0xFF212121),
  );

  // Body silhouette — narrower waist, rounded hood/trunk.
  final bodyPath = Path()
    ..moveTo(w * 0.30, h * 0.03)
    ..lineTo(w * 0.70, h * 0.03)
    ..quadraticBezierTo(w * 0.84, h * 0.08, w * 0.86, h * 0.22)
    ..lineTo(w * 0.82, h * 0.82)
    ..quadraticBezierTo(w * 0.77, h * 0.97, w * 0.63, h * 0.98)
    ..lineTo(w * 0.37, h * 0.98)
    ..quadraticBezierTo(w * 0.23, h * 0.97, w * 0.18, h * 0.82)
    ..lineTo(w * 0.14, h * 0.22)
    ..quadraticBezierTo(w * 0.16, h * 0.08, w * 0.30, h * 0.03)
    ..close();
  canvas.drawPath(
    bodyPath,
    Paint()
      ..shader = Gradient.linear(
        Offset(w * 0.16, 0),
        Offset(w * 0.84, h),
        [light, base, dark],
        [0.0, 0.55, 1.0],
      ),
  );
  canvas.drawPath(
    bodyPath,
    Paint()
      ..color = const Color(0xBB111111)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0,
  );

  // Hood crease and trunk seams.
  final seamPaint = Paint()
    ..color = const Color(0x77000000)
    ..strokeWidth = 1.2
    ..strokeCap = StrokeCap.round;
  canvas.drawLine(Offset(w * 0.27, h * 0.23), Offset(w * 0.73, h * 0.23), seamPaint);
  canvas.drawLine(Offset(w * 0.24, h * 0.78), Offset(w * 0.76, h * 0.78), seamPaint);
  canvas.drawLine(Offset(w * 0.22, h * 0.24), Offset(w * 0.20, h * 0.74), seamPaint);
  canvas.drawLine(Offset(w * 0.78, h * 0.24), Offset(w * 0.80, h * 0.74), seamPaint);

  // Glass: windshield, cabin, rear window with strong highlights.
  final glass = Paint()
    ..shader = Gradient.linear(
      Offset(w * 0.28, h * 0.18),
      Offset(w * 0.72, h * 0.74),
      [const Color(0xFFE1F5FE), const Color(0xFF1976D2)],
    );
  final windshield = Path()
    ..moveTo(w * 0.32, h * 0.24)
    ..lineTo(w * 0.68, h * 0.24)
    ..lineTo(w * 0.73, h * 0.39)
    ..lineTo(w * 0.27, h * 0.39)
    ..close();
  canvas.drawPath(windshield, glass);
  canvas.drawPath(windshield, Paint()..color = const Color(0x66000000)..style = PaintingStyle.stroke..strokeWidth = 1.1);

  final cabin = RRect.fromRectAndRadius(
    Rect.fromLTWH(w * 0.27, h * 0.41, w * 0.46, h * 0.20),
    const Radius.circular(7),
  );
  canvas.drawRRect(cabin, Paint()..color = const Color(0xCC90CAF9));
  canvas.drawRRect(cabin, Paint()..color = const Color(0x66000000)..style = PaintingStyle.stroke..strokeWidth = 1.1);
  canvas.drawLine(Offset(w * 0.50, h * 0.42), Offset(w * 0.50, h * 0.60), seamPaint);

  final rear = Path()
    ..moveTo(w * 0.27, h * 0.63)
    ..lineTo(w * 0.73, h * 0.63)
    ..lineTo(w * 0.66, h * 0.77)
    ..lineTo(w * 0.34, h * 0.77)
    ..close();
  canvas.drawPath(rear, Paint()..color = const Color(0xCC64B5F6));
  canvas.drawPath(rear, Paint()..color = const Color(0x66000000)..style = PaintingStyle.stroke..strokeWidth = 1.1);

  // Lights, bumpers, license plate.
  canvas.drawRRect(
    RRect.fromRectAndRadius(Rect.fromLTWH(w * 0.24, h * 0.06, w * 0.17, h * 0.06), const Radius.circular(3)),
    Paint()..color = const Color(0xFFFFFDE7),
  );
  canvas.drawRRect(
    RRect.fromRectAndRadius(Rect.fromLTWH(w * 0.59, h * 0.06, w * 0.17, h * 0.06), const Radius.circular(3)),
    Paint()..color = const Color(0xFFFFFDE7),
  );
  canvas.drawRRect(
    RRect.fromRectAndRadius(Rect.fromLTWH(w * 0.25, h * 0.90, w * 0.14, h * 0.05), const Radius.circular(3)),
    Paint()..color = const Color(0xFFFF1744),
  );
  canvas.drawRRect(
    RRect.fromRectAndRadius(Rect.fromLTWH(w * 0.61, h * 0.90, w * 0.14, h * 0.05), const Radius.circular(3)),
    Paint()..color = const Color(0xFFFF1744),
  );
  canvas.drawRRect(
    RRect.fromRectAndRadius(Rect.fromCenter(center: Offset(w * 0.50, h * 0.92), width: w * 0.18, height: h * 0.035), const Radius.circular(2)),
    Paint()..color = const Color(0xFFECEFF1),
  );

  // Painted highlight and roof reflection.
  canvas.drawLine(
    Offset(w * 0.38, h * 0.11),
    Offset(w * 0.31, h * 0.72),
    Paint()
      ..color = const Color(0x66FFFFFF)
      ..strokeWidth = 2.4
      ..strokeCap = StrokeCap.round,
  );
  canvas.drawLine(
    Offset(w * 0.58, h * 0.43),
    Offset(w * 0.66, h * 0.55),
    Paint()
      ..color = const Color(0x88FFFFFF)
      ..strokeWidth = 1.4
      ..strokeCap = StrokeCap.round,
  );
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
  return Color.fromARGB(
    c.alpha,
    c.red + ((255 - c.red) * amount).round(),
    c.green + ((255 - c.green) * amount).round(),
    c.blue + ((255 - c.blue) * amount).round(),
  );
}

Color _darken(Color c, double amount) {
  return Color.fromARGB(
    c.alpha,
    (c.red * (1 - amount)).round(),
    (c.green * (1 - amount)).round(),
    (c.blue * (1 - amount)).round(),
  );
}
