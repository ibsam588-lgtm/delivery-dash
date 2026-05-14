import 'dart:ui';
import 'package:flame/components.dart';
import 'package:flutter/material.dart' hide Image;
import '../delivery_dash_game.dart';

class Hud extends PositionComponent with HasGameRef<DeliveryDashGame> {
  static const double barHeight = 84.0;

  TextComponent? _scoreText;
  TextComponent? _speedText;
  TextComponent? _coinText;
  TextComponent? _comboText;
  List<SpriteComponent> _lifeIcons = const [];

  Hud() : super(priority: 100);

  static final _scorePaint = TextPaint(
    style: const TextStyle(
      color: Colors.white,
      fontSize: 28,
      fontWeight: FontWeight.w900,
      shadows: [Shadow(color: Colors.black, blurRadius: 4)],
    ),
  );

  static final _speedPaint = TextPaint(
    style: const TextStyle(
      color: Color(0xFFB0BEC5),
      fontSize: 12,
      fontWeight: FontWeight.w500,
    ),
  );

  static final _coinPaint = TextPaint(
    style: const TextStyle(
      color: Color(0xFFFFD54F),
      fontSize: 18,
      fontWeight: FontWeight.bold,
      shadows: [Shadow(color: Colors.black, blurRadius: 3)],
    ),
  );

  static final _coinLabelPaint = TextPaint(
    style: const TextStyle(
      color: Color(0xFFFFD54F),
      fontSize: 20,
    ),
  );

  static final _comboPaint = TextPaint(
    style: const TextStyle(
      color: Colors.yellowAccent,
      fontSize: 16,
      fontWeight: FontWeight.bold,
      shadows: [Shadow(color: Colors.black, blurRadius: 4)],
    ),
  );

  @override
  Future<void> onLoad() async {
    size = gameRef.size;

    add(_HudBar(barWidth: gameRef.size.x, barHeight: barHeight));

    _scoreText = TextComponent(
      text: '${gameRef.score}',
      textRenderer: _scorePaint,
      position: Vector2(16, 14),
    );
    add(_scoreText!);

    _speedText = TextComponent(
      text: 'SPEED ${gameRef.currentSpeed.toStringAsFixed(0)}',
      textRenderer: _speedPaint,
      position: Vector2(16, 52),
    );
    add(_speedText!);

    final paperSprite = await gameRef.loadSprite('paper.png');
    final maxLives = gameRef.lives;
    final icons = <SpriteComponent>[];
    for (int i = 0; i < maxLives; i++) {
      final icon = SpriteComponent(
        sprite: paperSprite,
        size: Vector2(24, 24),
        position: Vector2(
          gameRef.size.x / 2 - (maxLives * 28) / 2 + i * 28.0,
          14,
        ),
      );
      icons.add(icon);
      add(icon);
    }
    _lifeIcons = icons;

    add(TextComponent(
      text: '🪙',
      textRenderer: _coinLabelPaint,
      position: Vector2(gameRef.size.x - 86, 14),
    ));

    _coinText = TextComponent(
      text: '${gameRef.coinsThisRun}',
      textRenderer: _coinPaint,
      position: Vector2(gameRef.size.x - 56, 16),
    );
    add(_coinText!);

    _comboText = TextComponent(
      text: '',
      textRenderer: _comboPaint,
      position: Vector2(gameRef.size.x / 2, 52),
      anchor: Anchor.topCenter,
    );
    add(_comboText!);
  }

  @override
  void update(double dt) {
    super.update(dt);
    _speedText?.text = 'SPEED ${gameRef.currentSpeed.toStringAsFixed(0)}';
  }

  void updateScore(int score) {
    _scoreText?.text = '$score';
  }

  void updateSpeed(double speed) {
    _speedText?.text = 'SPEED ${speed.toStringAsFixed(0)}';
  }

  void updateLives(int lives) {
    for (int i = 0; i < _lifeIcons.length; i++) {
      _lifeIcons[i].opacity = i < lives ? 1.0 : 0.15;
    }
  }

  void updateCoins(int coins) {
    _coinText?.text = '$coins';
  }

  void updateCombo(int combo) {
    _comboText?.text = combo >= 2 ? 'x$combo COMBO!' : '';
  }
}

class _HudBar extends PositionComponent {
  final double barWidth;
  final double barHeight;
  final Paint _bgPaint = Paint()..color = const Color(0xCC0A0A0A);
  final Paint _edgePaint = Paint()..color = const Color(0xFF1F1F1F);

  _HudBar({required this.barWidth, required this.barHeight})
      : super(priority: -1);

  @override
  void render(Canvas canvas) {
    canvas.drawRect(Rect.fromLTWH(0, 0, barWidth, barHeight), _bgPaint);
    canvas.drawRect(
        Rect.fromLTWH(0, barHeight - 2, barWidth, 2), _edgePaint);
  }
}
