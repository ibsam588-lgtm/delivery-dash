import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import '../game/difficulty.dart';
import '../services/ad_service.dart';
import '../services/audio_service.dart';
import '../services/score_service.dart';
import '../services/store_service.dart';

class MainMenuScreen extends StatefulWidget {
  const MainMenuScreen({super.key});

  @override
  State<MainMenuScreen> createState() => _MainMenuScreenState();
}

class _MainMenuScreenState extends State<MainMenuScreen>
    with TickerProviderStateMixin {
  late AnimationController _scrollCtrl;
  late AnimationController _bobCtrl;

  int _highScore = 0;
  int _coins = 0;
  Difficulty _difficulty = Difficulty.medium;

  @override
  void initState() {
    super.initState();
    _scrollCtrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 12),
    )..repeat();
    _bobCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);
    _load();
  }

  Future<void> _load() async {
    try {
      await StoreService.instance.init();
    } catch (_) {}
    int hs = 0;
    try {
      hs = await ScoreService.instance.getHighScore();
    } catch (_) {}
    if (!mounted) return;
    setState(() {
      _highScore = hs;
      _coins = StoreService.instance.coins;
    });
  }

  @override
  void dispose() {
    _scrollCtrl.dispose();
    _bobCtrl.dispose();
    super.dispose();
  }

  void _onPlay() {
    AudioService.instance.playPickup();
    Navigator.of(context)
        .pushNamed('/game', arguments: _difficulty)
        .then((_) => _refresh());
  }

  void _onStore() {
    Navigator.of(context).pushNamed('/store').then((_) => _refresh());
  }

  void _refresh() {
    if (!mounted) return;
    setState(() => _coins = StoreService.instance.coins);
    ScoreService.instance.getHighScore().then((hs) {
      if (!mounted) return;
      setState(() => _highScore = hs);
    });
  }

  Future<bool> _confirmExit() async {
    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A2E),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: Color(0xFF00E676), width: 1.5),
        ),
        title: Text(
          'EXIT GAME?',
          style: GoogleFonts.pressStart2p(
            color: Colors.white,
            fontSize: 14,
          ),
        ),
        content: const Text(
          'Are you sure you want to leave?',
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(
              'STAY',
              style: GoogleFonts.pressStart2p(
                color: const Color(0xFF00E676),
                fontSize: 11,
              ),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(
              'EXIT',
              style: GoogleFonts.pressStart2p(
                color: const Color(0xFFFF1744),
                fontSize: 11,
              ),
            ),
          ),
        ],
      ),
    );
    return result == true;
  }

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final heroHeight = media.size.height * 0.45;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        final shouldExit = await _confirmExit();
        if (shouldExit) SystemNavigator.pop();
      },
      child: Scaffold(
        backgroundColor: const Color(0xFF0D0D0D),
        body: SafeArea(
          child: Column(
            children: [
              // ── Hero (logo + road preview) ────────────────────────
              SizedBox(
                height: heroHeight,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    // Scrolling perspective road as background.
                    AnimatedBuilder(
                      animation: _scrollCtrl,
                      builder: (ctx, _) => CustomPaint(
                        size: Size.infinite,
                        painter: _RoadPreviewPainter(_scrollCtrl.value),
                      ),
                    ),
                    // Fade to bg at the bottom of hero so the rest of
                    // the menu sits cleanly on #0D0D0D.
                    const DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Color(0x000D0D0D),
                            Color(0x000D0D0D),
                            Color(0xFF0D0D0D),
                          ],
                          stops: [0.0, 0.55, 1.0],
                        ),
                      ),
                    ),

                    // Title + tag, centered in the hero.
                    Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            'DELIVERY',
                            style: GoogleFonts.pressStart2p(
                              fontSize: 28,
                              color: Colors.white,
                              letterSpacing: 3,
                              shadows: const [
                                Shadow(color: Colors.black, blurRadius: 8),
                              ],
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            'DASH',
                            style: GoogleFonts.pressStart2p(
                              fontSize: 36,
                              color: const Color(0xFF00E676),
                              letterSpacing: 6,
                              shadows: const [
                                Shadow(
                                  color: Color(0x8000E676),
                                  blurRadius: 24,
                                ),
                                Shadow(color: Colors.black, blurRadius: 4),
                              ],
                            ),
                          ),
                          const SizedBox(height: 12),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 14, vertical: 6),
                            decoration: BoxDecoration(
                              color: const Color(0x331A1A2E),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                color: const Color(0xFFFFD600),
                                width: 1,
                              ),
                            ),
                            child: Text(
                              'PAPER RUN ✦',
                              style: GoogleFonts.pressStart2p(
                                fontSize: 10,
                                color: const Color(0xFFFFD600),
                                letterSpacing: 2,
                              ),
                            ),
                          ),
                          const SizedBox(height: 14),
                          _BobbingBike(controller: _bobCtrl),
                        ],
                      ),
                    ),

                    // Coin badge top-right.
                    Positioned(
                      top: 12,
                      right: 16,
                      child: _CoinBadge(coins: _coins),
                    ),
                  ],
                ),
              ),

              // ── Difficulty + actions ──────────────────────────────
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Column(
                    children: [
                      const SizedBox(height: 16),
                      _DifficultyRow(
                        selected: _difficulty,
                        onChange: (d) => setState(() => _difficulty = d),
                      ),
                      const Spacer(),
                      _PlayButton(onTap: _onPlay),
                      const SizedBox(height: 12),
                      _StoreButton(onTap: _onStore),
                      const Spacer(),
                      Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Text(
                          'BEST   $_highScore',
                          style: GoogleFonts.pressStart2p(
                            fontSize: 10,
                            color: Colors.white60,
                            letterSpacing: 2,
                          ),
                        ),
                      ),
                      // Banner ad slot.
                      AdService.instance.bannerAd(),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CoinBadge extends StatelessWidget {
  final int coins;
  const _CoinBadge({required this.coins});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFFFFD600),
        borderRadius: BorderRadius.circular(20),
        boxShadow: const [
          BoxShadow(color: Colors.black54, blurRadius: 8),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text('🪙', style: TextStyle(fontSize: 16)),
          const SizedBox(width: 4),
          Text(
            '$coins',
            style: GoogleFonts.pressStart2p(
              fontSize: 12,
              color: const Color(0xFF1A1A2E),
            ),
          ),
        ],
      ),
    );
  }
}

class _BobbingBike extends StatelessWidget {
  final AnimationController controller;
  const _BobbingBike({required this.controller});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (context, child) {
        final t = controller.value * 2 * pi;
        return Transform.translate(
          offset: Offset(0, -sin(t) * 4),
          child: child,
        );
      },
      child: Image.asset(
        'assets/images/mailbox_blue.png',
        width: 44,
        height: 64,
        filterQuality: FilterQuality.none,
        isAntiAlias: false,
        errorBuilder: (_, __, ___) => const SizedBox(width: 44, height: 64),
      ),
    );
  }
}

class _DifficultyRow extends StatelessWidget {
  final Difficulty selected;
  final ValueChanged<Difficulty> onChange;
  const _DifficultyRow({
    required this.selected,
    required this.onChange,
  });

  static const Map<Difficulty, Color> _colors = {
    Difficulty.easy: Color(0xFF00E676),
    Difficulty.medium: Color(0xFFFFD600),
    Difficulty.hard: Color(0xFFFF1744),
  };

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        for (final d in Difficulty.values) ...[
          Expanded(
            child: _DifficultyChip(
              label: DifficultyConfig.label(d),
              startLevel: DifficultyConfig.startLevelFor(d),
              color: _colors[d]!,
              selected: d == selected,
              onTap: () => onChange(d),
            ),
          ),
          if (d != Difficulty.hard) const SizedBox(width: 10),
        ],
      ],
    );
  }
}

class _DifficultyChip extends StatelessWidget {
  final String label;
  final int startLevel;
  final Color color;
  final bool selected;
  final VoidCallback onTap;

  const _DifficultyChip({
    required this.label,
    required this.startLevel,
    required this.color,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: selected ? color : Colors.transparent,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: selected ? color : color.withValues(alpha: 0.5),
            width: selected ? 2 : 1.5,
          ),
          boxShadow: selected
              ? [
                  BoxShadow(
                    color: color.withValues(alpha: 0.55),
                    blurRadius: 18,
                  ),
                ]
              : null,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: GoogleFonts.pressStart2p(
                fontSize: 11,
                color: selected ? const Color(0xFF0D0D0D) : color,
                letterSpacing: 1.2,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'L$startLevel',
              style: GoogleFonts.pressStart2p(
                fontSize: 8,
                color: selected
                    ? const Color(0xFF0D0D0D).withValues(alpha: 0.8)
                    : color.withValues(alpha: 0.7),
                letterSpacing: 1.4,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PlayButton extends StatelessWidget {
  final VoidCallback onTap;
  const _PlayButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        height: 64,
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFF00E676), Color(0xFF00C853)],
          ),
          borderRadius: BorderRadius.circular(32),
          boxShadow: const [
            BoxShadow(
              color: Color(0x8000E676),
              blurRadius: 24,
              offset: Offset(0, 6),
            ),
          ],
        ),
        child: Center(
          child: Text(
            '▶  PLAY',
            style: GoogleFonts.pressStart2p(
              fontSize: 20,
              color: Colors.white,
              letterSpacing: 2,
            ),
          ),
        ),
      ),
    );
  }
}

class _StoreButton extends StatelessWidget {
  final VoidCallback onTap;
  const _StoreButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        height: 48,
        decoration: BoxDecoration(
          color: const Color(0xFF1A1A2E),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: const Color(0xFF00E676), width: 1.5),
        ),
        child: Center(
          child: Text(
            'STORE',
            style: GoogleFonts.pressStart2p(
              fontSize: 13,
              color: const Color(0xFF00E676),
              letterSpacing: 2,
            ),
          ),
        ),
      ),
    );
  }
}

/// Simplified perspective road preview for the menu's hero strip.
class _RoadPreviewPainter extends CustomPainter {
  final double progress;
  _RoadPreviewPainter(this.progress);

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    // Dark base.
    canvas.drawRect(
      Rect.fromLTWH(0, 0, w, h),
      Paint()..color = const Color(0xFF0D0D0D),
    );

    // Grass.
    canvas.drawRect(
      Rect.fromLTWH(0, 0, w, h),
      Paint()..color = const Color(0xFF1B3A1B),
    );

    final topL = Offset(w * 0.40, 0);
    final topR = Offset(w * 0.60, 0);
    final botL = Offset(w * 0.15, h);
    final botR = Offset(w * 0.85, h);

    final road = Path()
      ..moveTo(topL.dx, topL.dy)
      ..lineTo(topR.dx, topR.dy)
      ..lineTo(botR.dx, botR.dy)
      ..lineTo(botL.dx, botL.dy)
      ..close();
    canvas.drawPath(road, Paint()..color = const Color(0xFF1A1A1A));

    // Curbs.
    final curb = Paint()
      ..color = Colors.white
      ..strokeWidth = 2;
    canvas.drawLine(topL, botL, curb);
    canvas.drawLine(topR, botR, curb);

    // Dashed center line with depth-aware sizing.
    const cycle = 26.0;
    const dash = 14.0;
    final phase = (progress * cycle * 18) % cycle;
    var ground = -phase;
    while (ground < h + cycle) {
      final yA = h - ground - dash;
      final yB = h - ground;
      if (yB <= 0) break;
      if (yA >= 0) {
        final tB = (yB / h).clamp(0.0, 1.0);
        final stroke = (1.0 + tB * 3.5).clamp(1.0, 4.5);
        canvas.drawLine(
          Offset(w / 2, yA),
          Offset(w / 2, yB),
          Paint()
            ..color = const Color(0xFFFFD600)
            ..strokeWidth = stroke
            ..strokeCap = StrokeCap.square,
        );
      }
      ground += cycle;
    }

    // A few cars passing.
    _drawCar(canvas, size, _wrap(progress, 0.5, 0.10), 0.32);
    _drawCar(canvas, size, _wrap(progress, 0.45, 0.55), 0.68);
    _drawCar(canvas, size, _wrap(progress, 0.4, 0.30), 0.50);
  }

  double _wrap(double p, double speed, double phase) =>
      (p * speed + phase) % 1.0;

  void _drawCar(Canvas canvas, Size size, double t, double laneFraction) {
    final h = size.height;
    final w = size.width;
    final y = t * (h + 60) - 30;
    if (y < 0 || y > h) return;
    final tt = (y / h).clamp(0.0, 1.0);
    final scale = 0.35 + 0.65 * tt;
    final roadL = w * (0.40 + (0.15 - 0.40) * tt);
    final roadR = w * (0.60 + (0.85 - 0.60) * tt);
    final cx = roadL + (roadR - roadL) * laneFraction;
    final cw = 18 * scale;
    final ch = 28 * scale;
    // Shadow.
    canvas.drawOval(
      Rect.fromCenter(
          center: Offset(cx, y - 2),
          width: cw * 1.1,
          height: ch * 0.25),
      Paint()..color = const Color(0x88000000),
    );
    // Body.
    canvas.drawRRect(
      RRect.fromRectAndRadius(
          Rect.fromCenter(center: Offset(cx, y - ch / 2), width: cw, height: ch),
          Radius.circular(3 * scale)),
      Paint()..color = const Color(0xFFE53935),
    );
    // Windshield band.
    canvas.drawRect(
      Rect.fromCenter(
          center: Offset(cx, y - ch * 0.55),
          width: cw * 0.7,
          height: ch * 0.18),
      Paint()..color = const Color(0xFF1A1A2E),
    );
  }

  @override
  bool shouldRepaint(_RoadPreviewPainter old) => old.progress != progress;
}
