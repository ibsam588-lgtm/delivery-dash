import 'dart:math';
import 'dart:ui';
import 'package:flame/components.dart';
import '../delivery_dash_game.dart';
import 'house_window.dart';
import 'mailbox.dart';

// Curtain colour palette — one per house index slot.
const List<Color> _curtainColors = [
  Color(0xFFFFA726), // warm orange
  Color(0xFF64B5F6), // sky blue
  Color(0xFF81C784), // sage green
  Color(0xFFE91E63), // rose
  Color(0xFFFFD54F), // canary yellow
  Color(0xFFBA68C8), // lavender
];

class HouseComponent extends PositionComponent
    with HasGameRef<DeliveryDashGame> {
  static const double rowSpacing = 180.0;
  static const double fixedWidth = 100.0;
  static const double fixedHeight = 110.0;

  final double _initialY;
  int _index;
  final Random _rng = Random();

  bool _isTall = false;

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

  Color _curtainColor() => _curtainColors[_index % _curtainColors.length];

  void _setVariant() {
    _isTall = _index % 5 == 0;
  }

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
    _setVariant();
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
    for (final w in _windows) {
      w.removeFromParent();
    }
    _windows.clear();
    final cc = _curtainColor();
    final w1 = HouseWindow(position: Vector2.zero(), curtainColor: cc);
    final w2 = HouseWindow(position: Vector2.zero(), curtainColor: cc);
    _windows
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
    // Tall houses push the interactive windows up to the upper floor.
    final yFrac = _isTall ? 0.20 : 0.29;
    _windows[0]
      ..size = winSize
      ..position = Vector2(size.x * 0.06, size.y * yFrac);
    _windows[1]
      ..size = winSize
      ..position = Vector2(size.x * 0.36, size.y * yFrac);
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

    // Color palettes — 3 base + 2 extra roof colour variants.
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

    // Extra palette variation for 4th / 5th index slots.
    if (_index % 7 == 4) {
      roofFront = const Color(0xFF2E7D32); // forest green roof
      roofSide = const Color(0xFF1B5E20);
    } else if (_index % 7 == 6) {
      roofFront = const Color(0xFF6A1B9A); // purple roof
      roofSide = const Color(0xFF4A148C);
    }

    // Ground shadow.
    canvas.drawOval(
      Rect.fromLTWH(2, h - 8, w - 4, 10),
      Paint()..color = const Color(0x44000000),
    );

    // --- Isometric layout constants (proportional) ---
    final fRight = w * 0.72;
    final fTop = h * 0.24;
    final fBot = h * 0.95;
    final sTop = h * 0.11;
    final sBot = h * 0.83;
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
    canvas.drawRect(
      frontRect,
      Paint()
        ..color = const Color(0x33000000)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0.8,
    );

    // 2-storey floor divider ledge.
    if (_isTall) {
      final ledgeY = h * 0.52;
      canvas.drawRect(
        Rect.fromLTRB(0, ledgeY - 2, fRight, ledgeY + 2),
        Paint()..color = sideColor,
      );
      // Lower-floor decorative windows (visual only, non-interactive).
      final lWinW = (w * 0.17).clamp(11.0, 19.0);
      final lWinH = (h * 0.14).clamp(10.0, 17.0);
      final lWinY = h * 0.57;
      final cc = _curtainColor();
      for (final lx in [w * 0.06, w * 0.36]) {
        // Pane.
        canvas.drawRect(
          Rect.fromLTWH(lx, lWinY, lWinW, lWinH),
          Paint()..color = const Color(0xFFB3E5FC),
        );
        // Curtains.
        final cw = lWinW * 0.22;
        canvas.drawRect(
          Rect.fromLTWH(lx, lWinY, cw, lWinH),
          Paint()..color = cc.withValues(alpha: 0.55),
        );
        canvas.drawRect(
          Rect.fromLTWH(lx + lWinW - cw, lWinY, cw, lWinH),
          Paint()..color = cc.withValues(alpha: 0.55),
        );
        // Mullion.
        final mp = Paint()
          ..color = const Color(0xFF3E2A1E)
          ..strokeWidth = 1.2;
        canvas.drawLine(Offset(lx + lWinW / 2, lWinY), Offset(lx + lWinW / 2, lWinY + lWinH), mp);
        canvas.drawLine(Offset(lx, lWinY + lWinH / 2), Offset(lx + lWinW, lWinY + lWinH / 2), mp);
        // Frame.
        canvas.drawRect(
          Rect.fromLTWH(lx, lWinY, lWinW, lWinH),
          Paint()
            ..color = const Color(0xFF3E2A1E)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.5,
        );
      }
    }

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

    // Roof shingle lines (darker horizontal bands across front triangle).
    final shinglePaint = Paint()
      ..color = roofSide.withValues(alpha: 0.5)
      ..strokeWidth = 1.2;
    for (int i = 1; i <= 4; i++) {
      final t = i / 5.0;
      final sy = peakY + (fTop - peakY) * t;
      // Interpolate x bounds of the triangle at this y.
      final leftX = peakX * (1 - t); // from peak towards left edge
      final rightX = peakX + (fRight - peakX) * t;
      canvas.drawLine(Offset(leftX, sy), Offset(rightX, sy), shinglePaint);
    }

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
    canvas.drawRect(
      Rect.fromLTWH(w * 0.68, -h * 0.06, w * 0.16, h * 0.025),
      Paint()..color = const Color(0xFF6A2A1A),
    );
    // Mortar lines.
    final mortarPaint = Paint()
      ..color = const Color(0x44000000)
      ..strokeWidth = 0.8;
    canvas.drawLine(
      Offset(w * 0.70, h * 0.02),
      Offset(w * 0.82, h * 0.02),
      mortarPaint,
    );

    // Chimney smoke puff (grey squiggly path above chimney).
    final smokePaint = Paint()
      ..color = const Color(0x99BBBBBB)
      ..strokeWidth = 2.0
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    final smokePath = Path()..moveTo(w * 0.76, -h * 0.08);
    smokePath.quadraticBezierTo(w * 0.82, -h * 0.13, w * 0.76, -h * 0.18);
    smokePath.quadraticBezierTo(w * 0.70, -h * 0.23, w * 0.76, -h * 0.28);
    canvas.drawPath(smokePath, smokePaint);

    // Door (centred on front facade).
    final doorL = w * 0.24;
    final doorR = w * 0.50;
    final doorTop = h * 0.63;
    final doorBot = fBot;
    final doorRect = Rect.fromLTRB(doorL, doorTop, doorR, doorBot);
    canvas.drawRect(doorRect, Paint()..color = doorColor);
    // Arch.
    final archRect = Rect.fromLTWH(doorL, doorTop - (doorR - doorL) * 0.22,
        doorR - doorL, (doorR - doorL) * 0.44);
    canvas.drawOval(archRect, Paint()..color = doorColor);
    // Frame.
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
    // Handle.
    canvas.drawCircle(
      Offset(doorR - (doorR - doorL) * 0.20, h * 0.78),
      2.5,
      Paint()..color = const Color(0xFFFFD600),
    );

    // Steps.
    final stepPaint = Paint()..color = const Color(0xFFCCCCCC);
    canvas.drawRect(
      Rect.fromLTWH(doorL - w * 0.04, fBot - h * 0.04, (doorR - doorL) + w * 0.08, h * 0.04),
      stepPaint,
    );
    canvas.drawRect(
      Rect.fromLTWH(doorL - w * 0.02, fBot - h * 0.07, (doorR - doorL) + w * 0.04, h * 0.03),
      Paint()..color = const Color(0xFFBBBBBB),
    );

    // Flower pots flanking the door.
    _renderFlowerPot(canvas, Offset(doorL - w * 0.07, fBot - h * 0.05), w);
    _renderFlowerPot(canvas, Offset(doorR + w * 0.07, fBot - h * 0.05), w);

    // Bushes behind the pots.
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(doorL - w * 0.05, fBot - h * 0.09),
        width: w * 0.14,
        height: h * 0.07,
      ),
      Paint()..color = const Color(0xFF2E6B1E),
    );
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(doorR + w * 0.05, fBot - h * 0.09),
        width: w * 0.14,
        height: h * 0.07,
      ),
      Paint()..color = const Color(0xFF2E6B1E),
    );
    // Bush highlights.
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(doorL - w * 0.07, fBot - h * 0.12),
        width: w * 0.06,
        height: h * 0.03,
      ),
      Paint()..color = const Color(0x4466CC44),
    );
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(doorR + w * 0.03, fBot - h * 0.12),
        width: w * 0.06,
        height: h * 0.03,
      ),
      Paint()..color = const Color(0x4466CC44),
    );

    // Garden path (tan strip from step base to house bottom edge).
    final pathL = doorL - w * 0.02;
    final pathR = doorR + w * 0.02;
    canvas.drawRect(
      Rect.fromLTRB(pathL, fBot, pathR, h),
      Paint()..color = const Color(0xFFD2B48C),
    );
    // Path edge lines.
    canvas.drawLine(
      Offset(pathL, fBot),
      Offset(pathL, h),
      Paint()..color = const Color(0xFFAA8850)..strokeWidth = 0.8,
    );
    canvas.drawLine(
      Offset(pathR, fBot),
      Offset(pathR, h),
      Paint()..color = const Color(0xFFAA8850)..strokeWidth = 0.8,
    );

    // Picket fence along front edge of property.
    _renderFence(canvas, w, h, fBot);
  }

  void _renderFlowerPot(Canvas canvas, Offset center, double w) {
    // Terracotta pot body.
    canvas.drawOval(
      Rect.fromCenter(center: center, width: w * 0.10, height: w * 0.08),
      Paint()..color = const Color(0xFFB5541A),
    );
    // Flower dot on top (alternate pink / yellow per index).
    final flowerColor = _index.isEven
        ? const Color(0xFFFF69B4)
        : const Color(0xFFFFEB3B);
    canvas.drawCircle(
      center - Offset(0, w * 0.05),
      w * 0.03,
      Paint()..color = flowerColor,
    );
  }

  void _renderFence(Canvas canvas, double w, double h, double fBot) {
    final picketPaint = Paint()..color = const Color(0xFFF5F5F5);
    final railPaint = Paint()
      ..color = const Color(0xFFE0E0E0)
      ..strokeWidth = 1.2;
    const picketW = 3.5;
    const picketH = 9.0;
    final railY = fBot + 3.0;
    // Draw pickets from x=0 to x=fRight (front of house), stepping every 8px.
    double px = 2.0;
    final fRight = w * 0.72;
    while (px < fRight - 2) {
      canvas.drawRect(
        Rect.fromLTWH(px, fBot - picketH, picketW, picketH + 4),
        picketPaint,
      );
      // Pointed top.
      final tipPath = Path()
        ..moveTo(px, fBot - picketH)
        ..lineTo(px + picketW / 2, fBot - picketH - 4)
        ..lineTo(px + picketW, fBot - picketH)
        ..close();
      canvas.drawPath(tipPath, picketPaint);
      px += 8.0;
    }
    // Horizontal rail.
    canvas.drawLine(Offset(0, railY), Offset(fRight, railY), railPaint);
  }

  @override
  void update(double dt) {
    super.update(dt);
    if (gameRef.state != GameState.playing) return;
    // Only scroll vertically — position.x is fixed after onLoad.
    position.y += gameRef.scrollSpeed * dt;
    if (position.y > gameRef.size.y + size.y) {
      final rows = (gameRef.size.y / rowSpacing).ceil() + 2;
      position.y -= rows * rowSpacing;
      _index += 2;
      _setVariant();
      _regenerateMailbox();
      // Re-layout windows (curtain colour / position may change with index).
      _layoutWindows();
      for (final win in _windows) {
        win.restore();
      }
    }
  }
}
