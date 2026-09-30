import 'dart:math' as math;
import 'dart:ui';

/// 과일 단계별 반지름 (월드 좌표, 상자 너비 1000 기준). 0 체리 … 10 수박.
const fruitRadii = <double>[26, 36, 48, 60, 74, 90, 106, 124, 144, 166, 192];

/// 이 단계로 합쳐질 때 얻는 점수. 수박 두 개가 만나면 [watermelonBonus].
const mergePoints = <int>[1, 3, 6, 10, 15, 21, 28, 36, 45, 55, 66];
const watermelonBonus = 100;

const maxLevel = 10;

/// 떨어뜨릴 수 있는 과일은 0~4 단계 (체리~감). 작은 것이 더 자주 나온다.
const _dropWeights = <int>[30, 27, 21, 14, 8];

class Fruit {
  final int id;
  final int level;
  Offset pos;
  Offset vel;

  /// 떨어진 뒤 지난 시간(초). 막 떨어진 과일은 선 위에 있어도 게임 오버로 세지 않는다.
  double age = 0;

  Fruit(this.id, this.level, this.pos, [this.vel = Offset.zero]);

  double get r => fruitRadii[level];
  double get mass => r * r;
}

/// 합쳐짐 / 망치 / 수박 보너스 — 화면 효과(파티클·점수)용.
class WorldEvent {
  final Offset pos;
  final int level;
  final int points;
  final bool removed; // 망치 또는 수박+수박 (새 과일 없이 사라짐)
  const WorldEvent(this.pos, this.level, this.points, {this.removed = false});
}

/// 과일 합치기 물리 세계: 위에서 과일을 떨어뜨리고, 같은 과일끼리 닿으면 다음 단계로 합쳐진다.
/// 과일이 [lineY] 위로 [overAfter] 초 넘게 쌓여 있으면 게임 오버.
///
/// 원끼리 충돌만 다루는 단순 물리: 반고정 스텝 Euler + 위치 보정 + 법선 충격량. 서브스텝과
/// 반복 횟수로 쌓임 안정성을 맞춘다 (과일 60개에서도 한 프레임 수 ms).
class World {
  static const width = 1000.0;
  static const height = 1400.0;
  static const lineY = 230.0;
  static const dropY = 110.0;
  static const gravity = 2600.0;
  static const overAfter = 2.5;
  static const dropCooldown = 0.45;

  /// 상자 테두리 두께만큼 안쪽이 실제 벽.
  static const wall = 10.0;

  static const _substeps = 8;
  static const _iterations = 3;
  static const _restitution = 0.15;

  /// 미끄러짐: 바닥 마찰(접촉 서브스텝마다 곱하는 값)과 과일끼리 접선 마찰. 작을수록 잘 미끄러진다.
  static const _floorFriction = 0.998;
  static const _contactFriction = 0.01;
  static const _airDamping = 0.15;

  /// 합쳐질 때 주변 과일을 밀어내는 세기 (월드 단위 속도).
  static const bumpSpeed = 380.0;
  static const bumpRange = 70.0;

  final math.Random _rng;
  final fruits = <Fruit>[];
  final events = <WorldEvent>[];

  int score = 0;
  late int current;
  late int next;
  double dropX = width / 2;
  double cooldown = 0;

  /// 선을 넘은 채로 지난 시간 (0 ~ [overAfter]).
  double danger = 0;
  bool over = false;

  /// 이번 판에 만든 가장 큰 과일.
  int biggest = 0;
  int _nextId = 0;

  World({math.Random? random}) : _rng = random ?? math.Random() {
    current = _roll(first: true);
    next = _roll();
  }

  bool get canDrop => cooldown <= 0 && !over;

  /// 선 위에 과일이 걸려 있는 중인지 (경고 표시용).
  bool get inDanger => danger > 0.2;

  int _roll({bool first = false}) {
    // 첫 과일은 작은 것 중에서.
    final weights = first ? _dropWeights.sublist(0, 3) : _dropWeights;
    var t = _rng.nextInt(weights.reduce((a, b) => a + b));
    for (var i = 0; i < weights.length; i++) {
      t -= weights[i];
      if (t < 0) return i;
    }
    return 0;
  }

  /// 떨어뜨릴 위치를 정한다 (벽 밖으로 나가지 않게).
  void aim(double x) {
    final r = fruitRadii[current];
    dropX = x.clamp(r + wall + 2, width - r - wall - 2);
  }

  bool drop() {
    if (!canDrop) return false;
    fruits.add(Fruit(_nextId++, current, Offset(dropX, dropY)));
    current = next;
    next = _roll();
    cooldown = dropCooldown;
    aim(dropX);
    return true;
  }

  /// 과일을 직접 넣는다 (테스트·저장 복원용).
  Fruit add(int level, Offset pos, {double age = 10}) {
    final f = Fruit(_nextId++, level, pos)..age = age;
    fruits.add(f);
    biggest = math.max(biggest, level);
    return f;
  }

  void step(double dt) {
    if (over) return;
    dt = math.min(dt, 1 / 30);
    cooldown -= dt;
    final h = dt / _substeps;
    for (var s = 0; s < _substeps; s++) {
      _integrate(h);
      for (var k = 0; k < _iterations; k++) {
        _collide();
      }
    }
    for (final f in fruits) {
      f.age += dt;
    }
    final above = fruits.any((f) => f.age > 1.2 && f.pos.dy - f.r < lineY);
    danger = above ? danger + dt : math.max(0, danger - dt * 2);
    if (danger >= overAfter) over = true;
  }

  void _integrate(double h) {
    final damp = 1 - _airDamping * h;
    for (final f in fruits) {
      var v = Offset(f.vel.dx * damp, (f.vel.dy + gravity * h) * damp);
      var p = f.pos + v * h;
      final r = f.r;
      if (p.dx < r + wall) {
        p = Offset(r + wall, p.dy);
        if (v.dx < 0) v = Offset(-v.dx * 0.2, v.dy);
      } else if (p.dx > width - r - wall) {
        p = Offset(width - r - wall, p.dy);
        if (v.dx > 0) v = Offset(-v.dx * 0.2, v.dy);
      }
      if (p.dy > height - r - wall) {
        p = Offset(p.dx, height - r - wall);
        if (v.dy > 0) v = Offset(v.dx * _floorFriction, -v.dy * 0.1);
      }
      f
        ..pos = p
        ..vel = v;
    }
  }

  void _collide() {
    final removed = <Fruit>{};
    final born = <Fruit>[];
    final bumps = <(Offset, int)>[];
    final n = fruits.length;
    for (var i = 0; i < n; i++) {
      final a = fruits[i];
      if (removed.contains(a)) continue;
      for (var j = i + 1; j < n; j++) {
        final b = fruits[j];
        if (removed.contains(b)) continue;
        final d = b.pos - a.pos;
        final minDist = a.r + b.r;
        final dist2 = d.dx * d.dx + d.dy * d.dy;
        if (dist2 >= minDist * minDist) continue;

        if (a.level == b.level) {
          removed
            ..add(a)
            ..add(b);
          final mid = Offset((a.pos.dx + b.pos.dx) / 2, (a.pos.dy + b.pos.dy) / 2);
          if (a.level == maxLevel) {
            score += watermelonBonus;
            events.add(WorldEvent(mid, a.level, watermelonBonus, removed: true));
            bumps.add((mid, a.level));
          } else {
            final lv = a.level + 1;
            final vel = (a.vel + b.vel) * 0.25;
            final f = Fruit(_nextId++, lv, mid, vel)..age = math.max(a.age, b.age);
            born.add(f);
            score += mergePoints[lv];
            biggest = math.max(biggest, lv);
            events.add(WorldEvent(mid, lv, mergePoints[lv]));
            bumps.add((mid, lv));
          }
          break;
        }

        final dist = math.sqrt(dist2);
        final nrm = dist > 1e-6 ? d / dist : const Offset(0, 1);
        final overlap = minDist - dist;
        final ima = 1 / a.mass, imb = 1 / b.mass, sum = ima + imb;
        a.pos -= nrm * (overlap * ima / sum);
        b.pos += nrm * (overlap * imb / sum);
        final rel = (b.vel - a.vel);
        final vn = rel.dx * nrm.dx + rel.dy * nrm.dy;
        if (vn < 0) {
          final jn = -(1 + _restitution) * vn / sum;
          a.vel -= nrm * (jn * ima);
          b.vel += nrm * (jn * imb);
          // 아주 약한 마찰: 접선 방향 상대 속도를 살짝만 줄인다 (잘 미끄러지게).
          final t = Offset(-nrm.dy, nrm.dx);
          final vt = rel.dx * t.dx + rel.dy * t.dy;
          final jt = -vt * _contactFriction / sum;
          a.vel -= t * (jt * ima);
          b.vel += t * (jt * imb);
        }
      }
    }
    if (removed.isEmpty) return;
    fruits.removeWhere(removed.contains);
    for (final (c, lv) in bumps) {
      _bump(c, lv);
    }
    fruits.addAll(born);
  }

  /// 합쳐진 자리 주변 과일을 바깥쪽(살짝 위로)으로 톡 튕긴다. 가까울수록, 가벼울수록 세게.
  void _bump(Offset c, int level) {
    final big = fruitRadii[level];
    for (final f in fruits) {
      final d = f.pos - c;
      final dist = d.distance;
      // 표면 사이 틈 기준: 맞닿은 과일은 최대로, [bumpRange] 만큼 떨어지면 0.
      final gap = dist - big - f.r;
      if (gap >= bumpRange) continue;
      final dir = dist > 1e-6 ? d / dist : const Offset(0, -1);
      final falloff = (1 - gap / bumpRange).clamp(0.0, 1.0);
      final weight = (big / f.r).clamp(0.6, 1.4);
      final speed = bumpSpeed * (0.8 + level * 0.04) * falloff * weight;
      f.vel += Offset(dir.dx * speed, dir.dy * speed - speed * 0.35);
    }
  }

  /// [p] 위치의 과일 (위에 그려진 것 우선). 없으면 null.
  Fruit? fruitAt(Offset p) {
    for (final f in fruits.reversed) {
      if ((f.pos - p).distance <= f.r + 8) return f;
    }
    return null;
  }

  /// 망치: 과일 하나를 없앤다.
  void smash(Fruit f) {
    if (!fruits.remove(f)) return;
    events.add(WorldEvent(f.pos, f.level, 0, removed: true));
  }

  /// 이어하기: 선 근처(위쪽)에 쌓인 과일을 치우고 게임을 계속한다.
  int rescue() {
    final cut = lineY + 220;
    final gone = fruits.where((f) => f.pos.dy - f.r < cut).toList();
    for (final f in gone) {
      fruits.remove(f);
      events.add(WorldEvent(f.pos, f.level, 0, removed: true));
    }
    danger = 0;
    over = false;
    cooldown = 0.6;
    return gone.length;
  }

  // ------------------------------------------------------------- 저장 / 복원

  Map<String, Object> toJson() => {
    'score': score,
    'current': current,
    'next': next,
    'biggest': biggest,
    'fruits': [
      for (final f in fruits) [f.level, f.pos.dx.round(), f.pos.dy.round()],
    ],
  };

  static World? fromJson(Map<String, dynamic> j, {math.Random? random}) {
    try {
      final w = World(random: random)
        ..score = j['score'] as int
        ..current = j['current'] as int
        ..next = j['next'] as int
        ..biggest = j['biggest'] as int;
      for (final f in j['fruits'] as List) {
        final l = f as List;
        w.add(l[0] as int, Offset((l[1] as num).toDouble(), (l[2] as num).toDouble()));
      }
      w.aim(width / 2);
      return w;
    } catch (_) {
      return null;
    }
  }
}
