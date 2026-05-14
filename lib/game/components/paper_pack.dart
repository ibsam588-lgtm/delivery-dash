import 'dart:math';
import 'dart:ui';
import 'package:flame/collisions.dart';
import 'package:flame/components.dart';
import '../delivery_dash_game.dart';
import '../perspective.dart';
import 'player.dart';

/// Bundled newspaper stack pickup. Glows with a pulsing yellow aura.
/// Grants +10 papers when the player rides over it.
class PaperPackComponent extends PositionComponent
    with HasGameRef<DeliveryDashGame>, CollisionCallbacks {
  static const int paperGain = 10;

  final double laneFraction;
  bool _collected = false;
  double _life = 0;

  PaperPackComponent({required this.laneFraction})
      : super(
          size: Vector2(32, 38),
          anchor: Anchor.center,
          priority: 4,
        );

  @override
  Future<void> onLoad() async {
    final lm = gameRef.laneManager;
    position = Vector2(lm.roadXFromFraction(laneFraction), -size.y);
    add(RectangleHitbox(
      size: size * 0.85,
      position: size * 0.075,
      collisionType: CollisionType.passive,
    ));
  }

  @override
  void update(double dt) {
    super.update(dt);
    if (_collected) return;
    _life += dt;
    position.y += gameRef.scrollSpeed * dt;
    if (position.y > gameRef.size.y + size.y) {
      removeFromParent();
    }
  }

  @override
  void render(Canvas canvas) {
    if (_collected) return;
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

    canvas.save();
    canvas.translate(size.x / 2, size.y / 2);
    canvas.scale(s);
    canvas.translate(-size.x / 2, -size.y / 2);

    _renderPack(canvas);

    canvas.restore();
  }

  void _renderPack(Canvas canvas) {
    final w = size.x;
    final h = size.y;

    // Pulsing aura (scale 0.95 ↔ 1.05 over 0.6s).
    final auraPulse = 0.95 + 0.10 * (sin(_life * 2 * pi / 0.6) * 0.5 + 0.5);
    final auraW = w * 1.4 * auraPulse;
    final auraH = h * 1.2 * auraPulse;
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(w / 2, h * 0.55),
        width: auraW,
        height: auraH,
      ),
      Paint()
        ..color = const Color(0x44FFD600)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8),
    );

    // Ground shadow.
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(w / 2, h - 2),
        width: w * 0.80,
        height: 6,
      ),
      Paint()..color = const Color(0x55000000),
    );

    // 3 offset newspaper sheets (stacked slightly).
    for (int i = 2; i >= 0; i--) {
      final ox = i * 2.0;
      final oy = i * 2.5;
      final sheetRect = Rect.fromLTWH(ox, oy, w - ox * 1.5, h * 0.80 - oy);
      final sheetRR = RRect.fromRectAndRadius(sheetRect, const Radius.circular(3));

      // Sheet body (cream/off-white).
      canvas.drawRRect(
        sheetRR,
        Paint()
          ..shader = Gradient.linear(
            sheetRect.topLeft,
            sheetRect.bottomRight,
            [const Color(0xFFF8F4E0), const Color(0xFFE8E0C0)],
          ),
      );

      // Headline stripe.
      canvas.drawRect(
        Rect.fromLTWH(ox + w * 0.06, oy + h * 0.06, w * 0.76, h * 0.10),
        Paint()..color = const Color(0xFF1A1A1A),
      );

      // Outline.
      canvas.drawRRect(
        sheetRR,
        Paint()
          ..color = const Color(0xFF9A8860)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 0.8,
      );
    }

    // Binding string / band across the middle of the stack.
    final bandY = h * 0.38;
    canvas.drawRect(
      Rect.fromLTWH(0, bandY, w, h * 0.08),
      Paint()
        ..shader = Gradient.linear(
          Offset(0, bandY),
          Offset(w, bandY),
          [const Color(0xFFD4A017), const Color(0xFFB8860B), const Color(0xFFD4A017)],
        ),
    );
    // Band knot (small circle at center).
    canvas.drawCircle(
      Offset(w / 2, bandY + h * 0.04),
      3.5,
      Paint()..color = const Color(0xFF8B6914),
    );

    // Bright "+10" label below stack.
    final textPaint = Paint()
      ..color = const Color(0xFFFFD600)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2);
    // Glow hint under label.
    canvas.drawRect(
      Rect.fromLTWH(w * 0.10, h * 0.84, w * 0.80, h * 0.14),
      textPaint,
    );
    // White "+10" indicator strip.
    canvas.drawRect(
      Rect.fromLTWH(w * 0.12, h * 0.85, w * 0.76, h * 0.12),
      Paint()..color = const Color(0xFF1A1A1A),
    );
    canvas.drawRect(
      Rect.fromLTWH(w * 0.18, h * 0.87, w * 0.26, h * 0.07),
      Paint()..color = const Color(0xFFFFFFFF),
    );
    canvas.drawRect(
      Rect.fromLTWH(w * 0.52, h * 0.87, w * 0.30, h * 0.07),
      Paint()..color = const Color(0xFFFFD600),
    );
  }

  @override
  void onCollisionStart(
      Set<Vector2> intersectionPoints, PositionComponent other) {
    super.onCollisionStart(intersectionPoints, other);
    if (_collected) return;
    if (other is PlayerComponent) {
      _collected = true;
      gameRef.onPickupPaperPack(paperGain, position.clone());
      removeFromParent();
    }
  }
}
