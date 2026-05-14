import 'dart:math';
import 'dart:ui';
import 'package:flame/components.dart';
import '../delivery_dash_game.dart';
import '../perspective.dart';

class RoadBackground extends PositionComponent
    with HasGameRef<DeliveryDashGame> {
  static const Color _grassBase = Color(0xFF3A7D3A);
  static const Color _grassDash = Color(0xFF2D6B2D);
  static const Color _sidewalkColor = Color(0xFFC8B89A);
  static const Color _sidewalkShadow = Color(0xFFB8A888);
  static const Color _roadColor = Color(0xFF2A2A2A);
  static const Color _curbColor = Color(0xFFFFFFFF);
  static const Color _laneLineColor = Color(0xFFFFD700);

  static const double _dashLen = 40.0;
  static const double _gapLen = 30.0;
  static const double _cycle = _dashLen + _gapLen;
  static const double _sidewalkW = 22.0;

  final Paint _grassPaint = Paint()..color = _grassBase;
  final Paint _sidewalkPaint = Paint()..color = _sidewalkColor;
  final Paint _roadPaint = Paint()..color = _roadColor;
  final Paint _curbPaint = Paint()..color = _curbColor;
  final Paint _linePaint = Paint()
    ..color = _laneLineColor
    ..strokeWidth = 5
    ..strokeCap = StrokeCap.square;

  double _dashOffset = 0;

  // Pre-generated texture positions (created once in constructor).
  final List<Offset> _grassDashes = [];
  final List<Offset> _gravelDots = [];

  RoadBackground({required Vector2 gameSize})
      : super(size: gameSize, position: Vector2.zero(), priority: -10) {
    _generateTextures(gameSize);
  }

  void _generateTextures(Vector2 s) {
    final rng = Random(42);
    // Grass dashes — scattered across full screen, drawn before road.
    for (int i = 0; i < 380; i++) {
      _grassDashes.add(Offset(
        rng.nextDouble() * s.x,
        rng.nextDouble() * s.y,
      ));
    }
    // Gravel dots — in a band near road centre; clipPath will trim to road.
    final cx = s.x * 0.5;
    final rw = s.x * 0.55;
    for (int i = 0; i < 200; i++) {
      _gravelDots.add(Offset(
        cx + (rng.nextDouble() - 0.5) * rw,
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

  double _roadLeftAt(double y) {
    final lm = gameRef.laneManager;
    return lm.roadCenter - lm.roadWidth / 2 * roadWidthFactor(y, size.y);
  }

  double _roadRightAt(double y) {
    final lm = gameRef.laneManager;
    return lm.roadCenter + lm.roadWidth / 2 * roadWidthFactor(y, size.y);
  }

  @override
  void render(Canvas canvas) {
    final w = size.x;
    final h = size.y;

    // 1. Fill with grass.
    canvas.drawRect(Rect.fromLTWH(0, 0, w, h), _grassPaint);

    // 2. Grass texture dashes (short horizontal strokes, darker green).
    final dashPaint = Paint()
      ..color = _grassDash
      ..strokeWidth = 2.0
      ..strokeCap = StrokeCap.square;
    for (final p in _grassDashes) {
      final len = 5.0 + (p.dx * 0.0313 % 4);
      canvas.drawLine(p, Offset(p.dx + len, p.dy), dashPaint);
    }

    final leftTop = _roadLeftAt(0);
    final rightTop = _roadRightAt(0);
    final leftBot = _roadLeftAt(h);
    final rightBot = _roadRightAt(h);

    // 3. Concrete sidewalk strips (just outside curbs).
    final sLeftPath = Path()
      ..moveTo(leftTop - _sidewalkW, 0)
      ..lineTo(leftTop, 0)
      ..lineTo(leftBot, h)
      ..lineTo(leftBot - _sidewalkW, h)
      ..close();
    canvas.drawPath(sLeftPath, _sidewalkPaint);
    // Sidewalk inner shadow strip.
    canvas.drawPath(
      Path()
        ..moveTo(leftTop - 3, 0)
        ..lineTo(leftTop, 0)
        ..lineTo(leftBot, h)
        ..lineTo(leftBot - 3, h)
        ..close(),
      Paint()..color = _sidewalkShadow,
    );

    final sRightPath = Path()
      ..moveTo(rightTop, 0)
      ..lineTo(rightTop + _sidewalkW, 0)
      ..lineTo(rightBot + _sidewalkW, h)
      ..lineTo(rightBot, h)
      ..close();
    canvas.drawPath(sRightPath, _sidewalkPaint);
    canvas.drawPath(
      Path()
        ..moveTo(rightTop, 0)
        ..lineTo(rightTop + 3, 0)
        ..lineTo(rightBot + 3, h)
        ..lineTo(rightBot, h)
        ..close(),
      Paint()..color = _sidewalkShadow,
    );

    // 4. Trapezoidal asphalt road.
    final road = Path()
      ..moveTo(leftTop, 0)
      ..lineTo(rightTop, 0)
      ..lineTo(rightBot, h)
      ..lineTo(leftBot, h)
      ..close();
    canvas.drawPath(road, _roadPaint);

    // 5. Gravel texture dots on road (clipped to road shape).
    canvas.save();
    canvas.clipPath(road);
    final gravelPaint = Paint()
      ..color = const Color(0x44404040)
      ..strokeWidth = 1.5
      ..strokeCap = StrokeCap.round;
    for (final p in _gravelDots) {
      canvas.drawCircle(p, 1.2, gravelPaint);
    }
    canvas.restore();

    // 6. Horizon haze (depth fade at top of road).
    final horizonRect = Rect.fromLTRB(leftTop, 0, rightTop, h * 0.35);
    canvas.drawRect(
      horizonRect,
      Paint()
        ..shader = Gradient.linear(
          horizonRect.topCenter,
          horizonRect.bottomCenter,
          [const Color(0xFF0A0C12), const Color(0x002A2A2A)],
        ),
    );

    // 7. White curbs — 3px wide, with a grey inner-shadow line.
    void drawCurb(Path pathWhite, Path pathShadow) {
      canvas.drawPath(pathWhite, _curbPaint);
      canvas.drawPath(
        pathShadow,
        Paint()..color = const Color(0xFF888888),
      );
    }

    final curbLeftWhite = Path()
      ..moveTo(leftTop - 1, 0)
      ..lineTo(leftTop + 2, 0)
      ..lineTo(leftBot + 2, h)
      ..lineTo(leftBot - 1, h)
      ..close();
    final curbLeftShadow = Path()
      ..moveTo(leftTop + 2, 0)
      ..lineTo(leftTop + 4, 0)
      ..lineTo(leftBot + 4, h)
      ..lineTo(leftBot + 2, h)
      ..close();
    drawCurb(curbLeftWhite, curbLeftShadow);

    final curbRightWhite = Path()
      ..moveTo(rightTop - 2, 0)
      ..lineTo(rightTop + 1, 0)
      ..lineTo(rightBot + 1, h)
      ..lineTo(rightBot - 2, h)
      ..close();
    final curbRightShadow = Path()
      ..moveTo(rightTop - 4, 0)
      ..lineTo(rightTop - 2, 0)
      ..lineTo(rightBot - 2, h)
      ..lineTo(rightBot - 4, h)
      ..close();
    drawCurb(curbRightWhite, curbRightShadow);

    // 8. Center lane markings — yellow dashes + thin white centre stripe.
    final cx = gameRef.laneManager.roadCenter;
    var y = -_cycle + _dashOffset;
    while (y < h) {
      canvas.drawLine(Offset(cx, y), Offset(cx, y + _dashLen), _linePaint);
      y += _cycle;
    }
    // Thin white stripe between dashes for realism.
    y = -_cycle + _dashOffset + _dashLen;
    while (y < h) {
      canvas.drawLine(
        Offset(cx, y),
        Offset(cx, y + _gapLen),
        Paint()
          ..color = const Color(0x33FFFFFF)
          ..strokeWidth = 1.0,
      );
      y += _cycle;
    }

    // 9. Bottom vignette to anchor the foreground.
    final vignette = Rect.fromLTWH(0, h * 0.75, w, h * 0.25);
    canvas.drawRect(
      vignette,
      Paint()
        ..shader = Gradient.linear(
          vignette.topCenter,
          vignette.bottomCenter,
          [const Color(0x00000000), const Color(0x55000000)],
        ),
    );
  }
}
