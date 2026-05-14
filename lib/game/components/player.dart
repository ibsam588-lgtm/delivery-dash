import 'dart:ui';
import 'package:flame/collisions.dart';
import 'package:flame/components.dart';
import 'package:flame/flame.dart';
import '../delivery_dash_game.dart';
import '../perspective.dart';
import 'bike_trail.dart';

/// Sprite-based player. Fixed size, flat top-down, drag-to-move.
class PlayerComponent extends SpriteComponent
    with HasGameRef<DeliveryDashGame>, CollisionCallbacks {
  static const Color vipTint = Color(0xCCFFD54F);
  static const double _followSpeed = 8.0;
  static const double _flashInterval = 0.1;
  static const double _trailInterval = 0.06;

  final bool isVip;
  double _targetX = 0;
  double _flashTimer = 0;
  double _trailTimer = 0;

  // Wet flash overlay.
  double _wetTimer = 0;
  static const double _wetDuration = 0.4;

  PlayerComponent({this.isVip = false})
      : super(size: Vector2(55, 80), anchor: Anchor.center, priority: 5);

  @override
  Future<void> onLoad() async {
    sprite = Sprite(Flame.images.fromCache('player.png'));
    paint
      ..filterQuality = FilterQuality.none
      ..isAntiAlias = false;
    if (isVip) {
      paint.colorFilter =
          const ColorFilter.mode(vipTint, BlendMode.srcATop);
    }
    final lm = gameRef.laneManager;
    _targetX = lm.roadCenter;
    position = Vector2(_targetX, gameRef.size.y * 0.82);
    add(RectangleHitbox(
      size: Vector2(38, 62),
      position: Vector2((size.x - 38) / 2, (size.y - 62) / 2),
    ));
  }

  void moveTo(double worldX) {
    _targetX = gameRef.laneManager.clampToRoad(worldX, size.x / 2);
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

    // Emit a dust puff at the rear wheel periodically while playing.
    if (gameRef.state == GameState.playing) {
      _trailTimer += dt;
      if (_trailTimer >= _trailInterval) {
        _trailTimer = 0;
        gameRef.add(BikeTrailPuff(
          position: position + Vector2(0, size.y * 0.35),
        ));
      }
    }
  }

  @override
  void render(Canvas canvas) {
    final h = gameRef.size.y;
    final s = depthScale(position.y, h);
    final dx = depthXShift(
      position.x,
      position.y,
      gameRef.laneManager.roadCenter,
      h,
    );
    canvas.translate(dx, 0);

    // Ground shadow beneath the bike (depth-scaled).
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(size.x / 2, size.y - 2),
        width: size.x * 0.85 * s,
        height: 11 * s,
      ),
      Paint()..color = const Color(0x66000000),
    );

    canvas.save();
    // Apply depth scale + a 15% vertical squish for the top-down feel.
    canvas.translate(size.x / 2, size.y / 2);
    canvas.scale(s, s * 0.85);
    canvas.translate(-size.x / 2, -size.y / 2);
    super.render(canvas);
    if (_wetTimer > 0) {
      final phase = _wetTimer / _wetDuration;
      final alpha = (1 - (phase - 0.5).abs() * 2) * 0.4;
      canvas.drawRect(
        Rect.fromLTWH(0, 0, size.x, size.y),
        Paint()..color = const Color(0xFF42A5F5).withValues(alpha: alpha),
      );
    }
    canvas.restore();
  }
}
