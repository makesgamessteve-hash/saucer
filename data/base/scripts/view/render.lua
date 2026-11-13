-- SPDX-License-Identifier: MIT
-- Per-viewport rendering. Gets a read-only state; must not mutate it.
local assets = require("view.assets")
local hud = require("view.hud")
local configs = require("sim.config")
local vec = require("lib.vec")
local game = require("sim.game")
local tractor = require("sim.tractor")
local M = {}

local heard = {} -- per player: last fx tick played (render-side only)
M.SOUNDS = {
  shrink = "authored/sounds/shrink.wav", grow = "authored/sounds/grow.wav", tractor = "authored/sounds/tractor.wav",
  pickup = "authored/sounds/pickup.wav", denied = "authored/sounds/denied.wav", bank = "authored/sounds/bank.wav",
  echo = "authored/sounds/echo.wav",
}

function M.camera(p, xr)
  local ship = p.ship
  local c = configs.get(ship.size)
  local R, H = c.diameter / 2, c.height
  if p.cam == "chase" and not xr then
    local f = vec.fwd(ship.yaw)
    local back = R * 2.2 + 6
    return { pos = { ship.pos[1] - f[1] * back, ship.pos[2] + H * 1.2 + 3, ship.pos[3] - f[3] * back },
             yaw = ship.yaw, pitch = ship.pitch - 0.22, fov = 70 }
  end
  return { pos = { ship.pos[1], ship.pos[2] + H * 0.28, ship.pos[3] }, yaw = ship.yaw, pitch = ship.pitch, fov = 75 }
end

-- visual hull scale while morphing between sizes
function M.morph_scale(ship)
  if not ship.target then return 1 end
  local all = configs.all()
  local total = ship.target > ship.size and all.shrink_time or all.grow_time
  local t = 1 - ship.t_left / total
  local a, b = configs.get(ship.size).diameter, configs.get(ship.target).diameter
  return (a + (b - a) * t) / a
end

function M.audio(state, p)
  local last = heard[p.index] or -1
  if state.tick < last then last = -1 end
  for _, f in ipairs(p.fx) do
    if f.tick > last and M.SOUNDS[f.sound] then saucer.audio.play(M.SOUNDS[f.sound], { volume = 0.8 }) end
  end
  heard[p.index] = state.tick
end

function M.render(v, state, alpha)
  local p = state.players[v.player]
  if not p then return end
  local A = assets.init()
  local cam = M.camera(p, v.xr)
  v:camera(cam)
  v:fog({ color = { 0.02, 0.02, 0.06 }, density = 0.0012, clear = { 0.0, 0.0, 0.025 }, light = { 0.35, 0.8, 0.45 },
          ambient = 0.38 })
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
  local spin = (state.tick % 360) * saucer.math.tau / 360
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
  -- saucers
  for j, o in ipairs(state.players) do
    local m = A.saucer[o.ship.size]
    local sc = M.morph_scale(o.ship)
    local own_cockpit = (j == v.player) and (p.cam == "cockpit" or v.xr)
    v:mesh(m.hull, { pos = o.ship.pos, yaw = o.ship.yaw, scale = sc, tex = A.tex.hull, palette = A.pal.base })
    if not own_cockpit then v:mesh(m.dome, { pos = o.ship.pos, yaw = o.ship.yaw, scale = sc, ghost = true }) end
    if o.ghost > 0 and o.ghost_size then
      v:mesh(A.saucer[o.ghost_size].hull, { pos = o.ship.pos, yaw = o.ship.yaw, ghost = true, tint = { 1, 0.2, 0.2, 0.5 } })
    end
  end
  -- tractor beam: a dotted line of sprites
  local target
  if p.site ~= 0 then target = tractor.find(state, p, p.site, game.ruin(p.site)) end
  if p.tractor and target then
    for k = 1, 8 do
      local t = k / 9
      local q = vec.add(p.ship.pos, vec.scale(vec.sub(target.pos, p.ship.pos), t))
      v:billboard(A.tex.beam, q, 0.5, { palette = A.pal.base, tint = { 1, 0.9, 0.4, 0.8 } })
    end
  end
  if not v.xr then hud.draw(v, state, p, target) end
  if v.index == v.player then M.audio(state, p) end
end

return M
