import 'dart:math';
import 'dart:ui';
import 'package:flame/components.dart';
import '../delivery_dash_game.dart';
import '../difficulty.dart';

/// Continuous Paperboy-style suburban street background.
///
/// This intentionally removes the distant front-facing city strip/horizon
/// houses that made the road look like it ended. The scene now stays as one
/// continuous scrolling road with sidewalks and grass on both sides.
class RoadBackground extends PositionComponent
    with HasGameRef<DeliveryDashGame> {
  static const double _topFrac = 0.10;

  static const Color _skyTop = Color(0xFF74D5FF);
  static const Color _skyHorizon = Color(0xFFC8F0C2);
  static const Color _grassLight = Color(0xFF68CE5B);
  static const Color _grassDark = Color(0xFF2F9E44);
  static const Color _sidewalk = Color(0xFFD7D0C1);
  static const Color _sidewalkLine = Color(0xFF948D80);
  static const Color _curb = Color(0xFFF5F1E5);
  static const Color _roadNear = Color(0xFF202426);
  static const Color _roadFar = Color(0xFF30383A);
  static const Color _laneLine = Color(0xFFF8F6E8);

  static const double _dashLen = 38.0;
  static const double _gapLen = 34.0;
  static const double _cycle = _dashLen + _gapLen;

  double _dashOffset = 0;

  RoadBackground({required Vector2 gameSize})
      : super(size: gameSize, position: Vector2.zero(), priority: -10);

  @override
  void update(double dt) {
    super.update(dt);
    if (gameRef.state != GameState.playing) return;
    _dashOffset = (_dashOffset + gameRef.scrollSpeed * dt) % _cycle;
  }

  @override
  void render(Canvas canvas) {
    final w = size.x;
    final h = size.y;
    final lm = gameRef.laneManager;
    final topY = h * _topFrac;
    final isCity = gameRef.config.zone == RouteZone.city;

    _drawSimpleSky(canvas, w, topY, isCity: isCity);

    canvas.drawRect(
      Rect.fromLTWH(0, topY, w, h - topY),
      Paint()
        ..shader = Gradient.linear(
          Offset(0, topY),
          Offset(0, h),
          isCity
              ? [const Color(0xFF9FA8A3), const Color(0xFF59615D)]
              : [_grassLight, _grassDark],
        ),
    );
    if (isCity) _drawCityPavementTexture(canvas, w, topY, h);

    final leftBot = lm.roadLeftAt(h);
    final rightBot = lm.roadRightAt(h);
    final leftTop = lm.roadLeftAt(topY);
    final rightTop = lm.roadRightAt(topY);

    final sidewalkW =
        (w * (isCity ? 0.075 : 0.060)).clamp(58.0, 94.0).toDouble();
    _drawSidewalk(canvas, leftTop - sidewalkW, leftTop, leftBot - sidewalkW,
        leftBot, topY, h, true);
    _drawSidewalk(canvas, rightTop, rightTop + sidewalkW, rightBot,
        rightBot + sidewalkW, topY, h, false);

    final roadPath = Path()
      ..moveTo(leftBot, h)
      ..lineTo(rightBot, h)
      ..lineTo(rightTop, topY)
      ..lineTo(leftTop, topY)
      ..close();

    canvas.drawPath(
      roadPath,
      Paint()
        ..shader = Gradient.linear(
          Offset(0, topY),
          Offset(0, h),
          [_roadFar, _roadNear],
        ),
    );

    _drawAsphaltTexture(
        canvas, roadPath, leftTop, rightTop, leftBot, rightBot, topY, h);
    _drawCurbs(canvas, leftTop, rightTop, leftBot, rightBot, topY, h);
    _drawCenterLine(canvas, w, topY, h);
    if (isCity) {
      _drawCityRoadDetails(
          canvas, leftTop, rightTop, leftBot, rightBot, topY, h);
    }
  }

  void _drawSimpleSky(Canvas canvas, double w, double topY,
      {required bool isCity}) {
    canvas.drawRect(
      Rect.fromLTWH(0, 0, w, topY),
      Paint()
        ..shader = Gradient.linear(
          Offset.zero,
          Offset(0, topY),
          isCity
              ? [const Color(0xFF8DDCFF), const Color(0xFFD7E6EC)]
              : [_skyTop, _skyHorizon],
        ),
    );
    if (isCity) {
      final buildingPaints = [
        const Color(0xFF263238),
        const Color(0xFF37474F),
        const Color(0xFF455A64),
      ];
      for (int i = 0; i < 12; i++) {
        final bw = 62.0 + (i % 4) * 15.0;
        final bh = topY * (0.62 + (i % 5) * 0.16);
        final x = i * 86.0 - 18;
        final rect = Rect.fromLTWH(x, topY - bh, bw, bh);
        canvas.drawRect(rect, Paint()..color = buildingPaints[i % 3]);
        final lit = Paint()..color = const Color(0xFFFFF59D);
        for (double wy = rect.top + 8; wy < rect.bottom - 6; wy += 13) {
          for (double wx = rect.left + 7; wx < rect.right - 6; wx += 14) {
            if (((wx + wy + i) % 3) < 1.4) {
              canvas.drawRect(Rect.fromLTWH(wx, wy, 5, 6), lit);
            }
          }
        }
      }
    }
  }

  void _drawSidewalk(Canvas canvas, double topOuter, double topInner,
      double botOuter, double botInner, double topY, double botY, bool left) {
    final path = Path()
      ..moveTo(botOuter, botY)
      ..lineTo(botInner, botY)
      ..lineTo(topInner, topY)
      ..lineTo(topOuter, topY)
      ..close();
    final isCity = gameRef.config.zone == RouteZone.city;
    canvas.drawPath(
        path, Paint()..color = isCity ? const Color(0xFFB8B9B2) : _sidewalk);

    final edge = Paint()
      ..color = _sidewalkLine
      ..strokeWidth = 1.0;
    canvas.drawLine(Offset(botOuter, botY), Offset(topOuter, topY), edge);
    canvas.drawLine(Offset(botInner, botY), Offset(topInner, topY), edge);

    final seam = Paint()
      ..color = const Color(0x66948D80)
      ..strokeWidth = 0.8;
    double y = topY + ((_dashOffset * 0.32) % 46);
    while (y < botY) {
      final t = ((y - topY) / (botY - topY)).clamp(0.0, 1.0);
      final outer = lerpDouble(topOuter, botOuter, t)!;
      final inner = lerpDouble(topInner, botInner, t)!;
      canvas.drawLine(Offset(outer, y), Offset(inner, y), seam);
      y += 46;
    }

    if (!isCity) {
      final gardenW = left ? 24.0 : -24.0;
      final garden = Path()
        ..moveTo(botOuter, botY)
        ..lineTo(botOuter - gardenW, botY)
        ..lineTo(topOuter - gardenW, topY)
        ..lineTo(topOuter, topY)
        ..close();
      canvas.drawPath(garden, Paint()..color = const Color(0xFF4CAF50));
    }
  }

  void _drawCurbs(Canvas canvas, double leftTop, double rightTop,
      double leftBot, double rightBot, double topY, double botY) {
    final curbPaint = Paint()
      ..color = _curb
      ..strokeWidth = 4.0
      ..strokeCap = StrokeCap.round;
    final shadowPaint = Paint()
      ..color = const Color(0x66000000)
      ..strokeWidth = 2.0;

    canvas.drawLine(
        Offset(leftTop + 1, topY), Offset(leftBot + 1, botY), shadowPaint);
    canvas.drawLine(
        Offset(rightTop - 1, topY), Offset(rightBot - 1, botY), shadowPaint);
    canvas.drawLine(Offset(leftTop, topY), Offset(leftBot, botY), curbPaint);
    canvas.drawLine(Offset(rightTop, topY), Offset(rightBot, botY), curbPaint);
  }

  void _drawCenterLine(Canvas canvas, double w, double topY, double botY) {
    final centerX = w * 0.5;
    final paint = Paint()..color = _laneLine;
    var y = topY - _cycle + _dashOffset;
    while (y < botY) {
      final y1 = y.clamp(topY, botY);
      final y2 = (y + _dashLen).clamp(topY, botY);
      if (y2 > y1) {
        const hw1 = 2.6;
        const hw2 = 2.6;
        canvas.drawPath(
          Path()
            ..moveTo(centerX - hw1, y1)
            ..lineTo(centerX + hw1, y1)
            ..lineTo(centerX + hw2, y2)
            ..lineTo(centerX - hw2, y2)
            ..close(),
          paint,
        );
      }
      y += _cycle;
    }
  }

  void _drawAsphaltTexture(
      Canvas canvas,
      Path roadPath,
      double leftTop,
      double rightTop,
      double leftBot,
      double rightBot,
      double topY,
      double botY) {
    canvas.save();
    canvas.clipPath(roadPath);
    final rng = Random(11);
    final speck = Paint()..color = const Color(0x223F474A);
    for (int i = 0; i < 160; i++) {
      final y = topY + rng.nextDouble() * (botY - topY);
      final t = ((y - topY) / (botY - topY)).clamp(0.0, 1.0);
      final l = lerpDouble(leftTop, leftBot, t)!;
      final r = lerpDouble(rightTop, rightBot, t)!;
      final x = l + rng.nextDouble() * (r - l);
      canvas.drawCircle(Offset(x, y), 0.7 + rng.nextDouble() * 1.2, speck);
    }
    canvas.restore();
  }

  void _drawCityPavementTexture(
      Canvas canvas, double w, double topY, double botY) {
    final paint = Paint()
      ..color = const Color(0x225A5A5A)
      ..strokeWidth = 1.0;
    for (double y = topY + ((_dashOffset * 0.18) % 54); y < botY; y += 54) {
      canvas.drawLine(Offset(0, y), Offset(w, y), paint);
    }
    for (double x = 0; x < w; x += 72) {
      canvas.drawLine(Offset(x, topY), Offset(x, botY), paint);
    }
  }

  void _drawCityRoadDetails(Canvas canvas, double leftTop, double rightTop,
      double leftBot, double rightBot, double topY, double botY) {
    final bikePaint = Paint()
      ..color = const Color(0x553FCB70)
      ..strokeWidth = 2.0;
    canvas.drawLine(
        Offset(leftTop + 22, topY), Offset(leftBot + 28, botY), bikePaint);
    canvas.drawLine(
        Offset(rightTop - 22, topY), Offset(rightBot - 28, botY), bikePaint);

    final gratePaint = Paint()
      ..color = const Color(0xAA15191A)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.3;
    for (double y = topY + 120 - (_dashOffset % 220); y < botY; y += 220) {
      final t = ((y - topY) / (botY - topY)).clamp(0.0, 1.0);
      final l = lerpDouble(leftTop, leftBot, t)!;
      final r = lerpDouble(rightTop, rightBot, t)!;
      for (final x in [l + 46, r - 46]) {
        final rect =
            Rect.fromCenter(center: Offset(x, y), width: 26, height: 16);
        canvas.drawRRect(
          RRect.fromRectAndRadius(rect, const Radius.circular(3)),
          Paint()..color = const Color(0xFF242829),
        );
        for (int i = 0; i < 4; i++) {
          final gx = rect.left + 5 + i * 5;
          canvas.drawLine(Offset(gx, rect.top + 3), Offset(gx, rect.bottom - 3),
              gratePaint);
        }
      }
    }
  }
}
