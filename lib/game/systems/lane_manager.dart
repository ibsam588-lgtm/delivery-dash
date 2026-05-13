import 'package:flame/components.dart';

class LaneManager {
  final Vector2 gameSize;

  static const int laneCount = 3;

  LaneManager({required this.gameSize});

  double get laneWidth => (gameSize.x * 0.6) / laneCount;

  double get roadLeft => gameSize.x * 0.2;
  double get roadRight => gameSize.x * 0.8;
  double get roadWidth => roadRight - roadLeft;

  double laneX(int lane) {
    assert(lane >= 0 && lane < laneCount);
    return roadLeft + laneWidth * (lane + 0.5);
  }
}
