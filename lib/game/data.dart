/// 지옥(생산 건물) 정의.
class HellDef {
  const HellDef({
    required this.name,
    required this.emoji,
    required this.description,
    required this.baseCost,
    required this.baseIncome,
  });

  final String name;
  final String emoji;
  final String description;
  final double baseCost;

  /// 레벨 1당 초당 영혼 생산량.
  final double baseIncome;
}

const double hellCostGrowth = 1.15;

/// 이 레벨에 도달할 때마다 해당 지옥의 생산량이 2배가 된다.
const List<int> hellMilestones = [10, 25, 50, 100, 150, 200, 300, 400, 500];

const List<HellDef> hells = [
  HellDef(
    name: '발설지옥',
    emoji: '👅',
    description: '거짓말한 죄인의 혀를 뽑아 쟁기로 간다',
    baseCost: 15,
    baseIncome: 0.1,
  ),
  HellDef(
    name: '독사지옥',
    emoji: '🐍',
    description: '독사 떼가 죄인을 휘감아 문다',
    baseCost: 150,
    baseIncome: 1,
  ),
  HellDef(
    name: '거해지옥',
    emoji: '🪚',
    description: '거대한 톱으로 죄인을 켠다',
    baseCost: 2500,
    baseIncome: 8,
  ),
  HellDef(
    name: '철상지옥',
    emoji: '🛏️',
    description: '시뻘겋게 달군 쇠침대에 눕힌다',
    baseCost: 50000,
    baseIncome: 50,
  ),
  HellDef(
    name: '풍도지옥',
    emoji: '🌪️',
    description: '칼바람이 끝없이 살을 벤다',
    baseCost: 1.2e6,
    baseIncome: 300,
  ),
  HellDef(
    name: '흑암지옥',
    emoji: '🌑',
    description: '빛 한 점 없는 어둠 속 공포',
    baseCost: 3.5e7,
    baseIncome: 1800,
  ),
  HellDef(
    name: '도산지옥',
    emoji: '🗡️',
    description: '칼날로 된 산을 맨발로 오른다',
    baseCost: 1.2e9,
    baseIncome: 11000,
  ),
  HellDef(
    name: '화탕지옥',
    emoji: '🍲',
    description: '펄펄 끓는 쇳물 가마솥에 담근다',
    baseCost: 5e10,
    baseIncome: 70000,
  ),
  HellDef(
    name: '한빙지옥',
    emoji: '🧊',
    description: '얼음 속에 영원히 얼려 둔다',
    baseCost: 2.5e12,
    baseIncome: 4.5e5,
  ),
  HellDef(
    name: '검수지옥',
    emoji: '🌲',
    description: '칼날 잎이 돋은 숲을 헤매게 한다',
    baseCost: 1.5e14,
    baseIncome: 3e6,
  ),
  HellDef(
    name: '무간지옥',
    emoji: '💀',
    description: '단 한 순간도 쉼 없는 고통',
    baseCost: 1e16,
    baseIncome: 2e7,
  ),
];

/// 강화(레벨형 업그레이드) 정의.
class UpgradeDef {
  const UpgradeDef({
    required this.id,
    required this.name,
    required this.emoji,
    required this.description,
    required this.baseCost,
    required this.growth,
    required this.maxLevel,
    this.keptOnRebirth = false,
  });

  final String id;
  final String name;
  final String emoji;
  final String description;
  final double baseCost;
  final double growth;
  final int maxLevel;
  final bool keptOnRebirth;

  double costAt(int level) => baseCost * _pow(growth, level);
}

double _pow(double b, int e) {
  var r = 1.0;
  for (var i = 0; i < e; i++) {
    r *= b;
  }
  return r;
}

class UpgradeIds {
  static const tap = 'tap';
  static const trainer = 'trainer';
  static const reaper = 'reaper';
  static const ledger = 'ledger';
  static const court = 'court';
}

const List<UpgradeDef> upgrades = [
  UpgradeDef(
    id: UpgradeIds.tap,
    name: '형벌 도구 강화',
    emoji: '🔱',
    description: '터치 1회당 영혼 +2, 초당 생산량의 0.1%를 터치에 추가',
    baseCost: 25,
    growth: 1.6,
    maxLevel: 100,
  ),
  UpgradeDef(
    id: UpgradeIds.trainer,
    name: '악마 교관 고용',
    emoji: '😈',
    description: '모든 지옥 생산량 +25%',
    baseCost: 1e5,
    growth: 10,
    maxLevel: 50,
  ),
  UpgradeDef(
    id: UpgradeIds.reaper,
    name: '저승사자 증원',
    emoji: '🕴️',
    description: '탈옥수가 더 자주 나타나고 포상 +20%',
    baseCost: 2000,
    growth: 5,
    maxLevel: 10,
  ),
  UpgradeDef(
    id: UpgradeIds.court,
    name: '염라전 증축',
    emoji: '⚖️',
    description: '죄인이 더 자주 도착하고 심판 포상 +15%',
    baseCost: 800,
    growth: 5,
    maxLevel: 10,
  ),
  UpgradeDef(
    id: UpgradeIds.ledger,
    name: '저승 장부',
    emoji: '📜',
    description: '오프라인 수익 최대 시간 +2시간 (윤회해도 유지)',
    baseCost: 20000,
    growth: 10,
    maxLevel: 6,
    keptOnRebirth: true,
  ),
];

UpgradeDef upgradeById(String id) => upgrades.firstWhere((u) => u.id == id);

/// 누적 영혼에 따른 칭호.
const List<(double, String)> ranks = [
  (0, '견습 옥졸'),
  (1e3, '옥졸'),
  (1e5, '옥졸 반장'),
  (1e7, '나찰'),
  (1e9, '야차 장군'),
  (1e12, '시왕의 심복'),
  (1e15, '지옥 시왕'),
  (1e18, '염라대왕'),
  (1e24, '삼계의 지배자'),
];
