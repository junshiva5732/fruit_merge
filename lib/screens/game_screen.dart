import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';

import '../ads/ad_manager.dart';
import '../game/board_painter.dart';
import '../game/stages.dart';
import '../game/world.dart';
import '../l10n/strings.dart';
import '../services/challenge.dart';
import '../services/sound.dart';
import '../services/storage.dart';
import '../widgets/banner_ad_widget.dart';
import '../widgets/dialogs.dart';
import '../widgets/outlined_text.dart';
import '../widgets/share_sheet.dart';

/// 스크린샷용: 과일이 쌓인 판으로 시작 (디버그 빌드에서만).
const _demo = bool.fromEnvironment('DEMO');

const _bgTop = Color(0xFFFFCC80);
const _bgBottom = Color(0xFFFF8A65);

/// 결과 화면 종류.
enum _Panel { none, gameOver, clear, failOverflow, failDrops }

/// 게임 화면. [stage] 가 null 이면 무한 모드 (점수에 따라 어려워지고, 진행 중인 판을 저장),
/// 있으면 스테이지 모드 (목표 · 과일 수 제한 · 별).
class GameScreen extends StatefulWidget {
  final Storage storage;
  final Stage? stage;

  /// 친구 도전장으로 시작했으면 친구 점수 (이기면 축하, 결과에 비교 표시).
  final int? friendScore;
  const GameScreen({super.key, required this.storage, this.stage, this.friendScore});

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
  _Panel _panel = _Panel.none;
  bool _newBest = false;
  bool _aiming = false;

  /// 스테이지: 목표 달성 후 / 과일을 다 쓴 후 기다린 시간 (합쳐지는 모습을 보여 주려고 잠깐 둔다).
  double _clearWait = 0;
  double _outWait = 0;
  int _stars = 0;
  bool _hammerBonus = false;

  /// 위쪽 표시가 바뀌었는지 확인용 (바뀔 때만 다시 그린다).
  Object? _hud;

  Storage get _storage => widget.storage;
  Stage? get _stage => widget.stage;
  int? get _friend => widget.friendScore;

  /// 친구 점수를 넘었는지 (한 번만 축하).
  bool _beatFriend = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _world = _initialWorld();
    _ticker = createTicker(_tick)..start();
    if (!_storage.seenHelp && !_demo) {
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        await _pausedWhile(() => showHelpDialog(context));
        _storage.setSeenHelp();
      });
    }
  }

  World _initialWorld() {
    final st = _stage;
    if (st != null) return st.createWorld();
    if (kDebugMode && _demo) return _demoWorld();
    if (_friend != null) return World(); // 도전은 새 판으로
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

  /// 무한 모드만 진행 중인 판을 저장한다 (친구 도전 판은 저장하지 않아 원래 이어하던 판이 남는다).
  void _save() {
    if (_demo || _stage != null || _friend != null) return;
    _storage.saveGame(_world.over ? null : _world.toJson());
  }

  // ------------------------------------------------------------------ 루프

  bool _running = true;

  void _tick(Duration elapsed) {
    final dt = _last == Duration.zero ? 0.0 : (elapsed - _last).inMicroseconds / 1e6;
    _last = elapsed;
    if (dt <= 0) return;
    _time += dt;
    if (_running && _panel == _Panel.none) {
      _world.step(dt);
      for (final e in _world.events) {
        _fx.onEvent(e);
        _onWorldEvent(e);
      }
      _world.events.clear();
      _maybeExplainSpecial();
      _checkFriend();
      _checkEnd(dt);
    }
    _fx.step(dt);
    final hud = (_world.score, _world.dropsLeft, _world.stonesBroken, _world.biggest, _world.next);
    if (hud != _hud) setState(() => _hud = hud);
    _repaint.value++;
  }

  void _checkFriend() {
    final f = _friend;
    if (f == null || _beatFriend || _world.score <= f) return;
    _beatFriend = true;
    Sound.instance.play('stageclear');
    _haptic(HapticFeedback.heavyImpact);
    _fx.popups.add(Popup(const Offset(World.width / 2, World.lineY + 300), S.of(context).beatFriend, big: true));
  }

  /// 자랑하기: 무한 모드는 점수, 스테이지는 번호 + 별.
  void _share() {
    final st = _stage;
    showShareSheet(
      context,
      challenge: st == null
          ? Challenge(score: _world.score)
          : Challenge(score: _world.score, stage: st.number, stars: _stars),
      fruit: _world.biggest,
    );
  }

  void _checkEnd(double dt) {
    final st = _stage;
    if (st == null) {
      if (_world.over) _onGameOver();
      return;
    }
    if (st.achieved(_world)) {
      _clearWait += dt;
      if (_clearWait > 0.8) _onStageClear();
    } else if (_world.over) {
      _onStageFail(_Panel.failOverflow);
    } else if (_world.dropsLeft == 0) {
      _outWait += dt;
      if (_outWait > 2.5) _onStageFail(_Panel.failDrops);
    } else {
      _outWait = 0;
    }
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
    if (_hammerMode || _world.over || _panel != _Panel.none) return;
    if (!_aiming) _dropsAtPress = _world.drops;
    _world.aim(local.dx / scale);
    _aiming = true;
  }

  void _release() {
    if (!_aiming) return;
    _aiming = false;
    if (_world.drops != _dropsAtPress || _panel != _Panel.none) return;
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
    if (_world.over || _panel != _Panel.none) return;
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
    _showRewarded(() {
      _storage.setHammers(_storage.hammers + 2);
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(s.hammersGot(2))));
    });
  }

  /// 보상형 광고 → 끝까지 보면 [onReward].
  void _showRewarded(VoidCallback onReward) {
    final s = S.of(context);
    _adStarted();
    final shown = AdManager.instance.showRewarded(
      onReward: () {
        onReward();
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

  /// 대화상자가 떠 있는 동안 물리를 멈춘다.
  Future<T?> _pausedWhile<T>(Future<T?> Function() f) async {
    _running = false;
    try {
      return await f();
    } finally {
      _running = true;
    }
  }

  // -------------------------------------------------------- 끝 (무한 모드)

  void _onGameOver() {
    Sound.instance.play('gameover');
    _haptic(HapticFeedback.heavyImpact);
    _storage.submitBiggest(_world.biggest);
    final isBest = _storage.submitScore(_world.score);
    _storage.saveGame(null);
    setState(() {
      _panel = _Panel.gameOver;
      _newBest = _newBest || isBest;
      _hammerMode = false;
    });
  }

  // ------------------------------------------------------- 끝 (스테이지)

  void _onStageClear() {
    final st = _stage!;
    _stars = st.starsFor(_world);
    final first = _storage.recordStars(st.number, _stars);
    _hammerBonus = first && st.givesHammer;
    if (_hammerBonus) _storage.setHammers(_storage.hammers + 1);
    _storage.submitBiggest(_world.biggest);
    Sound.instance.play('stageclear');
    _haptic(HapticFeedback.heavyImpact);
    setState(() {
      _panel = _Panel.clear;
      _hammerMode = false;
    });
  }

  void _onStageFail(_Panel why) {
    Sound.instance.play('gameover');
    _haptic(HapticFeedback.heavyImpact);
    setState(() {
      _panel = why;
      _hammerMode = false;
    });
  }

  /// 이어하기 (광고): 무한 모드·넘침은 위쪽 정리, 과일 부족은 +5개.
  void _continue() {
    final why = _panel;
    _showRewarded(() {
      if (why == _Panel.failDrops) {
        _world.extraDrops += 5;
      } else {
        _world.rescue();
      }
      _usedContinue = true;
      _outWait = 0;
      _clearWait = 0;
      _panel = _Panel.none;
    });
  }

  /// 전면 광고(빈도 제한) 뒤에 [then].
  void _afterInterstitial(VoidCallback then) {
    Sound.instance.play('click');
    _adStarted();
    AdManager.instance.showInterstitialThen(() {
      _adEnded();
      if (mounted) then();
    });
  }

  void _playAgain() => _afterInterstitial(_newGame);

  void _nextStage() => _afterInterstitial(() {
    final next = Stage.of(_stage!.number + 1);
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => GameScreen(storage: _storage, stage: next)),
    );
  });

  void _toMap() {
    _save();
    if (_panel == _Panel.none) {
      Navigator.of(context).pop();
    } else {
      _afterInterstitial(() => Navigator.of(context).pop());
    }
  }

  void _newGame() {
    setState(() {
      _world = _stage?.createWorld() ?? World();
      _fx.clear();
      _usedContinue = false;
      _panel = _Panel.none;
      _newBest = false;
      _hammerMode = false;
      _clearWait = 0;
      _outWait = 0;
    });
    _save();
  }

  // ----------------------------------------------------------------- 메뉴

  Future<void> _showMenu() async {
    if (_panel != _Panel.none) return;
    Sound.instance.play('click');
    final s = S.of(context);
    final st = _stage;
    final action = await _pausedWhile(
      () => showDialog<String>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text(st == null ? s.paused : s.stageN(st.number), textAlign: TextAlign.center),
          content: SingleChildScrollView(
            child: Column(
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
                  label: Text(st == null ? s.restart : s.retry),
                  onPressed: () => Navigator.pop(ctx, 'restart'),
                ),
                const SizedBox(height: 8),
                OutlinedButton.icon(
                  icon: const Icon(Icons.map_rounded),
                  label: Text(s.toMap),
                  onPressed: () => Navigator.pop(ctx, 'map'),
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
                SoundSwitches(storage: _storage),
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
          if (st == null) {
            _storage.submitScore(_world.score);
            _storage.submitBiggest(_world.biggest);
          }
          _newGame();
        }
      case 'map':
        if (st == null) {
          _storage.submitScore(_world.score);
          _storage.submitBiggest(_world.biggest);
        }
        _toMap();
      case 'help':
        await _pausedWhile(() => showHelpDialog(context));
      case 'lang':
        await _pausedWhile(() => showLanguageDialog(context));
    }
  }

  // ----------------------------------------------------------------- 화면

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final st = _stage;
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _panel == _Panel.none ? _showMenu() : _toMap();
      },
      child: Scaffold(
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
                    child: st == null
                        ? _TopBar(
                            score: _world.score,
                            best: math.max(_storage.best, _world.score),
                            friend: _friend,
                            next: _world.next,
                            onMenu: _showMenu,
                          )
                        : _StageTopBar(stage: st, world: _world, onMenu: _showMenu),
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
                                    showAim: _panel == _Panel.none,
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
                        Expanded(child: EvolutionChart(biggest: _world.biggest, size: 28)),
                        const SizedBox(width: 8),
                        _HammerButton(count: _storage.hammers, active: _hammerMode, onTap: _onHammer),
                      ],
                    ),
                  ),
                  const BannerAdWidget(),
                ],
              ),
              if (_panel != _Panel.none) Positioned.fill(child: _panelWidget(s)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _panelWidget(S s) {
    final st = _stage;
    return switch (_panel) {
      _Panel.gameOver => _GameOverPanel(
        score: _world.score,
        best: _storage.best,
        newBest: _newBest,
        biggest: _world.biggest,
        canContinue: !_usedContinue,
        friend: _friend,
        onContinue: _continue,
        onPlayAgain: _playAgain,
        onShare: _share,
        onMap: _toMap,
      ),
      _Panel.clear => _StageClearPanel(
        stage: st!,
        stars: _stars,
        score: _world.score,
        hammerBonus: _hammerBonus,
        friend: _friend,
        onShare: _share,
        onNext: st.number < Stage.count ? _nextStage : null,
        onRetry: _playAgain,
        onMap: _toMap,
      ),
      _ => _StageFailPanel(
        stage: st!,
        reason: _panel == _Panel.failDrops ? s.outOfDrops : s.overflow,
        continueLabel: _panel == _Panel.failDrops ? s.plusDrops : s.continueRun,
        continueHint: _panel == _Panel.failDrops ? s.plusDropsHint : s.continueHint,
        canContinue: !_usedContinue,
        progress: st.progress(_world),
        onContinue: _continue,
        onRetry: _playAgain,
        onMap: _toMap,
      ),
    };
  }
}

// ======================================================================= 위쪽

Widget _pauseButton(VoidCallback onMenu) => IconButton.filledTonal(
  onPressed: onMenu,
  icon: const Icon(Icons.pause_rounded, size: 28),
  style: IconButton.styleFrom(backgroundColor: Colors.white70, foregroundColor: brown),
);

Widget _nextBox(BuildContext context, int next) {
  final s = S.of(context);
  return Container(
    padding: const EdgeInsets.fromLTRB(10, 4, 10, 4),
    decoration: BoxDecoration(color: Colors.white70, borderRadius: BorderRadius.circular(16)),
    child: Column(
      children: [
        Text(s.next, style: const TextStyle(fontWeight: FontWeight.w900, color: brown, fontSize: 12)),
        FruitIcon(next, size: 40),
      ],
    ),
  );
}

class _TopBar extends StatelessWidget {
  final int score;
  final int best;
  final int? friend;
  final int next;
  final VoidCallback onMenu;
  const _TopBar({required this.score, required this.best, this.friend, required this.next, required this.onMenu});

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 4, 12, 0),
      child: Row(
        children: [
          _pauseButton(onMenu),
          Expanded(
            child: Column(
              children: [
                OutlinedText('$score', size: 38),
                if (friend != null)
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        score > friend! ? Icons.emoji_events_rounded : Icons.flag_rounded,
                        size: 16,
                        color: score > friend! ? const Color(0xFFFFB300) : const Color(0xFFE53935),
                      ),
                      Text(
                        S.of(context).friendTarget(friend!),
                        style: TextStyle(
                          fontWeight: FontWeight.w900,
                          fontSize: 14,
                          color: score > friend! ? const Color(0xFF2E7D32) : const Color(0xFFC62828),
                        ),
                      ),
                    ],
                  )
                else
                  Text('${s.best} $best', style: const TextStyle(fontWeight: FontWeight.w800, color: brown, fontSize: 14)),
              ],
            ),
          ),
          _nextBox(context, next),
        ],
      ),
    );
  }
}

/// 스테이지 모드 위쪽: 스테이지 번호 · 목표 진행 · 남은 과일 · 다음 과일.
class _StageTopBar extends StatelessWidget {
  final Stage stage;
  final World world;
  final VoidCallback onMenu;
  const _StageTopBar({required this.stage, required this.world, required this.onMenu});

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final done = stage.achieved(world);
    final (Widget icon, String text) = switch (stage.goal) {
      GoalType.score => (const Icon(Icons.emoji_events_rounded, color: Color(0xFFFFB300), size: 26), '${world.score} / ${stage.target}'),
      GoalType.fruit => (FruitIcon(stage.target, size: 30), s.fruitName(stage.target)),
      GoalType.stones => (const FruitIcon(pieceStone, size: 30), '${world.stonesBroken} / ${stage.target}'),
    };
    final left = world.dropsLeft ?? 0;
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 4, 12, 0),
      child: Row(
        children: [
          _pauseButton(onMenu),
          const SizedBox(width: 4),
          Expanded(
            child: Column(
              children: [
                Text(s.stageN(stage.number), style: const TextStyle(fontWeight: FontWeight.w900, color: brown, fontSize: 15)),
                const SizedBox(height: 2),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    icon,
                    const SizedBox(width: 4),
                    Flexible(
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: OutlinedText(text, size: 22, strokeWidth: 5),
                      ),
                    ),
                    if (done) const Icon(Icons.check_circle_rounded, color: Color(0xFF43A047), size: 24),
                  ],
                ),
                const SizedBox(height: 4),
                ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: LinearProgressIndicator(
                    value: stage.progress(world),
                    minHeight: 8,
                    backgroundColor: Colors.white54,
                    color: done ? const Color(0xFF43A047) : const Color(0xFFFF7043),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.fromLTRB(10, 4, 10, 4),
            decoration: BoxDecoration(
              color: left <= 5 ? const Color(0xFFFFCDD2) : Colors.white70,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              children: [
                Text(s.dropsLeft, style: const TextStyle(fontWeight: FontWeight.w900, color: brown, fontSize: 12)),
                SizedBox(
                  height: 40,
                  child: Center(
                    child: OutlinedText('$left', size: 28, color: left <= 5 ? const Color(0xFFFF5252) : Colors.white, strokeWidth: 5),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 6),
          _nextBox(context, world.next),
        ],
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
            foregroundColor: brown,
            side: BorderSide(color: active ? const Color(0xFFE65100) : brown, width: 2),
          ),
          icon: Icon(active ? Icons.close_rounded : Icons.gavel_rounded),
        ),
      ),
    );
  }
}

// ================================================================== 결과 화면

/// 가운데 카드 + 튀어나오는 애니메이션.
class _PanelCard extends StatelessWidget {
  final List<Widget> children;
  const _PanelCard({required this.children});

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: Colors.black54,
      child: Center(
        child: SingleChildScrollView(
          child: TweenAnimationBuilder<double>(
            tween: Tween(begin: 0.6, end: 1),
            duration: const Duration(milliseconds: 450),
            curve: Curves.easeOutBack,
            builder: (context, v, child) => Transform.scale(scale: v, child: child),
            child: Container(
              width: 320,
              margin: const EdgeInsets.all(16),
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
              decoration: BoxDecoration(
                color: const Color(0xFFFFF8E1),
                borderRadius: BorderRadius.circular(28),
                border: Border.all(color: const Color(0xFFA1887F), width: 4),
              ),
              child: Column(mainAxisSize: MainAxisSize.min, children: children),
            ),
          ),
        ),
      ),
    );
  }
}

Widget _bigButton(String label, IconData icon, Color color, VoidCallback onTap) => SizedBox(
  width: double.infinity,
  child: FilledButton.icon(
    style: FilledButton.styleFrom(backgroundColor: color, padding: const EdgeInsets.symmetric(vertical: 12)),
    icon: Icon(icon),
    label: Text(label, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
    onPressed: onTap,
  ),
);

Widget _hint(String text) => Padding(
  padding: const EdgeInsets.only(top: 4, bottom: 8),
  child: Text(text, textAlign: TextAlign.center, style: const TextStyle(fontSize: 12, color: brown)),
);

/// 자랑하기 (노란 버튼: 카카오톡 느낌).
Widget _shareButton(String label, VoidCallback onTap) => SizedBox(
  width: double.infinity,
  child: FilledButton.icon(
    style: FilledButton.styleFrom(
      backgroundColor: const Color(0xFFFEE500),
      foregroundColor: const Color(0xFF3C1E1E),
      padding: const EdgeInsets.symmetric(vertical: 12),
    ),
    icon: const Icon(Icons.share_rounded),
    label: Text(label, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
    onPressed: onTap,
  ),
);

/// 친구 점수와 비교: 이겼다! / N점 모자라요!
class _VsFriend extends StatelessWidget {
  final int score;
  final int friend;
  const _VsFriend({required this.score, required this.friend});

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final win = score > friend;
    return Container(
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
      decoration: BoxDecoration(
        color: win ? const Color(0xFFC8E6C9) : const Color(0xFFFFCDD2),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Text(
        '${s.friendTarget(friend)} · ${win ? s.vsWin : s.vsLose(friend - score)}',
        style: TextStyle(fontWeight: FontWeight.w900, color: win ? const Color(0xFF2E7D32) : const Color(0xFFC62828)),
      ),
    );
  }
}

Widget _mapButton(String label, VoidCallback onTap) => TextButton.icon(
  onPressed: onTap,
  icon: const Icon(Icons.map_rounded, color: brown),
  label: Text(label, style: const TextStyle(color: brown, fontWeight: FontWeight.w700)),
);

class _GameOverPanel extends StatelessWidget {
  final int score;
  final int best;
  final bool newBest;
  final int biggest;
  final bool canContinue;
  final int? friend;
  final VoidCallback onContinue;
  final VoidCallback onPlayAgain;
  final VoidCallback onShare;
  final VoidCallback onMap;

  const _GameOverPanel({
    required this.score,
    required this.best,
    required this.newBest,
    required this.biggest,
    required this.canContinue,
    required this.friend,
    required this.onContinue,
    required this.onPlayAgain,
    required this.onShare,
    required this.onMap,
  });

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    return _PanelCard(
      children: [
        OutlinedText(s.gameOver, size: 34, color: const Color(0xFFFF7043)),
        const SizedBox(height: 12),
        Text(s.score, style: const TextStyle(fontWeight: FontWeight.w800, color: brown)),
        OutlinedText('$score', size: 48),
        if (newBest) OutlinedText(s.newBest, size: 22, color: const Color(0xFFFFEB3B), strokeWidth: 5),
        Text('${s.best} $best', style: const TextStyle(fontWeight: FontWeight.w700, color: brown)),
        if (friend != null) _VsFriend(score: score, friend: friend!),
        const SizedBox(height: 12),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            FruitIcon(biggest, size: 48),
            const SizedBox(width: 8),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(s.biggestFruit, style: const TextStyle(fontSize: 12, color: brown)),
                Text(s.fruitName(biggest), style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: brown)),
              ],
            ),
          ],
        ),
        const SizedBox(height: 16),
        if (canContinue) ...[
          _bigButton(s.continueRun, Icons.ondemand_video_rounded, const Color(0xFF43A047), onContinue),
          _hint(s.continueHint),
        ],
        _bigButton(s.playAgain, Icons.refresh_rounded, const Color(0xFFFF7043), onPlayAgain),
        const SizedBox(height: 8),
        _shareButton(s.brag, onShare),
        _mapButton(s.toMap, onMap),
      ],
    );
  }
}

class _StageClearPanel extends StatefulWidget {
  final Stage stage;
  final int stars;
  final int score;
  final bool hammerBonus;
  final int? friend;
  final VoidCallback onShare;
  final VoidCallback? onNext;
  final VoidCallback onRetry;
  final VoidCallback onMap;

  const _StageClearPanel({
    required this.stage,
    required this.stars,
    required this.score,
    required this.hammerBonus,
    required this.friend,
    required this.onShare,
    required this.onNext,
    required this.onRetry,
    required this.onMap,
  });

  @override
  State<_StageClearPanel> createState() => _StageClearPanelState();
}

class _StageClearPanelState extends State<_StageClearPanel> {
  /// 별이 하나씩 "띵" 하고 나타난다.
  int _shown = 0;

  @override
  void initState() {
    super.initState();
    for (var i = 0; i < widget.stars; i++) {
      Future.delayed(Duration(milliseconds: 500 + i * 380), () {
        if (!mounted) return;
        Sound.instance.play('star');
        setState(() => _shown = i + 1);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    return _PanelCard(
      children: [
        Text(s.stageN(widget.stage.number), style: const TextStyle(fontWeight: FontWeight.w900, color: brown)),
        FittedBox(fit: BoxFit.scaleDown, child: OutlinedText(s.stageClear, size: 34, color: const Color(0xFFFFEB3B))),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            for (var i = 0; i < 3; i++)
              Padding(
                padding: EdgeInsets.only(bottom: i == 1 ? 14 : 0),
                child: AnimatedScale(
                  scale: i < _shown ? 1 : 0.6,
                  duration: const Duration(milliseconds: 350),
                  curve: Curves.elasticOut,
                  child: Icon(
                    Icons.star_rounded,
                    size: i == 1 ? 72 : 58,
                    color: i < _shown ? const Color(0xFFFFB300) : Colors.black12,
                    shadows: i < _shown ? const [Shadow(color: Color(0xFFE65100), offset: Offset(0, 3))] : null,
                  ),
                ),
              ),
          ],
        ),
        Text(s.score, style: const TextStyle(fontWeight: FontWeight.w800, color: brown)),
        OutlinedText('${widget.score}', size: 40),
        if (widget.friend != null) _VsFriend(score: widget.score, friend: widget.friend!),
        if (widget.hammerBonus)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.gavel_rounded, color: brown),
                const SizedBox(width: 6),
                Text(s.hammerReward, style: const TextStyle(fontWeight: FontWeight.w900, color: Color(0xFFE65100))),
              ],
            ),
          ),
        const SizedBox(height: 16),
        if (widget.onNext != null) ...[
          _bigButton(s.nextStage, Icons.arrow_forward_rounded, const Color(0xFF43A047), widget.onNext!),
          const SizedBox(height: 8),
        ],
        _bigButton(s.retry, Icons.refresh_rounded, const Color(0xFFFF7043), widget.onRetry),
        const SizedBox(height: 8),
        _shareButton(s.brag, widget.onShare),
        _mapButton(s.toMap, widget.onMap),
      ],
    );
  }
}

class _StageFailPanel extends StatelessWidget {
  final Stage stage;
  final String reason;
  final String continueLabel;
  final String continueHint;
  final bool canContinue;
  final double progress;
  final VoidCallback onContinue;
  final VoidCallback onRetry;
  final VoidCallback onMap;

  const _StageFailPanel({
    required this.stage,
    required this.reason,
    required this.continueLabel,
    required this.continueHint,
    required this.canContinue,
    required this.progress,
    required this.onContinue,
    required this.onRetry,
    required this.onMap,
  });

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    return _PanelCard(
      children: [
        Text(s.stageN(stage.number), style: const TextStyle(fontWeight: FontWeight.w900, color: brown)),
        OutlinedText(s.stageFailed, size: 34, color: const Color(0xFFFF7043)),
        const SizedBox(height: 6),
        Text(reason, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: brown)),
        const SizedBox(height: 12),
        ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: LinearProgressIndicator(value: progress, minHeight: 12, backgroundColor: Colors.black12, color: const Color(0xFFFF7043)),
        ),
        const SizedBox(height: 4),
        Text('${(progress * 100).round()}%', style: const TextStyle(fontWeight: FontWeight.w900, color: brown)),
        const SizedBox(height: 16),
        if (canContinue) ...[
          _bigButton(continueLabel, Icons.ondemand_video_rounded, const Color(0xFF43A047), onContinue),
          _hint(continueHint),
        ],
        _bigButton(s.retry, Icons.refresh_rounded, const Color(0xFFFF7043), onRetry),
        _mapButton(s.toMap, onMap),
      ],
    );
  }
}
