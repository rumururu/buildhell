import 'package:flutter/material.dart';

import '../game/game_state.dart';
import '../game/numbers.dart';
import '../services/sound_service.dart';
import 'game_scope.dart';

class RebirthTab extends StatelessWidget {
  const RebirthTab({super.key});

  Future<void> _confirm(BuildContext context, GameState state) async {
    final scope = GameScope.of(context);
    final gain = state.karmaOnRebirth;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('☸️ 윤회하시겠습니까?'),
        content: Text(
          '영혼, 지옥, 수감 죄인, 강화(저승 장부 제외)가 초기화됩니다.\n'
          '혼석, 업적, 염라의 인장은 유지됩니다.\n\n'
          '대신 업보 $gain을 얻어 영구적으로 생산량이 '
          '+${gain * 10}% 증가합니다.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('아직이다'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('윤회한다'),
          ),
        ],
      ),
    );
    if (ok == true && state.rebirth()) {
      scope.sfx(Sfx.frenzy);
      scope.haptic(Haptic.heavy);
      scope.showToast('☸️ 윤회했습니다. 업보 +$gain');
      await scope.save?.save(state);
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = GameScope.of(context).state;
    final theme = Theme.of(context);
    final gain = state.karmaOnRebirth;
    // 다음 업보 1을 더 얻기 위해 필요한 평생 누적 영혼
    final nextAt = GameState.earningsForKarma(state.karma + gain + 1);

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text('☸️ 윤회', style: theme.textTheme.titleLarge),
        const SizedBox(height: 8),
        const Text(
          '지옥을 처음부터 다시 짓는 대신, 쌓은 업보로 영원히 강해집니다.\n'
          '업보 1당 모든 생산량과 터치 +10%.\n'
          '업보 총량 = ∛(평생 누적 영혼 ÷ 100만)',
          style: TextStyle(color: Colors.white70),
        ),
        const SizedBox(height: 16),
        _row('보유 업보', '${state.karma}  (+${state.karma * 10}%)'),
        _row('평생 누적 영혼', formatNumber(state.totalEarned)),
        _row('윤회 시 획득 업보', '+$gain'),
        _row('다음 업보까지', '${formatNumber(nextAt)} 누적 필요'),
        const SizedBox(height: 20),
        FilledButton.icon(
          key: const Key('rebirthButton'),
          style: FilledButton.styleFrom(
            backgroundColor: const Color(0xFF6A1B9A),
            foregroundColor: Colors.white,
            disabledForegroundColor: Colors.white38,
            padding: const EdgeInsets.symmetric(vertical: 14),
          ),
          onPressed: gain >= 1 ? () => _confirm(context, state) : null,
          icon: const Text('☸️', style: TextStyle(fontSize: 18)),
          label: Text(
            gain >= 1
                ? '윤회하기 (+$gain 업보)'
                : '평생 누적 ${formatNumber(nextAt)} 영혼 필요',
          ),
        ),
      ],
    );
  }

  Widget _row(String k, String v) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 4),
    child: Row(
      children: [
        Text(k, style: const TextStyle(color: Colors.white60)),
        const Spacer(),
        Text(v, style: const TextStyle(fontWeight: FontWeight.bold)),
      ],
    ),
  );
}
