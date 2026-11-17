-- SPDX-License-Identifier: MIT
-- The Holodeck (OpenSpec add-holodeck-home-life). A room on the lower deck
-- whose control panel runs programs. Every program is a Lua file under
-- holo/ in the virtual file system, so the base game's data/base/holo/*.lua
-- and any mod's holo/*.lua show up alike (no engine change needed). A
-- program file returns a table:
--
--   id, name, desc, kind ("relax" | "training" | "replay" | "recreation"),
--   order (sort key), source ("starter": always in the library; "loot" or
--   "trader": unlocked by decoding a data core or buying it),
--   mode ("walk" default, or "fly": you pilot a simulated Seat),
--   look = { sky, fog, density, ground, light, ambient } (render colours),
--   needs(state, p) -> ok, why          optional: can it run now?
--   options(state, p) -> { {label, arg} } optional: one Run row per option
--   props(ctx) -> list of props          what the space holds (view/holo.lua
--                                        draws the kinds; `solid` = radius)
--   spots(ctx) -> list of { id, at = {x, z}, radius, label, act(api, spot) }
--   gates(ctx) -> list of { x, y, z, r } fly mode: rings to fly through
--   finish(api, seconds)                 fly mode: called when the last gate
--                                        is passed
--   step(api, dt)                        optional, every tick inside
--
-- ctx = { size (half width of the space, m), detail (1..3), arg, rng, state, p }.
-- Everything is deterministic: props come from a seeded rng, and only plain
-- data is kept in the state (p.holo is saved; p.holo_run is the live run).
-- Upgrade modules (home/holo_modules.lua) raise the space size, detail and
-- the number of guests who can share a program in co-op.
local data = require("lib.data")
local vec = require("lib.vec")
local comfort = require("sim.comfort")
local buffs = require("sim.buffs")
local M = {}

M.DIR = "holo"
M.EYE = 1.62
M.BODY_R = 0.3
M.ARCH_R = 1.4
M.GUEST_RANGE = 150   -- meters between saucers for a co-op guest to join a program
M.SEAT_H = 2.4        -- flying: start height above the simulated floor

local list_cache
-- every program, sorted by (order, id)
function M.programs()
  if list_cache then return list_cache end
  local out = {}
  for _, path in ipairs(saucer.vfs.list(M.DIR)) do
    if path:sub(-4) == ".lua" then
      local ok, prog = pcall(data.load, path)
      if ok and type(prog) == "table" and prog.id and prog.name then out[#out + 1] = prog
      else saucer.log.warn("holodeck: skipped " .. path .. (ok and "" or (": " .. tostring(prog)))) end
    end
  end
  table.sort(out, function(a, b)
    if (a.order or 50) ~= (b.order or 50) then return (a.order or 50) < (b.order or 50) end
    return a.id < b.id
  end)
  list_cache = out
  return out
end
function M.reset_cache() list_cache = nil end

function M.program(id)
  for _, pr in ipairs(M.programs()) do
    if pr.id == id then return pr end
  end
  return nil
end

function M.modules() return data.load("home/holo_modules.lua") end

-- ensure(p) -> p.holo, filled in where missing (writes only what is missing,
-- so render code may call it on a set-up player)
function M.ensure(p)
  if not p.holo then p.holo = {} end
  local h = p.holo
  if not h.library then h.library = {} end
  if not h.mods then h.mods = {} end
  for id in pairs(M.modules()) do
    if not h.mods[id] then h.mods[id] = 1 end
  end
  if not h.best then h.best = {} end
  if not h.runs then h.runs = 0 end
  return h
end

-- the value of a module track for this saucer (its current level)
function M.level(p, id)
  local m = M.modules()[id]
  local h = M.ensure(p)
  local lv = math.min(h.mods[id] or 1, #m.levels)
  return m.levels[lv], lv, #m.levels
end

function M.has(p, id)
  local pr = M.program(id)
  if not pr then return false end
  return pr.source == nil or pr.source == "starter" or M.ensure(p).library[id] == true
end

-- unlock(p, id) -> true when it was new
function M.unlock(p, id)
  local h = M.ensure(p)
  if h.library[id] or not M.program(id) then return false end
  h.library[id] = true
  return true
end

function M.library(p)
  local out = {}
  for _, pr in ipairs(M.programs()) do
    if M.has(p, pr.id) then out[#out + 1] = pr end
  end
  return out
end

-- install(p, uid) -> ok, why: a module item from the hold raises its track
function M.install(p, uid)
  local items = require("sim.items")
  local it = items.find(p, uid)
  if not it or not it.home or it.home.kind ~= "module" then return false, "not a module" end
  local id = it.home.id
  local m = M.modules()[id]
  if not m then return false, "unknown module" end
  local h = M.ensure(p)
  if (h.mods[id] or 1) >= #m.levels then return false, "already at the top level" end
  h.mods[id] = (h.mods[id] or 1) + 1
  items.remove(p, uid)
  return true, m
end

-- the host whose program a player is in (themselves, or the player they joined)
function M.host(state, p)
  local r = p.holo_run
  if not r then return nil end
  if r.guest_of then return state.players[r.guest_of] end
  return p
end

local function run_seed(state, id, arg)
  return saucer.seed_child(state.seed or 0, "holo:" .. id, arg or 0)
end

-- the context programs build their space from
function M.ctx(state, host, run)
  local size = M.level(host, "size")
  local detail = M.level(host, "detail")
  local pr = M.program(run.id)
  return { size = size * ((pr and pr.scale) or 1), detail = detail, arg = run.arg, state = state, p = host,
           rng = saucer.rng.new(run_seed(state, run.id, run.arg)) }
end

local scene_cache = {}
-- scene(state, host, run) -> { props, spots, gates, solids, size } (derived, cached)
function M.scene(state, host, run)
  local pr = M.program(run.id)
  local size = M.level(host, "size") * ((pr and pr.scale) or 1)
  local key = string.format("%s:%s:%s:%d:%d:%d", run.id, tostring(run.arg), tostring(state.seed), size,
    M.level(host, "detail"), host.index or 0)
  local sc = scene_cache[key]
  if sc then return sc end
  local ctx = M.ctx(state, host, run)
  sc = { size = ctx.size, props = pr and pr.props and pr.props(ctx) or {},
         spots = pr and pr.spots and pr.spots(M.ctx(state, host, run)) or {},
         gates = pr and pr.gates and pr.gates(M.ctx(state, host, run)) or {}, solids = {} }
  for _, q in ipairs(sc.props) do
    if q.solid and q.at then sc.solids[#sc.solids + 1] = { q.at[1], q.at[2], q.solid } end
  end
  scene_cache[key] = sc
  return sc
end

function M.arch(size) return { 0, -size + 0.6 } end
function M.spawn(size) return { 0, 0, -size + 2.0 } end

-- the helper programs get in act/step/finish
function M.api(state, p, run, ctx)
  local books = require("sim.books")
  return {
    state = state, p = p, run = run, size = M.scene(state, M.host(state, p) or p, run).size,
    msg = function(text) ctx.msg(state, p, text) end,
    fx = function(sound) ctx.fx(state, p, sound) end,
    buff = function(id, minutes) return buffs.give(state, p, id, minutes) end,
    credit = function(n) p.credits = (p.credits or 0) + n end,
    shelve = function(id) return books.add(p, id) end,
    lead = function(site)
      p.leads = p.leads or {}
      p.leads[tostring(site)] = true
    end,
  }
end

-- can program id run for p now? -> ok, why
function M.can_run(state, p, id)
  local pr = M.program(id)
  if not pr then return false, "no such program" end
  if not M.has(p, id) then return false, "not in the library" end
  if pr.needs then return pr.needs(state, p) end
  return true
end

local function enter_space(run, sc, pr)
  local s = M.spawn(sc.size)
  run.body = { pos = { s[1], 0, s[3] }, yaw = 0, pitch = 0 }
  if pr.mode == "fly" then
    local shipm = require("sim.ship")
    local seat = require("sim.config").by_id("seat") or 2
    run.craft = shipm.new({ s[1], M.SEAT_H, s[3] }, 0, seat)
    run.gate = 1
  end
end

-- start(state, p, id, arg, ctx): step through the arch into the program
function M.start(state, p, id, arg, ctx)
  local ok, why = M.can_run(state, p, id)
  if not ok then
    ctx.msg(state, p, "Holodeck: " .. (why or "cannot run that now"))
    ctx.fx(state, p, "denied")
    return false
  end
  local pr = M.program(id)
  local h = M.ensure(p)
  h.runs = h.runs + 1
  local run = { id = id, arg = arg, t = 0, guests = {} }
  p.holo_run = run
  p.panel = false
  local sc = M.scene(state, p, run)
  enter_space(run, sc, pr)
  ctx.msg(state, p, string.format("Program %s. %s", pr.name, pr.mode == "fly" and
    "Fly through the rings. Use ends the run." or "Use at the arch behind you ends it."))
  ctx.fx(state, p, "grow")
  return true
end

-- join(state, guest, host, ctx): a co-op guest steps into the host's program
function M.join(state, guest, host, ctx)
  local run = host.holo_run
  if not run or run.guest_of then return false, "no program" end
  if vec.dist(guest.ship.pos, host.ship.pos) > M.GUEST_RANGE then return false, "too far" end
  if 1 + #run.guests >= M.level(host, "seats") then return false, "no free guest slot" end
  run.guests[#run.guests + 1] = guest.index
  local sc = M.scene(state, host, run)
  local s = M.spawn(sc.size)
  guest.holo_run = { guest_of = host.index, body = { pos = { s[1] + 1.2, 0, s[3] }, yaw = 0, pitch = 0 } }
  guest.panel = false
  ctx.msg(state, guest, "You join " .. M.program(run.id).name .. " as a guest.")
  return true
end

-- exit(state, p, ctx, text): back into the real holodeck room
function M.exit(state, p, ctx, text)
  local run = p.holo_run
  if not run then return false end
  if run.guest_of then
    local host = state.players[run.guest_of]
    if host and host.holo_run then
      for i, g in ipairs(host.holo_run.guests or {}) do
        if g == p.index then table.remove(host.holo_run.guests, i) break end
      end
    end
  else
    for _, g in ipairs(run.guests or {}) do
      local gp = state.players[g]
      if gp and gp.holo_run then M.exit(state, gp, ctx, "The host ended the program.") end
    end
  end
  p.holo_run = false
  p.panel = false
  local avatar = require("sim.avatar")
  local L = avatar.layout()
  local H = L.holodeck
  p.body = avatar.new(L, H.inside, H.inside_yaw)
  p.mode = "walk"
  ctx.msg(state, p, text or "The program ends. The grid fades back in.")
  ctx.fx(state, p, "shrink")
  return true
end

-- the program's spot within reach of the holo body, nearest first
function M.spot_near(state, p)
  local run = p.holo_run
  local host = M.host(state, p)
  if not run or not host or not host.holo_run then return nil end
  local sc = M.scene(state, host, host.holo_run)
  local b = run.body
  local best, bd
  for _, s in ipairs(sc.spots) do
    local dx, dz = b.pos[1] - s.at[1], b.pos[3] - s.at[2]
    local dd = dx * dx + dz * dz
    if dd <= (s.radius or 1.2) ^ 2 and (not bd or dd < bd) then best, bd = s, dd end
  end
  return best
end

function M.near_arch(state, p)
  local run = p.holo_run
  local host = M.host(state, p)
  if not run or not host or not host.holo_run then return false end
  local a = M.arch(M.scene(state, host, host.holo_run).size)
  local b = run.body
  return (b.pos[1] - a[1]) ^ 2 + (b.pos[3] - a[2]) ^ 2 <= M.ARCH_R * M.ARCH_R
end

-- Use inside a program: a spot, the exit arch, or (flying) end the run
function M.use(state, p, ctx)
  local run = p.holo_run
  local host = M.host(state, p)
  if not host or not host.holo_run then return M.exit(state, p, ctx) end
  local pr = M.program(host.holo_run.id)
  if run.craft or M.near_arch(state, p) then return M.exit(state, p, ctx) end
  local s = M.spot_near(state, p)
  if s and s.act then
    s.act(M.api(state, p, host.holo_run, ctx), s)
    return true
  end
  ctx.msg(state, p, pr and (pr.name .. ": the exit arch is at the start, behind you") or "The arch is behind you")
  return false
end

-- walking in the simulated space: the square of half width size, round solids
function M.walk(body, cmd, dt, sc)
  local L = require("sim.avatar").layout()
  body.yaw = comfort.yaw(body.yaw, cmd, L.turn, dt)
  body.pitch = vec.clamp(body.pitch + cmd:axis("look") * L.look * dt, -L.pitch_limit, L.pitch_limit)
  local mx, mz = cmd:axis("move_x"), cmd:axis("move_z")
  if mx == 0 and mz == 0 then return 0 end
  local f, r = vec.fwd(body.yaw), vec.right(body.yaw)
  local speed = L.walk_speed * (cmd:held("boost") and L.run_factor or 1)
  local lim = sc.size - M.BODY_R
  local blocked = 0
  for axis = 1, 2 do
    local i = axis == 1 and 1 or 3
    local d = (f[i] * mz + r[i] * mx) * speed * dt
    if d ~= 0 then
      local np = { body.pos[1], 0, body.pos[3] }
      np[i] = np[i] + d
      local hit = math.abs(np[1]) > lim or math.abs(np[3]) > lim
      for _, s in ipairs(sc.solids) do
        local dx, dz = np[1] - s[1], np[3] - s[2]
        local rr = s[3] + M.BODY_R
        if dx * dx + dz * dz < rr * rr then hit = true end
      end
      if hit then blocked = blocked + 1 else body.pos = np end
    end
  end
  return blocked
end

-- flying a simulated Seat: the space is a box (size wide, 2 x size high)
local function fly(run, cmd, dt, sc)
  local flight = require("sim.flight")
  local lim, top = sc.size - 1.2, sc.size * 1.2
  flight.step(run.craft, cmd, dt, function(craft, delta)
    local np = vec.add(craft.pos, delta)
    local blocked = 0
    for i = 1, 3 do
      local lo, hi = -lim, lim
      if i == 2 then lo, hi = 0.8, top end
      if np[i] < lo then np[i], blocked = lo, blocked + 1 elseif np[i] > hi then np[i], blocked = hi, blocked + 1 end
    end
    return np, blocked
  end)
  local g = sc.gates[run.gate]
  if g and vec.dist(run.craft.pos, { g[1], g[2], g[3] }) <= (g.r or g[4] or 1.5) then
    run.gate = run.gate + 1
    return "gate"
  end
  return nil
end

-- step(state, p, cmd, dt, ctx): one tick inside a program
function M.step(state, p, cmd, dt, ctx)
  local run = p.holo_run
  local host = M.host(state, p)
  if not host or not host.holo_run then
    M.exit(state, p, ctx, "The program is gone.")
    return
  end
  local hrun = host.holo_run
  local sc = M.scene(state, host, hrun)
  local pr = M.program(hrun.id)
  if run.craft then
    if not run.done then run.t = run.t + dt end
    local ev = fly(run, cmd, dt, sc)
    if ev == "gate" then
      ctx.fx(state, p, "pickup")
      if run.gate > #sc.gates and not run.done then
        run.done = true
        local h = M.ensure(p)
        local best = h.best[hrun.id]
        local first = best == nil
        if not best or run.t < best then h.best[hrun.id] = run.t end
        ctx.msg(state, p, string.format("Course clear in %.1f s%s", run.t,
          first and "" or string.format(" (best %.1f s)", h.best[hrun.id])))
        if pr.finish then pr.finish(M.api(state, p, hrun, ctx), run.t, first) end
      else
        ctx.msg(state, p, string.format("Ring %d/%d", run.gate - 1, #sc.gates))
      end
    end
  else
    run.t = (run.t or 0) + dt
    M.walk(run.body, cmd, dt, sc)
  end
  if pr and pr.step and not run.guest_of then pr.step(M.api(state, p, hrun, ctx), dt) end
end

-- where the player's eyes are inside the program -> pos, yaw, pitch
function M.viewpoint(state, p)
  local run = p.holo_run
  if run.craft then
    local c = run.craft
    local cfg = require("sim.config").get(c.size)
    local e = require("sim.avatar").rot(c.yaw, cfg.pilot_eye)
    return { c.pos[1] + e[1], c.pos[2] + e[2], c.pos[3] + e[3] }, c.yaw, c.pitch
  end
  local b = run.body
  return { b.pos[1], b.pos[2] + M.EYE, b.pos[3] }, b.yaw, b.pitch
end

-- what Use does in here, for the HUD
function M.hint(state, p)
  local run = p.holo_run
  if not run then return nil end
  if run.craft then return "USE: END THE RUN" end
  if M.near_arch(state, p) then return "USE: EXIT THE PROGRAM" end
  local s = M.spot_near(state, p)
  if s then return s.label or "USE" end
  return nil
end

-- the holodeck panel: run programs, install modules, join a co-op host
function M.rows(state, p, ctx)
  local rows = {}
  local items = require("sim.items")
  for _, pr in ipairs(M.library(p)) do
    local id = pr.id
    local opts = pr.options and pr.options(state, p) or nil
    if opts and #opts > 0 then
      for _, o in ipairs(opts) do
        local arg = o.arg
        rows[#rows + 1] = { text = "Run " .. pr.name .. ": " .. o.label,
          act = function(st, pl) M.start(st, pl, id, arg, ctx) end }
      end
    else
      local ok, why = M.can_run(state, p, id)
      rows[#rows + 1] = { text = "Run " .. pr.name .. (ok and "" or (" (" .. (why or "not now") .. ")")), enabled = ok,
        act = function(st, pl) M.start(st, pl, id, nil, ctx) end }
    end
  end
  for _, it in ipairs(p.hold) do
    if it.home and it.home.kind == "module" then
      local uid = it.uid
      rows[#rows + 1] = { text = "Install " .. it.name, act = function(st, pl)
        local ok, m = M.install(pl, uid)
        if ok then
          local v = M.level(pl, it.home.id)
          ctx.msg(st, pl, string.format("Installed the %s: %s now %d", m.name, m.what, v))
          ctx.fx(st, pl, "bank")
        else
          ctx.msg(st, pl, "Holodeck: " .. m)
          ctx.fx(st, pl, "denied")
        end
      end }
    end
  end
  for _, o in ipairs(state.players) do
    if o ~= p and o.holo_run and not o.holo_run.guest_of then
      local host = o
      rows[#rows + 1] = { text = string.format("Join P%d in %s", o.index, M.program(o.holo_run.id).name),
        act = function(st, pl)
          local ok, why = M.join(st, pl, host, ctx)
          if not ok then
            ctx.msg(st, pl, "Holodeck: " .. why)
            ctx.fx(st, pl, "denied")
          end
        end }
    end
  end
  rows[#rows + 1] = { text = string.format("Space %d m  detail %d  guests %d", M.level(p, "size") * 2, M.level(p, "detail"),
    M.level(p, "seats") - 1), enabled = false }
  rows[#rows + 1] = { text = "Close", act = function(_, pl) pl.panel = false end }
  return rows
end

return M
