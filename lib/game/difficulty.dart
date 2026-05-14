enum Difficulty { easy, medium, hard }

class LevelConfig {
  final int level;
  final double startSpeed;
  final double spawnInterval;
  final int papers;

  const LevelConfig({
    required this.level,
    required this.startSpeed,
    required this.spawnInterval,
    required this.papers,
  });

  static const List<LevelConfig> levels = [
    LevelConfig(level: 1, startSpeed: 140, spawnInterval: 3.0, papers: 20),
    LevelConfig(level: 2, startSpeed: 170, spawnInterval: 2.6, papers: 20),
    LevelConfig(level: 3, startSpeed: 200, spawnInterval: 2.2, papers: 20),
    LevelConfig(level: 4, startSpeed: 235, spawnInterval: 1.9, papers: 20),
    LevelConfig(level: 5, startSpeed: 270, spawnInterval: 1.6, papers: 20),
    LevelConfig(level: 6, startSpeed: 310, spawnInterval: 1.4, papers: 20),
    LevelConfig(level: 7, startSpeed: 350, spawnInterval: 1.2, papers: 20),
    LevelConfig(level: 8, startSpeed: 395, spawnInterval: 1.0, papers: 20),
    LevelConfig(level: 9, startSpeed: 440, spawnInterval: 0.85, papers: 20),
    LevelConfig(level: 10, startSpeed: 490, spawnInterval: 0.7, papers: 20),
  ];

  static LevelConfig of(int level) {
    final idx = (level - 1).clamp(0, levels.length - 1);
    return levels[idx];
  }

  static const double metersPerLevel = 600;
  static const double pxPerMeter = 9;
  static const int maxLevel = 10;
}

class DifficultyConfig {
  static int startLevelFor(Difficulty d) {
    switch (d) {
      case Difficulty.easy:
        return 1;
      case Difficulty.medium:
        return 3;
      case Difficulty.hard:
        return 6;
    }
  }

  static int livesFor(Difficulty d) {
    switch (d) {
      case Difficulty.easy:
        return 4;
      case Difficulty.medium:
        return 3;
      case Difficulty.hard:
        return 2;
    }
  }

  static double coinMultiplierFor(Difficulty d) {
    switch (d) {
      case Difficulty.easy:
        return 1.0;
      case Difficulty.medium:
        return 1.5;
      case Difficulty.hard:
        return 2.0;
    }
  }

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

  int get startLevel => DifficultyConfig.startLevelFor(difficulty);
  int get lives => DifficultyConfig.livesFor(difficulty);
  double get coinMultiplier => DifficultyConfig.coinMultiplierFor(difficulty);
}
