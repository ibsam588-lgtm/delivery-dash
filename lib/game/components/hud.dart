import 'package:flame/components.dart';
import 'package:flame/flame.dart';
import 'package:flutter/material.dart';
import '../delivery_dash_game.dart';

/// Top-only HUD. A semi-transparent dark slab with three sections:
///   left  : SCORE label + big number, then row of life icons under it
///   middle: gold LVL pill
///   right : coin icon + count
class Hud extends PositionComponent with HasGameRef<DeliveryDashGame> {
  static const double topBarHeight = 88.0;

  TextComponent? _scoreText;
  TextComponent? _levelText;
  TextComponent? _coinText;

  _LevelPill? _levelPill;
  _LivesRow? _livesRow;

  Hud() : super(priority: 100);

  static final _labelPaint = TextPaint(
    style: const TextStyle(
      color: Color(0xFF9CA3AF),
      fontSize: 10,
      fontWeight: FontWeight.w700,
      letterSpacing: 1.4,
    ),
  );
  static final _scoreBig = TextPaint(
    style: const TextStyle(
      color: Colors.white,
      fontSize: 26,
      fontWeight: FontWeight.w900,
      shadows: [Shadow(color: Colors.black, blurRadius: 4)],
    ),
  );
  static final _coinBig = TextPaint(
    style: const TextStyle(
      color: Color(0xFFFFD54F),
      fontSize: 20,
      fontWeight: FontWeight.w900,
      shadows: [Shadow(color: Colors.black, blurRadius: 3)],
    ),
  );
  static final _coinLabel = TextPaint(
    style: const TextStyle(
      color: Color(0xFFFFD54F),
      fontSize: 20,
    ),
  );

  @override
  Future<void> onLoad() async {
    size = gameRef.size;
    final w = gameRef.size.x;

    // Background slab (no hard border, soft drop shadow line at the bottom).
    add(_HudBar(barWidth: w, barHeight: topBarHeight));

    // SCORE label.
    add(TextComponent(
      text: 'SCORE',
      textRenderer: _labelPaint,
      position: Vector2(16, 10),
    ));
    _scoreText = TextComponent(
      text: '0',
      textRenderer: _scoreBig,
      position: Vector2(16, 24),
    );
    add(_scoreText!);

    // Lives row under the score.
    _livesRow = _LivesRow(
      position: Vector2(16, 58),
      total: gameRef.lives,
    );
    add(_livesRow!);

    // LVL pill centered.
    _levelPill = _LevelPill(
      center: Vector2(w / 2, topBarHeight / 2),
    );
    _levelText = _levelPill!.text;
    add(_levelPill!);

    // COIN icon + number top-right.
    add(TextComponent(
      text: '🪙',
      textRenderer: _coinLabel,
      position: Vector2(w - 76, 14),
    ));
    _coinText = TextComponent(
      text: '0',
      textRenderer: _coinBig,
      position: Vector2(w - 16, 18),
      anchor: Anchor.topRight,
    );
    add(_coinText!);
  }

  void updateScore(int score) => _scoreText?.text = '$score';
  void updateLevel(int level) => _levelText?.text = 'LVL $level';
  void updateCoins(int coins) => _coinText?.text = '$coins';
  void updateLives(int lives) => _livesRow?.setActive(lives);

  // No-op kept so older call sites don't break.
  void updateBonus(int bonus) {}
}

class _LevelPill extends PositionComponent {
  final TextComponent text;

  _LevelPill({required Vector2 center})
      : text = TextComponent(
          text: 'LVL 1',
          anchor: Anchor.center,
          textRenderer: TextPaint(
            style: const TextStyle(
              color: Color(0xFF1A1410),
              fontSize: 15,
              fontWeight: FontWeight.w900,
              letterSpacing: 1.4,
            ),
          ),
        ),
        super(position: center, anchor: Anchor.center, size: Vector2(90, 32)) {
    text.position = Vector2(size.x / 2, size.y / 2);
    add(text);
  }

  @override
  void render(Canvas canvas) {
    final r = RRect.fromRectAndRadius(
      Rect.fromLTWH(0, 0, size.x, size.y),
      const Radius.circular(20),
    );
    canvas.drawRRect(r, Paint()..color = const Color(0xFFFFD54F));
    canvas.drawRRect(
      r,
      Paint()
        ..color = const Color(0xFFFFA000)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2,
    );
  }
}

class _LivesRow extends PositionComponent {
  final int total;
  late final List<SpriteComponent> _icons;

  _LivesRow({required Vector2 position, required this.total})
      : super(position: position);

  @override
  Future<void> onLoad() async {
    final paperSprite =
        Sprite(Flame.images.fromCache('mailbox_red.png'));
    _icons = List.generate(total, (i) {
      final c = SpriteComponent(
        sprite: paperSprite,
        size: Vector2(18, 22),
        position: Vector2(i * 22.0, 0),
      );
      add(c);
      return c;
    });
  }

  void setActive(int n) {
    if (!isMounted) return;
    for (var i = 0; i < _icons.length; i++) {
      _icons[i].opacity = i < n ? 1.0 : 0.18;
    }
  }
}

class _HudBar extends PositionComponent {
  final double barWidth;
  final double barHeight;

  final Paint _bgPaint = Paint()..color = const Color(0xB3000000); // rgba(0,0,0,0.7)
  final Paint _shadowPaint = Paint()..color = const Color(0x88000000);

  _HudBar({required this.barWidth, required this.barHeight})
      : super(priority: -1);

  @override
  void render(Canvas canvas) {
    canvas.drawRect(Rect.fromLTWH(0, 0, barWidth, barHeight), _bgPaint);
    // Subtle bottom drop shadow line — softer than a hard border.
    canvas.drawRect(
      Rect.fromLTWH(0, barHeight, barWidth, 6),
      _shadowPaint,
    );
  }
}
