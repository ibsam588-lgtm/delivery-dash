import 'dart:ui';
import 'package:flame/collisions.dart';
import 'package:flame/components.dart';
import '../delivery_dash_game.dart';
import '../perspective.dart';

class ParkedCarComponent extends PositionComponent
    with HasGameRef<DeliveryDashGame>, CollisionCallbacks {
  static const int bonusPoints = 15;

  static const List<Color> _bodyColors = [
    Color(0xFFE53935),
    Color(0xFF1565C0),
    Color(0xFF9E9E9E),
    Color(0xFFFBC02D),
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
  // Determine lighter roof and darker trim colours from body.
  final roofColor = Color.fromARGB(
    255,
    ((bodyColor.r * 255 + 30).clamp(0.0, 255.0)).round(),
    ((bodyColor.g * 255 + 30).clamp(0.0, 255.0)).round(),
    ((bodyColor.b * 255 + 30).clamp(0.0, 255.0)).round(),
  );
  const wheelColor = Color(0xFF1A1A1A);
  const hubColor = Color(0xFF888888);

  // Car body.
  final bodyRRect = RRect.fromRectAndRadius(
    Rect.fromLTWH(w * 0.10, h * 0.04, w * 0.80, h * 0.92),
    Radius.circular(w * 0.13),
  );
  canvas.drawRRect(bodyRRect, Paint()..color = bodyColor);

  // Wheels (4 corners).
  const double wheelR = 5.5;
  for (final c in [
    Offset(w * 0.15, h * 0.12),
    Offset(w * 0.85, h * 0.12),
    Offset(w * 0.15, h * 0.88),
    Offset(w * 0.85, h * 0.88),
  ]) {
    canvas.drawCircle(c, wheelR, Paint()..color = wheelColor);
    canvas.drawCircle(c, wheelR * 0.45, Paint()..color = hubColor);
  }

  // Windshield (front, near top).
  final windshieldRect = Rect.fromLTWH(w * 0.15, h * 0.09, w * 0.70, h * 0.16);
  canvas.drawRRect(
    RRect.fromRectAndRadius(windshieldRect, Radius.circular(w * 0.04)),
    Paint()
      ..shader = Gradient.linear(
        windshieldRect.topLeft,
        windshieldRect.bottomRight,
        [const Color(0xFFB3D9F0), const Color(0xFF8BBCD8)],
      ),
  );

  // Rear window (near bottom, slightly narrower).
  final rearWinRect = Rect.fromLTWH(w * 0.18, h * 0.75, w * 0.64, h * 0.14);
  canvas.drawRRect(
    RRect.fromRectAndRadius(rearWinRect, Radius.circular(w * 0.04)),
    Paint()..color = const Color(0xFF8BBCD8),
  );

  // Roof (elevated inner rounded rect, lighter shade).
  final roofRect = Rect.fromLTWH(w * 0.20, h * 0.30, w * 0.60, h * 0.40);
  canvas.drawRRect(
    RRect.fromRectAndRadius(roofRect, Radius.circular(w * 0.06)),
    Paint()..color = roofColor,
  );
  // Roof reflection streak.
  canvas.drawLine(
    Offset(w * 0.28, h * 0.32),
    Offset(w * 0.38, h * 0.42),
    Paint()
      ..color = const Color(0x66FFFFFF)
      ..strokeWidth = 2.5
      ..strokeCap = StrokeCap.round,
  );

  // Headlights (front, top).
  final hlPaint = Paint()..color = const Color(0xFFFFF9C4);
  canvas.drawRect(Rect.fromLTWH(w * 0.12, h * 0.05, w * 0.18, h * 0.06), hlPaint);
  canvas.drawRect(Rect.fromLTWH(w * 0.70, h * 0.05, w * 0.18, h * 0.06), hlPaint);

  // Taillights (rear, bottom).
  final tlPaint = Paint()..color = const Color(0xFFEF5350);
  canvas.drawRect(Rect.fromLTWH(w * 0.12, h * 0.89, w * 0.18, h * 0.06), tlPaint);
  canvas.drawRect(Rect.fromLTWH(w * 0.70, h * 0.89, w * 0.18, h * 0.06), tlPaint);

  // Body outline.
  canvas.drawRRect(
    bodyRRect,
    Paint()
      ..color = const Color(0x44000000)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0,
  );
}
