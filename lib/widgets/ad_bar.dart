import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
import 'package:flutter/foundation.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

/// AdMob banner advertisement bar displayed at the top of the app body.
/// Uses production Google AdMob IDs for live advertising on mobile platforms.
/// Shows fallback content on web platform.
/// The visibility is persisted in the `settings_box` under `showAdBar` (bool).
class AdBar extends StatefulWidget {
  const AdBar({super.key});

  @override
  State<AdBar> createState() => _AdBarState();
}

class _AdBarState extends State<AdBar> {
  late Box _box;
  bool _visible = true;
  BannerAd? _bannerAd;
  bool _isBannerLoaded = false;
  bool _isMobilePlatform = false;

  // Production AdMob IDs
  static const String _bannerAdUnitId = 'ca-app-pub-3737089294643612/5965493414'; // Production banner ID

  @override
  void initState() {
    super.initState();
    _box = Hive.box('settings_box');
    _visible = _box.get('showAdBar', defaultValue: true) as bool;
    _isMobilePlatform = !kIsWeb && (defaultTargetPlatform == TargetPlatform.android || defaultTargetPlatform == TargetPlatform.iOS);
    
    if (_visible && _isMobilePlatform) {
      _loadBannerAd();
    }
  }

  void _loadBannerAd() {
    if (!_isMobilePlatform) return;
    
    try {
      _bannerAd = BannerAd(
        adUnitId: _bannerAdUnitId,
        size: AdSize.banner,
        request: const AdRequest(),
        listener: BannerAdListener(
          onAdLoaded: (ad) {
            setState(() {
              _isBannerLoaded = true;
            });
          },
          onAdFailedToLoad: (ad, error) {
            print('Banner ad failed to load: $error');
            ad.dispose();
            setState(() {
              _isBannerLoaded = false;
            });
          },
        ),
      );
      _bannerAd?.load();
    } catch (e) {
      print('AdMob not available on this platform: $e');
      setState(() {
        _isBannerLoaded = false;
      });
    }
  }

  void _hide() {
    setState(() => _visible = false);
    _box.put('showAdBar', false);
    _bannerAd?.dispose();
  }

  @override
  void dispose() {
    _bannerAd?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_visible) return const SizedBox.shrink();

    return Container(
      color: Colors.grey[100],
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (_isBannerLoaded && _bannerAd != null)
            SizedBox(
              height: _bannerAd!.size.height.toDouble(),
              width: _bannerAd!.size.width.toDouble(),
              child: AdWidget(ad: _bannerAd!),
            )
          else
            Container(
              height: 50,
              width: double.infinity,
              color: Colors.blue[50],
              padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 8.0),
              child: Row(
                children: [
                  const Icon(Icons.info_outline, color: Colors.blue),
                  const SizedBox(width: 8),
                  const Expanded(
                    child: Text(
                      'AI Reminder - Smart task management with voice reminders',
                      style: TextStyle(color: Colors.blue),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.blue),
                    onPressed: _hide,
                    tooltip: 'Hide ad',
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}