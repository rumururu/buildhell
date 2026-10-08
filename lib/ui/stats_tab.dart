import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../game/data.dart';
import '../game/numbers.dart';
import '../game/save_code.dart';
import 'game_scope.dart';

class StatsTab extends StatelessWidget {
  const StatsTab({super.key});

  Future<void> _confirmReset(BuildContext context) async {
    final scope = GameScope.of(context);
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('⚠️ 모든 기록 삭제'),
        content: const Text('업보, 혼석, 업적까지 전부 사라집니다. 되돌릴 수 없습니다.'),
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
      scope.state.hardReset();
      await scope.save?.save(scope.state);
    }
  }

  Future<void> _exportCode(BuildContext context) async {
    final scope = GameScope.of(context);
    final code = SaveCode.encode(scope.state.toJson());
    await Clipboard.setData(ClipboardData(text: code));
    scope.showToast('📋 저장 코드를 복사했습니다. 메모장 등에 보관하세요');
  }

  Future<void> _importCode(BuildContext context) async {
    final scope = GameScope.of(context);
    final controller = TextEditingController();
    final code = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('저장 코드 불러오기'),
        content: TextField(
          key: const Key('importField'),
          controller: controller,
          maxLines: 4,
          decoration: const InputDecoration(
            hintText: 'BH1.로 시작하는 코드를 붙여넣으세요',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('취소'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(controller.text),
            child: const Text('불러오기 (현재 진행 덮어씀)'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (code == null || code.trim().isEmpty) return;
    final json = SaveCode.decode(code);
    if (json == null) {
      scope.showToast('❌ 올바르지 않은 저장 코드입니다');
      return;
    }
    scope.state.loadJson(json);
    await scope.save?.save(scope.state);
    scope.showToast('✅ 저장 코드를 불러왔습니다');
  }

  @override
  Widget build(BuildContext context) {
    final state = GameScope.of(context).state;
    final owned = state.hellLevels.fold<int>(0, (a, b) => a + b);
    final totalJudged = state.correctJudgements + state.wrongJudgements;
    final rows = <(String, String)>[
      ('칭호', state.rankTitle),
      ('평생 누적 영혼', formatNumber(state.totalEarned)),
      (
        '개방한 지옥 (최고)',
        '${state.openHells.length} / ${hells.length} (${state.maxHellsOpened})',
      ),
      ('지옥 총 레벨', '$owned'),
      ('형벌 집행(터치)', '${state.totalTaps}회 (치명타 ${state.crits})'),
      (
        '심판',
        '$totalJudged회 · 정확도 ${totalJudged == 0 ? 0 : (state.correctJudgements * 100 / totalJudged).round()}%',
      ),
      ('최고 연속 판결', '${state.bestStreak}회'),
      ('체포한 탈옥수', '${state.escapeesCaught}명'),
      ('윤회 횟수', '${state.rebirths}회'),
      ('플레이 시간', formatDuration(Duration(seconds: state.playSeconds.floor()))),
    ];
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        for (final (k, v) in rows)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Row(
              children: [
                Text(k, style: const TextStyle(color: Colors.white60)),
                const Spacer(),
                Text(v, style: const TextStyle(fontWeight: FontWeight.bold)),
              ],
            ),
          ),
        const Divider(height: 28),
        SwitchListTile(
          key: const Key('soundSwitch'),
          contentPadding: EdgeInsets.zero,
          title: const Text('🔊 효과음'),
          value: state.soundOn,
          onChanged: state.setSound,
        ),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('📳 진동'),
          value: state.hapticsOn,
          onChanged: state.setHaptics,
        ),
        const Divider(height: 28),
        const Text(
          '기기를 바꿀 때 저장 코드를 복사해 두었다가 새 기기에서 불러오세요.',
          style: TextStyle(fontSize: 12, color: Colors.white54),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: OutlinedButton(
                onPressed: () => _exportCode(context),
                child: const Text('저장 코드 복사'),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: OutlinedButton(
                onPressed: () => _importCode(context),
                child: const Text('저장 코드 불러오기'),
              ),
            ),
          ],
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
