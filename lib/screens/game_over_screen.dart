import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../game/difficulty.dart';
import '../services/ad_service.dart';

class GameOverScreen extends StatelessWidget {
  const GameOverScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final args =
        ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;
    final score = args?['score'] as int? ?? 0;
    final highScore = args?['highScore'] as int? ?? 0;
    final isNewRecord = args?['isNewRecord'] as bool? ?? false;
    final coinsEarned = args?['coinsEarned'] as int? ?? 0;
    final bestCombo = args?['bestCombo'] as int? ?? 0;
    final reachedLevel = args?['reachedLevel'] as int? ?? 1;
    final difficulty = args?['difficulty'] as Difficulty? ?? Difficulty.medium;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        Navigator.of(context).pushNamedAndRemoveUntil('/', (r) => false);
      },
      child: Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF101218), Color(0xFF1A1A26)],
          ),
        ),
        child: SafeArea(
          child: Stack(
            children: [
              SingleChildScrollView(
                padding: const EdgeInsets.only(bottom: 80),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    const SizedBox(height: 28),
                    Text(
                      'GAME',
                      style: GoogleFonts.pressStart2p(
                        fontSize: 30,
                        color: const Color(0xFFE53935),
                        shadows: const [
                          Shadow(color: Colors.black, blurRadius: 8),
                        ],
                      ),
                    ),
                    Text(
                      'OVER',
                      style: GoogleFonts.pressStart2p(
                        fontSize: 30,
                        color: const Color(0xFFE53935),
                        shadows: const [
                          Shadow(color: Colors.black, blurRadius: 8),
                        ],
                      ),
                    ),
                    const SizedBox(height: 18),
                    if (isNewRecord) ...[
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 6),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFFD54F).withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: const Color(0xFFFFD54F)),
                        ),
                        child: Text(
                          '★ NEW RECORD ★',
                          style: GoogleFonts.pressStart2p(
                            fontSize: 12,
                            color: const Color(0xFFFFD54F),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],
                    _ScoreBox(label: 'SCORE', value: '$score', color: Colors.white),
                    const SizedBox(height: 10),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        _ScoreBox(
                          label: 'BEST',
                          value: '$highScore',
                          color: const Color(0xFFFFD54F),
                          compact: true,
                        ),
                        const SizedBox(width: 10),
                        _ScoreBox(
                          label: 'LEVEL',
                          value: '$reachedLevel',
                          color: const Color(0xFF90CAF9),
                          compact: true,
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        _ScoreBox(
                          label: '🪙 COINS',
                          value: '$coinsEarned',
                          color: const Color(0xFFFFD54F),
                          compact: true,
                        ),
                        const SizedBox(width: 10),
                        _ScoreBox(
                          label: 'COMBO',
                          value: '$bestCombo',
                          color: const Color(0xFFFF8A65),
                          compact: true,
                        ),
                      ],
                    ),
                    const SizedBox(height: 28),
                    _MenuButton(
                      label: 'PLAY AGAIN',
                      color: const Color(0xFF43A047),
                      onTap: () => Navigator.of(context).pushReplacementNamed(
                        '/game',
                        arguments: difficulty,
                      ),
                    ),
                    const SizedBox(height: 14),
                    _MenuButton(
                      label: 'MENU',
                      color: const Color(0xFF455A64),
                      onTap: () => Navigator.of(context)
                          .pushNamedAndRemoveUntil('/', (r) => false),
                    ),
                  ],
                ),
              ),
              Align(
                alignment: Alignment.bottomCenter,
                child: AdService.instance.bannerAd(),
              ),
            ],
          ),
        ),
      ),
      ),
    );
  }
}

class _ScoreBox extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  final bool compact;

  const _ScoreBox({
    required this.label,
    required this.value,
    required this.color,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 18 : 32,
        vertical: compact ? 10 : 14,
      ),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white12),
      ),
      child: Column(
        children: [
          Text(
            label,
            style: GoogleFonts.pressStart2p(
              fontSize: compact ? 9 : 11,
              color: Colors.white60,
            ),
          ),
          SizedBox(height: compact ? 4 : 6),
          Text(
            value,
            style: GoogleFonts.pressStart2p(
              fontSize: compact ? 16 : 22,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

class _MenuButton extends StatelessWidget {
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _MenuButton({
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 220,
        height: 54,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [color, Color.lerp(color, Colors.black, 0.35)!],
          ),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.white24, width: 1.5),
          boxShadow: const [
            BoxShadow(
                color: Colors.black54, blurRadius: 8, offset: Offset(0, 4)),
          ],
        ),
        child: Center(
          child: Text(
            label,
            style: GoogleFonts.pressStart2p(
                fontSize: 14, color: Colors.white),
          ),
        ),
      ),
    );
  }
}
