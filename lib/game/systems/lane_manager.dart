import 'package:flame/components.dart';

/// Paperboy-style road layout with a stable road width and readable sidewalks.
///
/// The playfield keeps the road broad enough for clear traffic lanes while
/// preserving enough footpath/yard space for houses, mailboxes, dogs, workers,
/// hydrants, and trash cans. The road edges intentionally do not converge or
/// expand as they move down the screen.
class LaneManager {
  final Vector2 gameSize;

  LaneManager({required this.gameSize});

  double get H => gameSize.y;
  double get W => gameSize.x;

  double _t(double y) => (y / H).clamp(0.0, 1.0);

  static const double _roadLeftFrac = 0.24;
  static const double _roadRightFrac = 0.76;

  double roadLeftAt(double y) => W * _roadLeftFrac;
  double roadRightAt(double y) => W * _roadRightFrac;
  double roadCenterAt(double y) => W * 0.50;
  double roadWidthAt(double y) => roadRightAt(y) - roadLeftAt(y);

  double get _refY => H * 0.85;
  double get roadLeft => roadLeftAt(_refY);
  double get roadRight => roadRightAt(_refY);
  double get roadCenter => W * 0.50;
  double get roadWidth => roadWidthAt(_refY);

  double get leftSidewalkWidth => roadLeft;
  double get rightSidewalkWidth => W - roadRight;
  double get sidewalkWidth => leftSidewalkWidth;

  double get playerMinX => 0;
  double get playerMaxX => W;

  double leftSidewalkRightAt(double y) => roadLeftAt(y);
  double rightSidewalkLeftAt(double y) => roadRightAt(y);
  double sidewalkPlayableWidthAt(double y) => (W * 0.075).clamp(58.0, 94.0);
  double rideableLeftAt(double y) => roadLeftAt(y) - sidewalkPlayableWidthAt(y);
  double rideableRightAt(double y) =>
      roadRightAt(y) + sidewalkPlayableWidthAt(y);
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

  double clampToRideableAt(double y, double x, double halfWidth) {
    final lo = rideableLeftAt(y) + halfWidth;
    final hi = rideableRightAt(y) - halfWidth;
    if (hi < lo) return roadCenterAt(y);
    return x.clamp(lo, hi);
  }
}
