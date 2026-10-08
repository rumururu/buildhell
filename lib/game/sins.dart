import 'dart:math' as math;

import 'data.dart';

/// 지옥별로 다루는 죄의 종류와 죄목 예시. 인덱스는 [hells]와 같다.
const List<(String, List<String>)> hellSins = [
  (
    '말로 지은 죄',
    [
      '평생 거짓말 3,021회',
      '악플 1만 2천 개 작성',
      '뒷담화로 친구 7명 손절시킴',
      '"5분 뒤 도착" 하고 40분 지각',
      '맛집 리뷰 조작',
    ],
  ),
  (
    '질투와 배신',
    [
      '친구 연인을 가로챔',
      '동업자 몰래 회삿돈 들고 잠적',
      '단톡방 몰래 캡처해서 유포',
      '동료 성과를 자기 것으로 보고',
      '남의 행복에 배 아파 잠 못 이룸 9,000일',
    ],
  ),
  (
    '탐욕과 도둑질',
    [
      '회사 탕비실 간식 상습 싹쓸이',
      '편의점 1+1 하나 더 슬쩍',
      '남의 와이파이 20년 무단 사용',
      '빌린 돈 "다음 달에 줄게" 18년째',
      '공용 우산 영구 대여',
    ],
  ),
  (
    '게으름',
    [
      '조별과제 무임승차 12회',
      '설거지 미루기 평생 기록 보유',
      '회의 중 몰래 게임',
      '"내일부터 운동" 선언 4,380회',
      '알람 끄고 다시 자기 3만 번',
    ],
  ),
  (
    '무례와 민폐',
    [
      '주차장 두 칸 차지 상습범',
      '새치기 장인',
      '영화관 앞좌석 발차기',
      '엘리베이터 문 닫힘 버튼 연타',
      '새벽 3시 층간소음',
    ],
  ),
  (
    '몰래 한 짓',
    [
      '남의 넷플릭스 계정 무단 사용',
      '냉장고 속 동생 푸딩 몰래 먹기',
      '시험 컨닝 상습범',
      '남의 택배 먼저 뜯어봄',
      '지인 사진 몰래 박제',
    ],
  ),
  (
    '폭력',
    ['약한 사람만 골라 괴롭힘', '길고양이 걷어참', '운전 중 보복운전', '술 마시고 기물 파손', '게임 지면 키보드 내려치기'],
  ),
  (
    '사기',
    [
      '보이스피싱 총책',
      '다단계로 친척 전부 끌어들임',
      '"무조건 오른다" 코인 리딩방 운영',
      '중고거래 벽돌 배송',
      '가짜 명품 판매',
    ],
  ),
  (
    '무정함',
    [
      '부모님 전화 3년째 안 받음',
      '친구 생일 10년 연속 까먹음',
      '단톡방 읽씹 1,204회',
      '아픈 친구에게 "그래서?"',
      '키우던 강아지 버림',
    ],
  ),
  (
    '갑질',
    [
      '알바생에게 반말과 막말',
      '"내가 누군지 알아?" 시전',
      '배달 리뷰로 사장님 협박',
      '부하 직원 주말 호출 상습',
      '경비원에게 갑질',
    ],
  ),
  (
    '극악무도',
    [
      '영화 개봉 첫날 결말 스포일러 유포',
      '민트초코 강제로 먹임',
      '남의 세이브 파일 삭제',
      '퇴근 5분 전 업무 지시',
      '마지막 남은 치킨 다리 독차지',
    ],
  ),
];

const List<String> _surnames = [
  '김',
  '이',
  '박',
  '최',
  '정',
  '강',
  '조',
  '윤',
  '장',
  '임',
  '한',
  '오',
  '서',
  '신',
];
const List<String> _givenFirst = [
  '민',
  '서',
  '지',
  '현',
  '수',
  '영',
  '준',
  '하',
  '도',
  '은',
];
const List<String> _givenLast = [
  '수',
  '준',
  '희',
  '호',
  '우',
  '아',
  '진',
  '빈',
  '석',
  '연',
];

/// 심판을 기다리는 죄인.
class Sinner {
  const Sinner({
    required this.name,
    required this.age,
    required this.sin,
    required this.hellIndex,
    required this.choices,
  });

  final String name;
  final int age;
  final String sin;

  /// 보내야 하는 정답 지옥.
  final int hellIndex;

  /// 화면에 보여줄 선택지 (정답 포함, 섞여 있음).
  final List<int> choices;

  String get category => hellSins[hellIndex].$1;

  Map<String, dynamic> toJson() => {
    'name': name,
    'age': age,
    'sin': sin,
    'hell': hellIndex,
    'choices': choices,
  };

  static Sinner? fromJson(Map<String, dynamic> j) {
    final hell = (j['hell'] as num?)?.toInt();
    if (hell == null || hell < 0 || hell >= hells.length) return null;
    final choices = ((j['choices'] as List?) ?? const [])
        .map((e) => (e as num).toInt())
        .where((c) => c >= 0 && c < hells.length)
        .toList();
    if (!choices.contains(hell)) choices.add(hell);
    return Sinner(
      name: j['name'] as String? ?? '무명씨',
      age: (j['age'] as num?)?.toInt() ?? 40,
      sin: j['sin'] as String? ?? '알 수 없는 죄',
      hellIndex: hell,
      choices: choices,
    );
  }

  /// 개방된 지옥 중에서 죄인 한 명을 만든다.
  static Sinner random(math.Random rng, List<int> openHells) {
    assert(openHells.isNotEmpty);
    final hell = openHells[rng.nextInt(openHells.length)];
    final sins = hellSins[hell].$2;
    final others = openHells.where((h) => h != hell).toList()..shuffle(rng);
    final choices = [hell, ...others.take(2)]..shuffle(rng);
    final name =
        '${_surnames[rng.nextInt(_surnames.length)]}'
        '${_givenFirst[rng.nextInt(_givenFirst.length)]}'
        '${_givenLast[rng.nextInt(_givenLast.length)]}';
    return Sinner(
      name: name,
      age: 20 + rng.nextInt(70),
      sin: sins[rng.nextInt(sins.length)],
      hellIndex: hell,
      choices: choices,
    );
  }
}
