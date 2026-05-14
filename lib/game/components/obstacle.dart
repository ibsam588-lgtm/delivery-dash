import 'dart:math';
import 'package:flame/collisions.dart';
import 'package:flame/components.dart';
import 'package:flame/flame.dart';
import 'package:flutter/material.dart';
import '../delivery_dash_game.dart';
import 'player.dart';

enum ObstacleType {
  car,
  dog,
  worker,
  cone,
  barrier,
  pothole,
  hydrant,
}

Vector2 _baseSizeFor(ObstacleType t) {
  switch (t) {
    case ObstacleType.car:
      return Vector2(72, 120);
    case ObstacleType.dog:
      return Vector2(58, 46);
    case ObstacleType.worker:
      return Vector2(56, 90);
    case ObstacleType.cone:
      return Vector2(44, 56);
    case ObstacleType.barrier:
      return Vector2(88, 56);
    case ObstacleType.pothole:
      return Vector2(56, 40);
    case ObstacleType.hydrant:
      return Vector2(32, 44);
  }
}

class ObstacleComponent extends PositionComponent
    with HasGameRef<DeliveryDashGame>, CollisionCallbacks {
  final ObstacleType type;
  final double laneFraction;
  final int carVariant;
  final bool onRightSidewalk;

  final double _speedFactor;
  final bool _isOvertaker;

  Sprite? _sprite;
  final Paint _spritePaint = Paint()
    ..filterQuality = FilterQuality.none
    ..isAntiAlias = false;

  bool _hasHitPlayer = false;
  final Vector2 _baseSize;

  final double _animPhase = Random().nextDouble() * 2 * pi;
  double _life = 0;
  final double _zigzagSeed = Random().nextDouble() * 2 * pi;
  final double _zigzagDir = 1;
  double _dogStartX = 0;

  ObstacleComponent({
    required this.type,
    required this.laneFraction,
    int? carVariant,
    double speedFactor = 1.0,
    bool isOvertaker = false,
    this.onRightSidewalk = false,
  })  : carVariant = carVariant ?? Random().nextInt(4),
        _speedFactor = speedFactor,
        _isOvertaker = isOvertaker,
        _baseSize = _baseSizeFor(type).clone(),
        super(anchor: Anchor.bottomCenter, priority: 3);

  bool get isLethal =>
      type == ObstacleType.car ||
      type == ObstacleType.dog ||
      type == ObstacleType.worker;

  bool get isDrenching => type == ObstacleType.hydrant;

  String? get _spriteName {
    switch (type) {
      case ObstacleType.car:
        switch (carVariant) {
          case 0:
            return 'car_2.png';
          case 1:
            return 'car_3.png';
          case 2:
            return 'dog.png';
          default:
            return 'worker.png';
        }
      case ObstacleType.dog:
        return null; // drawn procedurally
      case ObstacleType.worker:
        return 'barrier.png';
      case ObstacleType.cone:
        return 'pothole.png';
      case ObstacleType.barrier:
        return 'house_0.png';
      case ObstacleType.pothole:
        return 'house_1.png';
      case ObstacleType.hydrant:
        return null; // drawn procedurally
    }
  }

  @override
  Future<void> onLoad() async {
    final name = _spriteName;
    if (name != null) {
      _sprite = Sprite(Flame.images.fromCache(name));
    }
    size = _baseSize.clone();

    final lm = gameRef.laneManager;
    const initialY = -10.0;
    final scale = lm.scaleAt(initialY);
    size = _baseSize * scale;

    final double x;
    if (onRightSidewalk) {
      final sidewalkLeft = lm.roadRightAt(initialY);
      final sidewalkRight = gameRef.size.x;
      final t = laneFraction.clamp(0.0, 1.0);
      x = sidewalkLeft + (sidewalkRight - sidewalkLeft) * t;
    } else {
      x = lm.roadXFromFraction(laneFraction, initialY);
    }
    position = Vector2(x, initialY);
    _dogStartX = x;

    add(RectangleHitbox(
      size: size * 0.78,
      position: size * 0.11,
    ));
  }

  @override
  void update(double dt) {
    super.update(dt);
    _life += dt;

    final lm = gameRef.laneManager;
    final road = gameRef.scrollSpeed;

    double vy;
    if (type == ObstacleType.car) {
      final base = road * _speedFactor;
      vy = _isOvertaker ? road * 1.3 : base;
    } else {
      vy = road;
    }
    position.y += vy * dt;

    final scale = lm.scaleAt(position.y);
    final newSize = _baseSize * scale;
    if ((newSize - size).length > 0.5) {
      size = newSize;
      _resizeHitbox();
    }

    if (onRightSidewalk) {
      final sidewalkLeft = lm.roadRightAt(position.y);
      final sidewalkRight = gameRef.size.x;
      final t = laneFraction.clamp(0.0, 1.0);
      position.x = sidewalkLeft + (sidewalkRight - sidewalkLeft) * t;
    } else {
      position.x = lm.roadXFromFraction(laneFraction, position.y);
    }

    switch (type) {
      case ObstacleType.worker:
        final bob = sin((_life + _animPhase) * 2 * pi * 1.5) * 4 * scale;
        position.y += bob * dt;
        break;
      case ObstacleType.dog:
        final amplitude = lm.roadWidthAt(position.y) * 0.45;
        final phase = _life * 1.6 + _zigzagSeed;
        position.x = _dogStartX + sin(phase) * amplitude * _zigzagDir;
        position.x = position.x.clamp(
          lm.roadLeftAt(position.y) - 20,
          lm.roadRightAt(position.y) + 20,
        );
        break;
      default:
        break;
    }

    if (position.y > gameRef.size.y + size.y) {
      removeFromParent();
    }
  }

  void _resizeHitbox() {
    for (final c in children.whereType<RectangleHitbox>().toList()) {
      c.size.setFrom(size * 0.78);
      c.position.setFrom(size * 0.11);
    }
  }

  @override
  void render(Canvas canvas) {
    // Drop shadow under everything that's a "ground" object.
    if (type == ObstacleType.car ||
        type == ObstacleType.worker ||
        type == ObstacleType.cone ||
        type == ObstacleType.barrier ||
        type == ObstacleType.pothole) {
      canvas.drawOval(
        Rect.fromCenter(
          center: Offset(size.x / 2, size.y - 3),
          width: size.x * 0.85,
          height: size.y * 0.10,
        ),
        Paint()..color = const Color(0x66000000),
      );
    }

    if (_sprite != null) {
      _sprite!.render(canvas, size: size, overridePaint: _spritePaint);
    } else if (type == ObstacleType.hydrant) {
      _renderHydrant(canvas);
    } else if (type == ObstacleType.dog) {
      _renderDog(canvas);
    }
  }

  void _renderHydrant(Canvas canvas) {
    final bodyRect = RRect.fromRectAndRadius(
      Rect.fromLTWH(size.x * 0.18, size.y * 0.30, size.x * 0.64, size.y * 0.65),
      Radius.circular(size.x * 0.18),
    );
    canvas.drawRRect(bodyRect, Paint()..color = const Color(0xFFD32F2F));
    canvas.drawOval(
      Rect.fromLTWH(size.x * 0.10, size.y * 0.20, size.x * 0.80, size.y * 0.20),
      Paint()..color = const Color(0xFFB71C1C),
    );
    canvas.drawOval(
      Rect.fromLTWH(0, size.y * 0.45, size.x * 0.22, size.y * 0.20),
      Paint()..color = const Color(0xFFB71C1C),
    );
    canvas.drawOval(
      Rect.fromLTWH(size.x * 0.78, size.y * 0.45, size.x * 0.22, size.y * 0.20),
      Paint()..color = const Color(0xFFB71C1C),
    );

    final pulse = 0.8 + 0.2 * (0.5 + 0.5 * sin(_life * 2 * pi * 3));
    final centerX = size.x / 2;
    final baseY = size.y * 0.18;
    final blue = Paint()
      ..color = const Color(0xFF42A5F5)
      ..strokeWidth = 3
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    for (var i = -1; i <= 1; i++) {
      final dx = i * size.x * 0.32 * pulse;
      final dy = -size.y * 0.28 * pulse;
      final p = Path()
        ..moveTo(centerX, baseY)
        ..quadraticBezierTo(
          centerX + dx * 0.5,
          baseY + dy * 0.8,
          centerX + dx,
          baseY + dy,
        );
      canvas.drawPath(p, blue);
    }
    canvas.drawCircle(
      Offset(centerX, baseY - 4),
      2 * pulse,
      Paint()..color = const Color(0xFFBBDEFB),
    );
  }

  /// Procedurally-drawn brown dog. 4 legs animated by a sine, head with
  /// triangle ears, wagging tail.
  void _renderDog(Canvas canvas) {
    final w = size.x;
    final h = size.y;
    const brown = Color(0xFF8B4513);
    const dark = Color(0xFF5D2F0A);
    const pink = Color(0xFFE6A0A0);

    // Body: oval, low to the ground.
    canvas.drawOval(
      Rect.fromLTWH(w * 0.10, h * 0.30, w * 0.70, h * 0.55),
      Paint()..color = brown,
    );

    // Running leg phase — front pair / back pair alternate.
    final legPhase = sin(_life * 2 * pi * 4);
    final legOffsetA = legPhase > 0 ? 4.0 : 0.0;
    final legOffsetB = legPhase > 0 ? 0.0 : 4.0;
    final legPaint = Paint()..color = dark;
    canvas.drawRect(
        Rect.fromLTWH(w * 0.20, h * 0.78, 4, h * 0.18 + legOffsetA), legPaint);
    canvas.drawRect(
        Rect.fromLTWH(w * 0.30, h * 0.78, 4, h * 0.18 + legOffsetB), legPaint);
    canvas.drawRect(
        Rect.fromLTWH(w * 0.56, h * 0.78, 4, h * 0.18 + legOffsetB), legPaint);
    canvas.drawRect(
        Rect.fromLTWH(w * 0.66, h * 0.78, 4, h * 0.18 + legOffsetA), legPaint);

    // Head — circle on the front (top, since obstacles face downward at us).
    final headCenter = Offset(w * 0.78, h * 0.28);
    canvas.drawCircle(headCenter, h * 0.22, Paint()..color = brown);
    // Ears.
    final earPaint = Paint()..color = dark;
    final ear1 = Path()
      ..moveTo(headCenter.dx - h * 0.18, headCenter.dy - h * 0.04)
      ..lineTo(headCenter.dx - h * 0.06, headCenter.dy - h * 0.26)
      ..lineTo(headCenter.dx - h * 0.02, headCenter.dy - h * 0.10)
      ..close();
    final ear2 = Path()
      ..moveTo(headCenter.dx + h * 0.18, headCenter.dy - h * 0.04)
      ..lineTo(headCenter.dx + h * 0.06, headCenter.dy - h * 0.26)
      ..lineTo(headCenter.dx + h * 0.02, headCenter.dy - h * 0.10)
      ..close();
    canvas.drawPath(ear1, earPaint);
    canvas.drawPath(ear2, earPaint);

    // Eyes.
    final eyeWhite = Paint()..color = Colors.white;
    final eyeBlack = Paint()..color = Colors.black;
    canvas.drawCircle(
        Offset(headCenter.dx - 4, headCenter.dy - 2), 2, eyeWhite);
    canvas.drawCircle(
        Offset(headCenter.dx + 4, headCenter.dy - 2), 2, eyeWhite);
    canvas.drawCircle(
        Offset(headCenter.dx - 4, headCenter.dy - 2), 1, eyeBlack);
    canvas.drawCircle(
        Offset(headCenter.dx + 4, headCenter.dy - 2), 1, eyeBlack);

    // Nose.
    canvas.drawCircle(
      Offset(headCenter.dx, headCenter.dy + 5),
      2.5,
      Paint()..color = Colors.black,
    );
    // Tongue.
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(headCenter.dx, headCenter.dy + 8),
        width: 4,
        height: 3,
      ),
      Paint()..color = pink,
    );

    // Wagging tail — sine wave on Y end.
    final tailWag = sin(_life * 2 * pi * 2) * 4;
    final tailPath = Path()
      ..moveTo(w * 0.10, h * 0.40)
      ..quadraticBezierTo(
        w * 0.02,
        h * 0.20 + tailWag,
        w * -0.05,
        h * 0.05 + tailWag,
      );
    canvas.drawPath(
      tailPath,
      Paint()
        ..color = brown
        ..strokeWidth = 4
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round,
    );
  }

  @override
  void onCollisionStart(
      Set<Vector2> intersectionPoints, PositionComponent other) {
    super.onCollisionStart(intersectionPoints, other);
    if (_hasHitPlayer) return;
    if (other is PlayerComponent) {
      _hasHitPlayer = true;
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
