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
    with SingleTickerProviderStateMixin {
  late AnimationController _bobCtrl;
  int _highScore = 0;
  int _coins = 0;

  @override
  void initState() {
    super.initState();
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
    _bobCtrl.dispose();
    super.dispose();
  }

  void _onPlay(Difficulty difficulty) {
    AudioService.instance.playPickup();
    Navigator.of(context)
        .pushNamed('/game', arguments: difficulty)
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
          'EXIT?',
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
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        final exit = await _confirmExit();
        if (exit) SystemNavigator.pop();
      },
      child: Scaffold(
        backgroundColor: const Color(0xFF0D0D0D),
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Column(
              children: [
                // Top: coin badge.
                Padding(
                  padding: const EdgeInsets.only(top: 8, bottom: 8),
                  child: Row(
                    children: [
                      const Spacer(),
                      _CoinBadge(coins: _coins),
                    ],
                  ),
                ),
                const Spacer(flex: 2),
                _BobbingBike(controller: _bobCtrl),
                const SizedBox(height: 18),
                Text(
                  'DELIVERY',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.pressStart2p(
                    fontSize: 32,
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
                  textAlign: TextAlign.center,
                  style: GoogleFonts.pressStart2p(
                    fontSize: 42,
                    color: const Color(0xFF00E676),
                    letterSpacing: 8,
                    shadows: const [
                      Shadow(color: Color(0x8000E676), blurRadius: 18),
                      Shadow(color: Colors.black, blurRadius: 4),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                _PaperRunTag(),
                const Spacer(flex: 3),
                _DifficultyLaunchButton(
                  label: 'EASY',
                  emoji: '🟢',
                  color: const Color(0xFF43A047),
                  onTap: () => _onPlay(Difficulty.easy),
                ),
                const SizedBox(height: 12),
                _DifficultyLaunchButton(
                  label: 'MEDIUM',
                  emoji: '🟡',
                  color: const Color(0xFFFB8C00),
                  onTap: () => _onPlay(Difficulty.medium),
                ),
                const SizedBox(height: 12),
                _DifficultyLaunchButton(
                  label: 'HARD',
                  emoji: '🔴',
                  color: const Color(0xFFE53935),
                  onTap: () => _onPlay(Difficulty.hard),
                ),
                const SizedBox(height: 12),
                _OutlinedDarkButton(onTap: _onStore),
                const Spacer(flex: 1),
                Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Text(
                    'BEST   $_highScore',
                    style: GoogleFonts.pressStart2p(
                      fontSize: 10,
                      color: Colors.white60,
                      letterSpacing: 2,
                    ),
                  ),
                ),
                AdService.instance.bannerAd(),
              ],
            ),
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
          BoxShadow(color: Colors.black54, blurRadius: 6),
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
      builder: (context, _) {
        final v = sin(controller.value * 2 * pi);
        return Transform.translate(
          offset: Offset(0, -v * 6),
          child: CustomPaint(
            size: const Size(120, 110),
            painter: _MenuBikePainter(wheelAngle: controller.value * 2 * pi),
          ),
        );
      },
    );
  }
}

class _MenuBikePainter extends CustomPainter {
  final double wheelAngle;
  _MenuBikePainter({required this.wheelAngle});

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    // Shadow.
    canvas.drawOval(
      Rect.fromCenter(center: Offset(w / 2, h - 4), width: w * 0.7, height: 10),
      Paint()..color = const Color(0x66000000),
    );

    final rear = Offset(w * 0.28, h * 0.70);
    final front = Offset(w * 0.70, h * 0.40);
    const rearR = 16.0;
    const frontR = 14.0;

    void drawWheel(Offset c, double r) {
      canvas.drawCircle(c, r, Paint()..color = const Color(0xFF1A1A1A));
      canvas.drawCircle(c, r - 3, Paint()..color = const Color(0xFF888888));
      canvas.drawCircle(c, r - 5, Paint()..color = const Color(0xFFCCCCCC));
      canvas.save();
      canvas.translate(c.dx, c.dy);
      canvas.rotate(wheelAngle);
      final spokePaint = Paint()
        ..color = const Color(0xFF777777)
        ..strokeWidth = 1.2;
      for (int i = 0; i < 8; i++) {
        final ang = i * pi / 4;
        canvas.drawLine(
            Offset.zero,
            Offset(cos(ang) * (r - 4), sin(ang) * (r - 4)),
            spokePaint);
      }
      canvas.restore();
      canvas.drawCircle(c, 2.5, Paint()..color = const Color(0xFFE0E0E0));
    }

    drawWheel(rear, rearR);
    drawWheel(front, frontR);

    final framePaint = Paint()
      ..color = const Color(0xFFE53935)
      ..strokeWidth = 4.0
      ..strokeCap = StrokeCap.round;
    final bb = Offset(w * 0.50, h * 0.58);
    final seatTop = Offset(w * 0.34, h * 0.42);
    final head = Offset(w * 0.64, h * 0.30);
    canvas.drawLine(bb, seatTop, framePaint);
    canvas.drawLine(head, bb, framePaint);
    canvas.drawLine(seatTop, head, framePaint);
    canvas.drawLine(bb, rear, framePaint);
    canvas.drawLine(rear, seatTop, framePaint);
    canvas.drawLine(head, front, framePaint);

    // Handlebar.
    canvas.drawLine(
      Offset(head.dx - 9, head.dy - 4),
      Offset(head.dx + 11, head.dy - 6),
      Paint()
        ..color = const Color(0xFF222222)
        ..strokeWidth = 3.5
        ..strokeCap = StrokeCap.round,
    );

    // Rider body.
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(w * 0.30, h * 0.36, w * 0.36, h * 0.22),
        const Radius.circular(6),
      ),
      Paint()..color = const Color(0xFF1976D2),
    );
    // Head.
    canvas.drawCircle(
      Offset(w * 0.50, h * 0.26),
      8,
      Paint()..color = const Color(0xFFFFCC99),
    );
    // Helmet.
    canvas.drawArc(
      Rect.fromCenter(
        center: Offset(w * 0.50, h * 0.24),
        width: 20,
        height: 14,
      ),
      pi,
      pi,
      false,
      Paint()..color = const Color(0xFFFFD600),
    );
  }

  @override
  bool shouldRepaint(covariant _MenuBikePainter old) =>
      old.wheelAngle != wheelAngle;
}

class _PaperRunTag extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Container(width: 30, height: 1, color: const Color(0xFFFFD600)),
        const SizedBox(width: 10),
        Text(
          'PAPER RUN',
          style: GoogleFonts.pressStart2p(
            fontSize: 11,
            color: const Color(0xFFFFD600),
            letterSpacing: 3,
          ),
        ),
        const SizedBox(width: 10),
        Container(width: 30, height: 1, color: const Color(0xFFFFD600)),
      ],
    );
  }
}

class _DifficultyLaunchButton extends StatelessWidget {
  final String label;
  final String emoji;
  final Color color;
  final VoidCallback onTap;

  const _DifficultyLaunchButton({
    required this.label,
    required this.emoji,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        height: 58,
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(28),
          boxShadow: [
            BoxShadow(
              color: color.withValues(alpha: 0.55),
              blurRadius: 18,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(emoji, style: const TextStyle(fontSize: 22)),
            const SizedBox(width: 12),
            Text(
              label,
              style: GoogleFonts.pressStart2p(
                fontSize: 16,
                color: Colors.white,
                letterSpacing: 2,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _OutlinedDarkButton extends StatelessWidget {
  final VoidCallback onTap;
  const _OutlinedDarkButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        height: 46,
        decoration: BoxDecoration(
          color: const Color(0xFF1A1A2E),
          borderRadius: BorderRadius.circular(23),
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
