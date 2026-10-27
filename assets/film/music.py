# Music for the film, synthesized from a fixed seed: light plucked
# arpeggios over I-V-vi-IV, a soft pad and bass. Smooth on purpose: no noise
# sources, a fade at the end of every note, no detuned (beating) pad voices, a
# soft convolution reverb, and one steady duck under the whole narration.
# Kind to small speakers: a laptop speaker cannot play deep bass and buzzes
# when pushed to, so there is no kick, the bass carries overtones that small
# speakers can play, and everything below about 110 Hz is filtered out.
# Usage: music.py WORKDIR     (or set AIDENTITY_FILM_WORK)
# Reads WORKDIR/vo1.wav ... vo6.wav (the processed narration, 48 kHz) and
# writes WORKDIR/mix.wav, the narration over the music, as 32-bit float.
import os, sys
import numpy as np, soundfile as sf
from master import limit

WORK = sys.argv[1] if len(sys.argv) > 1 else os.environ.get("AIDENTITY_FILM_WORK")
if not WORK:
    sys.exit("usage: music.py WORKDIR")

SR = 48000
LEN = 19.5
BPM = 104
BEAT = 60 / BPM
BAR = 4 * BEAT
N = int(LEN * SR)

def t_of(d): return np.arange(int(d * SR)) / SR
def hz(m): return 440.0 * 2 ** ((m - 69) / 12)
def norm(x, p=1.0):
    m = np.max(np.abs(x)) or 1.0
    return x / m * p
def lowpass(x, c):
    a = 1 - np.exp(-2 * np.pi * c / SR); y = np.empty_like(x); acc = 0.0
    for i in range(len(x)):
        acc += a * (x[i] - acc); y[i] = acc
    return y
def highpass(x, fc):
    """Second-order Butterworth high-pass (an RBJ biquad), on a 1-D signal."""
    w = 2 * np.pi * fc / SR; al = np.sin(w) / (2 * np.sqrt(0.5)); c = np.cos(w); a0 = 1 + al
    b0, b1, b2, a1, a2 = (1 + c) / 2 / a0, -(1 + c) / a0, (1 + c) / 2 / a0, -2 * c / a0, (1 - al) / a0
    y = np.empty_like(x); x1 = x2 = y1 = y2 = 0.0
    for i in range(len(x)):
        v = x[i]; o = b0 * v + b1 * x1 + b2 * x2 - a1 * y1 - a2 * y2
        x2, x1, y2, y1 = x1, v, y1, o; y[i] = o
    return y
def tail(x, d=0.06):
    """Fade the last d seconds out, so a note never stops while it still sounds."""
    n = min(len(x), int(d * SR))
    x = x.copy()
    if n > 0: x[-n:] *= 0.5 * (1 + np.cos(np.linspace(0, np.pi, n)))
    return x

def pluck(m, d=1.2):
    t = t_of(d); f = hz(m)
    x = (np.sin(2 * np.pi * f * t) + 0.35 * np.sin(4 * np.pi * f * t) * np.exp(-t * 9)
         + 0.12 * np.sin(6 * np.pi * f * t) * np.exp(-t * 14))
    return tail(x * (1 - np.exp(-t / 0.005)) * np.exp(-t * 5.0))

def pad(ms, d):
    t = t_of(d); x = np.zeros_like(t)
    for m in ms:
        ph = 2 * np.pi * hz(m) * t
        x += np.sin(ph) + 0.3 * np.sin(2 * ph) + 0.12 * np.sin(3 * ph)
    env = np.clip(t / 0.35, 0, 1) * np.clip((d - t) / 0.35, 0, 1)
    return tail(lowpass(norm(x), 1800) * env)

def bass(m, d):
    """A bass note heard through its overtones, so a small speaker plays it too."""
    t = t_of(d); ph = 2 * np.pi * hz(m) * t
    x = 0.55 * np.sin(ph) + 0.5 * np.sin(2 * ph) + 0.25 * np.sin(3 * ph) + 0.1 * np.sin(4 * ph)
    return tail(x * (1 - np.exp(-t / 0.012)) * np.exp(-t * 3.0), 0.25)

def chime(ms, d=2.2):
    t = t_of(d)
    return tail(sum(np.sin(2 * np.pi * hz(m) * t) * (1 - np.exp(-t / 0.006)) * np.exp(-t * (2.5 + i))
                    for i, m in enumerate(ms)), 0.2)

def swell(d=0.7):
    t = t_of(d)
    return tail(norm(sum(np.sin(2 * np.pi * hz(m) * t) for m in (48, 55, 60, 64))) * (t / d) ** 2, 0.08)

music = np.zeros((N, 2))
def put(at, x, db, pan=0.0):
    s = int(at * SR)
    if s >= N: return
    x = x[: N - s] * 10 ** (db / 20)
    l, r = np.sqrt((1 - pan) / 2), np.sqrt((1 + pan) / 2)
    music[s:s + len(x), 0] += x * l; music[s:s + len(x), 1] += x * r

# C, G, Am, F: the root, the pad, and the tones the arpeggio walks.
CHORDS = [(48, [60, 64, 67], [60, 64, 67, 72, 76, 72, 67, 64]),
          (43, [55, 59, 62], [59, 62, 67, 71, 74, 71, 67, 62]),
          (45, [57, 60, 64], [60, 64, 69, 72, 76, 72, 69, 64]),
          (41, [53, 57, 60], [60, 65, 69, 72, 77, 72, 69, 65])]
START = 0.55
END_CHORD = 15.4
def play(at, x, db, pan=0.0):
    """A note of the groove: nothing starts once the end chord is due."""
    if at < END_CHORD - 0.05: put(at, x, db, pan)

put(0.0, swell(), -24)
bar = 0; at = START
while at < END_CHORD - 0.05:
    root, padn, arp = CHORDS[bar % 4]
    span = min(BAR, END_CHORD - at)            # the end chord cuts the last bar short
    play(at, pad(padn, span + 0.25), -25)
    play(at, bass(root, BAR * 0.5), -18)
    play(at + BAR / 2, bass(root, BAR * 0.5), -20)
    for k, m in enumerate(arp):
        play(at + k * BEAT / 2, pluck(m), -18 + (2 if k == 0 else 0), -0.25 if k % 2 else 0.25)
    bar += 1; at += BAR
put(0.8, chime([84, 88, 91]), -24)
put(END_CHORD, pad([60, 64, 67, 74], 4.2), -21)
put(END_CHORD, bass(48, 3.0), -18)
put(END_CHORD, chime([79, 84, 88, 91], 3.5), -20)
for k, m in enumerate([72, 76, 79, 84]):
    put(END_CHORD + k * BEAT / 2, pluck(m, 1.6), -19, (-0.2, 0.2)[k % 2])

# A soft reverb: the music convolved with a smooth, decaying tail.
def ir(seed):
    r = np.random.default_rng(seed); n = int(1.6 * SR); t = np.arange(n) / SR
    x = lowpass(r.standard_normal(n), 4500) * np.exp(-t * 4.2)
    x[: int(0.012 * SR)] = 0
    return x / np.sqrt(np.sum(x ** 2))
def conv(x, h):
    n = len(x) + len(h) - 1; m = 1 << (n - 1).bit_length()
    return np.fft.irfft(np.fft.rfft(x, m) * np.fft.rfft(h, m), m)[: len(x)]
wet = np.stack([conv(music[:, 0], ir(1)), conv(music[:, 1], ir(2))], axis=1)
music = music + 0.22 * wet / (np.max(np.abs(wet)) or 1) * np.max(np.abs(music))
music *= np.clip((LEN - t_of(LEN)) / 2.5, 0, 1)[:, None]
music = np.stack([highpass(highpass(music[:, c], 110), 110) for c in range(2)], axis=1)

# The narrator, with its few loudest glottal pulses held 3 dB down so the
# master limiter has almost nothing to do. The music stays 6 dB down under the
# whole narration, pauses included, so it never breathes between lines, and
# comes back up over one second after the last word.
VO = [(0.8, 1), (3.1, 2), (6.2, 3), (10.2, 4), (12.9, 5), (15.6, 6)]
voice = np.zeros(N)
for at, n in VO:
    v, sr = sf.read(os.path.join(WORK, f"vo{n}.wav")); assert sr == SR
    s = int(at * SR); v = v[: N - s]; voice[s:s + len(v)] += v
voice = limit(norm(voice, 0.95)[:, None], SR, 0.95 * 10 ** (-3 / 20), release=0.05)[0][:, 0]
last_word = np.nonzero(np.abs(voice) > 0.003)[0][-1] / SR
rise = 0.5 - 0.5 * np.cos(np.pi * np.clip((t_of(LEN) - last_word - 0.05) / 1.0, 0, 1))
duck = 10 ** (-6 * (1 - rise) / 20)

with_vo = norm(music * duck[:, None] * 0.7 + voice[:, None], 0.89)
sf.write(os.path.join(WORK, "mix.wav"), with_vo.astype(np.float32), SR, subtype="FLOAT")
print("last word ends at", round(last_word, 2), "s")
print("bars:", bar, "len:", LEN)
