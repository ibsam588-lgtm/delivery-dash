import 'dart:math';
import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import '../services/audio_service.dart';
import '../services/score_service.dart';
import 'components/player.dart';
import 'components/paper.dart';
import 'components/floating_text.dart';
import 'components/hud.dart';
import 'components/house.dart';
import 'components/road_background.dart';
import 'systems/lane_manager.dart';
import 'systems/spawner.dart';

enum GameState { playing, gameOver }

class DeliveryDashGame extends FlameGame with HasCollisionDetection {
  // Public state read by components and screens
  GameState state = GameState.playing;
  int score = 0;
  int lives = 3;
  int comboCount = 0;
  double speedMultiplier = 1.0;
  bool isInvincible = false;
  double invincibilityTimer = 0;

  late LaneManager laneManager;
  late PlayerComponent player;
  late Hud hud;

  // Camera shake
  bool _isShaking = false;
  double _shakeTimer = 0;
  static const double _shakeDuration = 0.2;
  static const double _shakeIntensity = 5.0;
  final Random _rng = Random();

  // Tutorial
  static bool _hasShownTutorial = false;

  // Callback set by GameScreen
  void Function(int score, int highScore, bool isNewRecord)? onGameOver;

  double get scrollSpeed => 200.0 * speedMultiplier;

  @override
  Color backgroundColor() => const Color(0xFF2E7D32);

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
    score = 0;
    lives = 3;
    comboCount = 0;
    speedMultiplier = 1.0;
    isInvincible = false;
    state = GameState.playing;

    // Road background
    add(RoadBackground(gameSize: size));

    // Scrolling houses on both sides
    for (int i = 0; i < 7; i++) {
      add(HouseComponent(
        side: HouseSide.left,
        initialY: i * 140.0 - 200,
        houseIndex: i % 4,
      ));
      add(HouseComponent(
        side: HouseSide.right,
        initialY: i * 140.0 - 240,
        houseIndex: (i + 2) % 4,
      ));
    }

    player = PlayerComponent();
    add(player);

    hud = Hud();
    add(hud);

    add(Spawner());

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

    // Invincibility countdown
    if (isInvincible) {
      invincibilityTimer -= dt;
      if (invincibilityTimer <= 0) {
        isInvincible = false;
        player.opacity = 1.0;
      }
    }

    // Screen shake
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

    // Speed ramps up every 500 points
    final targetSpeed = 1.0 + (score / 500.0) * 0.25;
    if (targetSpeed > speedMultiplier) {
      speedMultiplier = targetSpeed.clamp(1.0, 3.0);
    }
  }

  // ── Input handlers called by GameScreen ──────────────────────────────────

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
    add(PaperComponent(startPosition: player.position.clone()));
    AudioService.instance.playThrow();
  }

  // ── Game events ──────────────────────────────────────────────────────────

  void onPaperHitMailbox(bool isBlue, Vector2 position) {
    if (isBlue) {
      comboCount++;
      final bonus = comboCount >= 3 ? 20 : 10;
      _addScore(bonus, position, isBlue: true);
      hud.updateCombo(comboCount);
      AudioService.instance.playHit();
    } else {
      comboCount = 0;
      _addScore(-5, position, isBlue: false);
      hud.updateCombo(0);
      AudioService.instance.playMiss();
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
    if (isInvincible) return;

    lives--;
    isInvincible = true;
    invincibilityTimer = 1.5;
    comboCount = 0;
    hud.updateCombo(0);
    hud.updateLives(lives);

    _triggerShake();
    AudioService.instance.playHurt();

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

    final isNewRecord = await ScoreService.instance.submitScore(score);
    final highScore = await ScoreService.instance.getHighScore();

    // Defer to avoid calling navigator from within the game update loop
    Future.microtask(() => onGameOver?.call(score, highScore, isNewRecord));
  }
}
