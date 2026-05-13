import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/score_service.dart';

class MainMenuScreen extends StatefulWidget {
  const MainMenuScreen({super.key});

  @override
  State<MainMenuScreen> createState() => _MainMenuScreenState();
}

class _MainMenuScreenState extends State<MainMenuScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _houseController;
  int _highScore = 0;

  @override
  void initState() {
    super.initState();
    _houseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 6),
    )..repeat();
    _loadHighScore();
  }

  Future<void> _loadHighScore() async {
    final hs = await ScoreService.instance.getHighScore();
    if (mounted) setState(() => _highScore = hs);
  }

  @override
  void dispose() {
    _houseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        fit: StackFit.expand,
        children: [
          // Animated scrolling background
          AnimatedBuilder(
            animation: _houseController,
            builder: (context, _) => CustomPaint(
              painter: _MenuBackgroundPainter(_houseController.value),
            ),
          ),
          // Content
          SafeArea(
            child: Column(
              children: [
                const Spacer(flex: 2),
                // Title
                Text(
                  'DELIVERY',
                  style: GoogleFonts.pressStart2p(
                    fontSize: 28,
                    color: Colors.white,
                    shadows: const [
                      Shadow(color: Colors.black, blurRadius: 6, offset: Offset(2, 2)),
                    ],
                  ),
                ),
                Text(
                  'DASH',
                  style: GoogleFonts.pressStart2p(
                    fontSize: 36,
                    color: Colors.orangeAccent,
                    shadows: const [
                      Shadow(color: Colors.black, blurRadius: 6, offset: Offset(2, 2)),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'PAPER RUN',
                  style: GoogleFonts.pressStart2p(
                    fontSize: 14,
                    color: Colors.white70,
                    letterSpacing: 4,
                  ),
                ),
                const Spacer(flex: 2),
                // High score
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.5),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    'BEST: $_highScore',
                    style: GoogleFonts.pressStart2p(
                      fontSize: 14,
                      color: Colors.yellowAccent,
                    ),
                  ),
                ),
                const Spacer(),
                // Play button
                GestureDetector(
                  onTap: () => Navigator.of(context).pushNamed('/game'),
                  child: Container(
                    width: 200,
                    height: 64,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFFFF6F00), Color(0xFFFFB300)],
                      ),
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: const [
                        BoxShadow(
                          color: Colors.black38,
                          blurRadius: 8,
                          offset: Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Center(
                      child: Text(
                        'PLAY',
                        style: GoogleFonts.pressStart2p(
                          fontSize: 22,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                ),
                const Spacer(flex: 3),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _MenuBackgroundPainter extends CustomPainter {
  final double progress;

  _MenuBackgroundPainter(this.progress);

  static final _skyPaint = Paint()..color = const Color(0xFF87CEEB);
  static final _grassPaint = Paint()..color = const Color(0xFF4CAF50);
  static final _roadPaint = Paint()..color = const Color(0xFF616161);
  static final _housePaints = [
    Paint()..color = const Color(0xFFD7CCC8),
    Paint()..color = const Color(0xFFBCAAA4),
    Paint()..color = const Color(0xFFA5D6A7),
    Paint()..color = const Color(0xFFFFCC80),
  ];

  @override
  void paint(Canvas canvas, Size size) {
    // Sky
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height * 0.55), _skyPaint);
    // Grass
    canvas.drawRect(
        Rect.fromLTWH(0, size.height * 0.55, size.width, size.height * 0.45), _grassPaint);
    // Road strip
    canvas.drawRect(
        Rect.fromLTWH(size.width * 0.3, 0, size.width * 0.4, size.height), _roadPaint);

    // Scrolling houses
    final totalScroll = progress * size.height * 1.4;
    for (int i = 0; i < 5; i++) {
      final baseY = i * (size.height * 0.35) - totalScroll % (size.height * 0.35 * 5);
      final paintIdx = i % 4;
      // Left house
      _drawHouse(canvas, size.width * 0.04, baseY, 80, 100, _housePaints[paintIdx]);
      // Right house
      _drawHouse(canvas, size.width * 0.76, baseY, 80, 100, _housePaints[(paintIdx + 2) % 4]);
    }
  }

  void _drawHouse(Canvas canvas, double x, double y, double w, double h, Paint paint) {
    canvas.drawRect(Rect.fromLTWH(x, y + h * 0.3, w, h * 0.7), paint);
    final roofPath = Path()
      ..moveTo(x - 4, y + h * 0.3)
      ..lineTo(x + w / 2, y)
      ..lineTo(x + w + 4, y + h * 0.3)
      ..close();
    canvas.drawPath(
      roofPath,
      Paint()..color = const Color(0xFF8D6E63),
    );
  }

  @override
  bool shouldRepaint(_MenuBackgroundPainter old) => old.progress != progress;
}
