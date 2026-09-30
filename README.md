# 과일 합치기 (fruit_merge)

같은 과일 두 개가 닿으면 다음 과일로 합쳐지는 물리 머지 퍼즐. 위에서 과일을 떨어뜨려 수박까지 키운다.
Flutter, Android + iOS. 한국어 · 영어 · 일본어 · 중국어(간체).
앱 이름: 과일 합치기 / Fruit Merge / フルーツ合体 / 水果合合. applicationId `com.jun5731.fruit_merge`.

## 구조

```
lib/
  main.dart                     앱 진입, 세로 고정, 스크린샷용 LOCALE 강제
  l10n/strings.dart             문자열 en/ko/ja/zh (과일 이름 포함) + LocaleController
  ads/ad_ids.dart               AdMob 광고 단위 ID  ← 출시 전 교체 (지금은 테스트 ID)
  ads/ad_manager.dart           전면(게임 오버 3번에 1번, 45초 간격) + 보상형
  game/world.dart               물리 세계: 원 충돌(서브스텝 8 × 반복 3), 합치기, 위험선·게임 오버, 저장/복원, 규칙(Rules)
  game/stages.dart              스테이지 60개 (목표·과일 수·해금), 별 계산
  game/fruit_art.dart           과일 11종 그림 (코드로 그림: 몸통·무늬·꼭지·얼굴)
  game/board_painter.dart       상자·위험선·조준선·과일·파티클·점수 팝업, FruitIcon
  services/storage.dart         최고 점수, 망치 개수, 진행 중인 판, 언어, 소리, 진동
  services/sound.dart           배경음악(반복) + 효과음(저지연 플레이어 링), 광고·백그라운드 중 음악 정지
  screens/map_screen.dart       첫 화면: 스테이지 지도 (6개 지역, 구불구불한 길, 별, 무한 모드 버튼)
  screens/game_screen.dart      게임 화면 (무한/스테이지 공용: 목표 HUD, 망치, 결과 화면, 메뉴)
  widgets/dialogs.dart          설정·언어·게임 방법 대화상자, 진화표
  widgets/banner_ad_widget.dart 하단 배너 (태블릿 대응 버전)
test/world_test.dart            물리·합치기·게임 오버·이어하기·저장 테스트
test/preview_render_test.dart   과일/판 미리보기 PNG → build/previews/
tool/balance_test.dart          자동 플레이로 스테이지 난이도 측정 → stages.dart 표 (flutter test tool/balance_test.dart)
tool/make_sounds.py             배경음악·효과음 합성 (numpy + ffmpeg) → assets/music, assets/sfx
tool/icon_test.dart             앱 아이콘 원본 (flutter test tool/icon_test.dart → dart run flutter_launcher_icons)
```

과일: 0 체리 → 딸기 → 포도 → 귤 → 감 → 사과 → 배 → 복숭아 → 파인애플 → 멜론 → 10 수박.
떨어뜨리는 과일은 0~5단계. 수박 + 수박 = 둘 다 사라지고 +100.

### 스테이지 (`Stage`)
60개, 10개씩 6개 지역 (사과 과수원 → 딸기 밭 → 열대 해변 → 노을 언덕 → 별빛 정원 → 무지개 성).
- 목표: 점수 모으기 / 5의 배수는 과일 만들기 (감 → … → 60 수박) / 8·13·18… 은 바닥에 깔린 돌 깨기
- 과일 수 제한, 남은 과일 30% 이상 ★★★, 15% 이상 ★★, 아니면 ★. 이전 스테이지를 깨야 다음이 열림
- 고정 난이도 0 → 0.85, 해금: 3 무지개 · 5 폭탄 · 7 떨어지는 돌 · 8 자동 낙하 (스테이지 카드에 "새로 등장")
- 실패 시 이어하기(광고, 1번): 넘침 → 위쪽 정리, 과일 부족 → +5개. 5의 배수 첫 클리어 → 망치 +1
- 목표치·과일 수는 자동 플레이(스테이지당 12판)로 성공률 약 95% → 45% 가 되게 맞춤. 점수 ≈ 0.9 × (250 + 27 × 스테이지)

### 무한 모드 난이도 · 랜덤성 (`World`)
| 항목 | 처음 | 4000점 이상 (`hardScore`) |
|---|---|---|
| 떨어지는 과일 확률 | 체리 30 · 딸기 27 · 포도 21 · 귤 14 · 감 8 · 사과 0 | 16 · 20 · 24 · 22 · 13 · 5 |
| 선 위에서 버티는 시간 | 2.5초 | 1.5초 |
| 자동 낙하 (500점부터, 남은 3초 동안 빨간 링) | 6초 | 4초 |

특수 과일 (300점부터, 연달아 나오지 않음, 처음 나올 때 설명 스낵바):
- 무지개 3.5%: 닿은 일반 과일을 한 단계 키움 (수박이면 보너스)
- 폭탄 2.5%: 무엇이든 닿으면 터져 주변을 크게 날림 (화면 흔들림), 과일은 없어지지 않음
- 돌 (800점부터 3% → 8%): 합쳐지지 않음, 무거움, 주변 합치기/폭발 충격 3번 또는 망치로 깨짐

콤보: 1초 안에 이어서 합치면 점수 ×2, ×3 … ×5, 가운데 "N 콤보!" 배너 + 반짝임 소리.
과일이 빨간 점선 위에 2.5초 넘게 있으면 게임 오버 (막 떨어진 과일 1.2초는 제외).
합쳐지면 주변 과일이 바깥·위쪽으로 살짝 튕긴다 (`World.bumpSpeed`, `bumpRange`). 마찰은 낮게 (`_floorFriction`, `_contactFriction`).
소리: 128BPM C장조 배경음악 30초 반복, 합치기 효과음은 과일 단계마다 음이 올라간다. 메뉴에서 배경음악/효과음/진동 각각 끄기.

## 광고

| 위치 | 종류 | 비고 |
|---|---|---|
| 화면 하단 | 배너 | 적응형, 실패 시 320x50 |
| 게임 오버 → 다시 하기 | 전면 | 3판에 1번, 직전 전면/보상형에서 45초 이후 |
| 망치 0개일 때 망치 버튼 | 보상형 | 망치 +2 (처음 설치 시 1개 무료) |
| 게임 오버 → 이어하기 | 보상형 | 한 판에 1번, 위쪽 과일 정리 후 계속 |

## 개발 빌드

```bash
flutter pub get
flutter test
flutter build apk --debug --target-platform android-arm64
```

스크린샷용: `--dart-define=LOCALE=ko --dart-define=DEMO=true` (디버그 전용, 과일이 쌓인 판으로 시작).
이 PC 전용 설정(AGP 9 / Gradle 9.3, `-Djdk.net.unixdomain.tmpdir=C:/tmp`, `kotlin.incremental=false`)은 sky_hop 과 같다.

## 출시 체크리스트

### 1. AdMob
- [ ] Android 앱 "Fruit Merge" 등록
- [ ] 광고 단위: 배너 / 전면 / 보상형
- [ ] `lib/ads/ad_ids.dart` `_androidReal`, `AndroidManifest.xml` `APPLICATION_ID` 교체

### 2. 개인정보 / 정책
- [ ] GitHub 저장소(공개) + Pages 로 `docs/privacy-policy.html` 게시
- [ ] Play Console 앱 콘텐츠 (광고 있음, 타겟층 13세 이상, 데이터 보안: 광고 ID·기기 정보 AdMob)

### 3. Google Play
- [ ] 업로드 키 `android/upload-keystore.jks` + `android/key.properties` (git 제외, 따로 백업)
- [ ] `flutter build appbundle --release`
- [ ] 스토어 그래픽·등록정보, 내부 테스트 → 비공개 테스트(12명 × 14일) → 프로덕션
