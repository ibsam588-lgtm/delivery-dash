import 'dart:math';
import 'dart:ui';
import 'package:flame/collisions.dart';
import 'package:flame/components.dart';
import '../delivery_dash_game.dart';

/// Mailbox that stays in the world after a paper hits it. Blue mailboxes
/// raise their flag (animated) and glow briefly. Red (forbidden) mailboxes
/// just flash, no flag.
class MailboxComponent extends PositionComponent
    with HasGameRef<DeliveryDashGame>, CollisionCallbacks {
  static const double _raiseDuration = 0.30;
  static const double _glowDuration = 0.45;

  final bool isBlue;
  bool _delivered = false;
  double _glowTimer = 0;
  double _raiseTimer = 0;
  RectangleHitbox? _hitbox;

  MailboxComponent({required this.isBlue})
      : super(
          size: Vector2(36, 60),
          anchor: Anchor.center,
          priority: 4,
        );

  bool get delivered => _delivered;

  /// Flag angle in radians. 0 = flat-down, pi/4 = raised.
  double get _flagAngle {
    if (!_delivered) return 0.0;
    final raised = (1.0 - _raiseTimer / _raiseDuration).clamp(0.0, 1.0);
    return (pi / 4) * raised;
  }

  @override
  Future<void> onLoad() async {
    _hitbox = RectangleHitbox(
      size: size * 0.85,
      position: size * 0.075,
      collisionType: CollisionType.passive,
    );
    add(_hitbox!);
  }

  /// Called by paper on impact. Disables the hitbox (no more deliveries),
  /// raises the flag, and triggers the glow.
  void markDelivered() {
    if (_delivered) return;
    _delivered = true;
    _glowTimer = _glowDuration;
    _raiseTimer = _raiseDuration;
    _hitbox?.removeFromParent();
    _hitbox = null;
  }

  @override
  void update(double dt) {
    super.update(dt);
    if (_glowTimer > 0) {
      _glowTimer = (_glowTimer - dt).clamp(0.0, _glowDuration);
    }
    if (_raiseTimer > 0) {
      _raiseTimer = (_raiseTimer - dt).clamp(0.0, _raiseDuration);
    }
  }

  @override
  void render(Canvas canvas) {
    final w = size.x;
    final h = size.y;

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
      Paint()..color = const Color(0xFF3E3E3E),
    );

    // Box body.
    final boxColor =
        isBlue ? const Color(0xFF1E88E5) : const Color(0xFFE53935);
    final boxHighlight =
        isBlue ? const Color(0xFF42A5F5) : const Color(0xFFEF5350);

    final boxRect = Rect.fromLTWH(w * 0.06, h * 0.18, w * 0.84, h * 0.38);
    // Domed top.
    canvas.drawOval(
      Rect.fromLTWH(w * 0.06, h * 0.16, w * 0.84, h * 0.24),
      Paint()..color = boxHighlight,
    );
    canvas.drawRect(
      Rect.fromLTWH(w * 0.06, h * 0.28, w * 0.84, h * 0.28),
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

    // Slot.
    canvas.drawRect(
      Rect.fromLTWH(w * 0.20, h * 0.40, w * 0.60, h * 0.05),
      Paint()..color = const Color(0xFF111111),
    );
    // Glare.
    canvas.drawOval(
      Rect.fromLTWH(w * 0.18, h * 0.18, w * 0.24, h * 0.08),
      Paint()..color = const Color(0x66FFFFFF),
    );

    if (isBlue) {
      // ── Flag (pivots at its base, raises when delivered) ────────────────
      final pivot = Offset(w * 0.88, h * 0.40);
      canvas.save();
      canvas.translate(pivot.dx, pivot.dy);
      canvas.rotate(-_flagAngle);
      // Flag pole (stub).
      canvas.drawRect(
        Rect.fromLTWH(-1, 0, 2, h * 0.18),
        Paint()..color = const Color(0xFF555555),
      );
      // Flag — yellow/gold when raised, grey when down.
      final flagColor = _delivered
          ? const Color(0xFFFFD600)
          : const Color(0xFF888888);
      canvas.drawRect(
        Rect.fromLTWH(1, 0, w * 0.22, h * 0.13),
        Paint()..color = flagColor,
      );
      canvas.drawRect(
        Rect.fromLTWH(1, 0, w * 0.22, h * 0.13),
        Paint()
          ..color = const Color(0xFF222222)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 0.8,
      );
      canvas.restore();
    } else {
      // Red (forbidden) mailbox: black X marking.
      final xPaint = Paint()
        ..color = const Color(0xFF1A1A1A)
        ..strokeWidth = 2.5;
      canvas.drawLine(
        Offset(w * 0.32, h * 0.30),
        Offset(w * 0.62, h * 0.50),
        xPaint,
      );
      canvas.drawLine(
        Offset(w * 0.62, h * 0.30),
        Offset(w * 0.32, h * 0.50),
        xPaint,
      );
    }

    // Bright glow after delivery.
    if (_glowTimer > 0) {
      final phase = _glowTimer / _glowDuration;
      canvas.drawCircle(
        Offset(w * 0.5, h * 0.35),
        w * (0.8 + (1.0 - phase) * 0.3),
        Paint()
          ..color = (isBlue
                  ? const Color(0xFFFFD600)
                  : const Color(0xFFEF5350))
              .withValues(alpha: phase * 0.55),
      );
    }
  }
}
