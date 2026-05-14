import 'dart:math';
import 'package:flame/components.dart';
import '../delivery_dash_game.dart';
import 'mailbox.dart';

enum HouseSide { left, right }

class HouseComponent extends SpriteComponent with HasGameRef<DeliveryDashGame> {
  static const double houseSize = 96.0;
  static const double rowSpacing = 140.0;

  final HouseSide side;
  final double _initialY;
  int _index;
  final Random _rng = Random();

  MailboxComponent? _mailbox;

  HouseComponent({
    required this.side,
    required double initialY,
    required int index,
  })  : _initialY = initialY,
        _index = index,
        super(
          size: Vector2.all(houseSize),
          anchor: Anchor.topLeft,
          priority: -5,
        );

  String _spriteFor(int idx) => idx.isEven ? 'house_2.png' : 'house_3.png';

  double _xForHouse() {
    final lm = gameRef.laneManager;
    final sw = lm.sidewalkWidth;
    final inset = ((sw - houseSize) / 2).clamp(2.0, sw - houseSize - 2.0);
    if (side == HouseSide.left) {
      return inset;
    } else {
      return gameRef.size.x - sw + inset;
    }
  }

  @override
  Future<void> onLoad() async {
    sprite = Sprite(gameRef.images.fromCache(_spriteFor(_index)));
    position = Vector2(_xForHouse(), _initialY);
    _regenerateMailbox();
  }

  void _regenerateMailbox() {
    _mailbox?.removeFromParent();
    _mailbox = null;

    final r = _rng.nextDouble();
    if (r > 0.85) return;
    final isBlue = r > 0.15;
    final mb = MailboxComponent(isBlue: isBlue);

    final double localX = side == HouseSide.left
        ? houseSize + 6
        : -6;
    const double localY = houseSize * 0.68;
    mb.position = Vector2(localX, localY);
    add(mb);
    _mailbox = mb;
  }

  @override
  void update(double dt) {
    super.update(dt);
    if (gameRef.state != GameState.playing) return;

    position.y += gameRef.scrollSpeed * dt;

    if (position.y > gameRef.size.y) {
      final rows = (gameRef.size.y / rowSpacing).ceil() + 2;
      position.y -= rows * rowSpacing;
      _index += 2;
      sprite = Sprite(gameRef.images.fromCache(_spriteFor(_index)));
      _regenerateMailbox();
    }
  }
}
