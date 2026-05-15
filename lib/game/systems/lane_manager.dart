import 'package:flame/components.dart';

/// Paperboy-style road layout.
///
/// The original arcade feel is closer to a readable top-down / slight
/// perspective street than a hard vanishing-point racer. The road is wide at
/// the player and still clearly visible near the top so intersections,
/// mailboxes, houses, and hazards do not collapse into the horizon.
class LaneManager {
  final Vector2 gameSize;

  LaneManager({required this.gameSize});

  double get H => gameSize.y;
  double get W => gameSize.x;

  double _t(double y) => (y / H).clamp(0.0, 1.0);

  // Top:  27%..73% of screen width.
  // Bottom: 12%..88% of screen width.
  double roadLeftAt(double y) => W * (0.27 - 0.15 * _t(y));
  double roadRightAt(double y) => W * (0.73 + 0.15 * _t(y));
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

  // Player can move from far-left footpath to far-right footpath.
  double get playerMinX => 0;
  double get playerMaxX => W;

  double leftSidewalkRightAt(double y) => roadLeftAt(y);
  double rightSidewalkLeftAt(double y) => roadRightAt(y);
  double scaleAt(double y) => (0.55 + 0.45 * _t(y)).clamp(0.55, 1.0);

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
