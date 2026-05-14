import 'package:shared_preferences/shared_preferences.dart';

class StoreItem {
  final String id;
  final String name;
  final String emoji;
  final String description;
  final int price;

  const StoreItem({
    required this.id,
    required this.name,
    required this.emoji,
    required this.description,
    required this.price,
  });
}

class StoreService {
  static final StoreService instance = StoreService._();
  StoreService._();

  static const String _kCoins = 'coins';
  static const String _kShield = 'item_shield';
  static const String _kSpeedBoost = 'item_speed_boost';
  static const String _kDoubleCoins = 'item_double_coins';
  static const String _kPaperBlitz = 'item_paper_blitz';
  static const String _kVipSkin = 'item_vip_skin';

  static const List<StoreItem> items = [
    StoreItem(
      id: 'shield',
      name: 'Shield Pack',
      emoji: '🛡️',
      description: '+1 life per game',
      price: 50,
    ),
    StoreItem(
      id: 'speed_boost',
      name: 'Speed Boost Start',
      emoji: '⚡',
      description: 'Start faster',
      price: 75,
    ),
    StoreItem(
      id: 'double_coins',
      name: 'Double Coins',
      emoji: '🪙×2',
      description: '2x coins per run',
      price: 100,
    ),
    StoreItem(
      id: 'paper_blitz',
      name: 'Paper Blitz',
      emoji: '📰',
      description: 'Special throw mode',
      price: 150,
    ),
    StoreItem(
      id: 'vip_skin',
      name: 'VIP Bike Skin',
      emoji: '⭐',
      description: 'Orange player tint',
      price: 200,
    ),
  ];

  SharedPreferences? _prefs;
  int _coins = 0;
  bool _shieldOwned = false;
  bool _speedBoostOwned = false;
  bool _doubleCoinsOwned = false;
  bool _paperBlitzOwned = false;
  bool _vipSkinOwned = false;

  Future<void> init() async {
    _prefs ??= await SharedPreferences.getInstance();
    _coins = _prefs!.getInt(_kCoins) ?? 0;
    _shieldOwned = _prefs!.getBool(_kShield) ?? false;
    _speedBoostOwned = _prefs!.getBool(_kSpeedBoost) ?? false;
    _doubleCoinsOwned = _prefs!.getBool(_kDoubleCoins) ?? false;
    _paperBlitzOwned = _prefs!.getBool(_kPaperBlitz) ?? false;
    _vipSkinOwned = _prefs!.getBool(_kVipSkin) ?? false;
  }

  int get coins => _coins;
  bool get shieldOwned => _shieldOwned;
  bool get speedBoostOwned => _speedBoostOwned;
  bool get doubleCoinsOwned => _doubleCoinsOwned;
  bool get paperBlitzOwned => _paperBlitzOwned;
  bool get vipSkinOwned => _vipSkinOwned;

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

  Future<bool> purchaseItem(String id) async {
    final item = items.firstWhere(
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
    if (isOwned(id)) return false;
    if (!await spendCoins(item.price)) return false;
    await _setOwned(id, true);
    return true;
  }

  Future<void> _setOwned(String id, bool owned) async {
    switch (id) {
      case 'shield':
        _shieldOwned = owned;
        await _prefs?.setBool(_kShield, owned);
        break;
      case 'speed_boost':
        _speedBoostOwned = owned;
        await _prefs?.setBool(_kSpeedBoost, owned);
        break;
      case 'double_coins':
        _doubleCoinsOwned = owned;
        await _prefs?.setBool(_kDoubleCoins, owned);
        break;
      case 'paper_blitz':
        _paperBlitzOwned = owned;
        await _prefs?.setBool(_kPaperBlitz, owned);
        break;
      case 'vip_skin':
        _vipSkinOwned = owned;
        await _prefs?.setBool(_kVipSkin, owned);
        break;
    }
  }
}
