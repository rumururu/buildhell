import 'package:flutter/material.dart';

import '../game/data.dart';
import '../game/game_state.dart';
import '../game/numbers.dart';
import '../game/sins.dart';
import '../services/sound_service.dart';
import 'game_scope.dart';

/// 심판석: 대기열 맨 앞 죄인을 알맞은 지옥으로 보낸다.
class JudgePanel extends StatelessWidget {
  const JudgePanel({super.key});

  void _judge(BuildContext context, int hell) {
    final scope = GameScope.of(context);
    final r = scope.state.judge(hell);
    if (r == null) return;
    if (r.correct) {
      scope.sfx(Sfx.judgeOk);
      scope.haptic(Haptic.medium);
      scope.showToast(
        '⚖️ 정확한 판결! 영혼 +${formatNumber(r.amount)}'
        '${r.streak >= 2 ? '  (연속 ${r.streak})' : ''}',
      );
    } else {
      scope.sfx(Sfx.judgeBad);
      scope.haptic(Haptic.heavy);
      scope.showToast(
        '❌ 오판! ${r.sinner.name}은(는) ${hells[r.sinner.hellIndex].name}행이었다. '
        '억울한 죄인이 탈옥했다!',
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = GameScope.of(context).state;
    final queue = state.sinnerQueue;
    return AnimatedSize(
      duration: const Duration(milliseconds: 200),
      alignment: Alignment.topCenter,
      child: queue.isEmpty
          ? const SizedBox(width: double.infinity)
          : _buildCard(context, state, queue.first),
    );
  }

  Widget _buildCard(BuildContext context, GameState state, Sinner sinner) {
    final theme = Theme.of(context);
    return Container(
      key: const Key('judgePanel'),
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
      decoration: const BoxDecoration(
        color: Color(0xFF26100A),
        border: Border(
          top: BorderSide(color: Color(0xFF8D6E63), width: 1),
          bottom: BorderSide(color: Color(0xFF3E2723), width: 1),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Text(
                '⚖️ 심판  대기 ${state.sinnerQueue.length}/${GameState.maxSinnerQueue}',
                style: theme.textTheme.labelMedium?.copyWith(
                  color: Colors.amber.shade200,
                ),
              ),
              const Spacer(),
              if (state.judgeStreak >= 2)
                Text(
                  '🔥 연속 ${state.judgeStreak}회 (+${10 * state.judgeStreak.clamp(0, 20)}%)',
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: Colors.orangeAccent,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 2),
          Text.rich(
            TextSpan(
              children: [
                TextSpan(
                  text: '${sinner.name} (${sinner.age}세)  ',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                TextSpan(
                  text: '죄목: ${sinner.sin}',
                  style: const TextStyle(color: Colors.white70),
                ),
              ],
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              for (final h in sinner.choices)
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 3),
                    child: OutlinedButton(
                      key: Key('judge$h'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.white,
                        side: const BorderSide(color: Color(0xFF8D6E63)),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 4,
                          vertical: 8,
                        ),
                      ),
                      onPressed: () => _judge(context, h),
                      child: Column(
                        children: [
                          Text(
                            hells[h].emoji,
                            style: const TextStyle(fontSize: 18),
                          ),
                          Text(
                            hells[h].name,
                            style: const TextStyle(fontSize: 12),
                            maxLines: 1,
                          ),
                          Text(
                            hellSins[h].$1,
                            style: const TextStyle(
                              fontSize: 10,
                              color: Colors.white54,
                            ),
                            maxLines: 1,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}
