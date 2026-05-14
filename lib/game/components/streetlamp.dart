import 'dart:ui';
import 'package:flame/components.dart';
import '../delivery_dash_game.dart';

/// Pure decoration. Streetlamps sit on the sidewalk and scroll down with
/// the world. They don't collide with anything.
class StreetlampComponent extends PositionComponent
    with HasGameRef<DeliveryDashGame> {
  static const double poleHeight = 70;
  static const double poleWidth = 18;

  final bool onRight;

  StreetlampComponent({required this.onRight})
      : super(
          size: Vector2(poleWidth, poleHeight),
          anchor: Anchor.bottomCenter,
          priority: -4,
        );

  @override
  Future<void> onLoad() async {
    final lm = gameRef.laneManager;
    final x = onRight ? lm.roadRight + 14 : lm.roadLeft - 14;
    position = Vector2(x, -poleHeight);
  }

  @override
  void update(double dt) {
    super.update(dt);
    if (gameRef.state != GameState.playing) return;
    position.y += gameRef.scrollSpeed * dt;
    if (position.y > gameRef.size.y + poleHeight) removeFromParent();
  }

  @override
  void render(Canvas canvas) {
    // Long elliptical shadow trailing toward the road.
    final shadowDx = onRight ? -6.0 : 6.0;
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(poleWidth / 2 + shadowDx, poleHeight - 2),
        width: 26,
        height: 8,
      ),
      Paint()..color = const Color(0x55000000),
    );
    // Pole.
    final pole = Paint()..color = const Color(0xFF2F2F33);
    canvas.drawRect(
      const Rect.fromLTWH(poleWidth / 2 - 2, 14, 4, poleHeight - 14),
      pole,
    );
    // Arm extending over the road.
    const armLen = 16.0;
    const armStartX = poleWidth / 2;
    final armEndX = onRight ? armStartX - armLen : armStartX + armLen;
    canvas.drawRect(
      Rect.fromLTRB(
        armEndX < armStartX ? armEndX : armStartX,
        12,
        armEndX < armStartX ? armStartX : armEndX,
        16,
      ),
      pole,
    );
    // Lamp head.
    final headCenter = Offset(armEndX, 14);
    canvas.drawCircle(
      headCenter,
      6,
      Paint()..color = const Color(0xFFFFE082),
    );
    // Outer glow.
    canvas.drawCircle(
      headCenter,
      11,
      Paint()
        ..color = const Color(0x44FFE082)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6),
    );
  }
}
