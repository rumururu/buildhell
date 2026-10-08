import 'package:flutter/material.dart';

import '../game/data.dart';
import '../game/game_state.dart';
import '../game/numbers.dart';
import '../services/sound_service.dart';
import 'game_scope.dart';

class UpgradesTab extends StatelessWidget {
  const UpgradesTab({super.key});

  String _effect(GameState state, UpgradeDef u, int lv) => switch (u.id) {
    UpgradeIds.tap =>
      '현재: 터치 기본 ${1 + 2 * lv}, 초당 생산의 ${(0.5 * lv).toStringAsFixed(1)}%',
    UpgradeIds.trainer => '현재: 생산량 +${25 * lv}%',
    UpgradeIds.reaper => '현재: 출현 간격 -${7 * lv}%, 포상 +${20 * lv}%',
    UpgradeIds.ledger => '현재: 오프라인 최대 ${formatNumber(state.maxOfflineHours)}시간',
    _ => '',
  };

  @override
  Widget build(BuildContext context) {
    final state = GameScope.of(context).state;
    final theme = Theme.of(context);
    return ListView(
      padding: const EdgeInsets.all(8),
      children: [
        for (final u in upgrades)
          Card(
            color: const Color(0xFF221010),
            child: Padding(
              padding: const EdgeInsets.all(10),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 22,
                    backgroundColor: const Color(0xFF3A1515),
                    child: Text(u.emoji, style: const TextStyle(fontSize: 22)),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${u.name}  Lv.${state.upgradeLevel(u.id)}/${u.maxLevel}',
                          style: theme.textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          u.description,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: Colors.white60,
                          ),
                        ),
                        Text(
                          _effect(state, u, state.upgradeLevel(u.id)),
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: Colors.orange.shade200,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  SizedBox(
                    width: 96,
                    child: FilledButton(
                      key: Key('buyUpgrade_${u.id}'),
                      style: FilledButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        backgroundColor: const Color(0xFF6A1B9A),
                        foregroundColor: Colors.white,
                        disabledForegroundColor: Colors.white38,
                        disabledBackgroundColor: Colors.white10,
                      ),
                      onPressed: state.canBuyUpgrade(u.id)
                          ? () {
                              final scope = GameScope.of(context);
                              if (state.buyUpgrade(u.id)) {
                                scope.sfx(Sfx.upgrade);
                                scope.haptic(Haptic.light);
                              }
                            }
                          : null,
                      child: state.isUpgradeMaxed(u.id)
                          ? const Text('MAX')
                          : Column(
                              children: [
                                const Text(
                                  '강화',
                                  style: TextStyle(fontSize: 12),
                                ),
                                Text(
                                  '👻 ${formatNumber(state.upgradeCost(u.id))}',
                                  style: const TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}
