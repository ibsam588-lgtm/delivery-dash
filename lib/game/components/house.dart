import 'dart:math';
import 'dart:ui';
import 'package:flame/components.dart';
import 'package:flame/flame.dart';
import '../delivery_dash_game.dart';
import 'house_window.dart';
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
  final List<HouseWindow> _windows = [];

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
    final roadLeft = lm.roadLeft;
    // If the house won't physically fit on the sidewalk, shrink it.
    // Otherwise keep the configured fixed size. Aspect ratio preserved.
    final fitWidth = (roadLeft - 8).clamp(40.0, fixedWidth);
    final sizeChanged = (fitWidth - size.x).abs() > 0.5;
    if (sizeChanged) {
      size = Vector2(fitWidth, fitWidth * (fixedHeight / fixedWidth));
      _layoutWindows();
    }
    // Place the house so its right edge is just inside the curb.
    // Never produce a negative X (which would put the house off-screen).
    final x = roadLeft - size.x - 4;
    position.x = x < 0 ? 0 : x;
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
    _spawnWindows();
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

  /// Create two windows on the road-facing edge of the house. Called once
  /// per house lifetime; on recycle the existing windows are reset via
  /// [restore()] rather than rebuilt.
  void _spawnWindows() {
    final w1 = HouseWindow(position: Vector2.zero());
    final w2 = HouseWindow(position: Vector2.zero());
    _windows
      ..clear()
      ..add(w1)
      ..add(w2);
    add(w1);
    add(w2);
    _layoutWindows();
  }

  void _layoutWindows() {
    if (_windows.isEmpty) return;
    // Place them on the right portion of the facade (facing the road),
    // upper and middle vertically. Sized proportional to the house.
    final winW = (size.x * 0.18).clamp(12.0, 22.0);
    final winH = (size.y * 0.16).clamp(12.0, 22.0);
    final winSize = Vector2(winW, winH);
    final rightX = size.x - winW * 0.75 - 6;
    _windows[0]
      ..size = winSize
      ..position = Vector2(rightX, size.y * 0.20);
    _windows[1]
      ..size = winSize
      ..position = Vector2(rightX, size.y * 0.42);
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
      for (final w in _windows) {
        w.restore();
      }
    }
  }
}
