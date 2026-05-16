import 'dart:ui';
import 'package:flame/collisions.dart';
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
  _Palette(Color(0xFFF5E6C8), Color(0xFFD9C190), Color(0xFFB89D6A), Color(0xFFB39A6E), Color(0xFFC0392B), Color(0xFF85221A), Color(0xFF6D3A20)),
  _Palette(Color(0xFFFFE082), Color(0xFFE5B850), Color(0xFFC09238), Color(0xFFB89035), Color(0xFF4A4A4A), Color(0xFF2A2A2A), Color(0xFF2E7D32)),
  _Palette(Color(0xFFFAFAFA), Color(0xFFE4E4E4), Color(0xFFB8B8B8), Color(0xFFB0B0B0), Color(0xFF1E88E5), Color(0xFF0D47A1), Color(0xFFC62828)),
  _Palette(Color(0xFFFFAB91), Color(0xFFE57373), Color(0xFFBC5C4D), Color(0xFFBC5C4D), Color(0xFF388E3C), Color(0xFF1B5E20), Color(0xFFEEEEEE)),
  _Palette(Color(0xFFB3E5FC), Color(0xFF81D4FA), Color(0xFF4FB3E0), Color(0xFF60A8C8), Color(0xFFB55B2A), Color(0xFF7A3E1A), Color(0xFF3E2723)),
  _Palette(Color(0xFFD7C18D), Color(0xFFB89A5A), Color(0xFF8E7642), Color(0xFF8B713A), Color(0xFF7B1FA2), Color(0xFF4A148C), Color(0xFF5C3018)),
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

/// Stable side house. It only scrolls vertically and never randomizes X or
/// jitters/oscillates horizontally.
class HouseComponent extends PositionComponent
    with HasGameRef<DeliveryDashGame> {
  static const double rowSpacing = 340.0;
  static const double fixedHeight = 270.0;
  static const double _parallaxFactor = 1.0;

  int _index;
  final bool onRight;
  double _pinnedX = 0.0;

  MailboxComponent? _mailbox;
  final List<HouseWindow> _windows = [];
  DoorMatComponent? _doorMat;
  bool _hasDoorMat = false;
  int _cycle = 0;

  HouseComponent({
    required int index,
    this.onRight = false,
  })  : _index = index,
        super(
          size: Vector2(120, fixedHeight),
          anchor: Anchor.bottomLeft,
          priority: 5,
        );

  _Palette _palette() => _palettes[_index % _palettes.length];
  Color _curtainColor() => _curtainColors[_index % _curtainColors.length];

  @override
  Future<void> onLoad() async {
    final sideWidth = onRight
        ? gameRef.size.x - gameRef.laneManager.roadRight
        : gameRef.laneManager.roadLeft;
    size = Vector2(sideWidth.clamp(78.0, 132.0), fixedHeight);
    _pinnedX = onRight ? gameRef.size.x - size.x : 0.0;
    final slot = _index ~/ 2;
    position = Vector2(_pinnedX, -fixedHeight - slot * rowSpacing);
    _spawnWindows();
    _regenerateMailbox();
    _maybeSpawnDoorMat();
  }

  void _regenerateMailbox() {
    _mailbox?.removeFromParent();
    _mailbox = null;
    final selector = (_index + _cycle) % 10;
    if (selector == 0) return;
    final isBlue = selector < 8;
    final mb = MailboxComponent(isBlue: isBlue);
    if (onRight) {
      mb.position = Vector2(-4, size.y * 0.72);
    } else {
      mb.position = Vector2(size.x + 6, size.y * 0.72);
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
    for (int i = 0; i < 2; i++) {
      final win = HouseWindow(position: Vector2.zero(), curtainColor: cc);
      _windows.add(win);
      add(win);
    }
    _layoutWindows();
  }

  void _layoutWindows() {
    if (_windows.isEmpty) return;
    final winW = size.x * 0.24;
    final winH = size.y * 0.18;
    final winSize = Vector2(winW, winH);
    final yy = size.y * 0.42;
    final xs = onRight ? const [0.80, 0.55] : const [0.20, 0.45];
    for (int i = 0; i < 2 && i < _windows.length; i++) {
      _windows[i]
        ..size = winSize
        ..position = Vector2(size.x * xs[i], yy);
    }
  }

  void _maybeSpawnDoorMat() {
    _doorMat?.removeFromParent();
    _doorMat = null;
    _hasDoorMat = ((_index + _cycle) % 3) == 0;
    if (!_hasDoorMat) return;
    final mat = DoorMatComponent();
    final matY = size.y * 0.91;
    final matCenter = onRight ? size.x * 0.70 : size.x * 0.30;
    mat.position = Vector2(matCenter - mat.size.x / 2, matY);
    add(mat);
    _doorMat = mat;
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

    canvas.drawOval(
      Rect.fromLTWH(4, h - 10, w - 8, 14),
      Paint()..color = const Color(0x55000000),
    );

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

    final brickPaint = Paint()
      ..color = p.brickLine
      ..strokeWidth = 0.8;
    for (double y = fTop + 10; y < fBot - 2; y += 10) {
      canvas.drawLine(Offset(0, y), Offset(fRight, y), brickPaint);
    }

    canvas.drawRect(
      frontRect,
      Paint()
        ..color = const Color(0x33000000)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0.8,
    );

    final sidePath = Path()
      ..moveTo(fRight, fTop)
      ..lineTo(sRight, sTop)
      ..lineTo(sRight, sBot)
      ..lineTo(fRight, fBot)
      ..close();
    canvas.drawPath(sidePath, Paint()..color = p.wallSide);
    canvas.drawPath(
      sidePath,
      Paint()
        ..shader = Gradient.linear(
          Offset(fRight, 0),
          Offset(sRight, 0),
          [const Color(0x00000000), const Color(0x55000000)],
        ),
    );

    final sWinL = fRight + (sRight - fRight) * 0.25;
    final sWinR = fRight + (sRight - fRight) * 0.75;
    final sWinT = sTop + (fTop - sTop) * 0.55;
    final sWinB = sBot + (fBot - sBot) * 0.30;
    final sWinPath = Path()
      ..moveTo(sWinL, sWinT)
      ..lineTo(sWinR, sWinT)
      ..lineTo(sWinR, sWinB)
      ..lineTo(sWinL, sWinB)
      ..close();
    canvas.drawPath(sWinPath, Paint()..color = const Color(0xCFB3CFE0));
    canvas.drawPath(
      sWinPath,
      Paint()
        ..color = const Color(0xFF3E2A1E)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.2,
    );

    final roofFrontPath = Path()
      ..moveTo(-w * 0.04, fTop + 2)
      ..lineTo(fRight + 2, fTop + 2)
      ..lineTo(peakX, peakY)
      ..close();
    canvas.drawPath(roofFrontPath, Paint()..color = p.roofFront);

    final roofSidePath = Path()
      ..moveTo(fRight + 2, fTop + 2)
      ..lineTo(sRight + 2, sTop + 2)
      ..lineTo(sidePeakX, sidePeakY)
      ..lineTo(peakX, peakY)
      ..close();
    canvas.drawPath(roofSidePath, Paint()..color = p.roofSide);

    canvas.drawRect(
      Rect.fromLTWH(-w * 0.04, fTop, fRight + w * 0.08, 4),
      Paint()..color = p.roofSide.withValues(alpha: 0.45),
    );

    final chL = w * 0.66;
    final chR = chL + w * 0.10;
    final chTop = peakY - h * 0.04;
    final chBot = fTop - h * 0.02;
    canvas.drawRect(
      Rect.fromLTRB(chL, chTop, chR, chBot),
      Paint()..color = const Color(0xFF8B3A2A),
    );

    final doorL = w * 0.20;
    final doorR = w * 0.40;
    final doorTop = h * 0.62;
    final doorBot = fBot - 2;
    final doorRect = Rect.fromLTRB(doorL, doorTop, doorR, doorBot);
    canvas.drawRect(doorRect, Paint()..color = p.doorColor);
    canvas.drawRect(
      doorRect,
      Paint()
        ..color = const Color(0xFF2A1808)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.2,
    );
    canvas.drawCircle(
      Offset(doorR - (doorR - doorL) * 0.18, (doorTop + doorBot) / 2 + 6),
      2.2,
      Paint()..color = const Color(0xFFFFD600),
    );

    canvas.drawRect(
      Rect.fromLTWH(doorL - 4, doorBot - 2, (doorR - doorL) + 8, 4),
      Paint()..color = const Color(0xFFCCCCCC),
    );

    canvas.drawRect(
      Rect.fromLTWH(0, fBot, w, h - fBot),
      Paint()..color = const Color(0xFF4CAF50),
    );

    final flowerColor = _flowerColors[_index % _flowerColors.length];
    for (final fx in [w * 0.08, w * 0.55]) {
      _drawFlowerCluster(canvas, Offset(fx, fBot + (h - fBot) * 0.45), flowerColor);
    }

    _renderFence(canvas, w, h);
  }

  void _drawFlowerCluster(Canvas canvas, Offset center, Color flowerColor) {
    final petal = Paint()..color = flowerColor;
    final center2 = Paint()..color = const Color(0xFFFFEB3B);
    for (final off in [const Offset(-3, 0), const Offset(3, 0), const Offset(0, -3), const Offset(0, 3)]) {
      canvas.drawCircle(center + off, 2.2, petal);
    }
    canvas.drawCircle(center, 1.6, center2);
  }

  void _renderFence(Canvas canvas, double w, double h) {
    final picketPaint = Paint()..color = const Color(0xFFFAFAFA);
    final railPaint = Paint()
      ..color = const Color(0xFFE0E0E0)
      ..strokeWidth = 1.4;
    const picketW = 3.0;
    const picketH = 10.0;
    final railY = h - 4.0;
    final fenceTop = railY - picketH;
    double px = 1.0;
    while (px < w - 2) {
      canvas.drawRect(Rect.fromLTWH(px, fenceTop, picketW, picketH), picketPaint);
      px += 9.0;
    }
    canvas.drawLine(Offset(0, fenceTop + 4), Offset(w, fenceTop + 4), railPaint);
  }

  @override
  void update(double dt) {
    super.update(dt);
    position.x = _pinnedX;

    if (gameRef.state != GameState.playing) return;
    position.y += gameRef.scrollSpeed * _parallaxFactor * dt;

    if (position.y > gameRef.size.y + fixedHeight) {
      _cycle++;
      position.y = -fixedHeight;
      _index = (_index + 2) % _palettes.length;
      _layoutWindows();
      for (final win in _windows) {
        win.restore();
      }
      _regenerateMailbox();
      _maybeSpawnDoorMat();
    }
  }
}

class DoorMatComponent extends PositionComponent
    with HasGameRef<DeliveryDashGame>, CollisionCallbacks {
  static const int bonusPoints = 25;

  bool _delivered = false;
  double _flashTimer = 0;
  static const double _flashDuration = 0.5;

  DoorMatComponent()
      : super(
          size: Vector2(34, 12),
          anchor: Anchor.topLeft,
          priority: 2,
        );

  bool get delivered => _delivered;

  @override
  Future<void> onLoad() async {
    add(RectangleHitbox(
      size: size * 0.95,
      position: size * 0.025,
      collisionType: CollisionType.passive,
    ));
  }

  void onPaperHit() {
    if (_delivered) return;
    _delivered = true;
    _flashTimer = _flashDuration;
  }

  @override
  void update(double dt) {
    super.update(dt);
    if (_flashTimer > 0) {
      _flashTimer = (_flashTimer - dt).clamp(0.0, _flashDuration);
    }
  }

  @override
  void render(Canvas canvas) {
    final w = size.x;
    final h = size.y;

    canvas.drawRect(Rect.fromLTWH(0, 0, w, h), Paint()..color = const Color(0xFF8D6E63));
    canvas.drawRect(
      Rect.fromLTWH(0, 0, w, h),
      Paint()
        ..color = const Color(0xFF4E342E)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.0,
    );
    final stripe = Paint()..color = const Color(0xFF6D4C41);
    for (double sx = 2; sx < w - 2; sx += 5) {
      canvas.drawRect(Rect.fromLTWH(sx, 2, 1.5, h - 4), stripe);
    }
    final dot = Paint()..color = const Color(0xFFD7CCC8);
    for (double dx = 6; dx < w - 6; dx += 4) {
      canvas.drawCircle(Offset(dx, h * 0.5), 0.6, dot);
    }

    if (_delivered) {
      final phase = _flashTimer / _flashDuration;
      final alpha = (phase * 0.65).clamp(0.0, 0.65);
      canvas.drawRect(
        Rect.fromLTWH(-2, -2, w + 4, h + 4),
        Paint()..color = const Color(0xFFFFD600).withValues(alpha: alpha),
      );
    }
  }
}
