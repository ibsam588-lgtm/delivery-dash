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
    final shadowDx = onRight ? -6.0 : 6.0;
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(poleWidth / 2 + shadowDx, poleHeight - 2),
        width: 26,
        height: 8,
      ),
      Paint()..color = const Color(0x55000000),
    );

    final pole = Paint()
      ..shader = Gradient.linear(
        const Offset(6, 0),
        const Offset(13, 0),
        const [Color(0xFF111315), Color(0xFF4A4D50), Color(0xFF1B1D20)],
        const [0.0, 0.45, 1.0],
      )
      ..strokeWidth = 4.2
      ..strokeCap = StrokeCap.round;
    final basePaint = Paint()..color = const Color(0xFF202326);

    canvas.drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(3, 62, 12, 7),
        const Radius.circular(2),
      ),
      basePaint,
    );
    for (final bx in [5.5, 12.5]) {
      canvas.drawCircle(
          Offset(bx, 65.5), 1.1, Paint()..color = const Color(0xFF73777A));
    }

    final polePath = Path()
      ..moveTo(poleWidth / 2, poleHeight - 7)
      ..lineTo(poleWidth / 2, 22)
      ..quadraticBezierTo(
        poleWidth / 2,
        10,
        onRight ? poleWidth / 2 - 10 : poleWidth / 2 + 10,
        9,
      );
    canvas.drawPath(polePath, pole);

    final armEnd = Offset(onRight ? -4 : poleWidth + 4, 11);
    const armStart = Offset(poleWidth / 2, 16);
    canvas.drawLine(armStart, armEnd, pole);

    final headRect = Rect.fromCenter(
      center: armEnd + Offset(onRight ? -3 : 3, 1),
      width: 18,
      height: 9,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(headRect, const Radius.circular(5)),
      Paint()..color = const Color(0xFF202326),
    );
    final glowCenter = armEnd + Offset(onRight ? -4 : 4, 5);
    canvas.drawOval(
      Rect.fromCenter(center: glowCenter, width: 12, height: 7),
      Paint()..color = const Color(0xFFFFF2A6),
    );
    final conePath = Path()
      ..moveTo(glowCenter.dx - 6, glowCenter.dy)
      ..lineTo(glowCenter.dx + 6, glowCenter.dy)
      ..lineTo(glowCenter.dx + (onRight ? -22 : 22), poleHeight)
      ..lineTo(glowCenter.dx + (onRight ? 6 : -6), poleHeight)
      ..close();
    canvas.drawPath(
      conePath,
      Paint()
        ..shader = Gradient.linear(
          glowCenter,
          Offset(glowCenter.dx, poleHeight),
          [const Color(0x33FFE082), const Color(0x00FFE082)],
        ),
    );
    canvas.drawCircle(
      glowCenter,
      14,
      Paint()
        ..color = const Color(0x33FFE082)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8),
    );
  }
}
