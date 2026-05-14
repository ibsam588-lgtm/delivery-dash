import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../game/delivery_dash_game.dart';
import '../game/difficulty.dart';
import '../services/store_service.dart';

class GameScreen extends StatefulWidget {
  const GameScreen({super.key});

  @override
  State<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen> {
  DeliveryDashGame? _game;

  Offset? _panStart;
  bool _panIsDrag = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_game != null) return;

    final arg = ModalRoute.of(context)?.settings.arguments;
    final difficulty = arg is Difficulty ? arg : Difficulty.medium;

    final store = StoreService.instance;
    final config = GameConfig(
      difficulty: difficulty,
      hasShield: store.shieldOwned,
      speedBoostStart: store.speedBoostOwned,
      doubleCoins: store.doubleCoinsOwned,
      paperBlitz: store.paperBlitzOwned,
      vipSkin: store.vipSkinOwned,
    );

    _game = DeliveryDashGame(config: config)
      ..onGameOver = (score, highScore, isNewRecord, coinsEarned, bestCombo,
          reachedLevel) {
        if (!mounted) return;
        Navigator.of(context).pushReplacementNamed(
          '/gameover',
          arguments: {
            'score': score,
            'highScore': highScore,
            'isNewRecord': isNewRecord,
            'coinsEarned': coinsEarned,
            'bestCombo': bestCombo,
            'reachedLevel': reachedLevel,
            'difficulty': difficulty,
          },
        );
      };
  }

  void _onPanStart(DragStartDetails d) {
    _panStart = d.localPosition;
    _panIsDrag = false;
  }

  void _onPanUpdate(DragUpdateDetails d) {
    if (_panStart == null) return;
    final dist = (d.localPosition - _panStart!).distance;
    if (dist > 14) _panIsDrag = true;
  }

  void _onPanEnd(DragEndDetails d) {
    if (_panStart == null || _game == null) return;
    if (_panIsDrag) {
      final vx = d.velocity.pixelsPerSecond.dx;
      if (vx < -180) {
        _game!.onSwipeLeft();
      } else if (vx > 180) {
        _game!.onSwipeRight();
      }
    } else {
      _game!.onTap();
    }
    _panStart = null;
    _panIsDrag = false;
  }

  @override
  Widget build(BuildContext context) {
    final game = _game;
    if (game == null) {
      return const Scaffold(
        backgroundColor: Colors.black,
        body: Center(child: CircularProgressIndicator()),
      );
    }
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          GestureDetector(
            onPanStart: _onPanStart,
            onPanUpdate: _onPanUpdate,
            onPanEnd: _onPanEnd,
            child: GameWidget(
              game: game,
              overlayBuilderMap: {
                'Tutorial': (ctx, g) => const _TutorialOverlay(),
                'LevelUp': (ctx, g) =>
                    _LevelUpOverlay(level: (g as DeliveryDashGame).level),
              },
            ),
          ),
          Positioned(
            right: 22,
            bottom: 110,
            child: ValueListenableBuilder<int>(
              valueListenable: game.paperCountNotifier,
              builder: (ctx, count, _) => _ThrowFab(
                count: count,
                max: DeliveryDashGame.maxPapers,
                onTap: game.onThrowTapped,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ThrowFab extends StatefulWidget {
  final int count;
  final int max;
  final VoidCallback onTap;

  const _ThrowFab({
    required this.count,
    required this.max,
    required this.onTap,
  });

  @override
  State<_ThrowFab> createState() => _ThrowFabState();
}

class _ThrowFabState extends State<_ThrowFab>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulseCtrl;
  late final Animation<double> _pulse;

  @override
  void initState() {
    super.initState();
    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _pulse = Tween<double>(begin: 1.0, end: 1.05).animate(
      CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeInOut),
    );
    if (widget.count > 0) {
      _pulseCtrl.repeat(reverse: true);
    }
  }

  @override
  void didUpdateWidget(covariant _ThrowFab old) {
    super.didUpdateWidget(old);
    if (widget.count > 0 && !_pulseCtrl.isAnimating) {
      _pulseCtrl.repeat(reverse: true);
    } else if (widget.count <= 0 && _pulseCtrl.isAnimating) {
      _pulseCtrl.stop();
      _pulseCtrl.value = 0;
    }
  }

  @override
  void dispose() {
    _pulseCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final enabled = widget.count > 0;
    return GestureDetector(
      onTap: enabled ? widget.onTap : null,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          AnimatedBuilder(
            animation: _pulse,
            builder: (context, child) => Transform.scale(
              scale: enabled ? _pulse.value : 1.0,
              child: child,
            ),
            child: Container(
              width: 76,
              height: 76,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: enabled
                      ? const [Color(0xFFFF8A65), Color(0xFFE64A19)]
                      : const [Color(0xFF424242), Color(0xFF212121)],
                ),
                border: Border.all(color: Colors.white, width: 3),
                boxShadow: const [
                  BoxShadow(
                    color: Colors.black54,
                    blurRadius: 10,
                    offset: Offset(0, 4),
                  ),
                ],
              ),
              child: Center(
                child: Text(
                  'THROW',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.pressStart2p(
                    fontSize: 9,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
          ),
          Positioned(
            right: -4,
            top: -6,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: const Color(0xFF101218),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.white70, width: 1.5),
              ),
              child: Text(
                '${widget.count}/${widget.max}',
                style: GoogleFonts.pressStart2p(
                  fontSize: 9,
                  color: enabled ? const Color(0xFFFFD54F) : Colors.white54,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _TutorialOverlay extends StatelessWidget {
  const _TutorialOverlay();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 40),
        padding: const EdgeInsets.all(22),
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.82),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFFFC107), width: 2),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              '← SWIPE →',
              style: GoogleFonts.pressStart2p(
                color: Colors.white,
                fontSize: 16,
              ),
            ),
            const SizedBox(height: 6),
            const Text('change lanes',
                style: TextStyle(color: Colors.white70, fontSize: 13)),
            const SizedBox(height: 16),
            Text(
              'TAP THROW',
              style: GoogleFonts.pressStart2p(
                color: const Color(0xFFFF8A65),
                fontSize: 16,
              ),
            ),
            const SizedBox(height: 6),
            const Text('toss paper at mailboxes',
                style: TextStyle(color: Colors.white70, fontSize: 13)),
            const SizedBox(height: 16),
            const Text('BLUE +10  •  RED +25  •  avoid cars!',
                style:
                    TextStyle(color: Color(0xFF90CAF9), fontSize: 12)),
          ],
        ),
      ),
    );
  }
}

class _LevelUpOverlay extends StatelessWidget {
  final int level;
  const _LevelUpOverlay({required this.level});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 36, vertical: 22),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFFFFA000), Color(0xFFE65100)],
          ),
          borderRadius: BorderRadius.circular(14),
          boxShadow: const [
            BoxShadow(color: Colors.black87, blurRadius: 18),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'LEVEL UP!',
              style: GoogleFonts.pressStart2p(
                fontSize: 22,
                color: Colors.white,
                shadows: const [Shadow(color: Colors.black, blurRadius: 6)],
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'LV $level',
              style: GoogleFonts.pressStart2p(
                fontSize: 28,
                color: const Color(0xFFFFF59D),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
