import 'package:flame/components.dart';

/// Straight-ahead perspective road.
/// Road fans out from a vanishing point at the top toward the player at the
/// bottom.
///
/// At bottom (y = H, player depth):  road spans [0.30W .. 0.70W]  (40% wide)
/// At horizon  (y = H*0.28):         road spans [0.444W .. 0.556W] (11% wide)
///
/// t = y / H   (0 at top, 1 at bottom)
/// leftFrac(t)  = 0.50 - 0.20*t
/// rightFrac(t) = 0.50 + 0.20*t
class LaneManager {
  final Vector2 gameSize;

  LaneManager({required this.gameSize});

  double get H => gameSize.y;
  double get W => gameSize.x;

  double _t(double y) => (y / H).clamp(0.0, 1.0);

  double roadLeftAt(double y) => W * (0.50 - 0.20 * _t(y));
  double roadRightAt(double y) => W * (0.50 + 0.20 * _t(y));
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
  double scaleAt(double y) => _t(y).clamp(0.1, 1.0);

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
