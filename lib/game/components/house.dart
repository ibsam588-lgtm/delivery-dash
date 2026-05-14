import 'dart:math';
import 'dart:ui';
import 'package:flame/components.dart';
import '../delivery_dash_game.dart';
import 'house_window.dart';
import 'mailbox.dart';

class HouseComponent extends PositionComponent
    with HasGameRef<DeliveryDashGame> {
  static const double rowSpacing = 180.0;
  static const double fixedWidth = 100.0;
  static const double fixedHeight = 110.0;

  final double _initialY;
  int _index;
  final Random _rng = Random();

  MailboxComponent? _mailbox;
  final List<HouseWindow> _windows = [];

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

  int _palette() => _index % 3;

  void _alignToSidewalk() {
    final lm = gameRef.laneManager;
    final roadLeft = lm.roadLeft;
    final fitWidth = (roadLeft - 8).clamp(40.0, fixedWidth);
    final sizeChanged = (fitWidth - size.x).abs() > 0.5;
    if (sizeChanged) {
      size = Vector2(fitWidth, fitWidth * (fixedHeight / fixedWidth));
      _layoutWindows();
    }
    final x = roadLeft - size.x - 4;
    position.x = x < 0 ? 0 : x;
  }

  @override
  Future<void> onLoad() async {
    position = Vector2(0, _initialY);
    _alignToSidewalk();
    _regenerateMailbox();
    _spawnWindows();
  }

  void _regenerateMailbox() {
    _mailbox?.removeFromParent();
    _mailbox = null;
    final r = _rng.nextDouble();
    if (r < 0.10) return;
    final isBlue = r < 0.80;
    final mb = MailboxComponent(isBlue: isBlue);
    mb.position = Vector2(size.x + 6, size.y * 0.6);
    add(mb);
    _mailbox = mb;
  }

  void _spawnWindows() {
    final w1 = HouseWindow(position: Vector2.zero());
    final w2 = HouseWindow(position: Vector2.zero());
    _windows
      ..clear()
      ..add(w1)
      ..add(w2);
    add(w1);
    add(w2);
    _layoutWindows();
  }

  void _layoutWindows() {
    if (_windows.isEmpty) return;
    final winW = (size.x * 0.17).clamp(11.0, 19.0);
    final winH = (size.y * 0.14).clamp(10.0, 17.0);
    final winSize = Vector2(winW, winH);
    // Place both windows on the front facade (left ~72% of sprite).
    _windows[0]
      ..size = winSize
      ..position = Vector2(size.x * 0.06, size.y * 0.29);
    _windows[1]
      ..size = winSize
      ..position = Vector2(size.x * 0.36, size.y * 0.29);
  }

  @override
  void render(Canvas canvas) {
    _renderHouse(canvas);
    super.render(canvas);
  }

  void _renderHouse(Canvas canvas) {
    final w = size.x;
    final h = size.y;
    final p = _palette();

    // Color palettes.
    late Color wallTop, wallBot, sideColor, roofFront, roofSide, doorColor;
    switch (p) {
      case 0: // cream / red roof
        wallTop = const Color(0xFFF5E6C8);
        wallBot = const Color(0xFFE0C89A);
        sideColor = const Color(0xFFCCAA78);
        roofFront = const Color(0xFFB03030);
        roofSide = const Color(0xFF7A1A1A);
        doorColor = const Color(0xFF6D3A20);
      case 1: // tan / grey roof
        wallTop = const Color(0xFFD4B896);
        wallBot = const Color(0xFFBCA07A);
        sideColor = const Color(0xFFA88858);
        roofFront = const Color(0xFF7A7A7A);
        roofSide = const Color(0xFF484848);
        doorColor = const Color(0xFF5C3018);
      default: // white / blue roof
        wallTop = const Color(0xFFF2F0E8);
        wallBot = const Color(0xFFDEDAD0);
        sideColor = const Color(0xFFCCC8BC);
        roofFront = const Color(0xFF3A6AAA);
        roofSide = const Color(0xFF284E82);
        doorColor = const Color(0xFF5C3018);
    }

    // Ground shadow.
    canvas.drawOval(
      Rect.fromLTWH(2, h - 8, w - 4, 10),
      Paint()..color = const Color(0x44000000),
    );

    // --- Isometric layout constants (proportional) ---
    final fRight = w * 0.72; // front facade right edge
    final fTop = h * 0.24;   // top of walls
    final fBot = h * 0.95;   // bottom of walls (ground)
    final sTop = h * 0.11;   // side wall top (skewed up)
    final sBot = h * 0.83;   // side wall bottom (skewed up)
    final sRight = w * 0.99;
    final peakX = w * 0.36;
    final peakY = h * 0.04;

    // Front facade with vertical gradient.
    final frontRect = Rect.fromLTRB(0, fTop, fRight, fBot);
    canvas.drawRect(
      frontRect,
      Paint()
        ..shader = Gradient.linear(
          Offset(0, fTop),
          Offset(0, fBot),
          [wallTop, wallBot],
        ),
    );
    // Front facade outline.
    canvas.drawRect(
      frontRect,
      Paint()
        ..color = const Color(0x33000000)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0.8,
    );

    // Side wall (right face, darker).
    final sidePath = Path()
      ..moveTo(fRight, fTop)
      ..lineTo(sRight, sTop)
      ..lineTo(sRight, sBot)
      ..lineTo(fRight, fBot)
      ..close();
    canvas.drawPath(sidePath, Paint()..color = sideColor);
    canvas.drawPath(
      sidePath,
      Paint()
        ..color = const Color(0x22000000)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0.8,
    );

    // Roof front triangle.
    final roofFrontPath = Path()
      ..moveTo(0, fTop)
      ..lineTo(fRight, fTop)
      ..lineTo(peakX, peakY)
      ..close();
    canvas.drawPath(roofFrontPath, Paint()..color = roofFront);

    // Roof side triangle (darker overhang).
    final roofSidePath = Path()
      ..moveTo(fRight, fTop)
      ..lineTo(sRight, sTop)
      ..lineTo(peakX, peakY)
      ..close();
    canvas.drawPath(roofSidePath, Paint()..color = roofSide);

    // Roof ridge highlight.
    canvas.drawLine(
      Offset(0, fTop),
      Offset(peakX, peakY),
      Paint()
        ..color = const Color(0x44FFFFFF)
        ..strokeWidth = 1.0,
    );

    // Chimney on side wall.
    final chimneyRect = Rect.fromLTWH(w * 0.70, -h * 0.06, w * 0.12, h * 0.16);
    canvas.drawRect(chimneyRect, Paint()..color = const Color(0xFF8B3A2A));
    // Chimney top cap.
    canvas.drawRect(
      Rect.fromLTWH(w * 0.68, -h * 0.06, w * 0.16, h * 0.025),
      Paint()..color = const Color(0xFF6A2A1A),
    );
    // Chimney mortar lines.
    final mortarPaint = Paint()
      ..color = const Color(0x44000000)
      ..strokeWidth = 0.8;
    canvas.drawLine(
      Offset(w * 0.70, h * 0.02),
      Offset(w * 0.82, h * 0.02),
      mortarPaint,
    );

    // Door (centered on front facade).
    final doorL = w * 0.24;
    final doorR = w * 0.50;
    final doorTop = h * 0.63;
    final doorBot = fBot;
    final doorRect = Rect.fromLTRB(doorL, doorTop, doorR, doorBot);
    // Door body.
    canvas.drawRect(doorRect, Paint()..color = doorColor);
    // Door arch (rounded top).
    final archRect = Rect.fromLTWH(doorL, doorTop - (doorR - doorL) * 0.22,
        doorR - doorL, (doorR - doorL) * 0.44);
    canvas.drawOval(archRect, Paint()..color = doorColor);
    // Door frame.
    canvas.drawRRect(
      RRect.fromRectAndCorners(
        doorRect,
        topLeft: Radius.circular((doorR - doorL) * 0.22),
        topRight: Radius.circular((doorR - doorL) * 0.22),
      ),
      Paint()
        ..color = const Color(0xFF3A1A08)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5,
    );
    // Door handle.
    canvas.drawCircle(
      Offset(doorR - (doorR - doorL) * 0.20, h * 0.78),
      2.5,
      Paint()..color = const Color(0xFFFFD600),
    );

    // Steps at door base.
    final stepPaint = Paint()..color = const Color(0xFFCCCCCC);
    canvas.drawRect(
      Rect.fromLTWH(doorL - w * 0.04, fBot - h * 0.04, (doorR - doorL) + w * 0.08, h * 0.04),
      stepPaint,
    );
    canvas.drawRect(
      Rect.fromLTWH(doorL - w * 0.02, fBot - h * 0.07, (doorR - doorL) + w * 0.04, h * 0.03),
      Paint()..color = const Color(0xFFBBBBBB),
    );

    // Bushes flanking the door.
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(doorL - w * 0.05, fBot - h * 0.05),
        width: w * 0.14,
        height: h * 0.09,
      ),
      Paint()..color = const Color(0xFF2E6B1E),
    );
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(doorR + w * 0.05, fBot - h * 0.05),
        width: w * 0.14,
        height: h * 0.09,
      ),
      Paint()..color = const Color(0xFF2E6B1E),
    );
    // Bush highlight.
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(doorL - w * 0.07, fBot - h * 0.07),
        width: w * 0.06,
        height: h * 0.04,
      ),
      Paint()..color = const Color(0x4466CC44),
    );
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(doorR + w * 0.03, fBot - h * 0.07),
        width: w * 0.06,
        height: h * 0.04,
      ),
      Paint()..color = const Color(0x4466CC44),
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
      _regenerateMailbox();
      for (final w in _windows) {
        w.restore();
      }
    }
  }
}
