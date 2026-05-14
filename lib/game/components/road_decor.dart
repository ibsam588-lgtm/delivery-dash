import 'dart:math';
import 'dart:ui';
import 'package:flame/components.dart';
import '../delivery_dash_game.dart';

enum RoadDecorType { puddle, leaf }

Vector2 _sizeForDecor(RoadDecorType t) =>
    t == RoadDecorType.puddle ? Vector2(42, 20) : Vector2(13, 9);

class RoadDecorComponent extends PositionComponent
    with HasGameRef<DeliveryDashGame> {
  final RoadDecorType decorType;
  final Color _leafColor;
  final double _leafAngle;

  RoadDecorComponent({
    required this.decorType,
    required Vector2 position,
    Color? leafColor,
    double leafAngle = 0,
  })  : _leafColor = leafColor ?? const Color(0xFFD84315),
        _leafAngle = leafAngle,
        super(
          size: _sizeForDecor(decorType),
          anchor: Anchor.center,
          position: position,
          priority: -3,
        );

  @override
  void update(double dt) {
    super.update(dt);
    if (gameRef.state != GameState.playing) return;
    position.y += gameRef.scrollSpeed * dt;
    if (position.y > gameRef.size.y + 60) removeFromParent();
  }

  @override
  void render(Canvas canvas) {
    switch (decorType) {
      case RoadDecorType.puddle:
        _renderPuddle(canvas);
      case RoadDecorType.leaf:
        _renderLeaf(canvas);
    }
  }

  void _renderPuddle(Canvas canvas) {
    final w = size.x;
    final h = size.y;
    // Semi-transparent puddle body.
    canvas.drawOval(
      Rect.fromLTWH(0, 0, w, h),
      Paint()..color = const Color(0x5542A5F5),
    );
    // Darker border.
    canvas.drawOval(
      Rect.fromLTWH(0, 0, w, h),
      Paint()
        ..color = const Color(0x3329B6F6)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.0,
    );
    // Reflective white highlight arc.
    canvas.drawArc(
      Rect.fromLTWH(w * 0.12, h * 0.12, w * 0.44, h * 0.60),
      -pi * 0.75,
      pi * 0.55,
      false,
      Paint()
        ..color = const Color(0x77FFFFFF)
        ..strokeWidth = 1.8
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round,
    );
  }

  void _renderLeaf(Canvas canvas) {
    canvas.save();
    canvas.translate(size.x / 2, size.y / 2);
    canvas.rotate(_leafAngle);

    final sx = size.x / 2;
    final sy = size.y / 2;

    final leafPath = Path()
      ..moveTo(0, -sy)
      ..cubicTo(sx, -sy * 0.4, sx, sy * 0.4, 0, sy)
      ..cubicTo(-sx, sy * 0.4, -sx, -sy * 0.4, 0, -sy);
    canvas.drawPath(leafPath, Paint()..color = _leafColor);

    // Centre vein.
    canvas.drawLine(
      Offset(0, -sy * 0.7),
      Offset(0, sy * 0.7),
      Paint()
        ..color = _leafColor.withValues(alpha: 0.6)
        ..strokeWidth = 0.8
        ..strokeCap = StrokeCap.round,
    );

    canvas.restore();
  }
}
