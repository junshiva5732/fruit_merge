import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

/// 최고 점수 · 망치 개수 · 진행 중인 판 · 언어 · 소리 · 진동 설정을 기기에 저장한다.
class Storage {
  static const _kBest = 'best';
  static const _kHammers = 'hammers';
  static const _kGame = 'game';
  static const _kLocale = 'locale';
  static const _kVibration = 'vibration';
  static const _kMusic = 'music';
  static const _kSfx = 'sfx';
  static const _kBiggest = 'biggest_ever';
  static const _kSeenHelp = 'seen_help';

  /// 처음 설치하면 망치 1개를 준다.
  static const startHammers = 1;

  final SharedPreferences _prefs;
  Storage(this._prefs);

  static Future<Storage> create() async => Storage(await SharedPreferences.getInstance());

  int get best => _prefs.getInt(_kBest) ?? 0;

  /// [score] 가 최고 기록이면 저장하고 true.
  bool submitScore(int score) {
    if (score <= best) return false;
    _prefs.setInt(_kBest, score);
    return true;
  }

  /// 지금까지 만든 가장 큰 과일 단계 (-1 = 없음).
  int get biggestEver => _prefs.getInt(_kBiggest) ?? -1;
  void submitBiggest(int level) {
    if (level > biggestEver) _prefs.setInt(_kBiggest, level);
  }

  int get hammers => _prefs.getInt(_kHammers) ?? startHammers;
  Future<void> setHammers(int n) => _prefs.setInt(_kHammers, n);

  /// 진행 중인 판 (앱을 닫았다 열어도 이어서). 게임 오버면 지운다.
  Map<String, dynamic>? get savedGame {
    final s = _prefs.getString(_kGame);
    if (s == null) return null;
    try {
      return jsonDecode(s) as Map<String, dynamic>;
    } catch (_) {
      return null;
    }
  }

  Future<void> saveGame(Map<String, Object>? game) =>
      game == null ? _prefs.remove(_kGame) : _prefs.setString(_kGame, jsonEncode(game));

  bool get seenHelp => _prefs.getBool(_kSeenHelp) ?? false;
  Future<void> setSeenHelp() => _prefs.setBool(_kSeenHelp, true);

  bool get music => _prefs.getBool(_kMusic) ?? true;
  Future<void> setMusic(bool on) => _prefs.setBool(_kMusic, on);

  bool get sfx => _prefs.getBool(_kSfx) ?? true;
  Future<void> setSfx(bool on) => _prefs.setBool(_kSfx, on);

  bool get vibration => _prefs.getBool(_kVibration) ?? true;
  Future<void> setVibration(bool on) => _prefs.setBool(_kVibration, on);

  /// 사용자가 고른 언어 코드 (null = 시스템 언어).
  String? get localeCode => _prefs.getString(_kLocale);
  Future<void> setLocaleCode(String? code) => code == null ? _prefs.remove(_kLocale) : _prefs.setString(_kLocale, code);
}
