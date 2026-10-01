#!/usr/bin/env bash
# 스토어 스크린샷 원본 캡처. 사용: bash tool/capture_screens.sh <ko|en|ja|zh> [adb serial]
# LOCALE + DEMO(쌓인 판 · 가짜 진행 상태) 디버그 APK 를 설치하고 화면을 차례로 찍는다. 좌표는 720x1280 기준.
set +e
LANG_CODE=$1; SERIAL=${2:-emulator-5580}
ADB="/c/Users/Administrator/AppData/Local/Android/sdk/platform-tools/adb.exe -s $SERIAL"
OUT=store/raw/$LANG_CODE; mkdir -p "$OUT"
PKG=com.jun5731.fruit_merge
shot() { $ADB exec-out screencap -p > "$OUT/$1"; }

if [ "$SKIP_BUILD" != "1" ]; then
  flutter build apk --debug --dart-define=LOCALE=$LANG_CODE --dart-define=DEMO=true 2>&1 | tail -1
fi
$ADB uninstall $PKG >/dev/null 2>&1
$ADB install build/app/outputs/flutter-apk/app-debug.apk | tail -1
$ADB shell am start -n $PKG/.MainActivity >/dev/null
sleep 22                                   # 첫 실행 + 배너 로드
shot s_map.png                             # 지도 (별 38개, 스테이지 15)
$ADB shell input tap 170 688; sleep 3
shot s_intro.png                           # 스테이지 15 목표
$ADB shell input keyevent 4; sleep 2
$ADB shell input tap 548 112; sleep 4
shot s_share.png                           # 자랑하기 (점수 카드)
$ADB shell input keyevent 4; sleep 2
$ADB shell input tap 360 1053; sleep 6
shot s_game.png                            # 무한 모드 데모 판 (다음: 무지개)
$ADB shell input tap 170 688; sleep 3
shot s_merge.png                           # 무지개 → 멜론
$ADB shell input keyevent 4; sleep 2
$ADB shell input tap 360 632; sleep 3
shot s_help.png                            # 게임 방법 (진화표 · 특수 과일)
echo "captured: $OUT"
