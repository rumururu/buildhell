import 'dart:math' as math;

import 'package:buildhell/game/data.dart';
import 'package:buildhell/game/game_state.dart';
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

  test('터치하면 영혼을 얻는다', () {
    expect(s.tap(), 1);
    expect(s.souls, 1);
    expect(s.totalTaps, 1);
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
    s.runEarned = 4e6; // sqrt(4) = 2
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
    expect(s.tapPower, closeTo(1.2, 1e-9));
    expect(s.rebirth(), isFalse);
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
}
