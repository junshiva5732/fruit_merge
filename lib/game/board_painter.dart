import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'fruit_art.dart';
import 'world.dart';

/// 합쳐질 때 튀는 조각.
class Particle {
  Offset pos;
  Offset vel;
  final Color color;
  final double size;
  double life; // 남은 시간(초)
  final double maxLife;
  Particle(this.pos, this.vel, this.color, this.size, this.life) : maxLife = life;
}

/// 점수 팝업 (+15).
class Popup {
  final Offset pos;
  final String text;
  double t = 0; // 0 → 1
  Popup(this.pos, this.text);
}

/// 화면 효과 상태. 세계 이벤트를 받아 파티클/팝업/합쳐짐 애니메이션을 만든다.
class Effects {
  final _rng = math.Random();
  final particles = <Particle>[];
  final popups = <Popup>[];

  /// 방금 생긴 과일의 "뿅" 크기 애니메이션: 과일 id 가 아닌 위치로 찾기 어렵기 때문에
  /// 새 과일 위치 → 남은 시간.
  final pops = <(Offset, int), double>{};

  void onEvent(WorldEvent e) {
    final style = fruitStyles[e.level];
    final n = e.removed ? 14 : 10 + e.level * 2;
    for (var i = 0; i < n; i++) {
      final a = _rng.nextDouble() * math.pi * 2;
      final sp = 250 + _rng.nextDouble() * (350 + e.level * 40);
      particles.add(
        Particle(
          e.pos,
          Offset(math.cos(a) * sp, math.sin(a) * sp - 200),
          i.isEven ? style.body : style.light,
          8 + _rng.nextDouble() * (8 + e.level * 1.5),
          0.5 + _rng.nextDouble() * 0.35,
        ),
      );
    }
    if (e.points > 0) popups.add(Popup(e.pos, '+${e.points}'));
    if (!e.removed) pops[(e.pos, e.level)] = 0.18;
  }

  void step(double dt) {
    for (final p in particles) {
      p
        ..life -= dt
        ..vel = Offset(p.vel.dx * (1 - 2 * dt), p.vel.dy + 1800 * dt)
        ..pos += p.vel * dt;
    }
    particles.removeWhere((p) => p.life <= 0);
    for (final p in popups) {
      p.t += dt / 0.9;
    }
    popups.removeWhere((p) => p.t >= 1);
    pops.updateAll((_, v) => v - dt);
    pops.removeWhere((_, v) => v <= 0);
  }

  /// 새로 합쳐진 과일은 잠깐 작게 시작해 커진다.
  double scaleFor(Fruit f) {
    for (final e in pops.entries) {
      if (e.key.$2 == f.level && (e.key.$1 - f.pos).distance < f.r) {
        final t = 1 - e.value / 0.18;
        return 0.7 + 0.3 * Curves.easeOutBack.transform(t.clamp(0, 1));
      }
    }
    return 1;
  }
}

/// 상자 · 선 · 조준선 · 과일 · 효과를 그린다. 월드 좌표(1000x1400)를 화면에 맞춰 늘린다.
class BoardPainter extends CustomPainter {
  final World world;
  final Effects fx;
  final double time;
  final bool hammer;
  final bool showAim;

  BoardPainter({required this.world, required this.fx, required this.time, required this.hammer, required this.showAim, super.repaint});

  @override
  void paint(Canvas canvas, Size size) {
    final sc = size.width / World.width;
    canvas.save();
    canvas.scale(sc);
    const box = Rect.fromLTWH(0, 0, World.width, World.height);
    final rbox = RRect.fromRectAndRadius(box, const Radius.circular(36));

    // 상자 안쪽
    canvas.drawRRect(
      rbox,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFFFFF8E1), Color(0xFFFFE0B2)],
        ).createShader(box),
    );
    canvas.save();
    canvas.clipRRect(rbox);

    // 위험선
    final dangerOn = world.inDanger;
    final blink = dangerOn && (time * 6).floor().isEven;
    final linePaint = Paint()
      ..color = dangerOn ? (blink ? const Color(0xFFE53935) : const Color(0x66E53935)) : const Color(0x55BF360C)
      ..strokeWidth = dangerOn ? 8 : 5;
    for (var x = 16.0; x < World.width; x += 48) {
      canvas.drawLine(Offset(x, World.lineY), Offset(x + 26, World.lineY), linePaint);
    }

    // 조준선 + 떨어뜨릴 과일
    if (showAim && !world.over) {
      final r = fruitRadii[world.current];
      if (world.canDrop && !hammer) {
        final guide = Paint()
          ..color = const Color(0x40FFFFFF)
          ..strokeWidth = 6;
        for (var y = World.dropY + r + 10; y < World.height; y += 40) {
          canvas.drawLine(Offset(world.dropX, y), Offset(world.dropX, y + 20), guide..color = const Color(0x33A1887F));
        }
      }
      drawFruit(canvas, world.current, Offset(world.dropX, World.dropY), r, opacity: world.canDrop && !hammer ? 1 : 0.4);
    }

    // 과일
    for (final f in world.fruits) {
      final s = fx.scaleFor(f);
      drawFruit(canvas, f.level, f.pos, f.r * s);
      if (hammer) {
        canvas.drawCircle(
          f.pos,
          f.r * s,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 5
            ..color = Color.fromRGBO(255, 255, 255, 0.5 + 0.4 * math.sin(time * 8)),
        );
      }
    }

    // 파티클
    for (final p in fx.particles) {
      final a = (p.life / p.maxLife).clamp(0.0, 1.0);
      canvas.drawCircle(p.pos, p.size * (0.4 + 0.6 * a), Paint()..color = p.color.withValues(alpha: a));
    }
    canvas.restore();

    // 테두리
    canvas.drawRRect(
      rbox.deflate(4),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 10
        ..color = const Color(0xFFA1887F),
    );

    // 점수 팝업
    for (final p in fx.popups) {
      final tp = TextPainter(
        text: TextSpan(
          text: p.text,
          style: TextStyle(
            fontSize: 64,
            fontWeight: FontWeight.w900,
            color: Colors.white.withValues(alpha: 1 - p.t * p.t),
            shadows: [Shadow(color: const Color(0xFF6D4C41).withValues(alpha: 1 - p.t), blurRadius: 0, offset: const Offset(3, 4))],
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, p.pos.translate(-tp.width / 2, -tp.height / 2 - 120 * Curves.easeOut.transform(p.t)));
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(BoardPainter old) => true;
}

/// 작은 과일 하나 (다음 과일 미리보기·진화표용).
class FruitIcon extends StatelessWidget {
  final int level;
  final double size;
  final bool face;
  const FruitIcon(this.level, {super.key, required this.size, this.face = true});

  @override
  Widget build(BuildContext context) => SizedBox.square(dimension: size, child: CustomPaint(painter: _FruitIconPainter(level, face)));
}

class _FruitIconPainter extends CustomPainter {
  final int level;
  final bool face;
  _FruitIconPainter(this.level, this.face);

  @override
  void paint(Canvas canvas, Size size) {
    // 꼭지·잎이 원 밖으로 나오므로 조금 작게.
    drawFruit(canvas, level, size.center(Offset.zero).translate(0, size.height * 0.08), size.width * 0.36, face: face);
  }

  @override
  bool shouldRepaint(_FruitIconPainter old) => old.level != level || old.face != face;
}
