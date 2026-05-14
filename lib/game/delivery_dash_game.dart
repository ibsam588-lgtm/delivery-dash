import 'dart:math';
import 'package:flame/components.dart';
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
  int coinsThisRun = 0;
  double currentSpeed = 200;
  bool isInvincible = false;
  double invincibilityTimer = 0;

  late LaneManager laneManager;
  late PlayerComponent player;
  late Hud hud;

  bool _isShaking = false;
  double _shakeTimer = 0;
  static const double _shakeDuration = 0.2;
  static const double _shakeIntensity = 6.0;
  final Random _rng = Random();

  static bool _hasShownTutorial = false;

  void Function(int score, int highScore, bool isNewRecord, int coinsEarned)?
      onGameOver;

  DeliveryDashGame({this.config = const GameConfig()});

  double get scrollSpeed => currentSpeed;

  @override
  Color backgroundColor() => const Color(0xFF1E1E1E);

  @override
  Future<void> onLoad() async {
    await super.onLoad();
    laneManager = LaneManager(gameSize: size);
    await _preloadAssets();
    _initGame();
  }

  Future<void> _preloadAssets() async {
    await images.loadAll([
      'player.png',
      'paper.png',
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
    ]);
    await AudioService.instance.init();
  }

  void _initGame() {
    final diff = config.difficultyConfig;

    score = 0;
    lives = 3 + (config.hasShield ? 1 : 0);
    comboCount = 0;
    coinsThisRun = 0;
    currentSpeed = diff.startSpeed + (config.speedBoostStart ? 60 : 0);
    isInvincible = false;
    state = GameState.playing;

    add(RoadBackground(gameSize: size));

    const houseSpacing = 128.0;
    final rng = Random();
    final rowsPerSide = (size.y / houseSpacing).ceil() + 2;
    for (int i = 0; i < rowsPerSide; i++) {
      add(HouseComponent(
        side: HouseSide.left,
        initialY: i * houseSpacing - houseSpacing,
        variant: rng.nextInt(4),
      ));
      add(HouseComponent(
        side: HouseSide.right,
        initialY: i * houseSpacing - houseSpacing / 2,
        variant: rng.nextInt(4),
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

    // Speed ramps over time
    final diff = config.difficultyConfig;
    final maxSpeed = diff.startSpeed * 3.0;
    currentSpeed = (currentSpeed + diff.speedRamp * dt).clamp(0, maxSpeed);
    hud.updateSpeed(currentSpeed);
  }

  // ── Input ────────────────────────────────────────────────────────────────

  void onSwipeLeft() {
    if (state != GameState.playing) return;
    player.moveLeft();
  }

  void onSwipeRight() {
    if (state != GameState.playing) return;
    player.moveRight();
  }

  void onTap() {
    if (state != GameState.playing) return;
    _throwPaper();
  }

  void _throwPaper() {
    if (config.paperBlitz) {
      for (final a in const [-12.0, 0.0, 12.0]) {
        add(PaperComponent(
          startPosition: player.position.clone(),
          angleDeg: a,
        ));
      }
    } else {
      add(PaperComponent(startPosition: player.position.clone()));
    }
  }

  // ── Game events ──────────────────────────────────────────────────────────

  void onPaperHitMailbox(bool isBlue, Vector2 position) {
    if (isBlue) {
      comboCount++;
      final bonus = comboCount >= 3 ? 20 : 10;
      _addScore(bonus, position, isBlue: true);
      hud.updateCombo(comboCount);

      int coins = comboCount;
      if (config.doubleCoins) coins *= 2;
      coinsThisRun += coins;
      hud.updateCoins(coinsThisRun);

      AudioService.instance.playDelivery();
    } else {
      comboCount = 0;
      _addScore(-5, position, isBlue: false);
      hud.updateCombo(0);
    }
  }

  void _addScore(int delta, Vector2 position, {required bool isBlue}) {
    score = (score + delta).clamp(0, 999999);
    hud.updateScore(score);

    String label = delta > 0 ? '+$delta' : '$delta';
    if (comboCount >= 3 && isBlue) label += ' COMBO!';

    add(FloatingText(
      text: label,
      position: position,
      color: isBlue ? Colors.greenAccent : Colors.redAccent,
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

    Future.microtask(
        () => onGameOver?.call(score, highScore, isNewRecord, earned));
  }
}
