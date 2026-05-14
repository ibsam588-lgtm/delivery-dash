import 'package:flame/components.dart';
import 'package:flutter/material.dart';
import '../delivery_dash_game.dart';
import '../difficulty.dart';

class Hud extends PositionComponent with HasGameRef<DeliveryDashGame> {
  static const double topBarHeight = 72.0;
  static const double bottomBarHeight = 78.0;

  TextComponent? _scoreText;
  TextComponent? _scoreLabel;
  TextComponent? _levelText;
  TextComponent? _distText;
  TextComponent? _coinText;
  TextComponent? _comboText;
  TextComponent? _speedText;
  TextComponent? _paperCountText;
  List<SpriteComponent> _lifeIcons = const [];

  Hud() : super(priority: 100);

  static final _bigPaint = TextPaint(
    style: const TextStyle(
      color: Colors.white,
      fontSize: 24,
      fontWeight: FontWeight.w900,
      shadows: [Shadow(color: Colors.black, blurRadius: 4)],
    ),
  );

  static final _labelPaint = TextPaint(
    style: const TextStyle(
      color: Color(0xFFB0BEC5),
      fontSize: 11,
      fontWeight: FontWeight.w600,
      letterSpacing: 1.4,
    ),
  );

  static final _distPaint = TextPaint(
    style: const TextStyle(
      color: Color(0xFFE0E0E0),
      fontSize: 12,
      fontWeight: FontWeight.w500,
    ),
  );

  static final _coinPaint = TextPaint(
    style: const TextStyle(
      color: Color(0xFFFFD54F),
      fontSize: 22,
      fontWeight: FontWeight.bold,
      shadows: [Shadow(color: Colors.black, blurRadius: 3)],
    ),
  );

  static final _coinIconPaint = TextPaint(
    style: const TextStyle(color: Color(0xFFFFD54F), fontSize: 22),
  );

  static final _comboPaint = TextPaint(
    style: const TextStyle(
      color: Color(0xFFFFEB3B),
      fontSize: 16,
      fontWeight: FontWeight.w900,
      shadows: [Shadow(color: Colors.black, blurRadius: 4)],
    ),
  );

  static final _speedPaint = TextPaint(
    style: const TextStyle(
      color: Color(0xFFB0BEC5),
      fontSize: 14,
      fontWeight: FontWeight.w700,
    ),
  );

  @override
  Future<void> onLoad() async {
    size = gameRef.size;
    final w = gameRef.size.x;
    final h = gameRef.size.y;

    add(_HudBar(
      barWidth: w,
      barHeight: topBarHeight,
      yPos: 0,
      borderBottom: true,
    ));
    add(_HudBar(
      barWidth: w,
      barHeight: bottomBarHeight,
      yPos: h - bottomBarHeight,
      borderTop: true,
    ));

    _scoreText = TextComponent(
      text: '0',
      textRenderer: _bigPaint,
      position: Vector2(16, 12),
    );
    add(_scoreText!);
    _scoreLabel = TextComponent(
      text: 'SCORE',
      textRenderer: _labelPaint,
      position: Vector2(16, 46),
    );
    add(_scoreLabel!);

    _levelText = TextComponent(
      text: 'LV 1',
      textRenderer: _bigPaint,
      position: Vector2(w / 2, 12),
      anchor: Anchor.topCenter,
    );
    add(_levelText!);
    _distText = TextComponent(
      text: '0m / 500m',
      textRenderer: _distPaint,
      position: Vector2(w / 2, 48),
      anchor: Anchor.topCenter,
    );
    add(_distText!);

    add(TextComponent(
      text: '🪙',
      textRenderer: _coinIconPaint,
      position: Vector2(w - 92, 12),
    ));
    _coinText = TextComponent(
      text: '0',
      textRenderer: _coinPaint,
      position: Vector2(w - 58, 12),
    );
    add(_coinText!);

    final paperSprite = Sprite(gameRef.images.fromCache('mailbox_red.png'));
    final maxLives = gameRef.lives;
    final icons = <SpriteComponent>[];
    final iconY = h - bottomBarHeight + 16;
    for (int i = 0; i < maxLives; i++) {
      final icon = SpriteComponent(
        sprite: paperSprite,
        size: Vector2(26, 26),
        position: Vector2(16 + i * 30.0, iconY),
      );
      icons.add(icon);
      add(icon);
    }
    _lifeIcons = icons;
    add(TextComponent(
      text: 'LIVES',
      textRenderer: _labelPaint,
      position: Vector2(16, iconY + 32),
    ));

    _comboText = TextComponent(
      text: '',
      textRenderer: _comboPaint,
      position: Vector2(w / 2, h - bottomBarHeight + 18),
      anchor: Anchor.topCenter,
    );
    add(_comboText!);
    add(TextComponent(
      text: 'COMBO',
      textRenderer: _labelPaint,
      position: Vector2(w / 2, h - bottomBarHeight + 50),
      anchor: Anchor.topCenter,
    ));

    _speedText = TextComponent(
      text: 'SPD 0',
      textRenderer: _speedPaint,
      position: Vector2(w - 16, h - bottomBarHeight + 14),
      anchor: Anchor.topRight,
    );
    add(_speedText!);
    _paperCountText = TextComponent(
      text: 'PAPER 3/3',
      textRenderer: _labelPaint,
      position: Vector2(w - 16, h - bottomBarHeight + 40),
      anchor: Anchor.topRight,
    );
    add(_paperCountText!);
  }

  void updateScore(int score) => _scoreText?.text = '$score';
  void updateLevel(int level) => _levelText?.text = 'LV $level';
  void updateDistance(int distance, int target) =>
      _distText?.text = '${distance}m / ${target}m';
  void updateCoins(int coins) => _coinText?.text = '$coins';

  void updateCombo(int combo) {
    if (combo >= 3) {
      final m = comboMultiplier(combo);
      _comboText?.text = 'x$m  ($combo)';
    } else {
      _comboText?.text = '';
    }
  }

  void updateSpeed(double speed) =>
      _speedText?.text = 'SPD ${speed.toStringAsFixed(0)}';
  void updatePaperCount(int count, int max) =>
      _paperCountText?.text = 'PAPER $count/$max';

  void updateLives(int lives) {
    for (int i = 0; i < _lifeIcons.length; i++) {
      _lifeIcons[i].opacity = i < lives ? 1.0 : 0.18;
    }
  }
}

class _HudBar extends PositionComponent {
  final double barWidth;
  final double barHeight;
  final double yPos;
  final bool borderTop;
  final bool borderBottom;

  final Paint _bgPaint = Paint()..color = const Color(0xE60A0A14);
  final Paint _edgePaint = Paint()..color = const Color(0xFFFFC107);

  _HudBar({
    required this.barWidth,
    required this.barHeight,
    required this.yPos,
    this.borderTop = false,
    this.borderBottom = false,
  }) : super(priority: -1);

  @override
  void render(Canvas canvas) {
    canvas.drawRect(Rect.fromLTWH(0, yPos, barWidth, barHeight), _bgPaint);
    if (borderBottom) {
      canvas.drawRect(
          Rect.fromLTWH(0, yPos + barHeight - 2, barWidth, 2), _edgePaint);
    }
    if (borderTop) {
      canvas.drawRect(Rect.fromLTWH(0, yPos, barWidth, 2), _edgePaint);
    }
  }
}
