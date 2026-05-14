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
      duration: const Duration(seconds: 7),
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
    ).then((_) => _refresh());
  }

  void _onStore() {
    Navigator.of(context).pushNamed('/store').then((_) => _refresh());
  }

  void _refresh() {
    if (!mounted) return;
    setState(() {
      _coins = StoreService.instance.coins;
    });
    ScoreService.instance.getHighScore().then((hs) {
      if (!mounted) return;
      setState(() => _highScore = hs);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF101218),
      body: Stack(
        fit: StackFit.expand,
        children: [
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            top: MediaQuery.of(context).size.height * 0.45,
            child: AnimatedBuilder(
              animation: _scrollController,
              builder: (context, _) => CustomPaint(
                painter: _RoadScrollPainter(_scrollController.value),
              ),
            ),
          ),
          Positioned(
            left: 0,
            right: 0,
            top: MediaQuery.of(context).size.height * 0.45,
            child: Container(
              height: 24,
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Color(0xFF101218), Color(0x00101218)],
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
                  const Spacer(flex: 3),
                  Text(
                    'DELIVERY DASH',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.pressStart2p(
                      fontSize: 26,
                      color: const Color(0xFFFFD54F),
                      shadows: const [
                        Shadow(
                          color: Colors.black,
                          blurRadius: 10,
                          offset: Offset(3, 4),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),
                  Text(
                    'PAPER  RUN',
                    style: GoogleFonts.pressStart2p(
                      fontSize: 12,
                      color: Colors.white,
                      letterSpacing: 4,
                    ),
                  ),
                  const Spacer(flex: 2),
                  _DifficultySelector(
                    selected: _difficulty,
                    onChange: (d) => setState(() => _difficulty = d),
                  ),
                  const SizedBox(height: 26),
                  _BigButton(
                    label: 'PLAY',
                    color: const Color(0xFF43A047),
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
                    height: 46,
                    fontSize: 13,
                  ),
                  const Spacer(flex: 3),
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 18, vertical: 8),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.55),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.white24, width: 1),
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
    );
  }
}

class _TopBar extends StatelessWidget {
  final int coins;
  const _TopBar({required this.coins});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
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
              startDay: DifficultyConfig.startDayFor(d),
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
  final int startDay;
  final Color color;
  final bool selected;
  final VoidCallback onTap;

  const _DifficultyButton({
    required this.label,
    required this.startDay,
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
                    color: color.withValues(alpha: 0.5),
                    blurRadius: 12,
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
              'START D$startDay',
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
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              color,
              Color.lerp(color, Colors.black, 0.35)!,
            ],
          ),
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

class _RoadScrollPainter extends CustomPainter {
  final double progress;

  _RoadScrollPainter(this.progress);

  static final _roadPaint = Paint()..color = const Color(0xFF2D2D33);
  static final _sidewalkPaint = Paint()..color = const Color(0xFF5A8A47);
  static final _sidewalkBandPaint = Paint()..color = const Color(0xFF4A7438);
  static final _curbPaint = Paint()..color = const Color(0xFFE8E8E8);
  static final _edgePaint = Paint()..color = const Color(0xFF3D5C30);
  static final _linePaint = Paint()
    ..color = const Color(0xFFFFC107)
    ..strokeWidth = 4
    ..strokeCap = StrokeCap.square;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final sidewalk = w * 0.20;
    final roadLeft = sidewalk;
    final roadRight = w - sidewalk;
    final laneWidth = (roadRight - roadLeft) / 3;

    canvas.drawRect(Rect.fromLTWH(0, 0, sidewalk, h), _sidewalkPaint);
    canvas.drawRect(
        Rect.fromLTWH(roadRight, 0, sidewalk, h), _sidewalkPaint);

    const bandSpacing = 60.0;
    var by = -(bandSpacing) + (progress * bandSpacing);
    while (by < h) {
      canvas.drawRect(
          Rect.fromLTWH(0, by, sidewalk, 4), _sidewalkBandPaint);
      canvas.drawRect(
          Rect.fromLTWH(roadRight, by, sidewalk, 4), _sidewalkBandPaint);
      by += bandSpacing;
    }

    canvas.drawRect(Rect.fromLTWH(roadLeft - 6, 0, 6, h), _edgePaint);
    canvas.drawRect(Rect.fromLTWH(roadRight, 0, 6, h), _edgePaint);
    canvas.drawRect(Rect.fromLTWH(roadLeft - 2, 0, 2, h), _curbPaint);
    canvas.drawRect(Rect.fromLTWH(roadRight + 4, 0, 2, h), _curbPaint);

    canvas.drawRect(Rect.fromLTWH(roadLeft, 0, roadRight - roadLeft, h),
        _roadPaint);

    const cycle = 64.0;
    const dashLen = 36.0;
    final scroll = progress * cycle;
    for (int lane = 1; lane < 3; lane++) {
      final x = roadLeft + lane * laneWidth;
      var y = -cycle + scroll;
      while (y < h) {
        canvas.drawLine(Offset(x, y), Offset(x, y + dashLen), _linePaint);
        y += cycle;
      }
    }

    final houseScroll = progress * h;
    for (int i = 0; i < 5; i++) {
      final cycleH = h + 110;
      final baseY = (i * (cycleH / 4) + houseScroll) % cycleH - 100;
      final houseSize = sidewalk * 0.7;
      final inset = (sidewalk - houseSize) / 2;
      _drawHouse(canvas, inset, baseY, houseSize,
          i.isEven ? const Color(0xFFE53935) : const Color(0xFF1E88E5));
      _drawHouse(canvas, w - sidewalk + inset, baseY + cycleH * 0.5 / 4,
          houseSize,
          i.isEven ? const Color(0xFF1E88E5) : const Color(0xFFE53935));
    }
  }

  void _drawHouse(Canvas canvas, double x, double y, double s, Color roof) {
    final body = Paint()..color = const Color(0xFFEFEBE9);
    final roofPaint = Paint()..color = roof;
    final door = Paint()..color = const Color(0xFF5D4037);

    canvas.drawRect(
        Rect.fromLTWH(x, y + s * 0.35, s, s * 0.65), body);
    final roofPath = Path()
      ..moveTo(x - 4, y + s * 0.35)
      ..lineTo(x + s / 2, y)
      ..lineTo(x + s + 4, y + s * 0.35)
      ..close();
    canvas.drawPath(roofPath, roofPaint);
    canvas.drawRect(
        Rect.fromLTWH(x + s * 0.4, y + s * 0.7, s * 0.2, s * 0.3), door);
  }

  @override
  bool shouldRepaint(_RoadScrollPainter old) => old.progress != progress;
}
