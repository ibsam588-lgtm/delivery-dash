import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class GameOverScreen extends StatelessWidget {
  const GameOverScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final args = ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;
    final score = args?['score'] as int? ?? 0;
    final highScore = args?['highScore'] as int? ?? 0;
    final isNewRecord = args?['isNewRecord'] as bool? ?? false;

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF1A237E), Color(0xFF283593)],
          ),
        ),
        child: SafeArea(
          child: Center(
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
                const SizedBox(height: 40),
                if (isNewRecord) ...[
                  Text(
                    '★ NEW RECORD! ★',
                    style: GoogleFonts.pressStart2p(
                      fontSize: 14,
                      color: Colors.yellowAccent,
                    ),
                  ),
                  const SizedBox(height: 12),
                ],
                _ScoreBox(label: 'SCORE', value: score, color: Colors.white),
                const SizedBox(height: 12),
                _ScoreBox(label: 'BEST', value: highScore, color: Colors.yellowAccent),
                const SizedBox(height: 48),
                _MenuButton(
                  label: 'PLAY AGAIN',
                  color: const Color(0xFFFF6F00),
                  onTap: () => Navigator.of(context)
                      .pushReplacementNamed('/game'),
                ),
                const SizedBox(height: 16),
                _MenuButton(
                  label: 'MENU',
                  color: const Color(0xFF37474F),
                  onTap: () => Navigator.of(context)
                      .pushNamedAndRemoveUntil('/', (r) => false),
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
  final int value;
  final Color color;

  const _ScoreBox({required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 14),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Text(
            label,
            style: GoogleFonts.pressStart2p(fontSize: 11, color: Colors.white60),
          ),
          const SizedBox(height: 6),
          Text(
            '$value',
            style: GoogleFonts.pressStart2p(fontSize: 26, color: color),
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

  const _MenuButton({required this.label, required this.color, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 220,
        height: 56,
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(12),
          boxShadow: const [
            BoxShadow(color: Colors.black38, blurRadius: 6, offset: Offset(0, 3)),
          ],
        ),
        child: Center(
          child: Text(
            label,
            style: GoogleFonts.pressStart2p(fontSize: 16, color: Colors.white),
          ),
        ),
      ),
    );
  }
}
