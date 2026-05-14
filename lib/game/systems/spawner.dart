import 'dart:math';
import 'package:flame/components.dart';
import '../components/obstacle.dart';
import '../components/paper_pack.dart';
import '../delivery_dash_game.dart';
import '../difficulty.dart';

class Spawner extends Component with HasGameRef<DeliveryDashGame> {
  double _obstacleTimer = 0;
  double _packDistanceMark = 0;
  final Random _rng = Random();

  static const double paperPackDistanceInterval = 300; // meters

  double get _obstacleInterval {
    final cfg = LevelConfig.of(gameRef.level);
    final base = cfg.spawnInterval;
    final speedFactor = cfg.startSpeed / gameRef.scrollSpeed;
    return (base * speedFactor).clamp(0.4, base);
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

    // Paper packs ride along the player's distance counter so pacing
    // scales naturally with level speed.
    if (gameRef.distanceMeters - _packDistanceMark >=
        paperPackDistanceInterval) {
      _packDistanceMark = gameRef.distanceMeters;
      _spawnPaperPack();
    }
  }

  void _spawnObstacle() {
    final roll = _rng.nextDouble();
    final ObstacleType type;
    if (roll < 0.40) {
      type = ObstacleType.car;
    } else if (roll < 0.52) {
      type = ObstacleType.dog;
    } else if (roll < 0.62) {
      type = ObstacleType.worker;
    } else if (roll < 0.74) {
      type = ObstacleType.cone;
    } else if (roll < 0.84) {
      type = ObstacleType.barrier;
    } else if (roll < 0.92) {
      type = ObstacleType.pothole;
    } else {
      type = ObstacleType.hydrant;
    }

    switch (type) {
      case ObstacleType.car:
        final factor = 0.8 + _rng.nextDouble() * 0.4; // 0.8..1.2
        final overtaker = _rng.nextDouble() < 0.12;
        gameRef.add(ObstacleComponent(
          type: type,
          laneFraction: _carLaneFraction(),
          speedFactor: factor,
          isOvertaker: overtaker,
        ));
        break;
      case ObstacleType.worker:
        // Hangs out on the right sidewalk.
        gameRef.add(ObstacleComponent(
          type: type,
          laneFraction: 0.35 + _rng.nextDouble() * 0.55,
          onRightSidewalk: true,
        ));
        break;
      case ObstacleType.dog:
        // Spawns near the right edge then sweeps across.
        gameRef.add(ObstacleComponent(
          type: type,
          laneFraction: 0.85,
        ));
        break;
      case ObstacleType.hydrant:
        // Near sidewalk edges of the road.
        final f = _rng.nextBool()
            ? 0.05 + _rng.nextDouble() * 0.18
            : 0.77 + _rng.nextDouble() * 0.18;
        gameRef.add(ObstacleComponent(
          type: type,
          laneFraction: f,
        ));
        break;
      case ObstacleType.cone:
      case ObstacleType.barrier:
      case ObstacleType.pothole:
        gameRef.add(ObstacleComponent(
          type: type,
          laneFraction: 0.15 + _rng.nextDouble() * 0.70,
        ));
        break;
    }
  }

  double _carLaneFraction() {
    // Carve cars into rough lanes for variety.
    final pick = _rng.nextInt(3);
    switch (pick) {
      case 0:
        return 0.20 + _rng.nextDouble() * 0.10;
      case 1:
        return 0.45 + _rng.nextDouble() * 0.10;
      default:
        return 0.70 + _rng.nextDouble() * 0.10;
    }
  }

  void _spawnPaperPack() {
    // Bias toward the side the player is currently on so it's collectible.
    final lm = gameRef.laneManager;
    final playerX = gameRef.player.position.x;
    final roadLeft = lm.roadLeft;
    final roadRight = lm.roadRight;
    final pf = ((playerX - roadLeft) / (roadRight - roadLeft))
        .clamp(0.0, 1.0);
    final jitter = (_rng.nextDouble() - 0.5) * 0.2;
    final laneFraction = (pf + jitter).clamp(0.05, 0.95);
    gameRef.add(PaperPackComponent(laneFraction: laneFraction));
  }
}
