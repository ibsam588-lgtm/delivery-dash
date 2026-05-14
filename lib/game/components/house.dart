import 'dart:math';
import 'dart:ui';
import 'package:flame/components.dart';
import '../delivery_dash_game.dart';
import 'mailbox.dart';

class HouseComponent extends SpriteComponent with HasGameRef<DeliveryDashGame> {
  static const double rowSpacing = 180.0;
  static const double targetWidth = 110.0;

  final double _initialY;
  int _index;
  final Random _rng = Random();

  MailboxComponent? _mailbox;

  HouseComponent({
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
    final sw = lm.leftSidewalkWidth;
    // House fills most of the left sidewalk, capped to spec target width.
    final houseW = (sw * 0.8).clamp(70.0, targetWidth);
    size = Vector2(houseW, houseW * (380.0 / 370.0));
    final inset = ((sw - houseW) / 2).clamp(2.0, sw - houseW - 2.0);
    position = Vector2(inset, _initialY);
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
    if (r < 0.10) return; // 10% no mailbox
    final isBlue = r < 0.80; // 70% blue, 20% red
    final mb = MailboxComponent(isBlue: isBlue);

    // Mailbox on the road-facing edge of the house (right side, toward road).
    mb.position = Vector2(size.x + 8, size.y * 0.7);
    add(mb);
    _mailbox = mb;
  }

  @override
  void render(Canvas canvas) {
    canvas.drawRect(
      Rect.fromLTWH(4, size.y * 0.88, size.x, 6),
      Paint()..color = const Color(0x55000000),
    );
    super.render(canvas);
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
