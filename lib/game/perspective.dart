/// Pseudo-3D perspective helpers shared by world-space components.
///
/// The road is drawn as a diagonal parallelogram (Paperboy perspective).
/// [depthXShiftDiag] is the primary helper: it maps a sprite's worldX
/// (set at the player reference depth) to the correct visual X at its
/// current render depth y, tracking both the diagonal centre-line shift
/// and the convergence of road width toward the horizon.
library;

import 'dart:ui';

// ── Legacy trapezoid factors (kept for any callers that still use them) ─────

const double _roadTopFactor = 0.52;
const double _roadBottomFactor = 1.58;

double _t(double y, double h) {
  if (h <= 0) return 1;
  final v = y / h;
  if (v < 0) return 0;
  if (v > 1) return 1;
  return v;
}

/// Depth scale — sprites appear small at the horizon and full-size at the
/// player's reference depth (~78% down the screen).
///   y == 0.28*H (horizon): scale = 0.15  (tiny, in the distance)
///   y == 0.78*H (player):  scale = 1.00  (full size)
double depthScale(double y, double h) {
  if (h <= 0) return 1.0;
  final t = ((y - h * 0.28) / (h * 0.50)).clamp(0.0, 1.0);
  return 0.15 + 0.85 * t;
}

/// Legacy road-width factor (kept for backward compat).
double roadWidthFactor(double y, double h) =>
    _roadTopFactor + (_roadBottomFactor - _roadTopFactor) * _t(y, h);

/// Legacy single-centre-line depth X shift (kept for backward compat).
double depthXShift(
    double worldX, double y, double roadCenter, double h) {
  final factor = roadWidthFactor(y, h);
  return (worldX - roadCenter) * (factor - 1.0);
}

/// Legacy convenience transform (kept for backward compat).
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

// ── Diagonal road depth shift ─────────────────────────────────────────────

/// Maps worldX (set at the player reference depth) to the correct
/// visual X-offset for rendering at depth [y].
///
/// [leftRef] / [widthRef] = road left edge and width at the reference depth.
/// [leftY]  / [widthY]   = road left edge and width at render depth y.
///
/// Returns the amount to translate the canvas horizontally before drawing.
double depthXShiftDiag({
  required double worldX,
  required double leftRef,
  required double widthRef,
  required double leftY,
  required double widthY,
}) {
  if (widthRef <= 0) return leftY - leftRef;
  final leftDelta = leftY - leftRef;
  final widthRatio = widthY / widthRef;
  return leftDelta + (worldX - leftRef) * (widthRatio - 1.0);
}
