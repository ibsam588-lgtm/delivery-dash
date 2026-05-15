import 'package:shared_preferences/shared_preferences.dart';

/// A purchasable store item — either a consumable power-up or a coin pack.
/// The [price] is in coins (for power-ups) or 0 for IAP-priced items.
class StoreItem {
  final String id;
  final String name;
  final String emoji;
  final String description;
  final int price;        // in coins (0 for IAP packs)
  final String? iapPrice; // e.g. "$0.99" for coin packs
  final int? coinsAwarded;
  final bool isConsumable;

  const StoreItem({
    required this.id,
    required this.name,
    required this.emoji,
    required this.description,
    required this.price,
    this.iapPrice,
    this.coinsAwarded,
    this.isConsumable = false,
  });
}

class StoreService {
  static final StoreService instance = StoreService._();
  StoreService._();

  static const String _kCoins = 'coins';
  // Legacy permanent unlocks (kept so game_screen can still read them).
  static const String _kShield = 'item_shield';
  static const String _kSpeedBoost = 'item_speed_boost';
  static const String _kDoubleCoins = 'item_double_coins';
  static const String _kPaperBlitz = 'item_paper_blitz';
  static const String _kVipSkin = 'item_vip_skin';
  // Consumable inventory.
  static const String _kExtraLives = 'inv_extra_lives';
  static const String _kPapers = 'inv_papers';
  static const String _kSpeedBoosts = 'inv_speed_boosts';
  static const String _kShields = 'inv_shields';

  static const int maxExtraLives = 3;

  // ── Power-up items (purchased with coins) ────────────────────────────────
  static const List<StoreItem> powerUps = [
    StoreItem(
      id: 'extra_life',
      name: 'EXTRA LIFE',
      emoji: '❤️',
      description: '+1 life (max 3)',
      price: 50,
      isConsumable: true,
    ),
    StoreItem(
      id: 'paper_bundle_20',
      name: 'PAPER PACK',
      emoji: '📰',
      description: '+20 papers',
      price: 30,
      isConsumable: true,
    ),
    StoreItem(
      id: 'paper_bundle_50',
      name: 'BIG PAPER PACK',
      emoji: '📦',
      description: '+50 papers',
      price: 70,
      isConsumable: true,
    ),
    StoreItem(
      id: 'speed_boost_30s',
      name: 'SPEED BOOST',
      emoji: '⚡',
      description: '30s boost',
      price: 25,
      isConsumable: true,
    ),
    StoreItem(
      id: 'shield_30s',
      name: 'SHIELD',
      emoji: '🛡️',
      description: '30s invincible',
      price: 40,
      isConsumable: true,
    ),
  ];

  // ── Coin packs (purchased with real money — IAP placeholders) ────────────
  static const List<StoreItem> coinPacks = [
    StoreItem(
      id: 'pack_starter',
      name: 'STARTER PACK',
      emoji: '💰',
      description: '2,500 coins',
      price: 0,
      iapPrice: r'$0.99',
      coinsAwarded: 2500,
    ),
    StoreItem(
      id: 'pack_value',
      name: 'VALUE PACK',
      emoji: '💎',
      description: '7,000 coins',
      price: 0,
      iapPrice: r'$2.49',
      coinsAwarded: 7000,
    ),
    StoreItem(
      id: 'pack_mega',
      name: 'MEGA PACK',
      emoji: '🏆',
      description: '15,000 coins',
      price: 0,
      iapPrice: r'$4.99',
      coinsAwarded: 15000,
    ),
  ];

  /// Legacy reference — kept for backward compatibility with any older
  /// code paths. New code should use [powerUps] and [coinPacks].
  static List<StoreItem> get items => powerUps;

  SharedPreferences? _prefs;
  int _coins = 0;
  bool _shieldOwned = false;
  bool _speedBoostOwned = false;
  bool _doubleCoinsOwned = false;
  bool _paperBlitzOwned = false;
  bool _vipSkinOwned = false;

  int _extraLives = 0;
  int _papers = 0;
  int _speedBoosts = 0;
  int _shields = 0;

  Future<void> init() async {
    _prefs ??= await SharedPreferences.getInstance();
    _coins = _prefs!.getInt(_kCoins) ?? 0;
    _shieldOwned = _prefs!.getBool(_kShield) ?? false;
    _speedBoostOwned = _prefs!.getBool(_kSpeedBoost) ?? false;
    _doubleCoinsOwned = _prefs!.getBool(_kDoubleCoins) ?? false;
    _paperBlitzOwned = _prefs!.getBool(_kPaperBlitz) ?? false;
    _vipSkinOwned = _prefs!.getBool(_kVipSkin) ?? false;
    _extraLives = _prefs!.getInt(_kExtraLives) ?? 0;
    _papers = _prefs!.getInt(_kPapers) ?? 0;
    _speedBoosts = _prefs!.getInt(_kSpeedBoosts) ?? 0;
    _shields = _prefs!.getInt(_kShields) ?? 0;
  }

  int get coins => _coins;
  bool get shieldOwned => _shieldOwned;
  bool get speedBoostOwned => _speedBoostOwned;
  bool get doubleCoinsOwned => _doubleCoinsOwned;
  bool get paperBlitzOwned => _paperBlitzOwned;
  bool get vipSkinOwned => _vipSkinOwned;

  int get extraLives => _extraLives;
  int get inventoryPapers => _papers;
  int get speedBoosts => _speedBoosts;
  int get shields => _shields;

  int quantityOf(String id) {
    switch (id) {
      case 'extra_life':
        return _extraLives;
      case 'paper_bundle_20':
      case 'paper_bundle_50':
        return _papers;
      case 'speed_boost_30s':
        return _speedBoosts;
      case 'shield_30s':
        return _shields;
    }
    return 0;
  }

  bool isOwned(String id) {
    switch (id) {
      case 'shield':
        return _shieldOwned;
      case 'speed_boost':
        return _speedBoostOwned;
      case 'double_coins':
        return _doubleCoinsOwned;
      case 'paper_blitz':
        return _paperBlitzOwned;
      case 'vip_skin':
        return _vipSkinOwned;
    }
    return false;
  }

  Future<void> addCoins(int amount) async {
    if (amount <= 0) return;
    _coins += amount;
    await _prefs?.setInt(_kCoins, _coins);
  }

  Future<bool> spendCoins(int amount) async {
    if (_coins < amount) return false;
    _coins -= amount;
    await _prefs?.setInt(_kCoins, _coins);
    return true;
  }

  /// Purchase a power-up. Returns false if not enough coins or at cap.
  Future<bool> purchasePowerUp(String id) async {
    final item = powerUps.firstWhere(
      (i) => i.id == id,
      orElse: () => const StoreItem(
        id: '',
        name: '',
        emoji: '',
        description: '',
        price: 0,
      ),
    );
    if (item.id.isEmpty) return false;
    // Cap extra lives.
    if (id == 'extra_life' && _extraLives >= maxExtraLives) return false;
    if (!await spendCoins(item.price)) return false;
    await _grantConsumable(id);
    return true;
  }

  Future<void> _grantConsumable(String id) async {
    switch (id) {
      case 'extra_life':
        _extraLives = (_extraLives + 1).clamp(0, maxExtraLives);
        await _prefs?.setInt(_kExtraLives, _extraLives);
        break;
      case 'paper_bundle_20':
        _papers += 20;
        await _prefs?.setInt(_kPapers, _papers);
        break;
      case 'paper_bundle_50':
        _papers += 50;
        await _prefs?.setInt(_kPapers, _papers);
        break;
      case 'speed_boost_30s':
        _speedBoosts += 1;
        await _prefs?.setInt(_kSpeedBoosts, _speedBoosts);
        break;
      case 'shield_30s':
        _shields += 1;
        await _prefs?.setInt(_kShields, _shields);
        break;
    }
  }

  /// Award coins from a (mock) coin-pack IAP purchase.
  Future<bool> grantCoinPack(String id) async {
    final pack = coinPacks.firstWhere(
      (p) => p.id == id,
      orElse: () => const StoreItem(
        id: '',
        name: '',
        emoji: '',
        description: '',
        price: 0,
      ),
    );
    if (pack.id.isEmpty || pack.coinsAwarded == null) return false;
    await addCoins(pack.coinsAwarded!);
    return true;
  }

  // Legacy entry-point used by older callers; routes to power-ups.
  Future<bool> purchaseItem(String id) => purchasePowerUp(id);
}
