import 'package:flame/components.dart';
import 'package:flutter/painting.dart';
import '../delivery_dash_game.dart';
import '../perspective.dart';

/// Pseudo-3D top-down road. The road itself is rendered as a trapezoid
/// (narrow at the top, wide at the bottom) to fake depth. Collisions and
/// gameplay still use a flat road strip via LaneManager — components apply
/// the same perspective transform when they draw, so visuals stay aligned
/// with hitboxes.
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

  final Paint _sidewalkPaint = Paint()..color = sidewalkColor;
  final Paint _sidewalkBandPaint = Paint()..color = sidewalkBandColor;
  final Paint _roadPaint = Paint()..color = roadColor;
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

  /// Trapezoid road edges at depth [y]. The shape narrows toward the
  /// horizon at the top of the screen.
  double _roadLeftAt(double y) {
    final lm = gameRef.laneManager;
    final cx = lm.roadCenter;
    final halfFlat = lm.roadWidth / 2;
    final f = roadWidthFactor(y, size.y);
    return cx - halfFlat * f;
  }

  double _roadRightAt(double y) {
    final lm = gameRef.laneManager;
    final cx = lm.roadCenter;
    final halfFlat = lm.roadWidth / 2;
    final f = roadWidthFactor(y, size.y);
    return cx + halfFlat * f;
  }

  @override
  void render(Canvas canvas) {
    final w = size.x;
    final h = size.y;

    // Fill the whole frame with grass first; the trapezoid road is
    // drawn on top.
    canvas.drawRect(Rect.fromLTWH(0, 0, w, h), _sidewalkPaint);

    // Horizontal mow bands scrolling on the grass.
    var bandY = -_bandSpacing + _bandOffset;
    while (bandY < h) {
      canvas.drawRect(Rect.fromLTWH(0, bandY, w, 4), _sidewalkBandPaint);
      bandY += _bandSpacing;
    }

    // Trapezoidal asphalt.
    final leftTop = _roadLeftAt(0);
    final rightTop = _roadRightAt(0);
    final leftBot = _roadLeftAt(h);
    final rightBot = _roadRightAt(h);

    final road = Path()
      ..moveTo(leftTop, 0)
      ..lineTo(rightTop, 0)
      ..lineTo(rightBot, h)
      ..lineTo(leftBot, h)
      ..close();
    canvas.drawPath(road, _roadPaint);

    // Horizon haze near the top of the road for added depth.
    final horizonRect = Rect.fromLTRB(leftTop, 0, rightTop, h * 0.35);
    canvas.drawRect(
      horizonRect,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF0A0C12), Color(0x002A2A2A)],
        ).createShader(horizonRect),
    );

    // White curbs along the trapezoid edges.
    final curbLeft = Path()
      ..moveTo(leftTop - 1, 0)
      ..lineTo(leftTop + 2, 0)
      ..lineTo(leftBot + 2, h)
      ..lineTo(leftBot - 1, h)
      ..close();
    final curbRight = Path()
      ..moveTo(rightTop - 2, 0)
      ..lineTo(rightTop + 1, 0)
      ..lineTo(rightBot + 1, h)
      ..lineTo(rightBot - 2, h)
      ..close();
    canvas.drawPath(curbLeft, _curbPaint);
    canvas.drawPath(curbRight, _curbPaint);

    // Center dashed line follows the trapezoid centerline (vertical,
    // since the center is the same X at top and bottom).
    final cx = gameRef.laneManager.roadCenter;
    var y = -_cycle + _dashOffset;
    while (y < h) {
      canvas.drawLine(
        Offset(cx, y),
        Offset(cx, y + _dashLen),
        _linePaint,
      );
      y += _cycle;
    }

    // Bottom vignette to anchor the foreground.
    final vignette = Rect.fromLTWH(0, h * 0.75, w, h * 0.25);
    canvas.drawRect(
      vignette,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0x00000000), Color(0x55000000)],
        ).createShader(vignette),
    );
  }
}
