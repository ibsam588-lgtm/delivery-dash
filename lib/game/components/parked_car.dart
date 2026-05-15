import 'dart:ui';
import 'package:flame/collisions.dart';
import 'package:flame/components.dart';
import '../delivery_dash_game.dart';
import '../perspective.dart';

class ParkedCarComponent extends PositionComponent
    with HasGameRef<DeliveryDashGame>, CollisionCallbacks {
  static const int bonusPoints = 15;

  static const List<Color> _bodyColors = [
    Color(0xFFCC1111), // bold red
    Color(0xFF1565C0), // bold blue
    Color(0xFFFFD600), // bold yellow
    Color(0xFFF5F5F5), // white
    Color(0xFF2E7D32), // forest green
    Color(0xFFE65100), // bold orange
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
    final lm = gameRef.laneManager;
    final dx = depthXShiftDiag(
      worldX: position.x,
      leftRef: lm.roadLeft,
      widthRef: lm.roadWidth,
      leftY: lm.roadLeftAt(position.y),
      widthY: lm.roadWidthAt(position.y),
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
  final lightColor = Color.fromARGB(
    255,
    ((bodyColor.r * 255 + 30).clamp(0.0, 255.0)).round(),
    ((bodyColor.g * 255 + 30).clamp(0.0, 255.0)).round(),
    ((bodyColor.b * 255 + 30).clamp(0.0, 255.0)).round(),
  );
  final darkColor = Color.fromARGB(
    255,
    ((bodyColor.r * 255 * 0.75).clamp(0.0, 255.0)).round(),
    ((bodyColor.g * 255 * 0.75).clamp(0.0, 255.0)).round(),
    ((bodyColor.b * 255 * 0.75).clamp(0.0, 255.0)).round(),
  );

  // Under-car shadow.
  canvas.drawOval(
    Rect.fromCenter(
      center: Offset(w / 2, h / 2),
      width: w * 0.90,
      height: h * 0.96,
    ),
    Paint()..color = const Color(0x55000000),
  );

  // Car body — rounded rectangle.
  final bodyRRect = RRect.fromRectAndRadius(
    Rect.fromLTWH(w * 0.08, h * 0.04, w * 0.84, h * 0.88),
    Radius.circular(w * 0.14),
  );
  canvas.drawRRect(bodyRRect, Paint()..color = bodyColor);

  // Hood (front — lighter, top of sprite = front of car).
  final hoodPath = Path()
    ..moveTo(w * 0.15, h * 0.04)
    ..lineTo(w * 0.85, h * 0.04)
    ..lineTo(w * 0.78, h * 0.22)
    ..lineTo(w * 0.22, h * 0.22)
    ..close();
  canvas.drawPath(hoodPath, Paint()..color = lightColor);

  // Trunk (rear — darker, bottom of sprite).
  final trunkPath = Path()
    ..moveTo(w * 0.22, h * 0.78)
    ..lineTo(w * 0.78, h * 0.78)
    ..lineTo(w * 0.85, h * 0.96)
    ..lineTo(w * 0.15, h * 0.96)
    ..close();
  canvas.drawPath(trunkPath, Paint()..color = darkColor);

  // Windshield (front glass — trapezoid, blue-tinted).
  final windshieldPath = Path()
    ..moveTo(w * 0.22, h * 0.22)
    ..lineTo(w * 0.78, h * 0.22)
    ..lineTo(w * 0.72, h * 0.34)
    ..lineTo(w * 0.28, h * 0.34)
    ..close();
  canvas.drawPath(
    windshieldPath,
    Paint()..color = const Color(0x9999BBDD),
  );

  // Roof (slightly narrower raised rectangle).
  final roofRect = Rect.fromLTWH(w * 0.22, h * 0.34, w * 0.56, h * 0.32);
  canvas.drawRRect(
    RRect.fromRectAndRadius(roofRect, Radius.circular(w * 0.06)),
    Paint()..color = lightColor,
  );
  // Roof glare.
  canvas.drawLine(
    Offset(w * 0.28, h * 0.36),
    Offset(w * 0.40, h * 0.46),
    Paint()
      ..color = const Color(0x55FFFFFF)
      ..strokeWidth = 2.5
      ..strokeCap = StrokeCap.round,
  );

  // Rear window (trapezoid).
  final rearWinPath = Path()
    ..moveTo(w * 0.28, h * 0.66)
    ..lineTo(w * 0.72, h * 0.66)
    ..lineTo(w * 0.78, h * 0.78)
    ..lineTo(w * 0.22, h * 0.78)
    ..close();
  canvas.drawPath(
    rearWinPath,
    Paint()..color = const Color(0x7799BBDD),
  );

  // Wheels — oval shapes at four corners.
  final wheelPaint = Paint()..color = const Color(0xFF1A1A1A);
  for (final wc in [
    Offset(w * 0.12, h * 0.12),
    Offset(w * 0.88, h * 0.12),
    Offset(w * 0.12, h * 0.78),
    Offset(w * 0.88, h * 0.78),
  ]) {
    canvas.drawOval(
      Rect.fromCenter(center: wc, width: w * 0.18, height: h * 0.10),
      wheelPaint,
    );
    canvas.drawOval(
      Rect.fromCenter(center: wc, width: w * 0.10, height: h * 0.06),
      Paint()..color = const Color(0xFF8A8A8A),
    );
    canvas.drawOval(
      Rect.fromCenter(center: wc, width: w * 0.04, height: h * 0.025),
      Paint()..color = const Color(0xFFDDDDDD),
    );
  }

  // Side mirrors.
  final mirrorPaint = Paint()..color = darkColor;
  canvas.drawRRect(
    RRect.fromRectAndRadius(
      Rect.fromLTWH(w * 0.01, h * 0.22, w * 0.07, h * 0.05),
      const Radius.circular(2),
    ),
    mirrorPaint,
  );
  canvas.drawRRect(
    RRect.fromRectAndRadius(
      Rect.fromLTWH(w * 0.92, h * 0.22, w * 0.07, h * 0.05),
      const Radius.circular(2),
    ),
    mirrorPaint,
  );

  // Headlights (front) — bright yellow ovals at top corners.
  for (final hx in [w * 0.16, w * 0.74]) {
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(hx, h * 0.09),
        width: w * 0.14,
        height: h * 0.055,
      ),
      Paint()..color = const Color(0xFFFFF176),
    );
  }

  // Taillights (rear) — red ovals at bottom corners.
  for (final tx in [w * 0.16, w * 0.74]) {
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(tx, h * 0.91),
        width: w * 0.14,
        height: h * 0.055,
      ),
      Paint()..color = const Color(0xFFFF1744),
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
