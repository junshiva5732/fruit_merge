// 스테이지 밸런스 측정: 간단한 자동 플레이로 각 스테이지를 여러 번 돌려
// 목표 달성률과 추천 목표치/과일 수를 출력한다.
// 실행: flutter test tool/balance_test.dart   (몇 분 걸림)
// 출력된 표를 lib/game/stages.dart 의 _table 에 붙여 넣는다.
import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:fruit_merge/game/stages.dart';
import 'package:fruit_merge/game/world.dart';

const runs = 12;

/// 떨어뜨릴 위치 고르기: 같은 과일 위에 떨어지면 크게 가산, 아니면 낮은(깊은) 곳.
double chooseX(World w, math.Random rng) {
  final piece = w.current;
  final r = pieceRadius(piece);
  var bestX = World.width / 2;
  var best = -1e9;
  for (var x = r + World.wall + 2; x <= World.width - r - World.wall - 2; x += 25) {
    var restY = World.height - World.wall - r;
    Fruit? contact;
    for (final f in w.fruits) {
      final dx = (f.pos.dx - x).abs();
      final reach = f.r + r;
      if (dx >= reach) continue;
      final y = f.pos.dy - math.sqrt(reach * reach - dx * dx);
      if (y < restY) {
        restY = y;
        contact = f;
      }
    }
    var score = restY + rng.nextDouble() * 20;
    final kind = kindOf(piece);
    if (contact != null && contact.kind == FruitKind.normal) {
      if (kind == FruitKind.normal && contact.level == piece) score += 2000;
      if (kind == FruitKind.rainbow) score += 300.0 * contact.level;
    }
    if (kind == FruitKind.stone) score += (x - World.width / 2).abs() * 2;
    if (score > best) {
      best = score;
      bestX = x;
    }
  }
  return bestX;
}

void settle(World w, double seconds) {
  for (var t = 0.0; t < seconds && !w.over; t += 1 / 60) {
    w.step(1 / 60);
  }
}

double quantile(List<double> xs, double q) {
  final s = [...xs]..sort();
  final i = ((s.length - 1) * q).round().clamp(0, s.length - 1);
  return s[i];
}

void main() {
  test('balance', () {
    final out = StringBuffer();
    final report = StringBuffer();
    for (final st in Stage.all) {
      // 목표 성공률: 1스테이지 95% → 60스테이지 45%.
      final want = 0.95 - 0.5 * (st.number - 1) / (Stage.count - 1);
      final measures = <double>[];
      var clears = 0;
      for (var run = 0; run < runs; run++) {
        final rng = math.Random(st.number * 1000 + run);
        final w = st.createWorld(random: math.Random(run * 31 + st.number), unlimited: true);
        final cap = st.goal == GoalType.score ? st.drops : st.drops * 3;
        double? measure;
        var n = 0;
        while (!w.over && n < cap) {
          for (var k = 0; k < 120 && !w.canDrop; k++) {
            w.step(1 / 60);
          }
          if (w.over) break;
          w.aim(chooseX(w, rng));
          w.drop();
          n++;
          w.events.clear();
          if (st.goal != GoalType.score && st.achieved(w) && measure == null) {
            measure = n.toDouble();
            break;
          }
        }
        settle(w, 2);
        if (st.goal == GoalType.score) {
          measure = w.over ? 0 : w.score.toDouble();
          if (!w.over && st.achieved(w)) clears++;
        } else {
          measure ??= st.achieved(w) ? n.toDouble() : 9999;
          if (measure <= st.drops) clears++;
        }
        measures.add(measure);
      }
      int target = st.target;
      int drops = st.drops;
      if (st.goal == GoalType.score) {
        target = (quantile(measures, 1 - want) / 10).floor() * 10;
        target = math.max(target, 40);
      } else {
        final q = quantile(measures, want);
        drops = q >= 9999 ? st.drops : ((q * 1.05) / 5).ceil() * 5;
      }
      final sorted = [...measures]..sort();
      report.writeln('stage ${st.number} ${st.goal.name} target ${st.target} drops ${st.drops}: '
          'clear ${(clears * 100 / runs).round()}% (want ${(want * 100).round()}%) measures $sorted');
      out.writeln('  (GoalType.${st.goal.name}, $target, $drops), // ${st.number}');
    }
    // ignore: avoid_print
    print(report);
    // ignore: avoid_print
    print(out);
  }, timeout: const Timeout(Duration(minutes: 30)));
}
