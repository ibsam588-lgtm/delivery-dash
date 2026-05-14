import 'package:flame/game.dart';
import 'package:flutter/material.dart';
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
    final difficulty =
        arg is Difficulty ? arg : Difficulty.medium;

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
      ..onGameOver = (score, highScore, isNewRecord, coinsEarned) {
        if (!mounted) return;
        Navigator.of(context).pushReplacementNamed(
          '/gameover',
          arguments: {
            'score': score,
            'highScore': highScore,
            'isNewRecord': isNewRecord,
            'coinsEarned': coinsEarned,
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
      body: GestureDetector(
        onPanStart: _onPanStart,
        onPanUpdate: _onPanUpdate,
        onPanEnd: _onPanEnd,
        child: GameWidget(
          game: game,
          overlayBuilderMap: {
            'Tutorial': (ctx, g) => const _TutorialOverlay(),
          },
        ),
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
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.78),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.orangeAccent, width: 2),
        ),
        child: const Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              '← SWIPE →',
              style: TextStyle(
                color: Colors.white,
                fontSize: 22,
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(height: 4),
            Text('change lanes',
                style: TextStyle(color: Colors.white70, fontSize: 13)),
            SizedBox(height: 14),
            Text(
              'TAP',
              style: TextStyle(
                color: Colors.orangeAccent,
                fontSize: 22,
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(height: 4),
            Text('throw newspaper',
                style: TextStyle(color: Colors.white70, fontSize: 13)),
            SizedBox(height: 14),
            Text(
              'BLUE = deliver  •  RED = avoid',
              style: TextStyle(color: Colors.lightBlueAccent, fontSize: 13),
            ),
          ],
        ),
      ),
    );
  }
}
