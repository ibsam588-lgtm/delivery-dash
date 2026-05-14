import 'dart:ui';
import 'package:flame/components.dart';
import '../delivery_dash_game.dart';

class RoadBackground extends PositionComponent
    with HasGameRef<DeliveryDashGame> {
  static const Color roadColor = Color(0xFF1E1E1E);
  static const Color sidewalkColor = Color(0xFF5C5C5C);
  static const Color sidewalkEdgeColor = Color(0xFF424242);
  static const Color laneLineColor = Color(0xFFF5F5F5);

  static const double _dashLen = 30.0;
  static const double _gapLen = 30.0;
  static const double _cycle = _dashLen + _gapLen;

  final Paint _roadPaint = Paint()..color = roadColor;
  final Paint _sidewalkPaint = Paint()..color = sidewalkColor;
  final Paint _edgePaint = Paint()..color = sidewalkEdgeColor;
  final Paint _linePaint = Paint()
    ..color = laneLineColor
    ..strokeWidth = 4
    ..strokeCap = StrokeCap.square;

  double _dashOffset = 0;

  RoadBackground({required Vector2 gameSize})
      : super(size: gameSize, position: Vector2.zero(), priority: -10);

  @override
  void update(double dt) {
    if (gameRef.state != GameState.playing) return;
    _dashOffset += gameRef.scrollSpeed * dt;
    if (_dashOffset >= _cycle) _dashOffset %= _cycle;
  }

  @override
  void render(Canvas canvas) {
    final w = size.x;
    final h = size.y;
    final lm = gameRef.laneManager;
    final roadLeft = lm.roadLeft;
    final roadRight = lm.roadRight;
    final laneWidth = lm.laneWidth;

    // Sidewalks
    canvas.drawRect(Rect.fromLTWH(0, 0, roadLeft, h), _sidewalkPaint);
    canvas.drawRect(
        Rect.fromLTWH(roadRight, 0, w - roadRight, h), _sidewalkPaint);

    // Inner curb line where sidewalk meets road
    canvas.drawRect(Rect.fromLTWH(roadLeft - 2, 0, 2, h), _edgePaint);
    canvas.drawRect(Rect.fromLTWH(roadRight, 0, 2, h), _edgePaint);

    // Asphalt
    canvas.drawRect(
        Rect.fromLTWH(roadLeft, 0, roadRight - roadLeft, h), _roadPaint);

    // Dashed lane dividers (scrolling downward)
    for (int lane = 1; lane < 3; lane++) {
      final x = roadLeft + lane * laneWidth;
      var y = -_cycle + _dashOffset;
      while (y < h) {
        canvas.drawLine(Offset(x, y), Offset(x, y + _dashLen), _linePaint);
        y += _cycle;
      }
    }
  }
}
