import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:fruit_merge/game/stages.dart';
import 'package:fruit_merge/game/world.dart';
import 'package:fruit_merge/services/storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  test('60 stages, numbered in order, getting harder', () {
    expect(Stage.all, hasLength(Stage.count));
    for (var i = 0; i < Stage.count; i++) {
      final st = Stage.all[i];
      expect(st.number, i + 1);
      expect(st.target, greaterThan(0));
      expect(st.drops, greaterThan(0));
      if (i > 0) expect(st.difficulty, greaterThan(Stage.all[i - 1].difficulty));
    }
    final scores = Stage.all.where((s) => s.goal == GoalType.score).map((s) => s.target).toList();
    for (var i = 1; i < scores.length; i++) {
      expect(scores[i], greaterThanOrEqualTo(scores[i - 1]), reason: 'score targets should not go down');
    }
    expect(Stage.of(60).goal, GoalType.fruit);
    expect(Stage.of(60).target, maxLevel);
  });

  test('features unlock by stage', () {
    expect(Stage.of(1).rules.rainbow, isFalse);
    expect(Stage.of(3).rules.rainbow, isTrue);
    expect(Stage.of(4).rules.bomb, isFalse);
    expect(Stage.of(5).rules.bomb, isTrue);
    expect(Stage.of(6).rules.stoneChance, 0);
    expect(Stage.of(7).rules.stoneChance, greaterThan(0));
    expect(Stage.of(7).rules.autoDrop, isFalse);
    expect(Stage.of(8).rules.autoDrop, isTrue);
  });

  test('stone stages start with stones on the floor', () {
    final st = Stage.all.firstWhere((s) => s.goal == GoalType.stones);
    final w = st.createWorld(random: math.Random(1));
    expect(w.fruits.where((f) => f.kind == FruitKind.stone), hasLength(st.target));
    expect(st.achieved(w), isFalse);
    w.stonesBroken = st.target;
    expect(st.achieved(w), isTrue);
  });

  test('drop limit stops drops, extra drops continue', () {
    final st = Stage.of(1);
    final w = st.createWorld(random: math.Random(1));
    expect(w.dropsLeft, st.drops);
    for (var i = 0; i < st.drops; i++) {
      w.cooldown = 0;
      expect(w.drop(), isTrue);
      w.fruits.clear();
    }
    expect(w.dropsLeft, 0);
    w.cooldown = 0;
    expect(w.canDrop, isFalse);
    expect(w.drop(), isFalse);
    w.extraDrops += 5;
    expect(w.dropsLeft, 5);
    expect(w.drop(), isTrue);
  });

  test('stage mode auto drop does not ignore the limit', () {
    final st = Stage.of(10);
    final w = st.createWorld(random: math.Random(1));
    for (var t = 0; t < 60 * 60 * 5 && w.dropsLeft! > 0; t++) {
      w.step(1 / 60);
      w.fruits.removeWhere((f) => f.kind != FruitKind.stone);
    }
    expect(w.dropsLeft, 0);
    expect(w.drops, st.drops);
  });

  test('stars by fruits left', () {
    final st = Stage.of(1);
    final w = st.createWorld(random: math.Random(1));
    expect(st.starsFor(w), 3);
    w.drops = (st.drops * 0.8).ceil();
    expect(st.starsFor(w), 2);
    w.drops = st.drops;
    expect(st.starsFor(w), 1);
  });

  test('goal progress', () {
    final st = Stage.all.firstWhere((s) => s.goal == GoalType.fruit);
    final w = st.createWorld(random: math.Random(1));
    expect(st.progress(w), 0);
    w.biggest = st.target;
    expect(st.achieved(w), isTrue);
    expect(st.progress(w), 1);
  });

  test('storage: stars, unlocks, totals', () async {
    SharedPreferences.setMockInitialValues({});
    final s = await Storage.create();
    expect(s.unlockedStage, 1);
    expect(s.stars(1), 0);
    expect(s.recordStars(1, 2), isTrue); // 처음 깸
    expect(s.unlockedStage, 2);
    expect(s.recordStars(1, 1), isFalse); // 더 적으면 무시
    expect(s.stars(1), 2);
    expect(s.recordStars(1, 3), isFalse); // 더 많으면 저장 (처음은 아님)
    expect(s.stars(1), 3);
    s.recordStars(2, 1);
    expect(s.totalStars, 4);
    expect(s.unlockedStage, 3);
    expect(s.stars(40), 0);
  });
}
