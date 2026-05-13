import 'dart:math';
import 'package:flame/components.dart';
import '../delivery_dash_game.dart';

enum HouseSide { left, right }

class HouseComponent extends SpriteComponent with HasGameRef<DeliveryDashGame> {
  final HouseSide side;
  int _houseIndex;
  final double _initialY;
  final Random _rng = Random();

  static const double _scrollFactor = 0.5;

  HouseComponent({
    required this.side,
    required double initialY,
    required int houseIndex,
  })  : _houseIndex = houseIndex,
        _initialY = initialY,
        super(size: Vector2(80, 120), anchor: Anchor.topLeft);

  @override
  Future<void> onLoad() async {
    sprite = Sprite(gameRef.images.fromCache('house_$_houseIndex.png'));
    position.y = _initialY;
    position.x = side == HouseSide.left ? 0 : gameRef.size.x - size.x;
  }

  @override
  void update(double dt) {
    super.update(dt);
    if (gameRef.state != GameState.playing) return;

    position.y += gameRef.scrollSpeed * _scrollFactor * dt;

    if (position.y > gameRef.size.y) {
      position.y = -size.y;
      _houseIndex = _rng.nextInt(4);
      sprite = Sprite(gameRef.images.fromCache('house_$_houseIndex.png'));
    }
  }
}
