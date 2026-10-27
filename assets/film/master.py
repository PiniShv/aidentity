# Static gain plus a smooth true-peak limiter, so loudness can rise without a
# single clipped sample. Peaks are found 4x oversampled; the gain drops over a
# 4 ms lookahead and recovers over the release time, so it never steps.
# Usage: master.py IN OUT GAIN_DB CEILING_DBTP
import sys, numpy as np, soundfile as sf
from numpy.lib.stride_tricks import sliding_window_view

def limit(x, sr, ceil, release=0.08):
    """x is (samples, channels). Returns the limited signal and the gain curve."""
    N = len(x)
    def over(ch, k=4):
        X = np.fft.rfft(ch); Y = np.zeros(k * N // 2 + 1, complex); Y[: len(X)] = X
        return np.fft.irfft(Y, k * N) * k
    tp = np.max([np.abs(over(x[:, c])).reshape(-1, 4).max(axis=1) for c in range(x.shape[1])], axis=0)
    g = np.minimum(1.0, ceil / np.maximum(tp, 1e-9))
    L = int(0.004 * sr)
    ahead = sliding_window_view(np.concatenate([g, np.ones(L)]), L + 1).min(axis=1)
    r = 1 - np.exp(-1 / (release * sr)); held = np.empty(N); acc = 1.0
    for i in range(N):
        v = ahead[i]
        acc = v if v < acc else acc + (v - acc) * r
        held[i] = acc
    gain = np.convolve(np.concatenate([np.ones(L), held]), np.ones(L + 1) / (L + 1), "valid")
    return x * gain[:, None], gain

if __name__ == "__main__":
    src, dst, gain_db, ceil_db = sys.argv[1], sys.argv[2], float(sys.argv[3]), float(sys.argv[4])
    x, sr = sf.read(src, always_2d=True)
    y, gain = limit(x * 10 ** (gain_db / 20), sr, 10 ** (ceil_db / 20))
    red = -20 * np.log10(gain)
    sf.write(dst, y.astype(np.float32), sr, subtype="FLOAT")
    print(f"{dst.split('/')[-1]}: max reduction {red.max():.2f} dB; "
          f"time >0.5 dB {np.sum(red > 0.5) / sr * 1000:.0f} ms; >2 dB {np.sum(red > 2) / sr * 1000:.0f} ms")
