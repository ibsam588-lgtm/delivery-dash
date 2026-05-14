import 'package:flame/components.dart';

/// Pseudo-3D road perspective.
///
/// Y = 0 is at the top (vanishing point), Y = gameSize.y at the bottom.
/// The road widens linearly from the top toward the bottom.
class LaneManager {
  final Vector2 gameSize;

  // Road bounds as fractions of screen width at top (vp) and bottom.
  static const double topLeftFrac = 0.35;
  static const double topRightFrac = 0.65;
  static const double bottomLeftFrac = 0.15;
  static const double bottomRightFrac = 0.85;

  // Scale factors at the vanishing point and at the bottom.
  static const double minScale = 0.35;
  static const double maxScale = 1.0;

  LaneManager({required this.gameSize});

  /// 0 (top) .. 1 (bottom).
  double _depthT(double y) => (y / gameSize.y).clamp(0.0, 1.0);

  double scaleAt(double y) {
    final t = _depthT(y);
    return minScale + (maxScale - minScale) * t;
  }

  double roadLeftAt(double y) {
    final t = _depthT(y);
    return gameSize.x * (topLeftFrac + (bottomLeftFrac - topLeftFrac) * t);
  }

  double roadRightAt(double y) {
    final t = _depthT(y);
    return gameSize.x * (topRightFrac + (bottomRightFrac - topRightFrac) * t);
  }

  double roadCenterAt(double y) =>
      (roadLeftAt(y) + roadRightAt(y)) / 2;

  double roadWidthAt(double y) => roadRightAt(y) - roadLeftAt(y);

  /// Convenience: bottom-screen bounds. Used by code that just wants
  /// "what counts as on the road" near the player.
  double get roadLeft => roadLeftAt(gameSize.y);
  double get roadRight => roadRightAt(gameSize.y);
  double get roadCenter => roadCenterAt(gameSize.y);
  double get roadWidth => roadWidthAt(gameSize.y);

  // Left sidewalk spans 0..roadLeftAt(y) at any Y.
  double leftSidewalkRightAt(double y) => roadLeftAt(y);
  // Right sidewalk spans roadRightAt(y)..gameSize.x at any Y.
  double rightSidewalkLeftAt(double y) => roadRightAt(y);

  double get leftSidewalkWidth => roadLeftAt(gameSize.y);
  double get rightSidewalkWidth =>
      gameSize.x - roadRightAt(gameSize.y);

  /// X within the road from a normalized fraction f in [0..1] (0=left edge).
  double roadXFromFraction(double f, double y) {
    return roadLeftAt(y) + roadWidthAt(y) * f.clamp(0.0, 1.0);
  }

  /// Clamp a world X so a centered object of half-width [halfWidth]
  /// stays fully on the road at the given Y.
  double clampToRoadAt(double y, double x, double halfWidth) {
    final lo = roadLeftAt(y) + halfWidth;
    final hi = roadRightAt(y) - halfWidth;
    if (hi < lo) return roadCenterAt(y);
    return x.clamp(lo, hi);
  }

  /// Alias used by older callers, evaluated at the bottom (player row).
  double clampToRoad(double x, double halfWidth) =>
      clampToRoadAt(gameSize.y, x, halfWidth);

  // Backwards-compat alias.
  double get sidewalkWidth => leftSidewalkWidth;
}
