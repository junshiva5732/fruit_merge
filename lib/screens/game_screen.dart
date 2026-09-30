import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';

import '../ads/ad_manager.dart';
import '../game/board_painter.dart';
import '../game/world.dart';
import '../l10n/strings.dart';
import '../services/sound.dart';
import '../services/storage.dart';
import '../widgets/banner_ad_widget.dart';
import '../widgets/outlined_text.dart';

/// 스크린샷용: 과일이 쌓인 판으로 시작 (디버그 빌드에서만).
const _demo = bool.fromEnvironment('DEMO');

const _bgTop = Color(0xFFFFCC80);
const _bgBottom = Color(0xFFFF8A65);
const _brown = Color(0xFF5D4037);

class GameScreen extends StatefulWidget {
  final Storage storage;
  const GameScreen({super.key, required this.storage});

  @override
  State<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen> with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  late World _world;
  final _fx = Effects();
  late final Ticker _ticker;
  final _repaint = ValueNotifier<int>(0);
  Duration _last = Duration.zero;
  double _time = 0;

  bool _hammerMode = false;
  bool _usedContinue = false;
  bool _showOver = false;
  bool _newBest = false;
  bool _aiming = false;
  int _shownScore = 0;

  Storage get _storage => widget.storage;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _world = _initialWorld();
    _shownScore = _world.score;
    _ticker = createTicker(_tick)..start();
    if (!_storage.seenHelp && !_demo) {
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        await _showHelp();
        _storage.setSeenHelp();
      });
    }
  }

  World _initialWorld() {
    if (kDebugMode && _demo) return _demoWorld();
    final saved = _storage.savedGame;
    return (saved == null ? null : World.fromJson(saved)) ?? World();
  }

  /// 스크린샷용 판: 여러 과일을 쌓고 물리로 잠깐 굴려 자리 잡게 한다.
  World _demoWorld() {
    final rng = math.Random(11);
    final w = World(random: rng);
    const levels = [8, 7, 6, 6, 5, 5, 4, pieceStone, 3, 3, 3, 2, 2, pieceRainbow, 1, 1, 1, 0, 0, 0, 5, 4, 2, 1];
    var x = 120.0;
    var y = 1200.0;
    for (final l in levels) {
      w.add(l, Offset(x, y));
      x += pieceRadius(l) * 2 + 20;
      if (x > 880) {
        x = 100 + rng.nextDouble() * 80;
        y -= 180;
      }
    }
    for (var i = 0; i < 600; i++) {
      w.step(1 / 60);
    }
    w.events.clear();
    w
      ..score = 1284
      ..current = 3
      ..next = pieceRainbow
      ..aim(430);
    return w;
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _ticker.dispose();
    _repaint.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused || state == AppLifecycleState.inactive) {
      _save();
      if (state == AppLifecycleState.paused) Sound.instance.suspend();
    } else if (state == AppLifecycleState.resumed && !_inAd) {
      Sound.instance.unsuspend();
    }
  }

  /// 전면/보상형 광고를 보여주는 중 (음악을 멈춰 둔다).
  bool _inAd = false;

  void _adStarted() {
    _inAd = true;
    _running = false;
    Sound.instance.suspend();
  }

  void _adEnded() {
    _inAd = false;
    _running = true;
    Sound.instance.unsuspend();
  }

  void _save() {
    if (_demo) return;
    _storage.saveGame(_world.over ? null : _world.toJson());
  }

  // ------------------------------------------------------------------ 루프

  bool _running = true;

  void _tick(Duration elapsed) {
    final dt = _last == Duration.zero ? 0.0 : (elapsed - _last).inMicroseconds / 1e6;
    _last = elapsed;
    if (dt <= 0) return;
    _time += dt;
    if (_running) {
      _world.step(dt);
      for (final e in _world.events) {
        _fx.onEvent(e);
        _onWorldEvent(e);
      }
      _world.events.clear();
      _maybeExplainSpecial();
      if (_world.over && !_showOver) _onGameOver();
    }
    _fx.step(dt);
    if (_world.score != _shownScore) setState(() => _shownScore = _world.score);
    _repaint.value++;
  }

  /// 사건별 소리와 진동.
  void _onWorldEvent(WorldEvent e) {
    final snd = Sound.instance;
    switch (e.type) {
      case EventType.drop:
        snd.play('drop');
        _haptic(HapticFeedback.selectionClick);
        _save();
      case EventType.merge:
        snd.merge(e.piece);
        if (e.combo > 1) snd.play('combo_${math.min(e.combo, World.maxCombo)}');
        _haptic(e.piece >= 7 || e.combo > 2 ? HapticFeedback.mediumImpact : HapticFeedback.lightImpact);
      case EventType.bonus:
        snd.play('bonus');
        _haptic(HapticFeedback.heavyImpact);
      case EventType.boom:
        snd.play('boom');
        _haptic(HapticFeedback.heavyImpact);
      case EventType.crumble:
        snd.play('crumble');
        _haptic(HapticFeedback.mediumImpact);
      case EventType.smash:
        snd.play('smash');
        _haptic(HapticFeedback.heavyImpact);
      case EventType.clear:
        break;
    }
  }

  /// 특수 과일이 처음 "다음"에 나오면 한 번 설명해 준다.
  void _maybeExplainSpecial() {
    final p = _world.next;
    if (!isSpecial(p) || _storage.seenSpecial(p) || _demo) return;
    _storage.setSeenSpecial(p);
    final s = S.of(context);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        duration: const Duration(seconds: 5),
        content: Row(
          children: [
            FruitIcon(p, size: 40),
            const SizedBox(width: 12),
            Expanded(child: Text('${s.newSpecial} ${s.specialHint(p)}')),
          ],
        ),
      ),
    );
  }

  void _haptic(Future<void> Function() f) {
    if (_storage.vibration) f();
  }

  // ---------------------------------------------------------------- 조작

  /// 누르기 시작했을 때의 [World.drops]. 누르고 있는 동안 자동으로 떨어졌으면 손을 떼도 또 떨어뜨리지 않는다.
  int _dropsAtPress = -1;

  void _aim(Offset local, double scale) {
    if (_hammerMode || _world.over) return;
    if (!_aiming) _dropsAtPress = _world.drops;
    _world.aim(local.dx / scale);
    _aiming = true;
  }

  void _release() {
    if (!_aiming) return;
    _aiming = false;
    if (_world.drops != _dropsAtPress) return;
    if (_world.drop()) setState(() {});
  }

  void _tapBoard(Offset local, double scale) {
    if (!_hammerMode) return;
    final f = _world.fruitAt(local / scale);
    if (f == null) return;
    _world.smash(f);
    _storage.setHammers(_storage.hammers - 1);
    setState(() => _hammerMode = false);
    _save();
  }

  Future<void> _onHammer() async {
    if (_world.over) return;
    Sound.instance.play('click');
    if (_hammerMode) {
      setState(() => _hammerMode = false);
      return;
    }
    if (_storage.hammers > 0) {
      setState(() => _hammerMode = true);
      return;
    }
    final s = S.of(context);
    final go = await _pausedWhile(
      () => showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          icon: const Icon(Icons.gavel_rounded, size: 36),
          title: Text(s.hammerGet),
          content: Text(s.hammerGetBody),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(s.cancel)),
            FilledButton.icon(
              icon: const Icon(Icons.ondemand_video_rounded),
              label: Text(s.watchAd),
              onPressed: () => Navigator.pop(ctx, true),
            ),
          ],
        ),
      ),
    );
    if (go != true || !mounted) return;
    _adStarted();
    final shown = AdManager.instance.showRewarded(
      onReward: () {
        _storage.setHammers(_storage.hammers + 2);
        Sound.instance.play('reward');
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(s.hammersGot(2))));
      },
      onClosed: () {
        _adEnded();
        if (mounted) setState(() {});
      },
    );
    if (!shown) {
      _adEnded();
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(s.adNotReady)));
    }
  }

  /// 대화상자가 떠 있는 동안 물리를 멈춘다.
  Future<T?> _pausedWhile<T>(Future<T?> Function() f) async {
    _running = false;
    try {
      return await f();
    } finally {
      _running = true;
    }
  }

  // ------------------------------------------------------------ 게임 오버

  void _onGameOver() {
    Sound.instance.play('gameover');
    _haptic(HapticFeedback.heavyImpact);
    _storage.submitBiggest(_world.biggest);
    final isBest = _storage.submitScore(_world.score);
    _storage.saveGame(null);
    setState(() {
      _showOver = true;
      _newBest = _newBest || isBest;
      _hammerMode = false;
    });
  }

  void _continue() {
    final s = S.of(context);
    _adStarted();
    final shown = AdManager.instance.showRewarded(
      onReward: () {
        _world.rescue();
        _usedContinue = true;
        _showOver = false;
        Sound.instance.play('reward');
      },
      onClosed: () {
        _adEnded();
        if (mounted) setState(() {});
        _save();
      },
    );
    if (!shown) {
      _adEnded();
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(s.adNotReady)));
    }
  }

  void _playAgain() {
    Sound.instance.play('click');
    _adStarted();
    AdManager.instance.showInterstitialThen(() {
      _adEnded();
      if (!mounted) return;
      _newGame();
    });
  }

  void _newGame() {
    setState(() {
      _world = World();
      _fx.clear();
      _usedContinue = false;
      _showOver = false;
      _newBest = false;
      _hammerMode = false;
      _shownScore = 0;
    });
    _save();
  }

  // ----------------------------------------------------------------- 메뉴

  Future<void> _showMenu() async {
    Sound.instance.play('click');
    final s = S.of(context);
    final action = await _pausedWhile(
      () => showDialog<String>(
        context: context,
        builder: (ctx) => StatefulBuilder(
          builder: (ctx, setLocal) => AlertDialog(
            title: Text(s.paused, textAlign: TextAlign.center),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                FilledButton.icon(
                  icon: const Icon(Icons.play_arrow_rounded),
                  label: Text(s.resume),
                  onPressed: () => Navigator.pop(ctx),
                ),
                const SizedBox(height: 8),
                OutlinedButton.icon(
                  icon: const Icon(Icons.refresh_rounded),
                  label: Text(s.restart),
                  onPressed: () => Navigator.pop(ctx, 'restart'),
                ),
                const SizedBox(height: 8),
                OutlinedButton.icon(
                  icon: const Icon(Icons.help_outline_rounded),
                  label: Text(s.howToPlay),
                  onPressed: () => Navigator.pop(ctx, 'help'),
                ),
                const SizedBox(height: 8),
                OutlinedButton.icon(
                  icon: const Icon(Icons.language_rounded),
                  label: Text(s.language),
                  onPressed: () => Navigator.pop(ctx, 'lang'),
                ),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  secondary: const Icon(Icons.music_note_rounded),
                  title: Text(s.music),
                  value: _storage.music,
                  onChanged: (v) {
                    _storage.setMusic(v);
                    Sound.instance.setMusic(v);
                    setLocal(() {});
                  },
                ),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  secondary: const Icon(Icons.volume_up_rounded),
                  title: Text(s.soundEffects),
                  value: _storage.sfx,
                  onChanged: (v) {
                    _storage.setSfx(v);
                    Sound.instance.setSfx(v);
                    Sound.instance.play('click');
                    setLocal(() {});
                  },
                ),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  secondary: const Icon(Icons.vibration_rounded),
                  title: Text(s.vibration),
                  value: _storage.vibration,
                  onChanged: (v) {
                    _storage.setVibration(v);
                    setLocal(() {});
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
    if (!mounted) return;
    switch (action) {
      case 'restart':
        final ok = await _pausedWhile(
          () => showDialog<bool>(
            context: context,
            builder: (ctx) => AlertDialog(
              title: Text(s.restartAsk),
              actions: [
                TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(s.no)),
                FilledButton(onPressed: () => Navigator.pop(ctx, true), child: Text(s.yes)),
              ],
            ),
          ),
        );
        if (ok == true) {
          _storage.submitScore(_world.score);
          _storage.submitBiggest(_world.biggest);
          _newGame();
        }
      case 'help':
        await _showHelp();
      case 'lang':
        await _showLanguage();
    }
  }

  Future<void> _showHelp() {
    final s = S.of(context);
    return _pausedWhile(
      () => showDialog<void>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text(s.howToPlay),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _EvolutionChart(biggest: maxLevel, size: 30),
                const SizedBox(height: 12),
                Text(s.helpBody),
              ],
            ),
          ),
          actions: [FilledButton(onPressed: () => Navigator.pop(ctx), child: Text(s.close))],
        ),
      ),
    );
  }

  Future<void> _showLanguage() async {
    final s = S.of(context);
    final controller = LocaleController.of(context);
    final picked = await _pausedWhile(
      () => showDialog<Locale?>(
        context: context,
        builder: (ctx) => SimpleDialog(
          title: Text(s.language),
          children: [
            RadioGroup<Locale?>(
              groupValue: controller.value,
              onChanged: (v) => Navigator.pop(ctx, v ?? const Locale('und')),
              child: Column(
                children: [
                  for (final l in <Locale?>[null, ...S.supported])
                    RadioListTile<Locale?>(value: l, title: Text(l == null ? s.systemLanguage : S.nativeName(l))),
                ],
              ),
            ),
          ],
        ),
      ),
    );
    if (picked == null) return;
    controller.value = picked.languageCode == 'und' ? null : picked;
  }

  // ----------------------------------------------------------------- 화면

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    return Scaffold(
      body: DecoratedBox(
        decoration: const BoxDecoration(
          gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [_bgTop, _bgBottom]),
        ),
        child: Stack(
          children: [
            Column(
              children: [
                SafeArea(
                  bottom: false,
                  child: _TopBar(
                    score: _shownScore,
                    best: math.max(_storage.best, _world.score),
                    next: _world.next,
                    onMenu: _showMenu,
                  ),
                ),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(12, 4, 12, 4),
                    child: Center(
                      child: AspectRatio(
                        aspectRatio: World.width / World.height,
                        child: LayoutBuilder(
                          builder: (context, box) {
                            final scale = box.maxWidth / World.width;
                            return GestureDetector(
                              behavior: HitTestBehavior.opaque,
                              onPanDown: (d) => _aim(d.localPosition, scale),
                              onPanUpdate: (d) => _aim(d.localPosition, scale),
                              onPanEnd: (_) => _release(),
                              onPanCancel: _release,
                              onTapUp: (d) => _tapBoard(d.localPosition, scale),
                              child: CustomPaint(
                                size: Size(box.maxWidth, box.maxHeight),
                                painter: BoardPainter(
                                  world: _world,
                                  fx: _fx,
                                  time: _time,
                                  hammer: _hammerMode,
                                  showAim: true,
                                  comboLabel: s.combo,
                                  repaint: _repaint,
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                    ),
                  ),
                ),
                if (_hammerMode)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: OutlinedText(s.hammerHint, size: 18, strokeWidth: 4),
                  ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 0, 12, 6),
                  child: Row(
                    children: [
                      Expanded(child: _EvolutionChart(biggest: _world.biggest, size: 28)),
                      const SizedBox(width: 8),
                      _HammerButton(count: _storage.hammers, active: _hammerMode, onTap: _onHammer),
                    ],
                  ),
                ),
                const BannerAdWidget(),
              ],
            ),
            if (_showOver)
              Positioned.fill(
                child: _GameOverPanel(
                  score: _world.score,
                  best: _storage.best,
                  newBest: _newBest,
                  biggest: _world.biggest,
                  canContinue: !_usedContinue,
                  onContinue: _continue,
                  onPlayAgain: _playAgain,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _TopBar extends StatelessWidget {
  final int score;
  final int best;
  final int next;
  final VoidCallback onMenu;
  const _TopBar({required this.score, required this.best, required this.next, required this.onMenu});

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 4, 12, 0),
      child: Row(
        children: [
          IconButton.filledTonal(
            onPressed: onMenu,
            icon: const Icon(Icons.pause_rounded, size: 28),
            style: IconButton.styleFrom(backgroundColor: Colors.white70, foregroundColor: _brown),
          ),
          Expanded(
            child: Column(
              children: [
                OutlinedText('$score', size: 38),
                Text(
                  '${s.best} $best',
                  style: const TextStyle(fontWeight: FontWeight.w800, color: _brown, fontSize: 14),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.fromLTRB(10, 4, 10, 4),
            decoration: BoxDecoration(color: Colors.white70, borderRadius: BorderRadius.circular(16)),
            child: Column(
              children: [
                Text(s.next, style: const TextStyle(fontWeight: FontWeight.w900, color: _brown, fontSize: 12)),
                FruitIcon(next, size: 40),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// 과일 진화표: 체리 → … → 수박. 이번 판에 아직 못 만든 과일은 흐리게.
class _EvolutionChart extends StatelessWidget {
  final int biggest;
  final double size;
  const _EvolutionChart({required this.biggest, required this.size});

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    return Tooltip(
      message: s.evolution,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
        decoration: BoxDecoration(color: Colors.white60, borderRadius: BorderRadius.circular(size)),
        child: FittedBox(
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (var l = 0; l <= maxLevel; l++)
                Opacity(opacity: l <= math.max(biggest, 4) ? 1 : 0.3, child: FruitIcon(l, size: size, face: false)),
            ],
          ),
        ),
      ),
    );
  }
}

class _HammerButton extends StatelessWidget {
  final int count;
  final bool active;
  final VoidCallback onTap;
  const _HammerButton({required this.count, required this.active, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    return Badge(
      label: count > 0 ? Text('$count') : const Icon(Icons.play_arrow_rounded, size: 12, color: Colors.white),
      backgroundColor: count > 0 ? const Color(0xFFE53935) : const Color(0xFF43A047),
      largeSize: 20,
      child: Tooltip(
        message: s.hammer,
        child: IconButton.filled(
          onPressed: onTap,
          iconSize: 30,
          style: IconButton.styleFrom(
            backgroundColor: active ? const Color(0xFFFFEB3B) : Colors.white,
            foregroundColor: _brown,
            side: BorderSide(color: active ? const Color(0xFFE65100) : _brown, width: 2),
          ),
          icon: Icon(active ? Icons.close_rounded : Icons.gavel_rounded),
        ),
      ),
    );
  }
}

class _GameOverPanel extends StatelessWidget {
  final int score;
  final int best;
  final bool newBest;
  final int biggest;
  final bool canContinue;
  final VoidCallback onContinue;
  final VoidCallback onPlayAgain;

  const _GameOverPanel({
    required this.score,
    required this.best,
    required this.newBest,
    required this.biggest,
    required this.canContinue,
    required this.onContinue,
    required this.onPlayAgain,
  });

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    return ColoredBox(
      color: Colors.black54,
      child: Center(
        child: TweenAnimationBuilder<double>(
          tween: Tween(begin: 0.6, end: 1),
          duration: const Duration(milliseconds: 450),
          curve: Curves.easeOutBack,
          builder: (context, v, child) => Transform.scale(scale: v, child: child),
          child: Container(
            width: 320,
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
            decoration: BoxDecoration(
              color: const Color(0xFFFFF8E1),
              borderRadius: BorderRadius.circular(28),
              border: Border.all(color: const Color(0xFFA1887F), width: 4),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                OutlinedText(s.gameOver, size: 34, color: const Color(0xFFFF7043)),
                const SizedBox(height: 12),
                Text(s.score, style: const TextStyle(fontWeight: FontWeight.w800, color: _brown)),
                OutlinedText('$score', size: 48),
                if (newBest) OutlinedText(s.newBest, size: 22, color: const Color(0xFFFFEB3B), strokeWidth: 5),
                Text('${s.best} $best', style: const TextStyle(fontWeight: FontWeight.w700, color: _brown)),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    FruitIcon(biggest, size: 48),
                    const SizedBox(width: 8),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(s.biggestFruit, style: const TextStyle(fontSize: 12, color: _brown)),
                        Text(s.fruitName(biggest), style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: _brown)),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                if (canContinue) ...[
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      style: FilledButton.styleFrom(backgroundColor: const Color(0xFF43A047), padding: const EdgeInsets.symmetric(vertical: 12)),
                      icon: const Icon(Icons.ondemand_video_rounded),
                      label: Text(s.continueRun, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
                      onPressed: onContinue,
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.only(top: 4, bottom: 8),
                    child: Text(s.continueHint, textAlign: TextAlign.center, style: const TextStyle(fontSize: 12, color: _brown)),
                  ),
                ],
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    style: FilledButton.styleFrom(backgroundColor: const Color(0xFFFF7043), padding: const EdgeInsets.symmetric(vertical: 12)),
                    icon: const Icon(Icons.refresh_rounded),
                    label: Text(s.playAgain, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
                    onPressed: onPlayAgain,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
