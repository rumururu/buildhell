import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

enum Sfx {
  tap('tap.wav', 6),
  crit('crit.wav', 2),
  buy('buy.wav', 3),
  upgrade('upgrade.wav', 2),
  catchEscapee('catch.wav', 1),
  judgeOk('judge_ok.wav', 2),
  judgeBad('judge_bad.wav', 1),
  frenzy('frenzy.wav', 1),
  reward('reward.wav', 2),
  alert('alert.wav', 1);

  const Sfx(this.file, this.maxPlayers);
  final String file;
  final int maxPlayers;
}

enum Haptic { light, medium, heavy }

/// 효과음과 진동. 설정 확인은 호출하는 쪽(UI)에서 한다.
abstract class FeedbackService {
  void play(Sfx sfx);
  void vibrate(Haptic h);
  void dispose() {}
}

/// 테스트·무음용.
class SilentFeedback implements FeedbackService {
  const SilentFeedback();
  @override
  void play(Sfx sfx) {}
  @override
  void vibrate(Haptic h) {}
  @override
  void dispose() {}
}

class AudioFeedback implements FeedbackService {
  final Map<Sfx, Future<AudioPool?>> _pools = {};
  final AudioCache _cache = AudioCache(prefix: 'assets/sfx/');

  Future<AudioPool?> _pool(Sfx sfx) => _pools[sfx] ??= _create(sfx);

  Future<AudioPool?> _create(Sfx sfx) async {
    try {
      return await AudioPool.create(
        source: AssetSource(sfx.file),
        maxPlayers: sfx.maxPlayers,
        audioCache: _cache,
      );
    } catch (e) {
      debugPrint('효과음 로드 실패 ${sfx.file}: $e');
      return null;
    }
  }

  /// 첫 재생 지연을 줄이기 위해 미리 불러온다.
  void preload() {
    for (final s in Sfx.values) {
      _pool(s);
    }
  }

  @override
  void play(Sfx sfx) {
    _start(sfx);
  }

  Future<void> _start(Sfx sfx) async {
    try {
      await (await _pool(sfx))?.start(volume: 0.8);
    } catch (e) {
      debugPrint('효과음 재생 실패 ${sfx.file}: $e');
    }
  }

  @override
  void vibrate(Haptic h) {
    switch (h) {
      case Haptic.light:
        HapticFeedback.lightImpact();
      case Haptic.medium:
        HapticFeedback.mediumImpact();
      case Haptic.heavy:
        HapticFeedback.heavyImpact();
    }
  }

  @override
  void dispose() {
    for (final f in _pools.values) {
      f.then((p) => p?.dispose());
    }
  }
}
