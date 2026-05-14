import 'dart:math';
import 'package:flame/components.dart';
import '../components/obstacle.dart';
import '../delivery_dash_game.dart';
import '../difficulty.dart';
import 'lane_manager.dart';

class Spawner extends Component with HasGameRef<DeliveryDashGame> {
  double _obstacleTimer = 0;
  final Random _rng = Random();

  double get _obstacleInterval {
    final cfg = DayConfig.of(gameRef.day);
    final base = cfg.spawnInterval;
    final speedFactor = cfg.startSpeed / gameRef.scrollSpeed;
    return (base * speedFactor).clamp(0.45, base);
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
    final lm = gameRef.laneManager;
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

    final spawnX = _xForType(type, lm);
    gameRef.add(ObstacleComponent(type: type, spawnX: spawnX));
  }

  double _xForType(ObstacleType type, LaneManager lm) {
    double inRoad(double pad) {
      final lo = lm.roadLeft + pad;
      final hi = lm.roadRight - pad;
      if (hi <= lo) return lm.roadCenter;
      return lo + _rng.nextDouble() * (hi - lo);
    }

    double onRightSidewalk(double pad) {
      final lo = lm.roadRight + pad;
      final hi = lm.roadRight + lm.rightSidewalkWidth - pad;
      if (hi <= lo) return lm.roadRight + lm.rightSidewalkWidth / 2;
      return lo + _rng.nextDouble() * (hi - lo);
    }

    switch (type) {
      case ObstacleType.car:
        return inRoad(36);
      case ObstacleType.cone:
        return inRoad(28);
      case ObstacleType.pothole:
        return inRoad(32);
      case ObstacleType.worker:
        return onRightSidewalk(30);
      case ObstacleType.dog:
        return _rng.nextBool() ? inRoad(30) : onRightSidewalk(28);
      case ObstacleType.barrier:
        if (_rng.nextBool()) {
          return lm.roadRight - 44;
        }
        return inRoad(44);
    }
  }
}
