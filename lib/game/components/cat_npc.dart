import 'dart:math';
import 'dart:ui';
import 'package:flame/components.dart';
import '../delivery_dash_game.dart';
import 'floating_text.dart';
import 'paper.dart';

// Palette of cat body colours.
const List<Color> _catColors = [
  Color(0xFFD4741A), // orange tabby
  Color(0xFF888888), // grey
  Color(0xFF1A1A1A), // black
  Color(0xFFD4B896), // cream / white
  Color(0xFF8B6914), // brown tabby
];

class CatNpcComponent extends PositionComponent
    with HasGameRef<DeliveryDashGame> {
  static const double _jumpHeight = 14.0;
  static const double _jumpDuration = 0.30;
  static const double _checkInterval = 0.10;
  static const double _paperProximity = 60.0;

  final Color _bodyColor;
  double _jumpTimer = 0;
  bool _isJumping = false;
  double _jumpOffset = 0;
  double _checkTimer = 0;

  CatNpcComponent._({
    required Color bodyColor,
    required Vector2 position,
  })  : _bodyColor = bodyColor,
        super(
          size: Vector2(32, 28),
          anchor: Anchor.bottomCenter,
          position: position,
          priority: 2,
        );

  factory CatNpcComponent({required Vector2 position, Random? rng}) {
    final r = rng ?? Random();
    return CatNpcComponent._(
      bodyColor: _catColors[r.nextInt(_catColors.length)],
      position: position,
    );
  }

  void _startJump() {
    _isJumping = true;
    _jumpTimer = 0;
    gameRef.add(FloatingText(
      text: '!',
      position: absolutePosition - Vector2(0, 24),
      color: const Color(0xFFFFEB3B),
    ));
  }

  @override
  void update(double dt) {
    super.update(dt);
    if (gameRef.state != GameState.playing) return;

    position.y += gameRef.scrollSpeed * dt;

    // Paper proximity check (throttled).
    if (!_isJumping) {
      _checkTimer += dt;
      if (_checkTimer >= _checkInterval) {
        _checkTimer = 0;
        for (final paper in gameRef.descendants().whereType<PaperComponent>()) {
          final d = (paper.position - absolutePosition).length;
          if (d < _paperProximity) {
            _startJump();
            break;
          }
        }
      }
    }

    // Jump animation.
    if (_isJumping) {
      _jumpTimer += dt;
      final half = _jumpDuration / 2;
      if (_jumpTimer < half) {
        _jumpOffset = -_jumpHeight * (_jumpTimer / half);
      } else if (_jumpTimer < _jumpDuration) {
        _jumpOffset = -_jumpHeight * (1.0 - (_jumpTimer - half) / half);
      } else {
        _isJumping = false;
        _jumpOffset = 0;
        _jumpTimer = 0;
      }
    }

    if (position.y > gameRef.size.y + size.y + 50) {
      removeFromParent();
    }
  }

  @override
  void render(Canvas canvas) {
    canvas.save();
    canvas.translate(0, _jumpOffset);
    _renderCat(canvas);
    canvas.restore();
  }

  void _renderCat(Canvas canvas) {
    final w = size.x;
    final h = size.y;

    // Ground shadow.
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(w * 0.50, h - 1),
        width: w * 0.65,
        height: 5,
      ),
      Paint()..color = const Color(0x44000000),
    );

    // --- Body (horizontal rounded oval) ---
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(w * 0.48, h * 0.66),
        width: w * 0.66,
        height: h * 0.46,
      ),
      Paint()..color = _bodyColor,
    );

    // --- Tail (curved arc from rear, sweeping up) ---
    final tailPath = Path()
      ..moveTo(w * 0.82, h * 0.62);
    tailPath.quadraticBezierTo(w * 1.10, h * 0.30, w * 0.98, h * 0.08);
    canvas.drawPath(
      tailPath,
      Paint()
        ..color = _bodyColor
        ..strokeWidth = 4.5
        ..strokeCap = StrokeCap.round
        ..style = PaintingStyle.stroke,
    );
    // Tail tip (slightly lighter).
    canvas.drawCircle(
      Offset(w * 0.98, h * 0.08),
      3.5,
      Paint()..color = const Color(0xFFFFFFFF).withValues(alpha: 0.25),
    );

    // --- Head ---
    final headCenter = Offset(w * 0.50, h * 0.28);
    canvas.drawCircle(headCenter, w * 0.22, Paint()..color = _bodyColor);

    // --- Ears (pointed triangles) ---
    final earBodyPaint = Paint()..color = _bodyColor;
    final earInnerPaint = Paint()..color = const Color(0xFFFF8FAB);

    // Left ear.
    final leftEarPath = Path()
      ..moveTo(w * 0.28, h * 0.22)
      ..lineTo(w * 0.20, h * 0.04)
      ..lineTo(w * 0.40, h * 0.16)
      ..close();
    canvas.drawPath(leftEarPath, earBodyPaint);
    final leftInnerPath = Path()
      ..moveTo(w * 0.30, h * 0.20)
      ..lineTo(w * 0.23, h * 0.07)
      ..lineTo(w * 0.38, h * 0.17)
      ..close();
    canvas.drawPath(leftInnerPath, earInnerPaint);

    // Right ear.
    final rightEarPath = Path()
      ..moveTo(w * 0.72, h * 0.22)
      ..lineTo(w * 0.80, h * 0.04)
      ..lineTo(w * 0.60, h * 0.16)
      ..close();
    canvas.drawPath(rightEarPath, earBodyPaint);
    final rightInnerPath = Path()
      ..moveTo(w * 0.70, h * 0.20)
      ..lineTo(w * 0.77, h * 0.07)
      ..lineTo(w * 0.62, h * 0.17)
      ..close();
    canvas.drawPath(rightInnerPath, earInnerPaint);

    // --- Eyes (oval with slit pupil) ---
    final eyeBasePaint = Paint()..color = const Color(0xFFBFE8F0);
    final pupilPaint = Paint()..color = const Color(0xFF111111);
    final eyeShine = Paint()..color = const Color(0xCCFFFFFF);

    for (final ex in [w * 0.37, w * 0.63]) {
      canvas.drawOval(
        Rect.fromCenter(center: Offset(ex, h * 0.27), width: 6.5, height: 5.5),
        eyeBasePaint,
      );
      // Slit pupil.
      canvas.drawOval(
        Rect.fromCenter(center: Offset(ex, h * 0.27), width: 2.0, height: 4.5),
        pupilPaint,
      );
      // Tiny shine.
      canvas.drawCircle(Offset(ex - 1.2, h * 0.24), 0.9, eyeShine);
    }

    // --- Nose ---
    canvas.drawOval(
      Rect.fromCenter(center: Offset(w * 0.50, h * 0.38), width: 4.0, height: 3.0),
      Paint()..color = const Color(0xFFFF8FAB),
    );

    // --- Whiskers (3 each side) ---
    final whiskerPaint = Paint()
      ..color = const Color(0xCCFFFFFF)
      ..strokeWidth = 0.9
      ..strokeCap = StrokeCap.round;
    // Left.
    canvas.drawLine(Offset(w * 0.28, h * 0.34), Offset(w * 0.02, h * 0.30), whiskerPaint);
    canvas.drawLine(Offset(w * 0.28, h * 0.37), Offset(w * 0.02, h * 0.37), whiskerPaint);
    canvas.drawLine(Offset(w * 0.28, h * 0.40), Offset(w * 0.02, h * 0.44), whiskerPaint);
    // Right.
    canvas.drawLine(Offset(w * 0.72, h * 0.34), Offset(w * 0.98, h * 0.30), whiskerPaint);
    canvas.drawLine(Offset(w * 0.72, h * 0.37), Offset(w * 0.98, h * 0.37), whiskerPaint);
    canvas.drawLine(Offset(w * 0.72, h * 0.40), Offset(w * 0.98, h * 0.44), whiskerPaint);
  }
}
