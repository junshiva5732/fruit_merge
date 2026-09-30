import 'dart:math' as math;
import 'dart:ui';

import 'world.dart';

enum GoalType {
  /// 점수 [Stage.target] 이상.
  score,

  /// 과일 [Stage.target] 단계 만들기.
  fruit,

  /// 돌 [Stage.target] 개 깨기 (시작할 때 바닥에 깔려 있다).
  stones,
}

/// 스테이지 하나. 60개, 10개씩 6개 지역.
///
/// 난이도: 스테이지가 오를수록 고정 난이도(큰 과일 확률·버티는 시간)가 오르고,
/// 3 무지개 · 5 폭탄 · 7 떨어지는 돌 · 8 자동 낙하가 차례로 열린다.
/// 목표 수치와 과일 수는 tool/balance_test.dart 의 자동 플레이로 맞춘 [_table] 값.
class Stage {
  final int number;
  final GoalType goal;
  final int target;
  final int drops;

  const Stage(this.number, this.goal, this.target, this.drops);

  static const count = 60;
  static const perRegion = 10;
  static const regions = count ~/ perRegion;

  int get region => (number - 1) ~/ perRegion;

  /// 0 ~ 0.85
  double get difficulty => 0.85 * (number - 1) / (count - 1);

  Rules get rules => Rules(
    difficulty: difficulty,
    rainbow: number >= 3,
    bomb: number >= 5,
    stoneChance: number >= 7 ? 0.02 + 0.04 * difficulty : 0,
    autoDrop: number >= 8,
    dropLimit: drops,
  );

  /// 시작할 때 바닥에 깔린 돌 수.
  int get presetStones => goal == GoalType.stones ? target : 0;

  World createWorld({math.Random? random, bool unlimited = false}) {
    final r = rules;
    final w = World(
      random: random,
      rules: unlimited
          ? Rules(difficulty: r.difficulty, rainbow: r.rainbow, bomb: r.bomb, stoneChance: r.stoneChance, autoDrop: r.autoDrop)
          : r,
    );
    // 돌은 바닥에 고르게 (스테이지마다 같은 배치).
    final n = presetStones;
    if (n > 0) {
      final rng = math.Random(number * 7919);
      final rad = pieceRadius(pieceStone);
      final span = World.width - 2 * (World.wall + rad);
      for (var i = 0; i < n; i++) {
        final x = World.wall + rad + span * (i + 0.5) / n + (rng.nextDouble() - 0.5) * 40;
        w.add(pieceStone, Offset(x, World.height - World.wall - rad));
      }
    }
    return w;
  }

  bool achieved(World w) => switch (goal) {
    GoalType.score => w.score >= target,
    GoalType.fruit => w.biggest >= target,
    GoalType.stones => w.stonesBroken >= target,
  };

  /// 0 ~ 1
  double progress(World w) {
    final p = switch (goal) {
      GoalType.score => w.score / target,
      GoalType.fruit => achieved(w) ? 1.0 : w.biggest / target,
      GoalType.stones => w.stonesBroken / target,
    };
    return p.clamp(0.0, 1.0);
  }

  /// 깼을 때 별: 남은 과일이 30% 이상 3개, 15% 이상 2개, 아니면 1개.
  int starsFor(World w) {
    final left = (w.dropsLeft ?? 0) / drops;
    if (left >= 0.3) return 3;
    if (left >= 0.15) return 2;
    return 1;
  }

  /// 5의 배수 스테이지를 처음 깨면 망치 +1.
  bool get givesHammer => number % 5 == 0;

  static final all = List<Stage>.unmodifiable([
    for (var i = 0; i < count; i++) Stage(i + 1, _table[i].$1, _table[i].$2, _table[i].$3),
  ]);

  static Stage of(int number) => all[number - 1];
}

/// 목표 종류 · 목표치 · 과일 수. 5의 배수는 과일 만들기, 8·13·18… 은 돌 깨기, 나머지는 점수.
/// tool/balance_test.dart 자동 플레이 결과(스테이지당 12판, 2번 검증)를 매끄럽게 다듬은 값:
/// 점수 ≈ 0.9 × (250 + 27 × 스테이지) (1~4는 연습용으로 낮게), 과일 수는 자동 플레이 성공률 95% → 45% 기준.
const _table = <(GoalType, int, int)>[
  (GoalType.score, 200, 25), // 1
  (GoalType.score, 250, 26), // 2
  (GoalType.score, 300, 26), // 3
  (GoalType.score, 350, 27), // 4
  (GoalType.fruit, 4, 20), // 5
  (GoalType.score, 370, 28), // 6
  (GoalType.score, 400, 28), // 7
  (GoalType.stones, 2, 30), // 8
  (GoalType.score, 440, 29), // 9
  (GoalType.fruit, 5, 30), // 10
  (GoalType.score, 490, 30), // 11
  (GoalType.score, 520, 31), // 12
  (GoalType.stones, 2, 34), // 13
  (GoalType.score, 570, 32), // 14
  (GoalType.fruit, 5, 24), // 15
  (GoalType.score, 610, 33), // 16
  (GoalType.score, 640, 33), // 17
  (GoalType.stones, 3, 30), // 18
  (GoalType.score, 690, 34), // 19
  (GoalType.fruit, 6, 45), // 20
  (GoalType.score, 740, 35), // 21
  (GoalType.score, 760, 36), // 22
  (GoalType.stones, 3, 28), // 23
  (GoalType.score, 810, 37), // 24
  (GoalType.fruit, 6, 42), // 25
  (GoalType.score, 860, 38), // 26
  (GoalType.score, 880, 38), // 27
  (GoalType.stones, 3, 28), // 28
  (GoalType.score, 930, 39), // 29
  (GoalType.fruit, 7, 58), // 30
  (GoalType.score, 980, 40), // 31
  (GoalType.score, 1000, 41), // 32
  (GoalType.stones, 4, 30), // 33
  (GoalType.score, 1050, 42), // 34
  (GoalType.fruit, 7, 52), // 35
  (GoalType.score, 1100, 43), // 36
  (GoalType.score, 1120, 43), // 37
  (GoalType.stones, 4, 30), // 38
  (GoalType.score, 1170, 44), // 39
  (GoalType.fruit, 8, 95), // 40
  (GoalType.score, 1220, 45), // 41
  (GoalType.score, 1250, 46), // 42
  (GoalType.stones, 4, 30), // 43
  (GoalType.score, 1290, 47), // 44
  (GoalType.fruit, 8, 80), // 45
  (GoalType.score, 1340, 48), // 46
  (GoalType.score, 1370, 48), // 47
  (GoalType.stones, 5, 32), // 48
  (GoalType.score, 1420, 49), // 49
  (GoalType.fruit, 9, 115), // 50
  (GoalType.score, 1460, 50), // 51
  (GoalType.score, 1490, 51), // 52
  (GoalType.stones, 5, 36), // 53
  (GoalType.score, 1540, 52), // 54
  (GoalType.fruit, 9, 115), // 55
  (GoalType.score, 1590, 53), // 56
  (GoalType.score, 1610, 53), // 57
  (GoalType.stones, 5, 32), // 58
  (GoalType.score, 1660, 54), // 59
  (GoalType.fruit, 10, 230), // 60
];
