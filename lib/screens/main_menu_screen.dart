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
  late AnimationController _scrollController;
  late AnimationController _bikeBobController;
  late List<_Star> _stars;
  int _highScore = 0;
  int _coins = 0;
  Difficulty _difficulty = Difficulty.medium;
  bool _shownFadeIn = false;
  late AnimationController _fadeController;

  @override
  void initState() {
    super.initState();
    _scrollController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 10),
    )..repeat();
    _bikeBobController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);
    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    final rand = Random(7);
    _stars = List.generate(28, (_) {
      return _Star(
        x: rand.nextDouble(),
        y: rand.nextDouble(),
        speed: 0.02 + rand.nextDouble() * 0.05,
        size: 1.0 + rand.nextDouble() * 2.0,
      );
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _fadeController.forward();
      setState(() => _shownFadeIn = true);
    });
    _load();
  }

  Future<void> _load() async {
    await StoreService.instance.init();
    final hs = await ScoreService.instance.getHighScore();
    if (!mounted) return;
    setState(() {
      _highScore = hs;
      _coins = StoreService.instance.coins;
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _bikeBobController.dispose();
    _fadeController.dispose();
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
          side: const BorderSide(color: Color(0xFFFFC107), width: 1.5),
        ),
        title: Text(
          'EXIT GAME?',
          style: GoogleFonts.pressStart2p(
            color: Colors.white,
            fontSize: 14,
          ),
        ),
        content: const Text(
          'Are you sure you want to exit Delivery Dash?',
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(
              'STAY',
              style: GoogleFonts.pressStart2p(
                color: const Color(0xFF66BB6A),
                fontSize: 11,
              ),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(
              'EXIT',
              style: GoogleFonts.pressStart2p(
                color: const Color(0xFFEF5350),
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
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        final shouldExit = await _confirmExit();
        if (shouldExit) SystemNavigator.pop();
      },
      child: Scaffold(
        body: AnimatedOpacity(
          opacity: _shownFadeIn ? 1.0 : 0.0,
          duration: const Duration(milliseconds: 500),
          child: Stack(
            fit: StackFit.expand,
            children: [
              // Gradient background.
              const DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Color(0xFF0A0A1A), Color(0xFF1A2A0A)],
                  ),
                ),
              ),
              // Drifting star particles.
              AnimatedBuilder(
                animation: _scrollController,
                builder: (context, _) => CustomPaint(
                  size: Size.infinite,
                  painter: _StarsPainter(
                    stars: _stars,
                    progress: _scrollController.value,
                  ),
                ),
              ),
              // Road preview strip in the middle.
              Positioned(
                left: 0,
                right: 0,
                top: MediaQuery.of(context).size.height * 0.35,
                child: SizedBox(
                  height: MediaQuery.of(context).size.height * 0.22,
                  child: AnimatedBuilder(
                    animation: _scrollController,
                    builder: (context, _) => CustomPaint(
                      painter:
                          _RoadPreviewPainter(_scrollController.value),
                    ),
                  ),
                ),
              ),

              SafeArea(
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 56),
                  child: Column(
                    children: [
                      _TopBar(coins: _coins),
                      const SizedBox(height: 20),
                      Text(
                        'DELIVERY DASH',
                        textAlign: TextAlign.center,
                        style: GoogleFonts.pressStart2p(
                          fontSize: 26,
                          color: Colors.white,
                          letterSpacing: 2,
                          shadows: const [
                            Shadow(
                              color: Colors.black,
                              blurRadius: 10,
                              offset: Offset(3, 4),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        'Paper Run',
                        style: GoogleFonts.righteous(
                          fontSize: 16,
                          color: const Color(0xFFFFD700),
                          fontStyle: FontStyle.italic,
                          letterSpacing: 2,
                          shadows: const [
                            Shadow(color: Colors.black, blurRadius: 6),
                          ],
                        ),
                      ),
                      const SizedBox(height: 14),
                      _BobbingBike(controller: _bikeBobController),
                      const Spacer(flex: 4),
                      const _ControlCardsRow(),
                      const SizedBox(height: 18),
                      _DifficultySelector(
                        selected: _difficulty,
                        onChange: (d) => setState(() => _difficulty = d),
                      ),
                      const SizedBox(height: 22),
                      _BigButton(
                        label: 'PLAY',
                        onTap: _onPlay,
                        gradient: const LinearGradient(
                          colors: [Color(0xFF2ECC71), Color(0xFF27AE60)],
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                        ),
                        width: 220,
                        height: 64,
                        fontSize: 22,
                      ),
                      const SizedBox(height: 12),
                      _OutlineButton(
                        label: 'STORE',
                        onTap: _onStore,
                      ),
                      const Spacer(flex: 2),
                      Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 18, vertical: 8),
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.55),
                            borderRadius: BorderRadius.circular(12),
                            border:
                                Border.all(color: Colors.white24, width: 1),
                          ),
                          child: Text(
                            'BEST  $_highScore',
                            style: GoogleFonts.pressStart2p(
                              fontSize: 11,
                              color: Colors.white70,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              Align(
                alignment: Alignment.bottomCenter,
                child: SafeArea(child: AdService.instance.bannerAd()),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Star {
  final double x;
  double y;
  final double speed;
  final double size;
  _Star({
    required this.x,
    required this.y,
    required this.speed,
    required this.size,
  });
}

class _StarsPainter extends CustomPainter {
  final List<_Star> stars;
  final double progress;
  _StarsPainter({required this.stars, required this.progress});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = Colors.white.withValues(alpha: 0.6);
    for (final star in stars) {
      final dy = (star.y - progress * star.speed) % 1.0;
      final pos = Offset(star.x * size.width, dy * size.height);
      canvas.drawCircle(pos, star.size, paint);
    }
  }

  @override
  bool shouldRepaint(_StarsPainter old) => old.progress != progress;
}

class _TopBar extends StatelessWidget {
  final int coins;
  const _TopBar({required this.coins});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: Row(
        children: [
          const Spacer(),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.55),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: const Color(0xFFFFD54F), width: 1.5),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('🪙', style: TextStyle(fontSize: 18)),
                const SizedBox(width: 6),
                Text(
                  '$coins',
                  style: GoogleFonts.pressStart2p(
                    fontSize: 14,
                    color: const Color(0xFFFFD54F),
                  ),
                ),
              ],
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
        final v = sin(controller.value * 2 * pi);
        return Transform.translate(
          offset: Offset(v * 8, 0),
          child: child,
        );
      },
      child: Image.asset(
        'assets/images/mailbox_blue.png',
        width: 40,
        height: 60,
        filterQuality: FilterQuality.none,
        errorBuilder: (_, __, ___) => const SizedBox(width: 40, height: 60),
      ),
    );
  }
}

class _ControlCardsRow extends StatelessWidget {
  const _ControlCardsRow();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.symmetric(horizontal: 18),
      child: Row(
        children: [
          Expanded(child: _ControlCard(emoji: '🚲', label: 'DRAG', hint: 'Steer bike')),
          SizedBox(width: 8),
          Expanded(child: _ControlCard(emoji: '📰', label: 'TAP', hint: 'Throw paper')),
          SizedBox(width: 8),
          Expanded(child: _ControlCard(emoji: '📦', label: 'RIDE', hint: 'Collect packs')),
        ],
      ),
    );
  }
}

class _ControlCard extends StatelessWidget {
  final String emoji;
  final String label;
  final String hint;
  const _ControlCard({
    required this.emoji,
    required this.label,
    required this.hint,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 6),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.45),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white24, width: 1),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(emoji, style: const TextStyle(fontSize: 22)),
          const SizedBox(height: 4),
          Text(
            label,
            style: GoogleFonts.pressStart2p(
              color: const Color(0xFFFFD54F),
              fontSize: 9,
              letterSpacing: 1.4,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            hint,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 10,
            ),
          ),
        ],
      ),
    );
  }
}

class _DifficultySelector extends StatelessWidget {
  final Difficulty selected;
  final ValueChanged<Difficulty> onChange;

  const _DifficultySelector({
    required this.selected,
    required this.onChange,
  });

  static const Map<Difficulty, Color> _colors = {
    Difficulty.easy: Color(0xFF43A047),
    Difficulty.medium: Color(0xFFFBC02D),
    Difficulty.hard: Color(0xFFE53935),
  };

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        for (final d in Difficulty.values)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 6),
            child: _DifficultyButton(
              label: DifficultyConfig.label(d),
              startLevel: DifficultyConfig.startLevelFor(d),
              color: _colors[d]!,
              selected: d == selected,
              onTap: () => onChange(d),
            ),
          ),
      ],
    );
  }
}

class _DifficultyButton extends StatelessWidget {
  final String label;
  final int startLevel;
  final Color color;
  final bool selected;
  final VoidCallback onTap;

  const _DifficultyButton({
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
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: selected ? color : color.withValues(alpha: 0.25),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: selected ? Colors.white : Colors.white24,
            width: selected ? 2 : 1,
          ),
          boxShadow: selected
              ? [
                  BoxShadow(
                    color: Colors.white.withValues(alpha: 0.45),
                    blurRadius: 14,
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
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'START L$startLevel',
              style: GoogleFonts.pressStart2p(
                fontSize: 7,
                color: Colors.white70,
                letterSpacing: 1.4,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _BigButton extends StatelessWidget {
  final String label;
  final Gradient gradient;
  final VoidCallback onTap;
  final double width;
  final double height;
  final double fontSize;

  const _BigButton({
    required this.label,
    required this.gradient,
    required this.onTap,
    required this.width,
    required this.height,
    required this.fontSize,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: width,
        height: height,
        decoration: BoxDecoration(
          gradient: gradient,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white24, width: 1.5),
          boxShadow: const [
            BoxShadow(
              color: Colors.black54,
              blurRadius: 10,
              offset: Offset(0, 5),
            ),
          ],
        ),
        child: Center(
          child: Text(
            label,
            style: GoogleFonts.pressStart2p(
              fontSize: fontSize,
              color: Colors.white,
            ),
          ),
        ),
      ),
    );
  }
}

class _OutlineButton extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  const _OutlineButton({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 160,
        height: 44,
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.5),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFFFFD54F), width: 1.5),
        ),
        child: Center(
          child: Text(
            label,
            style: GoogleFonts.pressStart2p(
              fontSize: 13,
              color: const Color(0xFFFFD54F),
            ),
          ),
        ),
      ),
    );
  }
}

/// Quick perspective road preview for the menu — pure custom paint so we
/// don't need a Flame mini-game.
class _RoadPreviewPainter extends CustomPainter {
  final double progress;
  _RoadPreviewPainter(this.progress);

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    // Sky-ish strip
    canvas.drawRect(Rect.fromLTWH(0, 0, w, h * 0.06),
        Paint()..color = const Color(0xFF1B2032));

    // Grass.
    canvas.drawRect(
      Rect.fromLTWH(0, 0, w, h),
      Paint()..color = const Color(0xFF388E3C),
    );

    final topL = Offset(w * 0.35, 0);
    final topR = Offset(w * 0.65, 0);
    final botL = Offset(w * 0.15, h);
    final botR = Offset(w * 0.85, h);

    final roadPath = Path()
      ..moveTo(topL.dx, topL.dy)
      ..lineTo(topR.dx, topR.dy)
      ..lineTo(botR.dx, botR.dy)
      ..lineTo(botL.dx, botL.dy)
      ..close();
    canvas.drawPath(roadPath, Paint()..color = const Color(0xFF2E2E33));

    // Curbs.
    final curbPaint = Paint()
      ..color = Colors.white
      ..strokeWidth = 2;
    canvas.drawLine(topL, botL, curbPaint);
    canvas.drawLine(topR, botR, curbPaint);

    // Dashed center line, foreshortened toward top.
    const cycle = 24.0;
    const dash = 14.0;
    final phase = (progress * cycle * 12) % cycle;
    final dashPaint = Paint()
      ..color = const Color(0xFFFFC107)
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.square;
    var ground = -phase;
    while (ground < h + cycle) {
      final yA = h - ground - dash;
      final yB = h - ground;
      if (yB < 0) break;
      if (yA > 0) {
        final tA = (yA / h).clamp(0.0, 1.0);
        final tB = (yB / h).clamp(0.0, 1.0);
        final xA = w * (0.5);
        final xB = w * (0.5);
        // Center is constant — just draw line at center.
        canvas.drawLine(
          Offset(xA, yA),
          Offset(xB, yB),
          dashPaint
            ..strokeWidth = (1.5 + tB * 3).clamp(1.5, 4.5),
        );
        // Force perspective by using yA/yB so dashes pack near vp.
        // (Already implicit — they share x; gap visually matches cycle.)
        // Use tA/tB to satisfy analyzer.
        // ignore: unused_local_variable
        final _ = tA;
      }
      ground += cycle;
    }

    // A couple of houses scrolling on the left sidewalk.
    _drawHouse(canvas, size, _wrap(progress, 0.3, 0.0));
    _drawHouse(canvas, size, _wrap(progress, 0.3, 0.5));
    // A car on the road.
    _drawCar(canvas, size, _wrap(progress, 0.4, 0.2));
  }

  double _wrap(double p, double speed, double phase) {
    return (p * speed + phase) % 1.0;
  }

  void _drawHouse(Canvas canvas, Size size, double t) {
    final h = size.height;
    final w = size.width;
    final y = t * (h + 60) - 30;
    final scale = 0.35 + 0.65 * (y / h).clamp(0.0, 1.0);
    final houseW = 36 * scale;
    final houseH = 38 * scale;
    final sidewalkRightAtY = w * (0.35 + (0.15 - 0.35) * (y / h).clamp(0.0, 1.0));
    final x = (sidewalkRightAtY - houseW - 6).clamp(2.0, sidewalkRightAtY);
    canvas.drawRect(
      Rect.fromLTWH(x, y, houseW, houseH * 0.6),
      Paint()..color = const Color(0xFFD7A86E),
    );
    final roof = Path()
      ..moveTo(x - 2, y)
      ..lineTo(x + houseW / 2, y - houseH * 0.45)
      ..lineTo(x + houseW + 2, y)
      ..close();
    canvas.drawPath(roof, Paint()..color = const Color(0xFF8E2E1F));
  }

  void _drawCar(Canvas canvas, Size size, double t) {
    final h = size.height;
    final w = size.width;
    final y = t * (h + 50) - 25;
    final scale = 0.35 + 0.65 * (y / h).clamp(0.0, 1.0);
    final cw = 18 * scale;
    final ch = 30 * scale;
    final cx = w * 0.5 - cw / 2;
    canvas.drawRRect(
      RRect.fromRectAndRadius(Rect.fromLTWH(cx, y - ch, cw, ch),
          Radius.circular(3 * scale)),
      Paint()..color = const Color(0xFFE53935),
    );
  }

  @override
  bool shouldRepaint(_RoadPreviewPainter old) => old.progress != progress;
}
