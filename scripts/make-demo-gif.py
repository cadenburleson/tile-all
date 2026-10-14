#!/usr/bin/env python3
"""Render docs/demo.gif: a simulated desktop where ⌃⌥⌘G tiles the Terminal windows.

Drawn from scratch (no screen capture) so nothing private ends up in the repo.
Uses the same row-picking rule as Sources/TileAll/Layout.swift.

    python3 scripts/make-demo-gif.py
"""
import math
import random
from pathlib import Path

from PIL import Image, ImageDraw, ImageFont

W, H = 960, 600
MENU = 26
SCALE = 2  # draw at 2x, downsample for smooth edges
OUT = Path(__file__).resolve().parent.parent / "docs" / "demo.gif"


def font(size):
    for path in ("/System/Library/Fonts/SFNSMono.ttf", "/System/Library/Fonts/Menlo.ttc",
                 "/System/Library/Fonts/Supplemental/Courier New.ttf"):
        try:
            return ImageFont.truetype(path, size * SCALE)
        except OSError:
            pass
    return ImageFont.load_default()


def ui_font(size):
    for path in ("/System/Library/Fonts/SFNS.ttf", "/System/Library/Fonts/Helvetica.ttc"):
        try:
            return ImageFont.truetype(path, size * SCALE)
        except OSError:
            pass
    return ImageFont.load_default()


def rows_for(n, w, h):
    """Mirror of Layout.rows: row count whose tiles are closest to square."""
    best, best_score = [n], math.inf
    for r in range(1, n + 1):
        base, extra = divmod(n, r)
        rows = [base + 1 if i < extra else base for i in range(r)]
        score = sum(c * abs(math.log(w / c / (h / r))) for c in rows) / n
        if score < best_score - 1e-9:
            best, best_score = rows, score
    return best


def grid(n, x, y, w, h, gap=6):
    rows = rows_for(n, w, h)
    out = []
    rh = (h - gap * (len(rows) + 1)) / len(rows)
    for r, cols in enumerate(rows):
        cw = (w - gap * (cols + 1)) / cols
        for c in range(cols):
            out.append((x + gap + c * (cw + gap), y + gap + r * (rh + gap), cw, rh))
    return out


def lerp_rect(a, b, t):
    return tuple(p + (q - p) * t for p, q in zip(a, b))


def ease(t):
    return 4 * t ** 3 if t < 0.5 else 1 - (-2 * t + 2) ** 3 / 2


random.seed(7)
MONO = font(9)
UI = ui_font(11)
KEY = ui_font(22)
LABEL = ui_font(13)

COMMANDS = [
    ["$ npm run dev", "  ready on :3000", "  compiled in 412ms"],
    ["$ git status", "On branch main", "nothing to commit"],
    ["$ swift build", "Compiling TileAll", "Build complete!"],
    ["$ htop", "CPU [|||||    ] 38%", "Mem [||||     ] 9.1G"],
    ["$ tail -f app.log", "GET /api/posts 200", "GET /health 200"],
    ["$ python3 train.py", "epoch 3/10 loss 0.41", "epoch 4/10 loss 0.37"],
    ["$ ssh prod", "Welcome to Ubuntu", "~ $ uptime"],
]
TERMINALS = [
    (40, 60, 330, 220), (300, 110, 360, 240), (560, 50, 340, 200), (120, 300, 320, 220),
    (470, 280, 380, 230), (680, 200, 250, 180), (220, 190, 300, 200),
]
# A browser window from another app, which ⌃⌥⌘G leaves alone.
BROWSER = (90, 80, 780, 470)


def draw_window(d, rect, terminal, lines=None, active=False):
    x, y, w, h = (v * SCALE for v in rect)
    r = 10 * SCALE
    shadow = (0, 0, 0, 70)
    d.rounded_rectangle((x + 3 * SCALE, y + 6 * SCALE, x + w + 3 * SCALE, y + h + 6 * SCALE), r, fill=shadow)
    body = (28, 30, 36) if terminal else (250, 250, 252)
    bar = (48, 51, 60) if terminal else (232, 233, 238)
    d.rounded_rectangle((x, y, x + w, y + h), r, fill=body, outline=(80, 84, 96) if terminal else (205, 207, 214), width=SCALE)
    d.rounded_rectangle((x, y, x + w, y + 24 * SCALE), r, fill=bar)
    d.rectangle((x, y + 14 * SCALE, x + w, y + 24 * SCALE), fill=bar)
    for i, c in enumerate([(255, 95, 87), (254, 188, 46), (40, 200, 64)]):
        cx, cy = x + (14 + i * 16) * SCALE, y + 12 * SCALE
        d.ellipse((cx - 5 * SCALE, cy - 5 * SCALE, cx + 5 * SCALE, cy + 5 * SCALE), fill=c)
    if terminal:
        for i, line in enumerate(lines or []):
            ty = y + (34 + i * 15) * SCALE
            if ty + 12 * SCALE > y + h:
                break
            d.text((x + 12 * SCALE, ty), line, font=MONO, fill=(120, 220, 140) if i == 0 else (215, 218, 226))
        cy = y + (34 + len(lines or []) * 15) * SCALE
        if cy + 12 * SCALE < y + h:
            d.rectangle((x + 12 * SCALE, cy, x + 19 * SCALE, cy + 11 * SCALE), fill=(215, 218, 226))
    else:
        d.rounded_rectangle((x + 70 * SCALE, y + 5 * SCALE, x + w - 70 * SCALE, y + 19 * SCALE), 7 * SCALE, fill=(255, 255, 255))
        d.text((x + 82 * SCALE, y + 6 * SCALE), "github.com", font=UI, fill=(110, 112, 120))
        for i in range(6):
            bw = (w / SCALE - 80) * (0.9 if i % 3 else 0.55)
            d.rounded_rectangle((x + 40 * SCALE, y + (60 + i * 34) * SCALE, x + (40 + bw) * SCALE, y + (78 + i * 34) * SCALE),
                                5 * SCALE, fill=(228, 230, 236))


def background():
    img = Image.new("RGB", (W * SCALE, H * SCALE))
    d = ImageDraw.Draw(img)
    for yy in range(H * SCALE):
        t = yy / (H * SCALE)
        d.line((0, yy, W * SCALE, yy), fill=(int(40 + 60 * t), int(60 + 30 * t), int(140 - 20 * t)))
    return img


BG = background()


def frame(rects, overlay=None):
    img = BG.copy()
    d = ImageDraw.Draw(img, "RGBA")
    draw_window(d, BROWSER, terminal=False)
    for i, r in enumerate(rects):
        draw_window(d, r, terminal=True, lines=COMMANDS[i])
    # Menu bar with the Tile All icon.
    d.rectangle((0, 0, W * SCALE, MENU * SCALE), fill=(245, 245, 247, 225))
    d.text((16 * SCALE, 6 * SCALE), "Terminal", font=ui_font(12), fill=(20, 20, 24))
    ix, iy = (W - 70) * SCALE, 7 * SCALE
    for gx in range(2):
        for gy in range(2):
            d.rounded_rectangle((ix + gx * 7 * SCALE, iy + gy * 7 * SCALE, ix + (gx * 7 + 5) * SCALE, iy + (gy * 7 + 5) * SCALE),
                                SCALE, fill=(30, 30, 34))
    d.text(((W - 46) * SCALE, 6 * SCALE), "11:42", font=ui_font(12), fill=(20, 20, 24))
    if overlay:
        keys, label = overlay
        tw = d.textlength(keys, font=KEY)
        bw, bh = max(tw, d.textlength(label, font=LABEL)) + 48 * SCALE, 74 * SCALE
        bx, by = (W * SCALE - bw) / 2, (H - 110) * SCALE
        d.rounded_rectangle((bx, by, bx + bw, by + bh), 16 * SCALE, fill=(20, 20, 24, 215))
        d.text(((W * SCALE - tw) / 2, by + 10 * SCALE), keys, font=KEY, fill=(255, 255, 255))
        lw = d.textlength(label, font=LABEL)
        d.text(((W * SCALE - lw) / 2, by + 46 * SCALE), label, font=LABEL, fill=(190, 192, 200))
    return img.resize((W, H), Image.LANCZOS)


def main():
    tiled = grid(len(TERMINALS), 0, MENU, W, H - MENU)
    # Assign windows to tiles the way Tiler does: by row from the top, then left to right.
    order = sorted(range(len(TERMINALS)), key=lambda i: TERMINALS[i][1] + TERMINALS[i][3] / 2)
    rows = rows_for(len(TERMINALS), W, H - MENU)
    target = [None] * len(TERMINALS)
    k = 0
    for cols in rows:
        chunk = sorted(order[k:k + cols], key=lambda i: TERMINALS[i][0] + TERMINALS[i][2] / 2)
        for j, i in enumerate(chunk):
            target[i] = tiled[k + j]
        k += cols

    frames, durations = [], []

    def hold(rects, ms, overlay=None):
        frames.append(frame(rects, overlay))
        durations.append(ms)

    def tween(a, b, overlay, steps=16):
        for s in range(1, steps + 1):
            t = ease(s / steps)
            frames.append(frame([lerp_rect(p, q, t) for p, q in zip(a, b)], overlay))
            durations.append(33)

    tile_hint = ("⌃ ⌥ ⌘ G", "Tile Terminal windows")
    undo_hint = ("⌃ ⌥ ⌘ Z", "Restore previous layout")
    hold(TERMINALS, 1400)
    hold(TERMINALS, 350, tile_hint)
    tween(TERMINALS, target, tile_hint)
    hold(target, 700, tile_hint)
    hold(target, 2200)
    hold(target, 350, undo_hint)
    tween(target, TERMINALS, undo_hint)
    hold(TERMINALS, 900, undo_hint)

    OUT.parent.mkdir(exist_ok=True)
    palette = [f.convert("P", palette=Image.ADAPTIVE, colors=256) for f in frames]
    palette[0].save(OUT, save_all=True, append_images=palette[1:], duration=durations, loop=0, optimize=True)
    print(f"wrote {OUT} ({OUT.stat().st_size // 1024} KB, {len(frames)} frames)")


if __name__ == "__main__":
    main()
