import 'dart:math';
import 'dart:ui' as ui;
import 'package:flame/components.dart';
import '../delivery_dash_game.dart';
import 'parked_car.dart' show renderTopDownCar;

/// Crossroads — the main road continues, a cross-street goes left/right.
/// Renders zebra crossing, traffic-light poles, "STOP" on approach,
/// and lets [CrossingCarComponent]s drive across.
class IntersectionComponent extends PositionComponent
    with HasGameRef<DeliveryDashGame> {
  static const double bandHeight = 110;

  final Random _rng = Random();
  double _spawnTimer = 0;
  bool _spawnedFirst = false;
  bool _spawnedPedestrians = false;

  IntersectionComponent()
      : super(
          size: Vector2(0, bandHeight),
          anchor: Anchor.topLeft,
          priority: -8,
        );

  @override
  Future<void> onLoad() async {
    size = Vector2(gameRef.size.x, bandHeight);
    position = Vector2(0, -bandHeight);
  }

  @override
  void update(double dt) {
    super.update(dt);
    if (gameRef.state != GameState.playing) return;
    position.y += gameRef.scrollSpeed * dt;

    final onScreen = position.y + bandHeight > 0 && position.y < gameRef.size.y;
    if (onScreen) {
      if (!_spawnedFirst) {
        _spawnedFirst = true;
        _spawnCar();
      }
      if (!_spawnedPedestrians) {
        _spawnedPedestrians = true;
        _spawnPedestrians();
      }
      _spawnTimer += dt;
      if (_spawnTimer >= 0.8) {
        _spawnTimer = 0;
        if (_rng.nextDouble() < 0.7) _spawnCar();
      }
    }
    if (position.y > gameRef.size.y) removeFromParent();
  }

  void _spawnCar() {
    final leftToRight = _rng.nextBool();
    gameRef.add(CrossingCarComponent(
      bandY: position.y + bandHeight / 2,
      leftToRight: leftToRight,
      variant: _rng.nextInt(2),
    ));
  }

  void _spawnPedestrians() {
    // 2-3 pedestrians walking across the road on the zebra crossing.
    final count = 2 + _rng.nextInt(2);
    for (int i = 0; i < count; i++) {
      final leftToRight = _rng.nextBool();
      gameRef.add(CrossingPedestrianComponent(
        bandY: position.y + bandHeight * 0.5 + (i - count / 2) * 12,
        leftToRight: leftToRight,
        delay: i * 0.4,
      ));
    }
  }

  @override
  void render(Canvas canvas) {
    final h = size.y;
    final lm = gameRef.laneManager;

    final topY = position.y;
    final botY = position.y + h;
    final leftTop = lm.roadLeftAt(topY);
    final rightTop = lm.roadRightAt(topY);
    final leftBot = lm.roadLeftAt(botY);
    final rightBot = lm.roadRightAt(botY);

    // ── Cross-street asphalt — only in sidewalk strips, NOT over the road ──
    final asphaltPaint = Paint()..color = const Color(0xFF2A2A2A);
    // Left sidewalk trapezoid
    final leftPath = Path()
      ..moveTo(0, 0)
      ..lineTo(leftTop, 0)
      ..lineTo(leftBot, h)
      ..lineTo(0, h)
      ..close();
    canvas.drawPath(leftPath, asphaltPaint);
    // Right sidewalk trapezoid
    final rightPath = Path()
      ..moveTo(rightTop, 0)
      ..lineTo(size.x, 0)
      ..lineTo(size.x, h)
      ..lineTo(rightBot, h)
      ..close();
    canvas.drawPath(rightPath, asphaltPaint);

    // Subtle perspective shading — top slightly lighter.
    canvas.drawRect(
      Rect.fromLTWH(0, 0, size.x, h),
      Paint()
        ..shader = ui.Gradient.linear(
          const Offset(0, 0),
          Offset(0, h),
          const [Color(0x33FFFFFF), Color(0x00FFFFFF)],
        ),
    );

    // Yellow dashed lane line down centre of the cross-street.
    final yellowPaint = Paint()..color = const Color(0xFFFFD600);
    double cx = 0;
    while (cx < size.x) {
      canvas.drawRect(
        Rect.fromLTWH(cx, h * 0.48, 16, 4),
        yellowPaint,
      );
      cx += 28;
    }

    // ── Zebra crossing stripes — only across the main road's width ────────
    final stripePaint = Paint()..color = const Color(0xFFFFFFFF);
    const stripeW = 16.0;
    const stripeGap = 10.0;
    const stripeBandH = 18.0;
    // Stripes at top edge of intersection (entering from far away).
    var sx = leftTop + 4;
    while (sx + stripeW < rightTop - 4) {
      canvas.drawRect(
        Rect.fromLTWH(sx, 4, stripeW, stripeBandH),
        stripePaint,
      );
      sx += stripeW + stripeGap;
    }
    // Stripes at bottom edge (entering from close).
    sx = leftBot + 4;
    while (sx + stripeW < rightBot - 4) {
      canvas.drawRect(
        Rect.fromLTWH(sx, h - stripeBandH - 4, stripeW, stripeBandH),
        stripePaint,
      );
      sx += stripeW + stripeGap;
    }

    // ── "STOP" text on the road surface just below the bottom crossing ────
    // Render only when the bottom of the intersection is well within the
    // viewport, so the text reads properly.
    if (position.y + h> gameRef.size.y * 0.2 &&
        position.y + h < gameRef.size.y * 0.95) {
      // STOP text painted directly on road surface
      final cx = lm.roadCenterAt(position.y + h - 10);
      _drawStopText(canvas, cx, h - 26);
    }
  }

  void _drawStopText(Canvas canvas, double cx, double y) {
    // Simple geometric STOP letters
    final p = Paint()
      ..color = const Color(0xFFFFFFFF)
      ..strokeWidth = 2.5
      ..strokeCap = StrokeCap.square;
    final letters = ['S', 'T', 'O', 'P'];
    double lx = cx - 26.0;
    for (final letter in letters) {
      _drawLetter(canvas, p, lx, y, letter);
      lx += 14.0;
    }
  }

  void _drawLetter(Canvas canvas, Paint p, double x, double y, String l) {
    // Each letter is 10w x 12h
    const w = 10.0;
    const h = 12.0;
    switch (l) {
      case 'S':
        canvas.drawLine(Offset(x + w, y), Offset(x, y), p);
        canvas.drawLine(Offset(x, y), Offset(x, y + h / 2), p);
        canvas.drawLine(Offset(x, y + h / 2), Offset(x + w, y + h / 2), p);
        canvas.drawLine(Offset(x + w, y + h / 2), Offset(x + w, y + h), p);
        canvas.drawLine(Offset(x + w, y + h), Offset(x, y + h), p);
        break;
      case 'T':
        canvas.drawLine(Offset(x, y), Offset(x + w, y), p);
        canvas.drawLine(Offset(x + w / 2, y), Offset(x + w / 2, y + h), p);
        break;
      case 'O':
        canvas.drawLine(Offset(x, y), Offset(x + w, y), p);
        canvas.drawLine(Offset(x, y), Offset(x, y + h), p);
        canvas.drawLine(Offset(x + w, y), Offset(x + w, y + h), p);
        canvas.drawLine(Offset(x, y + h), Offset(x + w, y + h), p);
        break;
      case 'P':
        canvas.drawLine(Offset(x, y), Offset(x, y + h), p);
        canvas.drawLine(Offset(x, y), Offset(x + w, y), p);
        canvas.drawLine(Offset(x + w, y), Offset(x + w, y + h / 2), p);
        canvas.drawLine(Offset(x, y + h / 2), Offset(x + w, y + h / 2), p);
        break;
      default:
        break;
    }
  }
}

/// A car that drives horizontally across the intersection band.
class CrossingCarComponent extends PositionComponent
    with HasGameRef<DeliveryDashGame> {
  final bool leftToRight;
  final int variant;
  late double _bandY;
  static const double _carSpeed = 160.0;
  static const double _carW = 52.0;
  static const double _carH = 26.0;

  CrossingCarComponent({
    required double bandY,
    required this.leftToRight,
    required this.variant,
  })  : _bandY = bandY,
        super(
          size: Vector2(_carW, _carH),
          anchor: Anchor.center,
          priority: 2,
        );

  @override
  Future<void> onLoad() async {
    final startX = leftToRight ? -_carW : gameRef.size.x + _carW;
    position = Vector2(startX, _bandY);
  }

  @override
  void update(double dt) {
    super.update(dt);
    if (gameRef.state != GameState.playing) return;
    _bandY += gameRef.scrollSpeed * dt;
    final dx = leftToRight ? _carSpeed * dt : -_carSpeed * dt;
    position = Vector2(position.x + dx, _bandY);
    if (leftToRight && position.x > gameRef.size.x + _carW) {
      removeFromParent();
    } else if (!leftToRight && position.x < -_carW) {
      removeFromParent();
    }
    if (_bandY > gameRef.size.y + _carH) removeFromParent();
  }

  @override
  void render(Canvas canvas) {
    final colors = variant == 0
        ? [const Color(0xFF1565C0), const Color(0xFFE53935)]
        : [const Color(0xFF2E7D32), const Color(0xFFF57F17)];
    canvas.save();
    if (!leftToRight) {
      canvas.translate(size.x, 0);
      canvas.scale(-1, 1);
    }
    renderTopDownCar(canvas, size, colors[0], colors[1]);
    canvas.restore();
  }
}

/// A pedestrian walking across the zebra crossing.
class CrossingPedestrianComponent extends PositionComponent
    with HasGameRef<DeliveryDashGame> {
  final bool leftToRight;
  double _bandY;
  double _delayTimer;
  bool _active = false;
  double _walkTimer = 0;
  bool _step = false;

  CrossingPedestrianComponent({
    required double bandY,
    required this.leftToRight,
    required double delay,
  })  : _bandY = bandY,
        _delayTimer = delay,
        super(
          size: Vector2(14, 24),
          anchor: Anchor.center,
          priority: 3,
        );

  @override
  Future<void> onLoad() async {
    final startX = leftToRight ? -14.0 : gameRef.size.x + 14.0;
    position = Vector2(startX, _bandY);
  }

  @override
  void update(double dt) {
    super.update(dt);
    if (gameRef.state != GameState.playing) return;
    _bandY += gameRef.scrollSpeed * dt;

    if (!_active) {
      _delayTimer -= dt;
      if (_delayTimer <= 0) _active = true;
      position.y = _bandY;
      return;
    }

    const speed = 60.0;
    final dx = leftToRight ? speed * dt : -speed * dt;
    position = Vector2(position.x + dx, _bandY);

    _walkTimer += dt;
    if (_walkTimer >= 0.25) {
      _walkTimer = 0;
      _step = !_step;
    }

    if (leftToRight && position.x > gameRef.size.x + 20) removeFromParent();
    if (!leftToRight && position.x < -20) removeFromParent();
    if (_bandY > gameRef.size.y + 20) removeFromParent();
  }

  @override
  void render(Canvas canvas) {
    final w = size.x;
    final h = size.y;
    // Body
    canvas.drawRect(
      Rect.fromLTWH(w * 0.25, h * 0.30, w * 0.50, h * 0.45),
      Paint()..color = const Color(0xFF546E7A),
    );
    // Head
    canvas.drawCircle(
      Offset(w * 0.5, h * 0.18),
      h * 0.13,
      Paint()..color = const Color(0xFFFFCC99),
    );
    // Legs (walking animation)
    final legPaint = Paint()
      ..color = const Color(0xFF37474F)
      ..strokeWidth = 3.0
      ..strokeCap = StrokeCap.round;
    final phase = _step ? 1.0 : -1.0;
    canvas.drawLine(
      Offset(w * 0.38, h * 0.75),
      Offset(w * 0.30 + phase * 3, h * 0.95),
      legPaint,
    );
    canvas.drawLine(
      Offset(w * 0.62, h * 0.75),
      Offset(w * 0.70 - phase * 3, h * 0.95),
      legPaint,
    );
  }
}
