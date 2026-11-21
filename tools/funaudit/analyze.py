#!/usr/bin/env python3
# SPDX-License-Identifier: MIT
"""Fun-audit analyzer (game-fun-evaluator skill, sections 4 and 7).
usage: analyze.py RUNDIR [--json out.json] [--frame-ms P50,P95,MAX,PRESENT] [--boot-s X]
Reads PERSONA_sSEED.log files written by tools/funaudit/run.sh."""
import glob, json, math, os, re, statistics as st, sys

TICK_MS = 1000 / 60
# ---- metric mapping constants (stated in the report) ----
LOOT_TARGET = 600      # c banked in a 20-min session = first upgrade tier (relay 180 + racks 250) + 150 c reserve
STORY_TARGET = 2       # first two clues of the run story
ECHO_TARGET = 1        # first Echo decoded (the mystery's first meso-goal)
TOOLS = ["tractor", "scan", "jam", "decoy", "shroud", "spike", "grapple", "fold", "land", "home", "map", "boost"]
FOLD = {"shrink", "grow", "size1", "size2", "size3"}
# feedback channels per event, from the code audit (anim, particles, camera/hitstop, audio, UI pop)
CHANNELS = {
    "pickup": (["anim:beam-shrink", "audio", "ui:msg"], "core"),
    "tractor": (["anim:beam", "audio", "ui:target"], "core"),
    "bank": (["audio", "ui:msg"], "core"),
    "hit": (["audio", "ui:bar"], "impact"),
    "alert": (["anim:sentry-light", "audio", "ui:msg"], "impact"),
    "locked": (["anim:sentry-light", "audio", "ui:alert-banner"], "impact"),
    "denied": (["audio", "ui:msg"], "impact"),
    "jam": (["anim:pulse", "audio", "ui:msg"], "core"),
    "scan": (["anim:cones", "audio", "ui:marks"], "core"),
    "grow": (["anim:morph", "audio", "ui:ladder"], "core"),
    "shrink": (["anim:morph", "audio", "ui:ladder"], "core"),
    "echo": (["audio", "ui:msg"], "impact"),
    "door": (["anim:door", "audio"], "core"),
    "click": (["audio", "ui:sel"], "core"),
}

def clamp(x, a=0.0, b=1.0): return max(a, min(b, x))
def band(x, lo, hi, lo0, hi0):
    """1 inside [lo,hi], linear to 0 at lo0 (below) / hi0 (above)."""
    if lo <= x <= hi: return 1.0
    if x < lo: return clamp((x - lo0) / (lo - lo0)) if lo != lo0 else 0.0
    return clamp((hi0 - x) / (hi0 - hi)) if hi0 != hi else 0.0

def parse(path):
    ep = {"S": [], "I": [], "E": [], "V": None, "end": None}
    for line in open(path, errors="replace"):
        line = line.replace("[info] ", "").strip()
        if line.startswith("FUNS "):
            f = line.split()
            ep["S"].append(dict(t=int(f[1]), mode=f[2], site=int(f[3]), hold=int(f[4]), hot=int(f[5]), banked=int(f[6]),
                                credits=int(f[7]), hull=float(f[8]), shield=float(f[9]), suit=float(f[10]), o2=float(f[11]),
                                threat=float(f[12]), nearest=float(f[13]), inputs=int(f[14]), story=int(f[15]),
                                echoes=int(f[16]), bolts=int(f[17]), size=int(f[18])))
        elif line.startswith("FUNI "):
            f = line.split()
            ep["I"].append((int(f[1]), f[2], f[3], int(f[4]), int(f[5])))
        elif line.startswith("FUNE "):
            f = line.split(None, 3)
            ep["E"].append((int(f[1]), f[2], f[3] if len(f) > 3 else ""))
        elif line.startswith("FUNV "):
            f = line.split(); ep["V"] = (int(f[2]), int(f[3]))
        elif line.startswith("FUNEND "):
            f = line.split(); ep["end"] = dict(t=int(f[1]), banked=int(f[3]), credits=int(f[5]))
    return ep

def episode_metrics(ep):
    S = ep["S"]
    if not S: return None
    last = S[-1]
    E = ep["E"]
    pickups = sum(1 for e in E if e[1] == "fx:pickup")
    lost = sum(1 for e in E if e[1] == "stolen")
    for e in E:
        m = re.match(r"(\d+)_hot_items?_stayed_behind", e[2])
        if m: lost += int(m.group(1))
    banked = (ep["end"] or {}).get("banked", last["banked"])
    story = max(s["story"] for s in S); echoes = max(s["echoes"] for s in S)
    integ = (1 - lost / pickups) if pickups else 0.0
    W = (clamp(banked / LOOT_TARGET) + clamp(story / STORY_TARGET) + clamp(echoes / ECHO_TARGET) + clamp(integ)) / 4
    minutes = last["t"] / 3600
    in_site = sum(1 for s in S if s["site"] > 0) / 60
    nm = [e for e in E if e[1] in ("near_bolt", "slip_alert", "escape_latch", "escape_clamp")]
    # tension index, 1 Hz
    T = []
    for s in S:
        threat = clamp((s["threat"] + 0.5 * s["bolts"]) / 2)
        rate = clamp(s["inputs"] / 6)
        o2 = (1 - s["o2"] / 100) if s["o2"] >= 0 else 0
        health = max(1 - s["hull"] / 100, 0.5 * (1 - s["shield"] / 100), o2, s["hot"] / 12)
        T.append(0.5 * threat + 0.2 * rate + 0.3 * health)
    mu = st.mean(T); sd = st.pstdev(T)
    longest_hot, run = 0, 0
    for x in T:
        run = run + 1 if x > 0.9 else 0
        longest_hot = max(longest_hot, run)
    # reward cadence
    micro_k = ("fx:pickup", "fx:bank", "fx:echo", "fx:tractor", "fx:scan", "bank", "fx:click", "fx:door")
    micro = sorted(e[0] for e in E if e[1] in micro_k)
    meso = sorted(set([e[0] for e in E if e[1] in ("bank",) or "Got_" in e[2] or "STORY" in e[2] or "Echo_" in e[2]
                       or "Decoded" in e[2] or "Upgrade" in e[2] or "Sold" in e[2]]))
    gaps = lambda xs: [(b - a) / 60 for a, b in zip(xs, xs[1:]) if b > a]
    first_pick = next((e[0] for e in E if e[1] == "fx:pickup"), None)
    first_bank = next((e[0] for e in E if e[1] == "bank"), None)
    retreat_ticks = [e[0] for e in E if e[1] == "retreat"]
    # time back into a site after a retreat (re-engage)
    reeng = []
    for rt in retreat_ticks:
        nxt = next((s["t"] for s in S if s["t"] > rt + 60 and s["site"] > 0), None)
        if nxt: reeng.append((nxt - rt) / 60)
    # tools used (button onsets), excluding locomotion/use/menu
    use = {}
    for (t, a, k, acc, lat) in ep["I"]:
        if k != "button": continue
        a2 = "fold" if a in FOLD else ("home" if a in ("home", "assist") else a)
        if a2 in TOOLS: use[a2] = use.get(a2, 0) + 1
    # activity share (time per mode) for an activity entropy
    act = {}
    for s in S:
        m = s["mode"].split("+")[0]
        key = ("site-" if s["site"] > 0 else "") + m + ("-seat" if s["size"] == 2 else "")
        act[key] = act.get(key, 0) + 1
    fx = {}
    for e in E:
        if e[1].startswith("fx:"): fx[e[1][3:]] = fx.get(e[1][3:], 0) + 1
    return dict(W=W, banked=banked, story=story, echoes=echoes, pickups=pickups, lost=lost, integ=integ, minutes=minutes,
                in_site_min=in_site, near=len(nm), near_kinds={k: sum(1 for e in nm if e[1] == k) for k in set(e[1] for e in nm)},
                T_mu=mu, T_cv=(sd / mu if mu > 0 else 0), T_long=longest_hot, micro_gaps=gaps(micro), meso_gaps=gaps(meso),
                first_pick=first_pick, first_bank=first_bank, retreats=len(retreat_ticks), reengage=reeng,
                use=use, act=act, fx=fx, inputs=ep["I"],
                loot_per_min=banked / minutes if minutes else 0, sector_value=(ep["V"] or (0, 0))[0])

def entropy(counts):
    tot = sum(counts.values()); K = len(TOOLS)
    if tot == 0: return 0.0, 1.0
    ps = [c / tot for c in counts.values() if c > 0]
    H = -sum(p * math.log(p) for p in ps) / math.log(K)
    return H, max(ps)

def med(xs): return st.median(xs) if xs else float("nan")
def pct(xs, q):
    if not xs: return float("nan")
    xs = sorted(xs); i = min(len(xs) - 1, int(q * (len(xs) - 1) + 0.5)); return xs[i]

def main():
    d = sys.argv[1]
    args = sys.argv[2:]
    frame = None; boot_s = None; jout = None
    for i, a in enumerate(args):
        if a == "--frame-ms": frame = [float(x) for x in args[i + 1].split(",")]
        if a == "--boot-s": boot_s = float(args[i + 1])
        if a == "--json": jout = args[i + 1]
    per = {}
    for f in sorted(glob.glob(os.path.join(d, "*_s*.log"))):
        name = os.path.basename(f)[:-4]
        persona, seed = name.rsplit("_s", 1)
        m = episode_metrics(parse(f))
        if m: per.setdefault(persona, []).append(m)
    R = {"n": {k: len(v) for k, v in per.items()}}
    Wm = {k: st.mean(x["W"] for x in v) for k, v in per.items()}
    Ws = {k: st.pstdev([x["W"] for x in v]) for k, v in per.items()}
    R["W"] = Wm; R["W_sd"] = Ws
    R["banked_mean"] = {k: st.mean(x["banked"] for x in v) for k, v in per.items()}
    R["loot_per_min"] = {k: st.mean(x["loot_per_min"] for x in v) for k, v in per.items()}
    R["story_mean"] = {k: st.mean(x["story"] for x in v) for k, v in per.items()}
    R["echo_mean"] = {k: st.mean(x["echoes"] for x in v) for k, v in per.items()}
    R["lost_mean"] = {k: st.mean(x["lost"] for x in v) for k, v in per.items()}
    R["pickups_mean"] = {k: st.mean(x["pickups"] for x in v) for k, v in per.items()}
    R["retreats_mean"] = {k: st.mean(x["retreats"] for x in v) for k, v in per.items()}
    R["zero_bank_eps"] = {k: sum(1 for x in v if x["banked"] == 0) for k, v in per.items()}
    # ---------------- feel ----------------
    hum = per.get("human", []); opt = per.get("opt", [])
    def inputs_of(eps):
        out = []
        for e in eps: out += e["inputs"]
        return out
    hi = inputs_of(hum)
    btn = [x for x in hi if x[2] == "button"]; ax = [x for x in hi if x[2] == "axis"]
    acc = [x for x in hi if x[3] == 1]
    lat_ticks = [x[4] for x in acc]
    present_ms = frame[3] if frame else 0.0
    lvis = (med(lat_ticks) - 1) * TICK_MS + TICK_MS + present_ms if lat_ticks else float("nan")
    lvis95 = (pct(lat_ticks, 0.95) - 1) * TICK_MS + TICK_MS + present_ms if lat_ticks else float("nan")
    drop = lambda xs: (sum(1 for x in xs if x[3] == 0 or x[4] > 6) / len(xs)) if xs else 0
    R["latency_ms_p50"] = lvis; R["latency_ms_p95"] = lvis95
    R["drop_all"] = drop(hi); R["drop_buttons"] = drop(btn); R["drop_axes"] = drop(ax)
    dropped_by = {}
    for x in btn:
        if x[3] == 0 or x[4] > 6: dropped_by[x[1]] = dropped_by.get(x[1], 0) + 1
    tot_by = {}
    for x in btn: tot_by[x[1]] = tot_by.get(x[1], 0) + 1
    R["drop_by_button"] = {k: f"{dropped_by.get(k,0)}/{tot_by[k]}" for k in sorted(tot_by, key=lambda k: -tot_by[k])}
    # rand persona drop rate too
    ri = inputs_of(per.get("rand", []))
    R["drop_rand_buttons"] = drop([x for x in ri if x[2] == "button"])
    # feedback channels weighted by observed event frequency (human + opt)
    fxc = {}
    for e in hum + opt:
        for k, c in e["fx"].items(): fxc[k] = fxc.get(k, 0) + c
    core_n = core_w = imp_n = imp_w = 0
    for k, c in fxc.items():
        if k not in CHANNELS: continue
        ch, cls = CHANNELS[k]
        if cls == "core": core_n += c; core_w += c * len(ch)
        else: imp_n += c; imp_w += c * len(ch)
    F_core = core_w / core_n if core_n else 0; F_imp = imp_w / imp_n if imp_n else 0
    R["fx_counts"] = fxc; R["F_core"] = F_core; R["F_impact"] = F_imp
    motion = 0.75  # flight: exponential approach + bank easing (sim/flight.lua); walking: boxcar (sim/avatar.lua)
    s_lat = band(lvis, 0, 33.4, 0, 67)
    s_drop = band(R["drop_buttons"], 0, 0.05, 0, 0.20)
    s_F = (clamp(F_core / 2.5) + clamp(F_imp / 3.5)) / 2
    M_feel = (s_lat + s_drop + motion + s_F) / 4
    R["feel_sub"] = dict(lat=s_lat, drop=s_drop, motion=motion, F=s_F)
    # ---------------- flow ----------------
    wr, wh, wo = Wm.get("rand", 0), Wm.get("human", 0), Wm.get("opt", 0)
    s_gap = clamp((wo - wr) / 0.55)
    s_rand = band(wr, 0, 0.35, 0, 0.70)
    s_opt = band(wo, 0.70, 1.0, 0.0, 1.0)
    s_hum = band(wh, 0.40, 0.75, 0.0, 1.0)
    s_sd = band(Ws.get("human", 0), 0.10, 0.25, 0.0, 0.45)
    M_flow = (s_gap + s_rand + s_opt + s_hum + s_sd) / 5
    R["flow_sub"] = dict(gap=s_gap, rand=s_rand, opt=s_opt, human=s_hum, sd=s_sd)
    # ---------------- choice ----------------
    def pooled_use(eps):
        u = {}
        for e in eps:
            for k, c in e["use"].items(): u[k] = u.get(k, 0) + c
        return u
    uh, uo = pooled_use(hum), pooled_use(opt)
    Hh, mh = entropy(uh); Ho, mo = entropy(uo)
    act = {}
    for e in hum:
        for k, c in e["act"].items(): act[k] = act.get(k, 0) + c
    tot = sum(act.values()); ps = [c / tot for c in act.values()] if tot else []
    H_act = -sum(p * math.log(p) for p in ps) / math.log(len(ps)) if len(ps) > 1 else 0
    spam_ratio = Wm.get("spam", 0) / wh if wh else 0
    beam_ratio = Wm.get("beamonly", 0) / wh if wh else 0
    H = (Hh + Ho) / 2; mp = max(mh, mo)
    s_H = clamp(H / 0.70); s_mp = band(mp, 0, 0.65, 0, 1.0)
    s_spam = 1.0 if max(spam_ratio, beam_ratio) < 0.80 else clamp(1 - (max(spam_ratio, beam_ratio) - 0.80) / 0.40)
    M_choice = (s_H + s_mp + s_spam) / 3
    R.update(H_human=Hh, H_opt=Ho, maxp_human=mh, maxp_opt=mo, use_human=uh, use_opt=uo, H_activity=H_act,
             activity_share={k: round(c / tot, 3) for k, c in sorted(act.items(), key=lambda kv: -kv[1])} if tot else {},
             spam_ratio=spam_ratio, beamonly_ratio=beam_ratio, choice_sub=dict(H=s_H, maxp=s_mp, spam=s_spam))
    # ---------------- pace ----------------
    cvs = [e["T_cv"] for e in hum]; cv = st.mean(cvs) if cvs else 0
    near = sum(e["near"] for e in hum); site_min = sum(e["in_site_min"] for e in hum)
    nmr = near / site_min if site_min else 0
    nk = {}
    for e in hum:
        for k, c in e["near_kinds"].items(): nk[k] = nk.get(k, 0) + c
    s_cv = band(cv, 0.25, 0.85, 0.05, 1.2); s_nm = band(nmr, 2, 12, 0, 24)
    s_exh = 1.0 if max((e["T_long"] for e in hum), default=0) <= 20 else 0.5
    M_pace = (s_cv + s_nm + s_exh) / 3
    R.update(T_cv=cv, T_mu=st.mean(e["T_mu"] for e in hum) if hum else 0, near_per_min=nmr, near_kinds=nk,
             site_minutes=site_min, T_longest_hot=max((e["T_long"] for e in hum), default=0),
             pace_sub=dict(cv=s_cv, near=s_nm, exhaust=s_exh))
    # ---------------- fairness (code audit numbers passed in report; computed here) ----------------
    fair = fairness()
    R["fair"] = fair
    M_fair = fair["M"]
    # ---------------- loop ----------------
    ttfa = (boot_s or 0) + st.mean([next((x[0] for x in e["inputs"] if x[2] == "axis" and x[3] == 1), 0) for e in opt]) / 60 if opt else float("nan")
    micro = [g for e in hum for g in e["micro_gaps"]]; meso = [g for e in hum for g in e["meso_gaps"]]
    fp = [e["first_pick"] / 60 for e in hum if e["first_pick"]]; fb = [e["first_bank"] / 60 for e in hum if e["first_bank"]]
    reeng = [g for e in hum + opt for g in e["reengage"]]
    retry = 0.33  # Fold Retreat: control is back the same tick; O2-out teleport: ~20 ticks (measured in shots run)
    s_ttfa = band(ttfa, 0, 3.0, 0, 10)
    s_retry = band(retry, 0, 1.0, 0, 5)
    s_micro = band(med(micro), 1, 5, 0, 30)
    s_meso = band(med(meso), 30, 90, 0, 600)
    M_loop = (s_ttfa + s_retry + s_micro + s_meso) / 4
    R.update(ttfa_s=ttfa, retry_s=retry, micro_gap_med=med(micro), micro_gap_p90=pct(micro, 0.9), meso_gap_med=med(meso),
             meso_gap_p90=pct(meso, 0.9), first_pickup_s_med=med(fp), first_bank_s_med=med(fb),
             first_bank_reached=f"{len(fb)}/{len(hum)}", reengage_s_med=med(reeng), loop_sub=dict(ttfa=s_ttfa, retry=s_retry, micro=s_micro, meso=s_meso))
    S = 100 * (M_feel ** 0.25 * M_flow ** 0.25 * M_fair ** 0.20) * (0.40 + 0.25 * M_choice + 0.20 * M_pace + 0.15 * M_loop)
    R["M"] = dict(feel=M_feel, flow=M_flow, choice=M_choice, pace=M_pace, fair=M_fair, loop=M_loop)
    R["S_fun"] = S
    R["frame"] = frame
    print(block(R))
    if jout:
        json.dump(R, open(jout, "w"), indent=1, default=str)

def fairness():
    # player collider vs drawn silhouette (side view), sim/sentry.lua step_bolts + saucer/configs.lua + meshes/saucer.lua
    def lathe_area(pts):
        a = 0
        for (r0, y0), (r1, y1) in zip(pts, pts[1:]): a += abs(y1 - y0) * (r0 + r1)  # 2r * dy, trapezoid
        return a
    villa_hull = [(2.7, -5.6), (7.5, -4.9), (11.6, -2.6), (13.0, -0.9), (12.9, -0.3), (12.0, 0.3), (10.8, 0.62)]
    # area enclosed by the profile: integrate width over y, the hull is monotone in y
    va = lathe_area(villa_hull) + 2 * 2.8 * 0.15
    dome_r, dome_h = 10.6, 5.6  # saucer/interior.lua: half-ellipse on the deck
    va += math.pi * dome_r * dome_h / 2
    hs = float(os.environ.get("FUN_HURT_SCALE", "0"))  # proposal D: ellipsoid of hs x the hull
    villa_collider = 26.0 * 12.0 if not hs else math.pi / 4 * 26.0 * hs * 12.0 * hs
    seat = [(0.25, -0.7), (0.72, -0.56), (0.9, -0.28), (0.86, -0.12), (0.62, -0.02)]
    sa = lathe_area(seat) + 0.44 * 0.06 + 0.56 * 0.57 + 0.8 * 0.14
    seat_collider = 1.8 * 1.4 if not hs else math.pi / 4 * 1.8 * hs * 1.4 * hs
    foot_collider, foot_visual = 0.7 * 1.8, 0.5 * 1.8 + 0.25  # body + fishbowl helmet
    a_villa, a_seat, a_foot = villa_collider / va, seat_collider / sa, foot_collider / foot_visual
    tele = {"watcher_alert_to_first_bolt_ms": 750, "snatcher_latch_to_siphon_ms": 3000, "snatcher_alert_ms": 750,
            "clamp_ms": 750, "o2_low_warn_to_teleport_s": "warn 40%/20% then assist", "bolt_travel_ms_at_30m": 30 / 18 * 1000}
    s_hurt = (band(a_villa, 0.5, 0.85, 0.2, 1.0) + band(a_seat, 0.5, 0.85, 0.2, 1.0) + band(a_foot, 0.5, 0.85, 0.2, 1.0)) / 3
    s_tel = 1.0  # every telegraph >= 750 ms (>= 300 ms target)
    contrast = CONTRAST
    s_con = band(contrast["min_ratio"], 3.5, 100, 1.0, 100)
    s_shake = 1.0  # no screen shake exists (view/xr.lua: 'the camera never shakes')
    M = (s_hurt + s_tel + s_con + s_shake) / 4
    return dict(alpha_villa=a_villa, alpha_seat=a_seat, alpha_foot=a_foot, villa_visual_m2=va, seat_visual_m2=sa,
                telegraph=tele, contrast=contrast, sub=dict(hurt=s_hurt, telegraph=s_tel, contrast=s_con, shake=s_shake), M=M)

CONTRAST = {"min_ratio": 0.0}
def block(R):
    M = R["M"]; W = R["W"]; f = R["fair"]
    return f"""=== GAME FUN AUDIT REPORT ===
Runs Executed: {R['n'].get('rand',0)}/{R['n'].get('human',0)}/{R['n'].get('opt',0)} per persona (Novice, Human-Proxy @ 200ms, Optimal) + SpamBot {R['n'].get('spam',0)} + BeamOnly {R['n'].get('beamonly',0)}

Pillar Scores (0.00 - 1.00):
- Kinesthetics & Feel (M_feel):   [{M['feel']:.2f}] | Latency: [{R['latency_ms_p50']:.0f}]ms, DropRate: [{100*R['drop_buttons']:.1f}]%, Channels: [{R['F_core']:.1f}]
- Flow & Skill Gap (M_flow):      [{M['flow']:.2f}] | Win/Surv: Rand=[{100*W.get('rand',0):.0f}]%, Human=[{100*W.get('human',0):.0f}]%, Opt=[{100*W.get('opt',0):.0f}]%
- Strategic Entropy (M_choice):   [{M['choice']:.2f}] | H_norm=[{(R['H_human']+R['H_opt'])/2:.2f}], SpamBot Ratio=[{max(R['spam_ratio'], R['beamonly_ratio']):.2f}]
- Pacing & Tension (M_pace):      [{M['pace']:.2f}] | Tension CV=[{R['T_cv']:.2f}], Near-Misses=[{R['near_per_min']:.1f}]/min
- Fairness & Clarity (M_fair):    [{M['fair']:.2f}] | Hurtbox Ratio=[{f['alpha_seat']:.2f}], Telegraph=[750]ms
- Loop Friction (M_loop):         [{M['loop']:.2f}] | TTFA=[{R['ttfa_s']:.1f}]s, Retry=[{R['retry_s']:.1f}]s

COMPOSITE FUN SCORE: [{R['S_fun']:.1f}] / 100"""

if __name__ == "__main__":
    if os.environ.get("FUN_CONTRAST"): CONTRAST["min_ratio"] = float(os.environ["FUN_CONTRAST"])
    main()
