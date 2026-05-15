import 'dart:math';
import 'dart:ui';
import 'package:flame/components.dart';
import '../delivery_dash_game.dart';

/// Straight-ahead "Road Rash" style trapezoid road.
/// Wide at the bottom (player), narrow at the top (horizon).
class RoadBackground extends PositionComponent
    with HasGameRef<DeliveryDashGame> {
  // Horizon: 28% down from top.
  static const double _horizonFrac = 0.28;

  // Sky
  static const Color _skyTop = Color(0xFF87CEEB);
  static const Color _skyHorizon = Color(0xFFD4E8C2);

  // Grass / scenery
  static const Color _grassColor = Color(0xFF4CAF50);
  static const Color _grassDark = Color(0xFF388E3C);

  // Footpath (concrete)
  static const Color _footpathColor = Color(0xFFB8BEC4);
  static const Color _footpathEdge = Color(0xFF8A929A);

  // Footpath width at the player depth (scales with perspective via roadLeftAt).
  static const double _footpathWidthBot = 48.0;

  // Asphalt road colours
  static const Color _roadNear = Color(0xFF404040);
  static const Color _roadFar = Color(0xFF707070);

  // Lane markings
  static const Color _laneLineColor = Color(0xFFFFFFFF);
  static const Color _shoulderColor = Color(0xFFE5E5E5);

  static const double _dashLen = 30.0;
  static const double _gapLen = 22.0;
  static const double _cycle = _dashLen + _gapLen;

  double _dashOffset = 0;

  // Horizon silhouette buildings (deterministic).
  final List<_HorizonBuilding> _horizonBuildings = [];

  RoadBackground({required Vector2 gameSize})
      : super(size: gameSize, position: Vector2.zero(), priority: -10) {
    _generateScenery(gameSize);
  }

  void _generateScenery(Vector2 s) {
    final rng = Random(7);
    final w = s.x;
    // Buildings / trees silhouettes along the horizon line.
    double x = 0;
    while (x < w) {
      final isTree = rng.nextBool();
      final bw = isTree
          ? 8.0 + rng.nextDouble() * 6.0
          : 18.0 + rng.nextDouble() * 22.0;
      final bh = isTree
          ? 14.0 + rng.nextDouble() * 14.0
          : 12.0 + rng.nextDouble() * 28.0;
      _horizonBuildings.add(_HorizonBuilding(x, bw, bh, isTree));
      x += bw + 2.0 + rng.nextDouble() * 4.0;
    }
  }

  @override
  void update(double dt) {
    if (gameRef.state != GameState.playing) return;
    _dashOffset += gameRef.scrollSpeed * dt;
    if (_dashOffset >= _cycle) _dashOffset %= _cycle;
  }

  @override
  void render(Canvas canvas) {
    final w = size.x;
    final h = size.y;
    final lm = gameRef.laneManager;
    final horizonY = h * _horizonFrac;

    // ── Sky gradient ──────────────────────────────────────────────────────
    canvas.drawRect(
      Rect.fromLTWH(0, 0, w, horizonY),
      Paint()
        ..shader = Gradient.linear(
          Offset.zero,
          Offset(0, horizonY),
          [_skyTop, _skyHorizon],
        ),
    );

    // ── Horizon silhouette band ──────────────────────────────────────────
    final silhouettePaint = Paint()..color = const Color(0xFF2E3A2F);
    for (final b in _horizonBuildings) {
      if (b.isTree) {
        // Tree silhouette — triangle on a tiny trunk.
        canvas.drawRect(
          Rect.fromLTWH(b.x + b.width * 0.42, horizonY - 2, b.width * 0.16, 2),
          silhouettePaint,
        );
        final path = Path()
          ..moveTo(b.x + b.width / 2, horizonY - b.height)
          ..lineTo(b.x, horizonY - 2)
          ..lineTo(b.x + b.width, horizonY - 2)
          ..close();
        canvas.drawPath(path, silhouettePaint);
      } else {
        canvas.drawRect(
          Rect.fromLTWH(b.x, horizonY - b.height, b.width, b.height),
          silhouettePaint,
        );
        // Window glint.
        if (b.height > 16) {
          canvas.drawRect(
            Rect.fromLTWH(
              b.x + b.width * 0.20,
              horizonY - b.height * 0.6,
              b.width * 0.12,
              2,
            ),
            Paint()..color = const Color(0xFFFFE082),
          );
        }
      }
    }

    // ── Grass everywhere below horizon ────────────────────────────────────
    canvas.drawRect(
      Rect.fromLTWH(0, horizonY, w, h - horizonY),
      Paint()..color = _grassColor,
    );

    // Distant grass — a slightly darker band right at the horizon.
    canvas.drawRect(
      Rect.fromLTWH(0, horizonY, w, 8),
      Paint()..color = _grassDark,
    );

    // ── Geometry ──────────────────────────────────────────────────────────
    final leftBot = lm.roadLeftAt(h);
    final rightBot = lm.roadRightAt(h);
    final leftTop = lm.roadLeftAt(horizonY);
    final rightTop = lm.roadRightAt(horizonY);

    // Footpath widths at top (perspective-scaled) and bottom.
    const fpBot = _footpathWidthBot;
    final fpTop = fpBot * (lm.roadWidthAt(horizonY) / lm.roadWidthAt(h));

    // ── Left footpath (between grass and road left edge) ──────────────────
    final leftFootPath = Path()
      ..moveTo(leftBot - fpBot, h)
      ..lineTo(leftBot, h)
      ..lineTo(leftTop, horizonY)
      ..lineTo(leftTop - fpTop, horizonY)
      ..close();
    canvas.drawPath(leftFootPath, Paint()..color = _footpathColor);
    // Edge lines.
    final edgePaint = Paint()
      ..color = _footpathEdge
      ..strokeWidth = 1.0;
    canvas.drawLine(
      Offset(leftTop - fpTop, horizonY),
      Offset(leftBot - fpBot, h),
      edgePaint,
    );
    canvas.drawLine(
      Offset(leftTop, horizonY),
      Offset(leftBot, h),
      edgePaint,
    );

    // ── Right footpath ────────────────────────────────────────────────────
    final rightFootPath = Path()
      ..moveTo(rightBot, h)
      ..lineTo(rightBot + fpBot, h)
      ..lineTo(rightTop + fpTop, horizonY)
      ..lineTo(rightTop, horizonY)
      ..close();
    canvas.drawPath(rightFootPath, Paint()..color = _footpathColor);
    canvas.drawLine(
      Offset(rightTop, horizonY),
      Offset(rightBot, h),
      edgePaint,
    );
    canvas.drawLine(
      Offset(rightTop + fpTop, horizonY),
      Offset(rightBot + fpBot, h),
      edgePaint,
    );

    // ── Road trapezoid ────────────────────────────────────────────────────
    final roadPath = Path()
      ..moveTo(leftBot, h)
      ..lineTo(rightBot, h)
      ..lineTo(rightTop, horizonY)
      ..lineTo(leftTop, horizonY)
      ..close();
    canvas.drawPath(
      roadPath,
      Paint()
        ..shader = Gradient.linear(
          Offset(0, horizonY),
          Offset(0, h),
          [_roadFar, _roadNear],
        ),
    );

    // ── Road shoulder lines (white edges) ────────────────────────────────
    final shoulderPaint = Paint()
      ..color = _shoulderColor
      ..strokeWidth = 1.4;
    canvas.drawLine(
      Offset(leftTop, horizonY),
      Offset(leftBot, h),
      shoulderPaint,
    );
    canvas.drawLine(
      Offset(rightTop, horizonY),
      Offset(rightBot, h),
      shoulderPaint,
    );

    // ── Dashed centre line ────────────────────────────────────────────────
    // Centre is always at W*0.5 — draw trapezoidal dashes, wider near bottom.
    final centerX = w * 0.5;
    final lanePaint = Paint()..color = _laneLineColor;
    var dy = horizonY - _cycle + _dashOffset;
    while (dy < h) {
      final y1 = dy.clamp(horizonY, h);
      final y2 = (dy + _dashLen).clamp(horizonY, h);
      if (y2 > y1) {
        final t1 = ((y1 - horizonY) / (h - horizonY)).clamp(0.0, 1.0);
        final t2 = ((y2 - horizonY) / (h - horizonY)).clamp(0.0, 1.0);
        final hw1 = 1.0 + 3.5 * t1;
        final hw2 = 1.0 + 3.5 * t2;
        canvas.drawPath(
          Path()
            ..moveTo(centerX - hw1, y1)
            ..lineTo(centerX + hw1, y1)
            ..lineTo(centerX + hw2, y2)
            ..lineTo(centerX - hw2, y2)
            ..close(),
          lanePaint,
        );
      }
      dy += _cycle;
    }

    // ── Distance fade — subtle haze near the horizon ─────────────────────
    canvas.drawRect(
      Rect.fromLTWH(0, horizonY, w, h * 0.10),
      Paint()
        ..shader = Gradient.linear(
          Offset(0, horizonY),
          Offset(0, horizonY + h * 0.10),
          [const Color(0x55D4E8C2), const Color(0x00D4E8C2)],
        ),
    );
  }
}

class _HorizonBuilding {
  final double x;
  final double width;
  final double height;
  final bool isTree;
  _HorizonBuilding(this.x, this.width, this.height, this.isTree);
}
