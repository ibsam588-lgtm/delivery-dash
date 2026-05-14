import 'dart:math';
import 'package:flame/components.dart';
import 'package:flutter/material.dart';
import '../delivery_dash_game.dart';
import 'mailbox.dart';

/// Procedurally-drawn house. Fixed size, sits on the left sidewalk and
/// scrolls down. Body / roof / windows / door / driveway / bushes are
/// drawn with canvas primitives so the visual quality doesn't depend
/// on a small pixel PNG being upscaled.
class HouseComponent extends PositionComponent
    with HasGameRef<DeliveryDashGame> {
  static const double rowSpacing = 180.0;
  static const double fixedWidth = 110.0;
  static const double fixedHeight = 140.0;

  final double _initialY;
  int _index;
  final Random _rng = Random();
  late final _HouseStyle _style;

  MailboxComponent? _mailbox;

  HouseComponent({
    required double initialY,
    required int index,
  })  : _initialY = initialY,
        _index = index,
        super(
          size: Vector2(fixedWidth, fixedHeight),
          anchor: Anchor.bottomLeft,
          priority: -5,
        );

  void _pickStyle() {
    _style = _index.isEven
        ? _HouseStyle.beigeRedRoof
        : _HouseStyle.taupeBlueRoof;
  }

  void _alignToSidewalk() {
    final lm = gameRef.laneManager;
    final sidewalkRight = lm.roadLeftAt(position.y);
    final desiredRight = sidewalkRight - 4;
    final x = desiredRight - size.x;
    position.x = x.clamp(2.0, sidewalkRight - size.x - 2);
  }

  @override
  Future<void> onLoad() async {
    _pickStyle();
    position = Vector2(0, _initialY);
    _alignToSidewalk();
    _regenerateMailbox();
  }

  void _regenerateMailbox() {
    _mailbox?.removeFromParent();
    _mailbox = null;
    final r = _rng.nextDouble();
    if (r < 0.10) return;
    final isBlue = r < 0.80;
    final mb = MailboxComponent(isBlue: isBlue);
    mb.position = Vector2(size.x + 6, size.y * 0.78);
    add(mb);
    _mailbox = mb;
  }

  @override
  void render(Canvas canvas) {
    final w = size.x;
    final h = size.y;
    final s = _style;

    // Driveway: gray trapezoid in front of the house.
    final driveway = Path()
      ..moveTo(w * 0.20, h * 0.95)
      ..lineTo(w * 0.80, h * 0.95)
      ..lineTo(w * 0.85, h)
      ..lineTo(w * 0.15, h)
      ..close();
    canvas.drawPath(driveway, Paint()..color = const Color(0xFF707070));

    // Shadow ellipse under the house.
    canvas.drawOval(
      Rect.fromLTWH(4, h * 0.92, w - 8, 8),
      Paint()..color = const Color(0x55000000),
    );

    // Foundation (slightly darker base strip).
    canvas.drawRect(
      Rect.fromLTWH(w * 0.10, h * 0.80, w * 0.80, h * 0.10),
      Paint()..color = const Color(0xFF9E9E9E),
    );

    // Main body.
    final body = Rect.fromLTWH(w * 0.13, h * 0.40, w * 0.74, h * 0.42);
    canvas.drawRect(body, Paint()..color = s.bodyColor);
    canvas.drawRect(
      body,
      Paint()
        ..color = s.bodyOutline
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.2,
    );

    // Roof: triangle pointing up.
    final roof = Path()
      ..moveTo(w * 0.06, h * 0.42)
      ..lineTo(w * 0.50, h * 0.10)
      ..lineTo(w * 0.94, h * 0.42)
      ..close();
    canvas.drawPath(roof, Paint()..color = s.roofColor);
    // Roof shadow line on the right slope for shading.
    canvas.drawPath(
      Path()
        ..moveTo(w * 0.50, h * 0.10)
        ..lineTo(w * 0.94, h * 0.42)
        ..lineTo(w * 0.50, h * 0.42)
        ..close(),
      Paint()..color = s.roofShadow,
    );

    // Two windows.
    _drawWindow(canvas, Rect.fromLTWH(w * 0.20, h * 0.48, w * 0.20, h * 0.18));
    _drawWindow(canvas, Rect.fromLTWH(w * 0.60, h * 0.48, w * 0.20, h * 0.18));

    // Door (centered, with doorknob).
    final door = Rect.fromLTWH(w * 0.42, h * 0.66, w * 0.16, h * 0.16);
    canvas.drawRect(door, Paint()..color = const Color(0xFF4A2511));
    canvas.drawRect(
      door,
      Paint()
        ..color = const Color(0xFF2E1707)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.4,
    );
    canvas.drawCircle(
      Offset(w * 0.54, h * 0.74),
      1.6,
      Paint()..color = const Color(0xFFFFD600),
    );

    // Two green bushes at the corners.
    final bush = Paint()..color = const Color(0xFF2E7D32);
    canvas.drawCircle(Offset(w * 0.10, h * 0.92), 10, bush);
    canvas.drawCircle(Offset(w * 0.90, h * 0.92), 10, bush);
  }

  void _drawWindow(Canvas canvas, Rect r) {
    canvas.drawRect(r, Paint()..color = const Color(0xFF87CEEB));
    // Window frame cross.
    final frame = Paint()
      ..color = Colors.white
      ..strokeWidth = 1.4;
    canvas.drawLine(Offset(r.center.dx, r.top), Offset(r.center.dx, r.bottom),
        frame);
    canvas.drawLine(Offset(r.left, r.center.dy), Offset(r.right, r.center.dy),
        frame);
    // Outer frame.
    canvas.drawRect(
      r,
      Paint()
        ..color = const Color(0xFFE0E0E0)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.4,
    );
  }

  @override
  void update(double dt) {
    super.update(dt);
    if (gameRef.state != GameState.playing) return;
    position.y += gameRef.scrollSpeed * dt;
    _alignToSidewalk();
    if (position.y > gameRef.size.y + size.y) {
      final rows = (gameRef.size.y / rowSpacing).ceil() + 2;
      position.y -= rows * rowSpacing;
      _index += 2;
      _pickStyle();
      _regenerateMailbox();
    }
  }
}

class _HouseStyle {
  final Color bodyColor;
  final Color bodyOutline;
  final Color roofColor;
  final Color roofShadow;
  const _HouseStyle({
    required this.bodyColor,
    required this.bodyOutline,
    required this.roofColor,
    required this.roofShadow,
  });

  static const beigeRedRoof = _HouseStyle(
    bodyColor: Color(0xFFE8C99A),
    bodyOutline: Color(0xFFA37F4F),
    roofColor: Color(0xFF8B1A1A),
    roofShadow: Color(0xFF651212),
  );
  static const taupeBlueRoof = _HouseStyle(
    bodyColor: Color(0xFFD7CCC8),
    bodyOutline: Color(0xFF8F857F),
    roofColor: Color(0xFF1565C0),
    roofShadow: Color(0xFF0D47A1),
  );
}
