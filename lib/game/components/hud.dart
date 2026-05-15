import 'dart:math';
import 'dart:ui';
import 'package:flame/components.dart';
import 'package:flutter/material.dart' hide Gradient;
import '../delivery_dash_game.dart';
import '../difficulty.dart';

/// Retro Paperboy-style HUD.
///
/// Uses a single arcade scoreboard panel instead of floating mobile chips.
class Hud extends PositionComponent with HasGameRef<DeliveryDashGame> {
  static const double panelHeight = 86.0;

  _ScoreboardPanel? _panel;
  _ComboBanner? _comboBanner;
  _ProgressBar? _progressBar;

  int _score = 0;
  int _lives = 0;
  int _papers = 0;
  int _day = 1;
  int _coins = 0;
  int _combo = 0;
  int _multiplier = 1;
  double _comboBorderFlash = 0;

  Hud() : super(priority: 200);

  @override
  Future<void> onLoad() async {
    size = gameRef.size;
    _lives = gameRef.lives;
    _day = gameRef.level;
    _papers = gameRef.papers;

    _panel = _ScoreboardPanel(size: Vector2(gameRef.size.x, panelHeight));
    add(_panel!);

    _comboBanner = _ComboBanner(
      center: Vector2(gameRef.size.x / 2, panelHeight + 18),
    );
    add(_comboBanner!);

    _progressBar = _ProgressBar(
      screenW: gameRef.size.x,
      screenH: gameRef.size.y,
    );
    add(_progressBar!);
  }

  void updateScore(int score) {
    _score = score;
    _panel?.markDirty();
  }

  void updateLevel(int level) {
    _day = level;
    _panel?.markDirty();
  }

  void updateCoins(int coins) {
    _coins = coins;
    _panel?.markDirty();
  }

  void updateLives(int lives) {
    _lives = lives;
    _panel?.markDirty();
  }

  void updateCombo(int combo, int multiplier) {
    _combo = combo;
    _multiplier = multiplier;
    _comboBanner?.setCombo(combo, multiplier);
    if (combo >= 3) _comboBorderFlash = 0.40;
  }

  void updatePapers(int papers) {
    _papers = papers;
    _panel?.markDirty();
  }

  void updateDelivery(int delivered) {}
  void updateBonus(int bonus) {}

  @override
  void update(double dt) {
    super.update(dt);
    if (_comboBorderFlash > 0) {
      _comboBorderFlash = (_comboBorderFlash - dt).clamp(0.0, 0.40);
    }
    _panel
      ?..score = _score
      ..lives = _lives
      ..papers = _papers
      ..day = _day
      ..coins = _coins
      ..combo = _combo
      ..multiplier = _multiplier;
  }

  @override
  void render(Canvas canvas) {
    super.render(canvas);
    if (_comboBorderFlash > 0) {
      final alpha = (_comboBorderFlash / 0.40) * 0.55;
      final borderPaint = Paint()
        ..color = const Color(0xFFFFD54F).withValues(alpha: alpha)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 5.0;
      canvas.drawRect(
        Rect.fromLTWH(3, 3, size.x - 6, size.y - 6),
        borderPaint,
      );
    }
  }
}

class _ScoreboardPanel extends PositionComponent {
  int score = 0;
  int lives = 0;
  int papers = 0;
  int day = 1;
  int coins = 0;
  int combo = 0;
  int multiplier = 1;

  bool _dirty = true;

  _ScoreboardPanel({required Vector2 size})
      : super(size: size, position: Vector2.zero(), priority: -1);

  void markDirty() => _dirty = true;

  static final _scorePaint = TextPaint(
    style: const TextStyle(
      color: Colors.white,
      fontSize: 28,
      fontWeight: FontWeight.w900,
      letterSpacing: 2.0,
      shadows: [Shadow(color: Colors.black, blurRadius: 3, offset: Offset(2, 2))],
    ),
  );

  static final _labelPaint = TextPaint(
    style: const TextStyle(
      color: Color(0xFFFFD54F),
      fontSize: 10,
      fontWeight: FontWeight.w900,
      letterSpacing: 2.0,
      shadows: [Shadow(color: Colors.black, blurRadius: 2)],
    ),
  );

  static final _smallPaint = TextPaint(
    style: const TextStyle(
      color: Colors.white,
      fontSize: 17,
      fontWeight: FontWeight.w900,
      shadows: [Shadow(color: Colors.black, blurRadius: 3, offset: Offset(1, 1))],
    ),
  );

  @override
  void render(Canvas canvas) {
    final w = size.x;
    final h = size.y;

    // Shadow behind panel.
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(8, 7, w - 16, h - 12),
        const Radius.circular(10),
      ),
      Paint()..color = const Color(0x99000000),
    );

    final panel = RRect.fromRectAndRadius(
      Rect.fromLTWH(10, 4, w - 20, h - 14),
      const Radius.circular(9),
    );

    canvas.drawRRect(panel, Paint()..color = const Color(0xF20A1922));
    canvas.drawRRect(
      panel,
      Paint()
        ..shader = Gradient.linear(
          const Offset(0, 4),
          Offset(0, h - 10),
          [const Color(0x44255A73), const Color(0x00000000)],
        ),
    );
    canvas.drawRRect(
      panel,
      Paint()
        ..color = const Color(0xFFFFC928)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3,
    );
    canvas.drawRRect(
      panel.deflate(4),
      Paint()
        ..color = const Color(0xFF132C38)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.2,
    );

    // Subtle CRT scan lines.
    final scan = Paint()..color = const Color(0x18000000);
    for (double y = 10; y < h - 14; y += 5) {
      canvas.drawRect(Rect.fromLTWH(14, y, w - 28, 1), scan);
    }

    // Score block.
    _labelPaint.render(canvas, 'SCORE', Vector2(w / 2 - 30, 12));
    final scoreText = score.toString().padLeft(6, '0');
    _scorePaint.render(canvas, scoreText, Vector2(w / 2 - 64, 29));

    // Lives.
    _drawHeart(canvas, 26, 26, 19);
    _smallPaint.render(canvas, 'x$lives', Vector2(54, 28));

    // Papers.
    _drawNewspaper(canvas, w - 114, 24, 30, 22);
    _smallPaint.render(canvas, 'x$papers', Vector2(w - 76, 28));

    // Lower chips: day left, coins right.
    _drawChip(canvas, 22, h - 31, 88, 22, 'DAY $day', alignLeft: true);
    _drawCoin(canvas, w - 101, h - 24, 9);
    _drawChip(canvas, w - 90, h - 31, 68, 22, '$coins', alignLeft: false);

    _dirty = false;
  }

  void _drawChip(Canvas canvas, double x, double y, double w, double h,
      String label,
      {required bool alignLeft}) {
    final r = RRect.fromRectAndRadius(
      Rect.fromLTWH(x, y, w, h),
      const Radius.circular(11),
    );
    canvas.drawRRect(r, Paint()..color = const Color(0xFF203844));
    canvas.drawRRect(
      r,
      Paint()
        ..color = const Color(0xFFFFC928)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.6,
    );
    _labelPaint.render(
      canvas,
      label,
      Vector2(alignLeft ? x + 13 : x + 26, y + 5),
    );
  }

  void _drawHeart(Canvas canvas, double x, double y, double s) {
    final path = Path();
    path.moveTo(x + s / 2, y + s);
    path.cubicTo(x + s * 1.18, y + s * 0.56, x + s * 0.88, y - s * 0.08,
        x + s / 2, y + s * 0.30);
    path.cubicTo(x + s * 0.12, y - s * 0.08, x - s * 0.18, y + s * 0.56,
        x + s / 2, y + s);
    path.close();
    canvas.drawPath(path, Paint()..color = const Color(0xFFE91E3A));
    canvas.drawPath(
      path,
      Paint()
        ..color = const Color(0xFF710011)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.4,
    );
    canvas.drawCircle(
      Offset(x + s * 0.34, y + s * 0.28),
      s * 0.11,
      Paint()..color = const Color(0x88FFFFFF),
    );
  }

  void _drawNewspaper(Canvas canvas, double x, double y, double w, double h) {
    canvas.drawRect(Rect.fromLTWH(x + 3, y + 3, w, h),
        Paint()..color = const Color(0xFF918B72));
    canvas.drawRect(
        Rect.fromLTWH(x, y, w, h), Paint()..color = const Color(0xFFF8F1D9));
    canvas.drawRect(
      Rect.fromLTWH(x, y, w, h),
      Paint()
        ..color = const Color(0xFF4E4938)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1,
    );
    canvas.drawRect(Rect.fromLTWH(x + 3, y + 3, w - 6, 5),
        Paint()..color = const Color(0xFF25323A));
    final line = Paint()
      ..color = const Color(0xFF7A7460)
      ..strokeWidth = 1;
    for (int i = 0; i < 4; i++) {
      canvas.drawLine(
          Offset(x + 4, y + 11 + i * 3), Offset(x + w - 4, y + 11 + i * 3), line);
    }
  }

  void _drawCoin(Canvas canvas, double x, double y, double r) {
    canvas.drawCircle(Offset(x, y), r, Paint()..color = const Color(0xFFFFC928));
    canvas.drawCircle(
      Offset(x, y),
      r,
      Paint()
        ..color = const Color(0xFF9B6500)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.4,
    );
    canvas.drawCircle(Offset(x - 3, y - 3), 2.2,
        Paint()..color = const Color(0x88FFFFFF));
  }
}

class _ComboBanner extends PositionComponent {
  static const Color glow = Color(0xFFFFD54F);

  int _combo = 0;
  int _mult = 1;
  double _pulse = 0;
  TextComponent? _text;

  _ComboBanner({required Vector2 center})
      : super(
          position: center,
          anchor: Anchor.center,
          size: Vector2(180, 26),
          priority: 10,
        );

  static final _paint = TextPaint(
    style: const TextStyle(
      color: glow,
      fontSize: 13,
      fontWeight: FontWeight.w900,
      letterSpacing: 1.4,
      shadows: [Shadow(color: Colors.black, blurRadius: 4, offset: Offset(1, 1))],
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
      _text?.text = 'COMBO x$mult';
    } else if (combo > 0) {
      _text?.text = 'STREAK $combo';
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
    final pulseScale = 1.0 + t * 0.12;
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
        ..color = glow.withValues(alpha: 0.28 + t * 0.15)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6),
    );
    canvas.drawRRect(r, Paint()..color = const Color(0xEE0A1922));
    canvas.drawRRect(
      r,
      Paint()
        ..color = glow
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.6,
    );
    canvas.restore();
  }
}

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

    final barY = screenH - 7.0;
    const barH = 5.0;

    canvas.drawRect(
      Rect.fromLTWH(0, barY, screenW, barH),
      Paint()..color = const Color(0xAA0A1922),
    );

    if (progress > 0) {
      final fillW = screenW * progress;
      canvas.drawRect(
        Rect.fromLTWH(0, barY, fillW, barH),
        Paint()
          ..shader = Gradient.linear(
            Offset(0, barY),
            Offset(fillW, barY),
            [const Color(0xFFFFD54F), const Color(0xFFFF7A00)],
          ),
      );
    }
  }
}
