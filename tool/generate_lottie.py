"""Generates Exposr's original Lottie animations (no third-party artwork).

Output: ../assets/lottie/*.json (run from the tool folder)
Format notes: classic Lottie JSON (keyframes with s/e/i/o), supported by the
Flutter `lottie` package, lottie-web and lottie-android.
"""
import json
import os

W = H = 200

ACCENT = [0.416, 0.639, 1.0, 1]      # 6AA3FF
PRIMARY = [0.145, 0.388, 0.922, 1]   # 2563EB
SUCCESS = [0.204, 0.827, 0.600, 1]   # 34D399
ERROR = [0.973, 0.443, 0.443, 1]     # F87171
TEXT = [0.910, 0.925, 0.949, 1]      # E8ECF2


def static(v):
    return {"a": 0, "k": v}


def ease(n, out=(0.33, 0.0), inn=(0.67, 1.0)):
    return (
        {"x": [inn[0]] * n, "y": [inn[1]] * n},
        {"x": [out[0]] * n, "y": [out[1]] * n},
    )


def anim(frames):
    """frames: list of (t, value) ; value is number or list."""
    out = []
    for idx, (t, v) in enumerate(frames):
        s = v if isinstance(v, list) else [v]
        n = len(s)
        if idx < len(frames) - 1:
            nxt = frames[idx + 1][1]
            e = nxt if isinstance(nxt, list) else [nxt]
            i, o = ease(n)
            out.append({"t": t, "s": s, "e": e, "i": i, "o": o})
        else:
            out.append({"t": t, "s": s})
    return {"a": 1, "k": out}


def transform(p=(0, 0), a=(0, 0), s=None, r=None, o=None):
    return {
        "ty": "tr",
        "p": static(list(p)),
        "a": static(list(a)),
        "s": s if s is not None else static([100, 100]),
        "r": r if r is not None else static(0),
        "o": o if o is not None else static(100),
        "sk": static(0),
        "sa": static(0),
    }


def stroke(color, width, opacity=None):
    return {
        "ty": "st",
        "c": static(color),
        "o": opacity if opacity is not None else static(100),
        "w": static(width) if not isinstance(width, dict) else width,
        "lc": 2,
        "lj": 2,
        "ml": 4,
    }


def fill(color, opacity=None):
    return {
        "ty": "fl",
        "c": static(color),
        "o": opacity if opacity is not None else static(100),
        "r": 1,
    }


def ellipse(d):
    return {"ty": "el", "s": static([d, d]), "p": static([0, 0])}


def path(vertices, ins=None, outs=None, closed=False):
    n = len(vertices)
    return {
        "ty": "sh",
        "ks": static({
            "i": ins or [[0, 0]] * n,
            "o": outs or [[0, 0]] * n,
            "v": vertices,
            "c": closed,
        }),
    }


def trim(start=0, end=100):
    return {
        "ty": "tm",
        "s": start if isinstance(start, dict) else static(start),
        "e": end if isinstance(end, dict) else static(end),
        "o": static(0),
        "m": 1,
    }


def group(items, name="g", tr=None):
    return {"ty": "gr", "it": items + [tr or transform()], "nm": name}


def layer(ind, name, shapes, op, p=(100, 100), s=None, r=None, o=None):
    return {
        "ddd": 0,
        "ind": ind,
        "ty": 4,
        "nm": name,
        "sr": 1,
        "ks": {
            "o": o if o is not None else static(100),
            "r": r if r is not None else static(0),
            "p": static([p[0], p[1], 0]),
            "a": static([0, 0, 0]),
            "s": s if s is not None else static([100, 100, 100]),
        },
        "ao": 0,
        "shapes": shapes,
        "ip": 0,
        "op": op,
        "st": 0,
        "bm": 0,
    }


def comp(name, op, layers, fr=30):
    return {
        "v": "5.7.0",
        "fr": fr,
        "ip": 0,
        "op": op,
        "w": W,
        "h": H,
        "nm": name,
        "ddd": 0,
        "assets": [],
        "layers": layers,
    }


# A shield outline, centred on (0, 0), about 84 wide and 104 tall.
SHIELD_V = [[0, -52], [42, -36], [42, 8], [0, 52], [-42, 8], [-42, -36]]
SHIELD_I = [[0, 0], [0, 0], [0, 0], [20, -8], [0, 22], [0, 0]]
SHIELD_O = [[0, 0], [0, 0], [0, 22], [-20, -8], [0, 0], [0, 0]]


def shield_path():
    return path(SHIELD_V, SHIELD_I, SHIELD_O, closed=True)


# ---------------------------------------------------------------- scan (loops)
def scan():
    op = 90
    shield = layer(1, "shield", [group([
        shield_path(), stroke(ACCENT, 5), fill(ACCENT, static(10)),
    ], "shield")], op)
    sweep = layer(2, "sweep", [group([
        ellipse(150), trim(0, 22), stroke(ACCENT, 5, static(90)),
    ], "arc")], op, r=anim([(0, 0), (90, 360)]))
    pulse = layer(3, "pulse", [group([
        ellipse(110), stroke(ACCENT, 3),
    ], "ring")], op,
        s=anim([(0, [60, 60, 100]), (90, [135, 135, 100])]),
        o=anim([(0, 70), (90, 0)]))
    dot = layer(4, "dot", [group([ellipse(12), fill(ACCENT)], "dot")], op,
                p=(100, 100),
                s=anim([(0, [100, 100, 100]), (45, [160, 160, 100]), (90, [100, 100, 100])]))
    return comp("Exposr scan", op, [dot, pulse, sweep, shield])


# ------------------------------------------------------------- success (once)
def success():
    op = 75
    glow = layer(1, "glow", [group([ellipse(150), fill(SUCCESS, static(14))], "glow")], op,
                 s=anim([(0, [40, 40, 100]), (30, [110, 110, 100]), (50, [100, 100, 100])]),
                 o=anim([(0, 0), (12, 100)]))
    ring = layer(2, "ring", [group([
        ellipse(118), trim(0, anim([(0, 0), (30, 100)])), stroke(SUCCESS, 7),
    ], "ring")], op, r=static(-90))
    check = layer(3, "check", [group([
        path([[-26, 2], [-8, 20], [28, -18]]),
        trim(0, anim([(24, 0), (46, 100)])),
        stroke(SUCCESS, 9),
    ], "check")], op,
        s=anim([(0, [100, 100, 100]), (46, [100, 100, 100]), (56, [112, 112, 100]), (66, [100, 100, 100])]))
    return comp("Exposr success", op, [check, ring, glow])


# -------------------------------------------------------------- alert (once)
def alert():
    op = 80
    shield = layer(1, "shield", [group([
        shield_path(), stroke(ERROR, 5), fill(ERROR, static(12)),
    ], "shield")], op,
        s=anim([(0, [60, 60, 100]), (14, [112, 112, 100]), (24, [100, 100, 100])]),
        r=anim([(24, 0), (30, -9), (38, 8), (46, -5), (54, 3), (62, 0)]),
        o=anim([(0, 0), (8, 100)]))
    mark = layer(2, "mark", [group([
        path([[0, -24], [0, 8]]), stroke(ERROR, 9),
    ], "bar"), group([
        ellipse(10), fill(ERROR),
    ], "dot", tr=transform(p=(0, 26)))], op,
        s=anim([(0, [0, 0, 100]), (16, [0, 0, 100]), (26, [118, 118, 100]), (34, [100, 100, 100])]))
    pulse1 = layer(3, "pulse1", [group([ellipse(110), stroke(ERROR, 3)], "ring")], op,
                   s=anim([(10, [60, 60, 100]), (50, [150, 150, 100])]),
                   o=anim([(10, 60), (50, 0)]))
    pulse2 = layer(4, "pulse2", [group([ellipse(110), stroke(ERROR, 3)], "ring")], op,
                   s=anim([(26, [60, 60, 100]), (66, [150, 150, 100])]),
                   o=anim([(26, 50), (66, 0)]))
    return comp("Exposr alert", op, [mark, shield, pulse2, pulse1])


# ------------------------------------------------------------- shield (once)
def shield():
    op = 80
    outline = layer(1, "outline", [group([
        shield_path(), trim(0, anim([(0, 0), (40, 100)])), stroke(ACCENT, 5),
    ], "outline")], op)
    body = layer(2, "body", [group([
        shield_path(), fill(ACCENT, static(14)),
    ], "body")], op, o=anim([(30, 0), (56, 100)]))
    # an eye, echoing the logo: a lens shape and a pupil
    eye = layer(3, "eye", [group([
        path([[-20, 0], [0, -14], [20, 0], [0, 14]],
             [[0, 0], [-12, 0], [0, 0], [12, 0]],
             [[0, 0], [12, 0], [0, 0], [-12, 0]], closed=True),
        stroke(TEXT, 4),
    ], "lens"), group([ellipse(11), fill(TEXT)], "pupil")], op,
        o=anim([(40, 0), (58, 100)]),
        s=anim([(40, [70, 70, 100]), (60, [100, 100, 100])]))
    glint = layer(4, "glint", [group([
        shield_path(), stroke(ACCENT, 5, anim([(56, 0), (66, 60), (80, 0)])),
    ], "glint")], op,
        s=anim([(56, [100, 100, 100]), (80, [118, 118, 100])]))
    return comp("Exposr shield", op, [eye, glint, outline, body])


if __name__ == "__main__":
    os.makedirs("../assets/lottie", exist_ok=True)
    for name, fn in [("scan", scan), ("success", success), ("alert", alert), ("shield", shield)]:
        with open(f"../assets/lottie/{name}.json", "w") as f:
            json.dump(fn(), f, separators=(",", ":"))
        print(name, os.path.getsize(f"../assets/lottie/{name}.json"), "bytes")
