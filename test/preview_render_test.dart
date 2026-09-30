import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fruit_merge/game/board_painter.dart';
import 'package:fruit_merge/game/fruit_art.dart';
import 'package:fruit_merge/game/world.dart';

/// 과일 그림 미리보기: build/previews/fruits.png, build/previews/board.png (눈으로 확인용).
Future<void> _save(ui.Picture pic, int w, int h, String name) async {
  final img = await pic.toImage(w, h);
  final data = await img.toByteData(format: ui.ImageByteFormat.png);
  Directory('build/previews').createSync(recursive: true);
  File('build/previews/$name').writeAsBytesSync(data!.buffer.asUint8List());
}

void main() {
  test('render previews', () async {
    await TestAsyncUtils.guard(() async {
      var rec = ui.PictureRecorder();
      var canvas = Canvas(rec);
      canvas.drawRect(const Rect.fromLTWH(0, 0, 1200, 560), Paint()..color = const Color(0xFFFFF8E1));
      for (var l = 0; l <= maxLevel; l++) {
        final col = l % 6, row = l ~/ 6;
        drawFruit(canvas, l, Offset(100 + col * 200.0, 150 + row * 270.0), 80);
      }
      // 특수 과일: 무지개, 폭탄 (마지막 칸)
      drawPiece(canvas, pieceRainbow, const Offset(1100, 420), 80, time: 0.3);
      await _save(rec.endRecording(), 1200, 560, 'fruits.png');
      rec = ui.PictureRecorder();
      canvas = Canvas(rec);
      canvas.drawRect(const Rect.fromLTWH(0, 0, 1000, 260), Paint()..color = const Color(0xFFFFF8E1));
      drawPiece(canvas, pieceBomb, const Offset(120, 140), 80, time: 0.1);
      for (var hp = 3; hp >= 1; hp--) {
        drawPiece(canvas, pieceStone, Offset(340 + (3 - hp) * 200.0, 140), 80, hp: hp);
      }
      drawPiece(canvas, pieceRainbow, const Offset(900, 140), 80, time: 1.2);
      await _save(rec.endRecording(), 1000, 260, 'specials.png');

      final w = World(random: math.Random(5));
      const levels = [9, 7, 6, 5, pieceStone, 4, 4, 3, 3, 2, pieceRainbow, 1, 1, 0, 0, 8, 3, 2];
      var x = 120.0, y = 1200.0;
      for (final l in levels) {
        w.add(l, Offset(x, y));
        x += pieceRadius(l) * 2 + 20;
        if (x > 880) {
          x = 150;
          y -= 200;
        }
      }
      for (var i = 0; i < 600; i++) {
        w.step(1 / 60);
      }
      rec = ui.PictureRecorder();
      canvas = Canvas(rec);
      BoardPainter(world: w, fx: Effects(), time: 0, hammer: false, showAim: true).paint(canvas, const Size(500, 700));
      await _save(rec.endRecording(), 500, 700, 'board.png');
    });
  });
}
