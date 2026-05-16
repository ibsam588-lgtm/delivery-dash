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
  late AnimationController _animCtrl;
  int _highScore = 0;
  int _coins = 0;

  @override
  void initState() {
    super.initState();
    _animCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    )..repeat();
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
    _animCtrl.dispose();
    super.dispose();
  }

  void _onPlay(Difficulty difficulty) {
    AudioService.instance.playPickup();
    Navigator.of(context)
        .pushNamed('/game', arguments: difficulty)
        .then((_) => _refresh());
  }

  void _onStore() {
    AudioService.instance.playPickup();
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
        backgroundColor: const Color(0xFF15202A),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
          side: const BorderSide(color: Color(0xFFFFC928), width: 2),
        ),
        title: Text(
          'EXIT ROUTE?',
          style: GoogleFonts.pressStart2p(
            color: Colors.white,
            fontSize: 13,
          ),
        ),
        content: const Text(
          'Are you sure you want to leave the paper route?',
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(
              'STAY',
              style: GoogleFonts.pressStart2p(
                color: const Color(0xFFFFC928),
                fontSize: 10,
              ),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(
              'EXIT',
              style: GoogleFonts.pressStart2p(
                color: const Color(0xFFFF5252),
                fontSize: 10,
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
        backgroundColor: const Color(0xFF0D1820),
        body: Stack(
          children: [
            Positioned.fill(
              child: AnimatedBuilder(
                animation: _animCtrl,
                builder: (context, _) => CustomPaint(
                  painter: _LandingScenePainter(t: _animCtrl.value),
                ),
              ),
            ),
            SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(18, 10, 18, 8),
                child: Column(
                  children: [
                    Row(
                      children: [
                        _StatBadge(label: 'BEST', value: _highScore.toString()),
                        const Spacer(),
                        _CoinBadge(coins: _coins),
                      ],
                    ),
                    const SizedBox(height: 16),
                    _TitleCard(),
                    const Spacer(),
                    AnimatedBuilder(
                      animation: _animCtrl,
                      builder: (context, _) {
                        final bob = sin(_animCtrl.value * 2 * pi) * 5;
                        return Transform.translate(
                          offset: Offset(0, bob),
                          child: const _CourierHero(),
                        );
                      },
                    ),
                    const Spacer(),
                    _RouteCard(
                      onEasy: () => _onPlay(Difficulty.easy),
                      onMedium: () => _onPlay(Difficulty.medium),
                      onHard: () => _onPlay(Difficulty.hard),
                      onStore: _onStore,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'DELIVER PAPERS  •  DODGE TRAFFIC  •  SURVIVE THE ROUTE',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.pressStart2p(
                        fontSize: 7,
                        color: Colors.white70,
                        letterSpacing: 0.7,
                      ),
                    ),
                    const SizedBox(height: 8),
                    AdService.instance.bannerAd(),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _LandingScenePainter extends CustomPainter {
  final double t;
  _LandingScenePainter({required this.t});

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    canvas.drawRect(
      Offset.zero & size,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF6EC6FF), Color(0xFFBEE7A6), Color(0xFF2F9E44)],
        ).createShader(Offset.zero & size),
    );

    final horizon = h * 0.30;
    _drawSkyline(canvas, w, horizon);

    final road = Path()
      ..moveTo(w * 0.30, h)
      ..lineTo(w * 0.70, h)
      ..lineTo(w * 0.58, horizon)
      ..lineTo(w * 0.42, horizon)
      ..close();
    canvas.drawPath(
      road,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: const [Color(0xFF3B4042), Color(0xFF202426)],
        ).createShader(Rect.fromLTWH(0, horizon, w, h - horizon)),
    );

    final curb = Paint()
      ..color = const Color(0xFFF5F1E5)
      ..strokeWidth = 5
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(Offset(w * 0.42, horizon), Offset(w * 0.30, h), curb);
    canvas.drawLine(Offset(w * 0.58, horizon), Offset(w * 0.70, h), curb);

    final dashPaint = Paint()..color = const Color(0xFFF8F6E8);
    final offset = (t * 52) % 52;
    for (double y = horizon + offset - 52; y < h; y += 52) {
      final prog = ((y - horizon) / (h - horizon)).clamp(0.0, 1.0);
      final dashH = 18 + prog * 18;
      final dashW = 3 + prog * 5;
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromCenter(
            center: Offset(w / 2, y),
            width: dashW,
            height: dashH,
          ),
          const Radius.circular(2),
        ),
        dashPaint,
      );
    }

    _drawMenuHouses(canvas, size, left: true);
    _drawMenuHouses(canvas, size, left: false);
  }

  void _drawSkyline(Canvas canvas, double w, double horizon) {
    final trunk = Paint()..color = const Color(0xFF5D4037);
    final leaf = Paint()..color = const Color(0xFF1E6F2A);
    for (double x = 0; x < w; x += 58) {
      canvas.drawRect(Rect.fromLTWH(x + 22, horizon - 24, 7, 24), trunk);
      canvas.drawCircle(Offset(x + 25, horizon - 30), 18, leaf);
      canvas.drawCircle(Offset(x + 15, horizon - 24), 12, leaf);
      canvas.drawCircle(Offset(x + 36, horizon - 24), 12, leaf);
    }
  }

  void _drawMenuHouses(Canvas canvas, Size size, {required bool left}) {
    final w = size.width;
    final h = size.height;
    final baseX = left ? 8.0 : w - 92.0;
    final colors = [
      const Color(0xFFF5E6C8),
      const Color(0xFFFFE082),
      const Color(0xFFB3E5FC),
    ];
    for (int i = 0; i < 3; i++) {
      final y = h * 0.36 + i * 94;
      final x = baseX + (left ? 0 : -i * 2);
      final houseW = 82.0;
      final houseH = 58.0;
      canvas.drawRect(
        Rect.fromLTWH(x, y + 20, houseW, houseH),
        Paint()..color = colors[i % colors.length],
      );
      final roof = Path()
        ..moveTo(x - 4, y + 22)
        ..lineTo(x + houseW / 2, y)
        ..lineTo(x + houseW + 4, y + 22)
        ..close();
      canvas.drawPath(roof, Paint()..color = const Color(0xFFB54A2A));
      canvas.drawRect(Rect.fromLTWH(x + 12, y + 38, 16, 16), Paint()..color = const Color(0xFF90CAF9));
      canvas.drawRect(Rect.fromLTWH(x + 52, y + 38, 16, 16), Paint()..color = const Color(0xFF90CAF9));
      canvas.drawRect(Rect.fromLTWH(x + 34, y + 50, 16, 28), Paint()..color = const Color(0xFF6D3A20));
    }
  }

  @override
  bool shouldRepaint(covariant _LandingScenePainter oldDelegate) =>
      oldDelegate.t != t;
}

class _TitleCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      decoration: BoxDecoration(
        color: const Color(0xE60A1922),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFFFC928), width: 3),
        boxShadow: const [
          BoxShadow(color: Colors.black54, blurRadius: 12, offset: Offset(0, 5)),
        ],
      ),
      child: Column(
        children: [
          Text(
            'DELIVERY',
            textAlign: TextAlign.center,
            style: GoogleFonts.pressStart2p(
              fontSize: 25,
              color: Colors.white,
              letterSpacing: 3,
              shadows: const [Shadow(color: Colors.black, blurRadius: 5)],
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'DASH',
            textAlign: TextAlign.center,
            style: GoogleFonts.pressStart2p(
              fontSize: 38,
              color: const Color(0xFFFFC928),
              letterSpacing: 8,
              shadows: const [
                Shadow(color: Color(0xFFFF6D00), blurRadius: 10),
                Shadow(color: Colors.black, blurRadius: 4),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
            decoration: BoxDecoration(
              color: const Color(0xFFD71920),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Text(
              'CLASSIC PAPER ROUTE',
              style: GoogleFonts.pressStart2p(
                fontSize: 8,
                color: Colors.white,
                letterSpacing: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CourierHero extends StatelessWidget {
  const _CourierHero();

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: const Size(150, 150),
      painter: _CourierHeroPainter(),
    );
  }
}

class _CourierHeroPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    canvas.drawOval(
      Rect.fromCenter(center: Offset(w / 2, h - 8), width: w * 0.78, height: 15),
      Paint()..color = const Color(0x77000000),
    );
    _drawWheel(canvas, Offset(w * 0.50, h * 0.78), 28, vertical: true);
    _drawWheel(canvas, Offset(w * 0.50, h * 0.54), 21, vertical: true);
    final frame = Paint()
      ..color = const Color(0xFFD71920)
      ..strokeWidth = 6
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(Offset(w * 0.50, h * 0.49), Offset(w * 0.50, h * 0.66), frame);
    canvas.drawLine(Offset(w * 0.50, h * 0.66), Offset(w * 0.42, h * 0.57), frame);
    canvas.drawLine(Offset(w * 0.50, h * 0.66), Offset(w * 0.58, h * 0.57), frame);
    canvas.drawLine(Offset(w * 0.30, h * 0.39), Offset(w * 0.70, h * 0.39), Paint()..color = const Color(0xFF222222)..strokeWidth = 5..strokeCap = StrokeCap.round);
    final body = RRect.fromRectAndRadius(
      Rect.fromCenter(center: Offset(w * 0.50, h * 0.38), width: 52, height: 42),
      const Radius.circular(13),
    );
    canvas.drawRRect(body, Paint()..color = const Color(0xFF1565C0));
    canvas.drawLine(Offset(w * 0.40, h * 0.24), Offset(w * 0.62, h * 0.51), Paint()..color = const Color(0xFFFFC928)..strokeWidth = 6..strokeCap = StrokeCap.round);
    final bag = RRect.fromRectAndRadius(Rect.fromLTWH(w * 0.21, h * 0.43, 36, 38), const Radius.circular(8));
    canvas.drawRRect(bag, Paint()..color = const Color(0xFFFFC928));
    canvas.drawRRect(bag, Paint()..color = const Color(0xFF6D4C00)..style = PaintingStyle.stroke..strokeWidth = 2);
    canvas.drawCircle(Offset(w * 0.50, h * 0.18), 18, Paint()..color = const Color(0xFFFFC590));
    final cap = Path()
      ..moveTo(w * 0.32, h * 0.15)
      ..quadraticBezierTo(w * 0.50, h * 0.00, w * 0.68, h * 0.15)
      ..quadraticBezierTo(w * 0.50, h * 0.11, w * 0.32, h * 0.15)
      ..close();
    canvas.drawPath(cap, Paint()..color = const Color(0xFFFDF9ED));
    canvas.drawPath(cap, Paint()..color = const Color(0xFFD71920)..style = PaintingStyle.stroke..strokeWidth = 3);
  }

  void _drawWheel(Canvas canvas, Offset c, double r, {required bool vertical}) {
    canvas.save();
    if (vertical) {
      canvas.translate(c.dx, c.dy);
      canvas.scale(0.40, 1.0);
      canvas.translate(-c.dx, -c.dy);
    }
    canvas.drawCircle(c, r, Paint()..color = const Color(0xFF0B0B0B));
    canvas.drawCircle(c, r * 0.75, Paint()..color = const Color(0xFF616161));
    canvas.drawCircle(c, r * 0.55, Paint()..color = const Color(0xFFE0E0E0));
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _RouteCard extends StatelessWidget {
  final VoidCallback onEasy;
  final VoidCallback onMedium;
  final VoidCallback onHard;
  final VoidCallback onStore;

  const _RouteCard({
    required this.onEasy,
    required this.onMedium,
    required this.onHard,
    required this.onStore,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xEE15202A),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: const Color(0xFFFFC928), width: 2),
        boxShadow: const [BoxShadow(color: Colors.black54, blurRadius: 12)],
      ),
      child: Column(
        children: [
          Text(
            'CHOOSE ROUTE',
            style: GoogleFonts.pressStart2p(
              fontSize: 12,
              color: Colors.white,
              letterSpacing: 1.5,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(child: _RouteButton(label: 'EASY', color: const Color(0xFF43A047), onTap: onEasy)),
              const SizedBox(width: 8),
              Expanded(child: _RouteButton(label: 'MED', color: const Color(0xFFFB8C00), onTap: onMedium)),
              const SizedBox(width: 8),
              Expanded(child: _RouteButton(label: 'HARD', color: const Color(0xFFE53935), onTap: onHard)),
            ],
          ),
          const SizedBox(height: 10),
          GestureDetector(
            onTap: onStore,
            child: Container(
              height: 44,
              decoration: BoxDecoration(
                color: const Color(0xFF0A1922),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: const Color(0xFFFFC928), width: 1.5),
              ),
              child: Center(
                child: Text(
                  'STORE  •  UPGRADES',
                  style: GoogleFonts.pressStart2p(
                    fontSize: 10,
                    color: const Color(0xFFFFC928),
                    letterSpacing: 1.0,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _RouteButton extends StatelessWidget {
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _RouteButton({required this.label, required this.color, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 50,
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(15),
          boxShadow: [BoxShadow(color: color.withValues(alpha: 0.45), blurRadius: 10)],
        ),
        child: Center(
          child: Text(
            label,
            style: GoogleFonts.pressStart2p(
              fontSize: 11,
              color: Colors.white,
              letterSpacing: 1.0,
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
    return _StatBadge(label: 'COINS', value: coins.toString(), gold: true);
  }
}

class _StatBadge extends StatelessWidget {
  final String label;
  final String value;
  final bool gold;

  const _StatBadge({required this.label, required this.value, this.gold = false});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: gold ? const Color(0xFFFFC928) : const Color(0xE60A1922),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFFFC928), width: gold ? 0 : 1.5),
        boxShadow: const [BoxShadow(color: Colors.black45, blurRadius: 8)],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '$label ',
            style: GoogleFonts.pressStart2p(
              fontSize: 8,
              color: gold ? const Color(0xFF15202A) : const Color(0xFFFFC928),
            ),
          ),
          Text(
            value,
            style: GoogleFonts.pressStart2p(
              fontSize: 11,
              color: gold ? const Color(0xFF15202A) : Colors.white,
            ),
          ),
        ],
      ),
    );
  }
}
