import 'dart:math';
import 'package:flame/components.dart';
import '../delivery_dash_game.dart';
import '../systems/lane_manager.dart';

enum HouseSide { left, right }

class HouseComponent extends SpriteComponent with HasGameRef<DeliveryDashGame> {
  static const double _houseSize = 88.0;
  static const double _scrollFactor = 1.0;
  static const double rowSpacing = 128.0;

  final HouseSide side;
  final double _initialY;
  int _variant;
  final Random _rng = Random();

  HouseComponent({
    required this.side,
    required double initialY,
    required int variant,
  })  : _initialY = initialY,
        _variant = variant,
        super(
          size: Vector2.all(_houseSize),
          anchor: Anchor.topLeft,
          priority: -5,
        );

  @override
  Future<void> onLoad() async {
    sprite = Sprite(gameRef.images.fromCache('house_$_variant.png'));
    position
      ..y = _initialY
      ..x = side == HouseSide.left
          ? (LaneManager.sidewalkWidth - _houseSize) / 2
          : gameRef.size.x -
              LaneManager.sidewalkWidth +
              (LaneManager.sidewalkWidth - _houseSize) / 2;
  }

  @override
  void update(double dt) {
    super.update(dt);
    if (gameRef.state != GameState.playing) return;

    position.y += gameRef.scrollSpeed * _scrollFactor * dt;

    if (position.y > gameRef.size.y) {
      final rows = (gameRef.size.y / rowSpacing).ceil() + 2;
      position.y -= rows * rowSpacing;
      _variant = _rng.nextInt(4);
      sprite = Sprite(gameRef.images.fromCache('house_$_variant.png'));
    }
  }
}
