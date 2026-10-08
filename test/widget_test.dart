import 'package:buildhell/game/game_state.dart';
import 'package:buildhell/main.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('터치로 영혼을 모으고 첫 지옥을 개방한다', (tester) async {
    final state = GameState();
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
    // 다음 지옥이 드러난다
    expect(find.text('독사지옥  Lv.0'), findsOneWidget);

    // 남은 애니메이션 정리
    await tester.pump(const Duration(seconds: 1));
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('탈옥수를 잡으면 보상 메시지가 뜬다', (tester) async {
    final state = GameState();
    state.hellLevels[0] = 1;
    state.escapee = Escapee(x: 0.5, y: 0.3, life: 8);
    await tester.pumpWidget(BuildHellApp(state: state));
    await tester.pump();

    await tester.tap(find.byKey(const Key('escapee')));
    await tester.pump();
    expect(state.escapeesCaught, 1);
    expect(state.totalTaps, 0, reason: '탈옥수 터치는 형벌 터치로 세지 않는다');
    expect(find.byType(SnackBar), findsOneWidget);

    await tester.pump(const Duration(seconds: 5));
    await tester.pumpWidget(const SizedBox());
  });
}
