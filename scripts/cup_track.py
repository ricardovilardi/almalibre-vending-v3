# Builds build/video/cup-track.txt ("t dx dy angle blur alpha occl" per frame) for the logo printed on the cup.
#   python3 scripts/cup_track.py build/video/cup-shape.txt build/video/cup-entry.txt build/video/cup-exit.txt build/video/cup-track.txt build/video/cup-raw.txt
# Inputs:
#   cup-shape.txt  from scripts/cupshape.swift (cup body centroid / angle / area per frame, 5.9-22 s)
#   cup-entry.txt, cup-exit.txt  from scripts/segtrack.swift (chained translations while the camera pans)
#   cup-raw.txt    from scripts/track_cup.swift (cup body registration vs the 16 s frame; holds and the slow pan)
# The logo is laid out for the cup at 16 s (design/video-v3/cup-logo.html); offsets are relative to that pose.
# Where the cup stands still the offset is held constant, so the logo never jitters.
import sys

shape = [list(map(float, l.split())) for l in open(sys.argv[1]) if l.strip()]
def chain(path):  # segtrack rows: t h11 h12 h13 h21 h22 h23 ... (CI coords, y up)
    return {round(float(v[0]), 3): (float(v[3]), -float(v[6])) for v in (l.split() for l in open(path) if l.strip())}
entry, exit_ = chain(sys.argv[2]), chain(sys.argv[3])

raw = [tuple(map(float, l.split())) for l in open(sys.argv[5]) if l.strip()]  # registration vs 16 s (y down)
def mean_in(a, b, col):
    v = [r[col] for r in shape if a <= r[0] <= b and r[6] > 55000]
    return sum(v) / len(v)
def reg_hold(a, b):
    v = [r for r in raw if a <= r[0] <= b and abs(r[1]) < 60 and abs(r[2]) < 60]
    return (round(sum(r[1] for r in v) / len(v)), round(sum(r[2] for r in v) / len(v)))
H1 = reg_hold(6.1, 9.05) + (mean_in(8.9, 9.09, 3),)    # berries falling, cup on the floor
H2 = reg_hold(10.6, 11.0) + (mean_in(10.54, 10.65, 3),)  # soft serve, before the camera move
H3 = reg_hold(13.7, 21.9) + (0.0,)                      # toppings, cup on the floor
# body centroid at rest just before / after the tilt (colour measurement is only used relative to these)
PRE = (mean_in(8.9, 9.09, 1), mean_in(8.9, 9.09, 2)); POST = (mean_in(10.54, 10.65, 1), mean_in(10.54, 10.65, 2))
TILT = (9.10, 10.56)      # Almita lifts and turns the cup
PAN = (11.04, 13.7)       # slow camera move: follow the measured centroid, heavily smoothed
EXIT_START = 21.92

rows = {round(r[0], 3): r for r in shape}
times = [round(i / 24, 3) for i in range(int(4.8 * 24), int(23.2 * 24))]

def measured(t, a_ok=55000):
    r = rows.get(t)
    return r if r and r[6] > a_ok else None

def interp_series(ts, getter):
    pts = [(t, getter(t)) for t in ts]
    known = [(t, v) for t, v in pts if v is not None]
    out = []
    for t, v in pts:
        if v is None:
            prev = max((k for k in known if k[0] <= t), default=known[0], key=lambda k: k[0])
            nxt = min((k for k in known if k[0] >= t), default=known[-1], key=lambda k: k[0])
            f = 0 if nxt[0] == prev[0] else (t - prev[0]) / (nxt[0] - prev[0])
            v = tuple(p + f * (n - p) for p, n in zip(prev[1], nxt[1]))
        out.append((t, v))
    return out

def smooth(series, w):
    out = []
    for i, (t, _) in enumerate(series):
        win = [v for _, v in series[max(0, i - w):i + w + 1]]
        out.append((t, tuple(sum(c) / len(win) for c in zip(*win))))
    return out

# tilt: measured body centroid + angle relative to the rest pose before it
tilt_ts = [t for t in times if TILT[0] <= t <= TILT[1]]
def tilt_rel(t):
    r = measured(t)
    if not r: return None
    f = (t - TILT[0]) / (TILT[1] - TILT[0])
    rx, ry = PRE[0] + f * (POST[0] - PRE[0]), PRE[1] + f * (POST[1] - PRE[1])
    bx, by = H1[0] + f * (H2[0] - H1[0]), H1[1] + f * (H2[1] - H1[1])
    ra = H1[2] + f * (H2[2] - H1[2])
    return (bx + r[1] - rx, by + r[2] - ry, r[3] - ra)
tilt = smooth(interp_series(tilt_ts, tilt_rel), 1)
tilt = dict(tilt)
# pan: measured centroid, smoothed hard
pan_ts = [t for t in times if PAN[0] - 0.1 <= t <= PAN[1] + 0.1]
regd = {round(r[0], 3): r for r in raw}
pan = dict(smooth(interp_series(pan_ts, lambda t: (lambda r: (r[1], r[2], 0.0) if r and abs(r[1]) < 60 and abs(r[2]) < 60 else None)(regd.get(t))), 6))

def ease(x):
    x = max(0.0, min(1.0, x)); return x * x * (3 - 2 * x)

def pose(t):
    if t < 6.04:  # entry: camera pans, cup slides in from the right
        k = [k for k in entry if k <= t + 1e-6]
        if t < 5.3:  # cup mostly off screen; keep its speed (~40 px/frame)
            dx = entry[5.292][0] + (5.292 - t) * 24 * 40; dy = entry[5.292][1]
        else:
            dx, dy = entry[min(entry, key=lambda k: abs(k - t))]
        return H1[0] + dx, H1[1] + dy, 0.0
    if t <= TILT[0]: return H1[0], H1[1], 0.0
    if t <= TILT[1]:
        x, y, a = tilt[t]
        # blend into the holds at both ends
        f_in, f_out = ease((t - TILT[0]) / 0.08), ease((TILT[1] - t) / 0.12)
        f = min(f_in, f_out)
        base = H1 if t - TILT[0] < TILT[1] - t else H2
        return base[0] + f * (x - base[0]), base[1] + f * (y - base[1]), f * a
    if t < PAN[0]: return H2[0], H2[1], 0.0
    if t <= PAN[1]:
        x, y, _ = pan[t]
        f_in, f_out = ease((t - PAN[0]) / 0.3), ease((PAN[1] - t) / 0.4)
        base = H2 if t - PAN[0] < PAN[1] - t else H3
        f = min(f_in, f_out)
        return base[0] + f * (x - base[0]), base[1] + f * (y - base[1]), 0.0
    if t < EXIT_START: return H3[0], H3[1], 0.0
    dx, dy = exit_[min(exit_, key=lambda k: abs(k - t))]
    return H3[0] + dx, H3[1] + dy, 0.0

poses = [(t, pose(t)) for t in times]
lines = []
if True:
    for i, (t, (dx, dy, ang)) in enumerate(poses):
        # horizontal motion blur: speed-based everywhere, plus a lateral smear while the cup is turned
        prev = poses[max(0, i - 1)][1]; nxt = poses[min(len(poses) - 1, i + 1)][1]
        vx, vy, va = (abs(n - p) / 2 for n, p in zip(nxt, prev))
        blur = min(6.0, vx * 0.08)   # camera pans: the footage itself is only slightly blurred
        if TILT[0] <= t <= TILT[1]:  # turning cup: lateral smear that follows how fast it moves, sharp again at rest
            turn = min(ease((t - TILT[0]) / 0.08), ease((TILT[1] - 0.04 - t) / 0.12))
            blur = max(blur, turn * min(16.0, 3.0 + vx * 0.35 + vy * 0.1 + va * 1.6))
        occl = 0  # Almita's foot only brushes the cup's left edge, outside the logo
        lines.append([t, dx, dy, ang, blur, occl])
with open(sys.argv[4], "w") as out:
    for i, (t, dx, dy, ang, _, occl) in enumerate(lines):
        win = [l[4] for l in lines[max(0, i - 2):i + 3]]
        blur = sum(win) / len(win) if lines[i][4] > 0.5 else lines[i][4]
        out.write(f"{t:.3f} {dx:.2f} {dy:.2f} {ang:.2f} {blur:.1f} 1 {occl}\n")
print("holds", H1, H2, H3, "rest", PRE, POST)
