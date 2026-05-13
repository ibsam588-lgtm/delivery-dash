import 'dart:io' show Platform;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

class AdService {
  AdService._();
  static final AdService instance = AdService._();

  static const String _testBannerUnitId = 'ca-app-pub-3940256099942544/6300978111';

  bool _initialized = false;

  Future<void> initialize() async {
    if (_initialized) return;
    try {
      if (!kIsWeb && (Platform.isAndroid || Platform.isIOS)) {
        await MobileAds.instance.initialize();
        _initialized = true;
      }
    } catch (_) {
      // Silently ignore — ads are non-essential.
    }
  }

  Widget bannerAd() {
    return const _BannerAdView();
  }
}

class _BannerAdView extends StatefulWidget {
  const _BannerAdView();

  @override
  State<_BannerAdView> createState() => _BannerAdViewState();
}

class _BannerAdViewState extends State<_BannerAdView> {
  BannerAd? _ad;
  bool _loaded = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  void _load() {
    try {
      if (kIsWeb || !(Platform.isAndroid || Platform.isIOS)) return;
      final ad = BannerAd(
        adUnitId: AdService._testBannerUnitId,
        size: AdSize.banner,
        request: const AdRequest(),
        listener: BannerAdListener(
          onAdLoaded: (_) {
            if (mounted) setState(() => _loaded = true);
          },
          onAdFailedToLoad: (ad, _) {
            ad.dispose();
          },
        ),
      );
      ad.load();
      _ad = ad;
    } catch (_) {
      // No-op on failure.
    }
  }

  @override
  void dispose() {
    _ad?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 50,
      child: _loaded && _ad != null ? AdWidget(ad: _ad!) : const SizedBox.shrink(),
    );
  }
}
