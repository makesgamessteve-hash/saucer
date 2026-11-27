#!/usr/bin/env python3
# SPDX-License-Identifier: MIT
# relic-room-shapes: pairwise layout distances of the relics dumped by tools/relicunique/relicunique_spec.lua, the
# same metric as sim/relicsig.lua (1 - IoU of the top-down footprints, minimised over the square's eight turns and
# mirrors about the centre pixel). Prints, per species: relics, min / 1st percentile / median distance, closest pair.
# Usage: relicunique.py sigs1.txt [sigs2.txt ...]
import sys
import numpy as np

def perms(N):
    h = N // 2
    j, i = np.divmod(np.arange(N * N), N)
    out = []
    for t in range(8):
        x, y = i - h, j - h
        if t >= 4:
            x = -x
        q = t % 4
        if q == 1:
            x, y = -y, x
        elif q == 2:
            x, y = -x, -y
        elif q == 3:
            x, y = y, -x
        x, y = x + h, y + h
        ok = (x >= 0) & (y >= 0) & (x < N) & (y < N)
        out.append((ok, np.where(ok, y * N + x, 0)))
    return out

def load(path):
    head, seeds, rows = None, [], []
    for line in open(path):
        p = line.split()
        if p[0] == "#":
            continue
        if p[0] == "species":
            head = (p[1], int(p[3]), int(p[5]))
        else:
            seeds.append(int(p[1]))
            rows.append([int(v) for v in p[2:]])
    name, N, _ = head
    A = np.zeros((len(rows), N * N), dtype=np.float32)
    for r, idx in enumerate(rows):
        A[r, idx] = 1
    return name, N, seeds, A

def distances(A, N):
    n = A.shape[0]
    cnt = A.sum(1)
    best = np.ones((n, n), dtype=np.float64)
    for ok, m in perms(N):
        # B_t[k] = A[m[k]] where the pixel k of b maps to m[k] of a (relicsig: inter over b's set of a[m])
        Bt = np.zeros_like(A)
        Bt[:, ok] = A[:, m[ok]]
        inter = A @ Bt.T             # inter[a, b] = |a ∩ sym_t(b)|
        # sym_t drops pixels mapped outside: relicsig still counts b's full n in the union
        d = 1 - inter / (cnt[:, None] + cnt[None, :] - inter)
        best = np.minimum(best, d)
    np.fill_diagonal(best, 1)
    return best

def main(paths):
    print("species    relics  min     p1      median  closest")
    for path in paths:
        name, N, seeds, A = load(path)
        D = distances(A, N)
        iu = np.triu_indices(len(seeds), 1)
        v = D[iu]
        k = int(np.argmin(v))
        print("%-10s %6d  %.3f   %.3f   %.3f   %d,%d" % (name, len(seeds), v.min(), np.percentile(v, 1), np.median(v),
                                                      seeds[iu[0][k]], seeds[iu[1][k]]))

if __name__ == "__main__":
    main(sys.argv[1:])
