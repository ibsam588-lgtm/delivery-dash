import 'package:flame/components.dart';

class LaneManager {
  final Vector2 gameSize;

  static const int laneCount = 3;

  LaneManager({required this.gameSize});

  double get sidewalkWidth => gameSize.x * 0.20;
  double get roadLeft => sidewalkWidth;
  double get roadRight => gameSize.x - sidewalkWidth;
  double get roadWidth => roadRight - roadLeft;
  double get laneWidth => roadWidth / laneCount;

  double laneX(int lane) {
    assert(lane >= 0 && lane < laneCount);
    return roadLeft + laneWidth * (lane + 0.5);
  }

  double laneLeftEdge(int lane) => roadLeft + laneWidth * lane;
  double laneRightEdge(int lane) => roadLeft + laneWidth * (lane + 1);
}
