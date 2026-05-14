import 'dart:math';
import 'package:flame/components.dart';
import '../components/mailbox.dart';
import '../components/obstacle.dart';
import '../delivery_dash_game.dart';

class Spawner extends Component with HasGameRef<DeliveryDashGame> {
  double _obstacleTimer = 0;
  double _mailboxTimer = 0;
  final Random _rng = Random();

  static const List<ObstacleType> _types = ObstacleType.values;

  double get _obstacleInterval {
    final base = gameRef.config.difficultyConfig.spawnInterval;
    final factor = gameRef.config.difficultyConfig.startSpeed /
        gameRef.scrollSpeed;
    return (base * factor).clamp(0.5, base);
  }

  double get _mailboxInterval => _obstacleInterval * 1.1;

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
    final speedRatio =
        gameRef.scrollSpeed / gameRef.config.difficultyConfig.startSpeed;
    final redChance = ((speedRatio - 1.0) * 0.2).clamp(0.0, 0.45);
    final isBlue = _rng.nextDouble() > redChance;
    final onLeft = _rng.nextBool();
    gameRef.add(MailboxComponent(isBlue: isBlue, onLeft: onLeft));
  }
}
