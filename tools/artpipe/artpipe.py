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


def synth(path, dur, fn, rate=22050):
    n = int(dur * rate)
    frames = bytearray()
    for i in range(n):
        t = i / rate
        env = min(1.0, t / 0.01) * max(0.0, 1.0 - t / dur)
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
    return out


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
    attrib = []
    for g in gens:
        e = log[g["prompt_id"]]
        write_meta(g["out"], {
            "license": "LicenseRef-xAI-Output", "source": "generated", "tool": e["tool"], "model": e["model"],
            "prompt_id": e["id"], "prompt": e["prompt"], "date": e["date"], "attribution": "Created with Grok",
            "source_file": g["src"], "processing": "crop/resize/median-cut quantize to palette region " + g["region"],
        })
        attrib.append(("data/base/" + g["out"], "LicenseRef-xAI-Output", "Created with Grok (%s), prompt %s" % (e["tool"], e["id"])))
    for rel in sprites + [pal] + sounds:
        write_meta(rel, {"license": "CC-BY-4.0", "source": "code", "author": AUTHOR,
                         "generator": "tools/artpipe/artpipe.py"})
        attrib.append(("data/base/" + rel, "CC-BY-4.0", "code-generated by tools/artpipe/artpipe.py, " + AUTHOR))
    write_attribution(attrib, log)
    print("artpipe: %d generated, %d code-generated assets" % (len(gens), len(sprites) + len(sounds) + 1))


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
