import 'dart:ui';
import 'package:flame/collisions.dart';
import 'package:flame/components.dart';
import 'package:flame/flame.dart';
import '../delivery_dash_game.dart';

/// A parked car on the right sidewalk. Awards bonus points when the
/// player lands a paper on it (handled by PaperComponent). Does not
/// hurt the player.
class ParkedCarComponent extends SpriteComponent
    with HasGameRef<DeliveryDashGame>, CollisionCallbacks {
  static const int bonusPoints = 15;

  final int variant;
  bool _hit = false;
  double _bounce = 0;

  ParkedCarComponent({this.variant = 0})
      : super(
          size: Vector2(56, 90),
          anchor: Anchor.center,
          priority: 2,
        );

  @override
  Future<void> onLoad() async {
    final name = variant.isEven ? 'car_2.png' : 'car_3.png';
    sprite = Sprite(Flame.images.fromCache(name));
    paint
      ..filterQuality = FilterQuality.none
      ..isAntiAlias = false;
    final lm = gameRef.laneManager;
    final x = lm.roadRight + 4 + size.x / 2;
    position = Vector2(x, -size.y);
    add(RectangleHitbox(
      size: size * 0.85,
      position: size * 0.075,
      collisionType: CollisionType.passive,
    ));
  }

  void onPaperHit() {
    _hit = true;
    _bounce = 0.2;
  }

  @override
  void update(double dt) {
    super.update(dt);
    if (gameRef.state == GameState.playing) {
      position.y += gameRef.scrollSpeed * dt;
    }
    if (_bounce > 0) {
      _bounce = (_bounce - dt).clamp(0.0, 0.2);
    }
    if (position.y > gameRef.size.y + size.y) removeFromParent();
  }

  @override
  void render(Canvas canvas) {
    // Long ground shadow.
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(size.x / 2 + 4, size.y - 4),
        width: size.x + 6,
        height: 12,
      ),
      Paint()..color = const Color(0x66000000),
    );
    if (_bounce > 0) {
      final s = 1 + (_bounce / 0.2) * 0.08;
      canvas.save();
      canvas.translate(size.x / 2, size.y / 2);
      canvas.scale(s);
      canvas.translate(-size.x / 2, -size.y / 2);
      super.render(canvas);
      canvas.restore();
    } else {
      super.render(canvas);
    }
    if (_hit) {
      // Briefly outline in gold to show bonus.
      canvas.drawRect(
        Rect.fromLTWH(0, 0, size.x, size.y),
        Paint()
          ..color = const Color(0xCCFFD600)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2,
      );
    }
  }
}
