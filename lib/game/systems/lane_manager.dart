import 'package:flame/components.dart';

/// Paperboy-style road layout with larger yards and sidewalks.
///
/// The mockup has a readable central road, generous sidewalks, gardens, and
/// side houses. This layout narrows the driveable road so cars stay in lanes
/// and the side art has enough room to look intentional.
class LaneManager {
  final Vector2 gameSize;

  LaneManager({required this.gameSize});

  double get H => gameSize.y;
  double get W => gameSize.x;

  double _t(double y) => (y / H).clamp(0.0, 1.0);

  // Top:  35%..65% of screen width.
  // Bottom: 21%..79% of screen width.
  double roadLeftAt(double y) => W * (0.35 - 0.14 * _t(y));
  double roadRightAt(double y) => W * (0.65 + 0.14 * _t(y));
  double roadCenterAt(double y) => W * 0.50;
  double roadWidthAt(double y) => roadRightAt(y) - roadLeftAt(y);

  // Player reference depth ~85% down.
  double get _refY => H * 0.85;
  double get roadLeft => roadLeftAt(_refY);
  double get roadRight => roadRightAt(_refY);
  double get roadCenter => W * 0.50;
  double get roadWidth => roadWidthAt(_refY);

  double get leftSidewalkWidth => roadLeft;
  double get rightSidewalkWidth => W - roadRight;
  double get sidewalkWidth => leftSidewalkWidth;

  // Player can still reach both sides for mailbox throws, but cars clamp to road.
  double get playerMinX => 0;
  double get playerMaxX => W;

  double leftSidewalkRightAt(double y) => roadLeftAt(y);
  double rightSidewalkLeftAt(double y) => roadRightAt(y);
  double scaleAt(double y) => (0.58 + 0.42 * _t(y)).clamp(0.58, 1.0);

  double roadXFromFraction(double f, [double? y]) {
    final ry = y ?? _refY;
    return roadLeftAt(ry) + roadWidthAt(ry) * f.clamp(0.0, 1.0);
  }

  double clampToRoad(double x, double halfWidth) =>
      clampToRoadAt(_refY, x, halfWidth);

  double clampToRoadAt(double y, double x, double halfWidth) {
    final lo = roadLeftAt(y) + halfWidth;
    final hi = roadRightAt(y) - halfWidth;
    if (hi < lo) return roadCenterAt(y);
    return x.clamp(lo, hi);
  }
}
