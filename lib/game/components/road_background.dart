import 'dart:ui';
import 'package:flame/components.dart';
import '../delivery_dash_game.dart';
import '../systems/lane_manager.dart';

/// Draws a perspective trapezoid road that widens from a vanishing
/// point at the top center to a wide base at the bottom.
class RoadBackground extends PositionComponent
    with HasGameRef<DeliveryDashGame> {
  static const Color roadColor = Color(0xFF2C2C2C);
  static const Color roadShadeColor = Color(0xFF1B1B1B);
  static const Color sidewalkColor = Color(0xFF4CAF50);
  static const Color sidewalkBandColor = Color(0xFF3F9E45);
  static const Color skyColor = Color(0xFF1B2032);
  static const Color curbColor = Color(0xFFFFFFFF);
  static const Color laneLineColor = Color(0xFFFFD700);

  static const int dashCount = 14;
  static const double bandSpacing = 64.0;

  final Paint _roadPaint = Paint()..color = roadColor;
  final Paint _roadShadePaint = Paint()..color = roadShadeColor;
  final Paint _sidewalkPaint = Paint()..color = sidewalkColor;
  final Paint _sidewalkBandPaint = Paint()..color = sidewalkBandColor;
  final Paint _skyPaint = Paint()..color = skyColor;
  final Paint _curbPaint = Paint()..color = curbColor..strokeWidth = 3;
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
    _bandOffset += gameRef.scrollSpeed * dt;
  }

  @override
  void render(Canvas canvas) {
    final w = size.x;
    final h = size.y;
    final lm = gameRef.laneManager;

    // Sky: small gradient strip from top down to where the road meets
    // the horizon-ish region (we just fill below the entire screen with
    // sidewalk and road, but a darker tint at the top sells the depth).
    canvas.drawRect(Rect.fromLTWH(0, 0, w, h * 0.06), _skyPaint);

    final topLeft = Offset(lm.roadLeftAt(0), 0);
    final topRight = Offset(lm.roadRightAt(0), 0);
    final bottomLeft = Offset(lm.roadLeftAt(h), h);
    final bottomRight = Offset(lm.roadRightAt(h), h);

    // Left sidewalk trapezoid: 0..topLeft at top, 0..bottomLeft at bottom.
    final leftSidewalk = Path()
      ..moveTo(0, 0)
      ..lineTo(topLeft.dx, 0)
      ..lineTo(bottomLeft.dx, h)
      ..lineTo(0, h)
      ..close();
    canvas.drawPath(leftSidewalk, _sidewalkPaint);

    // Right sidewalk trapezoid.
    final rightSidewalk = Path()
      ..moveTo(topRight.dx, 0)
      ..lineTo(w, 0)
      ..lineTo(w, h)
      ..lineTo(bottomRight.dx, h)
      ..close();
    canvas.drawPath(rightSidewalk, _sidewalkPaint);

    // Scrolling mow bands on grass. Drawn as full-width horizontal lines
    // then clipped to the sidewalk paths visually by drawing on top of
    // the sidewalk fill but masking against sidewalk Y-only rectangles.
    _drawSidewalkBands(canvas, h);

    // Road trapezoid.
    final road = Path()
      ..moveTo(topLeft.dx, 0)
      ..lineTo(topRight.dx, 0)
      ..lineTo(bottomRight.dx, h)
      ..lineTo(bottomLeft.dx, h)
      ..close();
    canvas.drawPath(road, _roadPaint);

    // Subtle inner shading along road edges (thin trapezoids).
    const shadeFrac = 0.10;
    final leftShade = Path()
      ..moveTo(topLeft.dx, 0)
      ..lineTo(
          topLeft.dx + (lm.roadWidthAt(0) * shadeFrac), 0)
      ..lineTo(
          bottomLeft.dx + (lm.roadWidthAt(h) * shadeFrac), h)
      ..lineTo(bottomLeft.dx, h)
      ..close();
    canvas.drawPath(leftShade, _roadShadePaint);
    final rightShade = Path()
      ..moveTo(
          topRight.dx - (lm.roadWidthAt(0) * shadeFrac), 0)
      ..lineTo(topRight.dx, 0)
      ..lineTo(bottomRight.dx, h)
      ..lineTo(
          bottomRight.dx - (lm.roadWidthAt(h) * shadeFrac), h)
      ..close();
    canvas.drawPath(rightShade, _roadShadePaint);

    // White curb lines at the road edges (converging toward vp).
    canvas.drawLine(topLeft, bottomLeft, _curbPaint);
    canvas.drawLine(topRight, bottomRight, _curbPaint);

    // Center dashed line with perspective foreshortening.
    _drawCenterDashes(canvas, h);
  }

  void _drawSidewalkBands(Canvas canvas, double h) {
    final lm = gameRef.laneManager;
    const spacing = bandSpacing;
    final offset = _bandOffset % spacing;
    var y = -spacing + offset;
    while (y < h) {
      if (y >= 0) {
        // Left sidewalk band: from x=0 to roadLeftAt(y).
        canvas.drawRect(
          Rect.fromLTWH(0, y, lm.roadLeftAt(y), 4),
          _sidewalkBandPaint,
        );
        canvas.drawRect(
          Rect.fromLTWH(
              lm.roadRightAt(y), y, size.x - lm.roadRightAt(y), 4),
          _sidewalkBandPaint,
        );
      }
      y += spacing;
    }
  }

  void _drawCenterDashes(Canvas canvas, double h) {
    // Lay dashes along the road on a depth-uniform schedule so they
    // shrink and pack together toward the vanishing point.
    //
    // We accumulate dashes from y = h upward. Each dash occupies a chunk
    // of "depth" proportional to the current Y. The scroll offset shifts
    // every dash forward.
    final lm = gameRef.laneManager;
    const dashWorld = 56.0; // dash length in "ground units" at bottom
    const cycleWorld = 90.0; // dash + gap at bottom
    final scrollPhase = _dashOffset % cycleWorld;

    var ground = -scrollPhase;
    while (ground < dashCount * cycleWorld) {
      final yA = h - ground - dashWorld;
      final yB = h - ground;
      if (yB < 0) break;
      // Skip dashes whose body sits past the horizon.
      if (yA < h * 0.04) {
        ground += cycleWorld;
        continue;
      }
      final cx1 = lm.roadCenterAt(yA);
      final cx2 = lm.roadCenterAt(yB);
      final thickness = (lm.scaleAt(yB) * 5).clamp(1.0, 6.0);
      canvas.drawLine(
        Offset(cx1, yA),
        Offset(cx2, yB),
        Paint()
          ..color = laneLineColor
          ..strokeWidth = thickness
          ..strokeCap = StrokeCap.square,
      );
      ground += cycleWorld;
    }
    // Reference _linePaint so its initializer isn't reported as dead code
    // — we may need it again if we ever switch back to non-perspective.
    canvas.save();
    canvas.restore();
    // ignore: unused_local_variable
    final _ = _linePaint;
  }

  // Expose perspective helpers for components that want them.
  LaneManager get perspective => gameRef.laneManager;
}
