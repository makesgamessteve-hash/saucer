-- SPDX-License-Identifier: MIT
-- Fun audit (game-fun-evaluator skill): one seeded episode for one persona,
-- with a telemetry bridge that prints JSON-ish "FUN*" lines for analyze.py.
-- tools/funaudit/run.sh prepends CFG = { persona=..., limit=..., seed=... }
-- plus BOT (tools/playtest/bot.lua) and CAREER (tools/playtest/career.lua).
--   rand  : random valid inputs at ~3 Hz, no spatial awareness (skill floor)
--   human : the career autopilot, every input through a 200 ms +-35 ms delay line (12 +-2 ticks)
--   opt   : the career autopilot, zero latency, exact state (skill ceiling)
--   spam  : gets up, then spams the primary button (tractor) only
--   beamonly : career autopilot in the Villa only (no Seat, no Jammer reflex, no mystery): dominant-strategy probe
-- Telemetry lines:
--   FUNI tick action kind accepted latency_ticks  (one per input onset, resolved within 30 ticks)
--   FUNS tick mode site hold hot banked credits hull shield suit o2 threat nearest_m inputs story echoes
--   FUNE tick kind detail  (near_bolt, slip_alert, escape_latch, stolen, retreat, teleport, pickup, bank, clue, fx:<snd>, msg)
local T = saucer.test
local game = require("sim.game")
local vec = require("lib.vec")
local LIMIT = CFG.limit
local PERSONA = CFG.persona
local ORIG_PRESS, ORIG_AXIS = T.press, T.axis

-- deterministic LCG (the sim's own RNG must stay untouched)
local rs = (CFG.seed * 7919 + #PERSONA * 104729) % 2147483647
if rs == 0 then rs = 1 end
local function rnd() rs = (rs * 48271) % 2147483647 return rs / 2147483647 end

local function S() return T.state() end
local function P1() return S().players[1] end
local function out(fmt, ...) print(string.format(fmt, ...)) end

-- ---------------- input bridge: delay line + acceptance tracking ----------------
local pending = {}     -- delayed injections {due, fn}
local watch = {}       -- inputs awaiting a response {t0, action, kind, sig}
local last_axis = {}   -- last injected axis value per action (onsets only)
local inputs_this_sec = 0
local function num(x) return type(x) == "number" and x or 0 end
local function sig_motion(p)
  local s, b = p.ship, p.body or {}
  local sp, sv, bp = s.pos or {}, s.vel or {}, b.pos or {}
  return { num(sp[1]), num(sp[2]), num(sp[3]), num(sv[1]), num(sv[2]), num(sv[3]), num(s.yaw), num(s.pitch),
           num(bp[1]), num(bp[2]), num(bp[3]), num(b.yaw), num(b.pitch), p.panel and num(p.panel.sel) or 0,
           p.eva and num((p.eva.vel or {})[1]) + num((p.eva.vel or {})[3]) or 0 }
end
local function sig_disc(p)
  return table.concat({ tostring(p.mode), p.panel and (p.panel.kind .. ":" .. tostring(p.panel.sel)) or "-",
    tostring(p.ship.size), tostring(p.ship.morph and true or false), tostring(p.tractor and true or false),
    tostring(#p.hold), tostring(p.docked), tostring(p.excursion and true or false), tostring(p.eva and p.eva.jet),
    tostring(p.eva and p.eva.tele), tostring(p.eva and p.eva.helmet), tostring(p.shroud), tostring(p.decoys),
    tostring(p.spike and true or false), tostring(p.grapple and true or false) }, "|")
end
local function last_tick(list) return list and #list > 0 and list[#list].tick or -1 end
local function moved(a, b)
  for i = 1, #a do if math.abs(a[i] - b[i]) > 1e-4 then return true end end
  return false
end
local function track(pl, action, kind)
  if pl ~= 1 then return end
  local p = P1()
  inputs_this_sec = inputs_this_sec + 1
  watch[#watch + 1] = { t0 = S().tick, action = action, kind = kind, m = sig_motion(p), d = sig_disc(p),
                        fx = last_tick(p.fx), msg = last_tick(p.msgs) }
end
local function resolve()
  local p, now = P1(), S().tick
  local keep = {}
  for _, w in ipairs(watch) do
    local resp = false
    if now > w.t0 then
      if w.kind == "axis" then resp = moved(w.m, sig_motion(p)) or sig_disc(p) ~= w.d
      else resp = sig_disc(p) ~= w.d or last_tick(p.fx) > w.fx or last_tick(p.msgs) > w.msg or moved(w.m, sig_motion(p)) end
    end
    if resp then out("FUNI %d %s %s 1 %d", w.t0, w.action, w.kind, now - w.t0)
    elseif now - w.t0 >= 30 then out("FUNI %d %s %s 0 -1", w.t0, w.action, w.kind)
    else keep[#keep + 1] = w end
  end
  watch = keep
end

local DELAYED = PERSONA == "human"
local function delay_ticks() return 12 + math.floor(rnd() * 5) - 2 end -- 200 ms +- 33 ms
T.press = function(pl, a, ticks, nowait)
  local fire = function() track(pl, a, "button") ORIG_PRESS(pl, a, ticks or 1, true) end
  if DELAYED then pending[#pending + 1] = { due = S().tick + delay_ticks(), fn = fire }
  else fire() end
  if not nowait then return T.wait(ticks or 1) end
end
T.axis = function(pl, a, v, ticks, nowait)
  local fire = function()
    local key = pl .. a
    local q = math.floor(v * 20 + 0.5)
    if q ~= last_axis[key] then
      last_axis[key] = q
      if v ~= 0 then track(pl, a, "axis") end
    end
    ORIG_AXIS(pl, a, v, ticks or 1, true)
  end
  if DELAYED then pending[#pending + 1] = { due = S().tick + delay_ticks(), fn = fire }
  else fire() end
  if not nowait then return T.wait(ticks or 1) end
end
local function flush()
  local now, keep = S().tick, {}
  -- keep order: earlier-queued inputs first (a human's jitter does not reorder a held stick)
  for _, e in ipairs(pending) do
    if e.due <= now then e.fn() else keep[#keep + 1] = e end
  end
  pending = keep
end

-- ---------------- the objective: loot value available in sector 1 ----------------
local function sector_value()
  local loot = require("sim.loot")
  local st, v, n = S(), 0, 0
  for i = 1, #st.sector.sites do
    local r = game.ruin(i)
    if r and r.slots then
      for _, s in ipairs(r.slots) do
        local it = loot.roll(loot.instance_seed(s.seed, 1), s.max_size, s.tier)
        v, n = v + (it.value or 0), n + 1
      end
    end
  end
  return v, n
end

-- ---------------- telemetry coroutine ----------------
local function telemetry()
  local seen_msg, seen_fx = -1, -1
  local bolts = {}       -- key -> {min = normalized distance, hit = bool}
  local sstate = {}      -- "site:k" -> last st targeting player
  local hits0 = 0
  local story = require("sim.story")
  local sentry = require("sim.sentry")
  local configs = require("sim.config")
  local v, n = sector_value()
  out("FUNV %d %d %d", S().tick, v, n)
  while S().tick < LIMIT do
    flush()
    resolve()
    local st, p = S(), P1()
    local now = st.tick
    -- messages and fx (feedback channels per event)
    for _, m in ipairs(p.msgs or {}) do
      if m.tick > seen_msg then
        local tx = m.text
        local kind = "msg"
        if tx:find("siphoned", 1, true) or tx:find("tore", 1, true) then kind = "stolen"
        elseif tx:find("FOLD RETREAT", 1, true) then kind = "retreat"
        elseif tx:find("OUT OF OXYGEN", 1, true) or tx:find("SUIT FAILURE", 1, true) then kind = "teleport_forced"
        elseif tx:find("^Banked") then kind = "bank"
        elseif tx:find("LOCKED", 1, true) then kind = "locked"
        elseif tx:find("stirs", 1, true) or tx:find("wakes up", 1, true) then kind = "alerted"
        elseif tx:find("latched on", 1, true) then kind = "latched"
        elseif tx:find("CLAMPED", 1, true) then kind = "clamped" end
        out("FUNE %d %s %s", m.tick, kind, (tx:gsub("%s+", "_")):sub(1, 80))
      end
    end
    seen_msg = math.max(seen_msg, last_tick(p.msgs))
    for _, f in ipairs(p.fx or {}) do
      if f.tick > seen_fx then out("FUNE %d fx:%s -", f.tick, tostring(f.sound)) end
    end
    seen_fx = math.max(seen_fx, last_tick(p.fx))
    -- bolts: near misses (closest pass within 1.0-1.5x of the hit radius, no hit)
    local s = p.ship
    local c = configs.get(s.size)
    local foot = sentry.on_foot(p)
    local rr = (foot and 0.35 or c.diameter / 2) + 0.4
    local live = {}
    local tune = sentry.tune().watcher
    for _, b in ipairs(st.bolts or {}) do
      if b.site == p.site then
        local born = now - math.floor((tune.bolt_life - b.life) * 60 + 0.5)
        local key = b.site .. ":" .. born .. ":" .. math.floor(b.vel[1] * 10) .. ":" .. math.floor(b.vel[3] * 10)
        live[key] = true
        local dx, dz = b.pos[1] - s.pos[1], b.pos[3] - s.pos[3]
        local d = math.sqrt(dx * dx + dz * dz) / rr
        local e = bolts[key] or { min = 1e9 }
        if d < e.min and math.abs(b.pos[2] - s.pos[2]) <= (foot and 0.9 or c.height / 2) + 0.4 + 2 then e.min = d end
        bolts[key] = e
      end
    end
    local hits = p.hits or 0
    for key, e in pairs(bolts) do
      if not live[key] then
        if hits > hits0 then e.hit = true end
        if not e.hit and e.min >= 1.0 and e.min <= 1.5 then out("FUNE %d near_bolt %.2f", now, e.min) end
        bolts[key] = nil
      end
    end
    hits0 = hits
    -- sentry state transitions targeting the player: slipped detection, escaped latches
    local threat, nearest = 0, 1e9
    for site, list in pairs(st.sentries or {}) do
      local defs = game.sentries(site)
      for k, dyn in ipairs(list) do
        local key = site .. ":" .. k
        local mine = dyn.target == p.index
        local cur = mine and dyn.st or "none"
        local prev = sstate[key] or "none"
        if prev == "alert" and cur ~= "alert" and cur ~= "locked" then out("FUNE %d slip_alert %s", now, (defs[k] or {}).kind or "?") end
        if prev == "latched" and cur ~= "latched" and cur ~= "flee" and dyn.st ~= "flee" then out("FUNE %d escape_latch -", now) end
        if prev == "clamped" and cur ~= "clamped" then out("FUNE %d escape_clamp -", now) end
        sstate[key] = cur
        if mine and (cur == "alert" or cur == "locked" or cur == "latched" or cur == "clamped" or cur == "chase") then
          threat = threat + (cur == "alert" and 0.5 or 1)
        end
        if site == p.site and dyn.st ~= "off" and dyn.st ~= "disabled" then
          local pos = dyn.pos or (defs[k] and defs[k].pos)
          if pos then nearest = math.min(nearest, vec.dist(pos, s.pos)) end
        end
      end
    end
    if now % 60 == 0 then
      local hot = 0
      for _, it in ipairs(p.hold) do if it.hot then hot = hot + 1 end end
      local nb = 0
      for _, b in ipairs(st.bolts or {}) do if b.site == p.site then nb = nb + 1 end end
      local ok, sc = pcall(story.found_count, st.story)
      local echoes = 0
      for _, e in pairs((st.mystery or {}).echoes or {}) do if e.decoded then echoes = echoes + 1 end end
      out("FUNS %d %s %d %d %d %d %d %.0f %.0f %.0f %.0f %.1f %.0f %d %d %d %d %d", now,
        p.mode .. (p.panel and ("+" .. p.panel.kind) or ""), p.site or 0, #p.hold, hot, p.banked_value or 0,
        p.credits or 0, s.hull, s.shield, p.suit or 100, p.eva and p.eva.o2 or -1, threat, nearest > 1e8 and -1 or nearest,
        inputs_this_sec, ok and sc or 0, echoes, nb, s.size)
      inputs_this_sec = 0
    end
    coroutine.yield()
  end
  out("FUNEND %d banked %d credits %d", S().tick, P1().banked_value or 0, P1().credits or 0)
end

-- ---------------- personas ----------------
local BUTTONS = { "shrink", "grow", "size1", "size2", "tractor", "scan", "boost", "use", "jam", "size3", "map",
                  "decoy", "shroud", "spike", "grapple", "land", "home", "assist" }
local AXES = { "move_x", "move_z", "lift", "turn", "look" }
local function rand_bot()
  BOT.B.wait(30)
  while S().tick < LIMIT do
    if rnd() < 0.5 then
      local a = AXES[1 + math.floor(rnd() * #AXES)]
      T.axis(1, a, rnd() * 2 - 1, 10 + math.floor(rnd() * 30), true)
    else
      T.press(1, BUTTONS[1 + math.floor(rnd() * #BUTTONS)], 1 + math.floor(rnd() * 3), true)
    end
    BOT.B.wait(15 + math.floor(rnd() * 15)) -- 2-4 Hz
  end
end
local function spam_bot()
  BOT.B.wait(30)
  require("sim.autopilot").wake(BOT.B, 1, P1)
  while S().tick < LIMIT do
    T.press(1, "tractor", 1, true)
    BOT.B.wait(6)
  end
end
local function career_bot(pol)
  return function()
    BOT.B.wait(30)
    require("sim.autopilot").wake(BOT.B, 1, P1)
    CAREER(1, pol)
  end
end

-- prototype interventions (fun_audit_report.md), switched on per batch with PROTO=ACD
local PROTO = CFG.proto or ""
if PROTO:find("A", 1, true) then require("sim.sentry").tune().watcher.small_range = tonumber(PROTO:match("A(%d+)")) or 22 end
if PROTO:find("D", 1, true) then require("sim.sentry").tune().watcher.hurt_scale = 0.8 end
if PROTO:find("C", 1, true) then
  for _, p in ipairs(S().players) do p.upgrades = p.upgrades or {} p.upgrades.beam_relay = 1 end
end
out("FUNP %s", PROTO)
BOT.spawn(0, "telemetry", telemetry)
if PERSONA == "rand" then BOT.spawn(1, "rand", rand_bot)
elseif PERSONA == "spam" then BOT.spawn(1, "spam", spam_bot)
elseif PERSONA == "beamonly" then
  CFG.jam = false
  BOT.spawn(1, "beamonly", career_bot({ name = "beam-only", sell_at = 6, max_danger = 3, trade = { fold = false },
    dive = function() return { seat = false } end }))
else
  BOT.spawn(1, PERSONA, career_bot({ name = "mystery-first", mystery = true, sell_at = 6, sleep_every = 4, max_danger = 3,
    trade = { fold = true }, dive = function(s) return { seat = s.guarded } end }))
end
BOT.run_all()
