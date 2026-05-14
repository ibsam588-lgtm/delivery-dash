import 'dart:math';
import 'package:flame/components.dart';
import '../delivery_dash_game.dart';
import 'mailbox.dart';

enum HouseSide { left, right }

class HouseComponent extends SpriteComponent with HasGameRef<DeliveryDashGame> {
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
          size: Vector2.all(64),
          anchor: Anchor.topLeft,
          priority: -5,
        );

  String _spriteFor(int idx) => idx.isEven ? 'house_2.png' : 'house_3.png';

  void _layout() {
    final lm = gameRef.laneManager;
    final sw = lm.sidewalkWidth;
    // House fills 90% of sidewalk width, capped to a sane range.
    final houseW = (sw * 0.9).clamp(40.0, 110.0);
    size = Vector2(houseW, houseW * 1.25);
    final inset = ((sw - houseW) / 2).clamp(0.0, sw);
    final x = side == HouseSide.left
        ? inset
        : gameRef.size.x - sw + inset;
    position = Vector2(x, _initialY);
  }

  @override
  Future<void> onLoad() async {
    sprite = Sprite(gameRef.images.fromCache(_spriteFor(_index)));
    _layout();
    _regenerateMailbox();
  }

  void _regenerateMailbox() {
    _mailbox?.removeFromParent();
    _mailbox = null;

    final r = _rng.nextDouble();
    if (r > 0.85) return;
    final isBlue = r > 0.15;
    final mb = MailboxComponent(isBlue: isBlue);

    final double localX = side == HouseSide.left ? size.x + 4 : -4;
    final double localY = size.y * 0.65;
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
