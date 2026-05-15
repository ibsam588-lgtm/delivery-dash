import 'package:delivery_dash/game/difficulty.dart';
import 'package:delivery_dash/services/score_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('ScoreService is a singleton', () {
    expect(ScoreService.instance, same(ScoreService.instance));
  });

  group('DifficultyConfig', () {
    test('maps difficulty to expected start levels', () {
      expect(DifficultyConfig.startLevelFor(Difficulty.easy), 1);
      expect(DifficultyConfig.startLevelFor(Difficulty.medium), 3);
      expect(DifficultyConfig.startLevelFor(Difficulty.hard), 6);
    });

    test('maps difficulty to expected lives and papers', () {
      expect(DifficultyConfig.livesFor(Difficulty.easy), 5);
      expect(DifficultyConfig.livesFor(Difficulty.medium), 3);
      expect(DifficultyConfig.livesFor(Difficulty.hard), 2);

      expect(DifficultyConfig.papersFor(Difficulty.easy), 30);
      expect(DifficultyConfig.papersFor(Difficulty.medium), 20);
      expect(DifficultyConfig.papersFor(Difficulty.hard), 15);
    });

    test('keeps harder difficulties faster and more rewarding', () {
      expect(
        DifficultyConfig.speedMultiplierFor(Difficulty.hard),
        greaterThan(DifficultyConfig.speedMultiplierFor(Difficulty.medium)),
      );
      expect(
        DifficultyConfig.coinMultiplierFor(Difficulty.hard),
        greaterThan(DifficultyConfig.coinMultiplierFor(Difficulty.medium)),
      );
    });
  });

  group('LevelConfig', () {
    test('clamps level lookup to supported range', () {
      expect(LevelConfig.of(0).level, 1);
      expect(LevelConfig.of(1).level, 1);
      expect(LevelConfig.of(LevelConfig.maxLevel + 99).level,
          LevelConfig.maxLevel);
    });

    test('speed and spawn pressure increase across levels', () {
      expect(LevelConfig.of(10).startSpeed,
          greaterThan(LevelConfig.of(1).startSpeed));
      expect(LevelConfig.of(10).spawnInterval,
          lessThan(LevelConfig.of(1).spawnInterval));
    });
  });

  group('GameConfig', () {
    test('uses difficulty-derived defaults', () {
      const config = GameConfig(difficulty: Difficulty.hard);

      expect(config.startLevel, 6);
      expect(config.lives, 2);
      expect(config.papers, 15);
      expect(config.speedMultiplier,
          DifficultyConfig.speedMultiplierFor(Difficulty.hard));
      expect(config.spawnIntervalMultiplier,
          DifficultyConfig.spawnIntervalMultiplierFor(Difficulty.hard));
    });
  });

  test('combo multiplier increases at delivery streak breakpoints', () {
    expect(comboMultiplier(0), 1);
    expect(comboMultiplier(2), 1);
    expect(comboMultiplier(3), 2);
    expect(comboMultiplier(6), 3);
    expect(comboMultiplier(10), 5);
  });
}
