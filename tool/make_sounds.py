"""배경음악·효과음 합성 (저작권 걱정 없는 직접 만든 소리).
실행: python tool/make_sounds.py
출력: assets/music/bgm.ogg (Android, 끊김 없는 반복), assets/music/bgm.m4a (iOS),
      assets/sfx/*.wav (짧은 효과음, 22kHz 모노)
필요: numpy, ffmpeg (libvorbis, aac)
"""
import os
import subprocess
import wave

import numpy as np

ROOT = os.path.join(os.path.dirname(__file__), "..")
MUSIC = os.path.join(ROOT, "assets", "music")
SFX = os.path.join(ROOT, "assets", "sfx")
rng = np.random.default_rng(7)


def midi(n):
    return 440.0 * 2 ** ((n - 69) / 12)


def env(n, sr, attack=0.005, decay=0.3):
    t = np.arange(n) / sr
    a = np.clip(t / attack, 0, 1)
    return a * np.exp(-t / decay)


def write_wav(path, x, sr):
    x = np.clip(x, -1, 1)
    with wave.open(path, "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(sr)
        w.writeframes((x * 32767).astype(np.int16).tobytes())


# ------------------------------------------------------------------ 배경음악

SR = 44100
BPM = 128
EIGHTH = 60 / BPM / 2
BAR = EIGHTH * 8

# 코드 진행 (2 프레이즈 × 8마디): C G Am F C G F G
CHORDS = {
    "C": [60, 64, 67],
    "G": [59, 62, 67],
    "Am": [60, 64, 69],
    "F": [60, 65, 69],
}
BASS = {"C": 36, "G": 43, "Am": 45, "F": 41}
PROG = ["C", "G", "Am", "F", "C", "G", "F", "G"] * 2

_ = None
MELODY = [
    [76, 79, _, 84, _, 79, 76, _],
    [74, 79, _, 83, _, 79, 74, _],
    [72, 76, _, 81, _, 79, 76, _],
    [77, 81, _, 84, 81, 79, 77, _],
    [79, _, 76, 79, 84, _, 86, _],
    [83, _, 79, _, 86, _, 83, _],
    [81, 79, 77, 81, 84, _, 81, _],
    [79, _, _, _, 74, 76, 77, 79],
    [84, _, 79, _, 76, 79, 84, _],
    [86, _, 83, _, 79, 83, 86, _],
    [88, _, 84, _, 81, _, 79, _],
    [81, 84, _, 81, 77, _, 79, _],
    [76, 77, 79, _, 84, _, 79, _],
    [74, 76, 79, _, 83, _, 79, _],
    [77, 79, 81, _, 84, _, 86, _],
    [83, _, 79, _, 74, _, 79, _],
]


def marimba(f, dur, sr=SR, decay=0.35):
    """말랑한 마림바/벨 소리: 기음 + 4배음 조금, 빠른 감쇠."""
    n = int(dur * sr)
    t = np.arange(n) / sr
    x = np.sin(2 * np.pi * f * t) + 0.25 * np.sin(2 * np.pi * f * 4 * t) * np.exp(-t / 0.05)
    x += 0.15 * np.sin(2 * np.pi * f * 2 * t)
    return x * env(n, sr, 0.003, decay)


def pluck(f, dur, sr=SR, decay=0.18):
    n = int(dur * sr)
    t = np.arange(n) / sr
    x = np.sin(2 * np.pi * f * t) + 0.3 * np.sin(2 * np.pi * f * 2 * t) + 0.1 * np.sin(2 * np.pi * f * 3 * t)
    return x * env(n, sr, 0.004, decay)


def bass(f, dur, sr=SR):
    n = int(dur * sr)
    t = np.arange(n) / sr
    # 부드러운 사각파 느낌 (홀수 배음 3개)
    x = np.sin(2 * np.pi * f * t) + 0.3 * np.sin(2 * np.pi * 3 * f * t) + 0.12 * np.sin(2 * np.pi * 5 * f * t)
    return x * env(n, sr, 0.005, 0.22)


def kick(sr=SR):
    n = int(0.18 * sr)
    t = np.arange(n) / sr
    f = 50 + 90 * np.exp(-t / 0.03)
    ph = 2 * np.pi * np.cumsum(f) / sr
    return np.sin(ph) * np.exp(-t / 0.07)


def noise_hit(dur, decay, hp=True, sr=SR):
    n = int(dur * sr)
    x = rng.standard_normal(n)
    if hp:
        x = np.diff(x, prepend=0)  # 간단한 고역 통과
    return x * env(n, sr, 0.001, decay)


def mix_at(buf, x, t, gain):
    i = int(round(t * SR))
    j = min(len(buf), i + len(x))
    buf[i:j] += x[: j - i] * gain


def make_bgm():
    total = BAR * len(PROG)
    tail = 1.5
    buf = np.zeros(int((total + tail) * SR))
    for b, ch in enumerate(PROG):
        t0 = b * BAR
        # 드럼: 킥 1·3박, 박수 2·4박, 하이햇 8분
        for beat in range(4):
            tb = t0 + beat * EIGHTH * 2
            if beat in (0, 2):
                mix_at(buf, kick(), tb, 0.55)
            else:
                mix_at(buf, noise_hit(0.12, 0.04, hp=False), tb, 0.12)
            mix_at(buf, noise_hit(0.05, 0.012), tb + EIGHTH, 0.06)
            mix_at(buf, noise_hit(0.04, 0.008), tb, 0.03)
        # 베이스: 8분음표 통통 (근음-근음-옥타브-근음 …)
        root = BASS[ch]
        for k, off in enumerate([0, 0, 12, 0, 0, 12, 7, 12]):
            mix_at(buf, bass(midi(root + off), EIGHTH * 0.95), t0 + k * EIGHTH, 0.22)
        # 코드: 엇박 스타카토 (경쾌하게)
        for k in range(1, 8, 2):
            for note in CHORDS[ch]:
                mix_at(buf, pluck(midi(note), EIGHTH * 1.2), t0 + k * EIGHTH, 0.07)
        # 멜로디
        for k, note in enumerate(MELODY[b]):
            if note is not None:
                mix_at(buf, marimba(midi(note), 0.6), t0 + k * EIGHTH, 0.3)
    # 끊김 없이 반복되도록 꼬리를 앞쪽에 겹친다.
    n = int(total * SR)
    loop = buf[:n].copy()
    loop[: len(buf) - n] += buf[n:]
    loop = np.tanh(loop * 1.4) / np.tanh(1.4)
    loop *= 0.8 / np.max(np.abs(loop))
    os.makedirs(MUSIC, exist_ok=True)
    tmp = os.path.join(MUSIC, "_bgm.wav")
    write_wav(tmp, loop, SR)
    ogg = os.path.join(MUSIC, "bgm.ogg")
    m4a = os.path.join(MUSIC, "bgm.m4a")
    subprocess.run(["ffmpeg", "-y", "-loglevel", "error", "-i", tmp, "-c:a", "libvorbis", "-q:a", "3", ogg], check=True)
    subprocess.run(["ffmpeg", "-y", "-loglevel", "error", "-i", tmp, "-c:a", "aac", "-b:a", "96k", m4a], check=True)
    os.remove(tmp)
    print(f"bgm {total:.1f}s -> {os.path.getsize(ogg) // 1024}KB ogg, {os.path.getsize(m4a) // 1024}KB m4a")


# ------------------------------------------------------------------ 효과음

SSR = 22050


def tone_sweep(f0, f1, dur, decay, sr=SSR):
    n = int(dur * sr)
    t = np.arange(n) / sr
    f = f1 + (f0 - f1) * np.exp(-t / (dur / 3))
    ph = 2 * np.pi * np.cumsum(f) / sr
    return np.sin(ph) * env(n, sr, 0.002, decay)


def bell(f, dur, decay, sr=SSR):
    n = int(dur * sr)
    t = np.arange(n) / sr
    x = np.sin(2 * np.pi * f * t) + 0.35 * np.sin(2 * np.pi * 2 * f * t) * np.exp(-t / (decay / 2))
    x += 0.12 * np.sin(2 * np.pi * 3.01 * f * t) * np.exp(-t / (decay / 3))
    return x * env(n, sr, 0.002, decay)


def place(buf, x, t, gain=1.0, sr=SSR):
    i = int(t * sr)
    j = min(len(buf), i + len(x))
    buf[i:j] += x[: j - i] * gain


def norm(x, peak=0.85):
    return x * (peak / max(1e-9, np.max(np.abs(x))))


def make_sfx():
    os.makedirs(SFX, exist_ok=True)
    # 떨어뜨리기: 톡 (짧고 부드럽게)
    write_wav(os.path.join(SFX, "drop.wav"), norm(tone_sweep(700, 330, 0.12, 0.05), 0.6), SSR)

    # 합치기: 뽁 + 단계별로 올라가는 벨 (C 장조 5음계)
    notes = [72, 74, 76, 79, 81, 84, 86, 88, 91, 93, 96]
    for lv, n in enumerate(notes):
        f = midi(n)
        buf = np.zeros(int(0.7 * SSR))
        place(buf, tone_sweep(f * 0.45, f * 1.1, 0.07, 0.03), 0, 0.8)  # 물방울 "뽁"
        place(buf, bell(f, 0.6, 0.18 + lv * 0.02), 0.025, 0.7)
        if lv >= 6:  # 큰 과일은 5도 위 반짝임 추가
            place(buf, bell(f * 1.5, 0.5, 0.2), 0.09, 0.4)
        if lv >= 9:
            place(buf, bell(f * 2, 0.45, 0.2), 0.16, 0.35)
        write_wav(os.path.join(SFX, f"merge_{lv}.wav"), norm(buf, 0.8), SSR)

    # 수박 + 수박: 팡파르 아르페지오
    buf = np.zeros(int(1.3 * SSR))
    for k, n in enumerate([72, 76, 79, 84, 88, 91]):
        place(buf, bell(midi(n), 0.7, 0.3), k * 0.07, 0.6)
    write_wav(os.path.join(SFX, "bonus.wav"), norm(buf, 0.85), SSR)

    # 망치: 쿵 + 파삭
    buf = np.zeros(int(0.35 * SSR))
    place(buf, tone_sweep(180, 55, 0.3, 0.09), 0, 1.0)
    n = int(0.12 * SSR)
    crack = rng.standard_normal(n) * env(n, SSR, 0.001, 0.03)
    place(buf, np.diff(crack, prepend=0), 0.005, 0.5)
    write_wav(os.path.join(SFX, "smash.wav"), norm(buf, 0.85), SSR)

    # 게임 오버: 내려가는 네 음
    buf = np.zeros(int(1.4 * SSR))
    for k, n in enumerate([79, 76, 72, 67]):
        place(buf, bell(midi(n), 0.7, 0.28), k * 0.18, 0.6)
    write_wav(os.path.join(SFX, "gameover.wav"), norm(buf, 0.75), SSR)

    # 보상(망치 받기·이어하기): 올라가는 반짝임
    buf = np.zeros(int(0.9 * SSR))
    for k, n in enumerate([84, 88, 91, 96]):
        place(buf, bell(midi(n), 0.5, 0.18), k * 0.06, 0.5)
    write_wav(os.path.join(SFX, "reward.wav"), norm(buf, 0.75), SSR)

    # 버튼: 똑
    write_wav(os.path.join(SFX, "click.wav"), norm(tone_sweep(1500, 900, 0.05, 0.015), 0.45), SSR)
    total = sum(os.path.getsize(os.path.join(SFX, f)) for f in os.listdir(SFX))
    print(f"sfx {len(os.listdir(SFX))} files, {total // 1024}KB")


if __name__ == "__main__":
    make_bgm()
    make_sfx()
