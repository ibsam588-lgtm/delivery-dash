import 'dart:math';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import '../game/difficulty.dart';
import '../services/ad_service.dart';
import '../services/audio_service.dart';
import '../services/score_service.dart';
import '../services/store_service.dart';

const _kBg = Color(0xFF0B1020);
const _kBgDeep = Color(0xFF050813);
const _kAccent = Color(0xFFFFC93C);
const _kAccentDeep = Color(0xFFFF8A00);
const _kSurface = Color(0xCC121A2E);
const _kStroke = Color(0x22FFFFFF);
const _kTextDim = Color(0xB3FFFFFF);

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

  @override
  void initState() {
    super.initState();
    _animCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 4200),
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
        .pushNamed('/game', arguments: difficulty)
        .then((_) => _refresh());
  }

  void _onStore() {
    AudioService.instance.playPickup();
    Navigator.of(context).pushNamed('/store').then((_) => _refresh());
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
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.symmetric(horizontal: 28),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(22),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
            child: Container(
              padding: const EdgeInsets.fromLTRB(22, 22, 22, 16),
              decoration: BoxDecoration(
                color: const Color(0xE6121A2E),
                borderRadius: BorderRadius.circular(22),
                border: Border.all(color: _kStroke),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Exit route?',
                    style: GoogleFonts.outfit(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.2,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Your progress is saved. You can pick up the route any time.',
                    style: GoogleFonts.inter(
                      color: _kTextDim,
                      fontSize: 13,
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: 20),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton(
                        onPressed: () => Navigator.pop(ctx, false),
                        child: Text(
                          'Stay',
                          style: GoogleFonts.outfit(
                            color: _kAccent,
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      const SizedBox(width: 4),
                      TextButton(
                        onPressed: () => Navigator.pop(ctx, true),
                        child: Text(
                          'Exit',
                          style: GoogleFonts.outfit(
                            color: const Color(0xFFFF6B6B),
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
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
        backgroundColor: _kBgDeep,
        body: Stack(
          children: [
            Positioned.fill(
              child: AnimatedBuilder(
                animation: _animCtrl,
                builder: (context, _) => CustomPaint(
                  painter: _AuroraBackgroundPainter(t: _animCtrl.value),
                ),
              ),
            ),
            SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(18, 12, 18, 8),
                child: Column(
                  children: [
                    Row(
                      children: [
                        _StatBadge(
                          icon: Icons.emoji_events_rounded,
                          label: 'BEST',
                          value: _highScore.toString(),
                        ),
                        const Spacer(),
                        _CoinBadge(coins: _coins),
                      ],
                    ),
                    const SizedBox(height: 18),
                    const _TitleCard(),
                    const SizedBox(height: 10),
                    AnimatedBuilder(
                      animation: _animCtrl,
                      builder: (context, _) {
                        final bob = sin(_animCtrl.value * 2 * pi) * 5;
                        return Transform.translate(
                          offset: Offset(0, bob),
                          child: const _CourierAvatar(),
                        );
                      },
                    ),
                    const SizedBox(height: 10),
                    const _RouteBriefing(),
                    const Spacer(),
                    _RouteCard(
                      onEasy: () => _onPlay(Difficulty.easy),
                      onMedium: () => _onPlay(Difficulty.medium),
                      onHard: () => _onPlay(Difficulty.hard),
                      onStore: _onStore,
                    ),
                    const SizedBox(height: 10),
                    Text(
                      'Deliver papers  ·  Dodge traffic  ·  Survive the route',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.inter(
                        fontSize: 11,
                        color: _kTextDim,
                        letterSpacing: 0.4,
                        fontWeight: FontWeight.w500,
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

class _RouteBriefing extends StatelessWidget {
  const _RouteBriefing();

  @override
  Widget build(BuildContext context) {
    return _GlassCard(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 6,
                height: 6,
                decoration: const BoxDecoration(
                  color: _kAccent,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(color: _kAccent, blurRadius: 8),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Text(
                'Route briefing',
                style: GoogleFonts.outfit(
                  fontSize: 13,
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.6,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
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
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0x331C2540),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: _kStroke),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(icon, style: const TextStyle(fontSize: 12)),
          const SizedBox(width: 6),
          Text(
            text,
            style: GoogleFonts.inter(
              color: Colors.white,
              fontSize: 11,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

class _GlassCard extends StatelessWidget {
  final Widget child;
  final EdgeInsets padding;

  const _GlassCard({
    required this.child,
    required this.padding,
  });

  @override
  Widget build(BuildContext context) {
    const radius = BorderRadius.all(Radius.circular(20));
    return ClipRRect(
      borderRadius: radius,
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
        child: Container(
          padding: padding,
          decoration: BoxDecoration(
            color: _kSurface,
            borderRadius: radius,
            border: Border.all(color: _kStroke),
            boxShadow: const [
              BoxShadow(
                color: Color(0x66000000),
                blurRadius: 24,
                offset: Offset(0, 10),
              ),
            ],
          ),
          child: child,
        ),
      ),
    );
  }
}

class _AuroraBackgroundPainter extends CustomPainter {
  final double t;
  _AuroraBackgroundPainter({required this.t});

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    canvas.drawRect(
      Offset.zero & size,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF0E1530), _kBg, _kBgDeep],
        ).createShader(Offset.zero & size),
    );

    final blobs = [
      _Blob(Offset(w * (0.18 + 0.04 * sin(t * 2 * pi)), h * 0.18),
          w * 0.65, const Color(0x55FF8A00)),
      _Blob(Offset(w * (0.85 + 0.05 * cos(t * 2 * pi)), h * 0.32),
          w * 0.55, const Color(0x33FFC93C)),
      _Blob(Offset(w * 0.5, h * (0.65 + 0.03 * sin(t * 4 * pi))),
          w * 0.85, const Color(0x33334BFF)),
    ];
    for (final b in blobs) {
      canvas.drawCircle(
        b.center,
        b.radius,
        Paint()
          ..shader = RadialGradient(
            colors: [b.color, b.color.withValues(alpha: 0)],
          ).createShader(Rect.fromCircle(center: b.center, radius: b.radius))
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 40),
      );
    }

    final rng = Random(7);
    final star = Paint()..color = const Color(0xCCFFFFFF);
    for (int i = 0; i < 38; i++) {
      final x = rng.nextDouble() * w;
      final y = rng.nextDouble() * h * 0.55;
      final base = 0.4 + rng.nextDouble() * 0.6;
      final twinkle =
          0.5 + 0.5 * sin(t * 2 * pi * (0.6 + rng.nextDouble()) + i);
      canvas.drawCircle(
        Offset(x, y),
        base,
        star..color = Color.fromARGB((180 * twinkle).round(), 255, 255, 255),
      );
    }

    final horizon = h * 0.62;
    canvas.drawRect(
      Rect.fromLTWH(0, horizon, w, h - horizon),
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0x00000000), Color(0xAA000000)],
        ).createShader(Rect.fromLTWH(0, horizon, w, h - horizon)),
    );

    final laneDash = Paint()..color = const Color(0x55FFFFFF);
    final offset = (t * 70) % 70;
    for (double y = horizon + offset - 70; y < h; y += 70) {
      final prog = ((y - horizon) / (h - horizon)).clamp(0.0, 1.0);
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromCenter(
            center: Offset(w / 2, y),
            width: 2 + prog * 4,
            height: 14 + prog * 18,
          ),
          const Radius.circular(3),
        ),
        laneDash..color = Color.fromARGB((90 * prog).round(), 255, 255, 255),
      );
    }
  }

  @override
  bool shouldRepaint(covariant _AuroraBackgroundPainter oldDelegate) =>
      oldDelegate.t != t;
}

class _Blob {
  final Offset center;
  final double radius;
  final Color color;
  _Blob(this.center, this.radius, this.color);
}

class _TitleCard extends StatelessWidget {
  const _TitleCard();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: const Color(0x33FFC93C),
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: const Color(0x66FFC93C)),
          ),
          child: Text(
            'PAPER RUN',
            style: GoogleFonts.outfit(
              fontSize: 10,
              color: _kAccent,
              fontWeight: FontWeight.w700,
              letterSpacing: 3,
            ),
          ),
        ),
        const SizedBox(height: 10),
        ShaderMask(
          shaderCallback: (rect) => const LinearGradient(
            colors: [Colors.white, Color(0xFFE0E7FF)],
          ).createShader(rect),
          child: Text(
            'Delivery',
            style: GoogleFonts.outfit(
              fontSize: 30,
              color: Colors.white,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.5,
              height: 1.0,
            ),
          ),
        ),
        ShaderMask(
          shaderCallback: (rect) => const LinearGradient(
            colors: [_kAccent, _kAccentDeep],
          ).createShader(rect),
          child: Text(
            'DASH',
            style: GoogleFonts.outfit(
              fontSize: 56,
              color: Colors.white,
              fontWeight: FontWeight.w900,
              letterSpacing: 4,
              height: 1.0,
              shadows: const [
                Shadow(color: Color(0x66FF8A00), blurRadius: 24),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _CourierAvatar extends StatelessWidget {
  const _CourierAvatar();

  @override
  Widget build(BuildContext context) {
    return Stack(
      alignment: Alignment.center,
      children: [
        Container(
          width: 170,
          height: 170,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: RadialGradient(
              colors: [
                _kAccent.withValues(alpha: 0.35),
                _kAccent.withValues(alpha: 0.0),
              ],
            ),
          ),
        ),
        CustomPaint(size: const Size(140, 124), painter: _CourierPainter()),
      ],
    );
  }
}

class _CourierPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(w * 0.50, h - 6),
        width: w * 0.78,
        height: 14,
      ),
      Paint()..color = const Color(0x55000000),
    );

    _drawWheel(canvas, Offset(w * 0.30, h * 0.78), 17);
    _drawWheel(canvas, Offset(w * 0.70, h * 0.78), 17);

    final frameStroke = Paint()
      ..color = const Color(0xFFE0263A)
      ..strokeWidth = 4.6
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..style = PaintingStyle.stroke;
    final framePath = Path()
      ..moveTo(w * 0.30, h * 0.78)
      ..lineTo(w * 0.50, h * 0.60)
      ..lineTo(w * 0.70, h * 0.78)
      ..moveTo(w * 0.50, h * 0.60)
      ..lineTo(w * 0.50, h * 0.46)
      ..moveTo(w * 0.30, h * 0.78)
      ..lineTo(w * 0.50, h * 0.46)
      ..lineTo(w * 0.66, h * 0.46);
    canvas.drawPath(framePath, frameStroke);

    canvas.drawLine(
      Offset(w * 0.34, h * 0.40),
      Offset(w * 0.70, h * 0.40),
      Paint()
        ..color = const Color(0xFF1A1A2E)
        ..strokeWidth = 4
        ..strokeCap = StrokeCap.round,
    );

    final bagRect = RRect.fromRectAndRadius(
      Rect.fromCenter(
        center: Offset(w * 0.22, h * 0.55),
        width: 28,
        height: 30,
      ),
      const Radius.circular(8),
    );
    canvas.drawRRect(
      bagRect,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [_kAccent, _kAccentDeep],
        ).createShader(bagRect.outerRect),
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(
          center: Offset(w * 0.22, h * 0.50),
          width: 22,
          height: 6,
        ),
        const Radius.circular(2),
      ),
      Paint()..color = const Color(0xFFFFF6D6),
    );

    final body = RRect.fromRectAndRadius(
      Rect.fromCenter(
        center: Offset(w * 0.50, h * 0.36),
        width: 42,
        height: 34,
      ),
      const Radius.circular(12),
    );
    canvas.drawRRect(
      body,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF3B82F6), Color(0xFF1E40AF)],
        ).createShader(body.outerRect),
    );
    canvas.drawLine(
      Offset(w * 0.40, h * 0.22),
      Offset(w * 0.62, h * 0.50),
      Paint()
        ..color = _kAccent
        ..strokeWidth = 4.5
        ..strokeCap = StrokeCap.round,
    );

    canvas.drawCircle(
      Offset(w * 0.50, h * 0.18),
      15,
      Paint()..color = const Color(0xFFFFD2A8),
    );

    final cap = Path()
      ..moveTo(w * 0.34, h * 0.16)
      ..quadraticBezierTo(w * 0.50, h * 0.02, w * 0.66, h * 0.16)
      ..quadraticBezierTo(w * 0.50, h * 0.12, w * 0.34, h * 0.16)
      ..close();
    canvas.drawPath(
      cap,
      Paint()
        ..shader = const LinearGradient(
          colors: [Color(0xFFFFFFFF), Color(0xFFF1F5F9)],
        ).createShader(cap.getBounds()),
    );
    canvas.drawPath(
      cap,
      Paint()
        ..color = const Color(0xFFE0263A)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.2,
    );

    canvas.drawCircle(
      Offset(w * 0.50, h * 0.13),
      2.8,
      Paint()..color = const Color(0xFFE0263A),
    );
  }

  void _drawWheel(Canvas canvas, Offset c, double r) {
    canvas.drawCircle(c, r, Paint()..color = const Color(0xFF0B0B0F));
    canvas.drawCircle(c, r * 0.78, Paint()..color = const Color(0xFF505563));
    canvas.drawCircle(c, r * 0.55, Paint()..color = const Color(0xFFE8EAF0));
    canvas.drawCircle(c, r * 0.20, Paint()..color = const Color(0xFF1A1A2E));
    final spoke = Paint()
      ..color = const Color(0xFFB0B7C2)
      ..strokeWidth = 1.0
      ..strokeCap = StrokeCap.round;
    for (int i = 0; i < 6; i++) {
      final a = i * pi / 3;
      canvas.drawLine(
        c,
        Offset(c.dx + cos(a) * r * 0.7, c.dy + sin(a) * r * 0.7),
        spoke,
      );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _RouteCard extends StatelessWidget {
  final VoidCallback onEasy;
  final VoidCallback onMedium;
  final VoidCallback onHard;
  final VoidCallback onStore;

  const _RouteCard({
    required this.onEasy,
    required this.onMedium,
    required this.onHard,
    required this.onStore,
  });

  @override
  Widget build(BuildContext context) {
    return _GlassCard(
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
      child: Column(
        children: [
          Row(
            children: [
              Text(
                'Choose route',
                style: GoogleFonts.outfit(
                  fontSize: 13,
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.4,
                ),
              ),
              const Spacer(),
              Text(
                'Tap to start',
                style: GoogleFonts.inter(
                  fontSize: 10,
                  color: _kTextDim,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _RouteButton(
                  label: 'Easy',
                  sub: 'Cruise',
                  colors: const [Color(0xFF22D3A8), Color(0xFF059669)],
                  onTap: onEasy,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _RouteButton(
                  label: 'Medium',
                  sub: 'Rush',
                  colors: const [Color(0xFFFBBF24), Color(0xFFEA580C)],
                  onTap: onMedium,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _RouteButton(
                  label: 'Hard',
                  sub: 'Chaos',
                  colors: const [Color(0xFFFB7185), Color(0xFFB91C1C)],
                  onTap: onHard,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          GestureDetector(
            onTap: onStore,
            child: Container(
              height: 48,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0x331C2540), Color(0x111C2540)],
                ),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: const Color(0x55FFC93C)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.storefront_rounded,
                      color: _kAccent, size: 18),
                  const SizedBox(width: 8),
                  Text(
                    'Store  ·  Upgrades',
                    style: GoogleFonts.outfit(
                      fontSize: 13,
                      color: _kAccent,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.4,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _RouteButton extends StatelessWidget {
  final String label;
  final String sub;
  final List<Color> colors;
  final VoidCallback onTap;

  const _RouteButton({
    required this.label,
    required this.sub,
    required this.colors,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 60,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: colors,
          ),
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: colors.last.withValues(alpha: 0.45),
              blurRadius: 16,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              label,
              style: GoogleFonts.outfit(
                fontSize: 14,
                color: Colors.white,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.4,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              sub,
              style: GoogleFonts.inter(
                fontSize: 10,
                color: Colors.white.withValues(alpha: 0.8),
                fontWeight: FontWeight.w500,
              ),
            ),
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
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [_kAccent, _kAccentDeep],
        ),
        borderRadius: BorderRadius.circular(999),
        boxShadow: const [
          BoxShadow(color: Color(0x55FF8A00), blurRadius: 16),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text('🪙', style: TextStyle(fontSize: 13)),
          const SizedBox(width: 6),
          Text(
            coins.toString(),
            style: GoogleFonts.outfit(
              fontSize: 13,
              color: const Color(0xFF1A1A2E),
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class _StatBadge extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _StatBadge({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(999),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: _kSurface,
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: _kStroke),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, color: _kAccent, size: 14),
              const SizedBox(width: 6),
              Text(
                label,
                style: GoogleFonts.inter(
                  fontSize: 10,
                  color: _kTextDim,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 1.0,
                ),
              ),
              const SizedBox(width: 6),
              Text(
                value,
                style: GoogleFonts.outfit(
                  fontSize: 13,
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
