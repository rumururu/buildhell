import 'dart:math' as math;

import 'package:flutter/foundation.dart';

import 'data.dart';

enum BuyMode { one, ten, hundred, max }

extension BuyModeLabel on BuyMode {
  String get label => switch (this) {
    BuyMode.one => 'x1',
    BuyMode.ten => 'x10',
    BuyMode.hundred => 'x100',
    BuyMode.max => 'MAX',
  };
}

/// 화면에 나타나 도망치는 탈옥수 (잡으면 보상).
class Escapee {
  Escapee({required this.x, required this.y, required this.life});

  /// 탭 영역 안의 상대 위치 (0~1).
  final double x;
  final double y;

  /// 남은 시간(초).
  double life;
}

/// 탈옥수를 잡았을 때의 결과.
class CatchResult {
  const CatchResult.souls(this.amount) : frenzySeconds = 0;
  const CatchResult.frenzy(this.frenzySeconds) : amount = 0;

  final double amount;
  final double frenzySeconds;

  bool get isFrenzy => frenzySeconds > 0;
}

/// 오프라인 정산 결과.
class OfflineReport {
  const OfflineReport(this.elapsed, this.gain);
  final Duration elapsed;
  final double gain;
}

class GameState extends ChangeNotifier {
  GameState({DateTime Function()? clock, math.Random? random})
    : _clock = clock ?? DateTime.now,
      _rng = random ?? math.Random(),
      hellLevels = List.filled(hells.length, 0),
      upgradeLevels = {for (final u in upgrades) u.id: 0} {
    _lastUpdate = _clock();
    escapeeCountdown = _nextEscapeeDelay();
  }

  static const double frenzyMultiplier = 7;
  static const double escapeeLifetime = 8;
  static const double offlineRate = 0.5;
  static const double baseOfflineHours = 4;

  /// 이 이상 시간이 비면 실시간 진행이 아니라 오프라인 정산으로 처리한다.
  static const Duration offlineThreshold = Duration(seconds: 10);

  final DateTime Function() _clock;
  final math.Random _rng;

  double souls = 0;
  double runEarned = 0;
  double totalEarned = 0;
  int karma = 0;
  int rebirths = 0;
  int totalTaps = 0;
  int escapeesCaught = 0;
  double playSeconds = 0;
  List<int> hellLevels;
  Map<String, int> upgradeLevels;
  BuyMode buyMode = BuyMode.one;

  double frenzyRemaining = 0;
  double escapeeCountdown = 60;
  Escapee? escapee;

  /// 앱을 다시 켰을 때 보여줄 오프라인 정산 내역 (UI가 소비 후 null로 만든다).
  OfflineReport? pendingOffline;

  late DateTime _lastUpdate;

  DateTime get now => _clock();

  // ---------------------------------------------------------------------------
  // 수치 계산
  // ---------------------------------------------------------------------------

  int upgradeLevel(String id) => upgradeLevels[id] ?? 0;

  double get karmaMultiplier => 1 + 0.1 * karma;

  bool get isFrenzy => frenzyRemaining > 0;

  double incomeMultiplier({bool includeFrenzy = true}) {
    var m = karmaMultiplier * (1 + 0.25 * upgradeLevel(UpgradeIds.trainer));
    if (includeFrenzy && isFrenzy) m *= frenzyMultiplier;
    return m;
  }

  static double milestoneMultiplier(int level) {
    var m = 1.0;
    for (final ms in hellMilestones) {
      if (level >= ms) m *= 2;
    }
    return m;
  }

  /// 다음 2배 마일스톤 레벨 (없으면 null).
  static int? nextMilestone(int level) {
    for (final ms in hellMilestones) {
      if (level < ms) return ms;
    }
    return null;
  }

  double hellIncome(int i, {bool includeFrenzy = true}) {
    final lv = hellLevels[i];
    if (lv == 0) return 0;
    return hells[i].baseIncome *
        lv *
        milestoneMultiplier(lv) *
        incomeMultiplier(includeFrenzy: includeFrenzy);
  }

  double soulsPerSecond({bool includeFrenzy = true}) {
    var total = 0.0;
    for (var i = 0; i < hells.length; i++) {
      total += hellIncome(i, includeFrenzy: includeFrenzy);
    }
    return total;
  }

  double get tapPower {
    final lv = upgradeLevel(UpgradeIds.tap);
    final base = (1 + 2 * lv) * incomeMultiplier();
    return base + soulsPerSecond() * 0.005 * lv;
  }

  /// 지옥 i를 지금 레벨에서 count개 더 살 때의 총 비용.
  double hellCost(int i, int count) {
    if (count <= 0) return 0;
    const r = hellCostGrowth;
    final first = hells[i].baseCost * math.pow(r, hellLevels[i]);
    return first * (math.pow(r, count) - 1) / (r - 1);
  }

  /// 현재 영혼으로 살 수 있는 최대 개수.
  int maxAffordable(int i) {
    const r = hellCostGrowth;
    final first = hells[i].baseCost * math.pow(r, hellLevels[i]);
    if (souls < first) return 0;
    var k = (math.log(souls * (r - 1) / first + 1) / math.log(r)).floor();
    // 부동소수점 오차 보정
    while (k > 0 && hellCost(i, k) > souls) {
      k--;
    }
    while (hellCost(i, k + 1) <= souls) {
      k++;
    }
    return k;
  }

  /// 현재 구매 모드에서 구매할 개수 (MAX인데 하나도 못 사면 1을 보여준다).
  int buyCount(int i) => switch (buyMode) {
    BuyMode.one => 1,
    BuyMode.ten => 10,
    BuyMode.hundred => 100,
    BuyMode.max => math.max(1, maxAffordable(i)),
  };

  /// 지옥이 목록에 공개되어 있는지 (첫 지옥 또는 이전 지옥을 1개 이상 보유).
  bool isHellRevealed(int i) => i == 0 || hellLevels[i - 1] > 0;

  bool canBuyHell(int i) =>
      isHellRevealed(i) && souls >= hellCost(i, buyCount(i));

  double upgradeCost(String id) => upgradeById(id).costAt(upgradeLevel(id));

  bool isUpgradeMaxed(String id) =>
      upgradeLevel(id) >= upgradeById(id).maxLevel;

  bool canBuyUpgrade(String id) =>
      !isUpgradeMaxed(id) && souls >= upgradeCost(id);

  double get maxOfflineHours =>
      baseOfflineHours + 2 * upgradeLevel(UpgradeIds.ledger);

  /// 지금 윤회하면 얻을 업보.
  int get karmaOnRebirth => math.sqrt(runEarned / 1e6).floor();

  String get rankTitle {
    var title = ranks.first.$2;
    for (final (threshold, name) in ranks) {
      if (totalEarned >= threshold) title = name;
    }
    return title;
  }

  // ---------------------------------------------------------------------------
  // 행동
  // ---------------------------------------------------------------------------

  void _earn(double amount) {
    souls += amount;
    runEarned += amount;
    totalEarned += amount;
  }

  /// 형벌 집행(터치). 얻은 영혼을 반환한다.
  double tap() {
    final gain = tapPower;
    _earn(gain);
    totalTaps++;
    notifyListeners();
    return gain;
  }

  bool buyHell(int i) {
    if (!canBuyHell(i)) return false;
    final count = buyCount(i);
    souls -= hellCost(i, count);
    hellLevels[i] += count;
    notifyListeners();
    return true;
  }

  bool buyUpgrade(String id) {
    if (!canBuyUpgrade(id)) return false;
    souls -= upgradeCost(id);
    upgradeLevels[id] = upgradeLevel(id) + 1;
    notifyListeners();
    return true;
  }

  void setBuyMode(BuyMode mode) {
    buyMode = mode;
    notifyListeners();
  }

  CatchResult? catchEscapee() {
    if (escapee == null) return null;
    escapee = null;
    escapeesCaught++;
    escapeeCountdown = _nextEscapeeDelay();
    final CatchResult result;
    if (_rng.nextBool()) {
      result = const CatchResult.frenzy(20);
      frenzyRemaining = math.max(frenzyRemaining, result.frenzySeconds);
    } else {
      final bonus = 1 + 0.2 * upgradeLevel(UpgradeIds.reaper);
      final amount =
          math.max(soulsPerSecond(includeFrenzy: false) * 90, tapPower * 30) *
          bonus;
      _earn(amount);
      result = CatchResult.souls(amount);
    }
    notifyListeners();
    return result;
  }

  /// 윤회: 업보를 얻고 진행을 초기화한다.
  bool rebirth() {
    final gain = karmaOnRebirth;
    if (gain < 1) return false;
    karma += gain;
    rebirths++;
    souls = 0;
    runEarned = 0;
    hellLevels = List.filled(hells.length, 0);
    upgradeLevels = {
      for (final u in upgrades) u.id: u.keptOnRebirth ? upgradeLevel(u.id) : 0,
    };
    frenzyRemaining = 0;
    escapee = null;
    escapeeCountdown = _nextEscapeeDelay();
    notifyListeners();
    return true;
  }

  // ---------------------------------------------------------------------------
  // 시간 진행
  // ---------------------------------------------------------------------------

  double _nextEscapeeDelay() {
    final speed = 1 - 0.07 * upgradeLevel(UpgradeIds.reaper);
    return (40 + _rng.nextDouble() * 50) * speed;
  }

  /// 실제 시계 기준으로 게임을 진행시킨다. 주기적으로 호출한다.
  void update() {
    final t = _clock();
    final elapsed = t.difference(_lastUpdate);
    _lastUpdate = t;
    if (elapsed.isNegative) return;
    if (elapsed > offlineThreshold) {
      _applyOffline(elapsed);
    } else {
      _simulate(elapsed.inMicroseconds / 1e6);
    }
    notifyListeners();
  }

  void _simulate(double dt) {
    if (dt <= 0) return;
    playSeconds += dt;

    // 폭주가 도중에 끝나는 경우를 정확히 나눠 계산한다.
    if (isFrenzy) {
      final frenzyDt = math.min(dt, frenzyRemaining);
      _earn(soulsPerSecond() * frenzyDt);
      frenzyRemaining -= frenzyDt;
      if (frenzyRemaining <= 1e-9) frenzyRemaining = 0;
      final rest = dt - frenzyDt;
      if (rest > 0) _earn(soulsPerSecond() * rest);
    } else {
      _earn(soulsPerSecond() * dt);
    }

    final e = escapee;
    if (e != null) {
      e.life -= dt;
      if (e.life <= 0) {
        escapee = null;
        escapeeCountdown = _nextEscapeeDelay();
      }
    } else if (hellLevels[0] > 0) {
      escapeeCountdown -= dt;
      if (escapeeCountdown <= 0) {
        escapee = Escapee(
          x: 0.15 + _rng.nextDouble() * 0.7,
          y: 0.15 + _rng.nextDouble() * 0.6,
          life: escapeeLifetime,
        );
      }
    }
  }

  void _applyOffline(Duration elapsed) {
    final maxDur = Duration(minutes: (maxOfflineHours * 60).round());
    final counted = elapsed > maxDur ? maxDur : elapsed;
    // 자리를 비운 사이 폭주와 탈옥수는 사라진다.
    frenzyRemaining = 0;
    if (escapee != null) {
      escapee = null;
      escapeeCountdown = _nextEscapeeDelay();
    }
    final gain =
        soulsPerSecond(includeFrenzy: false) *
        (counted.inSeconds) *
        offlineRate;
    if (gain > 0) {
      _earn(gain);
      pendingOffline = OfflineReport(elapsed, gain);
    }
  }

  // ---------------------------------------------------------------------------
  // 저장
  // ---------------------------------------------------------------------------

  Map<String, dynamic> toJson() => {
    'v': 1,
    'souls': souls,
    'runEarned': runEarned,
    'totalEarned': totalEarned,
    'karma': karma,
    'rebirths': rebirths,
    'totalTaps': totalTaps,
    'escapeesCaught': escapeesCaught,
    'playSeconds': playSeconds,
    'hellLevels': hellLevels,
    'upgradeLevels': upgradeLevels,
    'buyMode': buyMode.name,
    'frenzyRemaining': frenzyRemaining,
    'lastUpdate': _lastUpdate.millisecondsSinceEpoch,
  };

  /// 저장 데이터를 불러온다. 마지막 저장 이후 흐른 시간은 오프라인으로 정산된다.
  void loadJson(Map<String, dynamic> j) {
    double d(String k) => (j[k] as num?)?.toDouble() ?? 0;
    int n(String k) => (j[k] as num?)?.toInt() ?? 0;

    souls = d('souls');
    runEarned = d('runEarned');
    totalEarned = d('totalEarned');
    karma = n('karma');
    rebirths = n('rebirths');
    totalTaps = n('totalTaps');
    escapeesCaught = n('escapeesCaught');
    playSeconds = d('playSeconds');
    frenzyRemaining = d('frenzyRemaining');

    final levels = (j['hellLevels'] as List?) ?? const [];
    hellLevels = List.generate(
      hells.length,
      (i) => i < levels.length ? (levels[i] as num).toInt() : 0,
    );
    final ups = (j['upgradeLevels'] as Map?) ?? const {};
    upgradeLevels = {
      for (final u in upgrades) u.id: (ups[u.id] as num?)?.toInt() ?? 0,
    };
    buyMode = BuyMode.values.firstWhere(
      (m) => m.name == j['buyMode'],
      orElse: () => BuyMode.one,
    );

    final last = j['lastUpdate'] as num?;
    _lastUpdate = last != null
        ? DateTime.fromMillisecondsSinceEpoch(last.toInt())
        : _clock();
    escapee = null;
    escapeeCountdown = _nextEscapeeDelay();
    update();
  }

  /// 모든 기록 초기화.
  void hardReset() {
    souls = 0;
    runEarned = 0;
    totalEarned = 0;
    karma = 0;
    rebirths = 0;
    totalTaps = 0;
    escapeesCaught = 0;
    playSeconds = 0;
    hellLevels = List.filled(hells.length, 0);
    upgradeLevels = {for (final u in upgrades) u.id: 0};
    buyMode = BuyMode.one;
    frenzyRemaining = 0;
    escapee = null;
    escapeeCountdown = _nextEscapeeDelay();
    pendingOffline = null;
    _lastUpdate = _clock();
    notifyListeners();
  }
}
