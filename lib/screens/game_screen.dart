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

  Offset? _downPos;
  DateTime? _downTime;
  bool _moved = false;

  static const double _tapMaxMovePx = 10.0;
  static const int _tapMaxDurationMs = 220;

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

  void _handlePointerDown(PointerDownEvent e) {
    _downPos = e.localPosition;
    _downTime = DateTime.now();
    _moved = false;
  }

  void _handlePointerMove(PointerMoveEvent e) {
    final start = _downPos;
    if (start == null) return;
    final dist = (e.localPosition - start).distance;
    if (dist > _tapMaxMovePx) {
      _moved = true;
      _game?.onDragMoveTo(e.localPosition.dx);
    }
  }

  void _handlePointerUp(PointerUpEvent e) {
    final start = _downPos;
    final startTime = _downTime;
    _downPos = null;
    _downTime = null;
    if (start == null || startTime == null) return;
    final dur = DateTime.now().difference(startTime).inMilliseconds;
    if (!_moved && dur <= _tapMaxDurationMs) {
      _game?.onTap();
    }
    _moved = false;
  }

  Future<bool> _confirmQuit() async {
    final game = _game;
    game?.pauseGame();
    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A2E),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: Color(0xFFFFC107), width: 1.5),
        ),
        title: Text(
          'QUIT GAME?',
          style: GoogleFonts.pressStart2p(
            color: Colors.white,
            fontSize: 14,
          ),
        ),
        content: const Text(
          'Your current run will end. Return to the main menu?',
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(
              'KEEP PLAYING',
              style: GoogleFonts.pressStart2p(
                color: const Color(0xFF66BB6A),
                fontSize: 11,
              ),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(
              'QUIT',
              style: GoogleFonts.pressStart2p(
                color: const Color(0xFFEF5350),
                fontSize: 11,
              ),
            ),
          ),
        ],
      ),
    );
    final shouldQuit = result == true;
    if (!shouldQuit) {
      game?.resumeGame();
    }
    return shouldQuit;
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
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        final navigator = Navigator.of(context);
        final shouldQuit = await _confirmQuit();
        if (!mounted) return;
        if (shouldQuit) {
          navigator.pop();
        }
      },
      child: Scaffold(
        backgroundColor: Colors.black,
        body: Listener(
          behavior: HitTestBehavior.opaque,
          onPointerDown: _handlePointerDown,
          onPointerMove: _handlePointerMove,
          onPointerUp: _handlePointerUp,
          child: GameWidget(
            game: game,
            overlayBuilderMap: {
              'Tutorial': (ctx, g) => const _TutorialOverlay(),
              'LevelUp': (ctx, g) =>
                  _LevelUpOverlay(level: (g as DeliveryDashGame).level),
            },
          ),
        ),
      ),
    );
  }
}

class _TutorialOverlay extends StatelessWidget {
  const _TutorialOverlay();

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Align(
        alignment: Alignment.bottomCenter,
        child: Padding(
          padding: const EdgeInsets.only(bottom: 28),
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 24),
            padding:
                const EdgeInsets.symmetric(horizontal: 22, vertical: 14),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.78),
              borderRadius: BorderRadius.circular(14),
              border:
                  Border.all(color: const Color(0xFFFFC107), width: 1.5),
            ),
            child: Text(
              'DRAG ← → to move   •   TAP to throw',
              textAlign: TextAlign.center,
              style: GoogleFonts.pressStart2p(
                color: Colors.white,
                fontSize: 10,
              ),
            ),
          ),
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
      child: Container(
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
              'LEVEL $level',
              style: GoogleFonts.pressStart2p(
                fontSize: 22,
                color: Colors.white,
                shadows: const [Shadow(color: Colors.black, blurRadius: 6)],
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'NEW STREET',
              style: GoogleFonts.pressStart2p(
                fontSize: 11,
                color: const Color(0xFFFFF59D),
                letterSpacing: 2,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
