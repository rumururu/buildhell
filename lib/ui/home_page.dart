import 'dart:async';

import 'package:flutter/material.dart';

import '../game/game_state.dart';
import '../game/numbers.dart';
import '../game/save_service.dart';
import '../services/ad_service.dart';
import '../services/sound_service.dart';
import 'game_scope.dart';
import 'hells_tab.dart';
import 'judge_panel.dart';
import 'quests_tab.dart';
import 'rebirth_tab.dart';
import 'shop_tab.dart';
import 'stats_tab.dart';
import 'tap_area.dart';
import 'upgrades_tab.dart';

class HomePage extends StatefulWidget {
  const HomePage({
    super.key,
    required this.state,
    required this.feedback,
    required this.ads,
    this.save,
  });

  final GameState state;
  final FeedbackService feedback;
  final AdService ads;
  final SaveService? save;

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  Timer? _ticker;
  Timer? _autosave;
  Timer? _toastTimer;
  late final AppLifecycleListener _lifecycle;
  bool _dialogOpen = false;
  String? _toastText;
  int _toastId = 0;

  GameState get state => widget.state;

  @override
  void initState() {
    super.initState();
    _ticker = Timer.periodic(const Duration(milliseconds: 100), (_) => _tick());
    _autosave = Timer.periodic(const Duration(seconds: 10), (_) => _save());
    _lifecycle = AppLifecycleListener(
      onHide: _save,
      onPause: _save,
      onResume: state.update,
    );
    state.addListener(_checkDialogs);
    WidgetsBinding.instance.addPostFrameCallback((_) => _checkDialogs());
  }

  @override
  void dispose() {
    state.removeListener(_checkDialogs);
    _ticker?.cancel();
    _autosave?.cancel();
    _toastTimer?.cancel();
    _lifecycle.dispose();
    _save();
    super.dispose();
  }

  void _save() => widget.save?.save(state);

  void _sfx(Sfx s) {
    if (state.soundOn) widget.feedback.play(s);
  }

  void _tick() {
    state.update();
    for (final e in state.takeEvents()) {
      switch (e) {
        case GameEvent.sinnerArrived:
        case GameEvent.escapeeAppeared:
          _sfx(Sfx.alert);
        case GameEvent.achievementUnlocked:
          break;
      }
    }
    if (state.pendingAchievements.isNotEmpty) {
      final a = state.pendingAchievements.removeAt(0);
      _sfx(Sfx.reward);
      if (state.hapticsOn) widget.feedback.vibrate(Haptic.medium);
      _toast('🏆 업적 달성: ${a.title}  💎+${a.reward}');
    }
  }

  void _toast(String message) {
    if (!mounted) return;
    setState(() {
      _toastText = message;
      _toastId++;
    });
    _toastTimer?.cancel();
    _toastTimer = Timer(const Duration(milliseconds: 2600), () {
      if (mounted) setState(() => _toastText = null);
    });
  }

  /// 오프라인 정산 → 출석 순서로 대화상자를 하나씩 띄운다.
  void _checkDialogs() {
    if (_dialogOpen || !mounted) return;
    final report = state.pendingOffline;
    if (report != null) {
      state.pendingOffline = null;
      _show(_OfflineDialog(report: report, ads: widget.ads, state: state));
      return;
    }
    if (state.canClaimLogin) {
      _show(_LoginDialog(state: state, ads: widget.ads));
    }
  }

  void _show(Widget dialog) {
    _dialogOpen = true;
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => dialog,
    ).whenComplete(() {
      _dialogOpen = false;
      _sfx(Sfx.reward);
      // 다음 대화상자가 있으면 이어서
      WidgetsBinding.instance.addPostFrameCallback((_) => _checkDialogs());
    });
  }

  @override
  Widget build(BuildContext context) {
    return GameScope(
      state: state,
      feedback: widget.feedback,
      ads: widget.ads,
      save: widget.save,
      toast: _toast,
      child: DefaultTabController(
        length: 6,
        child: Scaffold(
          body: SafeArea(
            child: ListenableBuilder(
              listenable: state,
              builder: (context, _) => Stack(
                children: [
                  Column(
                    children: [
                      _Header(state: state),
                      // 심판석이 열리면 가마솥 영역을 줄여 아래 목록 공간을 확보한다.
                      Expanded(
                        flex: state.sinnerQueue.isEmpty ? 4 : 3,
                        child: const TapArea(),
                      ),
                      const JudgePanel(),
                      TabBar(
                        isScrollable: true,
                        tabAlignment: TabAlignment.start,
                        labelPadding: const EdgeInsets.symmetric(
                          horizontal: 12,
                        ),
                        tabs: [
                          const Tab(text: '🔥 지옥'),
                          const Tab(text: '🔱 강화'),
                          const Tab(text: '💎 상점'),
                          Tab(
                            child: _DotLabel(
                              text: '📜 임무',
                              dot: hasClaimableRewards(state),
                            ),
                          ),
                          const Tab(text: '☸️ 윤회'),
                          const Tab(text: '📊 기록'),
                        ],
                      ),
                      const Expanded(
                        flex: 5,
                        child: TabBarView(
                          children: [
                            HellsTab(),
                            UpgradesTab(),
                            ShopTab(),
                            QuestsTab(),
                            RebirthTab(),
                            StatsTab(),
                          ],
                        ),
                      ),
                    ],
                  ),
                  Positioned(
                    top: 4,
                    left: 12,
                    right: 12,
                    child: IgnorePointer(
                      child: AnimatedSwitcher(
                        duration: const Duration(milliseconds: 200),
                        child: _toastText == null
                            ? const SizedBox.shrink()
                            : _Toast(
                                key: ValueKey(_toastId),
                                text: _toastText!,
                              ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _DotLabel extends StatelessWidget {
  const _DotLabel({required this.text, required this.dot});
  final String text;
  final bool dot;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(text),
        if (dot)
          Container(
            margin: const EdgeInsets.only(left: 4),
            width: 7,
            height: 7,
            decoration: const BoxDecoration(
              color: Colors.redAccent,
              shape: BoxShape.circle,
            ),
          ),
      ],
    );
  }
}

class _Toast extends StatelessWidget {
  const _Toast({super.key, required this.text});
  final String text;

  @override
  Widget build(BuildContext context) {
    return Material(
      key: const Key('toast'),
      color: const Color(0xEE2B1B12),
      elevation: 6,
      borderRadius: BorderRadius.circular(10),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        child: Text(
          text,
          textAlign: TextAlign.center,
          style: const TextStyle(color: Colors.white, fontSize: 13),
        ),
      ),
    );
  }
}

class _OfflineDialog extends StatelessWidget {
  const _OfflineDialog({
    required this.report,
    required this.ads,
    required this.state,
  });

  final OfflineReport report;
  final AdService ads;
  final GameState state;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('👹 옥졸 보고'),
      content: Text(
        '자리를 비운 ${formatDuration(report.elapsed)} 동안\n'
        '옥졸들이 영혼 ${formatNumber(report.gain)}개를 거둬들였습니다.\n\n'
        '(최대 ${formatNumber(state.maxOfflineHours)}시간, 생산량의 50%)',
      ),
      actions: [
        ListenableBuilder(
          listenable: ads,
          builder: (context, _) => TextButton(
            key: const Key('offlineDouble'),
            onPressed: ads.isReady
                ? () async {
                    final nav = Navigator.of(context);
                    if (await ads.showRewarded()) {
                      state.rewardOfflineDouble(report);
                    }
                    nav.pop();
                  }
                : null,
            child: const Text('📺 광고 보고 2배'),
          ),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('수고했다'),
        ),
      ],
    );
  }
}

class _LoginDialog extends StatelessWidget {
  const _LoginDialog({required this.state, required this.ads});

  final GameState state;
  final AdService ads;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('📅 출석 ${state.loginDays + 1}일차'),
      content: Text(
        '염라대왕이 성실한 옥졸에게 혼석을 하사합니다.\n\n'
        '💎 혼석 ${state.todayLoginReward}개',
      ),
      actions: [
        ListenableBuilder(
          listenable: ads,
          builder: (context, _) => TextButton(
            onPressed: ads.isReady
                ? () async {
                    final nav = Navigator.of(context);
                    final ok = await ads.showRewarded();
                    state.claimLogin(doubled: ok);
                    nav.pop();
                  }
                : null,
            child: const Text('📺 광고 보고 2배'),
          ),
        ),
        FilledButton(
          key: const Key('loginClaim'),
          onPressed: () {
            state.claimLogin();
            Navigator.of(context).pop();
          },
          child: const Text('받기'),
        ),
      ],
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.state});

  final GameState state;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF3A0A0A), Color(0xFF1A0505)],
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                '👑 ${state.rankTitle}',
                style: theme.textTheme.labelLarge?.copyWith(
                  color: Colors.amber.shade300,
                ),
              ),
              const Spacer(),
              if (state.karma > 0)
                Padding(
                  padding: const EdgeInsets.only(right: 10),
                  child: Text(
                    '☸️ ${state.karma}',
                    style: theme.textTheme.labelLarge?.copyWith(
                      color: Colors.purple.shade200,
                    ),
                  ),
                ),
              Text(
                '💎 ${state.gems}',
                key: const Key('gemsText'),
                style: theme.textTheme.labelLarge?.copyWith(
                  color: Colors.cyanAccent,
                ),
              ),
            ],
          ),
          Text(
            '👻 ${formatNumber(state.souls)}',
            key: const Key('soulsText'),
            style: theme.textTheme.headlineMedium?.copyWith(
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          Text(
            '초당 ${formatNumber(state.soulsPerSecond())}  ·  '
            '터치당 ${formatNumber(state.tapPower)}  ·  '
            '배율 x${formatNumber(state.incomeMultiplier())}',
            style: theme.textTheme.bodySmall?.copyWith(
              color: Colors.orange.shade200,
            ),
          ),
        ],
      ),
    );
  }
}
