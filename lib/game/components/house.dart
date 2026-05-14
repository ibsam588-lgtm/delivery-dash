import 'dart:math';
import 'dart:ui';
import 'package:flame/components.dart';
import 'package:flame/flame.dart';
import '../delivery_dash_game.dart';
import 'mailbox.dart';

/// House sits on the left sidewalk and scrolls downward at a fixed
/// size. Uses the house_2 / house_3 sprites alternating per row.
class HouseComponent extends SpriteComponent
    with HasGameRef<DeliveryDashGame> {
  static const double rowSpacing = 180.0;
  static const double fixedWidth = 100.0;
  static const double fixedHeight = 110.0;

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
          size: Vector2(fixedWidth, fixedHeight),
          anchor: Anchor.bottomLeft,
          priority: -5,
        );

  String _spriteFor(int idx) => idx.isEven ? 'house_2.png' : 'house_3.png';

  void _alignToSidewalk() {
    final lm = gameRef.laneManager;
    // Right edge of the house hugs the road's left curb.
    final desiredRight = lm.roadLeft - 4;
    final x = desiredRight - size.x;
    position.x = x.clamp(2.0, lm.roadLeft - size.x - 2);
  }

  @override
  Future<void> onLoad() async {
    sprite = Sprite(Flame.images.fromCache(_spriteFor(_index)));
    paint
      ..filterQuality = FilterQuality.none
      ..isAntiAlias = false;
    position = Vector2(0, _initialY);
    _alignToSidewalk();
    _regenerateMailbox();
  }

  void _regenerateMailbox() {
    _mailbox?.removeFromParent();
    _mailbox = null;
    final r = _rng.nextDouble();
    if (r < 0.10) return;
    final isBlue = r < 0.80;
    final mb = MailboxComponent(isBlue: isBlue);
    mb.position = Vector2(size.x + 6, size.y * 0.6);
    add(mb);
    _mailbox = mb;
  }

  @override
  void render(Canvas canvas) {
    // Soft drop shadow underneath.
    canvas.drawOval(
      Rect.fromLTWH(4, size.y - 6, size.x - 8, 8),
      Paint()..color = const Color(0x55000000),
    );
    super.render(canvas);
  }

  @override
  void update(double dt) {
    super.update(dt);
    if (gameRef.state != GameState.playing) return;
    position.y += gameRef.scrollSpeed * dt;
    _alignToSidewalk();
    if (position.y > gameRef.size.y + size.y) {
      final rows = (gameRef.size.y / rowSpacing).ceil() + 2;
      position.y -= rows * rowSpacing;
      _index += 2;
      sprite = Sprite(Flame.images.fromCache(_spriteFor(_index)));
      _regenerateMailbox();
    }
  }
}
