import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:fruit_merge/game/world.dart';

void settle(World w, [double seconds = 4]) {
  for (var t = 0.0; t < seconds; t += 1 / 60) {
    w.step(1 / 60);
  }
}

void main() {
  test('dropped fruit falls and rests on the floor', () {
    final w = World(random: math.Random(1));
    w.aim(500);
    final level = w.current;
    expect(w.drop(), isTrue);
    settle(w);
    final f = w.fruits.single;
    expect(f.level, level);
    expect(f.pos.dy, closeTo(World.height - World.wall - f.r, 2));
    expect(f.vel.distance, lessThan(5));
  });

  test('cooldown blocks rapid drops', () {
    final w = World(random: math.Random(1));
    expect(w.drop(), isTrue);
    expect(w.drop(), isFalse);
    w.step(1 / 30);
    expect(w.drop(), isFalse);
    for (var i = 0; i < 30; i++) {
      w.step(1 / 60);
    }
    expect(w.drop(), isTrue);
  });

  test('two identical fruits merge into the next level and score', () {
    final w = World(random: math.Random(1));
    w.add(2, const Offset(400, 1300));
    w.add(2, const Offset(470, 1300));
    settle(w, 1);
    expect(w.fruits, hasLength(1));
    expect(w.fruits.single.level, 3);
    expect(w.score, mergePoints[3]);
    expect(w.biggest, 3);
    expect(w.events.single.level, 3);
  });

  test('chain merge: 0+0 -> 1 then merges with a waiting 1', () {
    final w = World(random: math.Random(1));
    w.add(1, Offset(500, World.height - World.wall - fruitRadii[1]));
    w.add(0, Offset(500, 1100));
    w.add(0, Offset(500, 1000));
    settle(w, 3);
    expect(w.fruits.map((f) => f.level), [2]);
  });

  test('two watermelons vanish with a bonus', () {
    final w = World(random: math.Random(1));
    w.add(maxLevel, const Offset(250, 1200));
    w.add(maxLevel, const Offset(600, 1200));
    settle(w, 2);
    expect(w.fruits, isEmpty);
    expect(w.score, watermelonBonus);
  });

  test('different fruits stack without overlapping much', () {
    final w = World(random: math.Random(3));
    for (var i = 0; i < 40; i++) {
      w.add(i % 5, Offset(100 + (i * 97) % 800, 1300 - i * 25.0));
    }
    settle(w, 6);
    for (final a in w.fruits) {
      expect(a.pos.dx, inInclusiveRange(a.r - 1, World.width - a.r + 1));
      expect(a.pos.dy, lessThanOrEqualTo(World.height - a.r + 1));
      for (final b in w.fruits) {
        if (identical(a, b) || a.level == b.level) continue;
        expect((a.pos - b.pos).distance, greaterThan((a.r + b.r) * 0.9));
      }
    }
  });

  test('fruits piled above the line end the game; rescue clears the top', () {
    final w = World(random: math.Random(1));
    // 서로 다른 과일로 기둥을 쌓아 선을 넘긴다.
    var y = World.height;
    var level = 6;
    while (y > World.lineY - 100) {
      final r = fruitRadii[level];
      w.add(level, Offset(500, y - r));
      y -= r * 2;
      level = level == 6 ? 7 : 6;
    }
    // 가운데 기둥이 무너지지 않도록 벽 사이를 같은 크기로 채우지는 않는다: 짧게만 굴린다.
    for (var i = 0; i < 60 * 3 && !w.over; i++) {
      w.step(1 / 60);
      // 기둥이 쓰러지면 위쪽을 다시 올려 둔다 (게임 오버 판정만 확인).
      w.fruits.last.pos = Offset(w.fruits.last.pos.dx, World.lineY - 40);
      w.fruits.last.vel = Offset.zero;
    }
    expect(w.over, isTrue);
    expect(w.drop(), isFalse);
    final removed = w.rescue();
    expect(removed, greaterThan(0));
    expect(w.over, isFalse);
    expect(w.fruits.every((f) => f.pos.dy - f.r >= World.lineY + 220), isTrue);
  });

  test('aim keeps the fruit inside the walls', () {
    final w = World(random: math.Random(1));
    w.aim(-100);
    expect(w.dropX, fruitRadii[w.current] + World.wall + 2);
    w.aim(5000);
    expect(w.dropX, World.width - fruitRadii[w.current] - World.wall - 2);
  });

  test('json round trip', () {
    final w = World(random: math.Random(1));
    w.add(3, const Offset(300, 1300));
    w.add(5, const Offset(700, 1300));
    w.score = 42;
    final copy = World.fromJson(w.toJson())!;
    expect(copy.score, 42);
    expect(copy.current, w.current);
    expect(copy.next, w.next);
    expect(copy.fruits.map((f) => f.level), [3, 5]);
    expect(World.fromJson({'bad': 1}), isNull);
  });

  test('smash removes a fruit', () {
    final w = World(random: math.Random(1));
    final f = w.add(4, const Offset(500, 1300));
    expect(w.fruitAt(const Offset(510, 1290)), f);
    w.smash(f);
    expect(w.fruits, isEmpty);
    expect(w.fruitAt(const Offset(510, 1290)), isNull);
  });
}
