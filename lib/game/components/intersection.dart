import 'package:flame/components.dart';
import 'package:flutter/painting.dart' hide Gradient;
import '../delivery_dash_game.dart';

/// Lightweight suburban intersection. It should read as a normal road crossing,
/// not a railway crossing, and it must not hide the scene after it passes.
class IntersectionComponent extends PositionComponent
    with HasGameRef<DeliveryDashGame> {
  static const double bandHeight = 280;
  static const double _lightCycleTime = 3.0;

  double _lightTimer = 0;
  bool _isGreen = true;

  IntersectionComponent()
      : super(
          size: Vector2(0, bandHeight),
          anchor: Anchor.topLeft,
          priority: 4,
        );

  @override
  Future<void> onLoad() async {
    size = Vector2(gameRef.size.x, bandHeight);
    position = Vector2(0, -bandHeight);
  }

  @override
  void update(double dt) {
    super.update(dt);
    if (gameRef.state != GameState.playing) return;
    position.y += gameRef.scrollSpeed * dt;

    _lightTimer += dt;
    if (_lightTimer >= _lightCycleTime) {
      _lightTimer -= _lightCycleTime;
      _isGreen = !_isGreen;
    }

    if (position.y > gameRef.size.y + bandHeight) removeFromParent();
  }

  @override
  void render(Canvas canvas) {
    final h = size.y;
    final lm = gameRef.laneManager;
    final leftEdge = lm.roadLeft;
    final rightEdge = lm.roadRight;
    final roadW = rightEdge - leftEdge;
    final crossTop = h * 0.22;
    final crossBottom = h * 0.78;
    final crossH = crossBottom - crossTop;

    final grass = Paint()..color = const Color(0xFF4CAF50);
    final sidewalk = Paint()..color = const Color(0xFFD7D0C1);
    final asphalt = Paint()..color = const Color(0xFF23282A);
    final crossRoad = Paint()..color = const Color(0xFF2A3032);
    final intersectionPaint = Paint()..color = const Color(0xFF1F2426);

    canvas.drawRect(Rect.fromLTWH(0, 0, leftEdge, h), grass);
    canvas.drawRect(Rect.fromLTWH(rightEdge, 0, size.x - rightEdge, h), grass);

    canvas.drawRect(Rect.fromLTWH(0, 0, leftEdge, h), sidewalk);
    canvas.drawRect(
        Rect.fromLTWH(rightEdge, 0, size.x - rightEdge, h), sidewalk);

    canvas.drawRect(Rect.fromLTWH(leftEdge, 0, roadW, h), asphalt);
    canvas.drawRect(Rect.fromLTWH(0, crossTop, size.x, crossH), crossRoad);
    _drawAsphaltGrain(canvas, Rect.fromLTWH(0, crossTop, size.x, crossH));
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTRB(leftEdge, crossTop, rightEdge, crossBottom),
        const Radius.circular(2),
      ),
      intersectionPaint,
    );

    _drawCrossStreetLane(canvas, 0, leftEdge - 18, h * 0.50);
    _drawCrossStreetLane(canvas, leftEdge + 20, rightEdge - 20, h * 0.50);
    _drawCrossStreetLane(canvas, rightEdge + 18, size.x, h * 0.50);

    final curbPaint = Paint()
      ..color = const Color(0xFFF5F1E5)
      ..strokeWidth = 4.0
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(Offset(leftEdge, 0), Offset(leftEdge, crossTop), curbPaint);
    canvas.drawLine(
        Offset(leftEdge, crossBottom), Offset(leftEdge, h), curbPaint);
    canvas.drawLine(
        Offset(rightEdge, 0), Offset(rightEdge, crossTop), curbPaint);
    canvas.drawLine(
        Offset(rightEdge, crossBottom), Offset(rightEdge, h), curbPaint);
    canvas.drawLine(
        Offset(0, crossTop), Offset(leftEdge - 14, crossTop), curbPaint);
    canvas.drawLine(
        Offset(rightEdge + 14, crossTop), Offset(size.x, crossTop), curbPaint);
    canvas.drawLine(
        Offset(0, crossBottom), Offset(leftEdge - 14, crossBottom), curbPaint);
    canvas.drawLine(Offset(rightEdge + 14, crossBottom),
        Offset(size.x, crossBottom), curbPaint);

    _drawCurbRamp(canvas, leftEdge - 22, crossTop - 10, true, true);
    _drawCurbRamp(canvas, rightEdge + 4, crossTop - 10, false, true);
    _drawCurbRamp(canvas, leftEdge - 22, crossBottom + 2, true, false);
    _drawCurbRamp(canvas, rightEdge + 4, crossBottom + 2, false, false);

    // Crosswalks as two separated painted zebra crossings.
    final stripePaint = Paint()..color = const Color(0xFFF7F4EA);
    _drawCrosswalk(
        canvas, leftEdge + 14, rightEdge - 14, crossTop - 28, stripePaint);
    _drawCrosswalk(
        canvas, leftEdge + 14, rightEdge - 14, crossBottom + 10, stripePaint);
    _drawSideCrosswalk(
        canvas, leftEdge - 44, crossTop + 9, crossBottom - 9, stripePaint);
    _drawSideCrosswalk(
        canvas, rightEdge + 26, crossTop + 9, crossBottom - 9, stripePaint);

    final stopPaint = Paint()
      ..color = const Color(0xFFEDEBE0)
      ..strokeWidth = 3.0;
    canvas.drawLine(Offset(leftEdge + 10, crossTop - 32),
        Offset(rightEdge - 10, crossTop - 32), stopPaint);
    canvas.drawLine(Offset(leftEdge + 10, crossBottom + 34),
        Offset(rightEdge - 10, crossBottom + 34), stopPaint);
    canvas.drawLine(Offset(leftEdge - 58, crossTop + 8),
        Offset(leftEdge - 58, crossBottom - 8), stopPaint);
    canvas.drawLine(Offset(rightEdge + 58, crossTop + 8),
        Offset(rightEdge + 58, crossBottom - 8), stopPaint);

    final lanePaint = Paint()
      ..color = const Color(0x55F8F6E8)
      ..strokeWidth = 3.0;
    canvas.drawLine(Offset(size.x * 0.50, 0),
        Offset(size.x * 0.50, crossTop - 36), lanePaint);
    canvas.drawLine(Offset(size.x * 0.50, crossBottom + 38),
        Offset(size.x * 0.50, h), lanePaint);

    _drawTurnArrow(canvas, size.x * 0.50, crossTop - 48, true);
    _drawTurnArrow(canvas, size.x * 0.50, crossBottom + 54, false);

    _drawTrafficLight(canvas, leftEdge - 28, crossTop - 24, _isGreen);
    _drawTrafficLight(canvas, rightEdge + 10, crossBottom - 28, _isGreen);
    _drawStreetNameSigns(canvas, leftEdge, rightEdge, crossTop, crossBottom);
  }

  void _drawAsphaltGrain(Canvas canvas, Rect rect) {
    final paint = Paint()..color = const Color(0x223F474A);
    for (int i = 0; i < 70; i++) {
      final x = rect.left + ((i * 47) % rect.width);
      final y = rect.top + ((i * 31) % rect.height);
      canvas.drawCircle(Offset(x, y), 0.8 + (i % 3) * 0.35, paint);
    }
    final seam = Paint()
      ..color = const Color(0x33111111)
      ..strokeWidth = 1.0;
    canvas.drawLine(Offset(rect.left, rect.center.dy - rect.height * 0.28),
        Offset(rect.right, rect.center.dy - rect.height * 0.28), seam);
    canvas.drawLine(Offset(rect.left, rect.center.dy + rect.height * 0.28),
        Offset(rect.right, rect.center.dy + rect.height * 0.28), seam);
  }

  void _drawCrosswalk(
      Canvas canvas, double left, double right, double y, Paint paint) {
    const stripeW = 16.0;
    const gap = 10.0;
    const stripeH = 22.0;
    final apron = RRect.fromRectAndRadius(
      Rect.fromLTWH(left - 7, y - 4, right - left + 14, stripeH + 8),
      const Radius.circular(5),
    );
    canvas.drawRRect(apron, Paint()..color = const Color(0x33111111));
    final edge = Paint()
      ..color = const Color(0x55FFF8E1)
      ..strokeWidth = 1.2;
    canvas.drawLine(Offset(left - 3, y), Offset(right + 3, y), edge);
    canvas.drawLine(
        Offset(left - 3, y + stripeH), Offset(right + 3, y + stripeH), edge);
    double sx = left + 2;
    while (sx + stripeW < right - 2) {
      final stripe = RRect.fromRectAndRadius(
        Rect.fromLTWH(sx, y, stripeW, stripeH),
        const Radius.circular(2),
      );
      canvas.drawRRect(
        stripe,
        paint,
      );
      canvas.drawRRect(
        stripe,
        Paint()
          ..shader = const LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color(0xCCFFFFFF),
              Color(0x66FFFFFF),
              Color(0x22D7D0C1),
            ],
          ).createShader(Rect.fromLTWH(sx, y, stripeW, stripeH)),
      );
      sx += stripeW + gap;
    }
  }

  void _drawSideCrosswalk(
      Canvas canvas, double x, double top, double bottom, Paint paint) {
    const stripeH = 11.0;
    const gap = 8.0;
    const stripeW = 22.0;
    final apron = RRect.fromRectAndRadius(
      Rect.fromLTWH(x - 4, top - 4, stripeW + 8, bottom - top + 8),
      const Radius.circular(5),
    );
    canvas.drawRRect(apron, Paint()..color = const Color(0x33111111));
    final edge = Paint()
      ..color = const Color(0x55FFF8E1)
      ..strokeWidth = 1.2;
    canvas.drawLine(Offset(x, top - 2), Offset(x, bottom + 2), edge);
    canvas.drawLine(
        Offset(x + stripeW, top - 2), Offset(x + stripeW, bottom + 2), edge);
    double sy = top + 1;
    while (sy + stripeH < bottom - 1) {
      final stripe = RRect.fromRectAndRadius(
        Rect.fromLTWH(x, sy, stripeW, stripeH),
        const Radius.circular(2),
      );
      canvas.drawRRect(
        stripe,
        paint,
      );
      canvas.drawRRect(
        stripe,
        Paint()
          ..shader = const LinearGradient(
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
            colors: [
              Color(0xCCFFFFFF),
              Color(0x66FFFFFF),
              Color(0x22D7D0C1),
            ],
          ).createShader(Rect.fromLTWH(x, sy, stripeW, stripeH)),
      );
      sy += stripeH + gap;
    }
  }

  void _drawCrossStreetLane(
      Canvas canvas, double left, double right, double y) {
    if (right <= left) return;
    final paint = Paint()
      ..color = const Color(0x66F8F6E8)
      ..strokeWidth = 2.4
      ..strokeCap = StrokeCap.round;
    for (double x = left + 12; x < right - 10; x += 34) {
      final dashEnd = (x + 18).clamp(left, right).toDouble();
      canvas.drawLine(Offset(x, y), Offset(dashEnd, y), paint);
    }
  }

  void _drawCurbRamp(
      Canvas canvas, double x, double y, bool leftSide, bool topSide) {
    final path = Path();
    const rampW = 22.0;
    const rampH = 12.0;
    final dirX = leftSide ? 1.0 : -1.0;
    final dirY = topSide ? 1.0 : -1.0;
    path
      ..moveTo(x, y)
      ..lineTo(x + rampW * dirX, y)
      ..lineTo(x + rampW * dirX, y + rampH * dirY)
      ..close();
    canvas.drawPath(path, Paint()..color = const Color(0xFFC8C0AF));
  }

  void _drawTurnArrow(Canvas canvas, double x, double y, bool down) {
    final paint = Paint()
      ..color = const Color(0x88F8F6E8)
      ..strokeWidth = 3.0
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    final dir = down ? 1.0 : -1.0;
    canvas.drawLine(Offset(x, y), Offset(x, y + 22 * dir), paint);
    canvas.drawLine(
        Offset(x, y + 22 * dir), Offset(x - 8, y + 12 * dir), paint);
    canvas.drawLine(
        Offset(x, y + 22 * dir), Offset(x + 8, y + 12 * dir), paint);
    canvas.drawLine(Offset(x, y + 9 * dir), Offset(x + 13, y + 9 * dir), paint);
    canvas.drawLine(
        Offset(x + 13, y + 9 * dir), Offset(x + 13, y + 17 * dir), paint);
  }

  void _drawTrafficLight(Canvas canvas, double x, double y, bool isGreen) {
    canvas.drawRect(Rect.fromLTWH(x + 7, y + 28, 3, 34),
        Paint()..color = const Color(0xFF2A2A2A));
    canvas.drawRRect(
      RRect.fromRectAndRadius(
          Rect.fromLTWH(x, y, 17, 29), const Radius.circular(4)),
      Paint()..color = const Color(0xFF101010),
    );

    void bulb(double cy, Color on, Color off, bool active) {
      canvas.drawCircle(
          Offset(x + 8.5, y + cy), 3.4, Paint()..color = active ? on : off);
      if (active) {
        canvas.drawCircle(Offset(x + 8.5, y + cy), 6.0,
            Paint()..color = on.withValues(alpha: 0.24));
      }
    }

    bulb(6.5, const Color(0xFFFF5252), const Color(0xFF641A1A), !isGreen);
    bulb(14.5, const Color(0xFFFFD54F), const Color(0xFF6D5100), false);
    bulb(22.5, const Color(0xFF66BB6A), const Color(0xFF1B5E20), isGreen);
  }

  void _drawStreetNameSigns(Canvas canvas, double leftEdge, double rightEdge,
      double crossTop, double crossBottom) {
    final signPaint = Paint()..color = const Color(0xFF1B8F4D);
    final textLine = Paint()
      ..color = const Color(0xFFE8FFF0)
      ..strokeWidth = 1.3
      ..strokeCap = StrokeCap.round;

    void sign(double x, double y, bool rightSide) {
      canvas.drawRect(Rect.fromLTWH(x + 8, y + 24, 2.5, 28),
          Paint()..color = const Color(0xFF2A2A2A));
      final rect = RRect.fromRectAndRadius(
        Rect.fromLTWH(x, y, 34, 13),
        const Radius.circular(2),
      );
      canvas.drawRRect(rect, signPaint);
      canvas.drawLine(Offset(x + 5, y + 5), Offset(x + 29, y + 5), textLine);
      canvas.drawLine(Offset(x + 9, y + 9), Offset(x + 25, y + 9), textLine);
      if (!rightSide) {
        canvas.drawRect(Rect.fromLTWH(x + 1, y + 13, 13, 4), signPaint);
      }
    }

    sign(leftEdge - 70, crossTop - 18, false);
    sign(rightEdge + 38, crossBottom + 8, true);
  }
}
