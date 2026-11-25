#!/usr/bin/env python3
# SPDX-License-Identifier: MIT
# add-material-system: compare two PNG screenshots (8-bit RGB or RGBA, non-interlaced; stdlib only).
# Usage: golden_compare.py GOLDEN SHOT [MEAN_TOL] [BAD_TOL]
#        golden_compare.py --differ MIN_MEAN A B   (passes when the images differ by at least MIN_MEAN: the material
#        look must stay clearly visible, full against off)
#        golden_compare.py --brighter ON OFF   (fix-glow: ON is a scene with its glow sprites, OFF the same without;
#        passes when at most 0.2% of the pixels are darker in ON by more than 16 of luma, and at least 0.2% are
#        brighter: the sprites add light and never darken)
#   passes when the mean absolute channel difference is <= MEAN_TOL (default 2.0 of 255) and the share of pixels
#   that differ by more than 24 in any channel is <= BAD_TOL (default 0.02); prints the numbers either way.
import struct, sys, zlib

def load(path):
    with open(path, "rb") as f:
        data = f.read()
    if data[:8] != b"\x89PNG\r\n\x1a\n":
        raise SystemExit(path + ": not a PNG")
    pos, idat, w = 8, b"", 0
    while pos < len(data):
        n, kind = struct.unpack(">I4s", data[pos:pos + 8])
        body = data[pos + 8:pos + 8 + n]
        if kind == b"IHDR":
            w, h, depth, ctype, _, _, inter = struct.unpack(">IIBBBBB", body)
            if depth != 8 or ctype not in (2, 6) or inter:
                raise SystemExit(path + ": only 8-bit RGB/RGBA, non-interlaced")
            bpp = 3 if ctype == 2 else 4
        elif kind == b"IDAT":
            idat += body
        pos += 12 + n
    raw = zlib.decompress(idat)
    stride = w * bpp
    out, prev = bytearray(), bytearray(stride)
    for y in range(h):
        f = raw[y * (stride + 1)]
        line = bytearray(raw[y * (stride + 1) + 1:(y + 1) * (stride + 1)])
        for x in range(stride):
            a = line[x - bpp] if x >= bpp else 0
            b = prev[x]
            c = prev[x - bpp] if x >= bpp else 0
            if f == 1: line[x] = (line[x] + a) & 255
            elif f == 2: line[x] = (line[x] + b) & 255
            elif f == 3: line[x] = (line[x] + (a + b) // 2) & 255
            elif f == 4:
                p = a + b - c
                pa, pb, pc = abs(p - a), abs(p - b), abs(p - c)
                line[x] = (line[x] + (a if pa <= pb and pa <= pc else b if pb <= pc else c)) & 255
        out += line
        prev = line
    return w, h, bpp, out

def mean_diff(a, b):
    w1, h1, b1, p1 = load(a)
    w2, h2, b2, p2 = load(b)
    if (w1, h1) != (w2, h2):
        return None
    total = 0
    for i in range(w1 * h1):
        for k in range(3):
            total += abs(p1[i * b1 + k] - p2[i * b2 + k])
    return total / (w1 * h1 * 3)

def luma_shift(a, b, tol=16):
    w1, h1, b1, p1 = load(a)
    w2, h2, b2, p2 = load(b)
    if (w1, h1) != (w2, h2):
        return None
    darker = brighter = 0
    for i in range(w1 * h1):
        la = 0.299 * p1[i * b1] + 0.587 * p1[i * b1 + 1] + 0.114 * p1[i * b1 + 2]
        lb = 0.299 * p2[i * b2] + 0.587 * p2[i * b2 + 1] + 0.114 * p2[i * b2 + 2]
        if la < lb - tol: darker += 1
        elif la > lb + tol: brighter += 1
    n = float(w1 * h1)
    return darker / n, brighter / n

def main():
    if len(sys.argv) == 4 and sys.argv[1] == "--brighter":
        r = luma_shift(sys.argv[2], sys.argv[3])
        ok = r is not None and r[0] <= 0.002 and r[1] >= 0.002
        print("%s vs %s: %s -> %s" % (sys.argv[2], sys.argv[3], "size differs" if r is None else
              "darker %.4f (at most 0.0020), brighter %.4f (at least 0.0020)" % r, "ok" if ok else "FAIL"))
        return 0 if ok else 1
    if len(sys.argv) == 5 and sys.argv[1] == "--differ":
        need = float(sys.argv[2])
        m = mean_diff(sys.argv[3], sys.argv[4])
        ok = m is not None and m >= need
        print("%s vs %s: mean difference %s (at least %.2f) -> %s" % (sys.argv[3], sys.argv[4],
              "size differs" if m is None else "%.3f" % m, need, "ok" if ok else "FAIL"))
        return 0 if ok else 1
    if len(sys.argv) < 3:
        raise SystemExit(__doc__ or "usage: golden_compare.py GOLDEN SHOT [MEAN_TOL] [BAD_TOL]")
    mean_tol = float(sys.argv[3]) if len(sys.argv) > 3 else 2.0
    bad_tol = float(sys.argv[4]) if len(sys.argv) > 4 else 0.02
    w1, h1, b1, p1 = load(sys.argv[1])
    w2, h2, b2, p2 = load(sys.argv[2])
    if (w1, h1) != (w2, h2):
        print("size differs: %dx%d vs %dx%d" % (w1, h1, w2, h2))
        return 1
    total, bad = 0, 0
    for i in range(w1 * h1):
        worst = 0
        for k in range(3):
            d = abs(p1[i * b1 + k] - p2[i * b2 + k])
            total += d
            worst = max(worst, d)
        if worst > 24:
            bad += 1
    mean = total / (w1 * h1 * 3)
    share = bad / (w1 * h1)
    ok = mean <= mean_tol and share <= bad_tol
    print("%s: mean %.3f (tol %.2f), differing pixels %.4f (tol %.3f) -> %s" % (sys.argv[2], mean, mean_tol, share, bad_tol,
          "ok" if ok else "FAIL"))
    return 0 if ok else 1

if __name__ == "__main__":
    sys.exit(main())
