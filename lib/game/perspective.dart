/// Pseudo-3D perspective helpers shared by world-space components.
///
/// The road is drawn as a trapezoid that is wider at the bottom than the
/// top. Sprites use these helpers to scale down and pull toward the road
/// centerline as they approach the horizon, faking depth on top of an
/// otherwise flat collision grid.
library;

import 'dart:ui';

/// Trapezoid road half-width factor relative to the flat road, by depth.
///   y / h == 0 (horizon)  → 0.7  (road is 70% as wide as flat)
///   y / h == 1 (foreground) → 1.3 (road is 130% as wide as flat)
const double _roadTopFactor = 0.52;
const double _roadBottomFactor = 1.58;

/// Sprite scale by depth.
///   y / h == 0 → 0.55
///   y / h == 1 → 1.0
const double _scaleTop = 0.55;
const double _scaleBottom = 1.0;

double _t(double y, double h) {
  if (h <= 0) return 1;
  final v = y / h;
  if (v < 0) return 0;
  if (v > 1) return 1;
  return v;
}

/// Depth scale for a sprite whose world center is at [y] on a screen of
/// height [h]. Returns a value in `[scaleTop .. scaleBottom]`.
double depthScale(double y, double h) {
  return _scaleTop + (_scaleBottom - _scaleTop) * _t(y, h);
}

/// Horizontal road-width factor at depth [y] on a screen of height [h].
/// Multiply any X-offset relative to the road center by this value to
/// place it on the visual (trapezoid) road.
double roadWidthFactor(double y, double h) {
  return _roadTopFactor + (_roadBottomFactor - _roadTopFactor) * _t(y, h);
}

/// Returns the extra X translation to apply (in addition to the
/// component's flat world X) so it tracks the trapezoid road.
double depthXShift(double worldX, double y, double roadCenter, double h) {
  final factor = roadWidthFactor(y, h);
  return (worldX - roadCenter) * (factor - 1.0);
}

/// Convenience: apply both X-shift and uniform scale to [canvas]. Assumes
/// the canvas is currently translated so its origin is the component's
/// top-left, and the component has size [size]. The transform is anchored
/// on the component's center. Pass [extraYScale] for an extra vertical
/// squish (e.g. 0.85 to fake a tilted top-down camera).
void applyDepthTransform(
  Canvas canvas, {
  required double worldX,
  required double worldY,
  required double roadCenter,
  required double screenHeight,
  required double sizeX,
  required double sizeY,
  double extraYScale = 1.0,
}) {
  final scale = depthScale(worldY, screenHeight);
  final dx = depthXShift(worldX, worldY, roadCenter, screenHeight);
  canvas.translate(dx, 0);
  canvas.translate(sizeX / 2, sizeY / 2);
  canvas.scale(scale, scale * extraYScale);
  canvas.translate(-sizeX / 2, -sizeY / 2);
}
