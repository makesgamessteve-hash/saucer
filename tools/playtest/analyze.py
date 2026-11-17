#!/usr/bin/env python3
# SPDX-License-Identifier: MIT
"""Summarise playtest telemetry (tools/playtest/run.sh logs).

usage: analyze.py LOG [LOG...]   -> a table per run and per player, plus JSON
(--json) for docs/playtest. 60 ticks = 1 s of game time.
"""
import json, re, statistics, sys

MEANINGFUL = [r"^Got ", r"^Banked ", r"^Sold ", r"^Request filled", r"Fold jump complete", r"^Recovered ",
              r"Echo .* decoded|decoded", r"^Bought ", r"Course clear", r"vault opens", r"^You take the ",
              r"^New civilization", r"^Identified", r"Fold Core upgraded", r"Shelved", r"Pantry: \+", r"ENDING",
              r"Placed ", r"Planted ", r"Harvest", r"caught|catch the thief", r"shutter grinds open", r"grid"]
MEAN_RE = re.compile("|".join(MEANINGFUL))

def parse(path):
    runs = {"path": path, "pte": [], "pts": [], "ptm": [], "time": None, "ticks": None, "ok": None, "errors": []}
    for line in open(path, errors="replace"):
        line = line.rstrip("\n")
        if line.startswith("[info] "):
            line = line[7:]
        if line.startswith("PTE "):
            p = line.split(" ", 4)
            runs["pte"].append((int(p[1]), int(p[2]), p[3], p[4] if len(p) > 4 else ""))
        elif line.startswith("PTS "):
            p = line.split()
            runs["pts"].append(dict(t=int(p[1]), pl=int(p[2]), mode=p[3], site=int(p[4]), credits=int(p[5]),
                                    hold=int(p[6]), hot=int(p[7]), charge=float(p[8]), hull=float(p[9]),
                                    shield=float(p[10]), speed=float(p[11]), size=int(p[12]), sector=int(p[13]),
                                    locked=p[14] == "L", banked=int(p[15]), suit=float(p[16])))
        elif line.startswith("PTM "):
            p = line.split(" ", 3)
            runs["ptm"].append((int(p[1]), int(p[2]), p[3] if len(p) > 3 else ""))
        elif line.startswith("PTTIME"):
            runs["time"] = float(line.split()[1])
        elif line.startswith("ticks ") and "final_hash" in line:
            runs["ticks"] = int(line.split()[1]); runs["ok"] = line.endswith("OK")
        elif line.startswith("net slot"):
            runs["ticks"] = int(line.split()[4]) if runs["ticks"] is None else runs["ticks"]
        elif "[error]" in line or "error:" in line.lower():
            runs["errors"].append(line)
    return runs

def mmss(t):
    if t is None:
        return "-"
    s = t // 60
    return f"{s // 60}:{s % 60:02d}"

def player_summary(r, pl):
    pts = [s for s in r["pts"] if s["pl"] == pl]
    msgs = [(t, m) for t, p, m in r["ptm"] if p == pl]
    pte = [(t, k, d) for t, p, k, d in r["pte"] if p == pl]
    if not pts:
        return None
    end = pts[-1]["t"]
    out = {"player": pl, "ticks": end, "minutes": round(end / 3600, 1)}
    first = lambda pat: next((t for t, m in msgs if re.search(pat, m)), None)
    out["first_loot"] = first(r"^Got (?!Echo)")
    out["first_bank"] = first(r"^Banked ")
    out["first_sale"] = first(r"^Sold |^Request filled")
    out["fold_t2"] = first(r"Fold Core upgraded: tier 2")
    out["first_jump"] = first(r"Fold jump complete")
    out["act1_solved"] = first(r"vault opens")
    out["credits_end"] = pts[-1]["credits"]
    out["banked_end"] = pts[-1]["banked"]
    earned = 0
    for t, m in msgs:
        mm = re.search(r"for (\d+) c|\+(\d+) c", m)
        if mm and (m.startswith("Sold") or m.startswith("Request filled") or "Course clear" in m):
            earned += int(mm.group(1) or mm.group(2))
    out["earned"] = earned
    curve = {}
    for mark in (10, 20, 30, 40):
        s = [x for x in pts if x["t"] <= mark * 3600]
        if s and mark * 3600 <= end + 60:
            curve[mark] = s[-1]["credits"]
    out["credits_curve"] = curve
    out["loot_got"] = sum(1 for t, m in msgs if re.match(r"^Got ", m))
    out["retreats"] = sum(1 for t, m in msgs if "FOLD RETREAT" in m)
    out["watcher_locks"] = sum(1 for t, m in msgs if m.startswith("Watcher LOCKED"))
    out["snatched"] = sum(1 for t, m in msgs if "siphoned" in m)
    out["recovered"] = sum(1 for t, m in msgs if m.startswith("Recovered"))
    out["clamped"] = sum(1 for t, m in msgs if "Clamp" in m and "latch" in m.lower())
    out["lifelines"] = sum(1 for t, m in msgs if "LIFELINE" in m)
    out["lost_hardcore"] = sum(1 for t, m in msgs if "lost for good" in m)
    out["charge_denied"] = sum(1 for t, m in msgs if "Not enough Charge" in m)
    out["denied_grow"] = sum(1 for t, m in msgs if "No room to grow" in m)
    # gaps between meaningful events
    times = sorted(set([t for t, m in msgs if MEAN_RE.search(m)]))
    gaps = [b - a for a, b in zip([0] + times, times + [end])]
    out["meaningful_events"] = len(times)
    out["gap_max"] = max(gaps) if gaps else end
    out["gap_median"] = int(statistics.median(gaps)) if gaps else end
    out["dead_air_2min"] = sum(1 for g in gaps if g >= 7200)
    out["dead_air_total"] = sum(g for g in gaps if g >= 7200)
    # where the time went (samples are once a second)
    buckets = {}
    for s in pts:
        m = s["mode"]
        if m.startswith("helm"):
            if s["site"] == 0:
                k = "travel (open space)" if s["speed"] > 2 else "idle at helm (open space)"
            else:
                k = "flying inside a site" if s["speed"] > 0.6 else "hovering/lining up in a site"
        elif "+console" in m:
            k = "beam console"
        elif m.startswith("walk"):
            k = "menus (on foot)" if "+" in m else "walking the saucer"
        elif m.startswith("foot"):
            k = "on foot (station/excursion)"
        elif m.startswith("wake"):
            k = "title/wake"
        else:
            k = m
        buckets[k] = buckets.get(k, 0) + 1
    tot = sum(buckets.values()) or 1
    out["time_split"] = {k: round(100 * v / tot, 1) for k, v in sorted(buckets.items(), key=lambda kv: -kv[1])}
    kinds = {}
    for t, k, d in pte:
        kinds[k] = kinds.get(k, 0) + 1
    out["bot_events"] = {k: kinds[k] for k in ("stuck", "unstick", "beam_fail", "boterror", "fail", "excursion_fail",
                                               "softlock?", "give_up_site", "dead_end", "charge_wait") if k in kinds}
    out["dives"] = kinds.get("dive_end", 0)
    dv = [d for t, k, d in pte if k == "dive_end"]
    out["dive_ticks"] = [int(re.search(r"ticks (\d+)", d).group(1)) for d in dv]
    gr = [d for t, k, d in pte if k == "grab"]
    n_items = sum(int(re.search(r" n (\d+)", d).group(1)) for d in gr)
    g_ticks = sum(int(re.search(r"ticks (\d+)", d).group(1)) for d in gr)
    out["grab_ticks_per_item"] = round(g_ticks / n_items) if n_items else None
    out["sectors"] = sorted(set(s["sector"] for s in pts))
    out["hull_min"] = min(s["hull"] for s in pts)
    return out

def main():
    as_json = "--json" in sys.argv
    paths = [a for a in sys.argv[1:] if not a.startswith("--")]
    allr = []
    for path in paths:
        r = parse(path)
        res = {"log": path, "ticks": r["ticks"], "ok": r["ok"], "wall_s": r["time"], "errors": r["errors"][:5],
               "players": []}
        if r["time"] and r["ticks"]:
            res["ms_per_tick"] = round(1000 * r["time"] / r["ticks"], 3)
        for pl in sorted(set(s["pl"] for s in r["pts"])):
            ps = player_summary(r, pl)
            if ps:
                res["players"].append(ps)
        res["boterrors"] = [d for t, p, k, d in r["pte"] if k in ("boterror", "hardstop")]
        allr.append(res)
    if as_json:
        print(json.dumps(allr, indent=1))
        return
    for res in allr:
        print(f"== {res['log']}  ticks {res['ticks']} ok {res['ok']} wall {res['wall_s']} s  "
              f"{res.get('ms_per_tick', '-')} ms/tick  errors {len(res['errors'])} boterrors {res['boterrors'][:3]}")
        for p in res["players"]:
            print(f"  P{p['player']} {p['minutes']} min | first loot {mmss(p['first_loot'])} bank {mmss(p['first_bank'])} "
                  f"sale {mmss(p['first_sale'])} T2 {mmss(p['fold_t2'])} jump {mmss(p['first_jump'])} act1 {mmss(p['act1_solved'])}")
            print(f"     credits {p['credits_end']} earned {p['earned']} banked {p['banked_end']} curve {p['credits_curve']} "
                  f"loot {p['loot_got']} dives {p['dives']} sectors {p['sectors']}")
            print(f"     retreats {p['retreats']} watcher locks {p['watcher_locks']} snatched {p['snatched']} recovered "
                  f"{p['recovered']} lifelines {p['lifelines']} hc-lost {p['lost_hardcore']} hull min {p['hull_min']}")
            print(f"     events {p['meaningful_events']} gap median {p['gap_median']/60:.0f}s max {p['gap_max']/60:.0f}s "
                  f"dead-air(>2min) {p['dead_air_2min']} = {p['dead_air_total']/60:.0f}s  grab/item {p['grab_ticks_per_item']} ticks")
            print(f"     time {p['time_split']}")
            print(f"     bot {p['bot_events']}")

if __name__ == "__main__":
    main()
