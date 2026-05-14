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
    final difficulty = args?['difficulty'] as Difficulty? ?? Difficulty.medium;

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF0E0E11), Color(0xFF1A1A24)],
          ),
        ),
        child: SafeArea(
          child: Stack(
            children: [
              Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      'GAME',
                      style: GoogleFonts.pressStart2p(
                        fontSize: 32,
                        color: Colors.redAccent,
                        shadows: const [Shadow(color: Colors.black, blurRadius: 6)],
                      ),
                    ),
                    Text(
                      'OVER',
                      style: GoogleFonts.pressStart2p(
                        fontSize: 32,
                        color: Colors.redAccent,
                        shadows: const [Shadow(color: Colors.black, blurRadius: 6)],
                      ),
                    ),
                    const SizedBox(height: 30),
                    if (isNewRecord) ...[
                      Text(
                        '★ NEW RECORD! ★',
                        style: GoogleFonts.pressStart2p(
                          fontSize: 13,
                          color: const Color(0xFFFFD54F),
                        ),
                      ),
                      const SizedBox(height: 12),
                    ],
                    _ScoreBox(label: 'SCORE', value: score, color: Colors.white),
                    const SizedBox(height: 10),
                    _ScoreBox(
                      label: 'BEST',
                      value: highScore,
                      color: const Color(0xFFFFD54F),
                    ),
                    const SizedBox(height: 10),
                    _ScoreBox(
                      label: '🪙 COINS EARNED',
                      value: coinsEarned,
                      color: const Color(0xFFFFD54F),
                    ),
                    const SizedBox(height: 30),
                    _MenuButton(
                      label: 'PLAY AGAIN',
                      color: const Color(0xFF2E7D32),
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
    );
  }
}

class _ScoreBox extends StatelessWidget {
  final String label;
  final int value;
  final Color color;

  const _ScoreBox(
      {required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.45),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Text(
            label,
            style: GoogleFonts.pressStart2p(fontSize: 10, color: Colors.white60),
          ),
          const SizedBox(height: 6),
          Text(
            '$value',
            style: GoogleFonts.pressStart2p(fontSize: 22, color: color),
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

  const _MenuButton(
      {required this.label, required this.color, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 220,
        height: 54,
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(12),
          boxShadow: const [
            BoxShadow(color: Colors.black54, blurRadius: 8, offset: Offset(0, 4)),
          ],
        ),
        child: Center(
          child: Text(
            label,
            style: GoogleFonts.pressStart2p(fontSize: 15, color: Colors.white),
          ),
        ),
      ),
    );
  }
}
