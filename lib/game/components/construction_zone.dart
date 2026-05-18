import 'dart:ui';
import 'package:flame/components.dart';
import '../delivery_dash_game.dart';
import 'obstacle.dart';

/// Paperboy-style construction lane.
///
/// The old version was a flat orange tint. This version draws a readable work
/// zone with barricades, asphalt patch marks, cones, warning sign, and caution
/// tape while still keeping the driveable path clear.
class ConstructionZoneComponent extends PositionComponent
    with HasGameRef<DeliveryDashGame> {
  static const double zoneHeight = 220.0;

  bool _playerInside = false;
  bool _seeded = false;
  final double? initialY;

  ConstructionZoneComponent({this.initialY})
      : super(
          size: Vector2(0, zoneHeight),
          anchor: Anchor.topLeft,
          priority: -7,
        );

  @override
  Future<void> onLoad() async {
    size = Vector2(gameRef.size.x, zoneHeight);
    position = Vector2(0, initialY ?? -zoneHeight);
  }

  void _seedCones() {
    if (_seeded) return;
    _seeded = true;
    final lm = gameRef.laneManager;
    const fractions = [0.34, 0.48, 0.62, 0.42, 0.56];
    for (int i = 0; i < fractions.length; i++) {
      final yOff = 32.0 + i * 36.0;
      gameRef.add(ObstacleComponent(
        type: ObstacleType.cone,
        laneFraction: fractions[i],
        initialPositionOverride: Vector2(
          lm.roadXFromFraction(fractions[i], position.y + yOff),
          position.y + yOff,
        ),
      ));
    }

    const workerFractions = [0.28, 0.72];
    for (int i = 0; i < workerFractions.length; i++) {
      final y = position.y + 72.0 + i * 92.0;
      gameRef.add(ObstacleComponent(
        type: ObstacleType.worker,
        laneFraction: workerFractions[i],
        initialPositionOverride: Vector2(
          lm.roadXFromFraction(workerFractions[i], y),
          y,
        ),
      ));
    }
  }

  @override
  void update(double dt) {
    super.update(dt);
    if (gameRef.state != GameState.playing) return;
    position.y += gameRef.scrollSpeed * dt;

    if (!_seeded && position.y > -zoneHeight * 0.5) {
      _seedCones();
    }

    final playerY = gameRef.player.position.y;
    final inside = playerY >= position.y && playerY <= position.y + zoneHeight;
    if (inside && !_playerInside) {
      _playerInside = true;
      gameRef.applyConstructionSlow();
    } else if (!inside && _playerInside) {
      _playerInside = false;
      gameRef.clearConstructionSlow();
    }

    if (position.y > gameRef.size.y) {
      if (_playerInside) {
        _playerInside = false;
        gameRef.clearConstructionSlow();
      }
      removeFromParent();
    }
  }

  @override
  void render(Canvas canvas) {
    final lm = gameRef.laneManager;
    final left = lm.roadLeft;
    final right = lm.roadRight;
    final w = right - left;

    final roadRect = Rect.fromLTWH(left, 0, w, zoneHeight);
    canvas.drawRect(
      roadRect,
      Paint()
        ..shader = Gradient.linear(
          Offset(left, 0),
          Offset(right, zoneHeight),
          [const Color(0x223A2A12), const Color(0x33FF9800)],
        ),
    );

    final patchPaint = Paint()..color = const Color(0x553A2A12);
    for (int i = 0; i < 5; i++) {
      final y = 18.0 + i * 38.0;
      final direction = i.isEven ? 1.0 : -1.0;
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromCenter(
            center: Offset(left + w * (0.38 + 0.08 * direction), y),
            width: w * 0.24,
            height: 18,
          ),
          const Radius.circular(8),
        ),
        patchPaint,
      );
    }

    _drawCautionTape(canvas, left + 8, right - 8, 10);
    _drawCautionTape(canvas, left + 8, right - 8, zoneHeight - 18);

    for (final x in [left + 18, right - 70]) {
      for (final y in [46.0, 122.0]) {
        _drawBarricade(canvas, x, y);
      }
    }

    _drawWarningSign(canvas, left + w * 0.08, 82);
    _drawWarningSign(canvas, right - w * 0.18, 156);

    for (double y = 28; y < zoneHeight - 20; y += 44) {
      _drawTinyCone(canvas, left + 9, y);
      _drawTinyCone(canvas, right - 17, y + 12);
    }
  }

  void _drawCautionTape(Canvas canvas, double left, double right, double y) {
    canvas.drawRect(
      Rect.fromLTWH(left, y, right - left, 8),
      Paint()..color = const Color(0xFFFFC928),
    );
    final black = Paint()..color = const Color(0xFF202020);
    for (double x = left - 20; x < right; x += 22) {
      final p = Path()
        ..moveTo(x, y + 8)
        ..lineTo(x + 8, y + 8)
        ..lineTo(x + 24, y)
        ..lineTo(x + 16, y)
        ..close();
      canvas.drawPath(p, black);
    }
  }

  void _drawBarricade(Canvas canvas, double x, double y) {
    canvas.drawOval(
      Rect.fromCenter(center: Offset(x + 28, y + 26), width: 52, height: 10),
      Paint()..color = const Color(0x55000000),
    );
    final leg = Paint()
      ..color = const Color(0xFF5D4037)
      ..strokeWidth = 4
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(Offset(x + 8, y + 18), Offset(x + 0, y + 34), leg);
    canvas.drawLine(Offset(x + 48, y + 18), Offset(x + 56, y + 34), leg);
    final board = RRect.fromRectAndRadius(
      Rect.fromLTWH(x, y, 56, 18),
      const Radius.circular(3),
    );
    canvas.drawRRect(board, Paint()..color = const Color(0xFFFF9800));
    canvas.drawRRect(
      board,
      Paint()
        ..color = const Color(0xFF4E342E)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5,
    );
    final white = Paint()
      ..color = const Color(0xFFFFF3E0)
      ..strokeWidth = 5
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(Offset(x + 6, y + 15), Offset(x + 22, y + 3), white);
    canvas.drawLine(Offset(x + 30, y + 15), Offset(x + 48, y + 3), white);
  }

  void _drawWarningSign(Canvas canvas, double x, double y) {
    canvas.drawLine(
      Offset(x + 17, y + 24),
      Offset(x + 17, y + 50),
      Paint()
        ..color = const Color(0xFF5D4037)
        ..strokeWidth = 3,
    );
    final sign = Path()
      ..moveTo(x + 17, y)
      ..lineTo(x + 34, y + 17)
      ..lineTo(x + 17, y + 34)
      ..lineTo(x, y + 17)
      ..close();
    canvas.drawPath(sign, Paint()..color = const Color(0xFFFFB300));
    canvas.drawPath(
      sign,
      Paint()
        ..color = const Color(0xFF4E342E)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.6,
    );
    canvas.drawLine(
      Offset(x + 10, y + 17),
      Offset(x + 24, y + 17),
      Paint()
        ..color = const Color(0xFF4E342E)
        ..strokeWidth = 2,
    );
    canvas.drawCircle(
      Offset(x + 17, y + 24),
      2,
      Paint()..color = const Color(0xFF4E342E),
    );
  }

  void _drawTinyCone(Canvas canvas, double x, double y) {
    final cone = Path()
      ..moveTo(x + 8, y)
      ..lineTo(x + 16, y + 22)
      ..lineTo(x, y + 22)
      ..close();
    canvas.drawPath(cone, Paint()..color = const Color(0xFFFF6D00));
    canvas.drawRect(
      Rect.fromLTWH(x + 3, y + 13, 10, 3),
      Paint()..color = const Color(0xFFFFF3E0),
    );
    canvas.drawRect(
      Rect.fromLTWH(x - 2, y + 21, 20, 5),
      Paint()..color = const Color(0xFF4E342E),
    );
  }
}
