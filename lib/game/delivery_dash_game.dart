import 'dart:math';
import 'package:flame/flame.dart';
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
  int day = 1;
  double distanceMeters = 0;
  int papers = 5;

  double currentSpeed = 200;
  double _slowFactor = 1.0;
  double _slowTimer = 0;
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

  void Function(
    int score,
    int highScore,
    bool isNewRecord,
    int coinsEarned,
    int bestCombo,
    int daysCompleted,
  )? onGameOver;

  DeliveryDashGame({this.config = const GameConfig()});

  double get scrollSpeed => currentSpeed * _slowFactor;

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
    await Flame.images.loadAll([
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
    try {
      await AudioService.instance.init();
    } catch (_) {}
  }

  void _initGame() {
    score = 0;
    lives = config.lives + (config.hasShield ? 1 : 0);
    comboCount = 0;
    bestComboThisRun = 0;
    coinsThisRun = 0;
    day = config.startDay;
    distanceMeters = 0;
    final dayCfg = DayConfig.of(day);
    papers = dayCfg.papers;
    currentSpeed = dayCfg.startSpeed + (config.speedBoostStart ? 60 : 0);
    isInvincible = false;
    _slowFactor = 1.0;
    _slowTimer = 0;
    state = GameState.playing;

    add(RoadBackground(gameSize: size));

    final rows = (size.y / HouseComponent.rowSpacing).ceil() + 2;
    for (int i = 0; i < rows; i++) {
      add(HouseComponent(
        initialY: i * HouseComponent.rowSpacing - HouseComponent.rowSpacing,
        index: i,
      ));
    }

    player = PlayerComponent(isVip: config.vipSkin);
    add(player);

    hud = Hud();
    add(hud);
    hud.updateScore(0);
    hud.updateDay(day);
    hud.updateBonus(0);

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

    final dayCfg = DayConfig.of(day);
    final maxSpeed = dayCfg.startSpeed * 1.5;
    currentSpeed = (currentSpeed + 8 * dt).clamp(0, maxSpeed);

    distanceMeters += scrollSpeed * dt / DayConfig.pxPerMeter;
    if (distanceMeters >= DayConfig.metersPerDay) {
      _advanceDay();
    }
  }

  void _advanceDay() {
    distanceMeters = 0;
    if (day < DayConfig.days.length) {
      day += 1;
    }
    final cfg = DayConfig.of(day);
    currentSpeed = cfg.startSpeed;
    papers = cfg.papers;

    overlays.add('DayUp');
    Future.delayed(const Duration(milliseconds: 1200), () {
      overlays.remove('DayUp');
    });
    hud.updateDay(day);
  }

  // ── Input ─────────────────────────────────────────────────────────────

  void onDragMoveTo(double worldX) {
    if (state != GameState.playing) return;
    player.moveTo(worldX);
  }

  void onTap() {
    if (state != GameState.playing) return;
    _throwPaper();
  }

  void _throwPaper() {
    if (papers <= 0) return;
    papers--;

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

  // ── Events ────────────────────────────────────────────────────────────

  void onPaperHitMailbox(bool isBlue, Vector2 position) {
    if (!isBlue) {
      // Non-subscriber — no points, but no combo break either.
      return;
    }
    comboCount++;
    if (comboCount > bestComboThisRun) bestComboThisRun = comboCount;
    final mult = comboMultiplier(comboCount);
    const base = 10;
    final pts = base * mult;
    final bonus = pts - base;

    const coinsBase = 1;
    final coinMult =
        config.coinMultiplier * (config.doubleCoins ? 2 : 1);
    final coins = (coinsBase * coinMult).round();

    _addScore(pts, position, isBlue: true);
    coinsThisRun += coins;
    hud.updateBonus(bonus);
    AudioService.instance.playDelivery();
  }

  void _addScore(int delta, Vector2 position, {required bool isBlue}) {
    score = (score + delta).clamp(0, 999999);
    hud.updateScore(score);
    add(FloatingText(
      text: delta > 0 ? '+$delta' : '$delta',
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
    hud.updateBonus(0);

    _triggerShake();
    AudioService.instance.playHit();

    if (lives <= 0) _endGame();
  }

  void onPlayerHitSlowObstacle() {
    if (state != GameState.playing) return;
    if (isInvincible) return;

    final dayCfg = DayConfig.of(day);
    final maxSpeed = dayCfg.startSpeed * 1.5;
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
          day,
        ));
  }
}
