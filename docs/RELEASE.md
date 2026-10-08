# 출시 체크리스트

## 1. 앱 식별자 정하기
- 현재 `com.buildhell.buildhell`. 출시 후에는 바꿀 수 없으니 지금 정하세요 (예: `com.본인도메인.hellidle`).
  - Android: `android/app/build.gradle.kts`의 `applicationId`, `namespace`
    (namespace를 바꾸면 `MainActivity.kt`의 package와 폴더 경로도 같이 변경)
  - iOS: Xcode에서 Runner > Signing & Capabilities > Bundle Identifier
- 버전: `pubspec.yaml`의 `version: 1.0.0+1` (출시할 때마다 `+숫자`를 올림)

## 2. AdMob (광고 수익)
1. https://admob.google.com 에서 앱 2개(Android, iOS) 등록 → **앱 ID** 발급
2. 각 앱에 **보상형 광고 단위** 생성 → **광고 단위 ID** 발급
3. 교체할 곳
   - Android 앱 ID: `android/app/src/main/AndroidManifest.xml`의 `com.google.android.gms.ads.APPLICATION_ID`
   - iOS 앱 ID: `ios/Runner/Info.plist`의 `GADApplicationIdentifier`
   - 광고 단위 ID: `lib/config/ads_config.dart`의 `_prodRewardedAndroid`, `_prodRewardedIos`
4. 지금 들어있는 값은 전부 Google **테스트 ID**입니다. 개발 중에는 디버그 빌드가 자동으로 테스트 ID를 씁니다.
   개발 중 실제 광고를 직접 누르면 AdMob 계정이 정지될 수 있습니다.
5. iOS: Info.plist에 `SKAdNetworkItems` 추가 (AdMob 문서의 목록 복사),
   맞춤 광고를 위해 ATT(`NSUserTrackingUsageDescription`)를 쓸지 결정
6. 유럽(EEA)·영국 사용자가 있으면 동의 메시지(UMP) 설정 필요 — AdMob 콘솔 > 개인정보 보호 및 메시지
7. 웹사이트가 있으면 `app-ads.txt` 게시 권장

## 3. Android 릴리스 서명
```bash
keytool -genkey -v -keystore ~/hell-upload-key.jks -keyalg RSA -keysize 2048 -validity 10000 -alias upload
```
`android/key.properties` 파일 생성 (git에 올라가지 않도록 .gitignore에 등록되어 있음):
```properties
storePassword=비밀번호
keyPassword=비밀번호
keyAlias=upload
storeFile=/절대경로/hell-upload-key.jks
```
키 파일과 비밀번호는 **잃어버리면 업데이트를 못 올리니** 안전한 곳에 백업하세요.

빌드:
```bash
flutter build appbundle --release   # build/app/outputs/bundle/release/app-release.aab
```

## 4. Google Play Console
- 개발자 계정 등록 (일회성 25달러)
- 개인 계정이면 **비공개 테스트(테스터 12명 이상, 14일 이상)** 를 거쳐야 프로덕션 출시 가능
  (Google 정책은 바뀔 수 있으니 콘솔 안내 확인)
- 스토어 등록정보: `docs/STORE_LISTING.md`
- 개인정보처리방침 URL: `docs/PRIVACY_POLICY.md`를 웹에 게시
- 데이터 보안 양식: "광고 ID 수집(AdMob)", "기기 정보" 등 AdMob 안내에 맞춰 작성
- 광고 포함: 예 / 콘텐츠 등급 설문 / 타겟 연령층(만 13세 이상 권장)

## 5. iOS (App Store)
- Apple Developer Program 가입 (연 99달러), Mac + Xcode 필요
- `cd ios && pod install` 후 Xcode에서 서명 설정 → Archive → 업로드
- 최소 iOS 13 (google_mobile_ads 요구사항)

## 6. 출시 전 직접 확인할 것 (이 저장소에서 검증하지 못한 부분)
- [ ] 실제 Android 기기에서 `flutter run` (광고 테스트 표시, 효과음, 진동)
- [ ] 실제 iPhone에서 실행
- [ ] 효과음 볼륨/어울림 (합성음이라 취향에 따라 교체 권장: `tool/gen_sfx.py` 또는 무료 효과음 파일)
- [ ] 앱을 끄고 몇 시간 뒤 켰을 때 오프라인 보상, 날짜가 바뀐 뒤 출석/임무 초기화
- [ ] 지인 테스트로 하루·일주일 뒤 재방문 여부 확인 → `test/balance` 시뮬레이터로 수치 조정
