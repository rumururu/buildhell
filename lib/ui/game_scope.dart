import 'package:flutter/widgets.dart';

import '../game/game_state.dart';
import '../game/save_service.dart';
import '../services/ad_service.dart';
import '../services/sound_service.dart';

/// 화면 어디서든 게임 상태·효과음·광고·저장에 접근하기 위한 범위.
///
/// [GameState]가 바뀌면 `GameScope.of`를 부른 위젯이 다시 그려진다.
class GameScope extends InheritedNotifier<GameState> {
  const GameScope({
    super.key,
    required this.state,
    required this.feedback,
    required this.ads,
    this.save,
    this.toast,
    required super.child,
  }) : super(notifier: state);

  final GameState state;
  final FeedbackService feedback;
  final AdService ads;
  final SaveService? save;

  /// 화면 상단 알림 띄우기.
  final void Function(String message)? toast;

  static GameScope of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<GameScope>();
    assert(scope != null, 'GameScope가 없습니다');
    return scope!;
  }

  /// 설정을 확인하고 효과음 재생.
  void sfx(Sfx s) {
    if (state.soundOn) feedback.play(s);
  }

  /// 설정을 확인하고 진동.
  void haptic(Haptic h) {
    if (state.hapticsOn) feedback.vibrate(h);
  }

  void showToast(String message) => toast?.call(message);

  @override
  bool updateShouldNotify(GameScope oldWidget) =>
      super.updateShouldNotify(oldWidget) ||
      feedback != oldWidget.feedback ||
      ads != oldWidget.ads;
}
