import 'dart:math';
import 'dart:ui';
import 'package:flame/collisions.dart';
import 'package:flame/components.dart';
import 'package:flame/flame.dart';
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

    canvas.restore();

    if (_windowBroken) {
      // Cracks overlay on the windshield area.
      final w = size.x;
      final hh = size.y;
      final cx = w * 0.50;
      final cy = hh * 0.16;
      final crackPaint = Paint()
        ..color = const Color(0xFFE0E0E0)
        ..strokeWidth = 0.9
        ..strokeCap = StrokeCap.round;
      for (int i = 0; i < 8; i++) {
        final ang = i * pi / 4;
        canvas.drawLine(
          Offset(cx, cy),
          Offset(cx + cos(ang) * w * 0.34, cy + sin(ang) * hh * 0.10),
          crackPaint,
        );
      }
    }

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

/// Render a top-down car sprite into a [w]×[h] box. The image is fetched
/// from [Flame.images] (preloaded in `DeliveryDashGame.onLoad`). When
/// [isOncoming] is true the sprite is flipped vertically so the front of
/// the car faces the player.
void renderTopDownCar(
  Canvas canvas,
  double w,
  double h,
  int variant, {
  bool isOncoming = false,
}) {
  final img = Flame.images
      .fromCache('car_${variant % ParkedCarComponent.variantCount}.png');
  final src = Rect.fromLTWH(0, 0, img.width.toDouble(), img.height.toDouble());
  final dst = Rect.fromLTWH(0, 0, w, h);
  if (isOncoming) {
    canvas.save();
    canvas.translate(0, h);
    canvas.scale(1, -1);
    canvas.drawImageRect(img, src, dst, Paint());
    canvas.restore();
  } else {
    canvas.drawImageRect(img, src, dst, Paint());
  }
}
