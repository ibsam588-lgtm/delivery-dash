import 'package:flame/components.dart';
import 'package:flutter/material.dart';

class FloatingText extends TextComponent {
  double _lifetime = 1.2;
  final Color _baseColor;

  FloatingText({
    required String text,
    required Vector2 position,
    required Color color,
  })  : _baseColor = color,
        super(
          text: text,
          textRenderer: TextPaint(
            style: TextStyle(
              color: color,
              fontSize: 26,
              fontWeight: FontWeight.w900,
              shadows: const [
                Shadow(color: Colors.black, blurRadius: 4),
                Shadow(color: Colors.black, blurRadius: 2, offset: Offset(1, 1)),
              ],
            ),
          ),
          position: position,
          anchor: Anchor.center,
          priority: 150,
        );

  @override
  void update(double dt) {
    super.update(dt);
    _lifetime -= dt;
    position.y -= 55 * dt;

    if (_lifetime <= 0) {
      removeFromParent();
      return;
    }

    final alpha = _lifetime.clamp(0.0, 1.0);
    textRenderer = TextPaint(
      style: TextStyle(
        color: _baseColor.withValues(alpha: alpha),
        fontSize: 26,
        fontWeight: FontWeight.w900,
        shadows: [
          Shadow(color: Colors.black.withValues(alpha: alpha), blurRadius: 4),
        ],
      ),
    );
  }
}
