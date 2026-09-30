import 'dart:math' as math;
import 'dart:ui';

/// 과일 단계별 반지름 (월드 좌표, 상자 너비 1000 기준). 0 체리 … 10 수박.
const fruitRadii = <double>[26, 36, 48, 60, 74, 90, 106, 124, 144, 166, 192];

/// 이 단계로 합쳐질 때 얻는 점수. 수박 두 개가 만나면 [watermelonBonus].
const mergePoints = <int>[1, 3, 6, 10, 15, 21, 28, 36, 45, 55, 66];
const watermelonBonus = 100;

const maxLevel = 10;

/// 떨어뜨릴 조각 번호: 0~10 은 과일 단계, 그 위는 특수 과일.
const pieceRainbow = 100;
const pieceBomb = 101;
const pieceStone = 102;

enum FruitKind { normal, rainbow, bomb, stone }

FruitKind kindOf(int piece) => switch (piece) {
  pieceRainbow => FruitKind.rainbow,
  pieceBomb => FruitKind.bomb,
  pieceStone => FruitKind.stone,
  _ => FruitKind.normal,
};

bool isSpecial(int piece) => piece >= pieceRainbow;

double pieceRadius(int piece) => switch (kindOf(piece)) {
  FruitKind.normal => fruitRadii[piece],
  FruitKind.rainbow => 42,
  FruitKind.bomb => 44,
  FruitKind.stone => 52,
};

/// 떨어지는 과일 확률 (체리~사과). 점수가 오를수록 [_easyWeights] → [_hardWeights] 로 옮겨 간다.
const _easyWeights = <int>[30, 27, 21, 14, 8, 0];
const _hardWeights = <int>[16, 20, 24, 22, 13, 5];

/// 한 판의 규칙. 무한 모드는 [Rules.endless] (점수에 따라 어려워짐), 스테이지는 고정 난이도.
class Rules {
  /// 고정 난이도 0~1. null 이면 점수에 따라 올라간다 (무한 모드).
  final double? difficulty;
  final bool rainbow;
  final bool bomb;

  /// 떨어지는 돌 확률. null 이면 무한 모드 곡선 ([World.stonesFrom] 점부터 3% → 8%).
  final double? stoneChance;
  final bool autoDrop;

  /// 떨어뜨릴 수 있는 과일 수. null 이면 무제한.
  final int? dropLimit;

  const Rules({this.difficulty, this.rainbow = true, this.bomb = true, this.stoneChance, this.autoDrop = true, this.dropLimit});

  static const endless = Rules();
}

class Fruit {
  final int id;
  final FruitKind kind;

  /// 일반 과일 단계 (특수 과일은 -1).
  final int level;
  final double r;
  Offset pos;
  Offset vel;

  /// 떨어진 뒤 지난 시간(초). 막 떨어진 과일은 선 위에 있어도 게임 오버로 세지 않는다.
  double age = 0;

  /// 돌: 주변에서 합쳐지는 충격을 이만큼 더 받으면 깨진다.
  int hp;

  Fruit(this.id, int piece, this.pos, [this.vel = Offset.zero])
    : kind = kindOf(piece),
      level = isSpecial(piece) ? -1 : piece,
      r = pieceRadius(piece),
      hp = piece == pieceStone ? World.stoneHp : 0;

  int get piece => switch (kind) {
    FruitKind.normal => level,
    FruitKind.rainbow => pieceRainbow,
    FruitKind.bomb => pieceBomb,
    FruitKind.stone => pieceStone,
  };

  /// 돌은 무거워서 잘 밀리지 않는다.
  double get mass => r * r * (kind == FruitKind.stone ? 3 : 1);
}

enum EventType {
  /// 합쳐짐 (새 과일 [WorldEvent.level]).
  merge,

  /// 수박 + 수박 (둘 다 사라지고 보너스).
  bonus,

  /// 과일을 떨어뜨림 (직접 또는 자동).
  drop,

  /// 망치로 없앰.
  smash,

  /// 돌이 깨짐.
  crumble,

  /// 폭탄이 터짐.
  boom,

  /// 이어하기로 치움 (효과만).
  clear,
}

/// 화면 효과(파티클·점수·소리)용 사건.
class WorldEvent {
  final EventType type;
  final Offset pos;
  final int piece;
  final int points;

  /// 콤보 배수 (1 = 콤보 아님).
  final int combo;
  const WorldEvent(this.type, this.pos, {this.piece = 0, this.points = 0, this.combo = 1});
}

/// 과일 합치기 물리 세계: 위에서 과일을 떨어뜨리고, 같은 과일끼리 닿으면 다음 단계로 합쳐진다.
/// 과일이 [lineY] 위로 [overAfter] 초 넘게 쌓여 있으면 게임 오버.
///
/// 난이도: 점수가 오를수록 큰 과일이 자주 나오고, 버틸 수 있는 시간이 줄고, 가만히 있으면 자동으로 떨어진다.
/// 특수 과일: 무지개(아무 과일과 합쳐짐) · 폭탄(닿으면 주변을 날림) · 돌(합쳐지지 않음, 충격 3번에 깨짐).
/// 콤보: [comboWindow] 초 안에 이어서 합치면 점수 ×2, ×3 … (최대 ×[maxCombo]).
///
/// 원끼리 충돌만 다루는 단순 물리: 반고정 스텝 Euler + 위치 보정 + 법선 충격량. 서브스텝과
/// 반복 횟수로 쌓임 안정성을 맞춘다 (과일 60개에서도 한 프레임 수 ms).
class World {
  static const width = 1000.0;
  static const height = 1400.0;
  static const lineY = 230.0;
  static const dropY = 110.0;
  static const gravity = 2600.0;
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

  /// 폭탄.
  static const blastSpeed = 1150.0;
  static const blastRange = 260.0;

  static const stoneHp = 3;

  // 난이도 곡선
  /// 이 점수에서 난이도가 최대가 된다.
  static const hardScore = 4000;

  /// 이 점수부터 가만히 있으면 자동으로 떨어진다.
  static const autoDropFrom = 500;

  /// 특수 과일이 나오기 시작하는 점수.
  static const specialsFrom = 300;
  static const stonesFrom = 800;

  static const comboWindow = 1.0;
  static const maxCombo = 5;

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

  /// 지금까지 떨어뜨린 개수 (화면에서 자동 낙하와 손 떼기를 구분할 때 쓴다).
  int drops = 0;

  /// 마지막으로 떨어뜨린 뒤 지난 시간 (자동 낙하용).
  double idle = 0;

  /// 지금 이어지고 있는 콤보 수와 남은 시간.
  int combo = 0;
  double _comboLeft = 0;

  /// 이번 판에 깬 돌 수 (망치 포함).
  int stonesBroken = 0;

  final Rules rules;

  /// 추가로 받은 과일 수 (스테이지 이어하기 +5).
  int extraDrops = 0;

  int _nextId = 0;

  World({math.Random? random, this.rules = Rules.endless}) : _rng = random ?? math.Random() {
    current = _roll(first: true);
    next = _roll();
  }

  bool get _endless => rules.difficulty == null;

  /// 남은 과일 수. 무제한이면 null.
  int? get dropsLeft => rules.dropLimit == null ? null : math.max(0, rules.dropLimit! + extraDrops - drops);

  // ------------------------------------------------------------ 난이도

  /// 0 (처음) ~ 1 ([hardScore] 점 이상).
  double get difficulty => rules.difficulty ?? (score / hardScore).clamp(0.0, 1.0);

  /// 선 위에서 버틸 수 있는 시간: 2.5초 → 1.5초.
  double get overAfter => 2.5 - difficulty;

  /// 가만히 있을 때 자동으로 떨어지기까지: 6초 → 4초. [autoDropFrom] 점 전에는 없음.
  double get autoDropAfter => 6.0 - 2.0 * difficulty;

  /// 자동 낙하까지 남은 시간. 해당 없으면 null.
  double? get autoDropLeft => _autoDropOn && canDrop ? math.max(0.0, autoDropAfter - idle) : null;

  bool get _autoDropOn => rules.autoDrop && (!_endless || score >= autoDropFrom);

  bool get canDrop => cooldown <= 0 && !over && (dropsLeft ?? 1) > 0;

  /// 선 위에 과일이 걸려 있는 중인지 (경고 표시용).
  bool get inDanger => danger > 0.2;

  int _roll({bool first = false}) {
    if (first) return _rng.nextInt(3); // 첫 과일은 작은 것 중에서
    // 특수 과일: 연달아 나오지 않게, 지금 과일이 일반일 때만.
    if (!isSpecial(current) && (!_endless || score >= specialsFrom)) {
      final rainbow = rules.rainbow ? 0.035 : 0.0;
      final bomb = rules.bomb ? 0.025 : 0.0;
      final stone = rules.stoneChance ?? (score >= stonesFrom ? 0.03 + 0.05 * difficulty : 0.0);
      final t = _rng.nextDouble();
      if (t < rainbow) return pieceRainbow;
      if (t < rainbow + bomb) return pieceBomb;
      if (t < rainbow + bomb + stone) return pieceStone;
    }
    final d = difficulty;
    final weights = [for (var i = 0; i < _easyWeights.length; i++) _easyWeights[i] + (_hardWeights[i] - _easyWeights[i]) * d];
    var t = _rng.nextDouble() * weights.reduce((a, b) => a + b);
    for (var i = 0; i < weights.length; i++) {
      t -= weights[i];
      if (t < 0) return i;
    }
    return 0;
  }

  // ------------------------------------------------------------ 조작

  /// 떨어뜨릴 위치를 정한다 (벽 밖으로 나가지 않게).
  void aim(double x) {
    final r = pieceRadius(current);
    dropX = x.clamp(r + wall + 2, width - r - wall - 2);
  }

  bool drop() {
    if (!canDrop) return false;
    fruits.add(Fruit(_nextId++, current, Offset(dropX, dropY)));
    events.add(WorldEvent(EventType.drop, Offset(dropX, dropY), piece: current));
    current = next;
    next = _roll();
    cooldown = dropCooldown;
    idle = 0;
    drops++;
    aim(dropX);
    return true;
  }

  /// 과일을 직접 넣는다 (테스트·저장 복원용). [piece] 는 과일 단계 또는 특수 과일 번호.
  Fruit add(int piece, Offset pos, {double age = 10}) {
    final f = Fruit(_nextId++, piece, pos)..age = age;
    fruits.add(f);
    if (!isSpecial(piece)) biggest = math.max(biggest, piece);
    return f;
  }

  // ------------------------------------------------------------ 시뮬레이션

  void step(double dt) {
    if (over) return;
    dt = math.min(dt, 1 / 30);
    cooldown -= dt;
    _comboLeft -= dt;
    if (_comboLeft <= 0) combo = 0;

    if (_autoDropOn && canDrop) {
      idle += dt;
      if (idle >= autoDropAfter) drop();
    }

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
    List<Fruit>? landedBombs;
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
        if (f.kind == FruitKind.bomb) (landedBombs ??= []).add(f);
      }
      f
        ..pos = p
        ..vel = v;
    }
    if (landedBombs != null) {
      for (final b in landedBombs) {
        _explode(b);
      }
    }
  }

  /// 콤보를 세고 점수를 더한다. 이번 배수를 돌려준다.
  int _award(int base) {
    combo = _comboLeft > 0 ? combo + 1 : 1;
    _comboLeft = comboWindow;
    final m = math.min(combo, maxCombo);
    score += base * m;
    return m;
  }

  void _collide() {
    final removed = <Fruit>{};
    final born = <Fruit>[];
    final bumps = <(Offset, int)>[];
    final bombs = <Fruit>[];
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

        // 폭탄: 무엇이든 닿으면 터진다.
        if (a.kind == FruitKind.bomb || b.kind == FruitKind.bomb) {
          for (final x in [a, b]) {
            if (x.kind == FruitKind.bomb && removed.add(x)) bombs.add(x);
          }
          if (removed.contains(a)) break;
          continue;
        }

        // 합쳐질 짝: 같은 단계 과일끼리, 또는 무지개 + 일반 과일.
        Fruit? keep, other;
        if (a.kind == FruitKind.normal && b.kind == FruitKind.normal && a.level == b.level) {
          keep = a;
          other = b;
        } else if (a.kind == FruitKind.rainbow && b.kind == FruitKind.normal) {
          keep = b;
          other = a;
        } else if (b.kind == FruitKind.rainbow && a.kind == FruitKind.normal) {
          keep = a;
          other = b;
        }
        if (keep != null && other != null) {
          removed
            ..add(a)
            ..add(b);
          // 같은 과일끼리는 가운데서, 무지개는 상대 과일 자리에서 커진다.
          final at = other.kind == FruitKind.rainbow ? keep.pos : Offset((a.pos.dx + b.pos.dx) / 2, (a.pos.dy + b.pos.dy) / 2);
          if (keep.level == maxLevel) {
            final m = _award(watermelonBonus);
            events.add(WorldEvent(EventType.bonus, at, piece: maxLevel, points: watermelonBonus * m, combo: m));
            bumps.add((at, maxLevel));
          } else {
            final lv = keep.level + 1;
            final vel = (a.vel + b.vel) * 0.25;
            born.add(Fruit(_nextId++, lv, at, vel)..age = math.max(a.age, b.age));
            final m = _award(mergePoints[lv]);
            biggest = math.max(biggest, lv);
            events.add(WorldEvent(EventType.merge, at, piece: lv, points: mergePoints[lv] * m, combo: m));
            bumps.add((at, lv));
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
      _push(c, fruitRadii[lv], bumpRange, bumpSpeed * (0.8 + lv * 0.04));
    }
    for (final b in bombs) {
      _blast(b);
    }
    fruits.addAll(born);
  }

  void _explode(Fruit bomb) {
    if (!fruits.remove(bomb)) return;
    _blast(bomb);
  }

  void _blast(Fruit bomb) {
    events.add(WorldEvent(EventType.boom, bomb.pos, piece: pieceBomb));
    _push(bomb.pos, bomb.r, blastRange, blastSpeed);
  }

  /// [c] 주변 과일을 바깥쪽(살짝 위로)으로 밀어낸다. 가까울수록, 가벼울수록 세게.
  /// 범위 안의 돌은 금이 가고, [stoneHp] 번 맞으면 깨진다.
  void _push(Offset c, double big, double range, double speed0) {
    List<Fruit>? broken;
    for (final f in fruits) {
      final d = f.pos - c;
      final dist = d.distance;
      // 표면 사이 틈 기준: 맞닿은 과일은 최대로, [range] 만큼 떨어지면 0.
      final gap = dist - big - f.r;
      if (gap >= range) continue;
      final dir = dist > 1e-6 ? d / dist : const Offset(0, -1);
      final falloff = (1 - gap / range).clamp(0.0, 1.0);
      final weight = (big / f.r).clamp(0.6, 1.4) * (f.kind == FruitKind.stone ? 0.5 : 1);
      final speed = speed0 * falloff * weight;
      f.vel += Offset(dir.dx * speed, dir.dy * speed - speed * 0.35);
      if (f.kind == FruitKind.stone && --f.hp <= 0) (broken ??= []).add(f);
    }
    if (broken == null) return;
    for (final s in broken) {
      fruits.remove(s);
      stonesBroken++;
      events.add(WorldEvent(EventType.crumble, s.pos, piece: pieceStone));
    }
  }

  // ------------------------------------------------------------ 아이템

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
    if (f.kind == FruitKind.stone) stonesBroken++;
    events.add(WorldEvent(EventType.smash, f.pos, piece: f.piece));
  }

  /// 이어하기: 선 근처(위쪽)에 쌓인 과일을 치우고 게임을 계속한다.
  int rescue() {
    final cut = lineY + 220;
    final gone = fruits.where((f) => f.pos.dy - f.r < cut).toList();
    for (final f in gone) {
      fruits.remove(f);
      events.add(WorldEvent(EventType.clear, f.pos, piece: f.piece));
    }
    danger = 0;
    over = false;
    cooldown = 0.6;
    idle = 0;
    return gone.length;
  }

  // ------------------------------------------------------------- 저장 / 복원

  Map<String, Object> toJson() => {
    'score': score,
    'current': current,
    'next': next,
    'biggest': biggest,
    'fruits': [
      for (final f in fruits) [f.piece, f.pos.dx.round(), f.pos.dy.round(), f.hp],
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
        final fruit = w.add(l[0] as int, Offset((l[1] as num).toDouble(), (l[2] as num).toDouble()));
        if (l.length > 3 && fruit.kind == FruitKind.stone) fruit.hp = l[3] as int;
      }
      w.aim(width / 2);
      return w;
    } catch (_) {
      return null;
    }
  }
}
