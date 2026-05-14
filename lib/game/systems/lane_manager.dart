import 'package:flame/components.dart';

/// Flat top-down road layout.
///
/// No perspective. Road is a fixed-width vertical strip at 25%-75% of
/// screen width. Sidewalks fill the rest on each side. All Y-related
/// helpers ignore Y because the layout doesn't change with depth.
class LaneManager {
  final Vector2 gameSize;

  static const double roadLeftFrac = 0.25;
  static const double roadRightFrac = 0.75;

  LaneManager({required this.gameSize});

  double get roadLeft => gameSize.x * roadLeftFrac;
  double get roadRight => gameSize.x * roadRightFrac;
  double get roadWidth => roadRight - roadLeft;
  double get roadCenter => roadLeft + roadWidth / 2;

  double get leftSidewalkWidth => roadLeft;
  double get rightSidewalkWidth => gameSize.x - roadRight;

  /// Compatibility shims for callers that still pass a Y.
  double roadLeftAt(double y) => roadLeft;
  double roadRightAt(double y) => roadRight;
  double roadCenterAt(double y) => roadCenter;
  double roadWidthAt(double y) => roadWidth;
  double scaleAt(double y) => 1.0;
  double leftSidewalkRightAt(double y) => roadLeft;
  double rightSidewalkLeftAt(double y) => roadRight;

  /// Map a fraction in [0..1] across the road to a world X.
  double roadXFromFraction(double f, [double? y]) {
    return roadLeft + roadWidth * f.clamp(0.0, 1.0);
  }

  /// Clamp [x] so a centered object of half-width [halfWidth] stays
  /// fully on the road.
  double clampToRoad(double x, double halfWidth) {
    final lo = roadLeft + halfWidth;
    final hi = roadRight - halfWidth;
    if (hi < lo) return roadCenter;
    return x.clamp(lo, hi);
  }

  double clampToRoadAt(double y, double x, double halfWidth) =>
      clampToRoad(x, halfWidth);

  // Backwards-compat aliases (older code referenced these).
  double get sidewalkWidth => leftSidewalkWidth;
}
