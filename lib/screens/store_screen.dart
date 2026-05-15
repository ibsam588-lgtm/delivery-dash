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
    if (item.id == 'extra_life' &&
        s.extraLives >= StoreService.maxExtraLives) {
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
      backgroundColor: const Color(0xFF0D0D0D),
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
            padding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
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
                  padding: const EdgeInsets.symmetric(
                      horizontal: 6, vertical: 2),
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
        border: Border.all(color: const Color(0xFFFFD600).withValues(alpha: 0.45)),
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
              padding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
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
