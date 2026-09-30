import 'package:flutter/material.dart';

/// 아케이드풍 굵은 글자 + 진한 테두리. 어떤 하늘 색 위에서도 읽힌다.
class OutlinedText extends StatelessWidget {
  final String text;
  final double size;
  final Color color;
  final double strokeWidth;
  const OutlinedText(this.text, {super.key, required this.size, this.color = Colors.white, this.strokeWidth = 6});

  @override
  Widget build(BuildContext context) {
    final base = TextStyle(fontSize: size, fontWeight: FontWeight.w900, height: 1.1, letterSpacing: 0.5);
    return Stack(
      children: [
        Text(
          text,
          textAlign: TextAlign.center,
          style: base.copyWith(
            foreground: Paint()
              ..style = PaintingStyle.stroke
              ..strokeWidth = strokeWidth
              ..strokeJoin = StrokeJoin.round
              ..color = const Color(0xFF3E2723),
          ),
        ),
        Text(
          text,
          textAlign: TextAlign.center,
          style: base.copyWith(color: color),
        ),
      ],
    );
  }
}
