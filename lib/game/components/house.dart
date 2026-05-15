import 'dart:math';
import 'dart:ui';
import 'package:flame/components.dart';
import '../delivery_dash_game.dart';
import 'house_window.dart';
import 'mailbox.dart';

class _Palette {
  final Color wallTop;
  final Color wallBot;
  final Color wallSide;
  final Color brickLine;
  final Color roofFront;
  final Color roofSide;
  final Color doorColor;
  const _Palette(this.wallTop, this.wallBot, this.wallSide, this.brickLine,
      this.roofFront, this.roofSide, this.doorColor);
}

const List<_Palette> _palettes = [
  // 1. Cream walls / red roof / brown door
  _Palette(
    Color(0xFFF5E6C8),
    Color(0xFFD9C190),
    Color(0xFFB89D6A),
    Color(0xFFB39A6E),
    Color(0xFFC0392B),
    Color(0xFF85221A),
    Color(0xFF6D3A20),
  ),
  // 2. Yellow walls / dark grey roof / green door
  _Palette(
    Color(0xFFFFE082),
    Color(0xFFE5B850),
    Color(0xFFC09238),
    Color(0xFFB89035),
    Color(0xFF4A4A4A),
    Color(0xFF2A2A2A),
    Color(0xFF2E7D32),
  ),
  // 3. White walls / blue roof / red door
  _Palette(
    Color(0xFFFAFAFA),
    Color(0xFFE4E4E4),
    Color(0xFFB8B8B8),
    Color(0xFFB0B0B0),
    Color(0xFF1E88E5),
    Color(0xFF0D47A1),
    Color(0xFFC62828),
  ),
  // 4. Salmon walls / green roof / white door
  _Palette(
    Color(0xFFFFAB91),
    Color(0xFFE57373),
    Color(0xFFBC5C4D),
    Color(0xFFBC5C4D),
    Color(0xFF388E3C),
    Color(0xFF1B5E20),
    Color(0xFFEEEEEE),
  ),
  // 5. Light blue walls / rust roof / dark door
  _Palette(
    Color(0xFFB3E5FC),
    Color(0xFF81D4FA),
    Color(0xFF4FB3E0),
    Color(0xFF60A8C8),
    Color(0xFFB55B2A),
    Color(0xFF7A3E1A),
    Color(0xFF3E2723),
  ),
  // 6. Tan walls / purple roof / brown door
  _Palette(
    Color(0xFFD7C18D),
    Color(0xFFB89A5A),
    Color(0xFF8E7642),
    Color(0xFF8B713A),
    Color(0xFF7B1FA2),
    Color(0xFF4A148C),
    Color(0xFF5C3018),
  ),
];

const List<Color> _curtainColors = [
  Color(0xFFFFA726),
  Color(0xFF64B5F6),
  Color(0xFF81C784),
  Color(0xFFE91E63),
  Color(0xFFFFD54F),
  Color(0xFFBA68C8),
];

const List<Color> _flowerColors = [
  Color(0xFFE91E63),
  Color(0xFFFFD600),
  Color(0xFFFF80AB),
  Color(0xFFFF5252),
];

/// Big, isometric 3-face Paperboy-style house.
class HouseComponent extends PositionComponent
    with HasGameRef<DeliveryDashGame> {
  static const double rowSpacing = 230.0;
  static const double fixedWidth = 200.0;
  static const double fixedHeight = 220.0;

  static const double _parallaxFactor = 1.0;

  final double _initialY;
  int _index;
  final Random _rng = Random();
  final bool onRight;

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

  _Palette _palette() => _palettes[_index % _palettes.length];
  Color _curtainColor() => _curtainColors[_index % _curtainColors.length];

  /// Set house X and size based on the sidewalk width at the current Y.
  void _alignToSidewalk() {
    final lm = gameRef.laneManager;
    if (onRight) {
      final available = gameRef.size.x - lm.roadRightAt(position.y) - 12;
      final fitWidth = available.clamp(60.0, fixedWidth);
      if ((fitWidth - size.x).abs() > 0.5) {
        size = Vector2(fitWidth, fitWidth * (fixedHeight / fixedWidth));
        _layoutWindows();
      }
      position.x = lm.roadRightAt(position.y) + 8;
    } else {
      final available = lm.roadLeftAt(position.y) - 4;
      final fitWidth = available.clamp(60.0, fixedWidth);
      if ((fitWidth - size.x).abs() > 0.5) {
        size = Vector2(fitWidth, fitWidth * (fixedHeight / fixedWidth));
        _layoutWindows();
      }
      final x = lm.roadLeftAt(position.y) - size.x - 4;
      position.x = x < -size.x * 0.25 ? -size.x * 0.25 : x;
    }
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
    if (onRight) {
      mb.position = Vector2(-6, size.y * 0.70);
    } else {
      mb.position = Vector2(size.x + 10, size.y * 0.70);
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
    for (int i = 0; i < 3; i++) {
      final win = HouseWindow(position: Vector2.zero(), curtainColor: cc);
      _windows.add(win);
      add(win);
    }
    _layoutWindows();
  }

  void _layoutWindows() {
    if (_windows.isEmpty) return;
    // Dramatically larger windows — ~18% × 16% of house size,
    // 3 spread across the front face (left / centre / right).
    final winW = size.x * 0.18;
    final winH = size.y * 0.16;
    final winSize = Vector2(winW, winH);
    final yy = size.y * 0.40;
    // Front face spans 0..0.65w. Spread 3 window centres evenly across it.
    const xs = [0.13, 0.32, 0.51];
    for (int i = 0; i < 3 && i < _windows.length; i++) {
      _windows[i]
        ..size = winSize
        ..position = Vector2(size.x * xs[i], yy);
    }
  }

  @override
  void render(Canvas canvas) {
    if (onRight) {
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

  void _renderHouse(Canvas canvas) {
    final w = size.x;
    final h = size.y;
    final p = _palette();

    // Ground shadow.
    canvas.drawOval(
      Rect.fromLTWH(4, h - 10, w - 8, 14),
      Paint()..color = const Color(0x55000000),
    );

    // Geometry.
    final fRight = w * 0.65;
    final fTop = h * 0.28;
    final fBot = h * 0.92;
    final sTop = h * 0.16;
    final sBot = h * 0.82;
    final sRight = w * 0.97;
    final peakX = w * 0.30;
    final peakY = h * 0.04;
    final sidePeakX = w * 0.78;
    final sidePeakY = h * 0.00;

    // ── Front face with vertical gradient ────────────────────────────────
    final frontRect = Rect.fromLTRB(0, fTop, fRight, fBot);
    canvas.drawRect(
      frontRect,
      Paint()
        ..shader = Gradient.linear(
          Offset(0, fTop),
          Offset(0, fBot),
          [p.wallTop, p.wallBot],
        ),
    );

    // Brick / clapboard horizontal lines.
    final brickPaint = Paint()
      ..color = p.brickLine
      ..strokeWidth = 0.9;
    for (double y = fTop + 10; y < fBot - 2; y += 10) {
      canvas.drawLine(Offset(0, y), Offset(fRight, y), brickPaint);
    }
    // Vertical staggered brick lines.
    final vBrickPaint = Paint()
      ..color = p.brickLine.withValues(alpha: 0.55)
      ..strokeWidth = 0.7;
    int rowIdx = 0;
    for (double y = fTop + 10; y < fBot - 2; y += 10) {
      final stagger = (rowIdx.isEven ? 0.0 : 10.0);
      for (double x = stagger; x < fRight - 2; x += 20) {
        canvas.drawLine(Offset(x, y), Offset(x, y - 10), vBrickPaint);
      }
      rowIdx++;
    }

    // Front face outline.
    canvas.drawRect(
      frontRect,
      Paint()
        ..color = const Color(0x33000000)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0.8,
    );

    // ── Side face (parallelogram, darker — shadow side) ──────────────────
    final sidePath = Path()
      ..moveTo(fRight, fTop)
      ..lineTo(sRight, sTop)
      ..lineTo(sRight, sBot)
      ..lineTo(fRight, fBot)
      ..close();
    canvas.drawPath(sidePath, Paint()..color = p.wallSide);
    // Side darkening gradient overlay.
    canvas.drawPath(
      sidePath,
      Paint()
        ..shader = Gradient.linear(
          Offset(fRight, 0),
          Offset(sRight, 0),
          [const Color(0x00000000), const Color(0x55000000)],
        ),
    );
    canvas.drawPath(
      sidePath,
      Paint()
        ..color = const Color(0x44000000)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0.8,
    );

    // Side window (frosted look).
    final sWinL = fRight + (sRight - fRight) * 0.25;
    final sWinR = fRight + (sRight - fRight) * 0.75;
    final sWinT = sTop + (fTop - sTop) * 0.55;
    final sWinB = sBot + (fBot - sBot) * 0.30;
    // Approximate the side window as a parallelogram.
    final sWinPath = Path()
      ..moveTo(sWinL, sWinT + (fTop - sTop) * 0.05)
      ..lineTo(sWinR, sWinT - (fTop - sTop) * 0.05)
      ..lineTo(sWinR, sWinB - (fBot - sBot) * 0.05)
      ..lineTo(sWinL, sWinB + (fBot - sBot) * 0.05)
      ..close();
    canvas.drawPath(
      sWinPath,
      Paint()..color = const Color(0xCFB3CFE0),
    );
    canvas.drawPath(
      sWinPath,
      Paint()
        ..color = const Color(0xFF3E2A1E)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.3,
    );

    // ── Roof — front slope ───────────────────────────────────────────────
    final roofFrontPath = Path()
      ..moveTo(-w * 0.04, fTop + 2)
      ..lineTo(fRight + 2, fTop + 2)
      ..lineTo(peakX, peakY)
      ..close();
    canvas.drawPath(roofFrontPath, Paint()..color = p.roofFront);

    // Diagonal tile hatching on front slope.
    canvas.save();
    canvas.clipPath(roofFrontPath);
    final tilePaint = Paint()
      ..color = p.roofSide.withValues(alpha: 0.45)
      ..strokeWidth = 1.0;
    for (double x = -w * 0.5; x < w; x += 8) {
      canvas.drawLine(
        Offset(x, fTop + 2),
        Offset(x + (peakX - fRight), peakY),
        tilePaint,
      );
    }
    canvas.restore();

    // Roof — side slope.
    final roofSidePath = Path()
      ..moveTo(fRight + 2, fTop + 2)
      ..lineTo(sRight + 2, sTop + 2)
      ..lineTo(sidePeakX, sidePeakY)
      ..lineTo(peakX, peakY)
      ..close();
    canvas.drawPath(roofSidePath, Paint()..color = p.roofSide);

    // Roof ridge highlight.
    canvas.drawLine(
      Offset(peakX, peakY),
      Offset(sidePeakX, sidePeakY),
      Paint()
        ..color = const Color(0x88FFFFFF)
        ..strokeWidth = 1.4,
    );

    // Overhanging eaves (front).
    canvas.drawRect(
      Rect.fromLTWH(-w * 0.04, fTop, fRight + w * 0.08, 4),
      Paint()..color = p.roofSide.withValues(alpha: 0.45),
    );

    // ── Chimney ──────────────────────────────────────────────────────────
    final chL = w * 0.66;
    final chR = chL + w * 0.10;
    final chTop = peakY - h * 0.05;
    final chBot = fTop - h * 0.02;
    canvas.drawRect(
      Rect.fromLTRB(chL, chTop, chR, chBot),
      Paint()..color = const Color(0xFF8B3A2A),
    );
    // Chimney side face.
    final chSide = Path()
      ..moveTo(chR, chTop)
      ..lineTo(chR + w * 0.04, chTop - h * 0.02)
      ..lineTo(chR + w * 0.04, chBot - h * 0.02)
      ..lineTo(chR, chBot)
      ..close();
    canvas.drawPath(chSide, Paint()..color = const Color(0xFF6A2A1A));
    // Chimney cap.
    canvas.drawRect(
      Rect.fromLTRB(chL - 2, chTop, chR + w * 0.04 + 2, chTop + h * 0.018),
      Paint()..color = const Color(0xFF4A1A0A),
    );
    // Brick lines on chimney.
    final chimneyBrickPaint = Paint()
      ..color = const Color(0xFF6A2A1A)
      ..strokeWidth = 0.8;
    for (double y = chTop + 6; y < chBot - 1; y += 6) {
      canvas.drawLine(Offset(chL, y), Offset(chR, y), chimneyBrickPaint);
    }

    // Smoke wisps.
    final smokePaint = Paint()
      ..color = const Color(0x99CCCCCC)
      ..strokeWidth = 2.4
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    final smokeX = (chL + chR) / 2;
    final smokePath = Path()..moveTo(smokeX, chTop);
    smokePath.quadraticBezierTo(
        smokeX + w * 0.05, chTop - h * 0.06, smokeX, chTop - h * 0.12);
    smokePath.quadraticBezierTo(
        smokeX - w * 0.04, chTop - h * 0.18, smokeX, chTop - h * 0.24);
    canvas.drawPath(smokePath, smokePaint);

    // ── Door ──────────────────────────────────────────────────────────────
    final doorL = w * 0.18;
    final doorR = w * 0.42;
    final doorTop = h * 0.62;
    final doorBot = fBot - 2;
    final doorRect = Rect.fromLTRB(doorL, doorTop, doorR, doorBot);
    canvas.drawRect(doorRect, Paint()..color = p.doorColor);
    canvas.drawRect(
      doorRect,
      Paint()
        ..color = const Color(0xFF2A1808)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.4,
    );
    // Door panels.
    canvas.drawRect(
      Rect.fromLTRB(
        doorL + (doorR - doorL) * 0.15,
        doorTop + (doorBot - doorTop) * 0.12,
        doorR - (doorR - doorL) * 0.15,
        doorTop + (doorBot - doorTop) * 0.42,
      ),
      Paint()
        ..color = const Color(0x44000000)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.0,
    );
    // Door knob.
    canvas.drawCircle(
      Offset(doorR - (doorR - doorL) * 0.18, (doorTop + doorBot) / 2 + 6),
      2.5,
      Paint()..color = const Color(0xFFFFD600),
    );

    // Steps.
    canvas.drawRect(
      Rect.fromLTWH(doorL - 4, doorBot - 2, (doorR - doorL) + 8, 4),
      Paint()..color = const Color(0xFFCCCCCC),
    );

    // ── Front yard strip ─────────────────────────────────────────────────
    canvas.drawRect(
      Rect.fromLTWH(0, fBot, w, h - fBot),
      Paint()..color = const Color(0xFF4CAF50),
    );

    // Flower clusters.
    final flowerColor = _flowerColors[_index % _flowerColors.length];
    for (final fx in [w * 0.08, w * 0.55]) {
      _drawFlowerCluster(canvas, Offset(fx, fBot + (h - fBot) * 0.45),
          flowerColor);
    }

    // Bushes near door.
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(doorL - w * 0.05, fBot - h * 0.08),
        width: w * 0.14,
        height: h * 0.08,
      ),
      Paint()..color = const Color(0xFF2E6B1E),
    );
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(doorR + w * 0.05, fBot - h * 0.08),
        width: w * 0.14,
        height: h * 0.08,
      ),
      Paint()..color = const Color(0xFF2E6B1E),
    );

    // ── Picket fence (white posts + horizontal rail) ─────────────────────
    _renderFence(canvas, w, h, fBot);
  }

  void _drawFlowerCluster(Canvas canvas, Offset center, Color flowerColor) {
    final petal = Paint()..color = flowerColor;
    final center2 = Paint()..color = const Color(0xFFFFEB3B);
    for (final off in [
      const Offset(-3, 0),
      const Offset(3, 0),
      const Offset(0, -3),
      const Offset(0, 3),
    ]) {
      canvas.drawCircle(center + off, 2.4, petal);
    }
    canvas.drawCircle(center, 1.8, center2);
  }

  void _renderFence(Canvas canvas, double w, double h, double fBot) {
    final picketPaint = Paint()..color = const Color(0xFFFAFAFA);
    final railPaint = Paint()
      ..color = const Color(0xFFE0E0E0)
      ..strokeWidth = 1.6;
    const picketW = 3.0;
    const picketH = 12.0;
    final railY = h - 4.0;
    final fenceTop = railY - picketH;
    double px = 1.0;
    while (px < w - 2) {
      canvas.drawRect(
        Rect.fromLTWH(px, fenceTop, picketW, picketH),
        picketPaint,
      );
      // Pointed top.
      canvas.drawPath(
        Path()
          ..moveTo(px, fenceTop)
          ..lineTo(px + picketW / 2, fenceTop - 3.5)
          ..lineTo(px + picketW, fenceTop)
          ..close(),
        picketPaint,
      );
      px += 8.0;
    }
    canvas.drawLine(
      Offset(0, fenceTop + 4),
      Offset(w, fenceTop + 4),
      railPaint,
    );
  }

  @override
  void update(double dt) {
    super.update(dt);
    if (gameRef.state != GameState.playing) return;
    position.y += gameRef.scrollSpeed * _parallaxFactor * dt;
    // DO NOT track road edge here — only align on load / wrap.

    final newPri = (position.y / 10).clamp(-10, 95).round();
    if (newPri != priority) priority = newPri;

    if (position.y > gameRef.size.y + size.y) {
      final rows = (gameRef.size.y / rowSpacing).ceil() + 2;
      position.y -= rows * rowSpacing;
      _index += 2;
      _alignToSidewalk();
      _regenerateMailbox();
      _layoutWindows();
      for (final win in _windows) {
        win.restore();
      }
    }
  }
}
