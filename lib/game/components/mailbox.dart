import 'dart:ui';
import 'package:flame/collisions.dart';
import 'package:flame/components.dart';
import '../delivery_dash_game.dart';

class MailboxComponent extends PositionComponent
    with HasGameRef<DeliveryDashGame>, CollisionCallbacks {
  final bool isBlue;

  MailboxComponent({required this.isBlue})
      : super(
          size: Vector2(48, 72),
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

    // Subtle aura/glow behind mailbox so it's easy to spot.
    final glowColor = isBlue
        ? const Color(0x66BBDEFB)
        : const Color(0x66FFCDD2);
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(w / 2, h * 0.42),
        width: w * 1.35,
        height: h * 0.75,
      ),
      Paint()..color = glowColor,
    );

    // Ground shadow.
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(w / 2, h - 2),
        width: w * 0.85,
        height: 8,
      ),
      Paint()..color = const Color(0x77000000),
    );

    // Post.
    canvas.drawRect(
      Rect.fromLTWH(w * 0.44, h * 0.55, w * 0.12, h * 0.42),
      Paint()..color = const Color(0xFF4A4A4A),
    );

    // Body colour (vivid).
    final boxColor =
        isBlue ? const Color(0xFF1E88E5) : const Color(0xFFE53935);
    final boxHighlight =
        isBlue ? const Color(0xFF42A5F5) : const Color(0xFFEF5350);

    final boxRect = Rect.fromLTWH(w * 0.06, h * 0.16, w * 0.88, h * 0.42);
    // Dome (upper half).
    canvas.drawOval(
      Rect.fromLTWH(w * 0.06, h * 0.16, w * 0.88, h * 0.28),
      Paint()..color = boxHighlight,
    );
    // Rectangular lower half.
    canvas.drawRect(
      Rect.fromLTWH(w * 0.06, h * 0.30, w * 0.88, h * 0.28),
      Paint()..color = boxColor,
    );

    // Outline.
    canvas.drawRRect(
      RRect.fromRectAndCorners(
        boxRect,
        topLeft: const Radius.circular(10),
        topRight: const Radius.circular(10),
      ),
      Paint()
        ..color = const Color(0xFF1A1A1A)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5,
    );

    // Mail slot.
    canvas.drawRect(
      Rect.fromLTWH(w * 0.20, h * 0.40, w * 0.60, h * 0.05),
      Paint()..color = const Color(0xFF111111),
    );

    // Bold letter on body — "USPS"-style mark to make it obvious.
    final markPaint = Paint()..color = const Color(0xFFFAFAFA);
    canvas.drawRect(
      Rect.fromLTWH(w * 0.30, h * 0.48, w * 0.40, h * 0.04),
      markPaint,
    );

    // Shine highlight on dome.
    canvas.drawOval(
      Rect.fromLTWH(w * 0.18, h * 0.18, w * 0.24, h * 0.08),
      Paint()..color = const Color(0x66FFFFFF),
    );

    // Flag — only on BLUE (good) mailbox: white flag raised.
    if (isBlue) {
      // Flag pole.
      canvas.drawRect(
        Rect.fromLTWH(w * 0.84, h * 0.22, w * 0.05, h * 0.18),
        Paint()..color = const Color(0xFF555555),
      );
      // White flag.
      canvas.drawRect(
        Rect.fromLTWH(w * 0.84, h * 0.20, w * 0.14, h * 0.08),
        Paint()..color = const Color(0xFFFAFAFA),
      );
      canvas.drawRect(
        Rect.fromLTWH(w * 0.84, h * 0.20, w * 0.14, h * 0.08),
        Paint()
          ..color = const Color(0xFF222222)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 0.8,
      );
    } else {
      // Red mailbox: warning X marking instead of a flag.
      final xPaint = Paint()
        ..color = const Color(0xFFFAFAFA)
        ..strokeWidth = 2.5;
      canvas.drawLine(
        Offset(w * 0.32, h * 0.22),
        Offset(w * 0.48, h * 0.36),
        xPaint,
      );
      canvas.drawLine(
        Offset(w * 0.48, h * 0.22),
        Offset(w * 0.32, h * 0.36),
        xPaint,
      );
    }
  }
}
