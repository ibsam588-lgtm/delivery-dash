import 'dart:math';
import 'package:flame/components.dart';
import '../delivery_dash_game.dart';
import '../components/obstacle.dart';
import '../components/mailbox.dart';

class Spawner extends Component with HasGameRef<DeliveryDashGame> {
  double _obstacleTimer = 0;
  double _mailboxTimer = 0;
  final Random _rng = Random();

  static const List<ObstacleType> _types = ObstacleType.values;

  double get _obstacleInterval => (2.2 / gameRef.speedMultiplier).clamp(0.6, 2.2);
  double get _mailboxInterval => (1.8 / gameRef.speedMultiplier).clamp(0.9, 1.8);

  @override
  void update(double dt) {
    super.update(dt);
    if (gameRef.state != GameState.playing) return;

    _obstacleTimer += dt;
    _mailboxTimer += dt;

    if (_obstacleTimer >= _obstacleInterval) {
      _obstacleTimer = 0;
      _spawnObstacle();
    }

    if (_mailboxTimer >= _mailboxInterval) {
      _mailboxTimer = 0;
      _spawnMailbox();
    }
  }

  void _spawnObstacle() {
    final lane = _rng.nextInt(3);
    final type = _types[_rng.nextInt(_types.length)];
    gameRef.add(ObstacleComponent(type: type, lane: lane));
  }

  void _spawnMailbox() {
    final lane = _rng.nextInt(3);
    // Red mailbox chance grows with speed (max 40% at top speed)
    final redChance = ((gameRef.speedMultiplier - 1.0) * 0.2).clamp(0.0, 0.4);
    final isBlue = _rng.nextDouble() > redChance;
    final onLeft = _rng.nextBool();
    gameRef.add(MailboxComponent(isBlue: isBlue, lane: lane, onLeft: onLeft));
  }
}
