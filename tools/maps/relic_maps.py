#!/usr/bin/env python3
# SPDX-License-Identifier: MIT
# add-civ-dungeons: draw the relic maps dumped by tools/maps/relic_maps_spec.lua, top-down (x across, z down),
# lower levels darker, the main way to the heart outlined. Usage: relic_maps.py maps.txt maps.png [cols] [tile]
# relic-room-shapes: a shaped hall is drawn by its free floor (the box behind it dimmed) and its contour.
import sys
from PIL import Image, ImageDraw

COL = {"hall": (90, 140, 200), "core": (220, 120, 255), "trunk": (110, 110, 120), "shaft": (200, 200, 90),
       "entrance": (255, 120, 90), "chamber": (90, 200, 120), "reliquary": (255, 220, 90), "passage": (70, 160, 90)}

def main(src, dst, cols=3, tile=420):
    relics, cur, room = [], None, None
    for line in open(src):
        p = line.split()
        if p[0] == "relic":
            cur = {"title": line[6:].strip(), "rooms": []}
            relics.append(cur)
        elif p[0] == "run":
            room["runs"].append(tuple(map(float, p[1:])))
        elif p[0] == "seg":
            room["segs"].append(tuple(map(float, p[1:])))
        else:
            room = {"r": (p[0], p[1] == "1", *map(float, p[2:])), "runs": [], "segs": []}
            cur["rooms"].append(room)
    rows = (len(relics) + cols - 1) // cols
    img = Image.new("RGB", (tile * cols, tile * rows), (12, 12, 16))
    d = ImageDraw.Draw(img)
    for i, r in enumerate(relics):
        ox, oy = (i % cols) * tile, (i // cols) * tile
        rooms = [q["r"] for q in r["rooms"]]
        xs = [v for rm in rooms for v in (rm[2], rm[5])]
        zs = [v for rm in rooms for v in (rm[4], rm[7])]
        ys = [rm[3] for rm in rooms]
        x0, z0, ylo, yhi = min(xs), min(zs), min(ys), max(ys)
        s = (tile - 40) / max(max(xs) - x0, max(zs) - z0)
        X = lambda v: ox + 20 + (v - x0) * s
        Z = lambda v: oy + 30 + (v - z0) * s
        for q in sorted(r["rooms"], key=lambda q: q["r"][3]):
            rm = q["r"]
            k = 0.45 + 0.55 * ((rm[3] - ylo) / max(1, yhi - ylo))
            c = tuple(int(v * k) for v in COL.get(rm[0], (150, 150, 150)))
            box = [X(rm[2]), Z(rm[4]), X(rm[5]), Z(rm[7])]
            if q["runs"]:
                d.rectangle(box, fill=tuple(int(v * 0.22) for v in c))
                for a in q["runs"]:
                    d.rectangle([X(a[0]), Z(a[1]), X(a[2]), Z(a[3])], fill=c)
                for g in q["segs"]:
                    d.line([X(g[0]), Z(g[1]), X(g[2]), Z(g[3])], fill=(235, 235, 255), width=1)
                if rm[1]:
                    d.rectangle(box, outline=(160, 160, 160))
            else:
                d.rectangle(box, fill=c, outline=(255, 255, 255) if rm[1] else None)
        d.text((ox + 8, oy + 6), r["title"], fill=(230, 230, 230))
    img.save(dst)

if __name__ == "__main__":
    main(sys.argv[1], sys.argv[2], *(int(a) for a in sys.argv[3:5]))
