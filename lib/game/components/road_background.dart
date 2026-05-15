import 'dart:math';
import 'dart:ui';
import 'package:flame/components.dart';
import '../delivery_dash_game.dart';

/// Rich Paperboy-style diagonal road, sidewalks, sky and grass.
class RoadBackground extends PositionComponent
    with HasGameRef<DeliveryDashGame> {
  // Sky
  static const Color _skyTop = Color(0xFFB0BEC5);
  static const Color _skyHorizon = Color(0xFFF5E6C8);

  // Grass / sidewalk
  static const Color _grassBase = Color(0xFF4CAF50);
  static const Color _grassDark = Color(0xFF388E3C);
  static const Color _cementColor = Color(0xFFB8C0C8);
  static const Color _cementShadow = Color(0xFF8A929A);

  // Road
  static const Color _roadColor = Color(0xFF5A5A5A);
  static const Color _roadPebble = Color(0xFF646464);
  static const Color _curbColor = Color(0xFFFFFFFF);
  static const Color _laneLineColor = Color(0xFFFFFFFF);

  static const double _dashLen = 40.0;
  static const double _gapLen = 30.0;
  static const double _cycle = _dashLen + _gapLen;
  static const double _cementStripWidth = 40.0;

  final Paint _roadPaint = Paint()..color = _roadColor;
  final Paint _grassPaint = Paint()..color = _grassBase;
  final Paint _cementPaint = Paint()..color = _cementColor;

  double _dashOffset = 0;

  final List<Offset> _pebbles = [];
  final List<_GrassPatch> _grassPatches = [];

  RoadBackground({required Vector2 gameSize})
      : super(size: gameSize, position: Vector2.zero(), priority: -10) {
    _generateTextures(gameSize);
  }

  void _generateTextures(Vector2 s) {
    final rng = Random(42);
    // Pebbles scattered across road area.
    for (int i = 0; i < 260; i++) {
      _pebbles.add(Offset(
        s.x * (0.02 + rng.nextDouble() * 0.86),
        rng.nextDouble() * s.y,
      ));
    }
    // Darker grass patches scattered over sidewalks.
    for (int i = 0; i < 90; i++) {
      _grassPatches.add(_GrassPatch(
        Offset(rng.nextDouble() * s.x, rng.nextDouble() * s.y),
        6.0 + rng.nextDouble() * 12.0,
      ));
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

    final leftBot = lm.roadLeftAt(h);
    final rightBot = lm.roadRightAt(h);
    final leftTop = lm.roadLeftAt(0);
    final rightTop = lm.roadRightAt(0);
    final centerBot = lm.roadCenterAt(h);
    final centerTop = lm.roadCenterAt(0);

    // ── Sky gradient (top 10%) ────────────────────────────────────────────
    final skyH = h * 0.10;
    canvas.drawRect(
      Rect.fromLTWH(0, 0, w, skyH),
      Paint()
        ..shader = Gradient.linear(
          Offset.zero,
          Offset(0, skyH),
          [_skyTop, _skyHorizon],
        ),
    );

    // ── Grass everywhere below sky ───────────────────────────────────────
    canvas.drawRect(Rect.fromLTWH(0, skyH, w, h - skyH), _grassPaint);

    // Darker patches scattered.
    final patchPaint = Paint()..color = _grassDark;
    for (final patch in _grassPatches) {
      if (patch.center.dy < skyH) continue;
      canvas.drawOval(
        Rect.fromCenter(
            center: patch.center,
            width: patch.radius,
            height: patch.radius * 0.6),
        patchPaint,
      );
    }

    // ── Left cement footpath (curb side of left grass) ───────────────────
    canvas.drawPath(
      Path()
        ..moveTo(leftBot - _cementStripWidth, h)
        ..lineTo(leftBot, h)
        ..lineTo(leftTop, 0)
        ..lineTo(leftTop - _cementStripWidth, 0)
        ..close(),
      _cementPaint,
    );
    // Darker edge line on the OUTER side (grass side) of the cement.
    canvas.drawLine(
      Offset(leftTop - _cementStripWidth, 0),
      Offset(leftBot - _cementStripWidth, h),
      Paint()
        ..color = _cementShadow
        ..strokeWidth = 1.6,
    );
    // Darker edge line on the INNER side (road side) of the cement.
    canvas.drawLine(
      Offset(leftTop, 0),
      Offset(leftBot, h),
      Paint()
        ..color = _cementShadow
        ..strokeWidth = 1.6,
    );

    // ── Right cement footpath ────────────────────────────────────────────
    canvas.drawPath(
      Path()
        ..moveTo(rightBot, h)
        ..lineTo(rightBot + _cementStripWidth, h)
        ..lineTo(rightTop + _cementStripWidth, 0)
        ..lineTo(rightTop, 0)
        ..close(),
      _cementPaint,
    );
    canvas.drawLine(
      Offset(rightTop, 0),
      Offset(rightBot, h),
      Paint()
        ..color = _cementShadow
        ..strokeWidth = 1.6,
    );
    canvas.drawLine(
      Offset(rightTop + _cementStripWidth, 0),
      Offset(rightBot + _cementStripWidth, h),
      Paint()
        ..color = _cementShadow
        ..strokeWidth = 1.6,
    );

    // ── Road parallelogram ────────────────────────────────────────────────
    final roadPath = Path()
      ..moveTo(leftBot, h)
      ..lineTo(rightBot, h)
      ..lineTo(rightTop, 0)
      ..lineTo(leftTop, 0)
      ..close();
    canvas.drawPath(roadPath, _roadPaint);

    // ── Asphalt pebble texture ────────────────────────────────────────────
    canvas.save();
    canvas.clipPath(roadPath);
    final pebblePaint = Paint()..color = _roadPebble;
    for (final p in _pebbles) {
      final t = (1.0 - p.dy / h).clamp(0.0, 1.0);
      final rLeft = leftBot + (leftTop - leftBot) * t;
      final rRight = rightBot + (rightTop - rightBot) * t;
      if (p.dx >= rLeft && p.dx <= rRight) {
        canvas.drawCircle(p, 1.2, pebblePaint);
      }
    }
    canvas.restore();

    // ── Curb (1px bright white at road edges) ─────────────────────────────
    final curbPaint = Paint()
      ..color = _curbColor
      ..strokeWidth = 1.2;
    canvas.drawLine(Offset(leftTop, 0), Offset(leftBot, h), curbPaint);
    canvas.drawLine(Offset(rightTop, 0), Offset(rightBot, h), curbPaint);

    // ── Subtle tyre tracks (slightly darker lines on road) ────────────────
    final trackPaint = Paint()
      ..color = const Color(0x22000000)
      ..strokeWidth = 3.0;
    for (final frac in const [0.32, 0.68]) {
      final xBot = leftBot + (rightBot - leftBot) * frac;
      final xTop = leftTop + (rightTop - leftTop) * frac;
      canvas.drawLine(Offset(xTop, 0), Offset(xBot, h), trackPaint);
    }

    // ── Dashed centre line (follows diagonal, tilts with road angle) ──────
    final lanePaint = Paint()..color = _laneLineColor;
    var dy = -_cycle + _dashOffset;
    while (dy < h) {
      final y1 = dy.clamp(0.0, h);
      final y2 = (dy + _dashLen).clamp(0.0, h);
      if (y2 > y1) {
        final t1 = (1.0 - y1 / h).clamp(0.0, 1.0);
        final t2 = (1.0 - y2 / h).clamp(0.0, 1.0);
        final cx1 = centerBot + (centerTop - centerBot) * t1;
        final cx2 = centerBot + (centerTop - centerBot) * t2;
        final hw1 = 1.5 + 3.0 * (y1 / h);
        final hw2 = 1.5 + 3.0 * (y2 / h);
        canvas.drawPath(
          Path()
            ..moveTo(cx1 - hw1, y1)
            ..lineTo(cx1 + hw1, y1)
            ..lineTo(cx2 + hw2, y2)
            ..lineTo(cx2 - hw2, y2)
            ..close(),
          lanePaint,
        );
      }
      dy += _cycle;
    }

    // ── Horizon depth fade ───────────────────────────────────────────────
    final horizonRect = Rect.fromLTRB(leftTop - 12, 0, rightTop + 12, h * 0.20);
    canvas.drawRect(
      horizonRect,
      Paint()
        ..shader = Gradient.linear(
          horizonRect.topCenter,
          horizonRect.bottomCenter,
          [const Color(0x55505050), const Color(0x00505050)],
        ),
    );

    // ── Bottom vignette for ground contact ────────────────────────────────
    final vigRect = Rect.fromLTWH(0, h * 0.85, w, h * 0.15);
    canvas.drawRect(
      vigRect,
      Paint()
        ..shader = Gradient.linear(
          vigRect.topCenter,
          vigRect.bottomCenter,
          [const Color(0x00000000), const Color(0x44000000)],
        ),
    );
  }
}

class _GrassPatch {
  final Offset center;
  final double radius;
  _GrassPatch(this.center, this.radius);
}
