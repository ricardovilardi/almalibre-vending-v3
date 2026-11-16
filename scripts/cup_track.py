# Turns raw cup registration (build/video/cup-raw.txt: "t dx dy" per frame, from scripts/track_cup.swift)
# into build/video/cup-track.txt ("t dx dy alpha"): drops failed frames, interpolates, smooths,
# and fades the logo out where the cup is lifted (9.1-10.5 s) or Almita walks in front (22 s).
import sys
raw = [tuple(map(float, l.split())) for l in open(sys.argv[1]) if l.strip()]
ok = [(t, x, y) for t, x, y in raw if abs(x) < 60 and abs(y) < 60]
def interp(t):
    prev = max((k for k in ok if k[0] <= t), default=ok[0], key=lambda k: k[0])
    nxt = min((k for k in ok if k[0] >= t), default=ok[-1], key=lambda k: k[0])
    if nxt[0] == prev[0]: return prev[1], prev[2]
    f = (t - prev[0]) / (nxt[0] - prev[0])
    return prev[1] + f * (nxt[1] - prev[1]), prev[2] + f * (nxt[2] - prev[2])
# (start, end) of visible windows with fade-in/out lengths in s
WIN = [(5.96, 9.10, .25, .07), (10.46, 21.96, .25, .18)]
def alpha(t):
    for a, b, fi, fo in WIN:
        if a <= t <= b: return min(1, (t - a) / fi, (b - t) / fo)
    return 0
ts = [r[0] for r in raw]; pts = [interp(t) for t in ts]
with open(sys.argv[2], "w") as out:
    for i, t in enumerate(ts):
        w = pts[max(0, i - 2):i + 3]
        dx = sum(p[0] for p in w) / len(w); dy = sum(p[1] for p in w) / len(w)
        out.write(f"{t:.3f} {dx:.2f} {dy:.2f} {alpha(t):.3f}\n")
