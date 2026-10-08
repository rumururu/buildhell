import 'dart:math' as math;

import 'package:flutter/material.dart';

class _Particle {
  _Particle({
    required this.pos,
    required this.vel,
    required this.life,
    required this.size,
    required this.color,
    this.gravity = 0,
  }) : maxLife = life;

  Offset pos;
  Offset vel;
  double life;
  final double maxLife;
  final double size;
  final Color color;
  final double gravity;
}

/// 불씨·불꽃 파티클. 리빌드 없이 CustomPainter만 다시 그린다.
class ParticleSystem extends ChangeNotifier {
  ParticleSystem([math.Random? rng]) : _rng = rng ?? math.Random();

  final math.Random _rng;
  final List<_Particle> _ps = [];
  Size area = Size.zero;
  double _emberAcc = 0;

  /// 초당 바닥에서 피어오르는 불씨 수.
  double emberRate = 8;

  static const _emberColors = [
    Color(0xFFFF6D00),
    Color(0xFFFFAB40),
    Color(0xFFFF3D00),
    Color(0xFFFFD180),
  ];

  void tick(double dt) {
    if (area.isEmpty) return;
    _emberAcc += dt * emberRate;
    while (_emberAcc >= 1) {
      _emberAcc -= 1;
      _ps.add(
        _Particle(
          pos: Offset(_rng.nextDouble() * area.width, area.height + 4),
          vel: Offset(
            (_rng.nextDouble() - 0.5) * 20,
            -30 - _rng.nextDouble() * 50,
          ),
          life: 2 + _rng.nextDouble() * 2,
          size: 1.5 + _rng.nextDouble() * 2.5,
          color: _emberColors[_rng.nextInt(_emberColors.length)],
        ),
      );
    }
    for (final p in _ps) {
      p.vel = p.vel + Offset(math.sin(p.life * 3) * 4 * dt, p.gravity * dt);
      p.pos = p.pos + p.vel * dt;
      p.life -= dt;
    }
    _ps.removeWhere((p) => p.life <= 0);
    if (_ps.length > 300) _ps.removeRange(0, _ps.length - 300);
    notifyListeners();
  }

  /// 터치 지점에서 튀는 불꽃.
  void burst(Offset at, {int count = 8, bool critical = false}) {
    for (var i = 0; i < count; i++) {
      final a = _rng.nextDouble() * 2 * math.pi;
      final speed = (critical ? 160 : 90) + _rng.nextDouble() * 120;
      _ps.add(
        _Particle(
          pos: at,
          vel: Offset(math.cos(a), math.sin(a)) * speed,
          life: 0.4 + _rng.nextDouble() * 0.4,
          size: (critical ? 3 : 2) + _rng.nextDouble() * 2,
          color: critical
              ? (i.isEven ? const Color(0xFFFFEA00) : const Color(0xFFFF1744))
              : _emberColors[_rng.nextInt(_emberColors.length)],
          gravity: 300,
        ),
      );
    }
  }

  int get count => _ps.length;
}

class ParticlePainter extends CustomPainter {
  ParticlePainter(this.system) : super(repaint: system);

  final ParticleSystem system;
  final Paint _paint = Paint();

  @override
  void paint(Canvas canvas, Size size) {
    system.area = size;
    for (final p in system._ps) {
      final t = (p.life / p.maxLife).clamp(0.0, 1.0);
      _paint.color = p.color.withValues(alpha: t);
      canvas.drawCircle(p.pos, p.size * (0.5 + 0.5 * t), _paint);
    }
  }

  @override
  bool shouldRepaint(ParticlePainter oldDelegate) => false;
}
