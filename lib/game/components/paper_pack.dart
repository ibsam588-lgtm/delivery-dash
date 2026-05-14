import 'dart:math';
import 'package:flame/collisions.dart';
import 'package:flame/components.dart';
import 'package:flutter/material.dart';
import '../delivery_dash_game.dart';
import '../perspective.dart';
import 'player.dart';

/// Simple paper-pack pickup. A small yellow card with a darker outline
/// that slowly rotates while it scrolls toward the player.
class PaperPackComponent extends PositionComponent
    with HasGameRef<DeliveryDashGame>, CollisionCallbacks {
  static const int paperGain = 3;

  final double laneFraction;
  bool _collected = false;
  double _life = 0;

  PaperPackComponent({required this.laneFraction})
      : super(
          size: Vector2(26, 30),
          anchor: Anchor.center,
          priority: 4,
        );

  @override
  Future<void> onLoad() async {
    final lm = gameRef.laneManager;
    position = Vector2(lm.roadXFromFraction(laneFraction), -size.y);
    add(RectangleHitbox(
      size: size * 0.9,
      position: size * 0.05,
      collisionType: CollisionType.passive,
    ));
  }

  @override
  void update(double dt) {
    super.update(dt);
    if (_collected) return;
    _life += dt;
    position.y += gameRef.scrollSpeed * dt;
    if (position.y > gameRef.size.y + size.y) {
      removeFromParent();
    }
  }

  @override
  void render(Canvas canvas) {
    final h = gameRef.size.y;
    final s = depthScale(position.y, h);
    final dx = depthXShift(
      position.x,
      position.y,
      gameRef.laneManager.roadCenter,
      h,
    );
    canvas.translate(dx, 0);

    // Rotating spin (~90°/s) + depth scale.
    final rot = _life * (pi / 2);
    canvas.save();
    canvas.translate(size.x / 2, size.y / 2);
    canvas.scale(s);
    canvas.rotate(rot);
    canvas.translate(-size.x / 2, -size.y / 2);

    // Shadow.
    canvas.drawRect(
      Rect.fromLTWH(2, size.y - 3, size.x - 4, 3),
      Paint()..color = const Color(0x55000000),
    );
    // Card body.
    final rect = Rect.fromLTWH(0, 0, size.x, size.y * 0.85);
    canvas.drawRect(rect, Paint()..color = const Color(0xFFFFD600));
    canvas.drawRect(
      rect,
      Paint()
        ..color = const Color(0xFFB37700)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5,
    );
    // White paper sheets visible at the top.
    canvas.drawRect(
      Rect.fromLTWH(3, 3, size.x - 6, 4),
      Paint()..color = Colors.white,
    );
    canvas.drawRect(
      Rect.fromLTWH(3, 9, size.x - 6, 4),
      Paint()..color = Colors.white,
    );

    canvas.restore();
  }

  @override
  void onCollisionStart(
      Set<Vector2> intersectionPoints, PositionComponent other) {
    super.onCollisionStart(intersectionPoints, other);
    if (_collected) return;
    if (other is PlayerComponent) {
      _collected = true;
      gameRef.onPickupPaperPack(paperGain, position.clone());
      removeFromParent();
    }
  }
}
