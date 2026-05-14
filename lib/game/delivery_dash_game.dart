import 'dart:math';
import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import '../services/audio_service.dart';
import '../services/score_service.dart';
import '../services/store_service.dart';
import 'components/floating_text.dart';
import 'components/house.dart';
import 'components/hud.dart';
import 'components/paper.dart';
import 'components/player.dart';
import 'components/road_background.dart';
import 'difficulty.dart';
import 'systems/lane_manager.dart';
import 'systems/spawner.dart';

enum GameState { playing, gameOver }

class DeliveryDashGame extends FlameGame with HasCollisionDetection {
  final GameConfig config;

  GameState state = GameState.playing;
  int score = 0;
  int lives = 3;
  int comboCount = 0;
  int bestComboThisRun = 0;
  int coinsThisRun = 0;
  int level = 1;
  double distanceMeters = 0;
  double _lastRefillMeters = 0;
  int papers = 3;
  static const int maxPapers = 3;

  double currentSpeed = 200;
  double _slowFactor = 1.0;
  double _slowTimer = 0;
  bool isInvincible = false;
  double invincibilityTimer = 0;

  late LaneManager laneManager;
  late PlayerComponent player;
  late Hud hud;

  final ValueNotifier<int> paperCountNotifier = ValueNotifier<int>(maxPapers);

  bool _isShaking = false;
  double _shakeTimer = 0;
  static const double _shakeDuration = 0.2;
  static const double _shakeIntensity = 6.0;
  final Random _rng = Random();

  static bool _hasShownTutorial = false;

  void Function(
    int score,
    int highScore,
    bool isNewRecord,
    int coinsEarned,
    int bestCombo,
    int reachedLevel,
  )? onGameOver;

  DeliveryDashGame({this.config = const GameConfig()});

  double get scrollSpeed => currentSpeed * _slowFactor;
  int get distanceForLevelTarget => LevelConfig.metersPerLevel.toInt();

  @override
  Color backgroundColor() => const Color(0xFF101218);

  @override
  Future<void> onLoad() async {
    await super.onLoad();
    laneManager = LaneManager(gameSize: size);
    await _preloadAssets();
    _initGame();
  }

  Future<void> _preloadAssets() async {
    const files = [
      'mailbox_blue.png',
      'mailbox_red.png',
      'car_0.png',
      'car_1.png',
      'car_2.png',
      'car_3.png',
      'dog.png',
      'worker.png',
      'cone.png',
      'barrier.png',
      'pothole.png',
      'house_0.png',
      'house_1.png',
      'house_2.png',
      'house_3.png',
    ];
    // Load each individually so a single missing/corrupt file does not
    // abort the whole load and leave the game without sprites.
    for (final f in files) {
      try {
        await images.load(f);
      } catch (e) {
        debugPrint('Failed to preload $f: $e');
      }
    }
    try {
      await AudioService.instance.init();
    } catch (_) {}
  }

  void _initGame() {
    final diff = config.difficultyConfig;

    score = 0;
    lives = diff.lives + (config.hasShield ? 1 : 0);
    comboCount = 0;
    bestComboThisRun = 0;
    coinsThisRun = 0;
    level = 1;
    distanceMeters = 0;
    _lastRefillMeters = 0;
    papers = maxPapers;
    paperCountNotifier.value = papers;
    currentSpeed = diff.startSpeed + (config.speedBoostStart ? 60 : 0);
    isInvincible = false;
    _slowFactor = 1.0;
    _slowTimer = 0;
    state = GameState.playing;

    add(RoadBackground(gameSize: size));

    final rowsPerSide = (size.y / HouseComponent.rowSpacing).ceil() + 2;
    for (int i = 0; i < rowsPerSide; i++) {
      add(HouseComponent(
        side: HouseSide.left,
        initialY: i * HouseComponent.rowSpacing - HouseComponent.rowSpacing,
        index: i,
      ));
      add(HouseComponent(
        side: HouseSide.right,
        initialY: i * HouseComponent.rowSpacing -
            HouseComponent.rowSpacing / 2,
        index: i + 1,
      ));
    }

    player = PlayerComponent(isVip: config.vipSkin);
    add(player);

    hud = Hud();
    add(hud);
    hud.updateLives(lives);
    hud.updateCoins(0);
    hud.updateScore(0);
    hud.updateSpeed(currentSpeed);
    hud.updateLevel(level);
    hud.updateDistance(0, distanceForLevelTarget);
    hud.updatePaperCount(papers, maxPapers);

    add(Spawner());

    AudioService.instance.playBgm();

    if (!_hasShownTutorial) {
      _hasShownTutorial = true;
      overlays.add('Tutorial');
      Future.delayed(const Duration(seconds: 3), () {
        overlays.remove('Tutorial');
      });
    }
  }

  @override
  void update(double dt) {
    super.update(dt);
    if (state != GameState.playing) return;

    if (isInvincible) {
      invincibilityTimer -= dt;
      if (invincibilityTimer <= 0) {
        isInvincible = false;
        player.opacity = 1.0;
      }
    }

    if (_slowTimer > 0) {
      _slowTimer -= dt;
      if (_slowTimer <= 0) {
        _slowTimer = 0;
        _slowFactor = 1.0;
      }
    }

    if (_isShaking) {
      _shakeTimer -= dt;
      if (_shakeTimer <= 0) {
        _isShaking = false;
        camera.viewfinder.position = Vector2.zero();
      } else {
        camera.viewfinder.position = Vector2(
          (_rng.nextDouble() - 0.5) * _shakeIntensity,
          (_rng.nextDouble() - 0.5) * _shakeIntensity,
        );
      }
    }

    final diff = config.difficultyConfig;
    final levelBonus = LevelConfig.speedBonusForLevel(level);
    final maxSpeed = diff.startSpeed * 3.0 + levelBonus;
    currentSpeed = (currentSpeed + diff.speedRamp * dt).clamp(0, maxSpeed);
    hud.updateSpeed(currentSpeed);

    distanceMeters += scrollSpeed * dt / LevelConfig.pxPerMeter;
    hud.updateDistance(distanceMeters.toInt(), distanceForLevelTarget);

    if (distanceMeters >= distanceForLevelTarget) {
      _advanceLevel();
    }

    if (distanceMeters - _lastRefillMeters >= LevelConfig.paperRefillMeters) {
      _lastRefillMeters = distanceMeters;
      if (papers < maxPapers) {
        papers++;
        paperCountNotifier.value = papers;
        hud.updatePaperCount(papers, maxPapers);
      }
    }
  }

  void _advanceLevel() {
    distanceMeters = 0;
    level = (level + 1).clamp(1, LevelConfig.maxLevel);
    currentSpeed += 20;
    overlays.add('LevelUp');
    Future.delayed(const Duration(milliseconds: 1100), () {
      overlays.remove('LevelUp');
    });
    hud.updateLevel(level);
    hud.updateDistance(0, distanceForLevelTarget);
  }

  void onSwipeLeft() {
    if (state != GameState.playing) return;
    player.moveLeft();
  }

  void onSwipeRight() {
    if (state != GameState.playing) return;
    player.moveRight();
  }

  void onThrowTapped() {
    if (state != GameState.playing) return;
    _throwPaper();
  }

  void onTap() {
    if (state != GameState.playing) return;
    _throwPaper();
  }

  void _throwPaper() {
    if (papers <= 0) return;
    papers--;
    paperCountNotifier.value = papers;
    hud.updatePaperCount(papers, maxPapers);

    if (config.paperBlitz) {
      for (final a in const [-18.0, 0.0, 18.0]) {
        add(PaperComponent(
          startPosition: player.position.clone(),
          angleDeg: a,
        ));
      }
    } else {
      add(PaperComponent(startPosition: player.position.clone()));
    }
  }

  void onPaperHitMailbox(bool isBlue, Vector2 position) {
    comboCount++;
    if (comboCount > bestComboThisRun) bestComboThisRun = comboCount;
    final mult = comboMultiplier(comboCount);
    final base = isBlue ? 10 : 25;
    final pts = base * mult;

    final coinsBase = isBlue ? 1 : 3;
    final coinMult = config.difficultyConfig.coinMultiplier *
        (config.doubleCoins ? 2 : 1);
    final coins = (coinsBase * coinMult).round();

    _addScore(pts, position, isBlue: isBlue);
    coinsThisRun += coins;
    hud.updateCoins(coinsThisRun);
    hud.updateCombo(comboCount);
    AudioService.instance.playDelivery();
  }

  void _addScore(int delta, Vector2 position, {required bool isBlue}) {
    score = (score + delta).clamp(0, 999999);
    hud.updateScore(score);

    final label = delta > 0 ? '+$delta' : '$delta';
    add(FloatingText(
      text: label,
      position: position,
      color: isBlue ? const Color(0xFF66BB6A) : const Color(0xFFFFB74D),
    ));
  }

  void onPlayerHitObstacle() {
    if (isInvincible || state != GameState.playing) return;

    lives--;
    isInvincible = true;
    invincibilityTimer = 1.5;
    comboCount = 0;
    hud.updateCombo(0);
    hud.updateLives(lives);

    _triggerShake();
    AudioService.instance.playHit();

    if (lives <= 0) {
      _endGame();
    }
  }

  void onPlayerHitSlowObstacle() {
    if (state != GameState.playing) return;
    if (isInvincible) return;

    final diff = config.difficultyConfig;
    final maxSpeed = diff.startSpeed * 3.0;
    if (currentSpeed >= maxSpeed - 5) {
      onPlayerHitObstacle();
      return;
    }
    _slowFactor = 0.5;
    _slowTimer = 1.5;
    _triggerShake();
  }

  void _triggerShake() {
    _isShaking = true;
    _shakeTimer = _shakeDuration;
  }

  Future<void> _endGame() async {
    state = GameState.gameOver;
    AudioService.instance.playGameOver();
    AudioService.instance.stopBgm();

    final isNewRecord = await ScoreService.instance.submitScore(score);
    final highScore = await ScoreService.instance.getHighScore();
    final earned = coinsThisRun;
    await StoreService.instance.addCoins(earned);

    Future.microtask(() => onGameOver?.call(
          score,
          highScore,
          isNewRecord,
          earned,
          bestComboThisRun,
          level,
        ));
  }
}
