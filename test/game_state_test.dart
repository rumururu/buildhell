import 'dart:math' as math;

import 'package:buildhell/game/data.dart';
import 'package:buildhell/game/game_state.dart';
import 'package:buildhell/game/meta.dart';
import 'package:buildhell/game/save_code.dart';
import 'package:buildhell/game/numbers.dart';
import 'package:flutter_test/flutter_test.dart';

class FakeClock {
  DateTime t = DateTime(2026, 1, 1);
  DateTime call() => t;
  void advance(Duration d) => t = t.add(d);
}

void main() {
  late FakeClock clock;
  late GameState s;

  setUp(() {
    clock = FakeClock();
    s = GameState(clock: clock.call, random: math.Random(1));
  });

  group('formatNumber', () {
    test('작은 수', () {
      expect(formatNumber(0), '0');
      expect(formatNumber(0.15), '0.1');
      expect(formatNumber(15), '15');
      expect(formatNumber(9999), '9999');
    });
    test('한국식 단위', () {
      expect(formatNumber(10000), '1.00만');
      expect(formatNumber(123456), '12.3만');
      expect(formatNumber(1e8), '1.00억');
      expect(formatNumber(9999.9e8), '9999억');
      expect(formatNumber(1.5e12), '1.50조');
      expect(formatNumber(1e48), '1.00극');
      expect(formatNumber(1e52), '1.00e52');
    });
  });

  test('터치하면 영혼을 얻고, 치명타는 10배', () {
    var normal = 0, crit = 0;
    for (var i = 0; i < 2000; i++) {
      final r = s.tap();
      if (r.critical) {
        crit++;
        expect(r.amount, 10);
      } else {
        normal++;
        expect(r.amount, 1);
      }
    }
    expect(s.totalTaps, 2000);
    expect(s.crits, crit);
    expect(s.souls, normal + crit * 10);
    // 5% 근처
    expect(crit, inInclusiveRange(60, 140));
  });

  test('지옥 구매 비용과 생산', () {
    s.souls = 15;
    expect(s.buyHell(0), isTrue);
    expect(s.hellLevels[0], 1);
    expect(s.souls, closeTo(0, 1e-9));
    expect(s.soulsPerSecond(), closeTo(0.1, 1e-9));
    expect(s.hellCost(0, 1), closeTo(15 * 1.15, 1e-9));
    expect(s.buyHell(0), isFalse);
  });

  test('이전 지옥이 없으면 다음 지옥은 못 산다', () {
    s.souls = 1e9;
    expect(s.buyHell(1), isFalse);
    s.buyHell(0);
    expect(s.buyHell(1), isTrue);
  });

  test('MAX 구매는 살 수 있는 만큼 정확히 산다', () {
    s.souls = 1e6;
    s.setBuyMode(BuyMode.max);
    final k = s.maxAffordable(0);
    expect(s.hellCost(0, k), lessThanOrEqualTo(1e6));
    expect(s.hellCost(0, k + 1), greaterThan(1e6));
    s.buyHell(0);
    expect(s.hellLevels[0], k);
    expect(s.souls, greaterThanOrEqualTo(0));
  });

  test('일괄 구매 비용은 하나씩 산 합과 같다', () {
    var sum = 0.0;
    for (var i = 0; i < 10; i++) {
      sum += hells[0].baseCost * math.pow(hellCostGrowth, i);
    }
    expect(s.hellCost(0, 10), closeTo(sum, 1e-6));
  });

  test('마일스톤에서 생산량 2배', () {
    s.hellLevels[0] = 9;
    final before = s.hellIncome(0);
    s.hellLevels[0] = 10;
    expect(s.hellIncome(0), closeTo(before / 9 * 10 * 2, 1e-9));
  });

  test('시간이 지나면 생산된다', () {
    s.hellLevels[1] = 10; // 1 * 10 * 2(마일스톤) = 20/s
    s.hellLevels[0] = 1;
    clock.advance(const Duration(seconds: 2));
    s.update();
    // 업적(영혼 1만)은 아직 없으므로 배율 1
    expect(s.souls, closeTo((20 + 0.1) * 2, 1e-6));
  });

  test('오프라인 정산: 50%, 최대 시간 제한', () {
    s.hellLevels[1] = 1; // 1/s
    clock.advance(const Duration(hours: 10)); // 기본 최대 4시간
    s.update();
    expect(s.souls, closeTo(4 * 3600 * 0.5, 1e-6));
    expect(s.pendingOffline, isNotNull);
  });

  test('강화 구매', () {
    s.souls = 25;
    s.unlockedAchievements.clear();
    expect(s.buyUpgrade(UpgradeIds.tap), isTrue);
    expect(s.tapPower, 3);
    s.souls = 1e9;
    s.buyUpgrade(UpgradeIds.trainer);
    s.hellLevels[1] = 1;
    expect(s.soulsPerSecond(), closeTo(1.25, 1e-9));
  });

  test('탈옥수 출현, 체포, 도주', () {
    s.hellLevels[0] = 1;
    // 출현할 때까지 진행
    for (var i = 0; i < 2000 && s.escapee == null; i++) {
      clock.advance(const Duration(milliseconds: 100));
      s.update();
    }
    expect(s.escapee, isNotNull);
    final r = s.catchEscapee();
    expect(r, isNotNull);
    expect(s.escapee, isNull);
    expect(s.escapeesCaught, 1);
    expect(r!.isFrenzy ? s.isFrenzy : r.amount > 0, isTrue);

    // 다시 출현시키고 놓치기
    for (var i = 0; i < 2000 && s.escapee == null; i++) {
      clock.advance(const Duration(milliseconds: 100));
      s.update();
    }
    expect(s.escapee, isNotNull);
    for (var i = 0; i < 100; i++) {
      clock.advance(const Duration(milliseconds: 100));
      s.update();
    }
    expect(s.escapee, isNull);
  });

  test('폭주 중에는 7배 생산, 끝나면 원래대로', () {
    s.hellLevels[1] = 1;
    s.frenzyRemaining = 1;
    clock.advance(const Duration(seconds: 3));
    s.update();
    // 1초 x7 + 2초 x1
    expect(s.souls, closeTo(7 + 2, 1e-6));
    expect(s.isFrenzy, isFalse);
  });

  test('윤회', () {
    s.souls = 50;
    s.totalEarned = 8e6; // ∛8 = 2
    s.hellLevels[0] = 5;
    s.upgradeLevels[UpgradeIds.ledger] = 2;
    s.upgradeLevels[UpgradeIds.tap] = 3;
    expect(s.karmaOnRebirth, 2);
    expect(s.rebirth(), isTrue);
    expect(s.karma, 2);
    expect(s.souls, 0);
    expect(s.hellLevels.every((l) => l == 0), isTrue);
    expect(s.upgradeLevel(UpgradeIds.ledger), 2);
    expect(s.upgradeLevel(UpgradeIds.tap), 0);
    // 업보 2 (+20%) x 업적(첫 윤회, 영혼 1만, 100만 = +6%)
    expect(s.unlockedAchievements, containsAll(['rebirth1', 'earn1e4', 'earn1e6']));
    expect(s.tapPower, closeTo(1.2 * 1.06, 1e-9));
    expect(s.rebirth(), isFalse);
    // 업보 3이 되려면 평생 누적 27 x 100만
    s.totalEarned = 26.9e6;
    expect(s.karmaOnRebirth, 0);
    s.totalEarned = 27e6;
    expect(s.karmaOnRebirth, 1);
  });

  test('업보 공식 경계값', () {
    for (var k = 1; k <= 200; k++) {
      final need = GameState.earningsForKarma(k);
      expect(GameState.karmaForEarnings(need), k);
      expect(GameState.karmaForEarnings(need * 0.999), k - 1);
    }
  });

  test('저장 후 불러오기', () {
    s.souls = 1234;
    s.karma = 3;
    s.hellLevels[0] = 7;
    s.upgradeLevels[UpgradeIds.trainer] = 2;
    s.setBuyMode(BuyMode.ten);
    final json = s.toJson();

    final loaded = GameState(clock: clock.call, random: math.Random(2));
    loaded.loadJson(json);
    expect(loaded.souls, 1234);
    expect(loaded.karma, 3);
    expect(loaded.hellLevels[0], 7);
    expect(loaded.upgradeLevel(UpgradeIds.trainer), 2);
    expect(loaded.buyMode, BuyMode.ten);
  });

  test('불러올 때 흐른 시간은 오프라인 정산된다', () {
    s.hellLevels[1] = 1;
    final json = s.toJson();
    clock.advance(const Duration(hours: 1));
    final loaded = GameState(clock: clock.call);
    loaded.loadJson(json);
    expect(loaded.souls, closeTo(3600 * 0.5, 1e-6));
    expect(loaded.pendingOffline?.elapsed, const Duration(hours: 1));
  });

  test('칭호', () {
    expect(s.rankTitle, '견습 옥졸');
    s.totalEarned = 2e9;
    expect(s.rankTitle, '야차 장군');
  });

  group('죄인 심판', () {
    test('지옥이 열려야 죄인이 도착하고, 대기열은 최대 5명', () {
      for (var i = 0; i < 300; i++) {
        clock.advance(const Duration(milliseconds: 500));
        s.update();
      }
      expect(s.sinnerQueue, isEmpty);
      s.hellLevels[0] = 1;
      s.hellLevels[1] = 1;
      for (var i = 0; i < 600; i++) {
        clock.advance(const Duration(milliseconds: 500));
        s.update();
      }
      expect(s.sinnerQueue.length, GameState.maxSinnerQueue);
      for (final sinner in s.sinnerQueue) {
        expect([0, 1], contains(sinner.hellIndex));
        expect(sinner.choices, contains(sinner.hellIndex));
      }
    });

    test('정확한 판결: 보상, 수감, 연속 보너스', () {
      s.hellLevels[0] = 1;
      s.hellLevels[1] = 1;
      s.update();
      s.buyShop(ShopIds.sinners); // 혼석 없으면 실패
      expect(s.sinnerQueue, isEmpty);
      s.gems = 100;
      s.buyShop(ShopIds.sinners);
      expect(s.sinnerQueue.length, GameState.maxSinnerQueue);

      final first = s.sinnerQueue.first;
      final r1 = s.judge(first.hellIndex)!;
      expect(r1.correct, isTrue);
      expect(r1.amount, greaterThan(0));
      expect(s.prisoners[first.hellIndex], 1);
      expect(s.judgeStreak, 1);

      final second = s.sinnerQueue.first;
      final r2 = s.judge(second.hellIndex)!;
      expect(r2.streak, 2);
      expect(s.correctJudgements, 2);
      // 수감 죄인 1명당 해당 지옥 +2%
      expect(s.prisonerMultiplier(first.hellIndex), greaterThan(1));
    });

    test('오판하면 연속 끊기고 탈옥수가 나타난다', () {
      s.hellLevels[0] = 1;
      s.hellLevels[1] = 1;
      s.gems = 100;
      s.buyShop(ShopIds.sinners);
      s.judge(s.sinnerQueue.first.hellIndex);
      final sinner = s.sinnerQueue.first;
      final wrong = sinner.hellIndex == 0 ? 1 : 0;
      final r = s.judge(wrong)!;
      expect(r.correct, isFalse);
      expect(s.judgeStreak, 0);
      expect(s.wrongJudgements, 1);
      expect(s.escapee, isNotNull);
    });

    test('윤회하면 수감 죄인과 대기열 초기화', () {
      s.hellLevels[0] = 1;
      s.prisoners[0] = 10;
      s.gems = 100;
      s.buyShop(ShopIds.sinners);
      s.totalEarned = 1e6;
      expect(s.rebirth(), isTrue);
      expect(s.prisoners.every((p) => p == 0), isTrue);
      expect(s.sinnerQueue, isEmpty);
      // 혼석 유지 + 업적 보상(첫 윤회 20, 영혼 1만 5, 100만 10)
      expect(s.gems, 90 + 20 + 5 + 10);
    });

    test('오프라인 동안 대기열이 찬다', () {
      s.hellLevels[0] = 1;
      clock.advance(const Duration(minutes: 30));
      s.update();
      expect(s.sinnerQueue.length, GameState.maxSinnerQueue);
    });
  });

  group('혼석', () {
    test('출석은 하루 한 번, 7일 주기', () {
      expect(s.canClaimLogin, isTrue);
      expect(s.claimLogin(), loginRewards[0]);
      expect(s.canClaimLogin, isFalse);
      expect(s.claimLogin(), 0);
      clock.advance(const Duration(days: 1));
      s.update();
      expect(s.claimLogin(doubled: true), loginRewards[1] * 2);
      expect(s.gems, loginRewards[0] + loginRewards[1] * 2);
    });

    test('일일 임무: 진행, 수령, 보너스, 날짜가 바뀌면 새로 고침', () {
      expect(s.dailyQuests.length, dailyQuestCount);
      // 임무를 모두 강제로 완료
      for (final q in s.dailyQuests) {
        q.progress = q.def.target;
      }
      for (var i = 0; i < s.dailyQuests.length; i++) {
        expect(s.claimQuest(i), isTrue);
        expect(s.claimQuest(i), isFalse);
      }
      expect(s.claimDailyBonus(), isTrue);
      expect(s.gems, questReward * dailyQuestCount + allQuestsBonus);

      clock.advance(const Duration(days: 1));
      s.update();
      expect(s.dailyQuests.every((q) => !q.claimed && q.progress == 0), isTrue);
      expect(s.dailyBonusClaimed, isFalse);
    });

    test('터치가 형벌 임무 진행도에 반영된다', () {
      // 날짜를 바꿔가며 형벌 임무가 있는 날을 찾는다
      for (var d = 0; d < 30 && !s.dailyQuests.any((q) => q.id == QuestIds.tap); d++) {
        clock.advance(const Duration(days: 1));
        s.update();
      }
      final q = s.dailyQuests.firstWhere((q) => q.id == QuestIds.tap);
      for (var i = 0; i < 5; i++) {
        s.tap();
      }
      expect(q.progress, 5);
    });

    test('업적 달성 시 혼석과 영구 보너스, 알림은 한 번만', () {
      s.totalTaps = 99;
      s.update();
      expect(s.unlockedAchievements, isEmpty);
      s.tap();
      s.update();
      expect(s.unlockedAchievements, contains('tap100'));
      expect(s.gems, 5);
      expect(s.pendingAchievements.single.id, 'tap100');
      expect(s.takeEvents(), contains(GameEvent.achievementUnlocked));
      expect(s.achievementMultiplier, closeTo(1.02, 1e-9));
      s.update();
      expect(s.pendingAchievements.length, 1);
      expect(s.gems, 5);
    });

    test('상점: 모래시계, 폭주, 인장', () {
      s.hellLevels[1] = 1; // 1/s
      s.gems = 1000;
      expect(s.buyShop(ShopIds.timeSkip), closeTo(3600, 1e-6));
      expect(s.souls, closeTo(3600, 1e-6));
      s.buyShop(ShopIds.frenzy);
      expect(s.frenzyRemaining, 60);
      expect(s.shopCost(ShopIds.seal), 200);
      s.buyShop(ShopIds.seal);
      expect(s.sealLevel, 1);
      expect(s.shopCost(ShopIds.seal), 600);
      expect(s.sealMultiplier, 1.5);
      expect(s.gems, 1000 - 30 - 20 - 200);
    });

    test('광고 혼석은 하루 5번까지', () {
      for (var i = 0; i < 10; i++) {
        s.rewardAdGems();
      }
      expect(s.gems, adGemReward * adGemDailyLimit);
      expect(s.canWatchAdForGems, isFalse);
    });

    test('악마의 계약: 30분 x2, 오프라인에도 남은 만큼만 적용', () {
      s.hellLevels[1] = 1; // 1/s
      s.rewardAdBoost();
      expect(s.soulsPerSecond(), 2);
      clock.advance(const Duration(hours: 1));
      s.update();
      // 1시간 중 30분은 x2 → (3600 + 1800) * 0.5
      expect(s.souls, closeTo(5400 * 0.5, 1e-6));
      expect(s.isAdBoosted, isFalse);
    });
  });

  group('저장 코드', () {
    test('왕복', () {
      s.souls = 777;
      s.gems = 42;
      s.prisoners[0] = 3;
      final code = SaveCode.encode(s.toJson());
      expect(code, startsWith('BH1.'));
      final loaded = GameState(clock: clock.call);
      loaded.loadJson(SaveCode.decode(code)!);
      expect(loaded.souls, 777);
      expect(loaded.gems, 42);
      expect(loaded.prisoners[0], 3);
    });

    test('변조된 코드는 거부', () {
      final code = SaveCode.encode(s.toJson());
      final tampered = code.replaceRange(10, 11, code[10] == 'A' ? 'B' : 'A');
      expect(SaveCode.decode(tampered), isNull);
      expect(SaveCode.decode('엉터리'), isNull);
    });

    test('v1 저장 데이터도 불러온다', () {
      final loaded = GameState(clock: clock.call);
      loaded.loadJson({
        'v': 1,
        'souls': 10.0,
        'hellLevels': [3, 1],
        'upgradeLevels': {'tap': 2},
        'lastUpdate': clock.t.millisecondsSinceEpoch,
      });
      expect(loaded.hellLevels[0], 3);
      expect(loaded.maxHellsOpened, 2);
      expect(loaded.prisoners.every((p) => p == 0), isTrue);
      expect(loaded.gems, greaterThanOrEqualTo(0));
    });
  });
}
