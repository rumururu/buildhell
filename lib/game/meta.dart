/// 혼석(💎) 관련 데이터: 출석, 일일 임무, 업적, 상점.
library;

/// 7일 주기 출석 보상 (혼석).
const List<int> loginRewards = [10, 10, 15, 15, 20, 20, 50];

/// 일일 임무 종류.
class QuestDef {
  const QuestDef(this.id, this.title, this.target);
  final String id;
  final String title;
  final int target;
}

class QuestIds {
  static const tap = 'tap';
  static const judge = 'judge';
  static const build = 'build';
  static const catchEscapee = 'catch';
  static const upgrade = 'upgrade';
}

const List<QuestDef> questPool = [
  QuestDef(QuestIds.tap, '형벌 300회 집행', 300),
  QuestDef(QuestIds.judge, '죄인 10명 올바르게 심판', 10),
  QuestDef(QuestIds.build, '지옥 레벨 25 올리기', 25),
  QuestDef(QuestIds.catchEscapee, '탈옥수 3명 체포', 3),
  QuestDef(QuestIds.upgrade, '강화 5회', 5),
];

QuestDef questById(String id) => questPool.firstWhere((q) => q.id == id);

const int questReward = 10;
const int allQuestsBonus = 20;
const int dailyQuestCount = 3;

/// 광고 시청 보상.
const int adGemReward = 5;
const int adGemDailyLimit = 5;
const double adBoostSeconds = 30 * 60;
const double adBoostMultiplier = 2;

/// 업적 하나당 영구 생산량 보너스.
const double achievementBonus = 0.02;

/// 업적 판정용 수치 모음 (GameState가 채워서 넘긴다).
class AchievementStats {
  const AchievementStats({
    required this.totalTaps,
    required this.totalEarned,
    required this.maxHellsOpened,
    required this.correctJudgements,
    required this.bestStreak,
    required this.escapeesCaught,
    required this.rebirths,
    required this.crits,
  });

  final int totalTaps;
  final double totalEarned;
  final int maxHellsOpened;
  final int correctJudgements;
  final int bestStreak;
  final int escapeesCaught;
  final int rebirths;
  final int crits;
}

class AchievementDef {
  const AchievementDef(this.id, this.title, this.reward, this.check);
  final String id;
  final String title;

  /// 혼석 보상.
  final int reward;
  final bool Function(AchievementStats s) check;
}

final List<AchievementDef> achievements = [
  AchievementDef('tap100', '첫 출근: 형벌 100회', 5, (s) => s.totalTaps >= 100),
  AchievementDef('tap1k', '손목 단련: 형벌 1,000회', 10, (s) => s.totalTaps >= 1000),
  AchievementDef('tap10k', '쇠스랑의 달인: 형벌 1만 회', 20, (s) => s.totalTaps >= 10000),
  AchievementDef(
    'tap100k',
    '지옥의 손목: 형벌 10만 회',
    50,
    (s) => s.totalTaps >= 100000,
  ),
  AchievementDef('earn1e4', '영혼 1만 개 수확', 5, (s) => s.totalEarned >= 1e4),
  AchievementDef('earn1e6', '영혼 100만 개 수확', 10, (s) => s.totalEarned >= 1e6),
  AchievementDef('earn1e9', '영혼 10억 개 수확', 20, (s) => s.totalEarned >= 1e9),
  AchievementDef('earn1e12', '영혼 1조 개 수확', 30, (s) => s.totalEarned >= 1e12),
  AchievementDef('earn1e15', '영혼 1000조 개 수확', 50, (s) => s.totalEarned >= 1e15),
  AchievementDef('earn1e18', '영혼 100경 개 수확', 100, (s) => s.totalEarned >= 1e18),
  AchievementDef('hell3', '지옥 3곳 개방', 5, (s) => s.maxHellsOpened >= 3),
  AchievementDef('hell6', '지옥 6곳 개방', 15, (s) => s.maxHellsOpened >= 6),
  AchievementDef('hell9', '지옥 9곳 개방', 30, (s) => s.maxHellsOpened >= 9),
  AchievementDef('hell11', '무간지옥 개방', 100, (s) => s.maxHellsOpened >= 11),
  AchievementDef(
    'judge10',
    '신참 판관: 심판 10회',
    5,
    (s) => s.correctJudgements >= 10,
  ),
  AchievementDef(
    'judge100',
    '공정한 판관: 심판 100회',
    15,
    (s) => s.correctJudgements >= 100,
  ),
  AchievementDef(
    'judge1k',
    '명판관: 심판 1,000회',
    50,
    (s) => s.correctJudgements >= 1000,
  ),
  AchievementDef('streak10', '연속 정확 판결 10회', 10, (s) => s.bestStreak >= 10),
  AchievementDef('streak30', '연속 정확 판결 30회', 30, (s) => s.bestStreak >= 30),
  AchievementDef('catch10', '탈옥수 10명 체포', 10, (s) => s.escapeesCaught >= 10),
  AchievementDef(
    'catch100',
    '저승 수배 전문가: 탈옥수 100명',
    30,
    (s) => s.escapeesCaught >= 100,
  ),
  AchievementDef('crit100', '치명타 100회', 10, (s) => s.crits >= 100),
  AchievementDef('rebirth1', '첫 윤회', 20, (s) => s.rebirths >= 1),
  AchievementDef('rebirth5', '윤회 5회', 50, (s) => s.rebirths >= 5),
  AchievementDef('rebirth20', '윤회의 수레바퀴: 20회', 100, (s) => s.rebirths >= 20),
];

/// 혼석 상점 상품.
class ShopIds {
  static const timeSkip = 'timeSkip';
  static const frenzy = 'frenzy';
  static const sinners = 'sinners';
  static const seal = 'seal';
}

class ShopItemDef {
  const ShopItemDef({
    required this.id,
    required this.name,
    required this.emoji,
    required this.description,
    required this.baseCost,
    this.costGrowth = 1,
    this.maxLevel,
  });

  final String id;
  final String name;
  final String emoji;
  final String description;
  final int baseCost;
  final double costGrowth;

  /// 영구 상품이면 최대 레벨, 소모품이면 null.
  final int? maxLevel;
}

const List<ShopItemDef> shopItems = [
  ShopItemDef(
    id: ShopIds.timeSkip,
    name: '시간의 모래시계',
    emoji: '⏳',
    description: '1시간 치 생산량을 즉시 획득',
    baseCost: 30,
  ),
  ShopItemDef(
    id: ShopIds.frenzy,
    name: '지옥불 기름',
    emoji: '🛢️',
    description: '60초간 지옥불 폭주 (생산 x7)',
    baseCost: 20,
  ),
  ShopItemDef(
    id: ShopIds.sinners,
    name: '저승 호송차',
    emoji: '🚌',
    description: '심판 대기열을 죄인으로 가득 채움',
    baseCost: 10,
  ),
  ShopItemDef(
    id: ShopIds.seal,
    name: '염라의 인장',
    emoji: '🏮',
    description: '모든 생산량 영구 x1.5 (윤회해도 유지)',
    baseCost: 200,
    costGrowth: 3,
    maxLevel: 5,
  ),
];

ShopItemDef shopItemById(String id) => shopItems.firstWhere((s) => s.id == id);
