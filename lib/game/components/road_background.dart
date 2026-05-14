import 'dart:ui';
import 'package:flame/components.dart';
import '../delivery_dash_game.dart';

/// Flat top-down road. Sidewalks on both sides, single yellow dashed
/// center line, white curbs. No perspective.
class RoadBackground extends PositionComponent
    with HasGameRef<DeliveryDashGame> {
  static const Color roadColor = Color(0xFF2A2A2A);
  static const Color sidewalkColor = Color(0xFF5B8A3C);
  static const Color sidewalkBandColor = Color(0xFF4A7530);
  static const Color curbColor = Color(0xFFFFFFFF);
  static const Color laneLineColor = Color(0xFFFFD700);

  static const double _dashLen = 40.0;
  static const double _gapLen = 30.0;
  static const double _cycle = _dashLen + _gapLen;
  static const double _bandSpacing = 60.0;

  final Paint _roadPaint = Paint()..color = roadColor;
  final Paint _sidewalkPaint = Paint()..color = sidewalkColor;
  final Paint _sidewalkBandPaint = Paint()..color = sidewalkBandColor;
  final Paint _curbPaint = Paint()..color = curbColor;
  final Paint _linePaint = Paint()
    ..color = laneLineColor
    ..strokeWidth = 5
    ..strokeCap = StrokeCap.square;

  double _dashOffset = 0;
  double _bandOffset = 0;

  RoadBackground({required Vector2 gameSize})
      : super(size: gameSize, position: Vector2.zero(), priority: -10);

  @override
  void update(double dt) {
    if (gameRef.state != GameState.playing) return;
    _dashOffset += gameRef.scrollSpeed * dt;
    if (_dashOffset >= _cycle) _dashOffset %= _cycle;
    _bandOffset += gameRef.scrollSpeed * dt;
    if (_bandOffset >= _bandSpacing) _bandOffset %= _bandSpacing;
  }

  @override
  void render(Canvas canvas) {
    final w = size.x;
    final h = size.y;
    final lm = gameRef.laneManager;
    final roadLeft = lm.roadLeft;
    final roadRight = lm.roadRight;

    // Sidewalks (grass).
    canvas.drawRect(Rect.fromLTWH(0, 0, roadLeft, h), _sidewalkPaint);
    canvas.drawRect(
        Rect.fromLTWH(roadRight, 0, w - roadRight, h), _sidewalkPaint);

    // Horizontal mow bands scrolling.
    var bandY = -_bandSpacing + _bandOffset;
    while (bandY < h) {
      canvas.drawRect(
          Rect.fromLTWH(0, bandY, roadLeft, 4), _sidewalkBandPaint);
      canvas.drawRect(
          Rect.fromLTWH(roadRight, bandY, w - roadRight, 4),
          _sidewalkBandPaint);
      bandY += _bandSpacing;
    }

    // Asphalt.
    canvas.drawRect(
        Rect.fromLTWH(roadLeft, 0, roadRight - roadLeft, h), _roadPaint);

    // White curbs.
    canvas.drawRect(Rect.fromLTWH(roadLeft - 1, 0, 3, h), _curbPaint);
    canvas.drawRect(Rect.fromLTWH(roadRight - 2, 0, 3, h), _curbPaint);

    // Center dashed line (single).
    final centerX = (roadLeft + roadRight) / 2;
    var y = -_cycle + _dashOffset;
    while (y < h) {
      canvas.drawLine(
        Offset(centerX, y),
        Offset(centerX, y + _dashLen),
        _linePaint,
      );
      y += _cycle;
    }
  }
}
