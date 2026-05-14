import 'dart:ui';
import 'package:flame/collisions.dart';
import 'package:flame/components.dart';
import 'package:flame/flame.dart';
import '../delivery_dash_game.dart';

class PlayerComponent extends SpriteComponent
    with HasGameRef<DeliveryDashGame>, CollisionCallbacks {
  static const Color vipTint = Color(0xCCFFD54F);
  static const double _followSpeed = 8.0;
  static const double _flashInterval = 0.1;

  final bool isVip;
  double _targetX = 0;
  double _flashTimer = 0;

  // Wet/drenched effect.
  double _wetTimer = 0; // seconds remaining of wet overlay
  static const double _wetDuration = 0.4;

  PlayerComponent({this.isVip = false})
      : super(size: Vector2(55, 80), anchor: Anchor.bottomCenter, priority: 5);

  @override
  Future<void> onLoad() async {
    sprite = Sprite(Flame.images.fromCache('mailbox_blue.png'));
    if (isVip) {
      paint = Paint()
        ..colorFilter = const ColorFilter.mode(vipTint, BlendMode.srcATop);
    }
    final lm = gameRef.laneManager;
    _targetX = lm.roadCenterAt(gameRef.size.y * 0.75);
    position = Vector2(_targetX, gameRef.size.y * 0.85);
    add(RectangleHitbox(
      size: Vector2(38, 60),
      position: Vector2((size.x - 38) / 2, size.y - 60),
    ));
  }

  void moveTo(double worldX) {
    _targetX =
        gameRef.laneManager.clampToRoadAt(position.y, worldX, size.x / 2);
  }

  void triggerWetFlash() {
    _wetTimer = _wetDuration;
  }

  @override
  void update(double dt) {
    super.update(dt);

    final dx = _targetX - position.x;
    final t = (_followSpeed * dt).clamp(0.0, 1.0);
    position.x += dx * t;

    if (_wetTimer > 0) {
      _wetTimer = (_wetTimer - dt).clamp(0.0, _wetDuration);
    }

    if (gameRef.isInvincible) {
      _flashTimer += dt;
      if (_flashTimer >= _flashInterval) {
        _flashTimer = 0;
        opacity = opacity > 0.5 ? 0.25 : 1.0;
      }
    } else {
      _flashTimer = 0;
      if (opacity != 1.0) opacity = 1.0;
    }
  }

  @override
  void render(Canvas canvas) {
    super.render(canvas);
    if (_wetTimer > 0) {
      // Triangle wet overlay: 0 -> 0.4 -> 0 alpha across _wetDuration.
      final phase = _wetTimer / _wetDuration; // 1 -> 0
      final alpha = (1 - (phase - 0.5).abs() * 2) * 0.4;
      final paint = Paint()
        ..color = const Color(0xFF42A5F5).withValues(alpha: alpha);
      canvas.drawRect(Rect.fromLTWH(0, 0, size.x, size.y), paint);
    }
  }
}
