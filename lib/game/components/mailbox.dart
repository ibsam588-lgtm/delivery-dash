import 'dart:math';
import 'dart:ui';
import 'package:flame/collisions.dart';
import 'package:flame/components.dart';
import '../delivery_dash_game.dart';

class MailboxComponent extends PositionComponent
    with HasGameRef<DeliveryDashGame>, CollisionCallbacks {
  static const double _popDuration = 0.5;
  static const double _popScalePeak = 1.4;

  final bool isBlue;
  bool _hit = false;
  double _hitTimer = 0;
  RectangleHitbox? _hitbox;

  MailboxComponent({required this.isBlue})
      : super(
          size: Vector2(48, 72),
          anchor: Anchor.center,
          priority: 4,
        );

  @override
  Future<void> onLoad() async {
    _hitbox = RectangleHitbox(
      size: size * 0.85,
      position: size * 0.075,
      collisionType: CollisionType.passive,
    );
    add(_hitbox!);
  }

  /// Begin pop animation. Disables the hitbox so further papers pass through.
  /// The component will remove itself when the animation finishes.
  void startPopAnimation() {
    if (_hit) return;
    _hit = true;
    _hitTimer = 0;
    _hitbox?.removeFromParent();
    _hitbox = null;
  }

  @override
  void update(double dt) {
    super.update(dt);
    if (_hit) {
      _hitTimer += dt;
      if (_hitTimer >= _popDuration) {
        removeFromParent();
      }
    }
  }

  @override
  void render(Canvas canvas) {
    final w = size.x;
    final h = size.y;

    // Pop animation: scale up to peak, then shrink to 0 around the centre.
    if (_hit) {
      final t = (_hitTimer / _popDuration).clamp(0.0, 1.0);
      // 0..0.4: scale 1 → peak. 0.4..1.0: scale peak → 0.
      final double scale;
      if (t < 0.4) {
        scale = 1.0 + (_popScalePeak - 1.0) * (t / 0.4);
      } else {
        scale = _popScalePeak * (1.0 - (t - 0.4) / 0.6);
      }
      // Burst ring of dots around the centre.
      const ringSteps = 10;
      final ringR = w * 0.6 + w * 0.6 * t;
      final ringPaint = Paint()
        ..color = (isBlue ? const Color(0xFF42A5F5) : const Color(0xFFEF5350))
            .withValues(alpha: (1.0 - t).clamp(0.0, 1.0));
      for (int i = 0; i < ringSteps; i++) {
        final ang = i * 2 * pi / ringSteps;
        canvas.drawCircle(
          Offset(w / 2 + cos(ang) * ringR, h / 2 + sin(ang) * ringR),
          2.4,
          ringPaint,
        );
      }
      // Apply scaling for the body itself.
      canvas.save();
      canvas.translate(w / 2, h / 2);
      canvas.scale(scale);
      canvas.translate(-w / 2, -h / 2);
      _drawBody(canvas, w, h);
      canvas.restore();
      return;
    }

    _drawBody(canvas, w, h);
  }

  void _drawBody(Canvas canvas, double w, double h) {
    // Ground shadow.
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(w / 2, h - 2),
        width: w * 0.85,
        height: 8,
      ),
      Paint()..color = const Color(0x77000000),
    );

    // Post.
    canvas.drawRect(
      Rect.fromLTWH(w * 0.44, h * 0.55, w * 0.12, h * 0.42),
      Paint()..color = const Color(0xFF4A4A4A),
    );

    // Box body — a rounded rectangle with a domed top half.
    final boxColor = isBlue ? const Color(0xFF1565C0) : const Color(0xFFD32F2F);
    final boxHighlight =
        isBlue ? const Color(0xFF1E88E5) : const Color(0xFFEF5350);

    final boxRect = Rect.fromLTWH(w * 0.08, h * 0.18, w * 0.84, h * 0.38);
    canvas.drawOval(
      Rect.fromLTWH(w * 0.06, h * 0.16, w * 0.88, h * 0.28),
      Paint()..color = boxHighlight,
    );
    canvas.drawRect(
      Rect.fromLTWH(w * 0.06, h * 0.30, w * 0.88, h * 0.28),
      Paint()..color = boxColor,
    );

    canvas.drawRRect(
      RRect.fromRectAndCorners(
        boxRect,
        topLeft: const Radius.circular(10),
        topRight: const Radius.circular(10),
      ),
      Paint()
        ..color = const Color(0xFF1A1A1A)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5,
    );

    canvas.drawRect(
      Rect.fromLTWH(w * 0.20, h * 0.40, w * 0.60, h * 0.05),
      Paint()..color = const Color(0xFF111111),
    );

    canvas.drawOval(
      Rect.fromLTWH(w * 0.18, h * 0.18, w * 0.24, h * 0.08),
      Paint()..color = const Color(0x66FFFFFF),
    );

    // Flag — only on BLUE (good) mailbox: white flag raised.
    if (isBlue) {
      // Flag pole.
      canvas.drawRect(
        Rect.fromLTWH(w * 0.84, h * 0.22, w * 0.05, h * 0.18),
        Paint()..color = const Color(0xFF555555),
      );
      // White flag.
      canvas.drawRect(
        Rect.fromLTWH(w * 0.84, h * 0.20, w * 0.14, h * 0.08),
        Paint()..color = const Color(0xFFFAFAFA),
      );
      canvas.drawRect(
        Rect.fromLTWH(w * 0.84, h * 0.20, w * 0.14, h * 0.08),
        Paint()
          ..color = const Color(0xFF222222)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 0.8,
      );
    } else {
      // Red mailbox: warning X marking instead of a flag.
      final xPaint = Paint()
        ..color = const Color(0xFFFAFAFA)
        ..strokeWidth = 2.5;
      canvas.drawLine(
        Offset(w * 0.32, h * 0.22),
        Offset(w * 0.48, h * 0.36),
        xPaint,
      );
      canvas.drawLine(
        Offset(w * 0.48, h * 0.22),
        Offset(w * 0.32, h * 0.36),
        xPaint,
      );
    }
  }
}
