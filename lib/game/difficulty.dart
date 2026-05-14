enum Difficulty { easy, medium, hard }

class DifficultyConfig {
  final double startSpeed;
  final int laneSwitchMs;
  final double spawnInterval;
  final double speedRamp;
  final int lives;
  final double coinMultiplier;

  const DifficultyConfig({
    required this.startSpeed,
    required this.laneSwitchMs,
    required this.spawnInterval,
    required this.speedRamp,
    required this.lives,
    required this.coinMultiplier,
  });

  static const Map<Difficulty, DifficultyConfig> configs = {
    Difficulty.easy: DifficultyConfig(
      startSpeed: 180,
      laneSwitchMs: 220,
      spawnInterval: 2.2,
      speedRamp: 8,
      lives: 4,
      coinMultiplier: 1.0,
    ),
    Difficulty.medium: DifficultyConfig(
      startSpeed: 260,
      laneSwitchMs: 160,
      spawnInterval: 1.5,
      speedRamp: 15,
      lives: 3,
      coinMultiplier: 1.5,
    ),
    Difficulty.hard: DifficultyConfig(
      startSpeed: 360,
      laneSwitchMs: 100,
      spawnInterval: 0.9,
      speedRamp: 25,
      lives: 2,
      coinMultiplier: 2.0,
    ),
  };

  static DifficultyConfig of(Difficulty d) => configs[d]!;

  static String label(Difficulty d) {
    switch (d) {
      case Difficulty.easy:
        return 'EASY';
      case Difficulty.medium:
        return 'MEDIUM';
      case Difficulty.hard:
        return 'HARD';
    }
  }
}

class LevelConfig {
  static const double metersPerLevel = 500;
  static const int maxLevel = 10;
  static const double pxPerMeter = 9;
  static const double paperRefillMeters = 300;

  static double speedBonusForLevel(int level) {
    final clamped = level.clamp(1, maxLevel);
    return (clamped - 1) * 20.0;
  }

  static double spawnFactorForLevel(int level) {
    final clamped = level.clamp(1, maxLevel);
    return (1.0 - (clamped - 1) * 0.05).clamp(0.55, 1.0);
  }
}

int comboMultiplier(int combo) {
  if (combo >= 10) return 5;
  if (combo >= 6) return 3;
  if (combo >= 3) return 2;
  return 1;
}

class GameConfig {
  final Difficulty difficulty;
  final bool hasShield;
  final bool speedBoostStart;
  final bool doubleCoins;
  final bool paperBlitz;
  final bool vipSkin;

  const GameConfig({
    this.difficulty = Difficulty.medium,
    this.hasShield = false,
    this.speedBoostStart = false,
    this.doubleCoins = false,
    this.paperBlitz = false,
    this.vipSkin = false,
  });

  DifficultyConfig get difficultyConfig => DifficultyConfig.of(difficulty);
}
