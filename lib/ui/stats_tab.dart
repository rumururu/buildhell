import 'package:flutter/material.dart';

import '../game/data.dart';
import '../game/game_state.dart';
import '../game/numbers.dart';
import '../game/save_service.dart';

class StatsTab extends StatelessWidget {
  const StatsTab({super.key, required this.state, this.save});

  final GameState state;
  final SaveService? save;

  Future<void> _confirmReset(BuildContext context) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('⚠️ 모든 기록 삭제'),
        content: const Text('업보와 기록까지 전부 사라집니다. 되돌릴 수 없습니다.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('취소'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('삭제'),
          ),
        ],
      ),
    );
    if (ok == true) {
      state.hardReset();
      await save?.save(state);
    }
  }

  @override
  Widget build(BuildContext context) {
    final owned = state.hellLevels.fold<int>(0, (a, b) => a + b);
    final opened = state.hellLevels.where((l) => l > 0).length;
    final rows = <(String, String)>[
      ('칭호', state.rankTitle),
      ('평생 누적 영혼', formatNumber(state.totalEarned)),
      ('개방한 지옥', '$opened / ${hells.length}'),
      ('지옥 총 레벨', '$owned'),
      ('형벌 집행(터치)', '${state.totalTaps}회'),
      ('체포한 탈옥수', '${state.escapeesCaught}명'),
      ('윤회 횟수', '${state.rebirths}회'),
      ('플레이 시간', formatDuration(Duration(seconds: state.playSeconds.floor()))),
    ];
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        for (final (k, v) in rows)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 5),
            child: Row(
              children: [
                Text(k, style: const TextStyle(color: Colors.white60)),
                const Spacer(),
                Text(v, style: const TextStyle(fontWeight: FontWeight.bold)),
              ],
            ),
          ),
        const SizedBox(height: 24),
        OutlinedButton(
          onPressed: () => _confirmReset(context),
          style: OutlinedButton.styleFrom(foregroundColor: Colors.redAccent),
          child: const Text('기록 초기화'),
        ),
      ],
    );
  }
}
