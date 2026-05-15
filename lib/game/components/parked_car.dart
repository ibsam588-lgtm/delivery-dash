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

/// Rear-view car for the straight-ahead camera. The back of the car faces
/// the player: roof + rear windshield in the upper half, rear bumper +
/// licence plate + taillights at the bottom. When [isOncoming] is true the
/// sprite is flipped vertically so the front of the car faces the player.
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
    canvas.translate(0, h);
    canvas.scale(1, -1);
  }

  // ── Ground shadow ──────────────────────────────────────────────────────
  canvas.drawOval(
    Rect.fromCenter(
      center: Offset(w * 0.5, h * 0.94),
      width: w * 0.85,
      height: h * 0.09,
    ),
    Paint()..color = const Color(0x55000000),
  );

  // ── Car body (rear view — slightly tapered, wider at bottom/rear) ──────
  final bodyPath = Path()
    ..moveTo(w * 0.06, h * 0.20)
    ..lineTo(w * 0.94, h * 0.20)
    ..lineTo(w * 0.98, h * 0.88)
    ..lineTo(w * 0.02, h * 0.88)
    ..close();
  canvas.drawPath(
    bodyPath,
    Paint()
      ..shader = Gradient.linear(
        Offset(0, h * 0.20),
        Offset(0, h * 0.88),
        [bodyColor, _darken(bodyColor, 0.15)],
      ),
  );

  // ── Roof (slightly narrower, sits on top of body) ─────────────────────
  final roofPath = Path()
    ..moveTo(w * 0.18, h * 0.06)
    ..lineTo(w * 0.82, h * 0.06)
    ..lineTo(w * 0.88, h * 0.26)
    ..lineTo(w * 0.12, h * 0.26)
    ..close();
  canvas.drawPath(roofPath, Paint()..color = _darken(bodyColor, 0.08));
  // Roof highlight streak.
  canvas.drawLine(
    Offset(w * 0.35, h * 0.07),
    Offset(w * 0.55, h * 0.07),
    Paint()
      ..color = const Color(0x44FFFFFF)
      ..strokeWidth = 3.0
      ..strokeCap = StrokeCap.round,
  );

  // ── Rear windshield (trapezoid in roof area) ──────────────────────────
  final windPath = Path()
    ..moveTo(w * 0.22, h * 0.08)
    ..lineTo(w * 0.78, h * 0.08)
    ..lineTo(w * 0.84, h * 0.24)
    ..lineTo(w * 0.16, h * 0.24)
    ..close();
  if (!windshieldBroken) {
    canvas.drawPath(windPath, Paint()..color = const Color(0x9990CAF9));
    // Wiper lines.
    canvas.drawLine(
      Offset(w * 0.30, h * 0.23),
      Offset(w * 0.48, h * 0.10),
      Paint()
        ..color = const Color(0x88000000)
        ..strokeWidth = 1.5,
    );
    canvas.drawLine(
      Offset(w * 0.54, h * 0.10),
      Offset(w * 0.70, h * 0.23),
      Paint()
        ..color = const Color(0x88000000)
        ..strokeWidth = 1.5,
    );
  } else {
    canvas.save();
    canvas.clipPath(windPath);
    canvas.drawPath(windPath, Paint()..color = const Color(0xCC1A1A1A));
    final cx = w * 0.50;
    final cy = h * 0.16;
    final crackPaint = Paint()
      ..color = const Color(0xFFE0E0E0)
      ..strokeWidth = 0.9
      ..strokeCap = StrokeCap.round;
    for (int i = 0; i < 8; i++) {
      final ang = i * pi / 4;
      canvas.drawLine(
        Offset(cx, cy),
        Offset(cx + cos(ang) * w * 0.34, cy + sin(ang) * h * 0.10),
        crackPaint,
      );
    }
    canvas.restore();
  }

  // ── Side windows (small, mid-height) ──────────────────────────────────
  canvas.drawRRect(
    RRect.fromRectAndRadius(
      Rect.fromLTRB(w * 0.04, h * 0.28, w * 0.14, h * 0.54),
      const Radius.circular(3),
    ),
    Paint()..color = const Color(0x9990CAF9),
  );
  canvas.drawRRect(
    RRect.fromRectAndRadius(
      Rect.fromLTRB(w * 0.86, h * 0.28, w * 0.96, h * 0.54),
      const Radius.circular(3),
    ),
    Paint()..color = const Color(0x9990CAF9),
  );

  // ── Rear bumper ───────────────────────────────────────────────────────
  final bumperRect = Rect.fromLTRB(w * 0.04, h * 0.82, w * 0.96, h * 0.92);
  canvas.drawRRect(
    RRect.fromRectAndRadius(bumperRect, const Radius.circular(4)),
    Paint()..color = const Color(0xFF424242),
  );
  // Licence plate.
  canvas.drawRect(
    Rect.fromCenter(
      center: Offset(w * 0.5, h * 0.87),
      width: w * 0.30,
      height: h * 0.06,
    ),
    Paint()..color = const Color(0xFFFFF9C4),
  );

  // ── Tail lights (red ovals at lower corners) ──────────────────────────
  final tailPaint = Paint()..color = const Color(0xFFEF5350);
  canvas.drawOval(
    Rect.fromCenter(
      center: Offset(w * 0.13, h * 0.76),
      width: w * 0.18,
      height: h * 0.08,
    ),
    tailPaint,
  );
  canvas.drawOval(
    Rect.fromCenter(
      center: Offset(w * 0.87, h * 0.76),
      width: w * 0.18,
      height: h * 0.08,
    ),
    tailPaint,
  );
  // Inner bright core.
  final tailInner = Paint()..color = const Color(0xFFFF8A80);
  canvas.drawOval(
    Rect.fromCenter(
      center: Offset(w * 0.13, h * 0.76),
      width: w * 0.10,
      height: h * 0.04,
    ),
    tailInner,
  );
  canvas.drawOval(
    Rect.fromCenter(
      center: Offset(w * 0.87, h * 0.76),
      width: w * 0.10,
      height: h * 0.04,
    ),
    tailInner,
  );

  // ── Wheels (4 — rear bigger, front smaller) ───────────────────────────
  _drawCarWheel(canvas, Offset(w * 0.10, h * 0.68), w * 0.18, h * 0.10);
  _drawCarWheel(canvas, Offset(w * 0.90, h * 0.68), w * 0.18, h * 0.10);
  _drawCarWheel(canvas, Offset(w * 0.13, h * 0.35), w * 0.13, h * 0.07);
  _drawCarWheel(canvas, Offset(w * 0.87, h * 0.35), w * 0.13, h * 0.07);

  // ── Body outline ──────────────────────────────────────────────────────
  canvas.drawPath(
    bodyPath,
    Paint()
      ..color = const Color(0x55000000)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0,
  );

  if (isOncoming) canvas.restore();
}

void _drawCarWheel(Canvas canvas, Offset center, double rx, double ry) {
  canvas.drawOval(
    Rect.fromCenter(center: center, width: rx + 4, height: ry + 4),
    Paint()..color = const Color(0x44000000),
  );
  canvas.drawOval(
    Rect.fromCenter(center: center, width: rx, height: ry),
    Paint()..color = const Color(0xFF1A1A1A),
  );
  canvas.drawOval(
    Rect.fromCenter(center: center, width: rx * 0.65, height: ry * 0.65),
    Paint()..color = const Color(0xFFAAAAAA),
  );
  for (int i = 0; i < 5; i++) {
    final a = i * 2 * pi / 5;
    canvas.drawLine(
      Offset(center.dx + cos(a) * rx * 0.08, center.dy + sin(a) * ry * 0.08),
      Offset(center.dx + cos(a) * rx * 0.28, center.dy + sin(a) * ry * 0.28),
      Paint()
        ..color = const Color(0xFF888888)
        ..strokeWidth = 1.0,
    );
  }
}

Color _darken(Color c, double amount) {
  final inv = 1.0 - amount;
  return Color.fromARGB(
    ((c.a * 255).clamp(0.0, 255.0)).round(),
    ((c.r * 255 * inv).clamp(0.0, 255.0)).round(),
    ((c.g * 255 * inv).clamp(0.0, 255.0)).round(),
    ((c.b * 255 * inv).clamp(0.0, 255.0)).round(),
  );
}
