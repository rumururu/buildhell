import 'package:flutter/material.dart';

import '../game/data.dart';
import '../game/game_state.dart';
import '../game/numbers.dart';
import '../services/sound_service.dart';
import 'game_scope.dart';

class HellsTab extends StatelessWidget {
  const HellsTab({super.key});

  @override
  Widget build(BuildContext context) {
    final state = GameScope.of(context).state;
    // 공개된 지옥 + 그 다음 하나는 "???"로 미리 보여준다.
    var visible = 0;
    while (visible < hells.length && state.isHellRevealed(visible)) {
      visible++;
    }
    final showMystery = visible < hells.length;

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
          child: SegmentedButton<BuyMode>(
            segments: [
              for (final m in BuyMode.values)
                ButtonSegment(value: m, label: Text(m.label)),
            ],
            selected: {state.buyMode},
            showSelectedIcon: false,
            onSelectionChanged: (s) => state.setBuyMode(s.first),
          ),
        ),
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.all(8),
            itemCount: visible + (showMystery ? 1 : 0),
            itemBuilder: (context, i) => i < visible
                ? _HellTile(state: state, index: i)
                : _MysteryTile(def: hells[i]),
          ),
        ),
      ],
    );
  }
}

class _HellTile extends StatelessWidget {
  const _HellTile({required this.state, required this.index});

  final GameState state;
  final int index;

  @override
  Widget build(BuildContext context) {
    final def = hells[index];
    final level = state.hellLevels[index];
    final count = state.buyCount(index);
    final cost = state.hellCost(index, count);
    final canBuy = state.canBuyHell(index);
    final next = GameState.nextMilestone(level);
    final prevMs = hellMilestones.lastWhere((m) => m <= level, orElse: () => 0);
    final theme = Theme.of(context);

    return Card(
      color: level > 0 ? const Color(0xFF2A0D0D) : const Color(0xFF1E0B0B),
      child: Padding(
        padding: const EdgeInsets.all(10),
        child: Row(
          children: [
            CircleAvatar(
              radius: 24,
              backgroundColor: const Color(0xFF4A1010),
              child: Text(def.emoji, style: const TextStyle(fontSize: 24)),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${def.name}  Lv.$level',
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    def.description,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: Colors.white60,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    level > 0
                        ? '초당 ${formatNumber(state.hellIncome(index))}'
                              '${GameState.milestoneMultiplier(level) > 1 ? '  (x${GameState.milestoneMultiplier(level).toInt()})' : ''}'
                        : '개당 초당 ${formatNumber(def.baseIncome * state.incomeMultiplier())}',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: Colors.orange.shade200,
                    ),
                  ),
                  if (state.prisoners[index] > 0)
                    Text(
                      '⛓️ 수감 죄인 ${state.prisoners[index]}명 (+${2 * state.prisoners[index]}%)',
                      style: const TextStyle(
                        fontSize: 11,
                        color: Colors.white54,
                      ),
                    ),
                  if (next != null && level > 0) ...[
                    const SizedBox(height: 4),
                    LinearProgressIndicator(
                      value: (level - prevMs) / (next - prevMs),
                      minHeight: 3,
                      color: Colors.amber,
                      backgroundColor: Colors.white10,
                    ),
                    Text(
                      'Lv.$next 달성 시 생산량 x2',
                      style: const TextStyle(
                        fontSize: 10,
                        color: Colors.white38,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 8),
            SizedBox(
              width: 96,
              child: FilledButton(
                key: Key('buyHell$index'),
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  backgroundColor: const Color(0xFFC62828),
                  foregroundColor: Colors.white,
                  disabledForegroundColor: Colors.white38,
                  disabledBackgroundColor: Colors.white10,
                ),
                onPressed: canBuy
                    ? () {
                        final scope = GameScope.of(context);
                        if (state.buyHell(index)) {
                          scope.sfx(Sfx.buy);
                          scope.haptic(Haptic.light);
                        }
                      }
                    : null,
                child: Column(
                  children: [
                    Text(
                      level == 0 ? '개방' : '확장 x$count',
                      style: const TextStyle(fontSize: 12),
                    ),
                    Text(
                      '👻 ${formatNumber(cost)}',
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
    );
  }
}

class _MysteryTile extends StatelessWidget {
  const _MysteryTile({required this.def});

  final HellDef def;

  @override
  Widget build(BuildContext context) {
    return Card(
      color: const Color(0xFF150808),
      child: ListTile(
        leading: const CircleAvatar(
          radius: 24,
          backgroundColor: Colors.black26,
          child: Text('❓', style: TextStyle(fontSize: 22)),
        ),
        title: const Text('??? 지옥', style: TextStyle(color: Colors.white38)),
        subtitle: Text(
          '이전 지옥을 개방하면 드러납니다 · 👻 ${formatNumber(def.baseCost)}',
          style: const TextStyle(color: Colors.white24, fontSize: 12),
        ),
      ),
    );
  }
}
