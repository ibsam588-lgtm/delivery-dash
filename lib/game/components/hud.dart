import 'package:flame/components.dart';
import 'package:flutter/material.dart';
import '../delivery_dash_game.dart';

/// Modern minimal HUD.
///
/// One dark slab at the top (56 px) with a neon-green hairline below it.
///   - Left  : SCORE pill (#1A1A2E surface, gold "SCORE" label, big white number)
///   - Middle: LEVEL chip (neon green outline + glow, "LVL n")
///   - Right : coin count and heart icons stacked compactly
///   - Below : combo multiplier chip (only visible when combo >= 2)
class Hud extends PositionComponent with HasGameRef<DeliveryDashGame> {
  static const double topBarHeight = 56.0;

  _ScorePill? _scorePill;
  _LevelChip? _levelChip;
  _RightInfo? _rightInfo;
  _ComboChip? _comboChip;

  Hud() : super(priority: 100);

  @override
  Future<void> onLoad() async {
    size = gameRef.size;
    final w = gameRef.size.x;

    add(_HudBar(width: w, height: topBarHeight));

    _scorePill = _ScorePill(position: Vector2(10, 6));
    add(_scorePill!);

    _levelChip = _LevelChip(center: Vector2(w / 2, topBarHeight / 2));
    add(_levelChip!);

    _rightInfo = _RightInfo(
      anchorPoint: Vector2(w - 10, 6),
      lives: gameRef.lives,
    );
    add(_rightInfo!);

    _comboChip = _ComboChip(center: Vector2(w / 2, topBarHeight + 22));
    add(_comboChip!);
  }

  void updateScore(int score) => _scorePill?.setValue(score);
  void updateLevel(int level) => _levelChip?.setLevel(level);
  void updateCoins(int coins) => _rightInfo?.setCoins(coins);
  void updateLives(int lives) => _rightInfo?.setLives(lives);
  void updateCombo(int combo, int multiplier) =>
      _comboChip?.setCombo(combo, multiplier);

  // Kept for back-compat with any old call site.
  void updateBonus(int bonus) {}
}

class _HudBar extends PositionComponent {
  final double barWidth;
  final double barHeight;

  final Paint _bgPaint = Paint()..color = const Color(0xD90D0D0D); // 85%
  final Paint _accent = Paint()..color = const Color(0xFF00E676);

  _HudBar({required double width, required double height})
      : barWidth = width,
        barHeight = height,
        super(priority: -1);

  @override
  void render(Canvas canvas) {
    canvas.drawRect(Rect.fromLTWH(0, 0, barWidth, barHeight), _bgPaint);
    canvas.drawRect(Rect.fromLTWH(0, barHeight - 1, barWidth, 1), _accent);
  }
}

class _ScorePill extends PositionComponent {
  TextComponent? _label;
  TextComponent? _value;

  _ScorePill({required Vector2 position})
      : super(position: position, size: Vector2(110, 44));

  static final _labelPaint = TextPaint(
    style: const TextStyle(
      color: Color(0xFFFFD600),
      fontSize: 8,
      fontWeight: FontWeight.w700,
      letterSpacing: 1.5,
    ),
  );
  static final _valuePaint = TextPaint(
    style: const TextStyle(
      color: Colors.white,
      fontSize: 22,
      fontWeight: FontWeight.w900,
      letterSpacing: -0.5,
    ),
  );

  @override
  Future<void> onLoad() async {
    _label = TextComponent(
      text: 'SCORE',
      textRenderer: _labelPaint,
      position: Vector2(10, 5),
    );
    add(_label!);
    _value = TextComponent(
      text: '0',
      textRenderer: _valuePaint,
      position: Vector2(10, 16),
    );
    add(_value!);
  }

  void setValue(int v) => _value?.text = '$v';

  @override
  void render(Canvas canvas) {
    final r = RRect.fromRectAndRadius(
      Rect.fromLTWH(0, 0, size.x, size.y),
      const Radius.circular(10),
    );
    canvas.drawRRect(r, Paint()..color = const Color(0xFF1A1A2E));
  }
}

class _LevelChip extends PositionComponent {
  TextComponent? _text;

  _LevelChip({required Vector2 center})
      : super(
          position: center,
          anchor: Anchor.center,
          size: Vector2(80, 30),
        );

  static final _paint = TextPaint(
    style: const TextStyle(
      color: Colors.white,
      fontSize: 13,
      fontWeight: FontWeight.w900,
      letterSpacing: 1.4,
    ),
  );

  @override
  Future<void> onLoad() async {
    _text = TextComponent(
      text: 'LVL 1',
      textRenderer: _paint,
      anchor: Anchor.center,
      position: Vector2(size.x / 2, size.y / 2),
    );
    add(_text!);
  }

  void setLevel(int level) => _text?.text = 'LVL $level';

  @override
  void render(Canvas canvas) {
    final r = RRect.fromRectAndRadius(
      Rect.fromLTWH(0, 0, size.x, size.y),
      const Radius.circular(15),
    );
    // Soft glow.
    canvas.drawRRect(
      r.inflate(2),
      Paint()
        ..color = const Color(0x6600E676)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6),
    );
    // Surface.
    canvas.drawRRect(r, Paint()..color = const Color(0xFF1A1A2E));
    // Neon outline.
    canvas.drawRRect(
      r,
      Paint()
        ..color = const Color(0xFF00E676)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5,
    );
  }
}

class _ComboChip extends PositionComponent {
  static const Color glow = Color(0xFFFFD600);

  int _combo = 0;
  int _mult = 1;
  double _pulse = 0;
  TextComponent? _text;

  _ComboChip({required Vector2 center})
      : super(
          position: center,
          anchor: Anchor.center,
          size: Vector2(120, 26),
          priority: 10,
        );

  static final _paint = TextPaint(
    style: const TextStyle(
      color: glow,
      fontSize: 12,
      fontWeight: FontWeight.w900,
      letterSpacing: 1.5,
      shadows: [Shadow(color: Colors.black, blurRadius: 4)],
    ),
  );

  @override
  Future<void> onLoad() async {
    _text = TextComponent(
      text: '',
      textRenderer: _paint,
      anchor: Anchor.center,
      position: Vector2(size.x / 2, size.y / 2),
    );
    add(_text!);
  }

  void setCombo(int combo, int mult) {
    final boosted = mult > _mult;
    _combo = combo;
    _mult = mult;
    if (boosted) _pulse = 0.4;
    _text?.text = combo > 0 ? 'x$mult  •  COMBO $combo' : '';
  }

  @override
  void update(double dt) {
    super.update(dt);
    if (_pulse > 0) _pulse = (_pulse - dt).clamp(0.0, 0.4);
  }

  @override
  void render(Canvas canvas) {
    if (_combo <= 0) return;
    final pulseScale = 1 + (_pulse / 0.4) * 0.18;
    canvas.save();
    canvas.translate(size.x / 2, size.y / 2);
    canvas.scale(pulseScale);
    canvas.translate(-size.x / 2, -size.y / 2);
    final r = RRect.fromRectAndRadius(
      Rect.fromLTWH(0, 0, size.x, size.y),
      const Radius.circular(13),
    );
    canvas.drawRRect(
      r.inflate(2),
      Paint()
        ..color = glow.withValues(alpha: 0.35)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6),
    );
    canvas.drawRRect(r, Paint()..color = const Color(0xFF1A1A2E));
    canvas.drawRRect(
      r,
      Paint()
        ..color = glow
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5,
    );
    canvas.restore();
  }
}

class _RightInfo extends PositionComponent {
  int _lives;
  TextComponent? _coinText;

  _RightInfo({required Vector2 anchorPoint, required int lives})
      : _lives = lives,
        super(position: anchorPoint, size: Vector2(120, 44), anchor: Anchor.topRight);

  static final _coinPaint = TextPaint(
    style: const TextStyle(
      color: Color(0xFFFFD600),
      fontSize: 16,
      fontWeight: FontWeight.w900,
      letterSpacing: -0.5,
    ),
  );

  @override
  Future<void> onLoad() async {
    _coinText = TextComponent(
      text: '🪙 0',
      textRenderer: _coinPaint,
      position: Vector2(size.x, 4),
      anchor: Anchor.topRight,
    );
    add(_coinText!);
  }

  void setCoins(int coins) => _coinText?.text = '🪙 $coins';
  void setLives(int lives) {
    _lives = lives;
  }

  @override
  void render(Canvas canvas) {
    // Hearts row below coin text. Drawn directly instead of using emoji
    // (more compact and renders consistently across devices).
    const iconSize = 10.0;
    const spacing = 14.0;
    final totalW = (_lives.clamp(0, 9)) * spacing;
    final startX = size.x - totalW;
    final y = size.y - iconSize - 4;
    final paint = Paint()..color = const Color(0xFFFF1744);
    for (var i = 0; i < _lives.clamp(0, 9); i++) {
      _drawHeart(canvas, startX + i * spacing, y, iconSize, paint);
    }
  }

  void _drawHeart(Canvas canvas, double x, double y, double s, Paint paint) {
    final path = Path();
    final w = s;
    final h = s;
    path.moveTo(x + w / 2, y + h);
    path.cubicTo(
      x + w * 1.2, y + h * 0.6,
      x + w * 0.9, y - h * 0.1,
      x + w / 2, y + h * 0.3,
    );
    path.cubicTo(
      x + w * 0.1, y - h * 0.1,
      x - w * 0.2, y + h * 0.6,
      x + w / 2, y + h,
    );
    path.close();
    canvas.drawPath(path, paint);
  }
}
