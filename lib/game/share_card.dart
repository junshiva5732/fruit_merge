import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import 'fruit_art.dart';
import 'world.dart';

/// 자랑하기용 점수 카드 (1080x1350, 인스타 4:5 에도 맞음). 이미지 파일 없이 코드로 그린다.
class ShareCard {
  static const width = 1080.0;
  static const height = 1350.0;

  final String title;

  /// "무한 모드 기록" / "스테이지 12 클리어"
  final String label;
  final int score;
  final int stars;
  final int fruit;

  /// 아래쪽 한 줄 ("나를 이길 수 있어?")
  final String callToAction;

  const ShareCard({
    required this.title,
    required this.label,
    required this.score,
    required this.stars,
    required this.fruit,
    required this.callToAction,
  });

  Future<Uint8List> toPng() async {
    final rec = ui.PictureRecorder();
    paint(Canvas(rec));
    final img = await rec.endRecording().toImage(width.toInt(), height.toInt());
    final data = await img.toByteData(format: ui.ImageByteFormat.png);
    return data!.buffer.asUint8List();
  }

  void paint(Canvas canvas) {
    const rect = Rect.fromLTWH(0, 0, width, height);
    canvas.drawRect(
      rect,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFFFFE0B2), Color(0xFFFFAB91), Color(0xFFFF8A65)],
        ).createShader(rect),
    );
    // 배경 물방울
    final bubble = Paint()..color = const Color(0x22FFFFFF);
    final rng = math.Random(5);
    for (var i = 0; i < 14; i++) {
      canvas.drawCircle(Offset(rng.nextDouble() * width, rng.nextDouble() * height), 40 + rng.nextDouble() * 120, bubble);
    }

    _text(canvas, title, const Offset(width / 2, 120), size: 92);

    // 가장 큰 과일 + 뒤쪽 햇살
    const c = Offset(width / 2, 520);
    final rays = Paint()..color = const Color(0x33FFFFFF);
    for (var i = 0; i < 12; i++) {
      final a = i * math.pi / 6;
      canvas.drawPath(
        Path()
          ..moveTo(c.dx, c.dy)
          ..lineTo(c.dx + math.cos(a - 0.12) * 420, c.dy + math.sin(a - 0.12) * 420)
          ..lineTo(c.dx + math.cos(a + 0.12) * 420, c.dy + math.sin(a + 0.12) * 420)
          ..close(),
        rays,
      );
    }
    drawFruit(canvas, fruit.clamp(0, maxLevel), c.translate(0, 20), 220);

    _text(canvas, label, const Offset(width / 2, 830), size: 58, color: const Color(0xFF5D4037), outline: false);
    _text(canvas, _comma(score), const Offset(width / 2, 935), size: 160, color: Colors.white);

    if (stars > 0) {
      for (var i = 0; i < 3; i++) {
        _star(canvas, Offset(width / 2 + (i - 1) * 130, 1110 - (i == 1 ? 12 : 0)), i == 1 ? 58 : 48, i < stars);
      }
    }

    // 아래쪽 알약 버튼 모양
    const pill = Rect.fromLTWH(140, 1180, width - 280, 120);
    canvas.drawRRect(RRect.fromRectAndRadius(pill, const Radius.circular(60)), Paint()..color = Colors.white);
    canvas.drawRRect(
      RRect.fromRectAndRadius(pill, const Radius.circular(60)),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 8
        ..color = const Color(0xFFFF7043),
    );
    _text(canvas, callToAction, pill.center, size: 56, color: const Color(0xFFFF5722), outline: false, maxWidth: pill.width - 60);
  }

  static String _comma(int n) => n.toString().replaceAllMapped(RegExp(r'\B(?=(\d{3})+(?!\d))'), (_) => ',');

  void _star(Canvas canvas, Offset c, double r, bool on) {
    final path = Path();
    for (var i = 0; i < 10; i++) {
      final rr = i.isEven ? r : r * 0.45;
      final a = -math.pi / 2 + i * math.pi / 5;
      final p = c + Offset(math.cos(a) * rr, math.sin(a) * rr);
      i == 0 ? path.moveTo(p.dx, p.dy) : path.lineTo(p.dx, p.dy);
    }
    path.close();
    canvas.drawPath(path, Paint()..color = on ? const Color(0xFFFFC107) : const Color(0x33000000));
    canvas.drawPath(
      path,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 8
        ..strokeJoin = StrokeJoin.round
        ..color = on ? const Color(0xFFE65100) : const Color(0x22000000),
    );
  }

  void _text(
    Canvas canvas,
    String text,
    Offset center, {
    required double size,
    Color color = Colors.white,
    bool outline = true,
    double maxWidth = width - 80,
  }) {
    TextPainter build(TextStyle style) => TextPainter(
      text: TextSpan(text: text, style: style),
      textDirection: TextDirection.ltr,
      textAlign: TextAlign.center,
      maxLines: 1,
      ellipsis: '…',
    )..layout(maxWidth: maxWidth);
    var base = TextStyle(fontSize: size, fontWeight: FontWeight.w900, height: 1.1);
    // 너무 길면 줄인다.
    var probe = build(base.copyWith(color: color));
    if (probe.didExceedMaxLines || probe.width > maxWidth) {
      base = base.copyWith(fontSize: size * maxWidth / (probe.width + 1) * 0.95);
    }
    if (outline) {
      final stroke = build(
        base.copyWith(
          foreground: Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = size * 0.14
            ..strokeJoin = StrokeJoin.round
            ..color = const Color(0xFF5D4037),
        ),
      );
      stroke.paint(canvas, center.translate(-stroke.width / 2, -stroke.height / 2));
    }
    probe = build(base.copyWith(color: color));
    probe.paint(canvas, center.translate(-probe.width / 2, -probe.height / 2));
  }
}
