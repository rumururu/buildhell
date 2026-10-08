import 'package:flutter/material.dart';

import '../game/game_state.dart';
import '../game/meta.dart';
import '../services/sound_service.dart';
import 'game_scope.dart';

/// 수령 가능한 보상이 있는지 (탭 빨간 점 표시용).
bool hasClaimableRewards(GameState s) =>
    s.canClaimLogin ||
    s.canClaimDailyBonus ||
    s.dailyQuests.any((q) => q.done && !q.claimed);

class QuestsTab extends StatelessWidget {
  const QuestsTab({super.key});

  @override
  Widget build(BuildContext context) {
    final scope = GameScope.of(context);
    final state = scope.state;
    final theme = Theme.of(context);

    void rewarded(String msg) {
      scope.sfx(Sfx.reward);
      scope.haptic(Haptic.medium);
      scope.showToast(msg);
    }

    final day = state.loginDays % loginRewards.length;
    return ListView(
      padding: const EdgeInsets.all(12),
      children: [
        Text('📅 출석', style: theme.textTheme.titleMedium),
        const SizedBox(height: 6),
        Row(
          children: [
            for (var i = 0; i < loginRewards.length; i++)
              Expanded(
                child: Container(
                  margin: const EdgeInsets.symmetric(horizontal: 2),
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  decoration: BoxDecoration(
                    color: i < day || (i == day && !state.canClaimLogin)
                        ? const Color(0xFF1B5E20)
                        : i == day
                        ? const Color(0xFF5D4037)
                        : const Color(0xFF1E1E1E),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Column(
                    children: [
                      Text('${i + 1}일', style: const TextStyle(fontSize: 10)),
                      Text(
                        '💎${loginRewards[i]}',
                        style: const TextStyle(fontSize: 11),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 6),
        FilledButton(
          key: const Key('claimLogin'),
          onPressed: state.canClaimLogin
              ? () {
                  final g = state.claimLogin();
                  rewarded('📅 출석 보상 💎+$g');
                }
              : null,
          child: Text(
            state.canClaimLogin
                ? '오늘 출석 보상 받기 (💎${state.todayLoginReward})'
                : '내일 또 오세요 (누적 ${state.loginDays}일)',
          ),
        ),
        const Divider(height: 28),
        Text('📜 오늘의 임무', style: theme.textTheme.titleMedium),
        for (var i = 0; i < state.dailyQuests.length; i++)
          _QuestRow(
            quest: state.dailyQuests[i],
            onClaim: () {
              if (state.claimQuest(i)) rewarded('📜 임무 완료 💎+$questReward');
            },
            index: i,
          ),
        const SizedBox(height: 4),
        OutlinedButton(
          onPressed: state.canClaimDailyBonus
              ? () {
                  if (state.claimDailyBonus()) {
                    rewarded('🎁 오늘의 임무 전부 완료 💎+$allQuestsBonus');
                  }
                }
              : null,
          child: Text(
            state.dailyBonusClaimed
                ? '오늘 보너스 수령 완료'
                : '임무 3개 완료 보너스 💎$allQuestsBonus',
          ),
        ),
        const Divider(height: 28),
        Text(
          '🏆 업적 ${state.unlockedAchievements.length}/${achievements.length}'
          '  (영구 생산 +${(achievementBonus * 100 * state.unlockedAchievements.length).round()}%)',
          style: theme.textTheme.titleMedium,
        ),
        const SizedBox(height: 4),
        for (final a in achievements)
          ListTile(
            dense: true,
            contentPadding: EdgeInsets.zero,
            leading: Text(
              state.unlockedAchievements.contains(a.id) ? '🏆' : '🔒',
              style: const TextStyle(fontSize: 20),
            ),
            title: Text(
              a.title,
              style: TextStyle(
                color: state.unlockedAchievements.contains(a.id)
                    ? Colors.amber.shade200
                    : Colors.white54,
              ),
            ),
            trailing: Text(
              '💎${a.reward}',
              style: const TextStyle(color: Colors.white54),
            ),
          ),
      ],
    );
  }
}

class _QuestRow extends StatelessWidget {
  const _QuestRow({
    required this.quest,
    required this.onClaim,
    required this.index,
  });

  final QuestProgress quest;
  final VoidCallback onClaim;
  final int index;

  @override
  Widget build(BuildContext context) {
    final target = quest.def.target;
    final progress = quest.progress.clamp(0, target);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(quest.def.title),
                const SizedBox(height: 4),
                LinearProgressIndicator(
                  value: progress / target,
                  minHeight: 5,
                  color: Colors.amber,
                  backgroundColor: Colors.white10,
                ),
                Text(
                  '$progress / $target',
                  style: const TextStyle(fontSize: 11, color: Colors.white54),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          SizedBox(
            width: 90,
            child: FilledButton(
              key: Key('claimQuest$index'),
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 4),
              ),
              onPressed: quest.done && !quest.claimed ? onClaim : null,
              child: Text(
                quest.claimed ? '완료' : '💎$questReward',
                style: const TextStyle(fontSize: 12),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
