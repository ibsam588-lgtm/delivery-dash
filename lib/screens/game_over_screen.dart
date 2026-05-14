import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../game/difficulty.dart';
import '../services/ad_service.dart';

class GameOverScreen extends StatefulWidget {
  const GameOverScreen({super.key});

  @override
  State<GameOverScreen> createState() => _GameOverScreenState();
}

class _GameOverScreenState extends State<GameOverScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _countCtrl;
  Animation<int> _scoreAnim = const AlwaysStoppedAnimation(0);

  int _score = 0;
  int _highScore = 0;
  bool _isNewRecord = false;
  int _coinsEarned = 0;
  int _bestCombo = 0;
  int _reachedLevel = 1;
  Difficulty _difficulty = Difficulty.medium;
  bool _argsLoaded = false;

  @override
  void initState() {
    super.initState();
    _countCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_argsLoaded) return;
    _argsLoaded = true;
    final args =
        ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;
    _score = args?['score'] as int? ?? 0;
    _highScore = args?['highScore'] as int? ?? 0;
    _isNewRecord = args?['isNewRecord'] as bool? ?? false;
    _coinsEarned = args?['coinsEarned'] as int? ?? 0;
    _bestCombo = args?['bestCombo'] as int? ?? 0;
    _reachedLevel = args?['reachedLevel'] as int? ?? 1;
    _difficulty =
        args?['difficulty'] as Difficulty? ?? Difficulty.medium;

    _scoreAnim = IntTween(begin: 0, end: _score).animate(
      CurvedAnimation(parent: _countCtrl, curve: Curves.easeOutCubic),
    );
    _countCtrl.forward();
  }

  @override
  void dispose() {
    _countCtrl.dispose();
    super.dispose();
  }

  void _playAgain() => Navigator.of(context).pushReplacementNamed(
        '/game',
        arguments: _difficulty,
      );

  void _menu() =>
      Navigator.of(context).pushNamedAndRemoveUntil('/', (r) => false);

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        _menu();
      },
      child: Scaffold(
        backgroundColor: const Color(0xFF0D0D0D),
        body: Stack(
          fit: StackFit.expand,
          children: [
            // Full-screen 90% black overlay vibe.
            const DecoratedBox(
              decoration: BoxDecoration(color: Color(0xE60D0D0D)),
            ),
            SafeArea(
              child: Padding(
                padding: const EdgeInsets.only(bottom: 70),
                child: Center(
                  child: SingleChildScrollView(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 22),
                      child: _Card(
                        score: _score,
                        scoreAnim: _scoreAnim,
                        highScore: _highScore,
                        isNewRecord: _isNewRecord,
                        coinsEarned: _coinsEarned,
                        bestCombo: _bestCombo,
                        reachedLevel: _reachedLevel,
                        onPlayAgain: _playAgain,
                        onMenu: _menu,
                      ),
                    ),
                  ),
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
    );
  }
}

class _Card extends StatelessWidget {
  final int score;
  final Animation<int> scoreAnim;
  final int highScore;
  final bool isNewRecord;
  final int coinsEarned;
  final int bestCombo;
  final int reachedLevel;
  final VoidCallback onPlayAgain;
  final VoidCallback onMenu;

  const _Card({
    required this.score,
    required this.scoreAnim,
    required this.highScore,
    required this.isNewRecord,
    required this.coinsEarned,
    required this.bestCombo,
    required this.reachedLevel,
    required this.onPlayAgain,
    required this.onMenu,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 28),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A2E),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white12, width: 1),
        boxShadow: const [
          BoxShadow(
            color: Colors.black87,
            blurRadius: 32,
            offset: Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'GAME OVER',
            style: GoogleFonts.pressStart2p(
              fontSize: 20,
              color: const Color(0xFFFF1744),
              letterSpacing: 3,
              shadows: const [Shadow(color: Colors.black, blurRadius: 8)],
            ),
          ),
          const SizedBox(height: 8),
          Container(
            height: 2,
            margin: const EdgeInsets.symmetric(horizontal: 30),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [
                  Color(0x00FF1744),
                  Color(0xFFFF1744),
                  Color(0x00FF1744),
                ],
              ),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 26),
          AnimatedBuilder(
            animation: scoreAnim,
            builder: (context, _) => Text(
              '${scoreAnim.value}',
              style: GoogleFonts.pressStart2p(
                fontSize: 44,
                color: Colors.white,
                letterSpacing: -0.5,
                shadows: const [Shadow(color: Colors.black, blurRadius: 6)],
              ),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'SCORE',
            style: GoogleFonts.pressStart2p(
              fontSize: 9,
              color: Colors.white54,
              letterSpacing: 2,
            ),
          ),
          if (isNewRecord) ...[
            const SizedBox(height: 12),
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
              decoration: BoxDecoration(
                color: const Color(0xFFFFD600).withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(12),
                border:
                    Border.all(color: const Color(0xFFFFD600), width: 1),
              ),
              child: Text(
                '★ NEW RECORD ★',
                style: GoogleFonts.pressStart2p(
                  fontSize: 10,
                  color: const Color(0xFFFFD600),
                ),
              ),
            ),
          ],
          const SizedBox(height: 24),
          Row(
            children: [
              Expanded(
                child: _Stat(
                  label: 'LEVEL',
                  value: '$reachedLevel',
                  color: const Color(0xFF90CAF9),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _Stat(
                  label: 'BEST',
                  value: '$highScore',
                  color: const Color(0xFFFFD600),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _Stat(
                  label: 'COINS',
                  value: '🪙 $coinsEarned',
                  color: const Color(0xFFFFD600),
                ),
              ),
            ],
          ),
          if (bestCombo >= 3) ...[
            const SizedBox(height: 10),
            _Stat(
              label: 'BEST COMBO',
              value: '$bestCombo',
              color: const Color(0xFF00E676),
            ),
          ],
          const SizedBox(height: 28),
          _PrimaryBtn(label: 'PLAY AGAIN', onTap: onPlayAgain),
          const SizedBox(height: 12),
          _OutlineBtn(label: 'MENU', onTap: onMenu),
        ],
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  const _Stat({
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white12, width: 1),
      ),
      child: Column(
        children: [
          Text(
            label,
            style: GoogleFonts.pressStart2p(
              fontSize: 8,
              color: Colors.white54,
              letterSpacing: 1.4,
            ),
          ),
          const SizedBox(height: 6),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              value,
              style: GoogleFonts.pressStart2p(
                fontSize: 14,
                color: color,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PrimaryBtn extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  const _PrimaryBtn({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        height: 58,
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFF00E676), Color(0xFF00C853)],
          ),
          borderRadius: BorderRadius.circular(29),
          boxShadow: const [
            BoxShadow(
              color: Color(0x6600E676),
              blurRadius: 20,
              offset: Offset(0, 6),
            ),
          ],
        ),
        child: Center(
          child: Text(
            label,
            style: GoogleFonts.pressStart2p(
              fontSize: 14,
              color: Colors.white,
              letterSpacing: 2,
            ),
          ),
        ),
      ),
    );
  }
}

class _OutlineBtn extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  const _OutlineBtn({required this.label, required this.onTap});

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
            label,
            style: GoogleFonts.pressStart2p(
              fontSize: 12,
              color: const Color(0xFF00E676),
              letterSpacing: 2,
            ),
          ),
        ),
      ),
    );
  }
}
