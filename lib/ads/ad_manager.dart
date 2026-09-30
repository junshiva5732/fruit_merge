import 'package:flutter/foundation.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

import 'ad_ids.dart';

/// 전면 광고 / 보상형 광고를 미리 로드해 두고 필요할 때 보여주는 싱글톤.
///
/// 배너는 화면마다 붙어야 하므로 [BannerAdWidget] 에서 개별 관리한다.
class AdManager {
  AdManager._();
  static final AdManager instance = AdManager._();

  InterstitialAd? _interstitial;
  RewardedAd? _rewarded;

  /// 전면 광고 노출 빈도: 게임 오버 [interstitialEvery] 번마다 한 번, 단 직전 전면/보상형 광고로부터
  /// [minInterval] 이 지나야 한다. 한 판이 짧은 장르라 매 판 광고는 이탈을 부른다. 이탈률을 보고 조정한다.
  int _interstitialRequests = 0;
  static const interstitialEvery = 3;
  static const minInterval = Duration(seconds: 45);
  DateTime _lastFullScreenAt = DateTime.fromMillisecondsSinceEpoch(0);

  Future<void> init() async {
    await MobileAds.instance.initialize();
    loadInterstitial();
    loadRewarded();
  }

  // ---------------------------------------------------------------- 전면 광고

  void loadInterstitial() {
    InterstitialAd.load(
      adUnitId: AdIds.interstitial,
      request: const AdRequest(),
      adLoadCallback: InterstitialAdLoadCallback(
        onAdLoaded: (ad) => _interstitial = ad,
        onAdFailedToLoad: (err) {
          debugPrint('Interstitial load failed: $err');
          _interstitial = null;
        },
      ),
    );
  }

  /// 로드된 전면 광고가 있고 노출 차례이면 보여준다. 없으면 그냥 넘어간다.
  /// 광고 유무와 무관하게 [onDone] 은 반드시 호출된다.
  void showInterstitialThen(VoidCallback onDone) {
    _interstitialRequests++;
    final ad = _interstitial;
    final tooSoon = DateTime.now().difference(_lastFullScreenAt) < minInterval;
    if (ad == null || tooSoon || _interstitialRequests < interstitialEvery) {
      onDone();
      return;
    }
    _interstitialRequests = 0;
    _interstitial = null;
    _lastFullScreenAt = DateTime.now();
    ad.fullScreenContentCallback = FullScreenContentCallback(
      onAdDismissedFullScreenContent: (ad) {
        ad.dispose();
        loadInterstitial();
        onDone();
      },
      onAdFailedToShowFullScreenContent: (ad, err) {
        ad.dispose();
        loadInterstitial();
        onDone();
      },
    );
    ad.show();
  }

  // -------------------------------------------------------------- 보상형 광고

  bool get isRewardedReady => _rewarded != null;

  void loadRewarded() {
    RewardedAd.load(
      adUnitId: AdIds.rewarded,
      request: const AdRequest(),
      rewardedAdLoadCallback: RewardedAdLoadCallback(
        onAdLoaded: (ad) => _rewarded = ad,
        onAdFailedToLoad: (err) {
          debugPrint('Rewarded load failed: $err');
          _rewarded = null;
        },
      ),
    );
  }

  /// 보상형 광고를 보여주고, 사용자가 끝까지 봤을 때만 [onReward] 를 호출한다.
  /// 광고가 닫히면(보상 여부와 무관하게) [onClosed] 를 호출한다.
  /// 광고가 준비 안 됐으면 false 를 반환하고 아무것도 하지 않는다.
  bool showRewarded({required VoidCallback onReward, VoidCallback? onClosed}) {
    final ad = _rewarded;
    if (ad == null) return false;
    _rewarded = null;
    _lastFullScreenAt = DateTime.now();
    var earned = false;
    ad.fullScreenContentCallback = FullScreenContentCallback(
      onAdDismissedFullScreenContent: (ad) {
        ad.dispose();
        loadRewarded();
        if (earned) onReward();
        onClosed?.call();
      },
      onAdFailedToShowFullScreenContent: (ad, err) {
        ad.dispose();
        loadRewarded();
        onClosed?.call();
      },
    );
    ad.show(onUserEarnedReward: (_, _) => earned = true);
    return true;
  }
}
