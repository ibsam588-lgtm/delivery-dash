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
  late Animation<int> _scoreAnim;

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
      duration: const Duration(milliseconds: 900),
    );
    _scoreAnim = const AlwaysStoppedAnimation(0);
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

  void _playAgain() {
    Navigator.of(context).pushReplacementNamed(
      '/game',
      arguments: _difficulty,
    );
  }

  void _menu() {
    Navigator.of(context).pushNamedAndRemoveUntil('/', (r) => false);
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        _menu();
      },
      child: Scaffold(
        backgroundColor: Colors.black,
        body: Stack(
          fit: StackFit.expand,
          children: [
            // Dark overlay gradient background.
            const DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Color(0xFF101218), Color(0xFF1A1A26)],
                ),
              ),
            ),

            // Centered card.
            SafeArea(
              child: Padding(
                padding: const EdgeInsets.only(bottom: 70),
                child: Center(
                  child: SingleChildScrollView(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 28),
                      child: _GameOverCard(
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

            // Banner ad pinned to the very bottom — outside the card area
            // so it doesn't overlap the action buttons.
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

class _GameOverCard extends StatelessWidget {
  final int score;
  final Animation<int> scoreAnim;
  final int highScore;
  final bool isNewRecord;
  final int coinsEarned;
  final int bestCombo;
  final int reachedLevel;
  final VoidCallback onPlayAgain;
  final VoidCallback onMenu;

  const _GameOverCard({
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
      padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 26),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A2E),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: Colors.white12, width: 1),
        boxShadow: const [
          BoxShadow(
            color: Colors.black87,
            blurRadius: 28,
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
              fontSize: 18,
              color: const Color(0xFFEF5350),
              letterSpacing: 2,
              shadows: const [Shadow(color: Colors.black, blurRadius: 6)],
            ),
          ),
          const SizedBox(height: 18),
          Text(
            'SCORE',
            style: GoogleFonts.pressStart2p(
              fontSize: 10,
              color: Colors.white54,
              letterSpacing: 2,
            ),
          ),
          const SizedBox(height: 6),
          AnimatedBuilder(
            animation: scoreAnim,
            builder: (context, _) => Text(
              '${scoreAnim.value}',
              style: GoogleFonts.pressStart2p(
                fontSize: 38,
                color: Colors.white,
                shadows: const [Shadow(color: Colors.black, blurRadius: 6)],
              ),
            ),
          ),
          const SizedBox(height: 8),
          if (isNewRecord)
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
              decoration: BoxDecoration(
                color: const Color(0xFFFFD54F).withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(10),
                border:
                    Border.all(color: const Color(0xFFFFD54F), width: 1),
              ),
              child: Text(
                '★ NEW RECORD ★',
                style: GoogleFonts.pressStart2p(
                  fontSize: 10,
                  color: const Color(0xFFFFD54F),
                ),
              ),
            ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: _StatTile(
                  label: 'LEVEL',
                  value: '$reachedLevel',
                  color: const Color(0xFF90CAF9),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _StatTile(
                  label: 'BEST',
                  value: '$highScore',
                  color: const Color(0xFFFFD54F),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _StatTile(
                  label: 'COINS',
                  value: '$coinsEarned',
                  color: const Color(0xFFFFD54F),
                  prefix: '🪙 ',
                ),
              ),
            ],
          ),
          if (bestCombo >= 3) ...[
            const SizedBox(height: 10),
            _StatTile(
              label: 'BEST COMBO',
              value: '$bestCombo',
              color: const Color(0xFFFF8A65),
            ),
          ],
          const SizedBox(height: 24),
          _ActionButton(
            label: 'PLAY AGAIN',
            gradient: const LinearGradient(
              colors: [Color(0xFF2ECC71), Color(0xFF27AE60)],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ),
            onTap: onPlayAgain,
          ),
          const SizedBox(height: 12),
          _OutlinedAction(label: 'MENU', onTap: onMenu),
        ],
      ),
    );
  }
}

class _StatTile extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  final String prefix;

  const _StatTile({
    required this.label,
    required this.value,
    required this.color,
    this.prefix = '',
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.35),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white10, width: 1),
      ),
      child: Column(
        children: [
          Text(
            label,
            style: GoogleFonts.pressStart2p(
              fontSize: 8,
              color: Colors.white54,
              letterSpacing: 1.2,
            ),
          ),
          const SizedBox(height: 6),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              '$prefix$value',
              style: GoogleFonts.pressStart2p(
                fontSize: 16,
                color: color,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  final String label;
  final Gradient gradient;
  final VoidCallback onTap;

  const _ActionButton({
    required this.label,
    required this.gradient,
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
              fontSize: 15,
              color: Colors.white,
            ),
          ),
        ),
      ),
    );
  }
}

class _OutlinedAction extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  const _OutlinedAction({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        height: 48,
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.5),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFF90CAF9), width: 1.5),
        ),
        child: Center(
          child: Text(
            label,
            style: GoogleFonts.pressStart2p(
              fontSize: 13,
              color: const Color(0xFF90CAF9),
            ),
          ),
        ),
      ),
    );
  }
}
