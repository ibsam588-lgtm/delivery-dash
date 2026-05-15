import 'dart:math';
import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import '../services/audio_service.dart';
import '../services/score_service.dart';
import '../services/store_service.dart';
import 'components/floating_text.dart';
import 'components/house.dart';
import 'components/house_window.dart';
import 'components/hud.dart';
import 'components/mailbox.dart';
import 'components/obstacle.dart';
import 'components/paper.dart';
import 'components/parked_car.dart';
import 'components/particle_burst.dart';
import 'components/player.dart';
import 'components/road_background.dart';
import 'difficulty.dart';
import 'systems/lane_manager.dart';
import 'systems/spawner.dart';

enum GameState { playing, paused, gameOver }

class DeliveryDashGame extends FlameGame with HasCollisionDetection {
  final GameConfig config;

  GameState state = GameState.playing;
  int score = 0;
  int lives = 3;
  int comboCount = 0;
  int bestComboThisRun = 0;
  int coinsThisRun = 0;
  int level = 1;
  int highestLevelThisRun = 1;
  double distanceMeters = 0;
  int papers = 5;
  int deliveredCount = 0;

  double currentSpeed = 200;
  double _slowFactor = 1.0;
  double _slowTimer = 0;
  double _zoneSlow = 1.0;
  bool isInvincible = false;
  double invincibilityTimer = 0;

  // Paper-hit screen flash (100ms white overlay at 10% opacity).
  double _hitFlashTimer = 0;
  static const double _hitFlashDuration = 0.1;

  late LaneManager laneManager;
  late PlayerComponent player;
  late Hud hud;

  bool _isShaking = false;
  double _shakeTimer = 0;
  double _shakeIntensity = 6.0;
  static const double _shakeDuration = 0.2;
  final Random _rng = Random();

  // Drench overlay (blue tint over the whole game).
  double _drenchTimer = 0;
  static const double _drenchDuration = 0.4;

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

  double get scrollSpeed => currentSpeed * _slowFactor * _zoneSlow;

  void applyConstructionSlow() {
    _zoneSlow = 0.7;
  }

  void clearConstructionSlow() {
    _zoneSlow = 1.0;
  }

  void _triggerHitFlash() {
    _hitFlashTimer = _hitFlashDuration;
  }

  @override
  Color backgroundColor() => const Color(0xFF101218);

  bool _initialized = false;

  @override
  Future<void> onLoad() async {
    await super.onLoad();
    // IMPORTANT: don't read `size` here. In Flame's lifecycle `size`
    // can still be Vector2.zero() until the first onGameResize fires.
    // We initialize the LaneManager and spawn the world in onMount,
    // which runs after the first layout pass.
    await _preloadAssets();
  }

  @override
  void onMount() {
    super.onMount();
    if (_initialized) return;
    _initialized = true;
    laneManager = LaneManager(gameSize: size);
    debugPrint(
        'DeliveryDash onMount: size=$size roadLeft=${laneManager.roadLeft} '
        'roadRight=${laneManager.roadRight}');
    _initGame();
  }

  Future<void> _preloadAssets() async {
    // All sprites are now drawn procedurally — no PNG assets to load.
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
    level = config.startLevel;
    highestLevelThisRun = level;
    distanceMeters = 0;
    deliveredCount = 0;
    final cfg = LevelConfig.of(level);
    currentSpeed = (cfg.startSpeed + (config.speedBoostStart ? 60 : 0)) *
        config.speedMultiplier;
    isInvincible = false;
    _slowFactor = 1.0;
    _slowTimer = 0;
    _zoneSlow = 1.0;
    _drenchTimer = 0;
    _hitFlashTimer = 0;
    state = GameState.playing;

    add(RoadBackground(gameSize: size));

    final rows = (size.y / HouseComponent.rowSpacing).ceil() + 2;
    for (int i = 0; i < rows; i++) {
      final y = i * HouseComponent.rowSpacing - HouseComponent.rowSpacing;
      // Left-side houses (even index) and right-side houses (odd offset).
      add(HouseComponent(initialY: y, index: i));
      add(HouseComponent(initialY: y, index: i + 1, onRight: true));
    }

    player = PlayerComponent(isVip: config.vipSkin);
    add(player);

    hud = Hud();
    add(hud);
    hud.updateScore(0);
    hud.updateLevel(level);
    hud.updateCoins(0);
    hud.updateLives(lives);
    hud.updateCombo(0, 1);

    add(Spawner());

    // Starting paper count is driven by difficulty (easy=30, med=20, hard=15).
    papers = config.papers;
    hud.updatePapers(papers);

    AudioService.instance.playBgm();

    if (!_hasShownTutorial) {
      _hasShownTutorial = true;
      overlays.add('Tutorial');
      Future.delayed(const Duration(seconds: 3), () {
        overlays.remove('Tutorial');
      });
    }
  }

  /// Count visible mailboxes currently within the viewport. Used by
  /// "smart paper count" logic.
  int countVisibleMailboxes() {
    final h = size.y;
    return descendants()
        .whereType<MailboxComponent>()
        .where((m) {
          final ap = m.absolutePosition;
          return ap.y >= 0 && ap.y <= h;
        })
        .length;
  }

  @override
  void update(double dt) {
    super.update(dt);
    if (state != GameState.playing) return;

    if (isInvincible) {
      invincibilityTimer -= dt;
      if (invincibilityTimer <= 0) {
        isInvincible = false;
      }
    }

    if (_slowTimer > 0) {
      _slowTimer -= dt;
      if (_slowTimer <= 0) {
        _slowTimer = 0;
        _slowFactor = 1.0;
      }
    }

    if (_drenchTimer > 0) {
      _drenchTimer = (_drenchTimer - dt).clamp(0.0, _drenchDuration);
    }

    if (_hitFlashTimer > 0) {
      _hitFlashTimer = (_hitFlashTimer - dt).clamp(0.0, _hitFlashDuration);
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

    final cfg = LevelConfig.of(level);
    final maxSpeed = cfg.startSpeed * 1.5 * config.speedMultiplier;
    currentSpeed = (currentSpeed + 8 * dt).clamp(0, maxSpeed);

    distanceMeters += scrollSpeed * dt / LevelConfig.pxPerMeter;
    if (distanceMeters >= LevelConfig.metersPerLevel) {
      _advanceLevel();
    }
  }

  @override
  void render(Canvas canvas) {
    super.render(canvas);
    // Drench screen overlay (drawn over everything, including HUD).
    if (_drenchTimer > 0) {
      final phase = _drenchTimer / _drenchDuration; // 1 -> 0
      final alpha = (1 - (phase - 0.5).abs() * 2) * 0.4;
      canvas.drawRect(
        Rect.fromLTWH(0, 0, size.x, size.y),
        Paint()..color = const Color(0xFF42A5F5).withValues(alpha: alpha),
      );
    }
    // Brief white screen flash on paper hits (100ms, 10% opacity).
    if (_hitFlashTimer > 0) {
      final alpha = (_hitFlashTimer / _hitFlashDuration) * 0.10;
      canvas.drawRect(
        Rect.fromLTWH(0, 0, size.x, size.y),
        Paint()..color = const Color(0xFFFFFFFF).withValues(alpha: alpha),
      );
    }
  }

  void _advanceLevel() {
    distanceMeters = 0;
    deliveredCount = 0;
    hud.updateDelivery(0);
    if (level < LevelConfig.maxLevel) {
      level += 1;
      if (level > highestLevelThisRun) highestLevelThisRun = level;
    }
    final cfg = LevelConfig.of(level);
    currentSpeed = cfg.startSpeed * config.speedMultiplier;

    // Smart-paper allotment: visible mailboxes + 3, scaled by difficulty.
    final visible = countVisibleMailboxes();
    final diffPapers = config.papers;
    papers = (visible + 3).clamp(diffPapers, diffPapers + 5);
    hud.updatePapers(papers);

    AudioService.instance.playLevelUp();
    overlays.add('LevelUp');
    Future.delayed(const Duration(milliseconds: 1200), () {
      overlays.remove('LevelUp');
    });
    hud.updateLevel(level);
  }

  // ── Input ─────────────────────────────────────────────────────────────

  void onDragMoveTo(double worldX) {
    if (state != GameState.playing) return;
    player.moveTo(worldX);
  }

  void onTap(double tapX) {
    if (state != GameState.playing) return;
    _throwPaper(throwLeft: tapX < size.x / 2);
  }

  /// Pause / resume. Used by the back-button dialog.
  void pauseGame() {
    if (state == GameState.playing) {
      state = GameState.paused;
      AudioService.instance.pauseBgm();
    }
  }

  void resumeGame() {
    if (state == GameState.paused) {
      state = GameState.playing;
      AudioService.instance.resumeBgm();
    }
  }

  void _throwPaper({required bool throwLeft}) {
    if (papers <= 0) {
      return;
    }
    papers--;
    hud.updatePapers(papers);
    player.triggerThrowArm(throwLeft: throwLeft);

    // Negative angle = throw toward the left sidewalk; positive = right.
    final baseAngle = throwLeft ? -38.0 : 38.0;
    if (config.paperBlitz) {
      // Spread 3 papers in a fan on the chosen side.
      for (final offset in const [-18.0, 0.0, 18.0]) {
        add(PaperComponent(
          startPosition: player.position.clone(),
          angleDeg: baseAngle + offset,
        ));
      }
    } else {
      add(PaperComponent(
        startPosition: player.position.clone(),
        angleDeg: baseAngle,
      ));
    }
  }

  // ── Pickups ───────────────────────────────────────────────────────────

  void onPickupPaperPack(int amount, Vector2 position) {
    papers += amount;
    hud.updatePapers(papers);
    AudioService.instance.playPickup();
    add(FloatingText(
      text: '+$amount 📰',
      position: position,
      color: const Color(0xFFFFD54F),
    ));
  }

  // ── Events ────────────────────────────────────────────────────────────

  void onPaperHitMailbox(bool isBlue, Vector2 position) {
    if (isBlue) {
      // Good delivery — combo + score + coins.
      comboCount++;
      deliveredCount++;
      hud.updateDelivery(deliveredCount);
      if (comboCount > bestComboThisRun) bestComboThisRun = comboCount;
      final mult = comboMultiplier(comboCount);
      const base = 15;
      final pts = base * mult;
      final bonus = pts - base;

      const coinsBase = 1;
      final coinMult =
          config.coinMultiplier * (config.doubleCoins ? 2 : 1);
      final coins = (coinsBase * coinMult).round();

      _addScore(pts, position, color: const Color(0xFF66BB6A));
      coinsThisRun += coins;
      hud.updateCoins(coinsThisRun);
      hud.updateCombo(comboCount, mult);
      add(ParticleBurst(
        position: position,
        color: const Color(0xFFFFEB3B),
        color2: const Color(0xFF66BB6A),
        count: 14,
        spread: 140,
      ));
      if (bonus > 0) {
        add(FloatingText(
          text: '+$bonus BONUS',
          position: position - Vector2(0, 18),
          color: const Color(0xFFFFEB3B),
        ));
      }
      AudioService.instance.playDelivery();
      hud.updateBonus(bonus);
    } else {
      // Red (forbidden) mailbox — penalty, no combo, no coins.
      const penalty = 10;
      score = (score - penalty).clamp(0, 999999);
      hud.updateScore(score);
      add(FloatingText(
        text: '-$penalty',
        position: position,
        color: const Color(0xFFFF5252),
      ));
      add(ParticleBurst(
        position: position,
        color: const Color(0xFFEF5350),
        color2: const Color(0xFFFFCDD2),
        count: 10,
        spread: 110,
      ));
      // Reset combo on bad hit.
      comboCount = 0;
      hud.updateCombo(0, 1);
      AudioService.instance.playHit();
    }
    _triggerHitFlash();
  }

  /// Paper hit a non-mailbox obstacle. Trigger particle, score popup,
  /// stagger animation on the obstacle, and SFX.
  void onPaperHitObstacle(ObstacleComponent obstacle, Vector2 position) {
    obstacle.onHitByPaper();
    final pts = obstacle.paperHitPoints;
    if (pts > 0) {
      _addScore(pts, position, color: const Color(0xFFFFB74D));
    }
    // Cars: glass shatter; everything else: dust + hit thud.
    if (obstacle.type == ObstacleType.car) {
      add(GlassShardBurst(position: position));
      add(ParticleBurst(
        position: position,
        color: const Color(0xFFB3E5FC),
        color2: const Color(0xFFFFFFFF),
        count: 10,
        spread: 110,
      ));
      AudioService.instance.playWindowSmash();
    } else {
      add(ParticleBurst(
        position: position,
        color: const Color(0xFFFFFFFF),
        color2: const Color(0xFFFFD600),
        count: 8,
        spread: 90,
      ));
      AudioService.instance.playHit();
    }
    _triggerHitFlash();
  }

  /// Paper hit (and broke) a house window. Glass shard burst + light
  /// particle burst, small score bonus, no combo impact.
  void onPaperHitWindow(HouseWindow window, Vector2 position) {
    window.breakWindow(position);
    _addScore(HouseWindow.bonusPoints, position,
        color: const Color(0xFFB3E5FC));
    add(GlassShardBurst(position: position));
    add(ParticleBurst(
      position: position,
      color: const Color(0xFFB3E5FC),
      color2: const Color(0xFFFFFFFF),
      count: 8,
      spread: 100,
      pixelSize: 2,
    ));
    AudioService.instance.playWindowSmash();
    _triggerHitFlash();
  }

  /// Paper hit a parked car. Bonus points, particle, no penalty.
  void onPaperHitParkedCar(ParkedCarComponent car, Vector2 position) {
    final wasAlreadyHit = car.windowBroken;
    car.onPaperHit();
    _addScore(ParkedCarComponent.bonusPoints, position,
        color: const Color(0xFFFFD600));
    add(ParticleBurst(
      position: position,
      color: const Color(0xFFB3E5FC),
      color2: const Color(0xFFFFFFFF),
      count: 12,
      spread: 110,
    ));
    // First hit: glass smash sound + glass shards.
    if (!wasAlreadyHit) {
      add(GlassShardBurst(position: position));
      AudioService.instance.playWindowSmash();
    } else {
      AudioService.instance.playPickup();
    }
    _triggerHitFlash();
  }

  void _addScore(int delta, Vector2 position, {required Color color}) {
    score = (score + delta).clamp(0, 999999);
    hud.updateScore(score);
    add(FloatingText(
      text: delta > 0 ? '+$delta' : '$delta',
      position: position,
      color: color,
    ));
  }

  void onPlayerHitObstacle() {
    if (isInvincible || state != GameState.playing) return;

    lives--;
    isInvincible = true;
    invincibilityTimer = 1.5;
    comboCount = 0;
    hud.updateLives(lives);
    hud.updateCombo(0, 1);

    _triggerShake(intensity: 8.0);
    AudioService.instance.playHit();

    if (lives <= 0) _endGame();
  }

  void onPlayerHitSlowObstacle() {
    if (state != GameState.playing) return;
    if (isInvincible) return;

    final cfg = LevelConfig.of(level);
    final maxSpeed = cfg.startSpeed * 1.5;
    if (currentSpeed >= maxSpeed - 5) {
      onPlayerHitObstacle();
      return;
    }
    _slowFactor = 0.5;
    _slowTimer = 1.5;
    _triggerShake(intensity: 5.0);
  }

  void onPlayerDrenched() {
    if (state != GameState.playing) return;
    if (isInvincible) return;
    _slowFactor = 0.5;
    _slowTimer = 2.0;
    _drenchTimer = _drenchDuration;
    player.triggerWetFlash();
    AudioService.instance.playSplash();
    _triggerShake(intensity: 5.0);
  }

  void _triggerShake({double intensity = 6.0}) {
    _isShaking = true;
    _shakeTimer = _shakeDuration;
    _shakeIntensity = intensity;
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
          highestLevelThisRun,
        ));
  }
}
