import 'dart:math';
import 'dart:ui';
import 'package:flame/collisions.dart';
import 'package:flame/components.dart';
import '../delivery_dash_game.dart';
import 'bike_trail.dart';

/// Player bicycle courier — back-of-bike view, Road Rash perspective.
/// Camera is directly behind the player; the bike fills the bottom-center
/// of the screen with the rider looking forward into the scene.
class PlayerComponent extends PositionComponent
    with HasGameRef<DeliveryDashGame>, CollisionCallbacks {
  static const Color vipTint = Color(0x88FFD54F);
  static const double _followSpeed = 8.0;
  static const double _flashInterval = 0.1;
  static const double _trailInterval = 0.06;
  static const double _pedalInterval = 0.25;

  static const double _swayAmplitudeDeg = 1.5;
  static const double _swayHz = 1.5;
  static const double _throwArmDuration = 0.20;

  final bool isVip;
  double _targetX = 0;
  double _flashTimer = 0;
  double _trailTimer = 0;
  double _opacity = 1.0;
  double _wetTimer = 0;
  double _pedalTimer = 0;
  bool _pedalPhase = false;
  double _swayTimer = 0;
  double _throwArmTimer = 0;
  static const double _wetDuration = 0.4;
  late Sprite _sprite;

  PlayerComponent({this.isVip = false})
      : super(size: Vector2(90, 120), anchor: Anchor.center, priority: 100);

  double get opacity => _opacity;
  set opacity(double v) => _opacity = v.clamp(0.0, 1.0);

  void triggerThrowArm({bool throwLeft = true}) {
    _throwArmTimer = _throwArmDuration;
  }

  @override
  Future<void> onLoad() async {
    _sprite = await Sprite.load('player.png');
    position = Vector2(gameRef.size.x * 0.5, gameRef.size.y * 0.78);
    _targetX = position.x;
    add(RectangleHitbox(
      size: Vector2(56, 78),
      position: Vector2((size.x - 56) / 2, (size.y - 78) / 2),
    ));
  }

  void moveTo(double worldX) {
    final lo = size.x / 2;
    final hi = gameRef.size.x - size.x / 2;
    _targetX = worldX.clamp(lo, hi);
  }

  void triggerWetFlash() {
    _wetTimer = _wetDuration;
  }

  @override
  void update(double dt) {
    super.update(dt);

    _swayTimer += dt;

    _pedalTimer += dt;
    if (_pedalTimer >= _pedalInterval) {
      _pedalTimer = 0;
      _pedalPhase = !_pedalPhase;
    }

    if (_throwArmTimer > 0) {
      _throwArmTimer = (_throwArmTimer - dt).clamp(0.0, _throwArmDuration);
    }

    final dx = _targetX - position.x;
    final t = (_followSpeed * dt).clamp(0.0, 1.0);
    position.x += dx * t;

    // Keep player pinned at 78% down (camera depth).
    position.y = gameRef.size.y * 0.78;

    if (_wetTimer > 0) {
      _wetTimer = (_wetTimer - dt).clamp(0.0, _wetDuration);
    }

    if (gameRef.isInvincible) {
      _flashTimer += dt;
      if (_flashTimer >= _flashInterval) {
        _flashTimer = 0;
        _opacity = _opacity > 0.5 ? 0.25 : 1.0;
      }
    } else {
      _flashTimer = 0;
      _opacity = 1.0;
    }

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
    final needsLayer = _opacity < 1.0;
    if (needsLayer) {
      canvas.saveLayer(
        null,
        Paint()
          ..color = Color.fromARGB((_opacity * 255).round(), 255, 255, 255),
      );
    }
    // Apply gentle sway
    canvas.save();
    canvas.translate(size.x / 2, size.y / 2);
    canvas.rotate(_swayTimer > 0
        ? sin(_swayTimer * _swayHz * 2 * pi) * _swayAmplitudeDeg * pi / 180
        : 0);
    canvas.translate(-size.x / 2, -size.y / 2);
    _sprite.render(canvas, position: Vector2.zero(), size: size);
    canvas.restore();
    if (needsLayer) canvas.restore();
  }
}
