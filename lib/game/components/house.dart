import 'dart:ui';
import 'package:flame/collisions.dart';
import 'package:flame/components.dart';
import '../delivery_dash_game.dart';
import '../difficulty.dart';
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
  _Palette(
      Color(0xFFF5E6C8),
      Color(0xFFD9C190),
      Color(0xFFB89D6A),
      Color(0xFFB39A6E),
      Color(0xFFC0392B),
      Color(0xFF85221A),
      Color(0xFF6D3A20)),
  _Palette(
      Color(0xFFFFE082),
      Color(0xFFE5B850),
      Color(0xFFC09238),
      Color(0xFFB89035),
      Color(0xFF4A4A4A),
      Color(0xFF2A2A2A),
      Color(0xFF2E7D32)),
  _Palette(
      Color(0xFFFAFAFA),
      Color(0xFFE4E4E4),
      Color(0xFFB8B8B8),
      Color(0xFFB0B0B0),
      Color(0xFF1E88E5),
      Color(0xFF0D47A1),
      Color(0xFFC62828)),
  _Palette(
      Color(0xFFFFAB91),
      Color(0xFFE57373),
      Color(0xFFBC5C4D),
      Color(0xFFBC5C4D),
      Color(0xFF388E3C),
      Color(0xFF1B5E20),
      Color(0xFFEEEEEE)),
  _Palette(
      Color(0xFFB3E5FC),
      Color(0xFF81D4FA),
      Color(0xFF4FB3E0),
      Color(0xFF60A8C8),
      Color(0xFFB55B2A),
      Color(0xFF7A3E1A),
      Color(0xFF3E2723)),
  _Palette(
      Color(0xFFD7C18D),
      Color(0xFFB89A5A),
      Color(0xFF8E7642),
      Color(0xFF8B713A),
      Color(0xFF7B1FA2),
      Color(0xFF4A148C),
      Color(0xFF5C3018)),
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

Color _lighten(Color c, double amount) {
  return Color.lerp(c, const Color(0xFFFFFFFF), amount) ?? c;
}

Color _darken(Color c, double amount) {
  return Color.lerp(c, const Color(0xFF000000), amount) ?? c;
}

/// Stable side house. It only scrolls vertically and never randomizes X or
/// jitters/oscillates horizontally.
class HouseComponent extends PositionComponent
    with HasGameRef<DeliveryDashGame> {
  static const double rowSpacing = 320.0;
  static const double fixedHeight = 200.0;
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
    final isCity = gameRef.config.zone == RouteZone.city;
    final lm = gameRef.laneManager;
    final sidewalkWidth =
        (gameRef.size.x * (isCity ? 0.075 : 0.060)).clamp(58.0, 94.0);
    final grassGap = isCity ? 10.0 : 16.0;
    final footpathOuterLeft = lm.roadLeft - sidewalkWidth;
    final footpathOuterRight = lm.roadRight + sidewalkWidth;
    final sideWidth = onRight
        ? gameRef.size.x - footpathOuterRight - grassGap
        : footpathOuterLeft - grassGap;
    final minHouseWidth = isCity ? 72.0 : 60.0;
    final maxHouseWidth = isCity ? 176.0 : 132.0;
    final houseWidth = sideWidth >= minHouseWidth
        ? sideWidth.clamp(minHouseWidth, maxHouseWidth).toDouble()
        : sideWidth.clamp(44.0, maxHouseWidth).toDouble();
    size = Vector2(
      houseWidth,
      isCity ? fixedHeight * 1.18 : fixedHeight,
    );
    if (onRight) {
      final desiredX = footpathOuterRight + grassGap;
      final maxX = gameRef.size.x - size.x;
      _pinnedX = desiredX <= maxX ? desiredX : maxX;
    } else {
      final desiredRight = footpathOuterLeft - grassGap;
      final desiredX = desiredRight - size.x;
      _pinnedX = desiredX >= 0 ? desiredX : 0.0;
    }
    final slot = _index ~/ 2;
    position = Vector2(_pinnedX, gameRef.size.y - slot * rowSpacing);
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
    final winW = size.x * 0.22;
    final winH = size.y * 0.15;
    final winSize = Vector2(winW, winH);
    final yy = size.y * 0.44;
    const xs = [0.34, 0.66];
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
    final matCenter = onRight ? size.x * 0.32 : size.x * 0.68;
    mat.position = Vector2(matCenter - mat.size.x / 2, matY);
    add(mat);
    _doorMat = mat;
  }

  @override
  void render(Canvas canvas) {
    if (gameRef.config.zone == RouteZone.city) {
      _renderCityBuilding(canvas);
    } else {
      _renderHouse(canvas);
    }
    super.render(canvas);
  }

  void _renderCityBuilding(Canvas canvas) {
    final w = size.x;
    final h = size.y;
    final baseColors = [
      const Color(0xFF546E7A),
      const Color(0xFF455A64),
      const Color(0xFF6D5D4D),
      const Color(0xFF607D8B),
    ];
    final wall = baseColors[_index % baseColors.length];
    final bodyTop = h * 0.08;
    final bodyBottom = h * 0.92;
    final body = Rect.fromLTRB(w * 0.06, bodyTop, w * 0.94, bodyBottom);

    canvas.drawOval(
      Rect.fromLTWH(4, h - 12, w - 8, 16),
      Paint()..color = const Color(0x66000000),
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(body, const Radius.circular(2)),
      Paint()
        ..shader = Gradient.linear(
          body.topLeft,
          body.bottomRight,
          [_lighten(wall, 0.16), wall, _darken(wall, 0.24)],
          [0.0, 0.62, 1.0],
        ),
    );

    final trimPaint = Paint()
      ..color = const Color(0x55000000)
      ..strokeWidth = 1.0;
    for (double y = body.top + 22; y < body.bottom - 42; y += 28) {
      canvas.drawLine(Offset(body.left, y), Offset(body.right, y), trimPaint);
    }

    final windowPaints = [
      const Color(0xFFB3E5FC),
      const Color(0xFFFFF59D),
      const Color(0xFF90CAF9),
    ];
    for (int row = 0; row < 5; row++) {
      for (int col = 0; col < 2; col++) {
        final wx = body.left + w * (0.18 + col * 0.34);
        final wy = body.top + h * 0.10 + row * h * 0.105;
        final rect = Rect.fromLTWH(wx, wy, w * 0.18, h * 0.055);
        canvas.drawRRect(
          RRect.fromRectAndRadius(rect, const Radius.circular(2)),
          Paint()..color = windowPaints[(_index + row + col) % 3],
        );
        canvas.drawRect(
          Rect.fromLTWH(rect.left, rect.top, rect.width, rect.height * 0.20),
          Paint()..color = const Color(0x55FFFFFF),
        );
      }
    }

    final shopRect = Rect.fromLTWH(body.left, h * 0.69, body.width, h * 0.19);
    canvas.drawRect(shopRect, Paint()..color = const Color(0xFF263238));
    final awningY = shopRect.top - h * 0.035;
    final stripeW = body.width / 5;
    for (int i = 0; i < 5; i++) {
      canvas.drawRect(
        Rect.fromLTWH(body.left + stripeW * i, awningY, stripeW, h * 0.045),
        Paint()
          ..color =
              i.isEven ? const Color(0xFFE53935) : const Color(0xFFFFF8E1),
      );
    }

    final doorCenter = onRight ? w * 0.32 : w * 0.68;
    final door = RRect.fromRectAndRadius(
      Rect.fromCenter(
        center: Offset(doorCenter, h * 0.82),
        width: w * 0.24,
        height: h * 0.20,
      ),
      const Radius.circular(3),
    );
    canvas.drawRRect(door, Paint()..color = const Color(0xFF4E342E));
    canvas.drawRRect(
      door,
      Paint()
        ..color = const Color(0xFF212121)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.2,
    );
    canvas.drawCircle(
      Offset(doorCenter + w * 0.07, h * 0.82),
      2.0,
      Paint()..color = const Color(0xFFFFD54F),
    );

    final walkPaint = Paint()..color = const Color(0xFFB8B9B2);
    final walkEndX = onRight ? 0.0 : w;
    final walkPath = Path()
      ..moveTo(doorCenter - w * 0.13, bodyBottom)
      ..lineTo(doorCenter + w * 0.13, bodyBottom)
      ..lineTo(walkEndX, h)
      ..lineTo(walkEndX + (onRight ? w * 0.12 : -w * 0.12), h)
      ..close();
    canvas.drawPath(walkPath, walkPaint);

    canvas.drawRRect(
      RRect.fromRectAndRadius(body, const Radius.circular(2)),
      Paint()
        ..color = const Color(0xAA111111)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.2,
    );
  }

  void _renderHouse(Canvas canvas) {
    final w = size.x;
    final h = size.y;
    final p = _palette();

    canvas.drawOval(
      Rect.fromLTWH(4, h - 12, w - 8, 16),
      Paint()..color = const Color(0x55000000),
    );

    final bodyLeft = w * 0.09;
    final bodyRight = w * 0.91;
    final bodyTop = h * 0.25;
    final bodyBottom = h * 0.90;
    final bodyRect = Rect.fromLTRB(bodyLeft, bodyTop, bodyRight, bodyBottom);

    final roofPeak = Offset(w * 0.50, h * 0.06);
    final roofPath = Path()
      ..moveTo(w * 0.02, bodyTop + h * 0.02)
      ..lineTo(roofPeak.dx, roofPeak.dy)
      ..lineTo(w * 0.98, bodyTop + h * 0.02)
      ..lineTo(w * 0.90, bodyTop + h * 0.12)
      ..lineTo(w * 0.10, bodyTop + h * 0.12)
      ..close();
    canvas.drawPath(
      roofPath,
      Paint()
        ..shader = Gradient.linear(
          Offset(w * 0.20, roofPeak.dy),
          Offset(w * 0.80, bodyTop + h * 0.13),
          [p.roofFront, p.roofSide],
        ),
    );
    canvas.drawPath(
      roofPath,
      Paint()
        ..color = const Color(0xAA1E1E1E)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.4,
    );

    final shingle = Paint()
      ..color = const Color(0x44000000)
      ..strokeWidth = 0.9;
    for (double y = bodyTop + h * 0.035; y < bodyTop + h * 0.11; y += 9) {
      canvas.drawLine(Offset(w * 0.14, y), Offset(w * 0.86, y), shingle);
    }

    final chimneyRect = Rect.fromLTWH(w * 0.66, h * 0.075, w * 0.11, h * 0.16);
    canvas.drawRect(chimneyRect, Paint()..color = const Color(0xFF8B3A2A));
    canvas.drawRect(
      chimneyRect,
      Paint()
        ..color = const Color(0xFF4E1F18)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.0,
    );
    canvas.drawRect(
      Rect.fromLTWH(w * 0.64, h * 0.065, w * 0.15, h * 0.022),
      Paint()..color = const Color(0xFF5D2A22),
    );

    canvas.drawRRect(
      RRect.fromRectAndRadius(bodyRect, const Radius.circular(3)),
      Paint()
        ..shader = Gradient.linear(
          Offset(0, bodyTop),
          Offset(0, bodyBottom),
          [p.wallTop, p.wallBot],
        ),
    );

    final sidingPaint = Paint()
      ..color = p.brickLine
      ..strokeWidth = 0.8;
    for (double y = bodyTop + 12; y < bodyBottom - 4; y += 13) {
      canvas.drawLine(
          Offset(bodyLeft + 3, y), Offset(bodyRight - 3, y), sidingPaint);
    }

    canvas.drawRRect(
      RRect.fromRectAndRadius(bodyRect, const Radius.circular(3)),
      Paint()
        ..color = const Color(0x33000000)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.0,
    );

    final doorCenter = onRight ? w * 0.32 : w * 0.68;
    final doorW = w * 0.24;
    final doorL = doorCenter - doorW / 2;
    final doorR = doorCenter + doorW / 2;
    final doorTop = h * 0.61;
    final doorBot = bodyBottom - 2;
    final doorRect = Rect.fromLTRB(doorL, doorTop, doorR, doorBot);
    canvas.drawRRect(
      RRect.fromRectAndRadius(doorRect, const Radius.circular(4)),
      Paint()
        ..shader = Gradient.linear(
          Offset(doorL, doorTop),
          Offset(doorR, doorBot),
          [p.doorColor, const Color(0xFF2A1808)],
        ),
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(doorRect, const Radius.circular(4)),
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

    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(doorL - 6, doorBot - 3, doorW + 12, 5),
        const Radius.circular(2),
      ),
      Paint()..color = const Color(0xFFCCCCCC),
    );

    canvas.drawRect(
      Rect.fromLTWH(0, bodyBottom, w, h - bodyBottom),
      Paint()..color = const Color(0xFF4CAF50),
    );

    final walkPaint = Paint()..color = const Color(0xFFC9B18B);
    final walkEndX = onRight ? 0.0 : w;
    final walkPath = Path()
      ..moveTo(doorCenter - doorW * 0.34, bodyBottom)
      ..lineTo(doorCenter + doorW * 0.34, bodyBottom)
      ..lineTo(walkEndX + (onRight ? w * 0.08 : -w * 0.08), h)
      ..lineTo(walkEndX, h)
      ..close();
    canvas.drawPath(walkPath, walkPaint);

    final flowerColor = _flowerColors[_index % _flowerColors.length];
    for (final fx in [w * 0.14, w * 0.50, w * 0.86]) {
      if ((fx - doorCenter).abs() < w * 0.20) continue;
      _drawFlowerCluster(canvas,
          Offset(fx, bodyBottom + (h - bodyBottom) * 0.46), flowerColor);
    }

    _renderFence(canvas, w, h);
  }

  void _drawFlowerCluster(Canvas canvas, Offset center, Color flowerColor) {
    final petal = Paint()..color = flowerColor;
    final center2 = Paint()..color = const Color(0xFFFFEB3B);
    for (final off in [
      const Offset(-3, 0),
      const Offset(3, 0),
      const Offset(0, -3),
      const Offset(0, 3)
    ]) {
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
      canvas.drawRect(
          Rect.fromLTWH(px, fenceTop, picketW, picketH), picketPaint);
      px += 9.0;
    }
    canvas.drawLine(
        Offset(0, fenceTop + 4), Offset(w, fenceTop + 4), railPaint);
  }

  @override
  void update(double dt) {
    super.update(dt);
    position.x = _pinnedX;

    if (gameRef.state != GameState.playing) return;
    position.y += gameRef.scrollSpeed * _parallaxFactor * dt;

    if (position.y > gameRef.size.y + size.y) {
      _cycle++;
      position.y = -size.y * 0.05;
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

    canvas.drawRect(
        Rect.fromLTWH(0, 0, w, h), Paint()..color = const Color(0xFF8D6E63));
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
