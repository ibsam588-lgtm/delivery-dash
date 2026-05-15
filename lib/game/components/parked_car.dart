import 'dart:math';
import 'dart:ui';
import 'package:flame/collisions.dart';
import 'package:flame/components.dart';
import '../delivery_dash_game.dart';
import '../perspective.dart';

class ParkedCarComponent extends PositionComponent
    with HasGameRef<DeliveryDashGame>, CollisionCallbacks {
  static const int bonusPoints = 15;
  static const int variantCount = 4;

  final int variant;
  bool _hit = false;
  bool _windowBroken = false;
  double _bounce = 0;

  ParkedCarComponent({this.variant = 0})
      : super(
          size: Vector2(68, 105),
          anchor: Anchor.center,
          priority: 15,
        );

  static int get colorCount => variantCount;

  @override
  Future<void> onLoad() async {
    final lm = gameRef.laneManager;
    final x = lm.roadRight + 4 + size.x / 2;
    // Spawn just past the horizon, inside the road area — not in the sky.
    position = Vector2(x, gameRef.size.y * 0.30);
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

    renderTopDownCar(canvas, size.x, size.y, variant);

    if (_windowBroken) {
      _renderGlassCracks(canvas, size.x, size.y);
    }

    canvas.restore();

    if (_hit) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(2, 2, size.x - 4, size.y - 4),
          const Radius.circular(10),
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
  Color(0xFF1E88E5),
  Color(0xFF43A047),
  Color(0xFFFFB300),
];

/// Render a top-down car into a [w]×[h] box using Canvas primitives.
/// This replaces fragile PNG dependency with a consistent retro arcade look.
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
  final dark = _darken(base, 0.42);
  final light = _lighten(base, 0.28);

  // Tires.
  final tirePaint = Paint()..color = const Color(0xFF111111);
  for (final x in [w * 0.12, w * 0.88]) {
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(center: Offset(x, h * 0.28), width: w * 0.15, height: h * 0.18),
        const Radius.circular(5),
      ),
      tirePaint,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(center: Offset(x, h * 0.72), width: w * 0.15, height: h * 0.18),
        const Radius.circular(5),
      ),
      tirePaint,
    );
  }

  // Main body silhouette.
  final body = RRect.fromRectAndRadius(
    Rect.fromLTWH(w * 0.16, h * 0.04, w * 0.68, h * 0.92),
    const Radius.circular(16),
  );
  canvas.drawRRect(
    body,
    Paint()
      ..shader = Gradient.linear(
        Offset(w * 0.16, 0),
        Offset(w * 0.84, h),
        [light, base, dark],
        [0.0, 0.55, 1.0],
      ),
  );
  canvas.drawRRect(
    body,
    Paint()
      ..color = const Color(0xAA111111)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0,
  );

  // Hood and trunk panel lines.
  final seamPaint = Paint()
    ..color = const Color(0x66000000)
    ..strokeWidth = 1.2
    ..strokeCap = StrokeCap.round;
  canvas.drawLine(Offset(w * 0.24, h * 0.24), Offset(w * 0.76, h * 0.24), seamPaint);
  canvas.drawLine(Offset(w * 0.24, h * 0.76), Offset(w * 0.76, h * 0.76), seamPaint);

  // Windshield / cabin / rear window.
  final glass = Paint()
    ..shader = Gradient.linear(
      Offset(w * 0.30, h * 0.18),
      Offset(w * 0.70, h * 0.70),
      [const Color(0xFFB3E5FC), const Color(0xFF1565C0)],
    );
  final windshield = Path()
    ..moveTo(w * 0.33, h * 0.24)
    ..lineTo(w * 0.67, h * 0.24)
    ..lineTo(w * 0.72, h * 0.40)
    ..lineTo(w * 0.28, h * 0.40)
    ..close();
  canvas.drawPath(windshield, glass);
  canvas.drawPath(windshield, Paint()..color = const Color(0x55000000)..style = PaintingStyle.stroke..strokeWidth = 1.2);

  final cabin = RRect.fromRectAndRadius(
    Rect.fromLTWH(w * 0.28, h * 0.41, w * 0.44, h * 0.20),
    const Radius.circular(6),
  );
  canvas.drawRRect(cabin, Paint()..color = const Color(0xAA90CAF9));
  canvas.drawLine(Offset(w * 0.50, h * 0.42), Offset(w * 0.50, h * 0.60), seamPaint);

  final rear = Path()
    ..moveTo(w * 0.28, h * 0.62)
    ..lineTo(w * 0.72, h * 0.62)
    ..lineTo(w * 0.66, h * 0.76)
    ..lineTo(w * 0.34, h * 0.76)
    ..close();
  canvas.drawPath(rear, Paint()..color = const Color(0xAA64B5F6));
  canvas.drawPath(rear, Paint()..color = const Color(0x55000000)..style = PaintingStyle.stroke..strokeWidth = 1.2);

  // Headlights and tail lights.
  canvas.drawRRect(
    RRect.fromRectAndRadius(Rect.fromLTWH(w * 0.25, h * 0.06, w * 0.16, h * 0.055), const Radius.circular(3)),
    Paint()..color = const Color(0xFFFFF9C4),
  );
  canvas.drawRRect(
    RRect.fromRectAndRadius(Rect.fromLTWH(w * 0.59, h * 0.06, w * 0.16, h * 0.055), const Radius.circular(3)),
    Paint()..color = const Color(0xFFFFF9C4),
  );
  canvas.drawRRect(
    RRect.fromRectAndRadius(Rect.fromLTWH(w * 0.25, h * 0.89, w * 0.14, h * 0.045), const Radius.circular(3)),
    Paint()..color = const Color(0xFFFF1744),
  );
  canvas.drawRRect(
    RRect.fromRectAndRadius(Rect.fromLTWH(w * 0.61, h * 0.89, w * 0.14, h * 0.045), const Radius.circular(3)),
    Paint()..color = const Color(0xFFFF1744),
  );

  // Center reflection stripe.
  canvas.drawLine(
    Offset(w * 0.40, h * 0.12),
    Offset(w * 0.34, h * 0.72),
    Paint()
      ..color = const Color(0x55FFFFFF)
      ..strokeWidth = 2.5
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
