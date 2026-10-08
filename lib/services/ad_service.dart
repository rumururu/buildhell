import 'package:flutter/foundation.dart';

import 'ad_service_stub.dart'
    if (dart.library.io) 'ad_service_admob.dart'
    as platform;

/// 보상형 광고. 광고를 끝까지 봤으면 true.
abstract class AdService extends ChangeNotifier {
  bool get isReady;
  Future<bool> showRewarded();

  /// 모바일이면 AdMob, 디버그 웹이면 가짜 광고, 그 외에는 광고 없음.
  static AdService create() {
    final isMobile =
        !kIsWeb &&
        (defaultTargetPlatform == TargetPlatform.android ||
            defaultTargetPlatform == TargetPlatform.iOS);
    if (isMobile) return platform.createAdMobService();
    if (kDebugMode) return FakeAdService();
    return NoAdService();
  }
}

class NoAdService extends AdService {
  @override
  bool get isReady => false;
  @override
  Future<bool> showRewarded() async => false;
}

/// 개발용: 1초 기다린 뒤 보상 지급.
class FakeAdService extends AdService {
  FakeAdService({this.delay = const Duration(seconds: 1)});
  final Duration delay;

  @override
  bool get isReady => true;

  @override
  Future<bool> showRewarded() async {
    await Future<void>.delayed(delay);
    return true;
  }
}
