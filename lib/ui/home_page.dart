import 'dart:async';

import 'package:flutter/material.dart';

import '../game/game_state.dart';
import '../game/numbers.dart';
import '../game/save_service.dart';
import 'hells_tab.dart';
import 'rebirth_tab.dart';
import 'stats_tab.dart';
import 'tap_area.dart';
import 'upgrades_tab.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key, required this.state, this.save});

  final GameState state;
  final SaveService? save;

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  Timer? _ticker;
  Timer? _autosave;
  late final AppLifecycleListener _lifecycle;
  bool _offlineDialogOpen = false;

  GameState get state => widget.state;

  @override
  void initState() {
    super.initState();
    _ticker = Timer.periodic(
      const Duration(milliseconds: 100),
      (_) => state.update(),
    );
    _autosave = Timer.periodic(const Duration(seconds: 10), (_) => _save());
    _lifecycle = AppLifecycleListener(
      onHide: _save,
      onPause: _save,
      onResume: state.update,
    );
    state.addListener(_checkOffline);
    WidgetsBinding.instance.addPostFrameCallback((_) => _checkOffline());
  }

  @override
  void dispose() {
    state.removeListener(_checkOffline);
    _ticker?.cancel();
    _autosave?.cancel();
    _lifecycle.dispose();
    _save();
    super.dispose();
  }

  void _save() => widget.save?.save(state);

  void _checkOffline() {
    final report = state.pendingOffline;
    if (report == null || _offlineDialogOpen || !mounted) return;
    state.pendingOffline = null;
    _offlineDialogOpen = true;
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('👹 옥졸 보고'),
        content: Text(
          '자리를 비운 ${formatDuration(report.elapsed)} 동안\n'
          '옥졸들이 영혼 ${formatNumber(report.gain)}개를 거둬들였습니다.\n\n'
          '(최대 ${formatNumber(state.maxOfflineHours)}시간, 생산량의 50%)',
        ),
        actions: [
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('수고했다'),
          ),
        ],
      ),
    ).whenComplete(() => _offlineDialogOpen = false);
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 4,
      child: Scaffold(
        body: SafeArea(
          child: ListenableBuilder(
            listenable: state,
            builder: (context, _) => Column(
              children: [
                _Header(state: state),
                Expanded(flex: 5, child: TapArea(state: state)),
                const TabBar(
                  tabs: [
                    Tab(text: '🔥 지옥'),
                    Tab(text: '🔱 강화'),
                    Tab(text: '☸️ 윤회'),
                    Tab(text: '📊 기록'),
                  ],
                ),
                Expanded(
                  flex: 6,
                  child: TabBarView(
                    children: [
                      HellsTab(state: state),
                      UpgradesTab(state: state),
                      RebirthTab(state: state, onRebirth: _save),
                      StatsTab(state: state, save: widget.save),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
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
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
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
                Text(
                  '☸️ 업보 ${state.karma} (+${state.karma * 10}%)',
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: Colors.purple.shade200,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 4),
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
            '터치당 ${formatNumber(state.tapPower)}',
            style: theme.textTheme.bodySmall?.copyWith(
              color: Colors.orange.shade200,
            ),
          ),
        ],
      ),
    );
  }
}
