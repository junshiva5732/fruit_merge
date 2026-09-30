import 'dart:io';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';

/// 배경음악 + 효과음. 소리 파일은 tool/make_sounds.py 로 만든 것.
///
/// 효과음은 소리마다 저지연(SoundPool) 플레이어 몇 개를 돌려 쓴다 — 연쇄로 합쳐질 때 겹쳐 들리도록.
/// (audioplayers 의 AudioPool 은 저지연 모드에서 재생 완료 이벤트가 없어 플레이어가 쌓이므로 쓰지 않는다.)
class Sound {
  Sound._();
  static final instance = Sound._();

  static final _sfx = {
    'drop': 2,
    'click': 1,
    'smash': 1,
    'gameover': 1,
    'reward': 1,
    'bonus': 1,
    for (var i = 0; i <= 10; i++) 'merge_$i': i < 5 ? 3 : 2,
  };
  static const _volumes = {'drop': 0.55, 'click': 0.5, 'gameover': 0.8};
  static const musicVolume = 0.4;

  final _rings = <String, List<AudioPlayer>>{};
  final _next = <String, int>{};
  final _lastPlayed = <String, DateTime>{};
  AudioPlayer? _bgm;

  bool musicOn = true;
  bool sfxOn = true;

  /// 광고·백그라운드 중에는 음악을 멈춘다.
  bool _suspended = false;
  bool _ready = false;

  Future<void> init({required bool music, required bool sfx}) async {
    musicOn = music;
    sfxOn = sfx;
    try {
      // 다른 앱 소리와 섞이게 (효과음이 배경음악의 오디오 포커스를 빼앗지 않도록).
      await AudioPlayer.global.setAudioContext(AudioContextConfig(focus: AudioContextConfigFocus.mixWithOthers).build());
      final bgm = AudioPlayer(playerId: 'bgm');
      await bgm.setReleaseMode(ReleaseMode.loop);
      await bgm.setVolume(musicVolume);
      await bgm.setSource(AssetSource(Platform.isIOS ? 'music/bgm.m4a' : 'music/bgm.ogg'));
      _bgm = bgm;
      if (musicOn && !_suspended) await bgm.resume();

      for (final e in _sfx.entries) {
        final ring = <AudioPlayer>[];
        for (var i = 0; i < e.value; i++) {
          final p = AudioPlayer(playerId: '${e.key}_$i');
          await p.setPlayerMode(PlayerMode.lowLatency);
          await p.setReleaseMode(ReleaseMode.stop);
          await p.setVolume(_volumes[e.key] ?? 1.0);
          await p.setSource(AssetSource('sfx/${e.key}.wav'));
          ring.add(p);
        }
        _rings[e.key] = ring;
      }
      _ready = true;
    } catch (e) {
      debugPrint('Sound init failed: $e');
    }
  }

  /// 효과음 재생. 같은 소리가 40ms 안에 또 오면 건너뛴다 (한 프레임에 여러 번 합쳐질 때).
  void play(String name) {
    if (!sfxOn || !_ready) return;
    final ring = _rings[name];
    if (ring == null || ring.isEmpty) return;
    final now = DateTime.now();
    final last = _lastPlayed[name];
    if (last != null && now.difference(last).inMilliseconds < 40) return;
    _lastPlayed[name] = now;
    final i = (_next[name] ?? 0) % ring.length;
    _next[name] = i + 1;
    final p = ring[i];
    p.stop().then((_) => p.resume()).catchError((Object e) => debugPrint('sfx $name: $e'));
  }

  void merge(int level) => play('merge_$level');

  Future<void> setMusic(bool on) async {
    musicOn = on;
    if (on && !_suspended) {
      await _bgm?.resume();
    } else {
      await _bgm?.pause();
    }
  }

  void setSfx(bool on) => sfxOn = on;

  /// 광고를 보여주거나 앱이 백그라운드로 갈 때.
  void suspend() {
    _suspended = true;
    _bgm?.pause();
  }

  /// 광고가 닫히거나 앱으로 돌아왔을 때.
  void unsuspend() {
    _suspended = false;
    if (musicOn) _bgm?.resume();
  }
}
