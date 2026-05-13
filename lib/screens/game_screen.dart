import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import '../game/delivery_dash_game.dart';

class GameScreen extends StatefulWidget {
  const GameScreen({super.key});

  @override
  State<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen> {
  late final DeliveryDashGame _game;

  Offset? _panStart;
  bool _panIsDrag = false;

  @override
  void initState() {
    super.initState();
    _game = DeliveryDashGame();
    _game.onGameOver = (score, highScore, isNewRecord) {
      if (!mounted) return;
      Navigator.of(context).pushReplacementNamed(
        '/gameover',
        arguments: {
          'score': score,
          'highScore': highScore,
          'isNewRecord': isNewRecord,
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
    if (_panStart == null) return;
    if (_panIsDrag) {
      final vx = d.velocity.pixelsPerSecond.dx;
      if (vx < -180) {
        _game.onSwipeLeft();
      } else if (vx > 180) {
        _game.onSwipeRight();
      }
    } else {
      _game.onTap();
    }
    _panStart = null;
    _panIsDrag = false;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: GestureDetector(
        onPanStart: _onPanStart,
        onPanUpdate: _onPanUpdate,
        onPanEnd: _onPanEnd,
        child: GameWidget(
          game: _game,
          overlayBuilderMap: {
            'Tutorial': (ctx, game) => const _TutorialOverlay(),
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
          color: Colors.black.withValues(alpha: 0.75),
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
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(height: 6),
            Text(
              'change lanes',
              style: TextStyle(color: Colors.white70, fontSize: 14),
            ),
            SizedBox(height: 16),
            Text(
              'TAP',
              style: TextStyle(
                color: Colors.orangeAccent,
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(height: 6),
            Text(
              'throw newspaper',
              style: TextStyle(color: Colors.white70, fontSize: 14),
            ),
            SizedBox(height: 16),
            Text(
              'Hit BLUE mailboxes!',
              style: TextStyle(color: Colors.lightBlueAccent, fontSize: 16),
            ),
          ],
        ),
      ),
    );
  }
}
