enum Difficulty { easy, medium, hard }

class DifficultyConfig {
  final double startSpeed;
  final double spawnInterval;
  final double speedRamp;

  const DifficultyConfig({
    required this.startSpeed,
    required this.spawnInterval,
    required this.speedRamp,
  });

  static const Map<Difficulty, DifficultyConfig> configs = {
    Difficulty.easy: DifficultyConfig(
      startSpeed: 120,
      spawnInterval: 2.5,
      speedRamp: 8,
    ),
    Difficulty.medium: DifficultyConfig(
      startSpeed: 180,
      spawnInterval: 1.8,
      speedRamp: 12,
    ),
    Difficulty.hard: DifficultyConfig(
      startSpeed: 260,
      spawnInterval: 1.1,
      speedRamp: 18,
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

  DifficultyConfig get difficultyConfig =>
      DifficultyConfig.of(difficulty);
}
