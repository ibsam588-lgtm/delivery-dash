import 'package:shared_preferences/shared_preferences.dart';
import '../game/difficulty.dart';

/// A purchasable store item — either a consumable power-up or a coin pack.
/// The [price] is in coins (for power-ups) or 0 for IAP-priced items.
class StoreItem {
  final String id;
  final String name;
  final String emoji;
  final String description;
  final int price; // in coins (0 for IAP packs)
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

enum CosmeticCategory { outfit, bike }

class CosmeticItem {
  final String id;
  final CosmeticCategory category;
  final String name;
  final String preview;
  final String description;
  final int price;

  const CosmeticItem({
    required this.id,
    required this.category,
    required this.name,
    required this.preview,
    required this.description,
    required this.price,
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
  static const String _kOwnedCosmetics = 'owned_cosmetics';
  static const String _kOwnedAvatars = 'owned_avatars';
  static const String _kSelectedOutfit = 'selected_outfit';
  static const String _kSelectedBike = 'selected_bike';
  // Consumable inventory.
  static const String _kExtraLives = 'inv_extra_lives';
  static const String _kPapers = 'inv_papers';
  static const String _kSpeedBoosts = 'inv_speed_boosts';
  static const String _kShields = 'inv_shields';

  static const int maxExtraLives = 3;
  static const int boyAvatarPrice = 120;

  static const String defaultOutfit = 'outfit_classic';
  static const String defaultBike = 'bike_classic';

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

  static const List<CosmeticItem> cosmetics = [
    CosmeticItem(
      id: defaultOutfit,
      category: CosmeticCategory.outfit,
      name: 'CLASSIC COURIER',
      preview: 'BLUE',
      description: 'Clean paper-route jacket',
      price: 0,
    ),
    CosmeticItem(
      id: 'outfit_glam_pink',
      category: CosmeticCategory.outfit,
      name: 'GLAM PINK',
      preview: 'PINK',
      description: 'Bright doll-style courier fit',
      price: 180,
    ),
    CosmeticItem(
      id: 'outfit_sunset',
      category: CosmeticCategory.outfit,
      name: 'SUNSET POP',
      preview: 'GOLD',
      description: 'Warm orange jacket and trim',
      price: 150,
    ),
    CosmeticItem(
      id: 'outfit_neon',
      category: CosmeticCategory.outfit,
      name: 'NEON RIDER',
      preview: 'LIME',
      description: 'Streetwear with glowing green',
      price: 220,
    ),
    CosmeticItem(
      id: defaultBike,
      category: CosmeticCategory.bike,
      name: 'CLASSIC BIKE',
      preview: 'RED',
      description: 'Reliable red delivery bicycle',
      price: 0,
    ),
    CosmeticItem(
      id: 'bike_sky',
      category: CosmeticCategory.bike,
      name: 'SKY CRUISER',
      preview: 'CYAN',
      description: 'Sleek blue frame and white rims',
      price: 160,
    ),
    CosmeticItem(
      id: 'bike_neon',
      category: CosmeticCategory.bike,
      name: 'NEON COMET',
      preview: 'VOLT',
      description: 'Black frame with electric green',
      price: 240,
    ),
    CosmeticItem(
      id: 'bike_gold',
      category: CosmeticCategory.bike,
      name: 'GOLD DASH',
      preview: 'GOLD',
      description: 'Premium gold frame and chrome',
      price: 320,
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
  Set<String> _ownedCosmetics = {defaultOutfit, defaultBike};
  Set<CourierAvatar> _ownedAvatars = {CourierAvatar.girl};
  String _selectedOutfit = defaultOutfit;
  String _selectedBike = defaultBike;

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
    _ownedCosmetics =
        (_prefs!.getStringList(_kOwnedCosmetics) ?? const <String>[]).toSet()
          ..add(defaultOutfit)
          ..add(defaultBike);
    _ownedAvatars = (_prefs!.getStringList(_kOwnedAvatars) ?? const <String>[])
        .map((name) => CourierAvatar.values.firstWhere(
              (avatar) => avatar.name == name,
              orElse: () => CourierAvatar.girl,
            ))
        .toSet()
      ..add(CourierAvatar.girl);
    _selectedOutfit = _prefs!.getString(_kSelectedOutfit) ?? defaultOutfit;
    _selectedBike = _prefs!.getString(_kSelectedBike) ?? defaultBike;
    if (!_ownedCosmetics.contains(_selectedOutfit)) {
      _selectedOutfit = defaultOutfit;
    }
    if (!_ownedCosmetics.contains(_selectedBike)) {
      _selectedBike = defaultBike;
    }
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
  String get selectedOutfit => _selectedOutfit;
  String get selectedBike => _selectedBike;

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

  bool isCosmeticOwned(String id) => _ownedCosmetics.contains(id);
  bool isAvatarOwned(CourierAvatar avatar) => _ownedAvatars.contains(avatar);

  int avatarPrice(CourierAvatar avatar) {
    switch (avatar) {
      case CourierAvatar.boy:
        return boyAvatarPrice;
      case CourierAvatar.girl:
        return 0;
    }
  }

  bool isCosmeticEquipped(CosmeticItem item) {
    switch (item.category) {
      case CosmeticCategory.outfit:
        return _selectedOutfit == item.id;
      case CosmeticCategory.bike:
        return _selectedBike == item.id;
    }
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

  Future<bool> purchaseCosmetic(String id) async {
    final item = cosmetics.firstWhere(
      (i) => i.id == id,
      orElse: () => const CosmeticItem(
        id: '',
        category: CosmeticCategory.outfit,
        name: '',
        preview: '',
        description: '',
        price: 0,
      ),
    );
    if (item.id.isEmpty) return false;
    if (_ownedCosmetics.contains(id)) return equipCosmetic(id);
    if (!await spendCoins(item.price)) return false;
    _ownedCosmetics.add(id);
    await _prefs?.setStringList(_kOwnedCosmetics, _ownedCosmetics.toList());
    await equipCosmetic(id);
    return true;
  }

  Future<bool> purchaseAvatar(CourierAvatar avatar) async {
    if (_ownedAvatars.contains(avatar)) return true;
    final price = avatarPrice(avatar);
    if (!await spendCoins(price)) return false;
    _ownedAvatars.add(avatar);
    await _prefs?.setStringList(
      _kOwnedAvatars,
      _ownedAvatars.map((avatar) => avatar.name).toList(),
    );
    return true;
  }

  Future<bool> equipCosmetic(String id) async {
    if (!_ownedCosmetics.contains(id)) return false;
    final item = cosmetics.firstWhere(
      (i) => i.id == id,
      orElse: () => const CosmeticItem(
        id: '',
        category: CosmeticCategory.outfit,
        name: '',
        preview: '',
        description: '',
        price: 0,
      ),
    );
    if (item.id.isEmpty) return false;
    switch (item.category) {
      case CosmeticCategory.outfit:
        _selectedOutfit = id;
        await _prefs?.setString(_kSelectedOutfit, id);
        break;
      case CosmeticCategory.bike:
        _selectedBike = id;
        await _prefs?.setString(_kSelectedBike, id);
        break;
    }
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
