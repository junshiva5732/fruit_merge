import 'dart:math' as math;
import 'dart:ui';

/// 과일 그림. 이미지 파일 없이 코드로 그린다: 동그란 몸 + 무늬 + 꼭지/잎 + 얼굴.
/// 물리 판정이 원이므로 모양은 항상 원에 꽉 차게 그린다.
class FruitStyle {
  final Color body;
  final Color dark;
  final Color light;
  const FruitStyle(this.body, this.dark, this.light);
}

const fruitStyles = <FruitStyle>[
  FruitStyle(Color(0xFFD81B60), Color(0xFF880E4F), Color(0xFFF48FB1)), // 0 체리
  FruitStyle(Color(0xFFF44336), Color(0xFFB71C1C), Color(0xFFFF8A80)), // 1 딸기
  FruitStyle(Color(0xFF8E24AA), Color(0xFF4A148C), Color(0xFFCE93D8)), // 2 포도
  FruitStyle(Color(0xFFFFA726), Color(0xFFE65100), Color(0xFFFFE0B2)), // 3 귤
  FruitStyle(Color(0xFFFF7043), Color(0xFFBF360C), Color(0xFFFFCCBC)), // 4 감
  FruitStyle(Color(0xFFE53935), Color(0xFF8E0000), Color(0xFFFFCDD2)), // 5 사과
  FruitStyle(Color(0xFFE6C75A), Color(0xFF9E7C1F), Color(0xFFFFF3C4)), // 6 배
  FruitStyle(Color(0xFFFF9E9E), Color(0xFFD35D6E), Color(0xFFFFE4E1)), // 7 복숭아
  FruitStyle(Color(0xFFFFCA28), Color(0xFFB8860B), Color(0xFFFFF59D)), // 8 파인애플
  FruitStyle(Color(0xFFAED581), Color(0xFF558B2F), Color(0xFFF1F8E9)), // 9 멜론
  FruitStyle(Color(0xFF43A047), Color(0xFF1B5E20), Color(0xFFA5D6A7)), // 10 수박
];

const _leaf = Color(0xFF43A047);
const _leafDark = Color(0xFF1B5E20);
const _stem = Color(0xFF6D4C41);
const _ink = Color(0xFF3E2723);

/// [c] 를 중심으로 반지름 [r] 인 [level] 과일을 그린다. [face] 가 false 면 얼굴 없이 (아주 작게 그릴 때).
void drawFruit(Canvas canvas, int level, Offset c, double r, {bool face = true, double opacity = 1}) {
  final s = fruitStyles[level];
  if (opacity < 1) {
    canvas.saveLayer(Rect.fromCircle(center: c, radius: r * 1.4), Paint()..color = Color.fromRGBO(0, 0, 0, opacity));
  }
  final body = Rect.fromCircle(center: c, radius: r);

  // 몸통: 위쪽 왼편이 밝은 방사형 그라데이션.
  canvas.drawCircle(
    c,
    r,
    Paint()
      ..shader = Gradient.radial(
        c.translate(-r * 0.35, -r * 0.4),
        r * 1.5,
        [s.light, s.body, s.dark],
        [0, 0.45, 1],
      ),
  );

  canvas.save();
  canvas.clipPath(Path()..addOval(body));
  _pattern(canvas, level, c, r, s);
  canvas.restore();

  // 테두리
  canvas.drawCircle(
    c,
    r - r * 0.03,
    Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = math.max(1.2, r * 0.06)
      ..color = s.dark.withValues(alpha: 0.85),
  );

  _topper(canvas, level, c, r);

  // 반짝이
  canvas.drawOval(
    Rect.fromCenter(center: c.translate(-r * 0.42, -r * 0.45), width: r * 0.34, height: r * 0.2),
    Paint()..color = const Color(0xB3FFFFFF),
  );

  if (face) _face(canvas, c, r, level);
  if (opacity < 1) canvas.restore();
}

/// 과일별 무늬 (몸통 안쪽에 잘려 그려진다).
void _pattern(Canvas canvas, int level, Offset c, double r, FruitStyle s) {
  final p = Paint();
  switch (level) {
    case 1: // 딸기 씨
      p.color = const Color(0xFFFFF59D);
      for (var i = 0; i < 12; i++) {
        final a = i * 2.4;
        final d = r * (0.25 + 0.55 * ((i * 37) % 10) / 10);
        canvas.drawOval(
          Rect.fromCenter(center: c + Offset(math.cos(a) * d, math.sin(a) * d + r * 0.1), width: r * 0.08, height: r * 0.13),
          p,
        );
      }
    case 2: // 포도 알
      p.color = s.dark.withValues(alpha: 0.35);
      for (final o in const [Offset(-0.45, 0.35), Offset(0.45, 0.35), Offset(0, 0.62), Offset(-0.55, -0.15), Offset(0.55, -0.15)]) {
        canvas.drawCircle(c + o * r, r * 0.3, p..style = PaintingStyle.stroke..strokeWidth = r * 0.05);
      }
    case 3: // 귤 껍질 점
    case 4:
      p.color = s.dark.withValues(alpha: 0.18);
      for (var i = 0; i < 16; i++) {
        final a = i * 1.7;
        final d = r * (0.3 + 0.6 * ((i * 53) % 10) / 10);
        canvas.drawCircle(c + Offset(math.cos(a) * d, math.sin(a) * d), r * 0.035, p);
      }
    case 6: // 배 점
      p.color = const Color(0xFF9E7C1F).withValues(alpha: 0.35);
      for (var i = 0; i < 22; i++) {
        final a = i * 2.1;
        final d = r * (0.2 + 0.75 * ((i * 29) % 10) / 10);
        canvas.drawCircle(c + Offset(math.cos(a) * d, math.sin(a) * d), r * 0.025, p);
      }
    case 7: // 복숭아 골
      canvas.drawArc(
        Rect.fromCenter(center: c.translate(r * 0.55, 0), width: r * 1.1, height: r * 1.9),
        math.pi * 0.6,
        math.pi * 0.8,
        false,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = r * 0.06
          ..color = s.dark.withValues(alpha: 0.45),
      );
    case 8: // 파인애플 격자
      final line = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = r * 0.05
        ..color = const Color(0xFFB8860B).withValues(alpha: 0.6);
      for (var k = -3; k <= 3; k++) {
        final x = c.dx + k * r * 0.4;
        canvas.drawLine(Offset(x - r, c.dy - r), Offset(x + r, c.dy + r), line);
        canvas.drawLine(Offset(x + r, c.dy - r), Offset(x - r, c.dy + r), line);
      }
    case 9: // 멜론 그물
      final net = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = r * 0.035
        ..color = const Color(0xFFF1F8E9).withValues(alpha: 0.8);
      for (var k = -4; k <= 4; k++) {
        final x = c.dx + k * r * 0.3;
        final path = Path()..moveTo(x, c.dy - r);
        for (var y = -1.0; y <= 1.0; y += 0.25) {
          path.lineTo(x + math.sin(y * 7 + k) * r * 0.06, c.dy + y * r);
        }
        canvas.drawPath(path, net);
      }
      for (var k = -4; k <= 4; k++) {
        final y = c.dy + k * r * 0.3;
        canvas.drawLine(Offset(c.dx - r, y), Offset(c.dx + r, y + math.cos(k.toDouble()) * r * 0.05), net);
      }
    case 10: // 수박 줄무늬
      final stripe = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = r * 0.12
        ..strokeCap = StrokeCap.round
        ..color = const Color(0xFF1B5E20);
      for (var k = -2; k <= 2; k++) {
        final x = c.dx + k * r * 0.42;
        final path = Path()..moveTo(x, c.dy - r);
        for (var y = -1.0; y <= 1.0; y += 0.1) {
          path.lineTo(x + k * r * 0.18 * (1 - y * y) + math.sin(y * 12) * r * 0.05, c.dy + y * r);
        }
        canvas.drawPath(path, stripe);
      }
  }
}

/// 꼭지 · 잎 · 왕관.
void _topper(Canvas canvas, int level, Offset c, double r) {
  final top = c.translate(0, -r * 0.92);
  final leaf = Paint()..color = _leaf;
  final leafEdge = Paint()
    ..style = PaintingStyle.stroke
    ..strokeWidth = math.max(1, r * 0.04)
    ..color = _leafDark;
  final stem = Paint()
    ..style = PaintingStyle.stroke
    ..strokeCap = StrokeCap.round
    ..strokeWidth = math.max(1.5, r * 0.09)
    ..color = _stem;

  Path leafPath(Offset base, double len, double angle) {
    final dir = Offset(math.cos(angle), math.sin(angle));
    final nrm = Offset(-dir.dy, dir.dx);
    final tip = base + dir * len;
    final mid = base + dir * (len * 0.5);
    return Path()
      ..moveTo(base.dx, base.dy)
      ..quadraticBezierTo((mid + nrm * len * 0.35).dx, (mid + nrm * len * 0.35).dy, tip.dx, tip.dy)
      ..quadraticBezierTo((mid - nrm * len * 0.35).dx, (mid - nrm * len * 0.35).dy, base.dx, base.dy);
  }

  switch (level) {
    case 0: // 체리: 휜 꼭지
      canvas.drawPath(
        Path()
          ..moveTo(top.dx, top.dy + r * 0.1)
          ..quadraticBezierTo(top.dx + r * 0.1, top.dy - r * 0.5, top.dx + r * 0.45, top.dy - r * 0.6),
        stem,
      );
      final l = leafPath(top.translate(r * 0.3, -r * 0.5), r * 0.55, -0.4);
      canvas.drawPath(l, leaf);
      canvas.drawPath(l, leafEdge);
    case 1: // 딸기: 초록 꽃받침
    case 4: // 감: 네 잎 꽃받침
      final n = level == 1 ? 5 : 4;
      for (var i = 0; i < n; i++) {
        // 꼭지에서 아래쪽으로 부채꼴로 펼쳐진 잎 (과일 윗면에 얹힌 모양)
        final a = math.pi / 2 + (i - (n - 1) / 2) * (level == 1 ? 0.7 : 0.9);
        final l = leafPath(top.translate(0, r * 0.1), r * (level == 1 ? 0.42 : 0.38), a);
        canvas.drawPath(l, leaf);
        canvas.drawPath(l, leafEdge);
      }
      canvas.drawCircle(top.translate(0, r * 0.05), r * 0.08, Paint()..color = _stem);
    case 8: // 파인애플: 뾰족한 잎 왕관
      for (var i = -2; i <= 2; i++) {
        final l = leafPath(top.translate(i * r * 0.08, r * 0.12), r * (0.55 - i.abs() * 0.08), -math.pi / 2 + i * 0.35);
        canvas.drawPath(l, leaf);
        canvas.drawPath(l, leafEdge);
      }
    case 10: // 수박: 꼭지만
      canvas.drawPath(
        Path()
          ..moveTo(top.dx, top.dy + r * 0.06)
          ..quadraticBezierTo(top.dx + r * 0.02, top.dy - r * 0.12, top.dx + r * 0.1, top.dy - r * 0.16),
        stem,
      );
    default: // 포도·귤·사과·배·복숭아·멜론: 꼭지 + 잎 하나
      canvas.drawLine(top.translate(0, r * 0.08), top.translate(r * 0.03, -r * 0.18), stem);
      final l = leafPath(top.translate(r * 0.02, -r * 0.1), r * 0.42, -0.5);
      canvas.drawPath(l, leaf);
      canvas.drawPath(l, leafEdge);
  }
}

/// 얼굴: 눈(하이라이트) + 입 + 볼터치. 큰 과일일수록 느긋한 표정.
void _face(Canvas canvas, Offset c, double r, int level) {
  final eyeY = c.dy + r * 0.02;
  final eyeDx = r * 0.3;
  final eyeR = r * 0.1;
  final ink = Paint()..color = _ink;
  final white = Paint()..color = const Color(0xFFFFFFFF);
  if (level >= 9) {
    // 멜론·수박: 웃는 눈 (^ ^)
    final p = Paint()
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = r * 0.055
      ..color = _ink;
    for (final sx in [-1, 1]) {
      canvas.drawArc(Rect.fromCircle(center: Offset(c.dx + sx * eyeDx, eyeY + eyeR * 0.5), radius: eyeR), math.pi * 1.1, math.pi * 0.8, false, p);
    }
  } else {
    for (final sx in [-1, 1]) {
      final e = Offset(c.dx + sx * eyeDx, eyeY);
      canvas.drawCircle(e, eyeR, ink);
      canvas.drawCircle(e.translate(-eyeR * 0.3, -eyeR * 0.35), eyeR * 0.38, white);
    }
  }
  // 볼
  final blush = Paint()..color = const Color(0x66FF5C8A);
  for (final sx in [-1, 1]) {
    canvas.drawOval(Rect.fromCenter(center: Offset(c.dx + sx * r * 0.48, eyeY + r * 0.2), width: r * 0.22, height: r * 0.12), blush);
  }
  // 입
  canvas.drawArc(
    Rect.fromCenter(center: Offset(c.dx, eyeY + r * 0.16), width: r * 0.22, height: r * 0.16),
    0.15,
    math.pi - 0.3,
    false,
    Paint()
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = math.max(1, r * 0.05)
      ..color = _ink,
  );
}
