import 'dart:math';
import 'dart:ui';
import 'package:flame/collisions.dart';
import 'package:flame/components.dart';
import '../delivery_dash_game.dart';
import '../difficulty.dart';
import 'bike_trail.dart';

class PlayerComponent extends PositionComponent
    with HasGameRef<DeliveryDashGame>, CollisionCallbacks {
  static const Color vipTint = Color(0x88FFD54F);
  static const double _followSpeed = 8.0;
  static const double _flashInterval = 0.1;
  static const double _trailInterval = 0.08;
  static const double _pedalInterval = 0.22;
  static const double _swayAmplitudeDeg = 0.8;
  static const double _swayHz = 1.35;
  static const double _throwArmDuration = 0.20;
  static const double _wetDuration = 0.4;
  static const double _normalCrashDuration = 0.95;
  static const double _hardCrashDuration = 1.45;

  final bool isVip;
  final CourierAvatar avatar;
  final String outfitId;
  final String bikeId;
  double _targetX = 0;
  double _flashTimer = 0;
  double _trailTimer = 0;
  double _opacity = 1.0;
  double _wetTimer = 0;
  double _pedalTimer = 0;
  bool _pedalPhase = false;
  bool _throwLeft = true;
  double _swayTimer = 0;
  double _throwArmTimer = 0;
  double _crashTimer = 0;
  double _crashDuration = _normalCrashDuration;
  double _crashDir = 1;
  bool _hardCrash = false;

  PlayerComponent({
    this.isVip = false,
    this.avatar = CourierAvatar.girl,
    this.outfitId = 'outfit_classic',
    this.bikeId = 'bike_classic',
  }) : super(size: Vector2(68, 90), anchor: Anchor.center, priority: 100);

  double get opacity => _opacity;
  set opacity(double v) => _opacity = v.clamp(0.0, 1.0);

  void triggerThrowArm({bool throwLeft = true}) {
    _throwLeft = throwLeft;
    _throwArmTimer = _throwArmDuration;
  }

  void triggerCrash({double direction = 1, bool hard = false}) {
    _hardCrash = hard;
    _crashDuration = hard ? _hardCrashDuration : _normalCrashDuration;
    _crashTimer = _crashDuration;
    _crashDir = direction >= 0 ? 1 : -1;
  }

  @override
  Future<void> onLoad() async {
    position = Vector2(gameRef.size.x * 0.5, gameRef.size.y * 0.80);
    _targetX = position.x;
    add(RectangleHitbox(
      size: Vector2(28, 56),
      position: Vector2((size.x - 28) / 2, (size.y - 56) / 2 + 6),
    ));
  }

  void moveTo(double worldX) {
    final roadY = gameRef.size.y * 0.80;
    _targetX =
        gameRef.laneManager.clampToRideableAt(roadY, worldX, size.x * 0.42);
  }

  void triggerWetFlash() {
    _wetTimer = _wetDuration;
  }

  @override
  void update(double dt) {
    super.update(dt);
    _swayTimer += dt;
    _pedalTimer += dt;
    if (_pedalTimer >= _pedalInterval) {
      _pedalTimer = 0;
      _pedalPhase = !_pedalPhase;
    }
    if (_throwArmTimer > 0) {
      _throwArmTimer = (_throwArmTimer - dt).clamp(0.0, _throwArmDuration);
    }
    if (_crashTimer > 0) {
      _crashTimer = (_crashTimer - dt).clamp(0.0, _crashDuration);
    }

    final dx = _targetX - position.x;
    final t = (_followSpeed * dt).clamp(0.0, 1.0);
    position.x += dx * t;
    position.y = gameRef.size.y * 0.80;
    position.x = gameRef.laneManager
        .clampToRideableAt(position.y, position.x, size.x * 0.42);

    if (_wetTimer > 0) {
      _wetTimer = (_wetTimer - dt).clamp(0.0, _wetDuration);
    }

    if (gameRef.isInvincible) {
      _flashTimer += dt;
      if (_flashTimer >= _flashInterval) {
        _flashTimer = 0;
        _opacity = _opacity > 0.5 ? 0.25 : 1.0;
      }
    } else {
      _flashTimer = 0;
      _opacity = 1.0;
    }

    if (gameRef.state == GameState.playing && _crashTimer <= 0) {
      _trailTimer += dt;
      if (_trailTimer >= _trailInterval) {
        _trailTimer = 0;
        gameRef.add(BikeTrailPuff(
          position: position + Vector2(0, size.y * 0.38),
        ));
      }
    }
  }

  @override
  void render(Canvas canvas) {
    final needsLayer = _opacity < 1.0;
    if (needsLayer) {
      canvas.saveLayer(
        Rect.fromLTWH(0, 0, size.x, size.y).inflate(24),
        Paint()
          ..color = Color.fromARGB((_opacity * 255).round(), 255, 255, 255),
      );
    }

    canvas.save();
    canvas.translate(size.x / 2, size.y / 2);
    final crashProgress = _crashTimer > 0
        ? (1.0 - (_crashTimer / _crashDuration)).clamp(0.0, 1.0)
        : 0.0;
    final crashLean = crashProgress == 0
        ? 0.0
        : sin(crashProgress * pi) * _crashDir * (_hardCrash ? 1.35 : 0.95);
    final crashDrop = crashProgress == 0
        ? 0.0
        : sin(crashProgress * pi) * (_hardCrash ? 16.0 : 9.0) +
            (_hardCrash ? crashProgress * 9.0 : 0.0);
    canvas.translate(
        _crashDir * crashProgress * (_hardCrash ? 26.0 : 16.0), crashDrop);
    canvas.rotate(
      sin(_swayTimer * _swayHz * 2 * pi) * _swayAmplitudeDeg * pi / 180 +
          crashLean,
    );
    canvas.translate(-size.x / 2, -size.y / 2);
    _renderCourier(canvas, crashProgress: crashProgress, hardCrash: _hardCrash);

    if (_wetTimer > 0) {
      final a = (_wetTimer / _wetDuration) * 0.42;
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(6, 6, size.x - 12, size.y - 12),
          const Radius.circular(16),
        ),
        Paint()..color = const Color(0xFF42A5F5).withValues(alpha: a),
      );
    }

    canvas.restore();
    if (needsLayer) canvas.restore();
  }

  // ---------------------------------------------------------------------------
  // Avatar palette
  // ---------------------------------------------------------------------------

  Color _bikeColor() {
    switch (bikeId) {
      case 'bike_sky':
        return const Color(0xFF19A7CE);
      case 'bike_neon':
        return const Color(0xFF76FF03);
      case 'bike_gold':
        return const Color(0xFFFFC928);
      default:
        return avatar == CourierAvatar.girl
            ? const Color(0xFFEC407A)
            : const Color(0xFFD32F2F);
    }
  }

  Color _outfitTop() {
    switch (outfitId) {
      case 'outfit_glam_pink':
        return const Color(0xFFFF4FA8);
      case 'outfit_sunset':
        return const Color(0xFFFFA726);
      case 'outfit_neon':
        return const Color(0xFF76FF03);
      default:
        return avatar == CourierAvatar.girl
            ? const Color(0xFFEC407A)
            : const Color(0xFFE53935);
    }
  }

  Color _outfitBottom() {
    switch (outfitId) {
      case 'outfit_glam_pink':
        return const Color(0xFFAD1457);
      case 'outfit_sunset':
        return const Color(0xFFE65100);
      case 'outfit_neon':
        return const Color(0xFF33691E);
      default:
        return avatar == CourierAvatar.girl
            ? const Color(0xFF00ACC1)
            : const Color(0xFF1A237E);
    }
  }

  Color _outfitSleeve() {
    switch (outfitId) {
      case 'outfit_glam_pink':
        return const Color(0xFFD81B60);
      case 'outfit_sunset':
        return const Color(0xFFFF6F00);
      case 'outfit_neon':
        return const Color(0xFF2E7D32);
      default:
        return avatar == CourierAvatar.girl
            ? const Color(0xFFC2185B)
            : const Color(0xFFC62828);
    }
  }

  // ---------------------------------------------------------------------------
  // Main avatar render (back-of-bike Paperboy view)
  // ---------------------------------------------------------------------------

  void _renderCourier(Canvas canvas,
      {double crashProgress = 0, bool hardCrash = false}) {
    final w = size.x;
    final h = size.y;
    final isGirl = avatar == CourierAvatar.girl;
    final wheelAngle = _swayTimer * 13.0;
    final throwT = _throwArmTimer / _throwArmDuration;
    final pedalLift = _pedalPhase ? 1.0 : -1.0;
    final bikeTilt = -0.05 + crashProgress * _crashDir * 0.55;

    if (isVip) {
      canvas.drawOval(
        Rect.fromCenter(
            center: Offset(w * 0.50, h * 0.58),
            width: w * 0.98,
            height: h * 0.92),
        Paint()..color = vipTint.withValues(alpha: 0.22),
      );
    }

    // Ground shadow.
    canvas.drawOval(
      Rect.fromCenter(
          center: Offset(w * 0.50, h * 0.93),
          width: w * 0.80,
          height: h * 0.085),
      Paint()..color = const Color(0x77000000),
    );

    canvas.save();
    canvas.translate(w * 0.5, h * 0.66);
    canvas.rotate(bikeTilt);
    canvas.translate(-w * 0.5, -h * 0.66);

    // Anchor points for the bike + rider geometry.
    final rearWheel = Offset(w * 0.27, h * 0.80);
    final frontWheel = Offset(w * 0.74, h * 0.66);
    final crank = Offset(w * 0.42, h * 0.66);
    final saddle = Offset(w * 0.37, h * 0.48);
    final headTube = Offset(w * 0.63, h * 0.52);
    final stemTop = Offset(w * 0.65, h * 0.44);

    // ---- Behind the rider ----
    _drawAngledWheel(canvas, rearWheel, w * 0.22, wheelAngle, slant: -0.20);
    _drawFrameSegment(canvas, crank, rearWheel);
    _drawFrameSegment(canvas, saddle, rearWheel);
    _drawFrameSegment(canvas, saddle, crank);
    _drawSaddle(canvas, saddle);

    if (isGirl) _drawWickerBasket(canvas, w, h);

    _drawCranksAndPedals(canvas, crank, pedalLift);

    // ---- Rider lower body ----
    _drawRiderLegs(canvas, w, h, isGirl, crank, pedalLift);

    // ---- Rider torso ----
    _drawRiderTorso(canvas, w, h, isGirl);

    if (!isGirl) _drawCourierBag(canvas, w, h);

    // ---- Front of bike ----
    _drawFrameSegment(canvas, saddle, headTube);
    _drawFrameSegment(canvas, crank, headTube);
    _drawFrameSegment(canvas, headTube, frontWheel);
    _drawAngledWheel(canvas, frontWheel, w * 0.17, wheelAngle * 1.15,
        slant: -0.20);
    _drawHandlebars(canvas, headTube, stemTop);

    // ---- Arms (gripping the bars) ----
    final hands =
        _drawRiderArms(canvas, w, h, isGirl, throwT, crashProgress);

    // ---- Head / helmet / hair ----
    _drawRiderHead(canvas, w, h, isGirl);

    // ---- Newspaper held in throwing hand ----
    if (_throwArmTimer > 0) {
      _drawThrowingNewspaper(canvas, hands.throwing, throwT);
    }

    canvas.restore();

    if (hardCrash && crashProgress > 0.12) {
      _drawHeadSpinner(canvas, w, h, crashProgress);
    }
  }

  // ---------------------------------------------------------------------------
  // Bike pieces
  // ---------------------------------------------------------------------------

  void _drawFrameSegment(Canvas canvas, Offset a, Offset b) {
    final col = _bikeColor();
    canvas.drawLine(
      a,
      b,
      Paint()
        ..color = const Color(0x99000000)
        ..strokeWidth = 5.6
        ..strokeCap = StrokeCap.round,
    );
    canvas.drawLine(
      a,
      b,
      Paint()
        ..color = col
        ..strokeWidth = 3.8
        ..strokeCap = StrokeCap.round,
    );
    canvas.drawLine(
      Offset(a.dx - 0.9, a.dy - 0.7),
      Offset(b.dx - 0.9, b.dy - 0.7),
      Paint()
        ..color = Color.lerp(col, const Color(0xFFFFFFFF), 0.55)!
        ..strokeWidth = 1.1
        ..strokeCap = StrokeCap.round,
    );
  }

  void _drawSaddle(Canvas canvas, Offset c) {
    canvas.drawOval(
      Rect.fromCenter(
          center: c + const Offset(1.2, 1.6), width: 12, height: 4.6),
      Paint()..color = const Color(0x55000000),
    );
    canvas.drawOval(
      Rect.fromCenter(center: c, width: 12, height: 4.6),
      Paint()..color = const Color(0xFF161616),
    );
    canvas.drawOval(
      Rect.fromCenter(
          center: c + const Offset(-1.0, -1.0), width: 7.5, height: 2.0),
      Paint()..color = const Color(0xFF515151),
    );
  }

  void _drawCranksAndPedals(Canvas canvas, Offset crank, double pedalLift) {
    // Chainring with bolt detail.
    canvas.drawCircle(crank, 5.4, Paint()..color = const Color(0xFF1B1B1B));
    canvas.drawCircle(crank, 4.2, Paint()..color = const Color(0xFF4F4F4F));
    final boltPaint = Paint()..color = const Color(0xFF1B1B1B);
    for (int i = 0; i < 5; i++) {
      final a = i * 2 * pi / 5 - pi / 2;
      canvas.drawCircle(
          crank + Offset(cos(a) * 3.5, sin(a) * 3.5), 0.7, boltPaint);
    }
    canvas.drawCircle(crank, 1.4, Paint()..color = const Color(0xFFFFD54F));

    final crankArm = Paint()
      ..color = const Color(0xFF424242)
      ..strokeWidth = 2.8
      ..strokeCap = StrokeCap.round;
    final leftPedal = Offset(crank.dx - 9.5, crank.dy - pedalLift * 6.5);
    final rightPedal = Offset(crank.dx + 9.5, crank.dy + pedalLift * 6.5);
    canvas.drawLine(crank, leftPedal, crankArm);
    canvas.drawLine(crank, rightPedal, crankArm);

    for (final p in [leftPedal, rightPedal]) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(
            Rect.fromCenter(center: p, width: 8.4, height: 3.2),
            const Radius.circular(1.6)),
        Paint()..color = const Color(0xFF161616),
      );
      canvas.drawRect(
        Rect.fromCenter(
            center: p + const Offset(0, -0.7), width: 7.4, height: 0.9),
        Paint()..color = const Color(0xFF9E9E9E),
      );
    }
  }

  void _drawHandlebars(Canvas canvas, Offset headTube, Offset stemTop) {
    // Stem.
    canvas.drawLine(
      headTube,
      stemTop,
      Paint()
        ..color = const Color(0xFF263238)
        ..strokeWidth = 3.2
        ..strokeCap = StrokeCap.round,
    );
    canvas.drawLine(
      headTube + const Offset(-0.6, 0),
      stemTop + const Offset(-0.6, 0),
      Paint()
        ..color = const Color(0xFF607D8B)
        ..strokeWidth = 0.9
        ..strokeCap = StrokeCap.round,
    );

    final leftGrip = stemTop + const Offset(-13, -2);
    final rightGrip = stemTop + const Offset(13, 4);
    // Bar shadow.
    canvas.drawLine(
      leftGrip + const Offset(0, 1),
      rightGrip + const Offset(0, 1),
      Paint()
        ..color = const Color(0x66000000)
        ..strokeWidth = 4.0
        ..strokeCap = StrokeCap.round,
    );
    // Bar.
    canvas.drawLine(
      leftGrip,
      rightGrip,
      Paint()
        ..color = const Color(0xFF161616)
        ..strokeWidth = 3.0
        ..strokeCap = StrokeCap.round,
    );
    // Bar highlight.
    canvas.drawLine(
      leftGrip + const Offset(0, -0.7),
      rightGrip + const Offset(0, -0.7),
      Paint()
        ..color = const Color(0x99FFFFFF)
        ..strokeWidth = 0.7
        ..strokeCap = StrokeCap.round,
    );

    // Grips (rubber).
    for (final g in [leftGrip, rightGrip]) {
      canvas.drawCircle(g, 2.4, Paint()..color = const Color(0xFF1A1A1A));
      canvas.drawCircle(g + const Offset(-0.5, -0.5), 1.0,
          Paint()..color = const Color(0xFF6E6E6E));
    }
  }

  void _drawAngledWheel(Canvas canvas, Offset c, double r, double angle,
      {double slant = -0.4}) {
    canvas.save();
    canvas.translate(c.dx, c.dy);
    canvas.rotate(slant);
    canvas.scale(0.72, 1.0);

    // Drop shadow under the wheel.
    canvas.drawCircle(const Offset(1.0, 1.4), r,
        Paint()..color = const Color(0x66000000));

    // Tire.
    canvas.drawCircle(Offset.zero, r, Paint()..color = const Color(0xFF141414));

    // Tread marks rotating around the tire.
    canvas.save();
    canvas.rotate(angle * 0.45);
    final tread = Paint()
      ..color = const Color(0xFF3D3D3D)
      ..strokeWidth = 1.2
      ..strokeCap = StrokeCap.round;
    for (int i = 0; i < 18; i++) {
      final a = i * 2 * pi / 18;
      canvas.drawLine(
        Offset(cos(a) * r * 0.91, sin(a) * r * 0.91),
        Offset(cos(a) * r * 1.0, sin(a) * r * 1.0),
        tread,
      );
    }
    canvas.restore();

    // Tire side highlight.
    canvas.drawArc(
      Rect.fromCircle(center: Offset.zero, radius: r * 0.95),
      pi * 1.10,
      pi * 0.45,
      false,
      Paint()
        ..color = const Color(0x77FFFFFF)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.0,
    );

    // Rim.
    canvas.drawCircle(
        Offset.zero, r * 0.84, Paint()..color = const Color(0xFFB0BEC5));
    canvas.drawCircle(
        Offset.zero, r * 0.80, Paint()..color = const Color(0xFFECEFF1));

    // Spokes.
    canvas.save();
    canvas.rotate(angle);
    final spoke = Paint()
      ..color = const Color(0xFF455A64)
      ..strokeWidth = 0.9
      ..strokeCap = StrokeCap.round;
    for (int i = 0; i < 10; i++) {
      final a = i * 2 * pi / 10;
      canvas.drawLine(
        Offset(cos(a) * r * 0.18, sin(a) * r * 0.18),
        Offset(cos(a) * r * 0.76, sin(a) * r * 0.76),
        spoke,
      );
    }
    canvas.restore();

    // Hub.
    canvas.drawCircle(
        Offset.zero, r * 0.24, Paint()..color = const Color(0xFF1B1B1B));
    canvas.drawCircle(
        Offset.zero, r * 0.16, Paint()..color = const Color(0xFFCFD8DC));
    canvas.drawCircle(Offset(-r * 0.05, -r * 0.05), r * 0.06,
        Paint()..color = const Color(0xFFFFFFFF));

    // Rim inner edge highlight.
    canvas.drawCircle(
      Offset.zero,
      r * 0.80,
      Paint()
        ..color = const Color(0x55FFFFFF)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0.7,
    );

    canvas.restore();
  }

  // ---------------------------------------------------------------------------
  // Cargo
  // ---------------------------------------------------------------------------

  void _drawWickerBasket(Canvas canvas, double w, double h) {
    final cx = w * 0.23;
    final cy = h * 0.55;
    final bw = w * 0.30;
    final bh = h * 0.20;
    final rect = Rect.fromCenter(center: Offset(cx, cy), width: bw, height: bh);

    // Drop shadow.
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(
            center: Offset(cx + 1.6, cy + 2.0), width: bw, height: bh),
        const Radius.circular(5),
      ),
      Paint()..color = const Color(0x55000000),
    );

    // Body fill with gradient.
    canvas.drawRRect(
      RRect.fromRectAndRadius(rect, const Radius.circular(5)),
      Paint()
        ..shader = Gradient.linear(
          Offset(cx - bw / 2, cy - bh / 2),
          Offset(cx + bw / 2, cy + bh / 2),
          const [Color(0xFFD49558), Color(0xFF8C5A24)],
        ),
    );

    // Wicker weave.
    final weave = Paint()
      ..color = const Color(0x885A3A14)
      ..strokeWidth = 0.7;
    for (int i = 1; i < 7; i++) {
      final x = cx - bw / 2 + i * bw / 7;
      canvas.drawLine(
          Offset(x, cy - bh / 2 + 3), Offset(x, cy + bh / 2 - 2), weave);
    }
    for (int i = 1; i < 5; i++) {
      final y = cy - bh / 2 + i * bh / 5;
      canvas.drawLine(
          Offset(cx - bw / 2 + 2, y), Offset(cx + bw / 2 - 2, y), weave);
    }

    // Rim bands top and bottom.
    canvas.drawRect(
      Rect.fromLTWH(cx - bw / 2, cy - bh / 2 - 0.5, bw, 2.6),
      Paint()..color = const Color(0xFF8C5A24),
    );
    canvas.drawRect(
      Rect.fromLTWH(cx - bw / 2, cy + bh / 2 - 2.2, bw, 2.4),
      Paint()..color = const Color(0xFF6B3F0E),
    );

    // Outline.
    canvas.drawRRect(
      RRect.fromRectAndRadius(rect, const Radius.circular(5)),
      Paint()
        ..color = const Color(0xFF3F2402)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.2,
    );

    // Flowers peeking out of the basket.
    final stem = Paint()
      ..color = const Color(0xFF2E7D32)
      ..strokeWidth = 1.4
      ..strokeCap = StrokeCap.round;
    final s1 = Offset(cx - 4, cy - bh / 2 + 1);
    final s2 = Offset(cx + 1, cy - bh / 2 + 1);
    final s3 = Offset(cx + 5, cy - bh / 2 + 1);
    final f1 = Offset(cx - 5, cy - bh / 2 - 6);
    final f2 = Offset(cx + 1, cy - bh / 2 - 9);
    final f3 = Offset(cx + 6, cy - bh / 2 - 5);
    canvas.drawLine(s1, f1, stem);
    canvas.drawLine(s2, f2, stem);
    canvas.drawLine(s3, f3, stem);
    // Tiny leaves.
    canvas.drawOval(
      Rect.fromCenter(
          center: Offset(cx - 4.5, cy - bh / 2 - 2),
          width: 2.2,
          height: 1.2),
      Paint()..color = const Color(0xFF388E3C),
    );
    canvas.drawOval(
      Rect.fromCenter(
          center: Offset(cx + 2, cy - bh / 2 - 4), width: 2.2, height: 1.2),
      Paint()..color = const Color(0xFF388E3C),
    );

    _drawFlower(canvas, f1, const Color(0xFFEC407A));
    _drawFlower(canvas, f2, const Color(0xFFFFEB3B));
    _drawFlower(canvas, f3, const Color(0xFF42A5F5));
  }

  void _drawFlower(Canvas canvas, Offset c, Color petal) {
    final petalPaint = Paint()..color = petal;
    for (int i = 0; i < 5; i++) {
      final a = i * 2 * pi / 5 - pi / 2;
      canvas.drawCircle(c + Offset(cos(a) * 1.7, sin(a) * 1.7), 1.4, petalPaint);
    }
    canvas.drawCircle(c, 1.0, Paint()..color = const Color(0xFFFFEB3B));
    canvas.drawCircle(
        c + const Offset(-0.4, -0.4), 0.3,
        Paint()..color = const Color(0xFFFFFFFF));
  }

  void _drawCourierBag(Canvas canvas, double w, double h) {
    final cx = w * 0.22;
    final cy = h * 0.40;
    final bw = w * 0.22;
    final bh = h * 0.22;

    // Strap (right shoulder → left hip, across the back).
    final strapStart = Offset(w * 0.44, h * 0.22);
    final strapEnd = Offset(w * 0.20, h * 0.48);
    canvas.drawLine(
      strapStart,
      strapEnd,
      Paint()
        ..color = const Color(0xFF1A1A1A)
        ..strokeWidth = 4.2
        ..strokeCap = StrokeCap.round,
    );
    canvas.drawLine(
      strapStart + const Offset(-0.7, 0.6),
      strapEnd + const Offset(-0.7, 0.6),
      Paint()
        ..color = const Color(0xFF555555)
        ..strokeWidth = 1.4
        ..strokeCap = StrokeCap.round,
    );
    // Strap stitching dashes.
    final dash = Paint()
      ..color = const Color(0xFFE6A800)
      ..strokeWidth = 0.8
      ..strokeCap = StrokeCap.round;
    for (double t = 0.15; t < 0.9; t += 0.18) {
      final p = Offset.lerp(strapStart, strapEnd, t)!;
      canvas.drawLine(p + const Offset(-0.8, -0.4),
          p + const Offset(0.8, 0.4), dash);
    }

    final bagRect = RRect.fromRectAndRadius(
      Rect.fromCenter(center: Offset(cx, cy), width: bw, height: bh),
      const Radius.circular(6),
    );

    // Drop shadow.
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(
            center: Offset(cx + 1.3, cy + 1.7), width: bw, height: bh),
        const Radius.circular(6),
      ),
      Paint()..color = const Color(0x55000000),
    );

    // Bag body with gradient.
    canvas.drawRRect(
      bagRect,
      Paint()
        ..shader = Gradient.linear(
          Offset(cx - bw / 2, cy - bh / 2),
          Offset(cx + bw / 2, cy + bh / 2),
          const [Color(0xFFFFD54F), Color(0xFFE6A800)],
        ),
    );

    // Flap.
    final flap = Path()
      ..moveTo(cx - bw / 2, cy - bh / 2 + 2)
      ..lineTo(cx + bw / 2, cy - bh / 2 + 2)
      ..lineTo(cx + bw / 2 - 1.5, cy - bh / 2 + 10)
      ..lineTo(cx - bw / 2 + 1.5, cy - bh / 2 + 10)
      ..close();
    canvas.drawPath(flap, Paint()..color = const Color(0xFFB17F0A));

    // Buckle.
    canvas.drawRect(
      Rect.fromCenter(center: Offset(cx, cy - bh / 2 + 7), width: 4.4, height: 2.6),
      Paint()..color = const Color(0xFF424242),
    );
    canvas.drawRect(
      Rect.fromCenter(center: Offset(cx, cy - bh / 2 + 7), width: 4.4, height: 2.6),
      Paint()
        ..color = const Color(0xFFFFE082)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0.7,
    );

    // Stripe accent across the bag.
    canvas.drawRect(
      Rect.fromCenter(center: Offset(cx, cy + 2), width: bw, height: 2.0),
      Paint()..color = const Color(0xFFE53935),
    );

    // Newspapers peeking out.
    for (int i = 0; i < 3; i++) {
      final x = cx - bw / 2 + 2.5 + i * 3.6;
      final y = cy - bh / 2 - 2 - i * 1.0;
      canvas.drawRRect(
        RRect.fromRectAndRadius(
            Rect.fromLTWH(x, y, 7, 8), const Radius.circular(1.4)),
        Paint()..color = const Color(0xFFFBF5DC),
      );
      canvas.drawLine(
        Offset(x + 1, y + 2),
        Offset(x + 6, y + 2),
        Paint()
          ..color = const Color(0xFF7A7A7A)
          ..strokeWidth = 0.4,
      );
      canvas.drawLine(
        Offset(x + 1, y + 4),
        Offset(x + 6, y + 4),
        Paint()
          ..color = const Color(0xFF7A7A7A)
          ..strokeWidth = 0.4,
      );
    }

    // Outline.
    canvas.drawRRect(
      bagRect,
      Paint()
        ..color = const Color(0xFF5E3E00)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.4,
    );
  }

  // ---------------------------------------------------------------------------
  // Rider body parts
  // ---------------------------------------------------------------------------

  void _drawRiderLegs(Canvas canvas, double w, double h, bool isGirl,
      Offset crank, double pedalLift) {
    final leftFoot = Offset(crank.dx - 9.5, crank.dy - pedalLift * 6.5);
    final rightFoot = Offset(crank.dx + 9.5, crank.dy + pedalLift * 6.5);

    final leftHip = Offset(w * 0.33, h * 0.46);
    final rightHip = Offset(w * 0.46, h * 0.46);
    final leftKnee = Offset(w * 0.36, h * 0.58 - pedalLift * 1.5);
    final rightKnee = Offset(w * 0.46, h * 0.58 + pedalLift * 1.5);

    final pantColor = isGirl
        ? Color.lerp(_outfitBottom(), const Color(0xFF000000), 0.05)!
        : const Color(0xFF1A237E);
    final pantShade = Color.lerp(pantColor, const Color(0xFF000000), 0.35)!;
    final highlight = Color.lerp(pantColor, const Color(0xFFFFFFFF), 0.30)!;

    final thighShadow = Paint()
      ..color = pantShade
      ..strokeWidth = 6.6
      ..strokeCap = StrokeCap.round;
    final thigh = Paint()
      ..color = pantColor
      ..strokeWidth = 5.4
      ..strokeCap = StrokeCap.round;

    canvas.drawLine(leftHip, leftKnee, thighShadow);
    canvas.drawLine(rightHip, rightKnee, thighShadow);
    canvas.drawLine(leftHip, leftKnee, thigh);
    canvas.drawLine(rightHip, rightKnee, thigh);

    // Thigh highlight.
    final thighHi = Paint()
      ..color = highlight
      ..strokeWidth = 1.4
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(leftHip + const Offset(-1.1, 0.2),
        leftKnee + const Offset(-1.1, 0.2), thighHi);
    canvas.drawLine(rightHip + const Offset(1.1, 0.2),
        rightKnee + const Offset(1.1, 0.2), thighHi);

    // Calves: leggings (girl) vs. skin (boy in shorts).
    if (isGirl) {
      canvas.drawLine(leftKnee, leftFoot + const Offset(0, -3), thigh);
      canvas.drawLine(rightKnee, rightFoot + const Offset(0, -3), thigh);
      // Side stripe down leggings.
      final stripe = Paint()
        ..color = const Color(0xFFFFFFFF)
        ..strokeWidth = 0.8
        ..strokeCap = StrokeCap.round;
      canvas.drawLine(leftKnee + const Offset(-1.6, 0),
          leftFoot + const Offset(-1.6, -3), stripe);
      canvas.drawLine(rightKnee + const Offset(1.6, 0),
          rightFoot + const Offset(1.6, -3), stripe);
    } else {
      final skin = Paint()
        ..color = const Color(0xFFE8B07A)
        ..strokeWidth = 4.6
        ..strokeCap = StrokeCap.round;
      final skinShade = Paint()
        ..color = const Color(0xFFB5814F)
        ..strokeWidth = 5.4
        ..strokeCap = StrokeCap.round;
      canvas.drawLine(leftKnee, leftFoot + const Offset(0, -3), skinShade);
      canvas.drawLine(rightKnee, rightFoot + const Offset(0, -3), skinShade);
      canvas.drawLine(leftKnee, leftFoot + const Offset(0, -3), skin);
      canvas.drawLine(rightKnee, rightFoot + const Offset(0, -3), skin);
      // Calf muscle highlight.
      final calfHi = Paint()
        ..color = const Color(0x77FFFFFF)
        ..strokeWidth = 1.0
        ..strokeCap = StrokeCap.round;
      canvas.drawLine(leftKnee + const Offset(-0.8, 0.4),
          leftFoot + const Offset(-0.8, -2.5), calfHi);
      canvas.drawLine(rightKnee + const Offset(0.8, 0.4),
          rightFoot + const Offset(0.8, -2.5), calfHi);
    }

    _drawShoe(canvas, leftFoot, isGirl);
    _drawShoe(canvas, rightFoot, isGirl);
  }

  void _drawShoe(Canvas canvas, Offset p, bool isGirl) {
    if (isGirl) {
      // Cute high-top sneaker — pink/white with sole.
      canvas.drawRRect(
        RRect.fromRectAndRadius(
            Rect.fromCenter(
                center: p + const Offset(0, -1.5), width: 10.5, height: 4.4),
            const Radius.circular(2.2)),
        Paint()..color = const Color(0xFFFFFFFF),
      );
      canvas.drawRect(
        Rect.fromCenter(
            center: p + const Offset(0, -2.6), width: 10.6, height: 1.8),
        Paint()..color = const Color(0xFFEC407A),
      );
      canvas.drawRect(
        Rect.fromCenter(
            center: p + const Offset(0, -0.4), width: 10.6, height: 1.0),
        Paint()..color = const Color(0xFF424242),
      );
      // Laces dot.
      canvas.drawCircle(p + const Offset(-2.5, -1.8), 0.7,
          Paint()..color = const Color(0xFFEC407A));
      canvas.drawCircle(p + const Offset(0, -1.8), 0.7,
          Paint()..color = const Color(0xFFEC407A));
      canvas.drawCircle(p + const Offset(2.5, -1.8), 0.7,
          Paint()..color = const Color(0xFFEC407A));
    } else {
      // Cycling cleat — black with red stripe and visible cleat tab.
      canvas.drawRRect(
        RRect.fromRectAndRadius(
            Rect.fromCenter(
                center: p + const Offset(0, -1.6), width: 11.2, height: 4.6),
            const Radius.circular(2.4)),
        Paint()..color = const Color(0xFF111111),
      );
      canvas.drawRect(
        Rect.fromCenter(
            center: p + const Offset(0, -2.1), width: 10.5, height: 1.6),
        Paint()..color = const Color(0xFFE53935),
      );
      // White brand toe-cap.
      canvas.drawCircle(p + const Offset(4.6, -1.6), 1.5,
          Paint()..color = const Color(0xFFFFFFFF));
      // Cleat clip on the sole.
      canvas.drawRect(
        Rect.fromCenter(
            center: p + const Offset(0, 0.5), width: 5.2, height: 1.1),
        Paint()..color = const Color(0xFF9E9E9E),
      );
      // Sole highlight.
      canvas.drawRect(
        Rect.fromCenter(
            center: p + const Offset(0, -0.4), width: 10.6, height: 0.7),
        Paint()..color = const Color(0xFF4E4E4E),
      );
    }
  }

  void _drawRiderTorso(Canvas canvas, double w, double h, bool isGirl) {
    final top = _outfitTop();
    final shade = Color.lerp(top, const Color(0xFF000000), 0.35)!;
    final highlight = Color.lerp(top, const Color(0xFFFFFFFF), 0.30)!;

    final shoulderW = isGirl ? w * 0.30 : w * 0.36;
    final shoulderTop = h * 0.21;
    final waistY = h * 0.44;
    final waistW = isGirl ? w * 0.27 : w * 0.30;
    final cx = w * 0.39;

    final torsoPath = Path()
      ..moveTo(cx - shoulderW / 2, shoulderTop + 4)
      ..quadraticBezierTo(cx - shoulderW / 2 - 1.2, shoulderTop,
          cx - shoulderW / 2 + 3.5, shoulderTop - 1)
      ..lineTo(cx + shoulderW / 2 - 3.5, shoulderTop - 1)
      ..quadraticBezierTo(cx + shoulderW / 2 + 1.2, shoulderTop,
          cx + shoulderW / 2, shoulderTop + 4)
      ..lineTo(cx + waistW / 2, waistY)
      ..quadraticBezierTo(cx, waistY + 3.5, cx - waistW / 2, waistY)
      ..close();

    // Drop shadow.
    canvas.save();
    canvas.translate(1.3, 1.6);
    canvas.drawPath(torsoPath, Paint()..color = const Color(0x55000000));
    canvas.restore();

    // Body with shoulder→waist gradient.
    canvas.drawPath(
      torsoPath,
      Paint()
        ..shader = Gradient.linear(
          Offset(cx - shoulderW / 2, shoulderTop),
          Offset(cx + shoulderW / 2, waistY + 2),
          [highlight, top, shade],
          const [0.0, 0.55, 1.0],
        ),
    );

    // Spine streak (darker shade running down the centre).
    canvas.drawLine(
      Offset(cx, shoulderTop + 3),
      Offset(cx - 1.0, waistY - 1),
      Paint()
        ..color = shade
        ..strokeWidth = 2.2
        ..strokeCap = StrokeCap.round,
    );

    // Side highlight (one edge brighter for shading depth).
    canvas.drawLine(
      Offset(cx - shoulderW / 2 + 2.5, shoulderTop + 5),
      Offset(cx - waistW / 2 + 1.5, waistY - 2),
      Paint()
        ..color = highlight
        ..strokeWidth = 1.4
        ..strokeCap = StrokeCap.round,
    );

    if (isGirl) {
      // Cute heart logo on the back (two circles + triangle point).
      const heartLift = 11.0;
      final hc = Offset(cx, shoulderTop + heartLift);
      canvas.drawCircle(
          hc + const Offset(-1.8, 0), 2.0,
          Paint()..color = const Color(0xFFFFFFFF));
      canvas.drawCircle(
          hc + const Offset(1.8, 0), 2.0,
          Paint()..color = const Color(0xFFFFFFFF));
      final point = Path()
        ..moveTo(hc.dx - 3.2, hc.dy + 0.5)
        ..lineTo(hc.dx + 3.2, hc.dy + 0.5)
        ..lineTo(hc.dx, hc.dy + 5.0)
        ..close();
      canvas.drawPath(point, Paint()..color = const Color(0xFFFFFFFF));
      // Small inner shadow on heart.
      canvas.drawCircle(
          hc + const Offset(1.8, 0.6), 1.0,
          Paint()..color = const Color(0x33000000));
    } else {
      // Sporty shoulder-band stripe + numbered roundel for the boy.
      canvas.drawLine(
        Offset(cx - shoulderW / 2 + 4, shoulderTop + 4.5),
        Offset(cx + shoulderW / 2 - 4, shoulderTop + 4.5),
        Paint()
          ..color = const Color(0xFFFFFFFF)
          ..strokeWidth = 1.8
          ..strokeCap = StrokeCap.round,
      );
      canvas.drawCircle(
          Offset(cx, shoulderTop + 11), 3.6,
          Paint()..color = const Color(0xFFFFFFFF));
      canvas.drawCircle(
          Offset(cx, shoulderTop + 11), 2.6,
          Paint()..color = top);
      canvas.drawCircle(
          Offset(cx - 0.5, shoulderTop + 10.5), 0.8,
          Paint()..color = const Color(0x66FFFFFF));
    }

    // Belt.
    canvas.drawRect(
      Rect.fromCenter(
          center: Offset(cx, waistY - 0.5), width: waistW - 2, height: 1.6),
      Paint()..color = const Color(0xFF1B1B1B),
    );

    // Outline.
    canvas.drawPath(
      torsoPath,
      Paint()
        ..color = const Color(0x66000000)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0.9,
    );
  }

  ({Offset left, Offset right, Offset throwing}) _drawRiderArms(
      Canvas canvas,
      double w,
      double h,
      bool isGirl,
      double throwT,
      double crashProgress) {
    final sleeveCol = _outfitSleeve();
    final sleeveShade =
        Color.lerp(sleeveCol, const Color(0xFF000000), 0.35)!;
    final skinCol = isGirl
        ? const Color(0xFFFFD3AE)
        : const Color(0xFFEFB57E);
    final skinShade =
        Color.lerp(skinCol, const Color(0xFF000000), 0.28)!;

    final leftShoulder = Offset(w * 0.28, h * 0.24);
    final rightShoulder = Offset(w * 0.50, h * 0.24);

    final defaultLeft = Offset(w * 0.51, h * 0.43);
    final defaultRight = Offset(w * 0.78, h * 0.46);

    final fallReach = crashProgress * 0.10;
    final leftHand = _throwLeft && throwT > 0
        ? Offset(
            w * (0.32 - throwT * 0.26),
            h * (0.36 - throwT * 0.10 + crashProgress * 0.16))
        : Offset(defaultLeft.dx - fallReach * w,
            defaultLeft.dy + crashProgress * h * 0.16);
    final rightHand = !_throwLeft && throwT > 0
        ? Offset(
            w * (0.78 + throwT * 0.22),
            h * (0.36 - throwT * 0.10 + crashProgress * 0.16))
        : Offset(defaultRight.dx + fallReach * w,
            defaultRight.dy + crashProgress * h * 0.16);

    final leftElbow = Offset(
        (leftShoulder.dx + leftHand.dx) / 2 - 1.5,
        (leftShoulder.dy + leftHand.dy) / 2 + 1.5);
    final rightElbow = Offset(
        (rightShoulder.dx + rightHand.dx) / 2 + 1.5,
        (rightShoulder.dy + rightHand.dy) / 2 + 1.5);

    // Upper arm (sleeve) with shadow.
    final upperShadow = Paint()
      ..color = sleeveShade
      ..strokeWidth = 6.4
      ..strokeCap = StrokeCap.round;
    final upper = Paint()
      ..color = sleeveCol
      ..strokeWidth = 5.4
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(leftShoulder, leftElbow, upperShadow);
    canvas.drawLine(rightShoulder, rightElbow, upperShadow);
    canvas.drawLine(leftShoulder, leftElbow, upper);
    canvas.drawLine(rightShoulder, rightElbow, upper);

    // Sleeve cuff.
    canvas.drawCircle(leftElbow, 3.0, Paint()..color = sleeveShade);
    canvas.drawCircle(rightElbow, 3.0, Paint()..color = sleeveShade);

    // Forearm: girl keeps sleeve; boy has bare forearm (skin).
    if (isGirl) {
      final forearmShadow = Paint()
        ..color = sleeveShade
        ..strokeWidth = 5.4
        ..strokeCap = StrokeCap.round;
      final forearm = Paint()
        ..color = sleeveCol
        ..strokeWidth = 4.4
        ..strokeCap = StrokeCap.round;
      canvas.drawLine(leftElbow, leftHand, forearmShadow);
      canvas.drawLine(rightElbow, rightHand, forearmShadow);
      canvas.drawLine(leftElbow, leftHand, forearm);
      canvas.drawLine(rightElbow, rightHand, forearm);
    } else {
      final forearmShadow = Paint()
        ..color = skinShade
        ..strokeWidth = 5.0
        ..strokeCap = StrokeCap.round;
      final forearm = Paint()
        ..color = skinCol
        ..strokeWidth = 4.0
        ..strokeCap = StrokeCap.round;
      canvas.drawLine(leftElbow, leftHand, forearmShadow);
      canvas.drawLine(rightElbow, rightHand, forearmShadow);
      canvas.drawLine(leftElbow, leftHand, forearm);
      canvas.drawLine(rightElbow, rightHand, forearm);
      // Forearm highlight.
      final fHi = Paint()
        ..color = const Color(0x66FFFFFF)
        ..strokeWidth = 0.9
        ..strokeCap = StrokeCap.round;
      canvas.drawLine(leftElbow + const Offset(0, -0.8),
          leftHand + const Offset(0, -0.8), fHi);
      canvas.drawLine(rightElbow + const Offset(0, -0.8),
          rightHand + const Offset(0, -0.8), fHi);
    }

    // Hands (skin orbs with shading).
    for (final hand in [leftHand, rightHand]) {
      canvas.drawCircle(hand + const Offset(0.6, 0.7), 2.5,
          Paint()..color = skinShade);
      canvas.drawCircle(hand, 2.5, Paint()..color = skinCol);
      canvas.drawCircle(hand + const Offset(-0.6, -0.8), 0.6,
          Paint()..color = const Color(0xAAFFFFFF));
    }

    return (
      left: leftHand,
      right: rightHand,
      throwing: _throwLeft ? leftHand : rightHand,
    );
  }

  // ---------------------------------------------------------------------------
  // Head + helmet
  // ---------------------------------------------------------------------------

  void _drawRiderHead(Canvas canvas, double w, double h, bool isGirl) {
    final skin = isGirl
        ? const Color(0xFFFFD3AE)
        : const Color(0xFFEFB57E);
    final skinShade = Color.lerp(skin, const Color(0xFF000000), 0.28)!;
    final hairColor =
        isGirl ? const Color(0xFF8A4A1B) : const Color(0xFF3E2614);

    final headCenter = Offset(w * 0.39, h * 0.16);

    // Neck.
    canvas.drawRect(
      Rect.fromCenter(
          center: Offset(headCenter.dx, h * 0.235), width: 6.4, height: 5.0),
      Paint()..color = skinShade,
    );
    canvas.drawRect(
      Rect.fromCenter(
          center: Offset(headCenter.dx - 0.5, h * 0.235),
          width: 5.0,
          height: 5.0),
      Paint()..color = skin,
    );

    // For the girl, draw the ponytail first so it sits behind the helmet.
    if (isGirl) {
      final ponyShadow = Path()
        ..moveTo(w * 0.30, h * 0.17)
        ..quadraticBezierTo(w * 0.22, h * 0.28, w * 0.20, h * 0.40)
        ..quadraticBezierTo(w * 0.27, h * 0.40, w * 0.33, h * 0.34)
        ..quadraticBezierTo(w * 0.36, h * 0.26, w * 0.34, h * 0.19)
        ..close();
      canvas.save();
      canvas.translate(1.5, 1.6);
      canvas.drawPath(ponyShadow, Paint()..color = const Color(0x55000000));
      canvas.restore();
      canvas.drawPath(ponyShadow, Paint()..color = hairColor);
      // Ponytail highlight strands.
      final strand = Paint()
        ..color = Color.lerp(hairColor, const Color(0xFFFFFFFF), 0.30)!
        ..strokeWidth = 0.9
        ..strokeCap = StrokeCap.round;
      canvas.drawLine(Offset(w * 0.27, h * 0.23),
          Offset(w * 0.24, h * 0.34), strand);
      canvas.drawLine(Offset(w * 0.31, h * 0.21),
          Offset(w * 0.29, h * 0.33), strand);
      // Hair tie at base of ponytail.
      canvas.drawCircle(Offset(w * 0.31, h * 0.19), 2.2,
          Paint()..color = const Color(0xFFEC407A));
      canvas.drawCircle(Offset(w * 0.31, h * 0.19), 2.2,
          Paint()
            ..color = const Color(0xFFFFFFFF)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 0.5);
    }

    // Back-of-head hair patch peeking out from under the helmet.
    final hairPatch = Path()
      ..moveTo(headCenter.dx - w * 0.13, headCenter.dy + 3)
      ..quadraticBezierTo(
          headCenter.dx,
          headCenter.dy + 7,
          headCenter.dx + w * 0.13,
          headCenter.dy + 3)
      ..lineTo(headCenter.dx + w * 0.12, headCenter.dy + 6)
      ..quadraticBezierTo(
          headCenter.dx,
          headCenter.dy + 10,
          headCenter.dx - w * 0.12,
          headCenter.dy + 6)
      ..close();
    canvas.drawPath(hairPatch, Paint()..color = hairColor);

    // Face/skin visible below helmet (back of head from rider's pov).
    canvas.drawOval(
      Rect.fromCenter(
          center: Offset(headCenter.dx, headCenter.dy + 4.5),
          width: w * 0.22,
          height: h * 0.10),
      Paint()..color = skin,
    );
    // Ear hints.
    canvas.drawCircle(Offset(headCenter.dx - w * 0.11, headCenter.dy + 5),
        1.4, Paint()..color = skinShade);
    canvas.drawCircle(Offset(headCenter.dx + w * 0.11, headCenter.dy + 5),
        1.4, Paint()..color = skinShade);

    if (isGirl) {
      _drawGirlHelmet(canvas, w, h, headCenter);
    } else {
      _drawBoyHelmet(canvas, w, h, headCenter);
    }
  }

  void _drawBoyHelmet(Canvas canvas, double w, double h, Offset c) {
    const helmetColor = Color(0xFFE53935);
    const helmetDark = Color(0xFFA62721);
    const helmetHi = Color(0xFFFFCDD2);

    final helmetPath = Path()
      ..moveTo(c.dx - w * 0.14, c.dy + 1)
      ..quadraticBezierTo(
          c.dx - w * 0.16, c.dy - h * 0.10, c.dx - w * 0.04, c.dy - h * 0.115)
      ..quadraticBezierTo(c.dx + w * 0.04, c.dy - h * 0.12, c.dx + w * 0.14,
          c.dy - h * 0.095)
      ..quadraticBezierTo(c.dx + w * 0.17, c.dy - h * 0.03, c.dx + w * 0.14,
          c.dy + 1.5)
      ..lineTo(c.dx + w * 0.12, c.dy + 2.5)
      ..quadraticBezierTo(c.dx, c.dy + 4, c.dx - w * 0.12, c.dy + 2.5)
      ..close();

    // Drop shadow.
    canvas.save();
    canvas.translate(1.4, 1.8);
    canvas.drawPath(helmetPath, Paint()..color = const Color(0x66000000));
    canvas.restore();

    // Main helmet shell.
    canvas.drawPath(
      helmetPath,
      Paint()
        ..shader = Gradient.linear(
          Offset(c.dx - w * 0.16, c.dy - h * 0.10),
          Offset(c.dx + w * 0.16, c.dy + 4),
          const [helmetHi, helmetColor, helmetDark],
          const [0.0, 0.45, 1.0],
        ),
    );

    // Aero vent slits.
    final vent = Paint()
      ..color = const Color(0xFF161616)
      ..strokeWidth = 1.4
      ..strokeCap = StrokeCap.round;
    for (int i = 0; i < 3; i++) {
      final x = c.dx - w * 0.07 + i * w * 0.07;
      canvas.drawLine(Offset(x, c.dy - h * 0.085),
          Offset(x, c.dy - h * 0.025), vent);
    }

    // Visor strip across the front.
    final visorRect = RRect.fromRectAndRadius(
      Rect.fromCenter(
          center: Offset(c.dx, c.dy - h * 0.005),
          width: w * 0.26,
          height: 3.2),
      const Radius.circular(1.4),
    );
    canvas.drawRRect(visorRect, Paint()..color = const Color(0xFF0E0E0E));
    // Glossy visor highlight band.
    canvas.drawRect(
      Rect.fromCenter(
          center: Offset(c.dx - w * 0.04, c.dy - h * 0.005 - 0.6),
          width: w * 0.08,
          height: 0.9),
      Paint()..color = const Color(0xCCFFFFFF),
    );
    // Smaller secondary glint.
    canvas.drawRect(
      Rect.fromCenter(
          center: Offset(c.dx + w * 0.05, c.dy - h * 0.005 + 0.6),
          width: w * 0.03,
          height: 0.5),
      Paint()..color = const Color(0x88FFFFFF),
    );

    // White brand stripe near the crown.
    canvas.drawRect(
      Rect.fromCenter(
          center: Offset(c.dx, c.dy - h * 0.06),
          width: w * 0.18,
          height: 1.4),
      Paint()..color = const Color(0xFFFFFFFF),
    );
    canvas.drawCircle(Offset(c.dx + w * 0.08, c.dy - h * 0.06), 1.0,
        Paint()..color = const Color(0xFF1A237E));

    // Chin straps either side.
    final strap = Paint()
      ..color = const Color(0xFF111111)
      ..strokeWidth = 1.1
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(Offset(c.dx - w * 0.12, c.dy + 2),
        Offset(c.dx - w * 0.10, c.dy + h * 0.05), strap);
    canvas.drawLine(Offset(c.dx + w * 0.12, c.dy + 2),
        Offset(c.dx + w * 0.10, c.dy + h * 0.05), strap);

    // Outline.
    canvas.drawPath(
      helmetPath,
      Paint()
        ..color = const Color(0x99000000)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0.9,
    );

    // Crown highlight (glossy).
    canvas.drawOval(
      Rect.fromCenter(
          center: Offset(c.dx - w * 0.05, c.dy - h * 0.085),
          width: w * 0.09,
          height: 2.4),
      Paint()..color = const Color(0x99FFFFFF),
    );
  }

  void _drawGirlHelmet(Canvas canvas, double w, double h, Offset c) {
    const helmetColor = Color(0xFFEC407A);
    const helmetDark = Color(0xFF9C1458);
    const helmetHi = Color(0xFFFCE4EC);

    final helmetPath = Path()
      ..moveTo(c.dx - w * 0.15, c.dy + 2)
      ..quadraticBezierTo(c.dx - w * 0.18, c.dy - h * 0.10,
          c.dx - w * 0.05, c.dy - h * 0.12)
      ..quadraticBezierTo(c.dx + w * 0.05, c.dy - h * 0.125,
          c.dx + w * 0.15, c.dy - h * 0.10)
      ..quadraticBezierTo(
          c.dx + w * 0.18, c.dy - h * 0.02, c.dx + w * 0.14, c.dy + 2)
      ..lineTo(c.dx + w * 0.13, c.dy + 3)
      ..quadraticBezierTo(c.dx, c.dy + 4.5, c.dx - w * 0.13, c.dy + 3)
      ..close();

    // Drop shadow.
    canvas.save();
    canvas.translate(1.4, 1.8);
    canvas.drawPath(helmetPath, Paint()..color = const Color(0x66000000));
    canvas.restore();

    // Shell.
    canvas.drawPath(
      helmetPath,
      Paint()
        ..shader = Gradient.linear(
          Offset(c.dx - w * 0.18, c.dy - h * 0.12),
          Offset(c.dx + w * 0.18, c.dy + 4),
          const [helmetHi, helmetColor, helmetDark],
          const [0.0, 0.5, 1.0],
        ),
    );

    // Cute round vent holes.
    for (int i = 0; i < 4; i++) {
      final x = c.dx - w * 0.10 + i * w * 0.067;
      canvas.drawCircle(Offset(x, c.dy - h * 0.055), 1.3,
          Paint()..color = const Color(0xFF7A1645));
    }

    // White stripe band.
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(
            center: Offset(c.dx, c.dy - h * 0.018),
            width: w * 0.22,
            height: 2.0),
        const Radius.circular(1.0),
      ),
      Paint()..color = const Color(0xFFFFFFFF),
    );
    // Tiny dotted line on the band.
    final dot = Paint()..color = const Color(0xFFEC407A);
    for (int i = 0; i < 3; i++) {
      canvas.drawCircle(
          Offset(c.dx - w * 0.06 + i * w * 0.06, c.dy - h * 0.018), 0.5, dot);
    }

    // Flower decoration on the side.
    _drawFlower(canvas, Offset(c.dx + w * 0.11, c.dy - h * 0.025),
        const Color(0xFFFFEB3B));

    // Big glossy highlight on top.
    canvas.drawOval(
      Rect.fromCenter(
          center: Offset(c.dx - w * 0.07, c.dy - h * 0.08),
          width: w * 0.09,
          height: 3.0),
      Paint()..color = const Color(0xCCFFFFFF),
    );

    // Chin straps.
    final strap = Paint()
      ..color = const Color(0xFFFFFFFF)
      ..strokeWidth = 1.1
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(Offset(c.dx - w * 0.12, c.dy + 2.5),
        Offset(c.dx - w * 0.10, c.dy + h * 0.05), strap);
    canvas.drawLine(Offset(c.dx + w * 0.12, c.dy + 2.5),
        Offset(c.dx + w * 0.10, c.dy + h * 0.05), strap);

    // Outline.
    canvas.drawPath(
      helmetPath,
      Paint()
        ..color = const Color(0x99000000)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0.9,
    );
  }

  // ---------------------------------------------------------------------------
  // Newspaper held while throwing
  // ---------------------------------------------------------------------------

  void _drawThrowingNewspaper(Canvas canvas, Offset hand, double throwT) {
    final scale = 0.55 + throwT * 0.55;
    canvas.save();
    canvas.translate(hand.dx, hand.dy);
    canvas.rotate((_throwLeft ? -1 : 1) * (0.4 - throwT * 0.9));
    canvas.scale(scale);

    // Shadow.
    canvas.drawRRect(
      RRect.fromRectAndRadius(
          Rect.fromCenter(
              center: const Offset(0.6, 0.9), width: 9.0, height: 5.6),
          const Radius.circular(1.0)),
      Paint()..color = const Color(0x66000000),
    );
    // Paper body.
    canvas.drawRRect(
      RRect.fromRectAndRadius(
          Rect.fromCenter(center: Offset.zero, width: 9.0, height: 5.6),
          const Radius.circular(1.0)),
      Paint()..color = const Color(0xFFFBF5DC),
    );
    // Fold crease.
    canvas.drawLine(
      const Offset(0, -2.8),
      const Offset(0, 2.8),
      Paint()
        ..color = const Color(0xFFB6920A)
        ..strokeWidth = 0.5,
    );
    // Headline blocks.
    final ink = Paint()
      ..color = const Color(0xFF707070)
      ..strokeWidth = 0.35;
    for (int i = 0; i < 3; i++) {
      final y = -1.6 + i * 1.1;
      canvas.drawLine(const Offset(-3.4, 0).translate(0, y),
          const Offset(-0.6, 0).translate(0, y), ink);
      canvas.drawLine(const Offset(0.6, 0).translate(0, y),
          const Offset(3.4, 0).translate(0, y), ink);
    }
    // Red headline strip.
    canvas.drawRect(
      Rect.fromCenter(center: const Offset(0, -2.0), width: 7.0, height: 0.7),
      Paint()..color = const Color(0xFFE53935),
    );
    // Outline.
    canvas.drawRRect(
      RRect.fromRectAndRadius(
          Rect.fromCenter(center: Offset.zero, width: 9.0, height: 5.6),
          const Radius.circular(1.0)),
      Paint()
        ..color = const Color(0xFF707070)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0.5,
    );

    canvas.restore();
  }

  // ---------------------------------------------------------------------------
  // Hard-crash dizziness stars (unchanged)
  // ---------------------------------------------------------------------------

  void _drawHeadSpinner(Canvas canvas, double w, double h, double progress) {
    final center = Offset(w * 0.40, h * 0.05);
    final spin = _swayTimer * 8.0 + progress * 6.0;
    final ringPaint = Paint()
      ..color = const Color(0xCCFFF176)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.4;
    canvas.drawOval(
      Rect.fromCenter(center: center, width: w * 0.42, height: h * 0.12),
      ringPaint,
    );
    for (int i = 0; i < 4; i++) {
      final a = spin + i * pi / 2;
      final p = center + Offset(cos(a) * w * 0.22, sin(a) * h * 0.055);
      _drawTinyStar(canvas, p, 4.0 + i);
    }
  }

  void _drawTinyStar(Canvas canvas, Offset c, double r) {
    final path = Path();
    for (int i = 0; i < 8; i++) {
      final rr = i.isEven ? r : r * 0.45;
      final a = -pi / 2 + i * pi / 4;
      final p = c + Offset(cos(a) * rr, sin(a) * rr);
      if (i == 0) {
        path.moveTo(p.dx, p.dy);
      } else {
        path.lineTo(p.dx, p.dy);
      }
    }
    path.close();
    canvas.drawPath(path, Paint()..color = const Color(0xFFFFF176));
    canvas.drawPath(
      path,
      Paint()
        ..color = const Color(0xFFD6A600)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0.7,
    );
  }
}
