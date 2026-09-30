import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

/// 앱 문자열 (en / ko / ja / zh). 기본은 시스템 언어를 따르고(미지원 언어는 영어),
/// 메뉴의 언어 설정으로 바꿀 수 있다 ([LocaleController]).
///
/// 새 언어를 추가하려면 [supported] 와 [nativeName] 에 로케일을 넣고 [_t] 에 인자를 추가한다.
class S {
  final Locale locale;
  const S(this.locale);

  static S of(BuildContext context) => Localizations.of<S>(context, S)!;
  static const LocalizationsDelegate<S> delegate = _SDelegate();
  static const supported = [Locale('en'), Locale('ko'), Locale('ja'), Locale('zh')];

  /// 시스템 언어를 지원 로케일로 맞춘다 (미지원이면 영어).
  static Locale resolve(Locale? l) => supported.firstWhere((s) => s.languageCode == l?.languageCode, orElse: () => supported.first);

  /// 언어 선택 목록에 각 언어의 자기 이름으로 표시.
  static String nativeName(Locale l) => switch (l.languageCode) {
    'ko' => '한국어',
    'ja' => '日本語',
    'zh' => '简体中文',
    _ => 'English',
  };

  String _t(String en, String ko, String ja, String zh) => switch (locale.languageCode) {
    'ko' => ko,
    'ja' => ja,
    'zh' => zh,
    _ => en,
  };

  String get appTitle => _t('Fruit Merge', '과일 합치기', 'フルーツ合体', '水果合合');

  /// 과일 이름 (0 체리 … 10 수박).
  String fruitName(int level) => switch (level) {
    0 => _t('Cherry', '체리', 'さくらんぼ', '樱桃'),
    1 => _t('Strawberry', '딸기', 'いちご', '草莓'),
    2 => _t('Grape', '포도', 'ぶどう', '葡萄'),
    3 => _t('Tangerine', '귤', 'みかん', '橘子'),
    4 => _t('Persimmon', '감', 'かき', '柿子'),
    5 => _t('Apple', '사과', 'りんご', '苹果'),
    6 => _t('Pear', '배', 'なし', '梨'),
    7 => _t('Peach', '복숭아', 'もも', '桃子'),
    8 => _t('Pineapple', '파인애플', 'パイナップル', '菠萝'),
    9 => _t('Melon', '멜론', 'メロン', '甜瓜'),
    _ => _t('Watermelon', '수박', 'すいか', '西瓜'),
  };

  // 게임 화면
  String get score => _t('SCORE', '점수', 'スコア', '得分');
  String get best => _t('BEST', '최고', 'ベスト', '最佳');
  String get next => _t('NEXT', '다음', 'つぎ', '下一个');
  String get hammer => _t('Hammer', '망치', 'ハンマー', '锤子');
  String get hammerHint => _t('Tap a fruit to smash it', '없앨 과일을 탭하세요', '消したいフルーツをタップ', '点击要敲掉的水果');
  String get hammerGet => _t('Get 2 hammers', '망치 2개 받기', 'ハンマーを2個もらう', '获得 2 把锤子');
  String get hammerGetBody => _t(
    'A hammer smashes any one fruit. Watch a short ad to get 2 hammers.',
    '망치로 과일 하나를 없앨 수 있어요. 짧은 광고를 보면 망치 2개를 드려요.',
    'ハンマーでフルーツを1つ消せます。短い広告を見るとハンマーを2個もらえます。',
    '锤子可以敲掉任意一个水果。观看一段短广告即可获得 2 把锤子。',
  );
  String hammersGot(int n) => _t('+$n hammers!', '망치 +$n!', 'ハンマー +$n！', '锤子 +$n！');
  String get evolution => _t('Fruit chain', '과일 진화', 'フルーツの進化', '水果进化');
  String get combo => _t('COMBO', '콤보', 'コンボ', '连击');

  // 스테이지 / 지도
  String stageN(int n) => _t('Stage $n', '스테이지 $n', 'ステージ $n', '第 $n 关');
  String get endless => _t('Endless', '무한 모드', 'エンドレス', '无尽模式');
  String regionName(int i) => switch (i) {
    0 => _t('Apple Orchard', '사과 과수원', 'りんご果樹園', '苹果园'),
    1 => _t('Berry Field', '딸기 밭', 'いちご畑', '草莓田'),
    2 => _t('Tropical Beach', '열대 해변', 'トロピカルビーチ', '热带海滩'),
    3 => _t('Sunset Hill', '노을 언덕', '夕焼けの丘', '夕阳山丘'),
    4 => _t('Starlight Garden', '별빛 정원', '星あかりの庭', '星光花园'),
    _ => _t('Rainbow Castle', '무지개 성', 'にじのお城', '彩虹城堡'),
  };
  String get goal => _t('GOAL', '목표', 'もくひょう', '目标');
  String goalScore(int n) => _t('Score $n points', '$n점 모으기', '$n点を集めよう', '获得 $n 分');
  String goalFruit(int level) => _t('Make a ${fruitName(level)}', '${fruitName(level)} 만들기', '${fruitName(level)}を作ろう', '合成${fruitName(level)}');
  String goalStones(int n) => _t('Break $n stones', '돌 $n개 깨기', '石を$n個割ろう', '敲碎 $n 块石头');
  String dropsLimit(int n) => _t('Within $n fruits', '과일 $n개 안에', 'フルーツ$n個以内で', '$n 个水果之内');
  String get dropsLeft => _t('LEFT', '남은 과일', 'のこり', '剩余');
  String get play => _t('Play', '시작', 'スタート', '开始');
  String get stageClear => _t('STAGE CLEAR!', '스테이지 클리어!', 'ステージクリア！', '过关！');
  String get stageFailed => _t('FAILED', '실패', 'しっぱい', '失败');
  String get outOfDrops => _t('Out of fruits!', '과일을 다 썼어요!', 'フルーツがなくなった！', '水果用完了！');
  String get overflow => _t('The box overflowed!', '상자가 넘쳤어요!', '箱からあふれた！', '箱子满出来了！');
  String get plusDrops => _t('+5 fruits', '과일 +5개', 'フルーツ+5個', '水果 +5');
  String get plusDropsHint => _t('Watch an ad to get 5 more fruits', '광고 보고 과일 5개 더 받기', '広告を見てフルーツを5個追加', '看广告再得 5 个水果');
  String get nextStage => _t('Next stage', '다음 스테이지', '次のステージ', '下一关');
  String get retry => _t('Retry', '다시 도전', 'リトライ', '重试');
  String get toMap => _t('Map', '지도', 'マップ', '地图');
  String get hammerReward => _t('Bonus: +1 hammer!', '보너스: 망치 +1!', 'ボーナス：ハンマー+1！', '奖励：锤子 +1！');
  String get locked => _t('Clear the previous stage first', '이전 스테이지를 먼저 깨 주세요', '前のステージをクリアしよう', '请先通过上一关');
  String get settings => _t('Settings', '설정', '設定', '设置');

  // 자랑하기 / 도전장
  String get brag => _t('Share', '자랑하기', '自慢する', '炫耀一下');
  String get shareWithImage => _t('Send with score card', '점수 카드와 함께 보내기', 'スコアカード付きで送る', '附上分数卡发送');
  String get shareLinkOnly => _t('Send link only', '링크만 보내기', 'リンクだけ送る', '只发送链接');
  String get shareLinkHint => _t(
    'Chat apps like KakaoTalk show it as a preview card',
    '카카오톡 같은 채팅 앱에서 미리보기 카드로 보여요',
    'LINEなどのチャットアプリでプレビューカードになります',
    '在微信等聊天应用中显示为预览卡片',
  );
  String shareTextEndless(int score) => _t(
    '🍉 I scored $score points in Fruit Merge! Can you beat me? 👉 ',
    '🍉 과일 합치기에서 $score점! 나를 이길 수 있어? 👉 ',
    '🍉 フルーツ合体で$score点！私に勝てる？ 👉 ',
    '🍉 我在水果合合拿了 $score 分！你能超过我吗？👉 ',
  );
  String shareTextStage(int stage, int stars) => _t(
    '🍉 Cleared Stage $stage in Fruit Merge ${'★' * stars}! Your turn 👉 ',
    '🍉 과일 합치기 스테이지 $stage 클리어 ${'★' * stars}! 너도 도전해 봐 👉 ',
    '🍉 フルーツ合体 ステージ$stage クリア ${'★' * stars}！次はキミの番 👉 ',
    '🍉 水果合合第 $stage 关通关 ${'★' * stars}！轮到你了 👉 ',
  );
  String get cardEndless => _t('ENDLESS RECORD', '무한 모드 기록', 'エンドレス記録', '无尽模式记录');
  String cardStage(int n) => _t('STAGE $n CLEAR', '스테이지 $n 클리어', 'ステージ$n クリア', '第 $n 关通关');
  String get cardCallToAction => _t('Can you beat me?', '나를 이길 수 있어?', '私に勝てる？', '你能超过我吗？');
  String get challengeTitle => _t('A challenge has arrived!', '도전장이 도착했어요!', '挑戦状が届いた！', '收到挑战书啦！');
  String get friendScore => _t("Friend's score", '친구 기록', '友だちの記録', '好友记录');
  String get acceptChallenge => _t('Accept challenge', '도전하기', '挑戦する', '接受挑战');
  String get challengeNewGame => _t(
    'A separate game — your saved endless game stays',
    '따로 한 판 — 이어하던 무한 모드는 그대로 남아요',
    '別の1ゲーム — 続きのエンドレスはそのまま残ります',
    '单独一局 — 原来的无尽模式进度会保留',
  );
  String challengeStageLocked(int n) => _t(
    'Stage $n is still locked. Clear the stages before it first!',
    '스테이지 $n은 아직 잠겨 있어요. 앞 스테이지부터 깨 보세요!',
    'ステージ$nはまだロック中。前のステージからクリアしよう！',
    '第 $n 关尚未解锁，先通过前面的关卡吧！',
  );
  String friendTarget(int n) => _t('Friend $n', '친구 $n', '友だち $n', '好友 $n');
  String get beatFriend => _t('You beat your friend!', '친구 기록 돌파!', '友だちの記録を突破！', '超越好友记录！');
  String get vsWin => _t('You win!', '이겼다!', '勝ち！', '你赢了！');
  String vsLose(int diff) => _t('Just $diff points short!', '$diff점 모자라요!', 'あと$diff点！', '还差 $diff 分！');
  String get bestStars => _t('Best', '최고 기록', 'ベスト', '最佳');
  String get newHere => _t('NEW', '새로 등장', 'NEW', '新登场');
  String get autoDropHint => _t(
    'From here on, the fruit drops by itself if you wait too long.',
    '이제부터 오래 기다리면 과일이 저절로 떨어져요.',
    'ここからは、待ちすぎるとフルーツが自動で落ちます。',
    '从这里开始，等待太久水果会自动落下。',
  );
  String get fallingStonesHint => _t(
    'Stones start falling from the sky too!',
    '이제 하늘에서 돌도 떨어져요!',
    '空から石も落ちてくるよ！',
    '天上也会掉下石头了！',
  );
  String get newSpecial => _t('New!', '새로운 과일!', 'NEW!', '新水果！');
  String specialHint(int piece) => switch (piece) {
    100 => _t(
      'Rainbow fruit: merges with ANY fruit it touches.',
      '무지개 과일: 닿은 과일이 무엇이든 한 단계 커져요!',
      'にじフルーツ：触れたフルーツが何でも1段階大きくなる！',
      '彩虹水果：碰到任何水果都能让它升一级！',
    ),
    101 => _t(
      'Bomb: blasts the fruits around it when it lands.',
      '폭탄: 닿는 순간 주변 과일을 크게 날려 보내요!',
      'ばくだん：着地すると周りのフルーツを吹き飛ばす！',
      '炸弹：落地时把周围的水果炸飞！',
    ),
    _ => _t(
      'Stone: never merges. Merge next to it 3 times (or use a hammer) to break it.',
      '돌: 합쳐지지 않아요. 옆에서 3번 합치거나 망치로 깨세요.',
      '石：合体しません。となりで3回合体させるか、ハンマーで割ろう。',
      '石头：不能合成。在旁边合成 3 次或用锤子敲碎。',
    ),
  };

  // 게임 오버
  String get gameOver => _t('GAME OVER', '게임 오버', 'ゲームオーバー', '游戏结束');
  String get newBest => _t('NEW BEST!', '신기록!', '新記録！', '新纪录！');
  String get biggestFruit => _t('Biggest fruit', '이번 판 최고 과일', '今回の最大フルーツ', '本局最大水果');
  String get continueRun => _t('Continue', '이어하기', 'コンティニュー', '继续游戏');
  String get continueHint => _t('Watch an ad to clear the top and keep going', '광고 보고 위쪽 과일을 치우고 계속', '広告を見て上のフルーツを消して続ける', '看广告，清除上方水果后继续');
  String get playAgain => _t('Play again', '다시 하기', 'もう一度', '再玩一次');

  // 메뉴 / 설정
  String get paused => _t('PAUSED', '일시정지', '一時停止', '已暂停');
  String get resume => _t('Resume', '계속하기', '再開', '继续');
  String get restart => _t('Restart', '처음부터', '最初から', '重新开始');
  String get restartAsk => _t('Start a new game?', '처음부터 다시 할까요?', '最初からやり直しますか？', '要重新开始吗？');
  String get yes => _t('Yes', '네', 'はい', '是');
  String get no => _t('No', '아니요', 'いいえ', '否');
  String get cancel => _t('Cancel', '취소', 'キャンセル', '取消');
  String get vibration => _t('Vibration', '진동', 'バイブレーション', '振动');
  String get music => _t('Music', '배경음악', 'BGM', '背景音乐');
  String get soundEffects => _t('Sound effects', '효과음', '効果音', '音效');
  String get language => _t('Language', '언어', '言語', '语言');
  String get systemLanguage => _t('System default', '시스템 기본', 'システムの設定', '跟随系统');
  String get howToPlay => _t('How to play', '게임 방법', '遊び方', '玩法说明');
  String get close => _t('Close', '닫기', '閉じる', '关闭');
  String get watchAd => _t('Watch ad', '광고 보기', '広告を見る', '观看广告');
  String get adNotReady => _t(
    'The ad is not ready yet. Please try again in a moment.',
    '광고를 아직 불러오지 못했어요. 잠시 후 다시 시도해 주세요.',
    '広告をまだ読み込めていません。しばらくしてからもう一度お試しください。',
    '广告尚未加载完成，请稍后再试。',
  );
  String get helpBody => _t(
    'Drag left and right to aim, then let go to drop the fruit.\n\n'
        'When two identical fruits touch, they merge into the next fruit and you score points. '
        'Cherry → Strawberry → Grape → Tangerine → Persimmon → Apple → Pear → Peach → Pineapple → Melon → Watermelon!\n\n'
        'If fruits stay above the red dotted line for too long, the game is over.\n\n'
        'Combo: merge again within 1 second for ×2, ×3 … up to ×5 points!\n\n'
        'Special fruits: Rainbow merges with anything, Bomb blasts nearby fruits, Stone never merges '
        '(merge next to it 3 times or smash it).\n\n'
        'The higher your score, the bigger the fruits, the less time above the line, and from 500 points '
        'the fruit drops by itself if you wait too long.\n\n'
        'Hammer: smash any one fruit. Watch a short ad to get 2 more.\n'
        'Continue: once per game, watch a short ad to clear the fruits at the top and keep going.\n\n'
        'Your game is saved automatically, so you can come back any time.',
    '좌우로 끌어서 위치를 정하고, 손을 떼면 과일이 떨어져요.\n\n'
        '같은 과일 두 개가 닿으면 다음 과일로 합쳐지면서 점수를 얻어요. '
        '체리 → 딸기 → 포도 → 귤 → 감 → 사과 → 배 → 복숭아 → 파인애플 → 멜론 → 수박!\n\n'
        '과일이 빨간 점선 위에 오래 머물면 게임 오버예요.\n\n'
        '콤보: 1초 안에 이어서 합치면 점수 ×2, ×3 … 최대 ×5!\n\n'
        '특수 과일: 무지개는 아무 과일과 합쳐지고, 폭탄은 주변을 날려 보내요. '
        '돌은 합쳐지지 않으니 옆에서 3번 합치거나 망치로 깨세요.\n\n'
        '점수가 오를수록 큰 과일이 자주 나오고 버틸 시간이 줄어요. 500점부터는 오래 기다리면 과일이 저절로 떨어져요.\n\n'
        '망치: 과일 하나를 없앨 수 있어요. 짧은 광고를 보면 2개를 더 받아요.\n'
        '이어하기: 한 판에 한 번, 짧은 광고를 보면 위쪽 과일을 치우고 계속할 수 있어요.\n\n'
        '게임은 자동으로 저장되니 언제든 이어서 할 수 있어요.',
    '左右にドラッグして位置を決め、指を離すとフルーツが落ちます。\n\n'
        '同じフルーツ同士がくっつくと、次のフルーツに合体して得点！'
        'さくらんぼ → いちご → ぶどう → みかん → かき → りんご → なし → もも → パイナップル → メロン → すいか！\n\n'
        'フルーツが赤い点線より上に長くとどまるとゲームオーバーです。\n\n'
        'コンボ：1秒以内に続けて合体すると得点×2、×3…最大×5！\n\n'
        '特別なフルーツ：にじは何とでも合体、ばくだんは周りを吹き飛ばす、'
        '石は合体しないので、となりで3回合体させるかハンマーで割ろう。\n\n'
        'スコアが上がるほど大きなフルーツが増え、耐えられる時間も短くなります。500点からは待ちすぎると自動で落ちます。\n\n'
        'ハンマー：フルーツを1つ消せます。短い広告を見ると2個もらえます。\n'
        'コンティニュー：1ゲームに1回、短い広告を見ると上のフルーツを消して続けられます。\n\n'
        'ゲームは自動で保存されるので、いつでも続きから遊べます。',
    '左右拖动选择位置，松手水果就会落下。\n\n'
        '两个相同的水果碰到一起，就会合成下一种水果并得分！'
        '樱桃 → 草莓 → 葡萄 → 橘子 → 柿子 → 苹果 → 梨 → 桃子 → 菠萝 → 甜瓜 → 西瓜！\n\n'
        '水果在红色虚线上方停留太久，游戏就会结束。\n\n'
        '连击：1 秒内连续合成，得分 ×2、×3 … 最高 ×5！\n\n'
        '特殊水果：彩虹可与任何水果合成，炸弹会炸飞周围水果，'
        '石头不能合成，在旁边合成 3 次或用锤子敲碎。\n\n'
        '分数越高，大水果越多，可停留时间越短。500 分起，等待太久水果会自动落下。\n\n'
        '锤子：可以敲掉任意一个水果。观看短广告可再获得 2 把。\n'
        '继续：每局一次，观看短广告即可清除上方水果并继续游戏。\n\n'
        '游戏会自动保存，随时可以接着玩。',
  );
}

class _SDelegate extends LocalizationsDelegate<S> {
  const _SDelegate();

  @override
  bool isSupported(Locale locale) => S.supported.any((l) => l.languageCode == locale.languageCode);

  @override
  Future<S> load(Locale locale) => SynchronousFuture(S(locale));

  @override
  bool shouldReload(_SDelegate old) => false;
}

/// 사용자가 고른 언어. null 이면 시스템 언어를 따른다. 값이 바뀌면 [MaterialApp] 이 다시 빌드된다.
class LocaleController extends ValueNotifier<Locale?> {
  LocaleController(super.value);

  static LocaleController of(BuildContext context) => context.dependOnInheritedWidgetOfExactType<_LocaleScope>()!.controller;

  /// 저장된 언어 코드 → 로케일. 지원하지 않는 코드는 무시(null).
  static Locale? fromCode(String? code) =>
      code == null ? null : S.supported.cast<Locale?>().firstWhere((l) => l!.languageCode == code, orElse: () => null);
}

/// [LocaleController] 를 위젯 트리에 내려보낸다.
class LocaleScope extends StatelessWidget {
  final LocaleController controller;
  final Widget child;
  const LocaleScope({super.key, required this.controller, required this.child});

  @override
  Widget build(BuildContext context) => _LocaleScope(controller: controller, child: child);
}

class _LocaleScope extends InheritedWidget {
  final LocaleController controller;
  const _LocaleScope({required this.controller, required super.child});

  @override
  bool updateShouldNotify(_LocaleScope old) => old.controller != controller;
}
