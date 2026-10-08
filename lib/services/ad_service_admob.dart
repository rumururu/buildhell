import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

import '../config/ads_config.dart';
import 'ad_service.dart';

AdService createAdMobService() => AdMobService();

class AdMobService extends AdService {
  AdMobService() {
    MobileAds.instance.initialize().then((_) => _load()).catchError((Object e) {
      debugPrint('AdMob 초기화 실패: $e');
    });
  }

  RewardedAd? _ad;
  bool _loading = false;
  int _retry = 0;

  @override
  bool get isReady => _ad != null;

  void _load() {
    if (_loading || _ad != null) return;
    _loading = true;
    RewardedAd.load(
      adUnitId: AdsConfig.rewardedUnitId,
      request: const AdRequest(),
      rewardedAdLoadCallback: RewardedAdLoadCallback(
        onAdLoaded: (ad) {
          _loading = false;
          _retry = 0;
          _ad = ad;
          notifyListeners();
        },
        onAdFailedToLoad: (error) {
          _loading = false;
          _retry++;
          debugPrint('보상형 광고 로드 실패: $error');
          // 점점 길게 기다렸다가 다시 시도 (최대 2분).
          final wait = Duration(seconds: (5 * _retry).clamp(5, 120));
          Timer(wait, _load);
        },
      ),
    );
  }

  @override
  Future<bool> showRewarded() {
    final ad = _ad;
    if (ad == null) {
      _load();
      return Future.value(false);
    }
    _ad = null;
    notifyListeners();
    final done = Completer<bool>();
    var earned = false;
    ad.fullScreenContentCallback = FullScreenContentCallback(
      onAdDismissedFullScreenContent: (ad) {
        ad.dispose();
        if (!done.isCompleted) done.complete(earned);
        _load();
      },
      onAdFailedToShowFullScreenContent: (ad, error) {
        ad.dispose();
        if (!done.isCompleted) done.complete(false);
        _load();
      },
    );
    ad.show(onUserEarnedReward: (_, _) => earned = true);
    return done.future;
  }
}
