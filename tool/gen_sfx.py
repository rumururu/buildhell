"""효과음 WAV 합성 스크립트. `python3 tool/gen_sfx.py` 로 assets/sfx/ 를 다시 만든다."""
import os
import wave

import numpy as np

SR = 44100
OUT = os.path.join(os.path.dirname(__file__), '..', 'assets', 'sfx')
rng = np.random.default_rng(7)


def t(dur):
    return np.arange(int(SR * dur)) / SR


def env(n, attack=0.005, decay=8.0):
    x = np.arange(n) / SR
    a = np.clip(x / attack, 0, 1)
    return a * np.exp(-decay * x)


def tone(freq, dur, decay=6.0, kind='sine'):
    x = t(dur)
    if callable(freq):
        phase = 2 * np.pi * np.cumsum(freq(x)) / SR
    else:
        phase = 2 * np.pi * freq * x
    if kind == 'square':
        w = np.sign(np.sin(phase)) * 0.5
    elif kind == 'saw':
        w = 2 * ((phase / (2 * np.pi)) % 1) - 1
    else:
        w = np.sin(phase)
    return w * env(len(x), decay=decay)


def noise(dur, decay=20.0, smooth=1):
    n = rng.standard_normal(int(SR * dur))
    if smooth > 1:
        n = np.convolve(n, np.ones(smooth) / smooth, mode='same')
    return n * env(len(n), attack=0.001, decay=decay)


def seq(*parts, gap=0.0):
    out = []
    for p in parts:
        out.append(p)
        if gap:
            out.append(np.zeros(int(SR * gap)))
    return np.concatenate(out)


def mix(*parts):
    n = max(len(p) for p in parts)
    out = np.zeros(n)
    for p in parts:
        out[: len(p)] += p
    return out


def save(name, x, gain=0.8):
    x = x / (np.max(np.abs(x)) + 1e-9) * gain
    data = (x * 32767).astype(np.int16)
    with wave.open(os.path.join(OUT, name), 'wb') as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(SR)
        w.writeframes(data.tobytes())


os.makedirs(OUT, exist_ok=True)

# 형벌 터치: 낮게 떨어지는 타격음 + 짧은 노이즈
save('tap.wav', mix(tone(lambda x: 180 * np.exp(-25 * x) + 60, 0.12, decay=30),
                    noise(0.05, decay=60, smooth=6) * 0.5), gain=0.55)
# 치명타: 더 무겁고 길게 + 금속성
save('crit.wav', mix(tone(lambda x: 220 * np.exp(-12 * x) + 45, 0.35, decay=10),
                     noise(0.12, decay=25, smooth=3) * 0.6,
                     tone(1200, 0.25, decay=18) * 0.25), gain=0.8)
# 구매: 엽전 소리 (두 음)
save('buy.wav', seq(tone(1320, 0.07, decay=30, kind='square') * 0.6,
                    tone(1760, 0.18, decay=18, kind='square') * 0.6), gain=0.45)
# 강화: 상승 3음
save('upgrade.wav', seq(*(tone(f, 0.08, decay=20, kind='square') for f in (660, 880, 1320))), gain=0.45)
# 탈옥수 체포: 쇠사슬 + 상승 아르페지오
save('catch.wav', mix(noise(0.15, decay=20, smooth=2) * 0.4,
                      seq(*(tone(f, 0.07, decay=25) for f in (523, 659, 784, 1046)))), gain=0.7)
# 정확한 판결: 징 소리
x = t(1.2)
gong = (np.sin(2 * np.pi * 110 * x) + 0.6 * np.sin(2 * np.pi * 165.5 * x)
        + 0.4 * np.sin(2 * np.pi * 231 * x) + 0.2 * np.sin(2 * np.pi * 347 * x))
save('judge_ok.wav', gong * env(len(x), attack=0.01, decay=3.5), gain=0.75)
# 잘못된 판결: 부저
save('judge_bad.wav', seq(tone(140, 0.18, decay=4, kind='saw'), tone(110, 0.3, decay=5, kind='saw'), gap=0.03), gain=0.5)
# 폭주: 상승하는 불길
x = t(0.9)
whoosh = noise(0.9, decay=1.5, smooth=4) * np.sin(np.pi * x / 0.9)
save('frenzy.wav', mix(whoosh, tone(lambda x: 100 + 600 * x, 0.9, decay=1.5, kind='saw') * 0.3), gain=0.7)
# 업적·보상: 맑은 차임
save('reward.wav', mix(*(np.concatenate([np.zeros(int(SR * 0.09 * i)), tone(f, 0.6, decay=5)])
                         for i, f in enumerate((784, 988, 1175, 1568)))), gain=0.6)
# 탈옥수 등장 / 죄인 도착 알림
save('alert.wav', seq(tone(880, 0.06, decay=20, kind='square'), tone(660, 0.1, decay=15, kind='square'), gap=0.02), gain=0.35)
print('ok', sorted(os.listdir(OUT)))
