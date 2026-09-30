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

/// 점수 팝업 (+15, +30 ×2).
class Popup {
  final Offset pos;
  final String text;
  final bool big;
  double t = 0; // 0 → 1
  Popup(this.pos, this.text, {this.big = false});
}

/// 화면 효과 상태. 세계 이벤트를 받아 파티클/팝업/합쳐짐 애니메이션/흔들림을 만든다.
class Effects {
  final _rng = math.Random();
  final particles = <Particle>[];
  final popups = <Popup>[];

  /// 콤보 배너 (가운데 크게 "3 콤보!"). 배수와 진행도.
  int comboShown = 0;
  double comboT = 1;

  /// 화면 흔들림 세기 (폭탄). 0 이면 없음.
  double shake = 0;

  /// 방금 생긴 과일의 "뿅" 크기 애니메이션: 새 과일 위치 → 남은 시간.
  final pops = <(Offset, int), double>{};

  static const _stoneColors = [Color(0xFF90A4AE), Color(0xFF546E7A)];
  static const _boomColors = [Color(0xFFFF9800), Color(0xFFFFEB3B), Color(0xFFFF5722)];

  List<Color> _colors(int piece) => switch (piece) {
    pieceRainbow => const [Color(0xFFFF5252), Color(0xFFFFEB3B), Color(0xFF42A5F5), Color(0xFF66BB6A)],
    pieceBomb => _boomColors,
    pieceStone => _stoneColors,
    _ => [fruitStyles[piece].body, fruitStyles[piece].light],
  };

  void _burst(Offset pos, List<Color> colors, int n, double speed, double size) {
    for (var i = 0; i < n; i++) {
      final a = _rng.nextDouble() * math.pi * 2;
      final sp = speed * (0.6 + _rng.nextDouble() * 0.8);
      particles.add(
        Particle(
          pos,
          Offset(math.cos(a) * sp, math.sin(a) * sp - 200),
          colors[i % colors.length],
          size * (0.7 + _rng.nextDouble() * 0.8),
          0.5 + _rng.nextDouble() * 0.35,
        ),
      );
    }
  }

  void onEvent(WorldEvent e) {
    switch (e.type) {
      case EventType.merge:
      case EventType.bonus:
        final lv = e.piece;
        _burst(e.pos, _colors(lv), 10 + lv * 2, 350 + lv * 40, 10 + lv * 1.5);
        if (e.type == EventType.merge) pops[(e.pos, lv)] = 0.18;
        popups.add(Popup(e.pos, e.combo > 1 ? '+${e.points} ×${e.combo}' : '+${e.points}', big: e.combo > 1 || e.type == EventType.bonus));
        if (e.combo > 1) {
          comboShown = e.combo;
          comboT = 0;
        }
      case EventType.boom:
        _burst(e.pos, _boomColors, 36, 900, 18);
        shake = 1;
      case EventType.crumble:
        _burst(e.pos, _stoneColors, 18, 450, 14);
      case EventType.smash:
      case EventType.clear:
        _burst(e.pos, _colors(e.piece), 14, 400, 12);
      case EventType.drop:
        break;
    }
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
      p.t += dt / (p.big ? 1.2 : 0.9);
    }
    popups.removeWhere((p) => p.t >= 1);
    pops.updateAll((_, v) => v - dt);
    pops.removeWhere((_, v) => v <= 0);
    comboT = math.min(1, comboT + dt / 1.1);
    shake = math.max(0, shake - dt * 2.5);
  }

  void clear() {
    particles.clear();
    popups.clear();
    pops.clear();
    comboT = 1;
    shake = 0;
  }

  /// 새로 합쳐진 과일은 잠깐 작게 시작해 커진다.
  double scaleFor(Fruit f) {
    if (f.kind != FruitKind.normal) return 1;
    for (final e in pops.entries) {
      if (e.key.$2 == f.level && (e.key.$1 - f.pos).distance < f.r) {
        final t = 1 - e.value / 0.18;
        return 0.7 + 0.3 * Curves.easeOutBack.transform(t.clamp(0, 1));
      }
    }
    return 1;
  }

  /// 흔들림 오프셋 (화면 픽셀).
  Offset shakeOffset(double time) =>
      shake <= 0 ? Offset.zero : Offset(math.sin(time * 70) * 10 * shake, math.cos(time * 55) * 8 * shake);
}

/// 상자 · 선 · 조준선 · 과일 · 효과를 그린다. 월드 좌표(1000x1400)를 화면에 맞춰 늘린다.
class BoardPainter extends CustomPainter {
  final World world;
  final Effects fx;
  final double time;
  final bool hammer;
  final bool showAim;
  final String comboLabel;

  BoardPainter({
    required this.world,
    required this.fx,
    required this.time,
    required this.hammer,
    required this.showAim,
    this.comboLabel = 'COMBO',
    super.repaint,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final sc = size.width / World.width;
    canvas.save();
    canvas.translate(fx.shakeOffset(time).dx, fx.shakeOffset(time).dy);
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

    // 조준선 + 떨어뜨릴 과일 + 자동 낙하 카운트다운
    if (showAim && !world.over) {
      final r = pieceRadius(world.current);
      final c = Offset(world.dropX, World.dropY);
      final ready = world.canDrop && !hammer;
      if (ready) {
        final guide = Paint()
          ..color = const Color(0x33A1887F)
          ..strokeWidth = 6;
        for (var y = World.dropY + r + 10; y < World.height; y += 40) {
          canvas.drawLine(Offset(world.dropX, y), Offset(world.dropX, y + 20), guide);
        }
      }
      final left = world.autoDropLeft;
      if (ready && left != null && left < 3) {
        final frac = left / 3;
        final ring = Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 9
          ..strokeCap = StrokeCap.round
          ..color = Color.lerp(const Color(0xFFE53935), const Color(0xFFFFA726), frac)!;
        canvas.drawCircle(c, r + 14, Paint()..color = const Color(0x22E53935));
        canvas.drawArc(Rect.fromCircle(center: c, radius: r + 14), -math.pi / 2, math.pi * 2 * frac, false, ring);
      }
      drawPiece(canvas, world.current, c, r, opacity: ready ? 1 : 0.4, time: time);
    }

    // 과일
    for (final f in world.fruits) {
      final s = fx.scaleFor(f);
      drawPiece(canvas, f.piece, f.pos, f.r * s, hp: f.hp, time: time);
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
      _text(
        canvas,
        p.text,
        p.pos.translate(0, -120 * Curves.easeOut.transform(p.t)),
        size: p.big ? 76 : 64,
        color: (p.big ? const Color(0xFFFFEB3B) : Colors.white).withValues(alpha: 1 - p.t * p.t),
        shadow: const Color(0xFF6D4C41).withValues(alpha: 1 - p.t),
      );
    }

    // 콤보 배너
    if (fx.comboT < 1) {
      final t = fx.comboT;
      final pop = Curves.elasticOut.transform((t * 2.5).clamp(0.0, 1.0));
      final alpha = t > 0.75 ? (1 - t) / 0.25 : 1.0;
      canvas.save();
      canvas.translate(World.width / 2, World.lineY + 170);
      canvas.scale(0.6 + 0.4 * pop);
      canvas.rotate(-0.06);
      _text(
        canvas,
        '${fx.comboShown} $comboLabel!',
        Offset.zero,
        size: 120,
        color: Color.lerp(const Color(0xFFFF7043), const Color(0xFFE91E63), (fx.comboShown - 2) / 3)!.withValues(alpha: alpha),
        shadow: Colors.white.withValues(alpha: alpha),
        shadowOffset: const Offset(0, 0),
        outline: true,
      );
      canvas.restore();
    }
    canvas.restore();
  }

  void _text(
    Canvas canvas,
    String text,
    Offset center, {
    required double size,
    required Color color,
    required Color shadow,
    Offset shadowOffset = const Offset(3, 4),
    bool outline = false,
  }) {
    TextPainter build(TextStyle style) =>
        TextPainter(text: TextSpan(text: text, style: style), textDirection: TextDirection.ltr)..layout();
    final base = TextStyle(fontSize: size, fontWeight: FontWeight.w900);
    if (outline) {
      final stroke = build(
        base.copyWith(
          foreground: Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = size * 0.16
            ..strokeJoin = StrokeJoin.round
            ..color = shadow,
        ),
      );
      stroke.paint(canvas, center.translate(-stroke.width / 2, -stroke.height / 2));
    }
    final tp = build(base.copyWith(color: color, shadows: outline ? null : [Shadow(color: shadow, offset: shadowOffset)]));
    tp.paint(canvas, center.translate(-tp.width / 2, -tp.height / 2));
  }

  @override
  bool shouldRepaint(BoardPainter old) => true;
}

/// 작은 과일 하나 (다음 과일 미리보기·진화표용). [piece] 는 과일 단계 또는 특수 과일 번호.
class FruitIcon extends StatelessWidget {
  final int piece;
  final double size;
  final bool face;
  const FruitIcon(this.piece, {super.key, required this.size, this.face = true});

  @override
  Widget build(BuildContext context) => SizedBox.square(dimension: size, child: CustomPaint(painter: _FruitIconPainter(piece, face)));
}

class _FruitIconPainter extends CustomPainter {
  final int piece;
  final bool face;
  _FruitIconPainter(this.piece, this.face);

  @override
  void paint(Canvas canvas, Size size) {
    // 꼭지·잎·심지가 원 밖으로 나오므로 조금 작게.
    drawPiece(canvas, piece, size.center(Offset.zero).translate(0, size.height * 0.08), size.width * 0.36, face: face);
  }

  @override
  bool shouldRepaint(_FruitIconPainter old) => old.piece != piece || old.face != face;
}
