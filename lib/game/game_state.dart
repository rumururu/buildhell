import 'dart:math' as math;

import 'package:flutter/foundation.dart';

import 'data.dart';
import 'meta.dart';
import 'sins.dart';

enum BuyMode { one, ten, hundred, max }

extension BuyModeLabel on BuyMode {
  String get label => switch (this) {
    BuyMode.one => 'x1',
    BuyMode.ten => 'x10',
    BuyMode.hundred => 'x100',
    BuyMode.max => 'MAX',
  };
}

/// UI가 효과음·알림을 띄우기 위해 꺼내 가는 사건들.
enum GameEvent { sinnerArrived, escapeeAppeared, achievementUnlocked }

/// 화면에 나타나 도망치는 탈옥수 (잡으면 보상).
class Escapee {
  Escapee({required this.x, required this.y, required this.life});

  /// 탭 영역 안의 상대 위치 (0~1).
  final double x;
  final double y;

  /// 남은 시간(초).
  double life;
}

class TapResult {
  const TapResult(this.amount, {this.critical = false});
  final double amount;
  final bool critical;
}

/// 탈옥수를 잡았을 때의 결과.
class CatchResult {
  const CatchResult({this.amount = 0, this.frenzySeconds = 0, this.gems = 0});

  final double amount;
  final double frenzySeconds;
  final int gems;

  bool get isFrenzy => frenzySeconds > 0;
}

/// 심판 결과.
class JudgeResult {
  const JudgeResult({
    required this.correct,
    required this.sinner,
    this.amount = 0,
    this.streak = 0,
  });

  final bool correct;
  final Sinner sinner;
  final double amount;
  final int streak;
}

/// 오프라인 정산 결과.
class OfflineReport {
  const OfflineReport(this.elapsed, this.gain);
  final Duration elapsed;
  final double gain;
}

/// 오늘의 임무 진행 상황.
class QuestProgress {
  QuestProgress(this.id, {this.progress = 0, this.claimed = false});

  final String id;
  int progress;
  bool claimed;

  QuestDef get def => questById(id);
  bool get done => progress >= def.target;

  Map<String, dynamic> toJson() => {
    'id': id,
    'progress': progress,
    'claimed': claimed,
  };
}

class GameState extends ChangeNotifier {
  GameState({DateTime Function()? clock, math.Random? random})
    : _clock = clock ?? DateTime.now,
      _rng = random ?? math.Random(),
      hellLevels = List.filled(hells.length, 0),
      prisoners = List.filled(hells.length, 0),
      upgradeLevels = {for (final u in upgrades) u.id: 0} {
    _lastUpdate = _clock();
    escapeeCountdown = _nextEscapeeDelay();
    sinnerCountdown = 5;
    _ensureDaily();
  }

  static const double frenzyMultiplier = 7;
  static const double escapeeLifetime = 8;
  static const double offlineRate = 0.5;
  static const double baseOfflineHours = 4;
  static const double critChance = 0.05;
  static const double critMultiplier = 10;
  static const int maxSinnerQueue = 5;
  static const double baseSinnerInterval = 20;

  /// 이 이상 시간이 비면 실시간 진행이 아니라 오프라인 정산으로 처리한다.
  static const Duration offlineThreshold = Duration(seconds: 10);

  final DateTime Function() _clock;
  final math.Random _rng;

  // --- 이번 생(윤회 시 초기화) -------------------------------------------------
  double souls = 0;
  double runEarned = 0;
  List<int> hellLevels;
  List<int> prisoners;
  Map<String, int> upgradeLevels;
  List<Sinner> sinnerQueue = [];

  // --- 영구 ----------------------------------------------------------------
  double totalEarned = 0;
  int karma = 0;
  int rebirths = 0;
  int gems = 0;
  int sealLevel = 0;
  int totalTaps = 0;
  int crits = 0;
  int escapeesCaught = 0;
  int correctJudgements = 0;
  int wrongJudgements = 0;
  int judgeStreak = 0;
  int bestStreak = 0;
  int maxHellsOpened = 0;
  double playSeconds = 0;
  Set<String> unlockedAchievements = {};

  // --- 출석·일일 ------------------------------------------------------------
  int loginDays = 0;
  String? lastLoginDate;
  String dailyDate = '';
  List<QuestProgress> dailyQuests = [];
  bool dailyBonusClaimed = false;
  int adGemsToday = 0;

  // --- 설정 ----------------------------------------------------------------
  bool soundOn = true;
  bool hapticsOn = true;
  BuyMode buyMode = BuyMode.one;

  // --- 일시 효과 -------------------------------------------------------------
  double frenzyRemaining = 0;
  double adBoostRemaining = 0;
  double escapeeCountdown = 60;
  double sinnerCountdown = 20;
  Escapee? escapee;

  /// 앱을 다시 켰을 때 보여줄 오프라인 정산 내역 (UI가 소비 후 null로 만든다).
  OfflineReport? pendingOffline;

  /// 새로 달성한 업적 (UI가 알림을 띄우고 비운다).
  final List<AchievementDef> pendingAchievements = [];

  final List<GameEvent> _events = [];

  late DateTime _lastUpdate;

  DateTime get now => _clock();

  /// 쌓인 사건을 꺼내고 비운다.
  List<GameEvent> takeEvents() {
    final e = List<GameEvent>.of(_events);
    _events.clear();
    return e;
  }

  // ---------------------------------------------------------------------------
  // 수치 계산
  // ---------------------------------------------------------------------------

  int upgradeLevel(String id) => upgradeLevels[id] ?? 0;

  double get karmaMultiplier => 1 + 0.1 * karma;

  double get sealMultiplier => math.pow(1.5, sealLevel).toDouble();

  double get achievementMultiplier =>
      1 + achievementBonus * unlockedAchievements.length;

  bool get isFrenzy => frenzyRemaining > 0;

  bool get isAdBoosted => adBoostRemaining > 0;

  /// 일시 효과(폭주, 광고 부스트)를 뺀 영구 배율.
  double get permanentMultiplier =>
      karmaMultiplier *
      (1 + 0.25 * upgradeLevel(UpgradeIds.trainer)) *
      sealMultiplier *
      achievementMultiplier;

  double incomeMultiplier({bool includeTemporary = true}) {
    var m = permanentMultiplier;
    if (includeTemporary) {
      if (isFrenzy) m *= frenzyMultiplier;
      if (isAdBoosted) m *= adBoostMultiplier;
    }
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

  double prisonerMultiplier(int i) => 1 + 0.02 * prisoners[i];

  double hellIncome(int i, {bool includeTemporary = true}) {
    final lv = hellLevels[i];
    if (lv == 0) return 0;
    return hells[i].baseIncome *
        lv *
        milestoneMultiplier(lv) *
        prisonerMultiplier(i) *
        incomeMultiplier(includeTemporary: includeTemporary);
  }

  double soulsPerSecond({bool includeTemporary = true}) {
    var total = 0.0;
    for (var i = 0; i < hells.length; i++) {
      total += hellIncome(i, includeTemporary: includeTemporary);
    }
    return total;
  }

  /// 치명타가 아닌 일반 터치 1회의 영혼.
  double get tapPower {
    final lv = upgradeLevel(UpgradeIds.tap);
    final base = (1 + 2 * lv) * incomeMultiplier();
    return base + soulsPerSecond() * 0.001 * lv;
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

  List<int> get openHells => [
    for (var i = 0; i < hells.length; i++)
      if (hellLevels[i] > 0) i,
  ];

  double upgradeCost(String id) => upgradeById(id).costAt(upgradeLevel(id));

  bool isUpgradeMaxed(String id) =>
      upgradeLevel(id) >= upgradeById(id).maxLevel;

  bool canBuyUpgrade(String id) =>
      !isUpgradeMaxed(id) && souls >= upgradeCost(id);

  double get maxOfflineHours =>
      baseOfflineHours + 2 * upgradeLevel(UpgradeIds.ledger);

  double get sinnerInterval =>
      baseSinnerInterval * (1 - 0.08 * upgradeLevel(UpgradeIds.court));

  static const double karmaUnit = 1e6;

  /// 평생 누적 영혼으로 얻을 수 있는 업보 총량: ∛(평생 누적 / 100만).
  /// 이미 받은 업보를 빼야 하므로, 업보를 두 배로 늘리려면 누적이 8배 필요하다.
  static int karmaForEarnings(double total) =>
      (math.pow(total / karmaUnit, 1 / 3) + 1e-9).floor();

  /// 업보 총량 [k]에 도달하는 데 필요한 평생 누적 영혼.
  static double earningsForKarma(int k) => karmaUnit * k * k * k;

  /// 지금 윤회하면 얻을 업보.
  int get karmaOnRebirth => math.max(0, karmaForEarnings(totalEarned) - karma);

  String get rankTitle {
    var title = ranks.first.$2;
    for (final (threshold, name) in ranks) {
      if (totalEarned >= threshold) title = name;
    }
    return title;
  }

  /// 초보자 안내용 다음 목표.
  String? get goalHint {
    if (hellLevels[0] == 0) {
      return '가마솥을 터치해 영혼 15개를 모으고, 발설지옥을 개방하세요';
    }
    if (correctJudgements == 0) {
      return sinnerQueue.isEmpty
          ? '곧 죄인이 도착합니다. 죄에 맞는 지옥으로 보내세요'
          : '아래 심판석에서 죄인을 알맞은 지옥으로 보내세요';
    }
    if (hellLevels[1] == 0) return '독사지옥을 개방하면 죄인 종류가 늘어납니다';
    if (upgradeLevel(UpgradeIds.tap) == 0) return '강화 탭에서 형벌 도구를 강화해 보세요';
    if (escapeesCaught == 0 && totalTaps > 50) {
      return '가끔 나타나는 🏃탈옥수를 터치해서 잡으세요';
    }
    if (rebirths == 0 && karmaOnRebirth >= 5) {
      return '윤회 탭에서 업보를 얻고 더 강해질 수 있습니다';
    }
    return null;
  }

  // ---------------------------------------------------------------------------
  // 행동
  // ---------------------------------------------------------------------------

  void _earn(double amount) {
    souls += amount;
    runEarned += amount;
    totalEarned += amount;
  }

  void _progress(String questId, [int n = 1]) {
    for (final q in dailyQuests) {
      if (q.id == questId && !q.claimed) q.progress += n;
    }
  }

  /// 형벌 집행(터치).
  TapResult tap() {
    final critical = _rng.nextDouble() < critChance;
    final gain = tapPower * (critical ? critMultiplier : 1);
    _earn(gain);
    totalTaps++;
    if (critical) crits++;
    _progress(QuestIds.tap);
    notifyListeners();
    return TapResult(gain, critical: critical);
  }

  bool buyHell(int i) {
    if (!canBuyHell(i)) return false;
    final count = buyCount(i);
    souls -= hellCost(i, count);
    hellLevels[i] += count;
    maxHellsOpened = math.max(maxHellsOpened, openHells.length);
    _progress(QuestIds.build, count);
    notifyListeners();
    return true;
  }

  bool buyUpgrade(String id) {
    if (!canBuyUpgrade(id)) return false;
    souls -= upgradeCost(id);
    upgradeLevels[id] = upgradeLevel(id) + 1;
    _progress(QuestIds.upgrade);
    notifyListeners();
    return true;
  }

  void setBuyMode(BuyMode mode) {
    buyMode = mode;
    notifyListeners();
  }

  void setSound(bool on) {
    soundOn = on;
    notifyListeners();
  }

  void setHaptics(bool on) {
    hapticsOn = on;
    notifyListeners();
  }

  void _spawnEscapee() {
    escapee = Escapee(
      x: 0.15 + _rng.nextDouble() * 0.7,
      y: 0.2 + _rng.nextDouble() * 0.55,
      life: escapeeLifetime,
    );
    _events.add(GameEvent.escapeeAppeared);
  }

  CatchResult? catchEscapee() {
    if (escapee == null) return null;
    escapee = null;
    escapeesCaught++;
    escapeeCountdown = _nextEscapeeDelay();
    _progress(QuestIds.catchEscapee);
    final gemDrop = _rng.nextDouble() < 0.15 ? 2 : 0;
    gems += gemDrop;
    final CatchResult result;
    if (_rng.nextBool()) {
      result = CatchResult(frenzySeconds: 20, gems: gemDrop);
      frenzyRemaining = math.max(frenzyRemaining, result.frenzySeconds);
    } else {
      final bonus = 1 + 0.2 * upgradeLevel(UpgradeIds.reaper);
      final amount =
          math.max(
            soulsPerSecond(includeTemporary: false) * 60,
            tapPower * 30,
          ) *
          bonus;
      _earn(amount);
      result = CatchResult(amount: amount, gems: gemDrop);
    }
    notifyListeners();
    return result;
  }

  /// 대기열 맨 앞 죄인을 [hellIndex] 지옥으로 보낸다.
  JudgeResult? judge(int hellIndex) {
    if (sinnerQueue.isEmpty) return null;
    final sinner = sinnerQueue.removeAt(0);
    final JudgeResult result;
    if (sinner.hellIndex == hellIndex) {
      judgeStreak++;
      bestStreak = math.max(bestStreak, judgeStreak);
      correctJudgements++;
      prisoners[hellIndex]++;
      final streakBonus = 1 + 0.05 * math.min(judgeStreak, 20);
      final courtBonus = 1 + 0.15 * upgradeLevel(UpgradeIds.court);
      final amount =
          math.max(
            soulsPerSecond(includeTemporary: false) * 10,
            tapPower * 10,
          ) *
          streakBonus *
          courtBonus;
      _earn(amount);
      _progress(QuestIds.judge);
      result = JudgeResult(
        correct: true,
        sinner: sinner,
        amount: amount,
        streak: judgeStreak,
      );
    } else {
      judgeStreak = 0;
      wrongJudgements++;
      // 억울한 죄인은 탈옥한다.
      if (escapee == null) _spawnEscapee();
      result = JudgeResult(correct: false, sinner: sinner);
    }
    notifyListeners();
    return result;
  }

  void _addSinner() {
    final open = openHells;
    if (open.isEmpty || sinnerQueue.length >= maxSinnerQueue) return;
    sinnerQueue.add(Sinner.random(_rng, open));
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
    prisoners = List.filled(hells.length, 0);
    sinnerQueue = [];
    upgradeLevels = {
      for (final u in upgrades) u.id: u.keptOnRebirth ? upgradeLevel(u.id) : 0,
    };
    frenzyRemaining = 0;
    escapee = null;
    escapeeCountdown = _nextEscapeeDelay();
    sinnerCountdown = 5;
    _checkAchievements();
    notifyListeners();
    return true;
  }

  // ---------------------------------------------------------------------------
  // 혼석: 출석, 임무, 상점, 광고
  // ---------------------------------------------------------------------------

  String _dateKey(DateTime t) =>
      '${t.year}-${t.month.toString().padLeft(2, '0')}-${t.day.toString().padLeft(2, '0')}';

  String get todayKey => _dateKey(_clock());

  void _ensureDaily() {
    final today = todayKey;
    if (dailyDate == today && dailyQuests.isNotEmpty) return;
    dailyDate = today;
    final rng = math.Random(today.hashCode);
    final pool = questPool.map((q) => q.id).toList()..shuffle(rng);
    dailyQuests = [
      for (final id in pool.take(dailyQuestCount)) QuestProgress(id),
    ];
    dailyBonusClaimed = false;
    adGemsToday = 0;
  }

  bool get canClaimLogin => lastLoginDate != todayKey;

  int get todayLoginReward => loginRewards[loginDays % loginRewards.length];

  int claimLogin({bool doubled = false}) {
    if (!canClaimLogin) return 0;
    final reward = todayLoginReward * (doubled ? 2 : 1);
    gems += reward;
    loginDays++;
    lastLoginDate = todayKey;
    notifyListeners();
    return reward;
  }

  bool claimQuest(int index) {
    final q = dailyQuests[index];
    if (!q.done || q.claimed) return false;
    q.claimed = true;
    gems += questReward;
    notifyListeners();
    return true;
  }

  bool get canClaimDailyBonus =>
      !dailyBonusClaimed && dailyQuests.every((q) => q.claimed);

  bool claimDailyBonus() {
    if (!canClaimDailyBonus) return false;
    dailyBonusClaimed = true;
    gems += allQuestsBonus;
    notifyListeners();
    return true;
  }

  int shopLevel(String id) => id == ShopIds.seal ? sealLevel : 0;

  int shopCost(String id) {
    final def = shopItemById(id);
    return (def.baseCost * math.pow(def.costGrowth, shopLevel(id))).round();
  }

  bool isShopMaxed(String id) {
    final max = shopItemById(id).maxLevel;
    return max != null && shopLevel(id) >= max;
  }

  bool canBuyShop(String id) {
    if (isShopMaxed(id) || gems < shopCost(id)) return false;
    if (id == ShopIds.sinners) {
      return openHells.isNotEmpty && sinnerQueue.length < maxSinnerQueue;
    }
    if (id == ShopIds.timeSkip) return openHells.isNotEmpty;
    return true;
  }

  /// 혼석 상품 구매. 시간의 모래시계는 얻은 영혼을 반환한다.
  double? buyShop(String id) {
    if (!canBuyShop(id)) return null;
    gems -= shopCost(id);
    double gained = 0;
    switch (id) {
      case ShopIds.timeSkip:
        gained = soulsPerSecond(includeTemporary: false) * 3600;
        _earn(gained);
      case ShopIds.frenzy:
        frenzyRemaining += 60;
      case ShopIds.sinners:
        while (sinnerQueue.length < maxSinnerQueue) {
          _addSinner();
        }
      case ShopIds.seal:
        sealLevel++;
    }
    notifyListeners();
    return gained;
  }

  bool get canWatchAdForGems => adGemsToday < adGemDailyLimit;

  void rewardAdGems() {
    if (!canWatchAdForGems) return;
    adGemsToday++;
    gems += adGemReward;
    notifyListeners();
  }

  void rewardAdBoost() {
    adBoostRemaining = adBoostSeconds;
    notifyListeners();
  }

  /// 오프라인 보상을 한 번 더 받는다 (광고 시청 보상).
  void rewardOfflineDouble(OfflineReport report) {
    _earn(report.gain);
    notifyListeners();
  }

  AchievementStats get achievementStats => AchievementStats(
    totalTaps: totalTaps,
    totalEarned: totalEarned,
    maxHellsOpened: maxHellsOpened,
    correctJudgements: correctJudgements,
    bestStreak: bestStreak,
    escapeesCaught: escapeesCaught,
    rebirths: rebirths,
    crits: crits,
  );

  void _checkAchievements() {
    final stats = achievementStats;
    for (final a in achievements) {
      if (unlockedAchievements.contains(a.id)) continue;
      if (a.check(stats)) {
        unlockedAchievements.add(a.id);
        gems += a.reward;
        pendingAchievements.add(a);
        _events.add(GameEvent.achievementUnlocked);
      }
    }
  }

  // ---------------------------------------------------------------------------
  // 시간 진행
  // ---------------------------------------------------------------------------

  double _nextEscapeeDelay() {
    final speed = 1 - 0.07 * upgradeLevel(UpgradeIds.reaper);
    return (60 + _rng.nextDouble() * 60) * speed;
  }

  /// 실제 시계 기준으로 게임을 진행시킨다. 주기적으로 호출한다.
  void update() {
    final t = _clock();
    final elapsed = t.difference(_lastUpdate);
    _lastUpdate = t;
    _ensureDaily();
    if (!elapsed.isNegative) {
      if (elapsed > offlineThreshold) {
        _applyOffline(elapsed);
      } else {
        _simulate(elapsed.inMicroseconds / 1e6);
      }
    }
    _checkAchievements();
    notifyListeners();
  }

  /// 일시 효과가 도중에 끝나는 경우를 구간별로 나눠 생산량을 계산한다.
  void _produce(double dt) {
    var left = dt;
    while (left > 1e-9) {
      final cuts = [
        left,
        if (isFrenzy) frenzyRemaining,
        if (isAdBoosted) adBoostRemaining,
      ];
      final step = cuts.reduce(math.min);
      _earn(soulsPerSecond() * step);
      if (isFrenzy) frenzyRemaining = _decay(frenzyRemaining, step);
      if (isAdBoosted) adBoostRemaining = _decay(adBoostRemaining, step);
      left -= step;
    }
  }

  static double _decay(double v, double dt) {
    final r = v - dt;
    return r <= 1e-9 ? 0 : r;
  }

  void _simulate(double dt) {
    if (dt <= 0) return;
    playSeconds += dt;
    _produce(dt);

    final e = escapee;
    if (e != null) {
      e.life -= dt;
      if (e.life <= 0) {
        escapee = null;
        escapeeCountdown = _nextEscapeeDelay();
      }
    } else if (hellLevels[0] > 0) {
      escapeeCountdown -= dt;
      if (escapeeCountdown <= 0) _spawnEscapee();
    }

    if (openHells.isNotEmpty) {
      if (sinnerQueue.length >= maxSinnerQueue) {
        sinnerCountdown = sinnerInterval;
      } else {
        sinnerCountdown -= dt;
        if (sinnerCountdown <= 0) {
          _addSinner();
          sinnerCountdown = sinnerInterval;
          _events.add(GameEvent.sinnerArrived);
        }
      }
    }
  }

  void _applyOffline(Duration elapsed) {
    final maxDur = Duration(minutes: (maxOfflineHours * 60).round());
    final counted = (elapsed > maxDur ? maxDur : elapsed).inSeconds.toDouble();
    // 자리를 비운 사이 폭주와 탈옥수는 사라진다. 광고 부스트는 남은 만큼 적용.
    frenzyRemaining = 0;
    if (escapee != null) {
      escapee = null;
      escapeeCountdown = _nextEscapeeDelay();
    }
    final base = soulsPerSecond(includeTemporary: false);
    final boosted = math.min(adBoostRemaining, counted);
    adBoostRemaining = _decay(adBoostRemaining, counted);
    final gain =
        base * (counted + boosted * (adBoostMultiplier - 1)) * offlineRate;
    if (openHells.isNotEmpty) {
      final arrivals = (counted / sinnerInterval).floor();
      for (
        var i = 0;
        i < arrivals && sinnerQueue.length < maxSinnerQueue;
        i++
      ) {
        _addSinner();
      }
    }
    if (gain > 0) {
      _earn(gain);
      pendingOffline = OfflineReport(elapsed, gain);
    }
  }

  // ---------------------------------------------------------------------------
  // 저장
  // ---------------------------------------------------------------------------

  Map<String, dynamic> toJson() => {
    'v': 2,
    'souls': souls,
    'runEarned': runEarned,
    'totalEarned': totalEarned,
    'karma': karma,
    'rebirths': rebirths,
    'gems': gems,
    'sealLevel': sealLevel,
    'totalTaps': totalTaps,
    'crits': crits,
    'escapeesCaught': escapeesCaught,
    'correctJudgements': correctJudgements,
    'wrongJudgements': wrongJudgements,
    'judgeStreak': judgeStreak,
    'bestStreak': bestStreak,
    'maxHellsOpened': maxHellsOpened,
    'playSeconds': playSeconds,
    'hellLevels': hellLevels,
    'prisoners': prisoners,
    'upgradeLevels': upgradeLevels,
    'sinnerQueue': [for (final s in sinnerQueue) s.toJson()],
    'sinnerCountdown': sinnerCountdown,
    'achievements': unlockedAchievements.toList(),
    'loginDays': loginDays,
    'lastLoginDate': lastLoginDate,
    'dailyDate': dailyDate,
    'dailyQuests': [for (final q in dailyQuests) q.toJson()],
    'dailyBonusClaimed': dailyBonusClaimed,
    'adGemsToday': adGemsToday,
    'soundOn': soundOn,
    'hapticsOn': hapticsOn,
    'buyMode': buyMode.name,
    'frenzyRemaining': frenzyRemaining,
    'adBoostRemaining': adBoostRemaining,
    'lastUpdate': _lastUpdate.millisecondsSinceEpoch,
  };

  /// 저장 데이터를 불러온다. 마지막 저장 이후 흐른 시간은 오프라인으로 정산된다.
  void loadJson(Map<String, dynamic> j) {
    double d(String k) => (j[k] as num?)?.toDouble() ?? 0;
    int n(String k) => (j[k] as num?)?.toInt() ?? 0;
    List<int> intList(String k) {
      final l = (j[k] as List?) ?? const [];
      return List.generate(
        hells.length,
        (i) => i < l.length ? (l[i] as num).toInt() : 0,
      );
    }

    souls = d('souls');
    runEarned = d('runEarned');
    totalEarned = d('totalEarned');
    karma = n('karma');
    rebirths = n('rebirths');
    gems = n('gems');
    sealLevel = n('sealLevel');
    totalTaps = n('totalTaps');
    crits = n('crits');
    escapeesCaught = n('escapeesCaught');
    correctJudgements = n('correctJudgements');
    wrongJudgements = n('wrongJudgements');
    judgeStreak = n('judgeStreak');
    bestStreak = n('bestStreak');
    playSeconds = d('playSeconds');
    frenzyRemaining = d('frenzyRemaining');
    adBoostRemaining = d('adBoostRemaining');

    hellLevels = intList('hellLevels');
    prisoners = intList('prisoners');
    maxHellsOpened = math.max(n('maxHellsOpened'), openHells.length);
    final ups = (j['upgradeLevels'] as Map?) ?? const {};
    upgradeLevels = {
      for (final u in upgrades) u.id: (ups[u.id] as num?)?.toInt() ?? 0,
    };
    sinnerQueue = [
      for (final s in (j['sinnerQueue'] as List?) ?? const [])
        ?Sinner.fromJson((s as Map).cast<String, dynamic>()),
    ];
    sinnerCountdown =
        (j['sinnerCountdown'] as num?)?.toDouble() ?? sinnerInterval;
    unlockedAchievements = {
      for (final a in (j['achievements'] as List?) ?? const []) a as String,
    };

    loginDays = n('loginDays');
    lastLoginDate = j['lastLoginDate'] as String?;
    dailyDate = j['dailyDate'] as String? ?? '';
    dailyQuests = [
      for (final q in (j['dailyQuests'] as List?) ?? const [])
        if (questPool.any((p) => p.id == (q as Map)['id']))
          QuestProgress(
            q['id'] as String,
            progress: (q['progress'] as num?)?.toInt() ?? 0,
            claimed: q['claimed'] as bool? ?? false,
          ),
    ];
    dailyBonusClaimed = j['dailyBonusClaimed'] as bool? ?? false;
    adGemsToday = n('adGemsToday');
    soundOn = j['soundOn'] as bool? ?? true;
    hapticsOn = j['hapticsOn'] as bool? ?? true;
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
    pendingAchievements.clear();
    _events.clear();
    update();
    // 불러오면서 이미 달성되어 있던 업적은 알림을 띄우지 않는다.
    pendingAchievements.clear();
    _events.clear();
  }

  /// 모든 기록 초기화 (설정은 유지).
  void hardReset() {
    final sound = soundOn;
    final haptics = hapticsOn;
    loadJson({'lastUpdate': _clock().millisecondsSinceEpoch});
    soundOn = sound;
    hapticsOn = haptics;
    sinnerCountdown = 5;
    pendingOffline = null;
    notifyListeners();
  }
}
