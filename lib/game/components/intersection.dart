import 'package:flame/components.dart';
import 'package:flutter/painting.dart' hide Gradient;
import '../delivery_dash_game.dart';

/// Lightweight suburban intersection. It should read as a normal road crossing,
/// not a railway crossing, and it must not hide the scene after it passes.
class IntersectionComponent extends PositionComponent
    with HasGameRef<DeliveryDashGame> {
  static const double bandHeight = 150;
  static const double _lightCycleTime = 3.0;

  double _lightTimer = 0;
  bool _isGreen = true;

  IntersectionComponent()
      : super(
          size: Vector2(0, bandHeight),
          anchor: Anchor.topLeft,
          priority: -8,
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

    final grass = Paint()..color = const Color(0xFF4CAF50);
    final sidewalk = Paint()..color = const Color(0xFFD7D0C1);
    final crossRoad = Paint()..color = const Color(0xFF25292B);
    final roadPaint = Paint()..color = const Color(0xFF202426);

    canvas.drawRect(Rect.fromLTWH(0, 0, leftEdge, h), grass);
    canvas.drawRect(Rect.fromLTWH(rightEdge, 0, size.x - rightEdge, h), grass);

    // Sidewalk bands continue through the crossing so the scene does not look
    // like everything disappears behind a black block.
    canvas.drawRect(Rect.fromLTWH(0, 0, leftEdge, h), sidewalk);
    canvas.drawRect(Rect.fromLTWH(rightEdge, 0, size.x - rightEdge, h), sidewalk);

    // Subtle horizontal road crossing, not full-screen black railway block.
    canvas.drawRect(Rect.fromLTWH(0, h * 0.36, size.x, h * 0.28), crossRoad);
    canvas.drawRect(Rect.fromLTWH(leftEdge, 0, roadW, h), roadPaint);

    final curbPaint = Paint()
      ..color = const Color(0xFFF5F1E5)
      ..strokeWidth = 4.0
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(Offset(leftEdge, 0), Offset(leftEdge, h), curbPaint);
    canvas.drawLine(Offset(rightEdge, 0), Offset(rightEdge, h), curbPaint);

    // Crosswalks as two separated painted zebra crossings.
    final stripePaint = Paint()..color = const Color(0xFFEDEBE0);
    _drawCrosswalk(canvas, leftEdge + 14, rightEdge - 14, h * 0.24, stripePaint);
    _drawCrosswalk(canvas, leftEdge + 14, rightEdge - 14, h * 0.64, stripePaint);

    final stopPaint = Paint()
      ..color = const Color(0xFFEDEBE0)
      ..strokeWidth = 3.0;
    canvas.drawLine(Offset(leftEdge + 8, h * 0.18), Offset(rightEdge - 8, h * 0.18), stopPaint);
    canvas.drawLine(Offset(leftEdge + 8, h * 0.82), Offset(rightEdge - 8, h * 0.82), stopPaint);

    final lanePaint = Paint()
      ..color = const Color(0x55F8F6E8)
      ..strokeWidth = 3.0;
    canvas.drawLine(Offset(size.x * 0.50, 0), Offset(size.x * 0.50, h * 0.20), lanePaint);
    canvas.drawLine(Offset(size.x * 0.50, h * 0.84), Offset(size.x * 0.50, h), lanePaint);

    _drawTrafficLight(canvas, leftEdge - 20, h * 0.25, _isGreen);
    _drawTrafficLight(canvas, rightEdge + 4, h * 0.55, _isGreen);
  }

  void _drawCrosswalk(Canvas canvas, double left, double right, double y, Paint paint) {
    const stripeW = 9.0;
    const gap = 8.0;
    const stripeH = 18.0;
    double sx = left;
    while (sx + stripeW < right) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(sx, y, stripeW, stripeH),
          const Radius.circular(2),
        ),
        paint,
      );
      sx += stripeW + gap;
    }
  }

  void _drawTrafficLight(Canvas canvas, double x, double y, bool isGreen) {
    canvas.drawRect(Rect.fromLTWH(x + 7, y + 28, 3, 34), Paint()..color = const Color(0xFF2A2A2A));
    canvas.drawRRect(
      RRect.fromRectAndRadius(Rect.fromLTWH(x, y, 17, 29), const Radius.circular(4)),
      Paint()..color = const Color(0xFF101010),
    );

    void bulb(double cy, Color on, Color off, bool active) {
      canvas.drawCircle(Offset(x + 8.5, y + cy), 3.4, Paint()..color = active ? on : off);
      if (active) {
        canvas.drawCircle(Offset(x + 8.5, y + cy), 6.0, Paint()..color = on.withValues(alpha: 0.24));
      }
    }

    bulb(6.5, const Color(0xFFFF5252), const Color(0xFF641A1A), !isGreen);
    bulb(14.5, const Color(0xFFFFD54F), const Color(0xFF6D5100), false);
    bulb(22.5, const Color(0xFF66BB6A), const Color(0xFF1B5E20), isGreen);
  }
}
