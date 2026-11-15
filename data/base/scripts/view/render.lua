-- SPDX-License-Identifier: MIT
-- Per-viewport rendering. Gets a read-only state; must not mutate it.
-- The camera is the player's own eyes: on foot under the dome, or seated at
-- the helm with the interior around them. A chase view is a toggle away.
local assets = require("view.assets")
local hud = require("view.hud")
local configs = require("sim.config")
local vec = require("lib.vec")
local game = require("sim.game")
local tractor = require("sim.tractor")
local shipm = require("sim.ship")
local avatar = require("sim.avatar")
local fold = require("sim.fold")
local panelm = require("sim.panel")
local sm = saucer.math
local M = {}

local heard = {} -- per player: last fx tick played (render-side only)
M.SOUNDS = {
  shrink = "authored/sounds/shrink.wav", grow = "authored/sounds/grow.wav", tractor = "authored/sounds/tractor.wav",
  pickup = "authored/sounds/pickup.wav", denied = "authored/sounds/denied.wav", bank = "authored/sounds/bank.wav",
  echo = "authored/sounds/echo.wav",
}

function M.camera(p, xr)
  local ship = p.ship
  if p.cam == "chase" and not xr then
    local c = configs.get(ship.size)
    local R, H = c.diameter / 2, c.height
    local f = vec.fwd(ship.yaw)
    local back = R * 2.2 + 6
    return { pos = { ship.pos[1] - f[1] * back, ship.pos[2] + H * 1.2 + 3, ship.pos[3] - f[3] * back },
             yaw = ship.yaw, pitch = ship.pitch - 0.22, fov = 70, near = 0.1 }
  end
  local eye, yaw, pitch = game.viewpoint(p)
  return { pos = eye, yaw = yaw, pitch = pitch, fov = 75, near = 0.05 }
end

-- Where to draw a saucer this frame. A fold to the Seat happens in two
-- beats (milestone 2): first the rooms pack away one by one while the hull
-- holds its size (sim/fold.lua), then the hull shrinks about the player's eye.
-- Unfolding plays it backwards: the hull grows first, then the rooms unpack.
-- -> { size, pos, yaw, scale, fold, ipos, iscale, ht }
local function hull_t(ship, t)
  local m = ship.morph
  local a, b = configs.get(m.from).interior, configs.get(ship.size).interior
  if a and not b then return math.max(0, (t - fold.ROOM_PHASE) / (1 - fold.ROOM_PHASE)) end
  if b and not a then return math.min(1, t / fold.ROOM_PHASE) end
  return t
end
M.hull_t = hull_t

function M.pose(ship)
  if not ship.morph then
    return { size = ship.size, pos = ship.pos, yaw = ship.yaw, scale = 1, fold = 1, ipos = ship.pos, iscale = 1, ht = 1 }
  end
  local m = ship.morph
  local t = hull_t(ship, shipm.progress(ship))
  local da, db = configs.get(m.from).diameter, configs.get(ship.size).diameter
  local d = da + (db - da) * t
  local size, base, base_yaw, k
  if t < 0.5 then size, base, base_yaw, k = m.from, m.pos, m.yaw, d / da
  else size, base, base_yaw, k = ship.size, ship.pos, ship.yaw, d / db end
  local yaw = m.yaw + sm.wrap(ship.yaw - m.yaw) * t
  local shrinking = ship.size > m.from
  local f = shrinking and math.max(0, 1 - 2 * t) or math.max(0, 2 * t - 1)
  local e = m.eye
  local rel = avatar.rot(yaw - base_yaw, vec.sub(base, e))
  return {
    size = size, yaw = yaw, scale = k, fold = f, ht = t,
    pos = vec.add(e, vec.scale(rel, k)),
    ipos = vec.add(e, vec.scale(rel, k * f)), iscale = k * f,
  }
end

-- kept for mods: visual hull scale relative to the drawn config
function M.morph_scale(ship) return M.pose(ship).scale end

function M.audio(state, p)
  local last = heard[p.index] or -1
  if state.tick < last then last = -1 end
  for _, f in ipairs(p.fx) do
    if f.tick > last and M.SOUNDS[f.sound] then saucer.audio.play(M.SOUNDS[f.sound], { volume = 0.8 }) end
  end
  heard[p.index] = state.tick
end

-- hull-local point -> world, for a drawn pose
local function at(d, lp)
  local w = avatar.rot(d.yaw, { lp[1] * d.scale, lp[2] * d.scale, lp[3] * d.scale })
  return { d.pos[1] + w[1], d.pos[2] + w[2], d.pos[3] + w[3] }
end
M.at = at

-- a glowing block on a console: hull-local centre and size
local function blip(v, A, d, lp, size, color)
  v:mesh(A.unit, { pos = at(d, lp), yaw = d.yaw, scale = { size[1] * d.scale, size[2] * d.scale, size[3] * d.scale },
                   tint = color })
end
M.blip = blip

M.RADAR_RANGE = 1200
-- radar targets for a player: { pos, color }
function M.radar_targets(state, p)
  local out = {}
  for _, s in ipairs(state.sector.sites) do
    out[#out + 1] = { pos = s.pos, color = s.id == p.site and { 1, 0.75, 0.3, 1 } or { 0.9, 0.95, 1, 1 } }
  end
  out[#out + 1] = { pos = state.sector.trader.pos, color = { 0.35, 1, 0.45, 1 } }
  for _, t in ipairs(M.extra_radar) do
    for _, x in ipairs(t(state, p)) do out[#out + 1] = x end
  end
  return out
end
M.extra_radar = {} -- functions(state, p) -> list of { pos, color }; milestone 3 adds sentries and Resonant marks

-- live helm readouts (milestone 2): a radar on the desk, Charge/hull/shield
-- bars on the left wing screen, hold slots and the size ladder on the right
function M.console(v, A, state, o, d)
  local L = avatar.layout()
  local ship = o.ship
  local all = configs.all()
  local desk, lw, rw
  for _, f in ipairs(L.furniture) do
    if f.kind == "helm_desk" then desk = f end
    if f.kind == "helm_wing" and f.side < 0 then lw = f end
    if f.kind == "helm_wing" and f.side > 0 then rw = f end
  end
  if not desk then return 0 end
  local fl = L.decks[1].floor
  local cx, cz = (desk.box[1] + desk.box[3]) / 2, (desk.box[2] + desk.box[4]) / 2
  local top = fl + desk.h + 0.02
  local n = 0
  blip(v, A, d, { cx, top, cz }, { 0.03, 0.02, 0.03 }, { 1, 1, 1, 1 })
  for _, tg in ipairs(M.radar_targets(state, o)) do
    local rel = avatar.rot(-ship.yaw, vec.sub(tg.pos, ship.pos))
    local x, z = rel[1] / M.RADAR_RANGE * 0.22, rel[3] / M.RADAR_RANGE * 0.22
    local r = sm.sqrt(x * x + z * z)
    if r > 0.22 then x, z = x * 0.22 / r, z * 0.22 / r end
    blip(v, A, d, { cx + x, top + 0.01, cz + z }, { 0.035, 0.025, 0.035 }, tg.color)
    n = n + 1
  end
  local function wing_face(w)
    return w.side < 0 and w.box[3] + 0.02 or w.box[1] - 0.02
  end
  if lw then
    local x = wing_face(lw)
    local y0, y1 = fl + lw.h * 0.6, fl + lw.h * 0.95
    local vals = {
      { ship.charge / all.max_charge, { 0.4, 0.9, 1, 1 } },
      { (ship.hull or 100) / 100, { 0.4, 1, 0.5, 1 } },
      { (ship.shield or 100) / 100, { 0.5, 0.6, 1, 1 } },
    }
    for i, bar in ipairs(vals) do
      local z = lw.box[2] + 0.15 + (i - 1) * 0.28
      local h = math.max(0.01, (y1 - y0) * vec.clamp(bar[1], 0, 1))
      blip(v, A, d, { x, y0 + h / 2, z }, { 0.012, h, 0.16 }, bar[1] < 0.3 and { 1, 0.35, 0.3, 1 } or bar[2])
      n = n + 1
    end
  end
  if rw then
    local x = wing_face(rw)
    local y0 = fl + rw.h * 0.62
    for i = 1, all.hold_slots do
      local it = o.hold[i]
      local col = { 0.12, 0.14, 0.18, 1 }
      if it then col = it.hot and { 1, 0.7, 0.25, 1 } or { 0.4, 1, 0.5, 1 } end
      local row, colm = (i - 1) // 4, (i - 1) % 4
      blip(v, A, d, { x, y0 + row * 0.07, rw.box[2] + 0.2 + colm * 0.16 }, { 0.012, 0.05, 0.1 }, col)
      n = n + 1
    end
    for i = 1, configs.count() do
      local on = i == ship.size
      blip(v, A, d, { x, y0 + 0.24, rw.box[2] + 0.2 + (i - 1) * 0.16 }, { 0.012, 0.04, 0.12 },
           on and { 0.4, 1, 0.5, 1 } or { 0.2, 0.22, 0.28, 1 })
    end
  end
  return n
end

-- the Villa's rooms, each folding on its own (sim/fold.lua) plus the doors
function M.rooms(v, A, o, d, state)
  local L = avatar.layout()
  local ship = o.ship
  local amounts = fold.amounts(ship, L)
  local eye = ship.morph and fold.eye_local(ship) or { 0, 0, 0 }
  local drawn = 0
  for _, g in ipairs(fold.groups(L)) do
    local a = amounts[g.id] or 0
    local m = A.groups[g.id]
    if a < 1 and m then
      local lp, sc = fold.transform(g, a, { eye[1], g.anchor[2], eye[3] })
      local opts = { pos = at(d, lp), yaw = d.yaw, scale = { sc[1] * d.scale, sc[2] * d.scale, sc[3] * d.scale } }
      v:mesh(m, opts)
      if a > 0 then
        -- fold-space shimmer around a room while it packs
        v:mesh(m, { pos = opts.pos, yaw = d.yaw, scale = { opts.scale[1] * 1.04, opts.scale[2] * 1.04 + 0.02,
                    opts.scale[3] * 1.04 }, ghost = true, tint = { 0.4, 1, 0.9, 0.6 } })
      end
      drawn = drawn + 1
    end
  end
  if not ship.morph then
    for i, door in ipairs(L.doors or {}) do
      local open = o.doors and o.doors[i] or 0
      local b = door.box
      local w = b[3] - b[1]
      local side = (b[1] + b[3]) > 0 and 1 or -1
      if A.doors[i] then v:mesh(A.doors[i], { pos = at(d, { open * w * side * 0.95, 0, 0 }), yaw = d.yaw, scale = d.scale }) end
    end
    if state then M.console(v, A, state, o, d) end
  end
  return drawn
end

local function draw_saucer(v, A, o, own_eyes, state)
  local d = M.pose(o.ship)
  local c = configs.get(d.size)
  local m = A.saucer[d.size]
  v:mesh(m.hull, { pos = d.pos, yaw = d.yaw, scale = d.scale, tex = A.tex.hull, palette = A.pal.base })
  if c.interior then
    M.rooms(v, A, o, d, state)
    v:mesh(A.glass, { pos = d.pos, yaw = d.yaw, scale = d.scale, ghost = true, tint = { 0.55, 0.8, 1, 0.3 } })
    if o.mode == "walk" and not own_eyes and not o.ship.morph then
      local L = avatar.layout()
      local w = vec.add(o.ship.pos, avatar.rot(o.ship.yaw, o.body.pos))
      v:mesh(A.person, { pos = w, yaw = o.ship.yaw + o.body.yaw })
    end
  else
    v:mesh(m.dome, { pos = d.pos, yaw = d.yaw, scale = d.scale, ghost = true, tint = { 0.55, 0.8, 1, 0.3 } })
  end
  if o.ghost > 0 and o.ghost_size then
    v:mesh(A.saucer[o.ghost_size].hull, { pos = o.ghost_pos or o.ship.pos, yaw = o.ship.yaw, ghost = true,
                                          tint = { 1, 0.2, 0.2, 0.5 } })
  end
end

function M.render(v, state, alpha)
  local p = state.players[v.player]
  if not p then return end
  local A = assets.init()
  local cam = M.camera(p, v.xr)
  v:camera(cam)
  v:fog({ color = { 0.02, 0.02, 0.06 }, density = 0.0012, clear = { 0.0, 0.0, 0.025 }, light = { 0.35, 0.8, 0.45 },
          ambient = 0.42 })
  v:mesh(A.stars, { pos = cam.pos, sky = true })
  -- distant nebula sprites
  v:billboard(A.tex.nebula, { cam.pos[1] + 700, cam.pos[2] + 160, cam.pos[3] + 520 }, 900,
              { palette = A.pal.base, tint = { 0.8, 0.7, 1, 0.9 } })
  v:billboard(A.tex.nebula, { cam.pos[1] - 820, cam.pos[2] - 120, cam.pos[3] - 300 }, 700,
              { palette = A.pal.base, tint = { 1, 0.6, 0.5, 0.8 } })
  -- derelicts
  for i, site in ipairs(state.sector.sites) do
    local r = game.ruin(i)
    if r then v:mesh(assets.ruin_mesh(r, site.pos), { tex = A.tex.hull, palette = A.pal.base }) end
  end
  v:mesh(A.station, { pos = state.sector.trader.pos, yaw = state.tick * 0.002 })
  -- this player's loot instances and Echoes
  local spin = (state.tick % 360) * sm.tau / 360
  if p.site ~= 0 then
    for _, cand in ipairs(tractor.candidates(state, p, p.site, game.ruin(p.site))) do
      local s = 0.6 + cand.item.size * 0.35
      if cand.echo then
        v:billboard(A.tex.echo, cand.pos, 1.6, { palette = A.pal.base })
      else
        v:billboard(A.tex.loot, cand.pos, s, { palette = A.pal.base })
        v:mesh(A.cache_mesh, { pos = { cand.pos[1], cand.pos[2] - s * 0.7, cand.pos[3] }, yaw = spin, scale = s * 0.6 })
      end
    end
  end
  -- saucers (and, through their domes, the people in them)
  for j, o in ipairs(state.players) do
    draw_saucer(v, A, o, j == v.player and (p.cam ~= "chase" or v.xr), state)
  end
  -- tractor beam: a dotted line of sprites from just below the eyes
  local target
  local eye, yaw, pitch = game.viewpoint(p)
  if p.site ~= 0 then target = tractor.find(state, p, p.site, game.ruin(p.site), eye, yaw, pitch) end
  if p.tractor and target then
    local from = { eye[1], eye[2] - 0.6, eye[3] }
    for k = 1, 10 do
      local t = k / 11
      local q = vec.add(from, vec.scale(vec.sub(target.pos, from), t))
      v:billboard(A.tex.beam, q, 0.5, { palette = A.pal.base, tint = { 1, 0.9, 0.4, 0.8 } })
    end
  end
  if not v.xr then hud.draw(v, state, p, target) end
  if v.index == v.player then M.audio(state, p) end
end

return M
