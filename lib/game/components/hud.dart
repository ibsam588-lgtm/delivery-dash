import 'package:flame/components.dart';
import 'package:flutter/material.dart';
import '../delivery_dash_game.dart';

class Hud extends PositionComponent with HasGameRef<DeliveryDashGame> {
  static const double topBarHeight = 76.0;

  TextComponent? _scoreText;
  TextComponent? _dayText;
  TextComponent? _bonusText;

  Hud() : super(priority: 100);

  static final _labelWhitePaint = TextPaint(
    style: const TextStyle(
      color: Color(0xFFB0BEC5),
      fontSize: 10,
      fontWeight: FontWeight.w700,
      letterSpacing: 1.6,
    ),
  );
  static final _labelYellowPaint = TextPaint(
    style: const TextStyle(
      color: Color(0xFFFFE082),
      fontSize: 10,
      fontWeight: FontWeight.w700,
      letterSpacing: 1.6,
    ),
  );
  static final _labelGoldPaint = TextPaint(
    style: const TextStyle(
      color: Color(0xFFFFD54F),
      fontSize: 10,
      fontWeight: FontWeight.w700,
      letterSpacing: 1.6,
    ),
  );

  static final _whiteBigPaint = TextPaint(
    style: const TextStyle(
      color: Colors.white,
      fontSize: 26,
      fontWeight: FontWeight.w900,
      shadows: [Shadow(color: Colors.black, blurRadius: 4)],
    ),
  );
  static final _yellowBigPaint = TextPaint(
    style: const TextStyle(
      color: Color(0xFFFFEB3B),
      fontSize: 26,
      fontWeight: FontWeight.w900,
      shadows: [Shadow(color: Colors.black, blurRadius: 4)],
    ),
  );
  static final _goldBigPaint = TextPaint(
    style: const TextStyle(
      color: Color(0xFFFFD54F),
      fontSize: 24,
      fontWeight: FontWeight.w900,
      shadows: [Shadow(color: Colors.black, blurRadius: 4)],
    ),
  );

  @override
  Future<void> onLoad() async {
    size = gameRef.size;
    final w = gameRef.size.x;

    add(_HudBar(barWidth: w, barHeight: topBarHeight));

    // SCORE (left)
    add(TextComponent(
      text: 'SCORE',
      textRenderer: _labelWhitePaint,
      position: Vector2(16, 12),
    ));
    _scoreText = TextComponent(
      text: '0',
      textRenderer: _whiteBigPaint,
      position: Vector2(16, 30),
    );
    add(_scoreText!);

    // DAY (center)
    add(TextComponent(
      text: 'DAY',
      textRenderer: _labelYellowPaint,
      position: Vector2(w / 2, 12),
      anchor: Anchor.topCenter,
    ));
    _dayText = TextComponent(
      text: '1',
      textRenderer: _yellowBigPaint,
      position: Vector2(w / 2, 30),
      anchor: Anchor.topCenter,
    );
    add(_dayText!);

    // BONUS (right)
    add(TextComponent(
      text: 'BONUS',
      textRenderer: _labelGoldPaint,
      position: Vector2(w - 16, 12),
      anchor: Anchor.topRight,
    ));
    _bonusText = TextComponent(
      text: '0',
      textRenderer: _goldBigPaint,
      position: Vector2(w - 16, 30),
      anchor: Anchor.topRight,
    );
    add(_bonusText!);
  }

  void updateScore(int score) => _scoreText?.text = '$score';
  void updateDay(int day) => _dayText?.text = '$day';
  void updateBonus(int bonus) => _bonusText?.text = '$bonus';
}

class _HudBar extends PositionComponent {
  final double barWidth;
  final double barHeight;

  final Paint _bgPaint = Paint()..color = const Color(0xE60A0A14);
  final Paint _edgePaint = Paint()..color = const Color(0xFFFFC107);

  _HudBar({required this.barWidth, required this.barHeight})
      : super(priority: -1);

  @override
  void render(Canvas canvas) {
    canvas.drawRect(Rect.fromLTWH(0, 0, barWidth, barHeight), _bgPaint);
    canvas.drawRect(
        Rect.fromLTWH(0, barHeight - 3, barWidth, 3), _edgePaint);
  }
}
