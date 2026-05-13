import 'package:flame/components.dart';
import 'package:flutter/material.dart';
import '../delivery_dash_game.dart';

class Hud extends PositionComponent with HasGameRef<DeliveryDashGame> {
  late TextComponent _scoreText;
  late TextComponent _speedText;
  late TextComponent _comboText;
  late List<SpriteComponent> _lifeIcons;

  static final _scorePaint = TextPaint(
    style: const TextStyle(
      color: Colors.white,
      fontSize: 22,
      fontWeight: FontWeight.bold,
      shadows: [Shadow(color: Colors.black, blurRadius: 4)],
    ),
  );

  static final _speedPaint = TextPaint(
    style: const TextStyle(
      color: Color(0xFFFFCC80),
      fontSize: 13,
      shadows: [Shadow(color: Colors.black, blurRadius: 3)],
    ),
  );

  static final _comboPaint = TextPaint(
    style: const TextStyle(
      color: Colors.yellowAccent,
      fontSize: 18,
      fontWeight: FontWeight.bold,
      shadows: [Shadow(color: Colors.black, blurRadius: 4)],
    ),
  );

  Hud() : super(priority: 10);

  @override
  Future<void> onLoad() async {
    size = gameRef.size;

    _scoreText = TextComponent(
      text: 'Score: 0',
      textRenderer: _scorePaint,
      position: Vector2(16, 16),
    );
    add(_scoreText);

    _speedText = TextComponent(
      text: 'Speed: 1.0x',
      textRenderer: _speedPaint,
      position: Vector2(16, 46),
    );
    add(_speedText);

    _comboText = TextComponent(
      text: '',
      textRenderer: _comboPaint,
      position: Vector2(gameRef.size.x / 2, 16),
      anchor: Anchor.topCenter,
    );
    add(_comboText);

    final paperSprite = await gameRef.loadSprite('paper.png');
    _lifeIcons = List.generate(3, (i) {
      return SpriteComponent(
        sprite: paperSprite,
        size: Vector2(22, 22),
        position: Vector2(gameRef.size.x - 28 - i * 26.0, 16),
      );
    });
    for (final icon in _lifeIcons) {
      add(icon);
    }
  }

  void updateScore(int score) {
    _scoreText.text = 'Score: $score';
    final speed = (1.0 + score / 500.0).clamp(1.0, 3.0).toStringAsFixed(1);
    _speedText.text = 'Speed: ${speed}x';
  }

  void updateLives(int lives) {
    for (int i = 0; i < _lifeIcons.length; i++) {
      _lifeIcons[i].opacity = i < lives ? 1.0 : 0.15;
    }
  }

  void updateCombo(int combo) {
    _comboText.text = combo >= 3 ? 'x$combo COMBO!' : '';
  }
}
