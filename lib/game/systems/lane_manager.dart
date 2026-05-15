import 'package:flame/components.dart';

/// Diagonal isometric road layout — Paperboy perspective.
///
/// The road runs diagonally from lower-left (bottom of screen) toward
/// upper-right (horizon), matching the classic Paperboy arcade look.
///
///   y = gameSize.y (foreground) → road spans [0.04W .. 0.72W], width 0.68W
///   y = 0           (horizon)   → road spans [0.32W .. 0.88W], width 0.56W
///
/// t = 1 − y/H   (0 at bottom, 1 at top)
/// leftFrac(t)  = 0.04 + 0.28·t
/// rightFrac(t) = 0.72 + 0.16·t
class LaneManager {
  final Vector2 gameSize;

  // Diagonal road edge fractions — wider Paperboy-style perspective.
  // Left edge pulled right (0.08) so the left sidewalk has room for a chunky
  // cement footpath; right edge pulled left (0.70) to balance.
  static const double _leftBase = 0.08;
  static const double _leftSlope = 0.22;
  static const double _rightBase = 0.70;
  static const double _rightSlope = 0.12;

  // Reference depth for backward-compat flat getters (≈ player Y fraction).
  static const double _refFrac = 0.82;

  LaneManager({required this.gameSize});

  double _t(double y) => (1.0 - y / gameSize.y).clamp(0.0, 1.0);

  // ── Y-dependent accessors ────────────────────────────────────────────────

  double roadLeftAt(double y) =>
      gameSize.x * (_leftBase + _leftSlope * _t(y));

  double roadRightAt(double y) =>
      gameSize.x * (_rightBase + _rightSlope * _t(y));

  double roadCenterAt(double y) =>
      (roadLeftAt(y) + roadRightAt(y)) * 0.5;

  double roadWidthAt(double y) => roadRightAt(y) - roadLeftAt(y);

  // ── Backward-compat flat getters (evaluated at player reference depth) ───

  double get _refY => gameSize.y * _refFrac;

  double get roadLeft => roadLeftAt(_refY);
  double get roadRight => roadRightAt(_refY);
  double get roadCenter => roadCenterAt(_refY);
  double get roadWidth => roadWidthAt(_refY);

  // ── Sidewalk helpers ─────────────────────────────────────────────────────

  double get leftSidewalkWidth => roadLeft;
  double get rightSidewalkWidth => gameSize.x - roadRight;
  double get sidewalkWidth => leftSidewalkWidth;

  // Player can move from left footpath to right footpath.
  double get playerMinX => 0;
  double get playerMaxX => gameSize.x;

  // ── Compat shims for callers that still pass a Y ─────────────────────────

  double leftSidewalkRightAt(double y) => roadLeftAt(y);
  double rightSidewalkLeftAt(double y) => roadRightAt(y);
  double scaleAt(double y) => 1.0;

  // ── Road fraction mapping ────────────────────────────────────────────────

  /// Map a fraction [0..1] across the road to a world X.
  /// Uses [y] if provided, otherwise the player reference depth.
  double roadXFromFraction(double f, [double? y]) {
    final ry = y ?? _refY;
    return roadLeftAt(ry) + roadWidthAt(ry) * f.clamp(0.0, 1.0);
  }

  // ── Clamping ─────────────────────────────────────────────────────────────

  /// Clamp [x] so a centred object of half-width [halfWidth] stays on road.
  /// Uses the player reference depth.
  double clampToRoad(double x, double halfWidth) =>
      clampToRoadAt(_refY, x, halfWidth);

  double clampToRoadAt(double y, double x, double halfWidth) {
    final lo = roadLeftAt(y) + halfWidth;
    final hi = roadRightAt(y) - halfWidth;
    if (hi < lo) return roadCenterAt(y);
    return x.clamp(lo, hi);
  }
}
