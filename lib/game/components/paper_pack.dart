import 'dart:math';
import 'dart:ui';
import 'package:flame/collisions.dart';
import 'package:flame/components.dart';
import '../delivery_dash_game.dart';
import 'player.dart';

/// A spinning stack-of-papers pickup. Riding over it adds papers to the
/// player's stash.
class PaperPackComponent extends PositionComponent
    with HasGameRef<DeliveryDashGame>, CollisionCallbacks {
  static const int paperGain = 3;

  final double laneFraction;
  final Vector2 _baseSize = Vector2(28, 32);
  bool _collected = false;
  double _life = 0;

  PaperPackComponent({required this.laneFraction})
      : super(anchor: Anchor.bottomCenter, priority: 4);

  @override
  Future<void> onLoad() async {
    final lm = gameRef.laneManager;
    const initialY = -10.0;
    final scale = lm.scaleAt(initialY);
    size = _baseSize * scale;
    position = Vector2(
      lm.roadXFromFraction(laneFraction, initialY),
      initialY,
    );
    add(RectangleHitbox(
      size: size * 0.95,
      position: size * 0.025,
      collisionType: CollisionType.passive,
    ));
  }

  @override
  void update(double dt) {
    super.update(dt);
    if (_collected) return;
    _life += dt;
    position.y += gameRef.scrollSpeed * dt;

    final lm = gameRef.laneManager;
    final scale = lm.scaleAt(position.y);
    final newSize = _baseSize * scale;
    if ((newSize - size).length > 0.5) {
      size = newSize;
      for (final c in children.whereType<RectangleHitbox>().toList()) {
        c.size.setFrom(size * 0.95);
        c.position.setFrom(size * 0.025);
      }
    }
    position.x = lm.roadXFromFraction(laneFraction, position.y);

    if (position.y > gameRef.size.y + size.y) {
      removeFromParent();
    }
  }

  @override
  void render(Canvas canvas) {
    // Rotate the whole pack ~90deg/s for that spinning-pickup feel.
    final rotation = _life * (pi / 2);
    canvas.save();
    canvas.translate(size.x / 2, size.y / 2);
    canvas.rotate(rotation);
    canvas.translate(-size.x / 2, -size.y / 2);

    // Shadow behind.
    canvas.drawRect(
      Rect.fromLTWH(2, size.y * 0.6, size.x - 4, 4),
      Paint()..color = const Color(0x55000000),
    );

    // Stack of paper rectangles, slightly offset.
    final w = size.x;
    final h = size.y;
    final paperPaint = Paint()..color = const Color(0xFFFFFFFF);
    final stroke = Paint()
      ..color = const Color(0xFF263238)
      ..strokeWidth = 1.4
      ..style = PaintingStyle.stroke;
    for (var i = 2; i >= 0; i--) {
      final dx = i * 2.0;
      final dy = i * 2.5;
      final r = Rect.fromLTWH(2 + dx, 2 + dy, w - 4 - dx, h * 0.7 - dy);
      canvas.drawRect(r, paperPaint);
      canvas.drawRect(r, stroke);
    }

    // Yellow star on the top sheet.
    final starCenter = Offset(w * 0.5, h * 0.32);
    _drawStar(canvas, starCenter, w * 0.18,
        Paint()..color = const Color(0xFFFFD54F));

    canvas.restore();
  }

  void _drawStar(Canvas canvas, Offset c, double r, Paint paint) {
    final path = Path();
    const points = 5;
    for (var i = 0; i < points * 2; i++) {
      final radius = i.isEven ? r : r * 0.45;
      final theta = -pi / 2 + i * pi / points;
      final p = Offset(c.dx + radius * cos(theta), c.dy + radius * sin(theta));
      if (i == 0) {
        path.moveTo(p.dx, p.dy);
      } else {
        path.lineTo(p.dx, p.dy);
      }
    }
    path.close();
    canvas.drawPath(path, paint);
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
