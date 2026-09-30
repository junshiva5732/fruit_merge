import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:play_install_referrer/play_install_referrer.dart';

/// 친구에게 보내는 도전장: 무한 모드 점수, 또는 스테이지 번호 + 별.
///
/// 전달 경로 세 가지 (모두 같은 쿼리 `s=점수&st=스테이지&r=별`):
/// - 웹 링크 `https://junshiva5732.github.io/fruit_merge/c/?s=…` (공유 메시지에 들어가는 링크, docs/c/index.html)
/// - 앱 링크 `fruitmerge://fm/challenge?s=…` (웹 페이지가 앱을 열 때, 설치돼 있으면)
/// - 플레이 스토어 설치 정보 `referrer=s%3D…` (설치가 안 돼 있어서 스토어로 갔다가 설치한 뒤 첫 실행)
class Challenge {
  final int score;
  final int? stage;
  final int stars;

  const Challenge({required this.score, this.stage, this.stars = 0});

  static const webBase = 'https://junshiva5732.github.io/fruit_merge/c/';
  static const packageName = 'com.jun5731.fruit_merge';

  Map<String, String> get query => {
    's': '$score',
    if (stage != null) 'st': '$stage',
    if (stars > 0) 'r': '$stars',
  };

  Uri get webLink => Uri.parse(webBase).replace(queryParameters: query);

  static Challenge? fromQuery(Map<String, String> q) {
    final s = int.tryParse(q['s'] ?? '');
    if (s == null || s < 0 || s > 99999999) return null;
    final st = int.tryParse(q['st'] ?? '');
    final r = int.tryParse(q['r'] ?? '') ?? 0;
    return Challenge(
      score: s,
      stage: st != null && st >= 1 && st <= 60 ? st : null,
      stars: r.clamp(0, 3),
    );
  }

  /// 앱 경로("/challenge?s=…") 또는 전체 주소("fruitmerge://fm/challenge?s=…")에서.
  static Challenge? fromRoute(String? route) {
    if (route == null || !route.contains('challenge')) return null;
    final uri = Uri.tryParse(route);
    if (uri == null || !uri.path.endsWith('/challenge')) return null;
    return fromQuery(uri.queryParameters);
  }

  /// 플레이 스토어 설치 정보("s=15868&st=12")에서.
  static Challenge? fromReferrer(String? referrer) {
    if (referrer == null) return null;
    try {
      final decoded = Uri.decodeComponent(referrer);
      if (!decoded.contains('s=')) return null;
      return fromQuery(Uri.splitQueryString(decoded));
    } catch (_) {
      return null;
    }
  }

  /// 스토어에서 도전 링크로 설치했다면 그 도전장. 안드로이드에서만, 실패하면 null.
  static Future<Challenge?> fromInstallReferrer() async {
    if (kIsWeb || !Platform.isAndroid) return null;
    try {
      final details = await PlayInstallReferrer.installReferrer;
      return fromReferrer(details.installReferrer);
    } catch (e) {
      debugPrint('install referrer: $e');
      return null;
    }
  }

  @override
  bool operator ==(Object other) => other is Challenge && other.score == score && other.stage == stage && other.stars == stars;

  @override
  int get hashCode => Object.hash(score, stage, stars);
}
