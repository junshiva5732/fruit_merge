import 'dart:io';

import 'package:flutter/foundation.dart';

/// AdMob 광고 단위 ID.
///
/// - 디버그 빌드(`flutter run`, `--debug`): 항상 Google 공식 테스트 ID.
///   개발 중 실제 광고를 클릭하면 무효 트래픽으로 계정이 정지될 수 있으므로.
/// - 릴리즈 빌드(`--release`, 스토어 배포): 실제 ID.
///
/// Android 실제 ID: 아직 없음 — AdMob 등록 후 [_androidReal] 교체 (지금은 테스트 ID).
/// 보상형 단위 하나를 망치 받기·이어하기에 함께 쓴다.
class AdIds {
  AdIds._();

  // ── 실제 ID ─────────────────────────────────────────────────────────
  // TODO(출시): AdMob 에서 받은 실제 ID 로 교체
  static const _androidReal = _androidTest;

  // TODO(iOS): AdMob 에서 iOS 앱 등록 후 교체
  static const _iosReal = _iosTest;

  // ── Google 공식 테스트 ID ────────────────────────────────────────────
  static const _androidTest = _Ids(
    banner: 'ca-app-pub-3940256099942544/6300978111',
    interstitial: 'ca-app-pub-3940256099942544/1033173712',
    rewarded: 'ca-app-pub-3940256099942544/5224354917',
  );
  static const _iosTest = _Ids(
    banner: 'ca-app-pub-3940256099942544/2934735716',
    interstitial: 'ca-app-pub-3940256099942544/4411468910',
    rewarded: 'ca-app-pub-3940256099942544/1712485313',
  );

  static _Ids get _current {
    if (kReleaseMode) return Platform.isAndroid ? _androidReal : _iosReal;
    return Platform.isAndroid ? _androidTest : _iosTest;
  }

  static String get banner => _current.banner;
  static String get interstitial => _current.interstitial;
  static String get rewarded => _current.rewarded;
}

class _Ids {
  final String banner;
  final String interstitial;
  final String rewarded;
  const _Ids({required this.banner, required this.interstitial, required this.rewarded});
}
