import 'dart:math';
import 'dart:ui';
import 'package:flame/components.dart';
import 'package:flame/flame.dart';
import '../delivery_dash_game.dart';
import 'mailbox.dart';

class HouseComponent extends SpriteComponent with HasGameRef<DeliveryDashGame> {
  static const double rowSpacing = 180.0;
  static const double baseWidth = 110.0;

  final double _initialY;
  int _index;
  final Random _rng = Random();
  final Vector2 _baseSize = Vector2(baseWidth, baseWidth * (380.0 / 370.0));

  MailboxComponent? _mailbox;

  HouseComponent({
    required double initialY,
    required int index,
  })  : _initialY = initialY,
        _index = index,
        super(
          size: Vector2(baseWidth, baseWidth * (380.0 / 370.0)),
          anchor: Anchor.bottomLeft,
          priority: -5,
        );

  String _spriteFor(int idx) => idx.isEven ? 'house_2.png' : 'house_3.png';

  void _layout() {
    final lm = gameRef.laneManager;
    final y = _initialY;
    final scale = lm.scaleAt(y);
    size = _baseSize * scale;

    // House X = inside the left sidewalk, hugging the road-facing side
    // so the mailbox stays close to the road edge.
    final sidewalkRight = lm.roadLeftAt(y);
    const sidewalkLeft = 0.0;
    final houseRight = sidewalkRight - 4 * scale;
    position = Vector2(houseRight - size.x, y);
    // Keep at least some margin from the screen edge.
    if (position.x < sidewalkLeft + 2) {
      position.x = sidewalkLeft + 2;
    }
  }

  @override
  Future<void> onLoad() async {
    sprite = Sprite(Flame.images.fromCache(_spriteFor(_index)));
    _layout();
    _regenerateMailbox();
  }

  void _regenerateMailbox() {
    _mailbox?.removeFromParent();
    _mailbox = null;

    final r = _rng.nextDouble();
    if (r < 0.10) return;
    final isBlue = r < 0.80;
    final mb = MailboxComponent(isBlue: isBlue);
    mb.position = Vector2(size.x + 4, size.y * 0.42);
    add(mb);
    _mailbox = mb;
  }

  @override
  void render(Canvas canvas) {
    canvas.drawOval(
      Rect.fromLTWH(2, size.y - 6, size.x - 4, 8),
      Paint()..color = const Color(0x55000000),
    );
    super.render(canvas);
  }

  @override
  void update(double dt) {
    super.update(dt);
    if (gameRef.state != GameState.playing) return;

    position.y += gameRef.scrollSpeed * dt;

    final lm = gameRef.laneManager;
    final scale = lm.scaleAt(position.y);
    size = _baseSize * scale;

    final sidewalkRight = lm.roadLeftAt(position.y);
    final desiredRight = sidewalkRight - 4 * scale;
    position.x = (desiredRight - size.x).clamp(2.0, sidewalkRight - 4);

    // Tell child mailbox to update its local position to keep it
    // anchored at the road edge of the (now resized) house.
    final mb = _mailbox;
    if (mb != null && mb.isMounted) {
      mb.position = Vector2(size.x + 4, size.y * 0.42);
      mb.updateScale(scale);
    }

    if (position.y > gameRef.size.y + size.y) {
      final rows = (gameRef.size.y / rowSpacing).ceil() + 2;
      position.y -= rows * rowSpacing;
      _index += 2;
      sprite = Sprite(Flame.images.fromCache(_spriteFor(_index)));
      _regenerateMailbox();
    }
  }
}
