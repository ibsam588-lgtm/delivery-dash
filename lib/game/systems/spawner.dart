import 'dart:math';
import 'package:flame/components.dart';
import '../components/construction_zone.dart';
import '../components/intersection.dart';
import '../components/obstacle.dart';
import '../components/paper_pack.dart';
import '../components/parked_car.dart';
import '../components/streetlamp.dart';
import '../delivery_dash_game.dart';
import '../difficulty.dart';

class Spawner extends Component with HasGameRef<DeliveryDashGame> {
  double _obstacleTimer = 0;
  double _packDistanceMark = 0;
  double _lampDistanceMark = 0;
  double _parkedCarDistanceMark = 0;
  double _intersectionDistanceMark = 0;
  double _zoneDistanceMark = 0;
  final Random _rng = Random();

  static const double paperPackDistanceInterval = 300; // meters
  static const double lampDistanceInterval = 90;
  static const double parkedCarDistanceInterval = 220;
  static const double intersectionDistanceInterval = 400;
  static const double constructionZoneDistanceInterval = 550;

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

    final d = gameRef.distanceMeters;
    if (d - _packDistanceMark >= paperPackDistanceInterval) {
      _packDistanceMark = d;
      _spawnPaperPack();
    }
    if (d - _lampDistanceMark >= lampDistanceInterval) {
      _lampDistanceMark = d;
      _spawnStreetlamps();
    }
    if (d - _parkedCarDistanceMark >= parkedCarDistanceInterval) {
      _parkedCarDistanceMark = d;
      if (_rng.nextDouble() < 0.85) _spawnParkedCar();
    }
    if (d - _intersectionDistanceMark >= intersectionDistanceInterval) {
      _intersectionDistanceMark = d;
      _spawnIntersection();
    }
    if (d - _zoneDistanceMark >= constructionZoneDistanceInterval) {
      _zoneDistanceMark = d;
      if (_rng.nextDouble() < 0.7) _spawnConstructionZone();
    }
  }

  void _spawnObstacle() {
    final roll = _rng.nextDouble();
    final ObstacleType type;
    if (roll < 0.28) {
      type = ObstacleType.car;
    } else if (roll < 0.38) {
      type = ObstacleType.dog;
    } else if (roll < 0.46) {
      type = ObstacleType.kidBike;
    } else if (roll < 0.54) {
      type = ObstacleType.worker;
    } else if (roll < 0.64) {
      type = ObstacleType.cone;
    } else if (roll < 0.72) {
      type = ObstacleType.barrier;
    } else if (roll < 0.78) {
      type = ObstacleType.pothole;
    } else if (roll < 0.84) {
      type = ObstacleType.manhole;
    } else if (roll < 0.92) {
      type = ObstacleType.trashBin;
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
        // Hangs out on the right sidewalk near construction cones.
        gameRef.add(ObstacleComponent(
          type: type,
          laneFraction: 0.35 + _rng.nextDouble() * 0.55,
          onRightSidewalk: true,
        ));
        // Cluster of cones in the road (mini construction zone).
        if (_rng.nextBool()) {
          final coneLane = 0.20 + _rng.nextDouble() * 0.60;
          for (final offset in const [-0.05, 0.0, 0.05]) {
            gameRef.add(ObstacleComponent(
              type: ObstacleType.cone,
              laneFraction: (coneLane + offset).clamp(0.05, 0.95),
            ));
          }
        }
        break;
      case ObstacleType.dog:
        // Spawns near the right edge then sweeps across.
        gameRef.add(ObstacleComponent(
          type: type,
          laneFraction: 0.75,
        ));
        break;
      case ObstacleType.kidBike:
        // Spawns near the left edge then sweeps across.
        gameRef.add(ObstacleComponent(
          type: type,
          laneFraction: 0.25,
        ));
        break;
      case ObstacleType.trashBin:
        // On the right sidewalk close to the curb.
        gameRef.add(ObstacleComponent(
          type: type,
          laneFraction: 0.04 + _rng.nextDouble() * 0.20,
          onRightSidewalk: true,
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
      case ObstacleType.manhole:
        gameRef.add(ObstacleComponent(
          type: type,
          laneFraction: 0.15 + _rng.nextDouble() * 0.70,
        ));
        break;
    }
  }

  double _carLaneFraction() {
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

  void _spawnStreetlamps() {
    // Always come in pairs at the same Y to anchor depth visually.
    gameRef.add(StreetlampComponent(onRight: false));
    gameRef.add(StreetlampComponent(onRight: true));
  }

  void _spawnParkedCar() {
    gameRef.add(ParkedCarComponent(variant: _rng.nextInt(2)));
  }

  void _spawnIntersection() {
    gameRef.add(IntersectionComponent());
  }

  void _spawnConstructionZone() {
    gameRef.add(ConstructionZoneComponent());
  }
}
