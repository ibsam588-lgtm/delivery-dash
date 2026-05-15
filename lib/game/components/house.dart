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

/// Isometric 3-D house — front face + side face + gable roof, Paperboy style.
class HouseComponent extends PositionComponent
    with HasGameRef<DeliveryDashGame> {
  static const double rowSpacing = 160.0;
  static const double fixedWidth = 160.0;
  static const double fixedHeight = 150.0;

  static const double _parallaxFactor = 1.0;

  final double _initialY;
  int _index;
  final Random _rng = Random();
  final bool onRight;

  bool _isTall = false;

  MailboxComponent? _mailbox;
  final List<HouseWindow> _windows = [];

  HouseComponent({
    required double initialY,
    required int index,
    this.onRight = false,
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
    if (onRight) {
      final sw = gameRef.size.x - lm.roadRightAt(position.y);
      final fitWidth = (sw - 8).clamp(40.0, fixedWidth);
      if ((fitWidth - size.x).abs() > 0.5) {
        size = Vector2(fitWidth, fitWidth * (fixedHeight / fixedWidth));
        _layoutWindows();
      }
      position.x = lm.roadRightAt(position.y) + 4;
    } else {
      final fitWidth =
          (lm.roadLeftAt(position.y) - 8).clamp(40.0, fixedWidth);
      if ((fitWidth - size.x).abs() > 0.5) {
        size = Vector2(fitWidth, fitWidth * (fixedHeight / fixedWidth));
        _layoutWindows();
      }
      final x = lm.roadLeftAt(position.y) - size.x - 4;
      position.x = x < 0 ? 0 : x;
    }
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
    if (onRight) {
      mb.position = Vector2(-2, size.y * 0.6);
    } else {
      mb.position = Vector2(size.x + 6, size.y * 0.6);
    }
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
    final yFrac = _isTall ? 0.20 : 0.29;
    // Always place windows on the road-facing (left) side of the front face.
    _windows[0]
      ..size = winSize
      ..position = Vector2(size.x * 0.06, size.y * yFrac);
    _windows[1]
      ..size = winSize
      ..position = Vector2(size.x * 0.32, size.y * yFrac);
  }

  @override
  void render(Canvas canvas) {
    if (onRight) {
      // Mirror so front facade always faces the road.
      canvas.save();
      canvas.translate(size.x, 0);
      canvas.scale(-1, 1);
      _renderHouse(canvas);
      canvas.restore();
    } else {
      _renderHouse(canvas);
    }
    super.render(canvas);
  }

  // ── Isometric 3-D house rendering ────────────────────────────────────────

  void _renderHouse(Canvas canvas) {
    final w = size.x;
    final h = size.y;
    final p = _palette();

    late Color wallTop, wallBot, sideColor, roofFront, roofSide, doorColor;
    switch (p) {
      case 0:
        wallTop = const Color(0xFFF5E6C8);
        wallBot = const Color(0xFFE0C89A);
        sideColor = const Color(0xFFBFA070);
        roofFront = const Color(0xFFB03030);
        roofSide = const Color(0xFF7A1A1A);
        doorColor = const Color(0xFF6D3A20);
      case 1:
        wallTop = const Color(0xFFD4B896);
        wallBot = const Color(0xFFBCA07A);
        sideColor = const Color(0xFF9A7848);
        roofFront = const Color(0xFF7A7A7A);
        roofSide = const Color(0xFF484848);
        doorColor = const Color(0xFF5C3018);
      default:
        wallTop = const Color(0xFFF2F0E8);
        wallBot = const Color(0xFFDEDAD0);
        sideColor = const Color(0xFFBCB8AC);
        roofFront = const Color(0xFF3A6AAA);
        roofSide = const Color(0xFF284E82);
        doorColor = const Color(0xFF5C3018);
    }

    if (_index % 7 == 4) {
      roofFront = const Color(0xFF2E7D32);
      roofSide = const Color(0xFF1B5E20);
    } else if (_index % 7 == 6) {
      roofFront = const Color(0xFF6A1B9A);
      roofSide = const Color(0xFF4A148C);
    }

    // Ground shadow.
    canvas.drawOval(
      Rect.fromLTWH(2, h - 8, w - 4, 10),
      Paint()..color = const Color(0x44000000),
    );

    // ── Isometric house geometry ──────────────────────────────────────────
    // Front face occupies the left 65% of width.
    // Side face occupies the right 35% (darker, shadow side).
    // Roof: gable visible from 3/4 — front slope + side slope.

    final fRight = w * 0.65;   // front face right edge
    final fTop = h * 0.24;     // front face top
    final fBot = h * 0.93;     // front face bottom
    final sTop = h * 0.10;     // side face top (higher → isometric depth)
    final sBot = h * 0.82;     // side face bottom
    final sRight = w * 0.99;   // side face right edge
    final peakX = w * 0.28;    // roof peak X (1/3 into front face)
    final peakY = h * 0.02;    // roof peak Y (above front face top)

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

    // 2-storey floor divider ledge.
    if (_isTall) {
      final ledgeY = h * 0.52;
      canvas.drawRect(
        Rect.fromLTRB(0, ledgeY - 2, fRight, ledgeY + 2),
        Paint()..color = sideColor,
      );
      final lWinW = (w * 0.17).clamp(11.0, 19.0);
      final lWinH = (h * 0.14).clamp(10.0, 17.0);
      final lWinY = h * 0.57;
      final cc = _curtainColor();
      for (final lx in [w * 0.06, w * 0.32]) {
        canvas.drawRect(
          Rect.fromLTWH(lx, lWinY, lWinW, lWinH),
          Paint()..color = const Color(0xFFB3E5FC),
        );
        final cw = lWinW * 0.22;
        canvas.drawRect(
          Rect.fromLTWH(lx, lWinY, cw, lWinH),
          Paint()..color = cc.withValues(alpha: 0.55),
        );
        canvas.drawRect(
          Rect.fromLTWH(lx + lWinW - cw, lWinY, cw, lWinH),
          Paint()..color = cc.withValues(alpha: 0.55),
        );
        final mp = Paint()
          ..color = const Color(0xFF3E2A1E)
          ..strokeWidth = 1.2;
        canvas.drawLine(
          Offset(lx + lWinW / 2, lWinY),
          Offset(lx + lWinW / 2, lWinY + lWinH),
          mp,
        );
        canvas.drawLine(
          Offset(lx, lWinY + lWinH / 2),
          Offset(lx + lWinW, lWinY + lWinH / 2),
          mp,
        );
        canvas.drawRect(
          Rect.fromLTWH(lx, lWinY, lWinW, lWinH),
          Paint()
            ..color = const Color(0xFF3E2A1E)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.5,
        );
      }
    }

    // Side wall (isometric: slants inward and upward from front face).
    final sidePath = Path()
      ..moveTo(fRight, fTop)
      ..lineTo(sRight, sTop)
      ..lineTo(sRight, sBot)
      ..lineTo(fRight, fBot)
      ..close();
    canvas.drawPath(sidePath, Paint()..color = sideColor);
    // Side wall shadow gradient overlay.
    canvas.drawPath(
      sidePath,
      Paint()
        ..shader = Gradient.linear(
          Offset(fRight, 0),
          Offset(sRight, 0),
          [const Color(0x00000000), const Color(0x33000000)],
        ),
    );
    canvas.drawPath(
      sidePath,
      Paint()
        ..color = const Color(0x22000000)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0.8,
    );

    // Roof — front gable triangle.
    final roofFrontPath = Path()
      ..moveTo(0, fTop)
      ..lineTo(fRight, fTop)
      ..lineTo(peakX, peakY)
      ..close();
    canvas.drawPath(roofFrontPath, Paint()..color = roofFront);

    // Shingle lines on front roof slope.
    final shinglePaint = Paint()
      ..color = roofSide.withValues(alpha: 0.5)
      ..strokeWidth = 1.2;
    for (int i = 1; i <= 4; i++) {
      final t = i / 5.0;
      final sy = peakY + (fTop - peakY) * t;
      final leftX = 0.0 + (peakX - 0.0) * (1 - t);
      final rightX = peakX + (fRight - peakX) * t;
      canvas.drawLine(Offset(leftX, sy), Offset(rightX, sy), shinglePaint);
    }

    // Roof — side gable triangle (isometric: visible from 3/4 angle).
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
        ..color = const Color(0x55FFFFFF)
        ..strokeWidth = 1.0,
    );

    // Chimney (isometric box on the roof, side + front visible).
    final chTop = peakY - h * 0.04;
    final chBot = fTop - h * 0.02;
    final chL = w * 0.68;
    final chR = chL + w * 0.12;
    // Chimney front face.
    canvas.drawRect(
      Rect.fromLTRB(chL, chTop, chR, chBot),
      Paint()..color = const Color(0xFF8B3A2A),
    );
    // Chimney side face (isometric).
    final chSidePath = Path()
      ..moveTo(chR, chTop)
      ..lineTo(chR + w * 0.05, chTop - h * 0.02)
      ..lineTo(chR + w * 0.05, chBot - h * 0.02)
      ..lineTo(chR, chBot)
      ..close();
    canvas.drawPath(chSidePath, Paint()..color = const Color(0xFF6A2A1A));
    // Chimney cap.
    canvas.drawRect(
      Rect.fromLTRB(chL - 2, chTop, chR + w * 0.05 + 2, chTop + h * 0.018),
      Paint()..color = const Color(0xFF5A1A0A),
    );

    // Smoke.
    final smokePaint = Paint()
      ..color = const Color(0x88BBBBBB)
      ..strokeWidth = 1.8
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    final smokeX = (chL + chR) / 2;
    final smokePath = Path()..moveTo(smokeX, chTop);
    smokePath.quadraticBezierTo(
        smokeX + w * 0.06, chTop - h * 0.07, smokeX, chTop - h * 0.13);
    smokePath.quadraticBezierTo(
        smokeX - w * 0.04, chTop - h * 0.19, smokeX, chTop - h * 0.25);
    canvas.drawPath(smokePath, smokePaint);

    // Door (centred on front face).
    final doorL = w * 0.20;
    final doorR = w * 0.45;
    final doorTop = h * 0.62;
    final doorRect = Rect.fromLTRB(doorL, doorTop, doorR, fBot);
    canvas.drawRect(doorRect, Paint()..color = doorColor);
    // Arch top.
    canvas.drawOval(
      Rect.fromLTWH(doorL, doorTop - (doorR - doorL) * 0.22,
          doorR - doorL, (doorR - doorL) * 0.44),
      Paint()..color = doorColor,
    );
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
    // Door knob.
    canvas.drawCircle(
      Offset(doorR - (doorR - doorL) * 0.20, h * 0.77),
      2.5,
      Paint()..color = const Color(0xFFFFD600),
    );

    // Steps.
    canvas.drawRect(
      Rect.fromLTWH(
        doorL - w * 0.04,
        fBot - h * 0.04,
        (doorR - doorL) + w * 0.08,
        h * 0.04,
      ),
      Paint()..color = const Color(0xFFCCCCCC),
    );
    canvas.drawRect(
      Rect.fromLTWH(
        doorL - w * 0.02,
        fBot - h * 0.07,
        (doorR - doorL) + w * 0.04,
        h * 0.03,
      ),
      Paint()..color = const Color(0xFFBBBBBB),
    );

    // Flower pots.
    _renderFlowerPot(canvas, Offset(doorL - w * 0.07, fBot - h * 0.05), w);
    _renderFlowerPot(canvas, Offset(doorR + w * 0.06, fBot - h * 0.05), w);

    // Bushes.
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(doorL - w * 0.05, fBot - h * 0.10),
        width: w * 0.13,
        height: h * 0.07,
      ),
      Paint()..color = const Color(0xFF2E6B1E),
    );
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(doorR + w * 0.05, fBot - h * 0.10),
        width: w * 0.13,
        height: h * 0.07,
      ),
      Paint()..color = const Color(0xFF2E6B1E),
    );

    // Garden path.
    final pathL = doorL - w * 0.02;
    final pathR = doorR + w * 0.02;
    canvas.drawRect(
      Rect.fromLTRB(pathL, fBot, pathR, h),
      Paint()..color = const Color(0xFFD2B48C),
    );
    canvas.drawLine(
      Offset(pathL, fBot),
      Offset(pathL, h),
      Paint()
        ..color = const Color(0xFFAA8850)
        ..strokeWidth = 0.8,
    );
    canvas.drawLine(
      Offset(pathR, fBot),
      Offset(pathR, h),
      Paint()
        ..color = const Color(0xFFAA8850)
        ..strokeWidth = 0.8,
    );

    // Picket fence.
    _renderFence(canvas, w, h, fBot, fRight);
  }

  void _renderFlowerPot(Canvas canvas, Offset center, double w) {
    canvas.drawOval(
      Rect.fromCenter(center: center, width: w * 0.10, height: w * 0.08),
      Paint()..color = const Color(0xFFB5541A),
    );
    final flowerColor =
        _index.isEven ? const Color(0xFFFF69B4) : const Color(0xFFFFEB3B);
    canvas.drawCircle(
      center - Offset(0, w * 0.05),
      w * 0.03,
      Paint()..color = flowerColor,
    );
  }

  void _renderFence(
      Canvas canvas, double w, double h, double fBot, double fRight) {
    final picketPaint = Paint()..color = const Color(0xFFF5F5F5);
    final railPaint = Paint()
      ..color = const Color(0xFFE0E0E0)
      ..strokeWidth = 1.2;
    const picketW = 3.5;
    const picketH = 9.0;
    final railY = fBot + 3.0;
    double px = 2.0;
    while (px < fRight - 2) {
      canvas.drawRect(
        Rect.fromLTWH(px, fBot - picketH, picketW, picketH + 4),
        picketPaint,
      );
      canvas.drawPath(
        Path()
          ..moveTo(px, fBot - picketH)
          ..lineTo(px + picketW / 2, fBot - picketH - 4)
          ..lineTo(px + picketW, fBot - picketH)
          ..close(),
        picketPaint,
      );
      px += 8.0;
    }
    canvas.drawLine(Offset(0, railY), Offset(fRight, railY), railPaint);
  }

  @override
  void update(double dt) {
    super.update(dt);
    if (gameRef.state != GameState.playing) return;
    position.y += gameRef.scrollSpeed * _parallaxFactor * dt;

    // Y-based depth priority: houses lower on screen draw in front.
    final newPri = (position.y / 10).clamp(-10, 95).round();
    if (newPri != priority) priority = newPri;

    if (position.y > gameRef.size.y + size.y) {
      final rows = (gameRef.size.y / rowSpacing).ceil() + 2;
      position.y -= rows * rowSpacing;
      _index += 2;
      _setVariant();
      _alignToSidewalk();
      _regenerateMailbox();
      _layoutWindows();
      for (final win in _windows) {
        win.restore();
      }
    }
  }
}
