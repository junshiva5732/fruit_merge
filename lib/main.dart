import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'ads/ad_manager.dart';
import 'l10n/strings.dart';
import 'screens/challenge_screen.dart';
import 'screens/map_screen.dart';
import 'services/challenge.dart';
import 'services/sound.dart';
import 'services/storage.dart';

/// 스크린샷 촬영용 언어 강제 (디버그 빌드에서만 동작).
/// 예: flutter build apk --debug --dart-define=LOCALE=ja
const _localeOverride = String.fromEnvironment('LOCALE');

const seedColor = Color(0xFFFF7043);

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // 광고 SDK 초기화는 앱 표시를 막지 않도록 기다리지 않는다.
  AdManager.instance.init();
  await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  final storage = await Storage.create();
  // 스크린샷용(DEMO, 디버그 전용): 스테이지 진행·최고 점수가 있는 상태로 시작.
  if (kDebugMode && const bool.fromEnvironment('DEMO')) await storage.seedDemo();
  // 소리 준비도 앱 표시를 막지 않는다.
  Sound.instance.init(music: storage.music, sfx: storage.sfx);
  runApp(FruitMergeApp(storage: storage));
}

class FruitMergeApp extends StatefulWidget {
  final Storage storage;
  const FruitMergeApp({super.key, required this.storage});

  @override
  State<FruitMergeApp> createState() => _FruitMergeAppState();
}

class _FruitMergeAppState extends State<FruitMergeApp> {
  late final LocaleController _locale;

  @override
  void initState() {
    super.initState();
    _locale = LocaleController(LocaleController.fromCode(widget.storage.localeCode));
    _locale.addListener(() => widget.storage.setLocaleCode(_locale.value?.languageCode));
  }

  Route<void> _mapRoute() => MaterialPageRoute(builder: (_) => MapScreen(storage: widget.storage));

  Route<void> _challengeRoute(Challenge c) =>
      MaterialPageRoute(builder: (_) => ChallengeScreen(storage: widget.storage, challenge: c));

  @override
  void dispose() {
    _locale.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return LocaleScope(
      controller: _locale,
      child: ListenableBuilder(
        listenable: _locale,
        builder: (context, _) => MaterialApp(
          onGenerateTitle: (context) => S.of(context).appTitle,
          debugShowCheckedModeBanner: false,
          theme: ThemeData(colorSchemeSeed: seedColor, useMaterial3: true),
          localizationsDelegates: const [S.delegate, ...GlobalMaterialLocalizations.delegates],
          supportedLocales: S.supported,
          // 우선순위: 스크린샷용 강제 > 사용자 설정 > 시스템 언어
          locale: kDebugMode && _localeOverride.isNotEmpty ? Locale(_localeOverride) : _locale.value,
          // 첫 화면은 지도. 친구 도전 링크(fruitmerge://fm/challenge?s=…)로 열리면 그 위에 도전장.
          onGenerateInitialRoutes: (initial) => [
            _mapRoute(),
            if (Challenge.fromRoute(initial) case final c?) _challengeRoute(c),
          ],
          onGenerateRoute: (settings) {
            final c = Challenge.fromRoute(settings.name);
            return c != null ? _challengeRoute(c) : _mapRoute();
          },
        ),
      ),
    );
  }
}
