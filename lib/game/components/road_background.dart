import 'dart:math';
import 'dart:ui';
import 'package:flame/components.dart';
import '../delivery_dash_game.dart';

/// Paperboy-style suburban street background.
///
/// This keeps the scene readable and arcade-like: dark asphalt, bright curb
/// edges, tiled sidewalks, garden strips, and a subtle top-down perspective.
class RoadBackground extends PositionComponent
    with HasGameRef<DeliveryDashGame> {
  static const double _horizonFrac = 0.18;

  static const Color _skyTop = Color(0xFF6EC6FF);
  static const Color _skyHorizon = Color(0xFFB8E6B1);
  static const Color _grassLight = Color(0xFF67C75A);
  static const Color _grassDark = Color(0xFF2F9E44);
  static const Color _sidewalk = Color(0xFFD7D0C1);
  static const Color _sidewalkLine = Color(0xFF948D80);
  static const Color _curb = Color(0xFFF5F1E5);
  static const Color _roadNear = Color(0xFF23282A);
  static const Color _roadFar = Color(0xFF3B4042);
  static const Color _laneLine = Color(0xFFF8F6E8);

  static const double _dashLen = 36.0;
  static const double _gapLen = 34.0;
  static const double _cycle = _dashLen + _gapLen;

  double _dashOffset = 0;
  final List<_SceneryItem> _scenery = [];

  RoadBackground({required Vector2 gameSize})
      : super(size: gameSize, position: Vector2.zero(), priority: -10) {
    _generateScenery(gameSize);
  }

  void _generateScenery(Vector2 s) {
    final rng = Random(9);
    double x = 0;
    while (x < s.x) {
      final isTree = rng.nextDouble() < 0.55;
      final width = isTree ? 16.0 + rng.nextDouble() * 18 : 24.0 + rng.nextDouble() * 30;
      final height = isTree ? 24.0 + rng.nextDouble() * 28 : 16.0 + rng.nextDouble() * 22;
      _scenery.add(_SceneryItem(x, width, height, isTree));
      x += width + 5 + rng.nextDouble() * 8;
    }
  }

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
    final horizonY = h * _horizonFrac;

    _drawSkyAndHorizon(canvas, w, horizonY);

    canvas.drawRect(
      Rect.fromLTWH(0, horizonY, w, h - horizonY),
      Paint()
        ..shader = Gradient.linear(
          Offset(0, horizonY),
          Offset(0, h),
          [_grassLight, _grassDark],
        ),
    );

    final leftBot = lm.roadLeftAt(h);
    final rightBot = lm.roadRightAt(h);
    final leftTop = lm.roadLeftAt(horizonY);
    final rightTop = lm.roadRightAt(horizonY);

    _drawSidewalk(canvas, leftTop - 44, leftTop, leftBot - 70, leftBot, horizonY, h, true);
    _drawSidewalk(canvas, rightTop, rightTop + 44, rightBot, rightBot + 70, horizonY, h, false);

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

    _drawAsphaltTexture(canvas, roadPath, leftTop, rightTop, leftBot, rightBot, horizonY, h);
    _drawCurbs(canvas, leftTop, rightTop, leftBot, rightBot, horizonY, h);
    _drawCenterLine(canvas, w, horizonY, h);

    // Slight distance haze only at the very top, not over the whole playfield.
    canvas.drawRect(
      Rect.fromLTWH(0, horizonY, w, h * 0.035),
      Paint()
        ..shader = Gradient.linear(
          Offset(0, horizonY),
          Offset(0, horizonY + h * 0.035),
          [const Color(0x44B8E6B1), const Color(0x00B8E6B1)],
        ),
    );
  }

  void _drawSkyAndHorizon(Canvas canvas, double w, double horizonY) {
    canvas.drawRect(
      Rect.fromLTWH(0, 0, w, horizonY),
      Paint()
        ..shader = Gradient.linear(
          Offset.zero,
          Offset(0, horizonY),
          [_skyTop, _skyHorizon],
        ),
    );

    final treePaint = Paint()..color = const Color(0xFF1E5B2A);
    final housePaint = Paint()..color = const Color(0xFF3E4A44);
    for (final item in _scenery) {
      if (item.isTree) {
        canvas.drawRect(
          Rect.fromLTWH(item.x + item.width * 0.45, horizonY - 9, item.width * 0.10, 9),
          Paint()..color = const Color(0xFF5D4037),
        );
        canvas.drawCircle(
          Offset(item.x + item.width * 0.50, horizonY - item.height * 0.45),
          item.width * 0.45,
          treePaint,
        );
      } else {
        canvas.drawRect(
          Rect.fromLTWH(item.x, horizonY - item.height, item.width, item.height),
          housePaint,
        );
        final roof = Path()
          ..moveTo(item.x - 2, horizonY - item.height)
          ..lineTo(item.x + item.width / 2, horizonY - item.height - 10)
          ..lineTo(item.x + item.width + 2, horizonY - item.height)
          ..close();
        canvas.drawPath(roof, Paint()..color = const Color(0xFF7E2E22));
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
    canvas.drawPath(path, Paint()..color = _sidewalk);

    final edge = Paint()
      ..color = _sidewalkLine
      ..strokeWidth = 1.0;
    canvas.drawLine(Offset(botOuter, botY), Offset(topOuter, topY), edge);
    canvas.drawLine(Offset(botInner, botY), Offset(topInner, topY), edge);

    // Perspective sidewalk tile seams.
    final seam = Paint()
      ..color = const Color(0x66948D80)
      ..strokeWidth = 0.8;
    double y = topY + ((_dashOffset * 0.35) % 46);
    while (y < botY) {
      final t = ((y - topY) / (botY - topY)).clamp(0.0, 1.0);
      final outer = lerpDouble(topOuter, botOuter, t)!;
      final inner = lerpDouble(topInner, botInner, t)!;
      canvas.drawLine(Offset(outer, y), Offset(inner, y), seam);
      y += 46;
    }

    // Garden strip beyond sidewalk.
    final gardenW = left ? 22.0 : -22.0;
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
        final hw1 = 1.8 + 2.6 * t1;
        final hw2 = 1.8 + 2.6 * t2;
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

class _SceneryItem {
  final double x;
  final double width;
  final double height;
  final bool isTree;
  _SceneryItem(this.x, this.width, this.height, this.isTree);
}
