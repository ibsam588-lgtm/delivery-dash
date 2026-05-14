import 'dart:math';
import 'dart:ui';
import 'package:flame/components.dart';
import '../delivery_dash_game.dart';

/// Diagonal isometric road background — classic Paperboy perspective.
///
/// The road is drawn as a diagonal parallelogram that runs from the
/// lower-left foreground toward the upper-right horizon, matching the
/// original 1984 arcade look.
class RoadBackground extends PositionComponent
    with HasGameRef<DeliveryDashGame> {
  static const Color _skyTop = Color(0xFF87CEEB);
  static const Color _skyHorizon = Color(0xFFDDF0FF);
  static const Color _grassBase = Color(0xFF3A7D3A);
  static const Color _grassDash = Color(0xFF2D6B2D);
  static const Color _sidewalkColor = Color(0xFFC8B89A);
  static const Color _sidewalkShadow = Color(0xFFB8A080);
  static const Color _roadColor = Color(0xFF272727);
  static const Color _curbColor = Color(0xFFEEEEEE);
  static const Color _laneLineColor = Color(0xFFFFD700);

  static const double _dashLen = 44.0;
  static const double _gapLen = 28.0;
  static const double _cycle = _dashLen + _gapLen;
  static const double _sidewalkW = 22.0;

  final Paint _grassPaint = Paint()..color = _grassBase;
  final Paint _sidewalkPaint = Paint()..color = _sidewalkColor;
  final Paint _roadPaint = Paint()..color = _roadColor;
  final Paint _curbPaint = Paint()..color = _curbColor;

  double _dashOffset = 0;

  final List<Offset> _grassDashes = [];
  final List<Offset> _gravelDots = [];

  RoadBackground({required Vector2 gameSize})
      : super(size: gameSize, position: Vector2.zero(), priority: -10) {
    _generateTextures(gameSize);
  }

  void _generateTextures(Vector2 s) {
    final rng = Random(42);
    for (int i = 0; i < 420; i++) {
      _grassDashes.add(Offset(rng.nextDouble() * s.x, rng.nextDouble() * s.y));
    }
    // Gravel dots scattered inside the road bounds.
    for (int i = 0; i < 220; i++) {
      _gravelDots.add(Offset(
        s.x * (0.20 + rng.nextDouble() * 0.65),
        rng.nextDouble() * s.y,
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

    // Road corners (diagonal parallelogram).
    final leftBot = lm.roadLeftAt(h);
    final rightBot = lm.roadRightAt(h);
    final leftTop = lm.roadLeftAt(0);
    final rightTop = lm.roadRightAt(0);
    final centerBot = lm.roadCenterAt(h);
    final centerTop = lm.roadCenterAt(0);

    // ── 1. Sky gradient (top 10%) ────────────────────────────────────────
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

    // ── 2. Grass base ────────────────────────────────────────────────────
    canvas.drawRect(Rect.fromLTWH(0, skyH, w, h - skyH), _grassPaint);

    // ── 3. Grass texture dashes ──────────────────────────────────────────
    final dashPaint = Paint()
      ..color = _grassDash
      ..strokeWidth = 2.0
      ..strokeCap = StrokeCap.square;
    for (final p in _grassDashes) {
      final len = 5.0 + (p.dx * 0.0313 % 4);
      canvas.drawLine(p, Offset(p.dx + len, p.dy), dashPaint);
    }

    // ── 4. Left sidewalk (parallelogram strip) ───────────────────────────
    canvas.drawPath(
      Path()
        ..moveTo(leftBot - _sidewalkW, h)
        ..lineTo(leftBot, h)
        ..lineTo(leftTop, 0)
        ..lineTo(leftTop - _sidewalkW, 0)
        ..close(),
      _sidewalkPaint,
    );
    // Sidewalk inner shadow (3 px strip against the road).
    canvas.drawPath(
      Path()
        ..moveTo(leftBot - 3, h)
        ..lineTo(leftBot, h)
        ..lineTo(leftTop, 0)
        ..lineTo(leftTop - 3, 0)
        ..close(),
      Paint()..color = _sidewalkShadow,
    );

    // ── 5. Right sidewalk ────────────────────────────────────────────────
    canvas.drawPath(
      Path()
        ..moveTo(rightBot, h)
        ..lineTo(rightBot + _sidewalkW, h)
        ..lineTo(rightTop + _sidewalkW, 0)
        ..lineTo(rightTop, 0)
        ..close(),
      _sidewalkPaint,
    );
    canvas.drawPath(
      Path()
        ..moveTo(rightBot, h)
        ..lineTo(rightBot + 3, h)
        ..lineTo(rightTop + 3, 0)
        ..lineTo(rightTop, 0)
        ..close(),
      Paint()..color = _sidewalkShadow,
    );

    // ── 6. Road parallelogram ─────────────────────────────────────────────
    final road = Path()
      ..moveTo(leftBot, h)
      ..lineTo(rightBot, h)
      ..lineTo(rightTop, 0)
      ..lineTo(leftTop, 0)
      ..close();
    canvas.drawPath(road, _roadPaint);

    // ── 7. Gravel texture (clipped to road) ───────────────────────────────
    canvas.save();
    canvas.clipPath(road);
    final gravelPaint = Paint()
      ..color = const Color(0x3C404040)
      ..strokeWidth = 1.4
      ..strokeCap = StrokeCap.round;
    for (final p in _gravelDots) {
      // Only draw dots that fall inside the road parallelogram by checking X.
      final t = (1.0 - p.dy / h).clamp(0.0, 1.0);
      final rLeft = leftBot + (leftTop - leftBot) * t;
      final rRight = rightBot + (rightTop - rightBot) * t;
      if (p.dx >= rLeft && p.dx <= rRight) {
        canvas.drawCircle(p, 1.2, gravelPaint);
      }
    }
    canvas.restore();

    // ── 8. White curbs ────────────────────────────────────────────────────
    // Left curb.
    canvas.drawPath(
      Path()
        ..moveTo(leftBot - 1, h)
        ..lineTo(leftBot + 2, h)
        ..lineTo(leftTop + 2, 0)
        ..lineTo(leftTop - 1, 0)
        ..close(),
      _curbPaint,
    );
    canvas.drawPath(
      Path()
        ..moveTo(leftBot + 2, h)
        ..lineTo(leftBot + 4, h)
        ..lineTo(leftTop + 4, 0)
        ..lineTo(leftTop + 2, 0)
        ..close(),
      Paint()..color = const Color(0xFF999999),
    );
    // Right curb.
    canvas.drawPath(
      Path()
        ..moveTo(rightBot - 2, h)
        ..lineTo(rightBot + 1, h)
        ..lineTo(rightTop + 1, 0)
        ..lineTo(rightTop - 2, 0)
        ..close(),
      _curbPaint,
    );
    canvas.drawPath(
      Path()
        ..moveTo(rightBot - 4, h)
        ..lineTo(rightBot - 2, h)
        ..lineTo(rightTop - 2, 0)
        ..lineTo(rightTop - 4, 0)
        ..close(),
      Paint()..color = const Color(0xFF999999),
    );

    // ── 9. Centre-lane dashes (follow diagonal road centre) ───────────────
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
        final hw1 = 1.5 + 3.0 * (y1 / h); // tapers toward horizon
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

    // ── 10. Tyre tracks ───────────────────────────────────────────────────
    final trackPaint = Paint()
      ..color = const Color(0x22000000)
      ..strokeWidth = 3.0;
    for (final frac in const [0.33, 0.67]) {
      final xBot = leftBot + (rightBot - leftBot) * frac;
      final xTop = leftTop + (rightTop - leftTop) * frac;
      canvas.drawLine(Offset(xTop, 0), Offset(xBot, h), trackPaint);
    }

    // ── 11. Grass tufts at road edges ─────────────────────────────────────
    final tuftPaint = Paint()
      ..color = const Color(0xFF4A9A3A)
      ..strokeWidth = 1.8
      ..strokeCap = StrokeCap.round;
    final rng2 = Random(99);
    for (int i = 0; i < 26; i++) {
      final yPos = h * i / 26.0;
      final lEdge = lm.roadLeftAt(yPos);
      final rEdge = lm.roadRightAt(yPos);
      final tuftH = 4.0 + rng2.nextDouble() * 4;
      final lx = lEdge - 2.0 - rng2.nextDouble() * 5;
      canvas.drawLine(Offset(lx, yPos), Offset(lx, yPos - tuftH), tuftPaint);
      final rx = rEdge + 2.0 + rng2.nextDouble() * 5;
      canvas.drawLine(Offset(rx, yPos), Offset(rx, yPos - tuftH), tuftPaint);
    }

    // ── 12. Horizon depth fade ────────────────────────────────────────────
    final horizonRect = Rect.fromLTRB(leftTop - 10, 0, rightTop + 10, h * 0.22);
    canvas.drawRect(
      horizonRect,
      Paint()
        ..shader = Gradient.linear(
          horizonRect.topCenter,
          horizonRect.bottomCenter,
          [const Color(0xFF0A0C12), const Color(0x002A2A2A)],
        ),
    );

    // ── 13. Atmospheric haze (blends sky into road at horizon) ───────────
    canvas.drawRect(
      Rect.fromLTWH(0, 0, w, h * 0.18),
      Paint()
        ..shader = Gradient.linear(
          Offset.zero,
          Offset(0, h * 0.18),
          [const Color(0x22B3E5FC), const Color(0x00FFFFFF)],
        ),
    );

    // ── 14. Bottom vignette ───────────────────────────────────────────────
    final vigRect = Rect.fromLTWH(0, h * 0.80, w, h * 0.20);
    canvas.drawRect(
      vigRect,
      Paint()
        ..shader = Gradient.linear(
          vigRect.topCenter,
          vigRect.bottomCenter,
          [const Color(0x00000000), const Color(0x55000000)],
        ),
    );
  }
}
