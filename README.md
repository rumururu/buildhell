# 🔥 지옥키우기 (BuildHell)

염라대왕의 신참 옥졸이 되어 죄인을 심판하고, 형벌을 집행하고, 거둔 영혼으로 지옥을 넓혀 가는
Flutter 방치형(클리커) 게임. Android / iOS / 웹.

## 게임 시스템

| 시스템 | 내용 |
|---|---|
| 형벌 집행 | 가마솥 터치로 영혼 획득. 5% 확률 치명타(x10) + 화면 흔들림 |
| 🔥 지옥 11곳 | 발설지옥 → … → 무간지옥. 초당 자동 생산, Lv.10/25/50/100… 마다 x2, x1/x10/x100/MAX 구매 |
| ⚖️ 죄인 심판 | 웃긴 죄목의 죄인이 20초마다 도착(최대 5명 대기). 맞는 지옥으로 보내면 포상 + 수감(해당 지옥 +2%/명) + 연속 보너스, 오판하면 탈옥 |
| 🏃 탈옥수 | 가끔 등장, 8초 안에 잡으면 포상금 또는 지옥불 폭주(20초 x7), 가끔 혼석 |
| 🔱 강화 5종 | 형벌 도구, 악마 교관, 저승사자, 염라전 증축, 저승 장부 |
| ☸️ 윤회 | 업보 총량 = ∛(평생 누적 영혼 ÷ 100만). 업보 1당 +10% 영구 |
| 💎 혼석 | 7일 출석, 일일 임무 3개, 업적 25개(각 +2% 영구), 상점(모래시계/기름/호송차/염라의 인장) |
| 📺 보상형 광고 | 혼석 +5(하루 5회), 30분 생산 x2, 오프라인·출석 보상 2배 (AdMob, 현재 테스트 ID) |
| 오프라인 | 꺼 둔 동안 생산량 50% (기본 4시간, 강화로 연장), 그동안 죄인도 도착 |
| 기타 | 효과음·진동(설정에서 끄기), 초보자 목표 안내, 기기 변경용 저장 코드, 자동 저장 |

## 실행

```bash
flutter pub get
flutter run            # 연결된 기기/에뮬레이터
flutter run -d chrome  # 웹 (디버그에서는 가짜 광고로 보상 흐름 테스트 가능)
flutter test           # 로직·위젯·밸런스 테스트
```

## 밸런스 조정

수치는 `lib/game/data.dart`(지옥·강화), `lib/game/meta.dart`(혼석·업적·상점),
`lib/game/game_state.dart` 상단 상수에 모여 있습니다. 바꾼 뒤 시뮬레이터로 진행 속도를 확인하세요.

```bash
flutter test test/balance --reporter expanded
```
가상의 플레이어(적극적/느긋)가 자동으로 플레이하며 지옥 개방 시각, 윤회 시각, 시간대별 생산량을 출력합니다.
현재 기준: 첫 윤회 약 40분, 이후 40~80분 간격 / 8시간 플레이로 지옥 8곳 / 무간지옥은 며칠짜리 목표.

## 효과음

`tool/gen_sfx.py`가 numpy로 합성해 `assets/sfx/`를 만듭니다 (`python3 tool/gen_sfx.py`).
더 좋은 효과음이 있으면 같은 파일명으로 교체하면 됩니다.

## 출시

[docs/RELEASE.md](docs/RELEASE.md) — AdMob ID 교체, 서명 키, 스토어 등록 절차
[docs/STORE_LISTING.md](docs/STORE_LISTING.md) — 스토어 설명 문구 초안
[docs/PRIVACY_POLICY.md](docs/PRIVACY_POLICY.md) — 개인정보처리방침 초안

## 구조

```
lib/
  main.dart                  앱 진입점
  config/ads_config.dart     광고 단위 ID (테스트/실제)
  game/
    data.dart                지옥·강화·칭호
    sins.dart                죄목 데이터, 죄인 생성
    meta.dart                출석·임무·업적·상점
    game_state.dart          게임 로직 전체 (생산, 심판, 윤회, 혼석, 오프라인, 직렬화)
    numbers.dart             한국식 큰 수 표기 (만/억/조/경…)
    save_service.dart        기기 저장
    save_code.dart           저장 코드 내보내기/불러오기
  services/
    sound_service.dart       효과음(audioplayers)·진동
    ad_service*.dart         보상형 광고 (모바일 AdMob / 웹 제외)
  ui/                        화면 (헤더, 가마솥, 심판석, 탭 6개)
test/                        로직·위젯 테스트, balance/ 시뮬레이터
tool/gen_sfx.py              효과음 합성
assets/                      효과음, 아이콘 원본
```
