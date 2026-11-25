#!/usr/bin/env python3
# SPDX-License-Identifier: MIT
# add-civ-dungeons: draw the relic maps dumped by tools/maps/relic_maps_spec.lua, top-down (x across, z down),
# lower levels darker, the main way to the heart outlined. Usage: relic_maps.py maps.txt maps.png
import sys
from PIL import Image, ImageDraw

COL = {"hall": (90, 140, 200), "core": (220, 120, 255), "trunk": (110, 110, 120), "shaft": (200, 200, 90),
       "entrance": (255, 120, 90), "chamber": (90, 200, 120), "reliquary": (255, 220, 90), "passage": (70, 160, 90)}

def main(src, dst):
    relics, cur = [], None
    for line in open(src):
        p = line.split()
        if p[0] == "relic":
            cur = {"title": line[6:].strip(), "rooms": []}
            relics.append(cur)
        else:
            cur["rooms"].append((p[0], p[1] == "1", *map(float, p[2:])))
    tile, cols = 420, 3
    rows = (len(relics) + cols - 1) // cols
    img = Image.new("RGB", (tile * cols, tile * rows), (12, 12, 16))
    d = ImageDraw.Draw(img)
    for i, r in enumerate(relics):
        ox, oy = (i % cols) * tile, (i // cols) * tile
        xs = [v for rm in r["rooms"] for v in (rm[2], rm[5])]
        zs = [v for rm in r["rooms"] for v in (rm[4], rm[7])]
        ys = [rm[3] for rm in r["rooms"]]
        x0, z0, ylo, yhi = min(xs), min(zs), min(ys), max(ys)
        s = (tile - 40) / max(max(xs) - x0, max(zs) - z0)
        for rm in sorted(r["rooms"], key=lambda q: q[3]):
            k = 0.45 + 0.55 * ((rm[3] - ylo) / max(1, yhi - ylo))
            c = tuple(int(v * k) for v in COL.get(rm[0], (150, 150, 150)))
            box = [ox + 20 + (rm[2] - x0) * s, oy + 30 + (rm[4] - z0) * s, ox + 20 + (rm[5] - x0) * s, oy + 30 + (rm[7] - z0) * s]
            d.rectangle(box, fill=c, outline=(255, 255, 255) if rm[1] else None)
        d.text((ox + 8, oy + 6), r["title"], fill=(230, 230, 230))
    img.save(dst)

if __name__ == "__main__":
    main(sys.argv[1], sys.argv[2])
