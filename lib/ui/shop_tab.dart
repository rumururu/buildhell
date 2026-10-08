import 'package:flutter/material.dart';

import '../game/meta.dart';
import '../game/numbers.dart';
import '../services/sound_service.dart';
import 'game_scope.dart';

class ShopTab extends StatelessWidget {
  const ShopTab({super.key});

  Future<void> _watchAd(
    BuildContext context,
    void Function() reward,
    String message,
  ) async {
    final scope = GameScope.of(context);
    final ok = await scope.ads.showRewarded();
    if (!ok) {
      scope.showToast('광고를 끝까지 봐야 보상을 받을 수 있습니다');
      return;
    }
    reward();
    scope.sfx(Sfx.reward);
    scope.showToast(message);
  }

  @override
  Widget build(BuildContext context) {
    final scope = GameScope.of(context);
    final state = scope.state;
    final theme = Theme.of(context);
    return ListenableBuilder(
      listenable: scope.ads,
      builder: (context, _) {
        final adReady = scope.ads.isReady;
        final waitLabel = scope.ads.isSupported ? '준비 중' : '앱 전용';
        return ListView(
          padding: const EdgeInsets.all(8),
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 4, 8, 8),
              child: Text(
                '💎 혼석 ${state.gems}개',
                style: theme.textTheme.titleMedium?.copyWith(
                  color: Colors.cyanAccent,
                ),
              ),
            ),
            _ShopCard(
              emoji: '📺',
              title: '저승 방송 시청',
              description:
                  '광고 보고 혼석 +$adGemReward (오늘 ${state.adGemsToday}/$adGemDailyLimit)',
              buttonKey: const Key('adGems'),
              buttonLabel: adReady ? '광고 보기' : waitLabel,
              enabled: adReady && state.canWatchAdForGems,
              color: const Color(0xFF00838F),
              onPressed: () =>
                  _watchAd(context, state.rewardAdGems, '💎 혼석 +$adGemReward'),
            ),
            _ShopCard(
              emoji: '😈',
              title: '악마의 계약',
              description: state.isAdBoosted
                  ? '계약 중: 생산 x2 남은 시간 ${formatDuration(Duration(seconds: state.adBoostRemaining.ceil()))}'
                  : '광고 보고 30분간 모든 생산 x2 (오프라인에도 적용)',
              buttonKey: const Key('adBoost'),
              buttonLabel: adReady
                  ? (state.isAdBoosted ? '30분으로 갱신' : '광고 보기')
                  : waitLabel,
              enabled: adReady,
              color: const Color(0xFF6A1B9A),
              onPressed: () => _watchAd(
                context,
                state.rewardAdBoost,
                '😈 악마의 계약 체결! 30분간 생산 x2',
              ),
            ),
            const Divider(height: 24),
            for (final item in shopItems)
              _ShopCard(
                emoji: item.emoji,
                title: item.maxLevel != null
                    ? '${item.name}  Lv.${state.shopLevel(item.id)}/${item.maxLevel}'
                    : item.name,
                description: item.id == ShopIds.timeSkip
                    ? '${item.description} (지금 ${formatNumber(state.soulsPerSecond(includeTemporary: false) * 3600)})'
                    : item.description,
                buttonKey: Key('shop_${item.id}'),
                buttonLabel: state.isShopMaxed(item.id)
                    ? 'MAX'
                    : '💎 ${state.shopCost(item.id)}',
                enabled: state.canBuyShop(item.id),
                color: const Color(0xFF00695C),
                onPressed: () {
                  final gained = state.buyShop(item.id);
                  if (gained == null) return;
                  scope.sfx(
                    item.id == ShopIds.frenzy ? Sfx.frenzy : Sfx.reward,
                  );
                  scope.haptic(Haptic.medium);
                  if (item.id == ShopIds.timeSkip) {
                    scope.showToast('⏳ 영혼 +${formatNumber(gained)}');
                  }
                },
              ),
          ],
        );
      },
    );
  }
}

class _ShopCard extends StatelessWidget {
  const _ShopCard({
    required this.emoji,
    required this.title,
    required this.description,
    required this.buttonKey,
    required this.buttonLabel,
    required this.enabled,
    required this.color,
    required this.onPressed,
  });

  final String emoji;
  final String title;
  final String description;
  final Key buttonKey;
  final String buttonLabel;
  final bool enabled;
  final Color color;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Card(
      color: const Color(0xFF14181C),
      child: Padding(
        padding: const EdgeInsets.all(10),
        child: Row(
          children: [
            CircleAvatar(
              radius: 22,
              backgroundColor: const Color(0xFF263238),
              child: Text(emoji, style: const TextStyle(fontSize: 22)),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  Text(
                    description,
                    style: const TextStyle(fontSize: 12, color: Colors.white60),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            SizedBox(
              width: 100,
              child: FilledButton(
                key: buttonKey,
                style: FilledButton.styleFrom(
                  backgroundColor: color,
                  foregroundColor: Colors.white,
                  disabledBackgroundColor: Colors.white10,
                  disabledForegroundColor: Colors.white38,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 10,
                  ),
                ),
                onPressed: enabled ? onPressed : null,
                child: Text(
                  buttonLabel,
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 12),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
