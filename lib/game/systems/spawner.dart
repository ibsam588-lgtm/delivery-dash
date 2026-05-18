import 'dart:math';
import 'dart:ui';
import 'package:flame/components.dart';
import '../components/cat_npc.dart';
import '../components/construction_zone.dart';
import '../components/intersection.dart';
import '../components/obstacle.dart';
import '../components/paper_pack.dart';
import '../components/parked_car.dart';
import '../components/road_decor.dart';
import '../components/streetlamp.dart';
import '../delivery_dash_game.dart';
import '../difficulty.dart';

class Spawner extends Component with HasGameRef<DeliveryDashGame> {
  double _obstacleTimer = 0;
  double _runTimer = 0;
  double _packDistanceMark = 0;
  double _lampDistanceMark = 0;
  double _parkedCarDistanceMark = 0;
  double _intersectionTimer = 0;
  double _nextIntersectionDelay = firstIntersectionDelay;
  double _zoneDistanceMark = 0;
  double _catDistanceMark = 0;
  double _decorTimer = 0;
  bool _spawnedOpeningTraffic = false;
  bool _spawnedOpeningConstruction = false;
  final Random _rng = Random();

  static const double paperPackDistanceInterval = 400;
  static const double lampDistanceInterval = 90;
  static const double parkedCarDistanceInterval = 300;
  static const double firstIntersectionDelay = 12.0;
  static const double intersectionTimeInterval = 24.0;
  static const double constructionZoneDistanceInterval = 650;
  static const double catDistanceInterval = 620;
  static const double decorSpawnInterval = 1.4;
  static const double openingTrafficGrace = 2.2;

  static const List<Color> _leafColors = [
    Color(0xFFD84315),
    Color(0xFFE65100),
    Color(0xFFF9A825),
    Color(0xFF827717),
    Color(0xFFBF360C),
  ];

  double get _obstacleInterval {
    final cfg = LevelConfig.of(gameRef.level);
    final base = cfg.spawnInterval;
    final scroll = gameRef.scrollSpeed;
    final speedFactor = scroll > 1 ? cfg.startSpeed / scroll : 1.0;
    final diffMult = gameRef.config.spawnIntervalMultiplier;
    final upper = base * diffMult;
    return (base * speedFactor * diffMult)
        .clamp(0.60, upper < 0.60 ? 0.60 : upper);
  }

  @override
  void update(double dt) {
    super.update(dt);
    if (gameRef.state != GameState.playing) return;
    _runTimer += dt;

    if (!_spawnedOpeningTraffic && _runTimer >= 1.1) {
      _spawnedOpeningTraffic = true;
      _spawnTrafficCar(laneFraction: _rng.nextBool() ? 0.30 : 0.70);
    }

    if (!_spawnedOpeningConstruction && _runTimer >= 0.25) {
      _spawnedOpeningConstruction = true;
      _spawnConstructionZone(initialY: gameRef.size.y * 0.10);
    }

    _obstacleTimer += dt;
    if (_runTimer >= openingTrafficGrace &&
        _obstacleTimer >= _obstacleInterval) {
      _obstacleTimer = 0;
      _spawnObstacle();
    }

    _decorTimer += dt;
    if (_decorTimer >= decorSpawnInterval) {
      _decorTimer = 0;
      _spawnDecor();
    }

    _intersectionTimer += dt;
    if (_intersectionTimer >= _nextIntersectionDelay) {
      _intersectionTimer = 0;
      _nextIntersectionDelay = intersectionTimeInterval;
      _spawnIntersection();
    }

    final d = gameRef.totalDistanceMeters;
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
      if (_rng.nextDouble() < 0.50) _spawnParkedCar();
    }
    if (d - _zoneDistanceMark >= constructionZoneDistanceInterval) {
      _zoneDistanceMark = d;
      if (_rng.nextDouble() < 0.55) _spawnConstructionZone();
    }
    if (d - _catDistanceMark >= catDistanceInterval) {
      _catDistanceMark = d;
      if (_rng.nextDouble() < 0.75) _spawnCat();
      if (_rng.nextDouble() < 0.55) _spawnRightCat();
    }
  }

  void _spawnObstacle() {
    final roll = _rng.nextDouble();
    final ObstacleType type;
    if (gameRef.config.zone == RouteZone.city) {
      if (roll < 0.34) {
        type = ObstacleType.car;
      } else if (roll < 0.46) {
        type = ObstacleType.eBike;
      } else if (roll < 0.58) {
        type = ObstacleType.skateboarder;
      } else if (roll < 0.66) {
        type = ObstacleType.worker;
      } else if (roll < 0.76) {
        type = ObstacleType.cone;
      } else if (roll < 0.84) {
        type = ObstacleType.barrier;
      } else if (roll < 0.91) {
        type = ObstacleType.manhole;
      } else if (roll < 0.96) {
        type = ObstacleType.trashBin;
      } else {
        type = ObstacleType.hydrant;
      }
    } else {
      if (roll < 0.24) {
        type = ObstacleType.car;
      } else if (roll < 0.36) {
        type = ObstacleType.dog;
      } else if (roll < 0.43) {
        type = ObstacleType.kidBike;
      } else if (roll < 0.51) {
        type = ObstacleType.worker;
      } else if (roll < 0.62) {
        type = ObstacleType.cone;
      } else if (roll < 0.72) {
        type = ObstacleType.barrier;
      } else if (roll < 0.78) {
        type = ObstacleType.pothole;
      } else if (roll < 0.84) {
        type = ObstacleType.manhole;
      } else if (roll < 0.91) {
        type = ObstacleType.trashBin;
      } else {
        type = ObstacleType.hydrant;
      }
    }

    switch (type) {
      case ObstacleType.car:
        _spawnTrafficCar();
        break;
      case ObstacleType.worker:
        gameRef.add(ObstacleComponent(
          type: type,
          laneFraction: 0.15 + _rng.nextDouble() * 0.70,
          onRightSidewalk: true,
        ));
        if (_rng.nextBool()) {
          final coneLane = 0.30 + _rng.nextDouble() * 0.40;
          for (final offset in const [-0.06, 0.0, 0.06]) {
            gameRef.add(ObstacleComponent(
              type: ObstacleType.cone,
              laneFraction: (coneLane + offset).clamp(0.24, 0.76),
            ));
          }
        }
        break;
      case ObstacleType.dog:
        gameRef.add(ObstacleComponent(type: type, laneFraction: 0.66));
        break;
      case ObstacleType.kidBike:
        gameRef.add(ObstacleComponent(type: type, laneFraction: 0.34));
        break;
      case ObstacleType.skateboarder:
        gameRef.add(ObstacleComponent(
          type: type,
          laneFraction: 0.28 + _rng.nextDouble() * 0.44,
          speedFactor: 1.08,
        ));
        break;
      case ObstacleType.eBike:
        gameRef.add(ObstacleComponent(
          type: type,
          laneFraction: _frontCarLaneFraction(),
          speedFactor: 1.35,
        ));
        break;
      case ObstacleType.trashBin:
        gameRef.add(ObstacleComponent(
          type: type,
          laneFraction: 0.10 + _rng.nextDouble() * 0.80,
          onRightSidewalk: true,
        ));
        break;
      case ObstacleType.hydrant:
        gameRef.add(ObstacleComponent(
          type: type,
          laneFraction: 0.08 + _rng.nextDouble() * 0.84,
          onRightSidewalk: _rng.nextBool(),
        ));
        break;
      case ObstacleType.cone:
      case ObstacleType.barrier:
      case ObstacleType.pothole:
      case ObstacleType.manhole:
        gameRef.add(ObstacleComponent(
          type: type,
          laneFraction: 0.24 + _rng.nextDouble() * 0.52,
        ));
        break;
    }
  }

  void _spawnTrafficCar({double? laneFraction}) {
    gameRef.add(ObstacleComponent(
      type: ObstacleType.car,
      laneFraction: laneFraction ?? _frontCarLaneFraction(),
      // Much faster than road scroll so cars read as active traffic.
      speedFactor: 1.72 + _rng.nextDouble() * 0.55,
      isOvertaker: false,
      isOncoming: false,
    ));
  }

  double _frontCarLaneFraction() {
    final pick = _rng.nextInt(3);
    switch (pick) {
      case 0:
        return 0.28 + _rng.nextDouble() * 0.04;
      case 1:
        return 0.48 + _rng.nextDouble() * 0.04;
      default:
        return 0.68 + _rng.nextDouble() * 0.04;
    }
  }

  void _spawnPaperPack() {
    final lm = gameRef.laneManager;
    final playerX = gameRef.player.position.x;
    final roadLeft = lm.roadLeft;
    final roadRight = lm.roadRight;
    final pf = ((playerX - roadLeft) / (roadRight - roadLeft)).clamp(0.0, 1.0);
    final jitter = (_rng.nextDouble() - 0.5) * 0.16;
    final laneFraction = (pf + jitter).clamp(0.18, 0.82);
    gameRef.add(PaperPackComponent(laneFraction: laneFraction));
  }

  void _spawnStreetlamps() {
    gameRef.add(StreetlampComponent(onRight: false));
    gameRef.add(StreetlampComponent(onRight: true));
  }

  void _spawnParkedCar() {
    gameRef.add(ParkedCarComponent(
      variant: _rng.nextInt(ParkedCarComponent.variantCount),
      onRightCurb: _rng.nextBool(),
    ));
  }

  void _spawnIntersection() => gameRef.add(IntersectionComponent());

  void _spawnConstructionZone({double? initialY}) =>
      gameRef.add(ConstructionZoneComponent(initialY: initialY));

  void _spawnCat() {
    final lm = gameRef.laneManager;
    final maxX = lm.roadLeft - 6;
    const minX = 16.0;
    if (maxX <= minX) return;
    final x = minX + _rng.nextDouble() * (maxX - minX);
    gameRef.add(CatNpcComponent(position: Vector2(x, -30), rng: _rng));
  }

  void _spawnRightCat() {
    final lm = gameRef.laneManager;
    final minX = lm.roadRight + 6;
    final maxX = gameRef.size.x - 16;
    if (maxX <= minX) return;
    final x = minX + _rng.nextDouble() * (maxX - minX);
    gameRef.add(CatNpcComponent(position: Vector2(x, -30), rng: _rng));
  }

  void _spawnDecor() {
    final lm = gameRef.laneManager;

    if (_rng.nextDouble() < 0.30) {
      final x = lm.roadXFromFraction(0.25 + _rng.nextDouble() * 0.50);
      gameRef.add(RoadDecorComponent(
        decorType: RoadDecorType.puddle,
        position: Vector2(x, -25),
      ));
    }

    if (_rng.nextDouble() < 0.70) {
      final count = 1 + _rng.nextInt(4);
      for (int i = 0; i < count; i++) {
        final maxX = lm.roadLeft - 8;
        const minX = 8.0;
        if (maxX <= minX) break;
        final x = minX + _rng.nextDouble() * (maxX - minX);
        final y = -10.0 - _rng.nextDouble() * 50;
        final leafColor = _leafColors[_rng.nextInt(_leafColors.length)];
        gameRef.add(RoadDecorComponent(
          decorType: RoadDecorType.leaf,
          position: Vector2(x, y),
          leafColor: leafColor,
          leafAngle: _rng.nextDouble() * 2 * pi,
        ));
      }
    }

    if (_rng.nextDouble() < 0.65) {
      final count = 1 + _rng.nextInt(3);
      for (int i = 0; i < count; i++) {
        final minX = lm.roadRight + 8;
        final maxX = gameRef.size.x - 8;
        if (maxX <= minX) break;
        final x = minX + _rng.nextDouble() * (maxX - minX);
        final y = -10.0 - _rng.nextDouble() * 50;
        final leafColor = _leafColors[_rng.nextInt(_leafColors.length)];
        gameRef.add(RoadDecorComponent(
          decorType: RoadDecorType.leaf,
          position: Vector2(x, y),
          leafColor: leafColor,
          leafAngle: _rng.nextDouble() * 2 * pi,
        ));
      }
    }
  }
}
