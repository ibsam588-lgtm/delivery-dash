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

  void _renderCourier(Canvas canvas,
      {double crashProgress = 0, bool hardCrash = false}) {
    final w = size.x;
    final h = size.y;
    final wheelAngle = _swayTimer * 13.0;
    final throwT = _throwArmTimer / _throwArmDuration;
    final pedalLift = _pedalPhase ? 1.0 : -1.0;
    final bikeTilt = -0.08 + crashProgress * _crashDir * 0.55;
    final bikeColor = _bikeColor();

    if (isVip) {
      canvas.drawOval(
        Rect.fromCenter(
            center: Offset(w * 0.50, h * 0.58),
            width: w * 0.95,
            height: h * 0.88),
        Paint()..color = vipTint.withValues(alpha: 0.22),
      );
    }

    canvas.drawOval(
      Rect.fromCenter(
          center: Offset(w * 0.50, h * 0.91),
          width: w * 0.72,
          height: h * 0.09),
      Paint()..color = const Color(0x77000000),
    );

    canvas.save();
    canvas.translate(w * 0.5, h * 0.64);
    canvas.rotate(bikeTilt);
    canvas.translate(-w * 0.5, -h * 0.64);

    final rearWheel = Offset(w * 0.25, h * 0.82);
    final frontWheel = Offset(w * 0.74, h * 0.72);
    _drawAngledWheel(canvas, rearWheel, w * 0.20, wheelAngle, slant: -0.18);
    _drawAngledWheel(canvas, frontWheel, w * 0.19, wheelAngle + pi / 8,
        slant: -0.18);

    final framePaint = Paint()
      ..color = bikeColor
      ..strokeWidth = 4.0
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    final frameShadow = Paint()
      ..color = const Color(0x88000000)
      ..strokeWidth = 5.5
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final seat = Offset(w * 0.45, h * 0.50);
    final crank = Offset(w * 0.50, h * 0.66);
    final handle = Offset(w * 0.76, h * 0.48);
    final forkTop = Offset(w * 0.70, h * 0.55);

    void frame(Paint p) {
      canvas.drawLine(seat, crank, p);
      canvas.drawLine(crank, rearWheel, p);
      canvas.drawLine(crank, frontWheel, p);
      canvas.drawLine(seat, rearWheel, p);
      canvas.drawLine(seat, forkTop, p);
      canvas.drawLine(forkTop, frontWheel, p);
      canvas.drawLine(handle, forkTop, p);
      canvas.drawLine(seat, handle, p);
    }

    frame(frameShadow);
    frame(framePaint);

    canvas.drawLine(
      Offset(w * 0.62, h * 0.48),
      Offset(w * 0.86, h * 0.43),
      Paint()
        ..color = const Color(0xFF263238)
        ..strokeWidth = 3.4
        ..strokeCap = StrokeCap.round,
    );

    canvas.drawCircle(crank, 4.2, Paint()..color = const Color(0xFF1B1B1B));
    final pedalPaint = Paint()
      ..color = const Color(0xFF263238)
      ..strokeWidth = 2.5
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(
        crank, Offset(crank.dx + 10, crank.dy + pedalLift * 7), pedalPaint);
    canvas.drawLine(
        crank, Offset(crank.dx - 10, crank.dy - pedalLift * 7), pedalPaint);
    canvas.restore();

    _drawNewsBag(canvas, w, h);
    _drawRearRider(canvas, w, h, pedalLift, throwT, crashProgress, hardCrash);
  }

  void _drawRearRider(Canvas canvas, double w, double h, double pedalLift,
      double throwT, double crashProgress, bool hardCrash) {
    final isGirl = avatar == CourierAvatar.girl;
    final shirtTop = _outfitTop();
    final shirtBottom = _outfitBottom();
    final coatDark = _outfitSleeve();
    final capeColor =
        isGirl ? const Color(0xFFFF4FA2) : const Color(0xFFD63A30);
    const gold = Color(0xFFF7C84B);
    final hairColor =
        isGirl ? const Color(0xFFD89221) : const Color(0xFF6B381E);
    final skinColor =
        isGirl ? const Color(0xFFFFD3AE) : const Color(0xFFF1BC8F);
    final legPaint = Paint()
      ..color = const Color(0xFF4D3C87)
      ..strokeWidth = 4.7
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(Offset(w * 0.44, h * 0.53),
        Offset(w * 0.42, h * 0.68 - pedalLift * 3), legPaint);
    canvas.drawLine(Offset(w * 0.56, h * 0.53),
        Offset(w * 0.58, h * 0.68 + pedalLift * 3), legPaint);
    canvas.drawLine(Offset(w * 0.42, h * 0.68 - pedalLift * 3),
        Offset(w * 0.45, h * 0.81), legPaint);
    canvas.drawLine(Offset(w * 0.58, h * 0.68 + pedalLift * 3),
        Offset(w * 0.55, h * 0.81), legPaint);

    canvas.drawOval(
        Rect.fromCenter(
            center: Offset(w * 0.45, h * 0.82), width: 11, height: 6),
        Paint()..color = const Color(0xFF212121));
    canvas.drawOval(
        Rect.fromCenter(
            center: Offset(w * 0.55, h * 0.82), width: 11, height: 6),
        Paint()..color = const Color(0xFF37205D));

    final cape = Path()
      ..moveTo(w * 0.34, h * 0.28)
      ..quadraticBezierTo(w * 0.24, h * 0.40, w * 0.28, h * 0.58)
      ..quadraticBezierTo(w * 0.39, h * 0.55, w * 0.47, h * 0.47)
      ..quadraticBezierTo(w * 0.55, h * 0.56, w * 0.67, h * 0.54)
      ..quadraticBezierTo(w * 0.70, h * 0.39, w * 0.58, h * 0.29)
      ..close();
    canvas.drawPath(cape, Paint()..color = capeColor);
    canvas.drawPath(
      cape,
      Paint()
        ..color = const Color(0x44000000)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.0,
    );

    final body = RRect.fromRectAndRadius(
      Rect.fromCenter(
          center: Offset(w * 0.48, h * 0.39),
          width: w * 0.31,
          height: h * 0.23),
      const Radius.circular(12),
    );
    canvas.drawRRect(
      body,
      Paint()
        ..shader = Gradient.linear(
          Offset(w * 0.36, h * 0.24),
          Offset(w * 0.62, h * 0.53),
          [shirtTop, shirtBottom],
        ),
    );
    canvas.drawRRect(
        body,
        Paint()
          ..color = const Color(0x66000000)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.0);

    final lapelPaint = Paint()..color = const Color(0xFFF8E8C8);
    final leftLapel = Path()
      ..moveTo(w * 0.44, h * 0.28)
      ..lineTo(w * 0.39, h * 0.47)
      ..lineTo(w * 0.47, h * 0.40)
      ..close();
    final rightLapel = Path()
      ..moveTo(w * 0.52, h * 0.28)
      ..lineTo(w * 0.57, h * 0.47)
      ..lineTo(w * 0.49, h * 0.40)
      ..close();
    canvas.drawPath(leftLapel, lapelPaint);
    canvas.drawPath(rightLapel, lapelPaint);

    canvas.drawLine(
      Offset(w * 0.48, h * 0.26),
      Offset(w * 0.48, h * 0.50),
      Paint()
        ..color = gold
        ..strokeWidth = 3.6
        ..strokeCap = StrokeCap.round,
    );
    canvas.drawLine(
      Offset(w * 0.40, h * 0.34),
      Offset(w * 0.56, h * 0.34),
      Paint()
        ..color = gold
        ..strokeWidth = 1.9
        ..strokeCap = StrokeCap.round,
    );
    canvas.drawCircle(Offset(w * 0.41, h * 0.355), 2.8, Paint()..color = gold);
    canvas.drawCircle(Offset(w * 0.55, h * 0.355), 2.8, Paint()..color = gold);

    final sleevePaint = Paint()
      ..color = coatDark
      ..strokeWidth = 5.5
      ..strokeCap = StrokeCap.round;
    final skinPaint = Paint()
      ..color = skinColor
      ..strokeWidth = 3.8
      ..strokeCap = StrokeCap.round;
    final leftShoulder = Offset(w * 0.37, h * 0.33);
    final rightShoulder = Offset(w * 0.59, h * 0.33);
    final fallReach = crashProgress * 0.18;
    final leftHand = Offset(
        w * (0.31 - (_throwLeft ? throwT * 0.20 : 0) - fallReach),
        h * (0.43 - (_throwLeft ? throwT * 0.12 : 0) + crashProgress * 0.16));
    final rightHand = Offset(
        w * (0.66 + (!_throwLeft ? throwT * 0.20 : 0) + fallReach),
        h * (0.42 - (!_throwLeft ? throwT * 0.12 : 0) + crashProgress * 0.16));
    canvas.drawLine(leftShoulder, leftHand, sleevePaint);
    canvas.drawLine(rightShoulder, rightHand, sleevePaint);
    canvas.drawLine(leftHand, Offset(leftHand.dx, leftHand.dy + 1), skinPaint);
    canvas.drawLine(
        rightHand, Offset(rightHand.dx, rightHand.dy + 1), skinPaint);

    final faceRect = Rect.fromCenter(
      center: Offset(w * 0.48, h * 0.20),
      width: w * 0.24,
      height: h * 0.20,
    );
    if (isGirl) {
      final hairBack = Path()
        ..moveTo(w * 0.34, h * 0.12)
        ..quadraticBezierTo(w * 0.24, h * 0.23, w * 0.31, h * 0.40)
        ..quadraticBezierTo(w * 0.48, h * 0.46, w * 0.64, h * 0.39)
        ..quadraticBezierTo(w * 0.72, h * 0.24, w * 0.63, h * 0.13)
        ..quadraticBezierTo(w * 0.48, h * 0.03, w * 0.34, h * 0.12)
        ..close();
      canvas.drawPath(hairBack, Paint()..color = hairColor);
    } else {
      final hairBack = Path()
        ..moveTo(w * 0.35, h * 0.12)
        ..quadraticBezierTo(w * 0.24, h * 0.22, w * 0.32, h * 0.31)
        ..quadraticBezierTo(w * 0.48, h * 0.35, w * 0.64, h * 0.31)
        ..quadraticBezierTo(w * 0.72, h * 0.22, w * 0.62, h * 0.12)
        ..quadraticBezierTo(w * 0.48, h * 0.02, w * 0.35, h * 0.12)
        ..close();
      canvas.drawPath(hairBack, Paint()..color = hairColor);
    }
    canvas.drawOval(faceRect, Paint()..color = skinColor);
    canvas.drawOval(
      faceRect,
      Paint()
        ..color = const Color(0x44000000)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0.8,
    );
    _drawAvatarHeadTop(canvas, w, h, isGirl, hairColor, gold, shirtTop);
    _drawAvatarFace(canvas, w, h, isGirl);

    if (hardCrash && crashProgress > 0.12) {
      _drawHeadSpinner(canvas, w, h, crashProgress);
    }
  }

  void _drawAvatarHeadTop(Canvas canvas, double w, double h, bool isGirl,
      Color hairColor, Color gold, Color accent) {
    if (isGirl) {
      final bangs = Path()
        ..moveTo(w * 0.38, h * 0.14)
        ..quadraticBezierTo(w * 0.44, h * 0.09, w * 0.49, h * 0.14)
        ..quadraticBezierTo(w * 0.55, h * 0.08, w * 0.61, h * 0.14)
        ..quadraticBezierTo(w * 0.56, h * 0.18, w * 0.38, h * 0.14)
        ..close();
      canvas.drawPath(bangs, Paint()..color = hairColor);
      canvas.drawCircle(
          Offset(w * 0.35, h * 0.24), 4.6, Paint()..color = hairColor);
      canvas.drawCircle(
          Offset(w * 0.61, h * 0.24), 4.6, Paint()..color = hairColor);
      final tiara = Path()
        ..moveTo(w * 0.38, h * 0.08)
        ..lineTo(w * 0.43, h * 0.03)
        ..lineTo(w * 0.48, h * 0.08)
        ..lineTo(w * 0.53, h * 0.02)
        ..lineTo(w * 0.58, h * 0.08)
        ..quadraticBezierTo(w * 0.48, h * 0.11, w * 0.38, h * 0.08)
        ..close();
      canvas.drawPath(tiara, Paint()..color = gold);
      canvas.drawCircle(
          Offset(w * 0.43, h * 0.045), 1.2, Paint()..color = accent);
      canvas.drawCircle(Offset(w * 0.53, h * 0.04), 1.4,
          Paint()..color = const Color(0xFF9C6BFF));
    } else {
      final swoop = Path()
        ..moveTo(w * 0.37, h * 0.14)
        ..quadraticBezierTo(w * 0.43, h * 0.06, w * 0.50, h * 0.13)
        ..quadraticBezierTo(w * 0.56, h * 0.07, w * 0.61, h * 0.14)
        ..quadraticBezierTo(w * 0.55, h * 0.19, w * 0.37, h * 0.14)
        ..close();
      canvas.drawPath(swoop, Paint()..color = hairColor);
      final crown = Path()
        ..moveTo(w * 0.35, h * 0.08)
        ..lineTo(w * 0.40, h * 0.01)
        ..lineTo(w * 0.45, h * 0.06)
        ..lineTo(w * 0.49, h * -0.01)
        ..lineTo(w * 0.55, h * 0.06)
        ..lineTo(w * 0.60, h * 0.01)
        ..lineTo(w * 0.65, h * 0.08)
        ..quadraticBezierTo(w * 0.49, h * 0.11, w * 0.35, h * 0.08)
        ..close();
      canvas.drawPath(crown, Paint()..color = gold);
      canvas.drawCircle(Offset(w * 0.40, h * 0.03), 1.2,
          Paint()..color = const Color(0xFFEF5350));
      canvas.drawCircle(
          Offset(w * 0.49, h * 0.015), 1.4, Paint()..color = accent);
      canvas.drawCircle(Offset(w * 0.60, h * 0.03), 1.2,
          Paint()..color = const Color(0xFF66BB6A));
    }
  }

  void _drawAvatarFace(Canvas canvas, double w, double h, bool isGirl) {
    final eyeWhite = Paint()..color = const Color(0xFFFDF9ED);
    final iris = Paint()
      ..color = isGirl ? const Color(0xFF45A7FF) : const Color(0xFF7C4D2C);
    final pupil = Paint()..color = const Color(0xFF24160F);
    for (final eyeX in [w * 0.44, w * 0.53]) {
      canvas.drawOval(
        Rect.fromCenter(
            center: Offset(eyeX, h * 0.20), width: 5.4, height: 4.8),
        eyeWhite,
      );
      canvas.drawCircle(Offset(eyeX, h * 0.20), 1.7, iris);
      canvas.drawCircle(Offset(eyeX, h * 0.20), 0.8, pupil);
      canvas.drawCircle(Offset(eyeX - 0.55, h * 0.192), 0.34,
          Paint()..color = const Color(0xFFFFFFFF));
    }
    final brow = Paint()
      ..color = isGirl ? const Color(0xFFBC7A16) : const Color(0xFF4A2514)
      ..strokeWidth = 0.8
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(
        Offset(w * 0.41, h * 0.177), Offset(w * 0.45, h * 0.171), brow);
    canvas.drawLine(
        Offset(w * 0.52, h * 0.171), Offset(w * 0.56, h * 0.177), brow);
    canvas.drawArc(
      Rect.fromCenter(
          center: Offset(w * 0.48, h * 0.215), width: 4.0, height: 3.0),
      -0.45,
      0.9,
      false,
      Paint()
        ..color = const Color(0x55986A42)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0.55,
    );
    canvas.drawCircle(Offset(w * 0.40, h * 0.235), 1.3,
        Paint()..color = const Color(0x33F48FB1));
    canvas.drawCircle(Offset(w * 0.56, h * 0.235), 1.3,
        Paint()..color = const Color(0x33F48FB1));
    canvas.drawArc(
      Rect.fromCenter(
          center: Offset(w * 0.48, h * 0.252), width: 8.5, height: 5.4),
      0.22,
      pi - 0.44,
      false,
      Paint()
        ..color = const Color(0xFF8A2F26)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.0,
    );
  }

  void _drawHeadSpinner(Canvas canvas, double w, double h, double progress) {
    final center = Offset(w * 0.47, h * 0.07);
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

  Color _bikeColor() {
    switch (bikeId) {
      case 'bike_sky':
        return const Color(0xFF19A7CE);
      case 'bike_neon':
        return const Color(0xFF76FF03);
      case 'bike_gold':
        return const Color(0xFFFFC928);
      default:
        return const Color(0xFFD71920);
    }
  }

  Color _outfitTop() {
    switch (outfitId) {
      case 'outfit_glam_pink':
        return const Color(0xFFFF5FB7);
      case 'outfit_sunset':
        return const Color(0xFFFFB74D);
      case 'outfit_neon':
        return const Color(0xFF64DD17);
      default:
        return avatar == CourierAvatar.girl
            ? const Color(0xFFE91E63)
            : const Color(0xFF1E88E5);
    }
  }

  Color _outfitBottom() {
    switch (outfitId) {
      case 'outfit_glam_pink':
        return const Color(0xFFB0006D);
      case 'outfit_sunset':
        return const Color(0xFFE65100);
      case 'outfit_neon':
        return const Color(0xFF1B5E20);
      default:
        return avatar == CourierAvatar.girl
            ? const Color(0xFF8E1A63)
            : const Color(0xFF0B3D72);
    }
  }

  Color _outfitSleeve() {
    switch (outfitId) {
      case 'outfit_glam_pink':
        return const Color(0xFFD81B60);
      case 'outfit_sunset':
        return const Color(0xFFFF8A00);
      case 'outfit_neon':
        return const Color(0xFF2E7D32);
      default:
        return avatar == CourierAvatar.girl
            ? const Color(0xFFC2185B)
            : const Color(0xFF1565C0);
    }
  }

  void _drawNewsBag(Canvas canvas, double w, double h) {
    final bag = RRect.fromRectAndRadius(
      Rect.fromCenter(
          center: Offset(w * 0.25, h * 0.52),
          width: w * 0.25,
          height: h * 0.22),
      const Radius.circular(7),
    );
    canvas.drawRRect(bag, Paint()..color = const Color(0xFFFFC928));
    canvas.drawRRect(
        bag,
        Paint()
          ..color = const Color(0xFF6D4C00)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.8);
    for (int i = 0; i < 3; i++) {
      final x = w * (0.16 + i * 0.035);
      canvas.drawRRect(
        RRect.fromRectAndRadius(
            Rect.fromLTWH(x, h * 0.36 - i * 2, w * 0.07, h * 0.075),
            const Radius.circular(2)),
        Paint()..color = const Color(0xFFF6F0D8),
      );
    }
  }

  void _drawAngledWheel(Canvas canvas, Offset c, double r, double angle,
      {double slant = -0.4}) {
    canvas.save();
    canvas.translate(c.dx, c.dy);
    canvas.rotate(slant);
    canvas.scale(0.72, 1.0);
    canvas.drawCircle(Offset.zero, r, Paint()..color = const Color(0xFF0C0C0C));
    canvas.drawCircle(
        Offset.zero, r * 0.88, Paint()..color = const Color(0xFFECEFF1));
    canvas.drawCircle(
        Offset.zero, r * 0.78, Paint()..color = const Color(0xFF515151));
    canvas.drawCircle(
        Offset.zero, r * 0.58, Paint()..color = const Color(0xFFEEEEEE));
    canvas.drawCircle(
        Offset.zero, r * 0.20, Paint()..color = const Color(0xFF202020));
    canvas.rotate(angle);
    final spoke = Paint()
      ..color = const Color(0xFFBDBDBD)
      ..strokeWidth = 0.8
      ..strokeCap = StrokeCap.round;
    for (int i = 0; i < 8; i++) {
      final a = i * 2 * pi / 8;
      canvas.drawLine(
          Offset.zero, Offset(cos(a) * r * 0.72, sin(a) * r * 0.72), spoke);
    }
    canvas.restore();
  }
}
