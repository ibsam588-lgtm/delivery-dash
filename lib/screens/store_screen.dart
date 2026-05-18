import 'dart:math';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/store_service.dart';

class StoreScreen extends StatefulWidget {
  const StoreScreen({super.key});

  @override
  State<StoreScreen> createState() => _StoreScreenState();
}

class _StoreScreenState extends State<StoreScreen> {
  @override
  void initState() {
    super.initState();
    StoreService.instance.init().then((_) {
      if (mounted) setState(() {});
    });
  }

  Future<void> _buyPowerUp(StoreItem item) async {
    final s = StoreService.instance;
    if (item.id == 'extra_life' && s.extraLives >= StoreService.maxExtraLives) {
      _showSnack('Already at max extra lives');
      return;
    }
    if (s.coins < item.price) {
      _showSnack('Not enough coins');
      return;
    }
    final ok = await s.purchasePowerUp(item.id);
    if (!mounted) return;
    if (ok) {
      _showSnack('+ ${item.name}');
      setState(() {});
    }
  }

  Future<void> _buyCosmetic(CosmeticItem item) async {
    final s = StoreService.instance;
    if (s.isCosmeticOwned(item.id)) {
      final ok = await s.equipCosmetic(item.id);
      if (!mounted) return;
      if (ok) {
        _showSnack('${item.name} equipped');
        setState(() {});
      }
      return;
    }
    if (s.coins < item.price) {
      _showSnack('Not enough coins');
      return;
    }
    final ok = await s.purchaseCosmetic(item.id);
    if (!mounted) return;
    if (ok) {
      _showSnack('${item.name} unlocked');
      setState(() {});
    }
  }

  void _buyCoinPack(StoreItem pack) {
    // IAP is not yet wired up in this build. When IAP lands, route a
    // successful platform purchase through StoreService.grantCoinPack(pack.id).
    _showSnack('${pack.name} — coming soon');
  }

  void _showSnack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: const Color(0xFF263238),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final coins = StoreService.instance.coins;
    return Scaffold(
      backgroundColor: const Color(0xFF081018),
      body: SafeArea(
        child: Column(
          children: [
            _Header(coins: coins, onBack: () => Navigator.of(context).pop()),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const _SectionHeader('STYLE SHOP'),
                    const SizedBox(height: 10),
                    GridView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: StoreService.cosmetics.length,
                      gridDelegate:
                          const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 2,
                        mainAxisExtent: 258,
                        crossAxisSpacing: 12,
                        mainAxisSpacing: 12,
                      ),
                      itemBuilder: (context, index) {
                        final item = StoreService.cosmetics[index];
                        final s = StoreService.instance;
                        return _CosmeticCard(
                          item: item,
                          coins: coins,
                          owned: s.isCosmeticOwned(item.id),
                          equipped: s.isCosmeticEquipped(item),
                          onBuy: () => _buyCosmetic(item),
                        );
                      },
                    ),
                    const SizedBox(height: 22),
                    const _SectionHeader('POWER-UPS'),
                    const SizedBox(height: 10),
                    GridView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: StoreService.powerUps.length,
                      gridDelegate:
                          const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 2,
                        childAspectRatio: 0.80,
                        crossAxisSpacing: 12,
                        mainAxisSpacing: 12,
                      ),
                      itemBuilder: (context, index) {
                        final item = StoreService.powerUps[index];
                        return _PowerUpCard(
                          item: item,
                          coins: coins,
                          quantity: StoreService.instance.quantityOf(item.id),
                          maxedOut: item.id == 'extra_life' &&
                              StoreService.instance.extraLives >=
                                  StoreService.maxExtraLives,
                          onBuy: () => _buyPowerUp(item),
                        );
                      },
                    ),
                    const SizedBox(height: 22),
                    const _SectionHeader('COIN PACKS'),
                    const SizedBox(height: 10),
                    Column(
                      children: [
                        for (final pack in StoreService.coinPacks) ...[
                          _CoinPackCard(
                            pack: pack,
                            onBuy: () => _buyCoinPack(pack),
                          ),
                          const SizedBox(height: 10),
                        ],
                      ],
                    ),
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

class _Header extends StatelessWidget {
  final int coins;
  final VoidCallback onBack;
  const _Header({required this.coins, required this.onBack});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 10, 16, 12),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back, color: Colors.white),
            onPressed: onBack,
          ),
          Expanded(
            child: Text(
              'STORE',
              style: GoogleFonts.pressStart2p(
                fontSize: 18,
                color: Colors.white,
                letterSpacing: 2,
              ),
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFFFFC107), Color(0xFFFFD600)],
              ),
              borderRadius: BorderRadius.circular(16),
              boxShadow: const [
                BoxShadow(color: Color(0x66FFD600), blurRadius: 12),
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('🪙', style: TextStyle(fontSize: 18)),
                const SizedBox(width: 6),
                Text(
                  '$coins',
                  style: GoogleFonts.pressStart2p(
                    fontSize: 14,
                    color: const Color(0xFF1A1A2E),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String label;
  const _SectionHeader(this.label);

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 4,
          height: 18,
          color: const Color(0xFF00E676),
        ),
        const SizedBox(width: 8),
        Text(
          label,
          style: GoogleFonts.pressStart2p(
            fontSize: 13,
            color: Colors.white,
            letterSpacing: 2,
          ),
        ),
      ],
    );
  }
}

class _PowerUpCard extends StatelessWidget {
  final StoreItem item;
  final int coins;
  final int quantity;
  final bool maxedOut;
  final VoidCallback onBuy;

  const _PowerUpCard({
    required this.item,
    required this.coins,
    required this.quantity,
    required this.maxedOut,
    required this.onBuy,
  });

  @override
  Widget build(BuildContext context) {
    final affordable = coins >= item.price && !maxedOut;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF1B1B22), Color(0xFF101015)],
        ),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: affordable
              ? const Color(0xFF00E676).withValues(alpha: 0.45)
              : Colors.white12,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(item.emoji, style: const TextStyle(fontSize: 30)),
              if (quantity > 0)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: const Color(0xFF263238),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    'x$quantity',
                    style: GoogleFonts.pressStart2p(
                      fontSize: 8,
                      color: const Color(0xFF00E676),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            item.name,
            style: GoogleFonts.pressStart2p(
              fontSize: 9,
              color: Colors.white,
              letterSpacing: 1,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            item.description,
            style: const TextStyle(
              fontSize: 10,
              color: Colors.white70,
            ),
          ),
          const Spacer(),
          GestureDetector(
            onTap: affordable ? onBuy : null,
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 9),
              decoration: BoxDecoration(
                color: maxedOut
                    ? const Color(0xFF37474F)
                    : (affordable
                        ? const Color(0xFF43A047)
                        : const Color(0xFF424242)),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Center(
                child: Text(
                  maxedOut ? 'MAX' : '🪙 ${item.price}',
                  style: GoogleFonts.pressStart2p(
                    fontSize: 10,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CosmeticCard extends StatelessWidget {
  final CosmeticItem item;
  final int coins;
  final bool owned;
  final bool equipped;
  final VoidCallback onBuy;

  const _CosmeticCard({
    required this.item,
    required this.coins,
    required this.owned,
    required this.equipped,
    required this.onBuy,
  });

  @override
  Widget build(BuildContext context) {
    final affordable = coins >= item.price || owned;
    final accent = _accentFor(item.id);
    final isBike = item.category == CosmeticCategory.bike;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color.lerp(accent, const Color(0xFF101824), 0.78)!,
            const Color(0xFF071019),
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: equipped
              ? const Color(0xFFFFD600)
              : accent.withValues(alpha: owned ? 0.70 : 0.38),
          width: equipped ? 2 : 1.2,
        ),
        boxShadow: [
          BoxShadow(color: accent.withValues(alpha: 0.18), blurRadius: 16),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            height: 118,
            child: CustomPaint(
              painter: isBike
                  ? _BikePreviewPainter(accent)
                  : _OutfitPreviewPainter(accent),
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Container(
                width: 22,
                height: 22,
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.22),
                  borderRadius: BorderRadius.circular(7),
                  border: Border.all(color: accent.withValues(alpha: 0.75)),
                ),
                child: Icon(
                  isBike ? Icons.pedal_bike : Icons.checkroom,
                  size: 14,
                  color: Colors.white,
                ),
              ),
              const SizedBox(width: 6),
              Text(
                isBike ? 'BIKE' : 'OUTFIT',
                style: GoogleFonts.pressStart2p(
                  fontSize: 7,
                  color: accent,
                  letterSpacing: 1.1,
                ),
              ),
            ],
          ),
          const SizedBox(height: 7),
          Text(
            item.name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.pressStart2p(
              fontSize: 8,
              color: Colors.white,
              letterSpacing: 0.8,
            ),
          ),
          const SizedBox(height: 5),
          Text(
            item.description,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 10,
              color: Colors.white70,
              height: 1.15,
            ),
          ),
          const SizedBox(height: 9),
          GestureDetector(
            onTap: affordable ? onBuy : null,
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 9),
              decoration: BoxDecoration(
                color: equipped
                    ? const Color(0xFFFFD600)
                    : owned
                        ? const Color(0xFF00A86B)
                        : affordable
                            ? accent
                            : const Color(0xFF424242),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Center(
                child: Text(
                  equipped
                      ? 'EQUIPPED'
                      : owned
                          ? 'EQUIP'
                          : item.price == 0
                              ? 'FREE'
                              : 'COINS ${item.price}',
                  style: GoogleFonts.pressStart2p(
                    fontSize: 8,
                    color: equipped ? const Color(0xFF101824) : Colors.white,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Color _accentFor(String id) {
    switch (id) {
      case 'outfit_glam_pink':
        return const Color(0xFFFF5FB7);
      case 'outfit_sunset':
        return const Color(0xFFFF8A00);
      case 'outfit_neon':
      case 'bike_neon':
        return const Color(0xFF64DD17);
      case 'bike_sky':
        return const Color(0xFF19A7CE);
      case 'bike_gold':
        return const Color(0xFFFFC928);
      default:
        return id.startsWith('bike')
            ? const Color(0xFFD71920)
            : const Color(0xFF1565C0);
    }
  }
}

class _OutfitPreviewPainter extends CustomPainter {
  final Color accent;
  const _OutfitPreviewPainter(this.accent);

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final cx = w * 0.50;
    final bodyW = min(w * 0.30, h * 0.92);
    final bodyH = h * 0.38;
    final faceR = h * 0.155;
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(cx, h * 0.89),
        width: bodyW * 1.75,
        height: h * 0.10,
      ),
      Paint()..color = const Color(0x77000000),
    );
    canvas.drawCircle(
      Offset(cx, h * 0.40),
      h * 0.29,
      Paint()
        ..shader = RadialGradient(
          colors: [
            accent.withValues(alpha: 0.26),
            accent.withValues(alpha: 0.02),
          ],
        ).createShader(Rect.fromCircle(
          center: Offset(cx, h * 0.40),
          radius: h * 0.31,
        )),
    );

    final hairBack = Paint()..color = const Color(0xFFFFD166);
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(cx, h * 0.36),
        width: h * 0.38,
        height: h * 0.42,
      ),
      hairBack,
    );
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(cx - h * 0.18, h * 0.47),
        width: h * 0.17,
        height: h * 0.28,
      ),
      hairBack,
    );
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(cx + h * 0.18, h * 0.47),
        width: h * 0.17,
        height: h * 0.28,
      ),
      hairBack,
    );

    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(
          center: Offset(cx, h * 0.70),
          width: bodyW,
          height: bodyH,
        ),
        const Radius.circular(16),
      ),
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color.lerp(accent, Colors.white, 0.32)!,
            accent,
            Color.lerp(accent, Colors.black, 0.24)!,
          ],
        ).createShader(Offset.zero & size),
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(
          center: Offset(cx, h * 0.70),
          width: bodyW,
          height: bodyH,
        ),
        const Radius.circular(16),
      ),
      Paint()
        ..color = const Color(0x66000000)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.2,
    );
    canvas.drawLine(
      Offset(cx - bodyW * 0.32, h * 0.54),
      Offset(cx + bodyW * 0.18, h * 0.86),
      Paint()
        ..color = const Color(0xFFFFD54F)
        ..strokeWidth = 4.4
        ..strokeCap = StrokeCap.round,
    );
    final bag = RRect.fromRectAndRadius(
      Rect.fromLTWH(cx - bodyW * 0.46, h * 0.70, bodyW * 0.36, h * 0.16),
      const Radius.circular(6),
    );
    canvas.drawRRect(bag, Paint()..color = const Color(0xFFFFD54F));
    canvas.drawRRect(
      bag,
      Paint()
        ..color = const Color(0xFF6D4C00)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.0,
    );

    canvas.drawCircle(
        Offset(cx, h * 0.34), faceR, Paint()..color = const Color(0xFFFFC590));
    final bang = Path()
      ..moveTo(cx - h * 0.14, h * 0.29)
      ..quadraticBezierTo(cx - h * 0.04, h * 0.18, cx + h * 0.13, h * 0.26)
      ..quadraticBezierTo(cx + h * 0.04, h * 0.33, cx - h * 0.14, h * 0.29)
      ..close();
    canvas.drawPath(bang, Paint()..color = const Color(0xFFFFD166));
    canvas.drawCircle(Offset(cx - h * 0.055, h * 0.34), 1.8,
        Paint()..color = const Color(0xFF2D1B12));
    canvas.drawCircle(Offset(cx + h * 0.055, h * 0.34), 1.8,
        Paint()..color = const Color(0xFF2D1B12));
    canvas.drawArc(
      Rect.fromCenter(
        center: Offset(cx, h * 0.39),
        width: h * 0.11,
        height: h * 0.05,
      ),
      0.15,
      2.84,
      false,
      Paint()
        ..color = const Color(0xFFC75B39)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.2,
    );
    canvas.drawCircle(
        Offset(cx + h * 0.135, h * 0.27), h * 0.045, Paint()..color = accent);
    canvas.drawCircle(
        Offset(cx + h * 0.175, h * 0.30), h * 0.035, Paint()..color = accent);
    for (final point in [
      Offset(cx - bodyW * 0.92, h * 0.22),
      Offset(cx + bodyW * 0.92, h * 0.18),
      Offset(cx + bodyW * 1.02, h * 0.58),
    ]) {
      canvas.drawCircle(point, 2.2, Paint()..color = const Color(0xFFFFF59D));
      canvas.drawCircle(point, 0.9, Paint()..color = Colors.white);
    }
  }

  @override
  bool shouldRepaint(covariant _OutfitPreviewPainter oldDelegate) =>
      oldDelegate.accent != accent;
}

class _BikePreviewPainter extends CustomPainter {
  final Color accent;
  const _BikePreviewPainter(this.accent);

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(w * 0.50, h * 0.83),
        width: w * 0.70,
        height: h * 0.11,
      ),
      Paint()..color = const Color(0x77000000),
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(w * 0.12, h * 0.16, w * 0.76, h * 0.58),
        const Radius.circular(18),
      ),
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            accent.withValues(alpha: 0.18),
            const Color(0x11000000),
          ],
        ).createShader(Rect.fromLTWH(w * 0.12, h * 0.16, w * 0.76, h * 0.58)),
    );
    final wheel = Paint()
      ..color = const Color(0xFF111111)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 5.5;
    final rim = Paint()
      ..color = const Color(0xFFECEFF1)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0;
    final l = Offset(w * 0.26, h * 0.68);
    final r = Offset(w * 0.74, h * 0.68);
    canvas.drawCircle(l, h * 0.16, wheel);
    canvas.drawCircle(r, h * 0.16, wheel);
    canvas.drawCircle(l, h * 0.105, rim);
    canvas.drawCircle(r, h * 0.105, rim);
    for (final center in [l, r]) {
      for (int i = 0; i < 8; i++) {
        final a = i * 0.785398;
        canvas.drawLine(
          center,
          Offset(center.dx + cos(a) * h * 0.12, center.dy + sin(a) * h * 0.12),
          Paint()
            ..color = const Color(0x99ECEFF1)
            ..strokeWidth = 0.8,
        );
      }
    }
    final frame = Paint()
      ..color = accent
      ..strokeWidth = 5.4
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    final shine = Paint()
      ..color = Colors.white.withValues(alpha: 0.36)
      ..strokeWidth = 1.7
      ..strokeCap = StrokeCap.round;
    final seat = Offset(w * 0.45, h * 0.40);
    final crank = Offset(w * 0.50, h * 0.60);
    final bar = Offset(w * 0.76, h * 0.38);
    final forkTop = Offset(w * 0.69, h * 0.48);
    canvas.drawLine(l, crank, frame);
    canvas.drawLine(crank, r, frame);
    canvas.drawLine(l, seat, frame);
    canvas.drawLine(seat, forkTop, frame);
    canvas.drawLine(forkTop, r, frame);
    canvas.drawLine(seat, crank, frame);
    canvas.drawLine(forkTop, bar, frame);
    canvas.drawLine(seat, Offset(w * 0.39, h * 0.35), frame);
    canvas.drawLine(Offset(w * 0.70, h * 0.36), bar, frame);
    canvas.drawLine(l, crank, shine);
    canvas.drawLine(seat, forkTop, shine);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(
          center: Offset(w * 0.41, h * 0.35),
          width: w * 0.15,
          height: h * 0.035,
        ),
        const Radius.circular(5),
      ),
      Paint()..color = const Color(0xFF222222),
    );
    canvas.drawLine(
      bar,
      Offset(w * 0.84, h * 0.34),
      Paint()
        ..color = const Color(0xFF222222)
        ..strokeWidth = 3.2
        ..strokeCap = StrokeCap.round,
    );
    canvas.drawCircle(crank, 5.5, Paint()..color = const Color(0xFFFFD54F));
    canvas.drawLine(
      crank,
      Offset(w * 0.58, h * 0.63),
      Paint()
        ..color = const Color(0xFF263238)
        ..strokeWidth = 2.5
        ..strokeCap = StrokeCap.round,
    );
  }

  @override
  bool shouldRepaint(covariant _BikePreviewPainter oldDelegate) =>
      oldDelegate.accent != accent;
}

class _CoinPackCard extends StatelessWidget {
  final StoreItem pack;
  final VoidCallback onBuy;
  const _CoinPackCard({required this.pack, required this.onBuy});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF263238), Color(0xFF1B1F23)],
        ),
        borderRadius: BorderRadius.circular(14),
        border:
            Border.all(color: const Color(0xFFFFD600).withValues(alpha: 0.45)),
      ),
      child: Row(
        children: [
          Text(pack.emoji, style: const TextStyle(fontSize: 30)),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  pack.name,
                  style: GoogleFonts.pressStart2p(
                    fontSize: 11,
                    color: Colors.white,
                    letterSpacing: 1.2,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  pack.description,
                  style: const TextStyle(
                    fontSize: 12,
                    color: Color(0xFFFFD600),
                  ),
                ),
              ],
            ),
          ),
          GestureDetector(
            onTap: onBuy,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: const Color(0xFFFFD600),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                pack.iapPrice ?? '',
                style: GoogleFonts.pressStart2p(
                  fontSize: 11,
                  color: const Color(0xFF1A1A2E),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
