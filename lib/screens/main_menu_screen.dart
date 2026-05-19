import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import '../game/difficulty.dart';
import '../services/ad_service.dart';
import '../services/audio_service.dart';
import '../services/score_service.dart';
import '../services/store_service.dart';

class MainMenuScreen extends StatefulWidget {
  const MainMenuScreen({super.key});

  @override
  State<MainMenuScreen> createState() => _MainMenuScreenState();
}

class _MainMenuScreenState extends State<MainMenuScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _animCtrl;
  int _highScore = 0;
  int _coins = 0;
  CourierAvatar _selectedAvatar = CourierAvatar.girl;
  RouteZone _selectedZone = RouteZone.suburb;

  @override
  void initState() {
    super.initState();
    _animCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    )..repeat();
    _load();
  }

  Future<void> _load() async {
    try {
      await StoreService.instance.init();
    } catch (_) {}
    int hs = 0;
    try {
      hs = await ScoreService.instance.getHighScore();
    } catch (_) {}
    if (!mounted) return;
    setState(() {
      _highScore = hs;
      _coins = StoreService.instance.coins;
      if (!StoreService.instance.isAvatarOwned(_selectedAvatar)) {
        _selectedAvatar = CourierAvatar.girl;
      }
    });
  }

  @override
  void dispose() {
    _animCtrl.dispose();
    super.dispose();
  }

  void _onPlay(Difficulty difficulty) {
    AudioService.instance.playPickup();
    Navigator.of(context)
        .pushNamed(
          '/game',
          arguments: RunSelection(
            difficulty: difficulty,
            avatar: _selectedAvatar,
            zone: _selectedZone,
          ),
        )
        .then((_) => _refresh());
  }

  void _onStore() {
    AudioService.instance.playPickup();
    Navigator.of(context).pushNamed('/store').then((_) => _refresh());
  }

  Future<void> _selectAvatar(CourierAvatar avatar) async {
    final store = StoreService.instance;
    if (store.isAvatarOwned(avatar)) {
      setState(() => _selectedAvatar = avatar);
      return;
    }
    final ok = await store.purchaseAvatar(avatar);
    if (!mounted) return;
    if (ok) {
      AudioService.instance.playPickup();
      setState(() {
        _selectedAvatar = avatar;
        _coins = store.coins;
      });
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Need ${store.avatarPrice(avatar)} coins'),
          backgroundColor: const Color(0xFF263238),
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  void _refresh() {
    if (!mounted) return;
    setState(() => _coins = StoreService.instance.coins);
    ScoreService.instance.getHighScore().then((hs) {
      if (!mounted) return;
      setState(() => _highScore = hs);
    });
  }

  Future<bool> _confirmExit() async {
    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF15202A),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
          side: const BorderSide(color: Color(0xFFFFC928), width: 2),
        ),
        title: Text(
          'EXIT ROUTE?',
          style: GoogleFonts.pressStart2p(color: Colors.white, fontSize: 13),
        ),
        content: const Text(
          'Are you sure you want to leave the paper route?',
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(
              'STAY',
              style: GoogleFonts.pressStart2p(
                color: const Color(0xFFFFC928),
                fontSize: 10,
              ),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(
              'EXIT',
              style: GoogleFonts.pressStart2p(
                color: const Color(0xFFFF5252),
                fontSize: 10,
              ),
            ),
          ),
        ],
      ),
    );
    return result == true;
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        final exit = await _confirmExit();
        if (exit) SystemNavigator.pop();
      },
      child: Scaffold(
        backgroundColor: const Color(0xFF061217),
        body: Stack(
          children: [
            Positioned.fill(
              child: AnimatedBuilder(
                animation: _animCtrl,
                builder: (context, _) => CustomPaint(
                  painter: _LandingScenePainter(
                    t: _animCtrl.value,
                    zone: _selectedZone,
                  ),
                ),
              ),
            ),
            SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(18, 10, 18, 8),
                child: Column(
                  children: [
                    Row(
                      children: [
                        _StatBadge(label: 'BEST', value: _highScore.toString()),
                        const Spacer(),
                        _CoinBadge(coins: _coins),
                      ],
                    ),
                    Expanded(
                      child: AnimatedBuilder(
                        animation: _animCtrl,
                        builder: (context, _) => _HomeHero(
                          t: _animCtrl.value,
                          avatar: _selectedAvatar,
                          zone: _selectedZone,
                        ),
                      ),
                    ),
                    _RouteCard(
                      onEasy: () => _onPlay(Difficulty.easy),
                      onMedium: () => _onPlay(Difficulty.medium),
                      onHard: () => _onPlay(Difficulty.hard),
                      onStore: _onStore,
                      avatar: _selectedAvatar,
                      zone: _selectedZone,
                      onAvatarChanged: (avatar) {
                        _selectAvatar(avatar);
                      },
                      onZoneChanged: (zone) =>
                          setState(() => _selectedZone = zone),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'DELIVER PAPERS  •  DODGE TRAFFIC  •  SURVIVE THE ROUTE',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.pressStart2p(
                        fontSize: 7,
                        color: Colors.white70,
                        letterSpacing: 0.7,
                      ),
                    ),
                    const SizedBox(height: 8),
                    AdService.instance.bannerAd(),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _HomeHero extends StatelessWidget {
  final double t;
  final CourierAvatar avatar;
  final RouteZone zone;

  const _HomeHero({
    required this.t,
    required this.avatar,
    required this.zone,
  });

  @override
  Widget build(BuildContext context) {
    final city = zone == RouteZone.city;
    final isGirl = avatar == CourierAvatar.girl;
    final nameAccent =
        isGirl ? const Color(0xFFFF5FB7) : const Color(0xFF4A7DFF);
    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxHeight < 300;
        return Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _TitleCard(compact: compact),
            SizedBox(height: compact ? 6 : 12),
            Transform.translate(
              offset: Offset(0, sin(t * 2 * pi) * 3),
              child: CustomPaint(
                size: Size(compact ? 132 : 168, compact ? 108 : 132),
                painter: _HeroCourierPainter(
                  avatar: avatar,
                  city: city,
                ),
              ),
            ),
            SizedBox(height: compact ? 4 : 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
              decoration: BoxDecoration(
                color: const Color(0xDD061217),
                borderRadius: BorderRadius.circular(999),
                border: Border.all(color: nameAccent, width: 1.4),
                boxShadow: [
                  BoxShadow(
                      color: nameAccent.withValues(alpha: 0.45),
                      blurRadius: 10),
                ],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 7,
                    height: 7,
                    decoration:
                        BoxDecoration(color: nameAccent, shape: BoxShape.circle),
                  ),
                  const SizedBox(width: 7),
                  Text(
                    AvatarConfig.label(avatar),
                    style: GoogleFonts.pressStart2p(
                      fontSize: 10,
                      color: Colors.white,
                      letterSpacing: 1.6,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    AvatarConfig.tagline(avatar),
                    style: GoogleFonts.pressStart2p(
                      fontSize: 7,
                      color: nameAccent,
                      letterSpacing: 1.0,
                    ),
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}

class _HeroCourierPainter extends CustomPainter {
  final CourierAvatar avatar;
  final bool city;

  const _HeroCourierPainter({required this.avatar, required this.city});

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(w * 0.50, h * 0.92),
        width: w * 0.78,
        height: h * 0.10,
      ),
      Paint()..color = const Color(0x66000000),
    );

    final badge = RRect.fromRectAndRadius(
      Rect.fromCenter(
        center: Offset(w * 0.50, h * 0.44),
        width: w * 0.78,
        height: h * 0.78,
      ),
      const Radius.circular(28),
    );
    canvas.drawRRect(
      badge,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: city
              ? const [Color(0xFF22313A), Color(0xFF0C151B)]
              : const [Color(0xFFFFF3C4), Color(0xFFBEE8B0)],
        ).createShader(Offset.zero & size),
    );
    canvas.drawRRect(
      badge,
      Paint()
        ..color = const Color(0xFFFFC928)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3,
    );

    _AvatarPortraitPainter(avatar: avatar, selected: true)
        .paint(canvas, Size(w, h * 0.78));

    final bikePaint = Paint()
      ..color = const Color(0xFFD71920)
      ..strokeWidth = 4
      ..strokeCap = StrokeCap.round;
    final left = Offset(w * 0.29, h * 0.82);
    final right = Offset(w * 0.71, h * 0.82);
    final crank = Offset(w * 0.50, h * 0.73);
    final seat = Offset(w * 0.45, h * 0.62);
    final handle = Offset(w * 0.70, h * 0.61);
    for (final c in [left, right]) {
      canvas.drawCircle(
        c,
        w * 0.115,
        Paint()
          ..color = const Color(0xFF111111)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 4,
      );
      canvas.drawCircle(c, w * 0.025, Paint()..color = const Color(0xFF222222));
    }
    canvas.drawLine(left, crank, bikePaint);
    canvas.drawLine(crank, right, bikePaint);
    canvas.drawLine(left, seat, bikePaint);
    canvas.drawLine(seat, handle, bikePaint);
    canvas.drawLine(handle, right, bikePaint);
    canvas.drawLine(seat, crank, bikePaint);
  }

  @override
  bool shouldRepaint(covariant _HeroCourierPainter oldDelegate) =>
      oldDelegate.avatar != avatar || oldDelegate.city != city;
}

// ignore: unused_element
class _RouteTagline extends StatelessWidget {
  const _RouteTagline();

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: const Color(0xD7061217),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: const Color(0x99FFC928)),
        boxShadow: const [BoxShadow(color: Colors.black54, blurRadius: 10)],
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        child: Text(
          'THROW CLEAN  •  DODGE FAST  •  CASH OUT',
          textAlign: TextAlign.center,
          style: GoogleFonts.pressStart2p(
            fontSize: 8,
            color: Colors.white,
            letterSpacing: 0.8,
          ),
        ),
      ),
    );
  }
}

// ignore: unused_element
class _ObstacleGuide extends StatelessWidget {
  const _ObstacleGuide();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xE615202A),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFFFC928), width: 1.5),
        boxShadow: const [BoxShadow(color: Colors.black45, blurRadius: 8)],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'ROUTE BRIEFING',
            style: GoogleFonts.pressStart2p(
              fontSize: 9,
              color: const Color(0xFFFFC928),
              letterSpacing: 1.2,
            ),
          ),
          const SizedBox(height: 8),
          const Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              _GuideChip(icon: '📬', text: 'Blue mailbox = deliver'),
              _GuideChip(icon: '🚗', text: 'Cars hurt'),
              _GuideChip(icon: '🚧', text: 'Construction slows'),
              _GuideChip(icon: '📰', text: 'Paper packs refill'),
              _GuideChip(icon: '🔴', text: 'Red mailbox penalty'),
              _GuideChip(icon: '🐕', text: 'Dogs cross lanes'),
            ],
          ),
        ],
      ),
    );
  }
}

class _GuideChip extends StatelessWidget {
  final String icon;
  final String text;

  const _GuideChip({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: const Color(0xFF0A1922),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0x55FFC928)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(icon, style: const TextStyle(fontSize: 11)),
          const SizedBox(width: 4),
          Text(
            text,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 10,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

Color _lighten(Color c, double amount) {
  return Color.lerp(c, const Color(0xFFFFFFFF), amount) ?? c;
}

Color _darken(Color c, double amount) {
  return Color.lerp(c, const Color(0xFF000000), amount) ?? c;
}

class _LandingScenePainter extends CustomPainter {
  final double t;
  final RouteZone zone;
  _LandingScenePainter({required this.t, required this.zone});

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    final isCity = zone == RouteZone.city;
    canvas.drawRect(
      Offset.zero & size,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: isCity
              ? const [
                  Color(0xFF86D8FF),
                  Color(0xFFD7E6EC),
                  Color(0xFF59615D),
                ]
              : const [
                  Color(0xFF74D7FF),
                  Color(0xFFD3F7B6),
                  Color(0xFF37A852),
                ],
          stops: const [0.0, 0.46, 1.0],
        ).createShader(Offset.zero & size),
    );

    final horizon = h * 0.30;
    canvas.drawCircle(
      Offset(w * 0.82, horizon * 0.42),
      28,
      Paint()..color = const Color(0xFFFFD54F),
    );
    _drawCloud(
        canvas, Offset(w * 0.16 + sin(t * 2 * pi) * 8, horizon * 0.36), 1.0);
    _drawCloud(
        canvas, Offset(w * 0.62 - sin(t * 2 * pi) * 10, horizon * 0.22), 0.78);
    if (isCity) {
      _drawCitySkyline(canvas, w, horizon);
    } else {
      _drawSkyline(canvas, w, horizon);
    }

    final road = Path()
      ..moveTo(w * 0.33, h)
      ..lineTo(w * 0.67, h)
      ..lineTo(w * 0.58, horizon)
      ..lineTo(w * 0.42, horizon)
      ..close();
    canvas.drawPath(
      road,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF3B4042), Color(0xFF202426)],
        ).createShader(Rect.fromLTWH(0, horizon, w, h - horizon)),
    );

    final curb = Paint()
      ..color = const Color(0xFFF5F1E5)
      ..strokeWidth = 5
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(Offset(w * 0.42, horizon), Offset(w * 0.33, h), curb);
    canvas.drawLine(Offset(w * 0.58, horizon), Offset(w * 0.67, h), curb);

    final dashPaint = Paint()..color = const Color(0xFFF8F6E8);
    final offset = (t * 52) % 52;
    for (double y = horizon + offset - 52; y < h; y += 52) {
      final prog = ((y - horizon) / (h - horizon)).clamp(0.0, 1.0);
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromCenter(
            center: Offset(w / 2, y),
            width: 3 + prog * 5,
            height: 18 + prog * 18,
          ),
          const Radius.circular(2),
        ),
        dashPaint,
      );
    }

    final carT = (t + 0.12) % 1.0;
    final carY = horizon + (h - horizon) * (0.12 + carT * 0.58);
    final carScale = 0.35 + carT * 0.75;
    _drawRoadCar(canvas, Offset(w * (0.46 + carT * 0.06), carY), carScale,
        const Color(0xFFE53935));
    final vanT = (t + 0.58) % 1.0;
    final vanY = horizon + (h - horizon) * (0.05 + vanT * 0.44);
    _drawRoadCar(canvas, Offset(w * (0.56 - vanT * 0.04), vanY),
        0.28 + vanT * 0.55, const Color(0xFFF5F5F5));

    if (isCity) {
      _drawMenuBuildings(canvas, size, left: true);
      _drawMenuBuildings(canvas, size, left: false);
    } else {
      _drawMenuHouses(canvas, size, left: true);
      _drawMenuHouses(canvas, size, left: false);
    }
  }

  void _drawCloud(Canvas canvas, Offset c, double s) {
    final paint = Paint()..color = const Color(0xDDF6FDFF);
    canvas.drawOval(
        Rect.fromCenter(center: c, width: 50 * s, height: 18 * s), paint);
    canvas.drawCircle(c + Offset(-15 * s, -5 * s), 12 * s, paint);
    canvas.drawCircle(c + Offset(6 * s, -9 * s), 16 * s, paint);
    canvas.drawCircle(c + Offset(22 * s, -3 * s), 10 * s, paint);
  }

  void _drawRoadCar(Canvas canvas, Offset c, double s, Color color) {
    canvas.save();
    canvas.translate(c.dx, c.dy);
    canvas.scale(s, s);
    canvas.drawOval(
      Rect.fromCenter(center: const Offset(0, 29), width: 42, height: 8),
      Paint()..color = const Color(0x66000000),
    );
    final body = Path()
      ..moveTo(-16, -28)
      ..lineTo(16, -28)
      ..quadraticBezierTo(24, -22, 24, -10)
      ..lineTo(20, 24)
      ..quadraticBezierTo(14, 31, 0, 32)
      ..quadraticBezierTo(-14, 31, -20, 24)
      ..lineTo(-24, -10)
      ..quadraticBezierTo(-24, -22, -16, -28)
      ..close();
    canvas.drawPath(
      body,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [_lighten(color, 0.25), color, _darken(color, 0.55)],
          stops: const [0.0, 0.52, 1.0],
        ).createShader(const Rect.fromLTWH(-24, -28, 48, 60)),
    );
    canvas.drawPath(
      body,
      Paint()
        ..color = const Color(0xAA111111)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.8,
    );
    final glass = Paint()..color = const Color(0xDDB3E5FC);
    canvas.drawPath(
      Path()
        ..moveTo(-12, -12)
        ..lineTo(12, -12)
        ..lineTo(16, 2)
        ..lineTo(-16, 2)
        ..close(),
      glass,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
          const Rect.fromLTWH(-14, 6, 28, 13), const Radius.circular(4)),
      Paint()..color = const Color(0xCC64B5F6),
    );
    canvas.drawRect(
        const Rect.fromLTWH(-18, -25, 12, 4), Paint()..color = Colors.white);
    canvas.drawRect(
        const Rect.fromLTWH(6, -25, 12, 4), Paint()..color = Colors.white);
    canvas.drawRect(const Rect.fromLTWH(-18, 25, 10, 4),
        Paint()..color = const Color(0xFFFF1744));
    canvas.drawRect(const Rect.fromLTWH(8, 25, 10, 4),
        Paint()..color = const Color(0xFFFF1744));
    canvas.drawRect(
        const Rect.fromLTWH(-27, -10, 6, 12), Paint()..color = Colors.black);
    canvas.drawRect(
        const Rect.fromLTWH(21, -10, 6, 12), Paint()..color = Colors.black);
    canvas.restore();
  }

  void _drawSkyline(Canvas canvas, double w, double horizon) {
    canvas.drawRect(Rect.fromLTWH(0, horizon - 4, w, 8),
        Paint()..color = const Color(0xFFE8D9B9));
    final colors = [
      const Color(0xFFFFE082),
      const Color(0xFFB3E5FC),
      const Color(0xFFFFAB91),
      const Color(0xFFFAFAFA),
    ];
    for (int i = 0; i < 14; i++) {
      final houseW = 54.0 + (i % 3) * 8.0;
      final houseH = 36.0 + (i % 4) * 7.0;
      final x = i * 92.0 - 20;
      final y = horizon - houseH;
      canvas.drawRect(Rect.fromLTWH(x, y, houseW, houseH),
          Paint()..color = colors[i % colors.length]);
      final roof = Path()
        ..moveTo(x - 4, y + 2)
        ..lineTo(x + houseW * 0.5, y - 20)
        ..lineTo(x + houseW + 4, y + 2)
        ..close();
      canvas.drawPath(roof, Paint()..color = const Color(0xFFC64B32));
      for (int win = 0; win < 2; win++) {
        canvas.drawRect(
          Rect.fromLTWH(x + 11 + win * 25, y + 13, 12, 11),
          Paint()..color = const Color(0xFF90CAF9),
        );
      }
      canvas.drawRect(Rect.fromLTWH(x + houseW * 0.42, y + houseH - 20, 12, 20),
          Paint()..color = const Color(0xFF6D3A20));
    }
  }

  void _drawCitySkyline(Canvas canvas, double w, double horizon) {
    final colors = [
      const Color(0xFF263238),
      const Color(0xFF37474F),
      const Color(0xFF455A64),
    ];
    for (int i = 0; i < 15; i++) {
      final bw = 64.0 + (i % 4) * 16;
      final bh = horizon * (0.54 + (i % 5) * 0.14);
      final x = i * 82.0 - 26;
      final rect = Rect.fromLTWH(x, horizon - bh, bw, bh);
      canvas.drawRect(rect, Paint()..color = colors[i % colors.length]);
      final window = Paint()..color = const Color(0xFFFFF59D);
      for (double wy = rect.top + 10; wy < rect.bottom - 8; wy += 15) {
        for (double wx = rect.left + 8; wx < rect.right - 8; wx += 15) {
          if (((wx + wy + i) % 3) < 1.5) {
            canvas.drawRect(Rect.fromLTWH(wx, wy, 5, 7), window);
          }
        }
      }
    }
    canvas.drawRect(Rect.fromLTWH(0, horizon - 3, w, 6),
        Paint()..color = const Color(0xFF202426));
  }

  void _drawMenuHouses(Canvas canvas, Size size, {required bool left}) {
    final w = size.width;
    final h = size.height;
    final baseX = left ? 8.0 : w - 92.0;
    final colors = [
      const Color(0xFFF5E6C8),
      const Color(0xFFFFE082),
      const Color(0xFFB3E5FC),
    ];
    for (int i = 0; i < 3; i++) {
      final y = h * 0.38 + i * 90;
      final x = baseX + (left ? 0 : -i * 2);
      const houseW = 82.0;
      const houseH = 58.0;
      canvas.drawRect(Rect.fromLTWH(x, y + 20, houseW, houseH),
          Paint()..color = colors[i % colors.length]);
      final roof = Path()
        ..moveTo(x - 4, y + 22)
        ..lineTo(x + houseW / 2, y)
        ..lineTo(x + houseW + 4, y + 22)
        ..close();
      canvas.drawPath(roof, Paint()..color = const Color(0xFFB54A2A));
      canvas.drawRect(Rect.fromLTWH(x + 12, y + 38, 16, 16),
          Paint()..color = const Color(0xFF90CAF9));
      canvas.drawRect(Rect.fromLTWH(x + 52, y + 38, 16, 16),
          Paint()..color = const Color(0xFF90CAF9));
      canvas.drawRect(Rect.fromLTWH(x + 34, y + 50, 16, 28),
          Paint()..color = const Color(0xFF6D3A20));
    }
  }

  void _drawMenuBuildings(Canvas canvas, Size size, {required bool left}) {
    final w = size.width;
    final h = size.height;
    final baseX = left ? 10.0 : w - 112.0;
    final colors = [
      const Color(0xFF607D8B),
      const Color(0xFF546E7A),
      const Color(0xFF6D5D4D),
    ];
    for (int i = 0; i < 3; i++) {
      final y = h * 0.34 + i * 100;
      final x = baseX + (left ? i * 3 : -i * 3);
      const bw = 96.0;
      const bh = 88.0;
      canvas.drawRect(Rect.fromLTWH(x, y, bw, bh),
          Paint()..color = colors[i % colors.length]);
      canvas.drawRect(Rect.fromLTWH(x, y + bh * 0.72, bw, bh * 0.28),
          Paint()..color = const Color(0xFF263238));
      for (int row = 0; row < 3; row++) {
        for (int col = 0; col < 3; col++) {
          canvas.drawRect(
            Rect.fromLTWH(x + 12 + col * 25, y + 12 + row * 17, 11, 9),
            Paint()
              ..color = (row + col + i).isEven
                  ? const Color(0xFFFFF59D)
                  : const Color(0xFF90CAF9),
          );
        }
      }
      for (int stripe = 0; stripe < 5; stripe++) {
        canvas.drawRect(
          Rect.fromLTWH(x + stripe * (bw / 5), y + bh * 0.67, bw / 5, 9),
          Paint()
            ..color = stripe.isEven
                ? const Color(0xFFE53935)
                : const Color(0xFFFFF8E1),
        );
      }
    }
  }

  @override
  bool shouldRepaint(covariant _LandingScenePainter oldDelegate) =>
      oldDelegate.t != t || oldDelegate.zone != zone;
}

class _TitleCard extends StatelessWidget {
  final bool compact;

  const _TitleCard({this.compact = false});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: const Color(0xDD061217),
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: const Color(0xFFFFC928), width: 1.5),
          ),
          child: Text(
            'PAPER ROUTE',
            style: GoogleFonts.pressStart2p(
              fontSize: 9,
              color: const Color(0xFFFFC928),
              letterSpacing: 1.4,
            ),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'DELIVERY',
          textAlign: TextAlign.center,
          style: GoogleFonts.pressStart2p(
            fontSize: compact ? 20 : 25,
            color: Colors.white,
            letterSpacing: 3,
            shadows: const [
              Shadow(color: Color(0xFF061217), blurRadius: 7),
              Shadow(color: Color(0xFF061217), blurRadius: 3),
            ],
          ),
        ),
        const SizedBox(height: 6),
        Text(
          'DASH',
          textAlign: TextAlign.center,
          style: GoogleFonts.pressStart2p(
            fontSize: compact ? 30 : 40,
            color: const Color(0xFFFFC928),
            letterSpacing: 8,
            shadows: const [
              Shadow(color: Color(0xFFFF6D00), blurRadius: 12),
              Shadow(color: Color(0xFF061217), blurRadius: 5),
            ],
          ),
        ),
      ],
    );
  }
}

// ignore: unused_element
class _CourierHero extends StatelessWidget {
  final CourierAvatar avatar;
  final String outfitId;
  final String bikeId;

  const _CourierHero({
    required this.avatar,
    required this.outfitId,
    required this.bikeId,
  });

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: const Size(118, 104),
      painter: _CourierHeroPainter(avatar, outfitId, bikeId),
    );
  }
}

class _CourierHeroPainter extends CustomPainter {
  final CourierAvatar avatar;
  final String outfitId;
  final String bikeId;

  const _CourierHeroPainter(this.avatar, this.outfitId, this.bikeId);

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final isGirl = avatar == CourierAvatar.girl;
    final accent = isGirl ? const Color(0xFFFF5FB7) : const Color(0xFF4A7DFF);
    final bikeColor = _bikeColor();
    final outfitTop = _outfitTop(isGirl);
    final outfitDeep = _darken(outfitTop, 0.30);
    final capeColor =
        isGirl ? const Color(0xFFFF4FA2) : const Color(0xFFD63A30);
    const gold = Color(0xFFF7C84B);
    final skin = isGirl ? const Color(0xFFFFD3AE) : const Color(0xFFF1BC8F);
    final hair = isGirl ? const Color(0xFFD89221) : const Color(0xFF6B381E);

    canvas.drawOval(
      Rect.fromCenter(
          center: Offset(w / 2, h - 6), width: w * 0.78, height: 14),
      Paint()..color = const Color(0x66000000),
    );
    _drawWheel(canvas, Offset(w * 0.26, h * 0.76), 16);
    _drawWheel(canvas, Offset(w * 0.74, h * 0.70), 16);
    final frame = Paint()
      ..color = bikeColor
      ..strokeWidth = 4.2
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(
        Offset(w * 0.50, h * 0.48), Offset(w * 0.50, h * 0.65), frame);
    canvas.drawLine(
        Offset(w * 0.50, h * 0.65), Offset(w * 0.26, h * 0.76), frame);
    canvas.drawLine(
        Offset(w * 0.50, h * 0.65), Offset(w * 0.74, h * 0.70), frame);
    canvas.drawLine(
        Offset(w * 0.50, h * 0.48), Offset(w * 0.74, h * 0.70), frame);
    canvas.drawLine(
        Offset(w * 0.36, h * 0.57), Offset(w * 0.58, h * 0.57), frame);
    canvas.drawLine(
        Offset(w * 0.58, h * 0.42),
        Offset(w * 0.84, h * 0.38),
        Paint()
          ..color = const Color(0xFF222222)
          ..strokeWidth = 4
          ..strokeCap = StrokeCap.round);
    final cape = Path()
      ..moveTo(w * 0.43, h * 0.29)
      ..quadraticBezierTo(w * 0.31, h * 0.39, w * 0.27, h * 0.58)
      ..quadraticBezierTo(w * 0.39, h * 0.56, w * 0.47, h * 0.45)
      ..quadraticBezierTo(w * 0.56, h * 0.56, w * 0.69, h * 0.54)
      ..quadraticBezierTo(w * 0.67, h * 0.36, w * 0.53, h * 0.29)
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
          center: Offset(w * 0.50, h * 0.38), width: 40, height: 29),
      const Radius.circular(12),
    );
    canvas.drawRRect(
      body,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [_lighten(outfitTop, 0.22), outfitTop, outfitDeep],
        ).createShader(body.outerRect),
    );
    canvas.drawRRect(
      body,
      Paint()
        ..color = const Color(0x44000000)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.1,
    );
    canvas.drawLine(
      Offset(w * 0.50, h * 0.26),
      Offset(w * 0.50, h * 0.50),
      Paint()
        ..color = gold
        ..strokeWidth = 4.8
        ..strokeCap = StrokeCap.round,
    );
    canvas.drawLine(
      Offset(w * 0.40, h * 0.34),
      Offset(w * 0.60, h * 0.34),
      Paint()
        ..color = gold
        ..strokeWidth = 2.4
        ..strokeCap = StrokeCap.round,
    );
    canvas.drawCircle(Offset(w * 0.41, h * 0.355), 4.3, Paint()..color = gold);
    canvas.drawCircle(Offset(w * 0.59, h * 0.355), 4.3, Paint()..color = gold);
    final sleevePaint = Paint()
      ..color = outfitDeep
      ..strokeWidth = 6.0
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(
        Offset(w * 0.43, h * 0.34), Offset(w * 0.36, h * 0.42), sleevePaint);
    canvas.drawLine(
        Offset(w * 0.57, h * 0.34), Offset(w * 0.71, h * 0.39), sleevePaint);
    canvas.drawCircle(Offset(w * 0.35, h * 0.425), 4.2, Paint()..color = skin);
    canvas.drawCircle(Offset(w * 0.72, h * 0.395), 4.2, Paint()..color = skin);
    final bag = RRect.fromRectAndRadius(
      Rect.fromLTWH(w * 0.21, h * 0.41, 26, 28),
      const Radius.circular(7),
    );
    canvas.drawRRect(bag, Paint()..color = gold);
    canvas.drawRRect(
      bag,
      Paint()
        ..color = const Color(0xFF6D4C00)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.6,
    );
    canvas.drawLine(
      Offset(w * 0.38, h * 0.25),
      Offset(w * 0.24, h * 0.44),
      Paint()
        ..color = gold
        ..strokeWidth = 3.2
        ..strokeCap = StrokeCap.round,
    );
    canvas.drawLine(
      Offset(w * 0.47, h * 0.51),
      Offset(w * 0.45, h * 0.67),
      Paint()
        ..color = const Color(0xFF4D3C87)
        ..strokeWidth = 6.0
        ..strokeCap = StrokeCap.round,
    );
    canvas.drawLine(
      Offset(w * 0.53, h * 0.51),
      Offset(w * 0.55, h * 0.64),
      Paint()
        ..color = const Color(0xFF4D3C87)
        ..strokeWidth = 6.0
        ..strokeCap = StrokeCap.round,
    );
    canvas.drawOval(
      Rect.fromCenter(center: Offset(w * 0.45, h * 0.70), width: 13, height: 7),
      Paint()..color = const Color(0xFF37205D),
    );
    canvas.drawOval(
      Rect.fromCenter(center: Offset(w * 0.56, h * 0.67), width: 13, height: 7),
      Paint()..color = const Color(0xFF37205D),
    );
    final faceRect = Rect.fromCenter(
      center: Offset(w * 0.50, h * 0.18),
      width: 33,
      height: 30,
    );
    if (isGirl) {
      final hairBack = Path()
        ..moveTo(w * 0.37, h * 0.12)
        ..quadraticBezierTo(w * 0.27, h * 0.20, w * 0.33, h * 0.37)
        ..quadraticBezierTo(w * 0.50, h * 0.43, w * 0.67, h * 0.37)
        ..quadraticBezierTo(w * 0.73, h * 0.20, w * 0.63, h * 0.12)
        ..quadraticBezierTo(w * 0.50, h * 0.05, w * 0.37, h * 0.12)
        ..close();
      canvas.drawPath(hairBack, Paint()..color = hair);
    } else {
      final hairBack = Path()
        ..moveTo(w * 0.37, h * 0.11)
        ..quadraticBezierTo(w * 0.27, h * 0.20, w * 0.34, h * 0.31)
        ..quadraticBezierTo(w * 0.50, h * 0.34, w * 0.66, h * 0.31)
        ..quadraticBezierTo(w * 0.73, h * 0.20, w * 0.63, h * 0.11)
        ..quadraticBezierTo(w * 0.50, h * 0.03, w * 0.37, h * 0.11)
        ..close();
      canvas.drawPath(hairBack, Paint()..color = hair);
    }
    canvas.drawOval(faceRect, Paint()..color = skin);
    canvas.drawOval(
      faceRect,
      Paint()
        ..color = const Color(0x44000000)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0.9,
    );
    _drawHeadTop(canvas, w, h, isGirl, hair, gold, accent);
    _drawFace(canvas, w, h, isGirl);
  }

  void _drawHeadTop(
    Canvas canvas,
    double w,
    double h,
    bool isGirl,
    Color hair,
    Color gold,
    Color accent,
  ) {
    if (isGirl) {
      final bangs = Path()
        ..moveTo(w * 0.39, h * 0.13)
        ..quadraticBezierTo(w * 0.45, h * 0.08, w * 0.50, h * 0.13)
        ..quadraticBezierTo(w * 0.56, h * 0.08, w * 0.61, h * 0.14)
        ..quadraticBezierTo(w * 0.55, h * 0.18, w * 0.39, h * 0.13)
        ..close();
      canvas.drawPath(bangs, Paint()..color = hair);
      canvas.drawCircle(Offset(w * 0.36, h * 0.23), 6.5, Paint()..color = hair);
      canvas.drawCircle(Offset(w * 0.64, h * 0.23), 6.5, Paint()..color = hair);
      final tiara = Path()
        ..moveTo(w * 0.38, h * 0.07)
        ..lineTo(w * 0.44, h * 0.01)
        ..lineTo(w * 0.50, h * 0.07)
        ..lineTo(w * 0.56, h * 0.00)
        ..lineTo(w * 0.62, h * 0.07)
        ..quadraticBezierTo(w * 0.50, h * 0.11, w * 0.38, h * 0.07)
        ..close();
      canvas.drawPath(tiara, Paint()..color = gold);
      canvas.drawCircle(
          Offset(w * 0.44, h * 0.03), 1.8, Paint()..color = accent);
      canvas.drawCircle(Offset(w * 0.56, h * 0.02), 2.0,
          Paint()..color = const Color(0xFF9C6BFF));
    } else {
      final swoop = Path()
        ..moveTo(w * 0.36, h * 0.13)
        ..quadraticBezierTo(w * 0.42, h * 0.05, w * 0.51, h * 0.12)
        ..quadraticBezierTo(w * 0.58, h * 0.06, w * 0.64, h * 0.13)
        ..quadraticBezierTo(w * 0.57, h * 0.18, w * 0.36, h * 0.13)
        ..close();
      canvas.drawPath(swoop, Paint()..color = hair);
      final crown = Path()
        ..moveTo(w * 0.34, h * 0.08)
        ..lineTo(w * 0.40, h * 0.01)
        ..lineTo(w * 0.46, h * 0.06)
        ..lineTo(w * 0.50, h * -0.01)
        ..lineTo(w * 0.56, h * 0.06)
        ..lineTo(w * 0.62, h * 0.01)
        ..lineTo(w * 0.67, h * 0.08)
        ..quadraticBezierTo(w * 0.50, h * 0.12, w * 0.34, h * 0.08)
        ..close();
      canvas.drawPath(crown, Paint()..color = gold);
      canvas.drawCircle(Offset(w * 0.40, h * 0.03), 1.7,
          Paint()..color = const Color(0xFFEF5350));
      canvas.drawCircle(
          Offset(w * 0.50, h * 0.015), 2.0, Paint()..color = accent);
      canvas.drawCircle(Offset(w * 0.61, h * 0.03), 1.7,
          Paint()..color = const Color(0xFF66BB6A));
    }
  }

  void _drawFace(Canvas canvas, double w, double h, bool isGirl) {
    final eyeWhite = Paint()..color = const Color(0xFFFDF9ED);
    final iris = Paint()
      ..color = isGirl ? const Color(0xFF45A7FF) : const Color(0xFF7C4D2C);
    final pupil = Paint()..color = const Color(0xFF24160F);
    for (final eyeX in [w * 0.455, w * 0.545]) {
      canvas.drawOval(
        Rect.fromCenter(
            center: Offset(eyeX, h * 0.175), width: 7.4, height: 6.6),
        eyeWhite,
      );
      canvas.drawCircle(Offset(eyeX, h * 0.175), 2.4, iris);
      canvas.drawCircle(Offset(eyeX, h * 0.175), 1.2, pupil);
      canvas.drawCircle(Offset(eyeX - 0.9, h * 0.166), 0.55,
          Paint()..color = const Color(0xFFFFFFFF));
    }
    final brow = Paint()
      ..color = isGirl ? const Color(0xFFBC7A16) : const Color(0xFF4A2514)
      ..strokeWidth = 0.95
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(
        Offset(w * 0.42, h * 0.145), Offset(w * 0.47, h * 0.138), brow);
    canvas.drawLine(
        Offset(w * 0.53, h * 0.138), Offset(w * 0.58, h * 0.145), brow);
    canvas.drawArc(
      Rect.fromCenter(center: Offset(w * 0.50, h * 0.19), width: 5, height: 4),
      -0.4,
      0.9,
      false,
      Paint()
        ..color = const Color(0x55986A42)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0.7,
    );
    canvas.drawCircle(Offset(w * 0.42, h * 0.21), 2.1,
        Paint()..color = const Color(0x33F48FB1));
    canvas.drawCircle(Offset(w * 0.58, h * 0.21), 2.1,
        Paint()..color = const Color(0x33F48FB1));
    final mouth = Path()
      ..moveTo(w * 0.465, h * 0.225)
      ..quadraticBezierTo(w * 0.50, h * 0.257, w * 0.535, h * 0.225)
      ..quadraticBezierTo(w * 0.50, h * 0.274, w * 0.465, h * 0.225)
      ..close();
    canvas.drawPath(mouth, Paint()..color = const Color(0xFFB63A2F));
    canvas.drawArc(
      Rect.fromCenter(
          center: Offset(w * 0.50, h * 0.224), width: 14, height: 8),
      0.18,
      pi - 0.36,
      false,
      Paint()
        ..color = const Color(0xFF5D201A)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.0,
    );
  }

  void _drawWheel(Canvas canvas, Offset c, double r) {
    canvas.drawCircle(c, r, Paint()..color = const Color(0xFF0B0B0B));
    canvas.drawCircle(c, r * 0.75, Paint()..color = const Color(0xFF616161));
    canvas.drawCircle(c, r * 0.55, Paint()..color = const Color(0xFFE0E0E0));
    final spoke = Paint()
      ..color = const Color(0xAA263238)
      ..strokeWidth = 1.0;
    for (int i = 0; i < 8; i++) {
      final a = i * pi / 4;
      canvas.drawLine(
        c,
        Offset(c.dx + cos(a) * r * 0.58, c.dy + sin(a) * r * 0.58),
        spoke,
      );
    }
    canvas.drawCircle(c, r * 0.12, Paint()..color = const Color(0xFF263238));
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

  Color _outfitTop(bool isGirl) {
    switch (outfitId) {
      case 'outfit_glam_pink':
        return const Color(0xFFFF5FB7);
      case 'outfit_sunset':
        return const Color(0xFFFFB74D);
      case 'outfit_neon':
        return const Color(0xFF64DD17);
      default:
        return isGirl ? const Color(0xFFE91E63) : const Color(0xFF1565C0);
    }
  }

  @override
  bool shouldRepaint(covariant _CourierHeroPainter oldDelegate) =>
      oldDelegate.avatar != avatar ||
      oldDelegate.outfitId != outfitId ||
      oldDelegate.bikeId != bikeId;
}

class _RouteCard extends StatelessWidget {
  final VoidCallback onEasy;
  final VoidCallback onMedium;
  final VoidCallback onHard;
  final VoidCallback onStore;
  final CourierAvatar avatar;
  final RouteZone zone;
  final ValueChanged<CourierAvatar> onAvatarChanged;
  final ValueChanged<RouteZone> onZoneChanged;

  const _RouteCard({
    required this.onEasy,
    required this.onMedium,
    required this.onHard,
    required this.onStore,
    required this.avatar,
    required this.zone,
    required this.onAvatarChanged,
    required this.onZoneChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xF2061217),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFFFC928), width: 2),
        boxShadow: const [
          BoxShadow(color: Colors.black87, blurRadius: 16, offset: Offset(0, 5))
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              Text(
                'SETUP RUN',
                style: GoogleFonts.pressStart2p(
                  fontSize: 10,
                  color: Colors.white,
                  letterSpacing: 1.2,
                ),
              ),
              const Spacer(),
              Text(
                'TAP TO ROLL',
                style: GoogleFonts.pressStart2p(
                  fontSize: 7,
                  color: const Color(0xFFFFC928),
                  letterSpacing: 1.0,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          _AvatarPicker(value: avatar, onChanged: onAvatarChanged),
          const SizedBox(height: 8),
          _SegmentedPicker<RouteZone>(
            title: 'ZONE',
            value: zone,
            values: RouteZone.values,
            labelFor: ZoneConfig.label,
            onChanged: onZoneChanged,
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                  child: _RouteButton(
                      label: 'EASY',
                      caption: 'BREEZY',
                      color: const Color(0xFF43A047),
                      onTap: onEasy)),
              const SizedBox(width: 8),
              Expanded(
                  child: _RouteButton(
                      label: 'MED',
                      caption: 'CLASSIC',
                      color: const Color(0xFFFB8C00),
                      onTap: onMedium)),
              const SizedBox(width: 8),
              Expanded(
                  child: _RouteButton(
                      label: 'HARD',
                      caption: 'CHAOS',
                      color: const Color(0xFFE53935),
                      onTap: onHard)),
            ],
          ),
          const SizedBox(height: 10),
          GestureDetector(
            onTap: onStore,
            child: Container(
              height: 42,
              decoration: BoxDecoration(
                color: const Color(0xFF0A1922),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: const Color(0xFFFFC928), width: 1.5),
              ),
              child: Center(
                  child: Text('STORE  •  UPGRADES',
                      style: GoogleFonts.pressStart2p(
                          fontSize: 10,
                          color: const Color(0xFFFFC928),
                          letterSpacing: 1.0))),
            ),
          ),
        ],
      ),
    );
  }
}

class _AvatarPicker extends StatelessWidget {
  final CourierAvatar value;
  final ValueChanged<CourierAvatar> onChanged;

  const _AvatarPicker({required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final store = StoreService.instance;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'COURIER',
          style: GoogleFonts.pressStart2p(
            color: const Color(0xFFFFC928),
            fontSize: 7,
            letterSpacing: 1.1,
          ),
        ),
        const SizedBox(height: 6),
        Row(
          children: [
            for (final avatar in CourierAvatar.values) ...[
              Expanded(
                child: _AvatarChoice(
                  avatar: avatar,
                  selected: value == avatar,
                  owned: store.isAvatarOwned(avatar),
                  price: store.avatarPrice(avatar),
                  coins: store.coins,
                  onTap: () => onChanged(avatar),
                ),
              ),
              if (avatar != CourierAvatar.values.last) const SizedBox(width: 8),
            ],
          ],
        ),
      ],
    );
  }
}

class _AvatarChoice extends StatelessWidget {
  final CourierAvatar avatar;
  final bool selected;
  final bool owned;
  final int price;
  final int coins;
  final VoidCallback onTap;

  const _AvatarChoice({
    required this.avatar,
    required this.selected,
    required this.owned,
    required this.price,
    required this.coins,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isGirl = avatar == CourierAvatar.girl;
    final accent = isGirl ? const Color(0xFFFF5FB7) : const Color(0xFF4A7DFF);
    final secondary =
        isGirl ? const Color(0xFF26C6DA) : const Color(0xFFE53935);
    final locked = !owned;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        height: 142,
        padding: const EdgeInsets.fromLTRB(8, 6, 8, 8),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: selected
                ? [
                    accent.withValues(alpha: 0.32),
                    const Color(0xFF0A1922),
                  ]
                : locked
                    ? const [
                        Color(0xFF101820),
                        Color(0xFF0A1018),
                      ]
                    : const [
                        Color(0xFF132431),
                        Color(0xFF0A1922),
                      ],
          ),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: selected
                ? accent
                : locked
                    ? const Color(0x33FFC928)
                    : const Color(0x4464B5F6),
            width: selected ? 2.2 : 1.2,
          ),
          boxShadow: selected
              ? [
                  BoxShadow(
                    color: accent.withValues(alpha: 0.42),
                    blurRadius: 14,
                    spreadRadius: 0.5,
                  ),
                ]
              : const [],
        ),
        child: Stack(
          children: [
            Column(
              children: [
                Expanded(
                  child: Center(
                    child: CustomPaint(
                      size: const Size(86, 92),
                      painter: _AvatarPortraitPainter(
                        avatar: avatar,
                        selected: selected,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  AvatarConfig.label(avatar),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.pressStart2p(
                    fontSize: 10,
                    color: Colors.white,
                    letterSpacing: 1.4,
                    shadows: const [
                      Shadow(color: Colors.black87, blurRadius: 3),
                    ],
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  locked ? 'BUY $price' : AvatarConfig.tagline(avatar),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.pressStart2p(
                    fontSize: 6,
                    color: locked
                        ? (coins >= price
                            ? const Color(0xFFFFC928)
                            : const Color(0xFFEF5350))
                        : selected
                            ? secondary
                            : Colors.white70,
                    letterSpacing: 0.9,
                  ),
                ),
              ],
            ),
            if (selected)
              Positioned(
                top: 0,
                right: 0,
                child: Container(
                  width: 18,
                  height: 18,
                  decoration: BoxDecoration(
                    color: accent,
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 1.4),
                  ),
                  child: const Icon(
                    Icons.check,
                    color: Colors.white,
                    size: 12,
                  ),
                ),
              ),
            if (locked)
              Positioned(
                top: 0,
                left: 0,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                  decoration: BoxDecoration(
                    color: const Color(0xFF15202A),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFFFFC928)),
                  ),
                  child: const Icon(
                    Icons.lock,
                    color: Color(0xFFFFC928),
                    size: 10,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _AvatarPortraitPainter extends CustomPainter {
  final CourierAvatar avatar;
  final bool selected;

  const _AvatarPortraitPainter({
    required this.avatar,
    required this.selected,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final isGirl = avatar == CourierAvatar.girl;
    final accent = isGirl ? const Color(0xFFFF5FB7) : const Color(0xFF4A7DFF);
    final coatLight =
        isGirl ? const Color(0xFFFFA2DA) : const Color(0xFF3558D3);
    final coatDark = isGirl ? const Color(0xFFE14C98) : const Color(0xFF1F348E);
    final hairColor =
        isGirl ? const Color(0xFFD89221) : const Color(0xFF6B381E);
    final skinColor =
        isGirl ? const Color(0xFFFFD3AE) : const Color(0xFFF1BC8F);
    final capeColor =
        isGirl ? const Color(0xFFFF4FA2) : const Color(0xFFD63A30);
    const gold = Color(0xFFF7C84B);
    final cx = w * 0.50;

    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(cx, h * 0.94),
        width: w * 0.46,
        height: h * 0.08,
      ),
      Paint()..color = const Color(0x44000000),
    );
    canvas.drawCircle(
      Offset(cx, h * 0.40),
      min(w, h) * 0.45,
      Paint()
        ..shader = RadialGradient(
          colors: [
            accent.withValues(alpha: selected ? 0.26 : 0.14),
            const Color(0x00000000),
          ],
        ).createShader(Offset.zero & size),
    );
    final portraitFrame = RRect.fromRectAndRadius(
      Rect.fromCenter(
        center: Offset(cx, h * 0.45),
        width: w * 0.76,
        height: h * 0.90,
      ),
      const Radius.circular(20),
    );
    canvas.drawRRect(
      portraitFrame,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            const Color(0xFF122028),
            accent.withValues(alpha: 0.14),
            const Color(0xFF0A1217),
          ],
          stops: const [0.0, 0.42, 1.0],
        ).createShader(Offset.zero & size),
    );
    canvas.drawRRect(
      portraitFrame,
      Paint()
        ..color = accent.withValues(alpha: selected ? 0.78 : 0.42)
        ..style = PaintingStyle.stroke
        ..strokeWidth = selected ? 1.8 : 1.1,
    );
    final cape = Path()
      ..moveTo(w * 0.38, h * 0.37)
      ..quadraticBezierTo(w * 0.24, h * 0.49, w * 0.27, h * 0.72)
      ..quadraticBezierTo(w * 0.40, h * 0.68, w * 0.50, h * 0.60)
      ..quadraticBezierTo(w * 0.60, h * 0.68, w * 0.73, h * 0.72)
      ..quadraticBezierTo(w * 0.76, h * 0.49, w * 0.62, h * 0.37)
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
        center: Offset(cx, h * 0.58),
        width: w * 0.24,
        height: h * 0.17,
      ),
      const Radius.circular(10),
    );
    canvas.drawRRect(
      body,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [coatLight, accent, coatDark],
        ).createShader(body.outerRect),
    );
    canvas.drawRRect(
      body,
      Paint()
        ..color = const Color(0x66000000)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.0,
    );
    final leftLapel = Path()
      ..moveTo(w * 0.46, h * 0.50)
      ..lineTo(w * 0.40, h * 0.61)
      ..lineTo(w * 0.49, h * 0.56)
      ..close();
    final rightLapel = Path()
      ..moveTo(w * 0.54, h * 0.50)
      ..lineTo(w * 0.60, h * 0.61)
      ..lineTo(w * 0.51, h * 0.56)
      ..close();
    canvas.drawPath(leftLapel, Paint()..color = const Color(0xFFF8E8C8));
    canvas.drawPath(rightLapel, Paint()..color = const Color(0xFFF8E8C8));
    canvas.drawLine(
      Offset(w * 0.50, h * 0.48),
      Offset(w * 0.50, h * 0.64),
      Paint()
        ..color = gold
        ..strokeWidth = 3.8
        ..strokeCap = StrokeCap.round,
    );
    canvas.drawLine(
      Offset(w * 0.43, h * 0.53),
      Offset(w * 0.57, h * 0.53),
      Paint()
        ..color = gold
        ..strokeWidth = 2.0
        ..strokeCap = StrokeCap.round,
    );
    canvas.drawCircle(Offset(w * 0.43, h * 0.555), 3.0, Paint()..color = gold);
    canvas.drawCircle(Offset(w * 0.57, h * 0.555), 3.0, Paint()..color = gold);
    final sleeve = Paint()
      ..color = coatDark
      ..strokeWidth = 4.2
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(
        Offset(w * 0.43, h * 0.55), Offset(w * 0.31, h * 0.62), sleeve);
    canvas.drawLine(
        Offset(w * 0.57, h * 0.55), Offset(w * 0.69, h * 0.62), sleeve);
    canvas.drawCircle(
        Offset(w * 0.29, h * 0.625), 3.0, Paint()..color = skinColor);
    canvas.drawCircle(
        Offset(w * 0.71, h * 0.625), 3.0, Paint()..color = skinColor);
    canvas.drawLine(
      Offset(w * 0.46, h * 0.67),
      Offset(w * 0.43, h * 0.84),
      Paint()
        ..color = const Color(0xFF4D3C87)
        ..strokeWidth = 4.8
        ..strokeCap = StrokeCap.round,
    );
    canvas.drawLine(
      Offset(w * 0.54, h * 0.67),
      Offset(w * 0.57, h * 0.84),
      Paint()
        ..color = const Color(0xFF4D3C87)
        ..strokeWidth = 4.8
        ..strokeCap = StrokeCap.round,
    );
    canvas.drawOval(
      Rect.fromCenter(center: Offset(w * 0.43, h * 0.88), width: 11, height: 6),
      Paint()..color = const Color(0xFF37205D),
    );
    canvas.drawOval(
      Rect.fromCenter(center: Offset(w * 0.57, h * 0.88), width: 11, height: 6),
      Paint()..color = const Color(0xFF37205D),
    );
    final bag = RRect.fromRectAndRadius(
      Rect.fromLTWH(w * 0.19, h * 0.55, 16, 18),
      const Radius.circular(5),
    );
    canvas.drawRRect(bag, Paint()..color = gold);
    canvas.drawRRect(
      bag,
      Paint()
        ..color = const Color(0xFF6D4C00)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.0,
    );
    canvas.drawLine(
      Offset(w * 0.41, h * 0.47),
      Offset(w * 0.24, h * 0.57),
      Paint()
        ..color = gold
        ..strokeWidth = 2.4
        ..strokeCap = StrokeCap.round,
    );
    final faceRect = Rect.fromCenter(
      center: Offset(cx, h * 0.27),
      width: w * 0.42,
      height: h * 0.34,
    );
    if (isGirl) {
      final hairBack = Path()
        ..moveTo(w * 0.30, h * 0.19)
        ..quadraticBezierTo(w * 0.21, h * 0.30, w * 0.27, h * 0.47)
        ..quadraticBezierTo(w * 0.50, h * 0.56, w * 0.73, h * 0.47)
        ..quadraticBezierTo(w * 0.79, h * 0.30, w * 0.70, h * 0.19)
        ..quadraticBezierTo(w * 0.50, h * 0.08, w * 0.30, h * 0.19)
        ..close();
      canvas.drawPath(hairBack, Paint()..color = hairColor);
    } else {
      final hairBack = Path()
        ..moveTo(w * 0.30, h * 0.18)
        ..quadraticBezierTo(w * 0.21, h * 0.27, w * 0.28, h * 0.40)
        ..quadraticBezierTo(w * 0.50, h * 0.46, w * 0.72, h * 0.40)
        ..quadraticBezierTo(w * 0.79, h * 0.27, w * 0.70, h * 0.18)
        ..quadraticBezierTo(w * 0.50, h * 0.08, w * 0.30, h * 0.18)
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
    _drawHeadTop(canvas, w, h, isGirl, hairColor, gold, accent);
    _drawFace(canvas, w, h, isGirl);
  }

  void _drawHeadTop(
    Canvas canvas,
    double w,
    double h,
    bool isGirl,
    Color hairColor,
    Color gold,
    Color accent,
  ) {
    if (isGirl) {
      final bangs = Path()
        ..moveTo(w * 0.34, h * 0.20)
        ..quadraticBezierTo(w * 0.44, h * 0.12, w * 0.50, h * 0.20)
        ..quadraticBezierTo(w * 0.57, h * 0.12, w * 0.66, h * 0.21)
        ..quadraticBezierTo(w * 0.59, h * 0.28, w * 0.34, h * 0.20)
        ..close();
      canvas.drawPath(bangs, Paint()..color = hairColor);
      canvas.drawCircle(
          Offset(w * 0.31, h * 0.34), 5.8, Paint()..color = hairColor);
      canvas.drawCircle(
          Offset(w * 0.69, h * 0.34), 5.8, Paint()..color = hairColor);
      final tiara = Path()
        ..moveTo(w * 0.36, h * 0.13)
        ..lineTo(w * 0.42, h * 0.07)
        ..lineTo(w * 0.50, h * 0.12)
        ..lineTo(w * 0.58, h * 0.06)
        ..lineTo(w * 0.64, h * 0.13)
        ..quadraticBezierTo(w * 0.50, h * 0.18, w * 0.35, h * 0.14)
        ..close();
      canvas.drawPath(tiara, Paint()..color = gold);
      canvas.drawCircle(
          Offset(w * 0.42, h * 0.10), 1.5, Paint()..color = accent);
      canvas.drawCircle(Offset(w * 0.58, h * 0.095), 1.6,
          Paint()..color = const Color(0xFF9C6BFF));
    } else {
      final swoop = Path()
        ..moveTo(w * 0.33, h * 0.19)
        ..quadraticBezierTo(w * 0.40, h * 0.09, w * 0.51, h * 0.18)
        ..quadraticBezierTo(w * 0.60, h * 0.10, w * 0.67, h * 0.19)
        ..quadraticBezierTo(w * 0.59, h * 0.28, w * 0.33, h * 0.19)
        ..close();
      canvas.drawPath(swoop, Paint()..color = hairColor);
      final crown = Path()
        ..moveTo(w * 0.31, h * 0.15)
        ..lineTo(w * 0.38, h * 0.08)
        ..lineTo(w * 0.44, h * 0.13)
        ..lineTo(w * 0.50, h * 0.05)
        ..lineTo(w * 0.56, h * 0.13)
        ..lineTo(w * 0.62, h * 0.08)
        ..lineTo(w * 0.69, h * 0.15)
        ..quadraticBezierTo(w * 0.50, h * 0.19, w * 0.31, h * 0.15)
        ..close();
      canvas.drawPath(crown, Paint()..color = gold);
      canvas.drawCircle(Offset(w * 0.38, h * 0.10), 1.5,
          Paint()..color = const Color(0xFFEF5350));
      canvas.drawCircle(
          Offset(w * 0.50, h * 0.075), 1.8, Paint()..color = accent);
      canvas.drawCircle(Offset(w * 0.62, h * 0.10), 1.5,
          Paint()..color = const Color(0xFF66BB6A));
    }
  }

  void _drawFace(Canvas canvas, double w, double h, bool isGirl) {
    final eyeWhite = Paint()..color = const Color(0xFFFDF9ED);
    final iris = Paint()
      ..color = isGirl ? const Color(0xFF45A7FF) : const Color(0xFF7C4D2C);
    final pupil = Paint()..color = const Color(0xFF24160F);
    for (final eyeX in [w * 0.43, w * 0.57]) {
      canvas.drawOval(
        Rect.fromCenter(
            center: Offset(eyeX, h * 0.295), width: 8.4, height: 7.4),
        eyeWhite,
      );
      canvas.drawCircle(Offset(eyeX, h * 0.30), 2.5, iris);
      canvas.drawCircle(Offset(eyeX, h * 0.30), 1.15, pupil);
      canvas.drawCircle(Offset(eyeX - 1.0, h * 0.288), 0.55,
          Paint()..color = const Color(0xFFFFFFFF));
    }
    final brow = Paint()
      ..color = isGirl ? const Color(0xFFBC7A16) : const Color(0xFF4A2514)
      ..strokeWidth = 0.9
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(
        Offset(w * 0.39, h * 0.255), Offset(w * 0.46, h * 0.245), brow);
    canvas.drawLine(
        Offset(w * 0.54, h * 0.245), Offset(w * 0.61, h * 0.255), brow);
    canvas.drawArc(
      Rect.fromCenter(
          center: Offset(w * 0.50, h * 0.32), width: 4.6, height: 3.4),
      -0.45,
      0.9,
      false,
      Paint()
        ..color = const Color(0x55986A42)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0.65,
    );
    canvas.drawCircle(Offset(w * 0.39, h * 0.35), 1.8,
        Paint()..color = const Color(0x33F48FB1));
    canvas.drawCircle(Offset(w * 0.61, h * 0.35), 1.8,
        Paint()..color = const Color(0x33F48FB1));
    canvas.drawArc(
      Rect.fromCenter(
          center: Offset(w * 0.50, h * 0.375), width: 15, height: 9),
      0.22,
      pi - 0.44,
      false,
      Paint()
        ..color = const Color(0xFF8A2F26)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.0,
    );
  }

  @override
  bool shouldRepaint(covariant _AvatarPortraitPainter oldDelegate) =>
      oldDelegate.avatar != avatar || oldDelegate.selected != selected;
}

class _SegmentedPicker<T> extends StatelessWidget {
  final String title;
  final T value;
  final List<T> values;
  final String Function(T value) labelFor;
  final ValueChanged<T> onChanged;

  const _SegmentedPicker({
    required this.title,
    required this.value,
    required this.values,
    required this.labelFor,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 58,
      padding: const EdgeInsets.all(5),
      decoration: BoxDecoration(
        color: const Color(0xFF0A1922),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0x66FFC928), width: 1.2),
      ),
      child: Column(
        children: [
          Text(
            title,
            style: GoogleFonts.pressStart2p(
              color: const Color(0xFFFFC928),
              fontSize: 6,
              letterSpacing: 0.8,
            ),
          ),
          const SizedBox(height: 5),
          Expanded(
            child: Row(
              children: values
                  .map(
                    (v) => Expanded(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 2),
                        child: GestureDetector(
                          onTap: () => onChanged(v),
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              color: v == value
                                  ? const Color(0xFFFFC928)
                                  : const Color(0xFF132733),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: v == value
                                    ? const Color(0xFFFFF59D)
                                    : const Color(0x3364B5F6),
                              ),
                            ),
                            child: Center(
                              child: Text(
                                labelFor(v),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: GoogleFonts.pressStart2p(
                                  fontSize: 7,
                                  color: v == value
                                      ? const Color(0xFF061217)
                                      : Colors.white,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  )
                  .toList(),
            ),
          ),
        ],
      ),
    );
  }
}

class _RouteButton extends StatelessWidget {
  final String label;
  final String caption;
  final Color color;
  final VoidCallback onTap;

  const _RouteButton({
    required this.label,
    required this.caption,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 62,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [_lighten(color, 0.16), color, _darken(color, 0.24)],
            stops: const [0.0, 0.58, 1.0],
          ),
          border: Border.all(color: Colors.white.withValues(alpha: 0.32)),
          boxShadow: [
            BoxShadow(color: color.withValues(alpha: 0.45), blurRadius: 10)
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(label,
                style: GoogleFonts.pressStart2p(
                    fontSize: 11,
                    color: Colors.white,
                    letterSpacing: 1.0,
                    shadows: const [
                      Shadow(color: Colors.black54, blurRadius: 3)
                    ])),
            const SizedBox(height: 6),
            Text(caption,
                style: GoogleFonts.pressStart2p(
                    fontSize: 6,
                    color: Colors.white.withValues(alpha: 0.82),
                    letterSpacing: 0.8)),
          ],
        ),
      ),
    );
  }
}

class _CoinBadge extends StatelessWidget {
  final int coins;
  const _CoinBadge({required this.coins});

  @override
  Widget build(BuildContext context) {
    return _StatBadge(label: 'COINS', value: coins.toString(), gold: true);
  }
}

class _StatBadge extends StatelessWidget {
  final String label;
  final String value;
  final bool gold;

  const _StatBadge(
      {required this.label, required this.value, this.gold = false});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: gold ? const Color(0xFFFFC928) : const Color(0xE60A1922),
        borderRadius: BorderRadius.circular(16),
        border:
            Border.all(color: const Color(0xFFFFC928), width: gold ? 0 : 1.5),
        boxShadow: const [BoxShadow(color: Colors.black45, blurRadius: 8)],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('$label ',
              style: GoogleFonts.pressStart2p(
                  fontSize: 8,
                  color: gold
                      ? const Color(0xFF15202A)
                      : const Color(0xFFFFC928))),
          Text(value,
              style: GoogleFonts.pressStart2p(
                  fontSize: 11,
                  color: gold ? const Color(0xFF15202A) : Colors.white)),
        ],
      ),
    );
  }
}
