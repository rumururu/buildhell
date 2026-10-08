import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import '../game/game_state.dart';
import '../game/numbers.dart';
import '../services/sound_service.dart';
import 'game_scope.dart';
import 'particles.dart';

/// 화면 중앙의 "형벌 집행" 영역. 아무 곳이나 터치하면 영혼을 얻는다.
class TapArea extends StatefulWidget {
  const TapArea({super.key});

  @override
  State<TapArea> createState() => _TapAreaState();
}

class _Floater {
  _Floater(this.id, this.position, this.text, this.critical);
  final int id;
  final Offset position;
  final String text;
  final bool critical;
}

class _TapAreaState extends State<TapArea> with TickerProviderStateMixin {
  late final AnimationController _pulse = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 140),
  );
  late final AnimationController _flame = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 2),
  )..repeat();
  late final AnimationController _shake = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 320),
  );
  final ParticleSystem _particles = ParticleSystem();
  late final Ticker _particleTicker;
  Duration _lastTick = Duration.zero;

  final List<_Floater> _floaters = [];
  int _nextId = 0;
  int _sinnerIndex = 0;

  static const _sinners = ['😱', '😭', '😵', '🥵', '🥶', '😖'];

  @override
  void initState() {
    super.initState();
    _particleTicker = createTicker((elapsed) {
      final dt = ((elapsed - _lastTick).inMicroseconds / 1e6).clamp(0.0, 0.1);
      _lastTick = elapsed;
      _particles.tick(dt);
    })..start();
  }

  @override
  void dispose() {
    _particleTicker.dispose();
    _particles.dispose();
    _pulse.dispose();
    _flame.dispose();
    _shake.dispose();
    super.dispose();
  }

  void _onTap(Offset localPosition) {
    final scope = GameScope.of(context);
    final result = scope.state.tap();
    _pulse.forward(from: 0);
    if (result.critical) {
      _shake.forward(from: 0);
      scope.sfx(Sfx.crit);
      scope.haptic(Haptic.heavy);
    } else {
      scope.sfx(Sfx.tap);
      scope.haptic(Haptic.light);
    }
    _particles.burst(
      localPosition,
      count: result.critical ? 24 : 7,
      critical: result.critical,
    );
    setState(() {
      _sinnerIndex = (_sinnerIndex + 1) % _sinners.length;
      _floaters.add(
        _Floater(
          _nextId++,
          localPosition,
          result.critical
              ? '치명타! +${formatNumber(result.amount)}'
              : '+${formatNumber(result.amount)}',
          result.critical,
        ),
      );
      if (_floaters.length > 25) _floaters.removeAt(0);
    });
  }

  void _removeFloater(int id) {
    if (!mounted) return;
    setState(() => _floaters.removeWhere((f) => f.id == id));
  }

  void _catchEscapee() {
    final scope = GameScope.of(context);
    final result = scope.state.catchEscapee();
    if (result == null) return;
    scope.sfx(result.isFrenzy ? Sfx.frenzy : Sfx.catchEscapee);
    scope.haptic(Haptic.medium);
    final gem = result.gems > 0 ? '  💎+${result.gems}' : '';
    scope.showToast(
      result.isFrenzy
          ? '🔥 지옥불 폭주! ${result.frenzySeconds.toInt()}초간 생산 x${GameState.frenzyMultiplier.toInt()}$gem'
          : '⛓️ 탈옥수 체포! 포상금 영혼 ${formatNumber(result.amount)}$gem',
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = GameScope.of(context).state;
    _particles.emberRate = state.isFrenzy ? 30 : 8;
    return LayoutBuilder(
      builder: (context, constraints) {
        final w = constraints.maxWidth;
        final h = constraints.maxHeight;
        final pitSize = math.min(w, h) * 0.6;
        final escapee = state.escapee;
        final hint = state.goalHint;

        return ClipRect(
          child: AnimatedBuilder(
            animation: _shake,
            builder: (context, child) {
              final v = _shake.value;
              final dx = math.sin(v * math.pi * 10) * (1 - v) * 7;
              return Transform.translate(offset: Offset(dx, 0), child: child);
            },
            child: Stack(
              children: [
                // 배경 + 터치 판정 (가장 아래 레이어)
                Positioned.fill(
                  child: Listener(
                    key: const Key('tapArea'),
                    behavior: HitTestBehavior.opaque,
                    onPointerDown: (e) => _onTap(e.localPosition),
                    child: AnimatedBuilder(
                      animation: _flame,
                      builder: (context, _) {
                        final glow =
                            0.5 + 0.5 * math.sin(_flame.value * 2 * math.pi);
                        return DecoratedBox(
                          decoration: BoxDecoration(
                            gradient: RadialGradient(
                              center: const Alignment(0, 0.3),
                              radius: 1.1,
                              colors: [
                                Color.lerp(
                                  const Color(0xFF7A1A05),
                                  const Color(0xFFB33A0A),
                                  state.isFrenzy ? 1 : glow * 0.4,
                                )!,
                                const Color(0xFF2A0606),
                                const Color(0xFF120606),
                              ],
                              stops: const [0, 0.6, 1],
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ),
                Positioned.fill(
                  child: IgnorePointer(
                    child: CustomPaint(painter: ParticlePainter(_particles)),
                  ),
                ),
                // 가마솥(중앙)
                Center(
                  child: IgnorePointer(
                    child: AnimatedBuilder(
                      animation: Listenable.merge([_pulse, _flame]),
                      builder: (context, _) {
                        final v = _pulse.value;
                        final squash = 1 - 0.1 * (1 - (2 * v - 1).abs());
                        final wobble =
                            math.sin(_flame.value * 2 * math.pi) * 0.03;
                        return Transform.scale(
                          scale: squash,
                          child: Transform.rotate(
                            angle: wobble,
                            child: _Pit(
                              size: pitSize,
                              sinner: _sinners[_sinnerIndex],
                              frenzy: state.isFrenzy,
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ),
                // 상단: 안내 목표 / 효과 배지
                Positioned(
                  top: 6,
                  left: 8,
                  right: 8,
                  child: IgnorePointer(
                    child: Column(
                      children: [
                        if (hint != null) _Banner(text: '🎯 $hint'),
                        Wrap(
                          spacing: 6,
                          alignment: WrapAlignment.center,
                          children: [
                            if (state.isFrenzy)
                              _Badge(
                                color: Colors.deepOrange,
                                text:
                                    '🔥 폭주 x${GameState.frenzyMultiplier.toInt()} '
                                    '${state.frenzyRemaining.ceil()}초',
                              ),
                            if (state.isAdBoosted)
                              _Badge(
                                color: Colors.purple,
                                text:
                                    '😈 악마의 계약 x2 '
                                    '${formatDuration(Duration(seconds: state.adBoostRemaining.ceil()))}',
                              ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                if (hint == null)
                  Positioned(
                    left: 0,
                    right: 0,
                    bottom: 6,
                    child: IgnorePointer(
                      child: Text(
                        '터치해서 형벌 집행!',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.45),
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ),
                // 떠오르는 숫자
                for (final f in _floaters)
                  _FloatingText(
                    key: ValueKey(f.id),
                    position: f.position,
                    text: f.text,
                    critical: f.critical,
                    onDone: () => _removeFloater(f.id),
                  ),
                // 탈옥수 (터치 영역보다 위)
                if (escapee != null)
                  Positioned(
                    left: escapee.x * w - 32,
                    top: escapee.y * h - 32,
                    child: _EscapeeWidget(
                      life: escapee.life,
                      onTap: _catchEscapee,
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _Banner extends StatelessWidget {
  const _Banner({required this.text});
  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 4),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.amber.withValues(alpha: 0.5)),
      ),
      child: Text(
        text,
        textAlign: TextAlign.center,
        style: const TextStyle(fontSize: 12, color: Colors.amberAccent),
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  const _Badge({required this.color, required this.text});
  final Color color;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.85),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        text,
        style: const TextStyle(
          fontWeight: FontWeight.bold,
          color: Colors.white,
          fontSize: 12,
        ),
      ),
    );
  }
}

class _Pit extends StatelessWidget {
  const _Pit({required this.size, required this.sinner, required this.frenzy});

  final double size;
  final String sinner;
  final bool frenzy;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Container(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: frenzy
                    ? const [
                        Color(0xFFFFF176),
                        Color(0xFFFF6D00),
                        Color(0xFFB71C1C),
                      ]
                    : const [
                        Color(0xFFFFA726),
                        Color(0xFFD84315),
                        Color(0xFF4E0D0D),
                      ],
                stops: const [0, 0.55, 1],
              ),
              boxShadow: [
                BoxShadow(
                  color: (frenzy ? Colors.orangeAccent : Colors.deepOrange)
                      .withValues(alpha: 0.6),
                  blurRadius: size * 0.25,
                  spreadRadius: size * 0.02,
                ),
              ],
            ),
          ),
          Text(sinner, style: TextStyle(fontSize: size * 0.38)),
          Positioned(
            bottom: size * 0.04,
            child: Text('🔥🔥🔥', style: TextStyle(fontSize: size * 0.14)),
          ),
          Positioned(
            top: size * 0.02,
            right: size * 0.06,
            child: Text('😈', style: TextStyle(fontSize: size * 0.18)),
          ),
        ],
      ),
    );
  }
}

class _FloatingText extends StatefulWidget {
  const _FloatingText({
    super.key,
    required this.position,
    required this.text,
    required this.critical,
    required this.onDone,
  });

  final Offset position;
  final String text;
  final bool critical;
  final VoidCallback onDone;

  @override
  State<_FloatingText> createState() => _FloatingTextState();
}

class _FloatingTextState extends State<_FloatingText>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: Duration(milliseconds: widget.critical ? 1100 : 800),
  )..forward().whenComplete(widget.onDone);

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final crit = widget.critical;
    return AnimatedBuilder(
      animation: _c,
      builder: (context, child) {
        // 치명타는 처음에 크게 튀어나왔다가 줄어든다.
        final pop = crit ? 1 + 0.6 * math.max(0, 1 - _c.value * 4) : 1.0;
        return Positioned(
          left: widget.position.dx - 90,
          top: widget.position.dy - 24 - 60 * _c.value,
          width: 180,
          child: IgnorePointer(
            child: Opacity(
              opacity: 1 - _c.value,
              child: Transform.scale(scale: pop, child: child),
            ),
          ),
        );
      },
      child: Text(
        widget.text,
        textAlign: TextAlign.center,
        style: TextStyle(
          color: crit ? const Color(0xFFFF5252) : Colors.amberAccent,
          fontWeight: FontWeight.w900,
          fontSize: crit ? 26 : 20,
          shadows: const [Shadow(blurRadius: 4, color: Colors.black)],
        ),
      ),
    );
  }
}

class _EscapeeWidget extends StatefulWidget {
  const _EscapeeWidget({required this.life, required this.onTap});

  final double life;
  final VoidCallback onTap;

  @override
  State<_EscapeeWidget> createState() => _EscapeeWidgetState();
}

class _EscapeeWidgetState extends State<_EscapeeWidget>
    with SingleTickerProviderStateMixin {
  late final AnimationController _bounce = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 500),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _bounce.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final fraction = (widget.life / GameState.escapeeLifetime).clamp(0.0, 1.0);
    return GestureDetector(
      key: const Key('escapee'),
      behavior: HitTestBehavior.opaque,
      onTap: widget.onTap,
      child: AnimatedBuilder(
        animation: _bounce,
        builder: (context, child) => Transform.translate(
          offset: Offset(0, -8 * _bounce.value),
          child: child,
        ),
        child: SizedBox(
          width: 64,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('🏃', style: TextStyle(fontSize: 36, height: 1.1)),
              const Text(
                '탈옥수!',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: Colors.yellowAccent,
                ),
              ),
              const SizedBox(height: 2),
              LinearProgressIndicator(
                value: fraction,
                minHeight: 3,
                color: Colors.yellowAccent,
                backgroundColor: Colors.black45,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
