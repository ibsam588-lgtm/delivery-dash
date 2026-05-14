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

  Future<void> _buy(StoreItem item) async {
    if (StoreService.instance.coins < item.price) {
      _showSnack('Not enough coins');
      return;
    }
    final ok = await StoreService.instance.purchaseItem(item.id);
    if (!mounted) return;
    if (ok) {
      _showSnack('Unlocked ${item.name}');
      setState(() {});
    }
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
      backgroundColor: const Color(0xFF0E0E11),
      body: SafeArea(
        child: Column(
          children: [
            _Header(coins: coins, onBack: () => Navigator.of(context).pop()),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: GridView.builder(
                  itemCount: StoreService.items.length,
                  gridDelegate:
                      const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    childAspectRatio: 0.78,
                    crossAxisSpacing: 12,
                    mainAxisSpacing: 12,
                  ),
                  itemBuilder: (context, index) {
                    final item = StoreService.items[index];
                    return _ItemCard(
                      item: item,
                      owned: StoreService.instance.isOwned(item.id),
                      onBuy: () => _buy(item),
                    );
                  },
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
      padding: const EdgeInsets.fromLTRB(8, 12, 16, 16),
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
                fontSize: 20,
                color: Colors.white,
              ),
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.55),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: const Color(0xFFFFD54F), width: 1.5),
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
                    color: const Color(0xFFFFD54F),
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

class _ItemCard extends StatelessWidget {
  final StoreItem item;
  final bool owned;
  final VoidCallback onBuy;

  const _ItemCard({
    required this.item,
    required this.owned,
    required this.onBuy,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF1B1B22),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: owned
              ? const Color(0xFF66BB6A).withValues(alpha: 0.6)
              : Colors.white12,
        ),
      ),
      child: Column(
        children: [
          Text(item.emoji, style: const TextStyle(fontSize: 38)),
          const SizedBox(height: 6),
          Text(
            item.name,
            textAlign: TextAlign.center,
            style: GoogleFonts.pressStart2p(
              fontSize: 10,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            item.description,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 11,
            ),
          ),
          const Spacer(),
          if (owned)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 9),
              decoration: BoxDecoration(
                color: const Color(0xFF37474F),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Center(
                child: Text(
                  'OWNED',
                  style: GoogleFonts.pressStart2p(
                    fontSize: 10,
                    color: Colors.white60,
                  ),
                ),
              ),
            )
          else
            GestureDetector(
              onTap: onBuy,
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 9),
                decoration: BoxDecoration(
                  color: const Color(0xFF2E7D32),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Center(
                  child: Text(
                    'BUY  🪙${item.price}',
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
