import 'package:flame/components.dart';

/// Road layout for the Paperboy-style view.
///
/// Screen width is split into:
///   0–30%  left sidewalk (houses + driveways)
///   30–80% road (50% width)
///   80–100% right sidewalk (obstacles only)
///
/// Players move freely along X within the road bounds.
class LaneManager {
  final Vector2 gameSize;

  static const double leftSidewalkFraction = 0.30;
  static const double rightSidewalkFraction = 0.20;

  LaneManager({required this.gameSize});

  double get leftSidewalkWidth => gameSize.x * leftSidewalkFraction;
  double get rightSidewalkWidth => gameSize.x * rightSidewalkFraction;
  double get roadLeft => leftSidewalkWidth;
  double get roadRight => gameSize.x - rightSidewalkWidth;
  double get roadWidth => roadRight - roadLeft;
  double get roadCenter => roadLeft + roadWidth / 2;

  /// Alias retained for compatibility — refers to the left (house-side) walk.
  double get sidewalkWidth => leftSidewalkWidth;

  /// Clamp a world X so a centered object of half-width [halfWidth]
  /// stays fully within the road bounds.
  double clampToRoad(double x, double halfWidth) {
    final lo = roadLeft + halfWidth;
    final hi = roadRight - halfWidth;
    if (hi < lo) return roadCenter;
    return x.clamp(lo, hi);
  }
}
