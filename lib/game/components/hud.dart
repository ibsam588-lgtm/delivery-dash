import 'dart:math';
import 'dart:ui';
import 'package:flame/components.dart';
import 'package:flutter/material.dart' hide Gradient;
import '../delivery_dash_game.dart';
import '../difficulty.dart';

/// Clean Paperboy-style HUD.
///
/// Top bar (52px tall, dark translucent):
///   Left   : [♥ x N]   lives count with heart icons
///   Center : SCORE in large bold white text with drop shadow
///   Right  : [📰 x N]  paper count with newspaper icon
///
/// Below top bar:
///   "DAY n" indicator + combo chip (visible only when combo >= 2)
///
/// Combo flash: gold border pulse when combo >= 3.
/// Bottom: thin level-progress bar.
class Hud extends PositionComponent with HasGameRef<DeliveryDashGame> {
  static const double topBarHeight = 52.0;

  _TopBar? _topBar;
  _Hearts? _hearts;
  _ScoreLabel? _scoreLabel;
  _PapersLabel? _papersLabel;
  _DayChip? _dayChip;
  _ComboChip? _comboChip;
  _ProgressBar? _progressBar;
  _CoinLabel? _coinLabel;

  double _comboBorderFlash = 0;

  Hud() : super(priority: 200);

  @override
  Future<void> onLoad() async {
    size = gameRef.size;
    final w = gameRef.size.x;

    _topBar = _TopBar(width: w, height: topBarHeight);
    add(_topBar!);

    _hearts = _Hearts(position: Vector2(12, 8), lives: gameRef.lives);
    add(_hearts!);

    _scoreLabel = _ScoreLabel(center: Vector2(w / 2, topBarHeight / 2));
    add(_scoreLabel!);

    _papersLabel = _PapersLabel(anchorPoint: Vector2(w - 12, 8));
    add(_papersLabel!);

    _dayChip = _DayChip(position: Vector2(12, topBarHeight + 6));
    add(_dayChip!);

    _coinLabel = _CoinLabel(anchorPoint: Vector2(w - 12, topBarHeight + 6));
    add(_coinLabel!);

    _comboChip = _ComboChip(center: Vector2(w / 2, topBarHeight + 18));
    add(_comboChip!);

    _progressBar = _ProgressBar(
      screenW: w,
      screenH: gameRef.size.y,
    );
    add(_progressBar!);
  }

  void updateScore(int score) => _scoreLabel?.setValue(score);
  void updateLevel(int level) => _dayChip?.setDay(level);
  void updateCoins(int coins) => _coinLabel?.setCoins(coins);
  void updateLives(int lives) => _hearts?.setLives(lives);
  void updateCombo(int combo, int multiplier) {
    _comboChip?.setCombo(combo, multiplier);
    if (combo >= 3) _comboBorderFlash = 0.40;
  }
  void updatePapers(int papers) => _papersLabel?.setPapers(papers);
  void updateDelivery(int delivered) {}
  void updateBonus(int bonus) {}

  @override
  void update(double dt) {
    super.update(dt);
    if (_comboBorderFlash > 0) {
      _comboBorderFlash = (_comboBorderFlash - dt).clamp(0.0, 0.40);
    }
  }

  @override
  void render(Canvas canvas) {
    super.render(canvas);
    if (_comboBorderFlash > 0) {
      final alpha = (_comboBorderFlash / 0.40) * 0.65;
      final borderPaint = Paint()
        ..color = const Color(0xFFFFD600).withValues(alpha: alpha)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 7.0;
      canvas.drawRect(
        Rect.fromLTWH(3, 3, size.x - 6, size.y - 6),
        borderPaint,
      );
    }
  }
}

// ── Top bar ─────────────────────────────────────────────────────────────────

class _TopBar extends PositionComponent {
  final double barWidth;
  final double barHeight;

  _TopBar({required double width, required double height})
      : barWidth = width,
        barHeight = height,
        super(priority: -1);

  @override
  void render(Canvas canvas) {
    canvas.drawRect(
      Rect.fromLTWH(0, 0, barWidth, barHeight),
      Paint()..color = const Color(0xCC000000),
    );
    canvas.drawRect(
      Rect.fromLTWH(0, barHeight - 2, barWidth, 2),
      Paint()..color = const Color(0xFFFFD600),
    );
  }
}

// ── Hearts (lives) ──────────────────────────────────────────────────────────

class _Hearts extends PositionComponent {
  int _lives;

  _Hearts({required Vector2 position, required int lives})
      : _lives = lives,
        super(position: position, size: Vector2(120, 36));

  void setLives(int lives) => _lives = lives;

  static final _labelPaint = TextPaint(
    style: const TextStyle(
      color: Colors.white,
      fontSize: 18,
      fontWeight: FontWeight.w900,
      shadows: [Shadow(color: Colors.black, blurRadius: 3)],
    ),
  );

  @override
  void render(Canvas canvas) {
    // First heart at top-left, then a "x N" multiplier so it's compact.
    final heartPaint = Paint()..color = const Color(0xFFFF1744);
    _drawHeart(canvas, 0, 4, 18, heartPaint);
    _labelPaint.render(canvas, 'x$_lives', Vector2(26, 8));
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
    // Outline.
    canvas.drawPath(
      path,
      Paint()
        ..color = const Color(0xFF8B0000)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.2,
    );
    // Highlight.
    canvas.drawCircle(
      Offset(x + w * 0.35, y + h * 0.3),
      w * 0.12,
      Paint()..color = const Color(0x88FFFFFF),
    );
  }
}

// ── Score label (centre) ────────────────────────────────────────────────────

class _ScoreLabel extends PositionComponent {
  TextComponent? _value;

  _ScoreLabel({required Vector2 center})
      : super(
          position: center,
          anchor: Anchor.center,
          size: Vector2(160, 36),
        );

  static final _valuePaint = TextPaint(
    style: const TextStyle(
      color: Colors.white,
      fontSize: 26,
      fontWeight: FontWeight.w900,
      letterSpacing: -0.5,
      shadows: [Shadow(color: Colors.black, blurRadius: 3, offset: Offset(0, 1))],
    ),
  );

  @override
  Future<void> onLoad() async {
    _value = TextComponent(
      text: '0',
      textRenderer: _valuePaint,
      anchor: Anchor.center,
      position: Vector2(size.x / 2, size.y / 2),
    );
    add(_value!);
  }

  void setValue(int v) => _value?.text = '$v';
}

// ── Papers label (right) ────────────────────────────────────────────────────

class _PapersLabel extends PositionComponent {
  int _papers = 0;

  _PapersLabel({required Vector2 anchorPoint})
      : super(
          position: anchorPoint,
          size: Vector2(80, 36),
          anchor: Anchor.topRight,
        );

  static final _textPaint = TextPaint(
    style: const TextStyle(
      color: Colors.white,
      fontSize: 18,
      fontWeight: FontWeight.w900,
      shadows: [Shadow(color: Colors.black, blurRadius: 3)],
    ),
  );

  void setPapers(int p) => _papers = p;

  @override
  void render(Canvas canvas) {
    // Render paper icon + count, right-aligned.
    // Draw paper icon at left of component.
    _drawPaperIcon(canvas, size.x - 70, 4, 22, 16);
    _textPaint.render(canvas, 'x$_papers', Vector2(size.x - 40, 6));
  }

  void _drawPaperIcon(
      Canvas canvas, double x, double y, double w, double h) {
    // Stacked newspaper look.
    canvas.drawRect(
      Rect.fromLTWH(x + 2, y + 2, w, h),
      Paint()..color = const Color(0xFFC0BBA0),
    );
    canvas.drawRect(
      Rect.fromLTWH(x, y, w, h),
      Paint()..color = const Color(0xFFF5F0D8),
    );
    canvas.drawRect(
      Rect.fromLTWH(x, y, w, h),
      Paint()
        ..color = const Color(0xFF7A7460)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0.8,
    );
    // Masthead strip.
    canvas.drawRect(
      Rect.fromLTWH(x + 1, y + 1, w - 2, 3.5),
      Paint()..color = const Color(0xFF1A1A1A),
    );
    // Lines.
    final linePaint = Paint()
      ..color = const Color(0xFF7A7460)
      ..strokeWidth = 0.7;
    for (int i = 0; i < 3; i++) {
      canvas.drawLine(
        Offset(x + 2, y + 7 + i * 2.5),
        Offset(x + w - 3, y + 7 + i * 2.5),
        linePaint,
      );
    }
  }
}

// ── Day chip ────────────────────────────────────────────────────────────────

class _DayChip extends PositionComponent {
  TextComponent? _text;

  _DayChip({required Vector2 position})
      : super(position: position, size: Vector2(80, 22));

  static final _paint = TextPaint(
    style: const TextStyle(
      color: Color(0xFFFFD600),
      fontSize: 11,
      fontWeight: FontWeight.w900,
      letterSpacing: 1.5,
      shadows: [Shadow(color: Colors.black, blurRadius: 3)],
    ),
  );

  @override
  Future<void> onLoad() async {
    _text = TextComponent(
      text: 'DAY 1',
      textRenderer: _paint,
      anchor: Anchor.centerLeft,
      position: Vector2(8, size.y / 2),
    );
    add(_text!);
  }

  void setDay(int day) => _text?.text = 'DAY $day';

  @override
  void render(Canvas canvas) {
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(0, 0, size.x, size.y),
        const Radius.circular(11),
      ),
      Paint()..color = const Color(0xAA000000),
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(0, 0, size.x, size.y),
        const Radius.circular(11),
      ),
      Paint()
        ..color = const Color(0xFFFFD600)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.2,
    );
  }
}

// ── Coin label ──────────────────────────────────────────────────────────────

class _CoinLabel extends PositionComponent {
  TextComponent? _text;

  _CoinLabel({required Vector2 anchorPoint})
      : super(
          position: anchorPoint,
          size: Vector2(80, 22),
          anchor: Anchor.topRight,
        );

  static final _paint = TextPaint(
    style: const TextStyle(
      color: Color(0xFFFFD600),
      fontSize: 12,
      fontWeight: FontWeight.w900,
      shadows: [Shadow(color: Colors.black, blurRadius: 3)],
    ),
  );

  @override
  Future<void> onLoad() async {
    _text = TextComponent(
      text: '🪙 0',
      textRenderer: _paint,
      anchor: Anchor.centerRight,
      position: Vector2(size.x - 6, size.y / 2),
    );
    add(_text!);
  }

  void setCoins(int coins) => _text?.text = '🪙 $coins';

  @override
  void render(Canvas canvas) {
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(0, 0, size.x, size.y),
        const Radius.circular(11),
      ),
      Paint()..color = const Color(0xAA000000),
    );
  }
}

// ── Combo chip ──────────────────────────────────────────────────────────────

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
          size: Vector2(160, 24),
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
    final boosted = mult > _mult || (combo > _combo && combo > 0);
    _combo = combo;
    _mult = mult;
    if (boosted) _pulse = 0.30;
    if (combo >= 3) {
      _text?.text = '🔥 COMBO x$mult!';
    } else if (combo > 0) {
      _text?.text = 'COMBO $combo  ·  x$mult';
    } else {
      _text?.text = '';
    }
  }

  @override
  void update(double dt) {
    super.update(dt);
    if (_pulse > 0) _pulse = (_pulse - dt).clamp(0.0, 0.30);
  }

  @override
  void render(Canvas canvas) {
    if (_combo <= 0) return;
    final t = _pulse > 0 ? sin((_pulse / 0.30) * pi) : 0.0;
    final pulseScale = 1.0 + t * 0.15;
    canvas.save();
    canvas.translate(size.x / 2, size.y / 2);
    canvas.scale(pulseScale);
    canvas.translate(-size.x / 2, -size.y / 2);
    final r = RRect.fromRectAndRadius(
      Rect.fromLTWH(0, 0, size.x, size.y),
      const Radius.circular(12),
    );
    canvas.drawRRect(
      r.inflate(2),
      Paint()
        ..color = glow.withValues(alpha: 0.35 + t * 0.15)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6),
    );
    canvas.drawRRect(r, Paint()..color = const Color(0xCC000000));
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

// ── Progress bar ────────────────────────────────────────────────────────────

class _ProgressBar extends PositionComponent
    with HasGameRef<DeliveryDashGame> {
  final double screenW;
  final double screenH;

  _ProgressBar({required this.screenW, required this.screenH})
      : super(priority: 5);

  @override
  void render(Canvas canvas) {
    final progress =
        (gameRef.distanceMeters / LevelConfig.metersPerLevel).clamp(0.0, 1.0);

    final barY = screenH - 5.0;
    const barH = 3.0;

    canvas.drawRect(
      Rect.fromLTWH(0, barY, screenW, barH),
      Paint()..color = const Color(0x88000000),
    );

    if (progress > 0) {
      final fillW = screenW * progress;
      canvas.drawRect(
        Rect.fromLTWH(0, barY, fillW, barH),
        Paint()
          ..shader = Gradient.linear(
            Offset(0, barY),
            Offset(fillW, barY),
            [const Color(0xFFFFD600), const Color(0xFFFF6F00)],
          ),
      );
    }
  }
}
