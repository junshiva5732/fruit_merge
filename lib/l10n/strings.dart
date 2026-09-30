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
        'Hammer: smash any one fruit. Watch a short ad to get 2 more.\n'
        'Continue: once per game, watch a short ad to clear the fruits at the top and keep going.\n\n'
        'Your game is saved automatically, so you can come back any time.',
    '좌우로 끌어서 위치를 정하고, 손을 떼면 과일이 떨어져요.\n\n'
        '같은 과일 두 개가 닿으면 다음 과일로 합쳐지면서 점수를 얻어요. '
        '체리 → 딸기 → 포도 → 귤 → 감 → 사과 → 배 → 복숭아 → 파인애플 → 멜론 → 수박!\n\n'
        '과일이 빨간 점선 위에 오래 머물면 게임 오버예요.\n\n'
        '망치: 과일 하나를 없앨 수 있어요. 짧은 광고를 보면 2개를 더 받아요.\n'
        '이어하기: 한 판에 한 번, 짧은 광고를 보면 위쪽 과일을 치우고 계속할 수 있어요.\n\n'
        '게임은 자동으로 저장되니 언제든 이어서 할 수 있어요.',
    '左右にドラッグして位置を決め、指を離すとフルーツが落ちます。\n\n'
        '同じフルーツ同士がくっつくと、次のフルーツに合体して得点！'
        'さくらんぼ → いちご → ぶどう → みかん → かき → りんご → なし → もも → パイナップル → メロン → すいか！\n\n'
        'フルーツが赤い点線より上に長くとどまるとゲームオーバーです。\n\n'
        'ハンマー：フルーツを1つ消せます。短い広告を見ると2個もらえます。\n'
        'コンティニュー：1ゲームに1回、短い広告を見ると上のフルーツを消して続けられます。\n\n'
        'ゲームは自動で保存されるので、いつでも続きから遊べます。',
    '左右拖动选择位置，松手水果就会落下。\n\n'
        '两个相同的水果碰到一起，就会合成下一种水果并得分！'
        '樱桃 → 草莓 → 葡萄 → 橘子 → 柿子 → 苹果 → 梨 → 桃子 → 菠萝 → 甜瓜 → 西瓜！\n\n'
        '水果在红色虚线上方停留太久，游戏就会结束。\n\n'
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
