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

-- Where to draw a saucer this frame. While it reconfigures, the old hull
-- shrinks (or the new one grows) about the pilot's eye point, and the rooms
-- fold away faster than the hull: they are gone by the halfway mark when
-- shrinking and only unfold in the second half when growing.
-- -> { size, pos, yaw, scale, fold, ipos, iscale }
function M.pose(ship)
  if not ship.morph then
    return { size = ship.size, pos = ship.pos, yaw = ship.yaw, scale = 1, fold = 1, ipos = ship.pos, iscale = 1 }
  end
  local m = ship.morph
  local t = shipm.progress(ship)
  local da, db = configs.get(m.from).diameter, configs.get(ship.size).diameter
  local d = da + (db - da) * t
  local size, base, base_yaw, k
  if t < 0.5 then size, base, base_yaw, k = m.from, m.pos, m.yaw, d / da
  else size, base, base_yaw, k = ship.size, ship.pos, ship.yaw, d / db end
  local yaw = m.yaw + sm.wrap(ship.yaw - m.yaw) * t
  local shrinking = ship.size > m.from
  local fold = shrinking and math.max(0, 1 - 2 * t) or math.max(0, 2 * t - 1)
  local e = m.eye
  local rel = avatar.rot(yaw - base_yaw, vec.sub(base, e))
  return {
    size = size, yaw = yaw, scale = k, fold = fold,
    pos = vec.add(e, vec.scale(rel, k)),
    ipos = vec.add(e, vec.scale(rel, k * fold)), iscale = k * fold,
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

local function draw_saucer(v, A, o, own_eyes)
  local d = M.pose(o.ship)
  local c = configs.get(d.size)
  local m = A.saucer[d.size]
  v:mesh(m.hull, { pos = d.pos, yaw = d.yaw, scale = d.scale, tex = A.tex.hull, palette = A.pal.base })
  if c.interior then
    if d.iscale > 0.01 then v:mesh(A.interior, { pos = d.ipos, yaw = d.yaw, scale = d.iscale }) end
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
    draw_saucer(v, A, o, j == v.player and (p.cam ~= "chase" or v.xr))
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
