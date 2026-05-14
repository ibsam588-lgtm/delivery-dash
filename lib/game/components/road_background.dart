import 'dart:ui';
import 'package:flame/components.dart';
import '../delivery_dash_game.dart';

/// Perspective road with textured asphalt, white-curb + thin-gray rumble
/// strips, brightly foreshortened center dashes, and faint tire tracks
/// along each lane.
class RoadBackground extends PositionComponent
    with HasGameRef<DeliveryDashGame> {
  static const Color roadColor = Color(0xFF1A1A1A);
  static const Color asphaltNoiseColor = Color(0xFF222222);
  static const Color tireTrackColor = Color(0xFF101010);
  static const Color sidewalkColor = Color(0xFF4CAF50);
  static const Color sidewalkBandColor = Color(0xFF3F9E45);
  static const Color curbWhite = Color(0xFFFFFFFF);
  static const Color rumbleGray = Color(0xFF6A6A6A);
  static const Color laneLineColor = Color(0xFFFFD700);

  static const int dashCount = 18;
  static const double bandSpacing = 64.0;

  final Paint _roadPaint = Paint()..color = roadColor;
  final Paint _sidewalkPaint = Paint()..color = sidewalkColor;
  final Paint _sidewalkBandPaint = Paint()..color = sidewalkBandColor;
  final Paint _noisePaint = Paint()..color = asphaltNoiseColor;
  final Paint _tirePaint = Paint()..color = tireTrackColor;

  double _dashOffset = 0;
  double _bandOffset = 0;

  RoadBackground({required Vector2 gameSize})
      : super(size: gameSize, position: Vector2.zero(), priority: -10);

  @override
  void update(double dt) {
    if (gameRef.state != GameState.playing) return;
    _dashOffset += gameRef.scrollSpeed * dt;
    _bandOffset += gameRef.scrollSpeed * dt;
  }

  @override
  void render(Canvas canvas) {
    final w = size.x;
    final h = size.y;
    final lm = gameRef.laneManager;

    final topL = Offset(lm.roadLeftAt(0), 0);
    final topR = Offset(lm.roadRightAt(0), 0);
    final botL = Offset(lm.roadLeftAt(h), h);
    final botR = Offset(lm.roadRightAt(h), h);

    // ── Grass sidewalks ──────────────────────────────────────────────
    final leftSidewalk = Path()
      ..moveTo(0, 0)
      ..lineTo(topL.dx, 0)
      ..lineTo(botL.dx, h)
      ..lineTo(0, h)
      ..close();
    canvas.drawPath(leftSidewalk, _sidewalkPaint);
    final rightSidewalk = Path()
      ..moveTo(topR.dx, 0)
      ..lineTo(w, 0)
      ..lineTo(w, h)
      ..lineTo(botR.dx, h)
      ..close();
    canvas.drawPath(rightSidewalk, _sidewalkPaint);

    // Mow bands on the grass.
    _drawSidewalkBands(canvas, h);

    // ── Asphalt ──────────────────────────────────────────────────────
    final road = Path()
      ..moveTo(topL.dx, 0)
      ..lineTo(topR.dx, 0)
      ..lineTo(botR.dx, h)
      ..lineTo(botL.dx, h)
      ..close();
    canvas.drawPath(road, _roadPaint);

    // Subtle 2x2 noise dots, dithered along the road, scrolling.
    _drawAsphaltNoise(canvas, h, lm);

    // Faint worn tire tracks along each "lane" (left and right thirds).
    _drawTireTracks(canvas, h, lm);

    // ── Road edge: thick white + gap + thin gray rumble strip ──────
    canvas.drawLine(topL, botL, Paint()
      ..color = curbWhite
      ..strokeWidth = 3);
    canvas.drawLine(topR, botR, Paint()
      ..color = curbWhite
      ..strokeWidth = 3);
    // Thin gray rumble strip just inside the white.
    _drawInsetLine(canvas, h, lm, fromEdge: 5, color: rumbleGray, width: 1.4,
        leftSide: true);
    _drawInsetLine(canvas, h, lm, fromEdge: 5, color: rumbleGray, width: 1.4,
        leftSide: false);

    // ── Bright yellow center dashes ─────────────────────────────────
    _drawCenterDashes(canvas, h, lm);
  }

  void _drawSidewalkBands(Canvas canvas, double h) {
    final lm = gameRef.laneManager;
    const spacing = bandSpacing;
    final offset = _bandOffset % spacing;
    var y = -spacing + offset;
    while (y < h) {
      if (y >= 0) {
        canvas.drawRect(
          Rect.fromLTWH(0, y, lm.roadLeftAt(y), 4),
          _sidewalkBandPaint,
        );
        canvas.drawRect(
          Rect.fromLTWH(
              lm.roadRightAt(y), y, size.x - lm.roadRightAt(y), 4),
          _sidewalkBandPaint,
        );
      }
      y += spacing;
    }
  }

  void _drawAsphaltNoise(Canvas canvas, double h, dynamic lm) {
    // Static dot grid that scrolls with the road. Cheap, draws ~200 dots.
    const stepX = 18.0;
    const stepY = 28.0;
    final phase = _dashOffset % stepY;
    for (var y = -stepY + phase; y < h; y += stepY) {
      if (y < 0) continue;
      final left = lm.roadLeftAt(y);
      final right = lm.roadRightAt(y);
      // Slight pattern offset every other row.
      final shift = ((y ~/ stepY).isEven ? 0.0 : stepX / 2);
      for (var x = left + 6 + shift; x < right - 6; x += stepX) {
        canvas.drawRect(Rect.fromLTWH(x, y, 2, 2), _noisePaint);
      }
    }
  }

  void _drawTireTracks(Canvas canvas, double h, dynamic lm) {
    // Two faint dark strips per lane third, drawn as perspective lines.
    for (final laneFrac in const [0.30, 0.70]) {
      final topX = lm.roadLeftAt(0) +
          lm.roadWidthAt(0) * laneFrac;
      final botX = lm.roadLeftAt(h) +
          lm.roadWidthAt(h) * laneFrac;
      for (final offsetFrac in const [-0.04, 0.04]) {
        final topOff = topX + lm.roadWidthAt(0) * offsetFrac;
        final botOff = botX + lm.roadWidthAt(h) * offsetFrac;
        canvas.drawLine(
          Offset(topOff, 0),
          Offset(botOff, h),
          _tirePaint
            ..strokeWidth = 4
            ..strokeCap = StrokeCap.round,
        );
      }
    }
  }

  void _drawInsetLine(
    Canvas canvas,
    double h,
    dynamic lm, {
    required double fromEdge,
    required Color color,
    required double width,
    required bool leftSide,
  }) {
    final topX = leftSide
        ? lm.roadLeftAt(0) + fromEdge
        : lm.roadRightAt(0) - fromEdge;
    final botX = leftSide
        ? lm.roadLeftAt(h) + fromEdge
        : lm.roadRightAt(h) - fromEdge;
    canvas.drawLine(
      Offset(topX, 0),
      Offset(botX, h),
      Paint()
        ..color = color
        ..strokeWidth = width,
    );
  }

  void _drawCenterDashes(Canvas canvas, double h, dynamic lm) {
    const dashWorld = 56.0;
    const cycleWorld = 90.0;
    final scrollPhase = _dashOffset % cycleWorld;
    var ground = -scrollPhase;
    while (ground < dashCount * cycleWorld) {
      final yA = h - ground - dashWorld;
      final yB = h - ground;
      if (yB < 0) break;
      if (yA < h * 0.04) {
        ground += cycleWorld;
        continue;
      }
      final cx1 = lm.roadCenterAt(yA);
      final cx2 = lm.roadCenterAt(yB);
      final thickness = (lm.scaleAt(yB) * 5).clamp(1.5, 6.0);
      canvas.drawLine(
        Offset(cx1, yA),
        Offset(cx2, yB),
        Paint()
          ..color = laneLineColor
          ..strokeWidth = thickness
          ..strokeCap = StrokeCap.square,
      );
      ground += cycleWorld;
    }
  }
}
