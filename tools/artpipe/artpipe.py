#!/usr/bin/env python3
# SPDX-License-Identifier: MIT
"""Saucer art pipeline (concept §11).

  artpipe.py build   regenerate palette, index-map textures, sprites, sounds,
                     .meta.lua sidecars, ATTRIBUTION.md and REUSE.toml
  artpipe.py lint    verify every shipped asset has provenance + valid format

Textures ship as grayscale PNG *index maps* (pixel value = palette index,
0 = transparent) plus a palette strip PNG (one palette per row, 256 wide).
Generated (xAI) sources live in art/src/generated and are only quantized
here; code-generated art (sprites, sounds, palette ramps) is produced by this
script and licensed CC BY 4.0. Every prompt is in art/prompts/log.jsonl.
"""
import json
import math
import os
import struct
import sys
import wave

from PIL import Image, ImageEnhance

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
BASE = os.path.join(ROOT, "data", "base")
LOG = os.path.join(ROOT, "art", "prompts", "log.jsonl")
AUTHOR = "Steve Makesgames and contributors"

# palette regions: 1..63 hull, 64..127 nebula, 128..191 sprites, 192..255 the
# three derelict kit materials (add-detail-pass), 21 or 22 colours each
REGIONS = {"hull": (1, 63), "nebula": (64, 127), "sprites": (128, 191),
           "kit_starship": (192, 212), "kit_station": (213, 233), "kit_city": (234, 255)}

GENERATED = [
    {
        "id": "hull_plating",
        "src": "art/src/generated/hull_plating_src.jpg",
        "out": "generated/textures/hull_plating.png",
        "crop": (0, 0, 512, 512),  # the image came out as a 2x2 tile; keep one tile
        "size": (64, 64),
        "region": "hull",
        "cutout": None,
        "prompt_id": "2026-11-13-hull-plating-01",
    },
    {
        "id": "nebula",
        "src": "art/src/generated/nebula_src.jpg",
        "out": "generated/textures/nebula.png",
        "crop": None,
        "size": (128, 128),
        "region": "nebula",
        "cutout": 18,  # luminance below this becomes index 0 (transparent)
        "prompt_id": "2026-11-13-nebula-01",
    },
    # add-detail-pass: one wall material per derelict kit
    {
        "id": "kit_starship",
        "src": "art/src/generated/kit_starship_src.jpg",
        "out": "generated/textures/kit_starship.png",
        "crop": (0, 0, 512, 512),  # 2x2 repeat again; keep one tile
        "size": (64, 64),
        "region": "kit_starship",
        "cutout": None,
        "gain": 1.7,  # the source is very dark; walls multiply it by the kit colour
        "prompt_id": "2026-11-16-kit-starship-01",
    },
    {
        "id": "kit_station",
        "src": "art/src/generated/kit_station_src.jpg",
        "out": "generated/textures/kit_station.png",
        "crop": None,
        "size": (128, 128),
        "region": "kit_station",
        "cutout": None,
        "gain": 1.3,
        "saturation": 0.25,  # full-strength rust read as wood from a distance
        "prompt_id": "2026-11-16-kit-station-01",
    },
    {
        "id": "kit_city",
        "src": "art/src/generated/kit_city_src.jpg",
        "out": "generated/textures/kit_city.png",
        "crop": None,
        "size": (128, 128),
        "region": "kit_city",
        "cutout": None,
        "gain": 1.1,
        "prompt_id": "2026-11-16-kit-city-01",
    },
]


# add-presentation-packaging (milestone 6): the art pass. Each extra palette
# file holds one 256-colour palette; entries in it get consecutive index
# ranges ("colors" each). Options: crop (box or "cell": (col, row, n)), size
# (w, h) or fit (max w, max h, trimmed to the subject's bounding box), gain,
# saturation, contrast, mean (rescale so the mean luminance hits this; for
# detail textures multiplied by vertex colours), cutout (luminance below ->
# transparent), key (an RGB chroma key colour and its distance), flip (top row
# last, for decals whose v runs bottom-up).
MAT = dict(colors=40, size=(64, 64), saturation=0.25, contrast=0.55, mean=0.86)
ART = {
    "authored/palettes/interior.png": [
        dict(MAT, id="mat_wood", saturation=0.45, mean=0.9),
        dict(MAT, id="mat_fabric", contrast=1.6, size=(32, 32)),
        dict(MAT, id="mat_tile", crop=(0, 0, 512, 512), contrast=0.9, size=(32, 32)),
        dict(MAT, id="mat_floor", crop=(0, 0, 512, 512), contrast=1.0),
        dict(MAT, id="mat_metal", saturation=0.1, contrast=0.7),
        dict(MAT, id="mat_panel", crop=(0, 0, 512, 512), contrast=0.8, colors=35),
    ],
    "authored/palettes/kits.png": [
        dict(id="floor_starship", colors=63, size=(64, 64), crop=(0, 0, 512, 512), gain=1.9, contrast=0.7),
        dict(id="floor_station", colors=63, size=(64, 64), gain=1.35, saturation=0.6),
        dict(id="floor_city", colors=63, size=(64, 64), crop=(0, 0, 512, 512), gain=1.05),
        dict(id="station_hall", colors=63, size=(128, 128), contrast=0.6, saturation=0.7),
    ],
    "authored/palettes/sky.png": [
        dict(id="nebula_b", colors=100, size=(128, 128), cutout=18),
        dict(id="planet", colors=80, fit=(96, 96), cutout=12),
        dict(id="galaxy", colors=75, fit=(96, 96), cutout=14),
    ],
    "authored/palettes/sprites.png": [
        dict(id="folk_1", src="folk_sheet", crop=("cell", 0, 0, 2), colors=30, fit=(40, 80), key=((255, 0, 255), 230)),
        dict(id="folk_2", src="folk_sheet", crop=("cell", 1, 0, 2), colors=30, fit=(40, 80), key=((255, 0, 255), 230)),
        dict(id="folk_3", src="folk_sheet", crop=("cell", 0, 1, 2), colors=30, fit=(40, 80), key=((255, 0, 255), 230)),
        dict(id="folk_4", src="folk_sheet", crop=("cell", 1, 1, 2), colors=30, fit=(40, 80), key=((255, 0, 255), 230)),
        dict(id="sign_food", src="signs", crop=("cell", 0, 0, 2), colors=16, fit=(48, 48), cutout=20, flip=True),
        dict(id="sign_scrap", src="signs", crop=("cell", 1, 0, 2), colors=16, fit=(48, 48), cutout=20, flip=True),
        dict(id="sign_gems", src="signs", crop=("cell", 0, 1, 2), colors=16, fit=(48, 48), cutout=20, flip=True),
        dict(id="sign_bar", src="signs", crop=("cell", 1, 1, 2), colors=16, fit=(48, 48), cutout=20, flip=True),
        dict(id="glyphs", colors=8, size=(128, 128), cutout=40),
        dict(id="title_emblem", colors=47, fit=(128, 128), cutout=14),
    ],
}


def lua_str(s):
    return '"' + s.replace("\\", "\\\\").replace('"', '\\"').replace("\n", "\\n") + '"'


def read_log():
    out = []
    with open(LOG, encoding="utf-8") as f:
        for line in f:
            line = line.strip()
            if line:
                out.append(json.loads(line))
    return out


def quantize(img, ncolors, cutout):
    img = img.convert("RGB")
    q = img.quantize(colors=ncolors, method=Image.Quantize.MEDIANCUT, dither=Image.Dither.NONE)
    pal = q.getpalette()[: 3 * ncolors]
    idx = list(q.getdata())
    if cutout is not None:
        lum = [(r * 299 + g * 587 + b * 114) // 1000 for r, g, b in img.getdata()]
        idx = [-1 if l < cutout else i for i, l in zip(idx, lum)]
    colors = [tuple(pal[3 * i : 3 * i + 3]) for i in range(ncolors)]
    return idx, colors


def build_generated(palette):
    metas = []
    for g in GENERATED:
        img = Image.open(os.path.join(ROOT, g["src"]))
        if g["crop"]:
            img = img.crop(g["crop"])
        img = img.resize(g["size"], Image.Resampling.BOX)
        if g.get("gain"):
            img = ImageEnhance.Brightness(img.convert("RGB")).enhance(g["gain"])
        if g.get("saturation") is not None:
            img = ImageEnhance.Color(img.convert("RGB")).enhance(g["saturation"])
        lo, hi = REGIONS[g["region"]]
        idx, colors = quantize(img, hi - lo + 1, g["cutout"])
        for i, c in enumerate(colors):
            palette[lo + i] = c + (255,)
        out = Image.new("L", g["size"])
        out.putdata([0 if i < 0 else lo + i for i in idx])
        path = os.path.join(BASE, g["out"])
        os.makedirs(os.path.dirname(path), exist_ok=True)
        out.save(path, optimize=True)
        metas.append(g)
    return metas


def _trim(img, mask):
    """bounding box of the opaque pixels of mask (a list of bools) in img"""
    w, h = img.size
    xs = [i % w for i, m in enumerate(mask) if m]
    ys = [i // w for i, m in enumerate(mask) if m]
    if not xs:
        return (0, 0, w, h)
    return (min(xs), min(ys), max(xs) + 1, max(ys) + 1)


def build_art(entry):
    """one art-pass entry -> (index list, colours, size); colours are RGB"""
    src = os.path.join(ROOT, "art", "src", "generated", entry.get("src", entry["id"]) + "_src.jpg")
    img = Image.open(src).convert("RGB")
    crop = entry.get("crop")
    if crop and crop[0] == "cell":
        _, cx, cy, n = crop
        cw, ch = img.size[0] // n, img.size[1] // n
        img = img.crop((cx * cw, cy * ch, (cx + 1) * cw, (cy + 1) * ch))
    elif crop:
        img = img.crop(crop)

    def opaque(im):
        px = list(im.getdata())
        out = [True] * len(px)
        if entry.get("cutout") is not None:
            out = [o and (r * 299 + g * 587 + b * 114) // 1000 >= entry["cutout"] for o, (r, g, b) in zip(out, px)]
        if entry.get("key"):
            (kr, kg, kb), dist = entry["key"]
            out = [o and abs(r - kr) + abs(g - kg) + abs(b - kb) > dist and not (r > 140 and b > 140 and g < 110)
                   for o, (r, g, b) in zip(out, px)]
        return out

    if entry.get("fit"):
        small = img.resize((img.size[0] // 4, img.size[1] // 4), Image.Resampling.BOX)
        x0, y0, x1, y1 = _trim(small, opaque(small))
        pad = 1
        img = img.crop((max(0, (x0 - pad) * 4), max(0, (y0 - pad) * 4), min(img.size[0], (x1 + pad) * 4),
                        min(img.size[1], (y1 + pad) * 4)))
        mw, mh = entry["fit"]
        k = min(mw / img.size[0], mh / img.size[1])
        size = (max(1, round(img.size[0] * k)), max(1, round(img.size[1] * k)))
    else:
        size = entry["size"]
    img = img.resize(size, Image.Resampling.BOX)
    if entry.get("gain"):
        img = ImageEnhance.Brightness(img).enhance(entry["gain"])
    if entry.get("saturation") is not None:
        img = ImageEnhance.Color(img).enhance(entry["saturation"])
    if entry.get("contrast") is not None:
        img = ImageEnhance.Contrast(img).enhance(entry["contrast"])
    if entry.get("mean"):
        lum = [(r * 299 + g * 587 + b * 114) / 255000 for r, g, b in img.getdata()]
        m = sum(lum) / len(lum)
        img = ImageEnhance.Brightness(img).enhance(entry["mean"] / max(m, 1e-3))
    mask = opaque(img)
    if entry.get("flip"):
        img = img.transpose(Image.Transpose.FLIP_TOP_BOTTOM)
        w = size[0]
        mask = [mask[(size[1] - 1 - i // w) * w + i % w] for i in range(len(mask))]
    q = img.quantize(colors=entry["colors"], method=Image.Quantize.MEDIANCUT, dither=Image.Dither.NONE)
    pal = q.getpalette()[: 3 * entry["colors"]]
    pal += [0] * (3 * entry["colors"] - len(pal))
    idx = [i if m else -1 for i, m in zip(q.getdata(), mask)]
    colors = [tuple(pal[3 * i: 3 * i + 3]) for i in range(entry["colors"])]
    return idx, colors, size


def build_art_pass():
    """-> list of (texture rel path, entry, palette rel path)"""
    out = []
    for pal_rel, entries in ART.items():
        palette = [(0, 0, 0, 0)] + [(0, 0, 0, 255)] * 255
        lo = 1
        for e in entries:
            idx, colors, size = build_art(e)
            if lo + len(colors) - 1 > 255:
                raise SystemExit("artpipe: palette %s is full at %s" % (pal_rel, e["id"]))
            for i, c in enumerate(colors):
                palette[lo + i] = c + (255,)
            img = Image.new("L", size)
            img.putdata([0 if i < 0 else lo + i for i in idx])
            rel = "generated/textures/%s.png" % e["id"]
            img.save(os.path.join(BASE, rel), optimize=True)
            out.append((rel, e, pal_rel))
            lo += len(colors)
        im = Image.new("RGBA", (256, 1))
        im.putdata(palette)
        im.save(os.path.join(BASE, pal_rel), optimize=True)
    return out


def sprite(size, fn):
    img = Image.new("L", (size, size))
    img.putdata([fn(x, y) for y in range(size) for x in range(size)])
    return img


def build_sprites(palette):
    lo = REGIONS["sprites"][0]
    ramps = {
        "gold": [(60, 40, 10), (140, 90, 20), (220, 160, 40), (255, 220, 120), (255, 250, 220)],
        "cyan": [(10, 40, 60), (20, 110, 140), (60, 200, 230), (160, 240, 255), (240, 255, 255)],
        "beam": [(90, 70, 10), (200, 170, 40), (255, 240, 160), (255, 255, 240), (255, 255, 255)],
    }
    base = {}
    i = lo
    for name, ramp in ramps.items():
        base[name] = i
        for c in ramp:
            palette[i] = c + (255,)
            i += 1

    def orb(ramp, size, ring):
        b = base[ramp]
        c = (size - 1) / 2

        def f(x, y):
            d = math.hypot(x - c, y - c) / (size / 2)
            if ring:
                if 0.55 < d < 0.85:
                    return b + 2 + (1 if abs(d - 0.7) < 0.08 else 0)
                if d < 0.25:
                    return b + 4
                return 0
            if d > 0.95:
                return 0
            hl = math.hypot(x - c * 0.7, y - c * 0.7) / (size / 2)
            return b + max(0, min(4, int(4.5 - hl * 4.5)))

        return f

    out = {
        "authored/sprites/loot.png": sprite(16, orb("gold", 16, False)),
        "authored/sprites/echo.png": sprite(32, orb("cyan", 32, True)),
        "authored/sprites/beam.png": sprite(8, orb("beam", 8, False)),
        "authored/sprites/glow.png": sprite(16, orb("cyan", 16, False)),  # thruster glow (add-detail-pass)
    }
    for rel, img in out.items():
        path = os.path.join(BASE, rel)
        os.makedirs(os.path.dirname(path), exist_ok=True)
        img.save(path, optimize=True)
    return list(out)


def build_palette(palette):
    path = os.path.join(BASE, "authored", "palettes", "base.png")
    os.makedirs(os.path.dirname(path), exist_ok=True)
    img = Image.new("RGBA", (256, 1))
    img.putdata([palette[i] for i in range(256)])
    img.save(path, optimize=True)
    return "authored/palettes/base.png"


def synth(path, dur, fn, rate=22050, loop=False):
    n = int(dur * rate)
    frames = bytearray()
    for i in range(n):
        t = i / rate
        env = 1.0 if loop else min(1.0, t / 0.01) * max(0.0, 1.0 - t / dur)
        v = max(-1.0, min(1.0, fn(t) * env))
        frames += struct.pack("<h", int(v * 30000))
    os.makedirs(os.path.dirname(path), exist_ok=True)
    with wave.open(path, "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(rate)
        w.writeframes(bytes(frames))


def build_sounds():
    s = os.path.join(BASE, "authored", "sounds")
    sweep = lambda f0, f1, d: (lambda t: 0.5 * math.sin(2 * math.pi * (f0 * t + (f1 - f0) * t * t / (2 * d))))
    sounds = {
        "shrink.wav": (0.6, sweep(880, 220, 0.6)),
        "grow.wav": (1.0, sweep(180, 720, 1.0)),
        "tractor.wav": (0.5, lambda t: 0.4 * math.sin(2 * math.pi * 300 * t) * (0.6 + 0.4 * math.sin(2 * math.pi * 18 * t))),
        "pickup.wav": (0.35, lambda t: 0.5 * math.sin(2 * math.pi * (660 if t < 0.12 else 990) * t)),
        "denied.wav": (0.3, lambda t: 0.45 * (1 if math.sin(2 * math.pi * 140 * t) > 0 else -1) * 0.5),
        "bank.wav": (0.5, lambda t: 0.4 * (math.sin(2 * math.pi * 523 * t) + math.sin(2 * math.pi * 784 * t)) / 1.5),
        "echo.wav": (1.4, lambda t: 0.35 * math.sin(2 * math.pi * 440 * t) * math.sin(2 * math.pi * 3 * t) ** 2),
    }
    out = []
    for name, (dur, fn) in sounds.items():
        synth(os.path.join(s, name), dur, fn)
        out.append("authored/sounds/" + name)
    # add-presentation-packaging: the audio pass. One-shots for events that had
    # no sound yet, and seamless loops (whole cycles only, noise cross-faded
    # into its own start) for the engine, the beam, the holodeck, the station
    # and derelict halls.
    for name, (dur, fn, loop) in pass_sounds().items():
        synth(os.path.join(s, name), dur, fn, loop=loop)
        out.append("authored/sounds/" + name)
    # add-wider-dark: procedural music. One note per instrument at C4 (the bass
    # at C2); view/music.lua pitches them to each civilization's scale.
    for name, (dur, fn) in music_notes().items():
        synth(os.path.join(s, name), dur, fn)
        out.append("authored/sounds/" + name)
    return out


def music_notes():
    c4, c2 = 261.63, 65.41
    tau = 2 * math.pi

    def pluck(t):
        return 0.5 * math.exp(-t * 5.0) * (math.sin(tau * c4 * t) + 0.35 * math.sin(tau * 2 * c4 * t)
                                           + 0.12 * math.sin(tau * 3 * c4 * t))

    def bell(t):
        return 0.4 * math.exp(-t * 2.2) * (math.sin(tau * c4 * t) + 0.5 * math.sin(tau * 2.76 * c4 * t)
                                           + 0.25 * math.sin(tau * 5.4 * c4 * t))

    def pad(t):
        swell = min(1.0, t / 0.5)
        return 0.28 * swell * (math.sin(tau * c4 * t) + 0.5 * math.sin(tau * c4 * 1.003 * t)
                               + 0.3 * math.sin(tau * c4 * 2 * t)) * (0.85 + 0.15 * math.sin(tau * 4 * t))

    def bass(t):
        return 0.55 * math.exp(-t * 2.5) * (math.sin(tau * c2 * t) + 0.3 * math.sin(tau * 2 * c2 * t))

    return {"note_pluck.wav": (1.0, pluck), "note_bell.wav": (1.8, bell), "note_pad.wav": (2.4, pad),
            "note_bass.wav": (1.2, bass)}


def _noise(n, seed, smooth):
    """deterministic one-pole low-passed white noise, n samples in -1..1"""
    x, y, out = seed & 0x7FFFFFFF, 0.0, []
    for _ in range(n):
        x = (1103515245 * x + 12345) & 0x7FFFFFFF
        y += (x / 0x3FFFFFFF - 1.0 - y) * smooth
        out.append(y)
    peak = max(1e-6, max(abs(v) for v in out))
    return [v / peak for v in out]


def _loop_noise(dur, seed, smooth, rate=22050):
    """noise that loops: the last 10% fades into the first"""
    n = int(dur * rate)
    fade = n // 10
    raw = _noise(n + fade, seed, smooth)
    out = raw[:n]
    for i in range(fade):
        k = i / fade
        out[i] = raw[i] * k + raw[n + i] * (1 - k)
    return out


def pass_sounds(rate=22050):
    tau = 2 * math.pi
    sin = math.sin
    sq = lambda f, t: 1.0 if sin(tau * f * t) > 0 else -1.0
    hum_n = _loop_noise(2.0, 11, 0.02)
    station_n = _loop_noise(4.0, 23, 0.08)
    derelict_n = _loop_noise(4.0, 37, 0.01)
    door_n = _noise(int(0.45 * rate), 5, 0.25)
    hit_n = _noise(int(0.4 * rate), 9, 0.6)
    at = lambda arr: (lambda t: arr[min(len(arr) - 1, int(t * rate))])
    hn, sn, dn, don, hin = at(hum_n), at(station_n), at(derelict_n), at(door_n), at(hit_n)

    def engine_hum(t):  # 2 s: 55 Hz body, 110/165 Hz harmonics, 0.5 Hz throb, a breath of noise
        throb = 0.8 + 0.2 * sin(tau * 0.5 * t)
        return throb * (0.32 * sin(tau * 55 * t) + 0.14 * sin(tau * 110 * t) + 0.06 * sin(tau * 165 * t)) + 0.08 * hn(t)

    def beam_loop(t):  # 1 s: shimmering 300/450 Hz with a 6 Hz tremolo and a 3 Hz rising chirp
        trem = 0.6 + 0.4 * sin(tau * 6 * t)
        chirp = sin(tau * (600 * t + 150 * ((t * 3) % 1) ** 2 / 3))
        return trem * (0.25 * sin(tau * 300 * t) + 0.12 * sin(tau * 450 * t)) + 0.05 * chirp

    def holo_loop(t):  # 4 s: a soft pad (A2, C#3, E3 in 0.25 Hz steps) breathing at 0.25 Hz
        swell = 0.6 + 0.4 * sin(tau * 0.25 * t)
        return swell * 0.12 * (sin(tau * 110 * t) + sin(tau * 138.5 * t) + sin(tau * 165 * t) + 0.5 * sin(tau * 220 * t))

    def station_loop(t):  # 4 s: crowd murmur (noise in 1 Hz swells) and two distant clanks
        murmur = 0.22 * sn(t) * (0.7 + 0.3 * sin(tau * 1.0 * t))
        clank = 0.0
        for c, f in ((0.7, 740), (2.6, 523)):
            d = t - c
            if 0 <= d < 0.35:
                clank += 0.18 * sin(tau * f * d) * math.exp(-d * 14)
        return murmur + clank + 0.05 * sin(tau * 60 * t)

    def derelict_loop(t):  # 4 s: deep drone (41.25 Hz), slow wind, a creak at 1.9 s
        creak = 0.0
        d = t - 1.9
        if 0 <= d < 0.6:
            creak = 0.12 * sin(tau * (180 + 120 * d) * d) * sin(math.pi * d / 0.6)
        return 0.25 * sin(tau * 41.25 * t) * (0.8 + 0.2 * sin(tau * 0.5 * t)) + 0.18 * dn(t) + creak

    def door(t):  # pneumatic slide: filtered noise swell and a falling tone
        return 0.45 * don(t) * sin(math.pi * min(1, t / 0.45)) + 0.15 * sin(tau * (420 - 380 * t) * t)

    def scan(t):  # rising ping and its echo
        return 0.4 * sin(tau * (600 + 900 * t) * t) * math.exp(-t * 3) + 0.2 * sin(tau * 1200 * t) * math.exp(-abs(t - 0.4) * 12)

    def jam(t):  # buzzy detuned squares
        return 0.18 * (sq(97, t) + sq(103, t)) * (0.6 + 0.4 * sq(8, t))

    def alert(t):  # two-tone beep
        return 0.35 * sin(tau * (880 if t < 0.2 else 660) * t) * (1 if (t % 0.25) < 0.18 else 0)

    def locked(t):  # fast alarm warble
        return 0.3 * sq(700 + 250 * sin(tau * 9 * t), t)

    def hit(t):  # zap: noise burst and a falling sine
        return 0.5 * hin(t) * math.exp(-t * 9) + 0.3 * sin(tau * (900 - 1500 * t) * t) * math.exp(-t * 6)

    def click(t):  # menu tick
        return 0.4 * sin(tau * 1500 * t) * math.exp(-t * 60)

    def coin(t):  # the saucer pocketed / taken out: two bright chimes
        return 0.3 * (sin(tau * 1318.5 * t) + (sin(tau * 1975.5 * t) if t > 0.08 else 0)) * math.exp(-t * 6)

    return {
        "engine_hum.wav": (2.0, engine_hum, True),
        "beam_loop.wav": (1.0, beam_loop, True),
        "holo_loop.wav": (4.0, holo_loop, True),
        "station_loop.wav": (4.0, station_loop, True),
        "derelict_loop.wav": (4.0, derelict_loop, True),
        "door.wav": (0.45, door, False),
        "scan.wav": (0.8, scan, False),
        "jam.wav": (0.6, jam, False),
        "alert.wav": (0.5, alert, False),
        "locked.wav": (0.7, locked, False),
        "hit.wav": (0.4, hit, False),
        "click.wav": (0.06, click, False),
        "coin.wav": (0.5, coin, False),
    }


def write_meta(rel, fields):
    path = os.path.join(BASE, rel + ".meta.lua")
    lines = ["-- generated by tools/artpipe/artpipe.py; provenance record for " + rel, "return {"]
    for k, v in fields.items():
        lines.append("  %s = %s," % (k, lua_str(v) if isinstance(v, str) else str(v).lower()))
    lines.append("}")
    with open(path, "w", encoding="utf-8") as f:
        f.write("\n".join(lines) + "\n")


def build():
    palette = [(0, 0, 0, 0)] + [(0, 0, 0, 255)] * 255
    log = {e["id"]: e for e in read_log()}
    gens = build_generated(palette)
    sprites = build_sprites(palette)
    pal = build_palette(palette)
    sounds = build_sounds()
    art = build_art_pass()
    attrib = []
    for g in gens:
        e = log[g["prompt_id"]]
        write_meta(g["out"], {
            "license": "LicenseRef-xAI-Output", "source": "generated", "tool": e["tool"], "model": e["model"],
            "prompt_id": e["id"], "prompt": e["prompt"], "date": e["date"], "attribution": "Created with Grok",
            "source_file": g["src"], "processing": "crop/resize/median-cut quantize to palette region " + g["region"],
        })
        attrib.append(("data/base/" + g["out"], "LicenseRef-xAI-Output", "Created with Grok (%s), prompt %s" % (e["tool"], e["id"])))
    for rel, g, pal_rel in art:
        src = g.get("src", g["id"])
        e = log["2026-11-17-%s-01" % src.replace("_", "-")]
        write_meta(rel, {
            "license": "LicenseRef-xAI-Output", "source": "generated", "tool": e["tool"], "model": e["model"],
            "prompt_id": e["id"], "prompt": e["prompt"], "date": e["date"], "attribution": "Created with Grok",
            "source_file": "art/src/generated/%s_src.jpg" % src,
            "processing": "crop/resize/median-cut quantize to %d colours of %s" % (g["colors"], pal_rel),
            "palette": pal_rel,
        })
        attrib.append(("data/base/" + rel, "LicenseRef-xAI-Output", "Created with Grok (%s), prompt %s" % (e["tool"], e["id"])))
    for rel in list(dict.fromkeys(a[2] for a in art)):
        write_meta(rel, {"license": "CC-BY-4.0", "source": "code", "author": AUTHOR,
                         "generator": "tools/artpipe/artpipe.py",
                         "notes": "colours picked by median-cut from Grok Imagine sources; the palette itself is code output"})
        attrib.append(("data/base/" + rel, "CC-BY-4.0", "code-generated by tools/artpipe/artpipe.py, " + AUTHOR))
    for rel in sprites + [pal] + sounds:
        write_meta(rel, {"license": "CC-BY-4.0", "source": "code", "author": AUTHOR,
                         "generator": "tools/artpipe/artpipe.py"})
        attrib.append(("data/base/" + rel, "CC-BY-4.0", "code-generated by tools/artpipe/artpipe.py, " + AUTHOR))
    write_attribution(attrib, log)
    print("artpipe: %d generated, %d code-generated assets" % (len(gens) + len(art), len(sprites) + len(sounds) + 1 + len(ART)))


def write_attribution(attrib, log):
    lines = [
        "# Attribution",
        "",
        "Generated by `tools/artpipe/artpipe.py build` — do not edit by hand.",
        "See [LICENSING.md](LICENSING.md) for what each license covers.",
        "",
        "| Asset | License | Credit |",
        "|---|---|---|",
    ]
    for path, lic, credit in attrib:
        lines.append("| `%s` | %s | %s |" % (path, lic, credit))
    lines += ["", "## Image generation prompts", "",
              "Every prompt used for this project, kept or not, is recorded in `art/prompts/log.jsonl`.", ""]
    for e in log.values():
        lines.append("- **%s** (%s, %s, %s): %s" % (e["id"], e["tool"], e["date"], "kept" if e.get("kept") else "discarded",
                                                   e["prompt"]))
    lines += ["", "Images generated with Grok Imagine are xAI outputs: owned by the user under xAI's Terms of Service",
              "and attributed as \"Created with Grok\" per xAI's brand guidelines. See",
              "`LICENSES/LicenseRef-xAI-Output.md`.", ""]
    with open(os.path.join(ROOT, "ATTRIBUTION.md"), "w", encoding="utf-8") as f:
        f.write("\n".join(lines))


def lint():
    errors = []
    log_ids = {e["id"] for e in read_log()}
    for dirpath, _, files in os.walk(BASE):
        for name in files:
            rel = os.path.relpath(os.path.join(dirpath, name), BASE).replace(os.sep, "/")
            if name.endswith((".png", ".wav")):
                meta = os.path.join(dirpath, name + ".meta.lua")
                if not os.path.exists(meta):
                    errors.append("missing provenance sidecar: " + rel)
                    continue
                text = open(meta, encoding="utf-8").read()
                if rel.startswith("generated/") and "LicenseRef-xAI-Output" not in text:
                    errors.append("generated asset without xAI output license: " + rel)
                if rel.startswith("authored/") and "CC-BY-4.0" not in text:
                    errors.append("authored asset without CC-BY-4.0: " + rel)
                if "prompt_id" in text:
                    pid = text.split('prompt_id = "')[1].split('"')[0]
                    if pid not in log_ids:
                        errors.append("prompt %s of %s missing from art/prompts/log.jsonl" % (pid, rel))
            if name.endswith(".png") and "palettes" not in rel:
                img = Image.open(os.path.join(dirpath, name))
                if img.mode != "L":
                    errors.append("texture is not a grayscale index map: %s (%s)" % (rel, img.mode))
                if max(img.size) > 256:
                    errors.append("texture larger than 256 px: " + rel)
    for e in errors:
        print("artpipe lint: " + e)
    print("artpipe lint: %s" % ("FAIL" if errors else "OK"))
    return 1 if errors else 0


if __name__ == "__main__":
    cmd = sys.argv[1] if len(sys.argv) > 1 else "build"
    if cmd == "build":
        build()
    elif cmd == "lint":
        sys.exit(lint())
    else:
        print(__doc__)
        sys.exit(2)
