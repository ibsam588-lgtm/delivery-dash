import 'dart:math';
import 'dart:ui';
import 'package:flame/collisions.dart';
import 'package:flame/components.dart';
import '../delivery_dash_game.dart';
import '../perspective.dart';
import 'parked_car.dart' show renderTopDownCar;
import 'player.dart';

enum ObstacleType {
  car,
  dog,
  worker,
  cone,
  barrier,
  pothole,
  hydrant,
  trashBin,
  kidBike,
  manhole,
}

Vector2 _sizeFor(ObstacleType t) {
  switch (t) {
    case ObstacleType.car:
      return Vector2(72, 110);
    case ObstacleType.dog:
      return Vector2(55, 45);
    case ObstacleType.worker:
      return Vector2(50, 75);
    case ObstacleType.cone:
      return Vector2(40, 50);
    case ObstacleType.barrier:
      return Vector2(80, 45);
    case ObstacleType.pothole:
      return Vector2(50, 35);
    case ObstacleType.hydrant:
      return Vector2(28, 42);
    case ObstacleType.trashBin:
      return Vector2(40, 56);
    case ObstacleType.kidBike:
      return Vector2(48, 70);
    case ObstacleType.manhole:
      return Vector2(48, 30);
  }
}

class ObstacleComponent extends PositionComponent
    with HasGameRef<DeliveryDashGame>, CollisionCallbacks {
  final ObstacleType type;
  final double laneFraction;
  final int carVariant;
  final bool onRightSidewalk;
  final double speedFactor;
  final bool isOvertaker;

  bool _hasHitPlayer = false;
  bool _paperedOnce = false;
  double _life = 0;

  double _lateralPhase = 0;
  double? _baseX;

  double _reactionTimer = 0;
  static const double _reactionDuration = 0.35;
  double _tipAngle = 0;

  // Animation timers for dog / worker.
  double _animTimer = 0;

  static const List<Color> _carBodyColors = [
    Color(0xFFE53935),
    Color(0xFF1565C0),
    Color(0xFF9E9E9E),
    Color(0xFFFBC02D),
  ];

  ObstacleComponent({
    required this.type,
    required this.laneFraction,
    int? carVariant,
    this.speedFactor = 1.0,
    this.isOvertaker = false,
    this.onRightSidewalk = false,
  })  : carVariant = carVariant ?? Random().nextInt(4),
        super(
          size: _sizeFor(type),
          anchor: Anchor.center,
          priority: 3,
        );

  bool get isLethal =>
      type == ObstacleType.car ||
      type == ObstacleType.dog ||
      type == ObstacleType.worker ||
      type == ObstacleType.kidBike;

  bool get isDrenching => type == ObstacleType.hydrant;

  bool get isStaticOnSidewalk =>
      type == ObstacleType.worker ||
      type == ObstacleType.trashBin ||
      onRightSidewalk;

  bool get hasLateralSweep =>
      type == ObstacleType.dog || type == ObstacleType.kidBike;

  int get paperHitPoints {
    switch (type) {
      case ObstacleType.trashBin:
        return 5;
      case ObstacleType.dog:
        return 3;
      case ObstacleType.worker:
        return 5;
      case ObstacleType.kidBike:
        return 3;
      case ObstacleType.cone:
      case ObstacleType.barrier:
        return 2;
      case ObstacleType.hydrant:
      case ObstacleType.car:
      case ObstacleType.pothole:
      case ObstacleType.manhole:
        return 0;
    }
  }

  @override
  Future<void> onLoad() async {
    final lm = gameRef.laneManager;
    final double x;
    if (onRightSidewalk) {
      final lo = lm.roadRight + 6;
      final hi = gameRef.size.x - 6;
      final t = laneFraction.clamp(0.0, 1.0);
      x = lo + (hi - lo) * t;
    } else {
      x = lm.roadXFromFraction(laneFraction);
    }
    _baseX = x;
    position = Vector2(x, -size.y);
    add(RectangleHitbox(
      size: size * 0.78,
      position: size * 0.11,
      collisionType: CollisionType.active,
    ));
  }

  void onHitByPaper() {
    if (_paperedOnce) return;
    _paperedOnce = true;
    _reactionTimer = _reactionDuration;
    if (type == ObstacleType.trashBin) {
      _tipAngle = pi / 2.5;
    } else if (hasLateralSweep) {
      _lateralPhase += pi;
    }
  }

  @override
  void update(double dt) {
    super.update(dt);
    _life += dt;
    _animTimer += dt;

    final road = gameRef.scrollSpeed;
    final vy = type == ObstacleType.car
        ? (isOvertaker ? road * 1.3 : road * speedFactor)
        : road;
    position.y += vy * dt;

    if (hasLateralSweep) {
      _lateralPhase += dt * 2.2;
      final amp = type == ObstacleType.kidBike ? 60.0 : 80.0;
      final lm = gameRef.laneManager;
      final base = _baseX ?? lm.roadCenter;
      final desired = base + sin(_lateralPhase) * amp;
      position.x = lm.clampToRoad(desired, size.x / 2);
    }

    if (_reactionTimer > 0) {
      _reactionTimer = (_reactionTimer - dt).clamp(0.0, _reactionDuration);
    }

    if (position.y > gameRef.size.y + size.y) {
      removeFromParent();
    }
  }

  @override
  void render(Canvas canvas) {
    final h = gameRef.size.y;
    final scale = depthScale(position.y, h);
    final bounce = _reactionTimer > 0
        ? sin(_reactionTimer / _reactionDuration * pi) * 0.12
        : 0.0;
    final s = scale * (1 + bounce);

    final dx = depthXShift(
      position.x, position.y, gameRef.laneManager.roadCenter, h,
    );
    canvas.translate(dx, 0);

    if (type != ObstacleType.pothole && type != ObstacleType.manhole) {
      canvas.drawOval(
        Rect.fromCenter(
          center: Offset(size.x / 2, size.y - 3),
          width: size.x * 0.85 * s,
          height: 10 * s,
        ),
        Paint()..color = const Color(0x66000000),
      );
    }

    canvas.save();
    canvas.translate(size.x / 2, size.y / 2);
    canvas.scale(s, s * 0.85);
    if (_tipAngle != 0) canvas.rotate(_tipAngle);
    canvas.translate(-size.x / 2, -size.y / 2);

    switch (type) {
      case ObstacleType.car:
        _renderCar(canvas);
      case ObstacleType.dog:
        _renderDog(canvas);
      case ObstacleType.worker:
        _renderWorker(canvas);
      case ObstacleType.cone:
        _renderCone(canvas);
      case ObstacleType.barrier:
        _renderBarrier(canvas);
      case ObstacleType.pothole:
        _renderPothole(canvas);
      case ObstacleType.hydrant:
        _renderHydrant(canvas);
      case ObstacleType.trashBin:
        _renderTrashBin(canvas);
      case ObstacleType.kidBike:
        _renderKidBike(canvas);
      case ObstacleType.manhole:
        _renderManhole(canvas);
    }

    canvas.restore();
  }

  void _renderCar(Canvas canvas) {
    renderTopDownCar(
      canvas, size.x, size.y, _carBodyColors[carVariant % _carBodyColors.length],
    );
  }

  void _renderDog(Canvas canvas) {
    final w = size.x;
    final h = size.y;

    // Tail wag angle.
    final tailSwing = sin(_animTimer * pi / 0.4) * 0.30;
    // Leg phase: front and rear pairs alternate.
    final legToggle = (_animTimer / 0.2).floor().isEven;

    // Body (horizontal tan ellipse).
    final bodyRect = Rect.fromCenter(
      center: Offset(w * 0.52, h * 0.55),
      width: w * 0.64,
      height: h * 0.40,
    );
    canvas.drawOval(
      bodyRect,
      Paint()
        ..shader = Gradient.linear(
          bodyRect.topLeft,
          bodyRect.bottomRight,
          [const Color(0xFFD4A050), const Color(0xFFB07830)],
        ),
    );

    // Head (slightly larger circle, lighter tan, at front/left).
    final headCenter = Offset(w * 0.18, h * 0.48);
    canvas.drawCircle(headCenter, w * 0.16, Paint()..color = const Color(0xFFE8B860));

    // Ears (dark-brown teardrop shapes flopped to sides of head).
    final earPaint = Paint()..color = const Color(0xFF7A4010);
    // Left ear (above).
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(headCenter.dx - w * 0.04, headCenter.dy - w * 0.18),
        width: w * 0.12,
        height: w * 0.20,
      ),
      earPaint,
    );
    // Right ear (below).
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(headCenter.dx - w * 0.04, headCenter.dy + w * 0.18),
        width: w * 0.12,
        height: w * 0.20,
      ),
      earPaint,
    );

    // Legs (4 small rounded rects — alternating pairs).
    final legPaint = Paint()..color = const Color(0xFFB07830);
    final legW = w * 0.10;
    final legH = h * 0.22;
    // Front pair.
    final frontOffset = legToggle ? h * 0.05 : 0.0;
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(
          center: Offset(w * 0.33, h * 0.82 + frontOffset),
          width: legW, height: legH,
        ),
        const Radius.circular(3),
      ),
      legPaint,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(
          center: Offset(w * 0.48, h * 0.82 + frontOffset),
          width: legW, height: legH,
        ),
        const Radius.circular(3),
      ),
      legPaint,
    );
    // Rear pair.
    final rearOffset = legToggle ? 0.0 : h * 0.05;
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(
          center: Offset(w * 0.63, h * 0.82 + rearOffset),
          width: legW, height: legH,
        ),
        const Radius.circular(3),
      ),
      legPaint,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(
          center: Offset(w * 0.78, h * 0.82 + rearOffset),
          width: legW, height: legH,
        ),
        const Radius.circular(3),
      ),
      legPaint,
    );

    // Tail (curved arc at back, wagging).
    final tailPath = Path();
    final tailBase = Offset(w * 0.82, h * 0.50);
    final tailTip = Offset(
      w * 0.82 + w * 0.22 * cos(tailSwing),
      h * 0.38 + h * 0.22 * sin(tailSwing),
    );
    final tailCtrl = Offset(w * 0.92, h * 0.36 + h * 0.10 * sin(tailSwing));
    tailPath.moveTo(tailBase.dx, tailBase.dy);
    tailPath.quadraticBezierTo(tailCtrl.dx, tailCtrl.dy, tailTip.dx, tailTip.dy);
    canvas.drawPath(
      tailPath,
      Paint()
        ..color = const Color(0xFFB07830)
        ..strokeWidth = 4.0
        ..strokeCap = StrokeCap.round
        ..style = PaintingStyle.stroke,
    );

    // Eye (black dot with white highlight).
    canvas.drawCircle(
      Offset(headCenter.dx - w * 0.04, headCenter.dy - h * 0.06),
      2.8,
      Paint()..color = const Color(0xFF111111),
    );
    canvas.drawCircle(
      Offset(headCenter.dx - w * 0.06, headCenter.dy - h * 0.09),
      0.9,
      Paint()..color = const Color(0xFFFFFFFF),
    );

    // Nose.
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(headCenter.dx - w * 0.14, headCenter.dy),
        width: w * 0.06,
        height: h * 0.06,
      ),
      Paint()..color = const Color(0xFF331100),
    );
  }

  void _renderWorker(Canvas canvas) {
    final w = size.x;
    final h = size.y;

    // Legs / pants (dark).
    final legPaint = Paint()..color = const Color(0xFF37474F);
    canvas.drawRect(
      Rect.fromLTWH(w * 0.22, h * 0.58, w * 0.24, h * 0.36),
      legPaint,
    );
    canvas.drawRect(
      Rect.fromLTWH(w * 0.54, h * 0.58, w * 0.24, h * 0.36),
      legPaint,
    );

    // Body / grey shirt.
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(w * 0.18, h * 0.34, w * 0.64, h * 0.28),
        const Radius.circular(4),
      ),
      Paint()..color = const Color(0xFF9E9E9E),
    );

    // Orange safety vest over shirt.
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(w * 0.20, h * 0.34, w * 0.60, h * 0.26),
        const Radius.circular(4),
      ),
      Paint()
        ..shader = Gradient.linear(
          Offset(w * 0.20, h * 0.34),
          Offset(w * 0.80, h * 0.60),
          [const Color(0xFFFF8F00), const Color(0xFFE65100)],
        ),
    );
    // Vest reflective stripe.
    canvas.drawRect(
      Rect.fromLTWH(w * 0.20, h * 0.44, w * 0.60, h * 0.03),
      Paint()..color = const Color(0xCCFFFFFF),
    );

    // Arms (angled slightly outward).
    final armPaint = Paint()
      ..color = const Color(0xFF9E9E9E)
      ..strokeWidth = w * 0.11
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(
      Offset(w * 0.18, h * 0.38),
      Offset(w * 0.06, h * 0.56),
      armPaint,
    );
    canvas.drawLine(
      Offset(w * 0.82, h * 0.38),
      Offset(w * 0.94, h * 0.56),
      armPaint,
    );

    // Face (skin-tone circle).
    canvas.drawCircle(
      Offset(w * 0.50, h * 0.21),
      w * 0.15,
      Paint()..color = const Color(0xFFFFCC80),
    );

    // Yellow hard hat (semicircle + flat brim).
    final hatColor = Paint()..color = const Color(0xFFFFD600);
    final hatPath = Path()
      ..addOval(Rect.fromCenter(
        center: Offset(w * 0.50, h * 0.16),
        width: w * 0.36,
        height: w * 0.24,
      ));
    canvas.drawPath(hatPath, hatColor);
    // Brim.
    canvas.drawRect(
      Rect.fromLTWH(w * 0.24, h * 0.165, w * 0.52, h * 0.035),
      Paint()..color = const Color(0xFFCCAA00),
    );

    // Dot eyes.
    canvas.drawCircle(
      Offset(w * 0.43, h * 0.21),
      1.5,
      Paint()..color = const Color(0xFF333333),
    );
    canvas.drawCircle(
      Offset(w * 0.57, h * 0.21),
      1.5,
      Paint()..color = const Color(0xFF333333),
    );
  }

  void _renderCone(Canvas canvas) {
    final w = size.x;
    final h = size.y;

    // Circular base ring.
    canvas.drawOval(
      Rect.fromLTWH(w * 0.10, h * 0.75, w * 0.80, h * 0.18),
      Paint()..color = const Color(0xFFCC3300),
    );

    // Cone body (trapezoid / triangle in top-down view).
    final conePath = Path()
      ..moveTo(w * 0.18, h * 0.82)
      ..lineTo(w * 0.82, h * 0.82)
      ..lineTo(w * 0.62, h * 0.20)
      ..lineTo(w * 0.38, h * 0.20)
      ..close();
    canvas.drawPath(
      conePath,
      Paint()
        ..shader = Gradient.linear(
          Offset(w * 0.18, h * 0.82),
          Offset(w * 0.50, h * 0.20),
          [const Color(0xFFFF5722), const Color(0xFFBF360C)],
        ),
    );

    // White reflective stripe.
    final stripePath = Path()
      ..moveTo(w * 0.28, h * 0.54)
      ..lineTo(w * 0.72, h * 0.54)
      ..lineTo(w * 0.66, h * 0.40)
      ..lineTo(w * 0.34, h * 0.40)
      ..close();
    canvas.drawPath(stripePath, Paint()..color = const Color(0xCCFFFFFF));

    // Cone tip circle.
    canvas.drawCircle(
      Offset(w * 0.50, h * 0.17),
      w * 0.08,
      Paint()..color = const Color(0xFFFF8A65),
    );
  }

  void _renderBarrier(Canvas canvas) {
    final w = size.x;
    final h = size.y;

    // Two support legs.
    final legPaint = Paint()..color = const Color(0xFF555555);
    canvas.drawRect(Rect.fromLTWH(w * 0.08, h * 0.55, w * 0.10, h * 0.42), legPaint);
    canvas.drawRect(Rect.fromLTWH(w * 0.82, h * 0.55, w * 0.10, h * 0.42), legPaint);

    // Horizontal barrier main beam.
    final beamRect = Rect.fromLTWH(w * 0.04, h * 0.25, w * 0.92, h * 0.34);
    // Draw alternating red/white stripes.
    const stripeCount = 6;
    final stripeW = beamRect.width / stripeCount;
    canvas.save();
    canvas.clipRect(beamRect);
    for (int i = 0; i < stripeCount; i++) {
      canvas.drawRect(
        Rect.fromLTWH(beamRect.left + i * stripeW, beamRect.top, stripeW, beamRect.height),
        Paint()..color = i.isEven ? const Color(0xFFFFFFFF) : const Color(0xFFDD2222),
      );
    }
    canvas.restore();
    // Beam outline.
    canvas.drawRect(
      beamRect,
      Paint()
        ..color = const Color(0x88000000)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.0,
    );

    // Barrier top highlight.
    canvas.drawRect(
      Rect.fromLTWH(w * 0.04, h * 0.25, w * 0.92, h * 0.06),
      Paint()..color = const Color(0x33FFFFFF),
    );
  }

  void _renderPothole(Canvas canvas) {
    final w = size.x;
    final h = size.y;
    final c = Offset(w / 2, h / 2);

    // Outer irregular shadow.
    canvas.drawOval(
      Rect.fromCenter(center: c, width: w * 0.95, height: h * 0.90),
      Paint()..color = const Color(0xFF111111),
    );
    // Inner darker pit.
    canvas.drawOval(
      Rect.fromCenter(center: c, width: w * 0.76, height: h * 0.70),
      Paint()..color = const Color(0xFF080808),
    );
    // Crack lines radiating outward.
    final crackPaint = Paint()
      ..color = const Color(0xFF1A1A1A)
      ..strokeWidth = 1.5
      ..strokeCap = StrokeCap.round;
    for (final angle in [0.0, 0.7, 1.4, 2.2, 3.0, 4.0]) {
      canvas.drawLine(
        Offset(c.dx + cos(angle) * w * 0.10, c.dy + sin(angle) * h * 0.10),
        Offset(c.dx + cos(angle) * w * 0.46, c.dy + sin(angle) * h * 0.44),
        crackPaint,
      );
    }
    // Asphalt texture ring.
    canvas.drawOval(
      Rect.fromCenter(center: c, width: w * 0.88, height: h * 0.82),
      Paint()
        ..color = const Color(0x33444444)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.0,
    );
  }

  void _renderHydrant(Canvas canvas) {
    final w = size.x;
    final h = size.y;

    // Base flange (wide oval at bottom).
    canvas.drawOval(
      Rect.fromLTWH(w * 0.05, h * 0.82, w * 0.90, h * 0.14),
      Paint()..color = const Color(0xFF8B0000),
    );

    // Body (chunky rounded rect).
    final body = RRect.fromRectAndRadius(
      Rect.fromLTWH(w * 0.15, h * 0.22, w * 0.70, h * 0.63),
      const Radius.circular(6),
    );
    canvas.drawRRect(
      body,
      Paint()
        ..shader = Gradient.linear(
          Offset(w * 0.15, h * 0.22),
          Offset(w * 0.85, h * 0.85),
          [const Color(0xFFEF4444), const Color(0xFFB91C1C)],
        ),
    );

    // Pentagon top cap (5-sided, slightly wider than body).
    final capCx = w * 0.50;
    final capCy = h * 0.18;
    final capRx = w * 0.44;
    final capRy = h * 0.12;
    final penPath = Path();
    for (int i = 0; i < 5; i++) {
      final angle = -pi / 2 + (2 * pi * i / 5);
      final px = capCx + capRx * cos(angle);
      final py = capCy + capRy * sin(angle);
      if (i == 0) {
        penPath.moveTo(px, py);
      } else {
        penPath.lineTo(px, py);
      }
    }
    penPath.close();
    canvas.drawPath(penPath, Paint()..color = const Color(0xFFB71C1C));
    // Cap outline.
    canvas.drawPath(
      penPath,
      Paint()
        ..color = const Color(0xFF8B0000)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.0,
    );

    // Side bolt nubs (hexagonal caps left and right).
    for (final nx in [w * 0.00, w * 0.72]) {
      canvas.drawOval(
        Rect.fromLTWH(nx, h * 0.36, w * 0.28, h * 0.16),
        Paint()..color = const Color(0xFFCC2222),
      );
      // Bolt centre dot.
      canvas.drawCircle(
        Offset(nx + w * 0.14, h * 0.44),
        2.5,
        Paint()..color = const Color(0xFF8B0000),
      );
    }

    // Shine highlight.
    canvas.drawOval(
      Rect.fromLTWH(w * 0.22, h * 0.26, w * 0.20, h * 0.14),
      Paint()..color = const Color(0x44FFFFFF),
    );

    // Pulsing water drop (animated).
    final pulse = 0.7 + 0.3 * sin(_life * 2 * pi * 3);
    canvas.drawCircle(
      Offset(w / 2, h * 0.08),
      4.0 * pulse,
      Paint()..color = const Color(0xAA42A5F5),
    );
  }

  void _renderTrashBin(Canvas canvas) {
    final w = size.x;
    final h = size.y;

    // Body with metallic gradient.
    final bodyRect = Rect.fromLTWH(w * 0.10, h * 0.18, w * 0.80, h * 0.78);
    canvas.drawRRect(
      RRect.fromRectAndRadius(bodyRect, const Radius.circular(4)),
      Paint()
        ..shader = Gradient.linear(
          bodyRect.topLeft,
          bodyRect.topRight,
          [const Color(0xFF5A5A5A), const Color(0xFF8A8A8A), const Color(0xFF5A5A5A)],
          [0.0, 0.45, 1.0],
        ),
    );

    // Horizontal ridges.
    final ridgePaint = Paint()..color = const Color(0xFF404040);
    for (final y in [0.40, 0.60]) {
      canvas.drawRect(
        Rect.fromLTWH(w * 0.10, h * y, w * 0.80, 2),
        ridgePaint,
      );
    }

    // Shine line.
    canvas.drawRect(
      Rect.fromLTWH(w * 0.30, h * 0.20, w * 0.08, h * 0.74),
      Paint()..color = const Color(0x558E8E8E),
    );

    // Rivets.
    for (final rx in [w * 0.20, w * 0.70]) {
      canvas.drawCircle(
        Offset(rx, h * 0.50),
        2.5,
        Paint()..color = const Color(0xFF333333),
      );
    }

    // Lid (slightly wider flat oval on top).
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(w * 0.05, h * 0.05, w * 0.90, h * 0.17),
        const Radius.circular(5),
      ),
      Paint()..color = const Color(0xFF333333),
    );
    // Lid handle knob.
    canvas.drawOval(
      Rect.fromLTWH(w * 0.40, h * 0.01, w * 0.20, h * 0.07),
      Paint()..color = const Color(0xFF444444),
    );
    // Lid shine.
    canvas.drawOval(
      Rect.fromLTWH(w * 0.12, h * 0.07, w * 0.28, h * 0.06),
      Paint()..color = const Color(0x33FFFFFF),
    );

    // Stink wavy lines when tipped over.
    if (_tipAngle != 0) {
      final stinkPaint = Paint()
        ..color = const Color(0x99A5D6A7)
        ..strokeWidth = 1.5
        ..style = PaintingStyle.stroke;
      for (int i = 0; i < 3; i++) {
        final stinkPath = Path();
        final startX = w * (0.30 + i * 0.18);
        stinkPath.moveTo(startX, h * 0.05);
        for (int s = 0; s < 4; s++) {
          stinkPath.relativeQuadraticBezierTo(
            (i.isEven ? 5 : -5).toDouble(), -6,
            0, -12,
          );
        }
        canvas.drawPath(stinkPath, stinkPaint);
      }
    }
  }

  void _renderKidBike(Canvas canvas) {
    final w = size.x;
    final h = size.y;

    final wheelPaint = Paint()..color = const Color(0xFF222222);
    final hubPaint = Paint()..color = const Color(0xFFB0B0B0);
    const wheelR = 0.18;
    final wheelY = h * 0.78;
    final wheelLX = w * 0.30;
    final wheelRX = w * 0.70;
    canvas.drawCircle(Offset(wheelLX, wheelY), w * wheelR, wheelPaint);
    canvas.drawCircle(Offset(wheelRX, wheelY), w * wheelR, wheelPaint);
    canvas.drawCircle(Offset(wheelLX, wheelY), w * wheelR * 0.35, hubPaint);
    canvas.drawCircle(Offset(wheelRX, wheelY), w * wheelR * 0.35, hubPaint);

    // Bike frame — red diamond.
    final framePaint = Paint()
      ..color = const Color(0xFFE53935)
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(Offset(wheelLX, wheelY), Offset(wheelRX, wheelY), framePaint);
    canvas.drawLine(Offset(w * 0.50, h * 0.55), Offset(wheelLX + w * wheelR * 0.5, wheelY), framePaint);
    canvas.drawLine(Offset(w * 0.50, h * 0.55), Offset(wheelRX - w * wheelR * 0.5, wheelY), framePaint);

    // Rider torso (orange shirt, smaller than player).
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(w * 0.30, h * 0.30, w * 0.40, h * 0.30),
        const Radius.circular(3),
      ),
      Paint()..color = const Color(0xFFFF9800),
    );

    // Arms.
    final armPaint = Paint()..color = const Color(0xFFFFCC80);
    canvas.drawRect(Rect.fromLTWH(w * 0.20, h * 0.42, w * 0.14, h * 0.08), armPaint);
    canvas.drawRect(Rect.fromLTWH(w * 0.66, h * 0.42, w * 0.14, h * 0.08), armPaint);

    // Handlebars.
    canvas.drawRect(
      Rect.fromLTWH(w * 0.18, h * 0.48, w * 0.64, 3),
      Paint()..color = const Color(0xFF111111),
    );

    // Head.
    canvas.drawCircle(
      Offset(w * 0.50, h * 0.20),
      w * 0.13,
      Paint()..color = const Color(0xFFFFCC80),
    );
    // Hair.
    canvas.drawCircle(
      Offset(w * 0.50, h * 0.14),
      w * 0.11,
      Paint()..color = const Color(0xFF5D4037),
    );
  }

  void _renderManhole(Canvas canvas) {
    final cx = size.x / 2;
    final cy = size.y / 2;
    final c = Offset(cx, cy);

    // Outer ring (dark iron).
    canvas.drawOval(
      Rect.fromCenter(center: c, width: size.x, height: size.y),
      Paint()..color = const Color(0xFF1A1A1A),
    );
    // Inner face (slightly lighter iron).
    canvas.drawOval(
      Rect.fromCenter(center: c, width: size.x * 0.88, height: size.y * 0.78),
      Paint()..color = const Color(0xFF333333),
    );

    // Iron grid pattern (horizontal + vertical lines clipped to oval).
    canvas.save();
    final gridClip = Path()
      ..addOval(Rect.fromCenter(center: c, width: size.x * 0.86, height: size.y * 0.76));
    canvas.clipPath(gridClip);

    final gridPaint = Paint()
      ..color = const Color(0xFF222222)
      ..strokeWidth = 1.2;
    const cols = 5;
    const rows = 4;
    for (int col = 0; col <= cols; col++) {
      final x = size.x * 0.07 + (size.x * 0.86 / cols) * col;
      canvas.drawLine(Offset(x, 0), Offset(x, size.y), gridPaint);
    }
    for (int row = 0; row <= rows; row++) {
      final y = size.y * 0.11 + (size.y * 0.78 / rows) * row;
      canvas.drawLine(Offset(0, y), Offset(size.x, y), gridPaint);
    }
    canvas.restore();

    // Concentric ring near edge.
    canvas.drawOval(
      Rect.fromCenter(center: c, width: size.x * 0.70, height: size.y * 0.58),
      Paint()
        ..color = const Color(0xFF252525)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.0,
    );

    // Outer ring highlight.
    canvas.drawOval(
      Rect.fromCenter(center: c, width: size.x, height: size.y),
      Paint()
        ..color = const Color(0xFF404040)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.5,
    );
  }

  @override
  void onCollisionStart(
      Set<Vector2> intersectionPoints, PositionComponent other) {
    super.onCollisionStart(intersectionPoints, other);
    if (_hasHitPlayer) return;
    if (other is PlayerComponent) {
      _hasHitPlayer = true;
      if (isStaticOnSidewalk && !isLethal) return;
      if (isDrenching) {
        gameRef.onPlayerDrenched();
        return;
      }
      if (isLethal) {
        gameRef.onPlayerHitObstacle();
      } else {
        gameRef.onPlayerHitSlowObstacle();
      }
    }
  }
}
