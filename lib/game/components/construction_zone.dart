import 'dart:ui';
import 'package:flame/components.dart';
import '../delivery_dash_game.dart';
import 'obstacle.dart';

/// A 200px tall "construction zone" band that scrolls with the world.
/// While the player is inside the band their speed is throttled to 70%.
/// Renders a row of orange caution chevrons along each edge so the zone
/// is visually distinct from the asphalt around it. The zone also seeds
/// a zigzag of cone obstacles inside it on spawn.
class ConstructionZoneComponent extends PositionComponent
    with HasGameRef<DeliveryDashGame> {
  static const double zoneHeight = 200.0;

  bool _playerInside = false;
  bool _seeded = false;

  ConstructionZoneComponent()
      : super(
          size: Vector2(0, zoneHeight),
          anchor: Anchor.topLeft,
          priority: -7,
        );

  @override
  Future<void> onLoad() async {
    size = Vector2(gameRef.size.x, zoneHeight);
    position = Vector2(0, -zoneHeight);
  }

  void _seedCones() {
    if (_seeded) return;
    _seeded = true;
    // Zigzag of 4 cones across the road, anchored to this band's Y.
    const fractions = [0.25, 0.50, 0.40, 0.65];
    final lm = gameRef.laneManager;
    for (int i = 0; i < fractions.length; i++) {
      final yOff = 30.0 + i * 45.0;
      // Pass the desired position via override — otherwise ObstacleComponent.onLoad
      // resets it to a default spawn point near the horizon.
      gameRef.add(ObstacleComponent(
        type: ObstacleType.cone,
        laneFraction: fractions[i],
        initialPositionOverride: Vector2(
          lm.roadXFromFraction(fractions[i]),
          position.y + yOff,
        ),
      ));
    }
  }

  @override
  void update(double dt) {
    super.update(dt);
    if (gameRef.state != GameState.playing) return;
    position.y += gameRef.scrollSpeed * dt;

    // Seed the cones once we are about to appear on-screen.
    if (!_seeded && position.y > -zoneHeight * 0.5) {
      _seedCones();
    }

    final playerY = gameRef.player.position.y;
    final inside =
        playerY >= position.y && playerY <= position.y + zoneHeight;
    if (inside && !_playerInside) {
      _playerInside = true;
      gameRef.applyConstructionSlow();
    } else if (!inside && _playerInside) {
      _playerInside = false;
      gameRef.clearConstructionSlow();
    }

    if (position.y > gameRef.size.y) {
      if (_playerInside) {
        _playerInside = false;
        gameRef.clearConstructionSlow();
      }
      removeFromParent();
    }
  }

  @override
  void render(Canvas canvas) {
    final lm = gameRef.laneManager;
    final left = lm.roadLeft;
    final right = lm.roadRight;
    final w = right - left;

    // Orange caution stripes along each edge of the road inside the zone.
    final orange = Paint()..color = const Color(0xFFFF9800);
    final dark = Paint()..color = const Color(0xFF2A2A2A);
    const stripeH = 14.0;
    for (double y = 0; y < zoneHeight; y += stripeH * 2) {
      canvas.drawRect(Rect.fromLTWH(left + 2, y, 8, stripeH), orange);
      canvas.drawRect(Rect.fromLTWH(left + 2, y + stripeH, 8, stripeH), dark);
      canvas.drawRect(Rect.fromLTWH(right - 10, y, 8, stripeH), orange);
      canvas.drawRect(Rect.fromLTWH(right - 10, y + stripeH, 8, stripeH), dark);
    }

    // "SLOW" tint across the road body inside the zone.
    canvas.drawRect(
      Rect.fromLTWH(left + 12, 0, w - 24, zoneHeight),
      Paint()..color = const Color(0x22FF9800),
    );
  }
}
