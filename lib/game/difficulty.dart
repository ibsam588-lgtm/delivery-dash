enum Difficulty { easy, medium, hard }

class DayConfig {
  final int day;
  final double startSpeed;
  final double spawnInterval;
  final int papers;
  final String label;

  const DayConfig({
    required this.day,
    required this.startSpeed,
    required this.spawnInterval,
    required this.papers,
    required this.label,
  });

  static const List<DayConfig> days = [
    DayConfig(
      day: 1,
      startSpeed: 160,
      spawnInterval: 2.5,
      papers: 5,
      label: 'Easy Start',
    ),
    DayConfig(
      day: 2,
      startSpeed: 200,
      spawnInterval: 2.0,
      papers: 5,
      label: 'More Traffic',
    ),
    DayConfig(
      day: 3,
      startSpeed: 250,
      spawnInterval: 1.6,
      papers: 6,
      label: 'Faster',
    ),
    DayConfig(
      day: 4,
      startSpeed: 310,
      spawnInterval: 1.2,
      papers: 6,
      label: 'Hard',
    ),
    DayConfig(
      day: 5,
      startSpeed: 380,
      spawnInterval: 0.9,
      papers: 7,
      label: 'Expert',
    ),
  ];

  static DayConfig of(int day) {
    final idx = (day - 1).clamp(0, days.length - 1);
    return days[idx];
  }

  static const double metersPerDay = 600;
  static const double pxPerMeter = 9;
}

class DifficultyConfig {
  static int startDayFor(Difficulty d) {
    switch (d) {
      case Difficulty.easy:
        return 1;
      case Difficulty.medium:
        return 2;
      case Difficulty.hard:
        return 3;
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

  int get startDay => DifficultyConfig.startDayFor(difficulty);
  int get lives => DifficultyConfig.livesFor(difficulty);
  double get coinMultiplier => DifficultyConfig.coinMultiplierFor(difficulty);
}
