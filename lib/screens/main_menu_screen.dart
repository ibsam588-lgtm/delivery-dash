import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../game/difficulty.dart';
import '../services/ad_service.dart';
import '../services/score_service.dart';
import '../services/store_service.dart';

class MainMenuScreen extends StatefulWidget {
  const MainMenuScreen({super.key});

  @override
  State<MainMenuScreen> createState() => _MainMenuScreenState();
}

class _MainMenuScreenState extends State<MainMenuScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _scrollController;
  int _highScore = 0;
  int _coins = 0;
  Difficulty _difficulty = Difficulty.medium;

  @override
  void initState() {
    super.initState();
    _scrollController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 8),
    )..repeat();
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
    super.dispose();
  }

  void _onPlay() {
    Navigator.of(context).pushNamed(
      '/game',
      arguments: _difficulty,
    ).then((_) => _refreshCoins());
  }

  void _onStore() {
    Navigator.of(context).pushNamed('/store').then((_) => _refreshCoins());
  }

  void _refreshCoins() {
    if (!mounted) return;
    setState(() => _coins = StoreService.instance.coins);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0E0E11),
      body: Stack(
        fit: StackFit.expand,
        children: [
          Positioned.fill(
            top: MediaQuery.of(context).size.height * 0.5,
            child: AnimatedBuilder(
              animation: _scrollController,
              builder: (context, _) => CustomPaint(
                painter: _RoadScrollPainter(_scrollController.value),
              ),
            ),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.only(bottom: 56),
              child: Column(
                children: [
                  _CoinBar(coins: _coins),
                  const Spacer(flex: 2),
                  Text(
                    'DELIVERY DASH',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.pressStart2p(
                      fontSize: 26,
                      color: const Color(0xFFFFD54F),
                      shadows: const [
                        Shadow(color: Colors.black, blurRadius: 8, offset: Offset(3, 3)),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),
                  Text(
                    'Paper Run',
                    style: GoogleFonts.pressStart2p(
                      fontSize: 13,
                      color: Colors.white,
                      letterSpacing: 3,
                    ),
                  ),
                  const Spacer(flex: 2),
                  _DifficultySelector(
                    selected: _difficulty,
                    onChange: (d) => setState(() => _difficulty = d),
                  ),
                  const SizedBox(height: 28),
                  _BigButton(
                    label: 'PLAY',
                    color: const Color(0xFF2E7D32),
                    onTap: _onPlay,
                    width: 220,
                    height: 64,
                    fontSize: 22,
                  ),
                  const SizedBox(height: 14),
                  _BigButton(
                    label: 'STORE',
                    color: const Color(0xFF455A64),
                    onTap: _onStore,
                    width: 160,
                    height: 48,
                    fontSize: 14,
                  ),
                  const Spacer(flex: 2),
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Text(
                      'BEST: $_highScore',
                      style: GoogleFonts.pressStart2p(
                        fontSize: 12,
                        color: Colors.white70,
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
    );
  }
}

class _CoinBar extends StatelessWidget {
  final int coins;
  const _CoinBar({required this.coins});

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.topRight,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(0, 12, 16, 0),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
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
  final bool selected;
  final VoidCallback onTap;

  const _DifficultyButton({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: selected
              ? const Color(0xFFFF6F00)
              : Colors.white.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: selected ? Colors.white : Colors.white24,
            width: 1.5,
          ),
        ),
        child: Text(
          label,
          style: GoogleFonts.pressStart2p(
            fontSize: 11,
            color: selected ? Colors.white : Colors.white70,
          ),
        ),
      ),
    );
  }
}

class _BigButton extends StatelessWidget {
  final String label;
  final Color color;
  final VoidCallback onTap;
  final double width;
  final double height;
  final double fontSize;

  const _BigButton({
    required this.label,
    required this.color,
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
          color: color,
          borderRadius: BorderRadius.circular(14),
          boxShadow: const [
            BoxShadow(color: Colors.black54, blurRadius: 8, offset: Offset(0, 4)),
          ],
        ),
        child: Center(
          child: Text(
            label,
            style: GoogleFonts.pressStart2p(fontSize: fontSize, color: Colors.white),
          ),
        ),
      ),
    );
  }
}

class _RoadScrollPainter extends CustomPainter {
  final double progress;

  _RoadScrollPainter(this.progress);

  static final _roadPaint = Paint()..color = const Color(0xFF1E1E1E);
  static final _sidewalkPaint = Paint()..color = const Color(0xFF5C5C5C);
  static final _linePaint = Paint()
    ..color = Colors.white
    ..strokeWidth = 4;
  static final _housePaints = [
    Paint()..color = const Color(0xFFD7CCC8),
    Paint()..color = const Color(0xFFBCAAA4),
    Paint()..color = const Color(0xFFA5D6A7),
    Paint()..color = const Color(0xFFFFCC80),
  ];

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    const sidewalk = 70.0;

    canvas.drawRect(Rect.fromLTWH(0, 0, sidewalk, h), _sidewalkPaint);
    canvas.drawRect(Rect.fromLTWH(w - sidewalk, 0, sidewalk, h), _sidewalkPaint);
    canvas.drawRect(Rect.fromLTWH(sidewalk, 0, w - 2 * sidewalk, h), _roadPaint);

    final laneWidth = (w - 2 * sidewalk) / 3;
    final scroll = progress * 60;
    for (int lane = 1; lane < 3; lane++) {
      final x = sidewalk + lane * laneWidth;
      var y = -60.0 + scroll;
      while (y < h) {
        canvas.drawLine(Offset(x, y), Offset(x, y + 30), _linePaint);
        y += 60;
      }
    }

    final houseScroll = progress * h * 1.2;
    for (int i = 0; i < 6; i++) {
      final cycleH = h + 100;
      final baseY = (i * (cycleH / 4) + houseScroll) % cycleH - 100;
      final paintIdx = i % 4;
      _drawHouse(canvas, 4, baseY, 60, 80, _housePaints[paintIdx]);
      _drawHouse(canvas, w - 64, baseY + 30, 60, 80,
          _housePaints[(paintIdx + 2) % 4]);
    }
  }

  void _drawHouse(
      Canvas canvas, double x, double y, double width, double height, Paint p) {
    canvas.drawRect(Rect.fromLTWH(x, y + height * 0.3, width, height * 0.7), p);
    final roof = Path()
      ..moveTo(x - 4, y + height * 0.3)
      ..lineTo(x + width / 2, y)
      ..lineTo(x + width + 4, y + height * 0.3)
      ..close();
    canvas.drawPath(roof, Paint()..color = const Color(0xFF8D6E63));
  }

  @override
  bool shouldRepaint(_RoadScrollPainter old) => old.progress != progress;
}
