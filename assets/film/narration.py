# The narration of the film: one file per line, made offline with Kokoro.
# Usage: narration.py WORKDIR     (or set AIDENTITY_FILM_WORK)
# Writes WORKDIR/vo1-raw.wav ... vo10-raw.wav, 24 kHz, and prints each length.
import os, sys, soundfile as sf
from kokoro_onnx import Kokoro
# Each line is written the way it is said, not the way it is shown: the name is
# spelled so it is said right, and the second line has commas, so the two rounds
# are read as two even pairs.
LINES = [
    "You know this routine.",
    "Sign out, sign in. Sign out, sign in.",
    "And your open chats are gone.",
    "Meet Eye-dentity.",
    "Every account you use. Open at once.",
    "Each in its own window. Each one signed in.",
    "An icon for every account.",
    "Add one in a window, a menu, or with one command.",
    "Your app stays untouched. No copies. No signing out.",
    "Eye-dentity. Free, for your Mac.",
]
work = sys.argv[1] if len(sys.argv) > 1 else os.environ.get("AIDENTITY_FILM_WORK")
if not work:
    sys.exit("usage: narration.py WORKDIR")
k = Kokoro("/opt/tts/models/kokoro-v1.0.onnx", "/opt/tts/models/voices-v1.0.bin")
out = []
for i, text in enumerate(LINES, 1):
    samples, sr = k.create(text, voice="af_bella", speed=1.0, lang="en-us")
    sf.write(os.path.join(work, f"vo{i}-raw.wav"), samples, sr)
    out.append(f"{i}: {round(len(samples) / sr, 2)} s  {text}")
print("\n".join(out))
