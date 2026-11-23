#!/usr/bin/env python3
# SPDX-License-Identifier: MIT
"""add-strategic-sentries: per-persona sentry metrics for a fun-audit run directory.
usage: sentry_table.py RUNDIR [RUNDIR2 ...]  (prints one table per directory; --json for machine output)
Per persona (means over seeds unless noted): banked value, tow bills, net, Fold Retreats, first threat
(median minutes to the first Alert/Lock/Tag/latch/clamp on the player), near-misses per site-minute
(bolt near-misses + slipped detections + escaped latches/clamps), tool entropy H_norm and max share over
the 12 tools, alerts, locks, Spotter tags, site-alarm raises and power cells pulled."""
import json, os, statistics as st, sys
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import analyze as A
import glob

THREAT = ("alerted", "locked", "tagged", "latched", "clamped")

def per_dir(d):
    per = {}
    for f in sorted(glob.glob(os.path.join(d, "*_s*.log"))):
        name = os.path.basename(f)[:-4]
        persona, seed = name.rsplit("_s", 1)
        ep = A.parse(f)
        m = A.episode_metrics(ep)
        if not m: continue
        E = ep["E"]
        ft = next((e[0] for e in E if e[1] in THREAT), None)
        m["first_threat"] = ft / 3600 if ft is not None else None
        for k in ("alerted", "locked", "tagged", "alarm", "sabotage", "retreat"):
            m["n_" + k] = sum(1 for e in E if e[1] == k)
        per.setdefault(persona, []).append(m)
    out = {}
    for p, v in per.items():
        use = {}
        for x in v:
            for k, c in x["use"].items(): use[k] = use.get(k, 0) + c
        H, mp = A.entropy(use)
        site_min = sum(x["in_site_min"] for x in v)
        fts = [x["first_threat"] for x in v if x["first_threat"] is not None]
        out[p] = dict(
            n=len(v), banked=st.mean(x["banked"] for x in v), bills=st.mean(x["bills"] for x in v),
            net=st.mean(x["net"] for x in v), retreats=st.mean(x["retreats"] for x in v),
            first_threat_med=st.median(fts) if fts else None, no_threat=sum(1 for x in v if x["first_threat"] is None),
            near_per_site_min=(sum(x["near"] for x in v) / site_min) if site_min else 0.0,
            H=H, maxp=mp, tools=dict(sorted(use.items(), key=lambda kv: -kv[1])),
            alerts=st.mean(x["n_alerted"] for x in v), locks=st.mean(x["n_locked"] for x in v),
            tags=st.mean(x["n_tagged"] for x in v), alarms=st.mean(x["n_alarm"] for x in v),
            cells=st.mean(x["n_sabotage"] for x in v), lost=st.mean(x["lost"] for x in v),
            W=st.mean(x["W"] for x in v))
    return out

def main():
    js = "--json" in sys.argv
    dirs = [a for a in sys.argv[1:] if a != "--json"]
    allr = {d: per_dir(d) for d in dirs}
    if js:
        print(json.dumps(allr, indent=1)); return
    for d, R in allr.items():
        print("==", d)
        print("%-9s %3s %8s %6s %8s %6s %7s %9s %6s %5s %6s %6s %5s %5s %5s" % ("persona", "n", "banked", "bills", "net", "retr",
              "1st-thr", "near/smin", "H", "maxp", "alerts", "locks", "tags", "cells", "lost"))
        for p in sorted(R):
            r = R[p]
            ft = "%.1f" % r["first_threat_med"] if r["first_threat_med"] is not None else "never"
            print("%-9s %3d %8.0f %6.0f %8.0f %6.2f %7s %9.2f %6.2f %5.2f %6.1f %6.1f %5.1f %5.2f %5.2f" % (
                p, r["n"], r["banked"], r["bills"], r["net"], r["retreats"], ft, r["near_per_site_min"], r["H"], r["maxp"],
                r["alerts"], r["locks"], r["tags"], r["cells"], r["lost"]))
            print("          tools:", r["tools"])
        h = R.get("human", {}).get("net"); s = R.get("stealth", {}).get("net"); b = R.get("beamonly", {}).get("net")
        if b is not None and h: print("BeamOnly/Human net %.2f" % (b / h))
        if b is not None and s: print("BeamOnly/Stealth net %.2f" % (b / s))

if __name__ == "__main__":
    main()
