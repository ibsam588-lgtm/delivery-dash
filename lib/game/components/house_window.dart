import 'dart:math';
import 'dart:ui';
import 'package:flame/collisions.dart';
import 'package:flame/components.dart';
import '../delivery_dash_game.dart';

/// A pane of glass on a house facade. Paper hits trip [breakWindow], which
/// swaps the visual to a cracked state, removes the hitbox so subsequent
/// papers pass through, and awards a small bonus (handled by the game).
class HouseWindow extends PositionComponent
    with HasGameRef<DeliveryDashGame>, CollisionCallbacks {
  static const int bonusPoints = 15;

  bool broken = false;
  double _flashTimer = 0;
  static const double _flashDuration = 0.20;

  // Impact point in local coords (set when window breaks).
  double _impactX = 0;
  double _impactY = 0;

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

  /// [worldHit] is the world-space collision point from the paper.
  void breakWindow([Vector2? worldHit]) {
    if (broken) return;
    broken = true;
    _flashTimer = _flashDuration;

    if (worldHit != null) {
      // Convert world hit to local window coords.
      final topLeft = absolutePosition - size / 2;
      _impactX = (worldHit.x - topLeft.x).clamp(2.0, size.x - 2);
      _impactY = (worldHit.y - topLeft.y).clamp(2.0, size.y - 2);
    } else {
      _impactX = size.x * 0.55;
      _impactY = size.y * 0.45;
    }

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
    // Thick white frame (drawn after fill).
    final frame = Paint()
      ..color = const Color(0xFFFAFAFA)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3;

    if (!broken) {
      // Glassy pane.
      canvas.drawRect(
        Rect.fromLTWH(0, 0, size.x, size.y),
        Paint()..color = const Color(0xFFB3E5FC),
      );

      // Curtain triangles at each side (random soft colour).
      final cc = curtainColor;
      if (cc != null) {
        final curtainPaint = Paint()..color = cc.withValues(alpha: 0.75);
        // Left curtain: triangle along left edge, hangs from top.
        final leftCurtain = Path()
          ..moveTo(0, 0)
          ..lineTo(size.x * 0.32, 0)
          ..lineTo(0, size.y * 0.85)
          ..close();
        canvas.drawPath(leftCurtain, curtainPaint);
        // Right curtain: mirror.
        final rightCurtain = Path()
          ..moveTo(size.x, 0)
          ..lineTo(size.x * 0.68, 0)
          ..lineTo(size.x, size.y * 0.85)
          ..close();
        canvas.drawPath(rightCurtain, curtainPaint);
        // Subtle fold highlight on each curtain.
        final foldPaint = Paint()
          ..color = const Color(0x55FFFFFF)
          ..strokeWidth = 1.0;
        canvas.drawLine(
          Offset(size.x * 0.10, 0),
          Offset(0, size.y * 0.55),
          foldPaint,
        );
        canvas.drawLine(
          Offset(size.x * 0.90, 0),
          Offset(size.x, size.y * 0.55),
          foldPaint,
        );
      }

      // White cross mullion (vertical + horizontal).
      final mullion = Paint()
        ..color = const Color(0xFFFAFAFA)
        ..strokeWidth = 2.5;
      canvas.drawLine(
          Offset(size.x / 2, 0), Offset(size.x / 2, size.y), mullion);
      canvas.drawLine(
          Offset(0, size.y / 2), Offset(size.x, size.y / 2), mullion);
      // Highlight (glare in top-left pane).
      canvas.drawRect(
        Rect.fromLTWH(2, 2, size.x * 0.20, size.y * 0.20),
        Paint()..color = const Color(0x99FFFFFF),
      );
      canvas.drawRect(Rect.fromLTWH(0, 0, size.x, size.y), frame);
    } else {
      // Dark interior.
      canvas.drawRect(
        Rect.fromLTWH(0, 0, size.x, size.y),
        Paint()..color = const Color(0xFF161616),
      );

      // ── Spiderweb crack pattern ──────────────────────────────────────
      final cx = _impactX;
      final cy = _impactY;
      final crack = Paint()
        ..color = const Color(0xFFDDDDDD)
        ..strokeWidth = 0.9
        ..strokeCap = StrokeCap.round;
      final branchPaint = Paint()
        ..color = const Color(0xFFBBBBBB)
        ..strokeWidth = 0.6
        ..strokeCap = StrokeCap.round;

      // 8 primary rays from impact point.
      const numRays = 8;
      for (int i = 0; i < numRays; i++) {
        final angle = i * 2 * pi / numRays;
        // Ray length varies for natural look.
        final rayLen = (i.isEven ? 1.0 : 0.75) *
            (size.x > size.y ? size.x : size.y) * 0.85;
        final ex = cx + cos(angle) * rayLen;
        final ey = cy + sin(angle) * rayLen;
        canvas.drawLine(Offset(cx, cy), Offset(ex, ey), crack);

        // 2 branches on each primary ray.
        for (int b = 0; b < 2; b++) {
          final t = b == 0 ? 0.35 : 0.65; // fraction along ray
          final bx = cx + cos(angle) * rayLen * t;
          final by = cy + sin(angle) * rayLen * t;
          final branchAngle = angle + (b == 0 ? 0.55 : -0.55);
          final branchLen = rayLen * (0.35 - b * 0.10);
          canvas.drawLine(
            Offset(bx, by),
            Offset(bx + cos(branchAngle) * branchLen,
                by + sin(branchAngle) * branchLen),
            branchPaint,
          );
        }
      }

      // Tiny glass chip shards around impact.
      final shard = Paint()..color = const Color(0xCCB3E5FC);
      canvas.drawRect(Rect.fromLTWH(cx - 4, cy - 1, 3, 3), shard);
      canvas.drawRect(Rect.fromLTWH(cx + 2, cy + 2, 2, 2), shard);
      canvas.drawRect(Rect.fromLTWH(cx - 1, cy + 4, 2, 2), shard);

      canvas.drawRect(Rect.fromLTWH(0, 0, size.x, size.y), frame);
    }

    // Flash: bright expanding circle that fades over 100 ms.
    if (_flashTimer > 0) {
      final progress = 1.0 - (_flashTimer / _flashDuration); // 0→1
      final radius = (size.x + size.y) * progress * 1.2;
      final alpha = _flashTimer / _flashDuration; // 1→0
      canvas.save();
      canvas.clipRect(Rect.fromLTWH(0, 0, size.x, size.y));
      canvas.drawCircle(
        Offset(_impactX, _impactY),
        radius,
        Paint()..color = const Color(0xFFFFFFFF).withValues(alpha: alpha),
      );
      canvas.restore();
    }
  }
}
