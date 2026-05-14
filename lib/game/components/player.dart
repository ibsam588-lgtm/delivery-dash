import 'dart:ui';
import 'package:flame/collisions.dart';
import 'package:flame/components.dart';
import 'package:flame/effects.dart';
import 'package:flutter/animation.dart';
import '../delivery_dash_game.dart';

class PlayerComponent extends SpriteComponent
    with HasGameRef<DeliveryDashGame>, CollisionCallbacks {
  static const Color vipTint = Color(0xCCFFD54F);
  static const double _flashInterval = 0.1;

  final bool isVip;

  int currentLane = 1;
  double _flashTimer = 0;
  MoveByEffect? _moveEffect;

  PlayerComponent({this.isVip = false})
      : super(size: Vector2(78, 84), anchor: Anchor.center, priority: 5);

  @override
  Future<void> onLoad() async {
    sprite = await gameRef.loadSprite('mailbox_blue.png');
    if (isVip) {
      paint = Paint()
        ..colorFilter = const ColorFilter.mode(vipTint, BlendMode.srcATop);
    }
    final lm = gameRef.laneManager;
    position = Vector2(lm.laneX(1), gameRef.size.y - 150);
    add(RectangleHitbox(
      size: Vector2(54, 60),
      position: Vector2((size.x - 54) / 2, (size.y - 60) / 2),
    ));
  }

  void _moveToLane(int newLane) {
    final lm = gameRef.laneManager;
    final targetX = lm.laneX(newLane);
    final dx = targetX - position.x;
    if (dx.abs() < 0.5) return;
    _moveEffect?.removeFromParent();
    final durationSec = gameRef.config.difficultyConfig.laneSwitchMs / 1000.0;
    _moveEffect = MoveByEffect(
      Vector2(dx, 0),
      EffectController(duration: durationSec, curve: Curves.easeInOut),
    );
    add(_moveEffect!);
    currentLane = newLane;
  }

  void moveLeft() {
    if (currentLane > 0) _moveToLane(currentLane - 1);
  }

  void moveRight() {
    if (currentLane < 2) _moveToLane(currentLane + 1);
  }

  @override
  void update(double dt) {
    super.update(dt);
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
}
