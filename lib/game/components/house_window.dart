import 'dart:ui';
import 'package:flame/collisions.dart';
import 'package:flame/components.dart';
import '../delivery_dash_game.dart';

/// A pane of glass on a house facade. Paper hits trip [breakWindow], which
/// swaps the visual to a cracked state, removes the hitbox so subsequent
/// papers pass through, and awards a small bonus (handled by the game).
class HouseWindow extends PositionComponent
    with HasGameRef<DeliveryDashGame>, CollisionCallbacks {
  static const int bonusPoints = 4;

  bool broken = false;
  double _flashTimer = 0;
  static const double _flashDuration = 0.2;

  final Color? curtainColor;

  RectangleHitbox? _hitbox;

  HouseWindow({
    required Vector2 position,
    Vector2? size,
    this.curtainColor,
  }) : super(
          position: position,
          size: size ?? Vector2(18, 18),
          anchor: Anchor.center,
          priority: 1,
        );

  @override
  Future<void> onLoad() async {
    _hitbox = RectangleHitbox(
      size: size * 0.95,
      position: size * 0.025,
      collisionType: CollisionType.passive,
    );
    add(_hitbox!);
  }

  void breakWindow() {
    if (broken) return;
    broken = true;
    _flashTimer = _flashDuration;
    _hitbox?.removeFromParent();
    _hitbox = null;
  }

  /// Reset to intact (used when the parent house recycles to the top).
  void restore() {
    broken = false;
    _flashTimer = 0;
    if (_hitbox == null) {
      _hitbox = RectangleHitbox(
        size: size * 0.95,
        position: size * 0.025,
        collisionType: CollisionType.passive,
      );
      add(_hitbox!);
    }
  }

  @override
  void update(double dt) {
    super.update(dt);
    if (_flashTimer > 0) {
      _flashTimer = (_flashTimer - dt).clamp(0.0, _flashDuration);
    }
  }

  @override
  void render(Canvas canvas) {
    final frame = Paint()
      ..color = const Color(0xFF3E2A1E)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;

    if (!broken) {
      // Glassy pane.
      canvas.drawRect(
        Rect.fromLTWH(0, 0, size.x, size.y),
        Paint()..color = const Color(0xFFB3E5FC),
      );

      // Curtains at the edges (semi-transparent coloured strips).
      final cc = curtainColor;
      if (cc != null) {
        final cw = size.x * 0.22;
        final curtainPaint = Paint()..color = cc.withValues(alpha: 0.55);
        canvas.drawRect(Rect.fromLTWH(0, 0, cw, size.y), curtainPaint);
        canvas.drawRect(Rect.fromLTWH(size.x - cw, 0, cw, size.y), curtainPaint);
      }

      // Cross mullion.
      final mullion = Paint()
        ..color = const Color(0xFF3E2A1E)
        ..strokeWidth = 1.5;
      canvas.drawLine(
        Offset(size.x / 2, 0),
        Offset(size.x / 2, size.y),
        mullion,
      );
      canvas.drawLine(
        Offset(0, size.y / 2),
        Offset(size.x, size.y / 2),
        mullion,
      );
      // Highlight on the upper-left quadrant.
      canvas.drawRect(
        Rect.fromLTWH(2, 2, size.x * 0.28, size.y * 0.28),
        Paint()..color = const Color(0xCCFFFFFF),
      );
      canvas.drawRect(Rect.fromLTWH(0, 0, size.x, size.y), frame);
    } else {
      // Dark interior peeking through busted glass.
      canvas.drawRect(
        Rect.fromLTWH(0, 0, size.x, size.y),
        Paint()..color = const Color(0xFF161616),
      );
      // Crack lines (web pattern radiating from impact point).
      final crack = Paint()
        ..color = const Color(0xFFE0E0E0)
        ..strokeWidth = 1;
      final cx = size.x * 0.55;
      final cy = size.y * 0.45;
      canvas.drawLine(Offset(cx, cy), const Offset(0, 0), crack);
      canvas.drawLine(Offset(cx, cy), Offset(size.x, size.y * 0.15), crack);
      canvas.drawLine(Offset(cx, cy), Offset(size.x, size.y * 0.85), crack);
      canvas.drawLine(Offset(cx, cy), Offset(size.x * 0.2, size.y), crack);
      canvas.drawLine(
        Offset(cx, cy),
        Offset(size.x * 0.75, size.y),
        crack,
      );
      // Small shard slivers around the impact point.
      final shard = Paint()..color = const Color(0xCCB3E5FC);
      canvas.drawRect(Rect.fromLTWH(cx - 4, cy - 1, 3, 3), shard);
      canvas.drawRect(Rect.fromLTWH(cx + 2, cy + 2, 2, 2), shard);
      canvas.drawRect(Rect.fromLTWH(cx - 1, cy + 4, 2, 2), shard);

      canvas.drawRect(Rect.fromLTWH(0, 0, size.x, size.y), frame);
    }

    if (_flashTimer > 0) {
      final a = _flashTimer / _flashDuration;
      canvas.drawRect(
        Rect.fromLTWH(0, 0, size.x, size.y),
        Paint()..color = const Color(0xFFFFFFFF).withValues(alpha: a),
      );
    }
  }
}
