-- SPDX-License-Identifier: MIT
-- 2D HUD in low-res viewport pixels (8x8 font).
local configs = require("sim.config")
local loot = require("sim.loot")
local vec = require("lib.vec")
local avatar = require("sim.avatar")
local panel = require("sim.panel")
local fold = require("sim.fold")
local items = require("sim.items")
local M = {}

local WHITE, DIM, GREEN, RED, AMBER, CYAN = { 1, 1, 1, 1 }, { 0.6, 0.65, 0.75, 1 }, { 0.4, 1, 0.5, 1 },
  { 1, 0.35, 0.3, 1 }, { 1, 0.8, 0.3, 1 }, { 0.4, 0.9, 1, 1 }
M.MSG_TICKS = 300

local HINTS = {
  kbm = "WASD fly MOUSE aim SPACE/CTRL up/down G use Q/E fold F beam (Tractor Room) V scan T jam TAB map H help",
  pad = "LS move RS aim RT/LT up/down X use LB/RB fold A beam Y scan RS-click jam DPAD map/decoy/shroud",
  keys2 = "IJKL move ARROWS aim O/U up/down ENTER use ,/. fold RSHIFT beam ; scan \\ map",
  touch = "Stick move  drag aim  UP/DN climb/dive  USE helm/console  buttons fold/tractor/scan/jam",
  xr = "L stick fly  R stick up/down + turn  L trigger use  lever fold  R trigger beam",
}
M.HINTS = HINTS

-- add-playtest-recs (recommendation 10): the control hints for what you are
-- doing right now (helm, walking the saucer, on foot in a derelict, a
-- station); HINTS above stay the helm line for each device
local MODE_HINTS = {
  walk = {
    kbm = "WASD walk MOUSE look SHIFT run G use (helm, lab, terminal, beam console) TAB map H help",
    pad = "LS walk RS look LS-click run X use (helm, lab, terminal, beam console) DPAD-RIGHT map",
    keys2 = "IJKL walk ARROWS look ENTER use \\ map",
    touch = "Stick walk  drag look  USE helm/lab/terminal/console  MAP",
  },
  foot = {
    kbm = "WASD walk SHIFT sprint CTRL crouch SPACE hop G grab Y grapple N spike/cut V scan T jam E deploy",
    pad = "LS walk RS look X grab DPAD-UP grapple B spike Y scan RS-click jam RB deploy",
    keys2 = "IJKL walk ARROWS look ENTER grab 0 grapple P spike ; scan . deploy",
    touch = "Stick walk  drag look  USE grab  GRP grapple  SCN scan  JAM jam  +SZ deploy",
  },
  station = {
    kbm = "WASD walk SHIFT sprint G trade/talk/grab F hold the coin E or 1/2 unfold (hangar) H help",
    pad = "LS walk RS look LS-click sprint X trade/talk A hold the coin RB unfold (hangar)",
    keys2 = "IJKL walk ARROWS look ENTER trade/talk RSHIFT hold the coin . unfold",
    touch = "Stick walk  drag look  USE trade/talk  BM hold the coin  +SZ unfold",
  },
}
M.MODE_HINTS = MODE_HINTS

-- the context a hint line is for
function M.hint_context(p)
  if p.mode == "foot" then return p.station and "station" or "foot" end
  if p.mode == "walk" and not p.beam_console then return "walk" end
  return "helm"
end

function M.hint_for(p, mode)
  local c = M.hint_context(p)
  local set = MODE_HINTS[c]
  if c == "helm" or not set then return HINTS[mode] or HINTS.kbm end
  return set[mode] or set.kbm
end

-- per view, which context its hint was last shown for (view state, not sim)
local hint_seen = {}
M.HINT_TICKS = 600

-- wrap text to `cols` columns (long words are cut), at most `max` lines
function M.wrap(text, cols, max)
  local out = {}
  for _, l in ipairs(require("sim.books").wrap(text, math.max(4, cols))) do
    if max and #out >= max then
      out[#out] = out[#out]:sub(1, math.max(1, cols - 3)) .. "..."
      break
    end
    out[#out + 1] = l:sub(1, cols)
  end
  return out
end

-- how urgent a message is: 3 = act now, 2 = advice, 1 = news
local URGENT = { "LOCKED", "CLAMPED", "THE WARDEN", "FOLD RETREAT", "LOCKDOWN", "latched on", "pocket is light",
                 "CRITICAL", "HARDCORE" }
local ADVICE = { "TIP:", "Wait:", "Tow bill", "stirs", "Snatcher", "Clamp", "Fold jump waiting" }
function M.urgency(text)
  for _, k in ipairs(URGENT) do if text:find(k, 1, true) then return 3 end end
  for _, k in ipairs(ADVICE) do if text:find(k, 1, true) then return 2 end end
  return 1
end

-- the message log as screen lines: live messages, repeats folded into "(xN)",
-- the most urgent first, each wrapped to two lines. -> { {text, urgency} }
function M.message_lines(state, p, cols, max_lines)
  local live, by_text = {}, {}
  for i = #p.msgs, 1, -1 do
    local m = p.msgs[i]
    if state.tick - m.tick < M.MSG_TICKS then
      local e = by_text[m.text]
      if e then e.n = e.n + 1
      else
        e = { text = m.text, n = 1, tick = m.tick, order = #live, u = M.urgency(m.text) }
        by_text[m.text] = e
        live[#live + 1] = e
      end
    end
  end
  table.sort(live, function(a, b)
    if a.u ~= b.u then return a.u > b.u end
    return a.order < b.order
  end)
  local lines = {}
  for _, e in ipairs(live) do
    local t = e.n > 1 and string.format("%s (x%d)", e.text, e.n) or e.text
    for _, l in ipairs(M.wrap(t, cols, 2)) do
      if #lines >= max_lines then return lines end
      lines[#lines + 1] = { l, e.u }
    end
  end
  return lines
end

local HELP = {
  "SAUCER - controls",
  "Walk or fly: W A S D, look: mouse (click to capture)",
  "Use G/Enter: take the helm, or stand up from it",
  "At the helm: you fly where you look (mouse up/down climbs/dives)",
  "Up/down: Space/Ctrl (or R/Z), boost Shift",
  "Fold Q (to the Seat) / unfold E, or 1-2",
  "Beam: hover over loot, go down to the Tractor Room (stairs by",
  "the engine), Use the console, F pulls. Long scrap: line up the keel",
  "At the console the stick trims, Space/Ctrl up/down, Use gets up",
  "Scanner V (reveals sentries 10 s), Jammer T (disables 12 s)",
  "Lab bench: identify and decode; trade terminal when docked",
  "Home: holodeck (engine room), stove, bookshelf, TV (sofa)",
  "Docked: 3 pockets the saucer; F holds the coin, Shift sprints",
  "Station: G trades/talks/grabs a thief, E or 1-2 in a hangar",
  "Derelict: Seat near a deck, 3 (or Q) steps out; E deploys it",
  "On foot: Ctrl crouch, Space hop, G grabs / turns a hand-lock",
  "Map TAB: fold jumps (the party agrees), party, Xenoarchive",
  "Decoy B, Shroud X; on foot Y grapples, hold N spikes or cuts",
  "Clamped? hold Boost to shake it off, or Jam it",
  "Co-op: gamepad A or F2 (right-hand keys) joins a player",
  "Camera C, mystery mode M, help H/F1",
  "Gamepad, touch and WebXR work too.",
}
M.HELP = HELP

function M.ladder(v, p, x, y)
  local ship = p.ship
  for i, c in ipairs(configs.all()) do
    local col = DIM
    if i == ship.size then col = ship.morph and AMBER or GREEN end
    v:rect(x + (i - 1) * 12, y, 10, 10, { col[1] * 0.3, col[2] * 0.3, col[3] * 0.3, 0.8 })
    v:text(x + 1 + (i - 1) * 12, y + 1, c.name:sub(1, 1), col)
  end
end

-- where the player is and what Use would do right now
function M.status(p, state)
  local L = avatar.layout()
  if p.mode == "wake" then return "BEDROOM", nil end
  -- add-holodeck-home-life
  if p.holo_run then
    local holo = require("sim.holo")
    local host = state and holo.host(state, p)
    local pr = host and host.holo_run and holo.program(host.holo_run.id)
    return "HOLODECK: " .. (pr and pr.name:upper() or "PROGRAM"), state and holo.hint(state, p) or nil
  end
  if p.mode == "foot" and p.station and state then return require("sim.visit").status(state, p) end
  if p.mode == "foot" and p.excursion and state then return require("sim.excursion").status(state, p) end
  if p.tv then return "LIVING ROOM - TV", "USE: NEXT CHANNEL  MOVE: GET UP" end
  if p.reading then return "BOOKSHELF", nil end
  if p.cooking then return "KITCHEN", nil end
  if p.mode == "walk" and p.beam_console then return "TRACTOR ROOM", "F: PULL  STICK: TRIM  USE: GET UP" end
  if p.mode == "walk" then
    local room = avatar.room(L, p.body):upper()
    if avatar.near_helm(L, p.body) then return room, "USE: TAKE THE HELM" end
    local st = avatar.station(L, p.body)
    if st then return room, st.label end
    return room, nil
  end
  if configs.get(p.ship.size).interior then return "AT THE HELM", "USE: STAND UP" end
  return "SEAT", "F: MINI BEAM  E: UNFOLD THE VILLA"
end

function M.bearing(p, target)
  local d = vec.sub(target, p.ship.pos)
  local a = saucer.math.wrap(saucer.math.atan2(d[1], d[3]) - p.ship.yaw)
  if a > 0.25 then return "<" elseif a < -0.25 then return ">" end
  return "^"
end

-- vertical cue toward a target: "UP 120M", "DN 40M" or "LEVEL"
function M.elevation_cue(p, target)
  local dy = target[2] - p.ship.pos[2]
  if dy > 8 then return string.format("UP %dM", dy // 1) end
  if dy < -8 then return string.format("DN %dM", (-dy) // 1) end
  return "LEVEL"
end

-- the altitude tape at the helm (true 3D): ticks every 20 m around your
-- altitude, vertical speed and pitch. -> number of ticks drawn
function M.altitude(v, p)
  local W, H = v.width, v.height
  local ship = p.ship
  local x, y0, h = W - 48, H // 2 - 50, 100
  local alt = ship.pos[2]
  v:rect(x - 2, y0 - 2, 26, h + 4, { 0, 0, 0, 0.35 })
  local n = 0
  local base = (alt // 20) * 20
  for k = -3, 3 do
    local a = base + k * 20
    local yy = y0 + h / 2 - (a - alt) * (h / 140)
    if yy >= y0 and yy <= y0 + h - 2 then
      v:rect(x, yy, a % 100 == 0 and 8 or 4, 1, DIM)
      if a % 40 == 0 then v:text(x + 9, yy - 3, string.format("%d", a // 1), DIM) end
      n = n + 1
    end
  end
  v:rect(x - 4, y0 + h / 2, 10, 1, GREEN)
  v:text(x - 20, y0 + h + 6, string.format("ALT %d", alt // 1), CYAN)
  local vs = ship.vel[2]
  v:text(x - 20, y0 + h + 16, string.format("VS %s%d", vs >= 0 and "+" or "-", math.abs(vs) // 1), vs >= 0 and GREEN or AMBER)
  v:text(x - 20, y0 - 12, string.format("P %d", (ship.pitch * 57.2958) // 1), DIM)
  return n
end

-- the middle of a site's build volume (sites are huge; their origin is a corner)
function M.site_center(state, site)
  local game = require("sim.game")
  local b = game.site_bounds and game.site_bounds(site.id)
  if not b then return site.pos end
  return { (b[1][1] + b[2][1]) / 2, (b[1][2] + b[2][2]) / 2, (b[1][3] + b[2][3]) / 2 }
end

function M.nav(state, p)
  if p.site ~= 0 then return nil end
  local best, bd
  for _, s in ipairs(state.sector.sites) do
    local d = vec.dist(M.site_center(state, s), p.ship.pos)
    if not bd or d < bd then best, bd = s, d end
  end
  return best, bd
end

-- the open menu (title, bed, lab, trade): a box with a highlighted row
function M.panel(v, state, p)
  if not p.panel then return 0 end
  local W, H = v.width, v.height
  local rows = panel.rows(state, p)
  local title = panel.title(state, p)
  -- long lists (the trade terminal) show a window of rows around the selection
  local all, first = rows, 1
  -- (add-playtest-recs: leaves room for the nav, the row hint and two message lines)
  local maxr = math.max(4, (H - 110) // 11)
  if #all > maxr then
    first = vec.clamp(p.panel.sel - maxr // 2, 1, #all - maxr + 1)
    rows = {}
    for i = first, first + maxr - 1 do rows[#rows + 1] = all[i] end
  end
  local w = 8
  for _, r in ipairs(rows) do w = math.max(w, #r.text + 4) end
  w = math.min(math.max(w, #title + 4) * 8, W - 16)
  local x, y = W // 2 - w // 2, H // 2 - (#rows * 11 + 24) // 2
  -- add-pocket-station-visits: face to face, the menu sits low so you can
  -- still see who you are talking to
  if p.mode == "foot" then y = math.max(y, math.min(H // 2 + 20, H - 46 - #rows * 11 - 24)) end
  local is_title = p.panel.kind == "title"
  if is_title then
    -- add-presentation-packaging: the Grok Imagine title emblem above the name
    local A = require("view.assets").init()
    local es = math.min(96, y - 52)
    if A.tex.title_emblem and es >= 24 then
      v:image(A.tex.title_emblem, W // 2 - es // 2, y - 50 - es, es, es, A.pal.sprites)
    end
    v:text(W // 2 - 6 * 8 * 3 // 2, y - 46, "SAUCER", AMBER, 3)
    v:text(W // 2 - 13 * 8 // 2, y - 18, "a cozy salvage", DIM)
  end
  -- add-wider-dark: the sector map sits left of its rows when there is room
  if p.panel.kind == "map" and W >= 360 then
    local mw = math.min(W // 3, 200)
    require("view.map").draw(v, state, 6, 40, mw, math.min(H - 80, 160), p)
    x = math.max(x, mw + 16)
    w = math.min(w, W - 8 - x)
  end
  local top = is_title and 0 or 12
  v:rect(x - 4, y - 4, w + 8, #rows * 11 + top + 12, { 0, 0.02, 0.06, 0.82 })
  if not is_title then v:text(x, y, title, AMBER) end
  if first > 1 or first + #rows - 1 < #all then
    local more = string.format("%d-%d/%d", first, first + #rows - 1, #all)
    v:text(x + w - #more * 8, y, more, DIM)
  end
  for i, r in ipairs(rows) do
    local sel = i + first - 1 == p.panel.sel
    local col = r.enabled == false and DIM or (sel and GREEN or WHITE)
    if sel then v:rect(x - 2, y + top + (i - 1) * 11 - 1, w + 4, 10, { 0.2, 0.5, 0.3, 0.5 }) end
    v:text(x, y + top + (i - 1) * 11, ((sel and "> " or "  ") .. r.text):sub(1, w // 8), col)
  end
  local mode = saucer.input.device_mode(v.player)
  local nav = mode == "pad" and "STICK UP/DOWN  X: PICK" or (mode == "touch" and "STICK UP/DOWN  USE: PICK" or
    (mode == "keys2" and "I/K: CHOOSE  ENTER: PICK" or "W/S: CHOOSE  G/ENTER: PICK"))
  v:text(W // 2 - #nav * 4, y + top + 10 + #rows * 11, nav, DIM)
  -- add-home-among-stars: the selected row's hint (a mod's description)
  local cur = all[p.panel.sel]
  if cur and cur.hint then
    local h = cur.hint:sub(1, (W - 16) // 8)
    v:text(W // 2 - #h * 4, y + top + 21 + #rows * 11, h, CYAN)
  end
  return #rows
end

-- what the fold is doing right now, for the HUD (nil when idle)
function M.fold_status(p)
  local ship = p.ship
  if not ship.morph then return nil end
  local amounts, order = fold.amounts(ship)
  if not order then return nil end
  local packed, out, total, busy = 0, 0, #order, nil
  for _, g in ipairs(order) do
    local a = amounts[g.id]
    if a >= 1 then packed = packed + 1 elseif a > 0 and not busy then busy = g.name end
    if a <= 0 then out = out + 1 end
  end
  local growing = ship.size < ship.morph.from
  if growing then
    return string.format("UNFOLDING %d/%d ROOMS%s", out, total, busy and (": " .. busy:upper()) or "")
  end
  return string.format("FOLDING %d/%d ROOMS%s", packed, total, busy and (": " .. busy:upper()) or "")
end

-- milestone 3 readouts: the lab bench, a Snatcher latch and sentry alarms
function M.lab_status(state, p)
  local q = p.lab and p.lab.queue or {}
  local job = q[1]
  if not job then return nil end
  local it = items.find(p, job.uid)
  local what = it and items.label(it) or "?"
  local lab = require("sim.lab")
  local paused = not lab.running(p)
  -- add-playtest-recs: every running bench shows its job; the rest are "+N"
  local parts = {}
  local live = math.min(lab.slots(p), #q)
  for k = 1, live do
    local j = q[k]
    parts[#parts + 1] = string.format("%s %d%%", j.kind == "identify" and "ID" or "DECODE",
      math.floor((1 - j.left / j.total) * 100))
  end
  return string.format("LAB %s%s%s", table.concat(parts, " "), paused and " (PAUSED: VILLA ONLY)" or "",
    #q > live and (" +" .. (#q - live)) or ""), what
end

-- add-playtest-recs: the centre alerts, most urgent first -> { {text, colour, bar} }
function M.alerts(state, p, W)
  local out = {}
  local narrow = W < 400
  if p.clamped_by then
    out[#out + 1] = { string.format(narrow and "CLAMPED - BOOST %.1f/%.0f" or "CLAMPED - HOLD BOOST %.1f/%.0f OR JAM",
      p.shake or 0, require("sim.sentry").tune().clamp.shake_time), RED }
  end
  if p.latched_by then
    out[#out + 1] = { narrow and "SNATCHER - JAM IT" or "SNATCHER SIPHONING - JAM IT (T)", RED,
      math.min(1, (p.latched_by.t or 0) / 3) }
  end
  local alarm = M.alarm(state, p)
  if alarm == "LOCKED" then
    out[#out + 1] = { narrow and "! LOCKED - JAM OR RUN !" or "! SENTRY LOCKED - JAM (T) OR RUN !", RED }
  elseif alarm == "WARDEN" then
    out[#out + 1] = { narrow and "! WARDEN - JAM OR HIDE !" or "! THE WARDEN HUNTS YOU - JAM (T) OR HIDE !", RED }
  elseif alarm == "ALERT" then
    out[#out + 1] = { "! SENTRY ALERT !", AMBER }
  end
  return out
end

function M.alarm(state, p)
  local worst
  for site, list in pairs(state.sentries or {}) do
    if site == p.site then
      for _, dyn in pairs(list) do
        if dyn.target == p.index and (dyn.st == "locked" or dyn.st == "latched") then worst = "LOCKED"
        elseif dyn.target == p.index and dyn.st == "hunt" then worst = "WARDEN" -- add-home-among-stars
        elseif dyn.target == p.index and dyn.st == "alert" and not worst then worst = "ALERT" end
      end
    end
  end
  return worst
end

-- add-tractor-beam: the beam scope. A circle is the cone's footprint at the
-- target's depth, the dot is the target (seen the way you face: up = ahead),
-- with the rule that fails first spelled out (or LOCK). At the Villa's helm
-- it also tells you to go down to the Tractor Room. -> lines drawn
function M.beam(v, state, p, scan)
  local W, H = v.width, v.height
  local tractor = require("sim.tractor")
  local b = tractor.beam_of(p.ship)
  local n = 0
  -- at the console the view looks down the beam: keep the middle clear
  local y0 = p.beam_console and H // 2 + 58 or H // 2 + 10
  -- gameplay gaps: the Tractor Room target queue
  local ql = require("sim.beamqueue").line(p)
  if ql then
    v:text(W // 2 - #ql * 4, y0 + 36, #ql * 8 > W - 8 and ql:sub(1, (W - 8) // 8) or ql, CYAN)
    n = n + 1
  end
  if p.tractor then
    local f = vec.clamp(p.tractor.t / p.tractor.total, 0, 1)
    local t = f < 0.75 and "BEAM PULLING - SHRINKING TO FIT" or "INTO THE HOLD"
    v:text(W // 2 - #t * 4, y0 + 12, t, CYAN)
    v:rect(W // 2 - 40, y0 + 22, 80, 3, { 0.15, 0.15, 0.2, 1 })
    v:rect(W // 2 - 40, y0 + 22, 80 * f, 3, AMBER)
    return 2
  end
  local watching = p.beam_console or (p.mode == "helm" and not b.console)
  if not scan or not (watching or p.mode == "helm") then return 0 end
  local info, st = scan.info, scan.status
  local col = st == "lock" and GREEN or ((st == "big" or st == "blocked") and RED or AMBER)
  local label = string.format("%s [%s]", items.label(scan.cand.item), loot.size_name(scan.cand.item.size))
  v:text(W // 2 - #label * 4, y0, label, col)
  n = n + 1
  local hint = info.hint
  if st == "lock" and b.console and not p.beam_console then
    -- add-playtest-recs: the helm beam relay pulls small finds from here
    hint = require("sim.upgrades").relay(p, scan.cand.item) and "LOCK - F PULLS (HELM RELAY)" or "LOCK - GO DOWN TO THE TRACTOR ROOM"
  end
  v:text(W // 2 - #hint * 4, y0 + 10, hint, col)
  n = n + 1
  -- the scope, bottom right
  local cx, cy, R = W - 40, H - 70, 22
  v:rect(cx - R - 6, cy - R - 14, 2 * R + 12, 2 * R + 34, { 0, 0.02, 0.06, 0.6 })
  v:text(cx - 16, cy - R - 12, "BEAM", DIM)
  for k = 0, 23 do
    local a = k * saucer.math.tau / 24
    v:rect(cx + saucer.math.sin(a) * R, cy + saucer.math.cos(a) * R, 1, 1, col)
  end
  v:rect(cx - 3, cy, 7, 1, DIM)
  v:rect(cx, cy - 3, 1, 7, DIM)
  local _, heading = require("sim.game").viewpoint(p)
  local lim = math.max(0.5, info.max_lateral)
  local fx = vec.dot(info.off, vec.right(heading)) / lim
  local fz = vec.dot(info.off, vec.fwd(heading)) / lim
  local dx, dy = vec.clamp(fx, -1.3, 1.3) * R, -vec.clamp(fz, -1.3, 1.3) * R
  v:rect(cx + dx - 2, cy + dy - 2, 5, 5, col)
  v:text(cx - R - 2, cy + R + 4, string.format("D%d", info.depth // 1), DIM)
  if info.yaw_err then v:text(cx + 2, cy + R + 4, string.format("%dD", math.abs(info.yaw_err * 57.2958) // 1), DIM) end
  return n + 1
end

function M.draw(v, state, p, target)
  local W, H = v.width, v.height
  -- add-wider-dark: a split-screen view keeps only the essentials (a quarter
  -- of a four-way split, and since add-home-among-stars the narrow halves of
  -- a two-way split too: the full Seat HUD stacked on itself there)
  local compact = H < 200 or W < 400
  local function fit(t) return t:sub(1, (W - 8) // 8) end
  local ship = p.ship
  local c = configs.get(ship.size)
  if p.mode == "wake" then
    -- waking up: just the title card over the bedroom (and the touch buttons)
    M.panel(v, state, p)
    if saucer.input.device_mode(v.player) == "touch" then M.touch(v) end
    return
  end
  -- size + charge
  v:rect(4, 4, 120, 28, { 0, 0, 0, 0.45 })
  v:text(8, 7, c.name:upper(), WHITE)
  M.ladder(v, p, 70, 6)
  local charge = ship.charge / configs.all().max_charge
  v:rect(8, 18, 100, 5, { 0.15, 0.15, 0.2, 1 })
  v:rect(8, 18, 100 * charge, 5, charge > 0.3 and CYAN or RED)
  v:text(8, 25, string.format("CHG %d", ship.charge // 1), DIM)
  -- hold
  local hot = 0
  for _, it in ipairs(p.hold) do if it.hot then hot = hot + 1 end end
  if not compact then
    v:text(8, 36, string.format("HOLD %d/%d HOT %d BANK %dc", #p.hold, require("sim.upgrades").hold_slots(p), hot, p.banked_value), DIM)
  end
  -- hull, shield and credits (milestone 3)
  local sh, hu = (ship.shield or 100) / 100, (ship.hull or 100) / 100
  v:rect(128, 6, 60, 4, { 0.15, 0.15, 0.2, 1 })
  v:rect(128, 6, 60 * math.max(0, sh), 4, CYAN)
  v:rect(128, 12, 60, 4, { 0.15, 0.15, 0.2, 1 })
  v:rect(128, 12, 60 * math.max(0, hu), 4, hu > 0.3 and GREEN or RED)
  v:text(128, 19, string.format("%dc", p.credits or 0), AMBER)
  -- add-home-among-stars: Hardcore is always on screen
  -- (under the status lines; "HC" inside the Charge box in a compact view)
  if state.hardcore then
    if compact then v:text(96, 25, "HC", RED) else v:text(8, p.mode == "foot" and 116 or 76, "HARDCORE", RED) end
  end
  local ls = M.lab_status(state, p)
  if ls and not compact then v:text(8, 56, ls, DIM) end
  -- add-playtest-recs: the centre alerts as one stack, most urgent on top
  local alerts = M.alerts(state, p, W)
  local ay = H // 2 - (compact and 20 or 44) - (#alerts - 1) * 11
  for _, a in ipairs(alerts) do
    v:text(math.max(2, W // 2 - #a[1] * 4), ay, a[1]:sub(1, (W - 4) // 8), a[2])
    if a[3] then
      v:rect(W // 2 - 40, ay + 9, 80 * a[3], 2, a[2])
    end
    ay = ay + 11
  end
  if p.shroud then
    local moving = vec.len(ship.vel or { 0, 0, 0 }) > require("sim.sentry").tune().shroud.still
    v:text(128, 26, moving and "SHROUD (MOVING)" or "SHROUD", moving and AMBER or CYAN)
  end
  if (p.decoys or 0) > 0 and not compact and p.mode ~= "foot" then v:text(8, 66, string.format("DECOYS %d", p.decoys), DIM) end
  if p.visiting then v:text(W // 2 - 64, 36, string.format("VISITING P%d'S DOME", p.visiting), GREEN) end
  M.jump(v, state, p, compact)
  if p.mode == "helm" and not compact then M.altitude(v, p) end
  -- crosshair, where you are and what Use does
  v:text(W // 2 - 4, H // 2 - 4, "+", p.tractor and AMBER or WHITE)
  local where, hint = M.status(p, state)
  v:text(8, 46, where, CYAN)
  if hint then
    if not compact then hint = fit(hint) end
    -- (in a split view it sits above the messages, clear of the beam scope)
    if compact then
      -- one line per part ("F: MINI BEAM  E: UNFOLD" -> two lines), left of the scope
      local parts = {}
      for part in (hint .. "  "):gmatch("(.-)  +") do parts[#parts + 1] = part end
      for i = #parts, 1, -1 do v:text(6, H - 34 - (#parts - i) * 10, parts[i]:sub(1, (W - 64) // 8), AMBER) end
    else v:text(W // 2 - #hint * 4, H // 2 + 40, hint, AMBER) end
  end
  -- navigation
  local site, d = M.nav(state, p)
  if p.holo_run or p.mode == "foot" then site = nil end
  if p.mode == "foot" and p.station then M.station(v, state, p) end
  if p.mode == "foot" and p.excursion then M.excursion(v, state, p) end
  -- add-wider-dark: in a narrow split-screen view these go right-aligned
  -- under the size box instead of across the top
  local function nav(dx, y, t, col)
    if compact then
      if y == 0 then v:text(W - 4 - #t * 8, 36, t, col) end
    elseif W < 400 then v:text(W - 4 - #t * 8, 56 + y, t, col) else v:text(W // 2 - dx, 6 + y, t, col) end
  end
  if site then
    local c = M.site_center(state, site)
    nav(60, 0, string.format("%s SITE %d %dm", M.bearing(p, c), site.id, vec.dist(c, p.ship.pos) // 1), CYAN)
    nav(60, 10, M.elevation_cue(p, c), CYAN)
    if p.docked then nav(60, 20, W < 400 and "DOCKED" or "DOCKED AT THE TRADER", GREEN) end
  elseif p.site ~= 0 then
    nav(40, 0, "IN DERELICT " .. p.site, AMBER)
    if (p.scan_until or 0) > state.tick then nav(40, 10, "SCANNING", CYAN) end
  end
  -- the belly beam's alignment indicator (add-tractor-beam)
  -- (a two-way split half still has room for the scope: the beam needs it)
  if not compact or H >= 200 then M.beam(v, state, p, target) end
  -- mystery
  local m = state.mystery
  if compact then -- no room
  elseif m.mode == "off" then
    v:text(W - 72, 6, "SANDBOX", DIM)
  else
    local t = string.format("%s %d/%d", m.title:upper(), m.found, #m.echoes)
    -- add-wider-dark: a split-screen view is too narrow for the top row
    v:text(W - 4 - #t * 8, W < 400 and 86 or 6, t, m.solved and GREEN or AMBER)
  end
  -- messages
  -- add-playtest-recs: wrapped, repeats folded, the most urgent first
  -- (two lines under an open panel, so the two never overlap)
  local lines = M.message_lines(state, p, (W - 12) // 8, (compact or p.panel) and 2 or 5)
  local y = H - 12 - (#lines - 1) * 10
  for _, l in ipairs(lines) do
    v:text(6, y, l[1], l[2] == 3 and RED or (l[2] == 2 and AMBER or WHITE))
    y = y + 10
  end
  M.home(v, state, p)
  local fs = p.mode ~= "foot" and M.fold_status(p) or nil
  if fs then v:text(W // 2 - #fs * 4, H // 2 - 30, fs, CYAN) end
  M.lifeline(v, state, p)
  if p.slept_tick and state.tick - p.slept_tick < 120 then
    v:rect(0, 0, W, H, { 0, 0, 0.02, 1 - (state.tick - p.slept_tick) / 120 })
  end
  M.panel(v, state, p)
  if p.help then
    v:rect(W // 2 - 170, 50, 340, 12 * #HELP + 8, { 0, 0, 0.05, 0.8 })
    for i, line in ipairs(HELP) do v:text(W // 2 - 164, 46 + i * 12, line, i == 1 and AMBER or WHITE) end
  end
  local mode = saucer.input.device_mode(v.player)
  if mode == "touch" then M.touch(v) end
  -- add-playtest-recs: the hint for the current context only, wrapped, for
  -- a while after the context changes (and at the start)
  local ctxk = (v.player or 0) .. ":" .. M.hint_context(p) .. ":" .. mode
  local hs = hint_seen[v.player or 0]
  if not hs or hs.key ~= ctxk or state.tick < hs.tick then
    hs = { key = ctxk, tick = state.tick }
    hint_seen[v.player or 0] = hs
  end
  if not compact and not p.panel and state.tick - hs.tick < M.HINT_TICKS then
    local hl = M.wrap(M.hint_for(p, mode), (W - 12) // 8, 2)
    for i, l in ipairs(hl) do v:text(6, H - 14 - 10 * #lines - 10 * (#hl - i + 1), l, DIM) end
  end
end

-- add-playtest-recs: the co-op fold readiness line. During a jump vote:
-- every player's state ("P1 READY  P2 INSIDE A SITE"); otherwise the others
-- who said they are ready. -> text or nil
function M.ready_line(state, p, narrow)
  if #state.players < 2 then return nil end
  local coop = require("sim.coop")
  local parts = {}
  if state.jump then
    for _, r in ipairs(coop.readiness(state)) do
      local why = r.ok and "READY" or (narrow and "WAIT" or r.why:upper())
      parts[#parts + 1] = string.format("P%d %s", r.index, why)
    end
    return table.concat(parts, "  ")
  end
  for _, r in ipairs(coop.readiness(state)) do
    if r.flagged and r.index ~= p.index then parts[#parts + 1] = "P" .. r.index end
  end
  if #parts == 0 then return nil end
  return table.concat(parts, " ") .. (narrow and " READY TO FOLD" or " READY TO FOLD - TAB: MAP")
end

-- add-wider-dark: the sector you are in and a party jump being voted on
function M.jump(v, state, p, compact)
  local W, H = v.width, v.height
  local narrow = W < 400
  local galaxy = require("sim.galaxy")
  local g = galaxy.generate(state.seed)
  local here = g.sectors[state.sector_id or 1]
  if here and not compact then
    local t = here.name:upper()
    v:text(W - 4 - #t * 8, narrow and 96 or 16, t, here.heart and { 1, 0.45, 0.65, 1 } or DIM)
  end
  local m = state.mystery
  if require("sim.heart").can_vote(state, p) and not m.votes[tostring(p.index)] and state.tick % 60 < 45 then
    local t = narrow and "HEART OPEN - TAB TO VOTE" or "THE HEART IS OPEN - TAB TO VOTE"
    v:text(W // 2 - #t * 4, compact and 58 or narrow and H // 2 - 80 or 56, t, { 1, 0.45, 0.65, 1 })
  end
  local j = state.jump
  -- add-playtest-recs: who is ready to fold (co-op), for whoever waits
  local rl = M.ready_line(state, p, narrow)
  if rl then
    v:text(math.max(2, W // 2 - #rl * 4), compact and H // 2 - 6 or narrow and H // 2 - 20 or 66, rl:sub(1, (W - 4) // 8),
      j and AMBER or GREEN)
  end
  if not j then return end
  local n = 0
  for _ in pairs(j.yes) do n = n + 1 end
  local t
  if j.spool >= 0 then t = string.format("FOLD CORE SPOOLING %.1f", j.spool)
  elseif not j.yes[tostring(p.index)] then
    t = string.format(narrow and "P%d: %s? TAB AGREES" or "P%d: JUMP TO %s? TAB TO AGREE", j.by, g.sectors[j.to].name:upper())
  else t = string.format("JUMP TO %s %d/%d", g.sectors[j.to].name:upper(), n, #state.players) end
  v:text(math.max(2, W // 2 - #t * 4), compact and H // 2 - 16 or narrow and H // 2 - 30 or 46, t, j.spool >= 0 and CYAN or AMBER)
  -- the spool: a widening fold ring and a tint that builds toward the jump
  if j.spool >= 0 then
    local k = 1 - j.spool / require("sim.galaxy").tune().spool
    v:rect(0, 0, W, H, { 0.3, 0.6, 1, 0.25 * k })
    local R = 12 + k * math.min(W, H) * 0.45
    for a = 0, 47 do
      local ang = a * saucer.math.tau / 48 + k * 2
      v:rect(W // 2 + saucer.math.sin(ang) * R - 1, H // 2 + saucer.math.cos(ang) * R * 0.8 - 1, 3, 3, CYAN)
    end
  end
end

-- add-holodeck-home-life overlays: active buffs, the open book, the TV's
-- caption, the stove's progress and the holodeck's course readout. -> draws
local PAPER, INK = { 0.93, 0.88, 0.76, 0.96 }, { 0.18, 0.14, 0.1, 1 }
function M.home(v, state, p)
  local W, H = v.width, v.height
  local n = 0
  local bl = require("sim.buffs").list(state, p)
  for i, b in ipairs(bl) do
    local t = string.format("%s %d:%02d", b.name:upper(), b.left // 60, (b.left % 60) // 1)
    v:text(W - 4 - #t * 8, 16 + i * 10, t, GREEN)
    n = n + 1
  end
  if p.reading then
    local books = require("sim.books")
    local r = books.resolve(state, p.reading.id)
    local page = r.pages[p.reading.page] or {}
    local bw, bh = 30 * 8 + 24, 14 * 10 + 30
    local x, y = W // 2 - bw // 2, H // 2 - bh // 2 - 10
    v:rect(x - 3, y - 3, bw + 6, bh + 6, { 0.35, 0.2, 0.12, 0.95 })
    v:rect(x, y, bw, bh, PAPER)
    v:rect(x + bw // 2, y + 4, 1, bh - 8, { 0.7, 0.62, 0.5, 1 })
    v:text(x + 12, y + 8, r.title:sub(1, 30), { 0.45, 0.2, 0.1, 1 })
    for i, line in ipairs(page) do v:text(x + 12, y + 16 + i * 10, line:sub(1, 30), INK) end
    local pg = string.format("PAGE %d/%d%s", p.reading.page, #r.pages, r.kind == "clue" and "  CLUE" or "")
    v:text(x + bw - 12 - #pg * 8, y + bh - 12, pg, { 0.45, 0.35, 0.25, 1 })
    local h = "USE: NEXT PAGE  MOVE: CLOSE THE BOOK"
    v:text(W // 2 - #h * 4, y + bh + 8, h, AMBER)
    n = n + 1
  end
  if p.tv then
    local tv = require("sim.tv")
    local ch = tv.current(state, p)
    if ch then
      local show, hint = tv.now(state, p, ch)
      local lines = require("sim.books").wrap(hint, (W - 40) // 8)
      local bh = 16 + #lines * 10
      local y = H - 40 - bh
      v:rect(10, y, W - 20, bh, { 0, 0, 0, 0.6 })
      v:text(16, y + 4, string.format("%s - %s", ch.name:upper(), show:upper()), CYAN)
      for i, l in ipairs(lines) do v:text(16, y + 4 + i * 10, l, WHITE) end
      n = n + 1
    end
  end
  if p.cooking then
    local r = require("sim.kitchen").recipe(p.cooking.recipe)
    local f = vec.clamp(1 - p.cooking.left / p.cooking.total, 0, 1)
    local t = "COOKING " .. (r and r.name:upper() or "")
    v:text(W // 2 - #t * 4, H // 2 + 30, t, AMBER)
    v:rect(W // 2 - 50, H // 2 + 42, 100, 4, { 0.15, 0.15, 0.2, 1 })
    v:rect(W // 2 - 50, H // 2 + 42, 100 * f, 4, AMBER)
    n = n + 1
  end
  if p.holo_run and p.holo_run.craft then
    local holo = require("sim.holo")
    local run = p.holo_run
    local sc = holo.scene(state, p, run)
    local best = holo.ensure(p).best[run.id]
    local t = string.format("RING %d/%d  %.1f S%s", math.min(run.gate, #sc.gates), #sc.gates, run.t,
      best and string.format("  BEST %.1f", best) or "")
    if run.done then t = string.format("COURSE CLEAR %.1f S  USE: END", run.t) end
    v:text(W // 2 - #t * 4, 30, t, run.done and GREEN or AMBER)
    n = n + 1
  end
  return n
end

-- add-pocket-station-visits: on foot in a station, where the coin is and,
-- while the pickpocket runs, which way and how far he is
function M.station(v, state, p)
  local visit = require("sim.visit")
  local W, H = v.width, v.height
  local text, kind = visit.coin_text(p)
  v:text(8, 66, text, kind == "alarm" and RED or (kind == "busy" and AMBER or GREEN))
  local pos, d, mode = visit.thief_info(p)
  if mode == "flee" then
    local b = p.station.body
    local a = saucer.math.wrap(saucer.math.atan2(pos[1] - b.pos[1], pos[2] - b.pos[3]) - b.yaw)
    local dir = math.abs(a) < 0.4 and "AHEAD" or (math.abs(a) > 2.6 and "BEHIND" or (a > 0 and "LEFT" or "RIGHT"))
    local t = string.format("THIEF %s %dm  SPRINT: SHIFT", dir, d // 1)
    v:text(W // 2 - #t * 4, 80, t, RED)
    local left = math.max(0, visit.tune().escape - (p.station.thief.t or 0))
    v:rect(W // 2 - 50, 90, 100, 3, { 0.15, 0.15, 0.2, 1 })
    v:rect(W // 2 - 50, 90, 100 * left / visit.tune().escape, 3, RED)
  elseif mode == "stalk" and d < 5 then
    local t = "SOMEONE IS CROWDING YOU"
    v:text(W // 2 - #t * 4, 80, t, AMBER)
  end
  return 1
end

-- add-on-foot-excursions: the suit (the only meter on foot), your four hand
-- slots, the coin, a hand-lock's progress and your caches' bearing
function M.excursion(v, state, p)
  local ex = require("sim.excursion")
  local T = ex.tune()
  local W, H = v.width, v.height
  local e = p.excursion
  local s = math.max(0, (p.suit or 0) / T.suit.max)
  local col = s > 0.3 and CYAN or (s > 0.1 and AMBER or RED)
  local blink = s <= 0.1 and (state.tick // 15) % 2 == 0
  v:rect(4, 60, 120, 40, { 0, 0, 0, 0.45 })
  v:text(8, 63, string.format("SUIT %d%%", (p.suit or 0) // 1), blink and WHITE or col)
  v:rect(8, 73, 100, 5, { 0.15, 0.15, 0.2, 1 })
  v:rect(8, 73, 100 * s, 5, col)
  -- hands: four slots
  for i = 1, T.hands do
    local it = p.hands[i]
    local x = 8 + (i - 1) * 14
    v:rect(x, 82, 12, 12, it and (it.delicate and { 0.2, 0.5, 0.6, 0.9 } or { 0.5, 0.38, 0.15, 0.9 }) or { 0.15, 0.15, 0.2, 0.8 })
    if it then v:text(x + 2, 84, (it.name or "?"):sub(1, 1), WHITE) end
  end
  v:text(70, 84, "HANDS", DIM)
  local text, kind = ex.coin_text(p)
  v:text(8, 104, text, kind == "busy" and AMBER or GREEN)
  if s <= 0.3 then
    local t = s <= 0.1 and "! SUIT CHARGE CRITICAL - DEPLOY (E) !" or "SUIT CHARGE LOW"
    v:text(W // 2 - #t * 4, H // 2 - 56, t, s <= 0.1 and RED or AMBER)
  end
  if e.work then
    local f = vec.clamp(e.work.t / e.work.total, 0, 1)
    v:rect(W // 2 - 50, H // 2 + 52, 100, 4, { 0.15, 0.15, 0.2, 1 })
    v:rect(W // 2 - 50, H // 2 + 52, 100 * f, 4, AMBER)
  end
  -- your caches here: which way and how far
  local b = e.body
  local n = 0
  for _, c in ipairs(state.caches or {}) do
    if c.owner == p.record_index and c.site == e.site and n < 2 then
      local a = saucer.math.wrap(saucer.math.atan2(c.pos[1] - b.pos[1], c.pos[3] - b.pos[3]) - b.yaw)
      local dir = math.abs(a) < 0.4 and "AHEAD" or (math.abs(a) > 2.6 and "BEHIND" or (a > 0 and "LEFT" or "RIGHT"))
      local t = string.format("CACHE %s %dm", dir, vec.dist(c.pos, b.pos) // 1)
      v:text(W - 4 - #t * 8, 40 + n * 10, t, AMBER)
      n = n + 1
    end
  end
  return 1
end

-- the Lifeline's white-out, fading as you come to in the Seat
function M.lifeline(v, state, p)
  if not p.lifeline then return false end
  local frames = require("sim.excursion").tune().white * 60
  local k = 1 - (state.tick - p.lifeline.tick) / frames
  if k <= 0 then return false end
  v:rect(0, 0, v.width, v.height, { 1, 1, 1, k })
  return true
end

-- add-presentation-packaging: touch overlay. Held widgets light up, labels
-- sit centred, the stick shows where the thumb landed and where it is now,
-- and the lift slider shows its level.
-- (three letters fit the smallest buttons at the 512 x 288 target)
M.TOUCH_LABEL = { stick = "MOVE", lift = "LFT", up = "UP", dn = "DN", shrink = "-SZ", grow = "+SZ",
                  tractor = "BM", scan = "SCN", use = "USE", boost = "BST", jam = "JAM", grapple = "GRP" }
local TOUCH_FILL, TOUCH_EDGE = { 0.4, 0.8, 1, 0.22 }, { 0.6, 0.9, 1, 0.55 }
local TOUCH_HELD, TOUCH_KNOB = { 0.6, 1, 1, 0.5 }, { 0.8, 1, 1, 0.75 }

local function outline(v, x, y, w, h, c)
  v:rect(x, y, w, 1, c)
  v:rect(x, y + h - 1, w, 1, c)
  v:rect(x, y, 1, h, c)
  v:rect(x + w - 1, y, 1, h, c)
end

function M.touch(v)
  local W, H = v.width, v.height
  local lay = saucer.input.touch_layout()
  local n = 0
  for _, w in ipairs(lay) do
    if w.name ~= "look" then
      local x, y, ww, hh = w.x * W, w.y * H, w.w * W, w.h * H
      if w.kind ~= 1 then v:rect(x, y, ww, hh, w.held and TOUCH_HELD or TOUCH_FILL) end
      if not (w.kind == 1 and w.held) then outline(v, x, y, ww, hh, TOUCH_EDGE) end
      if w.kind == 2 then
        -- the lift level: a bar from the middle toward the thumb
        local mid, lv = y + hh / 2, (w.value or 0) * hh / 2
        v:rect(x + 2, math.min(mid, mid - lv), ww - 4, math.max(1, math.abs(lv)), TOUCH_KNOB)
      end
      local label = M.TOUCH_LABEL[w.name] or w.name:upper()
      label = label:sub(1, math.max(1, math.floor(ww / 8)))
      local tw = #label * 8
      v:text(x + math.max(1, (ww - tw) / 2), y + (w.kind == 1 and 2 or (hh - 8) / 2), label, WHITE)
      n = n + 1
    end
  end
  if lay.stick then
    -- floating stick: a ring where the thumb landed, a knob where it is
    local s = lay.stick
    local bx, by, kx, ky = s[1] * W, s[2] * H, s[3] * W, s[4] * H
    local r = 0.53 * 0.35 * H
    outline(v, bx - r, by - r, r * 2, r * 2, TOUCH_EDGE)
    local dx, dy = kx - bx, ky - by
    local d = math.sqrt(dx * dx + dy * dy)
    if d > r then kx, ky = bx + dx / d * r, by + dy / d * r end
    v:rect(kx - 6, ky - 6, 12, 12, TOUCH_KNOB)
    n = n + 1
  end
  return n
end

return M
