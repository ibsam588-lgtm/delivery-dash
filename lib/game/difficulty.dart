enum Difficulty { easy, medium, hard }

enum CourierAvatar { boy, girl }

enum RouteZone { suburb, city }

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
        return 5;
      case Difficulty.medium:
        return 3;
      case Difficulty.hard:
        return 2;
    }
  }

  static int papersFor(Difficulty d) {
    switch (d) {
      case Difficulty.easy:
        return 30;
      case Difficulty.medium:
        return 20;
      case Difficulty.hard:
        return 15;
    }
  }

  /// Multiplier applied to baseline scroll speed.
  static double speedMultiplierFor(Difficulty d) {
    switch (d) {
      case Difficulty.easy:
        return 0.7;
      case Difficulty.medium:
        return 1.0;
      case Difficulty.hard:
        return 1.3;
    }
  }

  /// Multiplier applied to obstacle spawn interval — larger = slower spawns.
  static double spawnIntervalMultiplierFor(Difficulty d) {
    switch (d) {
      case Difficulty.easy:
        return 1.5;
      case Difficulty.medium:
        return 1.0;
      case Difficulty.hard:
        return 0.7;
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

class AvatarConfig {
  static String label(CourierAvatar avatar) {
    switch (avatar) {
      case CourierAvatar.boy:
        return 'BOY';
      case CourierAvatar.girl:
        return 'DOLL';
    }
  }
}

class ZoneConfig {
  static String label(RouteZone zone) {
    switch (zone) {
      case RouteZone.suburb:
        return 'SUBURB';
      case RouteZone.city:
        return 'CITY';
    }
  }
}

class RunSelection {
  final Difficulty difficulty;
  final CourierAvatar avatar;
  final RouteZone zone;

  const RunSelection({
    required this.difficulty,
    this.avatar = CourierAvatar.girl,
    this.zone = RouteZone.suburb,
  });
}

int comboMultiplier(int combo) {
  if (combo >= 10) return 5;
  if (combo >= 6) return 3;
  if (combo >= 3) return 2;
  return 1;
}

class GameConfig {
  final Difficulty difficulty;
  final CourierAvatar avatar;
  final RouteZone zone;
  final bool hasShield;
  final bool speedBoostStart;
  final bool doubleCoins;
  final bool paperBlitz;
  final bool vipSkin;
  final String outfitId;
  final String bikeId;

  const GameConfig({
    this.difficulty = Difficulty.medium,
    this.avatar = CourierAvatar.girl,
    this.zone = RouteZone.suburb,
    this.hasShield = false,
    this.speedBoostStart = false,
    this.doubleCoins = false,
    this.paperBlitz = false,
    this.vipSkin = false,
    this.outfitId = 'outfit_classic',
    this.bikeId = 'bike_classic',
  });

  int get startLevel => DifficultyConfig.startLevelFor(difficulty);
  int get lives => DifficultyConfig.livesFor(difficulty);
  int get papers => DifficultyConfig.papersFor(difficulty);
  double get coinMultiplier => DifficultyConfig.coinMultiplierFor(difficulty);
  double get speedMultiplier => DifficultyConfig.speedMultiplierFor(difficulty);
  double get spawnIntervalMultiplier =>
      DifficultyConfig.spawnIntervalMultiplierFor(difficulty);
}
