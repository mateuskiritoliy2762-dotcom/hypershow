# Uso: python tools/split_voice_block.py <bloco.mp3> robo/falas_para_gravar.txt audio/hyper/falas <Categoria> [<Categoria> ...]
# Corta um bloco de falas em um arquivo por fala, alinhando as palavras do Whisper com o texto esperado.
import difflib, re, subprocess, sys, unicodedata
from faster_whisper import WhisperModel

block, listfile, outdir, cats = sys.argv[1], sys.argv[2], sys.argv[3], sys.argv[4:]

lines = []  # (nome_arquivo, texto)
for l in open(listfile, encoding="utf-8"):
    m = re.match(r"((\w+)_\d+\.mp3)\t(.*)", l.rstrip("\n"))
    if m and m[2] in cats:
        lines.append((m[1], m[3]))
lines.sort(key=lambda x: cats.index(x[0].rsplit("_", 1)[0]))

def norm(w):
    w = unicodedata.normalize("NFKD", w.lower())
    return re.sub(r"[^a-z0-9]", "", w.encode("ascii", "ignore").decode())

expected, owner = [], []
for i, (_, text) in enumerate(lines):
    for w in text.split():
        if norm(w):
            expected.append(norm(w)); owner.append(i)

model = WhisperModel("small", device="cpu", compute_type="int8")
import numpy as np
pcm = subprocess.check_output(["ffmpeg", "-v", "error", "-i", block, "-ac", "1", "-ar", "16000", "-f", "f32le", "-"])
segs, _ = model.transcribe(np.frombuffer(pcm, np.float32),language="pt", word_timestamps=True, vad_filter=False)
heard = [(norm(w.word), w.start, w.end) for s in segs for w in s.words if norm(w.word)]

sm = difflib.SequenceMatcher(None, expected, [h[0] for h in heard], autojunk=False)
first = [None] * len(lines); last = [None] * len(lines)
for a, b, size in sm.get_matching_blocks():
    for k in range(size):
        i = owner[a + k]; _, st, en = heard[b + k]
        if first[i] is None or st < first[i]: first[i] = st
        if last[i] is None or en > last[i]: last[i] = en

dur = float(subprocess.check_output(["ffprobe", "-v", "error", "-show_entries", "format=duration", "-of", "csv=p=0", block]))
missing = [lines[i][0] for i in range(len(lines)) if first[i] is None]
if missing:
    sys.exit("sem alinhamento: " + ", ".join(missing))

# Volume em janelas de 10 ms (dB), suavizado em 50 ms. O Whisper erra os tempos das palavras em até ~0,3 s,
# então o corte vai no trecho mais silencioso perto da troca de fala, e não no meio do caminho entre as palavras.
samples = np.frombuffer(pcm, np.float32)
FRAME = 160  # 10 ms a 16 kHz
rms = np.sqrt(np.mean(samples[: len(samples) // FRAME * FRAME].reshape(-1, FRAME) ** 2, axis=1))
db = 20 * np.log10(np.convolve(rms, np.ones(5) / 5, mode="same") + 1e-9)
QUIET = -40

def cut_between(a, b):
    lo, hi = int((min(a, b) - 0.3) * 100), int((max(a, b) + 0.3) * 100)
    lo, hi = max(lo, 0), min(hi, len(db) - 1)
    best, run_start, best_len = None, None, 0
    for f in range(lo, hi + 1):  # maior trecho silencioso da janela; corte no meio dele
        if db[f] < QUIET:
            run_start = f if run_start is None else run_start
            if f - run_start + 1 > best_len:
                best_len, best = f - run_start + 1, (run_start + f) / 2
        else:
            run_start = None
    if best is None:
        best = lo + int(np.argmin(db[lo : hi + 1]))  # sem silêncio: o ponto mais baixo
    return best / 100

cuts = [0.0] + [cut_between(last[i], first[i + 1]) for i in range(len(lines) - 1)] + [dur]

def trim(start, end):
    # tira o silêncio das pontas, deixando 60 ms de folga
    frames = [f for f in range(int(start * 100), min(int(end * 100), len(db))) if db[f] >= QUIET]
    if not frames:
        return start, end
    return max(start, frames[0] / 100 - 0.06), min(end, frames[-1] / 100 + 0.06)

for i, (name, text) in enumerate(lines):
    start, end = trim(cuts[i], cuts[i + 1])
    subprocess.run(["ffmpeg", "-v", "error", "-y", "-i", block, "-ss", f"{start:.3f}", "-to", f"{end:.3f}",
                    "-af", "afade=t=in:d=0.02,areverse,afade=t=in:d=0.04,areverse", "-b:a", "128k",
                    f"{outdir}/{name}"], check=True)
    print(f"{name}\t{start:6.2f}-{end:6.2f}\t{text}")
print("ouvido:", " ".join(h[0] for h in heard))
