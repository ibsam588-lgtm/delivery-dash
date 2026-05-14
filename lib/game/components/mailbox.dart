import 'dart:ui';
import 'package:flame/collisions.dart';
import 'package:flame/components.dart';
import '../delivery_dash_game.dart';

class MailboxComponent extends PositionComponent
    with HasGameRef<DeliveryDashGame>, CollisionCallbacks {
  final bool isBlue;

  MailboxComponent({required this.isBlue})
      : super(
          size: Vector2(40, 60),
          anchor: Anchor.center,
          priority: 4,
        );

  @override
  Future<void> onLoad() async {
    add(RectangleHitbox(
      size: size * 0.85,
      position: size * 0.075,
      collisionType: CollisionType.passive,
    ));
  }

  @override
  void render(Canvas canvas) {
    final w = size.x;
    final h = size.y;

    // Ground shadow.
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(w / 2, h - 2),
        width: w * 0.8,
        height: 7,
      ),
      Paint()..color = const Color(0x66000000),
    );

    // Post.
    canvas.drawRect(
      Rect.fromLTWH(w * 0.44, h * 0.52, w * 0.12, h * 0.45),
      Paint()..color = const Color(0xFF4A4A4A),
    );

    // Box body — a rounded rectangle with a domed top half.
    final boxColor = isBlue ? const Color(0xFF1565C0) : const Color(0xFFD32F2F);
    final boxHighlight = isBlue ? const Color(0xFF1E88E5) : const Color(0xFFEF5350);

    final boxRect = Rect.fromLTWH(w * 0.08, h * 0.18, w * 0.84, h * 0.38);
    // Draw dome (upper half) as an ellipse.
    canvas.drawOval(
      Rect.fromLTWH(w * 0.08, h * 0.18, w * 0.84, h * 0.26),
      Paint()..color = boxHighlight,
    );
    // Draw rectangular lower half of body.
    canvas.drawRect(
      Rect.fromLTWH(w * 0.08, h * 0.31, w * 0.84, h * 0.25),
      Paint()..color = boxColor,
    );

    // Box outline.
    canvas.drawRRect(
      RRect.fromRectAndCorners(
        boxRect,
        topLeft: const Radius.circular(8),
        topRight: const Radius.circular(8),
      ),
      Paint()
        ..color = const Color(0xFF222222)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.2,
    );

    // Mail slot.
    canvas.drawRect(
      Rect.fromLTWH(w * 0.22, h * 0.40, w * 0.56, h * 0.045),
      Paint()..color = const Color(0xFF111111),
    );

    // Flag (red, raised).
    canvas.drawRect(
      Rect.fromLTWH(w * 0.82, h * 0.24, w * 0.06, h * 0.15),
      Paint()..color = const Color(0xFF555555),
    );
    canvas.drawRect(
      Rect.fromLTWH(w * 0.82, h * 0.22, w * 0.14, h * 0.07),
      Paint()..color = const Color(0xFFE53935),
    );

    // Shine highlight on dome.
    canvas.drawOval(
      Rect.fromLTWH(w * 0.18, h * 0.20, w * 0.22, h * 0.08),
      Paint()..color = const Color(0x44FFFFFF),
    );
  }
}
