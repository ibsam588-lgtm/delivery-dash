import 'dart:math';
import 'dart:ui';
import 'package:flame/components.dart';
import 'package:flutter/material.dart' hide Gradient;
import '../delivery_dash_game.dart';
import '../difficulty.dart';

/// Modern minimal HUD.
///
/// One dark slab at the top (56 px) with a neon-green hairline below it.
///   - Left  : SCORE pill (#1A1A2E surface, gold "SCORE" label, big white number)
///   - Middle: LEVEL chip (neon green outline + glow, "LVL n")
///   - Right : coin count and heart icons stacked compactly
///   - Below : paper count display (newspaper icon + count)
///   - Below : combo multiplier chip (only visible when combo >= 2)
///   - Bottom: thin level-progress bar
class Hud extends PositionComponent with HasGameRef<DeliveryDashGame> {
  static const double topBarHeight = 56.0;

  _ScorePill? _scorePill;
  _LevelChip? _levelChip;
  _RightInfo? _rightInfo;
  _ComboChip? _comboChip;
  _PapersDisplay? _papersDisplay;
  _ProgressBar? _progressBar;

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

    _papersDisplay = _PapersDisplay(position: Vector2(10, topBarHeight + 4));
    add(_papersDisplay!);

    _comboChip = _ComboChip(center: Vector2(w / 2, topBarHeight + 22));
    add(_comboChip!);

    _progressBar = _ProgressBar(
      screenW: w,
      screenH: gameRef.size.y,
    );
    add(_progressBar!);
  }

  void updateScore(int score) => _scorePill?.setValue(score);
  void updateLevel(int level) => _levelChip?.setLevel(level);
  void updateCoins(int coins) => _rightInfo?.setCoins(coins);
  void updateLives(int lives) => _rightInfo?.setLives(lives);
  void updateCombo(int combo, int multiplier) =>
      _comboChip?.setCombo(combo, multiplier);
  void updatePapers(int papers) => _papersDisplay?.setPapers(papers);

  // Kept for back-compat with any old call site.
  void updateBonus(int bonus) {}
}

class _HudBar extends PositionComponent {
  final double barWidth;
  final double barHeight;

  final Paint _bgPaint = Paint()..color = const Color(0xD90D0D0D);
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
    canvas.drawRRect(
      r.inflate(2),
      Paint()
        ..color = const Color(0x6600E676)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6),
    );
    canvas.drawRRect(r, Paint()..color = const Color(0xFF1A1A2E));
    canvas.drawRRect(
      r,
      Paint()
        ..color = const Color(0xFF00E676)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5,
    );
  }
}

// ── Papers display ──────────────────────────────────────────────────────────

class _PapersDisplay extends PositionComponent {
  TextComponent? _countText;

  _PapersDisplay({required Vector2 position})
      : super(position: position, size: Vector2(72, 18));

  static final _textPaint = TextPaint(
    style: const TextStyle(
      color: Color(0xFFF8F4E0),
      fontSize: 11,
      fontWeight: FontWeight.w900,
      letterSpacing: 0.5,
    ),
  );

  @override
  Future<void> onLoad() async {
    _countText = TextComponent(
      text: '20',
      textRenderer: _textPaint,
      position: Vector2(28, 3),
    );
    add(_countText!);
  }

  void setPapers(int p) => _countText?.text = '$p';

  @override
  void render(Canvas canvas) {
    // Dark backing pill.
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(0, 0, size.x, size.y),
        const Radius.circular(9),
      ),
      Paint()..color = const Color(0xCC1A1A2E),
    );

    // Draw 3 stacked mini newspaper rects.
    final paperPaint = Paint()..color = const Color(0xFFF8F4E0);
    final paperOutline = Paint()
      ..color = const Color(0xFF9A8860)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.7;
    final headerPaint = Paint()..color = const Color(0xFF333333);

    for (int i = 2; i >= 0; i--) {
      final ox = 5.0 + i * 1.5;
      final oy = 3.0 - i * 1.0;
      final pRect = Rect.fromLTWH(ox, oy, 16, 12);
      canvas.drawRect(pRect, paperPaint);
      canvas.drawRect(
        Rect.fromLTWH(ox + 1.5, oy + 1.5, 10, 2),
        headerPaint,
      );
      canvas.drawRect(pRect, paperOutline);
    }
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
    final boosted = mult > _mult || (combo > _combo && combo > 0);
    _combo = combo;
    _mult = mult;
    if (boosted) _pulse = 0.30;
    _text?.text = combo > 0 ? 'x$mult  •  COMBO $combo' : '';
  }

  @override
  void update(double dt) {
    super.update(dt);
    if (_pulse > 0) _pulse = (_pulse - dt).clamp(0.0, 0.30);
  }

  @override
  void render(Canvas canvas) {
    if (_combo <= 0) return;
    // Stronger pulse: 1.0 → 1.15 → 1.0 over 0.3s.
    final t = _pulse > 0 ? sin((_pulse / 0.30) * pi) : 0.0;
    final pulseScale = 1.0 + t * 0.15;
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
        ..color = glow.withValues(alpha: 0.35 + t * 0.15)
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

// ── Right info ──────────────────────────────────────────────────────────────

class _RightInfo extends PositionComponent {
  int _lives;
  TextComponent? _coinText;

  _RightInfo({required Vector2 anchorPoint, required int lives})
      : _lives = lives,
        super(
            position: anchorPoint,
            size: Vector2(120, 44),
            anchor: Anchor.topRight);

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

    final barY = screenH - 6.0;
    const barH = 4.0;

    // Track.
    canvas.drawRect(
      Rect.fromLTWH(0, barY, screenW, barH),
      Paint()..color = const Color(0x88000000),
    );

    // Fill (neon green → yellow gradient as bar fills).
    if (progress > 0) {
      final fillW = screenW * progress;
      canvas.drawRect(
        Rect.fromLTWH(0, barY, fillW, barH),
        Paint()
          ..shader = Gradient.linear(
            Offset(0, barY),
            Offset(fillW, barY),
            [const Color(0xFF00E676), const Color(0xFFFFD600)],
          ),
      );
    }

    // Edge glow dot at progress head.
    if (progress > 0 && progress < 1) {
      canvas.drawCircle(
        Offset(screenW * progress, barY + barH / 2),
        3.5,
        Paint()
          ..color = const Color(0xFFFFFFFF)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3),
      );
    }
  }
}
