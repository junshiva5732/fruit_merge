import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../game/board_painter.dart';
import '../game/fruit_art.dart';
import '../game/stages.dart';
import '../game/world.dart';
import '../l10n/strings.dart';
import '../services/sound.dart';
import '../services/storage.dart';
import '../widgets/banner_ad_widget.dart';
import '../widgets/dialogs.dart';
import '../widgets/outlined_text.dart';
import 'game_screen.dart';

/// 지역별 배경색 (아래 → 위): 과수원, 딸기 밭, 열대 해변, 노을 언덕, 별빛 정원, 무지개 성.
const _regionColors = [
  Color(0xFFC5E1A5),
  Color(0xFFF8BBD0),
  Color(0xFFB3E5FC),
  Color(0xFFFFCC80),
  Color(0xFF7986CB),
  Color(0xFFD1C4E9),
];

/// 지역마다 흩뿌리는 장식 과일.
const _regionDeco = [
  [5, 3, 5],
  [1, 0, 1],
  [8, 9, 3],
  [4, 7, 4],
  [2, 2, 6],
  [pieceRainbow, 10, pieceRainbow],
];

/// 스테이지 지도 (앱의 첫 화면). 아래(1)에서 위(60)로 구불구불한 길을 따라 올라간다.
class MapScreen extends StatefulWidget {
  final Storage storage;
  const MapScreen({super.key, required this.storage});

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> with SingleTickerProviderStateMixin {
  static const _spacing = 116.0;
  static const _top = 190.0;
  static const _bottom = 200.0;

  final _scroll = ScrollController();
  late final AnimationController _pulse = AnimationController(vsync: this, duration: const Duration(milliseconds: 900))
    ..repeat(reverse: true);

  Storage get _storage => widget.storage;

  static double get _height => (Stage.count - 1) * _spacing + _top + _bottom;

  static Offset nodePos(int index, double width) =>
      Offset(width / 2 + math.sin(index * 0.8) * width * 0.27, _height - _bottom - index * _spacing);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToCurrent(animate: false));
  }

  @override
  void dispose() {
    _scroll.dispose();
    _pulse.dispose();
    super.dispose();
  }

  int get _current => math.min(_storage.unlockedStage, Stage.count);

  void _scrollToCurrent({bool animate = true}) {
    if (!_scroll.hasClients) return;
    final view = _scroll.position.viewportDimension;
    final y = nodePos(_current - 1, 400).dy;
    final target = (y - view * 0.6).clamp(0.0, _scroll.position.maxScrollExtent);
    if (animate) {
      _scroll.animateTo(target, duration: const Duration(milliseconds: 600), curve: Curves.easeOutCubic);
    } else {
      _scroll.jumpTo(target);
    }
  }

  Future<void> _openStage(Stage st) async {
    final s = S.of(context);
    if (st.number > _storage.unlockedStage) {
      Sound.instance.play('click');
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(s.locked), duration: const Duration(seconds: 2)));
      return;
    }
    Sound.instance.play('click');
    final go = await showDialog<bool>(context: context, builder: (ctx) => _StageIntro(stage: st, stars: _storage.stars(st.number)));
    if (go == true && mounted) await _play(st);
  }

  Future<void> _play(Stage? st) async {
    await Navigator.of(context).push(MaterialPageRoute(builder: (_) => GameScreen(storage: _storage, stage: st)));
    if (!mounted) return;
    setState(() {});
    WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToCurrent());
  }

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    return Scaffold(
      body: Stack(
        children: [
          Positioned.fill(
            child: LayoutBuilder(
              builder: (context, box) {
                final w = box.maxWidth;
                return SingleChildScrollView(
                  controller: _scroll,
                  child: SizedBox(
                    width: w,
                    height: _height,
                    child: Stack(
                      clipBehavior: Clip.none,
                      children: [
                        Positioned.fill(child: CustomPaint(painter: _MapPainter(width: w))),
                        for (var r = 0; r < Stage.regions; r++) _regionSign(context, r, w),
                        for (final st in Stage.all) _node(st, w),
                        _avatar(w),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
          // 위쪽: 제목 · 별 합계 · 설정 (지도 위에서도 잘 보이게 흐린 배경)
          Positioned(
            left: 0,
            right: 0,
            top: 0,
            child: IgnorePointer(
              child: Container(
                height: MediaQuery.paddingOf(context).top + 90,
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Color(0xE6FFF8E1), Color(0x00FFF8E1)],
                  ),
                ),
              ),
            ),
          ),
          Positioned(
            left: 0,
            right: 0,
            top: 0,
            child: SafeArea(
              bottom: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 8, 8, 0),
                child: Row(
                  children: [
                    const FruitIcon(10, size: 40),
                    const SizedBox(width: 6),
                    Flexible(child: FittedBox(fit: BoxFit.scaleDown, child: OutlinedText(s.appTitle, size: 26))),
                    const Spacer(),
                    _Chip(
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.star_rounded, color: Color(0xFFFFB300), size: 24),
                          const SizedBox(width: 2),
                          Text(
                            '${_storage.totalStars} / ${Stage.count * 3}',
                            style: const TextStyle(fontWeight: FontWeight.w900, color: brown),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 6),
                    IconButton.filledTonal(
                      onPressed: () async {
                        await showSettingsDialog(context, _storage);
                        if (mounted) setState(() {});
                      },
                      style: IconButton.styleFrom(backgroundColor: Colors.white70, foregroundColor: brown),
                      icon: const Icon(Icons.settings_rounded),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
      bottomNavigationBar: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            color: const Color(0xFFFFF8E1),
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
            child: SafeArea(
              top: false,
              bottom: false,
              child: SizedBox(
                width: double.infinity,
                child: FilledButton(
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFFFF7043),
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                  ),
                  onPressed: () {
                    Sound.instance.play('click');
                    _play(null);
                  },
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.all_inclusive_rounded, size: 28),
                      const SizedBox(width: 10),
                      Text(s.endless, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900)),
                      const SizedBox(width: 10),
                      Text('${s.best} ${_storage.best}', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
                    ],
                  ),
                ),
              ),
            ),
          ),
          const BannerAdWidget(),
        ],
      ),
    );
  }

  Widget _regionSign(BuildContext context, int r, double w) {
    final s = S.of(context);
    final first = nodePos(r * Stage.perRegion, w);
    final left = first.dx > w / 2;
    return Positioned(
      top: first.dy - 78,
      left: left ? 14 : null,
      right: left ? null : 14,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: const Color(0xFF8D6E63),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFF5D4037), width: 3),
          boxShadow: const [BoxShadow(color: Color(0x40000000), blurRadius: 4, offset: Offset(0, 2))],
        ),
        child: Text(
          s.regionName(r),
          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 15),
        ),
      ),
    );
  }

  Widget _node(Stage st, double w) {
    final p = nodePos(st.number - 1, w);
    const size = 64.0;
    return Positioned(
      left: p.dx - 50,
      top: p.dy - size / 2,
      width: 100,
      child: _StageNode(
        stage: st,
        stars: _storage.stars(st.number),
        locked: st.number > _storage.unlockedStage,
        current: st.number == _current && _storage.stars(st.number) == 0,
        pulse: _pulse,
        onTap: () => _openStage(st),
      ),
    );
  }

  /// 지금 도전할 스테이지 위에서 통통 튀는 딸기.
  Widget _avatar(double w) {
    final p = nodePos(_current - 1, w);
    return AnimatedBuilder(
      animation: _pulse,
      builder: (context, _) => Positioned(
        left: p.dx - 22,
        top: p.dy - 92 - Curves.easeOut.transform(_pulse.value) * 12,
        child: const IgnorePointer(child: FruitIcon(1, size: 44)),
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  final Widget child;
  const _Chip({required this.child});

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
    decoration: BoxDecoration(color: Colors.white70, borderRadius: BorderRadius.circular(20)),
    child: child,
  );
}

class _StageNode extends StatelessWidget {
  final Stage stage;
  final int stars;
  final bool locked;
  final bool current;
  final Animation<double> pulse;
  final VoidCallback onTap;

  const _StageNode({
    required this.stage,
    required this.stars,
    required this.locked,
    required this.current,
    required this.pulse,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    const size = 64.0;
    final colors = locked
        ? const [Color(0xFFCFD8DC), Color(0xFF90A4AE)]
        : current
        ? const [Color(0xFFFFF176), Color(0xFFFF7043)]
        : const [Color(0xFFFFCC80), Color(0xFFFB8C00)];
    Widget circle = Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: colors),
        border: Border.all(color: locked ? const Color(0xFF78909C) : Colors.white, width: 4),
        boxShadow: const [BoxShadow(color: Color(0x55000000), blurRadius: 6, offset: Offset(0, 3))],
      ),
      alignment: Alignment.center,
      child: locked
          ? const Icon(Icons.lock_rounded, color: Colors.white, size: 28)
          : OutlinedText('${stage.number}', size: 24, strokeWidth: 5),
    );
    if (current) {
      circle = AnimatedBuilder(
        animation: pulse,
        builder: (context, child) => Transform.scale(scale: 1 + 0.08 * pulse.value, child: child),
        child: circle,
      );
    }
    final badge = switch (stage.goal) {
      GoalType.fruit => stage.target,
      GoalType.stones => pieceStone,
      GoalType.score => null,
    };
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Stack(
            clipBehavior: Clip.none,
            children: [
              circle,
              if (badge != null && !locked) Positioned(right: -12, top: -10, child: FruitIcon(badge, size: 32, face: false)),
            ],
          ),
          const SizedBox(height: 2),
          if (!locked)
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                for (var i = 0; i < 3; i++)
                  Icon(
                    Icons.star_rounded,
                    size: 20,
                    color: i < stars ? const Color(0xFFFFB300) : const Color(0x55FFFFFF),
                    shadows: const [Shadow(color: Color(0x88000000), blurRadius: 2)],
                  ),
              ],
            ),
        ],
      ),
    );
  }
}

/// 스테이지 시작 전 카드: 목표 · 과일 수 · 최고 별 · 새로 등장하는 것.
class _StageIntro extends StatelessWidget {
  final Stage stage;
  final int stars;
  const _StageIntro({required this.stage, required this.stars});

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final goalText = switch (stage.goal) {
      GoalType.score => s.goalScore(stage.target),
      GoalType.fruit => s.goalFruit(stage.target),
      GoalType.stones => s.goalStones(stage.target),
    };
    final goalIcon = switch (stage.goal) {
      GoalType.score => const Icon(Icons.emoji_events_rounded, size: 44, color: Color(0xFFFFB300)),
      GoalType.fruit => FruitIcon(stage.target, size: 52),
      GoalType.stones => const FruitIcon(pieceStone, size: 52),
    };
    final (Widget, String)? news = switch (stage.number) {
      3 => (const FruitIcon(pieceRainbow, size: 40), s.specialHint(pieceRainbow)),
      5 => (const FruitIcon(pieceBomb, size: 40), s.specialHint(pieceBomb)),
      7 => (const FruitIcon(pieceStone, size: 40), s.fallingStonesHint),
      8 => (const Icon(Icons.timer_rounded, size: 36, color: Color(0xFFE53935)), s.autoDropHint),
      _ => null,
    };
    return AlertDialog(
      backgroundColor: const Color(0xFFFFF8E1),
      title: Column(
        children: [
          Text(s.regionName(stage.region), style: const TextStyle(fontSize: 14, color: brown)),
          OutlinedText(s.stageN(stage.number), size: 32, color: const Color(0xFFFF7043)),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16)),
            child: Row(
              children: [
                goalIcon,
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(s.goal, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: brown)),
                      Text(goalText, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: brown)),
                      Text(s.dropsLimit(stage.drops), style: const TextStyle(fontSize: 14, color: brown)),
                    ],
                  ),
                ),
              ],
            ),
          ),
          if (stars > 0) ...[
            const SizedBox(height: 10),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text('${s.bestStars} ', style: const TextStyle(color: brown)),
                for (var i = 0; i < 3; i++)
                  Icon(Icons.star_rounded, color: i < stars ? const Color(0xFFFFB300) : Colors.black26),
              ],
            ),
          ],
          if (news != null) ...[
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(color: const Color(0xFFFFF59D), borderRadius: BorderRadius.circular(14)),
              child: Row(
                children: [
                  news.$1,
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text.rich(
                      TextSpan(
                        children: [
                          TextSpan(text: '${s.newHere}  ', style: const TextStyle(fontWeight: FontWeight.w900, color: Color(0xFFE65100))),
                          TextSpan(text: news.$2),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
      actionsAlignment: MainAxisAlignment.spaceBetween,
      actions: [
        TextButton(onPressed: () => Navigator.pop(context, false), child: Text(s.close)),
        FilledButton.icon(
          style: FilledButton.styleFrom(backgroundColor: const Color(0xFF43A047), padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 12)),
          icon: const Icon(Icons.play_arrow_rounded),
          label: Text(s.play, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
          onPressed: () => Navigator.pop(context, true),
        ),
      ],
    );
  }
}

/// 지도 배경: 지역별 색 그라데이션 + 장식 과일 + 스테이지를 잇는 길.
class _MapPainter extends CustomPainter {
  final double width;
  _MapPainter({required this.width});

  @override
  void paint(Canvas canvas, Size size) {
    final h = size.height;
    // 지역 가운데 높이에 색을 둔 세로 그라데이션 (아래 → 위).
    final stops = <double>[];
    final colors = <Color>[];
    for (var r = Stage.regions - 1; r >= 0; r--) {
      final mid = _MapScreenState.nodePos(r * Stage.perRegion + Stage.perRegion ~/ 2, width).dy;
      stops.add((mid / h).clamp(0.0, 1.0));
      colors.add(_regionColors[r]);
    }
    canvas.drawRect(
      Offset.zero & size,
      Paint()..shader = ui.Gradient.linear(Offset.zero, Offset(0, h), colors, stops),
    );

    // 별빛 정원 위로는 작은 별
    final starPaint = Paint()..color = const Color(0xCCFFFFFF);
    final srng = math.Random(3);
    final nightTop = _MapScreenState.nodePos(5 * Stage.perRegion + 4, width).dy;
    final nightBottom = _MapScreenState.nodePos(4 * Stage.perRegion, width).dy;
    for (var i = 0; i < 60; i++) {
      final y = nightTop + srng.nextDouble() * (nightBottom - nightTop);
      canvas.drawCircle(Offset(srng.nextDouble() * width, y), 1 + srng.nextDouble() * 2, starPaint);
    }

    // 장식 과일: 길에서 떨어진 곳에
    final rng = math.Random(42);
    for (var r = 0; r < Stage.regions; r++) {
      final yBottom = _MapScreenState.nodePos(r * Stage.perRegion, width).dy + 40;
      final yTop = _MapScreenState.nodePos(r * Stage.perRegion + Stage.perRegion - 1, width).dy - 40;
      var placed = 0;
      for (var tries = 0; tries < 80 && placed < 9; tries++) {
        final y = yTop + rng.nextDouble() * (yBottom - yTop);
        final x = 20 + rng.nextDouble() * (width - 40);
        final idx = ((_height(size) - _MapScreenState._bottom - y) / _MapScreenState._spacing).clamp(0.0, Stage.count - 1.0);
        final pathX = width / 2 + math.sin(idx * 0.8) * width * 0.27;
        if ((x - pathX).abs() < 80) continue;
        final piece = _regionDeco[r][placed % 3];
        final rad = 14.0 + rng.nextDouble() * 10;
        drawPiece(canvas, piece, Offset(x, y), rad, face: rng.nextBool(), opacity: 0.55);
        placed++;
      }
    }

    // 길: 부드러운 곡선 + 흰 테두리 + 점선
    final pts = [for (var i = 0; i < Stage.count; i++) _MapScreenState.nodePos(i, width)];
    final path = Path()..moveTo(pts.first.dx, pts.first.dy + 120);
    path.lineTo(pts.first.dx, pts.first.dy);
    for (var i = 0; i < pts.length - 1; i++) {
      final a = pts[i], b = pts[i + 1];
      final mid = Offset((a.dx + b.dx) / 2, (a.dy + b.dy) / 2);
      path.quadraticBezierTo(a.dx, a.dy - (a.dy - mid.dy) * 0.9, mid.dx, mid.dy);
      path.quadraticBezierTo(b.dx, b.dy + (mid.dy - b.dy) * 0.9, b.dx, b.dy);
    }
    canvas.drawPath(
      path,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 40
        ..strokeCap = StrokeCap.round
        ..color = const Color(0x55FFFFFF),
    );
    canvas.drawPath(
      path,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 28
        ..strokeCap = StrokeCap.round
        ..color = const Color(0xFFFFF3E0),
    );
    final dot = Paint()..color = const Color(0xFFFFB74D);
    for (final m in path.computeMetrics()) {
      for (var d = 0.0; d < m.length; d += 26) {
        final t = m.getTangentForOffset(d);
        if (t != null) canvas.drawCircle(t.position, 4, dot);
      }
    }
  }

  double _height(Size size) => size.height;

  @override
  bool shouldRepaint(_MapPainter old) => old.width != width;
}
