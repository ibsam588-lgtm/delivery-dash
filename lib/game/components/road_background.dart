import 'dart:ui';
import 'package:flame/components.dart';
import '../delivery_dash_game.dart';

class RoadBackground extends PositionComponent with HasGameRef<DeliveryDashGame> {
  final _roadPaint = Paint()..color = const Color(0xFF555555);
  final _grassPaint = Paint()..color = const Color(0xFF4CAF50);
  final _sidewalkPaint = Paint()..color = const Color(0xFFBCAAA4);
  final _linePaint = Paint()
    ..color = const Color(0xFFFFFFFF)
    ..strokeWidth = 3
    ..strokeCap = StrokeCap.round;

  double _lineOffset = 0;

  RoadBackground({required Vector2 gameSize})
      : super(size: gameSize, position: Vector2.zero());

  @override
  void update(double dt) {
    if (gameRef.state != GameState.playing) return;
    _lineOffset += gameRef.scrollSpeed * dt;
    if (_lineOffset > 60) _lineOffset -= 60;
  }

  @override
  void render(Canvas canvas) {
    final w = size.x;
    final h = size.y;
    final lm = gameRef.laneManager;
    final roadLeft = lm.roadLeft;
    final roadRight = lm.roadRight;
    final laneWidth = lm.laneWidth;

    // Grass strips
    canvas.drawRect(Rect.fromLTWH(0, 0, roadLeft, h), _grassPaint);
    canvas.drawRect(Rect.fromLTWH(roadRight, 0, w - roadRight, h), _grassPaint);

    // Sidewalk
    const sidewalkW = 10.0;
    canvas.drawRect(Rect.fromLTWH(roadLeft - sidewalkW, 0, sidewalkW, h), _sidewalkPaint);
    canvas.drawRect(Rect.fromLTWH(roadRight, 0, sidewalkW, h), _sidewalkPaint);

    // Road surface
    canvas.drawRect(Rect.fromLTWH(roadLeft, 0, roadRight - roadLeft, h), _roadPaint);

    // Dashed lane dividers
    for (int lane = 1; lane < 3; lane++) {
      final x = roadLeft + lane * laneWidth;
      var y = -60.0 + _lineOffset;
      while (y < h) {
        canvas.drawLine(Offset(x, y), Offset(x, y + 30), _linePaint);
        y += 60;
      }
    }
  }
}
