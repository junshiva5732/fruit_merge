// 앱 아이콘 원본 생성: flutter test tool/icon_test.dart → assets/icon/icon.png, icon_fg.png
// 그 다음: dart run flutter_launcher_icons
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fruit_merge/game/fruit_art.dart';

Future<void> _save(ui.Picture pic, int size, String path) async {
  final img = await pic.toImage(size, size);
  final data = await img.toByteData(format: ui.ImageByteFormat.png);
  File(path).writeAsBytesSync(data!.buffer.asUint8List());
}

/// 수박(가운데) + 복숭아·체리. [scale] 은 적응형 아이콘 안전 영역(66%)에 맞추기 위한 축소 비율.
void _fruits(Canvas c, double s, double scale) {
  c.save();
  c.translate(s / 2, s / 2);
  c.scale(scale);
  c.translate(-s / 2, -s / 2);
  drawFruit(c, 7, Offset(s * 0.27, s * 0.66), s * 0.17);
  drawFruit(c, 10, Offset(s * 0.56, s * 0.58), s * 0.3);
  drawFruit(c, 0, Offset(s * 0.3, s * 0.3), s * 0.1);
  c.restore();
}

void main() {
  test('make icon', () async {
    await TestAsyncUtils.guard(() async {
      const s = 1024.0;
      Directory('assets/icon').createSync(recursive: true);

      var rec = ui.PictureRecorder();
      var c = Canvas(rec);
      c.drawRect(
        const Rect.fromLTWH(0, 0, s, s),
        Paint()
          ..shader = ui.Gradient.radial(const Offset(s * 0.4, s * 0.3), s * 0.9, const [Color(0xFFFFE0B2), Color(0xFFFFB74D), Color(0xFFFF8A65)], const [0, 0.55, 1]),
      );
      _fruits(c, s, 1);
      await _save(rec.endRecording(), s.toInt(), 'assets/icon/icon.png');

      rec = ui.PictureRecorder();
      c = Canvas(rec);
      _fruits(c, s, 0.72);
      await _save(rec.endRecording(), s.toInt(), 'assets/icon/icon_fg.png');
    });
  });
}
