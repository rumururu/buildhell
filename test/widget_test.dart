import 'package:buildhell/game/game_state.dart';
import 'package:buildhell/main.dart';
import 'package:buildhell/services/ad_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

GameState _fresh() {
  final s = GameState();
  s.lastLoginDate = s.todayKey; // 출석 대화상자 생략
  return s;
}

Future<void> _finish(WidgetTester tester) async {
  await tester.pump(const Duration(seconds: 3));
  await tester.pumpWidget(const SizedBox());
  await tester.pump(const Duration(seconds: 1));
}

void main() {
  testWidgets('터치로 영혼을 모으고 첫 지옥을 개방한다', (tester) async {
    final state = _fresh();
    await tester.pumpWidget(BuildHellApp(state: state));
    await tester.pump();

    expect(find.text('👻 0'), findsOneWidget);
    expect(find.text('발설지옥  Lv.0'), findsOneWidget);

    for (var i = 0; i < 15; i++) {
      await tester.tap(find.byKey(const Key('tapArea')));
      await tester.pump(const Duration(milliseconds: 50));
    }
    expect(state.souls, greaterThanOrEqualTo(15));

    await tester.tap(find.byKey(const Key('buyHell0')));
    await tester.pump();
    expect(state.hellLevels[0], 1);
    expect(find.text('발설지옥  Lv.1'), findsOneWidget);
    expect(find.text('독사지옥  Lv.0'), findsOneWidget);
    await _finish(tester);
  });

  testWidgets('심판석에서 정답 지옥을 누르면 보상', (tester) async {
    final state = _fresh();
    state.hellLevels[0] = 1;
    state.hellLevels[1] = 1;
    state.gems = 10;
    state.buyShop('sinners');
    await tester.pumpWidget(BuildHellApp(state: state));
    await tester.pump();

    expect(find.byKey(const Key('judgePanel')), findsOneWidget);
    final sinner = state.sinnerQueue.first;
    expect(find.textContaining(sinner.sin), findsOneWidget);
    await tester.tap(find.byKey(Key('judge${sinner.hellIndex}')));
    await tester.pump();
    expect(state.correctJudgements, 1);
    expect(state.prisoners[sinner.hellIndex], 1);
    expect(find.textContaining('정확한 판결'), findsOneWidget);
    await _finish(tester);
  });

  testWidgets('탈옥수를 잡으면 알림, 형벌 터치로 세지 않음', (tester) async {
    final state = _fresh();
    state.hellLevels[0] = 1;
    state.escapee = Escapee(x: 0.5, y: 0.5, life: 8);
    await tester.pumpWidget(BuildHellApp(state: state));
    await tester.pump();

    await tester.tap(find.byKey(const Key('escapee')));
    await tester.pump();
    expect(state.escapeesCaught, 1);
    expect(state.totalTaps, 0);
    expect(find.byKey(const Key('toast')), findsOneWidget);
    await _finish(tester);
  });

  testWidgets('첫 실행 시 출석 대화상자, 받으면 혼석 증가', (tester) async {
    final state = GameState();
    await tester.pumpWidget(BuildHellApp(state: state));
    await tester.pump();
    await tester.pump();
    expect(find.text('📅 출석 1일차'), findsOneWidget);
    await tester.tap(find.byKey(const Key('loginClaim')));
    await tester.pump(const Duration(milliseconds: 500));
    expect(state.gems, 10);
    expect(find.text('📅 출석 1일차'), findsNothing);
    await _finish(tester);
  });

  testWidgets('상점에서 광고 보고 혼석 받기 (가짜 광고)', (tester) async {
    final state = _fresh();
    await tester.pumpWidget(
      BuildHellApp(
        state: state,
        ads: FakeAdService(delay: const Duration(milliseconds: 100)),
      ),
    );
    await tester.pump();
    await tester.tap(find.text('💎 상점'));
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 60));
    }
    await tester.tap(find.byKey(const Key('adGems')));
    await tester.pump(const Duration(milliseconds: 200));
    expect(state.gems, 5);
    expect(state.adGemsToday, 1);
    await _finish(tester);
  });
}
