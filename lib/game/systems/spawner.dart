import 'dart:math';
import 'package:flame/components.dart';
import '../components/obstacle.dart';
import '../delivery_dash_game.dart';
import '../difficulty.dart';

class Spawner extends Component with HasGameRef<DeliveryDashGame> {
  double _obstacleTimer = 0;
  final Random _rng = Random();

  double get _obstacleInterval {
    final base = gameRef.config.difficultyConfig.spawnInterval;
    final speedFactor =
        gameRef.config.difficultyConfig.startSpeed / gameRef.scrollSpeed;
    final lvlFactor = LevelConfig.spawnFactorForLevel(gameRef.level);
    return (base * speedFactor * lvlFactor).clamp(0.45, base);
  }

  @override
  void update(double dt) {
    super.update(dt);
    if (gameRef.state != GameState.playing) return;
    _obstacleTimer += dt;
    if (_obstacleTimer >= _obstacleInterval) {
      _obstacleTimer = 0;
      _spawnObstacle();
    }
  }

  void _spawnObstacle() {
    final lane = _rng.nextInt(3);
    final roll = _rng.nextDouble();
    final ObstacleType type;
    if (roll < 0.45) {
      type = ObstacleType.car;
    } else if (roll < 0.58) {
      type = ObstacleType.dog;
    } else if (roll < 0.70) {
      type = ObstacleType.worker;
    } else if (roll < 0.82) {
      type = ObstacleType.cone;
    } else if (roll < 0.92) {
      type = ObstacleType.barrier;
    } else {
      type = ObstacleType.pothole;
    }
    gameRef.add(ObstacleComponent(type: type, lane: lane));
  }
}
