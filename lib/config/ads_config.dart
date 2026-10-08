import 'package:flutter/foundation.dart';

/// AdMob 광고 단위 ID.
///
/// 지금은 Google 공식 **테스트 ID**다. 출시 전에 AdMob 콘솔에서 만든 실제 ID로
/// 바꿔야 수익이 난다. 앱 ID는 AndroidManifest.xml / ios/Runner/Info.plist 에 있다.
/// (개발 중 실제 ID로 자기 광고를 누르면 계정이 정지될 수 있으니 디버그에서는 테스트 ID 유지)
class AdsConfig {
  static const _testRewardedAndroid = 'ca-app-pub-3940256099942544/5224354917';
  static const _testRewardedIos = 'ca-app-pub-3940256099942544/1712485313';

  // TODO(출시): 실제 광고 단위 ID 입력
  static const _prodRewardedAndroid = _testRewardedAndroid;
  static const _prodRewardedIos = _testRewardedIos;

  static String get rewardedUnitId {
    final ios = defaultTargetPlatform == TargetPlatform.iOS;
    if (kReleaseMode) return ios ? _prodRewardedIos : _prodRewardedAndroid;
    return ios ? _testRewardedIos : _testRewardedAndroid;
  }
}
