// 밸런스 시뮬레이터: 가상의 플레이어가 자동으로 플레이하며 진행 시간표를 출력한다.
//   flutter test test/balance --reporter expanded
// 수치를 바꾼 뒤 이 결과를 보고 템포를 조정한다.
import 'dart:math' as math;

import 'package:buildhell/game/data.dart';
import 'package:buildhell/game/game_state.dart';
import 'package:flutter_test/flutter_test.dart';

class _Clock {
  DateTime t = DateTime(2026, 1, 1, 9);
  DateTime call() => t;
}

class SimResult {
  final Map<int, double> hellOpenedAt = {};
  final List<(double, int)> rebirths = [];
  final Map<int, double> spsAtMinute = {};
  double? firstKarmaAt;
  final Map<int, double> earnedAtMinute = {};
}

/// [tapsPerSecond]: 활동 중 초당 터치, [minutes]: 총 플레이 시간.
SimResult simulate({
  required double tapsPerSecond,
  required int minutes,
  double judgeAccuracy = 0.9,
  double catchRate = 0.7,
  int seed = 1,
  bool allowRebirth = true,
}) {
  final clock = _Clock();
  final rng = math.Random(seed);
  final s = GameState(clock: clock.call, random: math.Random(seed));
  s.lastLoginDate = s.todayKey;
  final r = SimResult();
  var tapDebt = 0.0;
  Escapee? decided;

  void buyGreedy() {
    for (var guard = 0; guard < 500; guard++) {
      final sps = math.max(s.soulsPerSecond(includeTemporary: false), 0.1);
      // 후보: (회수 기간, 구매 함수)
      final options = <(double, bool Function())>[];
      for (var i = 0; i < hells.length; i++) {
        if (!s.isHellRevealed(i)) continue;
        final cost = s.hellCost(i, 1);
        final lv = s.hellLevels[i];
        final before = s.hellIncome(i, includeTemporary: false);
        final after = hells[i].baseIncome *
            (lv + 1) *
            GameState.milestoneMultiplier(lv + 1) *
            s.prisonerMultiplier(i) *
            s.permanentMultiplier;
        final gain = math.max(after - before, 1e-12);
        options.add((cost / gain, () {
          s.buyMode = BuyMode.one;
          return s.buyHell(i);
        }));
      }
      if (!s.isUpgradeMaxed(UpgradeIds.trainer)) {
        final lv = s.upgradeLevel(UpgradeIds.trainer);
        final gain = sps * 0.25 / (1 + 0.25 * lv);
        options.add((s.upgradeCost(UpgradeIds.trainer) / gain,
            () => s.buyUpgrade(UpgradeIds.trainer)));
      }
      for (final id in [UpgradeIds.tap, UpgradeIds.court, UpgradeIds.reaper]) {
        if (s.isUpgradeMaxed(id)) continue;
        // 보조 강화는 생산 40초분 이하일 때만
        final cost = s.upgradeCost(id);
        if (cost < sps * 40 || (id == UpgradeIds.tap && cost < 200)) {
          options.add((0, () => s.buyUpgrade(id)));
        }
      }
      options.sort((a, b) => a.$1.compareTo(b.$1));
      final best = options.first;
      if (!best.$2()) break; // 가장 좋은 것을 못 사면 모은다
    }
  }

  for (var sec = 0; sec < minutes * 60; sec++) {
    clock.t = clock.t.add(const Duration(seconds: 1));
    s.update();
    tapDebt += tapsPerSecond;
    while (tapDebt >= 1) {
      s.tap();
      tapDebt -= 1;
    }
    if (s.sinnerQueue.isNotEmpty) {
      final sinner = s.sinnerQueue.first;
      final correct = rng.nextDouble() < judgeAccuracy;
      final wrong = sinner.choices.firstWhere(
        (c) => c != sinner.hellIndex,
        orElse: () => sinner.hellIndex,
      );
      s.judge(correct ? sinner.hellIndex : wrong);
    }
    final e = s.escapee;
    if (e != null && !identical(e, decided)) {
      decided = e;
      if (rng.nextDouble() < catchRate) s.catchEscapee();
    }
    buyGreedy();
    for (var i = 0; i < hells.length; i++) {
      if (s.hellLevels[i] > 0) r.hellOpenedAt.putIfAbsent(i, () => sec / 60);
    }
    if (s.karmaOnRebirth >= 1) r.firstKarmaAt ??= sec / 60;
    // 업보가 현재 보유량 이상(최소 5) 쌓이면 윤회
    if (allowRebirth && s.karmaOnRebirth >= math.max(5, s.karma)) {
      final gain = s.karmaOnRebirth;
      s.rebirth();
      r.rebirths.add((sec / 60, gain));
    }
    if ((sec + 1) % 60 == 0) {
      r.spsAtMinute[(sec + 1) ~/ 60] = s.soulsPerSecond(includeTemporary: false);
      r.earnedAtMinute[(sec + 1) ~/ 60] = s.totalEarned;
    }
  }
  return r;
}

void _print(String name, SimResult r) {
  String m(double v) => '${v.toStringAsFixed(1)}분';
  final b = StringBuffer('\n=== $name ===\n');
  for (final e in r.hellOpenedAt.entries) {
    b.writeln('  ${hells[e.key].name.padRight(5)} 개방: ${m(e.value)}');
  }
  b.writeln('  첫 업보 가능: ${r.firstKarmaAt == null ? '없음' : m(r.firstKarmaAt!)}');
  for (final (t, g) in r.rebirths) {
    b.writeln('  윤회: ${m(t)} (+$g 업보)');
  }
  for (final min in [5, 15, 30, 60, 120, 240, 480]) {
    final v = r.spsAtMinute[min];
    if (v != null) {
      b.writeln('  $min분 시점 초당: ${v.toStringAsExponential(2)}  누적: ${r.earnedAtMinute[min]!.toStringAsExponential(2)}');
    }
  }
  // ignore: avoid_print
  print(b);
}

void main() {
  test('윤회 없이 (곡선 측정용)', () {
    _print('윤회 없음 4h', simulate(tapsPerSecond: 4, minutes: 240, allowRebirth: false));
  });

  test('적극적인 플레이어 (초당 4회 터치, 4시간)', () {
    final r = simulate(tapsPerSecond: 4, minutes: 240);
    _print('적극적 4h', r);
    expect(r.hellOpenedAt[0]!, lessThan(0.5), reason: '첫 지옥은 30초 안에');
    expect(r.hellOpenedAt[1]!, lessThan(3), reason: '두 번째 지옥은 3분 안에');
    expect(r.rebirths, isNotEmpty);
    expect(r.rebirths.first.$1, inInclusiveRange(25, 90),
        reason: '첫 윤회(업보 5)는 25~90분');
    // 윤회가 폭주하지 않는다: 4시간 동안 업보는 수백 단위 이하
    final totalKarma = r.rebirths.fold<int>(0, (a, b) => a + b.$2);
    expect(totalKarma, lessThan(1000));
    expect(r.hellOpenedAt.containsKey(10), isFalse, reason: '무간지옥은 4시간 안에 못 연다');
  });

  test('느긋한 플레이어 (초당 1회 터치, 8시간)', () {
    final r = simulate(tapsPerSecond: 1, minutes: 480, judgeAccuracy: 0.75, catchRate: 0.4);
    _print('느긋 8h', r);
    expect(r.hellOpenedAt[1]!, lessThan(6));
    expect(r.hellOpenedAt.length, greaterThanOrEqualTo(8),
        reason: '8시간이면 지옥 8곳 이상');
  });
}
