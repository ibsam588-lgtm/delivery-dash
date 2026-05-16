import 'dart:math';
import 'dart:ui';
import 'package:flame/components.dart';
import '../delivery_dash_game.dart';

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

    _drawSimpleSky(canvas, w, topY);

    canvas.drawRect(
      Rect.fromLTWH(0, topY, w, h - topY),
      Paint()
        ..shader = Gradient.linear(
          Offset(0, topY),
          Offset(0, h),
          [_grassLight, _grassDark],
        ),
    );

    final leftBot = lm.roadLeftAt(h);
    final rightBot = lm.roadRightAt(h);
    final leftTop = lm.roadLeftAt(topY);
    final rightTop = lm.roadRightAt(topY);

    _drawSidewalk(canvas, leftTop - 54, leftTop, leftBot - 76, leftBot, topY, h, true);
    _drawSidewalk(canvas, rightTop, rightTop + 54, rightBot, rightBot + 76, topY, h, false);

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

    _drawAsphaltTexture(canvas, roadPath, leftTop, rightTop, leftBot, rightBot, topY, h);
    _drawCurbs(canvas, leftTop, rightTop, leftBot, rightBot, topY, h);
    _drawCenterLine(canvas, w, topY, h);
  }

  void _drawSimpleSky(Canvas canvas, double w, double topY) {
    canvas.drawRect(
      Rect.fromLTWH(0, 0, w, topY),
      Paint()
        ..shader = Gradient.linear(
          Offset.zero,
          Offset(0, topY),
          [_skyTop, _skyHorizon],
        ),
    );
  }

  void _drawSidewalk(Canvas canvas, double topOuter, double topInner,
      double botOuter, double botInner, double topY, double botY, bool left) {
    final path = Path()
      ..moveTo(botOuter, botY)
      ..lineTo(botInner, botY)
      ..lineTo(topInner, topY)
      ..lineTo(topOuter, topY)
      ..close();
    canvas.drawPath(path, Paint()..color = _sidewalk);

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

    final gardenW = left ? 24.0 : -24.0;
    final garden = Path()
      ..moveTo(botOuter, botY)
      ..lineTo(botOuter - gardenW, botY)
      ..lineTo(topOuter - gardenW * 0.55, topY)
      ..lineTo(topOuter, topY)
      ..close();
    canvas.drawPath(garden, Paint()..color = const Color(0xFF4CAF50));
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

    canvas.drawLine(Offset(leftTop + 1, topY), Offset(leftBot + 1, botY), shadowPaint);
    canvas.drawLine(Offset(rightTop - 1, topY), Offset(rightBot - 1, botY), shadowPaint);
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
        final t1 = ((y1 - topY) / (botY - topY)).clamp(0.0, 1.0);
        final t2 = ((y2 - topY) / (botY - topY)).clamp(0.0, 1.0);
        final hw1 = 1.8 + 2.8 * t1;
        final hw2 = 1.8 + 2.8 * t2;
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

  void _drawAsphaltTexture(Canvas canvas, Path roadPath, double leftTop,
      double rightTop, double leftBot, double rightBot, double topY, double botY) {
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
}
